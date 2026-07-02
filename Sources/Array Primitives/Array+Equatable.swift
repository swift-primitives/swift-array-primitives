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

// MARK: - Equatable (the S5 chain)

/// Element-keyed equality chains through the COLUMN: `Shared` carries `Equatable` exactly
/// when its (direct) `Element` parameter does — element-wise over live elements,
/// capacity-independent — so `Array<Shared<Int, …>> == Array<Shared<Int, …>>` compares
/// elements. Move-only columns are never `Equatable`, by design (R-1: copyability — and
/// with it value-semantic comparison — flows from the column).
extension __Array: Equatable where S: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.store == rhs.store
    }
}
