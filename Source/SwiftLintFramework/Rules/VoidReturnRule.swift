//
//  VoidReturnRule.swift
//  SwiftLint
//
//  Created by Marcelo Fabri on 12/12/16.
//  Copyright © 2016 Realm. All rights reserved.
//

import Foundation
import SourceKittenFramework

public struct VoidReturnRule: ConfigurationProviderRule, CorrectableRule {
    public var configuration = SeverityConfiguration(.warning)

    public init() {}

    public static let description = RuleDescription(
        identifier: "void_return",
        name: "Void Return",
        description: "Prefer `-> Void` over `-> ()`.",
        nonTriggeringExamples: [
            "let abc: () -> Void = {}\n",
            "func foo(completion: () -> Void)\n",
            "let foo: (ConfigurationTests) -> () throws -> Void)\n",
            "let foo: (ConfigurationTests) ->   () throws -> Void)\n",
            "let foo: (ConfigurationTests) ->() throws -> Void)\n",
            "let foo: (ConfigurationTests) -> () -> Void)\n"
        ],
        triggeringExamples: [
            "let abc: () -> ↓() = {}\n",
            "func foo(completion: () -> ↓())\n",
            "func foo(completion: () -> ↓(   ))\n",
            "let foo: (ConfigurationTests) -> () throws -> ↓())\n"
        ],
        corrections: [
            "let abc: () -> () = {}\n": "let abc: () -> Void = {}\n",
            "func foo(completion: () -> ())\n": "func foo(completion: () -> Void)\n",
            "func foo(completion: () -> (   ))\n": "func foo(completion: () -> Void)\n",
            "let foo: (ConfigurationTests) -> () throws -> ())\n":
                "let foo: (ConfigurationTests) -> () throws -> Void)\n"
        ]
    )

    public func validateFile(_ file: File) -> [StyleViolation] {
        return violationRanges(file: file).map {
            StyleViolation(ruleDescription: type(of: self).description,
                           severity: configuration.severity,
                           location: Location(file: file, characterOffset: $0.location))
        }
    }

    private func violationRanges(file: File) -> [NSRange] {
        let kinds = SyntaxKind.commentAndStringKinds()
        let parensPattern = "\\(\\s*\\)"
        let pattern = "->\\s*\(parensPattern)\\s*(?!->)"
        let excludingPattern = "(\(pattern))\\s*(throws\\s+)?->"

        return file.matchPattern(pattern, excludingSyntaxKinds: kinds,
                                 excludingPattern: excludingPattern) { $0.rangeAt(1) }.flatMap {
            let parensRegex = NSRegularExpression.forcePattern(parensPattern)
            return parensRegex.firstMatch(in: file.contents, options: [], range: $0)?.range
        }
    }

    public func correctFile(_ file: File) -> [Correction] {
        let violatingRanges = file.ruleEnabledViolatingRanges(violationRanges(file: file),
                                                              forRule: self)
        return writeToFile(file, violatingRanges: violatingRanges)
    }

    private func writeToFile(_ file: File, violatingRanges: [NSRange]) -> [Correction] {
        var correctedContents = file.contents
        var adjustedLocations = [Int]()

        for violatingRange in violatingRanges.reversed() {
            if let indexRange = correctedContents.nsrangeToIndexRange(violatingRange) {
                correctedContents = correctedContents
                    .replacingCharacters(in: indexRange, with: "Void")
                adjustedLocations.insert(violatingRange.location, at: 0)
            }
        }

        file.write(correctedContents)

        return adjustedLocations.map {
            Correction(ruleDescription: type(of: self).description,
                       location: Location(file: file, characterOffset: $0))
        }
    }
}
