@_spi(Unsafe) import Array_Primitives
import Buffer_Primitives_Test_Support
import Buffer_Primitive
import Buffer_Linear_Primitive
import Buffer_Linear_Bounded_Primitives
import Storage_Contiguous_Primitives
import Memory_Heap_Primitives
import Memory_Allocator_Primitive
import Shared_Primitive
import Index_Primitives
import Tagged_Primitives_Standard_Library_Integration
import Ordinal_Primitives_Standard_Library_Integration
import Testing

// The W4 audit backfill: the seam-ledger laws on both ratified columns, and the
// surface gaps the column-keyed core suite left open.

private typealias HeapColumn<E: ~Copyable> =
    Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear

private typealias SharedColumn<E: ~Copyable> = Shared<E, HeapColumn<E>>
private typealias MoveArray<E: ~Copyable> = Array<HeapColumn<E>>

private typealias BoundedHeapColumn<E: ~Copyable> =
    Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear.Bounded

private typealias FixedArray<E: ~Copyable> = Fixed<BoundedHeapColumn<E>>
private typealias CoWArray<E: ~Copyable> = Array<SharedColumn<E>>

// MARK: - The seam-ledger laws (audit #2): both columns must be lawful

@Suite
struct ArraySeamLawTests {

    @Test
    func `the direct heap column obeys the seam ledger laws`() {
        let violations = Seam.Ledger.violations(
            makeEmpty: { HeapColumn<Int>(minimumCapacity: Index<Int>.Count(4)) },
            element: { $0 }
        )
        #expect(violations.isEmpty, "\(violations)")
    }

    @Test
    func `the Shared CoW column obeys the seam ledger laws`() {
        let violations = Seam.Ledger.violations(
            makeEmpty: { SharedColumn<Int>(HeapColumn<Int>(minimumCapacity: Index<Int>.Count(4))) },
            element: { $0 }
        )
        #expect(violations.isEmpty, "\(violations)")
    }
}

// MARK: - Surface backfill (audit #4)

@Suite(.serialized)
struct ArraySurfaceTests {

    @Test
    func `element(at:offsetBy:) resolves valid offsets and rejects out-of-bounds`() {
        var a = MoveArray<Int>(initialCapacity: 3)
        a.append(10)
        a.append(20)
        a.append(30)
        let base: MoveArray<Int>.Index = 0
        let plusTwo = a.element(at: base, offsetBy: 2)
        #expect(plusTwo == 30)
        let beyond = a.element(at: base, offsetBy: 3)
        #expect(beyond == nil)
        let fromMiddle: MoveArray<Int>.Index = 1
        let backOne = a.element(at: fromMiddle, offsetBy: -1)
        #expect(backOne == 10)
    }

    @Test
    func `the SPI pointer lane reads the direct column`() {
        var a = MoveArray<Int>(initialCapacity: 3)
        a.append(1)
        a.append(2)
        a.append(3)
        let sum = unsafe a.withUnsafeBufferPointer { buffer in
            unsafe buffer.reduce(0, +)
        }
        #expect(sum == 6)
    }

    @Test
    func `growth from zero capacity is sound on both columns`() {
        var a = MoveArray<Int>(initialCapacity: .zero)
        a.append(1)
        a.append(2)
        a.append(3)
        let aCount = a.count
        #expect(aCount == Index<Int>.Count(3))
        let aLast = a[2]
        #expect(aLast == 3)

        var c = CoWArray<Int>(initialCapacity: .zero)
        c.append(7)
        c.append(8)
        let cCount = c.count
        #expect(cCount == Index<Int>.Count(2))
        let c0 = c[0]
        #expect(c0 == 7)
    }

    @Test
    func `take then rewrap preserves contents`() {
        var a = MoveArray<Int>(initialCapacity: 2)
        a.append(4)
        a.append(5)
        let column = a.take()
        let b = Array(store: column)
        let bCount = b.count
        #expect(bCount == Index<Int>.Count(2))
        let b1 = b[1]
        #expect(b1 == 5)
    }

    @Test
    func `equal CoW arrays hash equal; unequal lengths compare unequal`() {
        var a = CoWArray<Int>(initialCapacity: 2)
        a.append(1)
        var b = CoWArray<Int>(initialCapacity: 4)
        b.append(1)
        #expect(a == b)
        var ha = Hasher(), hb = Hasher()
        a.hash(into: &ha)
        b.hash(into: &hb)
        #expect(ha.finalize() == hb.finalize())
        b.append(2)
        #expect(a != b)                              // length-discriminating
        let prefixSame = (a[0] == b[0])
        #expect(prefixSame)
    }
}

// MARK: - Fixed: span-keyed institute conformances (audit #4)

@Suite
struct ArrayFixedSemanticsTests {

    @Test
    func `Fixed equality and hashing are span-keyed and capacity-independent`() throws {
        let f1 = try FixedArray<Int>(count: Index<Int>.Count(3)) { _ in 7 }
        let f2 = try FixedArray<Int>(count: Index<Int>.Count(3)) { _ in 7 }
        let equal = (f1 == f2)                       // Equation.Protocol over the span
        #expect(equal)
        var h1 = Hasher(), h2 = Hasher()
        f1.hash(into: &h1)
        f2.hash(into: &h2)
        #expect(h1.finalize() == h2.finalize())      // Hash.Protocol over the span

        var f3 = try FixedArray<Int>(count: Index<Int>.Count(3)) { _ in 7 }
        f3[1] = 8
        let diverged = (f1 != f3)
        #expect(diverged)
    }
}
