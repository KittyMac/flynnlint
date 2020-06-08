//
//  FlynnLintTests.swift
//  FlynnLintTests
//
//  Created by Rocco Bowling on 5/31/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import XCTest
@testable import FlynnLintFramework

class FlynnLintTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }
    
    func testFlynn() throws {
        let flynnlint = FlynnLint()
        flynnlint.process(directory: "/Volumes/Development/Development/chimerasw2/flynn/Tests")
        flynnlint.process(directory: "/Volumes/Development/Development/chimerasw2/flynn/Sources")
        flynnlint.finish()
    }
    
    func testOneRuleOneCode() throws {
        let rule = PrivateFunctionInActorRule()
        XCTAssert(!rule.test("""
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
        """))
    }
    
    func testOneRule() throws {
        let rule = PrivateFunctionInActorRule()
        XCTAssert(rule.test())
    }

    func testAllRules() throws {
        let rules = Ruleset()
        for rule in rules.all {
            XCTAssert(rule.test())
        }
    }

    func testSampleSet() throws {
        let flynnlint = FlynnLint()
        flynnlint.process(directory: "/Volumes/Development/Development/chimerasw2/flynnlint/Tests/sample")
        flynnlint.finish()
    }

    func testPerformanceSet() throws {
        measure {
            let flynnlint = FlynnLint()
            flynnlint.process(directory: "/Volumes/Development/Development/chimerasw2/flynnlint/Tests/benchmark")
            flynnlint.finish()
        }
    }
    
    func testReleasePerformanceSet() throws {
        measure {
            let task = Process()
            task.launchPath = "/Volumes/Development/Development/chimerasw2/flynnlint/.build/release/flynnlint"
            task.arguments = ["/Volumes/Development/Development/chimerasw2/flynnlint/Tests/benchmark"]
            task.launch()
            task.waitUntilExit()
        }
    }
    
    func testSwiftLintPerformanceSet() throws {
        measure {
            let task = Process()
            task.launchPath = "/usr/local/bin/swiftlint"
            task.arguments = ["--path","/Volumes/Development/Development/chimerasw2/flynnlint/Tests/benchmark"]
            task.launch()
            task.waitUntilExit()
        }
    }


}
