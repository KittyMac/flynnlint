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
            PrivateVariablesInActorRule.self
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

    func lineAndCharacter(_ file: File, _ offset: Int) -> (Int, Int) {
        let contents = file.contents.utf8
        var line: Int = 1
        var character: Int = 1
        var count: Int = offset
        for ccc in contents {
            if ccc == 10 {
                line += 1
                character = 1
            } else {
                character += 1
            }
            count -= 1
            if count <= 0 {
                break
            }
        }
        return (line, character)
    }

    func error(_ offset: Int64?, _ fileSyntax: FileSyntax) -> String {
        let path = fileSyntax.0.path ?? "<nopath>"
        if let offset = offset {
            let (line, character) = lineAndCharacter(fileSyntax.0, Int(offset))
            return "\(path):\(line):\(character): error: \(description.consoleDescription)"
        }
        return "\(path): error: \(description.consoleDescription)"
    }

    func warning(_ offset: Int64?, _ fileSyntax: FileSyntax) -> String {
        let path = fileSyntax.0.path ?? "<nopath>"
        if let offset = offset {
            let (line, character) = lineAndCharacter(fileSyntax.0, Int(offset))
            return "\(path):\(line):\(character): warning: \(description.consoleDescription)"
        }
        return "\(path): warning: \(description.consoleDescription)"
    }

    func test(_ code: String) -> Bool {
        //let printError: PrintError? = PrintError()
        let printError: PrintError? = nil

        do {
            let file = File(contents: code)
            let structure = try Structure(file: file)
            let fileSyntax = FileSyntax(file, structure.dictionary)

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
}
