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

public import Index_Primitives

extension Array where Element: ~Copyable {
    /// Type-safe index for array elements.
    ///
    /// Uses `Index<Element>` to provide compile-time safety preventing
    /// cross-collection index confusion.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let arrayIdx: Array<Int>.Index = 5
    /// var array = try Array<Int>.Bounded(count: 10) { $0 }
    /// print(array[arrayIdx])  // 5
    /// ```
    public typealias Index = Index_Primitives.Index<Element>

    /// Signed offset type for index arithmetic.
    ///
    /// Follows affine space semantics:
    /// - `index2 - index1 → offset` (displacement between indices)
    /// - `index + offset → index?` (translation, nil if negative result)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let idx: Array<Int>.Index = try Array<Int>.Index(5)
    /// let offset: Array<Int>.Offset = 3
    /// let newIdx = (idx + offset)!  // Index at position 8
    /// ```
    public typealias Offset = Index_Primitives.Index<Element>.Offset
}

// MARK: - Typed Subscript (Array.Bounded)

extension Array.Bounded where Element: ~Copyable {
    /// Accesses the element at the given typed index (borrowing access for ~Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Array<Element>.Index) -> Element {
        _read {
            precondition(index < _count, "Index out of bounds")
            yield unsafe storage[index.position.rawValue]
        }
        _modify {
            precondition(index < _count, "Index out of bounds")
            yield &(unsafe storage[index.position.rawValue])
        }
    }
}

extension Array.Bounded where Element: Copyable {
    /// Accesses the element at the given typed index (copy semantics for Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Array<Element>.Index) -> Element {
        get {
            precondition(index < _count, "Index out of bounds")
            return unsafe storage[index.position.rawValue]
        }
        set {
            precondition(index < _count, "Index out of bounds")
            unsafe storage[index.position.rawValue] = newValue
        }
    }
}

// MARK: - Typed Subscript (Array.Unbounded)

extension Array.Unbounded where Element: ~Copyable {
    /// Accesses the element at the given typed index.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Array<Element>.Index) -> Element {
        _read {
            precondition(index < count, "Index out of bounds")
            yield _cachedPtr[index.position.rawValue]
        }
        _modify {
            precondition(index < count, "Index out of bounds")
            yield &_cachedPtr[index.position.rawValue]
        }
    }
}

extension Array.Unbounded where Element: Copyable {
    /// Accesses the element at the given typed index with copy-on-write semantics.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Array<Element>.Index) -> Element {
        get {
            precondition(index < count, "Index out of bounds")
            return _cachedPtr[index.position.rawValue]
        }
        set {
            makeUnique()
            precondition(index < count, "Index out of bounds")
            _cachedPtr[index.position.rawValue] = newValue
        }
    }
}

// MARK: - Typed Subscript (Array.Inline)

extension Array.Inline where Element: ~Copyable {
    /// Accesses the element at the given typed index (borrowing access for ~Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Array<Element>.Index) -> Element {
        _read {
            precondition(index < _count, "Index out of bounds")
            yield unsafe _readPointerToElement(at: index.position.rawValue).pointee
        }
        _modify {
            precondition(index < _count, "Index out of bounds")
            yield &(unsafe _pointerToElement(at: index.position.rawValue).pointee)
        }
    }
}

extension Array.Inline where Element: Copyable {
    /// Accesses the element at the given typed index (copy semantics for Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Array<Element>.Index) -> Element {
        get {
            precondition(index < _count, "Index out of bounds")
            return unsafe _readPointerToElement(at: index.position.rawValue).pointee
        }
        set {
            precondition(index < _count, "Index out of bounds")
            unsafe _pointerToElement(at: index.position.rawValue).pointee = newValue
        }
    }
}

// MARK: - Typed Subscript (Array.Small)

extension Array.Small where Element: ~Copyable {
    /// Accesses the element at the given typed index (borrowing access for ~Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Array<Element>.Index) -> Element {
        _read {
            precondition(index < _count, "Index out of bounds")
            if let heapPtr = _heapPtr {
                yield unsafe heapPtr[index.position.rawValue]
            } else {
                yield unsafe _inlineReadPointerToElement(at: index.position.rawValue).pointee
            }
        }
        _modify {
            precondition(index < _count, "Index out of bounds")
            if let heapPtr = _heapPtr {
                yield &(unsafe heapPtr[index.position.rawValue])
            } else {
                yield &(unsafe _inlinePointerToElement(at: index.position.rawValue).pointee)
            }
        }
    }
}

extension Array.Small where Element: Copyable {
    /// Accesses the element at the given typed index (copy semantics for Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Array<Element>.Index) -> Element {
        get {
            precondition(index < _count, "Index out of bounds")
            if let heapPtr = _heapPtr {
                return unsafe heapPtr[index.position.rawValue]
            } else {
                return unsafe _inlineReadPointerToElement(at: index.position.rawValue).pointee
            }
        }
        set {
            precondition(index < _count, "Index out of bounds")
            if _heapStorage != nil {
                _ = _heapStorage!._moveElement(at: index.position.rawValue)
                _heapStorage!._initializeElement(at: index.position.rawValue, to: newValue)
            } else {
                unsafe _inlinePointerToElement(at: index.position.rawValue).pointee = newValue
            }
        }
    }
}

// MARK: - Bounded Index (Inline Arrays)

extension Array.Inline where Element: ~Copyable {
    /// Bounded index type for inline arrays.
    ///
    /// Guarantees index is in `0..<capacity` at compile time,
    /// eliminating runtime bounds checks for subscript access.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var inline = Array<Int>.Inline<8>()
    /// // Fill with 8 elements...
    /// let idx: Array<Int>.Inline<8>.BoundedIndex = 3
    /// print(inline[idx])  // No runtime bounds check
    /// ```
    public typealias BoundedIndex = Index_Primitives.Index<Element>.Bounded<capacity>
}

extension Array.Inline where Element: ~Copyable {
    /// Accesses the element at the given bounded index (no runtime bounds check).
    ///
    /// - Parameter index: A bounded index guaranteed to be in `0..<capacity`.
    /// - Precondition: The array must have at least `index.rawValue + 1` elements.
    @inlinable
    public subscript(index: BoundedIndex) -> Element {
        _read {
            precondition(index.rawValue < _count.rawValue, "Index exceeds current count")
            yield unsafe _readPointerToElement(at: index.rawValue).pointee
        }
        _modify {
            precondition(index.rawValue < _count.rawValue, "Index exceeds current count")
            yield &(unsafe _pointerToElement(at: index.rawValue).pointee)
        }
    }
}

// MARK: - Offset Navigation

extension Array.Bounded where Element: Copyable {
    /// Returns element at index offset from given base index.
    ///
    /// - Parameters:
    ///   - base: The starting index.
    ///   - offset: The signed offset from the base.
    /// - Returns: The element at the computed position, or `nil` if out of bounds.
    @inlinable
    public func element(at base: Array<Element>.Index, offsetBy offset: Array<Element>.Offset) -> Element? {
        guard let newIndex = base + offset else { return nil }
        guard newIndex < _count else { return nil }
        return unsafe storage[newIndex.position.rawValue]
    }
}

extension Array.Unbounded where Element: Copyable {
    /// Returns element at index offset from given base index.
    ///
    /// - Parameters:
    ///   - base: The starting index.
    ///   - offset: The signed offset from the base.
    /// - Returns: The element at the computed position, or `nil` if out of bounds.
    @inlinable
    public func element(at base: Array<Element>.Index, offsetBy offset: Array<Element>.Offset) -> Element? {
        guard let newIndex = base + offset else { return nil }
        guard newIndex < count else { return nil }
        return _cachedPtr[newIndex.position.rawValue]
    }
}

extension Array.Inline where Element: Copyable {
    /// Returns element at index offset from given base index.
    ///
    /// - Parameters:
    ///   - base: The starting index.
    ///   - offset: The signed offset from the base.
    /// - Returns: The element at the computed position, or `nil` if out of bounds.
    @inlinable
    public func element(at base: Array<Element>.Index, offsetBy offset: Array<Element>.Offset) -> Element? {
        guard let newIndex = base + offset else { return nil }
        guard newIndex < _count else { return nil }
        return unsafe _readPointerToElement(at: newIndex.position.rawValue).pointee
    }
}

extension Array.Small where Element: Copyable {
    /// Returns element at index offset from given base index.
    ///
    /// - Parameters:
    ///   - base: The starting index.
    ///   - offset: The signed offset from the base.
    /// - Returns: The element at the computed position, or `nil` if out of bounds.
    @inlinable
    public func element(at base: Array<Element>.Index, offsetBy offset: Array<Element>.Offset) -> Element? {
        guard let newIndex = base + offset else { return nil }
        guard newIndex < _count else { return nil }
        if let heapPtr = _heapPtr {
            return unsafe heapPtr[newIndex.position.rawValue]
        } else {
            return unsafe _inlineReadPointerToElement(at: newIndex.position.rawValue).pointee
        }
    }
}

// MARK: - Safe Access

extension Array.Bounded where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Array<Element>.Index) -> Element? {
        guard index < _count else { return nil }
        return unsafe storage[index.position.rawValue]
    }
}

extension Array.Unbounded where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Array<Element>.Index) -> Element? {
        guard index < count else { return nil }
        return _cachedPtr[index.position.rawValue]
    }
}

extension Array.Inline where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Array<Element>.Index) -> Element? {
        guard index < _count else { return nil }
        return unsafe _readPointerToElement(at: index.position.rawValue).pointee
    }
}

extension Array.Small where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Array<Element>.Index) -> Element? {
        guard index < _count else { return nil }
        if let heapPtr = _heapPtr {
            return unsafe heapPtr[index.position.rawValue]
        } else {
            return unsafe _inlineReadPointerToElement(at: index.position.rawValue).pointee
        }
    }
}
