//
//  main.swift
//  flynnlint
//
//  Created by Rocco Bowling on 5/29/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

// swiftlint:disable line_length
// swiftlint:disable cyclomatic_complexity
// swiftlint:disable function_body_length

import Foundation
import Flynn
import SourceKittenFramework

private struct BehaviorCallCheckConst {
    static let stringBuilder = """
        class StringBuilder: Actor {
            private var string: String = ""
            lazy var \(FlynnLint.prefixBehavior)Append = ChainableBehavior(self) { (args: BehaviorArgs) in
                // flynnlint:parameter String - the string to be appended
                let value: String = args[x: 0]
                self.string.append(value)
            }
            lazy var \(FlynnLint.prefixBehavior)Space = ChainableBehavior(self) { (_: BehaviorArgs) in
                // flynnlint:parameter None
                self.string.append(" ")
            }
            lazy var \(FlynnLint.prefixBehavior)Space = ChainableBehavior(self) { (_: BehaviorArgs) in
                self.string.append(" ")
            }
            lazy var \(FlynnLint.prefixBehavior)Result = ChainableBehavior(self) { (args: BehaviorArgs) in
                // flynnlint:parameter String - closure to call when the string is completed
                let callback: ((String) -> Void) = args[x:0]
                callback(self.string)
            }
        }
    """
}

struct BehaviorCallCheck: Rule {

    let behaviorCallString = ".\(FlynnLint.prefixBehavior)"

    let description = RuleDescription(
        identifier: "actors_safe_func",
        name: "Parameter Violation",
        description: "The parameters for this behavior call do not match the expected parameters documentation.",
        syntaxTriggers: [ ],
        nonTriggeringExamples: [
            Example("""
                class HelloWorld: Actor {
                    private func _beSomething(_ args: BehaviorArgs) {
                        // flynnlint:parameter String - string to print
                        print(args[x:0])
                    }
                    lazy var beSomething = Behavior(self, _beSomething)
                }
                class Foo {
                    init() {
                        let a = HelloWorld()
                        a.beSomething("Hello")
                    }
                }
            """),
            Example("""
                \(BehaviorCallCheckConst.stringBuilder)
                class Foo {
                    init() {
                        let a = StringBuilder()
                        a.beAppend("Hello")
                        a.beAppend("World")
                        a.beSpace()
                        a.beResult { (value: String) in
                            print(value)
                        }
                    }
                }
            """),
            Example("""
                \(BehaviorCallCheckConst.stringBuilder)
                class Foo: Actor {
                    init() {
                        beCount("Hello")
                    }
                    lazy var beCount = Behavior(self) { (args: BehaviorArgs) in
                        // flynnlint:parameter Int - amount
                        self.count()
                    }
                }
            """)
        ],
        triggeringExamples: [
            Example("""
                \(BehaviorCallCheckConst.stringBuilder)
                class Foo {
                    init() {
                        let a = StringBuilder()
                        a.beAppend("Hello", "World")
                    }
                }
            """),
            Example("""
                \(BehaviorCallCheckConst.stringBuilder)
                class Foo {
                    init() {
                        let a = StringBuilder()
                        a.beAppend()
                    }
                }
            """)
        ]
    )

    func precheck(_ file: File) -> Bool {
        return file.contents.contains(".be")
    }

    func check(_ ast: AST, _ syntax: FileSyntax, _ output: Flowable?) -> Bool {
        var noErrors = true

        syntax.matches(#"[\.\s]("# + FlynnLint.prefixBehavior + #"[A-Z][^\s\.\(]*)\s*\(\s*([^)]*?)\s*\)"#) { (match, groups) in
            var behaviorName = groups[1]
            let argumentString = groups[2]

            behaviorName = behaviorName.deletingSuffix(".dynamicallyCall")

            let behaviors = ast.getBehaviors(behaviorName)

            // 1. Check that the number of arguments in the behavior call matches the
            // number of arguments documented in the behavior documentation
            if behaviors.count == 0 {
                if let output = output {
                    let msg = description.console("Unable to find behavior declaration for \(behaviorName)")
                    output.beFlow(warning(Int64(match.range.location), syntax, msg))
                }
            } else if behaviors.count > 1 && !checkBehaviorsAreTheSame(behaviors) {
                if let output = output {
                    let msg = description.console("Ambiguous behavior \(behaviorName), unable to check arguments")
                    output.beFlow(warning(Int64(match.range.location), syntax, msg))
                }
            } else if let behavior = behaviors.first {
                if !behavior.anyParams {

                    // If there is a ( in the name, its because our regex can't handle nested
                    // parenthesis. We need to try a different mechanism to handle this case.
                    if behaviorName.contains("(") || argumentString.contains("(") {
                        if let output = output {
                            let msg = description.console("Unable to check arguments when there are nested parenthesis")
                            output.beFlow(warning(Int64(match.range.location), syntax, msg))
                        }
                        return
                    }

                    var arguments: [String] = []
                    argumentString.matches(#"(".*?"|[^",\s]+)(?=\s*,|\s*$)"#, { (_, argGroups) in
                        arguments.append(argGroups[1])
                    })

                    if arguments.count < behavior.parameters.count {
                        if let output = output {
                            let msg = description.console("Not enough arguments for behavior (expected \(arguments.count) arguments)")
                            output.beFlow(error(Int64(match.range.location), syntax, msg))
                            noErrors = false
                        }
                    } else if arguments.count > behavior.parameters.count {
                        if let output = output {
                            let msg = description.console("Too many arguments for behavior (expected \(arguments.count) arguments)")
                            output.beFlow(error(Int64(match.range.location), syntax, msg))
                            noErrors = false
                        }
                    } else {
                        // Do some lite type checking
                        for idx in 0..<behavior.parameters.count {
                            let paramA = ASTSimpleType(infer: behavior.parameters[idx].type)
                            let paramB = ASTSimpleType(infer: arguments[idx])
                            if  paramA.kind != .unknown &&
                                paramB.kind != .unknown &&
                                paramA != paramB {
                                if let output = output {
                                    let msg = description.console("Type mismatch for argument #\(idx+1), expected \(paramA.description) got \(paramB.description)")
                                    output.beFlow(warning(Int64(match.range.location), syntax, msg))
                                }
                            }
                        }
                    }
                }
            }
        }
        return noErrors
    }

    func checkBehaviorsAreTheSame(_ behaviors: [AST.Behavior]) -> Bool {
        guard let first = behaviors.first else { return false }
        for behavior in behaviors where first != behavior {
            return false
        }
        return true
    }

}
