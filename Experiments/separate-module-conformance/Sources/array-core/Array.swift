// ===----------------------------------------------------------------------===//
// EXPERIMENT: separate-module-conformance - ArrayCore Module
// ===----------------------------------------------------------------------===//
//
// PURPOSE: Test if a separate module can add Sequence conformance to a
//          ~Copyable array type WITHOUT causing constraint poisoning.
//
// HYPOTHESIS: Module boundaries might prevent constraint propagation.
//
// ===----------------------------------------------------------------------===//

/// Array namespace supporting ~Copyable elements.
public enum Array<Element: ~Copyable>: ~Copyable {

    /// A fixed-capacity array supporting ~Copyable elements.
    public struct Bounded: ~Copyable {
        @usableFromInline
        var storage: UnsafeMutablePointer<Element>

        public let count: Int

        /// Creates an array with the given count, initializing each element.
        @inlinable
        public init(count: Int, initializer: (Int) throws -> Element) rethrows {
            if count == 0 {
                unsafe self.storage = UnsafeMutablePointer<Element>(bitPattern: 1)!
                self.count = 0
                return
            }

            let storage = UnsafeMutablePointer<Element>.allocate(capacity: count)
            for i in 0..<count {
                try unsafe (storage + i).initialize(to: initializer(i))
            }
            unsafe self.storage = storage
            self.count = count
        }

        /// Element access via subscript (borrowing).
        @inlinable
        public subscript(position: Int) -> Element {
            _read {
                precondition(position >= 0 && position < count, "Index out of bounds")
                yield unsafe storage[position]
            }
            _modify {
                precondition(position >= 0 && position < count, "Index out of bounds")
                yield &(unsafe storage[position])
            }
        }

        /// Borrowing forEach iteration for all Element types.
        @inlinable
        public func forEach(_ body: (borrowing Element) -> Void) {
            for i in 0..<count {
                body(unsafe storage[i])
            }
        }

        deinit {
            for i in 0..<count {
                unsafe (storage + i).deinitialize(count: 1)
            }
            if count > 0 {
                unsafe storage.deallocate()
            }
        }
    }
}

// MARK: - Sendable

extension Array.Bounded: @unchecked Sendable where Element: Sendable {}
