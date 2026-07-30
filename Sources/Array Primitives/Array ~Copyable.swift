// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// The COLUMN-GENERIC surface of the base Array: everything expressible through the
// seam (`Store.Protocol`: subscript/initialize/move/capacity + the `unshare()`
// gate) and the count surface (`Buffer.Protocol`) lives here ONCE, for every column.
// Semantic mutations call the gate before their first write, so the same generic body
// is copy-on-write-correct on the `Shared` column and free on the move-only columns.
// Only GROWTH and CONSTRUCTION pin per column (`Array+Columns.swift`).
public import Array_Primitive
public import Array_Protocol_Primitives
public import Buffer_Protocol_Primitives
public import Span_Protocol_Primitives
public import Store_Protocol_Primitives

// ============================================================================
// MARK: - Collection Conformances (the span-bridged lattice)
// ============================================================================
//
// `Collection.Protocol` refines `Iterable`, whose multipass borrowing iterator is
// vended by the memory→Iterable bridge over `Span.Protocol` — so the lattice holds
// exactly where the COLUMN vends a span (`S: Span.Protocol`). Since
// shared-primitives c27eaa7 (the W5 lifetime-laundered span) that includes the
// `Shared` column — the CoW ADTs ride the same lattice as the direct columns.
//
// NO element bound (Audit-#5 relaxation, W5-1): the lattice protocols admit
// `~Copyable` elements and every witness reads borrowing (`_read`/`borrowing get` —
// the R2 probe verified borrow-through-call over move-only elements debug + -O).
// Element-RETURNING conveniences stay `S.Element: Copyable`-gated in their own
// extensions.

// The Collection lattice conformances restate the SEAM bound (`Store.Protocol &
// Buffer.Protocol` + the element-domain count constraint) alongside `Span.Protocol`:
// without it, `count`/`Index`/subscript would silently resolve to the Span-gated
// protocol defaults instead of the seam-bound witnesses (a recurring silent break
// observed across the W1 clusters). Matching the conformance condition to what the
// witnesses require keeps the real O(1) `count` and the typed `Index` in play.

// MARK: Collection.Protocol

extension __Array: Collection.`Protocol`
where S: Span.`Protocol` & Store.`Protocol` & Buffer.`Protocol` & ~Copyable {}

// MARK: Collection.Bidirectional

extension __Array: Collection.Bidirectional
where S: Span.`Protocol` & Store.`Protocol` & Buffer.`Protocol` & ~Copyable {}

// MARK: Indexable (top-level capability protocol; `__ArrayProtocol` is a compatibility
// alias — `Array` is a generic front-door typealias and has no nested `Array.Protocol`
// spelling to conform through)

extension __Array: __ArrayProtocol
where S: Span.`Protocol` & Store.`Protocol` & Buffer.`Protocol` & ~Copyable {}

// ============================================================================
// MARK: - Properties (generic: Buffer.Protocol count + seam capacity)
// ============================================================================

extension __Array where S: ~Copyable, S: Store.`Protocol` & Buffer.`Protocol` {
    /// The number of elements in the array.
    @inlinable
    public var count: Index.Count {
        store.count
    }

    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { store.isEmpty }

    /// The current capacity of the array.
    @inlinable
    public var capacity: Index.Count { store.capacity }

    /// The number of additional elements that can be added without reallocating.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var freeCapacity: Index.Count {
        store.capacity.subtract.saturating(store.count)
    }
}

// ============================================================================
// MARK: - Element Access (generic: the seam subscript)
// ============================================================================

extension __Array where S: ~Copyable, S: Store.`Protocol` & Buffer.`Protocol` {
    /// Accesses the element at the given typed index.
    ///
    /// The mutating access runs the column's semantic mutation gate FIRST
    /// (`unshare()`), so in-place writes are copy-on-write-correct on the
    /// `Shared` column and free on the statically-unique columns.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(_ index: Index) -> S.Element {
        _read {
            precondition(index < count, "Index out of bounds")
            yield store[index]
        }
        _modify {
            precondition(index < count, "Index out of bounds")
            store.unshare()
            yield &store[index]
        }
    }

    /// Accesses the element at the given index via closure (for ~Copyable elements).
    ///
    /// - Precondition: The index must be in bounds.
    @inlinable
    public func withElement<R>(at index: Index, _ body: (borrowing S.Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return body(store[index])
    }
}

extension __Array
where
    S: ~Copyable,
    S.Element: Copyable,
    S: Store.`Protocol` & Buffer.`Protocol`
{
    /// Returns the element at the typed index, or nil if out of bounds.
    @inlinable
    public func element(at index: Index) -> S.Element? {
        guard index < count else { return nil }
        return store[index]
    }

    /// Returns element at index offset from given base index.
    @inlinable
    public func element(
        at base: Index,
        offsetBy offset: Index.Offset
    ) -> S.Element? {
        let newIndex: Index
        do throws(Ordinal.Error) {
            newIndex = try base + offset
        } catch {
            return nil
        }
        guard newIndex < count else { return nil }
        return store[newIndex]
    }
}

// ============================================================================
// MARK: - Mutating Operations (generic: gate + seam)
// ============================================================================

extension __Array where S: ~Copyable, S: Store.`Protocol` & Buffer.`Protocol` {
    /// Removes and returns the last element, or `nil` if the array is empty.
    ///
    /// Returns `Element?` — the tower-wide remove-from-empty convention
    /// ([API-NAME-008]; adt-tower.md §4.7, §9.3 — the landed `Queue.dequeue()`
    /// model). The empty check returns `nil` BEFORE `unshare()`, so gating
    /// happens only on the non-empty path (an empty array is never detached).
    /// Consuming an `Element?` is available even for `~Copyable` elements
    /// (unlike a borrow).
    ///
    /// - Complexity: O(1)
    @inlinable
    public mutating func pop() -> S.Element? {
        if isEmpty { return nil }
        store.unshare()
        let end: Index = count.map(Ordinal.init)
        // WHY: isEmpty returned false above, so count ≥ 1 and end ≥ 1 — predecessor
        // is always in-bounds.
        // swift-format-ignore: NeverUseForceTry
        // swiftlint:disable:next force_try
        let last = try! end.predecessor.exact()
        return store.move(at: last)
    }

    /// Removes and returns the element at the given index, shifting subsequent elements left.
    ///
    /// - Parameter index: The index of the element to remove.
    /// - Returns: The removed element.
    /// - Precondition: The index must be in bounds.
    /// - Complexity: O(n) where n is the distance from `index` to the end.
    @inlinable
    public mutating func remove(at index: Index) -> S.Element {
        precondition(index < count, "Index out of bounds")
        store.unshare()
        return _removeShiftingDown(at: index)
    }

    /// Removes the element at `position`, shifting every later element down one slot, and
    /// hands the removed element back.
    ///
    /// ## Why a backward CARRY SWEEP and not `move` + `initialize`
    ///
    /// The seam's 4-op discipline (`Buffer.Linear+Store.Protocol`) is *trailing-only*:
    /// `initialize(at:to:)` only appends at `slot == count`, and `move(at:)` only retracts
    /// at `slot == count.subtract.saturating(.one)` — both mirror the header cursor with the ledger's own
    /// arithmetic. An interior `move(at:)` (any `index` other than the trailing slot)
    /// violates that contract; in `-Onone` it trips the buffer's `precondition`, and in
    /// `-O` the same `precondition` lowers to `Builtin.condfail_message` — a bare `ud2`
    /// (SIGILL) with no diagnostic (swift-primitives/swift-array-primitives#8; identical
    /// class fixed in swift-primitives/swift-hash-table-primitives#4). The prior
    /// implementation opened this removal with `store.move(at: index)`, so every interior
    /// removal (`index < count.subtract.saturating(.one)`) trapped under `-O`.
    ///
    /// The lawful shape uses only the two ops the seam actually grants at an interior
    /// slot: the *live-slot subscript* (which never touches the ledger) and a *single*
    /// trailing retraction. So:
    ///
    ///   1. Pop the trailing element into a carry — the one lawful ledger move.
    ///   2. Walk the carry DOWN to `position`, exchanging it with one live slot at a time.
    ///      Slot `i` receives what slot `i + 1` held, and the carry picks up slot `i`.
    ///   3. When the walk reaches `position`, the carry holds the element that was there —
    ///      the removed element — and every later element sits one slot lower.
    ///
    /// Every slot stays initialized for the whole sweep, the ledger moves exactly once,
    /// and nothing is copied — which is what makes it correct for `~Copyable` elements too.
    ///
    /// - Precondition: `position < count`; the caller already ran `unshare()`.
    /// - Complexity: O(`count` − `position`)
    @inlinable
    package mutating func _removeShiftingDown(at position: Index) -> S.Element {
        var frontier: Index.Count = count.subtract.saturating(.one)
        var carry = store.move(at: frontier.map(Ordinal.init))
        while position < frontier.map(Ordinal.init) {
            frontier = frontier.subtract.saturating(.one)
            let slot: Index = frontier.map(Ordinal.init)
            Swift.swap(&carry, &store[slot])
        }
        return carry
    }

    /// Exchanges the elements at the two given positions.
    ///
    /// Passing the same index for both has no effect.
    ///
    /// - Precondition: Both indices must be in bounds.
    /// - Complexity: O(1)
    @inlinable
    public mutating func swap(at i: Index, with j: Index) {
        precondition(i < count && j < count, "Index out of bounds")
        guard i != j else { return }
        store.unshare()
        store.swapAt(i, j)
    }

    /// Consumes every element front-to-back, leaving the array empty.
    ///
    /// ## Why REVERSE-then-POP and not a forward `move(at:)` walk
    ///
    /// The prior implementation walked `move(at:)` forward from `.zero` — the same
    /// unlawful interior-move class fixed in `_removeShiftingDown` (the seam's
    /// `Buffer.Linear` conformance only grants `move(at:)` at the trailing slot,
    /// `slot == count.subtract.saturating(.one)`); every element before the last one trapped under `-O`
    /// (swift-primitives/swift-array-primitives#3).
    ///
    /// The lawful shape uses only what the seam actually grants at an interior slot
    /// pair — `swapAt(_:_:)`, unrestricted (`Buffer.Linear+Store.Protocol.swift`
    /// forwards it straight to the underlying storage, bypassing the trailing-only
    /// `move`/`initialize` discipline) — plus trailing-only `move(at:)`:
    ///
    ///   1. Reverse the live region in place using only `swapAt` (two-pointer,
    ///      closing from both ends).
    ///   2. Pop from the trailing slot repeatedly (the one lawful ledger retraction).
    ///      Since the region is now reversed, popping the tail yields the elements
    ///      in their ORIGINAL front-to-back order.
    ///
    /// Every slot stays initialized throughout, nothing is copied, and the ledger
    /// only ever moves at the trailing slot — which is what makes it correct for
    /// `~Copyable` elements too.
    @inlinable
    public mutating func drain(_ body: (consuming S.Element) -> Void) {
        store.unshare()

        var low: Index = .zero
        var high: Index.Count = count.subtract.saturating(.one)
        while low < high.map(Ordinal.init) {
            store.swapAt(low, high.map(Ordinal.init))
            low = low.successor.saturating()
            high = high.subtract.saturating(.one)
        }

        while !isEmpty {
            let end: Index = count.map(Ordinal.init)
            // WHY: the loop guard above guarantees count ≥ 1, so end ≥ 1 and
            // predecessor is always in-bounds.
            // swift-format-ignore: NeverUseForceTry
            // swiftlint:disable:next force_try
            let last = try! end.predecessor.exact()
            body(store.move(at: last))
        }
    }
}

// ============================================================================
// MARK: - Cloning (generic on the CoW column)
// ============================================================================

extension __Array where S: Copyable, S: Store.`Protocol` {
    /// Returns an independent copy of this array with its own storage.
    ///
    /// On the `Shared` (CoW) column the fresh value shares the box with `self` at the
    /// moment of copy, so running the mutation gate on it ALWAYS installs a deep copy —
    /// `clone()` never returns shared storage.
    ///
    /// - Complexity: O(`count`)
    @inlinable
    public borrowing func clone() -> Self {
        var result = copy self
        result.store.unshare()
        return result
    }
}
