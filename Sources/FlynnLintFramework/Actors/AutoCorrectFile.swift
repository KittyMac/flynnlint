//
//  main.swift
//  flynnlint
//
//  Created by Rocco Bowling on 5/29/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

// swiftlint:disable function_body_length
// swiftlint:disable cyclomatic_complexity

import Foundation
import SourceKittenFramework
import Flynn

extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }

    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }
}

class AutoCorrectFile: Actor, Flowable {
    // input: path to swift file
    // output: path to swift file
    lazy var safeFlowable = FlowableState(self)

    private func autocorrect(_ string: String, _ marker: String, _ replacement: String) -> String {
        // Expectation is the following:
        //
        // string::BEHAVIOR
        //
        // converts to
        //
        // lazy var beString = Behavior(self) { [unowned self] (args: BehaviorArgs) in
        //     // flynnlint:parameter String - string to print
        //     print(args[x:0])
        // }
        //
        // with proper indentation preserved

        var corrected = string

        while true {
            if  let markerRange = corrected.range(of: marker) {

                var offset: Int = 0
                var indent: Int = 0
                var valid: Bool = false

                // walk backwards to find the name start (if it exists)
                while true {
                    offset -= 1
                    let offsetIdx = corrected.index(markerRange.lowerBound, offsetBy: offset)
                    let char = corrected[offsetIdx]
                    if char.isLetter || char.isNumber {
                        continue
                    }

                    if char.isWhitespace {
                        offset += 1
                        break
                    }

                    // error, bail!
                    return corrected
                }

                var name = "HelloWorld"
                let nameStartIdx = corrected.index(markerRange.lowerBound, offsetBy: offset)
                let nameEndIdx = markerRange.lowerBound
                if offset < -1 {
                    name = String(corrected[nameStartIdx..<nameEndIdx]).capitalizingFirstLetter()
                }

                while true {
                    offset -= 1

                    let offsetIdx = corrected.index(markerRange.lowerBound, offsetBy: offset)
                    if corrected[offsetIdx] == " " {
                        indent += 1
                    } else if corrected[offsetIdx] == "\t" {
                        indent += 4
                    } else if corrected[offsetIdx] == "\n" {
                        offset += 1
                        valid = true
                        break
                    } else {
                        valid = false
                        break
                    }
                }

                if valid {
                    let startIdx = corrected.index(markerRange.lowerBound, offsetBy: offset)
                    let endIdx = markerRange.upperBound
                    let range = startIdx..<endIdx
                    let indentString = String(repeating: " ", count: indent)

                    var fixedReplacement = replacement.replacingOccurrences(of: "INDENT", with: indentString)
                    fixedReplacement = fixedReplacement.replacingOccurrences(of: "NAME", with: name)

                    corrected = corrected.replacingCharacters(in: range, with: fixedReplacement)
                } else {
                    break
                }

            } else {
                break
            }
        }

        return corrected
    }

    lazy var beFlow = Behavior(self) { [unowned self] (args: BehaviorArgs) in
        // flynnlint:parameter Any
        if args.isEmpty { return self.safeFlowToNextTarget(args) }

        let path: String = args[x:0]
        if let fileString: String = try? String(contentsOfFile: path) {

            var corrected = fileString

            corrected = self.autocorrect(corrected,
                                        "::ACTOR",
                                        """
                                        INDENTclass NAME: Actor {
                                        INDENT
                                        INDENT    printString::BEHAVIOR
                                        INDENT
                                        INDENT}
                                        """)

            corrected = self.autocorrect(corrected,
                                        "::BEHAVIOR",
                                        """
                                        INDENTlazy var beNAME = Behavior(self) { [unowned self] (args: BehaviorArgs) in
                                        INDENT    // flynnlint:parameter String - string to print
                                        INDENT    let value: String = args[x:0]
                                        INDENT    print(value)
                                        INDENT}
                                        """)

            try? corrected.write(toFile: path, atomically: false, encoding: .utf8)
        }

        self.safeFlowToNextTarget([path])
    }
}
