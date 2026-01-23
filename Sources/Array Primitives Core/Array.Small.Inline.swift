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

extension Array.Small where Element: ~Copyable {
    /// Accessor for inline storage operations.
    ///
    /// Provides pointer-based access to inline elements. Uses a minimal custom
    /// struct because Swift does not support introducing value generics in
    /// extension where clauses, preventing use of Property.View.Typed pattern.
    @usableFromInline
    @safe
    package struct Inline: ~Copyable, ~Escapable {
        @usableFromInline
        let _base: UnsafeMutablePointer<Array<Element>.Small<inlineCapacity>>

        @usableFromInline
        @_lifetime(borrow base)
        init(_ base: UnsafeMutablePointer<Array<Element>.Small<inlineCapacity>>) {
            unsafe self._base = unsafe base
        }

        /// Returns a mutable pointer to the inline element at the given index.
        @usableFromInline
        @unsafe
        package func pointer(at index: Int) -> UnsafeMutablePointer<Element> {
            let stride = MemoryLayout<Element>.stride
            return unsafe Swift.withUnsafeMutablePointer(to: &_base.pointee._inline) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + index * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr
            }
        }

        /// Returns a read-only pointer to the inline element at the given index.
        @usableFromInline
        @unsafe
        package func read(at index: Int) -> UnsafePointer<Element> {
            let stride = MemoryLayout<Element>.stride
            return unsafe Swift.withUnsafePointer(to: _base.pointee._inline) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + index * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr
            }
        }

        /// Moves all inline elements to target heap storage.
        @usableFromInline
        @unsafe
        @_lifetime(&self)
        package mutating func moveAll(to target: Array<Element>.Storage) {
            let stride = MemoryLayout<Element>.stride
            let count = unsafe _base.pointee._count.rawValue
            _ = unsafe Swift.withUnsafeBytes(of: _base.pointee._inline) { bytes in
                unsafe target.withUnsafeMutablePointerToElements { heapPtr in
                    let inlineBase = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                    for i in 0..<count {
                        let inlineElement = unsafe (inlineBase + i * stride)
                            .assumingMemoryBound(to: Element.self)
                        unsafe (heapPtr + i).initialize(to: inlineElement.move())
                    }
                }
            }
        }

        /// Deinitializes all inline elements.
        @usableFromInline
        @unsafe
        @_lifetime(&self)
        package mutating func deinitializeAll() {
            let stride = MemoryLayout<Element>.stride
            let count = unsafe _base.pointee._count.rawValue
            unsafe Swift.withUnsafeBytes(of: _base.pointee._inline) { bytes in
                let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                for i in 0..<count {
                    let elementPtr = unsafe (basePtr + i * stride)
                        .assumingMemoryBound(to: Element.self)
                    unsafe elementPtr.deinitialize(count: 1)
                }
            }
        }
    }

    /// Access to inline storage operations.
    @usableFromInline
    package var inline: Inline {
        mutating _read {
            yield unsafe Inline(&self)
        }
        mutating _modify {
            var view = unsafe Inline(&self)
            yield &view
        }
    }
}
