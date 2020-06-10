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
    
    func testCutlass() throws {
        let flynnlint = FlynnLint()
        flynnlint.process(directory: "/Volumes/Development/Development/chimerasw2/cutlass/Cutlass")
        flynnlint.finish()
    }

    
    func testOneRuleOneCode() throws {
        let rule = BehaviorCallCheck()
        XCTAssert(rule.test("""
            class StringBuilder: Actor {
                private var string: String = ""
                lazy var beAppend = ChainableBehavior(self) { (args: BehaviorArgs) in
                    // flynnlint:parameter String - the string to be appended
                    let value: String = args[x: 0]
                    self.string.append(value)
                }
                lazy var beSpace = ChainableBehavior(self) { (_: BehaviorArgs) in
                    // flynnlint:parameter None
                    self.string.append(" ")
                }
                lazy var beSpace = ChainableBehavior(self) { (_: BehaviorArgs) in
                    self.string.append(" ")
                }
                lazy var beResult = ChainableBehavior(self) { (args: BehaviorArgs) in
                    // flynnlint:parameter String - closure to call when the string is completed
                    let callback: ((String) -> Void) = args[x:0]
                    callback(self.string)
                }
            }
            class Foo {
                init() {
                    let a = StringBuilder()
                    a.beAppend(5)
                }
            }
        """))
    }
    
    func testOneRule() throws {
        let rule = BehaviorCallCheck()
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
