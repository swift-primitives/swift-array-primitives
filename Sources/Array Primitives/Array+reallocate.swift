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

// MARK: - reallocate on dynamic Array

extension Array where Element: ~Copyable {

    /// Grows or shrinks the array's storage to exactly the specified capacity,
    /// preserving existing elements.
    ///
    /// Matches SE-0527's `reallocate(capacity:)` convention. Unlike
    /// `reserveCapacity`, which only grows, `reallocate` can also shrink
    /// storage, freeing memory when the array is holding more capacity than
    /// needed.
    ///
    /// When `Element: Copyable`, Buffer.Linear's CoW-aware shadow is dispatched
    /// automatically.
    ///
    /// Fixed-capacity variants (Array.Fixed, Array.Bounded) do not support
    /// this API: their capacity is an invariant of the type or a compile-time
    /// parameter.
    ///
    /// - Parameter newCapacity: The desired new capacity. Must be greater than
    ///     or equal to the current `count`.
    /// - Precondition: `newCapacity >= count`
    /// - Complexity: O(`count`)
    @inlinable
    public mutating func reallocate(capacity newCapacity: Array.Index.Count) {
        _buffer.reallocate(capacity: newCapacity)
    }
}
