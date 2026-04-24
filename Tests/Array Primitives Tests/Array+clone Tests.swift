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

@Suite("Array clone")
struct ArrayCloneTests {

    @Test
    func `clone produces independent storage`() {
        var original: Array<Int> = []
        original.append(1)
        original.append(2)
        original.append(3)

        let cloned = original.clone()

        original.append(999)

        #expect(original.count == 4)
        #expect(cloned.count == 3)
    }

    @Test
    func `clone sizes capacity to count`() {
        var source = Array<Int>(initialCapacity: 100)
        source.append(1)
        source.append(2)

        let cloned = source.clone()

        #expect(cloned.count == 2)
        #expect(cloned.capacity < source.capacity)
    }

    @Test
    func `clone of empty array`() {
        let source = Array<Int>()
        let cloned = source.clone()
        #expect(cloned.isEmpty)
    }

    @Test
    func `clone with explicit capacity`() {
        var source: Array<Int> = []
        source.append(10)
        source.append(20)

        let cloned = source.clone(capacity: 50)

        #expect(cloned.count == 2)
        #expect(cloned.capacity >= 50)

        source.append(999)
        #expect(cloned.count == 2)
    }

    @Test
    func `clone contents match original`() {
        var source: Array<Int> = []
        source.append(100)
        source.append(200)
        source.append(300)

        let cloned = source.clone()

        #expect(cloned.count == source.count)
        let first = Array<Int>.Index(Ordinal(0))
        let second = Array<Int>.Index(Ordinal(1))
        let third = Array<Int>.Index(Ordinal(2))
        #expect(cloned.withElement(at: first) { $0 } == 100)
        #expect(cloned.withElement(at: second) { $0 } == 200)
        #expect(cloned.withElement(at: third) { $0 } == 300)
    }
}
