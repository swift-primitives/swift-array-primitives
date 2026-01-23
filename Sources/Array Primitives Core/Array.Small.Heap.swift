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
    /// when `Array.Small._heap` is non-nil, both the storage reference
    /// and the element pointer are valid. When nil, inline storage is used.
    ///
    /// This makes an inconsistent state (pointer without storage, or vice versa)
    /// unrepresentable by construction.
    @usableFromInline
    @safe
    package struct Heap {
        /// The heap storage containing elements.
        @usableFromInline
        package let storage: Array<Element>.Storage

        /// Cached pointer to heap elements for fast access.
        @usableFromInline
        package let pointer: UnsafeMutablePointer<Element>

        /// Creates heap state from storage, caching the element pointer.
        @usableFromInline
        package init(_ storage: Array<Element>.Storage) {
            self.storage = storage
            unsafe self.pointer = storage._elementsPointer
        }
    }
}
