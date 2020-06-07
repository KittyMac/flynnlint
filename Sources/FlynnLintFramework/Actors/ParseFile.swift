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
    // output: SourceKitten File, SourceKitten Structure
    override func safeFlowProcess(args: BehaviorArgs) -> (Bool, BehaviorArgs) {
        if args.isEmpty { return (true, args) }

        let path: String = args[x:0]
        if let file = File(path: path) {
            do {
                let syntax = try StructureAndSyntax(file: file)

                var blacklist: [String] = []
                for rule in Ruleset().all {
                    if !rule.precheck(file) {
                        blacklist.append(rule.description.identifier)
                    }
                }

                let fileSyntax = FileSyntax(file, syntax.structure, syntax.syntax, blacklist)

                return (true, [fileSyntax])
            } catch {
                print("Parsing error: \(error)")
            }
        }

        return (false, [])
    }
}
