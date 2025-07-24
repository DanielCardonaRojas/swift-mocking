//
//  XCTestCase+Extensions.swift
//  Mockable
//
//  Created by Daniel Cardona on 6/07/25.
//

import IssueReporting

// MARK: Mockito utilities

public func when<each Input, Eff: Effect, Output>(_ interaction: Interaction<repeat each Input, Eff, Output>) -> Stub<repeat each Input, Eff, Output> {
    interaction.spy.when(calledWith: interaction.invocationMatcher)
}

public func verify<each Input, Eff: Effect, Output>(
    _ interaction: Interaction<repeat each Input, Eff, Output>
) -> Assert<repeat each Input, Eff, Output>  {
    Assert(invocationMatcher: interaction.invocationMatcher, spy: interaction.spy)
}

public func verifyInOrder<each Input, Eff: Effect, Output>(
    _ interactions: [Interaction<repeat each Input, Eff, Output>],
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let spy = interactions[0].spy
    var matchers = [InvocationMatcher<repeat each Input>]()
    for interaction in interactions {
        matchers.append(interaction.invocationMatcher)
    }

    if !spy.verifyInOrder(matchers) {
        reportIssue("Did not find sequence of interactions", filePath: file, line: line)
    }
}

// MARK: Asserts

public extension Assert {
    func called(
        _ countMatcher: ArgMatcher<Int>? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            try self.assert(countMatcher)
        } catch let error as MockingError {
            reportIssue("\(error.message)", filePath: file, line: line)
        } catch {
            reportIssue("\(error.localizedDescription)", filePath: file, line: line)
        }
    }

}

public extension Assert where Eff: Throwing {
    func `throws`(
        _ errorMatcher: ArgMatcher<any Error>? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            try doesThrow(errorMatcher)
        } catch let error as MockingError {
            reportIssue("\(error.message)", filePath: file, line: line)
        } catch {
            reportIssue("\(error.localizedDescription)", filePath: file, line: line)
        }
    }
}
