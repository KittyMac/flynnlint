//
//  main.swift
//  flynnlint
//
//  Created by Rocco Bowling on 5/29/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

// swiftlint:disable line_length

import Foundation
import Flynn
import SourceKittenFramework

struct PrivateFunctionInActorRule: Rule {

    let description = RuleDescription(
        identifier: "actors_private_func",
        name: "Access Level Violation",
        description: "Non-private functions are not allowed in Actors; make this function private or convert it to a behavior.",
        syntaxTriggers: [.class, .extension],
        nonTriggeringExamples: [
            Example("class SomeClass {}\n"),
            Example("class SomeActor: Actor {}\n"),
            Example("class SomeActor: Actor { private func foo() { } }\n"),
            Example("class SomeActor: Actor { init(_ data: OffToTheRacesData) { self.data = data } }\n"),
            Example("class SomeActor: Actor { override func safeFlowProcess() { } }\n"),
            Example("class SomeClass { public func foo() { } }\n")
        ],
        triggeringExamples: [
            Example("class SomeActor: Actor { public ↓func foo() { } }\n"),
            Example("class SomeActor: Actor { fileprivate ↓func foo() { } }\n"),
            Example("class SomeActor: Actor { internal ↓func foo() { } }\n"),
            Example("class SomeActor: Actor { ↓func foo() { } }\n"),
            Example("class SomeActor: Actor { override ↓func flowProcess() { } }\n")
        ]
    )

    func check(_ ast: AST, _ syntax: FileSyntax, _ output: Actor?) -> Bool {
        // Every function defined in a class which is a subclass of Actor must follow these rules:
        // 1. its access control level (ACL) must be set to private
        // 2. if it starts with safe, its ACL may be anything. Other rules will keep anything
        //    but a subclass of this Actor calling safe methods
        // 3. if it is an init function

        if let resolvedClass = ast.getClass(syntax.structure.name) {
            if ast.isActor(resolvedClass) {
                if let functions = syntax.structure.substructure {
                    for function in functions where
                        !(function.name ?? "").hasPrefix(FlynnLint.safePrefix) &&
                        !(function.name ?? "").hasPrefix("init(") &&
                        function.kind == .functionMethodInstance &&
                        function.accessibility != .private {
                            if let output = output {
                                output.flow(error(function.offset, syntax))
                            }
                        return false
                    }
                }
            }
        }

        return true
    }

}
