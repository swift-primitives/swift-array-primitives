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
public import Property_Primitives

// MARK: - Array<Bit>.Vector

extension Array where Element == Bit {
    /// Packed bit array using word-sized storage.
    ///
    /// `Array<Bit>.Vector` stores bits as individual bits in `UInt` words, providing 8x space
    /// efficiency over `[Bit]`. Operations are O(1) for single bit access and O(n/64)
    /// for bulk operations.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var bits = try Array<Bit>.Vector(count: 100)
    /// try bits.set(42)
    /// bits[42]           // true
    /// bits.popcount      // 1
    /// try bits.toggle(42)
    /// bits[42]           // false
    /// ```
    ///
    /// ## Conversions
    ///
    /// ```swift
    /// // From unpacked to packed
    /// let unpacked: [Bit] = [true, false, true]
    /// let packed = Array<Bit>.Vector(unpacked)
    ///
    /// // From packed to unpacked
    /// let backToUnpacked = [Bit](packed)
    /// ```
    ///
    /// ## Variants
    ///
    /// - ``Array<Bit>.Vector``: Dynamically-growing storage (this type)
    /// - ``Array<Bit>.Vector.Fixed``: Fixed-capacity, throws on overflow
    /// - ``Array<Bit>.Vector.Inline``: Zero-allocation inline storage with compile-time capacity
    public struct Vector: Sendable {
        @usableFromInline
        static var _bitsPerWord: Int { UInt.bitWidth }

        @usableFromInline
        var _storage: ContiguousArray<UInt>

        @usableFromInline
        var _count: Index.Count

        @inlinable
        public init() {
            self._storage = []
            self._count = .zero
        }

        @inlinable
        public init(count: Index.Count) {
            let storage = Bit.Index.Storage(count: count, bitsPerWord: Self._bitsPerWord)
            self._storage = ContiguousArray(repeating: 0, count: storage.wordCount)
            self._count = count
        }
    }
}

// MARK: - Properties

extension Array<Bit>.Vector {
    @inlinable
    public var count: Index.Count { _count }

    @inlinable
    public var isEmpty: Bool { _count == .zero }

    @inlinable
    public var popcount: Bit.Index.Count {
        var total = 0
        for word in _storage {
            total += word.nonzeroBitCount
        }
        return Bit.Index.Count(__unchecked: total)
    }

    @usableFromInline
    var _wordCount: Int { _storage.count }
}

// MARK: - Subscript Access

extension Array<Bit>.Vector {
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
    public func get(_ index: Bit.Index) throws(Array<Bit>.Vector.Error) -> Bool {
        guard index < _count else {
            throw .bounds(index: index, count: _count)
        }
        let loc = index.location(bitsPerWord: Self._bitsPerWord)
        return (_storage[loc.word] & loc.mask) != 0
    }
}

// MARK: - Bit Operations

extension Array<Bit>.Vector {
    @inlinable
    public mutating func set(_ index: Bit.Index) throws(Array<Bit>.Vector.Error) {
        guard index < _count else {
            throw .bounds(index: index, count: _count)
        }
        let loc = index.location(bitsPerWord: Self._bitsPerWord)
        _storage[loc.word] |= loc.mask
    }

    @inlinable
    public mutating func clear(_ index: Bit.Index) throws(Array<Bit>.Vector.Error) {
        guard index < _count else {
            throw .bounds(index: index, count: _count)
        }
        let loc = index.location(bitsPerWord: Self._bitsPerWord)
        _storage[loc.word] &= ~loc.mask
    }

    @inlinable
    public mutating func toggle(_ index: Bit.Index) throws(Array<Bit>.Vector.Error) {
        guard index < _count else {
            throw .bounds(index: index, count: _count)
        }
        let loc = index.location(bitsPerWord: Self._bitsPerWord)
        _storage[loc.word] ^= loc.mask
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
        let storage = Bit.Index.Storage(count: _count, bitsPerWord: Self._bitsPerWord)
        if storage.unusedBits > 0 && !_storage.isEmpty {
            let lastWord = _storage.count - 1
            let mask: UInt = ~0 >> storage.unusedBits
            _storage[lastWord] = mask
        }
    }
}

// MARK: - Resize

extension Array<Bit>.Vector {
    @inlinable
    public mutating func resize(to newCount: Index.Count, fill: Bool = false) {
        let newStorage = Bit.Index.Storage(count: newCount, bitsPerWord: Self._bitsPerWord)
        let oldWordCount = _storage.count

        if newStorage.wordCount > oldWordCount {
            let fillValue: UInt = fill ? ~0 : 0
            _storage.reserveCapacity(newStorage.wordCount)
            for _ in oldWordCount..<newStorage.wordCount {
                _storage.append(fillValue)
            }
        } else if newStorage.wordCount < oldWordCount {
            _storage.removeLast(oldWordCount - newStorage.wordCount)
        }

        if fill && newCount > _count && oldWordCount > 0 {
            let oldLoc = Bit.Index.Location(count: _count, bitsPerWord: Self._bitsPerWord)
            if oldLoc.bit > 0 && oldLoc.word < newStorage.wordCount {
                let highMask: UInt = ~0 << oldLoc.bit
                _storage[oldLoc.word] |= highMask
            }
        }

        _count = newCount

        if newStorage.wordCount > 0 && newStorage.unusedBits > 0 {
            let lastWord = newStorage.wordCount - 1
            let mask: UInt = ~0 >> newStorage.unusedBits
            _storage[lastWord] &= mask
        }
    }
}

// MARK: - Tag: Ones (set bit indices)

extension Array<Bit>.Vector {
    /// Tag type for `ones.forEach { }` - iterating set bit indices.
    public enum Ones: Sendable {}
}

// MARK: - Property: ones.forEach

extension Array<Bit>.Vector {
    /// Property view for iterating set (true) bit indices.
    ///
    /// Access `ones.forEach { }` for efficient iteration over set bit indices.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var bits = Array<Bit>.Vector([false, true, false, true])
    /// bits.ones.forEach { index in
    ///     print(index)  // prints 1, 3
    /// }
    /// ```
    @inlinable
    public var ones: Property<Ones, Self>.View {
        mutating _read {
            yield unsafe Property<Ones, Self>.View(&self)
        }
    }
}

extension Property.View where Tag == Array<Bit>.Vector.Ones, Base == Array<Bit>.Vector {
    /// Iterates over indices of set (true) bits.
    ///
    /// Uses efficient word-level bit manipulation for sparse iteration.
    @inlinable
    public func forEach(_ body: (Bit.Index) -> Void) {
        let storage = unsafe base.pointee._storage
        let count = unsafe base.pointee._count
        let bitsPerWord = UInt.bitWidth

        for (wordIndex, var word) in storage.enumerated() {
            while word != 0 {
                let bitIndex = word.trailingZeroBitCount
                let globalIndex = wordIndex * bitsPerWord + bitIndex
                if globalIndex < count.rawValue {
                    body(Bit.Index(__unchecked: (), position: globalIndex))
                }
                word &= word - 1
            }
        }
    }
}

// MARK: - Additional Properties

extension Array<Bit>.Vector {
    /// Returns the first element, or `nil` if empty.
    @inlinable
    public var first: Bool? {
        guard _count > .zero else { return nil }
        return (_storage[0] & 1) != 0
    }

    /// Returns the last element, or `nil` if empty.
    @inlinable
    public var last: Bool? {
        guard let lastCount = _count - .one else { return nil }
        let loc = Bit.Index.Location(count: lastCount, bitsPerWord: Self._bitsPerWord)
        return (_storage[loc.word] & loc.mask) != 0
    }
}

// MARK: - Tag Types

extension Array<Bit>.Vector {
    /// Tag type for `statistic.true`/`statistic.false` property accessors.
    public enum Statistic: Sendable {}

    /// Tag type for `all.true`/`all.false` property accessors.
    public enum All: Sendable {}

    /// Tag type for `toggle.returning(_:)` operation.
    public enum Toggle: Sendable {}

    /// Tag type for `set.returning(_:)` operation.
    public enum Set: Sendable {}

    /// Tag type for `clear.returning(_:)` operation.
    public enum Clear: Sendable {}

    /// Tag type for `byte.set(_:at:order:)` operation.
    public enum Byte: Sendable {}
}

// MARK: - Property: statistic.true / statistic.false

extension Array<Bit>.Vector {
    /// Property accessor for count statistics.
    ///
    /// Access `statistic.true` and `statistic.false` for filtered population counts.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let bits = Array<Bit>.Vector([true, false, true, false, true])
    /// bits.statistic.true   // 3
    /// bits.statistic.false  // 2
    /// ```
    @inlinable
    public var statistic: Property<Statistic, Self> {
        Property(self)
    }
}

extension Property where Tag == Array<Bit>.Vector.Statistic, Base == Array<Bit>.Vector {
    /// The number of `true` values in the array.
    @inlinable
    public var `true`: Bit.Index.Count { base.popcount }

    /// The number of `false` values in the array.
    @inlinable
    public var `false`: Bit.Index.Count? { base._count - base.popcount }
}

// MARK: - Property: all.true / all.false

extension Array<Bit>.Vector {
    /// Property accessor for universality checks.
    ///
    /// Access `all.true` and `all.false` for checking if all elements match.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let bits = Array<Bit>.Vector([true, true, true])
    /// bits.all.true   // true
    /// bits.all.false  // false
    /// ```
    @inlinable
    public var all: Property<All, Self> {
        Property(self)
    }
}

extension Property where Tag == Array<Bit>.Vector.All, Base == Array<Bit>.Vector {
    /// Whether all elements are `true`.
    @inlinable
    public var `true`: Bool {
        guard base._count > .zero else { return true }
        return base.popcount == base._count
    }

    /// Whether all elements are `false`.
    @inlinable
    public var `false`: Bool {
        base.popcount == .zero
    }
}

// MARK: - Append and Remove

extension Array<Bit>.Vector {
    /// Appends a boolean value to the array.
    @inlinable
    public mutating func append(_ value: Bool) {
        let loc = Bit.Index.Location(count: _count, bitsPerWord: Self._bitsPerWord)

        if loc.word >= _storage.count {
            _storage.append(0)
        }

        if value {
            _storage[loc.word] |= loc.mask
        }

        _count = _count + .one
    }

    /// Appends a `Bit` value to the array.
    @inlinable
    public mutating func append(_ bit: Bit) {
        append(bit.boolValue)
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

    /// Removes all elements from the array.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool = false) {
        if keepingCapacity {
            for i in 0..<_storage.count {
                _storage[i] = 0
            }
        } else {
            _storage.removeAll()
        }
        _count = .zero
    }
}

// MARK: - Initializers

extension Array<Bit>.Vector {
    /// Creates a packed bit array from a sequence of booleans.
    @inlinable
    public init<S: Swift.Sequence>(_ elements: S) where S.Element == Bool {
        self.init()
        for element in elements {
            append(element)
        }
    }

    /// Creates a packed bit array from a sequence of `Bit` values.
    @inlinable
    public init<S: Swift.Sequence>(_ elements: S) where S.Element == Bit {
        self.init()
        for element in elements {
            append(element.boolValue)
        }
    }

    /// Creates a packed bit array from an unpacked `[Bit]` array.
    @inlinable
    public init(_ bits: [Bit]) {
        self.init()
        _storage.reserveCapacity((bits.count + Self._bitsPerWord - 1) / Self._bitsPerWord)
        for bit in bits {
            append(bit.boolValue)
        }
    }

    /// Creates a packed bit array with a repeated value.
    @inlinable
    public init(repeating value: Bool, count: Index.Count) {
        let storage = Bit.Index.Storage(count: count, bitsPerWord: Self._bitsPerWord)
        self._storage = ContiguousArray(repeating: value ? ~0 : 0, count: storage.wordCount)
        self._count = count

        if value && count > .zero && storage.unusedBits > 0 {
            let lastWord = storage.wordCount - 1
            let mask: UInt = ~0 >> storage.unusedBits
            _storage[lastWord] = mask
        }
    }

    /// Creates a packed bit array with a repeated `Bit` value.
    @inlinable
    public init(repeating bit: Bit, count: Index.Count) {
        self.init(repeating: bit.boolValue, count: count)
    }
}

// MARK: - Conversion to [Bit]

extension Swift.Array where Element == Bit {
    /// Creates an unpacked `[Bit]` array from a packed bit array.
    @inlinable
    public init(_ packed: Array_Primitives_Core.Array<Bit>.Vector) {
        self.init()
        self.reserveCapacity(packed.count)
        for bit in packed {
            self.append(Bit(bit))
        }
    }
}

// MARK: - Sequence

extension Array<Bit>.Vector: Swift.Sequence {
    /// An iterator over the elements of a packed bit array.
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
        Iterator(storage: _storage, count: _count.rawValue)
    }
}

// MARK: - RandomAccessCollection

extension Array<Bit>.Vector: RandomAccessCollection {
    public typealias Index = Bit.Index
    public typealias Element = Bool

    @inlinable
    public var startIndex: Index { .zero }

    @inlinable
    public var endIndex: Index { Index(_count) }

    @inlinable
    public func index(after i: Index) -> Index {
        (i + 1)!
    }

    @inlinable
    public func index(before i: Index) -> Index {
        (i - 1)!
    }

    @inlinable
    public func distance(
        from start: Index,
        to end: Index
    ) -> Int {
        (end - start).rawValue
    }

    @inlinable
    public func index(
        _ i: Index,
        offsetBy distance: Int
    ) -> Index {
        (i + Index.Offset(distance))!
    }

    @inlinable
    public func index(
        _ i: Index,
        offsetBy distance: Int,
        limitedBy limit: Index
    ) -> Index? {
        let offset = Index.Offset(distance)
        guard let result = i + offset else { return nil }
        if distance >= 0 {
            return result <= limit ? result : nil
        } else {
            return result >= limit ? result : nil
        }
    }
}

// MARK: - Equatable
//
// Manual implementation to work around Swift compiler crash (signal 5) when
// synthesizing Equatable for types nested in `Array<Element: ~Copyable>`
// constrained extensions. The crash occurs during SIL generation for
// `__derived_struct_equals` with "ambiguous use of operator '=='".

extension Array<Bit>.Vector: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs._count == rhs._count else { return false }
        guard lhs._storage.count == rhs._storage.count else { return false }
        for i in 0..<lhs._storage.count {
            if lhs._storage[i] != rhs._storage[i] { return false }
        }
        return true
    }
}

// MARK: - Hashable
//
// Manual implementation to work around the same compiler crash.

extension Array<Bit>.Vector: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_count)
        hasher.combine(_storage)
    }
}

// MARK: - CustomStringConvertible

extension Array<Bit>.Vector: CustomStringConvertible {
    public var description: String {
        let bits = prefix(64).map { $0 ? "1" : "0" }.joined()
        let suffix = _count.rawValue > 64 ? "..." : ""
        return "Array<Bit>.Vector(\(bits)\(suffix))"
    }
}

// MARK: - Bit.Order Access

extension Array<Bit>.Vector {
    /// Accesses the bit at index with specified bit order.
    @inlinable
    public subscript(index: Bit.Index, order: Bit.Order) -> Bool {
        get {
            switch order {
            case .lsb:
                return self[index]
            case .msb:
                let msbPosition = _count.rawValue - 1 - index.position
                guard msbPosition >= 0 else { return false }
                let msbIndex = Bit.Index(__unchecked: (), position: msbPosition)
                return self[msbIndex]
            }
        }
        set {
            switch order {
            case .lsb:
                self[index] = newValue
            case .msb:
                let msbPosition = _count.rawValue - 1 - index.position
                guard msbPosition >= 0 else { return }
                let msbIndex = Bit.Index(__unchecked: (), position: msbPosition)
                self[msbIndex] = newValue
            }
        }
    }
}

// MARK: - Property: byte / byte.set

extension Array<Bit>.Vector {
    /// Extracts a byte at the given byte-aligned position with specified bit order.
    @inlinable
    public func byte(at byteIndex: Index_Primitives.Index<UInt8>, order: Bit.Order) -> UInt8 {
        var result: UInt8 = 0
        for bitOffset in 0..<8 {
            let idx = Bit.Index(byteIndex, bitOffset: bitOffset)
            guard idx < _count else { break }
            if self[idx] {
                switch order {
                case .lsb:
                    result |= 1 << bitOffset
                case .msb:
                    result |= 1 << (7 - bitOffset)
                }
            }
        }
        return result
    }

    /// Property view for byte-level set operations.
    ///
    /// Access `byte.set(_:at:order:)` to write a byte at a position.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var bits = Array<Bit>.Vector(count: 16)
    /// bits.byte.set(0xFF, at: 0, order: .lsb)
    /// ```
    @inlinable
    public var byte: Property<Byte, Self>.View {
        mutating _read {
            yield unsafe Property<Byte, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Byte, Self>.View(&self)
            yield &view
        }
    }
}

extension Property.View where Tag == Array<Bit>.Vector.Byte, Base == Array<Bit>.Vector {
    /// Sets a byte at the given byte-aligned position with specified bit order.
    @inlinable
    public func set(_ byte: UInt8, at byteIndex: Index_Primitives.Index<UInt8>, order: Bit.Order) {
        let count = unsafe base.pointee._count
        for bitOffset in 0..<8 {
            let idx = Bit.Index(byteIndex, bitOffset: bitOffset)
            guard idx < count else { break }
            let bitValue: Bool
            switch order {
            case .lsb:
                bitValue = (byte & (1 << bitOffset)) != 0
            case .msb:
                bitValue = (byte & (1 << (7 - bitOffset))) != 0
            }
            unsafe base.pointee[idx] = bitValue
        }
    }
}

// MARK: - Bit Type Returns

extension Array<Bit>.Vector {
    /// Returns the bit value at the given index as a `Bit`.
    @inlinable
    public func bit(at index: Bit.Index) throws(Array<Bit>.Vector.Error) -> Bit {
        Bit(try get(index))
    }

    /// Returns the bit value at the given index as a `Bit` (unchecked).
    @inlinable
    public func bit(__unchecked index: Bit.Index) -> Bit {
        Bit(self[index])
    }
}

// MARK: - Property: toggle.returning

extension Array<Bit>.Vector {
    /// Property view for toggle operations with return values.
    ///
    /// Access `toggle.returning(_:)` to toggle a bit and receive the new value.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var bits = Array<Bit>.Vector([true, false, true])
    /// let result = try bits.toggle.returning(1)  // Bit.Value(.one, 1)
    /// ```
    @inlinable
    public var toggle: Property<Toggle, Self>.View {
        mutating _read {
            yield unsafe Property<Toggle, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Toggle, Self>.View(&self)
            yield &view
        }
    }
}

extension Property.View where Tag == Array<Bit>.Vector.Toggle, Base == Array<Bit>.Vector {
    /// Toggles the bit at index and returns the new value with its index.
    @inlinable
    public func returning(_ index: Bit.Index) throws(Array<Bit>.Vector.Error) -> Bit.Value<Bit.Index> {
        try unsafe base.pointee.toggle(index)
        let newValue = Bit(try unsafe base.pointee.get(index))
        return Bit.Value(newValue, index)
    }
}

// MARK: - Property: set.returning

extension Array<Bit>.Vector {
    /// Property view for set operations with return values.
    ///
    /// Access `set.returning(_:)` to set a bit and receive the previous value.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var bits = Array<Bit>.Vector([false, false, false])
    /// let result = try bits.set.returning(1)  // Bit.Value(.zero, 1)
    /// ```
    @inlinable
    public var `set`: Property<Set, Self>.View {
        mutating _read {
            yield unsafe Property<Set, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Set, Self>.View(&self)
            yield &view
        }
    }
}

extension Property.View where Tag == Array<Bit>.Vector.Set, Base == Array<Bit>.Vector {
    /// Sets the bit at index and returns the previous value with its index.
    @inlinable
    public func returning(_ index: Bit.Index) throws(Array<Bit>.Vector.Error) -> Bit.Value<Bit.Index> {
        let previous = Bit(try unsafe base.pointee.get(index))
        try unsafe base.pointee.set(index)
        return Bit.Value(previous, index)
    }
}

// MARK: - Property: clear.returning

extension Array<Bit>.Vector {
    /// Property view for clear operations with return values.
    ///
    /// Access `clear.returning(_:)` to clear a bit and receive the previous value.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var bits = Array<Bit>.Vector([true, true, true])
    /// let result = try bits.clear.returning(1)  // Bit.Value(.one, 1)
    /// ```
    @inlinable
    public var clear: Property<Clear, Self>.View {
        mutating _read {
            yield unsafe Property<Clear, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Clear, Self>.View(&self)
            yield &view
        }
    }
}

extension Property.View where Tag == Array<Bit>.Vector.Clear, Base == Array<Bit>.Vector {
    /// Clears the bit at index and returns the previous value with its index.
    @inlinable
    public func returning(_ index: Bit.Index) throws(Array<Bit>.Vector.Error) -> Bit.Value<Bit.Index> {
        let previous = Bit(try unsafe base.pointee.get(index))
        try unsafe base.pointee.clear(index)
        return Bit.Value(previous, index)
    }
}
