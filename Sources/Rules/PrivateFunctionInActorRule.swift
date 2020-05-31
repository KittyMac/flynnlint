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

struct PrivateFunctionInActorRule: Rule {

    let description = RuleDescription(
        identifier: "actors_private_func",
        name: "Private Functions In Actors",
        description: "Only private functions are allowed in Actors",
        syntaxTriggers: [.class, .extension],
        nonTriggeringExamples: [
            Example("class SomeClass {}\n"),
            Example("class SomeActor: Actor {}\n"),
            Example("class SomeActor: Actor { private func foo() { } }\n"),
            Example("class SomeActor: Actor { init(_ data: OffToTheRacesData) { self.data = data } }\n"),
            Example("class SomeActor: Actor { override func protected_flowProcess() { } }\n"),
            Example("class SomeClass { public func foo() { } }\n")
        ],
        triggeringExamples: [
            Example("class SomeActor: Actor { public ↓func foo() { } }\n"),
            Example("class SomeActor: Actor { fileprivate ↓func foo() { } }\n"),
            Example("class SomeActor: Actor { internal ↓func foo() { } }\n"),
            Example("class SomeActor: Actor { ↓func foo() { } }\n"),
            Example("class SomeActor: Actor { override ↓func flowProcess() { } }\n")
        ]
    )

    func check(_ ast: AST, _ syntax: SyntaxStructure) {
        print("PrivateFunctionInActorRule: \(syntax)")
    }

}
