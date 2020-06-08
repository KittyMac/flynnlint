//
//  main.swift
//  flynnlint
//
//  Created by Rocco Bowling on 5/29/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

// swiftlint:disable line_length

import Foundation
import Flynn
import SourceKittenFramework

struct PrivateFunctionInActorRule: Rule {

    let description = RuleDescription(
        identifier: "actors_private_func",
        name: "Access Level Violation",
        description: "Non-private functions are not allowed in Actors; make this private, a behavior, or label it safe.",
        syntaxTriggers: [.class, .extension],
        nonTriggeringExamples: [
            Example("class SomeClass {}\n"),
            Example("class SomeActor: Actor {}\n"),
            Example("class SomeActor: Actor { private func foo() { } }\n"),
            Example("class SomeActor: Actor { init(_ data: OffToTheRacesData) { self.data = data } }\n"),
            Example("class SomeActor: Actor { override func safeFlowProcess() { } }\n"),
            Example("class SomeClass { public func foo() { } }\n"),

            Example("class SomeActor: Actor { public func unsafeFoo() { } }\n"),
            Example("class SomeActor: Actor { fileprivate func unsafeFoo() { } }\n"),
            Example("class SomeActor: Actor { internal func unsafeFoo() { } }\n"),
            Example("class SomeActor: Actor { func unsafeFoo() { } }\n"),
            Example("class SomeActor: Actor { override func unsafeFlowProcess() { } }\n")
        ],
        triggeringExamples: [
            Example("class SomeActor: Actor { public func foo() { } }\n"),
            Example("class SomeActor: Actor { fileprivate func foo() { } }\n"),
            Example("class SomeActor: Actor { internal func foo() { } }\n"),
            Example("class SomeActor: Actor { func foo() { } }\n"),
            Example("class SomeActor: Actor { override func flowProcess() { } }\n"),
            Example("""
                public protocol Viewable: Actor {
                    var beRender: Behavior { get }
                }

                public extension Viewable {

                    func viewableSubmitRenderUnit(_ ctx: RenderFrameContext,
                                                  _ vertices: FloatAlignedArray,
                                                  _ contentSize: GLKVector2,
                                                  _ shaderType: ShaderType = .flat,
                                                  _ textureName: String? = nil,
                                                  _ partNumber: Int64 = 0) {
                        let unit = RenderUnit(ctx,
                                              shaderType,
                                              vertices,
                                              contentSize,
                                              partNumber,
                                              textureName)
                        ctx.renderer.beSubmitRenderUnit(ctx, unit)
                    }

                    func safeViewableSubmitRenderFinished(_ ctx: RenderFrameContext) {
                        ctx.renderer.beSubmitRenderFinished(ctx)
                    }
                }
            """)
        ]
    )

    func check(_ ast: AST, _ syntax: FileSyntax, _ output: Actor?) -> Bool {
        // Every function defined in a class which is a subclass of Actor must follow these rules:
        // 1. its access control level (ACL) must be set to private
        // 2. if it starts with safe, its ACL may be anything. Other rules will keep anything
        //    but a subclass of this Actor calling safe methods
        // 3. if it is an init function

        if let resolvedClass = ast.getClassOrProtocol(syntax.structure.name) {
            if ast.isActor(resolvedClass) {
                if let functions = syntax.structure.substructure {
                    for function in functions where
                        !(function.name ?? "").hasPrefix(FlynnLint.unsafePrefix) &&
                        !(function.name ?? "").hasPrefix(FlynnLint.safePrefix) &&
                        !(function.name ?? "").hasPrefix("init(") &&
                        !(function.name ?? "").hasPrefix("deinit") &&
                        function.kind == .functionMethodInstance &&
                        function.accessibility != .private {
                        if let output = output {
                            output.flow(error(function.offset, syntax))
                        }
                        return false
                    }
                    for function in functions where
                        (function.name ?? "").hasPrefix(FlynnLint.unsafePrefix) &&
                        function.kind == .functionMethodInstance &&
                        function.accessibility != .private {
                        if let output = output {
                            output.flow(warning(function.offset, syntax, description.console("Unsafe functions should not be used")))
                        }
                    }
                }
            }
        }

        return true
    }

}
