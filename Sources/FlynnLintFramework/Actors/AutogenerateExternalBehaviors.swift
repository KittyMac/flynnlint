//
//  main.swift
//  flynnlint
//
//  Created by Rocco Bowling on 5/29/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

// swiftlint:disable function_body_length
// swiftlint:disable cyclomatic_complexity
// swiftlint:disable line_length
// swiftlint:disable file_length
// swiftlint:disable type_body_length

import Foundation
import SourceKittenFramework
import Flynn

class AutogenerateExternalBehaviors: Actor, Flowable {
    // input: an AST and one syntax structure
    // output: an AST and one syntax structure
    var safeFlowable = FlowableState()

    // MARK: - REMOTE ACTOR
    private func createRemoteActorExtensionIfRequired(_ syntax: FileSyntax,
                                                      _ ast: AST,
                                                      _ numOfExtensions: inout Int,
                                                      _ newExtensionString: inout String,
                                                      _ actorSyntax: FileSyntax) {
        if  actorSyntax.file == syntax.file &&
            ast.isRemoteActor(actorSyntax) {

            let (internals, _) = ast.getBehaviorsForActor(actorSyntax)

            if internals.count > 0 {
                let fullActorName = ast.getFullName(syntax, actorSyntax)

                var didHaveBehavior = false

                var scratch = ""
                scratch.append("\n")
                scratch.append("extension \(fullActorName) {\n\n")

                // 0. Create all Codable structs for message serializations (only if it has arguments)
                for behavior in internals where behavior.function.file.path == syntax.file.path && behavior.function.structure.name != nil {
                    didHaveBehavior = true

                    let (name, parameterLabels) = ast.parseFunctionDefinition(behavior.function.structure)

                    if parameterLabels.count > 0 {
                        scratch.append("    struct \(name)Message: Codable {\n")
                        if let parameters = behavior.function.structure.substructure {
                            var idx = 0
                            for parameter in parameters where parameter.kind == .varParameter {
                                if  let typename = parameter.typename {
                                    scratch.append("        let arg\(idx): \(typename)\n")
                                }
                                idx += 1
                            }
                        }
                        scratch.append("    }\n")
                    }
                }

                scratch.append("\n")

                // 1. Create all external behaviors (two types, with and without return values)

                for behavior in internals where behavior.function.file.path == syntax.file.path && behavior.function.structure.name != nil {
                    didHaveBehavior = true

                    let (name, parameterLabels) = ast.parseFunctionDefinition(behavior.function.structure)
                    let returnType = behavior.function.structure.typename

                    if parameterLabels.count == 0 {
                        if let returnType = returnType {
                            if returnType != "Data" {
                                scratch.append("\n    #error(\"Internal behavior \(name) must return a value of type Data (not \(returnType))\")\n")
                            }
                            scratch.append("    @discardableResult\n")
                            scratch.append("    public func \(name)(_ sender: Actor, _ callback: @escaping RemoteBehaviorReply) -> Self {\n")
                            scratch.append("        unsafeSendToRemote(\"\(fullActorName)\", \"\(name)\", Data(), sender, callback)\n")
                            scratch.append("        return self\n")
                            scratch.append("    }\n")
                        } else {
                            scratch.append("    @discardableResult\n")
                            scratch.append("    public func \(name)() -> Self {\n")
                            scratch.append("        unsafeSendToRemote(\"\(fullActorName)\", \"\(name)\", Data(), nil, nil)\n")
                            scratch.append("        return self\n")
                            scratch.append("    }\n")
                        }
                    } else {

                        scratch.append("    @discardableResult\n")
                        let functionNameHeader = "    public func \(name)("
                        scratch.append(functionNameHeader)
                        let parameterNameHeader = String(repeating: " ", count: functionNameHeader.count)
                        if let parameters = behavior.function.structure.substructure {
                            var idx = 0
                            for parameter in parameters where parameter.kind == .varParameter {
                                let label = parameterLabels[idx]

                                if let typename = parameter.typename,
                                    let name = parameter.name {
                                    let typename = ast.getFullName(syntax, typename)
                                    if idx != 0 {
                                        scratch.append(parameterNameHeader)
                                    }
                                    if label == name {
                                        scratch.append("\(name): \(typename),\n")
                                    } else {
                                        scratch.append("\(label) \(name): \(typename),\n")
                                    }
                                }
                                idx += 1
                            }
                        }

                        if returnType != nil {
                            scratch.append("\(parameterNameHeader)_ sender: Actor,\n")
                            scratch.append("\(parameterNameHeader)_ callback: @escaping RemoteBehaviorReply,\n")
                        }

                        scratch.removeLast()
                        scratch.removeLast()
                        scratch.append(" ) -> Self {\n")

                        scratch.append("        let msg = \(name)Message(")
                        if let parameters = behavior.function.structure.substructure {
                            var idx = 0
                            for parameter in parameters where parameter.kind == .varParameter {
                                if let name = parameter.name {
                                    scratch.append("arg\(idx): \(name)")
                                }
                                idx += 1
                            }
                        }
                        scratch.append(")\n")

                        scratch.append("        if let data = try? JSONEncoder().encode(msg) {\n")
                        if returnType != nil {
                            scratch.append("            unsafeSendToRemote(\"\(fullActorName)\", \"\(name)\", data, sender, callback)\n")
                        } else {
                            scratch.append("            unsafeSendToRemote(\"\(fullActorName)\", \"\(name)\", data, nil, nil)\n")
                        }
                        scratch.append("        } else {\n")
                        scratch.append("            fatalError()\n")
                        scratch.append("        }\n")
                        scratch.append("        return self\n")
                        scratch.append("    }\n")

                    }
                }

                scratch.append("\n")

                // 2. Create unsafeRegisterAllBehaviors()

                scratch.append("    func unsafeRegisterAllBehaviors() {\n")

                for behavior in internals where behavior.function.file.path == syntax.file.path && behavior.function.structure.name != nil {
                    didHaveBehavior = true

                    let (name, parameterLabels) = ast.parseFunctionDefinition(behavior.function.structure)
                    let returnType = behavior.function.structure.typename

                    if parameterLabels.count > 0 {
                        scratch.append("        safeRegisterRemoteBehavior(\"\(name)\") { [unowned self] (data) in\n")
                        scratch.append("            if let msg = try? JSONDecoder().decode(\(name)Message.self, from: data) {\n")

                        if returnType != nil {
                            scratch.append("                return self._\(name)(")
                        } else {
                            scratch.append("                self._\(name)(")
                        }

                        if let parameters = behavior.function.structure.substructure {
                            var idx = 0
                            for parameter in parameters where parameter.kind == .varParameter {
                                scratch.append("msg.arg\(idx), ")
                                idx += 1
                            }
                        }
                        scratch.removeLast()
                        scratch.removeLast()
                        scratch.append(")\n")

                        scratch.append("            }\n")
                        scratch.append("            return nil\n")
                        scratch.append("        }\n")
                    }
                }

                scratch.append("    }\n")

                scratch.append("}\n")

                if newExtensionString.contains(scratch) == false {
                    newExtensionString.append(scratch)
                }

                if didHaveBehavior {
                    numOfExtensions += 1
                }
            }
        }
    }

    // MARK: - ACTOR
    private func createActorExtensionIfRequired(_ syntax: FileSyntax,
                                                _ ast: AST,
                                                _ numOfExtensions: inout Int,
                                                _ newExtensionString: inout String,
                                                _ actorSyntax: FileSyntax) {
        if  actorSyntax.file == syntax.file &&
            ast.isActor(actorSyntax) {

            let (internals, _) = ast.getBehaviorsForActor(actorSyntax)

            if internals.count > 0 {
                let fullActorName = ast.getFullName(syntax, actorSyntax)

                var didHaveBehavior = false

                var scratch = ""
                scratch.append("\n")
                scratch.append("extension \(fullActorName) {\n\n")
                for behavior in internals where behavior.function.file.path == syntax.file.path && behavior.function.structure.name != nil {
                    didHaveBehavior = true

                    // Note: The information we need comes from two places:
                    // 1. behavior.function.structure.name is formatted like this:
                    //    _beSetCoreAffinity(theAffinity:arg2:)

                    let (name, parameterLabels) = ast.parseFunctionDefinition(behavior.function.structure)

                    // 2. the names and type of the parameters are in the substructures
                    scratch.append("    @discardableResult\n")
                    scratch.append("    public func \(name)(")
                    if parameterLabels.count > 0 {
                        if let parameters = behavior.function.structure.substructure {
                            var idx = 0
                            for parameter in parameters where parameter.kind == .varParameter {
                                let label = parameterLabels[idx]

                                if let typename = parameter.typename,
                                    let name = parameter.name {
                                    let typename = ast.getFullName(syntax, typename)
                                    if label == name {
                                        scratch.append("\(name): \(typename), ")
                                    } else {
                                        scratch.append("\(label) \(name): \(typename), ")
                                    }
                                }
                                idx += 1
                            }
                            scratch.removeLast()
                            scratch.removeLast()
                        }
                    }
                    scratch.append(") -> Self {\n")

                    if parameterLabels.count == 0 {
                        scratch.append("        unsafeSend(_\(name))\n")
                    } else {
                        scratch.append("        unsafeSend { self._\(name)(")

                        if let parameters = behavior.function.structure.substructure {
                            var idx = 0
                            for parameter in parameters where parameter.kind == .varParameter {
                                let label = parameterLabels[idx]
                                if label == "_" {
                                    scratch.append("\(parameter.name!), ")
                                } else {
                                    scratch.append("\(label): \(parameter.name!), ")
                                }
                                idx += 1
                            }
                            scratch.removeLast()
                            scratch.removeLast()
                        }
                        scratch.append(") }\n")
                    }
                    scratch.append("        return self\n")
                    scratch.append("    }\n")
                }

                scratch.append("\n}\n")

                if newExtensionString.contains(scratch) == false {
                    newExtensionString.append(scratch)
                }

                if didHaveBehavior {
                    numOfExtensions += 1
                }
            }
        }
    }

    private func _beFlow(_ args: FlowableArgs) {
        if args.isEmpty == false {
            let ast: AST = args[x:0]
            let syntax: FileSyntax = args[x:1]
            let fileOnly: Bool = args[x:2]

            if fileOnly {

                var numOfExtensions: Int = 0
                var fileString = syntax.file.contents
                let fileMarker = "\n// MARK: - Autogenerated by FlynnLint\n"

                let parts = fileString.components(separatedBy: fileMarker)
                fileString = parts[0]

                let previousExtensionString = parts.count > 1 ? parts[1] : "NOT FOUND"

                var newExtensionString = ""

                newExtensionString.append("// Contents of file after this marker will be overwritten as needed\n")

                // 1. run over all actor definitions in this file

                for (_, actorSyntax) in ast.classes.sorted(by: { $0.0 > $1.0 }) {
                    createActorExtensionIfRequired(syntax,
                                              ast,
                                              &numOfExtensions,
                                              &newExtensionString,
                                              actorSyntax)
                }

                for actorSyntax in ast.extensions {
                    // Note: we don't want to do extensions which were
                    // created previously by FlynnLint... but how?
                    createActorExtensionIfRequired(syntax,
                                              ast,
                                              &numOfExtensions,
                                              &newExtensionString,
                                              actorSyntax)
                }

                for (_, actorSyntax) in ast.classes.sorted(by: { $0.0 > $1.0 }) {
                    createRemoteActorExtensionIfRequired(syntax,
                                                         ast,
                                                         &numOfExtensions,
                                                         &newExtensionString,
                                                         actorSyntax)
                }

                for actorSyntax in ast.extensions {
                    // Note: we don't want to do extensions which were
                    // created previously by FlynnLint... but how?
                    createRemoteActorExtensionIfRequired(syntax,
                                                         ast,
                                                         &numOfExtensions,
                                                         &newExtensionString,
                                                         actorSyntax)
                }

                // Four scenarios we want to make sure we handle:
                // - Actor in file with no previous FlynnLint generation
                // - Actor in file with existing FlynnLint generation, but does not need updated (no changes)
                // - Actor in file with existing FlynnLint generation, but does need updated
                // - Actor in file, but an existing FlynnLint generation.
                if  (numOfExtensions > 0 && previousExtensionString == "NOT FOUND") ||
                    (numOfExtensions > 0 && newExtensionString != previousExtensionString) ||
                    (numOfExtensions == 0 && previousExtensionString != "NOT FOUND") {

                    if numOfExtensions > 0 {
                        fileString.append(fileMarker)
                        fileString.append(newExtensionString)
                    }

                    if let outputFilePath = syntax.file.path {
                        try? fileString.write(toFile: outputFilePath, atomically: true, encoding: .utf8)
                        print("Generating behaviors for \(URL(fileURLWithPath: outputFilePath).lastPathComponent)")
                    }
                }

            }
        }

        self.safeFlowToNextTarget(args)

    }
}

extension AutogenerateExternalBehaviors {
    func beFlow(_ args: FlowableArgs) {
        unsafeSend {
            self._beFlow(args)
        }
    }
}

// MARK: - Autogenerated by FlynnLint
// Contents of file after this marker will be overwritten as needed

extension AutogenerateExternalBehaviors {

    @discardableResult
    public func beFlow(_ args: FlowableArgs) -> Self {
        unsafeSend { self._beFlow(args) }
        return self
    }

}
