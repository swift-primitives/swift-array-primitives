import Array_Primitives
import Buffer_Linear_Primitive
import Buffer_Linear_Primitives
import Buffer_Primitive
import Index_Primitives
import Memory_Allocator_Primitive
import Memory_Heap_Primitives
import Ordinal_Primitives_Standard_Library_Integration
import Ownership_Shared_Primitive
import Storage_Contiguous_Primitives
import Tagged_Primitives_Standard_Library_Integration
import Testing

// MARK: - Fixtures

/// ~Copyable element with identity + recording deinit (teardown observation).
private struct Item: ~Copyable {
    let id: Int
    var value: Int
    init(_ id: Int, value: Int = 0) {
        self.id = id
        self.value = value
    }
    deinit { Probe.recordDestroy(id) }
}

/// Copyable element with observable destruction (class ref — deinit at refcount zero).
private final class Payload {
    let id: Int
    init(_ id: Int) { self.id = id }
    deinit { Probe.recordDestroy(id) }
}

/// Serialized destruction recorder (the suite below is `.serialized`).
private enum Probe {
    nonisolated(unsafe) static var _destroyed: [Int] = []
    static func reset() { unsafe _destroyed = [] }
    static func recordDestroy(_ id: Int) { unsafe _destroyed.append(id) }
    static var destroyedSorted: [Int] { unsafe _destroyed.sorted() }
}

// The two ratified columns.
private typealias HeapColumn<E: ~Copyable> =
    Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear

private typealias SharedColumn<E: ~Copyable> = Ownership.Shared<E, HeapColumn<E>>

// `Array<E>` here is the institute's own typealias (shadows `Swift.Array`); `[E]`
// sugar is hardwired to `Swift.Array` and would silently change the type.
// swift-format-ignore: UseShorthandTypeNames
// swiftlint:disable syntactic_sugar
/// The default move-only array — the CANONICAL front door ([DS-028]).
private typealias MoveArray<E: ~Copyable> = Array<E>
// swiftlint:enable syntactic_sugar

/// The explicit CoW value-semantic array (`Shared` column — no front door yet;
/// spelled through the carrier).
private typealias CoWArray<E: ~Copyable> = __Array<SharedColumn<E>>

/// Generic borrow-through-call reads via the lattice bound — compiles ONLY with the
/// element-unbounded conformances (the Audit-#5 relaxation, W5-1; the R2 probe shape).
private func latticeSum<C: Collection.`Protocol` & ~Copyable>(_ c: borrowing C) -> Int
where C.Element == Item, C.Index == Index<Item> {
    var total = 0
    var i = c.startIndex
    while i < c.endIndex {
        total += c[i].value
        i = c.index(after: i)
    }
    return total
}

@Suite(.serialized)
struct ArrayTests {

    // MARK: - Construction + properties (both columns)

    @Test
    func `direct column constructs empty with capacity`() {
        let a = MoveArray<Int>(initialCapacity: 4)
        let isEmpty = a.isEmpty
        let count = a.count
        #expect(isEmpty)
        #expect(count == Index<Int>.Count(0))
        let capacityOK = a.capacity >= Index<Int>.Count(4)
        #expect(capacityOK)
        let free = a.freeCapacity
        #expect(free == a.capacity)
    }

    @Test
    func `shared column constructs empty with capacity`() {
        let a = CoWArray<Int>(initialCapacity: 4)
        let isEmpty = a.isEmpty
        #expect(isEmpty)
        let capacityOK = a.capacity >= Index<Int>.Count(4)
        #expect(capacityOK)
    }

    // MARK: - Append / subscript / element access (both columns)

    @Test
    func `direct column appends, reads, and writes through the gated subscript`() {
        var a = MoveArray<Int>(initialCapacity: 2)
        a.append(10)
        a.append(20)
        a.append(30)  // growth past initial capacity
        let count = a.count
        #expect(count == Index<Int>.Count(3))
        let e1 = a[1]
        #expect(e1 == 20)
        a[1] = 25  // _modify (gate is a no-op here)
        let e1b = a[1]
        #expect(e1b == 25)
        let opt = a.element(at: 2)
        #expect(opt == 30)
        let beyond = a.element(at: 3)
        #expect(beyond == nil)
        let viaClosure = a.withElement(at: 0) { $0 * 2 }
        #expect(viaClosure == 20)
    }

    @Test
    func `shared column appends and reads; copies share until mutation`() {
        var a = CoWArray<Int>(initialCapacity: 2)
        a.append(1)
        a.append(2)
        let b = a  // S5: Array is Copyable because S is
        let bCount = b.count
        #expect(bCount == Index<Int>.Count(2))
        a.append(3)  // CoW restore inside Shared.append
        let aCount = a.count
        let bCount2 = b.count
        #expect(aCount == Index<Int>.Count(3))
        #expect(bCount2 == Index<Int>.Count(2))
    }

    @Test
    func `the seam mutation gate makes the generic subscript CoW-correct`() {
        var a = CoWArray<Int>(initialCapacity: 2)
        a.append(1)
        a.append(2)
        let b = a  // share the box
        a[0] = 100  // generic _modify → unshare()
        let aSees = a[0]
        let bSees = b[0]
        #expect(aSees == 100)
        #expect(bSees == 1)  // sibling untouched: uniqueness was restored
    }

    // MARK: - Generic mutations through the gate + seam (both columns)

    @Test
    func `pop and remove(at:) shift correctly on the direct column`() {
        var a = MoveArray<Int>(initialCapacity: 4)
        a.append(1)
        a.append(2)
        a.append(3)
        a.append(4)
        let last = a.pop()
        #expect(last == 4)
        let removed = a.remove(at: 1)  // [1, 2, 3] → remove 2 → [1, 3]
        #expect(removed == 2)
        let count = a.count
        #expect(count == Index<Int>.Count(2))
        let e0 = a[0]
        let e1 = a[1]
        #expect(e0 == 1)
        #expect(e1 == 3)
    }

    @Test
    func `remove(at:) on the shared column diverges from siblings`() {
        var a = CoWArray<Int>(initialCapacity: 4)
        a.append(1)
        a.append(2)
        a.append(3)
        let b = a
        let removed = a.remove(at: 0)
        #expect(removed == 1)
        let aCount = a.count
        let bCount = b.count
        #expect(aCount == Index<Int>.Count(2))
        #expect(bCount == Index<Int>.Count(3))
        let a0 = a[0]
        let b0 = b[0]
        #expect(a0 == 2)
        #expect(b0 == 1)
    }

    @Test
    func `swap exchanges elements in place`() {
        var a = MoveArray<Int>(initialCapacity: 3)
        a.append(1)
        a.append(2)
        a.append(3)
        a.swap(at: 0, with: 2)
        let e0 = a[0]
        let e2 = a[2]
        #expect(e0 == 3)
        #expect(e2 == 1)
        a.swap(at: 1, with: 1)  // same-index no-op
        let e1 = a[1]
        #expect(e1 == 2)
    }

    @Test
    func `drain consumes front-to-back and empties the array`() {
        var a = MoveArray<Int>(initialCapacity: 3)
        a.append(7)
        a.append(8)
        a.append(9)
        var seen: [Int] = []
        a.drain { seen.append($0) }
        #expect(seen == [7, 8, 9])
        let isEmpty = a.isEmpty
        #expect(isEmpty)
    }

    @Test
    func `drain on a shared column detaches from siblings first`() {
        var a = CoWArray<Int>(initialCapacity: 2)
        a.append(5)
        a.append(6)
        let b = a
        var seen: [Int] = []
        a.drain { seen.append($0) }
        #expect(seen == [5, 6])
        let aEmpty = a.isEmpty
        let bCount = b.count
        #expect(aEmpty)
        #expect(bCount == Index<Int>.Count(2))  // the gate cloned before draining
    }

    @Test
    func `removeAll on both columns; keepingCapacity preserves slots`() {
        var a = MoveArray<Int>(initialCapacity: 4)
        a.append(1)
        a.append(2)
        a.removeAll(keepingCapacity: true)
        let aEmpty = a.isEmpty
        #expect(aEmpty)
        let aCapacityKept = a.capacity >= Index<Int>.Count(4)
        #expect(aCapacityKept)

        var c = CoWArray<Int>(initialCapacity: 4)
        c.append(1)
        let d = c
        c.removeAll()
        let cEmpty = c.isEmpty
        let dCount = d.count
        #expect(cEmpty)
        #expect(dCount == Index<Int>.Count(1))  // detach, not drain: sibling intact
    }

    // MARK: - Move-only elements (direct column end-to-end)

    @Test
    func `move-only elements append, mutate via withElement, and tear down once`() {
        Probe.reset()
        do {
            var a = MoveArray<Item>(initialCapacity: 2)
            a.append(Item(1, value: 10))
            a.append(Item(2, value: 20))
            let v = a.withElement(at: 1) { $0.value }
            #expect(v == 20)
            guard let taken = a.pop() else {
                Issue.record("pop returned nil on a non-empty array")
                return
            }
            let tid = taken.id
            #expect(tid == 2)
            _ = consume taken
            let mid = Probe.destroyedSorted
            #expect(mid == [2])
        }
        let ds = Probe.destroyedSorted
        #expect(ds == [1, 2])  // the remaining element died with the array
    }

    // MARK: - Cloning

    @Test
    func `generic clone always detaches the CoW column`() {
        var a = CoWArray<Int>(initialCapacity: 2)
        a.append(1)
        a.append(2)
        var c = a.clone()
        c[0] = 99
        let a0 = a[0]
        let c0 = c[0]
        #expect(a0 == 1)
        #expect(c0 == 99)
    }

    @Test
    func `pinned clone copies the direct column into fresh storage`() {
        var a = MoveArray<Int>(initialCapacity: 2)
        a.append(4)
        a.append(5)
        var c = a.clone()
        c[0] = 40
        let a0 = a[0]
        let c0 = c[0]
        #expect(a0 == 4)
        #expect(c0 == 40)
        let cCount = c.count
        #expect(cCount == Index<Int>.Count(2))
    }

    // MARK: - Capacity ops (both columns)

    @Test
    func `reserveCapacity and reallocate on both columns`() {
        var a = MoveArray<Int>(initialCapacity: 1)
        a.append(1)
        a.reserveCapacity(Index<Int>.Count(8))
        let aCapacityOK = a.capacity >= Index<Int>.Count(8)
        #expect(aCapacityOK)
        a.reallocate(capacity: Index<Int>.Count(1))
        let aCapacityShrunk = a.capacity
        #expect(aCapacityShrunk == Index<Int>.Count(1))
        let kept = a[0]
        #expect(kept == 1)

        var c = CoWArray<Int>(initialCapacity: 1)
        c.append(2)
        let sibling = c
        c.reserveCapacity(Index<Int>.Count(8))  // uniquely, behind the gate
        let cCapacityOK = c.capacity >= Index<Int>.Count(8)
        #expect(cCapacityOK)
        let siblingValue = sibling[0]
        #expect(siblingValue == 2)
    }

    // MARK: - Spans

    @Test
    func `direct column vends span (Span.Protocol witness) and mutableSpan`() {
        var a = MoveArray<Int>(initialCapacity: 3)
        a.append(1)
        a.append(2)
        a.append(3)
        var sum = 0
        do {
            let span = a.span
            for i in 0..<span.count { sum += span[i] }
        }
        #expect(sum == 6)
        do {
            var m = a.mutableSpan()
            m[0] = 10
        }
        let e0 = a[0]
        #expect(e0 == 10)
    }

    @Test
    func `shared column scoped spans; mutable restores uniqueness first`() {
        var a = CoWArray<Int>(initialCapacity: 3)
        a.append(1)
        a.append(2)
        let b = a
        let sum = a.withSpan { span in
            var acc = 0
            for i in 0..<span.count { acc += span[i] }
            return acc
        }
        #expect(sum == 3)
        a.withMutableSpan { span in
            span[0] = 100
        }
        let aSees = a[0]
        let bSees = b[0]
        #expect(aSees == 100)
        #expect(bSees == 1)
    }

    // MARK: - Element-keyed semantics (the S5 chain through the Shared carrier)

    @Test
    func `Equatable and Hashable chain through the column`() {
        var a = CoWArray<Int>(initialCapacity: 4)
        a.append(1)
        a.append(2)
        var b = CoWArray<Int>(initialCapacity: 8)
        b.append(1)
        b.append(2)
        #expect(a == b)  // element-wise, capacity-independent
        b.append(3)
        #expect(a != b)
        var h1 = Hasher()
        var h2 = Hasher()
        a.hash(into: &h1)
        var a2 = a
        a2[0] = 1  // forces divergence (same elements)
        a2.hash(into: &h2)
        #expect(h1.finalize() == h2.finalize())
    }

    // MARK: - Collection lattice (direct column: Array.Protocol defaults over the span bridge)

    @Test
    func `index navigation defaults walk the direct column`() {
        var a = MoveArray<Int>(initialCapacity: 3)
        a.append(10)
        a.append(20)
        a.append(30)
        let start = a.startIndex
        let end = a.endIndex
        var walked: [Int] = []
        var i = start
        while i < end {
            walked.append(a[i])
            i = a.index(after: i)
        }
        #expect(walked == [10, 20, 30])
        let back = a.index(before: end)
        let lastValue = a[back]
        #expect(lastValue == 30)
    }

    // MARK: - The Audit-#5 relaxation (move-only elements reach the lattice)

    @Test
    func `move-only elements reach the span-bridged lattice`() {
        Probe.reset()
        do {
            var a = MoveArray<Item>(initialCapacity: 3)
            a.append(Item(1, value: 10))
            a.append(Item(2, value: 20))
            a.append(Item(3, value: 30))
            let total = latticeSum(a)  // generic Collection.Protocol dispatch
            #expect(total == 60)
            var walked = 0
            a.forEach { walked += $0.value }  // Iterable terminal over the span bridge
            #expect(walked == 60)
        }
        let ds = Probe.destroyedSorted
        #expect(ds == [1, 2, 3])  // borrowing reads moved nothing out
    }

    // MARK: - OutputSpan construction lanes (direct column)

    @Test
    func `OutputSpan init, windowed append, and edit on the direct column`() {
        var a = MoveArray<Int>(capacity: Index<Int>.Count(3)) { span in
            span.append(1)
            span.append(2)
        }
        let count = a.count
        #expect(count == Index<Int>.Count(2))  // no full-population requirement
        a.append(addingCapacity: Index<Int>.Count(2)) { span in
            span.append(3)
        }
        let count2 = a.count
        #expect(count2 == Index<Int>.Count(3))
        let total: Int = a.edit { span in
            var acc = 0
            for i in 0..<span.count { acc += span[i] }
            return acc
        }
        #expect(total == 6)
    }

    // MARK: - take() (column extraction) + Sequenceable chain

    @Test
    func `take unwraps the column; Sequenceable consumes through it`() {
        var a = MoveArray<Int>(initialCapacity: 2)
        a.append(1)
        a.append(2)
        let column = a.take()
        let columnCount = column.count
        #expect(columnCount == Index<Int>.Count(2))

        var b = MoveArray<Int>(initialCapacity: 2)
        b.append(7)
        b.append(8)
        var it = b.makeIterator()  // consuming, via the S chain
        var seen: [Int] = []
        while let x = it.next() { seen.append(x) }
        #expect(seen == [7, 8])
    }

    // MARK: - Sendable chain smoke

    @Test
    func `sendable composes through both columns`() {
        let a = MoveArray<Int>(initialCapacity: 1)
        requireSendable(a)
        let b = CoWArray<Int>(initialCapacity: 1)
        requireSendable(b)
        #expect(Bool(true))
    }
}

private func requireSendable<T: Sendable & ~Copyable>(_ value: borrowing T) {}
