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
public import Storage_Contiguous_Primitives
public import Index_Primitives

// MARK: - Array (Growable, Heap-Allocated)

/// A growable, heap-allocated array with ~Copyable support.
///
/// This is the primary dynamic array type, equivalent to C++'s `std::vector`
/// or Rust's `Vec<T>`. It supports both copyable and move-only elements.
///
/// This shadows `Swift.Array`. Bare `Array` resolves to this type when any
/// module in the ecosystem is imported. Use `Swift.Array` or `[T]` syntax
/// when the stdlib array is needed.
///
/// ## Move-Only Support
///
/// Both the array and its elements can be `~Copyable`:
///
/// ```swift
/// struct FileHandle: ~Copyable { ... }
/// var handles = Array<FileHandle>()
/// handles.append(FileHandle())
/// ```
///
/// ## Copy-on-Write
///
/// When `Element` is `Copyable`, the array uses copy-on-write semantics:
/// copies share storage until mutation.
///
/// ## Variants
///
/// - ``Array``: Dynamically-growing storage (this type)
/// - ``Array/Fixed``: Fixed-count, all elements initialized at creation
/// - ``Array/Static``: Fixed-capacity inline storage (stack-allocated, variable count)
/// - ``Array/Small``: Inline storage with automatic spill to heap (SmallVec pattern)
/// - ``Array/Bounded``: Compile-time dimensioned with `Index<Element>.Bounded<N>` indexing
/// - ``Array/Inline``: Typealias to `Swift.InlineArray` (all N elements always initialized)
// WHY: Category D — structural Sendable workaround; the type is
// WHY: structurally value-safe but the compiler cannot synthesize
// WHY: Sendable due to a stored pointer / generic parameter shape.
@safe
public struct Array<Element: ~Copyable>: ~Copyable {

    // MARK: - Buffer Storage

    /// Internal growable linear buffer.
    ///
    /// Delegates growth, CoW, element lifecycle, and span access
    /// to `Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Linear` from buffer-primitives.
    @usableFromInline
    package var _buffer: Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Linear

    // MARK: - Initialization

    /// Creates an empty array with initial capacity hint.
    ///
    /// - Parameter initialCapacity: The initial capacity to allocate.
    @inlinable
    public init(initialCapacity: Array.Index.Count = .zero) {
        self._buffer = Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Linear(minimumCapacity: initialCapacity)
    }

    /// Internal initializer for use by the ops module (cross-module designated init).
    @usableFromInline
    package init(_buffer: consuming Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Linear) {
        self._buffer = _buffer
    }
}

// MARK: - Conditional Copyable

/// `Array` is `Copyable` when its elements are `Copyable`.
/// Uses ManagedBuffer storage, so no deinit needed in the struct itself.
extension Array: Copyable where Element: Copyable {}

// MARK: - Sendable

extension Array: @unchecked Sendable where Element: Sendable {}
