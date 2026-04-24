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
public import Buffer_Linear_Primitives
public import Buffer_Linear_Small_Primitives

// MARK: - freeCapacity across Array variants
//
// Matches SE-0527's `freeCapacity` convention (number of additional elements
// that can be added without reallocating). Computed via the underlying
// `_buffer.capacity - _buffer.count` (saturating subtraction).
//
// Variants that do not currently expose a runtime `capacity` property
// (e.g., Array.Static<N>, whose capacity is the type-level generic) are
// deferred to a follow-up that also adds runtime capacity to them.

extension Array where Element: ~Copyable {

    /// The number of additional elements that can be added to this array
    /// without reallocating storage.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var freeCapacity: Array.Index.Count {
        _buffer.capacity.subtract.saturating(_buffer.count)
    }
}

extension Array.Fixed where Element: ~Copyable {

    /// Always zero — `Array.Fixed`'s invariant is `count == capacity`.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var freeCapacity: Array.Index.Count {
        _buffer.capacity.subtract.saturating(_buffer.count)
    }
}

extension Array.Small where Element: ~Copyable {

    /// The number of additional elements that can be added before triggering
    /// a spill to heap (when currently inline) or reallocation (when spilled).
    ///
    /// - Complexity: O(1)
    @inlinable
    public var freeCapacity: Array.Index.Count {
        _buffer.capacity.subtract.saturating(_buffer.count)
    }
}
