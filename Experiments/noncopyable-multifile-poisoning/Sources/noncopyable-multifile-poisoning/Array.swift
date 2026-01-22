// ===----------------------------------------------------------------------===//
// EXPERIMENT: noncopyable-multifile-poisoning
// ===----------------------------------------------------------------------===//
//
// PURPOSE: Test if conditional conformance in separate file causes
//          constraint poisoning for UnsafeMutablePointer<Element>
//
// This file mirrors Array.swift from swift-array-primitives
// ===----------------------------------------------------------------------===//

// Main type definition with ~Copyable element support
public enum Array<Element: ~Copyable>: ~Copyable {

    // Nested type with UnsafeMutablePointer storage
    public struct Bounded: ~Copyable {
        @usableFromInline
        var storage: UnsafeMutablePointer<Element>  // <-- Does this fail?

        public let count: Int

        public init(storage: UnsafeMutablePointer<Element>, count: Int) {
            self.storage = storage
            self.count = count
        }

        deinit {
            for i in 0..<count {
                (storage + i).deinitialize(count: 1)
            }
            if count > 0 {
                storage.deallocate()
            }
        }
    }

    // Nested type with ManagedBuffer storage
    @available(macOS 26.0, *)
    public struct Unbounded<let N: Int>: ~Copyable {

        @usableFromInline
        final class ElementStorage: ManagedBuffer<Int, Element> {
            @usableFromInline
            static func create(minimumCapacity: Int) -> ElementStorage {
                let storage = ElementStorage.create(minimumCapacity: minimumCapacity) { _ in 0 }
                return unsafeDowncast(storage, to: ElementStorage.self)
            }
        }

        @usableFromInline
        var _storage: ElementStorage

        public init() {
            _storage = ElementStorage.create(minimumCapacity: N)
        }
    }
}
