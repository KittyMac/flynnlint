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

    override func safeFlowProcess(args: BehaviorArgs) -> (Bool, BehaviorArgs) {
        if args.isEmpty == false {
            let ast: AST = args[x:0]
            let syntax: FileSyntax = args[x:1]
            let target = safeNextTarget()

            let blacklist = syntax.blacklist

            if let kind = syntax.structure.kind {
                if let rules = rules.byKind[kind] {
                    for rule in rules where !blacklist.contains(rule.description.identifier) {
                        rule.check(ast, syntax, target)
                    }
                }
            }
            return (false, [])
        }

        return (true, args)
    }
}
