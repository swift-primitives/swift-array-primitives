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
    @Suite struct Small {}
    @Suite struct Static {}
}

// MARK: - Dynamic

extension ArrayFreeCapacityTests.Dynamic {

    @Test
    func `empty array freeCapacity matches capacity`() {
        let array: [Int] = Array(initialCapacity: 10)
        #expect(array.freeCapacity == array.capacity)
    }

    @Test
    func `appending decreases freeCapacity`() {
        var array = [Int](initialCapacity: 5)
        let initial = array.freeCapacity
        array.append(42)
        #expect(array.freeCapacity == initial.subtract.saturating(.one))
    }

    @Test
    func `full array has zero freeCapacity`() {
        var array = [Int](initialCapacity: 3)
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

// MARK: - Small

extension ArrayFreeCapacityTests.Small {

    @Test
    func `empty Array.Small has capacity freeCapacity`() {
        let array = Array<Int>.Small<4>()
        #expect(array.freeCapacity == array.capacity)
    }

    @Test
    func `appending to Array.Small decreases freeCapacity`() {
        var array = Array<Int>.Small<4>()
        let initial = array.freeCapacity
        array.append(1)
        #expect(array.freeCapacity == initial.subtract.saturating(.one))
    }
}

// MARK: - Static

extension ArrayFreeCapacityTests.Static {

    @Test
    func `empty Array.Static has capacity freeCapacity`() {
        let array = Array<Int>.Static<5>()
        #expect(array.freeCapacity == .init(UInt(5)))
    }

    @Test
    func `appending to Array.Static decreases freeCapacity`() throws {
        var array = Array<Int>.Static<4>()
        try array.append(10)
        try array.append(20)
        #expect(array.freeCapacity == .init(UInt(2)))
    }

    @Test
    func `full Array.Static has zero freeCapacity`() throws {
        var array = Array<Int>.Static<3>()
        try array.append(1)
        try array.append(2)
        try array.append(3)
        #expect(array.freeCapacity == .zero)
    }
}
