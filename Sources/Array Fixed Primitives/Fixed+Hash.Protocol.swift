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
public import Hash_Primitives_Standard_Library_Integration

// MARK: - Hash.Protocol Conformance (span-keyed; span-vending columns)

extension Fixed: Hash.`Protocol` where S: Span.`Protocol` & ~Copyable, S.Element: Hash.`Protocol` {
    /// Hashes the count and elements, in order, over the span.
    @inlinable
    public borrowing func hash(into hasher: inout Hasher) {
        span.hash(into: &hasher)
    }
}
