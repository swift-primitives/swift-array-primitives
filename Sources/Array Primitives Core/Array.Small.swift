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
public import Array_Primitives_Core

extension Array where Element: ~Copyable {

    // MARK: - Small (SmallVec Pattern)

    /// An array with small-buffer optimization (SmallVec pattern).
    ///
    /// `Array.Small` stores up to `inlineCapacity` elements in inline storage,
    /// then automatically spills to heap storage when that capacity is exceeded.
    ///
    /// - Note: This type is declared inside `Array` (not in an extension) due to a
    ///   Swift compiler bug. Public API is in the Array Small Primitives module.
    @safe
    public struct Small<let inlineCapacity: Int>: ~Copyable {

        /// Current element count (valid in both inline and heap modes).
        public var count: Index.Count

        /// Inline buffer for elements (used when count <= inlineCapacity).
        @usableFromInline
        package var _inlineBuffer: Buffer<Element>.Linear.Inline<inlineCapacity>

        /// Heap storage state when spilled. Nil when using inline storage.
        ///
        /// Contains both the storage reference and cached element pointer,
        /// ensuring they are always consistent by construction.
        @usableFromInline
        package var heap: Array.Small<inlineCapacity>.Heap?

        /// Creates an empty small array.
        @inlinable
        public init() {
            self._inlineBuffer = Buffer<Element>.Linear.Inline<inlineCapacity>()
            self.count = .zero
            self.heap = nil
        }

        deinit {
            guard count > .zero else { return }

            if let heapState = heap {
                // Sync initialization state so Storage.Heap's deinit knows what to clean up.
                // Storage.Heap.deinit reads header.initialization to deinitialize elements.
                heapState.storage.initialization = .linear(count: count)
            }
            // Inline path: Storage.Inline's deinit auto-cleans up via _slots bit tracking.
        }
    }
}
