//
//  main.swift
//  flynnlint
//
//  Created by Rocco Bowling on 5/29/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

typealias Example = String

struct RuleDescription: Equatable {
    /// unique string representing this rule
    public let identifier: String

    /// user facing name
    public let name: String

    /// user facing description
    public let description: String

    /// triggering syntax kind for this rule
    public let syntaxTriggers: [SwiftDeclarationKind]

    /// Examples where the rule is used properly
    public let nonTriggeringExamples: [Example]

    /// Examples which violate the rule (Violations should occur where `↓` markers are located)
    public let triggeringExamples: [Example]

    /// The console-printable string for this description.
    public var consoleDescription: String { return "\(name) (\(identifier)): \(description)" }

    // MARK: Equatable

    public static func == (lhs: RuleDescription, rhs: RuleDescription) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}
