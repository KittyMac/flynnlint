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
    let classes: [String: FileSyntax]
    let extensions: [FileSyntax]

    init (_ classes: [String: FileSyntax], _ extensions: [FileSyntax]) {
        self.classes = classes
        self.extensions = extensions
    }

    func getClass(_ name: String?) -> FileSyntax? {
        guard let name = name else { return nil }
        return classes[name]
    }

    func isSubclassOf(_ syntax: FileSyntax, _ className: String) -> Bool {
        if syntax.1.kind == .class {
            if let inheritedTypes = syntax.1.inheritedTypes {
                for ancestor in inheritedTypes {
                    if ancestor.name == className {
                        return true
                    }
                    if let ancestorName = ancestor.name {
                        if let ancestorClass = classes[ancestorName] {
                            if isSubclassOf(ancestorClass, className) {
                                return true
                            }
                        }
                    }
                }
            }
        }
        return false
    }

    func isActor(_ syntax: FileSyntax) -> Bool {
        let actorName = "Actor"
        if let name = syntax.1.name {
            if let actualClass = getClass(name) {
                return isSubclassOf(actualClass, actorName)
            }
        }
        return false
    }
}
