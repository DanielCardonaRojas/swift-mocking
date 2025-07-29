
import XCTest
@testable import SwiftMocking

final class MetatypeParserTests: XCTestCase {
    func testParseSimpleType() {
        let parsedType = MetatypeParser.parse(Int.self)
        XCTAssertEqual(parsedType.name, "Int")
        XCTAssertTrue(parsedType.genericArguments.isEmpty)
    }

    func testParseGenericType() {
        let parsedType = MetatypeParser.parse(Array<String>.self)
        XCTAssertEqual(parsedType.name, "Array")
        XCTAssertEqual(parsedType.genericArguments.count, 1)
        XCTAssertEqual(parsedType.genericArguments[0].name, "String")
    }

    func testParseNestedGenericType() {
        let parsedType = MetatypeParser.parse(Dictionary<String, Array<Int>>.self)
        XCTAssertEqual(parsedType.name, "Dictionary")
        XCTAssertEqual(parsedType.genericArguments.count, 2)
        XCTAssertEqual(parsedType.genericArguments[0].name, "String")
        XCTAssertEqual(parsedType.genericArguments[1].name, "Array")
        XCTAssertEqual(parsedType.genericArguments[1].genericArguments.count, 1)
        XCTAssertEqual(parsedType.genericArguments[1].genericArguments[0].name, "Int")
    }

    func testParseComplexNestedGenericType() {
        typealias ComplexType = Result<[String: (Int, String)], Error>
        let parsedType = MetatypeParser.parse(ComplexType.self)
        XCTAssertEqual(parsedType.name, "Result")
        XCTAssertEqual(parsedType.genericArguments.count, 2)
        XCTAssertEqual(parsedType.genericArguments[0].name, "Dictionary")
        XCTAssertEqual(parsedType.genericArguments[0].genericArguments.count, 2)
        XCTAssertEqual(parsedType.genericArguments[0].genericArguments[0].name, "String")
        XCTAssertEqual(parsedType.genericArguments[0].genericArguments[1].name, "(Int, String)")
        XCTAssertEqual(parsedType.genericArguments[1].name, "Error")
    }
}
