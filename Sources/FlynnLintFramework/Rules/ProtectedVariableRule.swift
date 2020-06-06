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

struct ProtectedVariableRule: Rule {
    let description = RuleDescription(
        identifier: "actors_protected_var",
        name: "Protected Access Violation",
        description: "Protected variables may not be called outside of the Actor.",
        syntaxTriggers: [.class, .extension, .struct, .extensionStruct, .enum, .extensionEnum, .functionFree],
        nonTriggeringExamples: [
            Example("""
                class SomeActor: Actor {
                    var protected_colorable = 5
                }
                class OtherActor: SomeActor {
                    func foo() {
                        protected_colorable = 15
                        self.protected_colorable = 15
                    }
                }
            """),
            Example("""
                func testColor() {
                    let expectation = XCTestExpectation(description: "Protocols, extensions etc...")
                    let color = Color()
                    color.render(CGRect.zero)
                    //print(color.protected_colorable._color)
                    /* print(color.protected_colorable._color) */
                    /*
                     * print(color.protected_colorable._color)
                     */
                    ///print(color.protected_colorable._color)
                    expectation.fulfill()
                }
            """),
            Example("""
                func testArrayOfColors() {
                    let expectation = XCTestExpectation(description: "Array of actors by protocol")
                    let views: [Viewable] = Array(count: Flynn.cores) { Color() }
                    for view in views {
                        view.render(CGRect.zero)
                    }
                    expectation.fulfill()
                }
            """)
        ],
        triggeringExamples: [
            Example("""
                class SomeActor: Actor {
                    var protected_colorable = 5
                }
                class OtherActor: SomeActor {
                    func foo() {
                        let a = SomeActor()
                        a.protected_colorable = 15
                    }
                }
            """),
            Example("""
                func testColor() {
                    let expectation = XCTestExpectation(description: "Protocols, extensions etc...")
                    let color = Color()
                    color.render(CGRect.zero)
                    print(color.protected_colorable._color)
                    expectation.fulfill()
                }
            """)
        ]
    )

    func precheck(_ file: File) -> Bool {
        return file.contents.contains(".protected_")
    }

    func check(_ ast: AST, _ syntax: FileSyntax, _ output: Actor?) -> Bool {
        // sourcekit doesn't give us structures for variable accesses. So the
        // best we can do is grep the body contents. Doing this, we are looking
        // or any instances of .protected_ which are not self.protected_. This is
        // FAR from perfect, but until sourcekit provides the full, unadultered
        // AST what can we do?
        if let innerOffset = syntax.match(#"\w+(?<!self)\.protected_"#) {
            if let output = output {
                output.flow(error(innerOffset, syntax))
            }
            return false
        }

        return true
    }

}
