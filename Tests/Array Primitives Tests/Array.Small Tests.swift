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

/// Test namespace for Array.Small (SmallVec pattern)
///
/// Note: Array.Small is ~Copyable, so it doesn't conform to Sequence.
/// Use forEach for iteration instead of for-in loops.
enum ArraySmallTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
    @Suite struct Performance {}
}

// MARK: - Unit Tests

extension ArraySmallTests.Unit {

    // MARK: - Storage Mode Invariants

    @Test("Uses inline storage when count <= inlineCapacity")
    func usesInlineStorageWhenCountLessThanOrEqualToInlineCapacity() {
        var array = Array<Int>.Small<4>()

        array.append(1)
        
        #expect(array.capacity.rawValue.rawValue == Array<Int>.Small<4>.inlineCapacity)

        array.append(2)
        array.append(3)
        array.append(4)
        // Still inline at exactly inlineCapacity
        #expect(array.capacity.rawValue.rawValue == Array<Int>.Small<4>.inlineCapacity)
    }

    @Test("Spills to heap when exceeding inlineCapacity")
    func spillsToHeapWhenExceedingInlineCapacity() {
        var array = Array<Int>.Small<4>()

        // Fill inline
        array.append(1)
        array.append(2)
        array.append(3)
        array.append(4)

        // Spill
        array.append(5)
        #expect(array.capacity.rawValue.rawValue > Array<Int>.Small<4>.inlineCapacity)
    }

    @Test("Capacity reports inline capacity when not spilled")
    func capacityReportsInlineCapacityWhenNotSpilled() {
        var array = Array<Int>.Small<8>()
        array.append(1)
        array.append(2)

        #expect(array.capacity.rawValue.rawValue == 8)
    }

    @Test("Capacity grows after spill")
    func capacityGrowsAfterSpill() {
        var array = Array<Int>.Small<2>()
        array.append(1)
        array.append(2)

        let inlineCapacity = Array<Int>.Small<2>.inlineCapacity

        array.append(3)  // Spill

        #expect(array.capacity.rawValue.rawValue > inlineCapacity)
    }

    // MARK: - Count Invariants

    @Test("Empty array has count zero")
    func emptyArrayHasCountZero() {
        let array = Array<Int>.Small<4>()
        #expect(array.count == 0)
        #expect(array.isEmpty == true)
    }

    @Test("Append increments count (inline mode)")
    func appendIncrementsCountInlineMode() {
        var array = Array<Int>.Small<4>()

        array.append(1)
        #expect(array.count == 1)

        array.append(2)
        #expect(array.count == 2)
    }

    @Test("Append increments count (heap mode)")
    func appendIncrementsCountHeapMode() {
        var array = Array<Int>.Small<2>()
        array.append(1)
        array.append(2)
        array.append(3)  // Spill

        #expect(array.count == 3)

        array.append(4)
        #expect(array.count == 4)
    }

    @Test("RemoveLast decrements count (inline mode)")
    func removeLastDecrementsCountInlineMode() {
        var array = Array<Int>.Small<4>()
        array.append(1)
        array.append(2)

        _ = array.removeLast()
        #expect(array.count == 1)
    }

    @Test("RemoveLast decrements count (heap mode)")
    func removeLastDecrementsCountHeapMode() {
        var array = Array<Int>.Small<2>()
        array.append(1)
        array.append(2)
        array.append(3)
        array.append(4)

        _ = array.removeLast()
        #expect(array.count == 3)
    }

    // MARK: - forEach Invariants

    @Test("forEach yields exactly count elements (inline)")
    func forEachYieldsExactlyCountElementsInline() {
        var array = Array<Int>.Small<8>()
        for i in 0..<5 { array.append(i) }

        var iteratedCount = 0
        array.forEach { _ in iteratedCount += 1 }

        #expect(iteratedCount == 5)
    }

    @Test("forEach yields exactly count elements (heap)")
    func forEachYieldsExactlyCountElementsHeap() {
        var array = try! Array<Int>.Small<2>()
        for i in 0..<10 { array.append(i) }

        var iteratedCount = 0
        array.forEach { _ in iteratedCount += 1 }

        #expect(iteratedCount == 10)
    }

    @Test("forEach yields elements in insertion order (inline)")
    func forEachYieldsElementsInInsertionOrderInline() {
        var array = try! Array<Int>.Small<8>()
        array.append(10)
        array.append(20)
        array.append(30)

        var elements: [Int] = []
        array.forEach { elements.append($0) }

        #expect(elements == [10, 20, 30])
    }

    @Test("forEach yields elements in insertion order (heap)")
    func forEachYieldsElementsInInsertionOrderHeap() {
        var array = try! Array<Int>.Small<2>()
        array.append(10)
        array.append(20)
        array.append(30)  // Spills
        array.append(40)

        var elements: [Int] = []
        array.forEach { elements.append($0) }

        #expect(elements == [10, 20, 30, 40])
    }

    @Test("Empty array forEach yields nothing")
    func emptyArrayForEachYieldsNothing() {
        var array = try! Array<Int>.Small<4>()

        var iteratedCount = 0
        array.forEach { _ in iteratedCount += 1 }

        #expect(iteratedCount == 0)
    }

    @Test("forEach matches subscript access (inline)")
    func forEachMatchesSubscriptAccessInline() {
        var array = try! Array<Int>.Small<10>()
        for i in 0..<5 { array.append(i * 7) }

        // Collect elements via forEach
        var forEachElements: [Int] = []
        array.forEach { forEachElements.append($0) }

        // Compare with subscript access
        for i in 0..<5 {
            #expect(forEachElements[i] == array[Index<Int>(__unchecked: (), Ordinal(UInt(i)))])
        }
    }

    @Test("forEach matches subscript access (heap)")
    func forEachMatchesSubscriptAccessHeap() {
        var array = try! Array<Int>.Small<2>()
        for i in 0..<10 { array.append(i * 7) }

        // Collect elements via forEach
        var forEachElements: [Int] = []
        array.forEach { forEachElements.append($0) }

        // Compare with subscript access
        for i in 0..<10 {
            #expect(forEachElements[i] == array[Index<Int>(__unchecked: (), Ordinal(UInt(i)))])
        }
    }

    // MARK: - Behavioral Equivalence (Inline vs Heap)

    @Test("Behavior identical regardless of storage mode")
    func behaviorIdenticalRegardlessOfStorageMode() {
        // Test that operations work the same in both modes
        var inlineArray = try! Array<Int>.Small<100>()  // Will stay inline
        var spilledArray = try! Array<Int>.Small<2>()   // Will spill

        // Add same elements
        for i in 0..<10 {
            inlineArray.append(i * 5)
            spilledArray.append(i * 5)
        }

        // Counts should match
        #expect(inlineArray.count == spilledArray.count)

        // Subscript access should match
        for i in 0..<10 {
            let idx = Index<Int>(__unchecked: (), Ordinal(UInt(i)))
            #expect(inlineArray[idx] == spilledArray[idx])
        }

        // forEach output should match
        var inlineElements: [Int] = []
        var spilledElements: [Int] = []

        inlineArray.forEach { inlineElements.append($0) }
        spilledArray.forEach { spilledElements.append($0) }

        #expect(inlineElements == spilledElements)
    }

    @Test("forEach visits all elements in order (inline)")
    func forEachVisitsAllElementsInOrderInline() {
        var array = Array<Int>.Small<8>()
        array.append(100)
        array.append(200)
        array.append(300)

        var visited: [Int] = []
        array.forEach { visited.append($0) }

        #expect(visited == [100, 200, 300])
    }

    @Test("forEach visits all elements in order (heap)")
    func forEachVisitsAllElementsInOrderHeap() {
        var array = Array<Int>.Small<2>()
        array.append(100)
        array.append(200)
        array.append(300)  // Spill

        var visited: [Int] = []
        array.forEach { visited.append($0) }

        #expect(visited == [100, 200, 300])
    }

    // MARK: - Span Invariants

    @Test("withSpan provides correct access (inline)")
    func withSpanProvidesCorrectAccessInline() {
        var array = Array<Int>.Small<8>()
        for i in 0..<5 { array.append(i * 2) }

        #expect(array.span.count == 5)
        for i in 0..<5 {
            #expect(array.span[i] == i * 2)
        }
    }

    @Test("withSpan provides correct access (heap)")
    func withSpanProvidesCorrectAccessHeap() {
        var array = Array<Int>.Small<2>()
        for i in 0..<5 { array.append(i * 2) }

        
        #expect(array.span.count == 5)
        for i in 0..<5 {
            #expect(array.span[i] == i * 2)
        }
    }
}

// MARK: - Edge Case Tests

extension ArraySmallTests.EdgeCase {

    @Test("Spill preserves all elements")
    func spillPreservesAllElements() {
        var array = Array<Int>.Small<4>()

        // Fill inline
        array.append(1)
        array.append(2)
        array.append(3)
        array.append(4)

        // Verify before spill
        #expect(array[Index<Int>(__unchecked: (), Ordinal(UInt(0)))] == 1)
        #expect(array[Index<Int>(__unchecked: (), Ordinal(UInt(3)))] == 4)

        // Spill
        array.append(5)
        array.append(6)

        // Verify all elements preserved
        #expect(array.count == 6)
        #expect(array[Index<Int>(__unchecked: (), Ordinal(UInt(0)))] == 1)
        #expect(array[Index<Int>(__unchecked: (), Ordinal(UInt(1)))] == 2)
        #expect(array[Index<Int>(__unchecked: (), Ordinal(UInt(2)))] == 3)
        #expect(array[Index<Int>(__unchecked: (), Ordinal(UInt(3)))] == 4)
        #expect(array[Index<Int>(__unchecked: (), Ordinal(UInt(4)))] == 5)
        #expect(array[Index<Int>(__unchecked: (), Ordinal(UInt(5)))] == 6)
    }

    @Test("Large growth after spill preserves elements")
    func largeGrowthAfterSpillPreservesElements() {
        var array = Array<Int>.Small<4>()

        // Add many elements
        for i in 0..<1000 {
            array.append(i * 2)
        }

        #expect(array.count == 1000)

        // Verify all elements
        for i in 0..<1000 {
            #expect(array[Index<Int>(__unchecked: (), Ordinal(UInt(i)))] == i * 2)
        }

        // forEach should also work
        var index = 0
        array.forEach { element in
            #expect(element == index * 2)
            index += 1
        }
        #expect(index == 1000)
    }

    @Test("forEach works at exact inline capacity boundary")
    func forEachWorksAtExactInlineCapacityBoundary() {
        var array = Array<Int>.Small<4>()
        array.append(1)
        array.append(2)
        array.append(3)
        array.append(4)

        // At exactly inline capacity
        var elements: [Int] = []
        array.forEach { elements.append($0) }
        #expect(elements == [1, 2, 3, 4])

        // Add one more to spill
        array.append(5)

        elements = []
        array.forEach { elements.append($0) }
        #expect(elements == [1, 2, 3, 4, 5])
    }

    @Test("removeAll clears both modes")
    func removeAllClearsBothModes() {
        // Test inline mode
        var inlineArray = Array<Int>.Small<4>()
        inlineArray.append(1)
        inlineArray.append(2)
        inlineArray.removeAll()
        #expect(inlineArray.count == 0)

        var iterCount = 0
        inlineArray.forEach { _ in iterCount += 1 }
        #expect(iterCount == 0)

        // Test heap mode
        var heapArray = Array<Int>.Small<2>()
        heapArray.append(1)
        heapArray.append(2)
        heapArray.append(3)
        heapArray.removeAll()
        #expect(heapArray.count == 0)

        iterCount = 0
        heapArray.forEach { _ in iterCount += 1 }
        #expect(iterCount == 0)
    }

    @Test("Single inline capacity")
    func singleInlineCapacity() {
        var array = Array<Int>.Small<1>()

        array.append(42)
        #expect(array.count == 1)
        #expect(array[Index<Int>(__unchecked: (), Ordinal(UInt(0)))] == 42)

        var elements: [Int] = []
        array.forEach { elements.append($0) }
        #expect(elements == [42])

        // Spill with second element
        array.append(99)
        #expect(array.count == 2)
        #expect(array[Index<Int>(__unchecked: (), Ordinal(UInt(0)))] == 42)
        #expect(array[Index<Int>(__unchecked: (), Ordinal(UInt(1)))] == 99)

        elements = []
        array.forEach { elements.append($0) }
        #expect(elements == [42, 99])
    }
}

// MARK: - Integration Tests

extension ArraySmallTests.Integration {

    @Test("forEach and withSpan yield same elements (both modes)")
    func forEachAndWithSpanYieldSameElementsBothModes() {
        // Inline mode
        var inlineArray = Array<Int>.Small<10>()
        for i in 0..<5 { inlineArray.append(i * 2) }

        var forEachElements: [Int] = []
        inlineArray.forEach { forEachElements.append($0) }

        var spanElements: [Int] = []
        for i in 0..<inlineArray.span.count {
            spanElements.append(inlineArray.span[i])
        }

        #expect(forEachElements == spanElements)

        // Heap mode
        var heapArray = Array<Int>.Small<2>()
        for i in 0..<5 { heapArray.append(i * 2) }

        forEachElements = []
        heapArray.forEach { forEachElements.append($0) }

        spanElements = []
        for i in 0..<heapArray.span.count {
            spanElements.append(heapArray.span[i])
        }

        #expect(forEachElements == spanElements)
    }
}

// MARK: - Performance Tests

extension ArraySmallTests.Performance {
    // Performance tests with .timed() trait
}
