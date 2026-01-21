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

public import Bit_Primitives

// MARK: - Bit.Array.Inline

extension Bit.Array {
    /// Fixed-capacity packed bit array with inline storage.
    ///
    /// `Bit.Array.Inline` uses zero-allocation inline storage with compile-time
    /// capacity. Ideal for small bit arrays where heap allocation is unnecessary.
    public struct Inline<let wordCount: Int>: Sendable {
        @usableFromInline
        static var _bitsPerWord: Int { UInt.bitWidth }

        @inlinable
        public static var capacity: Int { wordCount * _bitsPerWord }

        @usableFromInline
        var _storage: InlineArray<wordCount, UInt>

        @usableFromInline
        var _count: Int

        @inlinable
        public init() {
            self._storage = InlineArray(repeating: 0)
            self._count = 0
        }

        @inlinable
        public init(count: Int) throws(__BitArrayInlineError) {
            guard count >= 0 && count <= Self.capacity else {
                throw .overflow
            }
            self._storage = InlineArray(repeating: 0)
            self._count = count
        }
    }
}

// MARK: - Properties

extension Bit.Array.Inline {
    @inlinable
    public var count: Int { _count }

    @inlinable
    public var isEmpty: Bool { _count == 0 }

    @inlinable
    public var isFull: Bool { _count >= Self.capacity }

    @inlinable
    public var popcount: Int {
        var total = 0
        for i in 0..<wordCount {
            total += _storage[i].nonzeroBitCount
        }
        return total
    }
}

// MARK: - Subscript Access

extension Bit.Array.Inline {
    @inlinable
    public subscript(index: Int) -> Bool {
        get {
            precondition(index >= 0 && index < _count, "Index out of bounds")
            let wordIndex = index / Self._bitsPerWord
            let bitIndex = index % Self._bitsPerWord
            let mask: UInt = 1 << bitIndex
            return (_storage[wordIndex] & mask) != 0
        }
        set {
            precondition(index >= 0 && index < _count, "Index out of bounds")
            let wordIndex = index / Self._bitsPerWord
            let bitIndex = index % Self._bitsPerWord
            let mask: UInt = 1 << bitIndex
            if newValue {
                _storage[wordIndex] |= mask
            } else {
                _storage[wordIndex] &= ~mask
            }
        }
    }

    @inlinable
    public func get(_ index: Int) throws(__BitArrayInlineError) -> Bool {
        guard index >= 0 && index < _count else {
            throw .bounds(index: index, count: _count)
        }
        let wordIndex = index / Self._bitsPerWord
        let bitIndex = index % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex
        return (_storage[wordIndex] & mask) != 0
    }
}

// MARK: - Bit Operations

extension Bit.Array.Inline {
    @inlinable
    public mutating func set(_ index: Int) throws(__BitArrayInlineError) {
        guard index >= 0 && index < _count else {
            throw .bounds(index: index, count: _count)
        }
        let wordIndex = index / Self._bitsPerWord
        let bitIndex = index % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex
        _storage[wordIndex] |= mask
    }

    @inlinable
    public mutating func clear(_ index: Int) throws(__BitArrayInlineError) {
        guard index >= 0 && index < _count else {
            throw .bounds(index: index, count: _count)
        }
        let wordIndex = index / Self._bitsPerWord
        let bitIndex = index % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex
        _storage[wordIndex] &= ~mask
    }

    @inlinable
    public mutating func toggle(_ index: Int) throws(__BitArrayInlineError) {
        guard index >= 0 && index < _count else {
            throw .bounds(index: index, count: _count)
        }
        let wordIndex = index / Self._bitsPerWord
        let bitIndex = index % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex
        _storage[wordIndex] ^= mask
    }

    @inlinable
    public mutating func clearAll() {
        for i in 0..<wordCount {
            _storage[i] = 0
        }
    }

    @inlinable
    public mutating func setAll() {
        for i in 0..<wordCount {
            _storage[i] = ~0
        }
        let unusedBits = wordCount * Self._bitsPerWord - _count
        if unusedBits > 0 && wordCount > 0 {
            let lastWord = wordCount - 1
            let mask: UInt = ~0 >> unusedBits
            _storage[lastWord] = mask
        }
    }
}

// MARK: - Resize

extension Bit.Array.Inline {
    @inlinable
    public mutating func resize(to newCount: Int, fill: Bool = false) throws(__BitArrayInlineError) {
        guard newCount >= 0 && newCount <= Self.capacity else {
            throw .overflow
        }

        let oldCount = _count

        if fill && newCount > oldCount {
            let oldWordIndex = oldCount / Self._bitsPerWord
            let newWordIndex = (newCount - 1) / Self._bitsPerWord

            if oldCount % Self._bitsPerWord != 0 {
                let highMask: UInt = ~0 << (oldCount % Self._bitsPerWord)
                _storage[oldWordIndex] |= highMask
            }

            for i in (oldWordIndex + 1)...newWordIndex {
                _storage[i] = ~0
            }
        }

        _count = newCount

        let usedWordCount = (newCount + Self._bitsPerWord - 1) / Self._bitsPerWord
        if usedWordCount > 0 {
            let unusedBits = usedWordCount * Self._bitsPerWord - newCount
            if unusedBits > 0 {
                let lastWord = usedWordCount - 1
                let mask: UInt = ~0 >> unusedBits
                _storage[lastWord] &= mask
            }
        }
    }
}

// MARK: - Iteration

extension Bit.Array.Inline {
    @inlinable
    public func forEachSetBit(_ body: (Int) -> Void) {
        for wordIndex in 0..<wordCount {
            var word = _storage[wordIndex]
            while word != 0 {
                let bitIndex = word.trailingZeroBitCount
                let globalIndex = wordIndex * Self._bitsPerWord + bitIndex
                if globalIndex < _count {
                    body(globalIndex)
                }
                word &= word - 1
            }
        }
    }
}

// MARK: - Equatable

extension Bit.Array.Inline: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs._count == rhs._count else { return false }
        for i in 0..<wordCount {
            if lhs._storage[i] != rhs._storage[i] { return false }
        }
        return true
    }
}

// MARK: - Hashable

extension Bit.Array.Inline: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_count)
        for i in 0..<wordCount {
            hasher.combine(_storage[i])
        }
    }
}
