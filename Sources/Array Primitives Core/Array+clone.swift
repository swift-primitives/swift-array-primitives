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

// MARK: - Array + clone (Copyable elements)

extension Array where Element: Copyable {

    /// Returns an independent copy of this array with its own storage, sized
    /// to exactly fit the current count of elements.
    ///
    /// Matches SE-0527's `clone()` convention. Unlike CoW value-semantic
    /// assignment (`var new = self`), which may share storage until mutation,
    /// `clone()` always allocates new storage.
    ///
    /// - Complexity: O(`count`)
    @inlinable
    public func clone() -> Self {
        var result = self
        result._buffer = _buffer.clone()
        return result
    }

    /// Returns an independent copy of this array with its own storage
    /// allocated to the specified capacity.
    ///
    /// - Parameter capacity: The desired capacity of the resulting array.
    ///     Must be greater than or equal to `count`.
    ///
    /// - Complexity: O(`count`)
    /// - Precondition: `capacity >= count`
    @inlinable
    public func clone(capacity: Array.Index.Count) -> Self {
        var result = self
        result._buffer = _buffer.clone(capacity: capacity)
        return result
    }
}
