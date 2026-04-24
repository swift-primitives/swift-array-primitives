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
public import Buffer_Linear_Inline_Primitives
public import Buffer_Linear_Small_Primitives

// MARK: - swapAt across Array variants
//
// Each variant delegates to the underlying Buffer.Linear* variant's
// `swap(at:with:)`. The stdlib-aligned `swapAt(_:_:)` name (two unlabeled
// positional arguments) matches SE-0527 and Swift.Array's existing convention.

extension Array where Element: ~Copyable {

    /// Exchanges the elements at the two given positions.
    ///
    /// Both parameters must be valid indices and not equal to `endIndex`.
    /// Passing the same index for both has no effect.
    ///
    /// - Complexity: O(1)
    @inlinable
    public mutating func swapAt(_ i: Array.Index, _ j: Array.Index) {
        _buffer.swap(at: i, with: j)
    }
}

extension Array.Fixed where Element: ~Copyable {

    /// Exchanges the elements at the two given positions.
    ///
    /// - Complexity: O(1)
    @inlinable
    public mutating func swapAt(_ i: Array.Index, _ j: Array.Index) {
        _buffer.swap(at: i, with: j)
    }
}

extension Array.Small where Element: ~Copyable {

    /// Exchanges the elements at the two given positions.
    ///
    /// - Complexity: O(1)
    @inlinable
    public mutating func swapAt(_ i: Array.Index, _ j: Array.Index) {
        _buffer.swap(at: i, with: j)
    }
}

extension Array.Static where Element: ~Copyable {

    /// Exchanges the elements at the two given positions.
    ///
    /// - Complexity: O(1)
    @inlinable
    public mutating func swapAt(_ i: Array.Index, _ j: Array.Index) {
        _buffer.swap(at: i, with: j)
    }
}
