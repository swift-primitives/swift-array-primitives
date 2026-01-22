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
// Since Array.Bounded is nested inside a generic type, we use a dedicated test enum.
// This follows [TEST-ORG-005] for types that cannot have nested Test types.

/// Test namespace for Array.Bounded
enum ArrayBoundedTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
    @Suite struct Performance {}
}

// MARK: - Unit Tests

extension ArrayBoundedTests.Unit {

    @Test("Init with count and closure")
    func initWithCountAndClosure() throws {
        let array = try Array<Int>.Bounded(count: 5) { index in
            index * 2
        }

        #expect(array.count == 5)
        #expect(array[try Index<Int>(0)] == 0)
        #expect(array[try Index<Int>(1)] == 2)
        #expect(array[try Index<Int>(2)] == 4)
        #expect(array[try Index<Int>(3)] == 6)
        #expect(array[try Index<Int>(4)] == 8)
    }

    @Test("Subscript read access")
    func subscriptReadAccess() throws {
        let array = try Array<String>.Bounded(count: 3) { _ in "test" }

        #expect(array[try Index<String>(0)] == "test")
        #expect(array[try Index<String>(1)] == "test")
        #expect(array[try Index<String>(2)] == "test")
    }

    @Test("Subscript write access")
    func subscriptWriteAccess() throws {
        var array = try Array<Int>.Bounded(count: 3) { $0 }

        array[try Index<Int>(1)] = 100

        #expect(array[try Index<Int>(0)] == 0)
        #expect(array[try Index<Int>(1)] == 100)
        #expect(array[try Index<Int>(2)] == 2)
    }

    @Test("Count property")
    func countProperty() throws {
        let array = try Array<Int>.Bounded(count: 10) { $0 }
        #expect(array.count == 10)
    }

    @Test("Empty array")
    func emptyArray() throws {
        let array = try Array<Int>.Bounded(count: 0) { $0 }
        #expect(array.count == 0)
    }
}

// MARK: - Edge Case Tests

extension ArrayBoundedTests.EdgeCase {

    @Test("Single element array")
    func singleElementArray() throws {
        let array = try Array<Int>.Bounded(count: 1) { _ in 42 }

        #expect(array.count == 1)
        #expect(array[try Index<Int>(0)] == 42)
    }

    @Test("Large array")
    func largeArray() throws {
        let array = try Array<Int>.Bounded(count: 10000) { $0 }

        #expect(array.count == 10000)
        #expect(array[try Index<Int>(0)] == 0)
        #expect(array[try Index<Int>(9999)] == 9999)
    }
}

// MARK: - Integration Tests

extension ArrayBoundedTests.Integration {
    // Integration tests for cross-type interactions
}

// MARK: - Performance Tests

extension ArrayBoundedTests.Performance {
    // Performance tests with .timed() trait
}
