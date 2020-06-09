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

private struct BehaviorCallCheckConst {
    static let stringBuilder = """
        class StringBuilder: Actor {
            private var string: String = ""
            lazy var \(FlynnLint.behaviorPrefix)Append = ChainableBehavior(self) { (args: BehaviorArgs) in
                // flynnlint:parameter String - the string to be appended
                let value: String = args[x: 0]
                self.string.append(value)
            }
            lazy var \(FlynnLint.behaviorPrefix)Space = ChainableBehavior(self) { (_: BehaviorArgs) in
                // flynnlint:parameter None
                self.string.append(" ")
            }
            lazy var \(FlynnLint.behaviorPrefix)Space = ChainableBehavior(self) { (_: BehaviorArgs) in
                self.string.append(" ")
            }
            lazy var \(FlynnLint.behaviorPrefix)Result = ChainableBehavior(self) { (args: BehaviorArgs) in
                // flynnlint:parameter String - closure to call when the string is completed
                let callback: ((String) -> Void) = args[x:0]
                callback(self.string)
            }
        }
    """
}

struct BehaviorCallCheck: Rule {

    let behaviorCallString = ".\(FlynnLint.behaviorPrefix)"

    let description = RuleDescription(
        identifier: "actors_safe_func",
        name: "Parameter Violation",
        description: "The parameters for this behavior call do not match the expected parameters documentation.",
        syntaxTriggers: [.class, .extension, .struct, .extensionStruct, .enum, .extensionEnum, .functionFree],
        nonTriggeringExamples: [
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

    func check(_ ast: AST, _ syntax: FileSyntax, _ output: Actor?) -> Bool {
        var noErrors = true

        syntax.matches(#"\.("# + FlynnLint.behaviorPrefix + #"[^\s]*)\s*\(\s*([^)]*?)\s*\)"#) { (match, groups) in
            let behaviorName = groups[1]
            let argumentString = groups[2]

            var arguments: [String] = []
            argumentString.matches(#"(".*?"|[^",\s]+)(?=\s*,|\s*$)"#, { (_, argGroups) in
                arguments.append(argGroups[1])
            })

            // 1. Check that the number of arguments in the behavior call matches the
            // number of arguments documented in the behavior documentation
            let behaviors = ast.getBehaviors(behaviorName)
            if behaviors.count == 0 {
                if let output = output {
                    let msg = description.console("Unable to find behavior declaration")
                    output.flow(warning(Int64(match.range.location), syntax, msg))
                }
            } else if behaviors.count > 1 {
                if let output = output {
                    let msg = description.console("More than one behavior declaration found for \(behaviorName)")
                    output.flow(warning(Int64(match.range.location), syntax, msg))
                }
            } else if let behavior = behaviors.first {
                if !behavior.anyParams {
                    if behavior.parameters.count != arguments.count {
                        if let output = output {
                            let msg = description.console("Missing arguments for call (\(arguments.count) of \(behaviors.count))")
                            output.flow(error(Int64(match.range.location), syntax, msg))
                            noErrors = false
                        }
                    }
                }
                
                // TODO: do simple type comparisons (String != String, Number != Number, etc...)
            }
        }
        return noErrors
    }

}
