//
//  MockableGenerator+SpyCollisions.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 20/08/25.
//

import SwiftSyntax

extension MockableGenerator {
    /// Identifies the spy a requirement records on.
    ///
    /// `Mock` stores spies as `[String: [AnySpy]]` and, on lookup, returns the
    /// first entry under the key whose *type* matches the requested
    /// `Spy<repeat each Input, Eff, Output>`. Two requirements therefore share a
    /// spy only when they agree on both halves of this identity — the
    /// dynamic-member key and the full spy signature. Differing only in
    /// signature is fine and is how method overloads already coexist.
    struct SpyIdentity: Hashable {
        /// The dynamic-member key (`super.<name>`).
        let name: String
        /// The spelling of the spy's generic arguments: inputs, effect, output.
        let signature: String
    }

    /// A pair of requirements that would record on one shared spy.
    struct SpyCollision {
        let identity: SpyIdentity
        /// Source spellings of the colliding requirements, in declaration order.
        let requirements: [String]
    }

    /// Finds requirements that would silently share a spy.
    ///
    /// The collision is invisible at runtime: stubbing one member answers calls
    /// to the other, and verification counts both. Only exact duplicates of
    /// *both* name and signature are reported — differing signatures under one
    /// key are a supported overload.
    static func spyCollisions(in protocolDecl: ProtocolDeclSyntax) -> [SpyCollision] {
        var seen = [SpyIdentity: [String]]()
        var order = [SpyIdentity]()

        for member in protocolDecl.memberBlock.members {
            for identity in spyIdentities(of: member.decl) {
                if seen[identity.0] == nil {
                    order.append(identity.0)
                }
                seen[identity.0, default: []].append(identity.1)
            }
        }

        return order.compactMap { identity in
            guard let requirements = seen[identity], requirements.count > 1 else {
                return nil
            }
            return SpyCollision(identity: identity, requirements: requirements)
        }
    }

    /// The spy identities a single requirement records on, each paired with the
    /// requirement's source spelling for diagnostics.
    ///
    /// A settable requirement contributes two: its read spy and its write spy.
    private static func spyIdentities(of decl: DeclSyntax) -> [(SpyIdentity, String)] {
        let spelling = decl.trimmedDescription

        if let funcDecl = decl.as(FunctionDeclSyntax.self) {
            let inputs = funcDecl.signature.parameterClause.parameters.map { parameter in
                parameter.ellipsis != nil
                    ? TypeSyntax(ArrayTypeSyntax(element: parameter.type)).trimmedDescription
                    : parameter.type.trimmedDescription
            }
            let output = funcDecl.signature.returnClause?.type.trimmedDescription ?? "Void"
            let identity = SpyIdentity(
                name: funcDecl.name.text,
                signature: signature(
                    inputs: inputs,
                    effect: getFunctionEffectType(funcDecl).rawValue,
                    output: output
                )
            )
            return [(identity, spelling)]
        }

        if let varDecl = decl.as(VariableDeclSyntax.self),
           let binding = varDecl.bindings.first,
           let type = binding.typeAnnotation?.type {
            let name = varDecl.name.text
            let read = SpyIdentity(
                name: name,
                signature: signature(inputs: [], effect: "None", output: type.trimmedDescription)
            )
            guard varDecl.hasSetter else {
                return [(read, spelling)]
            }
            let write = SpyIdentity(
                name: name.setterSpyName,
                signature: signature(
                    inputs: ["Void", type.trimmedDescription],
                    effect: "None",
                    output: "Void"
                )
            )
            return [(read, spelling), (write, spelling)]
        }

        if let subscriptDecl = decl.as(SubscriptDeclSyntax.self) {
            let indices = subscriptDecl.parameterClause.parameters.map(\.type.trimmedDescription)
            let element = subscriptDecl.returnClause.type.trimmedDescription
            let name = subscriptDecl.name
            let read = SpyIdentity(
                name: name,
                signature: signature(inputs: indices, effect: "None", output: element)
            )
            guard subscriptDecl.hasSetter else {
                return [(read, spelling)]
            }
            let write = SpyIdentity(
                name: name.setterSpyName,
                signature: signature(
                    inputs: indices + [element],
                    effect: "None",
                    output: "Void"
                )
            )
            return [(read, spelling), (write, spelling)]
        }

        return []
    }

    /// Renders a spy's generic arguments, matching how the generated
    /// `Interaction`/`Spy` types spell an empty input pack as `Void`.
    private static func signature(inputs: [String], effect: String, output: String) -> String {
        let inputs = inputs.isEmpty ? ["Void"] : inputs
        return (inputs + [effect, output]).joined(separator: ", ")
    }
}
