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
}

// MARK: - Typed Subscript (Array.Bounded)

extension Array.Bounded where Element: ~Copyable {
    /// Accesses the element at the given typed index.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index.position.rawValue` must be in `0..<count`.
    @inlinable
    public subscript(index: Array<Element>.Index) -> Element {
        _read {
            precondition(index.position.rawValue >= 0 && index.position.rawValue < count, "Index out of bounds")
            yield unsafe storage[index.position.rawValue]
        }
        _modify {
            precondition(index.position.rawValue >= 0 && index.position.rawValue < count, "Index out of bounds")
            yield &(unsafe storage[index.position.rawValue])
        }
    }
}

// MARK: - Typed Subscript (Array.Unbounded)

extension Array.Unbounded where Element: ~Copyable {
    /// Accesses the element at the given typed index.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index.position.rawValue` must be in `0..<count`.
    @inlinable
    public subscript(index: Array<Element>.Index) -> Element {
        _read {
            precondition(index.position.rawValue >= 0 && index.position.rawValue < count, "Index out of bounds")
            yield _cachedPtr[index.position.rawValue]
        }
        _modify {
            precondition(index.position.rawValue >= 0 && index.position.rawValue < count, "Index out of bounds")
            yield &_cachedPtr[index.position.rawValue]
        }
    }
}

extension Array.Unbounded where Element: Copyable {
    /// Accesses the element at the given typed index with copy-on-write semantics.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index.position.rawValue` must be in `0..<count`.
    @inlinable
    public subscript(index: Array<Element>.Index) -> Element {
        _read {
            precondition(index.position.rawValue >= 0 && index.position.rawValue < count, "Index out of bounds")
            yield _cachedPtr[index.position.rawValue]
        }
        _modify {
            makeUnique()
            precondition(index.position.rawValue >= 0 && index.position.rawValue < count, "Index out of bounds")
            yield &_cachedPtr[index.position.rawValue]
        }
    }
}

// MARK: - Typed Subscript (Array.Inline)

extension Array.Inline where Element: ~Copyable {
    /// Accesses the element at the given typed index.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index.position.rawValue` must be in `0..<count`.
    @inlinable
    public subscript(index: Array<Element>.Index) -> Element {
        _read {
            precondition(index.position.rawValue >= 0 && index.position.rawValue < _count, "Index out of bounds")
            yield unsafe _readPointerToElement(at: index.position.rawValue).pointee
        }
        _modify {
            precondition(index.position.rawValue >= 0 && index.position.rawValue < _count, "Index out of bounds")
            yield &(unsafe _pointerToElement(at: index.position.rawValue).pointee)
        }
    }
}

// MARK: - Typed Subscript (Array.Small)

extension Array.Small where Element: ~Copyable {
    /// Accesses the element at the given typed index.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index.position.rawValue` must be in `0..<count`.
    @inlinable
    public subscript(index: Array<Element>.Index) -> Element {
        _read {
            precondition(index.position.rawValue >= 0 && index.position.rawValue < _count, "Index out of bounds")
            if let heapPtr = _heapPtr {
                yield unsafe heapPtr[index.position.rawValue]
            } else {
                yield unsafe _inlineReadPointerToElement(at: index.position.rawValue).pointee
            }
        }
        _modify {
            precondition(index.position.rawValue >= 0 && index.position.rawValue < _count, "Index out of bounds")
            if let heapPtr = _heapPtr {
                yield &(unsafe heapPtr[index.position.rawValue])
            } else {
                yield &(unsafe _inlinePointerToElement(at: index.position.rawValue).pointee)
            }
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
        guard index.position.rawValue >= 0 && index.position.rawValue < count else { return nil }
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
        guard index.position.rawValue >= 0 && index.position.rawValue < count else { return nil }
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
        guard index.position.rawValue >= 0 && index.position.rawValue < _count else { return nil }
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
        guard index.position.rawValue >= 0 && index.position.rawValue < _count else { return nil }
        if let heapPtr = _heapPtr {
            return unsafe heapPtr[index.position.rawValue]
        } else {
            return unsafe _inlineReadPointerToElement(at: index.position.rawValue).pointee
        }
    }
}
