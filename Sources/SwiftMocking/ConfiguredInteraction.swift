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

// MARK: - None Effect Stubbing

public extension ConfiguredInteraction where Eff == None {
    /// Configures the stub to return a specific value.
    @discardableResult
    func thenReturn(_ output: Output) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        stub.thenReturn(output)
        return self
    }

    /// Configures the stub to compute return values dynamically based on input arguments.
    @discardableResult
    func thenReturn(_ handler: @escaping (repeat each Input) -> Output) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        stub.thenReturn(handler)
        return self
    }

    /// Configures the stub to execute a side effect without changing the return value.
    @discardableResult
    func `do`(_ handler: @escaping (repeat each Input) -> Void) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        let action = Action<repeat each Input, Eff>(invocationMatcher: interaction.invocationMatcher)
        action.do(handler)
        interaction.spy.registerAction(action)
        return self
    }
}

// MARK: - Throws Effect Stubbing

public extension ConfiguredInteraction where Eff == Throws {
    /// Configures the stub to return a specific value.
    @discardableResult
    func thenReturn(_ output: Output) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        stub.thenReturn(output)
        return self
    }

    /// Configures the stub to throw a specific error.
    @discardableResult
    func thenThrow<E: Error>(_ error: E) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        stub.thenThrow(error)
        return self
    }

    /// Configures the stub to compute return values dynamically, potentially throwing.
    @discardableResult
    func thenReturn(_ handler: @escaping (repeat each Input) throws -> Output) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        stub.thenReturn(handler)
        return self
    }

    /// Configures the stub to execute a side effect, potentially throwing.
    @discardableResult
    func `do`(_ handler: @escaping (repeat each Input) throws -> Void) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        let action = Action<repeat each Input, Eff>(invocationMatcher: interaction.invocationMatcher)
        action.do(handler)
        interaction.spy.registerAction(action)
        return self
    }
}

// MARK: - Async Effect Stubbing

public extension ConfiguredInteraction where Eff == Async {
    /// Configures the stub to return a specific value.
    @discardableResult
    func thenReturn(_ output: Output) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        stub.thenReturn(output)
        return self
    }

    /// Configures the stub to compute return values asynchronously.
    @discardableResult
    func thenReturn(_ handler: @escaping (repeat each Input) async -> Output) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        stub.thenReturn(handler)
        return self
    }

    /// Configures the stub to execute an asynchronous side effect.
    @discardableResult
    func `do`(_ handler: @escaping (repeat each Input) async -> Void) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        let action = Action<repeat each Input, Eff>(invocationMatcher: interaction.invocationMatcher)
        action.do(handler)
        interaction.spy.registerAction(action)
        return self
    }
}

// MARK: - AsyncThrows Effect Stubbing

public extension ConfiguredInteraction where Eff == AsyncThrows {
    /// Configures the stub to return a specific value.
    @discardableResult
    func thenReturn(_ output: Output) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        stub.thenReturn(output)
        return self
    }

    /// Configures the stub to throw a specific error.
    @discardableResult
    func thenThrow<E: Error>(_ error: E) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        stub.thenThrow(error)
        return self
    }

    /// Configures the stub to compute return values asynchronously, potentially throwing.
    @discardableResult
    func thenReturn(_ handler: @escaping (repeat each Input) async throws -> Output) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        stub.thenReturn(handler)
        return self
    }

    /// Configures the stub to execute an asynchronous side effect, potentially throwing.
    @discardableResult
    func `do`(_ handler: @escaping (repeat each Input) async throws -> Void) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        let action = Action<repeat each Input, Eff>(invocationMatcher: interaction.invocationMatcher)
        action.do(handler)
        interaction.spy.registerAction(action)
        return self
    }
}

// MARK: - Void Return Convenience

public extension ConfiguredInteraction where Output == Void, Eff == None {
    /// Convenience alias for `thenReturn` when the output is Void.
    @discardableResult
    func then(_ handler: @escaping (repeat each Input) -> Void) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        thenReturn(handler)
    }
}

public extension ConfiguredInteraction where Output == Void, Eff == Throws {
    /// Convenience alias for `thenReturn` when the output is Void.
    @discardableResult
    func then(_ handler: @escaping (repeat each Input) throws -> Void) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        thenReturn(handler)
    }
}

public extension ConfiguredInteraction where Output == Void, Eff == Async {
    /// Convenience alias for `thenReturn` when the output is Void.
    @discardableResult
    func then(_ handler: @escaping (repeat each Input) async -> Void) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        thenReturn(handler)
    }
}

public extension ConfiguredInteraction where Output == Void, Eff == AsyncThrows {
    /// Convenience alias for `thenReturn` when the output is Void.
    @discardableResult
    func then(_ handler: @escaping (repeat each Input) async throws -> Void) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        thenReturn(handler)
    }
}
