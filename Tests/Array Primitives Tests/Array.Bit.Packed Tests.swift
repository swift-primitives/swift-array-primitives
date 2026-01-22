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

// MARK: - Test Suite Structure
//
// Note: Swift Testing's @Suite/@Test macros cannot be applied within generic extensions.
// Since Array<Bit>.Packed is nested inside a generic type, we use a dedicated test enum.
// This follows [TEST-ORG-005] for types that cannot have nested Test types.

/// Test namespace for Array<Bit>.Packed
enum ArrayBitPackedTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
    @Suite struct Performance {}
}

// MARK: - Unit Tests

extension ArrayBitPackedTests.Unit {

    @Test("Append and subscript")
    func appendAndSubscript() {
        var bits = Array<Bit>.Packed()

        bits.append(true)
        bits.append(false)
        bits.append(true)

        #expect(bits[0] == true)
        #expect(bits[1] == false)
        #expect(bits[2] == true)
        #expect(bits.count == 3)
    }

    @Test("Subscript set")
    func subscriptSet() {
        var bits = Array<Bit>.Packed([true, true, true])

        bits[1] = false

        #expect(bits[0] == true)
        #expect(bits[1] == false)
        #expect(bits[2] == true)
    }

    @Test("popLast")
    func popLast() {
        var bits = Array<Bit>.Packed([true, false, true])

        let last = bits.popLast()
        #expect(last == true)
        #expect(bits.count == 2)

        let second = bits.popLast()
        #expect(second == false)
        #expect(bits.count == 1)

        let first = bits.popLast()
        #expect(first == true)
        #expect(bits.isEmpty)

        let empty = bits.popLast()
        #expect(empty == nil)
    }

    @Test("removeLast")
    func removeLast() {
        var bits = Array<Bit>.Packed([true, false])

        bits.removeLast()
        #expect(bits.count == 1)
        #expect(bits[0] == true)
    }

    @Test("removeAll")
    func removeAll() {
        var bits = Array<Bit>.Packed([true, false, true])

        bits.removeAll()
        #expect(bits.isEmpty)
    }

    @Test("count and isEmpty")
    func countAndIsEmpty() {
        var bits = Array<Bit>.Packed()
        #expect(bits.isEmpty)

        bits.append(true)
        #expect(bits.count == 1)
        #expect(!bits.isEmpty)
    }

    @Test("first and last")
    func firstAndLast() {
        var bits = Array<Bit>.Packed()
        #expect(bits.first == nil)
        #expect(bits.last == nil)

        bits.append(true)
        #expect(bits.first == true)
        #expect(bits.last == true)

        bits.append(false)
        #expect(bits.first == true)
        #expect(bits.last == false)
    }

    @Test("Init from sequence")
    func initFromSequence() {
        let bits = Array<Bit>.Packed([true, false, true, false])

        #expect(bits.count == 4)
        #expect(bits[0] == true)
        #expect(bits[1] == false)
        #expect(bits[2] == true)
        #expect(bits[3] == false)
    }

    @Test("Init repeating true")
    func initRepeatingTrue() {
        let bits = Array<Bit>.Packed(repeating: true, count: 5)

        #expect(bits.count == 5)
        #expect(bits.allTrue)
        for i in try! (0..<5).map(Bit.Index.init) {
            #expect(bits[i] == true)
        }
    }

    @Test("Init repeating false")
    func initRepeatingFalse() {
        let bits = Array<Bit>.Packed(repeating: false, count: 5)

        #expect(bits.count == 5)
        #expect(bits.allFalse)
        for i in try! (0..<5).map(Bit.Index.init) {
            #expect(bits[i] == false)
        }
    }

    @Test("Conversion from [Bit]")
    func conversionFromUnpacked() {
        let unpacked: [Bit] = [true, false, true, false]
        let packed = Array<Bit>.Packed(unpacked)

        #expect(packed.count == 4)
        #expect(packed[0] == true)
        #expect(packed[1] == false)
        #expect(packed[2] == true)
        #expect(packed[3] == false)
    }

    @Test("Conversion to [Bit]")
    func conversionToUnpacked() {
        let packed = Array<Bit>.Packed([true, false, true, false])
        let unpacked = [Bit](packed)

        #expect(unpacked.count == 4)
        #expect(unpacked[0] == true)
        #expect(unpacked[1] == false)
        #expect(unpacked[2] == true)
        #expect(unpacked[3] == false)
    }

    @Test("Roundtrip conversion")
    func roundtripConversion() {
        let original: [Bit] = [true, false, true, true, false, false, true, false]
        let packed = Array<Bit>.Packed(original)
        let backToUnpacked = [Bit](packed)

        #expect(original == backToUnpacked)
    }

    @Test("toggle")
    func toggle() throws {
        var bits = Array<Bit>.Packed([true, false, true])

        try bits.toggle(0)
        try bits.toggle(1)
        try bits.toggle(2)

        #expect(bits[0] == false)
        #expect(bits[1] == true)
        #expect(bits[2] == false)
    }

    @Test("trueCount and falseCount")
    func trueAndFalseCount() {
        let bits = Array<Bit>.Packed([true, false, true, false, true])

        #expect(bits.trueCount == 3)
        #expect(bits.falseCount == 2)
    }

    @Test("allTrue and allFalse")
    func allTrueAndAllFalse() {
        let allTrue = Array<Bit>.Packed([true, true, true])
        let allFalse = Array<Bit>.Packed([false, false, false])
        let mixed = Array<Bit>.Packed([true, false, true])

        #expect(allTrue.allTrue)
        #expect(!allTrue.allFalse)

        #expect(!allFalse.allTrue)
        #expect(allFalse.allFalse)

        #expect(!mixed.allTrue)
        #expect(!mixed.allFalse)
    }

    @Test("Iteration")
    func iteration() {
        let bits = Array<Bit>.Packed([true, false, true, false])

        var values: [Bool] = []
        for bit in bits {
            values.append(bit)
        }

        #expect(values == [true, false, true, false])
    }

    @Test("Collection conformance")
    func collectionConformance() {
        let bits = Array<Bit>.Packed([true, false, true])

        #expect(bits.startIndex == 0)
        #expect(bits.endIndex == 3)

        #expect(Swift.Array(bits) == [true, false, true])
    }

    @Test("Equality")
    func equality() {
        let a = Array<Bit>.Packed([true, false, true])
        let b = Array<Bit>.Packed([true, false, true])
        let c = Array<Bit>.Packed([true, true, true])

        #expect(a == b)
        #expect(a != c)
    }

    @Test("Description")
    func description() {
        let bits = Array<Bit>.Packed([true, false, true])
        let desc = bits.description
        #expect(desc.contains("Array<Bit>.Packed"))
        #expect(desc.contains("101"))
    }

    @Test("Append Bit type")
    func appendBitType() {
        var bits = Array<Bit>.Packed()
        bits.append(Bit.one)
        bits.append(Bit.zero)
        bits.append(Bit.one)

        #expect(bits.count == 3)
        #expect(bits[0] == true)
        #expect(bits[1] == false)
        #expect(bits[2] == true)
    }

    @Test("Init from [Bit] sequence")
    func initFromBitSequence() {
        let bitArray: [Bit] = [.one, .zero, .one, .zero]
        let packed = Array<Bit>.Packed(bitArray)

        #expect(packed.count == 4)
        #expect(packed[0] == true)
        #expect(packed[1] == false)
    }
}

// MARK: - Edge Case Tests

extension ArrayBitPackedTests.EdgeCase {

    @Test("Empty arrays equal")
    func emptyArraysEqual() {
        let a = Array<Bit>.Packed()
        let b = Array<Bit>.Packed()
        #expect(a == b)
    }

    @Test("Different lengths not equal")
    func differentLengthsNotEqual() {
        let a = Array<Bit>.Packed([true, false])
        let b = Array<Bit>.Packed([true, false, true])
        #expect(a != b)
    }

    @Test("Word boundary: index 63 and 64")
    func wordBoundary63And64() {
        var bits = Array<Bit>.Packed(repeating: false, count: 100)

        bits[63] = true
        bits[64] = true

        #expect(bits[63] == true)
        #expect(bits[64] == true)
        #expect(bits[62] == false)
        #expect(bits[65] == false)
    }

    @Test("Large array")
    func largeArray() {
        var bits = Array<Bit>.Packed(repeating: false, count: 1000)

        bits[0] = true
        bits[500] = true
        bits[999] = true

        #expect(bits.count == 1000)
        #expect(bits.trueCount == 3)
        #expect(bits.falseCount == 997)
    }
}

// MARK: - Integration Tests

extension ArrayBitPackedTests.Integration {
    // Integration tests for cross-type interactions
}

// MARK: - Performance Tests

extension ArrayBitPackedTests.Performance {
    // Performance tests with .timed() trait
}
