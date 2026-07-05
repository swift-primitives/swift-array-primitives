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

public import Buffer_Primitive
public import Buffer_Linear_Primitive
public import Storage_Contiguous_Primitives
public import Memory_Heap_Primitives
public import Memory_Allocator_Primitive
public import Memory_Allocator_Protocol_Primitives
public import Ownership_Shared_Primitive
public import Index_Primitives

// MARK: - Array (the ADT tier — generic over the COLUMN)

/// A growable array — the semantic ADT over an explicit storage COLUMN.
///
/// The ratified two-column design (`PROPOSAL-tower-perfected-design.md` §1.3): `__Array` is
/// generic over `S`, and **copyability flows from the column** (S5):
///
/// ```swift
/// __Array<            Buffer<Storage<…System>.Contiguous<FD >>.Linear >    // zero-cost MOVE-ONLY (default)
/// __Array<Ownership.Shared<Int, Buffer<Storage<…System>.Contiguous<Int>>.Linear>>   // explicit CoW value semantics
/// ```
///
/// Both columns expose the USER element as `S.Element` (the direct buffer's element IS the
/// user element; `Shared`'s direct `Element` parameter is welded to its buffer's), so the
/// element-generic surface (subscript, `count`, iteration) lives here generically; only
/// construction, growth, and CoW-checked mutation pin per column (mechanic #2). The
/// element-keyed semantics chain from the `Shared` carrier:
/// `__Array<S>: Equatable where S: Equatable`.
///
/// ## Carrier (hoisted per [API-IMPL-009]/[PKG-NAME-006])
///
/// `__Array` is the bound-free carrier ([DS-025]): its column parameter `S` is bound
/// `~Copyable` **only**; every capability (observability, the seam element ops,
/// construction/growth) attaches by conditional `@inlinable` extension keyed on the
/// seams the column conforms. The PUBLIC spelling of the family is the front-door alias
/// `Array<E>` (canonical), declared in `Array.FrontDoor.swift` ([DS-028]); the hoisted
/// name never appears in consumer signatures.
///
/// The canonical `Array<E>` front door shadows `Swift.Array`: bare `Array` resolves to it
/// when any module in the ecosystem is imported; use `Swift.Array` or `[T]` syntax for the
/// stdlib array.
@_documentation(visibility: public)
@frozen
public struct __Array<S: ~Copyable>: ~Copyable {

    /// The storage column — a move-only buffer (the default ownership column) or a `Shared`
    /// CoW column. The ADT is a thin semantic discipline over it; it carries NO deinit
    /// (teardown lives in the leaf's oracle / the shared box's drain).
    @usableFromInline
    package var store: S

    /// Wraps an existing column.
    @inlinable
    public init(store: consuming S) {
        self.store = store
    }

    /// Consumes the array, yielding its storage column.
    ///
    /// `@inlinable` is enabled by `@frozen` (the Q4 sweep): cross-module partial
    /// consumption of a frozen struct is legal, so the unwrap specializes at the
    /// call site.
    @inlinable
    public consuming func take() -> S {
        store
    }
}

// MARK: - Conditional Conformances (co-located per [COPY-FIX-004])

/// The S5 chain: `__Array<Ownership.Shared<E, B>>` is `Copyable` exactly when `Shared` is — i.e. when the
/// ELEMENT is. The direct (move-only buffer) columns never satisfy this, by design.
extension __Array: Copyable where S: Copyable {}

extension __Array: Sendable where S: Sendable & ~Copyable {}

// MARK: - Column-pinned construction

extension __Array where S: ~Copyable {
    /// Creates an empty MOVE-ONLY array (the default ownership column, any growable backing).
    ///
    /// Generic over the fresh-byte-construction capability `Memory.Growable`, so this serves the
    /// dense-heap column (`Memory.Heap`) AND the inline⊕heap small column (`Memory.Small<n>`)
    /// uniformly. For the small column, `initialCapacity` sizes the inline budget; growth past it
    /// re-runs the spill decision and relocates into a heap region.
    @inlinable
    public init<E: ~Copyable, Resource: Memory.Growable & ~Copyable>(initialCapacity: Index_Primitives.Index<E>.Count = .zero)
    where S == Buffer<Storage<Memory.Allocator<Resource>>.Contiguous<E>>.Linear {
        self.init(store: S(minimumCapacity: initialCapacity))
    }

    /// Creates an empty CoW (value-semantic) array on the `Shared` column.
    ///
    /// The element must be statically `Copyable` HERE: the construction site is where the
    /// column's clone strategy is captured (`Shared`'s constructors split on element
    /// copyability — see `unshare`'s backstop).
    @inlinable
    public init<E>(initialCapacity: Index_Primitives.Index<E>.Count = .zero)
    where S == Ownership.Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear> {
        self.init(
            store: Ownership.Shared(
                Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear(
                    minimumCapacity: initialCapacity
                )
            )
        )
    }

    /// Creates an empty statically-unique array of move-only elements on the `Shared` column
    /// (the boxed flavor of the move-only regime — useful when the box's O(1) move matters).
    @inlinable
    public init<E: ~Copyable>(initialCapacity: Index_Primitives.Index<E>.Count = .zero)
    where S == Ownership.Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear> {
        self.init(
            store: Ownership.Shared(
                Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear(
                    minimumCapacity: initialCapacity
                )
            )
        )
    }
}
