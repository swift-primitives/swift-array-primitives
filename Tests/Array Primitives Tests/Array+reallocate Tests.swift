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

@Suite("Array reallocate")
struct ArrayReallocateTests {

    @Test
    func `reallocate can grow`() {
        var array = [Int]()
        array.append(1)
        array.append(2)
        array.reallocate(capacity: 100)
        #expect(array.capacity >= 100)
        #expect(array.count == 2)
    }

    @Test
    func `reallocate can shrink`() {
        var array = [Int]()
        array.reserveCapacity(100)
        array.append(10)
        array.append(20)
        let beforeShrink = array.capacity
        array.reallocate(capacity: 5)
        #expect(array.capacity < beforeShrink)
        #expect(array.count == 2)
    }

    @Test
    func `reallocate preserves elements`() {
        var array: [Int] = []
        array.append(100)
        array.append(200)
        array.append(300)
        array.reallocate(capacity: 50)

        let i0 = Array<Int>.Index(Ordinal(0))
        let i1 = Array<Int>.Index(Ordinal(1))
        let i2 = Array<Int>.Index(Ordinal(2))
        #expect(array.withElement(at: i0) { $0 } == 100)
        #expect(array.withElement(at: i1) { $0 } == 200)
        #expect(array.withElement(at: i2) { $0 } == 300)
    }

    @Test
    func `reallocate on shared copy does not affect original`() {
        var original: [Int] = []
        original.reserveCapacity(100)
        original.append(1)
        original.append(2)
        let originalCap = original.capacity

        var copy = original
        copy.reallocate(capacity: 5)

        #expect(copy.count == 2)
        #expect(copy.capacity < originalCap)
        #expect(original.count == 2)
        #expect(original.capacity == originalCap)
    }
}
