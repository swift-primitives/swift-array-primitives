# Array Primitives Insights

<!--
---
title: Array Primitives Insights
version: 1.0.0
last_updated: 2026-01-22
applies_to: [swift-array-primitives]
normative: false
---
-->

@Metadata {
    @TitleHeading("Array Primitives")
}

Design decisions, implementation patterns, and lessons learned specific to this package.

## Overview

This document captures insights that emerged during development of swift-array-primitives. These are not API requirements—they are recorded decisions and patterns that inform future work on this package.

**Document type**: Non-normative (recorded decisions, not requirements).

**Consolidation source**: Reflection entries tagged with `[Package: swift-array-primitives]`.

---

## Module Boundary Solution for Constraint Poisoning

**Date**: 2026-01-22

**Context**: The array types (`Array.Bounded`, `Array`, `Array.Inline`, `Array.Small`) needed to support both `~Copyable` elements AND provide `Sequence.Protocol`/`Collection.Protocol` conformances for `Copyable` elements. Initial attempts resulted in "constraint poisoning"—the compiler propagated `Copyable` requirements from conditional conformances back to stored property declarations.

### The Problem

When a type `T<E: ~Copyable>` gains a conditional conformance `where E: Copyable`, the Swift compiler incorrectly applies the `Copyable` requirement to stored properties like `UnsafeMutablePointer<E>`—even though those types explicitly support noncopyable elements per SE-0437.

File organization does not prevent this. The poisoning occurs whether the conformance is in the same file, a separate file, or uses custom protocols instead of `Swift.Sequence`.

### The Solution: Internal Module Split

Module boundaries prevent constraint propagation. The compiler processes each SPM target independently, so conditional conformances in a separate module cannot poison the type definition in Core.

**Architecture**:
```
Sources/
├── Array Primitives Core/     # Types with ~Copyable support
│   └── Array.swift            # UnsafeMutablePointer<Element> storage
├── Array Primitives Sequence/ # Conformances (where Element: Copyable)
│   └── Array.Bounded+*.swift  # Sequence.Protocol, Collection.Protocol
└── Array Primitives/          # Public API (re-exports both)
    └── exports.swift          # @_exported import
```

Users import `Array_Primitives` and receive the unified API. The internal split is invisible.

### Key Implementation Detail: `package` Access Level

The module split creates a visibility challenge: Core's internal members must be accessible to Sequence for implementing `makeIterator()`, but not exposed publicly.

Swift 5.9's `package` access level solves this. Members marked `package` are visible to all targets within the same SPM package but invisible externally:

```swift
// In Array Primitives Core
@usableFromInline
package var storage: UnsafeMutablePointer<Element>
```

**Applies to**: All array type implementations requiring both `~Copyable` support and standard protocol conformances.

**Related documentation**:
- `Memory Copyable.md` Category 6 (Module Boundary Solution)
- `Noncopyable Generics Constraint Propagation.md` (research paper)
- `Noncopyable Generics Investigation Brief.md` (resolved)

---

## Topics

### Related Documents

- <doc:Array>
