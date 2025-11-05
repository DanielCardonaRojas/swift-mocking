//
//  StubbingBuilder.swift
//  SwiftMocking
//
//  Created by Daniel Cardona
//

/// A result builder for collecting stub configurations in a declarative way.
///
/// This builder enables ergonomic stub setup using a closure syntax, which aligns
/// well with the AAA (Arrange-Act-Assert) test pattern. Instead of multiple separate
/// `when(...).thenReturn(...)` calls, you can group all stub configurations together.
///
/// Example:
/// ```swift
/// when {
///     mock.method1(.any).thenReturn(value1)
///     mock.method2(.equal(5)).thenReturn(value2)
///     mock.method3(.any).thenThrow(SomeError())
/// }
/// ```
@resultBuilder
public struct StubbingBuilder {
    public static func buildBlock(_ components: [any StubbingConfiguration]...) -> [any StubbingConfiguration] {
        var result = [[any StubbingConfiguration]]()
        for component in components {
            result.append(component)
        }
        return result.flatMap({ $0 })
    }

    public static func buildExpression(_ expression: any StubbingConfiguration) -> [any StubbingConfiguration] {
        [expression]
    }

    /// Automatically converts an Interaction into an Arrange for stubbing
    public static func buildExpression<each Input, Eff: Effect, Output>(_ interaction: Interaction<repeat each Input, Eff, Output>) -> [any StubbingConfiguration] {
        [when(interaction)]
    }

    /// Activates a ConfiguredInteraction by registering its stub with the spy
    public static func buildExpression<each Input, Eff: Effect, Output>(_ configured: ConfiguredInteraction<repeat each Input, Eff, Output>) -> [any StubbingConfiguration] {
        [configured.activate()]
    }

    public static func buildEither(first component: [any StubbingConfiguration]) -> [any StubbingConfiguration] {
        component
    }

    public static func buildEither(second component: [any StubbingConfiguration]) -> [any StubbingConfiguration] {
        component
    }

    public static func buildOptional(_ component: [any StubbingConfiguration]?) -> [any StubbingConfiguration] {
        component ?? []
    }
}
