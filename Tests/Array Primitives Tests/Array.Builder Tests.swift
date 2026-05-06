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

import Array_Primitives_Test_Support
import Testing

@testable import Array_Primitives

// MARK: - Test Suite Structure

/// Test namespace for Array.Builder.
///
/// Validates declarative construction of the institute's ~Copyable Array<E>
/// via `@resultBuilder`. Includes ~Copyable element coverage.
enum ArrayBuilderTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
    @Suite struct NonCopyable {}
    @Suite struct StaticMethods {}
}

// MARK: - Move-Only Test Fixture

private struct Move: ~Copyable {
    let value: Int
    init(_ value: Int) { self.value = value }
}

// MARK: - Unit Tests

extension ArrayBuilderTests.Unit {

    @Test
    func `Single element expression`() {
        var array: Array<Int> = Array {
            42
        }
        var elements: [Int] = []
        array.forEach { elements.append($0) }
        #expect(elements == [42])
    }

    @Test
    func `Multiple element expressions`() {
        var array: Array<Int> = Array {
            1
            2
            3
        }
        var elements: [Int] = []
        array.forEach { elements.append($0) }
        #expect(elements == [1, 2, 3])
    }

    @Test
    func `Optional element - some`() {
        let value: Int? = 42
        var array: Array<Int> = Array {
            value
        }
        var elements: [Int] = []
        array.forEach { elements.append($0) }
        #expect(elements == [42])
    }

    @Test
    func `Optional element - none`() {
        let value: Int? = nil
        let array: Array<Int> = Array {
            value
        }
        #expect(array.count == 0)
    }

    @Test
    func `Mixed elements and optionals`() {
        let some: Int? = 2
        let none: Int? = nil
        var array: Array<Int> = Array {
            1
            some
            none
            3
        }
        var elements: [Int] = []
        array.forEach { elements.append($0) }
        #expect(elements == [1, 2, 3])
    }

    @Test
    func `Empty block`() {
        let array: Array<Int> = Array {}
        #expect(array.count == 0)
    }

    @Test
    func `Nested Array expression`() {
        let inner: Array<Int> = Array {
            10
            20
            30
        }
        var outer: Array<Int> = Array {
            1
            inner
            99
        }
        var elements: [Int] = []
        outer.forEach { elements.append($0) }
        #expect(elements == [1, 10, 20, 30, 99])
    }
}

// MARK: - Control Flow

extension ArrayBuilderTests.Unit {

    @Test
    func `Conditional include`() {
        let include = true
        var array: Array<Int> = Array {
            1
            if include {
                2
            }
            3
        }
        var elements: [Int] = []
        array.forEach { elements.append($0) }
        #expect(elements == [1, 2, 3])
    }

    @Test
    func `Conditional exclude`() {
        let include = false
        var array: Array<Int> = Array {
            1
            if include {
                2
            }
            3
        }
        var elements: [Int] = []
        array.forEach { elements.append($0) }
        #expect(elements == [1, 3])
    }

    @Test
    func `If-else first branch`() {
        let condition = true
        var array: Array<Int> = Array {
            if condition {
                1
            } else {
                2
            }
        }
        var elements: [Int] = []
        array.forEach { elements.append($0) }
        #expect(elements == [1])
    }

    @Test
    func `If-else second branch`() {
        let condition = false
        var array: Array<Int> = Array {
            if condition {
                1
            } else {
                2
            }
        }
        var elements: [Int] = []
        array.forEach { elements.append($0) }
        #expect(elements == [2])
    }

    @Test
    func `Limited availability passthrough`() {
        var array: Array<Int> = Array {
            1
            if #available(macOS 26, iOS 26, *) {
                2
            }
            3
        }
        var elements: [Int] = []
        array.forEach { elements.append($0) }
        #expect(elements == [1, 2, 3])
    }
}

// MARK: - Edge Cases

extension ArrayBuilderTests.EdgeCase {

    @Test
    func `Deeply nested conditionals`() {
        let a = true
        let b = false
        let c = true
        var array: Array<Int> = Array {
            0
            if a {
                1
                if b {
                    2
                } else {
                    3
                    if c {
                        4
                    }
                }
            }
            99
        }
        var elements: [Int] = []
        array.forEach { elements.append($0) }
        #expect(elements == [0, 1, 3, 4, 99])
    }

    @Test
    func `Empty arrays interleaved`() {
        let empty: Array<Int> = Array {}
        var result: Array<Int> = Array {
            1
            empty
            2
            empty
            3
        }
        var elements: [Int] = []
        result.forEach { elements.append($0) }
        #expect(elements == [1, 2, 3])
    }

    @Test
    func `Single empty conditional`() {
        let condition = false
        let array: Array<Int> = Array {
            if condition {
                1
            }
        }
        #expect(array.count == 0)
    }

    @Test
    func `Many elements`() {
        var array: Array<Int> = Array {
            1
            2
            3
            4
            5
            6
            7
            8
            9
            10
        }
        var elements: [Int] = []
        array.forEach { elements.append($0) }
        #expect(elements == Swift.Array(1...10))
    }
}

// MARK: - Integration

extension ArrayBuilderTests.Integration {

    @Test
    func `Builder result is mutable`() {
        var array: Array<Int> = Array {
            1
            2
            3
        }
        array.append(4)
        var elements: [Int] = []
        array.forEach { elements.append($0) }
        #expect(elements == [1, 2, 3, 4])
    }

    @Test
    func `Builder composes with append`() {
        var array: Array<Int> = Array {}
        #expect(array.count == 0)
        array.append(1)
        array.append(2)
        var elements: [Int] = []
        array.forEach { elements.append($0) }
        #expect(elements == [1, 2])
    }
}

// MARK: - NonCopyable

extension ArrayBuilderTests.NonCopyable {

    @Test
    func `Builder with single noncopyable element`() {
        var array: Array<Move> = Array {
            Move(42)
        }
        var values: [Int] = []
        array.forEach { (m: borrowing Move) in values.append(m.value) }
        #expect(values == [42])
    }

    @Test
    func `Builder with multiple noncopyable elements`() {
        var array: Array<Move> = Array {
            Move(1)
            Move(2)
            Move(3)
        }
        var values: [Int] = []
        array.forEach { (m: borrowing Move) in values.append(m.value) }
        #expect(values == [1, 2, 3])
    }

    @Test
    func `Builder with conditional noncopyable element - included`() {
        let include = true
        var array: Array<Move> = Array {
            Move(1)
            if include {
                Move(2)
            }
            Move(3)
        }
        var values: [Int] = []
        array.forEach { (m: borrowing Move) in values.append(m.value) }
        #expect(values == [1, 2, 3])
    }

    @Test
    func `Builder with conditional noncopyable element - excluded`() {
        let include = false
        var array: Array<Move> = Array {
            Move(1)
            if include {
                Move(2)
            }
            Move(3)
        }
        var values: [Int] = []
        array.forEach { (m: borrowing Move) in values.append(m.value) }
        #expect(values == [1, 3])
    }

    @Test
    func `Builder with if-else noncopyable`() {
        let condition = true
        var array: Array<Move> = Array {
            if condition {
                Move(10)
            } else {
                Move(20)
            }
        }
        var values: [Int] = []
        array.forEach { (m: borrowing Move) in values.append(m.value) }
        #expect(values == [10])
    }

    @Test
    func `Empty noncopyable builder`() {
        let array: Array<Move> = Array {}
        #expect(array.count == 0)
    }
}

// MARK: - Static Method Tests

extension ArrayBuilderTests.StaticMethods {

    @Test
    func `buildExpression single element`() {
        var result = Array<Int>.Builder.buildExpression(42)
        var elements: [Int] = []
        result.forEach { elements.append($0) }
        #expect(elements == [42])
    }

    @Test
    func `buildExpression existing array`() {
        let input: Array<Int> = Array {
            1
            2
            3
        }
        var result = Array<Int>.Builder.buildExpression(input)
        var elements: [Int] = []
        result.forEach { elements.append($0) }
        #expect(elements == [1, 2, 3])
    }

    @Test
    func `buildExpression optional - some`() {
        let value: Int? = 42
        var result = Array<Int>.Builder.buildExpression(value)
        var elements: [Int] = []
        result.forEach { elements.append($0) }
        #expect(elements == [42])
    }

    @Test
    func `buildExpression optional - none`() {
        let value: Int? = nil
        let result = Array<Int>.Builder.buildExpression(value)
        #expect(result.count == 0)
    }

    @Test
    func `buildPartialBlock first array`() {
        let first: Array<Int> = Array { 1; 2; 3 }
        var result = Array<Int>.Builder.buildPartialBlock(first: first)
        var elements: [Int] = []
        result.forEach { elements.append($0) }
        #expect(elements == [1, 2, 3])
    }

    @Test
    func `buildPartialBlock first void`() {
        let result = Array<Int>.Builder.buildPartialBlock(first: ())
        #expect(result.count == 0)
    }

    @Test
    func `buildPartialBlock accumulated and next`() {
        let acc: Array<Int> = Array { 1; 2 }
        let next: Array<Int> = Array { 3; 4 }
        var result = Array<Int>.Builder.buildPartialBlock(
            accumulated: acc,
            next: next
        )
        var elements: [Int] = []
        result.forEach { elements.append($0) }
        #expect(elements == [1, 2, 3, 4])
    }

    @Test
    func `buildBlock empty`() {
        let result = Array<Int>.Builder.buildBlock()
        #expect(result.count == 0)
    }

    @Test
    func `buildOptional some`() {
        let component: Array<Int>? = Array { 1; 2 }
        var result = Array<Int>.Builder.buildOptional(component)
        var elements: [Int] = []
        result.forEach { elements.append($0) }
        #expect(elements == [1, 2])
    }

    @Test
    func `buildOptional none`() {
        let component: Array<Int>? = nil
        let result = Array<Int>.Builder.buildOptional(component)
        #expect(result.count == 0)
    }

    @Test
    func `buildEither first`() {
        let first: Array<Int> = Array { 1; 2 }
        var result = Array<Int>.Builder.buildEither(first: first)
        var elements: [Int] = []
        result.forEach { elements.append($0) }
        #expect(elements == [1, 2])
    }

    @Test
    func `buildEither second`() {
        let second: Array<Int> = Array { 3; 4 }
        var result = Array<Int>.Builder.buildEither(second: second)
        var elements: [Int] = []
        result.forEach { elements.append($0) }
        #expect(elements == [3, 4])
    }

    @Test
    func `buildLimitedAvailability passthrough`() {
        let component: Array<Int> = Array { 1; 2; 3 }
        var result = Array<Int>.Builder.buildLimitedAvailability(component)
        var elements: [Int] = []
        result.forEach { elements.append($0) }
        #expect(elements == [1, 2, 3])
    }
}
