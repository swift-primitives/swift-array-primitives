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

// ============================================================================
// MARK: - Creation
// ============================================================================

extension Array.Storage where Element: ~Copyable {
    /// Creates empty storage with the specified minimum capacity.
    ///
    /// Used by growable arrays (Unbounded, Small heap mode).
    @usableFromInline
    package static func create(minimumCapacity: Array.Index.Count) -> Array<Element>.Storage {
        let storage = Array<Element>.Storage.create(minimumCapacity: minimumCapacity.rawValue) { _ in 0 }
        return unsafe unsafeDowncast(storage, to: Array<Element>.Storage.self)
    }

    /// Creates storage with the specified capacity, initialized with elements.
    ///
    /// Used by fixed-size arrays (Bounded).
    @usableFromInline
    static func create(
        capacity: Array.Index.Count,
        initializingWith initializer: (Array.Index) -> Element
    ) -> Array.Storage {
        let storage = Array.Storage.create(minimumCapacity: capacity.rawValue) { _ in 0 }
        let typed = unsafe unsafeDowncast(storage, to: Array.Storage.self)

        _ = unsafe typed.withUnsafeMutablePointerToElements { elements in
            (0..<capacity).forEach { index in
                unsafe (elements + index).initialize(to: initializer(index))
            }
        }
        typed.header = capacity.rawValue

        return typed
    }

    /// Creates empty storage (for zero-count arrays).
    @usableFromInline
    static func createEmpty() -> Array.Storage {
        let storage = Array.Storage.create(minimumCapacity: 0) { _ in 0 }
        return unsafe unsafeDowncast(storage, to: Array.Storage.self)
    }
}

// ============================================================================
// MARK: - Element Access (Mutable)
// ============================================================================

extension Array.Storage where Element: ~Copyable {
    /// Returns mutable pointer to element at index.
    ///
    /// - Parameter index: The index of the element.
    /// - Returns: A mutable pointer to the element.
    /// - Precondition: Index must be in bounds (caller's responsibility).
    @usableFromInline
    @unsafe
    package func pointer(at index: Array.Index) -> UnsafeMutablePointer<Element> {
        unsafe withUnsafeMutablePointerToElements { unsafe $0 + index }
    }

    /// Initializes element at the given index.
    ///
    /// - Parameters:
    ///   - element: The element to store (consumed).
    ///   - index: The index to initialize.
    /// - Precondition: The slot at index must be uninitialized.
    @usableFromInline
    package func initialize(to element: consuming Element, at index: Array.Index) {
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
    package func move(at index: Array.Index) -> Element {
        unsafe pointer(at: index).move()
    }
}

// ============================================================================
// MARK: - Element Access (Read-Only)
// ============================================================================

extension Array.Storage where Element: ~Copyable {
    /// Returns read-only pointer to element at index.
    ///
    /// - Parameter index: The index of the element.
    /// - Returns: A read-only pointer to the element.
    /// - Precondition: Index must be in bounds (caller's responsibility).
    @usableFromInline
    @unsafe
    package func read(at index: Array.Index) -> UnsafePointer<Element> {
        unsafe withUnsafeMutablePointerToElements { unsafe UnsafePointer($0 + index) }
    }
}

// ============================================================================
// MARK: - Bulk Operations
// ============================================================================

extension Array.Storage where Element: ~Copyable {
    /// Deinitializes elements in the given range.
    ///
    /// - Parameter range: The range of indices to deinitialize.
    /// - Precondition: All slots in range must be initialized.
    /// - Postcondition: All slots in range are deinitialized.
    @usableFromInline
    func deinitialize(in range: Range.Lazy<Array.Index>) {
        _ = unsafe withUnsafeMutablePointerToElements { elements in
            range.forEach { index in
                unsafe (elements + index).deinitialize(count: 1)
            }
        }
    }

    /// Deinitializes all elements and sets header to 0.
    ///
    /// - Precondition: Elements at indices 0..<header must be initialized.
    /// - Postcondition: All elements are deinitialized, header is 0.
    @usableFromInline
    package func deinitialize() {
        let count = self.count
        guard count > .zero else { return }
        _ = unsafe withUnsafeMutablePointerToElements { elements in
            (0..<count).forEach { index in
                unsafe (elements + index).deinitialize(count: 1)
            }
        }
        header = 0
    }

    /// Moves all elements to new storage.
    ///
    /// - Parameter newStorage: The destination storage.
    /// - Precondition: Elements at indices 0..<header must be initialized.
    /// - Precondition: Destination storage must have sufficient capacity.
    /// - Postcondition: Elements are moved to destination, source slots are deinitialized.
    @usableFromInline
    package func move(to newStorage: Array<Element>.Storage) {
        let count = self.count
        guard count > .zero else { return }
        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                (0..<count).forEach { index in
                    unsafe (dst + index).initialize(to: (src + index).move())
                }
            }
        }
    }
}

// ============================================================================
// MARK: - Copy-on-Write (Copyable elements only)
// ============================================================================

extension Array.Storage where Element: Copyable {
    /// Creates a copy of this storage.
    ///
    /// - Returns: A new storage instance with copied elements.
    @usableFromInline
    package func copy() -> Array<Element>.Storage {
        let count = self.count
        guard count > .zero else {
            return Array<Element>.Storage.create(minimumCapacity: .zero)
        }

        let new = Array<Element>.Storage.create(minimumCapacity: count)
        new.header = count.rawValue

        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe new.withUnsafeMutablePointerToElements { dst in
                (0..<count).forEach { index in
                    unsafe (dst + index).initialize(to: src[index])
                }
            }
        }

        return new
    }

    /// Copies all elements to new storage.
    ///
    /// - Parameter newStorage: The destination storage.
    /// - Precondition: Elements at indices 0..<header must be initialized.
    /// - Precondition: Destination storage must have sufficient capacity.
    @usableFromInline
    package func copy(to newStorage: Array<Element>.Storage) {
        let count = self.count
        guard count > .zero else { return }
        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                (0..<count).forEach { index in
                    unsafe (dst + index).initialize(to: src[index])
                }
            }
        }
    }
}
