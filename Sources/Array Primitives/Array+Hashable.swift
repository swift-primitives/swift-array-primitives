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

// MARK: - Hashable (the S5 chain)

/// Element-keyed hashing chains through the COLUMN (see `Array+Equatable.swift`):
/// `Shared` hashes count + live elements in order, so equal arrays hash equal across
/// distinct boxes and capacities.
extension __Array: Hashable where S: Hashable {
    /// Hashes by forwarding to the column's own `Hashable` conformance.
    @inlinable
    public func hash(into hasher: inout Hasher) {
        store.hash(into: &hasher)
    }
}
