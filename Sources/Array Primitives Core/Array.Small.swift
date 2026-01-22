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

// Note: Array.Small is declared INSIDE the Array enum body (in Array.swift)
// due to a Swift compiler bug where nested types with value generic parameters
// declared in extensions do not properly inherit ~Copyable constraints from
// the outer type. This file contains only extensions to Array.Small.

// MARK: - Properties

extension Array.Small where Element: ~Copyable {
    /// The number of elements in the array.
    @inlinable
    public var count: Int { _count }

    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// The current capacity of the array.
    @inlinable
    public var capacity: Int {
        if let heapStorage = _heapStorage {
            return heapStorage.capacity
        }
        return inlineCapacity
    }
}

// MARK: - Core Operations (Base - for ~Copyable elements)

extension Array.Small where Element: ~Copyable {
    /// Appends an element to the array.
    ///
    /// If the array is in inline mode and full, it spills to heap storage first.
    ///
    /// - Parameter element: The element to append (consumed).
    @inlinable
    public mutating func append(_ element: consuming Element) {
        if let heapStorage = _heapStorage {
            // Heap mode
            let count = heapStorage.header
            _ensureHeapCapacity(count + 1)
            _heapStorage!._initializeElement(at: count, to: element)
            _heapStorage!.header = count + 1
            _count += 1
        } else if _count < inlineCapacity {
            // Inline mode with room
            let ptr = unsafe _inlinePointerToElement(at: _count)
            unsafe ptr.initialize(to: element)
            _count += 1
        } else {
            // Need to spill
            _spillToHeap(minimumCapacity: _count + 1)
            _heapStorage!._initializeElement(at: _count, to: element)
            _heapStorage!.header = _count + 1
            _count += 1
        }
    }

    /// Removes and returns the last element.
    ///
    /// - Returns: The removed element, or `nil` if the array is empty.
    @inlinable
    public mutating func removeLast() -> Element? {
        guard _count > 0 else { return nil }

        if let heapStorage = _heapStorage {
            // Heap mode
            _count -= 1
            _heapStorage!.header = _count
            return heapStorage._moveElement(at: _count)
        } else {
            // Inline mode
            _count -= 1
            let ptr = unsafe _inlinePointerToElement(at: _count)
            return unsafe ptr.move()
        }
    }

    /// Removes all elements from the array.
    ///
    /// - Parameter keepingCapacity: Whether to keep heap storage (if spilled).
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool = false) {
        guard _count > 0 else { return }

        if let heapStorage = _heapStorage {
            // Heap mode - deinitialize via storage
            heapStorage._deinitializeAllElements()
            if !keepingCapacity {
                _heapStorage = nil
                unsafe (_heapPtr = nil)
            }
        } else {
            // Inline mode - deinitialize manually
            let stride = MemoryLayout<Element>.stride
            unsafe Swift.withUnsafeMutablePointer(to: &_inlineElements) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                for i in 0..<_count {
                    let elementPtr = unsafe (basePtr + i * stride)
                        .assumingMemoryBound(to: Element.self)
                    unsafe elementPtr.deinitialize(count: 1)
                }
            }
        }
        _count = 0
    }
}

// MARK: - Subscript Access (Copyable elements only)

extension Array.Small where Element: Copyable {
    /// Accesses the element at the specified index.
    ///
    /// - Parameter index: The index of the element.
    /// - Precondition: The index must be in bounds.
    @inlinable
    public subscript(index: Int) -> Element {
        get {
            precondition(index >= 0 && index < _count, "Index out of bounds")
            if let heapStorage = _heapStorage {
                return heapStorage._readElement(at: index)
            } else {
                return unsafe _inlineReadPointerToElement(at: index).pointee
            }
        }
        set {
            precondition(index >= 0 && index < _count, "Index out of bounds")
            if _heapStorage != nil {
                _ = _heapStorage!._moveElement(at: index)
                _heapStorage!._initializeElement(at: index, to: newValue)
            } else {
                let ptr = unsafe _inlinePointerToElement(at: index)
                unsafe ptr.pointee = newValue
            }
        }
    }
}

// MARK: - Borrowed Element Access (for ~Copyable elements)

extension Array.Small where Element: ~Copyable {
    /// Accesses the element at the given index via closure (for ~Copyable elements).
    ///
    /// - Parameters:
    ///   - index: The index of the element.
    ///   - body: A closure that receives a borrowed reference to the element.
    /// - Returns: The result of the closure.
    /// - Precondition: The index must be in bounds.
    @inlinable
    public func withElement<R>(at index: Int, _ body: (borrowing Element) -> R) -> R {
        precondition(index >= 0 && index < _count, "Index out of bounds")
        if let heapStorage = _heapStorage {
            return unsafe heapStorage.withUnsafeMutablePointerToElements { elements in
                body(unsafe (elements + index).pointee)
            }
        } else {
            return unsafe body(_inlineReadPointerToElement(at: index).pointee)
        }
    }

    /// Iterates over all elements in the array.
    ///
    /// - Parameter body: A closure that receives each borrowed element.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        guard _count > 0 else { return }

        if let heapStorage = _heapStorage {
            _ = try unsafe heapStorage.withUnsafeMutablePointerToElements { (elements) throws(E) in
                for i in 0..<_count {
                    try unsafe body((elements + i).pointee)
                }
            }
        } else {
            let stride = MemoryLayout<Element>.stride
            try unsafe withUnsafePointer(to: _inlineElements) { storagePtr throws(E) in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                for i in 0..<_count {
                    let elementPtr = unsafe (basePtr + i * stride)
                        .assumingMemoryBound(to: Element.self)
                    try unsafe body(elementPtr.pointee)
                }
            }
        }
    }

    /// Removes and consumes all elements.
    ///
    /// - Parameter body: A closure that receives each consumed element.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        guard _count > 0 else { return }

        if let heapStorage = _heapStorage {
            _ = unsafe heapStorage.withUnsafeMutablePointerToElements { elements in
                for i in 0..<_count {
                    unsafe body((elements + i).move())
                }
            }
            _heapStorage!.header = 0
        } else {
            let stride = MemoryLayout<Element>.stride
            unsafe Swift.withUnsafeMutablePointer(to: &_inlineElements) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                for i in 0..<_count {
                    let elementPtr = unsafe (basePtr + i * stride)
                        .assumingMemoryBound(to: Element.self)
                    unsafe body(elementPtr.move())
                }
            }
        }
        _count = 0
    }
}

// MARK: - Span Access

extension Array.Small where Element: ~Copyable {
    /// Provides read-only span access to the array elements.
    ///
    /// ## Lifetime Contract
    ///
    /// - The span is valid ONLY for the duration of the closure.
    /// - The span MUST NOT be stored, returned, or allowed to escape.
    /// - Violating this contract is undefined behavior.
    ///
    /// ## Note
    ///
    /// Small arrays use closure-based access because inline storage address
    /// is not stable (it moves with the struct). Use `span` property on
    /// heap-only variants (Bounded, Unbounded) for direct access.
    @inlinable
    public func withSpan<R, E: Swift.Error>(
        _ body: (Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        if _count > 0 {
            if let heapPtr = unsafe _heapPtr {
                let span = unsafe Span(_unsafeStart: heapPtr, count: _count)
                return try body(span)
            } else {
                return try unsafe withUnsafePointer(to: _inlineElements) { storagePtr throws(E) -> R in
                    let basePtr = unsafe UnsafeRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    let span = unsafe Span(_unsafeStart: elementPtr, count: _count)
                    return try body(span)
                }
            }
        } else {
            // Empty: pointer irrelevant when count == 0
            let span = unsafe Span(_unsafeStart: UnsafePointer<Element>(bitPattern: 1)!, count: 0)
            return try body(span)
        }
    }

    /// Provides mutable span access to the array elements.
    ///
    /// ## Lifetime Contract
    ///
    /// - The span is valid ONLY for the duration of the closure.
    /// - The span MUST NOT be stored, returned, or allowed to escape.
    /// - No concurrent mutable borrows are permitted.
    /// - Violating this contract is undefined behavior.
    ///
    /// ## Note
    ///
    /// Small arrays use closure-based access because inline storage address
    /// is not stable (it moves with the struct). Use `mutableSpan` property on
    /// heap-only variants (Bounded, Unbounded) for direct access.
    @inlinable
    public mutating func withMutableSpan<R, E: Swift.Error>(
        _ body: (borrowing MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        if _count > 0 {
            if let heapPtr = unsafe _heapPtr {
                let span = unsafe MutableSpan(_unsafeStart: heapPtr, count: _count)
                return try body(span)
            } else {
                return try unsafe withUnsafeMutablePointer(to: &_inlineElements) { storagePtr throws(E) -> R in
                    let basePtr = UnsafeMutableRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    let span = unsafe MutableSpan(_unsafeStart: elementPtr, count: _count)
                    return try body(span)
                }
            }
        } else {
            // Empty: pointer irrelevant when count == 0
            let span = unsafe MutableSpan(_unsafeStart: UnsafeMutablePointer<Element>(bitPattern: 1)!, count: 0)
            return try body(span)
        }
    }
}

// MARK: - Buffer Access (Escape Hatch for C Interop)

@_spi(Unsafe)
extension Array.Small where Element: ~Copyable {
    /// Provides read-only access to the underlying contiguous storage.
    ///
    /// - Warning: This is an escape hatch for C interop. Prefer `span` for safe access.
    /// - Warning: The pointer must not escape the closure scope.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        if _count > 0 {
            if let heapPtr = unsafe _heapPtr {
                return try unsafe body(UnsafeBufferPointer(start: heapPtr, count: _count))
            } else {
                return try unsafe withUnsafePointer(to: _inlineElements) { (storagePtr) throws(E) -> R in
                    let basePtr = unsafe UnsafeRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    return try unsafe body(UnsafeBufferPointer(start: elementPtr, count: _count))
                }
            }
        } else {
            return try unsafe body(UnsafeBufferPointer(start: nil, count: 0))
        }
    }

    /// Provides mutable access to the underlying contiguous storage.
    ///
    /// - Warning: This is an escape hatch for C interop. Prefer `mutableSpan` for safe access.
    /// - Warning: The pointer must not escape the closure scope.
    @unsafe
    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        if _count > 0 {
            if let heapPtr = unsafe _heapPtr {
                return try unsafe body(UnsafeMutableBufferPointer(start: heapPtr, count: _count))
            } else {
                return try unsafe withUnsafeMutablePointer(to: &_inlineElements) { (storagePtr) throws(E) -> R in
                    let basePtr = UnsafeMutableRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    return try unsafe body(UnsafeMutableBufferPointer(start: elementPtr, count: _count))
                }
            }
        } else {
            return try unsafe body(UnsafeMutableBufferPointer(start: nil, count: 0))
        }
    }
}
