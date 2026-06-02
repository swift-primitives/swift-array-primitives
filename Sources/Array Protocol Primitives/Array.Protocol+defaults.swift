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

// MARK: - Default Implementations

public import Array_Primitive
import Index_Primitives

extension Array.`Protocol` where Self: ~Copyable {
    /// Calls `body` with a borrowing reference to the element at `index`.
    @inlinable
    public func withElement<R>(at index: Index, _ body: (borrowing Element) -> R) -> R {
        body(self[index])
    }
}

// MARK: - Index navigation (count-derived; hoisted from the Array variants)

extension Array.`Protocol` where Self: ~Copyable, Index == Index_Primitives.Index<Element> {
    @inlinable
    public var startIndex: Index { .zero }

    @inlinable
    public var endIndex: Index { count.map(Ordinal.init) }

    @inlinable
    public func index(after i: Index) -> Index { i.successor.saturating() }

    @inlinable
    public func index(before i: Index) -> Index { try! i.predecessor.exact() }
}
