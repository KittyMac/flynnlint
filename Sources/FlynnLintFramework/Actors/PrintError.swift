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

typealias PrintErrorResult = ((Int) -> Void)

class PrintError: Actor {
    // input: error string
    // output: none
    var onComplete: PrintErrorResult?
    var numErrors: Int = 0

    override init() {
        super.init()
    }

    init(_ onComplete: @escaping PrintErrorResult) {
        self.onComplete = onComplete
    }

    override func safeFlowProcess(args: BehaviorArgs) -> (Bool, BehaviorArgs) {
        if args.isEmpty == false {
            let error: String = args[x:0]
            print(error)
            if error.contains("error") {
                numErrors += 1
            }
            return (false, [])
        }

        if let onComplete = onComplete {
            onComplete(numErrors)
        }

        return (false, [])
    }
}
