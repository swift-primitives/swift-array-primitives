// exports.swift
// Umbrella per [MOD-005]: re-exports the PACKAGE'S OWN sub-targets so a single
// `import Array_Primitives` surfaces the whole package. Per the exports-narrowing
// ruling (audit #9, 2026-06-10), no EXTERNAL modules are re-exported — consumers
// import the column-vocabulary modules (Buffer/Storage/Memory/Shared/Index) explicitly.

@_exported public import Array_Primitive
@_exported public import Array_Protocol_Primitives
