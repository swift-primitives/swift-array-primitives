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

public import Array_Primitives_Core

extension Array.Small.Heap where Element: ~Copyable {
    /// Accessor view for heap storage operations.
    ///
    /// Provides pointer-based access to heap storage. Uses a minimal custom
    /// struct because Swift does not support introducing value generics in
    /// extension where clauses, preventing use of Property.View.Typed pattern.
    @usableFromInline
    @safe
    package struct View: ~Copyable, ~Escapable {
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

        /// Adopts heap storage, updating internal state.
        @usableFromInline
        @_lifetime(&self)
        package mutating func adopt(_ newStorage: Array<Element>.Storage) {
            unsafe _base.pointee._heap = Array<Element>.Small<inlineCapacity>.Heap(newStorage)
        }

        /// Ensures capacity, reallocating if needed.
        @usableFromInline
        @_lifetime(&self)
        package mutating func ensureCapacity(_ minimumCapacity: Int) {
            guard let heapState = unsafe _base.pointee._heap else {
                preconditionFailure("Not in heap mode")
            }
            guard heapState.storage.capacity < minimumCapacity else { return }

            let newCapacity = Swift.max(minimumCapacity, heapState.storage.capacity * 2, 8)
            let newStorage = Array<Element>.Storage.create(minimumCapacity: newCapacity)
            let currentCount = heapState.storage.header

            heapState.storage._moveAllElements(to: newStorage)
            newStorage.header = currentCount
            unsafe _base.pointee._heap = Array<Element>.Small<inlineCapacity>.Heap(newStorage)
        }
    }
}

extension Array.Small where Element: ~Copyable {
    /// Access to heap storage operations.
    @usableFromInline
    package var heap: Heap.View {
        mutating _read {
            yield unsafe Heap.View(&self)
        }
        mutating _modify {
            var view = unsafe Heap.View(&self)
            yield &view
        }
    }
}
