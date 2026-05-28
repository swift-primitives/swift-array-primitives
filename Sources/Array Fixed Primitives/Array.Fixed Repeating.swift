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
public import Array_Fixed_Primitive
public import Array_Protocol_Primitives
// TODO: `init(repeating:count:)` should derive from a protocol requirement
// `init(count:initializingWith:)` so all conformers get `repeating` for free.
// Candidate home: Array.Protocol or a Finite.Constructible protocol.

extension Array.Fixed where Element: Copyable {
    /// Creates a fixed array filled with a repeated value.
    ///
    /// - Parameters:
    ///   - value: The value to repeat.
    ///   - count: The number of elements.
    @inlinable
    public init(repeating value: Element, count: Array.Index.Count) {
        self.init(__unchecked: (), count: count, initializingWith: { _ in value })
    }
}
