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
        // Note: _read must be mutating because inline storage access requires &self
        // to obtain a pointer. This is a fundamental limitation - see Non-Mutating-Accessor-Problem.md
        mutating _read {
            precondition(index < count, "Index out of bounds")
            if let heap {
                yield unsafe heap.pointer[index]
            } else {
                yield inline.pointer(at: index).pointee
            }
        }
        _modify {
            precondition(index < count, "Index out of bounds")
            if let heap {
                // Note: Using `var` is required for custom subscript with unsafeMutableAddress
                // to work through optional binding. See: Experiments/pointer-subscript-modify
                var ptr = unsafe heap.pointer
                yield &(unsafe ptr[index])
            } else {
                yield &(unsafe inline.pointer(at: index).pointee)
            }
        }
    }
}

// ============================================================================
// MARK: - Element Access
// ============================================================================

extension Array.Small where Element: ~Copyable {
    /// Accesses the element at the given index via closure (for ~Copyable elements).
    ///
    /// - Parameters:
    ///   - index: The index of the element.
    ///   - body: A closure that receives a borrowed reference to the element.
    /// - Returns: The result of the closure.
    /// - Precondition: The index must be in bounds.
    @inlinable
    public func withElement<R>(at index: Index, _ body: (borrowing Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        if let heap {
            return unsafe heap.storage.withUnsafeMutablePointerToElements { elements in
                body(unsafe (elements + index).pointee)
            }
        } else {
            // Use withUnsafePointer directly - inline accessor requires mutating context
            let stride = Affine.Discrete.Ratio<Element, UInt8>(MemoryLayout<Element>.stride)
            return unsafe withUnsafePointer(to: inline) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + (Index<Element>.Offset(index) * stride).vector.rawValue)
                    .assumingMemoryBound(to: Element.self)
                return unsafe body(elementPtr.pointee)
            }
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
    ///
    /// - Parameter minimumCapacity: The minimum capacity for heap storage.
    /// - Precondition: Must not already be in heap mode.
    @usableFromInline
    package mutating func spill(minimumCapacity: Array.Index.Count) {
        precondition(heap == nil, "Already spilled")

        let newStorage = Heap.create(minimumCapacity: minimumCapacity)
        inline.move(to: newStorage, count: count)
        newStorage.header = count.rawValue
        heap = Heap(newStorage)
    }

    /// Appends an element to the array.
    ///
    /// If the array is in inline mode and full, it spills to heap storage first.
    ///
    /// - Parameter element: The element to append (consumed).
    @inlinable
    public mutating func append(_ element: consuming Element) {
        if var heap {
            // Heap mode
            let currentCount: Array.Index.Count = .init(__unchecked: heap.storage.header)
            heap.ensureCapacity(currentCount + .one)
            self.heap = heap  // Write back mutation
            heap.storage.initialize(to: element, at: Index(currentCount))
            heap.storage.header = currentCount.rawValue + 1
            count = count + .one
        } else if count.rawValue < inlineCapacity {
            // Inline mode with room
            let ptr = unsafe inline.pointer(at: Array.Index(count))
            unsafe ptr.initialize(to: element)
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
    ///
    /// - Returns: The removed element, or `nil` if the array is empty.
    @inlinable
    public mutating func removeLast() -> Element? {
        guard count.rawValue > 0 else { return nil }

        if let heap {
            // Heap mode
            guard let newCount = count - .one else { return nil }
            self.heap?.storage.header = newCount.rawValue
            count = newCount
            return heap.storage.move(at: Index(newCount))
        } else {
            // Inline mode
            let newCount = count.rawValue - 1
            count = Index.Count(__unchecked: newCount)
            let ptr = unsafe inline.pointer(at: Array.Index(__unchecked: (), position: newCount))
            return unsafe ptr.move()
        }
    }

    /// Removes all elements from the array.
    ///
    /// - Parameter keepingCapacity: Whether to keep heap storage (if spilled).
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool = false) {
        guard count.rawValue > 0 else { return }

        if let heap {
            // Heap mode - deinitialize via storage
            heap.storage.deinitialize()
            if !keepingCapacity {
                self.heap = nil
            }
        } else {
            // Inline mode - deinitialize via Storage.Static
            inline.deinitialize(count: count)
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
                return try unsafe withUnsafePointer(to: inline) { storagePtr throws(E) -> R in
                    let basePtr = unsafe UnsafeRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    let span = unsafe Swift.Span(_unsafeStart: elementPtr, count: count.rawValue)
                    return try body(span)
                }
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
                let count = count.rawValue
                return try unsafe withUnsafeMutablePointer(to: &inline) { storagePtr throws(E) -> R in
                    let basePtr = UnsafeMutableRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    let span = unsafe MutableSpan(_unsafeStart: elementPtr, count: count)
                    return try body(span)
                }
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
                return try unsafe withUnsafePointer(to: inline) { (storagePtr) throws(E) -> R in
                    let basePtr = unsafe UnsafeRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    return try unsafe body(UnsafeBufferPointer(start: elementPtr, count: count.rawValue))
                }
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
                let count = count.rawValue
                return try unsafe withUnsafeMutablePointer(to: &inline) { (storagePtr) throws(E) -> R in
                    let basePtr = UnsafeMutableRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    return try unsafe body(UnsafeMutableBufferPointer(start: elementPtr, count: count))
                }
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
    ///
    /// Provides iteration patterns for ALL element types including `~Copyable`:
    /// - `.forEach { }` — Borrowing iteration via `callAsFunction`
    /// - `.forEach.borrowing { }` — Explicit borrowing iteration
    ///
    /// For `Copyable` elements only:
    /// - `.forEach.consuming { }` — Consuming iteration (clears array)
    ///
    /// ## Example
    ///
    /// ```swift
    /// var array = try Array<Int>.Small<4>()
    /// array.append(1)
    /// array.append(2)
    /// array.append(3)
    ///
    /// // Borrowing iteration (works for ALL elements)
    /// array.forEach { print($0) }
    ///
    /// // Consuming iteration (Copyable elements only)
    /// array.forEach.consuming { print($0) }
    /// // array is now empty
    /// ```
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
    ///
    /// Iterates over all elements without consuming them.
    /// Works for ALL element types including `~Copyable`.
    ///
    /// - Parameter body: A closure called with each borrowed element.
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
            // Inline storage uses stride-based raw pointer arithmetic
            let stride = MemoryLayout<Element>.stride
            unsafe withUnsafePointer(to: base.pointee.inline) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                for i in 0..<count.rawValue {
                    let elementPtr = unsafe (basePtr + i * stride)
                        .assumingMemoryBound(to: Element.self)
                    unsafe body(elementPtr.pointee)
                }
            }
        }
    }

    /// Explicit borrowing iteration: `.forEach.borrowing { }`
    ///
    /// Same as `callAsFunction`, but with explicit naming for clarity.
    /// Works for ALL element types including `~Copyable`.
    ///
    /// - Parameter body: A closure called with each borrowed element.
    @inlinable
    public func borrowing(_ body: (borrowing Element) -> Void) {
        callAsFunction(body)
    }
}

// MARK: Drain Property View

extension Array.Small where Element: ~Copyable {
    /// Property view for draining operations.
    ///
    /// Provides `.drain { }` via `callAsFunction`, which removes all elements
    /// from the array and passes each to the closure with ownership.
    /// Works for ALL element types including `~Copyable`.
    ///
    /// After draining, the array is empty but still usable.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var array = try Array<Int>.Small<4>()
    /// array.append(1)
    /// array.append(2)
    /// array.append(3)
    ///
    /// // Drain all elements (takes ownership)
    /// array.drain { element in
    ///     process(element)
    /// }
    /// // array is now empty but still usable
    /// array.append(4)
    /// ```
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
    ///
    /// Removes all elements from the array, passing each to the closure
    /// with ownership. After this call, the array is empty but usable.
    /// Works for ALL element types including `~Copyable`.
    ///
    /// - Parameter body: A closure called with each element (consuming).
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
            (0..<count).forEach { i in
                body(unsafe base.pointee.inline.move(at: i))
            }
        }
        unsafe base.pointee.count = .zero
    }
}
