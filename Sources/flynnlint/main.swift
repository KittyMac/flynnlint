//
//  main.swift
//  flynnlint
//
//  Created by Rocco Bowling on 5/29/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import FlynnLintFramework
import Flynn

if CommandLine.argc < 2 {
    print("usage: flynnlint <paths_to_directories>")
    exit(0)
}

let flynnlint = FlynnLint()
for iii in 1..<CommandLine.argc {
    flynnlint.process(directory: CommandLine.arguments[Int(iii)])
}

exit(Int32(flynnlint.finish()))
