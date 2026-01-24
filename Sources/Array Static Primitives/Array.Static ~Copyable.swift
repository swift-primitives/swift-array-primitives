public import Array_Primitives_Core
public import Index_Primitives

// MARK: - Properties

extension Array.Static where Element: ~Copyable {


    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { count == .zero }

    /// Whether the array is at full capacity.
    @inlinable
    public var isFull: Bool { count.rawValue >= capacity }
}

// MARK: - Core Operations

extension Array.Static where Element: ~Copyable {
    /// Appends an element to the array.
    ///
    /// - Parameter element: The element to append (consumed).
    /// - Throws: ``Array/Inline/Error/overflow`` if the array is full.
    @inlinable
    public mutating func append(_ element: consuming Element) throws(Array.Static.Error) {
        guard count.rawValue < capacity else {
            throw .overflow
        }
        storage.initialize(to: element, at: .init(count))
        count = Index.Count(__unchecked: count.rawValue + 1)
    }

    /// Removes and returns the last element.
    ///
    /// - Returns: The removed element, or `nil` if the array is empty.
    @inlinable
    public mutating func removeLast() -> Element? {
        guard let newCount = count - 1 else { return nil }
        count = newCount
        return storage.move(at: .init(newCount))
    }
}

// MARK: - Borrowed Element Access (for ~Copyable elements)

extension Array.Static where Element: ~Copyable {
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
        return unsafe body(storage.read(at: index).pointee)
    }
}

// MARK: - Bounded Index (Inline Arrays)

extension Array.Static where Element: ~Copyable {
    /// Accesses the element at the given bounded index.
    ///
    /// The type `Index<Element>.Bounded<capacity>` proves `0 <= index < capacity`.
    /// **No runtime bounds check is performed.**
    ///
    /// ## Type-Based Safety
    ///
    /// The TYPE encodes the bounds proof:
    /// - `Index<Element>` subscript → has runtime bounds check
    /// - `Index<Element>.Bounded<capacity>` subscript → NO bounds check (type proves it)
    ///
    /// ## Contract
    ///
    /// For full arrays (`count == capacity`), this subscript is completely safe.
    /// For partial arrays (`count < capacity`), caller must ensure `index < count`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var inline = Array<Int>.Inline<8>()
    /// // Fill to capacity...
    /// assert(inline.isFull)
    ///
    /// let idx: Index<Int>.Bounded<8> = 3
    /// print(inline[idx])  // No runtime bounds check - type proves 0 <= 3 < 8
    /// ```
    ///
    /// - Parameter index: A bounded index where the type proves `0 <= index < capacity`.
    @inlinable
    public subscript(_ index: Index.Bounded<capacity>) -> Element {
        _read {
            // Type proves: 0 <= index < capacity
            // For full arrays: count == capacity, so 0 <= index < count ✓
            yield unsafe storage.read(at: index.unbounded).pointee
        }
        _modify {
            yield &(unsafe storage.pointer(at: index.unbounded).pointee)
        }
    }
}

// MARK: - Typed Subscript (Array.Static)

extension Array.Static where Element: ~Copyable {
    /// Accesses the element at the given typed index (borrowing access for ~Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Index) -> Element {
        _read {
            precondition(index < count, "Index out of bounds")
            yield unsafe storage.read(at: index).pointee
        }
        _modify {
            precondition(index < count, "Index out of bounds")
            yield &(unsafe storage.pointer(at: index).pointee)
        }
    }
}

// MARK: - Error Description

extension Array.Static.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .overflow:
            return "static array is full"
        case .indexOutOfBounds(let index, let count):
            return "index \(index) out of bounds for count \(count)"
        }
    }
}



// MARK: - Buffer Access (Escape Hatch for C Interop)

@_spi(Unsafe)
extension Array.Static where Element: ~Copyable {
    /// Provides read-only access to the underlying contiguous storage.
    ///
    /// - Warning: This is an escape hatch for C interop. Prefer `span` for safe access.
    /// - Warning: The pointer must not escape the closure scope.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        return try unsafe withUnsafePointer(to: storage.raw) { storagePtr throws(E) -> R in
            let basePtr = unsafe UnsafeRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            return try unsafe body(UnsafeBufferPointer(start: count.rawValue > 0 ? elementPtr : nil, count: count.rawValue))
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
        return try unsafe withUnsafeMutablePointer(to: &storage.raw) { storagePtr throws(E) -> R in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            return try unsafe body(UnsafeMutableBufferPointer(start: count.rawValue > 0 ? elementPtr : nil, count: count.rawValue))
        }
    }
}

// MARK: - Span Access

extension Array.Static where Element: ~Copyable {
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
    /// Inline storage requires closure-based access because the storage address
    /// is not stable (it moves with the struct). Use `span` property on heap-backed
    /// variants (Fixed, Array) for direct access.
    @inlinable
    public func withSpan<R, E: Swift.Error>(
        _ body: (Swift.Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        return try unsafe withUnsafePointer(to: storage.raw) { storagePtr throws(E) -> R in
            let basePtr = unsafe UnsafeRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            let span = unsafe Swift.Span(_unsafeStart: elementPtr, count: count.rawValue)
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
    /// Inline storage requires closure-based access because the storage address
    /// is not stable (it moves with the struct). Use `mutableSpan` property on
    /// heap-backed variants (Fixed, Array) for direct access.
    @inlinable
    public mutating func withMutableSpan<R, E: Swift.Error>(
        _ body: (borrowing MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        return try unsafe withUnsafeMutablePointer(to: &storage.raw) { storagePtr throws(E) -> R in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            let span = unsafe MutableSpan(_unsafeStart: elementPtr, count: count.rawValue)
            return try body(span)
        }
    }
}


// MARK: - Pointer Helpers

extension Array.Static where Element: ~Copyable {

    /// Returns a mutable pointer to the element at the given index.
    @usableFromInline
    @unsafe
    package mutating func _pointerToElement(at index: Index) -> UnsafeMutablePointer<Element> {
        unsafe storage.pointer(at: index)
    }

    /// Returns a read-only pointer to the element at the given index.
    @usableFromInline
    @unsafe
    package func _readPointerToElement(at index: Index) -> UnsafePointer<Element> {
        unsafe storage.read(at: index)
    }
}

// MARK: - Operations Requiring Direct _storage Access

extension Array.Static where Element: ~Copyable {
    /// Removes all elements from the array.
    @inlinable
    public mutating func removeAll() {
        guard count.rawValue > 0 else { return }
        storage.deinitialize(count: count)
        count = .zero
    }
}

