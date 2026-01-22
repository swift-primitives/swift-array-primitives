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
// Since Array.Unbounded is nested inside a generic type, we use a dedicated test enum.
// This follows [TEST-ORG-005] for types that cannot have nested Test types.

/// Test namespace for Array.Unbounded
enum ArrayUnboundedTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
    @Suite struct Performance {}
}

// MARK: - Unit Tests

extension ArrayUnboundedTests.Unit {

    @Test("Init empty")
    func initEmpty() {
        let array = Array<Int>.Unbounded<4>()
        #expect(array.count == 0)
    }

    @Test("Append single element")
    func appendSingleElement() throws {
        var array = Array<Int>.Unbounded<4>()
        array.append(42)

        #expect(array.count == 1)
        #expect(array[try Index<Int>(0)] == 42)
    }

    @Test("Append multiple elements")
    func appendMultipleElements() throws {
        var array = Array<Int>.Unbounded<4>()
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
        var array = Array<Int>.Unbounded<4>()
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
        var array = Array<Int>.Unbounded<4>()
        #expect(array.count == 0)

        array.append(1)
        #expect(array.count == 1)
    }
}

// MARK: - Edge Case Tests

extension ArrayUnboundedTests.EdgeCase {

    @Test("Growth beyond initial capacity")
    func growthBeyondInitialCapacity() throws {
        var array = Array<Int>.Unbounded<4>()

        // Append more than initial capacity
        for i in 0..<100 {
            array.append(i)
        }

        #expect(array.count == 100)
        #expect(array[try Index<Int>(0)] == 0)
        #expect(array[try Index<Int>(99)] == 99)
    }
}

// MARK: - Integration Tests

extension ArrayUnboundedTests.Integration {
    // Integration tests for cross-type interactions
}

// MARK: - Performance Tests

extension ArrayUnboundedTests.Performance {
    // Performance tests with .timed() trait
}
