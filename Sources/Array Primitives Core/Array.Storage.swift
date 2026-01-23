//
//  File.swift
//  swift-array-primitives
//
//  Created by Coen ten Thije Boonkkamp on 23/01/2026.
//

public import Index_Primitives
public import Standard_Library_Extensions

extension Array.Storage {
    /// Creates storage with the specified capacity, initialized with elements.
    @usableFromInline
    static func create(
        capacity: Int,
        initializingWith initializer: (Int) -> Element
    ) -> Array.Storage {
        let storage = Array.Storage.create(minimumCapacity: capacity) { _ in 0 }
        let typed = unsafe unsafeDowncast(storage, to: Array.Storage.self)

        _ = unsafe typed.withUnsafeMutablePointerToElements { elements in
            for i in 0..<capacity {
                unsafe (elements + i).initialize(to: initializer(i))
            }
        }
        typed.header = capacity

        return typed
    }

    /// Creates empty storage (for zero-count arrays).
    @usableFromInline
    static func createEmpty() -> Array.Storage {
        let storage = Array.Storage.create(minimumCapacity: 0) { _ in 0 }
        return unsafe unsafeDowncast(storage, to: Array.Storage.self)
    }
}

extension Array.Storage {
    /// Returns pointer to element storage.
    @usableFromInline
    var _elementsPointer: UnsafeMutablePointer<Element> {
        unsafe withUnsafeMutablePointerToElements { unsafe $0 }
    }

    /// Initializes element at the given index.
    @usableFromInline
    func _initializeElement(at index: Int, to element: consuming Element) {
        let ptr = unsafe withUnsafeMutablePointerToElements { unsafe $0 + index }
        unsafe ptr.initialize(to: element)
    }

    /// Moves element from the given index.
    @usableFromInline
    func _moveElement(at index: Int) -> Element {
        unsafe withUnsafeMutablePointerToElements { elements in
            unsafe (elements + index).move()
        }
    }

    /// Deinitializes elements in the given range.
    @usableFromInline
    func _deinitializeElements(in range: Range<Int>) {
        _ = unsafe withUnsafeMutablePointerToElements { elements in
            for i in range {
                unsafe (elements + i).deinitialize(count: 1)
            }
        }
    }
}

extension Array.Storage where Element: Copyable {
    /// Creates a copy of this storage.
    @usableFromInline
    func copy() -> Array<Element>.Storage {
        let count = header
        guard count > 0 else {
            return Array<Element>.Storage.createEmpty()
        }

        return Array<Element>.Storage.create(capacity: count) { i in
            _readElement(at: i)
        }
    }

    /// Reads element at the given index (Copyable elements only).
    @usableFromInline
    func _readElement(at index: Int) -> Element {
        unsafe withUnsafeMutablePointerToElements { elements in
            unsafe (elements + index).pointee
        }
    }
}
