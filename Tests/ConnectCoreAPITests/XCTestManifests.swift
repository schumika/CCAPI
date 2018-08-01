import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(ConnectCoreAPITests.allTests),
    ]
}
#endif