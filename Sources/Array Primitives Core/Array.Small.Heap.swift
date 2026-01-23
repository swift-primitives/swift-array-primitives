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

extension Array.Small where Element: ~Copyable {
    /// Combined heap storage reference and cached element pointer.
    ///
    /// This type ensures storage and pointer are always consistent:
    /// when `Array.Small.heap` is non-nil, both the storage reference
    /// and the element pointer are valid. When nil, inline storage is used.
    ///
    /// This makes an inconsistent state (pointer without storage, or vice versa)
    /// unrepresentable by construction.
    @usableFromInline
    @safe
    package struct Heap {
        /// The heap storage containing elements.
        @usableFromInline
        package var storage: Array<Element>.Storage

        /// Cached pointer to heap elements for fast access.
        @usableFromInline
        package var pointer: UnsafeMutablePointer<Element>

        /// Creates heap state from storage, caching the element pointer.
        @usableFromInline
        package init(_ storage: Array<Element>.Storage) {
            self.storage = storage
            unsafe self.pointer = storage.pointer(at: 0)
        }

        /// Creates new heap storage with specified capacity.
        @usableFromInline
        package static func create(minimumCapacity: Array.Index.Count) -> Array<Element>.Storage {
            let newCapacity = Swift.max(minimumCapacity.rawValue, inlineCapacity * 2, 8)
            return Array<Element>.Storage.create(minimumCapacity: .init(__unchecked: newCapacity))
        }

        /// Ensures capacity, reallocating if needed.
        @usableFromInline
        package mutating func ensureCapacity(_ minimumCapacity: Int) {
            guard storage.capacity < minimumCapacity else { return }

            let newCapacity = Swift.max(minimumCapacity, storage.capacity * 2, 8)
            let newStorage = Array<Element>.Storage.create(minimumCapacity: .init(__unchecked: newCapacity))
            let currentCount = storage.header

            storage.move(to: newStorage)
            newStorage.header = currentCount

            self.storage = newStorage
            unsafe self.pointer = newStorage.pointer(at: 0)
        }
    }
}
