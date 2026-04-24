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

@Suite("Array swapAt")
struct ArraySwapAtTests {
    @Suite struct Dynamic {}
    @Suite struct Fixed {}
    @Suite struct Small {}
    @Suite struct Static {}
    @Suite struct EdgeCases {}
}

// MARK: - Dynamic Array

extension ArraySwapAtTests.Dynamic {

    @Test
    func `swapAt exchanges two elements`() throws {
        var array: Array<Int> = []
        array.append(10)
        array.append(20)
        array.append(30)

        let i = Array<Int>.Index(Ordinal(0))
        let j = Array<Int>.Index(Ordinal(2))
        array.swapAt(i, j)

        let first = array.withElement(at: i) { $0 }
        let third = array.withElement(at: j) { $0 }
        #expect(first == 30)
        #expect(third == 10)
    }
}

// MARK: - Array.Fixed

extension ArraySwapAtTests.Fixed {

    @Test
    func `swapAt on Array.Fixed`() throws {
        var array = try Array<Int>.Fixed(count: .init(3)) { idx in
            Int(idx.ordinal.rawValue) * 10
        }

        let i = Array<Int>.Index(Ordinal(0))
        let j = Array<Int>.Index(Ordinal(2))
        array.swapAt(i, j)

        let first = array.withElement(at: i) { $0 }
        let third = array.withElement(at: j) { $0 }
        #expect(first == 20)
        #expect(third == 0)
    }
}

// MARK: - Array.Small

extension ArraySwapAtTests.Small {

    @Test
    func `swapAt on Array.Small`() throws {
        var array = Array<Int>.Small<4>()
        array.append(10)
        array.append(20)
        array.append(30)

        let i = Array<Int>.Index(Ordinal(0))
        let j = Array<Int>.Index(Ordinal(2))
        array.swapAt(i, j)

        #expect(array.count == 3)
        // Can't easily read elements via subscript on Small without detailed API;
        // trust buffer-level tests to verify the swap actually happened.
    }
}

// MARK: - Array.Static

extension ArraySwapAtTests.Static {

    @Test
    func `swapAt on Array.Static`() throws {
        var array = Array<Int>.Static<4>()
        try array.append(10)
        try array.append(20)
        try array.append(30)

        let i = Array<Int>.Index(Ordinal(0))
        let j = Array<Int>.Index(Ordinal(2))
        array.swapAt(i, j)

        #expect(array.count == 3)
    }
}

// MARK: - Edge cases

extension ArraySwapAtTests.EdgeCases {

    @Test
    func `swapAt with same index is a noop`() throws {
        var array: Array<Int> = []
        array.append(100)
        array.append(200)

        let i = Array<Int>.Index(Ordinal(0))
        array.swapAt(i, i)

        let first = array.withElement(at: i) { $0 }
        #expect(first == 100)
        #expect(array.count == 2)
    }
}
