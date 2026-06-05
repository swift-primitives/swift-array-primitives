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

// Finalize the institute `Hash.Protocol` `hash(into:)` (span-derived) to a value
// so equal/unequal hashes can be compared. Concrete overloads avoid naming the
// ~Copyable `Hash.Protocol` generically.
private func finalizedHash(_ a: borrowing Array<Int>) -> Int {
    var hasher = Hasher()
    a.hash(into: &hasher)
    return hasher.finalize()
}

// A move-only element conforming Equation.Protocol + Hash.Protocol, to exercise
// span-derived equality / hashing over ~Copyable elements (no copy out of the span).
struct Token: ~Copyable {
    let value: Int
    init(_ value: Int) { self.value = value }
}

extension Token: Equation.`Protocol` {
    static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        lhs.value == rhs.value
    }
}

extension Token: Hash.`Protocol` {
    borrowing func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

@Suite("Array span-derived Equatable + Hashable")
struct ArrayEquationHashTests {

    @Test
    func `equal arrays compare equal with equal hashes`() {
        let a: Array<Int> = [1, 2, 3, 4]
        let b: Array<Int> = [1, 2, 3, 4]
        #expect(a == b)
        #expect(finalizedHash(a) == finalizedHash(b))
    }

    @Test
    func `unequal arrays differ (element and count)`() {
        let a: Array<Int> = [1, 2, 3, 4]
        let differentElement: Array<Int> = [1, 2, 9, 4]
        let differentCount: Array<Int> = [1, 2, 3]
        #expect(!(a == differentElement))
        #expect(!(a == differentCount))
        #expect(finalizedHash(a) != finalizedHash(differentElement))
    }

    @Test
    func `empty arrays are equal with equal hashes`() {
        let a: Array<Int> = []
        let b: Array<Int> = []
        #expect(a == b)
        #expect(finalizedHash(a) == finalizedHash(b))
    }

    @Test
    func `Array of move-only elements compares and hashes over the span`() {
        var a = Array<Token>()
        a.append(Token(1))
        a.append(Token(2))
        a.append(Token(3))

        var b = Array<Token>()
        b.append(Token(1))
        b.append(Token(2))
        b.append(Token(3))

        let abEqual = a == b
        #expect(abEqual)

        var hasherA = Hasher()
        a.hash(into: &hasherA)
        var hasherB = Hasher()
        b.hash(into: &hasherB)
        #expect(hasherA.finalize() == hasherB.finalize())

        var c = Array<Token>()
        c.append(Token(1))
        c.append(Token(2))
        c.append(Token(9))

        let acEqual = a == c
        #expect(!acEqual)
    }
}
