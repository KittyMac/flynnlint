//
//  main.swift
//  flynnlint
//
//  Created by Rocco Bowling on 5/29/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import Flynn

class FindFiles: Actor, Flowable {
    // input: path to source directory
    // output: paths to individual swift files
    lazy var safeFlowable = FlowableState(self)
    private let extensions: [String]

    init (_ extensions: [String]) {
        self.extensions = extensions
    }

    lazy var beFlow = Behavior(self) { [unowned self] (args: BehaviorArgs) in
        // flynnlint:parameter Any
        if args.isEmpty { return self.safeFlowToNextTarget(args) }

        let path: String = args[x:0]
        do {
            let resourceKeys: [URLResourceKey] = [.creationDateKey, .isDirectoryKey]
            let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: path),
                                                            includingPropertiesForKeys: resourceKeys,
                                                            options: [.skipsHiddenFiles],
                                                            errorHandler: { (url, error) -> Bool in
                                                                print("directoryEnumerator error at \(url): ", error)
                                                                return true
            })!

            for case let fileURL as URL in enumerator {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                let pathExtension = (fileURL.path as NSString).pathExtension
                if self.extensions.contains(pathExtension) && resourceValues.isDirectory == false {
                    self.safeFlowToNextTarget([fileURL.path])
                }
            }
        } catch {
            print(error)
        }
    }
}
