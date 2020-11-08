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

private func codableName(_ name: String) -> String {
    let cappedName = name.prefix(1).capitalized + name.dropFirst()
    return "\(cappedName)Codable"
}

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

            if internals.count >= 0 {
                let fullActorName = ast.getFullName(syntax, actorSyntax)

                var scratch = ""
                scratch.append("\n")
                scratch.append("extension \(fullActorName) {\n\n")

                var minParameterCount = 0
                var returnCallbackParameters: [String] = []
                var hasReturnCallback = false

                let checkParametersForRemoteCallback = { (behavior: AST.Behavior) in
                    hasReturnCallback = false
                    minParameterCount = 0
                    returnCallbackParameters = []
                    if let parameters = behavior.function.structure.substructure {
                        for parameter in parameters where parameter.kind == .varParameter {
                            if let typename = parameter.typename {
                                if parameter.name == "returnCallback" {
                                    minParameterCount = 1

                                    let (callbackParameters, _) = ast.parseClosureType(typename)
                                    returnCallbackParameters = callbackParameters
                                    hasReturnCallback = true
                                }
                            }
                        }
                    }
                }

                // 0. Create all Codable structs for message serializations (only if it has arguments)
                for behavior in internals where behavior.function.file.path == syntax.file.path && behavior.function.structure.name != nil {
                    checkParametersForRemoteCallback(behavior)

                    let (name, parameterLabels) = ast.parseFunctionDefinition(behavior.function.structure)
                    var returnType = behavior.function.structure.typename
                    if returnType == "Void" {
                        returnType = nil
                    }
                    if returnType == nil && returnCallbackParameters.count > 0 {
                        returnType = returnCallbackParameters[0]
                    }

                    if let returnType = returnType {
                        scratch.append("    struct \(codableName(name))Response: Codable {\n")

                        // if the returnType is a tuple
                        if returnType.hasPrefix("(") {
                            let (parts, _) = ast.parseTupleType(returnType)
                            var idx = 0
                            for part in parts {
                                scratch.append("        let response\(idx): \(part)\n")
                                idx += 1
                            }
                        } else {
                            scratch.append("        let response: \(returnType)\n")
                        }

                        scratch.append("    }\n")
                    }

                    if parameterLabels.count > minParameterCount {
                        scratch.append("    struct \(codableName(name))Request: Codable {\n")
                        if let parameters = behavior.function.structure.substructure {
                            var idx = 0
                            for parameter in parameters where parameter.kind == .varParameter {
                                if  let typename = parameter.typename {
                                    if parameter.name != "returnCallback" {
                                        scratch.append("        let arg\(idx): \(typename)\n")
                                        idx += 1
                                    }
                                }
                            }
                        }
                        scratch.append("    }\n")
                    }
                }

                if internals.count > 0 { scratch.append("\n") }

                // 1. Create all external behaviors (two types, with and without return values)

                for behavior in internals where behavior.function.file.path == syntax.file.path && behavior.function.structure.name != nil {
                    checkParametersForRemoteCallback(behavior)

                    let (name, parameterLabels) = ast.parseFunctionDefinition(behavior.function.structure)
                    var returnType = behavior.function.structure.typename
                    if returnType == "Void" {
                        returnType = nil
                    }
                    if returnType == nil && returnCallbackParameters.count > 0 {
                        returnType = returnCallbackParameters[0]
                    }

                    if parameterLabels.count == minParameterCount {
                        if let returnType = returnType {
                            scratch.append("    @discardableResult\n")
                            scratch.append("    public func \(name)(_ sender: Actor, _ callback: @escaping (\(returnType)) -> Void) -> Self {\n")
                            scratch.append("        unsafeSendToRemote(\"\(fullActorName)\", \"\(name)\", Data(), sender) {\n")
                            scratch.append("            callback(\n")
                            scratch.append("                // swiftlint:disable:next force_try\n")
                            scratch.append("                (try! JSONDecoder().decode(\(codableName(name))Response.self, from: $0)).response\n")
                            scratch.append("            )\n")
                            scratch.append("        }\n")
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
                            for parameter in parameters where parameter.kind == .varParameter && parameter.name != "returnCallback" {
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

                        if let returnType = returnType {
                            scratch.append("\(parameterNameHeader)_ sender: Actor,\n")
                            scratch.append("\(parameterNameHeader)_ callback: @escaping (\(returnType)) -> Void,\n")
                        }

                        if scratch.hasSuffix(",\n") {
                            scratch.removeLast()
                            scratch.removeLast()
                        }
                        scratch.append(" ) -> Self {\n")

                        scratch.append("        let msg = \(codableName(name))Request(")
                        if let parameters = behavior.function.structure.substructure {
                            var idx = 0
                            for parameter in parameters where parameter.kind == .varParameter {
                                if let name = parameter.name {
                                    if parameter.name != "returnCallback" {
                                        scratch.append("arg\(idx): \(name), ")
                                        idx += 1
                                    }
                                }
                            }
                            if scratch.hasSuffix(", ") {
                                scratch.removeLast()
                                scratch.removeLast()
                            }
                        }
                        scratch.append(")\n")

                        scratch.append("        // swiftlint:disable:next force_try\n")
                        scratch.append("        let data = try! JSONEncoder().encode(msg)\n")
                        if returnType != nil {
                            scratch.append("        unsafeSendToRemote(\"\(fullActorName)\", \"\(name)\", data, sender) {\n")

                            if let returnType = returnType, returnType.hasPrefix("(") {
                                let (parts, _) = ast.parseTupleType(returnType)
                                var idx = 0

                                scratch.append("            // swiftlint:disable:next force_try\n")
                                scratch.append("            let msg = try! JSONDecoder().decode(\(codableName(name))Response.self, from: $0)\n")
                                scratch.append("            callback((\n")
                                for _ in parts {
                                    scratch.append("                msg.response\(idx),\n")
                                    idx += 1
                                }
                                if scratch.hasSuffix(",\n") {
                                    scratch.removeLast(2)
                                    scratch.append("\n")
                                }
                                scratch.append("            ))\n")

                            } else {
                                scratch.append("            callback(\n")
                                scratch.append("                // swiftlint:disable:next force_try\n")
                                scratch.append("                (try! JSONDecoder().decode(\(codableName(name))Response.self, from: $0).response)\n")
                                scratch.append("            )\n")
                            }

                            scratch.append("        }\n")
                        } else {
                            scratch.append("        unsafeSendToRemote(\"\(fullActorName)\", \"\(name)\", data, nil, nil)\n")
                        }
                        scratch.append("        return self\n")
                        scratch.append("    }\n")

                    }
                }

                if internals.count > 0 { scratch.append("\n") }

                // 2. Create unsafeRegisterAllBehaviors()

                scratch.append("    public func unsafeRegisterAllBehaviors() {\n")

                for behavior in internals where behavior.function.file.path == syntax.file.path && behavior.function.structure.name != nil {
                    checkParametersForRemoteCallback(behavior)

                    let (name, parameterLabels) = ast.parseFunctionDefinition(behavior.function.structure)
                    var returnType = behavior.function.structure.typename
                    if returnType == "Void" {
                        returnType = nil
                    }
                    if returnType == nil && returnCallbackParameters.count > 0 {
                        returnType = returnCallbackParameters[0]
                    }

                    if hasReturnCallback {

                        if parameterLabels.count > minParameterCount {
                            scratch.append("        safeRegisterDelayedRemoteBehavior(\"\(name)\") { [unowned self] (data, callback) in\n")
                            scratch.append("            // swiftlint:disable:next force_try\n")
                            scratch.append("            let msg = try! JSONDecoder().decode(\(codableName(name))Request.self, from: data)\n")

                            scratch.append("            self._\(name)(")
                            if let parameters = behavior.function.structure.substructure {
                                var idx = 0
                                for parameter in parameters where parameter.kind == .varParameter && parameter.name != "returnCallback" {
                                    scratch.append("msg.arg\(idx), ")
                                    idx += 1
                                }
                            }

                            if scratch.hasSuffix(", ") {
                                scratch.removeLast()
                                scratch.removeLast()
                            }

                            if returnCallbackParameters.count > 0 {
                                scratch.append(") { (returnValue:\(returnCallbackParameters[0])) in \n")
                            } else {
                                scratch.append(") { \n")
                            }

                            if returnCallbackParameters.count > 0 {
                                scratch.append("                callback(\n")
                                scratch.append("                    // swiftlint:disable:next force_try\n")
                                scratch.append("                    try! JSONEncoder().encode(\n")
                                scratch.append("                        \(codableName(name))Response(response: returnValue))\n")
                                scratch.append("                )\n")
                            } else {
                                scratch.append("                callback(Data())\n")
                            }
                            scratch.append("            }\n")

                            scratch.append("        }\n")
                        } else {
                            scratch.append("        safeRegisterDelayedRemoteBehavior(\"\(name)\") { [unowned self] (data, callback) in\n")

                            if returnCallbackParameters.count > 0 {
                                scratch.append("            self._\(name)() { (returnValue:\(returnCallbackParameters[0])) in \n")
                            } else {
                                scratch.append("            self._\(name)() { \n")
                            }

                            if returnCallbackParameters.count > 0 {
                                scratch.append("                callback(\n")
                                scratch.append("                    // swiftlint:disable:next force_try\n")
                                scratch.append("                    try! JSONEncoder().encode(\n")
                                scratch.append("                        \(codableName(name))Response(response: returnValue))\n")
                                scratch.append("                )\n")
                            } else {
                                scratch.append("                callback(Data())\n")
                            }
                            scratch.append("            }\n")
                            scratch.append("        }\n")
                        }

                    } else {

                        if parameterLabels.count > minParameterCount {
                            scratch.append("        safeRegisterRemoteBehavior(\"\(name)\") { [unowned self] (data) in\n")
                            scratch.append("            // swiftlint:disable:next force_try\n")
                            scratch.append("            let msg = try! JSONDecoder().decode(\(codableName(name))Request.self, from: data)\n")

                            if returnType != nil {
                                scratch.append("            let response = self._\(name)(")
                            } else {
                                scratch.append("            self._\(name)(")
                            }
                            if let parameters = behavior.function.structure.substructure {
                                var idx = 0
                                for parameter in parameters where parameter.kind == .varParameter && parameter.name != "returnCallback" {
                                    scratch.append("msg.arg\(idx), ")
                                    idx += 1
                                }
                            }
                            if scratch.hasSuffix(", ") {
                                scratch.removeLast()
                                scratch.removeLast()
                            }
                            scratch.append(")\n")

                            if returnType != nil {
                                if let returnType = returnType, returnType.hasPrefix("(") {
                                    let (parts, _) = ast.parseTupleType(returnType)
                                    var idx = 0
                                    scratch.append("            let boxedResponse = \(codableName(name))Response(\n")
                                    for _ in parts {
                                        scratch.append("                response\(idx): response.\(idx),\n")
                                        idx += 1
                                    }
                                    if scratch.hasSuffix(",\n") {
                                        scratch.removeLast(2)
                                        scratch.append("\n")
                                    }
                                    scratch.append("            )\n")
                                    scratch.append("            // swiftlint:disable:next force_try\n")
                                    scratch.append("            return try! JSONEncoder().encode(boxedResponse)\n")
                                } else {
                                    scratch.append("            let boxedResponse = \(codableName(name))Response(response: response)\n")
                                    scratch.append("            // swiftlint:disable:next force_try\n")
                                    scratch.append("            return try! JSONEncoder().encode(boxedResponse)\n")
                                }
                            } else {
                                scratch.append("            return nil\n")
                            }

                            scratch.append("        }\n")
                        } else {
                            scratch.append("        safeRegisterRemoteBehavior(\"\(name)\") { [unowned self] (data) in\n")
                            if returnType != nil {
                                scratch.append("            // swiftlint:disable:next force_try\n")
                                scratch.append("            return try! JSONEncoder().encode(\n")
                                scratch.append("                \(codableName(name))Response(response: self._\(name)()))\n")
                            } else {
                                scratch.append("            self._\(name)()\n")
                                scratch.append("            return nil\n")
                            }
                            scratch.append("        }\n")
                        }

                    }
                }
                if internals.count == 0 {
                    scratch.append("\n")
                }

                scratch.append("    }\n")

                scratch.append("}\n")

                if newExtensionString.contains(scratch) == false {
                    newExtensionString.append(scratch)
                }

                numOfExtensions += 1
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

                var minParameterCount = 0
                var returnCallbackParameters: [String] = []
                var hasReturnCallback = false

                let checkParametersForRemoteCallback = { (behavior: AST.Behavior) in
                    hasReturnCallback = false
                    minParameterCount = 0
                    returnCallbackParameters = []
                    if let parameters = behavior.function.structure.substructure {
                        for parameter in parameters where parameter.kind == .varParameter {
                            if let typename = parameter.typename {
                                if parameter.name == "returnCallback" {
                                    minParameterCount = 1

                                    let (callbackParameters, _) = ast.parseClosureType(typename)
                                    returnCallbackParameters = callbackParameters
                                    hasReturnCallback = true
                                }
                            }
                        }
                    }
                }

                for behavior in internals where behavior.function.file.path == syntax.file.path && behavior.function.structure.name != nil {
                    checkParametersForRemoteCallback(behavior)

                    didHaveBehavior = true

                    // Note: The information we need comes from two places:
                    // 1. behavior.function.structure.name is formatted like this:
                    //    _beSetCoreAffinity(theAffinity:arg2:)

                    let (name, parameterLabels) = ast.parseFunctionDefinition(behavior.function.structure)
                    var returnType = behavior.function.structure.typename
                    if returnType == "Void" {
                        returnType = nil
                    }
                    if returnType == nil && hasReturnCallback {
                        returnType = "Void"
                    }

                    // 2. the names and type of the parameters are in the substructures
                    scratch.append("    @discardableResult\n")
                    let functionNameHeader = "    public func \(name)("
                    scratch.append(functionNameHeader)
                    let parameterNameHeader = String(repeating: " ", count: functionNameHeader.count)
                    if parameterLabels.count > minParameterCount {
                        if let parameters = behavior.function.structure.substructure {
                            var idx = 0
                            for parameter in parameters where parameter.kind == .varParameter && parameter.name != "returnCallback" {
                                let label = parameterLabels[idx]

                                if idx != 0 {
                                    scratch.append(parameterNameHeader)
                                }

                                if let typename = parameter.typename,
                                    let name = parameter.name {
                                    let typename = ast.getFullName(syntax, typename)
                                    if label == name {
                                        scratch.append("\(name): \(typename),\n")
                                    } else {
                                        scratch.append("\(label) \(name): \(typename),\n")
                                    }
                                }
                                idx += 1
                            }
                        }
                    }

                    if let returnType = returnType {
                        if parameterLabels.count > minParameterCount {
                            scratch.append(parameterNameHeader)
                        }
                        scratch.append("_ sender: Actor,\n")

                        if hasReturnCallback {
                            scratch.append("\(parameterNameHeader)_ callback: @escaping ((")
                            for type in returnCallbackParameters {
                                scratch.append("\(type), ")
                            }
                            if scratch.hasSuffix(", ") {
                                scratch.removeLast()
                                scratch.removeLast()
                            }
                            scratch.append(") -> Void)")
                        } else {
                            scratch.append("\(parameterNameHeader)_ callback: @escaping ((\(returnType)) -> Void)")
                        }
                    } else {
                        if scratch.hasSuffix(",\n") {
                            scratch.removeLast()
                            scratch.removeLast()
                        }
                    }
                    scratch.append(") -> Self {\n")

                    if returnType != nil {
                        scratch.append("        unsafeSend() {\n")

                        if hasReturnCallback == false {
                            scratch.append("            let result = self._\(name)(")
                        } else {
                            scratch.append("            self._\(name)(")
                        }

                        if let parameters = behavior.function.structure.substructure {
                            var idx = 0
                            for parameter in parameters where parameter.kind == .varParameter && parameter.name != "returnCallback" {
                                let label = parameterLabels[idx]
                                if label == "_" {
                                    scratch.append("\(parameter.name!), ")
                                } else {
                                    scratch.append("\(label): \(parameter.name!), ")
                                }
                                idx += 1
                            }
                            if scratch.hasSuffix(", ") {
                                scratch.removeLast()
                                scratch.removeLast()
                            }
                        }

                        if hasReturnCallback {
                            scratch.append(") { ")
                            for idx in 0..<returnCallbackParameters.count {
                                scratch.append("arg\(idx), ")
                            }
                            if scratch.hasSuffix(", ") {
                                scratch.removeLast()
                                scratch.removeLast()
                                scratch.append(" in \n")
                            } else {
                                scratch.append("\n")
                            }

                            scratch.append("                sender.unsafeSend {\n")
                            scratch.append("                    callback(")
                            for idx in 0..<returnCallbackParameters.count {
                                scratch.append("arg\(idx), ")
                            }
                            if scratch.hasSuffix(", ") {
                                scratch.removeLast()
                                scratch.removeLast()
                            }
                            scratch.append(")\n")

                            scratch.append("                }\n")
                            scratch.append("            }\n")
                        } else {
                            scratch.append(")\n")
                            scratch.append("            sender.unsafeSend { callback(result) }\n")
                        }

                        scratch.append("        }\n")
                        scratch.append("        return self\n")
                        scratch.append("    }\n")
                    } else {
                        if parameterLabels.count == minParameterCount {
                            scratch.append("        unsafeSend(_\(name))\n")
                        } else {
                            scratch.append("        unsafeSend { self._\(name)(")

                            if let parameters = behavior.function.structure.substructure {
                                var idx = 0
                                for parameter in parameters where parameter.kind == .varParameter && parameter.name != "returnCallback" {
                                    let label = parameterLabels[idx]
                                    if label == "_" {
                                        scratch.append("\(parameter.name!), ")
                                    } else {
                                        scratch.append("\(label): \(parameter.name!), ")
                                    }
                                    idx += 1
                                }
                                if scratch.hasSuffix(", ") {
                                    scratch.removeLast()
                                    scratch.removeLast()
                                }
                            }
                            scratch.append(") }\n")
                        }
                        scratch.append("        return self\n")
                        scratch.append("    }\n")
                    }
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
