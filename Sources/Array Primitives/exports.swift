// exports.swift
// Umbrella per [MOD-005]. The base-ops plural doubles as the umbrella: it carries
// the base `Array` conformances (this module's files) and re-exports every
// sub-target so a single `import Array_Primitives` surfaces the whole package.

@_exported public import Array_Primitive
@_exported public import Array_Protocol_Primitives
@_exported public import Array_Bounded_Primitives
@_exported public import Array_Fixed_Primitives
@_exported public import Buffer_Linear_Primitives
@_exported public import Cardinal_Primitives
@_exported public import Collection_Primitives
@_exported public import Index_Primitives
@_exported public import Ordinal_Primitives
@_exported public import Standard_Library_Extensions
