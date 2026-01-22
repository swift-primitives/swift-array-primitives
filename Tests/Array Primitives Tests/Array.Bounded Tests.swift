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

/// Test namespace for Array.Bounded
///
/// Note: Array.Bounded is ~Copyable, so it doesn't conform to Sequence.
/// Use forEach for iteration instead of for-in loops.
enum ArrayBoundedTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
    @Suite struct Performance {}
}

// MARK: - Unit Tests

extension ArrayBoundedTests.Unit {

    // MARK: - Initialization Invariants

    @Test("Init establishes count invariant")
    func initEstablishesCountInvariant() throws {
        let array = try Array<Int>.Bounded(count: 5) { $0 }
        #expect(array.count.rawValue == 5)
    }

    @Test("Init with zero count creates empty array")
    func initWithZeroCount() throws {
        let array = try Array<Int>.Bounded(count: 0) { $0 }
        #expect(array.count.rawValue == 0)
        #expect(array.isEmpty == true)
    }

    @Test("Init with negative count throws")
    func initWithNegativeCountThrows() {
        #expect(throws: Array<Int>.Bounded.Error.self) {
            try Array<Int>.Bounded(count: -1) { $0 }
        }
    }

    @Test("All indices 0..<count are initialized")
    func allIndicesInitialized() throws {
        let array = try Array<Int>.Bounded(count: 100) { $0 * 2 }

        for i in 0..<100 {
            let idx = try Index<Int>(i)
            #expect(array[idx] == i * 2)
        }
    }

    // MARK: - forEach Invariants

    @Test("forEach yields exactly count elements")
    func forEachYieldsExactlyCountElements() throws {
        let array = try Array<Int>.Bounded(count: 10) { $0 }

        var iteratedCount = 0
        array.forEach { _ in
            iteratedCount += 1
        }

        #expect(iteratedCount == 10)
    }

    @Test("forEach yields elements in order")
    func forEachYieldsElementsInOrder() throws {
        let array = try Array<Int>.Bounded(count: 5) { $0 * 10 }

        var expected = 0
        array.forEach { element in
            #expect(element == expected * 10)
            expected += 1
        }
        #expect(expected == 5)
    }

    @Test("Empty array forEach yields nothing")
    func emptyArrayForEachYieldsNothing() throws {
        let array = try Array<Int>.Bounded(count: 0) { $0 }

        var iteratedCount = 0
        array.forEach { _ in
            iteratedCount += 1
        }

        #expect(iteratedCount == 0)
    }

    @Test("forEach matches subscript access")
    func forEachMatchesSubscriptAccess() throws {
        let array = try Array<Int>.Bounded(count: 20) { $0 * 3 }

        var index = 0
        array.forEach { element in
            #expect(element == array[try! Index<Int>(index)])
            index += 1
        }
    }

    // MARK: - Subscript Invariants

    @Test("Subscript write preserves other elements")
    func subscriptWritePreservesOtherElements() throws {
        var array = try Array<Int>.Bounded(count: 5) { $0 }

        array[try Index<Int>(2)] = 999

        #expect(array[try Index<Int>(0)] == 0)
        #expect(array[try Index<Int>(1)] == 1)
        #expect(array[try Index<Int>(2)] == 999)
        #expect(array[try Index<Int>(3)] == 3)
        #expect(array[try Index<Int>(4)] == 4)
    }

    @Test("forEach visits all elements in order")
    func forEachVisitsAllElementsInOrder() throws {
        let array = try Array<Int>.Bounded(count: 5) { $0 }

        var visited: [Int] = []
        array.forEach { element in
            visited.append(element)
        }

        #expect(visited == [0, 1, 2, 3, 4])
    }

    @Test("forEach visits count elements")
    func forEachVisitsCountElements() throws {
        let array = try Array<Int>.Bounded(count: 100) { $0 }

        var visitCount = 0
        array.forEach { _ in
            visitCount += 1
        }

        #expect(visitCount == 100)
    }

    // MARK: - Span Invariants

    @Test("Span count matches array count")
    func spanCountMatchesArrayCount() throws {
        let array = try Array<Int>.Bounded(count: 10) { $0 }

        #expect(array.span.count == 10)
    }

    @Test("Span elements match subscript access")
    func spanElementsMatchSubscriptAccess() throws {
        let array = try Array<Int>.Bounded(count: 5) { $0 * 7 }
        let span = array.span

        for i in 0..<5 {
            #expect(span[i] == array[try Index<Int>(i)])
        }
    }
}

// MARK: - Edge Case Tests

extension ArrayBoundedTests.EdgeCase {

    @Test("Single element array")
    func singleElementArray() throws {
        let array = try Array<Int>.Bounded(count: 1) { _ in 42 }

        #expect(array.count.rawValue == 1)
        #expect(array[try Index<Int>(0)] == 42)

        var iteratedElements: [Int] = []
        array.forEach { iteratedElements.append($0) }
        #expect(iteratedElements == [42])
    }

    @Test("Large array maintains invariants")
    func largeArrayMaintainsInvariants() throws {
        let size = 10_000
        let array = try Array<Int>.Bounded(count: size) { $0 }

        #expect(array.count.rawValue == size)

        // Check first, middle, last
        #expect(array[try Index<Int>(0)] == 0)
        #expect(array[try Index<Int>(size / 2)] == size / 2)
        #expect(array[try Index<Int>(size - 1)] == size - 1)

        // forEach count matches
        var iterCount = 0
        array.forEach { _ in iterCount += 1 }
        #expect(iterCount == size)
    }

    @Test("Mutation via subscript reflects in forEach")
    func mutationViaSubscriptReflectsInForEach() throws {
        var array = try Array<Int>.Bounded(count: 3) { $0 }

        array[try Index<Int>(1)] = 100

        var elements: [Int] = []
        array.forEach { elements.append($0) }
        #expect(elements == [0, 100, 2])
    }
}

// MARK: - Integration Tests

extension ArrayBoundedTests.Integration {

    @Test("forEach and withSpan yield same elements")
    func forEachAndWithSpanYieldSameElements() throws {
        let array = try Array<Int>.Bounded(count: 10) { $0 * 2 }

        var forEachElements: [Int] = []
        array.forEach { forEachElements.append($0) }

        var spanElements: [Int] = []
        let span = array.span
        for i in 0..<span.count {
            spanElements.append(span[i])
        }

        #expect(forEachElements == spanElements)
    }
}

// MARK: - Performance Tests

extension ArrayBoundedTests.Performance {
    // Performance tests with .timed() trait
}
