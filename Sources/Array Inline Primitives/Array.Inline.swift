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

public import Array_Primitive

extension Array where Element: ~Copyable {

    // MARK: - Inline (Typealias to Swift.InlineArray)

    /// Fixed-count inline array (typealias to `Swift.InlineArray`).
    ///
    /// All N elements are always initialized. For variable-count inline
    /// storage (0 to capacity elements), use ``Array/Static`` instead.
    ///
    /// ## Comparison
    ///
    /// | Type | Count | Storage | Heap |
    /// |------|-------|---------|------|
    /// | `Array.Inline<N>` | Fixed (always N) | Inline | No |
    /// | `Array.Static<N>` | Variable (0..N) | Inline | No |
    /// | `Array.Bounded<N>` | Fixed (always N) | Heap (CoW) | Yes |
    public typealias Inline<let N: Int> = Swift.InlineArray<N, Element>
}
