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

@Suite("Array + OutputSpan")
struct ArrayOutputSpanTests {
    @Suite struct Init {}
    @Suite struct Append {}
    @Suite struct Edit {}
    @Suite struct NonCopyable {}
    @Suite struct Throwing {}
    @Suite struct CoW {}
}

// MARK: - Test fixtures

fileprivate struct MoveOnly: ~Copyable {
    let value: Int
    init(_ value: Int) { self.value = value }
}

fileprivate enum FixtureError: Swift.Error, Equatable {
    case deliberate
}

// MARK: - Init

extension ArrayOutputSpanTests.Init {

    @Test
    func `init with full population`() throws {
        let array = try Array<Int>(capacity: 4) { span in
            span.append(10)
            span.append(20)
            span.append(30)
            span.append(40)
        }
        #expect(array.count == 4)
    }

    @Test
    func `init with partial population`() throws {
        let array = try Array<Int>(capacity: 10) { span in
            for i in 0..<3 { span.append(i) }
        }
        #expect(array.count == 3)
    }

    @Test
    func `init with empty closure`() throws {
        let array = try Array<Int>(capacity: 4) { _ in }
        #expect(array.isEmpty)
    }

    @Test
    func `init with zero capacity`() throws {
        let array = try Array<Int>(capacity: 0) { _ in }
        #expect(array.isEmpty)
    }
}

// MARK: - Append

extension ArrayOutputSpanTests.Append {

    @Test
    func `append adds to existing array`() throws {
        var array = Array<Int>(initialCapacity: 2)
        array.append(1)
        array.append(2)

        try array.append(addingCapacity: 3) { span in
            span.append(10)
            span.append(20)
            span.append(30)
        }
        #expect(array.count == 5)
    }

    @Test
    func `append triggers growth`() throws {
        var array = Array<Int>()
        try array.append(addingCapacity: 100) { span in
            for i in 0..<100 { span.append(i) }
        }
        #expect(array.count == 100)
    }

    @Test
    func `append with partial population`() throws {
        var array = Array<Int>()
        array.append(1)

        try array.append(addingCapacity: 10) { span in
            span.append(100)
            span.append(200)
        }
        #expect(array.count == 3)
    }
}

// MARK: - Edit

extension ArrayOutputSpanTests.Edit {

    @Test
    func `edit can append and remove`() throws {
        var array = Array<Int>(initialCapacity: 10)
        array.append(1)
        array.append(2)
        array.append(3)

        try array.edit { span in
            _ = span.removeLast()
            span.append(4)
            span.append(5)
        }
        #expect(array.count == 4)
    }

    @Test
    func `edit returns closure result`() throws {
        var array: Array<Int> = []
        array.append(42)

        let doubled: Int = try array.edit { span in
            span.count * 2
        }
        #expect(doubled == 2)
    }
}

// MARK: - NonCopyable

extension ArrayOutputSpanTests.NonCopyable {

    @Test
    func `init with noncopyable elements`() throws {
        let array = try Array<MoveOnly>(capacity: 3) { span in
            span.append(MoveOnly(1))
            span.append(MoveOnly(2))
            span.append(MoveOnly(3))
        }
        #expect(array.count == 3)
    }

    @Test
    func `append noncopyable elements triggering growth`() throws {
        var array = Array<MoveOnly>(initialCapacity: 1)
        array.append(MoveOnly(0))
        try array.append(addingCapacity: 5) { span in
            for i in 1...5 { span.append(MoveOnly(i)) }
        }
        #expect(array.count == 6)
    }
}

// MARK: - Throwing

extension ArrayOutputSpanTests.Throwing {

    @Test
    func `init throw destroys partial state`() {
        #expect(throws: FixtureError.deliberate) {
            _ = try Array<Int>(capacity: 4) { span throws(FixtureError) in
                span.append(1)
                throw FixtureError.deliberate
            }
        }
    }

    @Test
    func `append throw preserves partial commits`() throws {
        var array = Array<Int>()
        array.append(1)

        do {
            try array.append(addingCapacity: 5) { span throws(FixtureError) in
                span.append(10)
                span.append(20)
                throw FixtureError.deliberate
            }
            Issue.record("Expected throw")
        } catch FixtureError.deliberate {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(array.count == 3)
    }
}

// MARK: - CoW

extension ArrayOutputSpanTests.CoW {

    @Test
    func `append on copy leaves original untouched`() throws {
        var original: Array<Int> = []
        original.append(1)
        original.append(2)
        original.append(3)

        var copy = original
        try copy.append(addingCapacity: 2) { span in
            span.append(100)
            span.append(200)
        }

        #expect(copy.count == 5)
        #expect(original.count == 3)
    }
}
