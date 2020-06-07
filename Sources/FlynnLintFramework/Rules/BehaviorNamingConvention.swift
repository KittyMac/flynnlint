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

struct BehaviorNamingConvention: Rule {
    let description = RuleDescription(
        identifier: "behavior_name",
        name: "Behavior Name Violation",
        description: "Behaviour names must start with 'be', such as 'beHelloWorld()'",
        syntaxTriggers: [.class, .extension],
        nonTriggeringExamples: [
            Example("""
                class StringBuilder: Actor {
                    private var string: String = ""
                    lazy var beAppend = ChainableBehavior(self) { (args: BehaviorArgs) in
                        // flynnlint:parameter String - the string to be appended
                        let value: String = args[x: 0]
                        self.string.append(value)
                    }
                    lazy var beSpace = ChainableBehavior(self) { (_: BehaviorArgs) in
                        // flynnlint:parameter None
                        self.string.append(" ")
                    }
                    lazy var beSpace = ChainableBehavior(self) { (_: BehaviorArgs) in
                        self.string.append(" ")
                    }
                    lazy var beResult = ChainableBehavior(self) { (args: BehaviorArgs) in
                        // flynnlint:parameter String - closure to call when the string is completed
                        let callback: ((String) -> Void) = args[x:0]
                        callback(self.string)
                    }
                }
            """)
        ],
        triggeringExamples: [
            Example("""
                class StringBuilder: Actor {
                    private var string: String = ""
                    lazy var append = ChainableBehavior(self) { (args: BehaviorArgs) in
                        // flynnlint:parameter String this is an improperly formatted parameter (missing - )
                        let value: String = args[x: 0]
                        self.string.append(value)
                    }
                    lazy var space = ChainableBehavior(self) { (_: BehaviorArgs) in
                        self.string.append(" ")
                    }
                    lazy var result = ChainableBehavior(self) { (args: BehaviorArgs) in
                        let callback: ((String) -> Void) = args[x:0]
                        callback(self.string)
                    }
                }
            """),
            Example("""
                class StringBuilder: Actor {
                    private var string: String = ""
                    lazy var append = ChainableBehavior(self) { (args: BehaviorArgs) in
                        // flynnlint:parameter String - the string to be appended
                        let value1: String = args[x: 0]
                        let value2: String = args[x: 1]
                        self.string.append(value)
                    }
                }
            """)
        ]
    )

    func precheck(_ file: File) -> Bool {
        return file.contents.contains("Behavior")
    }

    func check(_ ast: AST, _ syntax: FileSyntax, _ output: Actor?) -> Bool {
        // Since behaviors look just like functions at the call site, we enforce
        // behaviors to adhere to the "be" naming convention.  So, "actor.beFoo()"
        // instead of "actor.foo()"
        var noErrors = true
        guard let resolvedClass = ast.getClass(syntax.structure.name) else { return true }
        guard let name = resolvedClass.structure.name else { return true }
        guard let behaviors = ast.behaviors[name] else { return true }

        if !ast.isActor(resolvedClass) { return true }

        // 1. There must be some parameters defined
        for behavior in behaviors where behavior.syntax.structure.name?.starts(with: "be") == false {
            if let output = output,
               let bodyoffset = behavior.syntax.structure.offset {
                output.flow(error(bodyoffset, behavior.syntax))
                noErrors = false
            }
        }

        return noErrors
    }

}
