//
//  XCTestCase+Extensions.swift
//  Mockable
//
//  Created by Daniel Cardona on 6/07/25.
//

#if canImport(XCTest)
import XCTest

public extension XCTestCase {
    func when<each Input, Eff: Effect, Output>(_ interaction: Interaction<repeat each Input, Eff, Output>) -> Stub<repeat each Input, Eff, Output> {
        interaction.spy.when(calledWith: interaction.invocationMatcher)
    }

    func verify<each Input, Eff: Effect, Output>(
        _ interaction: Interaction<repeat each Input, Eff, Output>
    ) -> Assert<repeat each Input, Eff, Output>  {
        Assert(invocationMatcher: interaction.invocationMatcher, spy: interaction.spy)
    }

    func verifyInOrder<each Input, Eff: Effect, Output>(
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
            XCTFail("Did not find sequence of interactions", file: file, line: line)
        }
    }
}

public extension Assert {
    func called(
        _ countMatcher: ArgMatcher<Int>? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            try assert(countMatcher)
        } catch let error as MockingError {
            XCTFail("\(error.message)", file: file, line: line)
        } catch {
            XCTFail("\(error.localizedDescription)", file: file, line: line)
        }
    }

    func `throws`(
        _ errorMatcher: ArgMatcher<any Error>? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            try doesThrow(errorMatcher)
        } catch let error as MockingError {
            XCTFail("\(error.message)", file: file, line: line)
        } catch {
            XCTFail("\(error.localizedDescription)", file: file, line: line)
        }
    }
}
#endif
