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

public import Array_Primitive
public import Equation_Primitives_Standard_Library_Integration

// MARK: - Equation.Protocol Conformance

extension Array: Equation.`Protocol` where Element: Equation.`Protocol` & ~Copyable {
    /// Compares two arrays for element-wise, ordered-sequence equality, over the
    /// span (`Span: Equation.Protocol`, equation-primitives Standard Library
    /// Integration). Two arrays are equal iff they have the same count and all
    /// corresponding elements compare equal, in order.
    @inlinable
    public static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        lhs.span == rhs.span
    }
}
