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

// MARK: - Bit.Array.Bounded

extension Bit.Array {
    /// Fixed-capacity packed bit array.
    ///
    /// `Bit.Array.Bounded` allocates storage upfront and throws on overflow.
    /// Use this variant when capacity is known or in contexts requiring
    /// predictable memory behavior.
    public struct Bounded: Sendable {
        @usableFromInline
        static var _bitsPerWord: Int { UInt.bitWidth }

        @usableFromInline
        var _storage: ContiguousArray<UInt>

        @usableFromInline
        var _count: Int

        public let capacity: Int

        @inlinable
        public init(capacity: Int) throws(Bit.Array.Bounded.Error) {
            guard capacity >= 0 else {
                throw .invalidCount
            }
            let wordCount = (capacity + Self._bitsPerWord - 1) / Self._bitsPerWord
            self._storage = ContiguousArray(repeating: 0, count: wordCount)
            self._count = 0
            self.capacity = capacity
        }

        @inlinable
        public init(count: Int, capacity: Int) throws(Bit.Array.Bounded.Error) {
            guard count >= 0 && capacity >= 0 else {
                throw .invalidCount
            }
            guard count <= capacity else {
                throw .overflow
            }
            let wordCount = (capacity + Self._bitsPerWord - 1) / Self._bitsPerWord
            self._storage = ContiguousArray(repeating: 0, count: wordCount)
            self._count = count
            self.capacity = capacity
        }
    }
}

// MARK: - Properties

extension Bit.Array.Bounded {
    @inlinable
    public var count: Int { _count }

    @inlinable
    public var isEmpty: Bool { _count == 0 }

    @inlinable
    public var isFull: Bool { _count >= capacity }

    @inlinable
    public var popcount: Int {
        var total = 0
        for word in _storage {
            total += word.nonzeroBitCount
        }
        return total
    }
}

// MARK: - Subscript Access

extension Bit.Array.Bounded {
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
    public func get(_ index: Int) throws(Bit.Array.Bounded.Error) -> Bool {
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

extension Bit.Array.Bounded {
    @inlinable
    public mutating func set(_ index: Int) throws(Bit.Array.Bounded.Error) {
        guard index >= 0 && index < _count else {
            throw .bounds(index: index, count: _count)
        }
        let wordIndex = index / Self._bitsPerWord
        let bitIndex = index % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex
        _storage[wordIndex] |= mask
    }

    @inlinable
    public mutating func clear(_ index: Int) throws(Bit.Array.Bounded.Error) {
        guard index >= 0 && index < _count else {
            throw .bounds(index: index, count: _count)
        }
        let wordIndex = index / Self._bitsPerWord
        let bitIndex = index % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex
        _storage[wordIndex] &= ~mask
    }

    @inlinable
    public mutating func toggle(_ index: Int) throws(Bit.Array.Bounded.Error) {
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
        for i in 0..<_storage.count {
            _storage[i] = 0
        }
    }

    @inlinable
    public mutating func setAll() {
        for i in 0..<_storage.count {
            _storage[i] = ~0
        }
        let unusedBits = _storage.count * Self._bitsPerWord - _count
        if unusedBits > 0 && !_storage.isEmpty {
            let lastWord = _storage.count - 1
            let mask: UInt = ~0 >> unusedBits
            _storage[lastWord] = mask
        }
    }
}

// MARK: - Resize

extension Bit.Array.Bounded {
    @inlinable
    public mutating func resize(to newCount: Int, fill: Bool = false) throws(Bit.Array.Bounded.Error) {
        guard newCount >= 0 else {
            throw .invalidCount
        }
        guard newCount <= capacity else {
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

        let wordCount = (newCount + Self._bitsPerWord - 1) / Self._bitsPerWord
        if wordCount > 0 {
            let unusedBits = wordCount * Self._bitsPerWord - newCount
            if unusedBits > 0 {
                let lastWord = wordCount - 1
                let mask: UInt = ~0 >> unusedBits
                _storage[lastWord] &= mask
            }
        }
    }
}

// MARK: - Iteration

extension Bit.Array.Bounded {
    @inlinable
    public func forEachSetBit(_ body: (Int) -> Void) {
        for (wordIndex, var word) in _storage.enumerated() {
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

extension Bit.Array.Bounded: Equatable {}

// MARK: - Hashable

extension Bit.Array.Bounded: Hashable {}
