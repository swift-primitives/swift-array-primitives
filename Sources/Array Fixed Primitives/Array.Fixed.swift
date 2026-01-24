public import Collection_Primitives
public import Array_Primitives_Core
public import Index_Primitives

// MARK: - Properties

extension Array.Fixed {
    /// The number of elements in the array.
    @inlinable
    public var count: Index.Count { count }

    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { count == .zero }
}

// MARK: - Safe Element Access (Copyable elements only)

extension Array.Fixed where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Index) -> Element? {
        guard index < count else { return nil }
        return unsafe _cachedPtr[index]
    }
}

extension Array.Fixed where Element: Copyable {
    /// Returns element at index offset from given base index.
    ///
    /// - Parameters:
    ///   - base: The starting index.
    ///   - offset: The signed offset from the base.
    /// - Returns: The element at the computed position, or `nil` if out of bounds.
    @inlinable
    public func element(
        at base: Index,
        offsetBy offset: Index.Offset
    ) -> Element? {
        guard let newIndex = base + offset else { return nil }
        guard newIndex < count else { return nil }
        return unsafe _cachedPtr[newIndex]
    }
}

// MARK: - Span Access (Normative)

extension Array.Fixed where Element: ~Copyable {
    /// Read-only span of the array elements.
    ///
    /// ## Lifetime Contract
    ///
    /// - The span is valid ONLY for the duration of the borrow of `self`.
    /// - The span MUST NOT be stored, returned, or allowed to escape.
    /// - The returned span is lifetime-dependent; the compiler is expected to diagnose escapes.
    /// - Violating this contract is undefined behavior.
    @inlinable
    public var span: Swift.Span<Element> {
        @_lifetime(borrow self)
        borrowing get {
            unsafe Swift.Span(_unsafeStart: _cachedPtr, count: count.rawValue)
        }
    }

    /// Mutable span of the array elements.
    ///
    /// ## Lifetime Contract
    ///
    /// - The span is valid ONLY for the duration of the exclusive mutable borrow.
    /// - The span MUST NOT be stored, returned, or allowed to escape.
    /// - The returned span is lifetime-dependent; the compiler is expected to diagnose escapes.
    /// - No concurrent mutable borrows are permitted.
    /// - No mutable + immutable borrow overlap is permitted.
    /// - Violating this contract is undefined behavior.
    @inlinable
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            unsafe MutableSpan(_unsafeStart: _cachedPtr, count: count.rawValue)
        }
    }
}

// MARK: - CoW-aware MutableSpan (Copyable elements)

extension Array.Fixed where Element: Copyable {
    /// Mutable span with copy-on-write semantics.
    ///
    /// This shadows the base `mutableSpan` when `Element: Copyable`,
    /// ensuring the storage is unique before mutation.
    @inlinable
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            makeUnique()
            return unsafe MutableSpan(_unsafeStart: _cachedPtr, count: count.rawValue)
        }
    }
}

// MARK: - Pointer Access (Escape Hatch for C Interop)

@_spi(Unsafe)
extension Array.Fixed where Element: ~Copyable {
    /// Provides read-only access to the underlying contiguous storage.
    ///
    /// - Warning: This is an escape hatch for C interop. Prefer `span` for safe access.
    /// - Warning: The pointer must not escape the closure scope.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe body(UnsafeBufferPointer(start: count.rawValue > 0 ? _cachedPtr : nil, count: count.rawValue))
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
        try unsafe body(UnsafeMutableBufferPointer(start: count.rawValue > 0 ? _cachedPtr : nil, count: count.rawValue))
    }
}

// MARK: - Borrowed Element Access (for ~Copyable elements)

extension Array.Fixed where Element: ~Copyable {
    /// Accesses the element at the given index via closure (for ~Copyable elements).
    ///
    /// This method provides borrowed access to elements, enabling safe read access
    /// to move-only types without consuming them.
    ///
    /// - Parameters:
    ///   - index: The index of the element.
    ///   - body: A closure that receives a borrowed reference to the element.
    /// - Returns: The result of the closure.
    /// - Precondition: The index must be in bounds.
    @inlinable
    public func withElement<R>(at index: Index, _ body: (borrowing Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return unsafe body((_cachedPtr + index).pointee)
    }

}

// MARK: - Typed Subscript (Array.Fixed)

extension Array.Fixed where Element: ~Copyable {
    /// Accesses the element at the given typed index (borrowing access for ~Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Index) -> Element {
        _read {
            precondition(index < count, "Index out of bounds")
            yield unsafe _cachedPtr[index]
        }
        _modify {
            precondition(index < count, "Index out of bounds")
            yield &(unsafe _cachedPtr[index])
        }
    }
}

extension Array.Fixed where Element: Copyable {
    /// Accesses the element at the given typed index (copy semantics for Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Index) -> Element {
        get {
            precondition(index < count, "Index out of bounds")
            return unsafe _cachedPtr[index]
        }
        set {
            precondition(index < count, "Index out of bounds")
            unsafe _cachedPtr[index] = newValue
        }
    }
}
