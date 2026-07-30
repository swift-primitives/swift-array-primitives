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

// MARK: - Indexable (top-level capability protocol; formerly hoisted as __ArrayProtocol)

public import Array_Primitive
public import Collection_Primitives

/// Protocol unifying element access across all `Array` variants.
///
/// `Indexable` refines `Collection.Bidirectional` with `associatedtype Element: ~Copyable`
/// and subscript access. This enables:
///
/// - Generic functions over any Array variant
/// - Default `forEach` (element iteration) and `withElement` for all conformers
/// - Compile-time API parity enforcement
///
/// ## Why this is a top-level name, not a nested `Array.Protocol`
///
/// `Array` is a [DS-028] generic front-door typealias (`Array.FrontDoor.swift`), not a
/// namespace: member-type lookup does not look through an unbound generic typealias on
/// any toolchain (swift-institute/Issues#81), so `Array` has no `Array.Protocol` spelling
/// to nest into. A nested `extension Array { public typealias `Protocol` = ... }` never
/// type-checks against the unbound `Array<Element>` alias and has never had a working
/// consumer. The capability protocol therefore stays top-level and non-underscored, as
/// `Iterable`, `Buildable`, and `Initiable` already do.
///
/// `__ArrayProtocol` remains as a compatibility alias for this protocol.
///
/// ## Key Enabler
///
/// `associatedtype Element: ~Copyable` is enabled by the `SuppressedAssociatedTypes`
/// experimental feature flag.
///
/// ## Subscript Compiler Workaround
///
/// The protocol declares `subscript { get set }`. Conformers with `~Copyable` elements
/// use `_read`/`_modify` coroutines, which satisfy `get`/`set` requirements.
/// Protocol subscripts cannot declare `{ _read _modify }` directly.
///
/// ## Inherited from Collection.Bidirectional
///
/// - `associatedtype Index: Comparison.Protocol`
/// - `var startIndex: Index { get }`
/// - `var endIndex: Index { get }`
/// - `func index(after i: Index) -> Index`
/// - `func index(before i: Index) -> Index`
/// - `var isEmpty: Bool` (default from `Collection.Protocol`)
///
/// ## Generic Usage
///
/// ```swift
/// func iterate<V: Indexable & ~Copyable>(
///     _ v: borrowing V
/// ) where V.Element == Int {
///     v.forEach { print($0) }
/// }
/// ```
@_documentation(visibility: public)
public protocol Indexable: Collection.Bidirectional & ~Copyable {
    /// The number of elements in the array, as the array's typed count.
    ///
    /// Required here (rather than inherited) so the hoisted `endIndex` default
    /// resolves to each variant's O(1) count, not Collection.Protocol's O(n)
    /// index-walk (which would recurse through `endIndex`).
    var count: Index_Primitives.Index<Element>.Count { get }

    /// Accesses the element at the given position.
    subscript(_ position: Index) -> Element { get set }
}

// MARK: - Compatibility alias

/// Retained for source compatibility with call sites written against the pre-hoist name.
public typealias __ArrayProtocol = Indexable
