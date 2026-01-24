//
//  File.swift
//  swift-array-primitives
//
//  Created by Coen ten Thije Boonkkamp on 24/01/2026.
//

public import Array_Primitives_Core
public import Index_Primitives

// MARK: - Properties

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
    package mutating func spill(minimumCapacity: Array.Index.Count) {
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
            // Inline mode - deinitialize via Storage.Inline
            inline.deinitialize(count: count)
        }
        count = .zero
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
    public func withElement<R>(at index: Index, _ body: (borrowing Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        if let heap {
            return unsafe heap.storage.withUnsafeMutablePointerToElements { elements in
                body(unsafe (elements + index).pointee)
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

}

// MARK: - Span Access

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
                yield unsafe inline.read(at: index).pointee
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
