import XCTest

import fastscanTests

var tests = [XCTestCaseEntry]()
tests += fastscanTests.allTests()
XCTMain(tests)
