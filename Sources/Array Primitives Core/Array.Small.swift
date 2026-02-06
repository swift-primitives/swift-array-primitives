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
        
        /// Inline storage for elements.
        @usableFromInline
        package var inline: Storage_Primitives.Storage<Element>.Static<inlineCapacity>

        /// Heap storage state when spilled. Nil when using inline storage.
        ///
        /// Contains both the storage reference and cached element pointer,
        /// ensuring they are always consistent by construction.
        @usableFromInline
        package var heap: Array.Small<inlineCapacity>.Heap?

        /// Creates an empty small array.
        ///
        /// - Throws: `Error.strideExceedsSlotSize` if element stride exceeds inline storage slot size (64 bytes).
        /// - Throws: `Error.alignmentExceedsStorageAlignment` if element alignment exceeds inline storage alignment.
        @inlinable
        public init() throws(Error) {
            let stride = MemoryLayout<Element>.stride
            let alignment = MemoryLayout<Element>.alignment

            guard stride <= Storage.Inline<inlineCapacity>.maxStride else {
                throw .strideExceedsSlotSize(
                    elementStride: stride,
                    maxSlotSize: Storage.Inline<inlineCapacity>.maxStride
                )
            }
            guard alignment <= MemoryLayout<Int>.alignment else {
                throw .alignmentExceedsStorageAlignment(
                    elementAlignment: alignment,
                    maxAlignment: MemoryLayout<Int>.alignment
                )
            }

            self.inline = try! Storage.Inline<inlineCapacity>()
            self.count = .zero
            self.heap = nil
        }

        deinit {
            guard count > .zero else { return }

            if let heapState = heap {
                // Elements are on heap - ElementStorage handles cleanup via its deinit
                heapState.storage.count = count
            } else {
                // Elements are inline - clean up via Storage.Inline
                inline.deinitialize(count: count)
            }
        }
    }
}


