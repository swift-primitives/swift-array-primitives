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
public import Collection_Primitives
import Index_Primitives
import Sequence_Primitives

// ============================================================================
// MARK: - Protocol Conformances
// ============================================================================

// Collection.Protocol conformance is inherited through Collection.Bidirectional.

// MARK: Collection.Access.Random Conformance

extension Array.Static: Collection.Access.Random where Element: ~Copyable {}

// MARK: Collection.Remove.Last Conformance

extension Array.Static: Collection.Remove.Last where Element: ~Copyable {}

// MARK: Collection.Clearable Conformance

extension Array.Static: Collection.Clearable where Element: ~Copyable {}

// ============================================================================
// MARK: - Nested Types
// ============================================================================

// MARK: Sequence.Protocol Conformance

extension Array.Static: Sequence.`Protocol` {
    /// Iterator type delegates to the buffer's existing pointer-based iterator.
    public typealias Iterator = Buffer<Element>.Linear.Inline<capacity>.Iterator

    /// Returns a pointer-based iterator over the array elements.
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        _buffer.makeIterator()
    }
}

// MARK: Error

extension Array.Static.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .overflow:
            return "static array is full"
        case .indexOutOfBounds(let index, let count):
            return "index \(index) out of bounds for count \(count)"
        }
    }
}
