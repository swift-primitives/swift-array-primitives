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

// MARK: - reserveCapacity on dynamic Array

extension Array where Element: ~Copyable {

    /// Ensures that this array has at least `minimumCapacity` slots allocated,
    /// growing storage if necessary.
    ///
    /// When `Element: Copyable`, Buffer.Linear's CoW-aware shadow is dispatched
    /// automatically: a copy is made before reallocating if storage is shared.
    ///
    /// Matches SE-0527's reserveCapacity semantics and Swift.Array's
    /// established convention. Fixed-capacity variants (Array.Fixed,
    /// Array.Bounded) do not support this API because their capacity is an
    /// invariant of the type or a compile-time parameter.
    ///
    /// - Complexity: O(`count`) when growth occurs; O(1) otherwise.
    @inlinable
    public mutating func reserveCapacity(_ minimumCapacity: Array.Index.Count) {
        _buffer.reserveCapacity(minimumCapacity)
    }
}
