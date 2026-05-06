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

public import Array_Primitives_Core

extension Array where Element: ~Copyable {
    /// A result builder for declaratively constructing arrays.
    ///
    /// Supports `~Copyable` elements — the institute's `Array<E>` is the
    /// natural ~Copyable analogue of `Swift.Array<E>` (which currently
    /// requires `E: Copyable`). Move-only types compose declaratively:
    ///
    /// ```swift
    /// struct FileHandle: ~Copyable { ... }
    /// let handles: Array<FileHandle> = Array {
    ///     FileHandle()
    ///     FileHandle()
    /// }
    /// ```
    ///
    /// For `Copyable` elements the same declarative syntax applies:
    ///
    /// ```swift
    /// let array: Array<Int> = Array {
    ///     1
    ///     2
    ///     if condition {
    ///         3
    ///     }
    /// }
    /// ```
    ///
    /// ## `for` Loops Not Supported
    ///
    /// The `buildArray` step of Swift's result-builder transform takes
    /// `[Component]` (i.e., `Swift.Array<Component>`), which currently
    /// requires `Component: Copyable`. Because this builder's intermediate
    /// component is the ~Copyable `Array<Element>`, `buildArray` is
    /// omitted and `for` loops are therefore not supported in the builder
    /// body. Use explicit imperative construction
    /// (`var x = Array<E>(); x.append(...)`) for loop-based building when
    /// the element type is `~Copyable`.
    @resultBuilder
    public enum Builder {

        // MARK: - Expression Building

        @inlinable
        public static func buildExpression(
            _ expression: consuming Element
        ) -> Array<Element> {
            var result = Array<Element>()
            result.append(consume expression)
            return result
        }

        @inlinable
        public static func buildExpression(
            _ expression: consuming Array<Element>
        ) -> Array<Element> {
            consume expression
        }

        @inlinable
        public static func buildExpression(
            _ expression: consuming Element?
        ) -> Array<Element> {
            var result = Array<Element>()
            if let value = consume expression {
                result.append(consume value)
            }
            return result
        }

        // MARK: - Partial Block Building

        @inlinable
        public static func buildPartialBlock(
            first: consuming Array<Element>
        ) -> Array<Element> {
            consume first
        }

        @inlinable
        public static func buildPartialBlock(first: Void) -> Array<Element> {
            Array<Element>()
        }

        @inlinable
        public static func buildPartialBlock(first: Never) -> Array<Element> {}

        @inlinable
        public static func buildPartialBlock(
            accumulated: consuming Array<Element>,
            next: consuming Array<Element>
        ) -> Array<Element> {
            var result = consume accumulated
            var rest = consume next
            rest.drain { element in
                result.append(consume element)
            }
            return result
        }

        // MARK: - Block Building

        @inlinable
        public static func buildBlock() -> Array<Element> {
            Array<Element>()
        }

        // MARK: - Control Flow

        @inlinable
        public static func buildOptional(
            _ component: consuming Array<Element>?
        ) -> Array<Element> {
            if let result = consume component {
                return consume result
            }
            return Array<Element>()
        }

        @inlinable
        public static func buildEither(
            first: consuming Array<Element>
        ) -> Array<Element> {
            consume first
        }

        @inlinable
        public static func buildEither(
            second: consuming Array<Element>
        ) -> Array<Element> {
            consume second
        }

        // buildArray omitted: see DocC above. Swift.Array<Component>
        // requires Component: Copyable, which conflicts with this
        // builder's ~Copyable Component.

        @inlinable
        public static func buildLimitedAvailability(
            _ component: consuming Array<Element>
        ) -> Array<Element> {
            consume component
        }
    }
}

// MARK: - Convenience Init

extension Array where Element: ~Copyable {
    /// Constructs an array from a result-builder closure.
    ///
    /// ```swift
    /// let array: Array<Int> = Array {
    ///     1
    ///     2
    ///     3
    /// }
    /// ```
    @inlinable
    public init(@Array.Builder _ builder: () -> Self) {
        self = builder()
    }
}
