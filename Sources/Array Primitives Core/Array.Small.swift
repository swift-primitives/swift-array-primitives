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

public import Index_Primitives
public import Array_Primitives_Core

extension Array where Element: ~Copyable {
    
    // MARK: - Small (SmallVec Pattern)

    /// An array with small-buffer optimization (SmallVec pattern).
    ///
    /// `Array.Small` stores up to `inlineCapacity` elements in inline storage,
    /// then automatically spills to heap storage when that capacity is exceeded.
    /// This provides the performance benefits of inline storage for common cases
    /// while supporting unbounded growth.
    ///
    /// ## Move-Only
    ///
    /// `Array.Small` is unconditionally `~Copyable` (move-only) because it requires
    /// a deinitializer to clean up inline storage.
    ///
    /// ## Limitations
    ///
    /// - Maximum element stride: 64 bytes (8 Int-sized words) for inline storage
    /// - Element alignment must not exceed `MemoryLayout<Int>.alignment` for inline storage
    ///
    /// - Note: This type is declared inside `Array` (not in an extension) due to a
    ///   Swift compiler bug where nested types with value generic parameters declared
    ///   in extensions do not properly inherit `~Copyable` constraints from the outer type.
    @safe
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        /// Maximum element stride supported by inline storage (64 bytes per slot).
        @usableFromInline
        package static var _maxElementStride: Int { 64 }

        /// Raw byte storage for inline elements.
        @usableFromInline
        package var _inlineElements: InlineArray<inlineCapacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        /// Current element count (valid in both inline and heap modes).
        @usableFromInline
        package var _count: Index_Primitives.Index<Element>.Count

        /// Heap storage for elements when spilled. Nil when using inline storage.
        @usableFromInline
        package var _heapStorage: Unbounded<inlineCapacity>.ElementStorage?

        /// Cached pointer to heap elements. Only valid when _heapStorage is non-nil.
        @usableFromInline
        package var _heapPtr: UnsafeMutablePointer<Element>?

        /// Creates an empty small array.
        @inlinable
        public init() {
            precondition(
                MemoryLayout<Element>.stride <= Self._maxElementStride,
                "Element stride (\(MemoryLayout<Element>.stride)) exceeds inline storage slot size (\(Self._maxElementStride) bytes). Use Array.Unbounded instead."
            )
            precondition(
                MemoryLayout<Element>.alignment <= MemoryLayout<Int>.alignment,
                "Element alignment (\(MemoryLayout<Element>.alignment)) exceeds inline storage alignment (\(MemoryLayout<Int>.alignment)). Use Array.Unbounded instead."
            )
            self._inlineElements = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
            self._count = .zero
            self._heapStorage = nil
            unsafe (self._heapPtr = nil)
        }

        deinit {
            let count = _count.rawValue
            guard count > 0 else { return }

            if let heap = _heapStorage {
                // Elements are on heap - ElementStorage handles cleanup via its deinit
                // Set header count for proper cleanup
                heap.header = count
            } else {
                // Elements are inline - clean up manually
                let stride = MemoryLayout<Element>.stride
                unsafe Swift.withUnsafeBytes(of: _inlineElements) { bytes in
                    let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                    for i in 0..<count {
                        let elementPtr = unsafe (basePtr + i * stride)
                            .assumingMemoryBound(to: Element.self)
                        unsafe elementPtr.deinitialize(count: 1)
                    }
                }
            }
        }
    }
}

extension Array.Small: @unchecked Sendable where Element: Sendable {}

// MARK: - Properties

extension Array.Small where Element: ~Copyable {
    /// Whether the array is currently using heap storage.
    @inlinable
    public var isSpilled: Bool { _heapStorage != nil }

    // MARK: - Internal Helpers

    /// Returns a mutable pointer to the inline element at the given index.
    @usableFromInline
    @unsafe
    package mutating func _inlinePointerToElement(at index: Int) -> UnsafeMutablePointer<Element> {
        let stride = MemoryLayout<Element>.stride
        return unsafe Swift.withUnsafeMutablePointer(to: &_inlineElements) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            let elementPtr = unsafe (basePtr + index * stride)
                .assumingMemoryBound(to: Element.self)
            return unsafe elementPtr
        }
    }

    /// Returns a read-only pointer to the inline element at the given index.
    @usableFromInline
    @unsafe
    package func _inlineReadPointerToElement(at index: Int) -> UnsafePointer<Element> {
        let stride = MemoryLayout<Element>.stride
        return unsafe Swift.withUnsafePointer(to: _inlineElements) { storagePtr in
            let basePtr = unsafe UnsafeRawPointer(storagePtr)
            let elementPtr = unsafe (basePtr + index * stride)
                .assumingMemoryBound(to: Element.self)
            return unsafe elementPtr
        }
    }

    /// Spills inline storage to heap.
    @usableFromInline
    mutating func _spillToHeap(minimumCapacity: Int) {
        precondition(_heapStorage == nil, "Already spilled")

        // Create heap storage with growth factor
        let newCapacity = Swift.max(minimumCapacity, inlineCapacity * 2, 8)
        let newStorage = Array<Element>.Unbounded<inlineCapacity>.ElementStorage.create(minimumCapacity: newCapacity)

        // Move elements from inline to heap
        let stride = MemoryLayout<Element>.stride
        _ = unsafe Swift.withUnsafeBytes(of: _inlineElements) { bytes in
            unsafe newStorage.withUnsafeMutablePointerToElements { heapPtr in
                let inlineBase = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                for i in 0..<_count.rawValue {
                    let inlineElement = unsafe (inlineBase + i * stride)
                        .assumingMemoryBound(to: Element.self)
                    unsafe (heapPtr + i).initialize(to: inlineElement.move())
                }
            }
        }
        newStorage.header = _count.rawValue

        _heapStorage = newStorage
        unsafe (_heapPtr = newStorage._elementsPointer)
    }

    /// Ensures the heap has capacity for at least the specified number of elements.
    @usableFromInline
    mutating func _ensureHeapCapacity(_ minimumCapacity: Int) {
        guard let heapStorage = _heapStorage else {
            preconditionFailure("Not in heap mode")
        }
        guard heapStorage.capacity < minimumCapacity else { return }

        let newCapacity = Swift.max(minimumCapacity, heapStorage.capacity * 2, 8)
        let newStorage = Array<Element>.Unbounded<inlineCapacity>.ElementStorage.create(minimumCapacity: newCapacity)
        let currentCount = heapStorage.header

        heapStorage._moveAllElements(to: newStorage)
        newStorage.header = currentCount
        _heapStorage = newStorage
        unsafe (_heapPtr = newStorage._elementsPointer)
    }
}

extension Array.Small where Element: ~Copyable {
    /// The number of elements in the array.
    @inlinable
    public var count: Index_Primitives.Index<Element>.Count { _count }

    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { _count == .zero }

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
            _count = Index_Primitives.Index<Element>.Count(__unchecked: _count.rawValue + 1)
        } else if _count.rawValue < inlineCapacity {
            // Inline mode with room
            let ptr = unsafe _inlinePointerToElement(at: _count.rawValue)
            unsafe ptr.initialize(to: element)
            _count = Index_Primitives.Index<Element>.Count(__unchecked: _count.rawValue + 1)
        } else {
            // Need to spill
            _spillToHeap(minimumCapacity: _count.rawValue + 1)
            _heapStorage!._initializeElement(at: _count.rawValue, to: element)
            _heapStorage!.header = _count.rawValue + 1
            _count = Index_Primitives.Index<Element>.Count(__unchecked: _count.rawValue + 1)
        }
    }

    /// Removes and returns the last element.
    ///
    /// - Returns: The removed element, or `nil` if the array is empty.
    @inlinable
    public mutating func removeLast() -> Element? {
        guard _count.rawValue > 0 else { return nil }

        if let heapStorage = _heapStorage {
            // Heap mode
            let newCount = _count.rawValue - 1
            _count = Index_Primitives.Index<Element>.Count(__unchecked: newCount)
            _heapStorage!.header = newCount
            return heapStorage._moveElement(at: newCount)
        } else {
            // Inline mode
            let newCount = _count.rawValue - 1
            _count = Index_Primitives.Index<Element>.Count(__unchecked: newCount)
            let ptr = unsafe _inlinePointerToElement(at: newCount)
            return unsafe ptr.move()
        }
    }

    /// Removes all elements from the array.
    ///
    /// - Parameter keepingCapacity: Whether to keep heap storage (if spilled).
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool = false) {
        guard _count.rawValue > 0 else { return }

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
                for i in 0..<_count.rawValue {
                    let elementPtr = unsafe (basePtr + i * stride)
                        .assumingMemoryBound(to: Element.self)
                    unsafe elementPtr.deinitialize(count: 1)
                }
            }
        }
        _count = .zero
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
    public func withElement<R>(at index: Index_Primitives.Index<Element>, _ body: (borrowing Element) -> R) -> R {
        precondition(index < _count, "Index out of bounds")
        if let heapStorage = _heapStorage {
            return unsafe heapStorage.withUnsafeMutablePointerToElements { elements in
                body(unsafe (elements + index.position.rawValue).pointee)
            }
        } else {
            return unsafe body(_inlineReadPointerToElement(at: index.position.rawValue).pointee)
        }
    }

    /// Iterates over all elements in the array.
    ///
    /// - Parameter body: A closure that receives each borrowed element.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        guard _count.rawValue > 0 else { return }

        if let heapStorage = _heapStorage {
            _ = try unsafe heapStorage.withUnsafeMutablePointerToElements { (elements) throws(E) in
                for i in 0..<_count.rawValue {
                    try unsafe body((elements + i).pointee)
                }
            }
        } else {
            let stride = MemoryLayout<Element>.stride
            try unsafe withUnsafePointer(to: _inlineElements) { storagePtr throws(E) in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                for i in 0..<_count.rawValue {
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
        guard _count.rawValue > 0 else { return }

        if let heapStorage = _heapStorage {
            _ = unsafe heapStorage.withUnsafeMutablePointerToElements { elements in
                for i in 0..<_count.rawValue {
                    unsafe body((elements + i).move())
                }
            }
            _heapStorage!.header = 0
        } else {
            let stride = MemoryLayout<Element>.stride
            unsafe Swift.withUnsafeMutablePointer(to: &_inlineElements) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                for i in 0..<_count.rawValue {
                    let elementPtr = unsafe (basePtr + i * stride)
                        .assumingMemoryBound(to: Element.self)
                    unsafe body(elementPtr.move())
                }
            }
        }
        _count = .zero
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
        if _count.rawValue > 0 {
            if let heapPtr = unsafe _heapPtr {
                let span = unsafe Span(_unsafeStart: heapPtr, count: _count.rawValue)
                return try body(span)
            } else {
                return try unsafe withUnsafePointer(to: _inlineElements) { storagePtr throws(E) -> R in
                    let basePtr = unsafe UnsafeRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    let span = unsafe Span(_unsafeStart: elementPtr, count: _count.rawValue)
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
        if _count.rawValue > 0 {
            if let heapPtr = unsafe _heapPtr {
                let span = unsafe MutableSpan(_unsafeStart: heapPtr, count: _count.rawValue)
                return try body(span)
            } else {
                return try unsafe withUnsafeMutablePointer(to: &_inlineElements) { storagePtr throws(E) -> R in
                    let basePtr = UnsafeMutableRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    let span = unsafe MutableSpan(_unsafeStart: elementPtr, count: _count.rawValue)
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
        if _count.rawValue > 0 {
            if let heapPtr = unsafe _heapPtr {
                return try unsafe body(UnsafeBufferPointer(start: heapPtr, count: _count.rawValue))
            } else {
                return try unsafe withUnsafePointer(to: _inlineElements) { (storagePtr) throws(E) -> R in
                    let basePtr = unsafe UnsafeRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    return try unsafe body(UnsafeBufferPointer(start: elementPtr, count: _count.rawValue))
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
        if _count.rawValue > 0 {
            if let heapPtr = unsafe _heapPtr {
                return try unsafe body(UnsafeMutableBufferPointer(start: heapPtr, count: _count.rawValue))
            } else {
                return try unsafe withUnsafeMutablePointer(to: &_inlineElements) { (storagePtr) throws(E) -> R in
                    let basePtr = UnsafeMutableRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    return try unsafe body(UnsafeMutableBufferPointer(start: elementPtr, count: _count.rawValue))
                }
            }
        } else {
            return try unsafe body(UnsafeMutableBufferPointer(start: nil, count: 0))
        }
    }
}

