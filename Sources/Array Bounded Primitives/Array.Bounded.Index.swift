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
public import Finite_Primitives

// MARK: - Bounded Index

public import Array_Bounded_Primitive

extension Array.Bounded where S: ~Copyable {
    /// Type-safe bounded index for bounded array elements.
    ///
    /// `Array<S>.Bounded<N>.Index` is `Index<S.Element>.Bounded<N>` — a
    /// phantom-typed bounded-linear ordinal in `[0, N)`. The element phantom
    /// tag matches the family-wide `Array<S>.Index = Index<S.Element>`
    /// pattern; the `N` capacity bound provides compile-time dimension safety.
    ///
    /// Indices are bounds-checked at construction, not at subscript access.
    /// Once an index is constructed, subscripting with it is guaranteed safe.
    ///
    /// ## Type Structure
    ///
    /// ```
    /// Array<S>.Bounded<N>.Index
    /// = Index<S.Element>.Bounded<N>
    /// = Tagged<S.Element, Ordinal.Finite<N>>
    /// ```
    ///
    /// ## Type-Level Index Separation
    ///
    /// Indices from different bounded arrays are distinct types:
    /// `Array<…Int…>.Bounded<3>.Index` ≠ `Array<…Int…>.Bounded<5>.Index`.
    public typealias Index = Index_Primitives.Index<S.Element>.Bounded<N>
}
