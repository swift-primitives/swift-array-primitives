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

// Note: Array.Unbounded is declared INSIDE the Array enum body (in Array.swift)
// due to Swift's ~Copyable constraint propagation rules. This file contains
// only the minimal extensions required for the workaround. Public API is in
// the Array Unbounded Primitives module.

import Index_Primitives

// MARK: - Count (package access for Core - subscripts use this)

extension Array.Unbounded where Element: ~Copyable {
    /// The number of elements in the array (package access for Core subscripts).
    @usableFromInline
    package var _rawCount: Int { _storage.header }
}

// MARK: - Capacity Management (package access for cross-module use)

extension Array.Unbounded where Element: ~Copyable {
    /// Ensures the array has capacity for at least the specified number of elements.
    @usableFromInline
    package mutating func _ensureCapacity(_ minimumCapacity: Int) {
        guard _storage.capacity < minimumCapacity else { return }

        // Growth factor 2.0, minimum capacity from hint or 4
        let newCapacity = Swift.max(minimumCapacity, _storage.capacity * 2, N, 4)
        let newStorage = Array.Storage.create(minimumCapacity: newCapacity)
        let currentCount = _storage.header

        _storage._moveAllElements(to: newStorage)
        newStorage.header = currentCount
        _storage = newStorage
        unsafe (_cachedPtr = _storage._elementsPointer)  // CRITICAL: Update cached pointer
    }
}

// MARK: - Copy-on-Write (package access for cross-module use)

extension Array.Unbounded where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    package mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.copy()
            unsafe (_cachedPtr = _storage._elementsPointer)  // CRITICAL: Update cached pointer
        }
    }
}

// MARK: - Safe Element Access

extension Array.Unbounded where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Array<Element>.Index) -> Element? {
        guard index.position.rawValue < _rawCount else { return nil }
        return unsafe _cachedPtr[index.position.rawValue]
    }

    /// Returns element at index offset from given base index.
    ///
    /// - Parameters:
    ///   - base: The starting index.
    ///   - offset: The signed offset from the base.
    /// - Returns: The element at the computed position, or `nil` if out of bounds.
    @inlinable
    public func element(at base: Array<Element>.Index, offsetBy offset: Array<Element>.Offset) -> Element? {
        guard let newIndex = base + offset else { return nil }
        guard newIndex.position.rawValue < _rawCount else { return nil }
        return unsafe _cachedPtr[newIndex.position.rawValue]
    }
}

// MARK: - Typed Subscript

extension Array.Unbounded where Element: ~Copyable {
    /// Accesses the element at the given typed index.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Array<Element>.Index) -> Element {
        _read {
            precondition(index.position.rawValue < _rawCount, "Index out of bounds")
            yield unsafe _cachedPtr[index.position.rawValue]
        }
        _modify {
            precondition(index.position.rawValue < _rawCount, "Index out of bounds")
            yield &(unsafe _cachedPtr[index.position.rawValue])
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
            precondition(index.position.rawValue < _rawCount, "Index out of bounds")
            return unsafe _cachedPtr[index.position.rawValue]
        }
        set {
            makeUnique()
            precondition(index.position.rawValue < _rawCount, "Index out of bounds")
            unsafe _cachedPtr[index.position.rawValue] = newValue
        }
    }
}
