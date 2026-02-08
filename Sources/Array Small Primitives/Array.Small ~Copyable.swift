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

public import Array_Primitives_Core
public import Collection_Primitives
public import Index_Primitives
public import Ordinal_Primitives
public import Property_Primitives
public import Vector_Primitives
public import Sequence_Primitives

// ============================================================================
// MARK: - Collection Conformances
// ============================================================================

// MARK: Collection.Indexed

extension Array.Small: Collection.Indexed where Element: ~Copyable {
    public typealias Index = Array<Element>.Index

    @inlinable
    public var startIndex: Index { .zero }

    @inlinable
    public var endIndex: Index { count.map(Ordinal.init) }

    @inlinable
    public func index(after i: Index) -> Index { i + .one }
}

// MARK: Collection.Bidirectional

extension Array.Small: Collection.Bidirectional where Element: ~Copyable {
    @inlinable
    public func index(before i: Index) -> Index { try! i - .one }
}

// Note: Array.Small cannot conform to Swift.Collection because it is unconditionally
// ~Copyable (has deinit for inline storage cleanup). Swift.Collection requires Self: Copyable.

// ============================================================================
// MARK: - Properties
// ============================================================================

extension Array.Small where Element: ~Copyable {
    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { count == .zero }

    /// The current capacity of the array.
    @inlinable
    public var capacity: Int {
        if let heap {
            return heap.storage.capacity
        }
        return inlineCapacity
    }

    /// Whether the array is currently using heap storage.
    @inlinable
    public var isSpilled: Bool { heap != nil }
}

// ============================================================================
// MARK: - Subscripts
// ============================================================================

// MARK: Index Subscript

extension Array.Small where Element: ~Copyable {
    /// Accesses the element at the given typed index (borrowing access for ~Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Index) -> Element {
        mutating _read {
            precondition(index < count, "Index out of bounds")
            if let heap {
                yield unsafe heap.pointer[Int(bitPattern: index)]
            } else {
                yield _inlineBuffer[index]
            }
        }
        _modify {
            precondition(index < count, "Index out of bounds")
            if let heap {
                var ptr = unsafe heap.pointer
                yield &(unsafe ptr[index])
            } else {
                yield &_inlineBuffer[index]
            }
        }
    }
}

// ============================================================================
// MARK: - Element Access
// ============================================================================

extension Array.Small where Element: ~Copyable {
    /// Accesses the element at the given index via closure (for ~Copyable elements).
    @inlinable
    public func withElement<R>(at index: Index, _ body: (borrowing Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        if let heap {
            return body(unsafe heap.pointer[Int(bitPattern: index)])
        } else {
            return body(_inlineBuffer[index])
        }
    }
}

// ============================================================================
// MARK: - Mutating Operations
// ============================================================================

extension Array.Small where Element: ~Copyable {
    /// Spills inline storage to heap.
    ///
    /// Called when appending would exceed inline capacity.
    /// Moves all inline elements to newly allocated heap storage.
    @usableFromInline
    package mutating func spill(minimumCapacity: Array.Index.Count) {
        precondition(heap == nil, "Already spilled")

        let newStorage = Heap.create(minimumCapacity: minimumCapacity)
        // Move elements from inline buffer to heap storage
        for i in 0..<Int(bitPattern: count) {
            let slot = Index_Primitives.Index<Element>(Ordinal(UInt(i)))
            let element = _inlineBuffer.consumeFront()
            newStorage.initialize(to: element, at: slot)
        }
        newStorage.initialization = .linear(count: count)
        var newHeap = Heap(newStorage)
        newHeap.header.count = count
        heap = newHeap
    }

    /// Appends an element to the array.
    @inlinable
    public mutating func append(_ element: consuming Element) {
        if var heapState = heap {
            // Heap mode
            let currentCount = heapState.header.count
            heapState.ensureCapacity(currentCount + .one)
            let slot = currentCount.map(Ordinal.init)
            heapState.storage.initialize(to: consume element, at: slot)
            heapState.header.count = currentCount + .one
            self.heap = heapState
            count = count + .one
        } else if Int(bitPattern: count) < inlineCapacity {
            // Inline mode with room
            _ = _inlineBuffer.append(element)
            count = count + .one
        } else {
            // Need to spill
            spill(minimumCapacity: count + .one)
            var heapState = heap!
            let slot = heapState.header.count.map(Ordinal.init)
            heapState.storage.initialize(to: consume element, at: slot)
            heapState.header.count = heapState.header.count + .one
            heap = heapState
            count = count + .one
        }
    }

    /// Removes and returns the last element.
    @inlinable
    public mutating func removeLast() -> Element? {
        guard count > .zero else { return nil }

        let newCountRaw = count.rawValue.rawValue &- 1
        let newCount = Index.Count(Cardinal(newCountRaw))
        let lastSlot = Index_Primitives.Index<Element>(Ordinal(newCountRaw))

        if var heapState = heap {
            heapState.header.count = newCount
            self.heap = heapState
            count = newCount
            return heapState.storage.move(at: lastSlot)
        } else {
            // Inline mode
            count = newCount
            return _inlineBuffer.removeLast()
        }
    }

    /// Removes all elements from the array.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool = false) {
        guard count > .zero else { return }

        if let heap {
            // Sync initialization before deinitializing (storage may be stale)
            heap.storage.initialization = .linear(count: count)
            heap.storage.deinitialize()
            if !keepingCapacity {
                self.heap = nil
            } else {
                var heapState = heap
                heapState.header.count = .zero
                self.heap = heapState
            }
        } else {
            _inlineBuffer.removeAll()
        }
        count = .zero
    }
}

// ============================================================================
// MARK: - Span Access
// ============================================================================

extension Array.Small where Element: ~Copyable {
    /// Provides read-only span access to the array elements.
    @inlinable
    public func withSpan<R, E: Swift.Error>(
        _ body: (Swift.Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        let n = Int(bitPattern: count.rawValue.rawValue)
        if n > 0 {
            if let heap {
                let span = unsafe Swift.Span(_unsafeStart: UnsafePointer(heap.pointer), count: n)
                return try body(span)
            } else {
                return try body(_inlineBuffer.span)
            }
        } else {
            let span = unsafe Swift.Span(_unsafeStart: UnsafePointer<Element>(bitPattern: 1)!, count: 0)
            return try body(span)
        }
    }

    /// Provides mutable span access to the array elements.
    @inlinable
    public mutating func withMutableSpan<R, E: Swift.Error>(
        _ body: (borrowing MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        let n = Int(bitPattern: count.rawValue.rawValue)
        if n > 0 {
            if let heap {
                let span = unsafe MutableSpan(_unsafeStart: heap.pointer, count: n)
                return try body(span)
            } else {
                return try body(_inlineBuffer.mutableSpan)
            }
        } else {
            let span = unsafe MutableSpan(_unsafeStart: UnsafeMutablePointer<Element>(bitPattern: 1)!, count: 0)
            return try body(span)
        }
    }
}

// ============================================================================
// MARK: - Buffer Access
// ============================================================================

@_spi(Unsafe)
extension Array.Small where Element: Copyable {
    /// Provides read-only access to the underlying contiguous storage.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        let n = Int(bitPattern: count.rawValue.rawValue)
        if n > 0 {
            if let heap {
                return try unsafe body(UnsafeBufferPointer(start: UnsafePointer(heap.pointer), count: n))
            } else {
                return try _inlineBuffer.withUnsafeBufferPointer(body)
            }
        } else {
            return try unsafe body(UnsafeBufferPointer(start: nil, count: 0))
        }
    }

    /// Provides mutable access to the underlying contiguous storage.
    @unsafe
    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        let n = Int(bitPattern: count.rawValue.rawValue)
        if n > 0 {
            if let heap {
                return try unsafe body(UnsafeMutableBufferPointer(start: heap.pointer, count: n))
            } else {
                return try _inlineBuffer.withUnsafeMutableBufferPointer(body)
            }
        } else {
            return try unsafe body(UnsafeMutableBufferPointer(start: nil, count: 0))
        }
    }
}

// ============================================================================
// MARK: - Property Views
// ============================================================================

// MARK: ForEach Property View

extension Array.Small where Element: ~Copyable {
    /// Property view for iteration operations.
    @inlinable
    public var forEach: Property<Sequence.ForEach, Self>.View.Typed<Element>.Valued<inlineCapacity> {
        mutating _read {
            yield unsafe Property<Sequence.ForEach, Self>.View.Typed<Element>.Valued<inlineCapacity>(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.ForEach, Self>.View.Typed<Element>.Valued<inlineCapacity>(&self)
            yield &view
        }
    }
}

// MARK: ForEach: Borrowing Operations (~Copyable)

extension Property.View.Typed.Valued
where Tag == Sequence.ForEach, Base == Array<Element>.Small<n>, Element: ~Copyable {
    /// Borrowing iteration: `.forEach { }`
    @inlinable
    public func callAsFunction(_ body: (borrowing Element) -> Void) {
        let count = unsafe base.pointee.count
        guard count > .zero else { return }

        if let heapState = unsafe base.pointee.heap {
            for i in 0..<Int(bitPattern: count.rawValue.rawValue) {
                unsafe body(heapState.pointer[i])
            }
        } else {
            for i in 0..<Int(bitPattern: count.rawValue.rawValue) {
                let slot = Index_Primitives.Index<Element>(Ordinal(UInt(i)))
                body(unsafe base.pointee._inlineBuffer[slot])
            }
        }
    }

    /// Explicit borrowing iteration: `.forEach.borrowing { }`
    @inlinable
    public func borrowing(_ body: (borrowing Element) -> Void) {
        callAsFunction(body)
    }
}

// MARK: Drain Property View

extension Array.Small where Element: ~Copyable {
    /// Property view for draining operations.
    @inlinable
    public var drain: Property<Sequence.Drain, Self>.View.Typed<Element>.Valued<inlineCapacity> {
        mutating _read {
            yield unsafe Property<Sequence.Drain, Self>.View.Typed<Element>.Valued<inlineCapacity>(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain, Self>.View.Typed<Element>.Valued<inlineCapacity>(&self)
            yield &view
        }
    }
}

// MARK: Drain: Operations (~Copyable)

extension Property.View.Typed.Valued
where Tag == Sequence.Drain, Base == Array<Element>.Small<n>, Element: ~Copyable {
    /// Drain iteration: `.drain { }`
    @_lifetime(&self)
    @inlinable
    public mutating func callAsFunction(_ body: (consuming Element) -> Void) {
        let count = unsafe base.pointee.count
        guard count > .zero else { return }

        if let heapState = unsafe base.pointee.heap {
            for i in 0..<Int(bitPattern: count.rawValue.rawValue) {
                unsafe body((heapState.pointer + i).move())
            }
            heapState.storage.initialization = .empty
            var updatedHeap = heapState
            updatedHeap.header.count = .zero
            unsafe base.pointee.heap = updatedHeap
        } else {
            while unsafe !base.pointee._inlineBuffer.isEmpty {
                body(unsafe base.pointee._inlineBuffer.consumeFront())
            }
        }
        unsafe base.pointee.count = .zero
    }
}
