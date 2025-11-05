//
//  ConfiguredInteraction.swift
//  SwiftMocking
//
//  Created by Daniel Cardona
//

/// A wrapper that holds an Interaction with a configured but unregistered Stub.
///
/// `ConfiguredInteraction` bridges the gap between creating a stub (via Interaction)
/// and registering it with the spy. It holds both the interaction (which has the spy reference)
/// and the configured stub, allowing activation to register the stub when ready.
///
/// ## Usage
/// Users should not create `ConfiguredInteraction` instances directly. They are created
/// automatically when calling stubbing methods on `Interaction` objects within `when { }` blocks:
///
/// ```swift
/// when {
///     mock.method(.any).thenReturn(value)  // Returns ConfiguredInteraction
/// }
/// ```
///
/// ## Related Types
/// - ``Interaction`` - Creates ConfiguredInteraction instances via stubbing methods
/// - ``Stub`` - The configured stub held by ConfiguredInteraction
/// - ``StubbingBuilder`` - Activates ConfiguredInteraction instances via buildExpression
public struct ConfiguredInteraction<each Input, Eff: Effect, Output> {
    let interaction: Interaction<repeat each Input, Eff, Output>
    let stub: Stub<repeat each Input, Eff, Output>

    internal init(
        interaction: Interaction<repeat each Input, Eff, Output>,
        stub: Stub<repeat each Input, Eff, Output>
    ) {
        self.interaction = interaction
        self.stub = stub
    }

    /// Activates the configured stub by registering it with the spy and returning an Arrange.
    ///
    /// This method should only be called from `when()` or within the `when { }` builder.
    internal func activate() -> Arrange<repeat each Input, Eff, Output> {
        interaction.spy.registerStub(stub)
        return Arrange(interaction: interaction)
    }
}
