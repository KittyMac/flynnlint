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

typealias ASTBuilderResult = ((AST) -> Void)

struct ASTBuilderIterator: IteratorProtocol {
    private var combinedArray: [FileSyntax]
    private var index = -1

    init(_ astBuilder: ASTBuilder) {
        combinedArray = []
        combinedArray.append(contentsOf: Array(astBuilder.classes.values))
        combinedArray.append(contentsOf: astBuilder.extensions)
        combinedArray.append(contentsOf: astBuilder.calls)
    }

    mutating func next() -> FileSyntax? {
        index += 1
        if index >= combinedArray.count {
            return nil
        }
        return combinedArray[index]
    }
}

class ASTBuilder: Sequence {
    var classes: [String: FileSyntax] = [:]
    var extensions: [FileSyntax] = []
    var calls: [FileSyntax] = []

    func add(_ fileSyntax: FileSyntax) {
        let file = fileSyntax.0
        let syntax = fileSyntax.1

        if let name = syntax.name {
            if let kind = syntax.kind {
                switch syntax.kind {
                case .class:
                    classes[name] = fileSyntax
                case .extension:
                    extensions.append(fileSyntax)
                case .exprCall:
                    calls.append(fileSyntax)
                default:
                    //print("ASTBuilder: unhandled kind \(kind)...")
                    break
                }
            }
        }

        if let substructures = syntax.substructure {
            for substructure in substructures {
                add((file, substructure))
            }
        }
    }

    func build() -> AST {
        return AST(classes, extensions)
    }

    func makeIterator() -> ASTBuilderIterator {
        return ASTBuilderIterator(self)
    }

}

class BuildCombinedAST: Actor {
    // input: a File and  a syntax structure
    // output: an immutable AST and pass all syntax
    var astBuilder = ASTBuilder()

    override func protected_flowProcess(args: BehaviorArgs) -> (Bool, BehaviorArgs) {
        if args.isEmpty == false {
            astBuilder.add(FileSyntax(args[x:0], args[x:1]))
            return (false, [])
        }

        // Once we have all of the relevant structures from all of the files captured, we turn that
        // into an immutable struct which will allow us to share that safely with many actors. Then
        // we process eash structure against the rule set.
        let ast = astBuilder.build()

        // Run through every syntax structure and pass it to the rulesets
        for syntax in astBuilder {
            if let target = protected_nextTarget() {
                target.flow(ast, syntax)
            }
        }

        return (true, [])
    }
}
