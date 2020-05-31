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

class ASTBuilder: Actor {
    // input: an AST object to add to the mutable AST
    // output: when all files are done, we generate an immutable AST and send it
    // and all of the individual source entities on
    var classes: [String:SyntaxStructure] = [:]

    override func protected_flowProcess(args: BehaviorArgs) -> (Bool, BehaviorArgs) {
        if args.isEmpty == false {
            let syntax: SyntaxStructure = args[x:1]
            
            if let name = syntax.name {
                if syntax.kind == .class {
                    classes[name] = syntax
                }
            }

            return (false, [])
        }

        // Once we have all of the relevant structures from all of the files captured, we turn that
        // into an immutable struct which will allow us to share that safely with many actors. Then
        // we process eash structure against the rule set

        return (true, [])
    }
}
