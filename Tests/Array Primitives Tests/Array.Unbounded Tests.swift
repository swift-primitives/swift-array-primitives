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

/// Test namespace for Array.Unbounded
///
/// Note: Array.Unbounded is ~Copyable, so it doesn't conform to Sequence.
/// Use forEach for iteration instead of for-in loops.
enum ArrayUnboundedTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
    @Suite struct Performance {}
}

// MARK: - Unit Tests

extension ArrayUnboundedTests.Unit {

    // MARK: - Count Invariants

    @Test("Empty array has count zero")
    func emptyArrayHasCountZero() {
        let array = Array<Int>.Unbounded<4>()
        #expect(array.count.rawValue == 0)
        #expect(array.isEmpty == true)
    }

    @Test("Append increments count")
    func appendIncrementsCount() {
        var array = Array<Int>.Unbounded<4>()

        array.append(1)
        #expect(array.count.rawValue == 1)

        array.append(2)
        #expect(array.count.rawValue == 2)

        array.append(3)
        #expect(array.count.rawValue == 3)
    }

    @Test("RemoveLast decrements count")
    func removeLastDecrementsCount() {
        var array = Array<Int>.Unbounded<4>()
        array.append(1)
        array.append(2)
        array.append(3)

        _ = array.removeLast()
        #expect(array.count.rawValue == 2)

        _ = array.removeLast()
        #expect(array.count.rawValue == 1)

        _ = array.removeLast()
        #expect(array.count.rawValue == 0)
    }

    @Test("RemoveLast on empty returns nil")
    func removeLastOnEmptyReturnsNil() {
        var array = Array<Int>.Unbounded<4>()
        #expect(array.removeLast() == nil)
        #expect(array.count.rawValue == 0)
    }

    // MARK: - forEach Invariants

    @Test("forEach yields exactly count elements")
    func forEachYieldsExactlyCountElements() {
        var array = Array<Int>.Unbounded<4>()
        for i in 0..<10 { array.append(i) }

        var iteratedCount = 0
        array.forEach { _ in iteratedCount += 1 }

        #expect(iteratedCount == 10)
    }

    @Test("forEach yields elements in insertion order")
    func forEachYieldsElementsInInsertionOrder() {
        var array = Array<Int>.Unbounded<4>()
        array.append(10)
        array.append(20)
        array.append(30)
        array.append(40)

        var elements: [Int] = []
        array.forEach { elements.append($0) }

        #expect(elements == [10, 20, 30, 40])
    }

    @Test("Empty array forEach yields nothing")
    func emptyArrayForEachYieldsNothing() {
        let array = Array<Int>.Unbounded<4>()

        var iteratedCount = 0
        array.forEach { _ in iteratedCount += 1 }

        #expect(iteratedCount == 0)
    }

    @Test("forEach matches subscript access")
    func forEachMatchesSubscriptAccess() throws {
        var array = Array<Int>.Unbounded<4>()
        for i in 0..<20 { array.append(i * 5) }

        var index = 0
        array.forEach { element in
            #expect(element == array[try! Index<Int>(index)])
            index += 1
        }
    }

    // MARK: - Copy-on-Write Invariants

    @Test("CoW: Copy shares storage initially")
    func cowCopySharesStorageInitially() {
        var original = Array<Int>.Unbounded<4>()
        original.append(1)
        original.append(2)
        original.append(3)

        let copy = original

        // Both should have same elements
        var originalElements: [Int] = []
        var copyElements: [Int] = []

        original.forEach { originalElements.append($0) }
        copy.forEach { copyElements.append($0) }

        #expect(originalElements == copyElements)
    }

    @Test("CoW: Mutation of copy does not affect original")
    func cowMutationOfCopyDoesNotAffectOriginal() throws {
        var original = Array<Int>.Unbounded<4>()
        original.append(1)
        original.append(2)
        original.append(3)

        var copy = original

        // Mutate the copy
        copy.append(4)
        copy[try Index<Int>(0)] = 100

        // Original should be unchanged
        #expect(original.count.rawValue == 3)
        #expect(original[try Index<Int>(0)] == 1)
        #expect(original[try Index<Int>(1)] == 2)
        #expect(original[try Index<Int>(2)] == 3)

        // Copy should have the mutations
        #expect(copy.count.rawValue == 4)
        #expect(copy[try Index<Int>(0)] == 100)
        #expect(copy[try Index<Int>(3)] == 4)
    }

    @Test("CoW: Mutation of original does not affect copy")
    func cowMutationOfOriginalDoesNotAffectCopy() throws {
        var original = Array<Int>.Unbounded<4>()
        original.append(1)
        original.append(2)
        original.append(3)

        let copy = original

        // Mutate the original
        original.append(4)
        original[try Index<Int>(0)] = 100

        // Copy should be unchanged
        #expect(copy.count.rawValue == 3)
        #expect(copy[try Index<Int>(0)] == 1)
        #expect(copy[try Index<Int>(1)] == 2)
        #expect(copy[try Index<Int>(2)] == 3)
    }

    @Test("CoW: Multiple copies are independent")
    func cowMultipleCopiesAreIndependent() throws {
        var original = Array<Int>.Unbounded<4>()
        original.append(1)
        original.append(2)

        var copy1 = original
        var copy2 = original

        copy1.append(100)
        copy2.append(200)
        original.append(300)

        #expect(original[try Index<Int>(2)] == 300)
        #expect(copy1[try Index<Int>(2)] == 100)
        #expect(copy2[try Index<Int>(2)] == 200)
    }

    // MARK: - Capacity Invariants

    @Test("Capacity grows to accommodate elements")
    func capacityGrowsToAccommodateElements() {
        var array = Array<Int>.Unbounded<4>()

        // Add elements beyond initial capacity hint
        for i in 0..<100 {
            array.append(i)
        }

        #expect(array.capacity >= 100)
        #expect(array.count.rawValue == 100)

        // Verify all elements are accessible
        for i in 0..<100 {
            #expect(array[try! Index<Int>(i)] == i)
        }
    }

    @Test("forEach visits all elements in order")
    func forEachVisitsAllElementsInOrder() {
        var array = Array<Int>.Unbounded<4>()
        array.append(10)
        array.append(20)
        array.append(30)

        var visited: [Int] = []
        array.forEach { visited.append($0) }

        #expect(visited == [10, 20, 30])
    }

    @Test("forEach visits count elements")
    func forEachVisitsCountElements() {
        var array = Array<Int>.Unbounded<4>()
        for i in 0..<50 { array.append(i) }

        var visitCount = 0
        array.forEach { _ in visitCount += 1 }

        #expect(visitCount == 50)
    }

    // MARK: - Span Invariants

    @Test("Span count matches array count")
    func spanCountMatchesArrayCount() {
        var array = Array<Int>.Unbounded<4>()
        for i in 0..<10 { array.append(i) }

        #expect(array.span.count == 10)
    }

    @Test("Span elements match subscript access")
    func spanElementsMatchSubscriptAccess() throws {
        var array = Array<Int>.Unbounded<4>()
        for i in 0..<5 { array.append(i * 7) }

        let span = array.span
        for i in 0..<5 {
            #expect(span[i] == array[try Index<Int>(i)])
        }
    }
}

// MARK: - Edge Case Tests

extension ArrayUnboundedTests.EdgeCase {

    @Test("Single element operations")
    func singleElementOperations() throws {
        var array = Array<Int>.Unbounded<4>()

        array.append(42)
        #expect(array.count.rawValue == 1)
        #expect(array[try Index<Int>(0)] == 42)

        var elements: [Int] = []
        array.forEach { elements.append($0) }
        #expect(elements == [42])

        let removed = array.removeLast()
        #expect(removed == 42)
        #expect(array.count.rawValue == 0)
    }

    @Test("Growth beyond initial capacity preserves elements")
    func growthBeyondInitialCapacityPreservesElements() throws {
        var array = Array<Int>.Unbounded<2>()  // Small initial capacity

        // Add many elements
        for i in 0..<1000 {
            array.append(i * 2)
        }

        #expect(array.count.rawValue == 1000)

        // Verify all elements preserved through growth
        for i in 0..<1000 {
            #expect(array[try Index<Int>(i)] == i * 2)
        }

        // Verify forEach still works
        var index = 0
        array.forEach { element in
            #expect(element == index * 2)
            index += 1
        }
        #expect(index == 1000)
    }

    @Test("RemoveAll clears count")
    func removeAllClearsCount() {
        var array = Array<Int>.Unbounded<4>()
        for i in 0..<10 { array.append(i) }

        array.removeAll()

        #expect(array.count.rawValue == 0)
        #expect(array.isEmpty == true)

        var iterCount = 0
        array.forEach { _ in iterCount += 1 }
        #expect(iterCount == 0)
    }

    @Test("Append after removeAll works")
    func appendAfterRemoveAllWorks() throws {
        var array = Array<Int>.Unbounded<4>()
        array.append(1)
        array.append(2)

        array.removeAll()

        array.append(100)
        array.append(200)

        #expect(array.count.rawValue == 2)
        #expect(array[try Index<Int>(0)] == 100)
        #expect(array[try Index<Int>(1)] == 200)
    }
}

// MARK: - Integration Tests

extension ArrayUnboundedTests.Integration {

    @Test("forEach and withSpan yield same elements")
    func forEachAndWithSpanYieldSameElements() {
        var array = Array<Int>.Unbounded<4>()
        for i in 0..<10 { array.append(i * 2) }

        var forEachElements: [Int] = []
        array.forEach { forEachElements.append($0) }

        var spanElements: [Int] = []
        let span = array.span
        for i in 0..<span.count {
            spanElements.append(span[i])
        }

        #expect(forEachElements == spanElements)
    }

    @Test("CoW preserves forEach correctness after copy mutation")
    func cowPreservesForEachCorrectnessAfterCopyMutation() {
        var original = Array<Int>.Unbounded<4>()
        for i in 0..<5 { original.append(i) }

        var copy = original
        copy.append(999)

        // Original forEach should still work correctly
        var originalElements: [Int] = []
        original.forEach { originalElements.append($0) }
        #expect(originalElements == [0, 1, 2, 3, 4])

        // Copy forEach should include the new element
        var copyElements: [Int] = []
        copy.forEach { copyElements.append($0) }
        #expect(copyElements == [0, 1, 2, 3, 4, 999])
    }
}

// MARK: - Performance Tests

extension ArrayUnboundedTests.Performance {
    // Performance tests with .timed() trait
}
