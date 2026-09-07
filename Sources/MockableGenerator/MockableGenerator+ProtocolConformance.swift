//
//  MockableGenerator+ProtocolConformance.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 20/07/25.
//

import SwiftSyntax

extension MockableGenerator {
    /// Generates the necessary declarations to conform to a protocol.
    ///
    /// This function iterates through the members of a protocol and generates the corresponding
    /// function, variable, subscript, and initializer requirements.
    ///
    /// For example, for the following protocol:
    /// ```swift
    /// protocol MyService {
    ///     func doSomething()
    ///     var value: Int { get }
    /// }
    /// ```
    /// This function will generate the `doSomething()` function and the `value` computed property.
    static func makeConformanceRequirements(
        for protocolDecl: ProtocolDeclSyntax,
        spyAccess: SpyAccess = .inherited,
        mockName: String
    ) -> [DeclSyntax] {
        var declarations = [DeclSyntax]()
        // Tracked separately: a protocol declaring both `init()` and
        // `init(value:)` needs no synthesized initializer, but seeing either one
        // alone is not enough to decide that.
        var declaresAnyInitializer = false
        var declaresZeroArgumentInitializer = false
        // Whether the generated mock has a superclass to chain `super.init` to.
        // An inheriting mock always does (`Mock`); a composed one does only if
        // its protocol's inheritance clause could name a class, which is the
        // same conservative test that governs `Sendable`.
        let hasSuperclass = !isStrictlySendable(protocolDecl: protocolDecl, spyAccess: spyAccess)
        for member in protocolDecl.memberBlock.members {
            if let functionDecl = member.decl.as(FunctionDeclSyntax.self) {
                declarations.append(DeclSyntax(functionRequirement(functionDecl, spyAccess: spyAccess)))
            } else if let variableDecl = member.decl.as(VariableDeclSyntax.self) {
                declarations.append(DeclSyntax(variableRequirement(variableDecl, spyAccess: spyAccess)))
            } else if let subscriptDecl = member.decl.as(SubscriptDeclSyntax.self) {
                declarations.append(DeclSyntax(subscriptRequirement(subscriptDecl, spyAccess: spyAccess)))
            } else if let initDecl = member.decl.as(InitializerDeclSyntax.self) {
                declarations.append(
                    DeclSyntax(initializerRequirement(
                        initDecl,
                        spyAccess: spyAccess,
                        mockName: mockName,
                        hasSuperclass: hasSuperclass
                    ))
                )
                // A protocol may declare `init()` itself, in which case the
                // requirement above already provides it and restating it would
                // be an invalid redeclaration.
                declaresAnyInitializer = true
                if initDecl.signature.parameterClause.parameters.isEmpty {
                    declaresZeroArgumentInitializer = true
                }
            }
        }

        if declaresAnyInitializer
            && !declaresZeroArgumentInitializer
            && canSynthesizeDefaultInitializer(for: protocolDecl, spyAccess: spyAccess) {
            declarations.append(
                DeclSyntax(defaultInitializer(spyAccess: spyAccess, hasSuperclass: hasSuperclass))
            )
        }

        return declarations
    }

    /// A zero-argument initializer, emitted only when the protocol declares
    /// initializers of its own.
    ///
    /// Declaring any designated initializer suppresses the one a mock would
    /// otherwise inherit (`Mock`'s) or get synthesized, so without this a mock
    /// for a protocol with an `init` requirement cannot be constructed the way
    /// every other mock is:
    ///
    /// ```
    /// error: missing argument for parameter 'value' in call
    /// ```
    ///
    /// Tests construct mocks with `MockMyService()` and stub afterwards; the
    /// requirement's own initializer exists to satisfy the protocol.
    ///
    /// Only emitted when it can be spelled correctly — see
    /// ``canSynthesizeDefaultInitializer(for:spyAccess:)``.
    ///
    /// The body chains to `super.init()` only when the mock has a superclass to
    /// chain to — `super.init()` in a root class is an error. `override` is
    /// never emitted: an inheriting mock does not override `Mock`'s
    /// *convenience* `init()`, and the only composed case that reaches here has
    /// no superclass to override.
    static func defaultInitializer(
        spyAccess: SpyAccess,
        hasSuperclass: Bool
    ) -> InitializerDeclSyntax {
        InitializerDeclSyntax(
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    parameters: FunctionParameterListSyntax([])
                )
            ),
            body: CodeBlockSyntax {
                if hasSuperclass {
                    superInitCall(spyAccess: spyAccess)
                }
            }
        )
    }

    /// Whether a zero-argument `init()` can be synthesized correctly.
    ///
    /// An inheriting mock's superclass is always `Mock`, so it always can.
    ///
    /// A composed mock's superclass is whatever its protocol's inheritance
    /// clause names — and a bare identifier there is undecidable at expansion
    /// time, since the macro sees only syntax and cannot tell `BaseService` from
    /// `SomeBaseClass`. Both spellings of `init()` are wrong for one of those:
    ///
    /// - With a *class* parent declaring `init()`, omitting `override` is
    ///   `error: overriding declaration requires an 'override' keyword`.
    /// - With a *protocol* parent there is no superclass, so `override` is
    ///   `error: 'init()' does not override any declaration` and `super.init()`
    ///   is `error: 'super' cannot be used in class 'MockX' because it has no
    ///   superclass`.
    ///
    /// Rather than guess, nothing is emitted when a composed protocol has any
    /// inherited types. The mock is still constructible through the
    /// requirement's own initializer; it simply does not gain the extra
    /// zero-argument one. This mirrors ``isStrictlySendable(protocolDecl:spyAccess:)``,
    /// which is conservative in the same place and for the same reason.
    static func canSynthesizeDefaultInitializer(
        for protocolDecl: ProtocolDeclSyntax,
        spyAccess: SpyAccess
    ) -> Bool {
        guard case .composed = spyAccess else { return true }
        return protocolDecl.inheritanceClause?.inheritedTypes.isEmpty ?? true
    }

    /// Generates a `required` initializer declaration that records its call.
    ///
    /// For an initializer `init(value: Int)`, this will generate:
    /// ```swift
    /// required init(value: Int) {
    ///     let spy: Spy<Int, None, Void> = MockMyService.`init`
    ///     Mock.adapt(spy, value)
    ///     super.init(scopedStorageKey: nil)
    /// }
    /// ```
    ///
    /// ## Why the spy is static
    ///
    /// Every other requirement records on instance storage, but an initializer
    /// runs *before* the instance exists: neither `self.mock` nor the inherited
    /// `super` subscript is reachable until `super.init()` has returned, and
    /// recording after that point would be too late for a mock whose
    /// construction is the thing under test. Static storage has no such phase —
    /// it is the same reasoning that makes `staticMock` necessary for static
    /// requirements. The generated interaction is `static` to match.
    ///
    /// ## Chaining to `super.init`
    ///
    /// Swift requires every designated initializer to chain to `super.init`,
    /// when there is a superclass at all:
    ///
    /// ```
    /// error: 'super.init' isn't called on all paths before returning from initializer
    /// ```
    ///
    /// For the inheriting strategy the superclass is known — `Mock` — and
    /// ``superInitCall(spyAccess:)`` names its designated initializer directly.
    ///
    /// For `.composition` the macro cannot see the superclass its protocol
    /// constrains the mock to, so it cannot know which initializers exist.
    /// `super.init()` is correct whenever that superclass has a zero-argument
    /// initializer, and a compile error naming this line otherwise. That is a
    /// better failure than the `fatalError` this replaced: that always compiled
    /// but left the initializer unusable and its calls unrecorded, making
    /// `.composition` silently differ from the default strategy.
    static func initializerRequirement(
        _ initDecl: InitializerDeclSyntax,
        spyAccess: SpyAccess = .inherited,
        mockName: String,
        hasSuperclass: Bool
    ) -> InitializerDeclSyntax {
        let modifiers = DeclModifierListSyntax {
            DeclModifierSyntax(name: .keyword(.required))
            for modifier in initDecl.modifiers {
                modifier
            }
        }
        let parameters = initDecl.signature.parameterClause.parameters
        return InitializerDeclSyntax(
            attributes: initDecl.attributes,
            modifiers: modifiers,
            genericParameterClause: initDecl.genericParameterClause,
            signature: initDecl.signature,
            body: CodeBlockSyntax {
                initializerSpyBinding(initDecl, spyAccess: spyAccess, mockName: mockName)
                // Not assigned to `_`: the spy's output is always `Void` here,
                // and discarding a `Void` result warns that the discard is
                // redundant.
                FunctionCallExprSyntax(
                    calledExpression: MemberAccessExprSyntax(
                        base: DeclReferenceExprSyntax(baseName: .identifier("Mock")),
                        name: .identifier("adapt")
                    ),
                    leftParen: .leftParenToken(),
                    arguments: LabeledExprListSyntax {
                        LabeledExprSyntax(
                            expression: DeclReferenceExprSyntax(
                                baseName: .identifier(initializerSpyBindingName)
                            )
                        )
                        if parameters.isEmpty {
                            LabeledExprSyntax(
                                expression: TupleExprSyntax(elements: LabeledExprListSyntax())
                            )
                        } else {
                            for parameter in parameters {
                                LabeledExprSyntax(
                                    expression: DeclReferenceExprSyntax(
                                        baseName: parameter.secondName ?? parameter.firstName
                                    )
                                )
                            }
                        }
                    },
                    rightParen: .rightParenToken()
                )
                if hasSuperclass {
                    superInitCall(spyAccess: spyAccess)
                }
            }
        )
    }

    /// The local constant a generated initializer binds its spy to.
    static let initializerSpyBindingName = "spy"

    /// The `super.init(…)` call a generated designated initializer chains to.
    ///
    /// The inheriting strategy must name `Mock`'s *designated* initializer.
    /// `Mock.init()` is a convenience initializer, and chaining to one is an
    /// error:
    ///
    /// ```
    /// error: must call a designated initializer of the superclass 'Mock'
    /// ```
    ///
    /// `scopedStorageKey: nil` is what `Mock.init()` itself passes — the mock
    /// keeps its instance spies in its own storage.
    ///
    /// A composed mock's superclass is the one its protocol constrains it to, so
    /// the only initializer the macro can name is a zero-argument one.
    static func superInitCall(spyAccess: SpyAccess) -> ExprSyntax {
        switch spyAccess {
        case .inherited:
            return ExprSyntax("super.init(scopedStorageKey: nil)")
        case .composed:
            return ExprSyntax("super.init()")
        }
    }

    /// Builds `let spy: Spy<Inputs…, None, Void> = <Mock>.staticMock.\`init\``.
    ///
    /// The type is spelled for the same reason typed-throws requirements spell
    /// theirs: the spy comes from `Mock`'s generic `@dynamicMemberLookup`
    /// subscript, and `adapt`'s own generics cannot pin `Output` down from a
    /// discarded result. Without the annotation the solver reports
    /// `generic parameter 'Output' could not be inferred`.
    ///
    /// The base is the mock's own type name rather than `Self`: under
    /// `.composition` a `final` mock makes the two equivalent, but the
    /// inheriting strategy's mock is subclassable, and `Self` in a subclass
    /// would resolve to different static storage than the interaction — which
    /// is declared on the mock — reads from. See
    /// ``initializerSpyReference(spyAccess:mockName:)``.
    private static func initializerSpyBinding(
        _ initDecl: InitializerDeclSyntax,
        spyAccess: SpyAccess,
        mockName: String
    ) -> VariableDeclSyntax {
        let inputTypes = initDecl.signature.parameterClause.parameters.map { parameter -> String in
            let type = parameter.ellipsis != nil
                ? TypeSyntax(ArrayTypeSyntax(element: parameter.type))
                : removeAttributes(parameter.type)
            return type.trimmedDescription
        }
        let arguments = (inputTypes.isEmpty ? ["Void"] : inputTypes) + ["None", "Void"]
        let spyType = TypeSyntax(stringLiteral: "Spy<\(arguments.joined(separator: ", "))>")

        return VariableDeclSyntax(
            bindingSpecifier: .keyword(.let, trailingTrivia: .space),
            bindings: PatternBindingListSyntax {
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(
                        identifier: .identifier(initializerSpyBindingName)
                    ),
                    typeAnnotation: TypeAnnotationSyntax(
                        colon: .colonToken(trailingTrivia: .space),
                        type: spyType
                    ),
                    initializer: InitializerClauseSyntax(
                        equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                        value: initializerSpyReference(spyAccess: spyAccess, mockName: mockName)
                    )
                )
            }
        )
    }

    /// The expression naming an initializer's spy.
    ///
    /// Both strategies reach the same static storage the generated interaction
    /// reads, but they spell it differently.
    ///
    /// A composed mock goes through its `staticMock` property, a `Mock`
    /// instance, whose `@dynamicMemberLookup` subscript supplies the spy.
    ///
    /// An inheriting mock has no such property — its static spies come from
    /// `Mock`'s *static* subscript, reached on the mock's own metatype. That
    /// metatype is upcast to `Mock.Type` first, because the mock also declares a
    /// static member literally named `init` — the generated interaction — which
    /// otherwise shadows the dynamic-member lookup:
    ///
    /// ```
    /// error: cannot convert value of type '@Sendable (ArgMatcher<Int>) ->
    ///        Interaction<Int, None, Void>' to specified type 'Spy<Int, None, Void>'
    /// ```
    ///
    /// The upcast names a type that has no `init` member of its own, so lookup
    /// falls through to the subscript. It does not change *which* storage is
    /// read: that subscript keys on `Self`, which stays the mock's own type. The
    /// interaction sidesteps the same collision with `super`, which an instance
    /// initializer cannot use to reach static storage.
    private static func initializerSpyReference(
        spyAccess: SpyAccess,
        mockName: String
    ) -> ExprSyntax {
        switch spyAccess {
        case .inherited:
            return ExprSyntax(
                MemberAccessExprSyntax(
                    base: TupleExprSyntax {
                        LabeledExprSyntax(
                            expression: SequenceExprSyntax {
                                // `.self` is required: a bare type name is not
                                // a value expression, so `Mock as Mock.Type`
                                // does not parse.
                                MemberAccessExprSyntax(
                                    base: DeclReferenceExprSyntax(
                                        baseName: .identifier(mockName)
                                    ),
                                    name: .keyword(.self),
                                    trailingTrivia: .space
                                )
                                UnresolvedAsExprSyntax(trailingTrivia: .space)
                                TypeExprSyntax(
                                    type: TypeSyntax(stringLiteral: "Mock.Type")
                                )
                            }
                        )
                    },
                    name: escapedIdentifier(initializerSpyName)
                )
            )
        case .composed:
            return ExprSyntax(
                MemberAccessExprSyntax(
                    base: MemberAccessExprSyntax(
                        base: DeclReferenceExprSyntax(baseName: .identifier(mockName)),
                        name: .identifier(SpyAccess.staticStoredPropertyName)
                    ),
                    name: escapedIdentifier(initializerSpyName)
                )
            )
        }
    }

    /// Generates a function declaration that fulfills a protocol requirement.
    ///
    /// For a function `func doSomething()`, this will generate a function with a body that calls the mock's `adapt` function.
    static func functionRequirement(
        _ functionDecl: FunctionDeclSyntax,
        spyAccess: SpyAccess = .inherited
    ) -> FunctionDeclSyntax {
        return FunctionDeclSyntax(
            attributes: functionDecl.attributes,
            // Trimmed because modifiers copied from the protocol carry the
            // source's leading trivia; that stale newline and indentation would
            // otherwise survive into the generated member and misindent it.
            // `mutating`/`nonmutating` are dropped because the mock is a class.
            modifiers: functionDecl.modifiers.withoutValueTypeModifiers.trimmed,
            name: functionDecl.name,
            genericParameterClause: functionDecl.genericParameterClause,
            signature: functionDecl.signature,
            body: functionRequirementBody(functionDecl, spyAccess: spyAccess)
        )
    }
    
    /// Generates a variable declaration that fulfills a protocol requirement.
    ///
    /// For a variable `var value: Int { get }`, this will generate a computed property with a getter that calls the mock's `adapt` function.
    static func variableRequirement(
        _ variableDecl: VariableDeclSyntax,
        spyAccess: SpyAccess = .inherited
    ) -> VariableDeclSyntax {
        let isStatic = variableDecl.modifiers.contains(where: \.isStatic)
        return VariableDeclSyntax(
            attributes: variableDecl.attributes,
            modifiers: variableDecl.modifiers.trimmed,
            // Trimmed so the `var` keyword does not carry the protocol's source
            // indentation: BasicFormat infers a block's indentation by *adding*
            // the first token's existing leading trivia to the enclosing level,
            // which would double-indent the generated property.
            bindingSpecifier: variableDecl.bindingSpecifier.trimmed,
            bindings: PatternBindingListSyntax {
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(
                        identifier: variableDecl.name
                    ),
                    typeAnnotation: variableDecl.bindings.first?.typeAnnotation,
                    accessorBlock: AccessorBlockSyntax(
                        accessors: .accessors(
                            AccessorDeclListSyntax(
                                itemsBuilder: {
                                    // Setter
                                    if variableDecl.hasSetter {
                                        AccessorDeclSyntax(
                                            accessorSpecifier: .keyword(.set),
                                            bodyBuilder: {
                                                ReturnStmtSyntax(
                                                    expression: adaptCall(
                                                        effectType: .none,
                                                        requirementName: .identifier(variableDecl.name.text.setterSpyName),
                                                        parameters: [ExprSyntax(TupleExprSyntax(elements: LabeledExprListSyntax())), ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier("newValue")))],
                                                        spyAccess: spyAccess,
                                                        isStatic: isStatic
                                                    )
                                                )
                                            }
                                        )
                                    }
                                    // Getter
                                    AccessorDeclSyntax(
                                        accessorSpecifier: .keyword(.get),
                                        bodyBuilder: {
                                            adaptCall(
                                                effectType: .none,
                                                requirementName: variableDecl.name,
                                                parameters: [],
                                                spyAccess: spyAccess,
                                                isStatic: isStatic
                                            )
                                        }
                                    )

                            })
                        )
                    )
                )

            }
        )
    }
    
    /// Generates a subscript declaration that fulfills a protocol requirement.
    ///
    /// For a subscript `subscript(index: Int) -> String { get }`, this will generate a subscript with a getter that calls the mock's `adapt` function.
    /// For a settable requirement, it also generates a setter that records the write —
    /// indices followed by `newValue` — on the `set` + capitalized-parameters spy.
    static func subscriptRequirement(
        _ subscriptDecl: SubscriptDeclSyntax,
        spyAccess: SpyAccess = .inherited
    ) -> SubscriptDeclSyntax {
        let parameterNames = subscriptDecl.parameterClause.parameters.map({ ExprSyntax(DeclReferenceExprSyntax(baseName: $0.secondName ?? $0.firstName)) })
        let isStatic = subscriptDecl.modifiers.contains(where: \.isStatic)
        return SubscriptDeclSyntax(
            attributes: subscriptDecl.attributes,
            modifiers: subscriptDecl.modifiers,
            genericParameterClause: subscriptDecl.genericParameterClause,
            parameterClause: subscriptDecl.parameterClause,
            returnClause: subscriptDecl.returnClause,
            genericWhereClause: subscriptDecl.genericWhereClause,
            accessorBlock: AccessorBlockSyntax(
                accessors: .accessors(
                    AccessorDeclListSyntax {
                        // Setter
                        if subscriptDecl.hasSetter {
                            AccessorDeclSyntax(
                                accessorSpecifier: .keyword(.set),
                                bodyBuilder: {
                                    ReturnStmtSyntax(
                                        expression: adaptCall(
                                            effectType: .none,
                                            requirementName: .identifier(subscriptDecl.name.setterSpyName),
                                            parameters: parameterNames + [ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier("newValue")))],
                                            spyAccess: spyAccess,
                                            isStatic: isStatic
                                        )
                                    )
                                }
                            )
                        }
                        // Getter
                        AccessorDeclSyntax(
                            accessorSpecifier: .keyword(.get),
                            bodyBuilder: {
                                ReturnStmtSyntax(
                                    expression: adaptCall(
                                        effectType: .none,
                                        requirementName: .identifier(subscriptDecl.name),
                                        parameters: parameterNames,
                                        spyAccess: spyAccess,
                                        isStatic: isStatic
                                    )
                                )
                            }
                        )
                    })
            )
        )
    }

    /// Generates the body of a function requirement.
    ///
    /// This function generates a `CodeBlockSyntax` that contains the appropriate `adapt` call based on the function's effects (async, throws).
    ///
    /// For a function `func doSomething() throws -> Int`, this will generate:
    /// ```swift
    /// { try adaptThrowing(super.doSomething) }
    /// ```
    static func functionRequirementBody(
        _ funcDecl: FunctionDeclSyntax,
        spyAccess: SpyAccess = .inherited
    ) -> CodeBlockSyntax {
        let effectType = getFunctionEffectType(funcDecl)
        // Typed-throws requirements bind the spy to an explicitly typed local first.
        // The adapter's error type `E` appears only in its `throws(E)` clause and in
        // the spy parameter's effect, and the spy itself comes from `Mock`'s generic
        // `@dynamicMemberLookup` subscript — so with nothing spelled, both the
        // subscript's `Eff` and the adapter's `E` stay open and the solver reports
        //   error: generic parameter 'E' could not be inferred
        // Spelling the spy's type anchors `Eff`, which determines `E`. This is the
        // same technique the settable-subscript interactions use for their write spy.
        let spyBinding = typedThrowsSpyBinding(funcDecl, effectType: effectType, spyAccess: spyAccess)
        let call = baseFunctionRequirementBody(
            funcDecl,
            spyAccess: spyAccess,
            spyIsLocalBinding: spyBinding != nil
        )
        // The `return` is load-bearing for `Void`-returning members under
        // `.composition`: without a contextual result type the solver cannot
        // infer `Output` for the generic spy subscript, and the compiler
        // reports a "failed to produce diagnostic" internal error rather than a
        // usable message.
        //
        // `try`/`await` are applied from the effect's own flags so the typed
        // cases (`throws(E)`, `async throws(E)`) get the same treatment as their
        // untyped counterparts without another pair of cases to keep in sync.
        var expression = ExprSyntax(call)
        if effectType.isAsync {
            expression = ExprSyntax(AwaitExprSyntax(expression: expression))
        }
        if effectType.isThrowing {
            expression = ExprSyntax(TryExprSyntax(expression: expression))
        }
        return CodeBlockSyntax {
            if let spyBinding {
                spyBinding
            }
            ReturnStmtSyntax(expression: expression)
        }
    }

    /// The local constant a typed-throws requirement binds its spy to.
    static let typedThrowsSpyBindingName = "typedSpy"

    /// Builds `let typedSpy: Spy<Inputs…, TypedThrows<E>, Output> = super.<name>` for a
    /// typed-throws requirement, or `nil` for every other effect.
    ///
    /// See ``functionRequirementBody(_:spyAccess:)`` for why the type must be spelled.
    private static func typedThrowsSpyBinding(
        _ funcDecl: FunctionDeclSyntax,
        effectType: EffectType,
        spyAccess: SpyAccess
    ) -> VariableDeclSyntax? {
        switch effectType {
        case .none, .async, .throws, .asyncThrows:
            return nil
        case .typedThrows, .asyncTypedThrows:
            break
        }

        // The spy's input pack mirrors the requirement's parameters, with variadics
        // widened to arrays and `Void` standing in for an empty pack — matching the
        // pack the generated `Interaction` spells and that `adapt` records on.
        // Attributes are stripped for the same reason `createInteractionReturnType`
        // strips them: `@escaping`/`@autoclosure` describe how a parameter is passed,
        // not the type itself, and `Spy<@escaping () -> Void, …>` does not parse. The
        // spy's pack must match the one the generated `Interaction` spells.
        let inputTypes = funcDecl.signature.parameterClause.parameters.map { parameter -> String in
            let type = parameter.ellipsis != nil
                ? TypeSyntax(ArrayTypeSyntax(element: parameter.type))
                : removeAttributes(parameter.type)
            return type.trimmedDescription
        }
        let outputType = funcDecl.signature.returnClause?.type.trimmedDescription ?? "Void"
        let arguments = (inputTypes.isEmpty ? ["Void"] : inputTypes)
            + [effectType.typeName, outputType]
        let spyType = TypeSyntax(stringLiteral: "Spy<\(arguments.joined(separator: ", "))>")

        return VariableDeclSyntax(
            bindingSpecifier: .keyword(.let, trailingTrivia: .space),
            bindings: PatternBindingListSyntax {
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(
                        identifier: .identifier(typedThrowsSpyBindingName)
                    ),
                    typeAnnotation: TypeAnnotationSyntax(
                        colon: .colonToken(trailingTrivia: .space),
                        type: spyType
                    ),
                    initializer: InitializerClauseSyntax(
                        equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                        value: spyAccess.spyReference(
                            funcDecl.name,
                            isStatic: funcDecl.modifiers.contains(where: \.isStatic)
                        )
                    )
                )
            }
        )
    }
    
    /// Generates the base function call for a function requirement body.
    ///
    /// This function creates a `FunctionCallExprSyntax` that calls the appropriate `adapt` function.
    private static func baseFunctionRequirementBody(
        _ functionDecl: FunctionDeclSyntax,
        spyAccess: SpyAccess = .inherited,
        spyIsLocalBinding: Bool = false
    ) -> FunctionCallExprSyntax {
        let effectType = getFunctionEffectType(functionDecl)
        return adaptCall(
            effectType: effectType,
            requirementName: functionDecl.name,
            parameters: functionDecl.signature.parameterClause.parameters
                .map({ ExprSyntax(DeclReferenceExprSyntax(baseName: $0.secondName ?? $0.firstName)) }),
            spyAccess: spyAccess,
            isStatic: functionDecl.modifiers.contains(where: \.isStatic),
            spyIsLocalBinding: spyIsLocalBinding
        )
    }

    /// Creates a call to the appropriate `adapt` function.
    ///
    /// This function constructs a `FunctionCallExprSyntax` for `adapt`, `adaptThrowing`, etc., based on the `EffectType`.
    ///
    /// For a function `myMethod(param1: Int)` with `effectType: .none`, this will generate:
    /// ```swift
    /// adapt(super.myMethod, param1)
    /// ```
    ///
    /// - Parameter spyIsLocalBinding: When `true`, the spy has already been bound to an
    ///   explicitly typed local (see ``typedThrowsSpyBindingName``), so the call passes
    ///   that constant instead of re-deriving the spy through `super.`.
    private static func adaptCall(
        effectType: EffectType,
        requirementName: TokenSyntax,
        parameters: [ExprSyntax],
        spyAccess: SpyAccess = .inherited,
        isStatic: Bool = false,
        spyIsLocalBinding: Bool = false
    ) -> FunctionCallExprSyntax {
        let adaptingName = effectType.adapterName
        return FunctionCallExprSyntax(
            calledExpression: spyAccess.adapterCallee(adaptingName),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {
                // super.myMethodName — or mock.myMethodName when composing, or the
                // typed local binding for typed-throws requirements.
                LabeledExprSyntax(
                    expression: spyIsLocalBinding
                        ? ExprSyntax(DeclReferenceExprSyntax(
                            baseName: .identifier(typedThrowsSpyBindingName)
                        ))
                        : spyAccess.spyReference(requirementName, isStatic: isStatic)
                )

                // param1, param2... — or () when the requirement has no
                // parameters, so the spy's input pack stays (Void) and matches
                // the pack spelled by the generated Interaction.
                if parameters.isEmpty {
                    LabeledExprSyntax(
                        expression: TupleExprSyntax(elements: LabeledExprListSyntax())
                    )
                } else {
                    for parameter in parameters {
                        LabeledExprSyntax(expression: parameter)
                    }
                }
            },
            rightParen: .rightParenToken()
        )
    }
}

