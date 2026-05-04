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
public import Index_Primitives

// TODO: Should derive from protocol-level `init(repeating:count:)` default.
// See Array.Fixed Repeating.swift for design notes.

extension Array.Fixed.Indexed where Element: Copyable {
    /// Creates an indexed fixed array filled with a repeated value.
    ///
    /// - Parameters:
    ///   - value: The value to repeat.
    ///   - count: The phantom-typed count.
    @inlinable
    public init(repeating value: Element, count: Index_Primitives.Index<Tag>.Count) {
        self._storage = Array<Element>.Fixed(repeating: value, count: count.retag(Element.self))
    }
}
