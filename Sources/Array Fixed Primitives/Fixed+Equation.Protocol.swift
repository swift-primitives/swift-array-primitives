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
public import Span_Protocol_Primitives
public import Equation_Primitives_Standard_Library_Integration

// MARK: - Equation.Protocol Conformance (span-keyed; span-vending columns)

extension Fixed: Equation.`Protocol` where S: Span.`Protocol` & ~Copyable, S.Element: Equation.`Protocol` {
    /// Compares two fixed arrays for element-wise, ordered equality over the span.
    @inlinable
    public static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        lhs.span == rhs.span
    }
}
