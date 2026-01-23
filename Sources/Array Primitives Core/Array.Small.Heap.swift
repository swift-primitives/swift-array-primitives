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
    /// Accessor for heap storage operations.
    ///
    /// Provides pointer-based access to heap storage. Uses a minimal custom
    /// struct because Swift does not support introducing value generics in
    /// extension where clauses, preventing use of Property.View.Typed pattern.
    @usableFromInline
    @safe
    package struct Heap: ~Copyable, ~Escapable {
        @usableFromInline
        let _base: UnsafeMutablePointer<Array<Element>.Small<inlineCapacity>>

        @usableFromInline
        @_lifetime(borrow base)
        init(_ base: UnsafeMutablePointer<Array<Element>.Small<inlineCapacity>>) {
            unsafe self._base = base
        }

        /// Creates new heap storage with specified capacity.
        @usableFromInline
        package func create(minimumCapacity: Int) -> Array<Element>.Storage {
            let newCapacity = Swift.max(minimumCapacity, inlineCapacity * 2, 8)
            return Array<Element>.Storage.create(minimumCapacity: newCapacity)
        }

        /// Adopts heap storage, updating internal pointers.
        @usableFromInline
        @_lifetime(&self)
        package mutating func adopt(_ newStorage: Array<Element>.Storage) {
            unsafe _base.pointee._heapStorage = newStorage
            unsafe (_base.pointee._heapPtr = newStorage._elementsPointer)
        }

        /// Ensures capacity, reallocating if needed.
        @usableFromInline
        @_lifetime(&self)
        package mutating func ensureCapacity(_ minimumCapacity: Int) {
            guard let heapStorage = unsafe _base.pointee._heapStorage else {
                preconditionFailure("Not in heap mode")
            }
            guard heapStorage.capacity < minimumCapacity else { return }

            let newCapacity = Swift.max(minimumCapacity, heapStorage.capacity * 2, 8)
            let newStorage = Array<Element>.Storage.create(minimumCapacity: newCapacity)
            let currentCount = heapStorage.header

            heapStorage._moveAllElements(to: newStorage)
            newStorage.header = currentCount
            unsafe _base.pointee._heapStorage = newStorage
            unsafe (_base.pointee._heapPtr = newStorage._elementsPointer)
        }
    }

    /// Access to heap storage operations.
    @usableFromInline
    package var heap: Heap {
        mutating _read {
            yield unsafe Heap(&self)
        }
        mutating _modify {
            var view = unsafe Heap(&self)
            yield &view
        }
    }
}
