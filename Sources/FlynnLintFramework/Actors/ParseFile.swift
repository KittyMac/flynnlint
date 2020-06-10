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

class ParseFile: Actor, Flowable {
    // input: path to swift file
    // output: SourceKitten File, SourceKitten Structure
    lazy var safeFlowable = FlowableState(self)

    lazy var beFlow = Behavior(self) { (args: BehaviorArgs) in
        // flynnlint:parameter Any
        if args.isEmpty { return self.safeFlowToNextTarget(args) }

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

                self.safeFlowToNextTarget([fileSyntax])
            } catch {
                print("Parsing error: \(error)")
            }
        }
    }
}
