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
public import Range_Primitives
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
    public var endIndex: Index { Index(count) }

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
            return unsafe heap.storage.withUnsafeMutablePointerToElements { elements in
                body(unsafe (elements + index).pointee)
            }
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
        newStorage.header = count.rawValue
        heap = Heap(newStorage)
    }

    /// Appends an element to the array.
    @inlinable
    public mutating func append(_ element: consuming Element) {
        if var heap {
            // Heap mode
            let currentCount: Array.Index.Count = .init(__unchecked: heap.storage.header)
            heap.ensureCapacity(currentCount + .one)
            self.heap = heap
            heap.storage.initialize(to: element, at: Index(currentCount))
            heap.storage.header = currentCount.rawValue + 1
            count = count + .one
        } else if count.rawValue < inlineCapacity {
            // Inline mode with room
            _ = _inlineBuffer.append(element)
            count = count + .one
        } else {
            // Need to spill
            spill(minimumCapacity: count + .one)
            heap!.storage.initialize(to: element, at: Index(count))
            heap!.storage.header = count.rawValue + 1
            count = count + .one
        }
    }

    /// Removes and returns the last element.
    @inlinable
    public mutating func removeLast() -> Element? {
        guard count.rawValue > 0 else { return nil }

        if let heap {
            guard let newCount = count - .one else { return nil }
            self.heap?.storage.header = newCount.rawValue
            count = newCount
            return heap.storage.move(at: Index(newCount))
        } else {
            // Inline mode
            guard !_inlineBuffer.isEmpty else { return nil }
            count = count - .one
            return _inlineBuffer.removeLast()
        }
    }

    /// Removes all elements from the array.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool = false) {
        guard count.rawValue > 0 else { return }

        if let heap {
            heap.storage.deinitialize()
            if !keepingCapacity {
                self.heap = nil
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
        if count.rawValue > 0 {
            if let heap {
                let span = unsafe Swift.Span(_unsafeStart: heap.pointer, count: count.rawValue)
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
        if count.rawValue > 0 {
            if let heap {
                let span = unsafe MutableSpan(_unsafeStart: heap.pointer, count: count.rawValue)
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
extension Array.Small where Element: ~Copyable {
    /// Provides read-only access to the underlying contiguous storage.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        if count.rawValue > 0 {
            if let heap {
                return try unsafe body(UnsafeBufferPointer(start: heap.pointer, count: count.rawValue))
            } else {
                let span = _inlineBuffer.span
                return try unsafe body(UnsafeBufferPointer(start: span.unsafeBaseAddress, count: count.rawValue))
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
        if count.rawValue > 0 {
            if let heap {
                return try unsafe body(UnsafeMutableBufferPointer(start: heap.pointer, count: count.rawValue))
            } else {
                let span = _inlineBuffer.mutableSpan
                let ptr = unsafe UnsafeMutablePointer(mutating: span.unsafeBaseAddress!)
                return try unsafe body(UnsafeMutableBufferPointer(start: ptr, count: count.rawValue))
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
            _ = unsafe heapState.storage.withUnsafeMutablePointerToElements { elements in
                (0..<count).forEach { i in
                    unsafe body(elements[i])
                }
            }
        } else {
            for i in 0..<Int(bitPattern: count) {
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
            _ = unsafe heapState.storage.withUnsafeMutablePointerToElements { elements in
                (0..<count).forEach { i in
                    unsafe body((elements + i).move())
                }
            }
            unsafe base.pointee.heap!.storage.header = 0
        } else {
            while !unsafe base.pointee._inlineBuffer.isEmpty {
                body(unsafe base.pointee._inlineBuffer.consumeFront())
            }
        }
        unsafe base.pointee.count = .zero
    }
}
