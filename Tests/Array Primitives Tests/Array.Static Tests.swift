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

// MARK: - Test Suite Structure

/// Test namespace for Array.Static
///
/// Note: Array.Static is ~Copyable, so it doesn't conform to Sequence.
/// Use forEach for iteration instead of for-in loops.
enum ArrayStaticTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
    @Suite struct Performance {}
}

// MARK: - Unit Tests

extension ArrayStaticTests.Unit {

    // MARK: - Capacity Invariants

    @Test("Cannot exceed compile-time capacity")
    func cannotExceedCompileTimeCapacity() throws {
        var array = Array<Int>.Static<3>()

        try array.append(1)
        try array.append(2)
        try array.append(3)

        #expect(throws: Array<Int>.Static<3>.Error.self) {
            try array.append(4)
        }

        // Count should still be 3
        #expect(array.count == 3)
    }

    @Test("isFull returns true at capacity")
    func isFullReturnsTrueAtCapacity() throws {
        var array = Array<Int>.Static<2>()

        #expect(array.isFull == false)

        try array.append(1)
        #expect(array.isFull == false)

        try array.append(2)
        #expect(array.isFull == true)
    }

    @Test("Capacity is compile-time constant")
    func capacityIsCompileTimeConstant() throws {
        #expect(Array<Int>.Static<1>.capacity == 1)
        #expect(Array<Int>.Static<4>.capacity == 4)
        #expect(Array<Int>.Static<100>.capacity == 100)
    }

    // MARK: - Count Invariants

    @Test("Empty array has count zero")
    func emptyArrayHasCountZero() {
        let array = Array<Int>.Static<8>()
        #expect(array.count == 0)
        #expect(array.isEmpty == true)
    }

    @Test("Append increments count")
    func appendIncrementsCount() throws {
        var array = Array<Int>.Static<8>()

        try array.append(1)
        #expect(array.count == 1)

        try array.append(2)
        #expect(array.count == 2)
    }

    @Test("RemoveLast decrements count")
    func removeLastDecrementsCount() throws {
        var array = Array<Int>.Static<8>()
        try array.append(1)
        try array.append(2)

        _ = array.removeLast()
        #expect(array.count == 1)

        _ = array.removeLast()
        #expect(array.count == 0)
    }

    @Test("RemoveLast on empty returns nil")
    func removeLastOnEmptyReturnsNil() {
        var array = Array<Int>.Static<8>()
        #expect(array.removeLast() == nil)
    }

    // MARK: - forEach Invariants

    @Test("forEach yields exactly count elements")
    func forEachYieldsExactlyCountElements() throws {
        var array = Array<Int>.Static<10>()
        for i in 0..<5 { try array.append(i) }

        var iteratedCount = 0
        array.forEach { _ in iteratedCount += 1 }

        #expect(iteratedCount == 5)
    }

    @Test("forEach yields elements in insertion order")
    func forEachYieldsElementsInInsertionOrder() throws {
        var array = Array<Int>.Static<8>()
        try array.append(10)
        try array.append(20)
        try array.append(30)

        var elements: [Int] = []
        array.forEach { elements.append($0) }

        #expect(elements == [10, 20, 30])
    }

    @Test("Empty array forEach yields nothing")
    func emptyArrayForEachYieldsNothing() {
        var array = Array<Int>.Static<8>()

        var iteratedCount = 0
        array.forEach { _ in iteratedCount += 1 }

        #expect(iteratedCount == 0)
    }

    @Test("forEach matches subscript access")
    func forEachMatchesSubscriptAccess() throws {
        var array = Array<Int>.Static<10>()
        for i in 0..<5 { try array.append(i * 7) }

        // Collect elements via forEach
        var forEachElements: [Int] = []
        array.forEach { forEachElements.append($0) }

        // Compare with subscript access
        for i in 0..<5 {
            #expect(forEachElements[i] == array[Index<Int>(__unchecked: (), Ordinal(UInt(i)))])
        }
    }

    @Test("Full array forEach yields all elements")
    func fullArrayForEachYieldsAllElements() throws {
        var array = Array<Int>.Static<4>()
        try array.append(1)
        try array.append(2)
        try array.append(3)
        try array.append(4)

        var elements: [Int] = []
        array.forEach { elements.append($0) }

        #expect(elements == [1, 2, 3, 4])
        #expect(elements.count == Array<Int>.Static<4>.capacity)
    }

    // MARK: - Span Invariants

    @Test("withSpan provides correct element access")
    func withSpanProvidesCorrectElementAccess() throws {
        var array = Array<Int>.Static<8>()
        for i in 0..<5 { try array.append(i * 2) }

        array.withSpan { span in
            #expect(span.count == 5)
            for i in 0..<5 {
                #expect(span[i] == i * 2)
            }
        }
    }
}

// MARK: - Edge Case Tests

extension ArrayStaticTests.EdgeCase {

    @Test("Single element capacity")
    func singleElementCapacity() throws {
        var array = Array<Int>.Static<1>()

        try array.append(42)
        #expect(array.count == 1)
        #expect(array.isFull == true)
        #expect(array[Index<Int>(__unchecked: (), Ordinal(UInt(0)))] == 42)

        #expect(throws: Array<Int>.Static<1>.Error.self) {
            try array.append(999)
        }

        var elements: [Int] = []
        array.forEach { elements.append($0) }
        #expect(elements == [42])
    }

    @Test("Fill and empty multiple times")
    func fillAndEmptyMultipleTimes() throws {
        var array = Array<Int>.Static<3>()

        // First fill
        try array.append(1)
        try array.append(2)
        try array.append(3)
        #expect(array.isFull == true)

        // Empty
        array.removeAll()
        #expect(array.count == 0)
        #expect(array.isFull == false)

        // Second fill with different values
        try array.append(10)
        try array.append(20)
        try array.append(30)
        #expect(array.isFull == true)

        var elements: [Int] = []
        array.forEach { elements.append($0) }
        #expect(elements == [10, 20, 30])
    }

    @Test("Append after partial removeLast")
    func appendAfterPartialRemoveLast() throws {
        var array = Array<Int>.Static<4>()

        try array.append(1)
        try array.append(2)
        try array.append(3)
        try array.append(4)

        _ = array.removeLast()
        _ = array.removeLast()

        try array.append(100)
        try array.append(200)

        var elements: [Int] = []
        array.forEach { elements.append($0) }
        #expect(elements == [1, 2, 100, 200])
    }

    @Test("removeAll clears all elements")
    func removeAllClearsAllElements() throws {
        var array = Array<Int>.Static<5>()
        for i in 0..<5 { try array.append(i) }

        array.removeAll()

        #expect(array.count == 0)
        #expect(array.isEmpty == true)
        #expect(array.isFull == false)

        var iterCount = 0
        array.forEach { _ in iterCount += 1 }
        #expect(iterCount == 0)
    }

    @Test("Large inline capacity")
    func largeStaticCapacity() throws {
        var array = Array<Int>.Static<100>()

        for i in 0..<100 {
            try array.append(i * 3)
        }

        #expect(array.count == 100)
        #expect(array.isFull == true)

        // Verify all elements via forEach
        var index = 0
        array.forEach { element in
            #expect(element == index * 3)
            index += 1
        }
        #expect(index == 100)
    }
}

// MARK: - Integration Tests

extension ArrayStaticTests.Integration {

    @Test("forEach and withSpan yield same elements")
    func forEachAndWithSpanYieldSameElements() throws {
        var array = Array<Int>.Static<10>()
        for i in 0..<7 { try array.append(i * 2) }

        var forEachElements: [Int] = []
        array.forEach { forEachElements.append($0) }

        var spanElements: [Int] = []
        array.withSpan { span in
            for i in 0..<span.count {
                spanElements.append(span[i])
            }
        }

        #expect(forEachElements == spanElements)
    }
}

// MARK: - Performance Tests

extension ArrayStaticTests.Performance {
    // Performance tests with .timed() trait
}
