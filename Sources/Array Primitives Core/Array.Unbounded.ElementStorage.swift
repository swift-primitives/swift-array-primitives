//
//  File.swift
//  swift-array-primitives
//
//  Created by Coen ten Thije Boonkkamp on 23/01/2026.
//



extension Array.Unbounded.ElementStorage where Element: ~Copyable {
    /// Creates empty storage with the specified minimum capacity.
    @usableFromInline
    static func create(minimumCapacity: Int) -> Array<Element>.Unbounded<N>.ElementStorage {
        let storage = Array<Element>.Unbounded<N>.ElementStorage.create(minimumCapacity: minimumCapacity) { _ in 0 }
        return unsafe unsafeDowncast(storage, to: Array<Element>.Unbounded<N>.ElementStorage.self)
    }
    
    /// Returns pointer to element storage.
    @usableFromInline
    package var _elementsPointer: UnsafeMutablePointer<Element> {
        unsafe withUnsafeMutablePointerToElements { unsafe $0 }
    }

    /// Initializes element at the given index.
    @usableFromInline
    package func _initializeElement(at index: Int, to element: consuming Element) {
        let ptr = unsafe withUnsafeMutablePointerToElements { unsafe $0 + index }
        unsafe ptr.initialize(to: element)
    }

    /// Moves element from the given index.
    @usableFromInline
    package func _moveElement(at index: Int) -> Element {
        unsafe withUnsafeMutablePointerToElements { elements in
            unsafe (elements + index).move()
        }
    }

    /// Moves all elements to new storage.
    @usableFromInline
    package func _moveAllElements(to newStorage: Array<Element>.Unbounded<N>.ElementStorage) {
        let count = header
        guard count > 0 else { return }
        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                for i in 0..<count {
                    unsafe (dst + i).initialize(to: (src + i).move())
                }
            }
        }
    }

    /// Deinitializes all elements.
    @usableFromInline
    package func _deinitializeAllElements() {
        let count = header
        guard count > 0 else { return }
        _ = unsafe withUnsafeMutablePointerToElements { elements in
            for i in 0..<count {
                unsafe (elements + i).deinitialize(count: 1)
            }
        }
        header = 0
    }
}

extension Array.Unbounded.ElementStorage where Element: Copyable {
    /// Reads element at the given index (Copyable elements only).
    @usableFromInline
    package func _readElement(at index: Int) -> Element {
        unsafe withUnsafeMutablePointerToElements { elements in
            unsafe (elements + index).pointee
        }
    }
}
