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
}

public extension Assert {
    func called(
        _ countMatcher: ArgMatcher<Int>? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if !inspect(countMatcher) {
            XCTFail("Unfulfilled method call count", file: file, line: line)
        }
    }

}
#endif
