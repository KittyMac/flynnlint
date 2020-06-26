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

class PrintError: Actor, Flowable {
    // input: error string
    // output: none
    lazy var safeFlowable = FlowableState(self)

    private var onComplete: PrintErrorResult?
    private var numErrors: Int = 0

    override init() {
        super.init()
    }

    init(_ onComplete: @escaping PrintErrorResult) {
        self.onComplete = onComplete
    }

    lazy var beFlow = Behavior(self) { [unowned self] (args: BehaviorArgs) in
        // flynnlint:parameter Any
        if args.isEmpty == false {
            let error: String = args[x:0]
            print(error)
            if error.contains("error") {
                self.numErrors += 1
            }
        }

        if let onComplete = self.onComplete {
            onComplete(self.numErrors)
        }
    }
}
