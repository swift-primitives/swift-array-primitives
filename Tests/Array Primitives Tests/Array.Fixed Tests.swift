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

/// Array.Fixed is nested inside a generic type — uses parallel namespace per [TEST-004].
@Suite("Array.Fixed")
struct ArrayFixedTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
    @Suite(.serialized) struct Performance {}
}

// MARK: - Unit Tests

extension ArrayFixedTests.Unit {

    // MARK: - Initialization Invariants

    @Test
    func `init establishes count invariant`() throws {
        let array = try Array<Ordinal>.Fixed(count: 5) { $0.position }
        #expect(array.count == 5)
    }

    @Test
    func `init with zero count creates empty array`() throws {
        let array = try Array<Ordinal>.Fixed(count: 0) { $0.position }
        #expect(array.count == 0)
        #expect(array.isEmpty == true)
    }

    @Test
    func `all indices are initialized with correct values`() throws {
        var array = try Array<Ordinal>.Fixed(count: 10) { $0.position }

        var visited: [Ordinal] = []
        array.forEach { visited.append($0) }
        #expect(visited == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
    }

    // MARK: - forEach Invariants

    @Test
    func `forEach yields exactly count elements`() throws {
        var array = try Array<Ordinal>.Fixed(count: 10) { $0.position }

        var iteratedCount = 0
        array.forEach { _ in
            iteratedCount += 1
        }

        #expect(iteratedCount == 10)
    }

    @Test
    func `forEach yields elements in order`() throws {
        var array = try Array<Ordinal>.Fixed(count: 5) { $0.position }

        var visited: [Ordinal] = []
        array.forEach { visited.append($0) }
        #expect(visited == [0, 1, 2, 3, 4])
    }

    @Test
    func `empty array forEach yields nothing`() throws {
        var array = try Array<Ordinal>.Fixed(count: 0) { $0.position }

        var iteratedCount = 0
        array.forEach { _ in
            iteratedCount += 1
        }

        #expect(iteratedCount == 0)
    }

    @Test
    func `forEach matches subscript access`() throws {
        var array = try Array<Ordinal>.Fixed(count: 5) { $0.position }

        var forEachValues: [Ordinal] = []
        array.forEach { forEachValues.append($0) }

        #expect(forEachValues[0] == array[0])
        #expect(forEachValues[1] == array[1])
        #expect(forEachValues[2] == array[2])
        #expect(forEachValues[3] == array[3])
        #expect(forEachValues[4] == array[4])
    }

    // MARK: - Subscript Invariants

    @Test
    func `subscript write preserves other elements`() throws {
        var array = try Array<Ordinal>.Fixed(count: 5) { $0.position }

        array[2] = 999

        #expect(array[0] == 0)
        #expect(array[1] == 1)
        #expect(array[2] == 999)
        #expect(array[3] == 3)
        #expect(array[4] == 4)
    }

    @Test
    func `forEach visits count elements for large array`() throws {
        var array = try Array<Ordinal>.Fixed(count: 100) { $0.position }

        var visitCount = 0
        array.forEach { _ in
            visitCount += 1
        }

        #expect(visitCount == 100)
    }

    // MARK: - Span Invariants

    @Test
    func `span count matches array count`() throws {
        let array = try Array<Ordinal>.Fixed(count: 10) { $0.position }

        #expect(array.span.count == 10)
    }

    @Test
    func `span elements match subscript access`() throws {
        let array = try Array<Ordinal>.Fixed(count: 5) { $0.position }
        let span = array.span

        #expect(span[0] == array[0])
        #expect(span[1] == array[1])
        #expect(span[2] == array[2])
        #expect(span[3] == array[3])
        #expect(span[4] == array[4])
    }
}

// MARK: - Edge Case Tests

extension ArrayFixedTests.EdgeCase {

    @Test
    func `single element array`() throws {
        var array = try Array<Ordinal>.Fixed(count: 1) { _ in 42 }

        #expect(array.count == 1)
        #expect(array[0] == 42)

        var iteratedElements: [Ordinal] = []
        array.forEach { iteratedElements.append($0) }
        #expect(iteratedElements == [42])
    }

    @Test
    func `large array maintains invariants`() throws {
        var array = try Array<Ordinal>.Fixed(count: 10_000) { $0.position }

        #expect(array.count == 10_000)
        #expect(array[0] == 0)
        #expect(array[5000] == 5000)
        #expect(array[9999] == 9999)

        var iterCount = 0
        array.forEach { _ in iterCount += 1 }
        #expect(iterCount == 10_000)
    }

    @Test
    func `mutation via subscript reflects in forEach`() throws {
        var array = try Array<Ordinal>.Fixed(count: 3) { $0.position }

        array[1] = 100

        var elements: [Ordinal] = []
        array.forEach { elements.append($0) }
        #expect(elements == [0, 100, 2])
    }
}

// MARK: - Integration Tests

extension ArrayFixedTests.Integration {

    @Test
    func `forEach and span yield same elements`() throws {
        var array = try Array<Ordinal>.Fixed(count: 10) { $0.position }

        var forEachElements: [Ordinal] = []
        array.forEach { forEachElements.append($0) }

        var spanElements: [Ordinal] = []
        let span = array.span
        for i in 0..<span.count {
            spanElements.append(span[i])
        }

        #expect(forEachElements == spanElements)
    }
}

// MARK: - Performance Tests

extension ArrayFixedTests.Performance {
    // Performance tests with .timed() trait
}
