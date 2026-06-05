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
public import Storage_Contiguous_Primitives
public import Storage_Heap_Primitives
public import Buffer_Linear_Primitives

extension Array where Element: ~Copyable {

    // MARK: - Fixed (Fixed-Count, Heap-Allocated)

    /// A non-resizable array that is always fully initialized.
    ///
    /// Unlike the base `Array`, `Fixed` cannot grow or shrink after creation.
    /// All elements are initialized at construction time. This is the Swift
    /// equivalent of a fixed-length array.
    ///
    /// ## Move-Only Support
    ///
    /// Both the array and its elements can be `~Copyable`:
    ///
    /// ```swift
    /// struct FileHandle: ~Copyable { ... }
    /// let handles = try Array<FileHandle>.Fixed(count: 3) { _ in FileHandle() }
    /// ```
    ///
    /// ## Conditional Copyable
    ///
    /// When `Element` is `Copyable`, `Fixed` is also `Copyable`:
    ///
    /// ```swift
    /// let a = try Array<Int>.Fixed(count: 3) { $0 }
    /// let b = a  // Copy works!
    /// ```
    ///
    /// ## Copy-on-Write
    ///
    /// When `Element` is `Copyable`, `Fixed` uses copy-on-write semantics:
    /// copies share storage until mutation.
    // WHY: Category D — structural Sendable workaround; the type is
    // WHY: structurally value-safe but the compiler cannot synthesize
    // WHY: Sendable due to a stored pointer / generic parameter shape.
    @safe
    public struct Fixed {
        /// Internal bounded linear buffer.
        @usableFromInline
        package var _buffer: Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Linear.Bounded

        /// Internal initializer for use by the ops module (cross-module designated init).
        @usableFromInline
        package init(_buffer: consuming Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Linear.Bounded) {
            self._buffer = _buffer
        }

        // Note: No deinit needed - Buffer/Storage handles cleanup
    }
}

// MARK: - Conditional Copyable

/// `Array.Fixed` is `Copyable` when its elements are `Copyable`.
///
/// This enables value semantics with copy-on-write optimization:
/// copies share storage until mutation.
extension Array.Fixed: Copyable where Element: Copyable {}

// MARK: - Sendable

extension Array.Fixed: @unchecked Sendable where Element: Sendable {}
