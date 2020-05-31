//
//  main.swift
//  flynnlint
//
//  Created by Rocco Bowling on 5/29/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import SourceKittenFramework
import Flynn

struct SyntaxStructure: Codable {
    let accessibility: AccessControlLevel?
    let attribute: String?
    let attributes: [SyntaxStructure]?
    let bodylength: Int?
    let bodyoffset: Int?
    let diagnosticstage: String?
    let elements: [SyntaxStructure]?
    let inheritedTypes: [SyntaxStructure]?
    let kind: SwiftDeclarationKind?
    let length: Int?
    let name: String?
    let namelength: Int?
    let nameoffset: Int?
    let offset: Int?
    let runtimename: String?
    let substructure: [SyntaxStructure]?
    let typename: String?

    enum CodingKeys: String, CodingKey {
        case accessibility = "key.accessibility"
        case attribute = "key.attribute"
        case attributes = "key.attributes"
        case bodylength = "key.bodylength"
        case bodyoffset = "key.bodyoffset"
        case diagnosticstage = "key.diagnostic_stage"
        case elements = "key.elements"
        case inheritedTypes = "key.inheritedtypes"
        case kind = "key.kind"
        case length = "key.length"
        case name = "key.name"
        case namelength = "key.namelength"
        case nameoffset = "key.nameoffset"
        case offset = "key.offset"
        case runtimename = "key.runtime_name"
        case substructure = "key.substructure"
        case typename = "key.typename"
    }
}

// MARK: - Default to the last item in enum if codable fails

protocol CaseIterableDefaultsLast: Decodable & CaseIterable & RawRepresentable
where RawValue: Decodable, AllCases: BidirectionalCollection { }

extension CaseIterableDefaultsLast {
    public init(from decoder: Decoder) throws {
        self = try Self(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? Self.allCases.last!
    }
}

// MARK: - Swift Stuff

public enum SwiftDeclarationKind: String, Codable, CaseIterableDefaultsLast {
    /// `associatedtype`.
    case `associatedtype` = "source.lang.swift.decl.associatedtype"
    /// `class`.
    case `class` = "source.lang.swift.decl.class"
    /// `enum`.
    case `enum` = "source.lang.swift.decl.enum"
    /// `enumcase`.
    case enumcase = "source.lang.swift.decl.enumcase"
    /// `enumelement`.
    case enumelement = "source.lang.swift.decl.enumelement"
    /// `extension`.
    case `extension` = "source.lang.swift.decl.extension"
    /// `extension.class`.
    case extensionClass = "source.lang.swift.decl.extension.class"
    /// `extension.enum`.
    case extensionEnum = "source.lang.swift.decl.extension.enum"
    /// `extension.protocol`.
    case extensionProtocol = "source.lang.swift.decl.extension.protocol"
    /// `extension.struct`.
    case extensionStruct = "source.lang.swift.decl.extension.struct"
    /// `function.accessor.address`.
    case functionAccessorAddress = "source.lang.swift.decl.function.accessor.address"
    /// `function.accessor.didset`.
    case functionAccessorDidset = "source.lang.swift.decl.function.accessor.didset"
    /// `function.accessor.getter`.
    case functionAccessorGetter = "source.lang.swift.decl.function.accessor.getter"
    /// `function.accessor.modify`
    //    @available(swift, introduced: 5.0)
    case functionAccessorModify = "source.lang.swift.decl.function.accessor.modify"
    /// `function.accessor.mutableaddress`.
    case functionAccessorMutableaddress = "source.lang.swift.decl.function.accessor.mutableaddress"
    /// `function.accessor.read`
    //    @available(swift, introduced: 5.0)
    case functionAccessorRead = "source.lang.swift.decl.function.accessor.read"
    /// `function.accessor.setter`.
    case functionAccessorSetter = "source.lang.swift.decl.function.accessor.setter"
    /// `function.accessor.willset`.
    case functionAccessorWillset = "source.lang.swift.decl.function.accessor.willset"
    /// `function.constructor`.
    case functionConstructor = "source.lang.swift.decl.function.constructor"
    /// `function.destructor`.
    case functionDestructor = "source.lang.swift.decl.function.destructor"
    /// `function.free`.
    case functionFree = "source.lang.swift.decl.function.free"
    /// `function.method.class`.
    case functionMethodClass = "source.lang.swift.decl.function.method.class"
    /// `function.method.instance`.
    case functionMethodInstance = "source.lang.swift.decl.function.method.instance"
    /// `function.method.static`.
    case functionMethodStatic = "source.lang.swift.decl.function.method.static"
    /// `function.operator`.
    //    @available(swift, obsoleted: 2.2)
    case functionOperator = "source.lang.swift.decl.function.operator"
    /// `function.operator.infix`.
    case functionOperatorInfix = "source.lang.swift.decl.function.operator.infix"
    /// `function.operator.postfix`.
    case functionOperatorPostfix = "source.lang.swift.decl.function.operator.postfix"
    /// `function.operator.prefix`.
    case functionOperatorPrefix = "source.lang.swift.decl.function.operator.prefix"
    /// `function.subscript`.
    case functionSubscript = "source.lang.swift.decl.function.subscript"
    /// `generic_type_param`.
    case genericTypeParam = "source.lang.swift.decl.generic_type_param"
    /// `module`.
    case module = "source.lang.swift.decl.module"
    /// `opaquetype`.
    case opaqueType = "source.lang.swift.decl.opaquetype"
    /// `precedencegroup`.
    case precedenceGroup = "source.lang.swift.decl.precedencegroup"
    /// `protocol`.
    case `protocol` = "source.lang.swift.decl.protocol"
    /// `struct`.
    case `struct` = "source.lang.swift.decl.struct"
    /// `typealias`.
    case `typealias` = "source.lang.swift.decl.typealias"
    /// `var.class`.
    case varClass = "source.lang.swift.decl.var.class"
    /// `var.global`.
    case varGlobal = "source.lang.swift.decl.var.global"
    /// `var.instance`.
    case varInstance = "source.lang.swift.decl.var.instance"
    /// `var.local`.
    case varLocal = "source.lang.swift.decl.var.local"
    /// `var.parameter`.
    case varParameter = "source.lang.swift.decl.var.parameter"
    /// `var.static`.
    case varStatic = "source.lang.swift.decl.var.static"
    /// Unknown
    case unknown
}

public enum AccessControlLevel: String, Codable, CaseIterableDefaultsLast {
    /// Accessible by the declaration's immediate lexical scope.
    case `private` = "source.lang.swift.accessibility.private"
    /// Accessible by the declaration's same file.
    case `fileprivate` = "source.lang.swift.accessibility.fileprivate"
    /// Accessible by the declaration's same module, or modules importing it with the `@testable` attribute.
    case `internal` = "source.lang.swift.accessibility.internal"
    /// Accessible by the declaration's same program.
    case `public` = "source.lang.swift.accessibility.public"
    /// Accessible and customizable (via subclassing or overrides) by the declaration's same program.
    case `open` = "source.lang.swift.accessibility.open"
    /// Unknown
    case unknown
}
