//
//  main.swift
//  flynnlint
//
//  Created by Rocco Bowling on 5/29/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import SourceKittenFramework
import Flynn

class CheckRules: Actor {
    // input: an AST and one syntax structure
    // output: error string if rule failed
    let rules: Ruleset

    init(_ rules: Ruleset) {
        self.rules = rules
    }

    override func protected_flowProcess(args: BehaviorArgs) -> (Bool, BehaviorArgs) {
        if args.isEmpty == false {
            let ast: AST = args[x:0]
            let syntax: FileSyntax = args[x:1]
            let target = protected_nextTarget()

            if let kind = syntax.1.kind {
                if let rules = rules.byKind[kind] {
                    for rule in rules {
                        rule.check(ast, syntax, target)
                    }
                }
            }
        }

        return (false, [])
    }
}
