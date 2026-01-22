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
public import Standard_Library_Extensions

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

    /// Internal storage class for bounded arrays using ManagedBuffer.
    ///
    /// Declared as a nested class inside `Array` so that the `Element` generic
    /// inherits the `~Copyable` suppression from the outer type. This enables
    /// `Array.Bounded` to be conditionally Copyable.
    ///
    /// - Note: This must be nested directly in `Array`, not in `Array.Bounded`,
    ///   due to Swift's generic constraint propagation limitations with `~Copyable`.
    @usableFromInline
    final class Storage: ManagedBuffer<Int, Element> {

        /// Creates storage with the specified capacity, initialized with elements.
        @usableFromInline
        static func create(
            capacity: Int,
            initializingWith initializer: (Int) -> Element
        ) -> Storage {
            let storage = Storage.create(minimumCapacity: capacity) { _ in 0 }
            let typed = unsafe unsafeDowncast(storage, to: Storage.self)

            _ = unsafe typed.withUnsafeMutablePointerToElements { elements in
                for i in 0..<capacity {
                    unsafe (elements + i).initialize(to: initializer(i))
                }
            }
            typed.header = capacity

            return typed
        }

        /// Creates empty storage (for zero-count arrays).
        @usableFromInline
        static func createEmpty() -> Storage {
            let storage = Storage.create(minimumCapacity: 0) { _ in 0 }
            return unsafe unsafeDowncast(storage, to: Storage.self)
        }

        deinit {
            let count = header
            guard count > 0 else { return }
            _ = unsafe withUnsafeMutablePointerToElements { elements in
                for i in 0..<count {
                    unsafe (elements + i).deinitialize(count: 1)
                }
            }
        }

        /// Returns pointer to element storage.
        @usableFromInline
        var _elementsPointer: UnsafeMutablePointer<Element> {
            unsafe withUnsafeMutablePointerToElements { unsafe $0 }
        }

        /// Initializes element at the given index.
        @usableFromInline
        func _initializeElement(at index: Int, to element: consuming Element) {
            let ptr = unsafe withUnsafeMutablePointerToElements { unsafe $0 + index }
            unsafe ptr.initialize(to: element)
        }

        /// Moves element from the given index.
        @usableFromInline
        func _moveElement(at index: Int) -> Element {
            unsafe withUnsafeMutablePointerToElements { elements in
                unsafe (elements + index).move()
            }
        }

        /// Deinitializes elements in the given range.
        @usableFromInline
        func _deinitializeElements(in range: Range<Int>) {
            _ = unsafe withUnsafeMutablePointerToElements { elements in
                for i in range {
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
    public struct Bounded: ~Copyable {

        // MARK: - Properties

        @usableFromInline
        var _storage: Storage

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
    public struct Unbounded<let N: Int>: ~Copyable {

        // MARK: - ElementStorage (nested to inherit Element's ~Copyable context)

        /// Internal storage class for elements using ManagedBuffer.
        ///
        /// Declared as a nested class inside `Unbounded` so that the `Element` generic
        /// inherits the `~Copyable` suppression from the outer type.
        @usableFromInline
        package final class ElementStorage: ManagedBuffer<Int, Element> {

            /// Creates empty storage with the specified minimum capacity.
            @usableFromInline
            static func create(minimumCapacity: Int) -> ElementStorage {
                let storage = ElementStorage.create(minimumCapacity: minimumCapacity) { _ in 0 }
                return unsafe unsafeDowncast(storage, to: ElementStorage.self)
            }

            deinit {
                let count = header
                guard count > 0 else { return }
                _ = unsafe withUnsafeMutablePointerToElements { elements in
                    for i in 0..<count {
                        unsafe (elements + i).deinitialize(count: 1)
                    }
                }
            }

            /// Returns pointer to element storage.
            @usableFromInline
            package var _elementsPointer: UnsafeMutablePointer<Element> {
                unsafe withUnsafeMutablePointerToElements { unsafe $0 }
            }

            /// Initializes element at the given index.
            @usableFromInline
            func _initializeElement(at index: Int, to element: consuming Element) {
                let ptr = unsafe withUnsafeMutablePointerToElements { unsafe $0 + index }
                unsafe ptr.initialize(to: element)
            }

            /// Moves element from the given index.
            @usableFromInline
            func _moveElement(at index: Int) -> Element {
                unsafe withUnsafeMutablePointerToElements { elements in
                    unsafe (elements + index).move()
                }
            }

            /// Moves all elements to new storage.
            @usableFromInline
            func _moveAllElements(to newStorage: ElementStorage) {
                let count = header
                guard count > 0 else { return }
                _ = unsafe withUnsafeMutablePointerToElements { src in
                    unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                        for i in 0..<count {
                            unsafe (dst + i).initialize(to: (src + i).move())
                        }
                    }
                }
            }

            /// Deinitializes all elements.
            @usableFromInline
            func _deinitializeAllElements() {
                let count = header
                guard count > 0 else { return }
                _ = unsafe withUnsafeMutablePointerToElements { elements in
                    for i in 0..<count {
                        unsafe (elements + i).deinitialize(count: 1)
                    }
                }
                header = 0
            }
        }

        @usableFromInline
        package var _storage: ElementStorage

        /// Cached pointer to element storage. Stored in struct to enable property-based access.
        /// CRITICAL: Must be updated whenever _storage is replaced (reallocation, CoW copy).
        @usableFromInline
        package var _cachedPtr: UnsafeMutablePointer<Element>

        /// Creates an empty growable array.
        @inlinable
        public init() {
            self._storage = ElementStorage.create(minimumCapacity: 0)
            unsafe (self._cachedPtr = _storage._elementsPointer)
        }

        // Note: No deinit needed - ElementStorage handles cleanup
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
    public struct Inline<let capacity: Int>: ~Copyable {
        /// Maximum element stride supported by inline storage (64 bytes per slot).
        @usableFromInline
        static var _maxElementStride: Int { 64 }

        /// Raw byte storage for elements. Each slot is 64 bytes (8 Ints on 64-bit).
        @usableFromInline
        var _elements: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

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
            precondition(
                MemoryLayout<Element>.stride <= Self._maxElementStride,
                "Element stride (\(MemoryLayout<Element>.stride)) exceeds inline storage slot size (\(Self._maxElementStride) bytes). Use Array.Bounded instead."
            )
            precondition(
                MemoryLayout<Element>.alignment <= MemoryLayout<Int>.alignment,
                "Element alignment (\(MemoryLayout<Element>.alignment)) exceeds inline storage alignment (\(MemoryLayout<Int>.alignment)). Use Array.Bounded instead."
            )
            self._elements = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
            self._count = .zero
        }

        deinit {
            let count = _count.rawValue
            guard count > 0 else { return }

            let stride = MemoryLayout<Element>.stride
            unsafe Swift.withUnsafePointer(to: _elements) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(mutating: UnsafeRawPointer(storagePtr))
                for i in 0..<count {
                    let elementPtr = unsafe (basePtr + i * stride)
                        .assumingMemoryBound(to: Element.self)
                    unsafe elementPtr.deinitialize(count: 1)
                }
            }
        }

        /// Returns a mutable pointer to the element at the given index.
        @usableFromInline
        @unsafe
        mutating func _pointerToElement(at index: Int) -> UnsafeMutablePointer<Element> {
            let stride = MemoryLayout<Element>.stride
            return unsafe Swift.withUnsafeMutablePointer(to: &_elements) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + index * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr
            }
        }

        /// Returns a read-only pointer to the element at the given index.
        @usableFromInline
        @unsafe
        package func _readPointerToElement(at index: Int) -> UnsafePointer<Element> {
            let stride = MemoryLayout<Element>.stride
            return unsafe Swift.withUnsafePointer(to: _elements) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + index * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr
            }
        }
    }

    // MARK: - Small (SmallVec Pattern)

    /// An array with small-buffer optimization (SmallVec pattern).
    ///
    /// `Array.Small` stores up to `inlineCapacity` elements in inline storage,
    /// then automatically spills to heap storage when that capacity is exceeded.
    /// This provides the performance benefits of inline storage for common cases
    /// while supporting unbounded growth.
    ///
    /// ## Move-Only
    ///
    /// `Array.Small` is unconditionally `~Copyable` (move-only) because it requires
    /// a deinitializer to clean up inline storage.
    ///
    /// ## Limitations
    ///
    /// - Maximum element stride: 64 bytes (8 Int-sized words) for inline storage
    /// - Element alignment must not exceed `MemoryLayout<Int>.alignment` for inline storage
    ///
    /// - Note: This type is declared inside `Array` (not in an extension) due to a
    ///   Swift compiler bug where nested types with value generic parameters declared
    ///   in extensions do not properly inherit `~Copyable` constraints from the outer type.
    @safe
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        /// Maximum element stride supported by inline storage (64 bytes per slot).
        @usableFromInline
        package static var _maxElementStride: Int { 64 }

        /// Raw byte storage for inline elements.
        @usableFromInline
        package var _inlineElements: InlineArray<inlineCapacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        /// Current element count (valid in both inline and heap modes).
        @usableFromInline
        package var _count: Index_Primitives.Index<Element>.Count

        /// Heap storage for elements when spilled. Nil when using inline storage.
        @usableFromInline
        package var _heapStorage: Unbounded<inlineCapacity>.ElementStorage?

        /// Cached pointer to heap elements. Only valid when _heapStorage is non-nil.
        @usableFromInline
        package var _heapPtr: UnsafeMutablePointer<Element>?

        /// Creates an empty small array.
        @inlinable
        public init() {
            precondition(
                MemoryLayout<Element>.stride <= Self._maxElementStride,
                "Element stride (\(MemoryLayout<Element>.stride)) exceeds inline storage slot size (\(Self._maxElementStride) bytes). Use Array.Unbounded instead."
            )
            precondition(
                MemoryLayout<Element>.alignment <= MemoryLayout<Int>.alignment,
                "Element alignment (\(MemoryLayout<Element>.alignment)) exceeds inline storage alignment (\(MemoryLayout<Int>.alignment)). Use Array.Unbounded instead."
            )
            self._inlineElements = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
            self._count = .zero
            self._heapStorage = nil
            unsafe (self._heapPtr = nil)
        }

        deinit {
            let count = _count.rawValue
            guard count > 0 else { return }

            if let heap = _heapStorage {
                // Elements are on heap - ElementStorage handles cleanup via its deinit
                // Set header count for proper cleanup
                heap.header = count
            } else {
                // Elements are inline - clean up manually
                let stride = MemoryLayout<Element>.stride
                unsafe Swift.withUnsafeBytes(of: _inlineElements) { bytes in
                    let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                    for i in 0..<count {
                        let elementPtr = unsafe (basePtr + i * stride)
                            .assumingMemoryBound(to: Element.self)
                        unsafe elementPtr.deinitialize(count: 1)
                    }
                }
            }
        }

        /// Whether the array is currently using heap storage.
        @inlinable
        public var isSpilled: Bool { _heapStorage != nil }

        // MARK: - Internal Helpers

        /// Returns a mutable pointer to the inline element at the given index.
        @usableFromInline
        @unsafe
        mutating func _inlinePointerToElement(at index: Int) -> UnsafeMutablePointer<Element> {
            let stride = MemoryLayout<Element>.stride
            return unsafe Swift.withUnsafeMutablePointer(to: &_inlineElements) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + index * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr
            }
        }

        /// Returns a read-only pointer to the inline element at the given index.
        @usableFromInline
        @unsafe
        package func _inlineReadPointerToElement(at index: Int) -> UnsafePointer<Element> {
            let stride = MemoryLayout<Element>.stride
            return unsafe Swift.withUnsafePointer(to: _inlineElements) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + index * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr
            }
        }

        /// Spills inline storage to heap.
        @usableFromInline
        mutating func _spillToHeap(minimumCapacity: Int) {
            precondition(_heapStorage == nil, "Already spilled")

            // Create heap storage with growth factor
            let newCapacity = Swift.max(minimumCapacity, inlineCapacity * 2, 8)
            let newStorage = Unbounded<inlineCapacity>.ElementStorage.create(minimumCapacity: newCapacity)

            // Move elements from inline to heap
            let stride = MemoryLayout<Element>.stride
            _ = unsafe Swift.withUnsafeBytes(of: _inlineElements) { bytes in
                unsafe newStorage.withUnsafeMutablePointerToElements { heapPtr in
                    let inlineBase = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                    for i in 0..<_count.rawValue {
                        let inlineElement = unsafe (inlineBase + i * stride)
                            .assumingMemoryBound(to: Element.self)
                        unsafe (heapPtr + i).initialize(to: inlineElement.move())
                    }
                }
            }
            newStorage.header = _count.rawValue

            _heapStorage = newStorage
            unsafe (_heapPtr = newStorage._elementsPointer)
        }

        /// Ensures the heap has capacity for at least the specified number of elements.
        @usableFromInline
        mutating func _ensureHeapCapacity(_ minimumCapacity: Int) {
            guard let heapStorage = _heapStorage else {
                preconditionFailure("Not in heap mode")
            }
            guard heapStorage.capacity < minimumCapacity else { return }

            let newCapacity = Swift.max(minimumCapacity, heapStorage.capacity * 2, 8)
            let newStorage = Unbounded<inlineCapacity>.ElementStorage.create(minimumCapacity: newCapacity)
            let currentCount = heapStorage.header

            heapStorage._moveAllElements(to: newStorage)
            newStorage.header = currentCount
            _heapStorage = newStorage
            unsafe (_heapPtr = newStorage._elementsPointer)
        }
    }
}

// MARK: - Conditional Copyable

/// `Array.Bounded` is `Copyable` when its elements are `Copyable`.
///
/// This enables value semantics with copy-on-write optimization:
/// copies share storage until mutation.
extension Array.Bounded: Copyable where Element: Copyable {}

/// `Array.Unbounded` is `Copyable` when its elements are `Copyable`.
/// Uses ManagedBuffer storage, so no deinit needed in the struct itself.
extension Array.Unbounded: Copyable where Element: Copyable {}

// Note: Array.Inline and Array.Small are UNCONDITIONALLY ~Copyable
// due to their deinit requirements for inline storage cleanup.

// MARK: - Sequence (Copyable elements only)

// NOTE: Swift.Sequence conformance is provided by the Sequence module
// (Array Primitives Sequence) via Sequence.Protocol + Swift.Sequence bridge.
// See Array.Bounded+Collection.Access.Random.swift for the Iterator definition.

// MARK: - Sendable

extension Array.Bounded: @unchecked Sendable where Element: Sendable {}
extension Array.Unbounded: @unchecked Sendable where Element: Sendable {}
extension Array.Inline: @unchecked Sendable where Element: Sendable {}
extension Array.Small: @unchecked Sendable where Element: Sendable {}

// MARK: - Convenience Typealiases

extension Array {
    /// Convenience typealias for small arrays with initial capacity 1.
    public typealias Small1 = Unbounded<1>

    /// Convenience typealias for small arrays with initial capacity 4.
    public typealias Small4 = Unbounded<4>

    /// Convenience typealias for small arrays with initial capacity 8.
    public typealias Small8 = Unbounded<8>
}

// MARK: - Storage Copyable Extensions

extension Array.Storage where Element: Copyable {
    /// Creates a copy of this storage.
    @usableFromInline
    func copy() -> Array<Element>.Storage {
        let count = header
        guard count > 0 else {
            return Array<Element>.Storage.createEmpty()
        }

        return Array<Element>.Storage.create(capacity: count) { i in
            _readElement(at: i)
        }
    }

    /// Reads element at the given index (Copyable elements only).
    @usableFromInline
    func _readElement(at index: Int) -> Element {
        unsafe withUnsafeMutablePointerToElements { elements in
            unsafe (elements + index).pointee
        }
    }
}

extension Array.Unbounded.ElementStorage where Element: Copyable {
    /// Reads element at the given index (Copyable elements only).
    @usableFromInline
    package func _readElement(at index: Int) -> Element {
        unsafe withUnsafeMutablePointerToElements { elements in
            unsafe (elements + index).pointee
        }
    }
}
