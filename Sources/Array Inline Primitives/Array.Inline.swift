public import Array_Primitives_Core
public import Index_Primitives
public import Sequence_Primitives
public import Property_Primitives

// MARK: - Properties

extension Array.Inline where Element: ~Copyable {
    /// The number of elements in the array.
    @inlinable
    public var count: Index_Primitives.Index<Element>.Count { _count }

    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { _count == .zero }

    /// Whether the array is at full capacity.
    @inlinable
    public var isFull: Bool { _count.rawValue >= capacity }
}

// MARK: - Core Operations

extension Array.Inline where Element: ~Copyable {
    /// Appends an element to the array.
    ///
    /// - Parameter element: The element to append (consumed).
    /// - Throws: ``Array/Inline/Error/overflow`` if the array is full.
    @inlinable
    public mutating func append(_ element: consuming Element) throws(Array.Inline.Error) {
        guard _count.rawValue < capacity else {
            throw .overflow
        }
        _storage.initialize(to: element, at: _count.rawValue)
        _count = Index_Primitives.Index<Element>.Count(__unchecked: _count.rawValue + 1)
    }

    /// Removes and returns the last element.
    ///
    /// - Returns: The removed element, or `nil` if the array is empty.
    @inlinable
    public mutating func removeLast() -> Element? {
        guard _count.rawValue > 0 else { return nil }
        let newCount = _count.rawValue - 1
        _count = Index_Primitives.Index<Element>.Count(__unchecked: newCount)
        return _storage.move(at: newCount)
    }
}

// MARK: - Borrowed Element Access (for ~Copyable elements)

extension Array.Inline where Element: ~Copyable {
    /// Accesses the element at the given index via closure (for ~Copyable elements).
    ///
    /// - Parameters:
    ///   - index: The index of the element.
    ///   - body: A closure that receives a borrowed reference to the element.
    /// - Returns: The result of the closure.
    /// - Precondition: The index must be in bounds.
    @inlinable
    public func withElement<R>(at index: Index_Primitives.Index<Element>, _ body: (borrowing Element) -> R) -> R {
        precondition(index < _count, "Index out of bounds")
        return unsafe body(_storage.read(at: index.position.rawValue).pointee)
    }
}

// MARK: - Safe Element Access (Copyable elements only)

extension Array.Inline where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Array<Element>.Index) -> Element? {
        guard index < _count else { return nil }
        return unsafe _storage.read(at: index.position.rawValue).pointee
    }
}

extension Array.Inline where Element: Copyable {
    /// Returns element at index offset from given base index.
    ///
    /// - Parameters:
    ///   - base: The starting index.
    ///   - offset: The signed offset from the base.
    /// - Returns: The element at the computed position, or `nil` if out of bounds.
    @inlinable
    public func element(
        at base: Array<Element>.Index,
        offsetBy offset: Array<Element>.Index.Offset
    ) -> Element? {
        guard let newIndex = base + offset else { return nil }
        guard newIndex < _count else { return nil }
        return unsafe _storage.read(at: newIndex.position.rawValue).pointee
    }
}

// MARK: - Bounded Index (Inline Arrays)

extension Array.Inline where Element: ~Copyable {
    /// Accesses the element at the given bounded index.
    ///
    /// The type `Index<Element>.Bounded<capacity>` proves `0 <= index < capacity`.
    /// **No runtime bounds check is performed.**
    ///
    /// ## Type-Based Safety
    ///
    /// The TYPE encodes the bounds proof:
    /// - `Index<Element>` subscript → has runtime bounds check
    /// - `Index<Element>.Bounded<capacity>` subscript → NO bounds check (type proves it)
    ///
    /// ## Contract
    ///
    /// For full arrays (`count == capacity`), this subscript is completely safe.
    /// For partial arrays (`count < capacity`), caller must ensure `index < count`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var inline = Array<Int>.Inline<8>()
    /// // Fill to capacity...
    /// assert(inline.isFull)
    ///
    /// let idx: Index<Int>.Bounded<8> = 3
    /// print(inline[idx])  // No runtime bounds check - type proves 0 <= 3 < 8
    /// ```
    ///
    /// - Parameter index: A bounded index where the type proves `0 <= index < capacity`.
    @inlinable
    public subscript(_ index: Index_Primitives.Index<Element>.Bounded<capacity>) -> Element {
        _read {
            // Type proves: 0 <= index < capacity
            // For full arrays: count == capacity, so 0 <= index < count ✓
            yield unsafe _storage.read(at: index.rawValue).pointee
        }
        _modify {
            yield &(unsafe _storage.pointer(at: index.rawValue).pointee)
        }
    }
}

// MARK: - Typed Subscript (Array.Inline)

extension Array.Inline where Element: ~Copyable {
    /// Accesses the element at the given typed index (borrowing access for ~Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Array<Element>.Index) -> Element {
        _read {
            precondition(index < _count, "Index out of bounds")
            yield unsafe _storage.read(at: index.position.rawValue).pointee
        }
        _modify {
            precondition(index < _count, "Index out of bounds")
            yield &(unsafe _storage.pointer(at: index.position.rawValue).pointee)
        }
    }
}

extension Array.Inline where Element: Copyable {
    /// Accesses the element at the given typed index (copy semantics for Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Array<Element>.Index) -> Element {
        get {
            precondition(index < _count, "Index out of bounds")
            return unsafe _storage.read(at: index.position.rawValue).pointee
        }
        set {
            precondition(index < _count, "Index out of bounds")
            unsafe _storage.pointer(at: index.position.rawValue).pointee = newValue
        }
    }
}

// MARK: - Error Description

extension Array.Inline.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .overflow:
            return "inline array is full"
        case .indexOutOfBounds(let index, let count):
            return "index \(index) out of bounds for count \(count)"
        }
    }
}

// MARK: - Sequence.Clearable Conformance

/// Clearable conformance for Copyable elements.
///
/// Enables `.forEach.consuming { }` via Property.View extension when using
/// the `forEachView` property.
///
/// ## Element Type Limitation
///
/// This conformance requires `Element: Copyable` because `Sequence.Clearable`
/// extends `Sequence.Protocol`, which requires a `Copyable` iterator element.
///
/// For `~Copyable` elements, use the direct methods instead:
/// - `forEach { }` — borrowing iteration
/// - `drain { }` — consuming iteration (array survives empty)
/// - `removeAll()` — clear the array
extension Array.Inline: Sequence.Clearable where Element: Copyable {}

// MARK: - Sequence.Drain.Protocol Conformance

/// Drain protocol conformance for Copyable elements.
///
/// Enables `.drain { }` via Property.View extension when using the `drainView` property.
///
/// ## Element Type Limitation
///
/// This conformance requires `Element: Copyable` because `Sequence.Drain.Protocol`
/// has an `Element` associated type that implicitly requires `Copyable` per SE-0427.
///
/// For `~Copyable` elements, use the direct `drain(_:)` method instead:
/// ```swift
/// array.drain { element in
///     process(element)  // Takes ownership
/// }
/// ```
extension Array.Inline: Sequence.Drain.`Protocol` where Element: Copyable {
    public typealias Element = Element
}

// MARK: - Property.View: forEachView (Copyable elements)

extension Array.Inline where Element: Copyable {
    /// Property view for iteration operations (Copyable elements).
    ///
    /// Provides iteration patterns via `Property.View`:
    /// - `.forEachView { }` — Borrowing iteration via `callAsFunction`
    /// - `.forEachView.borrowing { }` — Explicit borrowing iteration
    /// - `.forEachView.consuming { }` — Consuming iteration (clears array)
    ///
    /// ## ~Copyable Elements
    ///
    /// For `~Copyable` elements, use the direct methods:
    /// - `forEach { }` — borrowing iteration
    /// - `drain { }` — consuming iteration
    ///
    /// ## Example
    ///
    /// ```swift
    /// var array = Array<Int>.Inline<8>()
    /// try array.append(1)
    /// try array.append(2)
    /// try array.append(3)
    ///
    /// // Borrowing iteration via Property.View
    /// array.forEachView { print($0) }
    ///
    /// // Consuming iteration (array becomes empty)
    /// array.forEachView.consuming { print($0) }
    /// ```
    @inlinable
    public var forEachView: Property<Sequence.ForEach, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.ForEach, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.ForEach, Self>.View(&self)
            yield &view
        }
    }
}

// MARK: - Property.View: drainView (Copyable elements)

extension Array.Inline where Element: Copyable {
    /// Property view for draining operations (Copyable elements).
    ///
    /// Provides `.drainView { }` via `callAsFunction`, which removes all elements
    /// from the array and passes each to the closure with ownership.
    ///
    /// ## ~Copyable Elements
    ///
    /// For `~Copyable` elements, use the direct `drain(_:)` method instead.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var array = Array<Int>.Inline<8>()
    /// try array.append(1)
    /// try array.append(2)
    /// try array.append(3)
    ///
    /// // Drain all elements via Property.View
    /// array.drainView { element in
    ///     process(element)  // Takes ownership
    /// }
    /// // array is now empty but still usable
    /// try array.append(4)
    /// ```
    @inlinable
    public var drainView: Property<Sequence.Drain, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.Drain, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain, Self>.View(&self)
            yield &view
        }
    }
}
