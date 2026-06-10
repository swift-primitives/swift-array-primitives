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

public import Array_Fixed_Primitives

// MARK: - freeCapacity on Array.Fixed
//
// The base Array's `freeCapacity` is COLUMN-GENERIC (seam capacity − count, saturating)
// and lives in `Array ~Copyable.swift`.

extension Array.Fixed where S: ~Copyable {

    /// Always zero — `Array.Fixed`'s invariant is `count == capacity`.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var freeCapacity: Array<S>.Index.Count {
        _buffer.capacity.subtract.saturating(_buffer.count)
    }
}
