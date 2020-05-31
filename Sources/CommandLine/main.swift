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

if CommandLine.argc != 2 {
    print("usage: flynnlint <path_to_source_directory>")
    exit(0)
}

let path = CommandLine.arguments[1]

FlynnLintFramework.Process(path)
