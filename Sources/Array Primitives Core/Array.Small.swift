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

// Note: Array.Small is declared INSIDE the Array enum body (in Array.swift)
// due to a Swift compiler bug where nested types with value generic parameters
// declared in extensions do not properly inherit ~Copyable constraints from
// the outer type. This file contains only the minimal extensions required
// for the workaround. Public API is in Array Small Primitives module.

public import Index_Primitives

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
        /// Maximum element stride supported by inline storage (64 bytes per slot).
        @usableFromInline
        package static var maxElementStride: Int { 64 }

        /// Raw byte storage for inline elements.
        @usableFromInline
        package var _inline: InlineArray<inlineCapacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        /// Current element count (valid in both inline and heap modes).
        @usableFromInline
        package var _count: Index_Primitives.Index<Element>.Count

        /// Heap storage state when spilled. Nil when using inline storage.
        ///
        /// Contains both the storage reference and cached element pointer,
        /// ensuring they are always consistent by construction.
        @usableFromInline
        package var _heap: Heap.State?

        /// Creates an empty small array.
        ///
        /// - Throws: `Error.strideExceedsSlotSize` if element stride exceeds inline storage slot size (64 bytes).
        /// - Throws: `Error.alignmentExceedsStorageAlignment` if element alignment exceeds inline storage alignment.
        @inlinable
        public init() throws(Error) {
            let stride = MemoryLayout<Element>.stride
            let alignment = MemoryLayout<Element>.alignment

            guard stride <= Self.maxElementStride else {
                throw .strideExceedsSlotSize(
                    elementStride: stride,
                    maxSlotSize: Self.maxElementStride
                )
            }
            guard alignment <= MemoryLayout<Int>.alignment else {
                throw .alignmentExceedsStorageAlignment(
                    elementAlignment: alignment,
                    maxAlignment: MemoryLayout<Int>.alignment
                )
            }

            self._inline = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
            self._count = .zero
            self._heap = nil
        }

        deinit {
            let count = _count.rawValue
            guard count > 0 else { return }

            if let heap = _heap {
                // Elements are on heap - ElementStorage handles cleanup via its deinit
                heap.storage.header = count
            } else {
                // Elements are inline - clean up manually
                let stride = MemoryLayout<Element>.stride
                unsafe Swift.withUnsafeBytes(of: _inline) { bytes in
                    let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                    for i in 0..<count {
                        let elementPtr = unsafe (basePtr + i * stride)
                            .assumingMemoryBound(to: Element.self)
                        unsafe elementPtr.deinitialize(count: 1)
                    }
                }
            }
        }
    }
}
