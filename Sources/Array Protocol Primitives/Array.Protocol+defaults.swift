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

import Index_Primitives

extension __ArrayProtocol where Self: ~Copyable {
    /// Calls `body` with a borrowing reference to the element at `index`.
    @inlinable
    public func withElement<R>(at index: Index, _ body: (borrowing Element) -> R) -> R {
        body(self[index])
    }
}

// MARK: - Index navigation (count-derived; hoisted from the Array variants)

extension __ArrayProtocol where Self: ~Copyable, Index == Index_Primitives.Index<Element> {
    /// The index of the first element — always zero.
    @inlinable
    public var startIndex: Index { .zero }

    /// The index one past the last element.
    @inlinable
    public var endIndex: Index { count.map(Ordinal.init) }

    /// Returns the index immediately after `i`, saturating at `endIndex`.
    @inlinable
    public func index(after i: Index) -> Index { i.successor.saturating() }

    /// Returns the index immediately before `i`.
    ///
    /// - Precondition: `i != startIndex` (mirrors `Swift.Array`'s `index(before:)` contract).
    @inlinable
    public func index(before i: Index) -> Index {
        // WHY: the precondition above guarantees `i.predecessor` is in-bounds; violating
        // it is a programmer error that should trap, exactly like `try!` does here.
        // swift-format-ignore: NeverUseForceTry
        // swiftlint:disable:next force_try
        try! i.predecessor.exact()
    }
}
