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

## The Pointer Acquisition Problem

**Date**: 2026-01-23

**Context**: Investigating why `Array.Small.makeIterator()` cannot use the `inline` accessor pattern, leading to a deep analysis of Swift's ownership model.

### The Root Discovery

Swift's ownership model conflates two conceptually distinct operations: *obtaining an address* and *having permission to write to that address*. The `&self` syntax creates an `inout` reference, which grants both address and write permission simultaneously. There is no mechanism to request "just the address, read-only."

This conflation appears reasonable until you need a pointer-based accessor in a non-mutating context. The `Sequence.makeIterator()` protocol requirement is non-mutating, but obtaining a pointer to inline storage requires `&self`. The language provides no way to say "I need self's address but promise not to write."

### Rust Contrast

Rust handles this differently: `&self as *const Self` is legal. An immutable reference can be cast to a raw pointer without requiring mutable access. The pointer creation is safe; only pointer *use* is unsafe. Swift's design prevents even *creating* the pointer in immutable contexts.

This isn't a bug—it's a design choice with deep roots in how Swift models ownership. But it creates a fundamental limitation for pointer-based accessor patterns on `~Copyable` types.

### The ~Escapable Misconception

Initial intuition suggested that `~Escapable` might solve the problem: if a type cannot escape its scope, perhaps Swift would allow creating pointers to borrowed values since the pointer cannot outlive the borrow. This intuition was wrong.

`~Escapable` controls the *output*—what can be stored, returned, or captured. It prevents a value from outliving its creation scope. But it provides no mechanism for *input*—how to obtain a pointer in the first place.

Swift has sophisticated mechanisms for controlling where values go (`~Escapable`, `@_lifetime`, `consuming`/`borrowing`), but no mechanism exists for: "How do I obtain a stable address from a borrowed value?"

### Workaround Analysis

Six workarounds were evaluated:

| Workaround | Trade-off |
|------------|-----------|
| Duplicated logic | Violates DRY |
| Static methods | Breaks path-like composition |
| Cached pointers | Pointer invalidates on value type move |
| withUnsafePointer closure | Cannot return pointer |
| Builtin.addressOfBorrow | Not public API |
| Reference wrapper | Defeats inline optimization |

**Selected solution**: Static methods (`Inline.read(at:in:)` accepts `borrowing`).

The cost—API asymmetry between read (static) and write (instance)—is acceptable. The asymmetry reflects a real underlying asymmetry in what Swift permits.

### Implications for Property Primitives

The `Property.View` pattern in swift-property-primitives stores `UnsafeMutablePointer<Base>`. Construction requires `&base`, forcing `mutating _read` accessors. This pattern cannot be used for non-mutating access contexts like protocol conformances. The limitation is inherent to Swift, not to the Property design.

**Applies to**: Any type needing pointer-based access in non-mutating contexts.

**Related documentation**:
- SE-Pitch opportunity: borrowing pointer projection

---

## Value-Generic Parameter Name Shadows Runtime Properties

**Date**: 2026-04-26 (incident 2026-04-24)

**Context**: `Array.Static<let capacity: Int>` declares its value-generic parameter as `capacity`. Inside any extension on `Array.Static`, bare `capacity` resolves to the type-level `Int` generic parameter, NOT to a (hypothetical) runtime instance property of the same name. This means the type cannot expose a public `var capacity: Index.Count` without name collision.

### The Hazard

The 2026-04-24 SE-0527 OutputSpan adoption session attempted to add `Array.Static.freeCapacity`. Initial implementation referenced a runtime `capacity` property; this conflicted with the shadowed generic parameter. The first-cut "fix" was to remove `Array.Static` from the `freeCapacity` extension (`array-primitives@aeda9a6`) — the user caught it post-commit and asked "why was this removed?", which prompted the actual fix.

### The Workaround

`Array.Static.freeCapacity` computes from the type's own generic parameter directly, not through a runtime `capacity` accessor:

```swift
extension Array.Static {
    public var freeCapacity: Index.Count {
        // `capacity` here resolves to the type-level Int generic parameter
        let total = Array.Index.Count(UInt(capacity))
        return total - count
    }
}
```

The `UInt(capacity)` conversion is required because the generic parameter is `Int` but `Index.Count` is `UInt`-backed. The conversion is non-throwing because the type-level `Int` value is bounded by the generic constraint and cannot be negative at this site.

Restored in `array-primitives@929836b` (2026-04-24).

### Ecosystem-Level Note

The shadowing hazard recurs in any value-generic-parameterized type using `capacity` as the parameter name. Affected types include:
- `Array.Static<let capacity: Int>`
- `Buffer.Linear.Inline<let capacity: Int>`

Types using single-letter conventions (`Array.Bounded<let N: Int>`) or scope-disambiguated names (`Array.Small<let inlineCapacity: Int>`) avoid the hazard by construction.

A cross-package research investigation into value-generic parameter naming convention is at `swift-institute/Research/value-generic-parameter-naming-convention.md` (2026-04-26 IN_PROGRESS, Tier 2). The recommendation will likely converge on stdlib-aligned `<let N: Int>` for new types; migration of existing `<let capacity: Int>` types is a breaking change and warrants explicit gate.

**Applies to**: `Array.Static`, `Buffer.Linear.Inline` (`Buffer.Linear.Inline` is in `swift-buffer-primitives`); future Array variants should adopt `<let N: Int>` per the pending convention.

**Related documentation**:
- Reflection: `swift-institute/Research/Reflections/2026-04-24-se-0527-outputspan-adoption-wave.md` (Pattern 2 — origin)
- Cross-package research: `swift-institute/Research/value-generic-parameter-naming-convention.md` (convention selection)

---

## Related

- Array
