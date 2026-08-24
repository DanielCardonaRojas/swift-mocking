//
//  Spy.swift
//  Witness
//
//  Created by Daniel Cardona on 3/07/25.
//
import Foundation

/// A ``Spy`` is a type that captures calls to a single method, enabling inspections.
///
/// You can use a ``Spy`` to verify that a method was called with specific arguments, or to check how many times it was called.
/// Spies are useful for testing interactions between objects.
///
/// ## Related Types
/// - ``Mock`` - Base class that manages and provides access to spies
/// - ``Stub`` - Defines behavior for method calls
/// - ``Interaction`` - Represents a method call for verification
/// - ``ArgMatcher`` - Matches method arguments with various criteria
///
/// All mutable state lives in lock-guarded boxes, so the `Sendable` conformance below is
/// checked rather than asserted. It is conditional: a spy is only safe to share when the
/// values it stores — recorded invocations and stubbed outputs — are themselves `Sendable`.
public final class Spy<each Input, Effects: Effect, Output>: AnySpy {
    /// Post-init configuration, read together on the invoke path.
    ///
    /// Grouping these in one box keeps a single acquisition serving all three, so logging
    /// cannot observe a torn configuration.
    private struct Configuration {
        var isLoggingEnabled = false
        var defaultProviderRegistry: DefaultProvidableRegistry?
        var logger: (@Sendable (Invocation<repeat each Input>) -> Void)?
    }

    private let configuration: UncheckedLockIsolated<Configuration>
    private let _invocations = UncheckedLockIsolated<[Invocation<repeat each Input>]>([])
    private let _stubs = UncheckedLockIsolated<[Stub<repeat each Input, Effects, Output>]>([])
    private let _actions = UncheckedLockIsolated<[Action<repeat each Input, Effects>]>([])

    /// A point-in-time snapshot of all ``Invocation``s captured by this spy.
    public var invocations: [Invocation<repeat each Input>] { snapshotInvocations() }

    public var isLoggingEnabled: Bool {
        get { configuration.withLock { $0.isLoggingEnabled } }
        set { configuration.withLock { $0.isLoggingEnabled = newValue } }
    }

    /// Unique identifier for this spy instance used for cross-spy verification
    public let spyID: UUID = UUID()

    /// Human-readable label for this spy, typically "ClassName.methodName"
    public let methodLabel: String?

    var stubs: [Stub<repeat each Input, Effects, Output>] { snapshotStubs() }

    var actions: [Action<repeat each Input, Effects>] {
        _actions.withLock { Array($0) }
    }

    public var defaultProviderRegistry: DefaultProvidableRegistry? {
        get { configuration.withLock { $0.defaultProviderRegistry } }
        set { configuration.withLock { $0.defaultProviderRegistry = newValue } }
    }

    var logger: (@Sendable (Invocation<repeat each Input>) -> Void)? {
        get { configuration.withLock { $0.logger } }
        set { configuration.withLock { $0.logger = newValue } }
    }

    public var invocationCount: Int {
        _invocations.withLock { $0.count }
    }

    func configureLogger(label: String) {
        logger = { invocation in
            print("\(label)\(invocation.debugDescription)")
        }
    }

    /// Initializes a new `Spy` instance.
    /// - Parameter label: An optional method name
    public init(label: String? = nil) {
        self.methodLabel = label
        self.configuration = UncheckedLockIsolated(
            Configuration(
                defaultProviderRegistry: MockScope.fallbackValueRegistry,
                logger: { invocation in
                    print("\(label ?? "")\(invocation.debugDescription)")
                }
            )
        )
    }

    /// Records an invocation and attempts to find a matching stub to return a value or throw an error.
    /// - Parameter input: The arguments of the invocation.
    /// - Returns: The ``Return`` value from the matching stub.
    /// - Throws: ``MockingError/unStubbed`` if no matching stub is found.
    @usableFromInline
    func invoke(_ input: repeat each Input) throws -> Return<Effects, Output> {
        let invocation = intake(repeat each input)

        // One acquisition for the whole prologue, so logging cannot observe a
        // half-applied reconfiguration.
        let (isLoggingEnabled, logger, registry) = configuration.withLock {
            ($0.isLoggingEnabled, $0.logger, $0.defaultProviderRegistry)
        }

        // Log invocations
        if isLoggingEnabled {
            logger?(invocation)
        }

        // search through stub for a return value

        let matchingStub = matchingStub(invocation: invocation)
        guard let returnValue = matchingStub?.returnValue(for: invocation) else {
            if let fallback = registry?.getDefaultForType(Output.self) {
                return .value(fallback)
            }

            throw MockingError.unStubbed(methodLabel, inputs: invocation.debugDescription)
        }

        return returnValue
    }


    private func intake(_ input: repeat each Input) -> Invocation<repeat each Input> {
        let invocation = Invocation(arguments: repeat each input)
        _invocations.withLock { $0.append(invocation) }

        // Record in global timeline for cross-spy verification
        var argumentsArray: [Any] = []
        for argument in repeat each input {
            argumentsArray.append(argument)
        }

        MockScope.invocationRecorder.record(
            spyID: self.spyID,
            invocationID: invocation.invocationID,
            methodLabel: self.methodLabel,
            arguments: argumentsArray
        )

        return invocation
    }

    /// Returns a deep, point-in-time copy of the recorded invocations.
    ///
    /// The copy is taken under the box's lock and uses `Array(...)` to disconnect its
    /// storage from `invocations`. Callers iterate it outside the lock without racing the
    /// appends in `intake` — a shallow `return invocations` would share CoW storage and
    /// race the array resize that `intake` triggers (the same hazard proven for `Mock`'s
    /// dictionary snapshot under Thread Sanitizer).
    private func snapshotInvocations() -> [Invocation<repeat each Input>] {
        _invocations.withLock { Array($0) }
    }

    /// Returns a deep, point-in-time copy of the registered stubs.
    ///
    /// The copy is taken under the box's lock and uses `Array(...)` to disconnect its
    /// storage from `stubs`. Callers match against it outside the lock without racing the appends
    /// in `createStub` (a shallow copy would share CoW storage with the same resize hazard).
    private func snapshotStubs() -> [Stub<repeat each Input, Effects, Output>] {
        _stubs.withLock { Array($0) }
    }

    private func matchingStub(invocation: Invocation<repeat each Input>) -> Stub<repeat each Input, Effects, Output>? {
        var matchingStub: Stub<repeat each Input, Effects, Output>?
        for stub in snapshotStubs().reversed().sorted(by: { $0.precedence > $1.precedence }) {
            if stub.invocationMatcher.isMatchedBy(invocation) {
                matchingStub = stub
                break
            }
        }
        return matchingStub
    }

    @usableFromInline
    func matchingAction(invocation: Invocation<repeat each Input>) -> Action<repeat each Input, Effects>? {
        for action in actions.reversed().sorted(by: { $0.precedence > $1.precedence }) {
            if action.invocationMatcher.isMatchedBy(invocation) {
                return action
            }
        }
        return nil
    }

    /// Defines a stubbing behavior for the spy when called with specific argument matchers.
    /// - Parameter matchingInput: A variadic list of ``ArgMatcher``s to match the input arguments.
    /// - Returns: A ``Stub`` instance to configure the return value or error.
    public func when(calledWith matchingInput: repeat ArgMatcher<each Input>) -> Arrange<repeat each Input, Effects, Output> {
        let interaction = Interaction(repeat each matchingInput, spy: self)
        return Arrange(interaction: interaction)
    }

    /// Defines a stubbing behavior for the spy when called with a specific invocation matcher.
    /// - Parameter invocationMatcher: An ``InvocationMatcher`` to match the input arguments.
    /// - Returns: A ``Stub`` instance to configure the return value or error.
    public func when(calledWith invocationMatcher: InvocationMatcher <repeat each Input>) -> Arrange<repeat each Input, Effects, Output> {
        let interaction = Interaction(invocationMatcher: invocationMatcher, spy: self)
        return Arrange(interaction: interaction)
    }

    func createStub(for invocationMatcher: InvocationMatcher<repeat each Input>) -> Stub<repeat each Input, Effects, Output> {
        let stub = Stub<repeat each Input, Effects, Output>(invocationMatcher: invocationMatcher)
        _stubs.withLock { $0.append(stub) }
        return stub
    }

    func registerAction(
        _ action: Action<repeat each Input, Effects>
    ) {
        _actions.withLock { $0.append(action) }
    }

    func removeAction(_ action: Action<repeat each Input, Effects>) {
        _actions.withLock { $0.removeAll { $0 === action } }
    }

    /// Available so that spies can be used with `when` and `verify`.
    public func callAsFunction(_ matchingInput: repeat ArgMatcher<each Input>) -> Interaction<repeat each Input, Effects, Output> {
        Interaction(repeat each matchingInput, spy: self)
    }

    /// Verifies that the spy's method was called at least once.
    /// - Parameter countMatcher: An optional ``ArgMatcher`` for `Int` to specify the expected call count. If `nil`, verifies at least one call.
    /// - Returns: `true` if the call count matches the criteria, `false` otherwise.
    public func verifyCalled(_ countMatcher: ArgMatcher<Int>? = nil) -> Bool {
        let matcher = countMatcher ?? .greaterThan(.zero)
        return matcher(invocationCount)
    }

    /// Verifies that the spy's method was called with specific arguments and a specific call count.
    /// - Parameters:
    ///   - arguments: A variadic list of ``ArgMatcher``s to match the input arguments.
    ///   - countMatcher: An ``ArgMatcher`` for `Int` to specify the expected call count.
    /// - Returns: `true` if the call matches the criteria, `false` otherwise.
    public func verify(calledWith arguments: repeat ArgMatcher<each Input>, count countMatcher: ArgMatcher<Int>) -> Bool {
        let invocationMatcher = InvocationMatcher(matchers: repeat each arguments)
        return verify(calledWith: invocationMatcher, count: countMatcher)
    }

    /// Verifies that the spy's method was called with a specific invocation matcher and a specific call count.
    /// - Parameters:
    ///   - invocationMatcher: An ``InvocationMatcher`` to match the input arguments.
    ///   - countMatcher: An ``ArgMatcher`` for `Int` to specify the expected call count.
    /// - Returns: `true` if the call matches the criteria, `false` otherwise.
    public func verify(calledWith invocationMatcher: InvocationMatcher<repeat each Input>, count countMatcher: ArgMatcher<Int>) -> Bool {
        let count = invocationCount(matching: invocationMatcher)
        return countMatcher(count)
    }

    /// Returns the number of invocations that match the given invocation matcher.
    /// - Parameter invocationMatcher: The ``InvocationMatcher`` to count matching invocations.
    /// - Returns: The number of matching invocations.
    func invocationCount(matching invocationMatcher: InvocationMatcher<repeat each Input>) -> Int {
        var count = 0
        for invocation in snapshotInvocations() {
            if invocationMatcher.isMatchedBy(invocation) {
                count += 1
            }
        }
        return count
    }

    /// Clear stubs and invocations, leaving the spy in a fresh state.
    ///
    /// Each collection is reset under its own lock so the reassignment cannot race the
    /// locked appends in `intake`/`createStub`/`registerAction`. No locks are nested.
    public func clear() {
        _stubs.withLock { $0 = [] }
        _actions.withLock { $0 = [] }
        _invocations.withLock { $0 = [] }
    }
}

extension Spy: Sendable where repeat each Input: Sendable, Output: Sendable { }

extension Spy {
    /// A `Sendable` handle over just this spy's action bookkeeping.
    ///
    /// Lets `until(_:timeout:)` await a call without requiring `Output: Sendable`; see
    /// ``SpyActionRegistering``.
    var actionRegistrar: any SpyActionRegistering {
        SpyActionRegistrar(spy: self)
    }
}

/// The concrete ``SpyActionRegistering`` handle, vended by ``Spy/actionRegistrar``.
///
/// ``Spy`` cannot conform to `SpyActionRegistering` itself: that protocol inherits
/// `Sendable`, and at this package's Swift 6.0 floor a type conforming to a
/// `Sendable`-inheriting protocol must be *unconditionally* `Sendable` — which `Spy`
/// deliberately is not. This non-generic class conforms instead, closing over the spy's
/// bookkeeping methods, so the conditional conformance survives.
///
/// The `@unchecked` annotation covers the captured spy. It is sound for the reason
/// ``SpyActionRegistering`` documents: the closures below reach only the spy's
/// lock-guarded action storage and never an `Input` or `Output` value.
final class SpyActionRegistrar: SpyActionRegistering, @unchecked Sendable {
    private let label: String?
    private let register: (AnyObject) -> Void
    private let remove: (AnyObject) -> Void

    init<each Input, Effects: Effect, Output>(spy: Spy<repeat each Input, Effects, Output>) {
        self.label = spy.methodLabel
        self.register = { action in
            guard let action = action as? Action<repeat each Input, Effects> else { return }
            spy.registerAction(action)
        }
        self.remove = { action in
            guard let action = action as? Action<repeat each Input, Effects> else { return }
            spy.removeAction(action)
        }
    }

    var actionMethodLabel: String? { label }

    func registerErasedAction(_ action: AnyObject) { register(action) }

    func removeErasedAction(_ action: AnyObject) { remove(action) }
}

// MARK: Throwing
extension Spy where Effects == Throws {
    /// Calls the spy's method, expecting it to throw an error.
    /// - Parameter input: The arguments for the method call.
    /// - Returns: The output of the method if it doesn't throw.
    /// - Throws: The error thrown by the method.
    @discardableResult
    public func callAsFunction(_ input: repeat each Input) throws -> Output {
        let invocation = Invocation(arguments: repeat each input)
        let action = matchingAction(invocation: invocation)
        let result = try invoke(repeat each input)
        if let action {
            try action.perform(invocation)
        }
        return try result.get()
    }

    public func asFunction() -> @Sendable (repeat each Input) throws -> Output
    where repeat each Input: Sendable, Output: Sendable {
        return { (args:  repeat each Input) in
            try self(repeat each args)
        }
    }

    /// A plain (non-`@Sendable`) function wrapper, available for any input and output.
    public func asFunction() -> (repeat each Input) throws -> Output {
        return { (args:  repeat each Input) in
            try self(repeat each args)
        }
    }

    /// Verifies that the spy's method threw an error matching the given `errorMatcher`.
    /// - Parameter errorMatcher: An ``ArgMatcher`` for `Error` to specify the expected error.
    /// - Returns: `true` if a matching error was thrown, `false` otherwise.
    public func verifyThrows(_ errorMatcher: ArgMatcher<any Error>) -> Bool {
        var doesThrow = false
        for invocation in snapshotInvocations() {
            for stub in snapshotStubs() where stub.invocationMatcher.isMatchedBy(invocation) {
                guard let stubbedReturn = stub.returnValue(for: invocation) else {
                    continue
                }
                switch stubbedReturn.resolve() {
                case .success:
                    break
                case .failure(let error):
                    doesThrow = doesThrow || errorMatcher(error)
                }
            }
        }
        return doesThrow
    }

    /// Verifies that the spy's method threw any error.
    /// - Returns: `true` if any error was thrown, `false` otherwise.
    public func verifyThrows() -> Bool {
        verifyThrows(.anyError())
    }
}

// MARK: Typed throwing
extension Spy where Effects: TypedThrowingEffect {
    /// Narrows a resolved failure to the effect's declared error type.
    ///
    /// A `Return` for a typed-throwing spy can hold two very different failures: an
    /// error the test stubbed (necessarily an `Effects.Failure`, because `thenThrow`
    /// only accepts one), or a ``MockingError`` raised by the framework for an
    /// unstubbed call. Only the former can cross a `throws(Failure)` boundary.
    ///
    /// The latter traps rather than propagating, matching how non-throwing spies
    /// (`Effects == None`, `Effects == Async`) already report an unstubbed call: the
    /// method's signature leaves no way to surface it, and an unstubbed call is a
    /// test-authoring mistake rather than a condition under test.
    private static func narrow(_ error: any Error) -> Effects.Failure {
        if let typed = error as? Effects.Failure {
            return typed
        }
        if let mockingError = error as? MockingError {
            fatalError("MockingError: \(mockingError.message)")
        }
        fatalError(
            """
            Spy stubbed with an error of type \(type(of: error)) but the requirement \
            is declared to throw \(Effects.Failure.self).
            """
        )
    }
}

// MARK: Typed throwing (synchronous)
extension Spy where Effects: SyncTypedThrowingEffect {
    /// Calls the spy's method, rethrowing the stubbed error as the declared error type.
    /// - Parameter input: The arguments for the method call.
    /// - Returns: The output of the method if it doesn't throw.
    /// - Throws: The stubbed error, typed as the requirement's declared error type.
    @discardableResult
    public func callAsFunction(_ input: repeat each Input) throws(Effects.Failure) -> Output {
        let invocation = Invocation(arguments: repeat each input)
        let action = matchingAction(invocation: invocation)
        let result: Return<Effects, Output>
        do {
            result = try invoke(repeat each input)
        } catch {
            throw Self.narrow(error)
        }
        if let action {
            do {
                try action.perform(invocation)
            } catch {
                throw Self.narrow(error)
            }
        }
        switch result.resolve() {
        case .success(let value):
            return value
        case .failure(let error):
            throw Self.narrow(error)
        }
    }

    public func asFunction() -> @Sendable (repeat each Input) throws(Effects.Failure) -> Output
    where repeat each Input: Sendable, Output: Sendable {
        return { (args: repeat each Input) throws(Effects.Failure) in
            try self(repeat each args)
        }
    }

    /// A plain (non-`@Sendable`) function wrapper, available for any input and output.
    public func asFunction() -> (repeat each Input) throws(Effects.Failure) -> Output {
        return { (args: repeat each Input) throws(Effects.Failure) in
            try self(repeat each args)
        }
    }

    /// Verifies that the spy's method threw an error matching the given `errorMatcher`.
    /// - Parameter errorMatcher: An ``ArgMatcher`` for `Error` to specify the expected error.
    /// - Returns: `true` if a matching error was thrown, `false` otherwise.
    public func verifyThrows(_ errorMatcher: ArgMatcher<any Error>) -> Bool {
        var doesThrow = false
        for invocation in snapshotInvocations() {
            for stub in snapshotStubs() where stub.invocationMatcher.isMatchedBy(invocation) {
                guard let stubbedReturn = stub.returnValue(for: invocation) else {
                    continue
                }
                switch stubbedReturn.resolve() {
                case .success:
                    break
                case .failure(let error):
                    doesThrow = doesThrow || errorMatcher(error)
                }
            }
        }
        return doesThrow
    }

    /// Verifies that the spy's method threw any error.
    /// - Returns: `true` if any error was thrown, `false` otherwise.
    public func verifyThrows() -> Bool {
        verifyThrows(.anyError())
    }
}

// MARK: Typed throwing (asynchronous)
extension Spy where Effects: AsyncTypedThrowingEffect {
    /// Calls the spy's method asynchronously, rethrowing the stubbed error as the
    /// declared error type.
    /// - Parameter input: The arguments for the method call.
    /// - Returns: The output of the method if it doesn't throw.
    /// - Throws: The stubbed error, typed as the requirement's declared error type.
    @discardableResult
    public func callAsFunction(_ input: repeat each Input) async throws(Effects.Failure) -> Output {
        let invocation = Invocation(arguments: repeat each input)
        let action = matchingAction(invocation: invocation)
        let result: Return<Effects, Output>
        do {
            result = try invoke(repeat each input)
        } catch {
            throw Self.narrow(error)
        }
        if let action {
            do {
                try await action.perform(invocation)
            } catch {
                throw Self.narrow(error)
            }
        }
        switch await result.resolveAsync() {
        case .success(let value):
            return value
        case .failure(let error):
            throw Self.narrow(error)
        }
    }

    public func asFunction() -> @Sendable (repeat each Input) async throws(Effects.Failure) -> Output
    where repeat each Input: Sendable, Output: Sendable {
        return { (args: repeat each Input) async throws(Effects.Failure) in
            try await self(repeat each args)
        }
    }

    /// A plain (non-`@Sendable`) function wrapper, available for any input and output.
    public func asFunction() -> (repeat each Input) async throws(Effects.Failure) -> Output {
        return { (args: repeat each Input) async throws(Effects.Failure) in
            try await self(repeat each args)
        }
    }

    /// Verifies that the spy's method threw an error matching the given `errorMatcher`.
    /// - Parameter errorMatcher: An ``ArgMatcher`` for `Error` to specify the expected error.
    /// - Returns: `true` if a matching error was thrown, `false` otherwise.
    public func verifyThrows(_ errorMatcher: ArgMatcher<any Error>) async -> Bool {
        var doesThrow = false
        for invocation in snapshotInvocations() {
            for stub in snapshotStubs() where stub.invocationMatcher.isMatchedBy(invocation) {
                guard let stubbedReturn = stub.returnValue(for: invocation) else {
                    continue
                }
                switch await stubbedReturn.resolveAsync() {
                case .success:
                    break
                case .failure(let error):
                    doesThrow = doesThrow || errorMatcher(error)
                }
            }
        }
        return doesThrow
    }

    /// Verifies that the spy's method threw any error.
    /// - Returns: `true` if any error was thrown, `false` otherwise.
    public func verifyThrows() async -> Bool {
        await verifyThrows(.anyError())
    }
}

// MARK: None throwing
extension Spy where Effects == None {
    /// Calls the spy's method, expecting it not to throw an error.
    ///
    /// When invoked directly (rather than through a generated conformance) the defaulted
    /// location parameters capture the caller's own file and line, so an unstubbed call
    /// is attributed to the calling test.
    /// - Parameter input: The arguments for the method call.
    /// - Returns: The output of the method.
    /// - FatalError: If the method throws an error.
    @inlinable
    @inline(__always)
    @discardableResult
    public func callAsFunction(
        _ input: repeat each Input,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) -> Output {
        do {
            return try process(repeat each input)
        } catch {
            reportUnrecoverable(
                error,
                fileID: fileID,
                filePath: filePath,
                line: line,
                column: column
            )
        }
    }

    @usableFromInline
    func process(_ input: repeat each Input) throws -> Output {
        let invocation = Invocation(arguments: repeat each input)
        let action = matchingAction(invocation: invocation)
        let returnValue = try invoke(repeat each input)
        if let action {
            action.perform(invocation)
        }
        return returnValue.get()
    }


    public func asFunction() -> @Sendable (repeat each Input) -> Output
    where repeat each Input: Sendable, Output: Sendable {
        return { (args:  repeat each Input) in
            self(repeat each args)
        }
    }

    /// A plain (non-`@Sendable`) function wrapper, available for any input and output.
    public func asFunction() -> (repeat each Input) -> Output {
        return { (args:  repeat each Input) in
            self(repeat each args)
        }
    }
}

// MARK: Async
extension Spy where Effects == Async {
    /// Calls the spy's method asynchronously.
    /// - Parameter input: The arguments for the method call.
    /// - Returns: The output of the method.
    /// - FatalError: If the method throws an error, as `Async` effects are not expected to throw.
    @inlinable
    @inline(__always)
    @discardableResult
    public func callAsFunction(
        _ input: repeat each Input,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) async -> Output {
        do {
            return try await process(repeat each input)
        } catch {
            reportUnrecoverable(
                error,
                fileID: fileID,
                filePath: filePath,
                line: line,
                column: column
            )
        }
    }

    @usableFromInline
    func process(_ input: repeat each Input) async throws -> Output {
        let invocation = Invocation(arguments: repeat each input)
        let action = matchingAction(invocation: invocation)
        let returnValue = try invoke(repeat each input)
        if let action {
            await action.perform(invocation)
        }
        return await returnValue.get()
    }

    public func asFunction() -> @Sendable (repeat each Input) async -> Output
    where repeat each Input: Sendable, Output: Sendable {
        return { (args:  repeat each Input) in
            await self(repeat each args)
        }
    }

    /// A plain (non-`@Sendable`) function wrapper, available for any input and output.
    public func asFunction() -> (repeat each Input) async -> Output {
        return { (args:  repeat each Input) in
            await self(repeat each args)
        }
    }
}

// MARK: AsyncThrows
extension Spy where Effects == AsyncThrows {
    /// Calls the spy's method asynchronously, allowing it to throw an error.
    /// - Parameter input: The arguments for the method call.
    /// - Returns: The output of the method if it doesn't throw.
    /// - Throws: The error thrown by the method.
    @discardableResult
    public func callAsFunction(_ input: repeat each Input) async throws -> Output {
        let invocation = Invocation(arguments: repeat each input)
        let action = matchingAction(invocation: invocation)
        let returnValue = try invoke(repeat each input)
        if let action {
            try await action.perform(invocation)
        }
        return try await returnValue.get()
    }

    public func asFunction() -> @Sendable (repeat each Input) async throws -> Output
    where repeat each Input: Sendable, Output: Sendable {
        return { (args:  repeat each Input) in
            try await self(repeat each args)
        }
    }

    /// A plain (non-`@Sendable`) function wrapper, available for any input and output.
    public func asFunction() -> (repeat each Input) async throws -> Output {
        return { (args:  repeat each Input) in
            try await self(repeat each args)
        }
    }

    /// Verifies that the spy's method threw an error matching the given `errorMatcher`.
    /// - Parameter errorMatcher: An ``ArgMatcher`` for `Error` to specify the expected error.
    /// - Returns: `true` if a matching error was thrown, `false` otherwise.
    public func verifyThrows(_ errorMatcher: ArgMatcher<any Error>) async -> Bool {
        var doesThrow = false
        for invocation in snapshotInvocations() {
            for stub in snapshotStubs() where stub.invocationMatcher.isMatchedBy(invocation) {
                guard let stubbedReturn = stub.returnValue(for: invocation) else {
                    continue
                }
                let resolved = await stubbedReturn.resolveAsync()
                switch resolved {
                case .success:
                    break
                case .failure(let error):
                    doesThrow = doesThrow || errorMatcher(error)
                }
            }
        }
        return doesThrow
    }

    /// Verifies that the spy's method threw any error.
    /// - Returns: `true` if any error was thrown, `false` otherwise.
    public func verifyThrows() async -> Bool {
        await verifyThrows(.anyError())
    }
}
