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

// MARK: - swap on Array.Fixed
//
// The base Array's `swap(at:with:)` is COLUMN-GENERIC (gate + seam dance) and lives in
// `Array ~Copyable.swift`. `Array.Fixed` wraps the bounded buffer directly, so it
// delegates to the buffer's `swap(at:with:)`.

extension Array.Fixed where S: ~Copyable {

    /// Exchanges the elements at the two given positions.
    ///
    /// Both parameters must be valid indices and not equal to `endIndex`.
    /// Passing the same index for both has no effect.
    ///
    /// - Complexity: O(1)
    @inlinable
    public mutating func swap(at i: Array<S>.Index, with j: Array<S>.Index) {
        _buffer.swap(at: i, with: j)
    }
}
