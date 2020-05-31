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

if CommandLine.argc != 2 {
    print("usage: flynnlint <path_to_source_directory>")
    exit(0)
}

let path = CommandLine.arguments[1]

var ast: AST = AST()

let findFiles = FindFiles(["swift"]) |> Array(count: 28) { ParseFile() } |> ASTBuilder()

findFiles.flow(path)
findFiles.flow()

Flynn.shutdown()
