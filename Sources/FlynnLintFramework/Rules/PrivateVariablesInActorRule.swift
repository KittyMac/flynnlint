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

struct PrivateVariablesInActorRule: Rule {

    let description = RuleDescription(
        identifier: "actors_private_vars",
        name: "Access Level Violation",
        description: "Non-private variables are not allowed in Actors.",
        syntaxTriggers: [.class],
        nonTriggeringExamples: [
            Example("class SomeClass {}\n"),
            Example("class SomeActor: Actor { private var x:Int = 0 }\n"),
            Example("class SomeActor: Actor { private let x:Int = 0 }\n"),
            Example("""
                class WhoseCallWasThisAnyway: Actor {
                    lazy var printFoo = ChainableBehavior(self) { (_: BehaviorArgs) in
                        print("foo")
                    }
                }
            """)
        ],
        triggeringExamples: [
            Example("class SomeActor: Actor { var x:Int = 0 }\n"),
            Example("class SomeActor: Actor { let x:Int = 0 }\n")
        ]
    )

    func check(_ ast: AST, _ syntax: FileSyntax, _ output: Actor?) -> Bool {
        if let resolvedClass = ast.getClass(syntax.1.name) {
            if ast.isActor(resolvedClass) {
                if let variables = syntax.1.substructure {

                    for idx in 0..<variables.count {
                        let variable = variables[idx]
                        if (variable.kind == .varGlobal || variable.kind == .varClass || variable.kind == .varInstance) &&
                            variable.accessibility != .private {

                            // If we're a Behavior or ChainableBehavior, then this is Ok. To know this, we need the sibling
                            // structure of this structure
                            if idx+1 < variables.count {
                                let sibling = variables[idx+1]
                                if (sibling.name == "ChainableBehavior" || sibling.name == "Behavior") &&
                                sibling.kind == .exprCall {
                                    continue
                                }
                            }

                            if let output = output {
                                output.flow(error(variable.offset, syntax))
                            }
                            return false
                        }
                    }
                }
            }
        }
        return true
    }
}