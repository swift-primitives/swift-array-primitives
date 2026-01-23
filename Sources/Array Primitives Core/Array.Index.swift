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

extension Array where Element: ~Copyable {
    /// Type-safe index for array elements.
    ///
    /// Uses `Index<Element>` to provide compile-time safety preventing
    /// cross-collection index confusion.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let arrayIdx: Array<Int>.Index = 5
    /// var array = try Array<Int>.Bounded(count: 10) { $0 }
    /// print(array[arrayIdx])  // 5
    /// ```
    public typealias Index = Index_Primitives.Index<Element>

    /// Signed offset type for index arithmetic.
    ///
    /// Follows affine space semantics:
    /// - `index2 - index1 → offset` (displacement between indices)
    /// - `index + offset → index?` (translation, nil if negative result)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let idx: Array<Int>.Index = try Array<Int>.Index(5)
    /// let offset: Array<Int>.Offset = 3
    /// let newIdx = (idx + offset)!  // Index at position 8
    /// ```
    public typealias Offset = Index_Primitives.Index<Element>.Offset
}

