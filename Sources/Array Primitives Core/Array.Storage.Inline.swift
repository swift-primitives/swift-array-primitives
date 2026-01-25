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

public import Range_Primitives

extension Array.Storage where Element: ~Copyable {

    /// Inline (stack-allocated) storage for small-buffer optimization.
    ///
    /// Provides the same element management API as `Array.Storage` but for
    /// elements stored inline within a containing struct. Used by `Array.Small`
    /// and `Array.Inline` for their inline storage needs.
    ///
    /// ## API Symmetry with Array.Storage
    ///
    /// | Heap (`Array.Storage`) | Inline (`Array.Storage.Inline`) |
    /// |------------------------|--------------------------------|
    /// | `initialize(to:at:)` | `initialize(to:at:)` |
    /// | `move(at:)` | `move(at:)` |
    /// | `deinitialize()` | `deinitialize(count:)` |
    /// | `move(to:)` | `move(to:count:)` |
    /// | `read(at:)` | `read(at:)` |
    ///
    /// The inline variant requires `count` to be passed explicitly since it
    /// doesn't store count internally (the containing type manages count).
    @safe
    @usableFromInline
    package struct Inline<let capacity: Int>: ~Copyable {

        /// Raw byte storage (64 bytes per slot).
        @usableFromInline
        package var raw: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        /// Maximum element stride supported (64 bytes).
        @inlinable
        package static var maxStride: Int { 64 }

        // MARK: - Lifecycle

        /// Creates uninitialized inline storage.
        ///
        /// - Precondition: Element stride must not exceed 64 bytes.
        /// - Precondition: Element alignment must not exceed `Int` alignment.
        @inlinable
        package init() {
            precondition(
                MemoryLayout<Element>.stride <= Self.maxStride,
                "Element stride (\(MemoryLayout<Element>.stride)) exceeds inline storage slot size (\(Self.maxStride) bytes)"
            )
            precondition(
                MemoryLayout<Element>.alignment <= MemoryLayout<Int>.alignment,
                "Element alignment (\(MemoryLayout<Element>.alignment)) exceeds inline storage alignment (\(MemoryLayout<Int>.alignment))"
            )
            self.raw = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
        }
    }
}

extension Array.Storage.Inline where Element: ~Copyable {
    // MARK: - Element Access (Mutable)

    /// Returns mutable pointer to element at index.
    ///
    /// - Parameter index: The index of the element.
    /// - Returns: A mutable pointer to the element.
    /// - Precondition: Index must be in bounds (caller's responsibility).
    @usableFromInline
    @unsafe
    package mutating func pointer(at index: Array.Index) -> UnsafeMutablePointer<Element> {
        let stride = MemoryLayout<Element>.stride
        return unsafe Swift.withUnsafeMutablePointer(to: &raw) { rawPointer in
            let base = UnsafeMutableRawPointer(rawPointer)
            return unsafe (base + index.position.rawValue * stride).assumingMemoryBound(to: Element.self)
        }
    }

    /// Initializes element at the given index.
    ///
    /// - Parameters:
    ///   - element: The element to store (consumed).
    ///   - index: The index to initialize.
    /// - Precondition: The slot at index must be uninitialized.
    @usableFromInline
    package mutating func initialize(to element: consuming Element, at index: Array.Index) {
        let ptr = unsafe pointer(at: index)
        unsafe ptr.initialize(to: element)
    }

    /// Moves element from the given index.
    ///
    /// - Parameter index: The index to move from.
    /// - Returns: The moved element.
    /// - Precondition: The slot at index must be initialized.
    /// - Postcondition: The slot at index is deinitialized.
    @usableFromInline
    package mutating func move(at index: Array.Index) -> Element {
        unsafe pointer(at: index).move()
    }

    // MARK: - Element Access (Read-Only)

    /// Returns read-only pointer to element at index.
    ///
    /// - Parameter index: The index of the element.
    /// - Returns: A read-only pointer to the element.
    /// - Precondition: Index must be in bounds (caller's responsibility).
    @usableFromInline
    @unsafe
    package func read(at index: Array.Index) -> UnsafePointer<Element> {
        let stride = MemoryLayout<Element>.stride
        return unsafe Swift.withUnsafePointer(to: raw) { rawPointer in
            let base = unsafe UnsafeRawPointer(rawPointer)
            return unsafe (base + index.position.rawValue * stride).assumingMemoryBound(to: Element.self)
        }
    }

    // MARK: - Bulk Operations

    /// Deinitializes elements in range.
    ///
    /// - Parameter range: The range of indices to deinitialize.
    /// - Precondition: All slots in range must be initialized.
    /// - Postcondition: All slots in range are deinitialized.
    /// - Note: Non-mutating to allow use from deinit contexts.
    @usableFromInline
    package func deinitialize(in range: Range.Lazy<Array.Index>) {
        let stride = MemoryLayout<Element>.stride
        unsafe Swift.withUnsafePointer(to: raw) { rawPointer in
            let base = unsafe UnsafeMutableRawPointer(mutating: UnsafeRawPointer(rawPointer))
            range.forEach { index in
                unsafe (base + index.position.rawValue * stride)
                    .assumingMemoryBound(to: Element.self)
                    .deinitialize(count: 1)
            }
        }
    }

    /// Deinitializes all elements up to count.
    ///
    /// - Parameter count: The number of initialized elements.
    /// - Precondition: Elements at indices 0..<count must be initialized.
    /// - Postcondition: All elements are deinitialized.
    /// - Note: Non-mutating to allow use from deinit contexts.
    @usableFromInline
    package func deinitialize(count: Array.Index.Count) {
        guard count > .zero else { return }
        deinitialize(in: 0..<count)
    }

    /// Moves all elements to heap storage.
    ///
    /// Used when spilling from inline to heap storage.
    ///
    /// - Parameters:
    ///   - heapStorage: The destination heap storage.
    ///   - count: The number of initialized elements.
    /// - Precondition: Elements at indices 0..<count must be initialized.
    /// - Precondition: Heap storage must have sufficient capacity.
    /// - Postcondition: Elements are moved to heap, inline slots are deinitialized.
    @usableFromInline
    package mutating func move(to heapStorage: Array<Element>.Storage, count: Array.Index.Count) {
        guard count > .zero else { return }
        let stride = MemoryLayout<Element>.stride
        unsafe Swift.withUnsafePointer(to: raw) { rawPointer in
            unsafe heapStorage.withUnsafeMutablePointerToElements { dst in
                let base = unsafe UnsafeMutableRawPointer(mutating: UnsafeRawPointer(rawPointer))
                (0..<count).forEach { index in
                    let src = unsafe (base + index.position.rawValue * stride).assumingMemoryBound(to: Element.self)
                    unsafe (dst + index).initialize(to: src.move())
                }
            }
        }
    }
}

// MARK: - Copyable Element Extensions

extension Array.Storage.Inline where Element: Copyable {
    /// Copies all elements to heap storage.
    ///
    /// - Parameters:
    ///   - heapStorage: The destination heap storage.
    ///   - count: The number of initialized elements.
    /// - Precondition: Elements at indices 0..<count must be initialized.
    /// - Precondition: Heap storage must have sufficient capacity.
    @usableFromInline
    package func copy(to heapStorage: Array<Element>.Storage, count: Array.Index.Count) {
        guard count > .zero else { return }
        let stride = MemoryLayout<Element>.stride
        unsafe Swift.withUnsafePointer(to: raw) { rawPointer in
            unsafe heapStorage.withUnsafeMutablePointerToElements { dst in
                let base = unsafe UnsafeRawPointer(rawPointer)
                (0..<count).forEach { index in
                    let src = unsafe (base + index.position.rawValue * stride).assumingMemoryBound(to: Element.self)
                    unsafe (dst + index).initialize(to: src.pointee)
                }
            }
        }
    }
}
