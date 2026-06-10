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

public import Array_Primitive
public import Memory_Heap_Primitives
public import Memory_Allocator_Primitive
public import Storage_Contiguous_Primitives
public import Buffer_Linear_Primitives

extension Array where S: ~Copyable {

    // MARK: - Fixed (Fixed-Count, Heap-Allocated)

    /// A non-resizable array that is always fully initialized.
    ///
    /// Unlike the base `Array`, `Fixed` cannot grow or shrink after creation.
    /// All elements are initialized at construction time. This is the Swift
    /// equivalent of a fixed-length array.
    ///
    /// ## Move-Only (R-1)
    ///
    /// `Fixed` wraps the direct bounded buffer over the enclosing column's element —
    /// a move-only substrate — so it is unconditionally `~Copyable`: copyability lives
    /// at the column (`Shared`), not in per-ADT CoW machinery. Use `clone()` for an
    /// explicit deep copy of `Copyable` elements; a value-semantic fixed array is a
    /// future `Shared`-column variant, to be added on consumer evidence.
    ///
    /// Both the array and its elements can be `~Copyable`:
    ///
    /// ```swift
    /// struct FileHandle: ~Copyable { ... }
    /// let handles = try Array<…>.Fixed(count: 3) { _ in FileHandle() }
    /// ```
    @safe
    public struct Fixed: ~Copyable {
        /// Internal bounded linear buffer over the column's element.
        @usableFromInline
        package var _buffer: Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<S.Element>>.Linear.Bounded

        /// Internal initializer for use by the ops module (cross-module designated init).
        @usableFromInline
        package init(_buffer: consuming Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<S.Element>>.Linear.Bounded) {
            self._buffer = _buffer
        }

        // Note: No deinit needed — the buffer's oracle handles cleanup.
    }
}

// MARK: - Sendable

extension Array.Fixed: @unchecked Sendable where S: ~Copyable, S.Element: Sendable {}
