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

public import Buffer_Linear_Inline_Primitives

extension Array where Element: ~Copyable {

    // MARK: - Static (Fixed-Capacity, Inline Storage)

    /// A fixed-capacity vector with inline storage (static_vector / ArrayVec).
    ///
    /// `Array.Static` stores elements directly within the struct's memory layout,
    /// requiring no heap allocation. The capacity is specified as a compile-time
    /// generic parameter. Count varies from 0 to capacity.
    ///
    /// ## Move-Only
    ///
    /// `Array.Static` is unconditionally `~Copyable` due to its deinitializer requirement.
    /// Both the array and its elements can be move-only types.
    ///
    /// ## Limitations
    ///
    /// - Maximum element stride: 64 bytes (8 Int-sized words)
    /// - Element alignment must not exceed `MemoryLayout<Int>.alignment`
    /// - Capacity is fixed at compile time; use `Array.Small` for flexible sizing
    public struct Static<let capacity: Int>: ~Copyable {
        /// Internal inline linear buffer.
        @usableFromInline
        package var _buffer: Buffer<Element>.Linear.Inline<capacity>

        // WORKAROUND: Forces compiler to execute deinit body.
        // TRACKING: swiftlang/swift #86652 variant (nested ~Copyable deinit chain)
        // WHEN TO REMOVE: When the compiler correctly destroys ~Copyable structs
        //      with cross-package value-generic stored properties.
        private var _deinitWorkaround: AnyObject? = nil

        /// Creates an empty inline array.
        @inlinable
        public init() {
            self._buffer = Buffer<Element>.Linear.Inline<capacity>()
        }

        deinit {
            // WORKAROUND: Manually clean up elements via the mutating path.
            // TRACKING: swiftlang/swift #86652 variant
            unsafe withUnsafePointer(to: _buffer) { ptr in
                unsafe UnsafeMutablePointer(mutating: ptr).pointee.remove.all()
            }
        }
    }
}

// MARK: - Sendable

extension Array.Static: @unchecked Sendable where Element: Sendable {}
