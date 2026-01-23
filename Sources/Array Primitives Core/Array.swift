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

// MARK: - Array Namespace

/// Namespace for array types supporting move-only elements.
///
/// This shadows `Swift.Array`. Use `Swift.Array` or `Array_Primitives.Array`
/// to disambiguate when both are in scope.
///
/// ## Variants
///
/// - ``Array/Bounded``: Fixed-capacity, all elements initialized at creation
/// - ``Array/Unbounded``: Dynamically-growing storage with CoW for Copyable elements
/// - ``Array/Inline``: Zero-allocation inline storage with compile-time capacity
/// - ``Array/Small``: Inline storage with automatic spill to heap (SmallVec pattern)
public enum Array<Element: ~Copyable>: ~Copyable {

    // MARK: - Unified Storage (nested to inherit Element's ~Copyable context)

    /// Unified storage class for array variants using ManagedBuffer.
    ///
    /// Declared as a nested class inside `Array` so that the `Element` generic
    /// inherits the `~Copyable` suppression from the outer type. This enables
    /// conditional Copyable conformance for `Bounded` and `Unbounded`.
    ///
    /// Used by: `Array.Bounded`, `Array.Unbounded`, `Array.Small` (heap mode).
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

    // MARK: - Bounded (Fixed-Capacity)

    /// A non-resizable array that is always fully initialized.
    ///
    /// Unlike standard `Array`, `Bounded` cannot grow or shrink after creation.
    /// All elements are initialized at construction time.
    ///
    /// ## Move-Only Support
    ///
    /// Both the array and its elements can be `~Copyable`:
    ///
    /// ```swift
    /// struct FileHandle: ~Copyable { ... }
    /// let handles = try Array<FileHandle>.Bounded(count: 3) { _ in FileHandle() }
    /// ```
    ///
    /// ## Conditional Copyable
    ///
    /// When `Element` is `Copyable`, `Bounded` is also `Copyable`:
    ///
    /// ```swift
    /// let a = try Array<Int>.Bounded(count: 3) { $0 }
    /// let b = a  // Copy works!
    /// ```
    ///
    /// ## Copy-on-Write
    ///
    /// When `Element` is `Copyable`, `Bounded` uses copy-on-write semantics:
    /// copies share storage until mutation.
    @safe
    public struct Fixed {

        @usableFromInline
        var _storage: Array.Storage

        /// Cached pointer for Span access.
        @usableFromInline
        package var _cachedPtr: UnsafeMutablePointer<Element>

        /// The number of elements in the array.
        public let _count: Index_Primitives.Index<Element>.Count

        // Note: No deinit needed - Storage handles cleanup
    }

    // MARK: - Unbounded (Dynamically-Growing)

    /// A growable array with a compile-time initial capacity hint.
    ///
    /// Unlike `Bounded`, this array can grow unbounded. The generic parameter `N`
    /// specifies the initial allocation capacity when the first element is added.
    /// Subsequent growth uses a doubling strategy.
    ///
    /// ## Move-Only Support
    ///
    /// Both the array and its elements can be `~Copyable`:
    ///
    /// ```swift
    /// struct FileHandle: ~Copyable { ... }
    /// var array = Array<FileHandle>.Unbounded<4>()
    /// array.append(FileHandle())
    /// ```
    ///
    /// ## Copy-on-Write
    ///
    /// When `Element` is `Copyable`, `Array.Unbounded` uses copy-on-write semantics:
    /// copies share storage until mutation.
    @safe
    public struct Unbounded<let N: Int> {

        @usableFromInline
        package var _storage: Array.Storage

        /// Cached pointer to element storage. Stored in struct to enable property-based access.
        /// CRITICAL: Must be updated whenever _storage is replaced (reallocation, CoW copy).
        @usableFromInline
        package var _cachedPtr: UnsafeMutablePointer<Element>

        /// Creates an empty growable array.
        @inlinable
        public init() {
            self._storage = Array.Storage.create(minimumCapacity: 0)
            unsafe (self._cachedPtr = _storage.pointer(at: 0))
        }
    }

    // MARK: - Inline (Zero-Allocation)

    /// A fixed-capacity, inline-storage array with compile-time capacity.
    ///
    /// `Array.Inline` stores elements directly within the struct's memory layout,
    /// requiring no heap allocation. The capacity is specified as a compile-time
    /// generic parameter.
    ///
    /// ## Move-Only
    ///
    /// `Array.Inline` is unconditionally `~Copyable` due to its deinitializer requirement.
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
        package var _count: Index_Primitives.Index<Element>.Count

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
}



// MARK: - Conditional Copyable

/// `Array.Bounded` is `Copyable` when its elements are `Copyable`.
///
/// This enables value semantics with copy-on-write optimization:
/// copies share storage until mutation.
extension Array.Fixed: Copyable where Element: Copyable {}

/// `Array.Unbounded` is `Copyable` when its elements are `Copyable`.
/// Uses ManagedBuffer storage, so no deinit needed in the struct itself.
extension Array.Unbounded: Copyable where Element: Copyable {}

// MARK: - Sendable

extension Array.Fixed: @unchecked Sendable where Element: Sendable {}
extension Array.Unbounded: @unchecked Sendable where Element: Sendable {}
extension Array.Static: @unchecked Sendable where Element: Sendable {}

