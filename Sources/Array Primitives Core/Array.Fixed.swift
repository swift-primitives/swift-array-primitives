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

// Note: Array.Fixed is declared INSIDE the Array struct body (in Array.swift)
// due to Swift's ~Copyable constraint propagation rules. This file contains
// only extensions that require internal access to _storage.

public import Index_Primitives

// MARK: - Initialization (Checked)

extension Array.Fixed {
    /// Creates a fixed array with the specified count, initializing each element.
    ///
    /// - Parameters:
    ///   - count: The number of elements.
    ///   - initializer: A closure that provides the element for each index.
    /// - Throws: `Error.invalidCount` if count is negative.
    @inlinable
    public init(
        count: Array.Index.Count,
        initializingWith initializer: (Array.Index) -> Element
    ) throws(Error) {
        guard count >= 0 else {
            throw .invalidCount(count)
        }

        if count == 0 {
            self.storage = Array.Storage.createEmpty()
            unsafe self._cachedPtr = storage.pointer(at: .zero)
            self.count = .zero
            return
        }

        self.storage = Array.Storage.create(capacity: count, initializingWith: initializer)
        unsafe self._cachedPtr = storage.pointer(at: .zero)
        self.count = count
    }
}

// MARK: - Initialization (Unchecked)

extension Array.Fixed {
    /// Creates a fixed array with the specified count without validation.
    ///
    /// Use this when the count has already been validated by an invariant.
    ///
    /// - Parameters:
    ///   - __unchecked: Marker parameter indicating unchecked operation.
    ///   - count: The number of elements. Must be non-negative.
    ///   - initializer: A closure that provides the element for each index.
    /// - Precondition: `count >= 0`
    @inlinable
    public init(
        __unchecked: Void,
        count: Array.Index.Count,
        initializingWith initializer: (Array.Index) -> Element
    ) {
        precondition(count >= 0, "Count must be non-negative")

        if count == 0 {
            self.storage = Array.Storage.createEmpty()
            unsafe self._cachedPtr = storage.pointer(at: .zero)
            self.count = .zero
            return
        }

        self.storage = Array.Storage.create(capacity: count, initializingWith: initializer)
        unsafe self._cachedPtr = storage.pointer(at: .zero)
        self.count = count
    }
}

