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

// MARK: - Bit.Array

extension Bit {
    /// Packed bit array using word-sized storage.
    ///
    /// `Bit.Array` stores boolean values as individual bits, providing 8x space
    /// efficiency over `[Bool]`. Operations are O(1) for single bit access and O(n/64)
    /// for bulk operations.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var bits = try Bit.Array(count: 100)
    /// try bits.set(42)
    /// bits[42]           // true
    /// bits.popcount      // 1
    /// try bits.toggle(42)
    /// bits[42]           // false
    /// ```
    ///
    /// ## Variants
    ///
    /// - ``Bit/Array``: Dynamically-growing storage (this type)
    /// - ``Bit/Array/Bounded``: Fixed-capacity, throws on overflow
    /// - ``Bit/Array/Inline``: Zero-allocation inline storage with compile-time capacity
    public struct Array: Sendable {
        @usableFromInline
        static var _bitsPerWord: Int { UInt.bitWidth }

        @usableFromInline
        var _storage: ContiguousArray<UInt>

        @usableFromInline
        var _count: Int

        @inlinable
        public init() {
            self._storage = []
            self._count = 0
        }

        @inlinable
        public init(count: Int) throws(__BitArrayError) {
            guard count >= 0 else {
                throw .invalidCount
            }
            let wordCount = (count + Self._bitsPerWord - 1) / Self._bitsPerWord
            self._storage = ContiguousArray(repeating: 0, count: wordCount)
            self._count = count
        }
    }
}

// MARK: - Properties

extension Bit.Array {
    @inlinable
    public var count: Int { _count }

    @inlinable
    public var isEmpty: Bool { _count == 0 }

    @inlinable
    public var popcount: Int {
        var total = 0
        for word in _storage {
            total += word.nonzeroBitCount
        }
        return total
    }

    @usableFromInline
    var _wordCount: Int { _storage.count }
}

// MARK: - Subscript Access

extension Bit.Array {
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
    public func get(_ index: Int) throws(__BitArrayError) -> Bool {
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

extension Bit.Array {
    @inlinable
    public mutating func set(_ index: Int) throws(__BitArrayError) {
        guard index >= 0 && index < _count else {
            throw .bounds(index: index, count: _count)
        }
        let wordIndex = index / Self._bitsPerWord
        let bitIndex = index % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex
        _storage[wordIndex] |= mask
    }

    @inlinable
    public mutating func clear(_ index: Int) throws(__BitArrayError) {
        guard index >= 0 && index < _count else {
            throw .bounds(index: index, count: _count)
        }
        let wordIndex = index / Self._bitsPerWord
        let bitIndex = index % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex
        _storage[wordIndex] &= ~mask
    }

    @inlinable
    public mutating func toggle(_ index: Int) throws(__BitArrayError) {
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

extension Bit.Array {
    @inlinable
    public mutating func resize(to newCount: Int, fill: Bool = false) throws(__BitArrayError) {
        guard newCount >= 0 else {
            throw .invalidCount
        }

        let oldCount = _count
        let oldWordCount = _storage.count
        let newWordCount = (newCount + Self._bitsPerWord - 1) / Self._bitsPerWord

        if newWordCount > oldWordCount {
            let fillValue: UInt = fill ? ~0 : 0
            _storage.reserveCapacity(newWordCount)
            for _ in oldWordCount..<newWordCount {
                _storage.append(fillValue)
            }
        } else if newWordCount < oldWordCount {
            _storage.removeLast(oldWordCount - newWordCount)
        }

        if fill && newCount > oldCount && oldWordCount > 0 {
            let oldBitInWord = oldCount % Self._bitsPerWord
            if oldBitInWord > 0 {
                let firstWordIndex = oldCount / Self._bitsPerWord
                if firstWordIndex < newWordCount {
                    let highMask: UInt = ~0 << oldBitInWord
                    _storage[firstWordIndex] |= highMask
                }
            }
        }

        _count = newCount

        if newWordCount > 0 {
            let unusedBits = newWordCount * Self._bitsPerWord - newCount
            if unusedBits > 0 {
                let lastWord = newWordCount - 1
                let mask: UInt = ~0 >> unusedBits
                _storage[lastWord] &= mask
            }
        }
    }
}

// MARK: - Iteration

extension Bit.Array {
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

// MARK: - Additional Properties

extension Bit.Array {
    /// Returns the first element, or `nil` if empty.
    @inlinable
    public var first: Bool? {
        guard _count > 0 else { return nil }
        return (_storage[0] & 1) != 0
    }

    /// Returns the last element, or `nil` if empty.
    @inlinable
    public var last: Bool? {
        guard _count > 0 else { return nil }
        let lastIndex = _count - 1
        let wordIndex = lastIndex / Self._bitsPerWord
        let bitIndex = lastIndex % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex
        return (_storage[wordIndex] & mask) != 0
    }

    /// Returns the number of `true` values in the array.
    ///
    /// This is an alias for ``popcount``.
    ///
    /// - Complexity: O(n/w) where w is word bit width
    @inlinable
    public var trueCount: Int { popcount }

    /// Returns the number of `false` values in the array.
    ///
    /// - Complexity: O(n/w) where w is word bit width
    @inlinable
    public var falseCount: Int { _count - popcount }

    /// Whether all elements are `true`.
    @inlinable
    public var allTrue: Bool {
        guard _count > 0 else { return true }
        return popcount == _count
    }

    /// Whether all elements are `false`.
    @inlinable
    public var allFalse: Bool {
        popcount == 0
    }
}

// MARK: - Append and Remove

extension Bit.Array {
    /// Appends a boolean value to the array.
    ///
    /// - Parameter value: The boolean value to append.
    /// - Complexity: O(1) amortized
    @inlinable
    public mutating func append(_ value: Bool) {
        let newIndex = _count
        let wordIndex = newIndex / Self._bitsPerWord
        let bitIndex = newIndex % Self._bitsPerWord

        if wordIndex >= _storage.count {
            _storage.append(0)
        }

        if value {
            let mask: UInt = 1 << bitIndex
            _storage[wordIndex] |= mask
        }

        _count += 1
    }

    /// Removes and returns the last element.
    ///
    /// - Returns: The last element, or `nil` if empty.
    /// - Complexity: O(1)
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
    ///
    /// - Precondition: The array must not be empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func removeLast() {
        precondition(_count > 0, "Cannot remove from empty array")
        _count -= 1
        let wordIndex = _count / Self._bitsPerWord
        let bitIndex = _count % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex
        _storage[wordIndex] &= ~mask
    }

    /// Removes all elements from the array.
    ///
    /// - Parameter keepingCapacity: Whether to keep the underlying storage.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool = false) {
        if keepingCapacity {
            for i in 0..<_storage.count {
                _storage[i] = 0
            }
        } else {
            _storage.removeAll()
        }
        _count = 0
    }
}

// MARK: - Additional Initializers

extension Bit.Array {
    /// Creates a bit array from a sequence of booleans.
    ///
    /// - Parameter elements: The boolean values to include.
    @inlinable
    public init<S: Sequence>(_ elements: S) where S.Element == Bool {
        self.init()
        for element in elements {
            append(element)
        }
    }

    /// Creates a bit array with a repeated value.
    ///
    /// - Parameters:
    ///   - repeating: The value to repeat.
    ///   - count: The number of times to repeat the value.
    @inlinable
    public init(repeating value: Bool, count: Int) {
        precondition(count >= 0, "Count must be non-negative")
        let wordCount = (count + Self._bitsPerWord - 1) / Self._bitsPerWord
        self._storage = ContiguousArray(repeating: value ? ~0 : 0, count: wordCount)
        self._count = count

        if value && count > 0 {
            let unusedBits = wordCount * Self._bitsPerWord - count
            if unusedBits > 0 {
                let lastWord = wordCount - 1
                let mask: UInt = ~0 >> unusedBits
                _storage[lastWord] = mask
            }
        }
    }
}

// MARK: - Sequence

extension Bit.Array: Sequence {
    /// An iterator over the elements of a bit array.
    public struct Iterator: IteratorProtocol, Sendable {
        @usableFromInline
        let storage: ContiguousArray<UInt>

        @usableFromInline
        let count: Int

        @usableFromInline
        var index: Int

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

// MARK: - RandomAccessCollection

extension Bit.Array: RandomAccessCollection {
    public typealias Index = Int
    public typealias Element = Bool

    @inlinable
    public var startIndex: Index { 0 }

    @inlinable
    public var endIndex: Index { _count }

    @inlinable
    public var indices: Range<Int> { 0..<_count }

    @inlinable
    public func index(after i: Index) -> Index { i + 1 }

    @inlinable
    public func index(before i: Index) -> Index { i - 1 }
}

// MARK: - Equatable

extension Bit.Array: Equatable {}

// MARK: - Hashable

extension Bit.Array: Hashable {}

// MARK: - CustomStringConvertible

extension Bit.Array: CustomStringConvertible {
    public var description: String {
        let bits = prefix(64).map { $0 ? "1" : "0" }.joined()
        let suffix = _count > 64 ? "..." : ""
        return "Bit.Array(\(bits)\(suffix))"
    }
}
