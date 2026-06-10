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

public import Buffer_Linear_Primitives
public import Memory_Heap_Primitives
public import Memory_Allocator_Primitive
public import Storage_Contiguous_Primitives

public import Array_Primitive

extension Array where S: ~Copyable {

    // MARK: - Bounded (Compile-Time Dimensioned, Heap-Allocated)

    /// A fixed-size array with compile-time dimension and `Index<S.Element>.Bounded<N>` indexing.
    ///
    /// `Array.Bounded<N>` provides compile-time dimension safety: the index type
    /// `Index<S.Element>.Bounded<N>` ensures indices are always within `[0, N)`.
    /// Once an index is constructed (with a bounds check), subscript access is
    /// guaranteed safe.
    ///
    /// ## Type-Level Index Separation
    ///
    /// Indices from different bounded arrays are distinct types:
    /// `Array<…Int…>.Bounded<3>.Index` ≠ `Array<…Int…>.Bounded<5>.Index`.
    ///
    /// ## Move-Only (R-1)
    ///
    /// `Bounded` wraps the direct bounded buffer over the enclosing column's element —
    /// a move-only substrate — so it is unconditionally `~Copyable`: copyability lives
    /// at the column (`Shared`), not in per-ADT CoW machinery.
    @safe
    public struct Bounded<let N: Int>: ~Copyable {
        /// Internal bounded linear buffer over the column's element.
        @usableFromInline
        package var _buffer: Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<S.Element>>.Linear.Bounded

        /// Internal initializer for use by extension modules.
        @usableFromInline
        package init(_buffer: consuming Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<S.Element>>.Linear.Bounded) {
            self._buffer = _buffer
        }
    }
}

// MARK: - Sendable

extension Array.Bounded: @unchecked Sendable where S: ~Copyable, S.Element: Sendable {}
