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
public import Store_Protocol_Primitives

extension __Array where S: Store.`Protocol` & ~Copyable {
    // swift-linter:disable:next namespace adoption typealias
    // REASON: Adoption confirmed (issue #9 ruling). `__Array` declares far more than five
    // members keyed on `Index` — subscript, withElement, startIndex/endIndex,
    // index(after:)/index(before:), remove(at:), swap(at:with:), insert(_:at:),
    // element(at:offsetBy:), and the Index.Count-typed count/capacity/freeCapacity.
    // This is namespace adoption per [API-NAME-004a], not a rename bridge.
    // swift-linter:disable:next typealiased namespace bridge
    // REASON: Collision grep clean at #9-ruling time — this package declares NO type at
    // `__Array.Index.<X>`; every `Index.`-qualified use in Sources reads a foreign member
    // (`Index.Count`, `Index.Offset`). Re-run the foreign-module collision grep before adding
    // any sub-type through this aliased path.
    /// Type-safe index for array elements — typed by the COLUMN's element (the user element
    /// on both ratified columns), preventing cross-collection index confusion.
    public typealias Index = Index_Primitives.Index<S.Element>
}
