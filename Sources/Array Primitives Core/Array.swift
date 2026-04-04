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
public import Buffer_Linear_Primitives

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
/// - ``Array/Bounded``: Compile-time dimensioned with `Algebra.Z<N>` indexing
/// - ``Array/Inline``: Typealias to `Swift.InlineArray` (all N elements always initialized)
@safe
public struct Array<Element: ~Copyable>: ~Copyable {

    // MARK: - Buffer Storage

    /// Internal growable linear buffer.
    ///
    /// Delegates growth, CoW, element lifecycle, and span access
    /// to `Buffer<Element>.Linear` from buffer-primitives.
    @usableFromInline
    package var _buffer: Buffer<Element>.Linear

    // MARK: - Initialization

    /// Creates an empty array with initial capacity hint.
    ///
    /// - Parameter initialCapacity: The initial capacity to allocate.
    @inlinable
    public init(initialCapacity: Array.Index.Count = .zero) {
        self._buffer = Buffer<Element>.Linear(minimumCapacity: initialCapacity)
    }

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
    @safe
    public struct Fixed {
        /// Internal bounded linear buffer.
        @usableFromInline
        package var _buffer: Buffer<Element>.Linear.Bounded

        // Note: No deinit needed - Buffer/Storage handles cleanup
    }

    // MARK: - Inline (Typealias to Swift.InlineArray)

    /// Fixed-count inline array (typealias to `Swift.InlineArray`).
    ///
    /// All N elements are always initialized. For variable-count inline
    /// storage (0 to capacity elements), use ``Array/Static`` instead.
    ///
    /// ## Comparison
    ///
    /// | Type | Count | Storage | Heap |
    /// |------|-------|---------|------|
    /// | `Array.Inline<N>` | Fixed (always N) | Inline | No |
    /// | `Array.Static<N>` | Variable (0..N) | Inline | No |
    /// | `Array.Bounded<N>` | Fixed (always N) | Heap (CoW) | Yes |
    public typealias Inline<let N: Int> = Swift.InlineArray<N, Element>
}


// MARK: - Conditional Copyable

/// `Array.Fixed` is `Copyable` when its elements are `Copyable`.
///
/// This enables value semantics with copy-on-write optimization:
/// copies share storage until mutation.
extension Array.Fixed: Copyable where Element: Copyable {}

/// `Array` is `Copyable` when its elements are `Copyable`.
/// Uses ManagedBuffer storage, so no deinit needed in the struct itself.
extension Array: Copyable where Element: Copyable {}
extension Array: @unchecked Sendable where Element: Sendable {}

// MARK: - Sendable

extension Array.Fixed: @unchecked Sendable where Element: Sendable {}


