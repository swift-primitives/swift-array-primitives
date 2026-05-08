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
public import Finite_Primitives_Core

// MARK: - Bounded Index

extension Array.Bounded where Element: ~Copyable {
    /// Type-safe bounded index for bounded array elements.
    ///
    /// `Array<Element>.Bounded<N>.Index` is `Index<Element>.Bounded<N>` — a
    /// phantom-typed bounded-linear ordinal in `[0, N)`. The `Element` phantom
    /// tag matches the family-wide `Array<Element>.Index = Index<Element>`
    /// pattern; the `N` capacity bound provides compile-time dimension safety.
    ///
    /// Indices are bounds-checked at construction, not at subscript access.
    /// Once an index is constructed, subscripting with it is guaranteed safe.
    ///
    /// ## Type Structure
    ///
    /// ```
    /// Array<Element>.Bounded<N>.Index
    /// = Index<Element>.Bounded<N>
    /// = Tagged<Element, Ordinal.Finite<N>>
    /// ```
    ///
    /// ## Type-Level Index Separation
    ///
    /// Indices from different bounded arrays are distinct types:
    /// `Array<Int>.Bounded<3>.Index` ≠ `Array<Int>.Bounded<5>.Index`.
    public typealias Index = Index_Primitives.Index<Element>.Bounded<N>
}
