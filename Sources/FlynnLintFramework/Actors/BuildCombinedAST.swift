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

// swiftlint:disable line_length

extension String {
    func substring(with nsrange: NSRange) -> Substring? {
        guard let range = Range(nsrange, in: self) else { return nil }
        return self[range]
    }
}

struct FileSyntax {
    let file: File
    let structure: SyntaxStructure
    let tokens: [SyntaxToken]
    let blacklist: [String]

    init(_ file: File, _ structure: SyntaxStructure, _ tokens: [SyntaxToken], _ blacklist: [String]) {
        self.file = file
        self.structure = structure
        self.tokens = tokens
        self.blacklist = blacklist
    }

    func clone(_ substructure: SyntaxStructure) -> FileSyntax {
        return FileSyntax(file, substructure, tokens, blacklist)
    }

    func match(_ pattern: String) -> Int64? {
        var firstOffendingMatchOffset: Int64?

        do {
            let body = self.file.contents
            let structure = self.structure
            let map = self.tokens

            if let bodyoffset = structure.offset, let bodylength = structure.length {
                if bodyoffset + bodylength < body.count {
                    let regex = try NSRegularExpression(pattern: pattern, options: [])
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
            }
        } catch {
            return nil
        }
        return firstOffendingMatchOffset
    }

    func matches(_ pattern: String, _ callback: ((NSTextCheckingResult, [String]) -> Void)) {
        do {
            let body = self.file.contents
            let structure = self.structure
            let map = self.tokens

            if let bodyoffset = structure.offset, let bodylength = structure.length {
                if bodyoffset + bodylength < body.count {
                    let regex = try NSRegularExpression(pattern: pattern, options: [])
                    let nsrange = NSRange(location: Int(bodyoffset), length: Int(bodylength))
                    regex.enumerateMatches(in: body, options: [], range: nsrange) { (match, _, _) in
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
                        var groups: [String] = []
                        for iii in 0..<match.numberOfRanges {
                            if let groupString = body.substring(with: match.range(at: iii)) {
                                groups.append(String(groupString))
                            }
                        }
                        callback(match, groups)
                    }
                }
            }
        } catch { }
    }

    func markup(_ label: String) -> [(ByteCount, String)] {
        let body = self.file.contents
        let structure = self.structure
        let map = self.tokens
        var markup: [(ByteCount, String)] = []

        if let bodyoffset = structure.offset, let bodylength = structure.length {
            if bodyoffset + bodylength < body.count {
                let targetString = "flynnlint:\(label)"
                // Check all comments inside the body to see if they are flynnlint commands
                // flynnlint:<name> <args>
                for commentSection in map {
                    if let type = SyntaxKind(rawValue: commentSection.type) {
                        let offset = commentSection.offset.value
                        if offset >= bodyoffset && offset <= (bodyoffset + bodylength) {
                            switch type {
                            case .comment, .commentURL, .commentMark, .docComment, .docCommentField:
                                let stringView = StringView.init(body)
                                if let commentString = stringView.substringWithByteRange(commentSection.range) {
                                    if let range = commentString.range(of: targetString) {
                                        markup.append( (commentSection.offset, String(commentString[range.upperBound...])) )
                                    }
                                }
                            default:
                                break
                            }
                        }
                    }
                }
            }
        }
        return markup
    }
}

typealias ASTBuilderResult = ((AST) -> Void)

struct ASTBuilderIterator: IteratorProtocol {
    private var combinedArray: [FileSyntax]
    private var index = -1

    init(_ astBuilder: ASTBuilder) {
        combinedArray = []
        combinedArray.append(contentsOf: Array(astBuilder.classes.values))
        combinedArray.append(contentsOf: astBuilder.extensions)
        combinedArray.append(contentsOf: astBuilder.calls)
        combinedArray.append(contentsOf: astBuilder.functions)
    }

    mutating func next() -> FileSyntax? {
        index += 1
        if index >= combinedArray.count {
            return nil
        }
        return combinedArray[index]
    }
}

class ASTBuilder: Sequence {
    var classes: [String: FileSyntax] = [:]
    var extensions: [FileSyntax] = []
    var calls: [FileSyntax] = []
    var functions: [FileSyntax] = []

    func add(_ fileSyntax: FileSyntax) {
        let syntax = fileSyntax.structure

        if let name = syntax.name {
            switch syntax.kind {
            case .class:
                classes[name] = fileSyntax
            case .extension, .extensionEnum, .extensionStruct:
                extensions.append(fileSyntax)
            case .exprCall:
                calls.append(fileSyntax)
            case .functionAccessorAddress, .functionAccessorDidset, .functionAccessorGetter, .functionAccessorModify,
                 .functionAccessorMutableaddress, .functionAccessorRead, .functionAccessorSetter,
                 .functionAccessorWillset, .functionConstructor, .functionDestructor, .functionFree,
                 .functionMethodClass, .functionMethodInstance, .functionMethodStatic, .functionOperator,
                 .functionOperatorInfix, .functionOperatorPostfix, .functionOperatorPrefix, .functionSubscript:
                functions.append(fileSyntax)
            default:
                //print("ASTBuilder: unhandled kind \(kind)...")
                break
            }
        }

        if let substructures = syntax.substructure {
            for substructure in substructures {
                add(fileSyntax.clone(substructure))
            }
        }
    }

    func build() -> AST {
        return AST(classes, extensions)
    }

    func makeIterator() -> ASTBuilderIterator {
        return ASTBuilderIterator(self)
    }

}

class BuildCombinedAST: Actor {
    // input: a File and  a syntax structure
    // output: an immutable AST and pass all syntax
    var astBuilder = ASTBuilder()

    override init() {
        super.init()
        priority = 1
    }

    override func protected_flowProcess(args: BehaviorArgs) -> (Bool, BehaviorArgs) {
        if args.isEmpty == false {
            astBuilder.add(args[x:0])
            return (false, [])
        }

        priority = -1

        // Once we have all of the relevant structures from all of the files captured, we turn that
        // into an immutable struct which will allow us to share that safely with many actors. Then
        // we process eash structure against the rule set.
        let ast = astBuilder.build()

        // Run through every syntax structure and pass it to the rulesets
        for syntax in astBuilder {
            if let target = protected_nextTarget() {
                target.flow(ast, syntax)
            }
        }

        return (true, [])
    }
}
