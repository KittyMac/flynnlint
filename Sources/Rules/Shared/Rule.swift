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

struct Ruleset {
    var byKind: [SwiftDeclarationKind: [Rule]] = [:]

    init() {
        let allRules = [
            PrivateFunctionInActorRule.self
        ]

        for ruleClass in allRules {
            let rule = ruleClass.init()
            for kind in rule.description.syntaxTriggers {
                if self.byKind[kind] == nil {
                    self.byKind[kind] = []
                }
                self.byKind[kind]?.append(rule)
            }
        }
    }
}

protocol Rule {
    var description: RuleDescription { get }
    func check(_ ast: AST, _ syntax: SyntaxStructure)
}
