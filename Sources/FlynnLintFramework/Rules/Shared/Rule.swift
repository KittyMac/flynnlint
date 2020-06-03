//
//  main.swift
//  flynnlint
//
//  Created by Rocco Bowling on 5/29/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import Flynn
import SourceKittenFramework

struct Ruleset {
    var all: [Rule] = []
    var byKind: [SwiftDeclarationKind: [Rule]] = [:]

    init() {
        let allRules: [Rule.Type] = [
            PrivateFunctionInActorRule.self,
            ProtectedFunctionRule.self,
            PrivateVariablesInActorRule.self,
            ProtectedVariableRule.self
        ]

        for ruleClass in allRules {
            let rule = ruleClass.init()

            all.append(rule)

            for trigger in rule.description.syntaxTriggers {
                if self.byKind[trigger] == nil {
                    self.byKind[trigger] = []
                }
                self.byKind[trigger]?.append(rule)
            }
        }
    }
}

protocol Rule {

    init()

    var description: RuleDescription { get }

    @discardableResult
    func check(_ ast: AST, _ syntax: FileSyntax, _ output: Actor?) -> Bool
}

extension Rule {

    func error(_ offset: Int64?, _ fileSyntax: FileSyntax) -> String {
        let path = fileSyntax.0.path ?? "<nopath>"
        if let offset = offset {
            let stringView = StringView.init(fileSyntax.0.contents)
            if let (line, character) = stringView.lineAndCharacter(forByteOffset: ByteCount(offset)) {
                return "\(path):\(line):\(character): error: \(description.consoleDescription)"
            }
        }
        return "\(path): error: \(description.consoleDescription)"
    }

    func warning(_ offset: Int64?, _ fileSyntax: FileSyntax) -> String {
        let path = fileSyntax.0.path ?? "<nopath>"
        if let offset = offset {
            let stringView = StringView.init(fileSyntax.0.contents)
            if let (line, character) = stringView.lineAndCharacter(forByteOffset: ByteCount(offset)) {
                return "\(path):\(line):\(character): warning: \(description.consoleDescription)"
            }
        }
        return "\(path): warning: \(description.consoleDescription)"
    }

    func test(_ code: String) -> Bool {
        let printError: PrintError? = PrintError()
        //let printError: PrintError? = nil

        do {
            let file = File(contents: code)
            let structure = try Structure(file: file)
            let syntaxMap = try SyntaxMap(file: file)
            let fileSyntax = FileSyntax(file, structure.dictionary, syntaxMap.tokens)

            let astBuilder = ASTBuilder()
            astBuilder.add(fileSyntax)

            let ast = astBuilder.build()

            for syntax in astBuilder {
                if description.syntaxTriggers.contains(syntax.1.kind!) {
                    if !check(ast, syntax, printError) {
                        return false
                    }
                }
            }

        } catch {
            print("Parsing error: \(error)")
        }
        return true
    }

    func test() -> Bool {
        for example in description.nonTriggeringExamples {
            if test(example) != true {
                print("\(description.identifier) failed on nonTriggeringExample:\n\(example)")
                return false
            }
        }
        for example in description.triggeringExamples {
            if test(example) != false {
                print("\(description.identifier) failed on triggeringExamples:\n\(example)")
                return false
            }
        }
        return true
    }

    func match(_ syntax: FileSyntax, _ regex: String) -> Int64? {
        var firstOffendingMatchOffset: Int64?

        do {
            let pattern = #"\w+(?<!self)\.protected_"#
            let body = syntax.0.contents
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let structure = syntax.1
            let map = syntax.2

            if let bodyoffset = structure.bodyoffset, let bodylength = structure.bodylength {
                let nsrange = NSRange(location: Int(bodyoffset), length: Int(bodylength))
                regex.enumerateMatches(in: body, options: [], range: nsrange) { (match, _, stop) in
                    guard let match = match else { return }

                    let fullBodyOffset = Int64(match.range.location)

                    // check this offset against all of the offsets in the syntax map.  If it is
                    // inside of a comment, then we want to ignore this offset
                    for commentSection in map {
                        if let type = SyntaxKind(rawValue: commentSection.type) {
                            let offset = commentSection.offset.value
                            let length = commentSection.length.value
                            if fullBodyOffset >= offset && fullBodyOffset <= (offset + length) {
                                switch type {
                                case .comment, .commentURL, .commentMark, .docComment, .docCommentField:
                                    return
                                default:
                                    break
                                }
                            }
                        }
                    }

                    firstOffendingMatchOffset = fullBodyOffset
                    stop.pointee = true
                }
            }
        } catch {
            return nil
        }
        return firstOffendingMatchOffset
    }
}
