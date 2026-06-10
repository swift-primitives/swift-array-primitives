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

public import Store_Protocol_Primitives
public import Buffer_Protocol_Primitives
public import Index_Primitives

// MARK: - Fixed (the always-full discipline over a non-growable COLUMN)

/// A fixed-count array that is always fully initialized — the thin, column-generic
/// always-full ADT (the Q3-B ruling, 2026-06-10).
///
/// `Fixed` carries exactly ONE invariant above its column: `count == capacity`, established
/// at construction and preserved by the surface (no remove/grow ops exist; `swap` and the
/// subscript replace in place). Everything else — element access, the mutation gate, the
/// Collection lattice — is the same seam-generic machinery as `Array<S>`.
///
/// The canonical column is the non-growable bounded buffer:
///
/// ```swift
/// Fixed<Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear.Bounded>
/// ```
///
/// Copyability flows from the column (S5): a `Shared`-wrapped bounded column yields a CoW
/// value-semantic fixed array with zero `Fixed`-side machinery.
@frozen
public struct Fixed<S: Store.`Protocol` & Buffer.`Protocol` & ~Copyable>: ~Copyable
where S.Count == Index_Primitives.Index<S.Element>.Count {

    /// The storage column. The always-full invariant (`count == capacity`) holds from
    /// construction onward.
    @usableFromInline
    package var store: S

    /// Wraps an existing FULL column.
    ///
    /// - Precondition: `store.count == store.capacity` (the always-full invariant).
    @inlinable
    public init(store: consuming S) {
        precondition(store.count == store.capacity, "Fixed requires an always-full column")
        self.store = store
    }
}

// MARK: - Conditional Conformances (co-located per [COPY-FIX-004])

extension Fixed: Copyable where S: Copyable {}

extension Fixed: Sendable where S: Sendable & ~Copyable {}

// MARK: - Index

extension Fixed where S: ~Copyable {
    /// Type-safe index for fixed-array elements, typed by the column's element.
    public typealias Index = Index_Primitives.Index<S.Element>
}
