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
public import Array_Primitives_Core
public import Index_Primitives

// MARK: - Array<Bit>.Vector.Inline

extension Array<Bit>.Vector {
    /// Zero-allocation packed bit array with compile-time capacity.
    ///
    /// `Array<Bit>.Vector.Inline` stores bits in inline storage using `InlineArray`,
    /// avoiding heap allocation entirely. The capacity is specified as a compile-time
    /// constant representing the number of `UInt` words.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // 2 words = 128 bits on 64-bit systems
    /// var bits = Array<Bit>.Vector.Inline<2>()
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
        public static var _capacity: Index.Count { Index.Count(__unchecked: wordCount * _bitsPerWord) }

        @usableFromInline
        var _storage: InlineArray<wordCount, UInt>

        @usableFromInline
        var _count: Index.Count

        /// Creates an empty inline packed bit array.
        @inlinable
        public init() {
            self._storage = InlineArray(repeating: 0)
            self._count = .zero
        }

        /// Creates an inline packed bit array with an initial count.
        ///
        /// - Parameter count: The initial number of bits (all set to false).
        /// - Throws: `Error.overflow` if count exceeds capacity.
        @inlinable
        public init(count: Index.Count) throws(Error) {
            guard count <= Self._capacity else {
                throw .overflow
            }
            self._storage = InlineArray(repeating: 0)
            self._count = count
        }
    }
}

// MARK: - Properties

extension Array<Bit>.Vector.Inline {
    /// The number of bits in the array.
    @inlinable
    public var count: Bit.Index.Count { _count }

    /// The maximum number of bits the array can hold.
    @inlinable
    public var capacity: Bit.Index.Count { Self._capacity }

    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { _count == .zero }

    /// Whether the array is at full capacity.
    @inlinable
    public var isFull: Bool { _count >= Self._capacity }

    /// The number of remaining slots.
    @inlinable
    public var remainingCapacity: Bit.Index.Count? { Self._capacity - _count }

    /// Population count (number of set bits).
    @inlinable
    public var popcount: Int {
        var total = 0
        let usedWords = (_count.rawValue + Self._bitsPerWord - 1) / Self._bitsPerWord
        for i in 0..<usedWords {
            total += _storage[i].nonzeroBitCount
        }
        return total
    }
}

// MARK: - Subscript Access

extension Array<Bit>.Vector.Inline {
    @inlinable
    public subscript(index: Bit.Index) -> Bool {
        get {
            precondition(index < _count, "Index out of bounds")
            let loc = index.location(bitsPerWord: Self._bitsPerWord)
            return (_storage[loc.word] & loc.mask) != 0
        }
        set {
            precondition(index < _count, "Index out of bounds")
            let loc = index.location(bitsPerWord: Self._bitsPerWord)
            if newValue {
                _storage[loc.word] |= loc.mask
            } else {
                _storage[loc.word] &= ~loc.mask
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
        guard index < _count else {
            throw .bounds(index: index, count: _count)
        }
        let loc = index.location(bitsPerWord: Self._bitsPerWord)
        return (_storage[loc.word] & loc.mask) != 0
    }
}

// MARK: - Bit Operations

extension Array<Bit>.Vector.Inline {
    @inlinable
    public mutating func set(_ index: Bit.Index) throws(Error) {
        guard index < _count else {
            throw .bounds(index: index, count: _count)
        }
        let loc = index.location(bitsPerWord: Self._bitsPerWord)
        _storage[loc.word] |= loc.mask
    }

    @inlinable
    public mutating func clear(_ index: Bit.Index) throws(Error) {
        guard index < _count else {
            throw .bounds(index: index, count: _count)
        }
        let loc = index.location(bitsPerWord: Self._bitsPerWord)
        _storage[loc.word] &= ~loc.mask
    }

    @inlinable
    public mutating func toggle(_ index: Bit.Index) throws(Error) {
        guard index < _count else {
            throw .bounds(index: index, count: _count)
        }
        let loc = index.location(bitsPerWord: Self._bitsPerWord)
        _storage[loc.word] ^= loc.mask
    }

    @inlinable
    public mutating func clearAll() {
        for i in 0..<wordCount {
            _storage[i] = 0
        }
    }

    @inlinable
    public mutating func setAll() {
        let usedWords = (_count.rawValue + Self._bitsPerWord - 1) / Self._bitsPerWord
        for i in 0..<usedWords {
            _storage[i] = ~0
        }
        // Clear unused high bits
        let unusedBits = usedWords * Self._bitsPerWord - _count.rawValue
        if unusedBits > 0 && usedWords > 0 {
            let lastWord = usedWords - 1
            let mask: UInt = ~0 >> unusedBits
            _storage[lastWord] = mask
        }
    }
}

// MARK: - Append and Remove

extension Array<Bit>.Vector.Inline {
    /// Appends a boolean value to the array.
    ///
    /// - Parameter value: The value to append.
    /// - Throws: `Error.overflow` if the array is at capacity.
    @inlinable
    public mutating func append(_ value: Bool) throws(Error) {
        guard _count < Self._capacity else {
            throw .overflow
        }
        let loc = Bit.Index.Location(count: _count, bitsPerWord: Self._bitsPerWord)

        if value {
            _storage[loc.word] |= loc.mask
        }
        _count = _count + .one
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
        guard let newCount = _count - .one else { return nil }
        _count = newCount
        let loc = Bit.Index.Location(count: _count, bitsPerWord: Self._bitsPerWord)
        let value = (_storage[loc.word] & loc.mask) != 0
        _storage[loc.word] &= ~loc.mask
        return value
    }

    /// Removes the last element.
    @inlinable
    public mutating func removeLast() {
        precondition(_count > .zero, "Cannot remove from empty array")
        _count = (_count - .one)!
        let loc = Bit.Index.Location(count: _count, bitsPerWord: Self._bitsPerWord)
        _storage[loc.word] &= ~loc.mask
    }

    /// Removes all elements.
    @inlinable
    public mutating func removeAll() {
        clearAll()
        _count = .zero
    }
}

// MARK: - Additional Properties

extension Array<Bit>.Vector.Inline {
    @inlinable
    public var first: Bool? {
        guard _count > .zero else { return nil }
        return (_storage[0] & 1) != 0
    }

    @inlinable
    public var last: Bool? {
        guard let lastCount = _count - .one else { return nil }
        let loc = Bit.Index.Location(count: lastCount, bitsPerWord: Self._bitsPerWord)
        return (_storage[loc.word] & loc.mask) != 0
    }

    @inlinable
    public var trueCount: Int { popcount }

    @inlinable
    public var falseCount: Int { _count.rawValue - popcount }

    @inlinable
    public var allTrue: Bool {
        guard _count > .zero else { return true }
        return popcount == _count.rawValue
    }

    @inlinable
    public var allFalse: Bool { popcount == 0 }
}

// MARK: - Initializers

extension Array<Bit>.Vector.Inline {
    /// Creates an inline packed bit array with a repeated value.
    @inlinable
    public init(repeating value: Bool, count: Bit.Index.Count) throws(Error) {
        try self.init(count: count)
        if value {
            setAll()
        }
    }
}

// MARK: - Conversion

extension Array<Bit>.Vector.Inline {
    /// Converts to a dynamically-sized packed bit array.
    @inlinable
    public func toPacked() -> Array<Bit>.Vector {
        var result = Array<Bit>.Vector()
        for bit in self {
            result.append(bit)
        }
        return result
    }
}

// MARK: - Sequence

extension Array<Bit>.Vector.Inline: Swift.Sequence {
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
        Iterator(storage: _storage, count: _count.rawValue)
    }
}

// MARK: - Equatable

extension Array<Bit>.Vector.Inline: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs._count == rhs._count else { return false }
        let usedWords = (lhs._count.rawValue + _bitsPerWord - 1) / _bitsPerWord
        for i in 0..<usedWords {
            if lhs._storage[i] != rhs._storage[i] { return false }
        }
        return true
    }
}

// MARK: - Hashable

extension Array<Bit>.Vector.Inline: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_count)
        let usedWords = (_count.rawValue + Self._bitsPerWord - 1) / Self._bitsPerWord
        for i in 0..<usedWords {
            hasher.combine(_storage[i])
        }
    }
}

// MARK: - CustomStringConvertible

extension Array<Bit>.Vector.Inline: CustomStringConvertible {
    public var description: String {
        let bits = prefix(64).map { $0 ? "1" : "0" }.joined()
        let suffix = _count.rawValue > 64 ? "..." : ""
        return "Array<Bit>.Vector.Inline<\(wordCount)>(\(bits)\(suffix))"
    }
}

// MARK: - Error Typealias

extension Array<Bit>.Vector.Inline {
    /// Errors that can occur during inline packed bit array operations.
    public typealias Error = __ArrayBitVectorInlineError
}
