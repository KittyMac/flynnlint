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

class CheckRules: Actor, Flowable {
    // input: an AST and one syntax structure
    // output: error string if rule failed
    var safeFlowable = FlowableState()
    private let rules: Ruleset

    init(_ rules: Ruleset) {
        self.rules = rules
    }

    fileprivate func _beFlow(_ args: FlowableArgs) {
        if args.isEmpty == false {
            let ast: AST = args[x:0]
            let syntax: FileSyntax = args[x:1]
            let fileOnly: Bool = args[x:2]
            let target = self.safeNextTarget()

            let blacklist = syntax.blacklist

            if fileOnly {
                for rule in self.rules.all where !blacklist.contains(rule.description.identifier) {
                    rule.check(ast, syntax, target)
                }
            } else {
                if let kind = syntax.structure.kind {
                    if let rules = self.rules.byKind[kind] {
                        for rule in rules where !blacklist.contains(rule.description.identifier) {
                            rule.check(ast, syntax, target)
                        }
                    }
                }
            }
            return
        }

        self.safeFlowToNextTarget(args)
    }
    
}

extension CheckRules {
    func beFlow(_ args: FlowableArgs) {
        unsafeSend { [unowned self] in
            self._beFlow(args)
        }
    }
}
