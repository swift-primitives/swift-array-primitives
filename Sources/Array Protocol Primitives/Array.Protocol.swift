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

// MARK: - Array.Protocol (Hoisted as __ArrayProtocol)

/// Protocol unifying element access across all Array variants.
///
/// See ``Array.`Protocol``` for documentation.
public import Array_Primitive
public import Collection_Primitives

public protocol __ArrayProtocol: Collection.Bidirectional & ~Copyable {
    /// Accesses the element at the given position.
    subscript(_ position: Index) -> Element { get set }
}

// MARK: - Namespace Typealias

extension Array where Element: ~Copyable {
    /// Protocol unifying element access across all `Array` variants.
    ///
    /// `Array.Protocol` (accessed as `Array.Protocol`) refines `Collection.Bidirectional`
    /// with `associatedtype Element: ~Copyable` and subscript access. This enables:
    ///
    /// - Generic functions over any Array variant
    /// - Default `forEach` (element iteration) and `withElement` for all conformers
    /// - Compile-time API parity enforcement
    ///
    /// ## Hoisted Protocol Pattern
    ///
    /// Swift does not allow nesting a protocol inside a generic type. This protocol
    /// is declared at module scope as `Array.Protocol` and aliased via:
    ///
    /// ```swift
    /// extension Array {
    ///     public typealias `Protocol` = Array.Protocol
    /// }
    /// ```
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
    /// - `var isEmpty: Bool` (default from `Collection.Indexed`)
    ///
    /// ## Generic Usage
    ///
    /// ```swift
    /// func iterate<V: Array.Protocol & ~Copyable>(
    ///     _ v: borrowing V
    /// ) where V.Element == Int {
    ///     v.forEach { print($0) }
    /// }
    /// ```
    public typealias `Protocol` = __ArrayProtocol
}
