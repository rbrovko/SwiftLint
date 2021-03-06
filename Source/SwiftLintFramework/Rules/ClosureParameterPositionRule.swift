//
//  ClosureParameterPositionRule.swift
//  SwiftLint
//
//  Created by Marcelo Fabri on 12/11/16.
//  Copyright © 2016 Realm. All rights reserved.
//

import Foundation
import SourceKittenFramework

public struct ClosureParameterPositionRule: ASTRule, ConfigurationProviderRule {
    public var configuration = SeverityConfiguration(.warning)

    public init() {}

    public static let description = RuleDescription(
        identifier: "closure_parameter_position",
        name: "Closure Parameter Position",
        description: "Closure parameters should be on the same line as opening brace.",
        nonTriggeringExamples: [
            "[1, 2].map { $0 + 1 }\n",
            "[1, 2].map({ $0 + 1 })\n",
            "[1, 2].map { number in\n number + 1 \n}\n",
            "[1, 2].map { number -> Int in\n number + 1 \n}\n",
            "[1, 2].map { (number: Int) -> Int in\n number + 1 \n}\n",
            "[1, 2].map { [weak self] number in\n number + 1 \n}\n",
            "[1, 2].something(closure: { number in\n number + 1 \n})\n",
            "let isEmpty = [1, 2].isEmpty()\n",
            "rlmConfiguration.migrationBlock.map { rlmMigration in\n" +
                "return { migration, schemaVersion in\n" +
                    "rlmMigration(migration.rlmMigration, schemaVersion)\n" +
                "}\n" +
            "}"
        ],
        triggeringExamples: [
            "[1, 2].map {\n ↓number in\n number + 1 \n}\n",
            "[1, 2].map {\n ↓number -> Int in\n number + 1 \n}\n",
            "[1, 2].map {\n (↓number: Int) -> Int in\n number + 1 \n}\n",
            "[1, 2].map {\n [weak self] ↓number in\n number + 1 \n}\n",
            "[1, 2].map { [weak self]\n ↓number in\n number + 1 \n}\n",
            "[1, 2].map({\n ↓number in\n number + 1 \n})\n",
            "[1, 2].something(closure: {\n ↓number in\n number + 1 \n})\n",
            "[1, 2].reduce(0) {\n ↓sum, ↓number in\n number + sum \n}\n"
        ]
    )

    private static let openBraceRegex = regex("\\{")

    public func validateFile(_ file: File,
                             kind: SwiftExpressionKind,
                             dictionary: [String: SourceKitRepresentable]) -> [StyleViolation] {
        guard kind == .call else {
            return []
        }

        guard let nameOffset = (dictionary["key.nameoffset"] as? Int64).flatMap({ Int($0) }),
            let nameLength = (dictionary["key.namelength"] as? Int64).flatMap({ Int($0) }),
            let bodyLength = (dictionary["key.bodylength"] as? Int64).flatMap({ Int($0) }),
            bodyLength > 0 else {
                return []
        }

        let parameters = filterByKind(dictionary: dictionary, kind: .varParameter)
        let rangeStart = nameOffset + nameLength
        let regex = ClosureParameterPositionRule.openBraceRegex

        // parameters from inner closures are reported on the top-level one, so we can't just
        // use the first and last parameters to check, we need to check all of them
        return parameters.flatMap { param -> StyleViolation? in
            guard let paramOffset = (param["key.offset"] as? Int64).flatMap({ Int($0) }) else {
                return nil
            }

            let rangeLength = paramOffset - rangeStart
            let contents = file.contents.bridge()

            guard let range = contents.byteRangeToNSRange(start: rangeStart,
                                                          length: rangeLength),
                let match = regex.matches(in: file.contents, options: [], range: range).last?.range,
                match.location != NSNotFound,
                let braceOffset = contents.NSRangeToByteRange(start: match.location,
                                                              length: match.length)?.location,
                let (braceLine, _) = contents.lineAndCharacter(forByteOffset: braceOffset),
                let (paramLine, _) = contents.lineAndCharacter(forByteOffset: paramOffset),
                braceLine != paramLine else {
                    return nil
            }

            return StyleViolation(ruleDescription: type(of: self).description,
                                  severity: configuration.severity,
                                  location: Location(file: file, byteOffset: paramOffset))
        }
    }

    private func filterByKind(dictionary: [String: SourceKitRepresentable],
                              kind: SwiftDeclarationKind) -> [[String: SourceKitRepresentable]] {

        let substructure = dictionary["key.substructure"] as? [SourceKitRepresentable] ?? []
        return substructure.flatMap { subItem -> [[String: SourceKitRepresentable]] in
            guard let subDict = subItem as? [String: SourceKitRepresentable],
                let kindString = subDict["key.kind"] as? String else {
                    return []
            }

            if SwiftDeclarationKind(rawValue: kindString) == kind {
                return [subDict]
            }

            if SwiftExpressionKind(rawValue: kindString) == .argument {
                return filterByKind(dictionary: subDict, kind: kind)
            }

            return []
        }
    }
}
