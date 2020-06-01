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

typealias FileSyntax = (File, SyntaxStructure)

class ASTBuilder: Actor {
    // input: a syntax structure
    // output: an immutable AST and pass all syntax
    var classes: [String: FileSyntax] = [:]
    var extensions: [FileSyntax] = []

    override func protected_flowProcess(args: BehaviorArgs) -> (Bool, BehaviorArgs) {
        if args.isEmpty == false {
            let file: File = args[x:0]
            let syntax: SyntaxStructure = args[x:1]
            let fileSyntax = (file, syntax)

            if let name = syntax.name {
                if let kind = syntax.kind {
                    switch syntax.kind {
                    case .class:
                        classes[name] = fileSyntax
                    case .extension:
                        extensions.append(fileSyntax)
                    default:
                        print("ASTBuilder: unhandled kind \(kind)...")
                    }
                }
            }

            return (false, [])
        }

        // Once we have all of the relevant structures from all of the files captured, we turn that
        // into an immutable struct which will allow us to share that safely with many actors. Then
        // we process eash structure against the rule set.
        let ast = AST(classes,
                      extensions)

        // Run through every syntax structure and pass it to the rulesets
        for syntax in classes.values {
            if let target = protected_nextTarget() {
                target.flow(ast, syntax)
            }
        }
        for syntax in extensions {
            if let target = protected_nextTarget() {
                target.flow(ast, syntax)
            }
        }

        return (true, [])
    }
}
