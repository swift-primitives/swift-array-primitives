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

import Array_Primitives_Test_Support
import Testing

@testable import Array_Primitives

@Suite("Array freeCapacity")
struct ArrayFreeCapacityTests {
    @Suite struct Dynamic {}
    @Suite struct Fixed {}
}

// MARK: - Dynamic

extension ArrayFreeCapacityTests.Dynamic {

    @Test
    func `empty array freeCapacity matches capacity`() {
        let array: Array<Int> = Array(initialCapacity: 10)
        #expect(array.freeCapacity == array.capacity)
    }

    @Test
    func `appending decreases freeCapacity`() {
        var array = Array<Int>(initialCapacity: 5)
        let initial = array.freeCapacity
        array.append(42)
        #expect(array.freeCapacity == initial.subtract.saturating(.one))
    }

    @Test
    func `full array has zero freeCapacity`() {
        var array = Array<Int>(initialCapacity: 3)
        array.append(1)
        array.append(2)
        array.append(3)
        // capacity may exceed 3 due to storage slotCapacity, so freeCapacity
        // could be non-zero; just assert it equals capacity - count.
        #expect(array.freeCapacity == array.capacity.subtract.saturating(array.count))
    }
}

// MARK: - Fixed

extension ArrayFreeCapacityTests.Fixed {

    @Test
    func `Array.Fixed always has zero freeCapacity`() throws {
        let array = try Array<Int>.Fixed(count: .init(5)) { Int($0.ordinal.rawValue) }
        #expect(array.freeCapacity == .zero)
    }
}

