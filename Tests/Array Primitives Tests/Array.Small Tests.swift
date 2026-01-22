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
import Index_Primitives

// MARK: - Test Suite Structure
//
// Note: Swift Testing's @Suite/@Test macros cannot be applied within generic extensions.
// Since Array.Small is nested inside a generic type, we use a dedicated test enum.
// This follows [TEST-ORG-005] for types that cannot have nested Test types.

/// Test namespace for Array.Small (SmallVec pattern)
enum ArraySmallTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
    @Suite struct Performance {}
}

// MARK: - Unit Tests

extension ArraySmallTests.Unit {

    @Test("Init empty")
    func initEmpty() {
        let array = Array<Int>.Small<4>()
        #expect(array.count == 0)
    }

    @Test("Append single element (inline)")
    func appendSingleElementInline() throws {
        var array = Array<Int>.Small<4>()
        array.append(42)

        #expect(array.count == 1)
        #expect(array[try Index<Int>(0)] == 42)
    }

    @Test("Append multiple elements (inline)")
    func appendMultipleElementsInline() throws {
        var array = Array<Int>.Small<4>()
        array.append(1)
        array.append(2)
        array.append(3)

        #expect(array.count == 3)
        #expect(array[try Index<Int>(0)] == 1)
        #expect(array[try Index<Int>(1)] == 2)
        #expect(array[try Index<Int>(2)] == 3)
    }

    @Test("Subscript write access")
    func subscriptWriteAccess() throws {
        var array = Array<Int>.Small<4>()
        array.append(1)
        array.append(2)
        array.append(3)

        array[try Index<Int>(1)] = 100

        #expect(array[try Index<Int>(0)] == 1)
        #expect(array[try Index<Int>(1)] == 100)
        #expect(array[try Index<Int>(2)] == 3)
    }

    @Test("Count property")
    func countProperty() {
        var array = Array<Int>.Small<4>()
        #expect(array.count == 0)

        array.append(1)
        #expect(array.count == 1)
    }
}

// MARK: - Edge Case Tests

extension ArraySmallTests.EdgeCase {

    @Test("Spill to heap storage")
    func spillToHeapStorage() throws {
        var array = Array<Int>.Small<4>()

        // Fill inline storage
        array.append(1)
        array.append(2)
        array.append(3)
        array.append(4)

        // Spill to heap
        array.append(5)
        array.append(6)

        #expect(array.count == 6)
        #expect(array[try Index<Int>(0)] == 1)
        #expect(array[try Index<Int>(4)] == 5)
        #expect(array[try Index<Int>(5)] == 6)
    }

    @Test("Large growth after spill")
    func largeGrowthAfterSpill() throws {
        var array = Array<Int>.Small<4>()

        // Append many elements to trigger multiple reallocations
        for i in 0..<100 {
            array.append(i)
        }

        #expect(array.count == 100)
        #expect(array[try Index<Int>(0)] == 0)
        #expect(array[try Index<Int>(99)] == 99)
    }
}

// MARK: - Integration Tests

extension ArraySmallTests.Integration {
    // Integration tests for cross-type interactions
}

// MARK: - Performance Tests

extension ArraySmallTests.Performance {
    // Performance tests with .timed() trait
}
