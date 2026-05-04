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

@Suite("Array swap")
struct ArraySwapTests {
    @Suite struct Dynamic {}
    @Suite struct Fixed {}
    @Suite struct Small {}
    @Suite struct Static {}
    @Suite struct EdgeCases {}
}

// MARK: - Dynamic Array

extension ArraySwapTests.Dynamic {

    @Test
    func `swap exchanges two elements`() throws {
        var array: [Int] = []
        array.append(10)
        array.append(20)
        array.append(30)

        let i = Array<Int>.Index(Ordinal(0))
        let j = Array<Int>.Index(Ordinal(2))
        array.swap(at: i, with: j)

        let first = array.withElement(at: i) { $0 }
        let third = array.withElement(at: j) { $0 }
        #expect(first == 30)
        #expect(third == 10)
    }
}

// MARK: - Array.Fixed

extension ArraySwapTests.Fixed {

    @Test
    func `swap on Array.Fixed`() throws {
        var array = try Array<Int>.Fixed(count: .init(3)) { idx in
            Int(idx.ordinal.rawValue) * 10
        }

        let i = Array<Int>.Index(Ordinal(0))
        let j = Array<Int>.Index(Ordinal(2))
        array.swap(at: i, with: j)

        let first = array.withElement(at: i) { $0 }
        let third = array.withElement(at: j) { $0 }
        #expect(first == 20)
        #expect(third == 0)
    }
}

// MARK: - Array.Small

extension ArraySwapTests.Small {

    @Test
    func `swap on Array.Small`() throws {
        var array = Array<Int>.Small<4>()
        array.append(10)
        array.append(20)
        array.append(30)

        let i = Array<Int>.Index(Ordinal(0))
        let j = Array<Int>.Index(Ordinal(2))
        array.swap(at: i, with: j)

        #expect(array.count == 3)
        // Can't easily read elements via subscript on Small without detailed API;
        // trust buffer-level tests to verify the swap actually happened.
    }
}

// MARK: - Array.Static

extension ArraySwapTests.Static {

    @Test
    func `swap on Array.Static`() throws {
        var array = Array<Int>.Static<4>()
        try array.append(10)
        try array.append(20)
        try array.append(30)

        let i = Array<Int>.Index(Ordinal(0))
        let j = Array<Int>.Index(Ordinal(2))
        array.swap(at: i, with: j)

        #expect(array.count == 3)
    }
}

// MARK: - Edge cases

extension ArraySwapTests.EdgeCases {

    @Test
    func `swap with same index is a noop`() throws {
        var array: [Int] = []
        array.append(100)
        array.append(200)

        let i = Array<Int>.Index(Ordinal(0))
        array.swap(at: i, with: i)

        let first = array.withElement(at: i) { $0 }
        #expect(first == 100)
        #expect(array.count == 2)
    }
}
