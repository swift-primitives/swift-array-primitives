public import Collection_Primitives
public import Index_Primitives
public import Array_Primitives_Core

// MARK: - Collection.Protocol Conformance
// Note: Index, startIndex, endIndex, index(after:) defined in Collection.Indexed conformance

extension Array.Fixed: Collection.`Protocol` {}

// MARK: - Collection.Access.Random Conformance

extension Array.Fixed: Collection.Access.Random {}

