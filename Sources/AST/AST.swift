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

struct AST {
    let classes: [String: SyntaxStructure]
    let extensions: [String: SyntaxStructure]

    init (_ classes: [String: SyntaxStructure], _ extensions: [String: SyntaxStructure]) {
        self.classes = classes
        self.extensions = extensions
    }
}
