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

    // MARK: - Storage

    @usableFromInline
    package var _storage: Array.Storage

    /// Cached pointer to element storage. Stored in struct to enable property-based access.
    /// CRITICAL: Must be updated whenever _storage is replaced (reallocation, CoW copy).
    @usableFromInline
    package var _cachedPtr: UnsafeMutablePointer<Element>

    // MARK: - Initialization

    /// Creates an empty growable array.
    @inlinable
    public init() {
        self._storage = Array.Storage.create(minimumCapacity: 0)
        unsafe (self._cachedPtr = _storage.pointer(at: 0))
    }

    /// Creates an empty array with initial capacity hint.
    ///
    /// - Parameter initialCapacity: The initial capacity to allocate.
    @inlinable
    public init(initialCapacity: Int) {
        precondition(initialCapacity >= 0, "Initial capacity must be non-negative")
        self._storage = Array.Storage.create(minimumCapacity: initialCapacity)
        unsafe (self._cachedPtr = _storage.pointer(at: 0))
    }
    
    // MARK: - Unified Storage (nested to inherit Element's ~Copyable context)

    /// Unified storage class for array variants using ManagedBuffer.
    ///
    /// Declared as a nested class inside `Array` so that the `Element` generic
    /// inherits the `~Copyable` suppression from the outer type. This enables
    /// conditional Copyable conformance for `Fixed` and the base `Array`.
    ///
    /// Used by: `Array`, `Array.Fixed`, `Array.Small` (heap mode).
    @usableFromInline
    package final class Storage: ManagedBuffer<Int, Element> {
        deinit {
            let count = header
            guard count > 0 else { return }
            _ = unsafe withUnsafeMutablePointerToElements { elements in
                for i in 0..<count {
                    unsafe (elements + i).deinitialize(count: 1)
                }
            }
        }
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
        var _storage: Array.Storage

        /// Cached pointer for Span access.
        @usableFromInline
        package var _cachedPtr: UnsafeMutablePointer<Element>

        /// The number of elements in the array.
        public let _count: Index.Count

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
        /// Uses `Array.Storage.Inline` for consistency with `Array.Small`.
        /// This provides a uniform API: `pointer(at:)`, `read(at:)`, `move(at:)`,
        /// `initialize(to:at:)`, `deinitialize(count:)`.
        @usableFromInline
        package var _storage: Array<Element>.Storage.Inline<capacity>

        /// Current element count.
        @usableFromInline
        package var _count: Index.Count

        /// Workaround for Swift compiler bug where deinit element cleanup
        /// fails for ~Copyable structs that contain only value-type properties.
        /// Adding a reference type property (`AnyObject?`) fixes the bug.
        /// See: https://github.com/swiftlang/swift/issues/86652
        @usableFromInline
        var _deinitWorkaround: AnyObject? = nil

        /// Creates an empty inline array.
        @inlinable
        public init() {
            self._storage = Storage.Inline<capacity>()
            self._count = .zero
        }

        deinit {
            let count = _count.rawValue
            guard count > 0 else { return }
            _storage.deinitialize(count: count)
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

