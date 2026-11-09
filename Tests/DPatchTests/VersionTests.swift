@testable import DPatch
import XCTest

final class VersionTests: XCTestCase {
    func testParsesPlainVersion() {
        let v = Version("1.2.3")
        XCTAssertEqual(v?.parts, [.num(1), .num(2), .num(3)])
        XCTAssertEqual(v?.description, "1.2.3")
    }

    func testStripsPrefixBuildAndRevision() {
        XCTAssertEqual(Version("v2.0-rc1")?.parts, [.num(2), .num(0), .str("rc"), .num(1)])
        XCTAssertEqual(Version("4.95.0,242831")?.parts, [.num(4), .num(95), .num(0)])
        XCTAssertEqual(Version("3.5.1_1")?.parts, [.num(3), .num(5), .num(1)])
        XCTAssertEqual(Version("  1.0  ")?.parts, [.num(1), .num(0)])
    }

    func testRejectsStringsWithoutLeadingNumber() {
        XCTAssertNil(Version("abc"))
        XCTAssertNil(Version("rc1"))
        XCTAssertNil(Version(""))
    }

    func testComparesNumerically() {
        XCTAssertTrue(Version.isLess("1.2.3", "1.2.10"))
        XCTAssertFalse(Version.isLess("1.2.10", "1.2.3"))
        // Missing parts count as zero, so these are equal.
        XCTAssertFalse(Version.isLess("1.2", "1.2.0"))
        XCTAssertFalse(Version.isLess("1.2.0", "1.2"))
    }

    func testPrereleaseSortsBeforeRelease() {
        XCTAssertTrue(Version.isLess("1.0rc1", "1.0"))
        XCTAssertFalse(Version.isLess("1.0", "1.0rc1"))
    }

    func testUnparseableSortsFirst() {
        XCTAssertTrue(Version.isLess("not a version", "1.0"))
        XCTAssertFalse(Version.isLess("1.0", "not a version"))
        XCTAssertFalse(Version.isLess("nope", "nada"))
    }

    func testFirstToken() {
        XCTAssertEqual(Version.firstToken(in: "1.18.0 or later"), "1.18.0")
        XCTAssertEqual(Version.firstToken(in: "fixed in 2.4.1."), "2.4.1")
        XCTAssertNil(Version.firstToken(in: "no digits at all"))
    }

    func testNormalizeName() {
        XCTAssertEqual(normalizeName("Visual Studio Code"), "visualstudiocode")
        XCTAssertEqual(normalizeName("visual-studio-code"), normalizeName("Visual Studio Code"))
    }
}
