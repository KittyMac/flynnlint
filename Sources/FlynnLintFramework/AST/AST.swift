//
//  main.swift
//  flynnlint
//
//  Created by Rocco Bowling on 5/29/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

// swiftlint:disable line_length

import Foundation
import SourceKittenFramework
import Flynn

struct ASTSimpleType: Equatable, CustomStringConvertible {
    static func == (lhs: ASTSimpleType, rhs: ASTSimpleType) -> Bool {
        return  lhs.kind == rhs.kind
    }

    enum Kind {
        case unknown
        case string
        case int
        case float

        public var description: String {
            switch self {
            case .unknown: return "Unknown"
            case .string: return "String"
            case .int: return "Int"
            case .float: return "Float"
            }
        }
    }

    var kind: Kind = .unknown

    public var description: String {
        return kind.description
    }

    init(infer: String) {
        let trimmed = infer.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.contains("\"") {
            kind = .string
        } else if trimmed.contains("'") {
            kind = .string
        } else if CharacterSet(charactersIn: "0123456789").isSuperset(of: CharacterSet(charactersIn: trimmed)) {
            kind = .int
        } else if CharacterSet(charactersIn: "x0123456789").isSuperset(of: CharacterSet(charactersIn: trimmed)) {
            kind = .int
        } else if CharacterSet(charactersIn: "0123456789.").isSuperset(of: CharacterSet(charactersIn: trimmed)) {
            kind = .float
        } else if trimmed == "String" || trimmed == "NSString" || trimmed == "NSMutableString" {
            kind = .string
        } else if trimmed == "Int" || trimmed == "Int8" || trimmed == "Int16" || trimmed == "Int32" || trimmed == "Int64" {
            kind = .int
        } else if trimmed == "UInt" || trimmed == "UInt8" || trimmed == "UInt16" || trimmed == "UInt32" || trimmed == "UInt64" {
            kind = .int
        } else if trimmed == "Float" || trimmed == "Double" {
            kind = .float
        }
    }
}

struct AST {

    struct Behavior {
        let actor: FileSyntax
        let function: FileSyntax
        init(actor: FileSyntax, behavior: FileSyntax) {
            self.actor = actor
            self.function = behavior
        }

        func isSymbioticWith(_ other: Behavior) -> Bool {
            if  let name1 = function.structure.name,
                let name2 = other.function.structure.name {
                return name1 == "_\(name2)" || name2 == "_\(name1)"
            }
            return false
        }
    }

    let classes: [String: FileSyntax]
    let protocols: [String: FileSyntax]
    var internalBehaviors: [String: [Behavior]]
    var externalBehaviors: [String: [Behavior]]
    let extensions: [FileSyntax]

    init (_ classes: [String: FileSyntax], _ protocols: [String: FileSyntax], _ extensions: [FileSyntax]) {
        self.classes = classes
        self.protocols = protocols
        self.extensions = extensions
        self.internalBehaviors = [:]
        self.externalBehaviors = [:]

        for actor in classes.values {
            cacheInternalBehaviorsByClass(actor)
            cacheExternalBehaviorsByClass(actor)
        }
        for actor in extensions {
            cacheInternalBehaviorsByClass(actor)
            cacheExternalBehaviorsByClass(actor)
        }

    }

    func error(_ offset: Int64?, _ file: File, _ message: String) -> String {
        let path = file.path ?? "<nopath>"
        if let offset = offset {
            let stringView = StringView.init(file.contents)
            if let (line, character) = stringView.lineAndCharacter(forByteOffset: ByteCount(offset)) {
                return "\(path):\(line):\(character): error: \(message)"
            }
        }
        return "\(path): error: \(message)"
    }

    func warning(_ offset: Int64?, _ file: File, _ message: String) -> String {
        let path = file.path ?? "<nopath>"
        if let offset = offset {
            let stringView = StringView.init(file.contents)
            if let (line, character) = stringView.lineAndCharacter(forByteOffset: ByteCount(offset)) {
                return "\(path):\(line):\(character): warning: \(message)"
            }
        }
        return "\(path): warning: \(message)"
    }

    private mutating func cacheInternalBehaviorsByClass(_ actor: FileSyntax) {
        // Find all instances of internal behavior functions:
        //  class Test: Actor {
        //    private func _bePrint() { }
        //  }

        guard let name = actor.structure.name else { return }
        guard let functions = actor.structure.substructure else { return }

        if internalBehaviors[name] == nil {
           internalBehaviors[name] = []
        }

        for function in functions where
            (function.name ?? "").hasPrefix(FlynnLint.prefixBehaviorInternal) &&
            function.kind == .functionMethodInstance &&
            function.accessibility == .private {
                internalBehaviors[name]?.append(Behavior(actor: actor,
                                                         behavior: actor.clone(function)))
        }
    }

    private mutating func cacheExternalBehaviorsByClass(_ actor: FileSyntax) {
        // Find all instances of external behavior functions:
        //  extension Test {
        //    func bePrint() { }
        //  }
        guard let name = actor.structure.name else { return }
        guard let functions = actor.structure.substructure else { return }

        if externalBehaviors[name] == nil {
           externalBehaviors[name] = []
        }

        for function in functions where
            (function.name ?? "").hasPrefix(FlynnLint.prefixBehaviorExternal) &&
            function.kind == .functionMethodInstance &&
            (function.accessibility == .public || function.accessibility == .open) {
                externalBehaviors[name]?.append(Behavior(actor: actor,
                                                         behavior: actor.clone(function)))
        }
    }

    func findSubstructureOfType(_ structure: SyntaxStructure, _ type: String) -> SyntaxStructure? {
        if structure.typename == type {
            return structure
        }
        if let substructures = structure.substructure {
            for substructure in substructures {
                if let found = findSubstructureOfType(substructure, type) {
                    return found
                }
            }
        }
        return nil
    }

    func getClassOrProtocol(_ name: String?) -> FileSyntax? {
        guard let name = name else { return nil }
        if let actualClass = classes[name] {
            return actualClass
        }
        return protocols[name]
    }

    func getBehaviorsForActor(_ actor: FileSyntax) -> ([Behavior], [Behavior]) {
        var internals: [Behavior] = []
        var externals: [Behavior] = []

        if let name = actor.structure.name {
            if let behaviors = internalBehaviors[name] {
                internals.append(contentsOf: behaviors)
            }
            if let behaviors = externalBehaviors[name] {
                externals.append(contentsOf: behaviors)
            }
        }

        return (internals, externals)
    }

    func getInternalBehaviors(_ name: String) -> [Behavior] {
        var retBehaviors: [Behavior] = []
        for key in internalBehaviors.keys {
            if let classBehaviors = internalBehaviors[key] {
                for behavior in classBehaviors where behavior.function.structure.name == name {
                    retBehaviors.append(behavior)
                }
            }
        }
        return retBehaviors
    }

    func getExternalBehaviors(_ name: String) -> [Behavior] {
        var retBehaviors: [Behavior] = []
        for key in externalBehaviors.keys {
            if let classBehaviors = externalBehaviors[key] {
                for behavior in classBehaviors where behavior.function.structure.name == name {
                    retBehaviors.append(behavior)
                }
            }
        }
        return retBehaviors
    }

    func getClass(_ name: String?) -> FileSyntax? {
        guard let name = name else { return nil }
        return classes[name]
    }

    func getProtocol(_ name: String?) -> FileSyntax? {
        guard let name = name else { return nil }
        return protocols[name]
    }

    func isSubclassOf(_ syntax: FileSyntax, _ className: String) -> Bool {
        if syntax.structure.kind == .class || syntax.structure.kind == .protocol {
            if let inheritedTypes = syntax.structure.inheritedTypes {
                for ancestor in inheritedTypes {
                    if ancestor.name == className {
                        return true
                    }
                    if let ancestorName = ancestor.name {
                        if let ancestorClass = classes[ancestorName] {
                            if isSubclassOf(ancestorClass, className) {
                                return true
                            }
                        }
                    }
                }
            }
        }
        return false
    }

    func isActor(_ syntax: FileSyntax) -> Bool {
        let actorName = "Actor"
        if let name = syntax.structure.name {
            if name == actorName {
                return true
            }
            if let actualClass = getClassOrProtocol(name) {
                return isSubclassOf(actualClass, actorName)
            }
        }
        return false
    }

    func isRemoteActor(_ syntax: FileSyntax) -> Bool {
        let actorName = "RemoteActor"
        if let name = syntax.structure.name {
            if name == actorName {
                return true
            }
            if let actualClass = getClassOrProtocol(name) {
                return isSubclassOf(actualClass, actorName)
            }
        }
        return false
    }

    private func recurseClassFullName(_ path: inout [String], _ current: SyntaxStructure, _ target: String) -> Bool {

        if let substructures = current.substructure {
            for substructure in substructures {
                if substructure.name == target {
                    if let name = substructure.name {
                        if  substructure.kind == .class ||
                            substructure.kind == .extension ||
                            substructure.kind == .extensionEnum ||
                            substructure.kind == .extensionStruct {
                            path.append(name)
                            return false
                        }
                    }
                }

                if let name = substructure.name {
                    path.append(name)

                    if recurseClassFullName(&path, substructure, target) == false {
                        return false
                    }

                    path.removeLast()
                }
            }
        }
        return true
    }

    func getFullName(_ file: FileSyntax, _ target: FileSyntax) -> String {
        guard let name = target.structure.name else { return "Unknown" }
        return getFullName(file, name)
    }

    func getFullName(_ file: FileSyntax, _ targetName: String) -> String {
        let isArray = targetName.hasPrefix("[")

        var actualTargetName = targetName

        if isArray {
            actualTargetName = targetName.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        }

        var names: [String] = []
        _ = recurseClassFullName(&names, file.structure, actualTargetName)
        if names.count == 0 {
            return targetName
        }

        let fullName = names.joined(separator: ".")

        if isArray {
            return "[\(fullName)]"
        }

        return fullName
    }

    func parseFunctionDefinition(_ function: SyntaxStructure) -> (String, [String]) {
        var parameterLabels: [String] = []
        var name = ""

        if let fullName = function.name {
            let regex = #"(.*)\(([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?\)"#
            fullName.matches(regex) { (_, groups) in
                // ["_beSetCoreAffinity(theAffinity:arg2:)", "_beSetCoreAffinity", "theAffinity:", "arg2:"]

                name = groups[1]
                if name.hasPrefix("_") {
                    name.removeFirst()
                }

                for idx in 2..<groups.count {
                    var label = groups[idx]
                    if label.hasSuffix(":") {
                        label.removeLast()
                    }
                    parameterLabels.append(label)
                }
            }
        }
        return (name, parameterLabels)
    }
}
