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

extension Array.Small where Element: ~Copyable {
    /// Accessor for inline storage operations.
    ///
    /// Provides pointer-based access to inline elements. Delegates to the
    /// underlying `Storage.Inline` instance.
    @usableFromInline
    @safe
    package struct Inline: ~Copyable, ~Escapable {
        @usableFromInline
        let _base: UnsafeMutablePointer<Array<Element>.Small<inlineCapacity>>

        @usableFromInline
        @_lifetime(borrow base)
        init(_ base: UnsafeMutablePointer<Array<Element>.Small<inlineCapacity>>) {
            unsafe self._base = unsafe base
        }

        /// Returns a mutable pointer to the inline element at the given index.
        @usableFromInline
        @unsafe
        package func pointer(at index: Int) -> UnsafeMutablePointer<Element> {
            unsafe _base.pointee._inline.pointer(at: index)
        }

        /// Returns a read-only pointer to the inline element at the given index.
        @usableFromInline
        @unsafe
        package func read(at index: Int) -> UnsafePointer<Element> {
            unsafe _base.pointee._inline.read(at: index)
        }

        /// Moves all inline elements to target heap storage.
        @usableFromInline
        @unsafe
        @_lifetime(&self)
        package mutating func move(to target: Array<Element>.Storage) {
            let count = unsafe _base.pointee._count.rawValue
            unsafe _base.pointee._inline.move(to: target, count: count)
        }
    }

    /// Access to inline storage operations.
    @usableFromInline
    package var inline: Inline {
        mutating _read {
            yield unsafe Inline(&self)
        }
        mutating _modify {
            var view = unsafe Inline(&self)
            yield &view
        }
    }
}
