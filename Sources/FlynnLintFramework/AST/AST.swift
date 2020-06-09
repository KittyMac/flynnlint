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

struct AST {
    struct Behavior {
        let syntax: FileSyntax
        let anyParams: Bool
        let noParams: Bool
        let parameters: [Parameter]
        let argsName: String

        init(_ syntax: FileSyntax, _ parameters: [Parameter], _ argsName: String) {
            self.syntax = syntax
            self.argsName = argsName
            if argsName == "_" || argsName == "None" {
                self.parameters = []
                self.anyParams = false
                self.noParams = true
            } else if parameters.isEmpty == false && parameters[0].type == "Any" {
                self.parameters = []
                self.anyParams = true
                self.noParams = false
            } else {
                self.parameters = parameters
                self.anyParams = false
                self.noParams = false
            }
        }
    }
    struct Parameter {
        let type: String
        let description: String
        init(_ paramString: String) {
            if let range = paramString.range(of: " - ") {
                type = String(paramString.prefix(upTo: range.lowerBound))
                description = String(paramString.suffix(from: range.upperBound))
            } else if paramString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("None") {
                type = "None"
                description = "This behavior accepts no parameters"
            } else if paramString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("Any") {
                type = "Any"
                description = "This behavior accepts any parameters"
            } else {
                type = ""
                description = ""
            }
        }
    }

    let classes: [String: FileSyntax]
    let protocols: [String: FileSyntax]
    var behaviors: [String: [Behavior]]
    let extensions: [FileSyntax]

    init (_ classes: [String: FileSyntax], _ protocols: [String: FileSyntax], _ extensions: [FileSyntax]) {
        self.classes = classes
        self.protocols = protocols
        self.extensions = extensions
        self.behaviors = [:]

        cacheAllBehaviorsByClass()
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

    // swiftlint:disable cyclomatic_complexity
    mutating func cacheAllBehaviorsByClass() {
        // To support behavior argument checking, we allow the dev to annoate the arguments
        // a behavior is supposed to accept ( // flynnlint:parameter String - this is a string
        // To make it easier for rules to access later, we run through all behaviors of all
        // classes here and add then to the SyntaxStructure of the class for easy lookup
        for actor in classes.values {
            guard let name = actor.structure.name else { continue }
            guard let variables = actor.structure.substructure else { continue }

            if behaviors[name] == nil {
               behaviors[name] = []
            }

            for idx in 0..<variables.count {
                let variable = variables[idx]
                if (variable.kind == .varGlobal ||
                    variable.kind == .varClass ||
                    variable.kind == .varInstance) &&
                    variable.accessibility != .private {

                    if idx+1 < variables.count {
                        let sibling = variables[idx+1]
                        if let siblingName = sibling.name {
                            if siblingName.contains("Behavior") && sibling.kind == .exprCall {
                                // Check for the existance of the flynnlint markup
                                let variableSyntax = actor.clone(variable)
                                var params: [Parameter] = []
                                let flynnlintParameterStrings = variableSyntax.markup("parameter")
                                for parameterInfo in flynnlintParameterStrings {
                                    let parameter = Parameter(parameterInfo.1)
                                    if !parameter.type.isEmpty && !parameter.description.isEmpty {
                                        params.append( parameter )
                                    } else {
                                        let err = error(Int64(parameterInfo.0.value),
                                                        actor.file,
                                                        "Malformed Hint: flynnlint:parameter <Type> - <Description>")
                                        print(err)
                                    }
                                }

                                // Extract the name of the "args" closure parameter
                                let argsStructure = findSubstructureOfType(sibling, "BehaviorArgs")
                                let argsName = argsStructure?.name ?? "_"
                                behaviors[name]?.append(Behavior(variableSyntax,
                                                                 params,
                                                                 argsName))
                            }
                        }
                    }
                }
            }
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

    func getBehaviors(_ name: String) -> [Behavior] {
        var retBehaviors: [Behavior] = []
        for key in behaviors.keys {
            if let classBehaviors = behaviors[key] {
                for behavior in classBehaviors where behavior.syntax.structure.name == name {
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
}
