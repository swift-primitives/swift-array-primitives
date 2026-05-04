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

@Suite("Array.Fixed + OutputSpan")
struct ArrayFixedOutputSpanTests {
    @Suite struct Unit {}
    @Suite struct NonCopyable {}
    @Suite struct Throwing {}
}

// MARK: - Test fixtures

private struct MoveOnly: ~Copyable {
    let value: Int
    init(_ value: Int) { self.value = value }
}

private enum FixtureError: Swift.Error, Equatable {
    case deliberate
}

// MARK: - Unit (Copyable elements)

extension ArrayFixedOutputSpanTests.Unit {

    @Test
    func `init with fully-populated closure succeeds`() throws {
        let array = try Array<Int>.Fixed(capacity: 4) { span in
            span.append(10)
            span.append(20)
            span.append(30)
            span.append(40)
        }
        #expect(array.count == 4)
    }

    @Test
    func `init with zero capacity and empty closure succeeds`() throws {
        let array = try Array<Int>.Fixed(capacity: 0) { _ in }
        #expect(array.count == .zero)
        #expect(array.isEmpty)
    }

    @Test
    func `init supports arbitrary initialization logic`() throws {
        let array = try Array<Int>.Fixed(capacity: 5) { span in
            for i in 0..<5 {
                span.append(i * i)
            }
        }
        #expect(array.count == 5)
    }
}

// MARK: - NonCopyable (~Copyable elements)

extension ArrayFixedOutputSpanTests.NonCopyable {

    @Test
    func `init with noncopyable elements fully populated`() throws {
        let array = try Array<MoveOnly>.Fixed(capacity: 3) { span in
            span.append(MoveOnly(1))
            span.append(MoveOnly(2))
            span.append(MoveOnly(3))
        }
        #expect(array.count == 3)
    }
}

// MARK: - Throwing

extension ArrayFixedOutputSpanTests.Throwing {

    @Test
    func `throw propagates before full population`() {
        #expect(throws: FixtureError.deliberate) {
            _ = try Array<Int>.Fixed(capacity: 4) { span throws(FixtureError) in
                span.append(1)
                throw FixtureError.deliberate
            }
        }
    }

    @Test
    func `throw with noncopyable elements — cleanup via OutputSpan deinit`() {
        #expect(throws: FixtureError.deliberate) {
            _ = try Array<MoveOnly>.Fixed(capacity: 3) { span throws(FixtureError) in
                span.append(MoveOnly(1))
                throw FixtureError.deliberate
            }
        }
    }
}
