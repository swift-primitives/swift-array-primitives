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

// MARK: - Array<Bit>.Packed.Bounded

extension Array<Bit>.Vector {
    /// Fixed-capacity packed bit array.
    ///
    /// `Array<Bit>.Packed.Bounded` stores bits in a fixed-size buffer, throwing on overflow.
    /// Use when the maximum size is known and overflow should be an error.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var bits = try Array<Bit>.Packed.Bounded(capacity: 100)
    /// try bits.append(true)
    /// try bits.set(50)
    /// bits[50]  // true
    /// ```
    public struct Bounded: Sendable {
        @usableFromInline
        static var _bitsPerWord: Int { UInt.bitWidth }

        @usableFromInline
        let _capacity: Int

        @usableFromInline
        var _storage: ContiguousArray<UInt>

        @usableFromInline
        var _count: Int

        /// Creates an empty bounded bit array with the specified capacity.
        ///
        /// - Parameter capacity: The maximum number of bits.
        /// - Throws: `Error.invalidCount` if capacity is negative.
        @inlinable
        public init(capacity: Int) throws(Error) {
            guard capacity >= 0 else {
                throw .invalidCount
            }
            let wordCount = (capacity + Self._bitsPerWord - 1) / Self._bitsPerWord
            self._capacity = capacity
            self._storage = ContiguousArray(repeating: 0, count: wordCount)
            self._count = 0
        }

        /// Creates a bounded bit array with an initial count.
        ///
        /// - Parameters:
        ///   - capacity: The maximum number of bits.
        ///   - count: The initial number of bits (all set to false).
        /// - Throws: `Error.invalidCount` if capacity is negative, `Error.overflow` if count exceeds capacity.
        @inlinable
        public init(capacity: Int, count: Int) throws(Error) {
            guard capacity >= 0 else {
                throw .invalidCount
            }
            guard count >= 0 && count <= capacity else {
                throw .overflow
            }
            let wordCount = (capacity + Self._bitsPerWord - 1) / Self._bitsPerWord
            self._capacity = capacity
            self._storage = ContiguousArray(repeating: 0, count: wordCount)
            self._count = count
        }
    }
}

// MARK: - Properties

extension Array<Bit>.Vector.Bounded {
    /// The number of bits in the array.
    @inlinable
    public var count: Int { _count }

    /// The maximum number of bits the array can hold.
    @inlinable
    public var capacity: Int { _capacity }

    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// Whether the array is at full capacity.
    @inlinable
    public var isFull: Bool { _count >= _capacity }

    /// The number of remaining slots.
    @inlinable
    public var remainingCapacity: Int { _capacity - _count }

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

extension Array<Bit>.Vector.Bounded {
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

extension Array<Bit>.Vector.Bounded {
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
        let usedWords = (_count + Self._bitsPerWord - 1) / Self._bitsPerWord
        for i in 0..<usedWords {
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

extension Array<Bit>.Vector.Bounded {
    /// Appends a boolean value to the array.
    ///
    /// - Parameter value: The value to append.
    /// - Throws: `Error.overflow` if the array is at capacity.
    @inlinable
    public mutating func append(_ value: Bool) throws(Error) {
        guard _count < _capacity else {
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

extension Array<Bit>.Vector.Bounded {
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

extension Array<Bit>.Vector.Bounded {
    /// Creates a bounded bit array from a sequence of booleans.
    @inlinable
    public init<S: Swift.Sequence>(capacity: Int, _ elements: S) throws(Error) where S.Element == Bool {
        try self.init(capacity: capacity)
        for element in elements {
            try append(element)
        }
    }

    /// Creates a bounded bit array with a repeated value.
    @inlinable
    public init(capacity: Int, repeating value: Bool, count: Int) throws(Error) {
        try self.init(capacity: capacity, count: count)
        if value {
            setAll()
        }
    }
}

// MARK: - Conversion

extension Array<Bit>.Vector.Bounded {
    /// Converts to a dynamically-sized packed bit array.
    @inlinable
    public func toPacked() -> Array<Bit>.Vector {
        var result = Array<Bit>.Vector()
        for i in 0..<_count {
            result.append(self[i])
        }
        return result
    }
}

extension Array<Bit>.Vector {
    /// Creates a packed bit array from a bounded packed bit array.
    @inlinable
    public init(_ bounded: Array<Bit>.Vector.Bounded) {
        self.init()
        for i in 0..<bounded._count {
            append(bounded[i])
        }
    }
}

// MARK: - Sequence

extension Array<Bit>.Vector.Bounded: Swift.Sequence {
    public struct Iterator: IteratorProtocol, Sendable {
        @usableFromInline let storage: ContiguousArray<UInt>
        @usableFromInline let count: Int
        @usableFromInline var index: Int

        @usableFromInline
        init(storage: ContiguousArray<UInt>, count: Int) {
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

extension Array<Bit>.Vector.Bounded: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs._count == rhs._count else { return false }
        let wordCount = (lhs._count + _bitsPerWord - 1) / _bitsPerWord
        for i in 0..<wordCount {
            if lhs._storage[i] != rhs._storage[i] { return false }
        }
        return true
    }
}

// MARK: - Hashable

extension Array<Bit>.Vector.Bounded: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_count)
        let wordCount = (_count + Self._bitsPerWord - 1) / Self._bitsPerWord
        for i in 0..<wordCount {
            hasher.combine(_storage[i])
        }
    }
}

// MARK: - CustomStringConvertible

extension Array<Bit>.Vector.Bounded: CustomStringConvertible {
    public var description: String {
        let bits = prefix(64).map { $0 ? "1" : "0" }.joined()
        let suffix = _count > 64 ? "..." : ""
        return "Array<Bit>.Packed.Bounded(\(bits)\(suffix), capacity: \(_capacity))"
    }
}

// MARK: - Error Typealias

extension Array<Bit>.Vector.Bounded {
    /// Errors that can occur during bounded packed bit array operations.
    public typealias Error = __ArrayBitPackedBoundedError
}
