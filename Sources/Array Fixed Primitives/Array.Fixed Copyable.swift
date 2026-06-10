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
import Index_Primitives

// MARK: - Sequenceable: WITHDRAWN at the W4 reshape (upstream cause)
//
// `Buffer.Linear.Bounded.Scalar` — the consuming iterator that backed this conformance —
// is declared `where S: Copyable` upstream, and the W4 `Storage.Contiguous` substrate is
// move-only (R-1), so the bounded Scalar lane is dead until buffer-linear reshapes it.
// Multipass borrowing iteration (Span.`Protocol` + Iterable, `Array.Fixed ~Copyable.swift`)
// remains the iteration surface. Re-admit when the bounded Scalar columnizes.

extension Array.Fixed where S: ~Copyable, S.Element: Copyable {
    /// Returns element at index offset from given base index.
    @inlinable
    public func element(
        at base: Index,
        offsetBy offset: Index.Offset
    ) -> S.Element? {
        guard let newIndex = try? (base + offset) else { return nil }
        guard newIndex < count else { return nil }
        return _buffer[newIndex]
    }

    /// Returns the element at the typed index, or nil if out of bounds.
    @inlinable
    public func element(at index: Index) -> S.Element? {
        guard index < count else { return nil }
        return _buffer[index]
    }
}
