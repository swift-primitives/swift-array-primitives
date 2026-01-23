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

        _storage.move(to: newStorage)
        newStorage.header = currentCount
        _storage = newStorage
        unsafe (_cachedPtr = _storage.pointer(at: 0))  // CRITICAL: Update cached pointer
    }
}

// MARK: - Copy-on-Write (package access for cross-module use)

extension Array.Unbounded where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    package mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.copy()
            unsafe (_cachedPtr = _storage.pointer(at: 0))  // CRITICAL: Update cached pointer
        }
    }
}

// MARK: - Typed Subscript
