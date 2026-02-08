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

import Index_Primitives
public import Array_Primitives_Core

extension Array.Small where Element: ~Copyable {
    /// Combined heap storage reference and cached element pointer.
    ///
    /// This type ensures storage and pointer are always consistent:
    /// when `Array.Small.heap` is non-nil, both the storage reference
    /// and the element pointer are valid. When nil, inline storage is used.
    ///
    /// Uses `Buffer.Linear` static methods for element operations, delegating
    /// growth and lifecycle management to the buffer layer.
    @usableFromInline
    @safe
    package struct Heap {
        /// The heap storage containing elements.
        @usableFromInline
        package var storage: Storage<Element>.Heap

        /// Buffer header tracking count and capacity.
        @usableFromInline
        package var header: Buffer<Element>.Linear.Header

        /// Cached pointer to heap elements for fast access.
        @usableFromInline
        package var pointer: UnsafeMutablePointer<Element>

        /// Creates heap state from storage, caching the element pointer.
        @usableFromInline
        package init(_ storage: Storage<Element>.Heap) {
            self.storage = storage
            self.header = Buffer<Element>.Linear.Header(capacity: storage.slotCapacity)
            self.pointer = unsafe storage.pointer(at: .zero)
        }

        /// Creates new heap storage with specified capacity.
        @usableFromInline
        package static func create(minimumCapacity: Array.Index.Count) -> Storage<Element>.Heap {
            Storage<Element>.Heap.create(
                minimumCapacity: Tagged.max(
                    minimumCapacity,
                    Tagged.max(.init(UInt(inlineCapacity * 2)), .init(UInt(8)))
                )
            )
        }

        /// Ensures capacity, reallocating if needed.
        @usableFromInline
        package mutating func ensureCapacity(_ minimumCapacity: Array.Index.Count) {
            let storageCapacity = storage.slotCapacity
            guard storageCapacity < minimumCapacity else { return }

            let newCapacity = Tagged.max(
                minimumCapacity,
                Tagged.max(storageCapacity + storageCapacity, .init(UInt(8)))
            )
            let newStorage = Storage<Element>.Heap.create(minimumCapacity: newCapacity)
            let currentCount = header.count

            // Move all elements from old to new storage
            if currentCount > .zero {
                let endIndex = currentCount.map(Ordinal.init)
                storage.move(range: .zero..<endIndex, to: newStorage)
                storage.initialization = .empty
                newStorage.initialization = .linear(count: currentCount)
            }

            self.storage = newStorage
            self.header = Buffer<Element>.Linear.Header(capacity: newStorage.slotCapacity)
            self.header.count = currentCount
            self.pointer = unsafe newStorage.pointer(at: .zero)
        }
    }
}
