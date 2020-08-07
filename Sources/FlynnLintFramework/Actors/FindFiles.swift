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
    var safeFlowable = FlowableState()
    private let extensions: [String]

    init (_ extensions: [String]) {
        self.extensions = extensions
    }

    fileprivate func _beFlow(_ args: FlowableArgs) {
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

extension FindFiles {
    func beFlow(_ args: FlowableArgs) {
        unsafeSend { [unowned self] in
            self._beFlow(args)
        }
    }
}
