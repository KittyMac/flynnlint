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

public class FlynnLint {

    private var pipeline: Actor = Actor()
    private var numErrors: Int = 0

    public init() {
        let ruleset = Ruleset()
        let poolSize = max(1, (Flynn.cores / Flynn.cpus) - 2 )

        pipeline = FindFiles(["swift"]) |>
            Array(count: poolSize) { ParseFile() } |>
            BuildCombinedAST() |>
            Array(count: poolSize) { CheckRules(ruleset) } |>
            PrintError { (numErrors: Int) in
                self.numErrors += numErrors
            }
    }

    public func process(directory path: String) {
        pipeline.flow(path)
        pipeline.flow()
    }

    @discardableResult
    public func finish() -> Int {
        Flynn.shutdown()
        return numErrors
    }
}
