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

    func testAllRules() throws {
        
    }

    func testSampleSet() throws {
        FlynnLintFramework.Process("/Volumes/Development/Development/chimerasw2/flynnlint/test")
    }

    func testPerformanceSet() throws {
        measure {
            FlynnLintFramework.Process("/Volumes/Development/Development/chimerasw2/flynnlint/benchmark")
        }
    }


}
