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

struct BehaviorUnownedSelf: Rule {
    let description = RuleDescription(
        identifier: "behavior_name",
        name: "Behavior Unowned Self",
        description: "Behaviors which reference self should use [unowned self] or [weak self]",
        syntaxTriggers: [.class, .extension],
        nonTriggeringExamples: [
            Example("""
                class StringBuilder: Actor {
                    lazy var \(FlynnLint.prefixBehavior)Space = ChainableBehavior(self) { [unowned self] (_: BehaviorArgs) in
                        self.string.append(" ")
                    }
                }
            """),
            Example("""
                class StringBuilder: Actor {
                    lazy var \(FlynnLint.prefixBehavior)Space = ChainableBehavior(self) { (_: BehaviorArgs) in
                        print(" ")
                    }
                }
            """)
        ],
        triggeringExamples: [
            Example("""
                class StringBuilder: Actor {
                    lazy var \(FlynnLint.prefixBehavior)Space = ChainableBehavior(self) { (_: BehaviorArgs) in
                        self.string.append(" ")
                    }
                }
            """)
        ]
    )

    func precheck(_ file: File) -> Bool {
        return file.contents.contains("Behavior")
    }

    func check(_ ast: AST, _ syntax: FileSyntax, _ output: Flowable?) -> Bool {
        var noErrors = true
        guard let resolvedClass = ast.getClassOrProtocol(syntax.structure.name) else { return true }
        guard let name = resolvedClass.structure.name else { return true }
        guard let behaviors = ast.behaviors[name] else { return true }

        // 1. There must be some parameters defined
        for behavior in behaviors {
            if behavior.bodySyntax.match(#"self\."#) != nil {
                // if the body of the behavior has references to self (ie self.) then
                // we should have [unowned self]

                if  behavior.bodySyntax.match(#"\[\s*unowned\s*self\]"#) == nil &&
                    behavior.bodySyntax.match(#"\[\s*weak\s*self\]"#) == nil {
                    if  let output = output,
                        let bodyoffset = behavior.syntax.structure.offset {
                        output.beFlow([warning(bodyoffset, behavior.bodySyntax)])
                        noErrors = false
                    }
                }
            }

        }

        return noErrors
    }

}
