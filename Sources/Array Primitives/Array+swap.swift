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

public import Buffer_Linear_Primitives
public import Index_Primitives

// MARK: - swap across Array variants
//
// Each variant delegates to the underlying Buffer.Linear* variant's
// `swap(at:with:)`. Labeled form (`swap(at:with:)`) matches the Buffer.Linear
// API one layer down and complies with [API-NAME-002] (the method name is
// `swap`, a single word; `at:` / `with:` are standard argument labels).

extension Array where Element: ~Copyable {

    /// Exchanges the elements at the two given positions.
    ///
    /// Both parameters must be valid indices and not equal to `endIndex`.
    /// Passing the same index for both has no effect.
    ///
    /// - Complexity: O(1)
    @inlinable
    public mutating func swap(at i: Array.Index, with j: Array.Index) {
        _buffer.swap(at: i, with: j)
    }
}

extension Array.Fixed where Element: ~Copyable {

    /// Exchanges the elements at the two given positions.
    ///
    /// - Complexity: O(1)
    @inlinable
    public mutating func swap(at i: Array.Index, with j: Array.Index) {
        _buffer.swap(at: i, with: j)
    }
}


