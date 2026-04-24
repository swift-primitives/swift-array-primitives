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

import Testing
@testable import Array_Primitives
import Array_Primitives_Test_Support

@Suite("Array reserveCapacity")
struct ArrayReserveCapacityTests {

    @Test
    func `reserveCapacity grows when needed`() {
        var array = Array<Int>()
        array.reserveCapacity(100)
        #expect(array.capacity >= 100)
        #expect(array.isEmpty)
    }

    @Test
    func `reserveCapacity less than current is noop`() {
        var array = Array<Int>(initialCapacity: 50)
        let initial = array.capacity
        array.reserveCapacity(10)
        #expect(array.capacity == initial)
    }

    @Test
    func `reserveCapacity preserves existing elements`() {
        var array = Array<Int>()
        array.append(1)
        array.append(2)
        array.append(3)
        array.reserveCapacity(100)
        #expect(array.count == 3)
        #expect(array.capacity >= 100)
    }

    @Test
    func `reserveCapacity with CoW makes copy before growing`() {
        var original: Array<Int> = []
        original.append(1)
        original.append(2)

        var copy = original
        copy.reserveCapacity(100)

        #expect(copy.count == 2)
        #expect(copy.capacity >= 100)
        // Original should be unchanged (small capacity, no growth triggered).
        #expect(original.count == 2)
    }
}
