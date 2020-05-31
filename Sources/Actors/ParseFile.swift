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

class ParseFile: Actor {
    // input: path to swift file
    // output: path to swift file, SourceKitten Structure
    override func protected_flowProcess(args: BehaviorArgs) -> (Bool, BehaviorArgs) {
        if args.isEmpty { return (true, args) }

        let path: String = args[x:0]
        if let file = File(path: path) {
            do {
                let structure = try Structure(file: file)
                let jsonData = structure.description.data(using: .utf8)!
                let syntax = try JSONDecoder().decode(SyntaxStructure.self, from: jsonData)

                if let target = protected_nextTarget() {
                    recurse(path, target, syntax)
                }

                return (false, [])
            } catch {
                print("Parsing error: \(error)")
            }
        }

        return (false, [])
    }

    private func recurse(_ path: String, _ target: Actor, _ syntax: SyntaxStructure) {
        if syntax.name != nil {
            if let kind = syntax.kind {
                switch syntax.kind {
                case .class, .extension:
                    target.flow(path, syntax)
                default:
                    print("ParseFile: unhandled kind \(kind)...")
                }
            }
        }

        if let substructures = syntax.substructure {
            for substructure in substructures {
                recurse(path, target, substructure)
            }
        }
    }
}
