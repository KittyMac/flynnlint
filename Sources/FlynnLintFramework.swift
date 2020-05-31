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

public struct Process {
    
    @discardableResult
    public init(_ path: String) {
        let ruleset = Ruleset()

        // TODO: Replace 28 with a Flynn.numCores() or equivalent
        let findFiles = FindFiles(["swift"]) |>
                        Array(count: 28) { ParseFile() } |>
                        ASTBuilder() |>
                        Array(count: 28) { CheckRules(ruleset) }

        findFiles.flow(path)
        findFiles.flow()

        Flynn.shutdown()
    }
}
