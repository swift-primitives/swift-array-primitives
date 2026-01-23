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

// MARK: - Creation

extension Array.Storage where Element: ~Copyable {
    /// Creates empty storage with the specified minimum capacity.
    ///
    /// Used by growable arrays (Unbounded, Small heap mode).
    @usableFromInline
    package static func create(minimumCapacity: Int) -> Array<Element>.Storage {
        let storage = Array<Element>.Storage.create(minimumCapacity: minimumCapacity) { _ in 0 }
        return unsafe unsafeDowncast(storage, to: Array<Element>.Storage.self)
    }

    /// Creates storage with the specified capacity, initialized with elements.
    ///
    /// Used by fixed-size arrays (Bounded).
    @usableFromInline
    static func create(
        capacity: Int,
        initializingWith initializer: (Int) -> Element
    ) -> Array.Storage {
        let storage = Array.Storage.create(minimumCapacity: capacity) { _ in 0 }
        let typed = unsafe unsafeDowncast(storage, to: Array.Storage.self)

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
    static func createEmpty() -> Array.Storage {
        let storage = Array.Storage.create(minimumCapacity: 0) { _ in 0 }
        return unsafe unsafeDowncast(storage, to: Array.Storage.self)
    }
}

// MARK: - Element Access

extension Array.Storage where Element: ~Copyable {
    /// Returns pointer to element storage.
    @usableFromInline
    package var _elementsPointer: UnsafeMutablePointer<Element> {
        unsafe withUnsafeMutablePointerToElements { unsafe $0 }
    }

    /// Initializes element at the given index.
    @usableFromInline
    package func _initializeElement(at index: Int, to element: consuming Element) {
        let ptr = unsafe withUnsafeMutablePointerToElements { unsafe $0 + index }
        unsafe ptr.initialize(to: element)
    }

    /// Moves element from the given index.
    @usableFromInline
    package func _moveElement(at index: Int) -> Element {
        unsafe withUnsafeMutablePointerToElements { elements in
            unsafe (elements + index).move()
        }
    }
}

// MARK: - Bulk Operations

extension Array.Storage where Element: ~Copyable {
    /// Deinitializes elements in the given range.
    @usableFromInline
    func _deinitializeElements(in range: Range<Int>) {
        _ = unsafe withUnsafeMutablePointerToElements { elements in
            for i in range {
                unsafe (elements + i).deinitialize(count: 1)
            }
        }
    }

    /// Deinitializes all elements and sets header to 0.
    @usableFromInline
    package func _deinitializeAllElements() {
        let count = header
        guard count > 0 else { return }
        _ = unsafe withUnsafeMutablePointerToElements { elements in
            for i in 0..<count {
                unsafe (elements + i).deinitialize(count: 1)
            }
        }
        header = 0
    }

    /// Moves all elements to new storage.
    @usableFromInline
    package func _moveAllElements(to newStorage: Array<Element>.Storage) {
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
}

// MARK: - Copy-on-Write (Copyable elements only)

extension Array.Storage where Element: Copyable {
    /// Creates a copy of this storage.
    @usableFromInline
    package func copy() -> Array<Element>.Storage {
        let count = header
        guard count > 0 else {
            return Array<Element>.Storage.create(minimumCapacity: 0)
        }

        let new = Array<Element>.Storage.create(minimumCapacity: capacity)
        new.header = count

        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe new.withUnsafeMutablePointerToElements { dst in
                for i in 0..<count {
                    unsafe (dst + i).initialize(to: src[i])
                }
            }
        }

        return new
    }

    /// Copies all elements to new storage.
    @usableFromInline
    package func _copyAllElements(to newStorage: Array<Element>.Storage) {
        let count = header
        guard count > 0 else { return }
        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                for i in 0..<count {
                    unsafe (dst + i).initialize(to: src[i])
                }
            }
        }
    }

    /// Reads element at the given index (Copyable elements only).
    @usableFromInline
    package func _readElement(at index: Int) -> Element {
        unsafe withUnsafeMutablePointerToElements { elements in
            unsafe (elements + index).pointee
        }
    }
}
