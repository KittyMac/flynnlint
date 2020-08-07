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

struct BehaviorParamsDefined: Rule {
    let description = RuleDescription(
        identifier: "behavior_params_defined",
        name: "Behavior Parameter Violation",
        description: "// flynnlint:parameter <Type> - <Description>",
        syntaxTriggers: [.class, .extension],
        nonTriggeringExamples: [
            Example("""
                class StringBuilder: Actor {
                    private var string: String = ""
                    lazy var append = ChainableBehavior(self) { (args: BehaviorArgs) in
                        // flynnlint:parameter String - the string to be appended
                        let value: String = args[x: 0]
                        self.string.append(value)
                    }
                    lazy var space = ChainableBehavior(self) { (_: BehaviorArgs) in
                        // flynnlint:parameter None
                        self.string.append(" ")
                    }
                    lazy var space = ChainableBehavior(self) { (_: BehaviorArgs) in
                        self.string.append(" ")
                    }
                    lazy var result = ChainableBehavior(self) { (args: BehaviorArgs) in
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
            """),
            Example("""
                class StringBuilder: Actor {
                    private var string: String = ""
                    lazy var append = ChainableBehavior(self) { (args: BehaviorArgs) in
                        // flynnlint:parameter String - the string to be appended
                        let value: String = args[x: -25]
                        self.string.append(value)
                    }
                }
            """)
            ,
            Example("""
                class StringBuilder: Actor {
                    private var string: String = ""
                    lazy var append = ChainableBehavior(self) { (foo: BehaviorArgs) in
                        // flynnlint:parameter String - the string to be appended
                        let value: String = foo[x: 999]
                        self.string.append(value)
                    }
                }
            """)
        ]
    )

    func precheck(_ file: File) -> Bool {
        return file.contents.contains("Behavior")
    }

    func check(_ ast: AST, _ syntax: FileSyntax, _ output: Flowable?) -> Bool {
        // Behaviors in Flynn utilize the @dynamicallyCallable syntax in swift
        // to wrap function calls with calls to actor behaviors. This is problematic
        // because @dynamicallyCallable is not type checked by Swift. We attempt
        // to make this safer by providing the following:
        // 1. Force documentation of parameters the behavior accepts (ie flynnlint:parameter )
        // 2. Restrict access to only parameters which are properly documented
        // 3. At the callsite for a behavior, ensure the number of params specified match the expected
        var noErrors = true
        guard let resolvedClass = ast.getClassOrProtocol(syntax.structure.name) else { return true }
        guard let name = resolvedClass.structure.name else { return true }
        guard let behaviors = ast.behaviors[name] else { return true }

        // 1. There must be some parameters defined
        for behavior in behaviors where
            behavior.parameters.count == 0 &&
            behavior.anyParams == false &&
            behavior.noParams == false {
            if let output = output,
               let bodyoffset = behavior.syntax.structure.offset {
                let msg = description.console("Behaviors must document their parameters using flynnlint:parameter")
                output.beFlow([error(bodyoffset, behavior.syntax, msg)])
                noErrors = false
            }
        }

        // 2. don't call args[x:0] to an index which does not exist
        for behavior in behaviors where behavior.parameters.count > 0 {
            behavior.syntax.matches(#"("# + behavior.argsName + #")\s*\[\s*x\s*:\s*(-*\d)*\s*]"#) { (match, groups) in
                if let output = output,
                    let paramIdx = Int(groups[2]) {
                    if paramIdx < 0 || paramIdx >= behavior.parameters.count {
                        let msg = description.console("Access to undocumented parameters is not allowed")
                        output.beFlow([error(Int64(match.range.location), behavior.syntax, msg)])
                        noErrors = false
                    }
                }
            }
        }

        return noErrors
    }

}
