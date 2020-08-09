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

    func testFlynnLint() throws {
        let flynnlint = FlynnLint()
        flynnlint.process(directory: "/Volumes/Development/Development/chimerasw2/flynnlint/Sources")
        flynnlint.process(directory: "/Volumes/Development/Development/chimerasw2/flynnlint/Tests")
        flynnlint.finish()
    }

    func testBatteryTester() throws {
        let flynnlint = FlynnLint()
        flynnlint.process(directory: "/Volumes/Development/Development/chimerasw2/flynn/Examples/BatteryTester/BatteryTester")
        flynnlint.finish()
    }
    
    func testHelloWorld() throws {
        let flynnlint = FlynnLint()
        flynnlint.process(directory: "/Volumes/Development/Development/chimerasw2/flynn/Examples/HelloWorld/HelloWorld")
        flynnlint.finish()
    }

    func testCutlass() throws {
        let flynnlint = FlynnLint()
        flynnlint.process(directory: "/Volumes/Development/Development/chimerasw2/cutlass/Cutlass")
        flynnlint.finish()
    }

    func testOneRuleOneCode() throws {
        let rule = PrivateFunctionInActorRule()
        XCTAssert(rule.test("""
            class TestActor: Actor {
                private var string: String = ""

                private func _bePrint() {
                    print("Hello world")
                }
            }
        """))
    }
    
    func testAllRulesOneCode() throws {
        let code = """
            class TestActor: Actor {
                private var string: String = ""

                private func _bePrint() {
                    print("Hello world")
                }
            }
        """
        let rules = Ruleset()
        for rule in rules.all {
            XCTAssert(rule.test(code))
        }
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
/*
    func testReleaseCrashTest() throws {
        for _ in 0..<1000 {
            let task = Process()
            task.launchPath = "/Volumes/Development/Development/chimerasw2/flynnlint/.build/release/flynnlint"
            task.arguments = ["/Volumes/Development/Development/chimerasw2/flynnlint/Tests/benchmark"]
            task.launch()
            task.waitUntilExit()
            XCTAssert(task.terminationStatus == 0)
        }
    }
    */
    func testReleasePerformanceSet() throws {
        measure {
            let task = Process()
            task.launchPath = "/Volumes/Development/Development/chimerasw2/flynnlint/.build/release/flynnlint"
            task.arguments = ["/Volumes/Development/Development/chimerasw2/flynnlint/Tests/benchmark"]
            task.launch()
            task.waitUntilExit()
            //XCTAssert(task.terminationStatus == 0)
        }
    }

    func testSwiftLintPerformanceSet() throws {
        measure {
            let task = Process()
            task.launchPath = "/usr/local/bin/swiftlint"
            task.arguments = ["--path", "/Volumes/Development/Development/chimerasw2/flynnlint/Tests/benchmark"]
            task.launch()
            task.waitUntilExit()
            //XCTAssert(task.terminationStatus == 0)
        }
    }

}
