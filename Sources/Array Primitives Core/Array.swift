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
public import Storage_Primitives
import Standard_Library_Extensions

// MARK: - Array (Growable, Heap-Allocated)

/// A growable, heap-allocated array with ~Copyable support.
///
/// This is the primary dynamic array type, equivalent to C++'s `std::vector`
/// or Rust's `Vec<T>`. It supports both copyable and move-only elements.
///
/// This shadows `Swift.Array`. Use `Swift.Array` or `Array_Primitives_Core.Array`
/// to disambiguate when both are in scope.
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
/// - ``Array/Inline``: Typealias to `Swift.InlineArray` (all N elements always initialized)
@safe
public struct Array<Element: ~Copyable>: ~Copyable {

    // MARK: - Unified Storage

    /// Unified heap storage for array variants.
    ///
    /// Typealias to `Storage_Primitives.Storage<Element>`. Uses the canonical
    /// storage implementation from storage-primitives.
    ///
    /// Used by: `Array`, `Array.Fixed`, `Array.Small` (heap mode).
    @usableFromInline
    package typealias Storage = Storage_Primitives.Storage<Element>

    // MARK: - Storage

    @usableFromInline
    package var storage: Storage

    // Cached pointer to element storage for single-dereference subscript access.
    // If this lived in Storage (ManagedBuffer), every subscript would require:
    //   1. Dereference storage (class reference)
    //   2. Call withUnsafeMutablePointerToElements to get pointer
    //   3. Access element
    // By caching the pointer in the struct, subscript is a single pointer dereference.
    // CRITICAL: Must be updated whenever storage is replaced (reallocation, CoW copy).
    @usableFromInline
    package var _cachedPtr: Pointer<Element>.Mutable

    // MARK: - Initialization
    /// Creates an empty array with initial capacity hint.
    ///
    /// - Parameter initialCapacity: The initial capacity to allocate.
    @inlinable
    public init(initialCapacity: Array.Index.Count = .zero) {
        self.storage = Storage.create(minimumCapacity: initialCapacity)
        unsafe (self._cachedPtr = storage.pointer(at: .zero))
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
        @usableFromInline
        var storage: Storage

        /// The number of elements in the array.
        public let count: Index.Count

        /// Cached pointer for Span access.
        @usableFromInline
        package var _cachedPtr: Pointer<Element>.Mutable


        // Note: No deinit needed - Storage handles cleanup
    }

    // MARK: - Static (Fixed-Capacity, Inline Storage)

    /// A fixed-capacity vector with inline storage (static_vector / ArrayVec).
    ///
    /// `Array.Static` stores elements directly within the struct's memory layout,
    /// requiring no heap allocation. The capacity is specified as a compile-time
    /// generic parameter. Count varies from 0 to capacity.
    ///
    /// ## Move-Only
    ///
    /// `Array.Static` is unconditionally `~Copyable` due to its deinitializer requirement.
    /// Both the array and its elements can be move-only types.
    ///
    /// ## Limitations
    ///
    /// - Maximum element stride: 64 bytes (8 Int-sized words)
    /// - Element alignment must not exceed `MemoryLayout<Int>.alignment`
    /// - Capacity is fixed at compile time; use `Array.Small` for flexible sizing
    ///
    /// - Note: This type is declared inside `Array` (not in an extension) due to a
    ///   Swift compiler bug where nested types with value generic parameters declared
    ///   in extensions do not properly inherit `~Copyable` constraints from the outer type.
    public struct Static<let capacity: Int>: ~Copyable {
        /// Inline storage for elements.
        ///
        /// Uses `Storage<Element>.Inline` from storage-primitives for consistency
        /// with `Array.Small`. This provides a uniform API: `pointer(at:)`,
        /// `mutablePointer(at:)`, `move(at:)`, `initialize(to:at:)`, `deinitialize(count:)`.
        @usableFromInline
        package var storage: Storage_Primitives.Storage<Element>.Inline<capacity>

        /// Current element count.
        @usableFromInline
        package var count: Index.Count

        /// Workaround for Swift compiler bug where deinit element cleanup
        /// fails for ~Copyable structs that contain only value-type properties.
        /// Adding a reference type property (`AnyObject?`) fixes the bug.
        /// See: https://github.com/swiftlang/swift/issues/86652
        @usableFromInline
        var _deinitWorkaround: AnyObject? = nil

        /// Creates an empty inline array.
        @inlinable
        public init() {
            self.storage = Storage_Primitives.Storage<Element>.Inline<capacity>()
            self.count = .zero
        }

        deinit {
            guard count > 0 else { return }
            storage.deinitialize(count: count)
        }
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
extension Array.Static: @unchecked Sendable where Element: Sendable {}



