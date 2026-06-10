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
public import Hash_Primitives_Standard_Library_Integration

// MARK: - Hash.Protocol Conformance

extension Array.Fixed: Hash.`Protocol` where S: ~Copyable, S.Element: Hash.`Protocol` {
    /// Hashes the count and elements of this fixed-capacity array, in order, over
    /// the span (`Span: Hash.Protocol`, hash-primitives Standard Library Integration).
    @inlinable
    public borrowing func hash(into hasher: inout Hasher) {
        span.hash(into: &hasher)
    }
}
