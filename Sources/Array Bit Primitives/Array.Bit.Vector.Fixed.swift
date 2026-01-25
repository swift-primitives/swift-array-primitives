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

// MARK: - Array<Bit>.Vector.Fixed

extension Array<Bit>.Vector {
    /// Fixed-capacity packed bit array.
    ///
    /// `Array<Bit>.Vector.Fixed` stores bits in a fixed-size buffer, throwing on overflow.
    /// Use when the maximum size is known and overflow should be an error.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var bits = try Array<Bit>.Vector.Fixed(capacity: 100)
    /// try bits.append(true)
    /// try bits.set(50)
    /// bits[50]  // true
    /// ```
    public struct Fixed: Sendable {
        @usableFromInline
        static var _bitsPerWord: Int { UInt.bitWidth }

        @usableFromInline
        let _capacity: Index.Count

        @usableFromInline
        var _storage: ContiguousArray<UInt>

        @usableFromInline
        var _count: Index.Count

        /// Creates an empty bounded bit array with the specified capacity.
        ///
        /// - Parameter capacity: The maximum number of bits.
        @inlinable
        public init(capacity: Index.Count) {
            let wordCount = (capacity.rawValue + Self._bitsPerWord - 1) / Self._bitsPerWord
            self._capacity = capacity
            self._storage = ContiguousArray(repeating: 0, count: wordCount)
            self._count = .zero
        }

        /// Creates a bounded bit array with an initial count.
        ///
        /// - Parameters:
        ///   - capacity: The maximum number of bits.
        ///   - count: The initial number of bits (all set to false).
        /// - Throws: `Error.overflow` if count exceeds capacity.
        @inlinable
        public init(capacity: Index.Count, count: Index.Count) throws(Error) {
            guard count <= capacity else {
                throw .overflow
            }
            let wordCount = (capacity.rawValue + Self._bitsPerWord - 1) / Self._bitsPerWord
            self._capacity = capacity
            self._storage = ContiguousArray(repeating: 0, count: wordCount)
            self._count = count
        }
    }
}

// MARK: - Properties

extension Array<Bit>.Vector.Fixed {
    /// The number of bits in the array.
    @inlinable
    public var count: Bit.Index.Count { _count }

    /// The maximum number of bits the array can hold.
    @inlinable
    public var capacity: Bit.Index.Count { _capacity }

    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { _count == .zero }

    /// Whether the array is at full capacity.
    @inlinable
    public var isFull: Bool { _count >= _capacity }

    /// The number of remaining slots.
    @inlinable
    public var remainingCapacity: Bit.Index.Count? { _capacity - _count }

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

extension Array<Bit>.Vector.Fixed {
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

extension Array<Bit>.Vector.Fixed {
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
        let usedWords = (_count.rawValue + Self._bitsPerWord - 1) / Self._bitsPerWord
        for i in 0..<usedWords {
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

extension Array<Bit>.Vector.Fixed {
    /// Appends a boolean value to the array.
    ///
    /// - Parameter value: The value to append.
    /// - Throws: `Error.overflow` if the array is at capacity.
    @inlinable
    public mutating func append(_ value: Bool) throws(Error) {
        guard _count < _capacity else {
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

extension Array<Bit>.Vector.Fixed {
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

extension Array<Bit>.Vector.Fixed {
    /// Creates a bounded bit array from a sequence of booleans.
    @inlinable
    public init<S: Swift.Sequence>(capacity: Bit.Index.Count, _ elements: S) throws(Error) where S.Element == Bool {
        self.init(capacity: capacity)
        for element in elements {
            try append(element)
        }
    }

    /// Creates a bounded bit array with a repeated value.
    @inlinable
    public init(capacity: Bit.Index.Count, repeating value: Bool, count: Bit.Index.Count) throws(Error) {
        try self.init(capacity: capacity, count: count)
        if value {
            setAll()
        }
    }
}

// MARK: - Conversion

extension Array<Bit>.Vector.Fixed {
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

extension Array<Bit>.Vector {
    /// Creates a packed bit array from a bounded packed bit array.
    @inlinable
    public init(_ bounded: Array<Bit>.Vector.Fixed) {
        self.init()
        for bit in bounded {
            append(bit)
        }
    }
}

// MARK: - Sequence

extension Array<Bit>.Vector.Fixed: Swift.Sequence {
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
        Iterator(storage: _storage, count: _count.rawValue)
    }
}

// MARK: - Equatable

extension Array<Bit>.Vector.Fixed: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs._count == rhs._count else { return false }
        let wordCount = (lhs._count.rawValue + _bitsPerWord - 1) / _bitsPerWord
        for i in 0..<wordCount {
            if lhs._storage[i] != rhs._storage[i] { return false }
        }
        return true
    }
}

// MARK: - Hashable

extension Array<Bit>.Vector.Fixed: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_count)
        let wordCount = (_count.rawValue + Self._bitsPerWord - 1) / Self._bitsPerWord
        for i in 0..<wordCount {
            hasher.combine(_storage[i])
        }
    }
}

// MARK: - CustomStringConvertible

extension Array<Bit>.Vector.Fixed: CustomStringConvertible {
    public var description: String {
        let bits = prefix(64).map { $0 ? "1" : "0" }.joined()
        let suffix = _count.rawValue > 64 ? "..." : ""
        return "Array<Bit>.Vector.Fixed(\(bits)\(suffix), capacity: \(_capacity.rawValue))"
    }
}

// MARK: - Error Typealias

extension Array<Bit>.Vector.Fixed {
    /// Errors that can occur during bounded packed bit array operations.
    public typealias Error = __ArrayBitVectorFixedError
}
