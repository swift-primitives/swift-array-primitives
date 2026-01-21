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

// MARK: - Array<Bit>.Packed.Inline

extension Array<Bit>.Packed {
    /// Zero-allocation packed bit array with compile-time capacity.
    ///
    /// `Array<Bit>.Packed.Inline` stores bits in inline storage using `InlineArray`,
    /// avoiding heap allocation entirely. The capacity is specified as a compile-time
    /// constant representing the number of `UInt` words.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // 2 words = 128 bits on 64-bit systems
    /// var bits = Array<Bit>.Packed.Inline<2>()
    /// try bits.append(true)
    /// try bits.append(false)
    /// bits[0]  // true
    /// ```
    ///
    /// ## Capacity
    ///
    /// The capacity is `wordCount * UInt.bitWidth`:
    /// - `Inline<1>`: 64 bits
    /// - `Inline<2>`: 128 bits
    /// - `Inline<4>`: 256 bits
    /// - `Inline<8>`: 512 bits
    public struct Inline<let wordCount: Int>: Sendable {
        @usableFromInline
        static var _bitsPerWord: Int { UInt.bitWidth }

        /// The maximum number of bits that can be stored.
        @inlinable
        public static var capacity: Int { wordCount * _bitsPerWord }

        @usableFromInline
        var _storage: InlineArray<wordCount, UInt>

        @usableFromInline
        var _count: Int

        /// Creates an empty inline packed bit array.
        @inlinable
        public init() {
            self._storage = InlineArray(repeating: 0)
            self._count = 0
        }

        /// Creates an inline packed bit array with an initial count.
        ///
        /// - Parameter count: The initial number of bits (all set to false).
        /// - Throws: `Error.overflow` if count exceeds capacity.
        @inlinable
        public init(count: Int) throws(Error) {
            guard count >= 0 && count <= Self.capacity else {
                throw .overflow
            }
            self._storage = InlineArray(repeating: 0)
            self._count = count
        }
    }
}

// MARK: - Properties

extension Array<Bit>.Packed.Inline {
    /// The number of bits in the array.
    @inlinable
    public var count: Int { _count }

    /// The maximum number of bits the array can hold.
    @inlinable
    public var capacity: Int { Self.capacity }

    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// Whether the array is at full capacity.
    @inlinable
    public var isFull: Bool { _count >= Self.capacity }

    /// The number of remaining slots.
    @inlinable
    public var remainingCapacity: Int { Self.capacity - _count }

    /// Population count (number of set bits).
    @inlinable
    public var popcount: Int {
        var total = 0
        let usedWords = (_count + Self._bitsPerWord - 1) / Self._bitsPerWord
        for i in 0..<usedWords {
            total += _storage[i].nonzeroBitCount
        }
        return total
    }
}

// MARK: - Subscript Access

extension Array<Bit>.Packed.Inline {
    @inlinable
    public subscript(index: Bit.Index) -> Bool {
        get {
            let i = index.position.rawValue
            precondition(i >= 0 && i < _count, "Index out of bounds")
            let wordIndex = i / Self._bitsPerWord
            let bitIndex = i % Self._bitsPerWord
            let mask: UInt = 1 << bitIndex
            return (_storage[wordIndex] & mask) != 0
        }
        set {
            let i = index.position.rawValue
            precondition(i >= 0 && i < _count, "Index out of bounds")
            let wordIndex = i / Self._bitsPerWord
            let bitIndex = i % Self._bitsPerWord
            let mask: UInt = 1 << bitIndex
            if newValue {
                _storage[wordIndex] |= mask
            } else {
                _storage[wordIndex] &= ~mask
            }
        }
    }

    @inlinable
    public subscript(index: Int) -> Bool {
        get { self[Bit.Index(__unchecked: (), position: index)] }
        set { self[Bit.Index(__unchecked: (), position: index)] = newValue }
    }

    @inlinable
    public func get(_ index: Bit.Index) throws(Error) -> Bool {
        let i = index.position.rawValue
        guard i >= 0 && i < _count else {
            throw .bounds(index: i, count: _count)
        }
        let wordIndex = i / Self._bitsPerWord
        let bitIndex = i % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex
        return (_storage[wordIndex] & mask) != 0
    }
}

// MARK: - Bit Operations

extension Array<Bit>.Packed.Inline {
    @inlinable
    public mutating func set(_ index: Bit.Index) throws(Error) {
        let i = index.position.rawValue
        guard i >= 0 && i < _count else {
            throw .bounds(index: i, count: _count)
        }
        let wordIndex = i / Self._bitsPerWord
        let bitIndex = i % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex
        _storage[wordIndex] |= mask
    }

    @inlinable
    public mutating func clear(_ index: Bit.Index) throws(Error) {
        let i = index.position.rawValue
        guard i >= 0 && i < _count else {
            throw .bounds(index: i, count: _count)
        }
        let wordIndex = i / Self._bitsPerWord
        let bitIndex = i % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex
        _storage[wordIndex] &= ~mask
    }

    @inlinable
    public mutating func toggle(_ index: Bit.Index) throws(Error) {
        let i = index.position.rawValue
        guard i >= 0 && i < _count else {
            throw .bounds(index: i, count: _count)
        }
        let wordIndex = i / Self._bitsPerWord
        let bitIndex = i % Self._bitsPerWord
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
        let usedWords = (_count + Self._bitsPerWord - 1) / Self._bitsPerWord
        for i in 0..<usedWords {
            _storage[i] = ~0
        }
        // Clear unused high bits
        let unusedBits = usedWords * Self._bitsPerWord - _count
        if unusedBits > 0 && usedWords > 0 {
            let lastWord = usedWords - 1
            let mask: UInt = ~0 >> unusedBits
            _storage[lastWord] = mask
        }
    }
}

// MARK: - Append and Remove

extension Array<Bit>.Packed.Inline {
    /// Appends a boolean value to the array.
    ///
    /// - Parameter value: The value to append.
    /// - Throws: `Error.overflow` if the array is at capacity.
    @inlinable
    public mutating func append(_ value: Bool) throws(Error) {
        guard _count < Self.capacity else {
            throw .overflow
        }
        let newIndex = _count
        let wordIndex = newIndex / Self._bitsPerWord
        let bitIndex = newIndex % Self._bitsPerWord

        if value {
            let mask: UInt = 1 << bitIndex
            _storage[wordIndex] |= mask
        }
        _count += 1
    }

    /// Appends a `Bit` value to the array.
    @inlinable
    public mutating func append(_ bit: Bit) throws(Error) {
        try append(bit.boolValue)
    }

    /// Removes and returns the last element.
    @discardableResult
    @inlinable
    public mutating func popLast() -> Bool? {
        guard _count > 0 else { return nil }
        _count -= 1
        let wordIndex = _count / Self._bitsPerWord
        let bitIndex = _count % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex
        let value = (_storage[wordIndex] & mask) != 0
        _storage[wordIndex] &= ~mask
        return value
    }

    /// Removes the last element.
    @inlinable
    public mutating func removeLast() {
        precondition(_count > 0, "Cannot remove from empty array")
        _count -= 1
        let wordIndex = _count / Self._bitsPerWord
        let bitIndex = _count % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex
        _storage[wordIndex] &= ~mask
    }

    /// Removes all elements.
    @inlinable
    public mutating func removeAll() {
        clearAll()
        _count = 0
    }
}

// MARK: - Additional Properties

extension Array<Bit>.Packed.Inline {
    @inlinable
    public var first: Bool? {
        guard _count > 0 else { return nil }
        return (_storage[0] & 1) != 0
    }

    @inlinable
    public var last: Bool? {
        guard _count > 0 else { return nil }
        let lastIndex = _count - 1
        let wordIndex = lastIndex / Self._bitsPerWord
        let bitIndex = lastIndex % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex
        return (_storage[wordIndex] & mask) != 0
    }

    @inlinable
    public var trueCount: Int { popcount }

    @inlinable
    public var falseCount: Int { _count - popcount }

    @inlinable
    public var allTrue: Bool {
        guard _count > 0 else { return true }
        return popcount == _count
    }

    @inlinable
    public var allFalse: Bool { popcount == 0 }
}

// MARK: - Initializers

extension Array<Bit>.Packed.Inline {
    /// Creates an inline packed bit array with a repeated value.
    @inlinable
    public init(repeating value: Bool, count: Int) throws(Error) {
        try self.init(count: count)
        if value {
            setAll()
        }
    }
}

// MARK: - Conversion

extension Array<Bit>.Packed.Inline {
    /// Converts to a dynamically-sized packed bit array.
    @inlinable
    public func toPacked() -> Array<Bit>.Packed {
        var result = Array<Bit>.Packed()
        for i in 0..<_count {
            result.append(self[i])
        }
        return result
    }
}

// MARK: - Sequence

extension Array<Bit>.Packed.Inline: Sequence {
    public struct Iterator: IteratorProtocol, Sendable {
        @usableFromInline let storage: InlineArray<wordCount, UInt>
        @usableFromInline let count: Int
        @usableFromInline var index: Int

        @usableFromInline
        init(storage: InlineArray<wordCount, UInt>, count: Int) {
            self.storage = storage
            self.count = count
            self.index = 0
        }

        @inlinable
        public mutating func next() -> Bool? {
            guard index < count else { return nil }
            let wordIndex = index / UInt.bitWidth
            let bitIndex = index % UInt.bitWidth
            let mask: UInt = 1 << bitIndex
            defer { index += 1 }
            return (storage[wordIndex] & mask) != 0
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(storage: _storage, count: _count)
    }
}

// MARK: - Equatable

extension Array<Bit>.Packed.Inline: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs._count == rhs._count else { return false }
        let usedWords = (lhs._count + _bitsPerWord - 1) / _bitsPerWord
        for i in 0..<usedWords {
            if lhs._storage[i] != rhs._storage[i] { return false }
        }
        return true
    }
}

// MARK: - Hashable

extension Array<Bit>.Packed.Inline: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_count)
        let usedWords = (_count + Self._bitsPerWord - 1) / Self._bitsPerWord
        for i in 0..<usedWords {
            hasher.combine(_storage[i])
        }
    }
}

// MARK: - CustomStringConvertible

extension Array<Bit>.Packed.Inline: CustomStringConvertible {
    public var description: String {
        let bits = prefix(64).map { $0 ? "1" : "0" }.joined()
        let suffix = _count > 64 ? "..." : ""
        return "Array<Bit>.Packed.Inline<\(wordCount)>(\(bits)\(suffix))"
    }
}

// MARK: - Error Typealias

extension Array<Bit>.Packed.Inline {
    /// Errors that can occur during inline packed bit array operations.
    public typealias Error = __ArrayBitPackedInlineError
}
