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

public import Buffer_Protocol_Primitives
public import Ownership_Shared_Primitive
public import Store_Protocol_Primitives

// MARK: - Array<E>.Shared — the OWNERSHIP variant ([DS-028] law 2)

extension __Array
where
    S: ~Copyable,
    S: Store.`Protocol` & Buffer.`Protocol`
{

    /// The explicit CoW (value-semantic) array: the current column boxed behind
    /// `Ownership.Shared`.
    ///
    /// This is an ownership-axis variant alias ([DS-028] law 2) — a
    /// column-PRESERVING transformer that wraps the member it is named on
    /// (`Ownership.Shared` wraps `S` unconditionally, so it chains correctly
    /// ahead of any future allocation or capacity variant; no `Store.Direct`
    /// fence — law 2 preserves `S`). Copyability flows from the element:
    /// `Array<E>.Shared` is `Copyable` exactly when `E` is; copies share the
    /// backing box until the first mutation restores uniqueness (copy-on-write).
    ///
    /// **Units/axis**: this alias changes only the OWNERSHIP axis (move-only →
    /// CoW value semantics). The element type, discipline, and allocation leaf
    /// of `S` are preserved — `Array<Payload>.Shared` over the canonical alias
    /// is `__Array<Ownership.Shared<Payload, heap-linear>>`, the identical type
    /// consumers previously spelled `__Array<Column.Shared<Payload>>`.
    ///
    /// ```swift
    /// var a = Array<Int>.Shared(minimumCapacity: 4)   // CoW value-semantic
    /// var b = a          // shares a's backing — no element copy
    /// b.append(9)        // copy-on-write: b diverges, a is untouched
    /// ```
    public typealias Shared = __Array<Ownership.Shared<S.Element, S>>
}
