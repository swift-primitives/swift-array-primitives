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
// Since Array.Inline is nested inside a generic type, we use a dedicated test enum.
// This follows [TEST-ORG-005] for types that cannot have nested Test types.

/// Test namespace for Array.Inline
enum ArrayInlineTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
    @Suite struct Performance {}
}

// MARK: - Unit Tests

extension ArrayInlineTests.Unit {

    @Test("Init empty")
    func initEmpty() {
        let array = Array<Int>.Inline<8>()
        #expect(array.count == 0)
    }

    @Test("Append single element")
    func appendSingleElement() throws {
        var array = Array<Int>.Inline<8>()
        try array.append(42)

        #expect(array.count == 1)
        #expect(array[try Index<Int>(0)] == 42)
    }

    @Test("Append multiple elements")
    func appendMultipleElements() throws {
        var array = Array<Int>.Inline<8>()
        try array.append(1)
        try array.append(2)
        try array.append(3)

        #expect(array.count == 3)
        #expect(array[try Index<Int>(0)] == 1)
        #expect(array[try Index<Int>(1)] == 2)
        #expect(array[try Index<Int>(2)] == 3)
    }

    @Test("Subscript write access")
    func subscriptWriteAccess() throws {
        var array = Array<Int>.Inline<8>()
        try array.append(1)
        try array.append(2)
        try array.append(3)

        array[try Index<Int>(1)] = 100

        #expect(array[try Index<Int>(0)] == 1)
        #expect(array[try Index<Int>(1)] == 100)
        #expect(array[try Index<Int>(2)] == 3)
    }

    @Test("Count property")
    func countProperty() throws {
        var array = Array<Int>.Inline<8>()
        #expect(array.count == 0)

        try array.append(1)
        #expect(array.count == 1)
    }

    @Test("Fill to capacity")
    func fillToCapacity() throws {
        var array = Array<Int>.Inline<4>()
        try array.append(1)
        try array.append(2)
        try array.append(3)
        try array.append(4)

        #expect(array.count == 4)
    }
}

// MARK: - Edge Case Tests

extension ArrayInlineTests.EdgeCase {

    @Test("Append beyond capacity throws")
    func appendBeyondCapacityThrows() throws {
        var array = Array<Int>.Inline<2>()
        try array.append(1)
        try array.append(2)

        #expect(throws: (any Error).self) {
            try array.append(3)
        }
    }

    @Test("Single element capacity")
    func singleElementCapacity() throws {
        var array = Array<Int>.Inline<1>()
        try array.append(42)

        #expect(array.count == 1)
        #expect(array[try Index<Int>(0)] == 42)
    }
}

// MARK: - Integration Tests

extension ArrayInlineTests.Integration {
    // Integration tests for cross-type interactions
}

// MARK: - Performance Tests

extension ArrayInlineTests.Performance {
    // Performance tests with .timed() trait
}
