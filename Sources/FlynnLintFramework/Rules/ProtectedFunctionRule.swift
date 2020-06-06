//
//  main.swift
//  flynnlint
//
//  Created by Rocco Bowling on 5/29/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import Flynn
import SourceKittenFramework

struct ProtectedFunctionRule: Rule {

    let description = RuleDescription(
        identifier: "actors_protected_func",
        name: "Protected Access Violation",
        description: "Protected functions may not be called outside of the Actor.",
        syntaxTriggers: [.exprCall],
        nonTriggeringExamples: [
            Example("class SomeClass {}\n"),
            Example("class SomeActor: Actor {}\n"),
            Example("class SomeActor: Actor { private func foo() { } }\n"),
            Example("class SomeActor: Actor { init(_ data: OffToTheRacesData) { self.data = data } }\n"),
            Example("""
                class SomeActor: Actor {
                    func protected_foo() {
                        print("hello world")
                    }

                    override func protected_flowProcess() {
                        protected_foo()
                        self.protected_foo()
                    }
                }
            """)
        ],
        triggeringExamples: [
            Example("""
                class SomeActor: Actor {
                    func protected_foo() {
                        print("hello world")
                    }

                    override func protected_flowProcess() {
                        protected_foo()
                    }
                }
                let a = SomeActor()
                a.protected_flowProcess()
            """),
            Example("""
                func testCallSiteUncertainty() {
                    // https://github.com/KittyMac/flynn/issues/8

                    let actor = WhoseCallWasThisAnyway()

                    // Since calls to functions and calls to behaviors are visually similar,
                    // and we cannot enforce developers NOT to have non-private functions,
                    // someone reading this would think it would print a bunch of "foo"
                    // followed by a bunch of "bar".  Oh, they'd be so wrong.
                    actor.printFoo()
                    actor.printFoo()
                    actor.printFoo()
                    actor.printFoo()
                    actor.printFoo()
                    actor.printFoo()
                    actor.printFoo()
                    // TODO: flynnlint should flag these as errors
                    actor.protected_printBar()
                    actor.protected_printBar()
                    actor.protected_printBar()
                    actor.protected_printBar()
                    actor.protected_printBar()
                    actor.protected_printBar()
                    actor.protected_printBar()
                    actor.protected_printBar()

                    actor.wait(0)
                }
            """),
            Example("""
                open class Actor {
                    public func protected_nextTarget() -> Actor? {
                        switch numTargets {
                        case 0:
                            return nil
                        case 1:
                            return flowTarget
                        default:
                            poolIdx = (poolIdx + 1) % numTargets
                            return flowTargets[poolIdx]
                        }
                    }
                }

                func testCallSiteUncertainty() {
                    // https://github.com/KittyMac/flynn/issues/8

                    let actor = WhoseCallWasThisAnyway()

                    // Since calls to functions and calls to behaviors are visually similar,
                    // and we cannot enforce developers NOT to have non-private functions,
                    // someone reading this would think it would print a bunch of "foo"
                    // followed by a bunch of "bar".  Oh, they'd be so wrong.
                    actor.printFoo()
                    actor.printFoo()
                    actor.printFoo()
                    actor.printFoo()
                    actor.printFoo()
                    actor.printFoo()
                    actor.printFoo()
                    actor.protected_nextTarget()

                    actor.wait(0)
                }
            """)
        ]
    )

    func check(_ ast: AST, _ syntax: FileSyntax, _ output: Actor?) -> Bool {
        // Only functions of the class may call protected methods on a class
        if let functionCall = syntax.structure.name {
            if  functionCall.range(of: "protected_") != nil &&
                functionCall.hasPrefix("protected_") == false &&
                functionCall.hasPrefix("self.") == false {
                if let output = output {
                    output.flow(error(syntax.structure.offset, syntax))
                }
                return false
            }
        }
        return true
    }

}
