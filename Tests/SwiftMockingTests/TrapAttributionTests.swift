//
//  TrapAttributionTests.swift
//  swift-mocking
//

import XCTest
@testable import SwiftMocking

/// Guards the inlining attributes that make an unstubbed, non-throwing call debuggable.
///
/// When a non-throwing requirement has no stub and no registered default there is nothing to
/// return, so ``reportUnrecoverable`` reports the issue and then traps. Which stack frame the
/// trap is attributed to — the frame Xcode's stack navigator selects — depends on every frame
/// between the user's call and `fatalError` being `@_transparent`, which inlines them before
/// the optimizer runs. A merely `@inlinable` frame leaves itself on the stack, and the
/// debugger then lands the user inside SwiftMocking instead of on their own call.
///
/// The behavior itself cannot be asserted in-process: `fatalError` takes the process down, and
/// the crash *message* stays correct even when the attribution regresses, because it is built
/// from location arguments that are forwarded explicitly. `Examples`' `ErrorReportingTests`
/// pins the real behavior by running a probe executable under `lldb`.
///
/// These tests are the cheap, fast guard for the same invariant: they read the source and fail
/// if any of the six entry points on the unrecoverable path loses `@_transparent`. That keeps
/// a regression detectable without a debugger, and localizes it to the declaration at fault.
final class TrapAttributionTests: XCTestCase {

    /// Declarations that reach ``reportUnrecoverable`` and must therefore be `@_transparent`.
    ///
    /// Spelled as (file, declaration) pairs rather than matched by a broad regex so that a
    /// newly added entry point is a deliberate addition here, not something a pattern silently
    /// absorbs.
    private static let requiredTransparentDeclarations: [(file: String, declaration: String)] = [
        // `Spy.callAsFunction` — invoked directly, e.g. `spy(3)`.
        ("Spy.swift", "public func callAsFunction("),
        // `Mock.adapt` — invoked from a generated conformance. Static and instance overloads
        // exist for both the synchronous and asynchronous effects, hence four declarations.
        ("Mock+Adapters.swift", "static func adapt<each I, O>("),
        ("Mock+Adapters.swift", "func adapt<each I, O>("),
    ]

    func testEveryUnrecoverableEntryPointIsTransparent() throws {
        for (file, declaration) in Self.requiredTransparentDeclarations {
            let source = try Self.source(of: file)
            let declarationRanges = source.ranges(of: declaration)

            XCTAssertFalse(
                declarationRanges.isEmpty,
                """
                Could not find '\(declaration)' in \(file). If it was renamed, update \
                `requiredTransparentDeclarations` so this guard keeps covering it.
                """
            )

            for range in declarationRanges {
                // Only the overloads that actually trap need the attribute; the throwing ones
                // surface an unstubbed call as a thrown error instead. Detected by looking for
                // the call in the body rather than by signature, since the adapters no longer
                // take a source location — a generated conformance has nowhere to get one.
                let body = source[range.lowerBound...]
                guard body.prefix(600).contains("reportUnrecoverable(") else { continue }

                let attributes = source[..<range.lowerBound]
                XCTAssertTrue(
                    Self.isTransparent(attributes),
                    """
                    '\(declaration)' in \(file) reaches reportUnrecoverable but is not \
                    @_transparent, so a trap on the unstubbed path will be attributed to \
                    SwiftMocking instead of to the caller. See reportUnrecoverable's docs.
                    """
                )
            }
        }
    }

    /// `reportUnrecoverable` itself must be `@_transparent`, for the same reason.
    func testReportUnrecoverableIsTransparent() throws {
        let source = try Self.source(of: "SourceLocation.swift")
        let range = try XCTUnwrap(
            source.range(of: "func reportUnrecoverable("),
            "reportUnrecoverable was renamed; update this guard."
        )

        XCTAssertTrue(
            Self.isTransparent(source[..<range.lowerBound]),
            """
            reportUnrecoverable is not @_transparent, so the trap will be attributed to \
            SwiftMocking's own frame rather than to the calling code.
            """
        )
    }

    /// The closure-producing helpers must capture the location where the closure is built.
    ///
    /// `asFunction` returns a closure that calls back into `callAsFunction`. If it does not
    /// capture and forward a location, that call supplies its own defaults — expanded inside
    /// `Spy.swift` — and an unstubbed call made through a closure-based dependency is
    /// reported against SwiftMocking's own source.
    ///
    /// `@_transparent` cannot help here the way it does for the direct and conformance
    /// routes: the closure runs long after `asFunction` returns, so there is no caller frame
    /// to inline into. The captured location is the only attribution available, which is why
    /// it is guarded separately.
    func testClosureProducingHelpersCaptureTheirLocation() throws {
        let source = try Self.source(of: "Spy.swift")

        // Only the non-throwing effects reach the trap; the throwing ones surface an
        // unstubbed call as a thrown error and need no location.
        for effect in ["None", "Async"] {
            let block = try XCTUnwrap(
                Self.extensionBody(of: "extension Spy where Effects == \(effect) {", in: source),
                "Could not find the `Effects == \(effect)` extension in Spy.swift."
            )

            let declarations = block.ranges(of: "public func asFunction(")
            XCTAssertFalse(
                declarations.isEmpty,
                "Expected asFunction overloads in the `Effects == \(effect)` extension."
            )

            for range in declarations {
                let signature = block[range.lowerBound...].prefix(400)
                XCTAssertTrue(
                    signature.contains("fileID: StaticString = #fileID"),
                    """
                    An `asFunction` overload for `Effects == \(effect)` does not capture a \
                    source location, so a closure-based dependency built from it reports \
                    unstubbed calls against SwiftMocking instead of the injection site.
                    """
                )
            }
        }
    }

    /// The free `adapt` functions must forward the location they capture.
    ///
    /// They are the documented way to build a closure dependency (`Client(load: adapt(spy))`),
    /// so a location captured here but dropped before `asFunction` is as bad as not capturing
    /// one at all.
    func testClosureAdaptersForwardTheirLocation() throws {
        let source = try Self.source(of: "SpyAdapters.swift")

        var checked = 0
        for range in source.ranges(of: "spy.asFunction(") {
            // Only the non-throwing effects trap, and only those capture a location to
            // forward. The throwing overloads surface an unstubbed call as a thrown error,
            // so they legitimately call `asFunction()` bare.
            let declaration = source[..<range.lowerBound]
            guard let signatureStart = declaration.range(
                of: "public func adapt", options: .backwards
            ) else { continue }
            let signature = declaration[signatureStart.lowerBound...]
            guard signature.contains(", None, Output>") || signature.contains(", Async, Output>")
            else { continue }

            checked += 1
            let call = source[range.lowerBound...].prefix(120)
            XCTAssertTrue(
                call.contains("fileID: fileID"),
                """
                A non-throwing `adapt` overload calls `spy.asFunction()` without forwarding \
                its captured location, so the closure falls back to defaults expanded inside \
                Spy.swift.
                """
            )
        }

        XCTAssertGreaterThan(
            checked, 0,
            """
            Found no non-throwing `adapt` overloads delegating to `asFunction`. If the \
            adapters were restructured, update this guard so it keeps covering them.
            """
        )
    }

    /// The trap must pass `fileID`, not `filePath`.
    ///
    /// `fatalError`'s output is the `file:` string verbatim, and only `#fileID` carries the
    /// `Module/File.swift` form that resolves to a source location; `#filePath` is an absolute
    /// path. Both render plausibly, which is what let this regress unnoticed before.
    func testTrapIsGivenTheFileIDNotTheFilePath() throws {
        let source = try Self.source(of: "SourceLocation.swift")

        XCTAssertTrue(
            source.contains("fatalError(message, file: fileID, line: line)"),
            """
            The trap in reportUnrecoverable must be given `fileID`. Passing `filePath` \
            produces a location that does not resolve back to the user's source.
            """
        )
    }

    // MARK: - Helpers

    /// Whether the attributes immediately preceding a declaration include `@_transparent`.
    ///
    /// Scoped to the trailing run of attribute and documentation lines so an unrelated
    /// `@_transparent` earlier in the file cannot satisfy the check.
    private static func isTransparent(_ precedingSource: Substring) -> Bool {
        var lines = Array(precedingSource.split(separator: "\n", omittingEmptySubsequences: false))

        // `static func adapt(...)` also contains `func adapt(...)`, so a match can land
        // mid-line. Drop the partial trailing line; its modifiers are not attributes.
        if let last = lines.last, !last.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.removeLast()
        }

        for line in lines.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("@_transparent") { return true }
            // Keep walking past other attributes, doc comments, and blank lines.
            if trimmed.isEmpty || trimmed.hasPrefix("@") || trimmed.hasPrefix("//") { continue }
            // Anything else means the declaration's own attribute list has ended.
            return false
        }
        return false
    }

    /// Returns the body of the extension introduced by `header`, up to its closing brace.
    ///
    /// Scoping the search matters: `Spy.swift` declares `asFunction` for every effect, and a
    /// file-wide search could satisfy a check for one effect with a declaration belonging to
    /// another. Brace counting is enough here because these extensions contain balanced code
    /// and no braces inside string literals.
    private static func extensionBody(of header: String, in source: String) -> Substring? {
        guard let start = source.range(of: header) else { return nil }

        var depth = 0
        var index = start.upperBound
        // `header` includes the opening brace.
        depth = 1

        while index < source.endIndex {
            switch source[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return source[start.upperBound..<index] }
            default: break
            }
            index = source.index(after: index)
        }
        return nil
    }

    /// Reads a SwiftMocking source file, located relative to this test file.
    ///
    /// Uses `#filePath` rather than a bundle resource: these files are library sources, not
    /// test fixtures, so they are not copied into the test bundle.
    private static func source(of fileName: String, testFile: StaticString = #filePath) throws -> String {
        let sourcesDirectory = URL(fileURLWithPath: "\(testFile)")
            // Tests/SwiftMockingTests/TrapAttributionTests.swift
            .deletingLastPathComponent()  // SwiftMockingTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root
            .appendingPathComponent("Sources/SwiftMocking")
            .appendingPathComponent(fileName)

        return try String(contentsOf: sourcesDirectory, encoding: .utf8)
    }
}
