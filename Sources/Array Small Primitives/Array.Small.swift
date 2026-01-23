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

// Extensions for Array.Small that work with ~Copyable elements.
// Moved from Core to minimize Core's footprint.

public import Index_Primitives
public import Array_Primitives_Core

// MARK: - Properties

extension Array.Small where Element: ~Copyable {
    /// The number of elements in the array.
    @inlinable
    public var count: Index_Primitives.Index<Element>.Count { elementCount }

    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { elementCount == .zero }

    /// The current capacity of the array.
    @inlinable
    public var capacity: Int {
        if let heapState = heap {
            return heapState.storage.capacity
        }
        return inlineCapacity
    }

    /// Whether the array is currently using heap storage.
    @inlinable
    public var isSpilled: Bool { heap != nil }
}

// MARK: - Internal Operations

extension Array.Small where Element: ~Copyable {
    /// Spills inline storage to heap.
    ///
    /// Called when appending would exceed inline capacity.
    /// Moves all inline elements to newly allocated heap storage.
    ///
    /// - Parameter minimumCapacity: The minimum capacity for heap storage.
    /// - Precondition: Must not already be in heap mode.
    @usableFromInline
    package mutating func spill(minimumCapacity: Int) {
        precondition(heap == nil, "Already spilled")

        let newStorage = Heap.create(minimumCapacity: minimumCapacity)
        inline.move(to: newStorage, count: count.rawValue)
        newStorage.header = count.rawValue
        heap = Heap(newStorage)
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
        if var heapState = heap {
            // Heap mode
            let currentCount = heapState.storage.header
            heapState.ensureCapacity(currentCount + 1)
            heap = heapState  // Write back mutation
            heap!.storage.initialize(to: element, at: currentCount)
            heap!.storage.header = currentCount + 1
            elementCount = Index_Primitives.Index<Element>.Count(__unchecked: count.rawValue + 1)
        } else if count.rawValue < inlineCapacity {
            // Inline mode with room
            let ptr = unsafe inline.pointer(at: count.rawValue)
            unsafe ptr.initialize(to: element)
            elementCount = Index_Primitives.Index<Element>.Count(__unchecked: count.rawValue + 1)
        } else {
            // Need to spill
            spill(minimumCapacity: count.rawValue + 1)
            heap!.storage.initialize(to: element, at: count.rawValue)
            heap!.storage.header = count.rawValue + 1
            elementCount = Index_Primitives.Index<Element>.Count(__unchecked: count.rawValue + 1)
        }
    }

    /// Removes and returns the last element.
    ///
    /// - Returns: The removed element, or `nil` if the array is empty.
    @inlinable
    public mutating func removeLast() -> Element? {
        guard count.rawValue > 0 else { return nil }

        if let heapState = heap {
            // Heap mode
            let newCount = count.rawValue - 1
            elementCount = Index_Primitives.Index<Element>.Count(__unchecked: newCount)
            heap!.storage.header = newCount
            return heapState.storage.move(at: newCount)
        } else {
            // Inline mode
            let newCount = count.rawValue - 1
            elementCount = Index_Primitives.Index<Element>.Count(__unchecked: newCount)
            let ptr = unsafe inline.pointer(at: newCount)
            return unsafe ptr.move()
        }
    }

    /// Removes all elements from the array.
    ///
    /// - Parameter keepingCapacity: Whether to keep heap storage (if spilled).
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool = false) {
        guard count.rawValue > 0 else { return }

        if let heapState = heap {
            // Heap mode - deinitialize via storage
            heapState.storage.deinitialize()
            if !keepingCapacity {
                heap = nil
            }
        } else {
            // Inline mode - deinitialize via Storage.Inline
            inline.deinitialize(count: count.rawValue)
        }
        elementCount = .zero
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
        precondition(index < count, "Index out of bounds")
        if let heapState = heap {
            return unsafe heapState.storage.withUnsafeMutablePointerToElements { elements in
                body(unsafe (elements + index.position.rawValue).pointee)
            }
        } else {
            // Use withUnsafePointer directly - inline accessor requires mutating context
            let stride = MemoryLayout<Element>.stride
            return unsafe withUnsafePointer(to: inline) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + index.position.rawValue * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe body(elementPtr.pointee)
            }
        }
    }

    /// Iterates over all elements in the array.
    ///
    /// - Parameter body: A closure that receives each borrowed element.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        guard count.rawValue > 0 else { return }

        if let heapState = heap {
            _ = try unsafe heapState.storage.withUnsafeMutablePointerToElements { (elements) throws(E) in
                for i in 0..<count.rawValue {
                    try unsafe body((elements + i).pointee)
                }
            }
        } else {
            let stride = MemoryLayout<Element>.stride
            try unsafe withUnsafePointer(to: inline) { storagePtr throws(E) in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                for i in 0..<count.rawValue {
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
        guard count.rawValue > 0 else { return }

        if let heapState = heap {
            _ = unsafe heapState.storage.withUnsafeMutablePointerToElements { elements in
                for i in 0..<count.rawValue {
                    unsafe body((elements + i).move())
                }
            }
            heap!.storage.header = 0
        } else {
            for i in 0..<count.rawValue {
                body(inline.move(at: i))
            }
        }
        elementCount = .zero
    }
}

// MARK: - Span Access

extension Array.Small where Element: ~Copyable {
    /// Provides read-only span access to the array elements.
    @inlinable
    public func withSpan<R, E: Swift.Error>(
        _ body: (Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        if count.rawValue > 0 {
            if let heapState = heap {
                let span = unsafe Span(_unsafeStart: heapState.pointer, count: count.rawValue)
                return try body(span)
            } else {
                return try unsafe withUnsafePointer(to: inline) { storagePtr throws(E) -> R in
                    let basePtr = unsafe UnsafeRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    let span = unsafe Span(_unsafeStart: elementPtr, count: count.rawValue)
                    return try body(span)
                }
            }
        } else {
            let span = unsafe Span(_unsafeStart: UnsafePointer<Element>(bitPattern: 1)!, count: 0)
            return try body(span)
        }
    }

    /// Provides mutable span access to the array elements.
    @inlinable
    public mutating func withMutableSpan<R, E: Swift.Error>(
        _ body: (borrowing MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        if count.rawValue > 0 {
            if let heapState = heap {
                let span = unsafe MutableSpan(_unsafeStart: heapState.pointer, count: count.rawValue)
                return try body(span)
            } else {
                let elementCount = count.rawValue
                return try unsafe withUnsafeMutablePointer(to: &inline) { storagePtr throws(E) -> R in
                    let basePtr = UnsafeMutableRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    let span = unsafe MutableSpan(_unsafeStart: elementPtr, count: elementCount)
                    return try body(span)
                }
            }
        } else {
            let span = unsafe MutableSpan(_unsafeStart: UnsafeMutablePointer<Element>(bitPattern: 1)!, count: 0)
            return try body(span)
        }
    }
}

// MARK: - Buffer Access (Escape Hatch for C Interop)

@_spi(Unsafe)
extension Array.Small where Element: ~Copyable {
    /// Provides read-only access to the underlying contiguous storage.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        if count.rawValue > 0 {
            if let heapState = heap {
                return try unsafe body(UnsafeBufferPointer(start: heapState.pointer, count: count.rawValue))
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
            if let heapState = heap {
                return try unsafe body(UnsafeMutableBufferPointer(start: heapState.pointer, count: count.rawValue))
            } else {
                let elementCount = count.rawValue
                return try unsafe withUnsafeMutablePointer(to: &inline) { (storagePtr) throws(E) -> R in
                    let basePtr = UnsafeMutableRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    return try unsafe body(UnsafeMutableBufferPointer(start: elementPtr, count: elementCount))
                }
            }
        } else {
            return try unsafe body(UnsafeMutableBufferPointer(start: nil, count: 0))
        }
    }
}

// MARK: - Safe Element Access

extension Array.Small where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Array<Element>.Index) -> Element? {
        guard index < count else { return nil }
        if let heapState = heap {
            return unsafe heapState.pointer[index.position.rawValue]
        } else {
            // Use withUnsafePointer directly - inline accessor requires mutating context
            let stride = MemoryLayout<Element>.stride
            return unsafe withUnsafePointer(to: inline) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + index.position.rawValue * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr.pointee
            }
        }
    }

    /// Returns element at index offset from given base index.
    ///
    /// - Parameters:
    ///   - base: The starting index.
    ///   - offset: The signed offset from the base.
    /// - Returns: The element at the computed position, or `nil` if out of bounds.
    @inlinable
    public func element(
        at base: Array<Element>.Index,
        offsetBy offset: Array<Element>.Index.Offset
    ) -> Element? {
        guard let newIndex = base + offset else { return nil }
        guard newIndex < count else { return nil }
        if let heapState = heap {
            return unsafe heapState.pointer[newIndex.position.rawValue]
        } else {
            // Use withUnsafePointer directly - inline accessor requires mutating context
            let stride = MemoryLayout<Element>.stride
            return unsafe withUnsafePointer(to: inline) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + newIndex.position.rawValue * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr.pointee
            }
        }
    }
}

// MARK: - Typed Subscript

extension Array.Small where Element: Copyable {
    /// Accesses the element at the given typed index (copy semantics for Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Array<Element>.Index) -> Element {
        get {
            precondition(index < count, "Index out of bounds")
            if let heapState = heap {
                return unsafe heapState.pointer[index.position.rawValue]
            } else {
                // Use withUnsafePointer directly - inline accessor requires mutating context
                let stride = MemoryLayout<Element>.stride
                return unsafe withUnsafePointer(to: inline) { storagePtr in
                    let basePtr = unsafe UnsafeRawPointer(storagePtr)
                    let elementPtr = unsafe (basePtr + index.position.rawValue * stride)
                        .assumingMemoryBound(to: Element.self)
                    return unsafe elementPtr.pointee
                }
            }
        }
        set {
            precondition(index < count, "Index out of bounds")
            if heap != nil {
                _ = heap!.storage.move(at: index.position.rawValue)
                heap!.storage.initialize(to: newValue, at: index.position.rawValue)
            } else {
                unsafe inline.pointer(at: index.position.rawValue).pointee = newValue
            }
        }
    }
}

extension Array.Small where Element: ~Copyable {
    /// Accesses the element at the given typed index (borrowing access for ~Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Array<Element>.Index) -> Element {
        // Note: _read must be mutating because inline storage access requires &self
        // to obtain a pointer. This is a fundamental limitation - see Non-Mutating-Accessor-Problem.md
        mutating _read {
            precondition(index < count, "Index out of bounds")
            if let heapState = heap {
                yield unsafe heapState.pointer[index.position.rawValue]
            } else {
                yield unsafe inline.read(at: index.position.rawValue).pointee
            }
        }
        _modify {
            precondition(index < count, "Index out of bounds")
            if let heapState = heap {
                yield &(unsafe heapState.pointer[index.position.rawValue])
            } else {
                yield &(unsafe inline.pointer(at: index.position.rawValue).pointee)
            }
        }
    }
}

extension Array.Small: @unchecked Sendable where Element: Sendable {}
