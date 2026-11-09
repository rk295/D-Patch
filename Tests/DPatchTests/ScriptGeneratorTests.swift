@testable import DPatch
import XCTest

final class ScriptGeneratorTests: XCTestCase {
    private func fix(_ method: FixMethod, _ target: String, toVersion: String = "2.0") -> Fix {
        Fix(method: method, target: target, toVersion: toVersion, summary: "test fix")
    }

    private func finding(id: String, method: FixMethod, target: String,
                         toVersion: String = "2.0", name: String? = nil) -> Finding {
        let cve = CVERecord(id: id, published: Date(timeIntervalSince1970: 0),
                            lastModified: Date(timeIntervalSince1970: 0),
                            severity: .high, score: 8.1, vector: "AV:N/AC:L", summary: "test",
                            references: [], ranges: [])
        let item = InventoryItem(kind: .formula, name: name ?? target, version: "1.0",
                                 aliases: [], vendorHint: nil, bundleID: nil, path: nil,
                                 caskToken: nil, latestVersion: nil)
        return Finding(cve: cve, item: item, fixedIn: toVersion, fix: fix(method, target, toVersion: toVersion))
    }

    func testShellQuote() {
        XCTAssertEqual(ScriptGenerator.shellQuote("ffmpeg"), "'ffmpeg'")
        XCTAssertEqual(ScriptGenerator.shellQuote("it's"), "'it'\\''s'")
        XCTAssertEqual(ScriptGenerator.shellQuote("a b"), "'a b'")
    }

    func testCommandsPerMethod() {
        XCTAssertEqual(ScriptGenerator.command(for: fix(.brewFormula, "ffmpeg")),
                       "brew upgrade --formula 'ffmpeg'")
        XCTAssertEqual(ScriptGenerator.command(for: fix(.brewCask, "firefox")),
                       "brew upgrade --cask --greedy 'firefox'")
        XCTAssertEqual(ScriptGenerator.command(for: fix(.brewCaskReplace, "firefox")),
                       "brew install --cask --force 'firefox'")
        XCTAssertEqual(ScriptGenerator.command(for: fix(.appStore, "12345")),
                       "mas upgrade '12345'")
        XCTAssertEqual(ScriptGenerator.command(for: fix(.softwareUpdate, "macOS Tahoe 26.7")),
                       "sudo /usr/sbin/softwareupdate --install 'macOS Tahoe 26.7'")
    }

    func testCommandsUseCustomToolPaths() {
        XCTAssertEqual(ScriptGenerator.command(for: fix(.brewFormula, "ffmpeg"), brew: "\"$BREW\"", mas: "\"$MAS\""),
                       "\"$BREW\" upgrade --formula 'ffmpeg'")
        XCTAssertEqual(ScriptGenerator.command(for: fix(.appStore, "12345"), brew: "\"$BREW\"", mas: "\"$MAS\""),
                       "\"$MAS\" upgrade '12345'")
    }

    func testDeduplicatesFixesByMethodAndTarget() {
        let findings = [finding(id: "CVE-1", method: .brewFormula, target: "ffmpeg"),
                        finding(id: "CVE-2", method: .brewFormula, target: "ffmpeg"),
                        finding(id: "CVE-3", method: .brewFormula, target: "pillow")]
        XCTAssertEqual(ScriptGenerator.fixes(for: findings).map(\.target), ["ffmpeg", "pillow"])
    }

    func testKeepsOnlyNewestMacOSUpdate() {
        let findings = [finding(id: "CVE-1", method: .softwareUpdate, target: "macOS Sonoma 14.5", toVersion: "14.5", name: "macOS"),
                        finding(id: "CVE-2", method: .softwareUpdate, target: "macOS Sonoma 14.6", toVersion: "14.6", name: "macOS")]
        XCTAssertEqual(ScriptGenerator.fixes(for: findings).map(\.target), ["macOS Sonoma 14.6"])
    }

    func testOrdersFixesByMethodThenTarget() {
        let findings = [finding(id: "CVE-1", method: .softwareUpdate, target: "macOS Sonoma 14.6", name: "macOS"),
                        finding(id: "CVE-2", method: .appStore, target: "12345", name: "Some App"),
                        finding(id: "CVE-3", method: .brewCask, target: "firefox", name: "Firefox"),
                        finding(id: "CVE-4", method: .brewFormula, target: "tesseract")]
        XCTAssertEqual(ScriptGenerator.fixes(for: findings).map(\.target),
                       ["tesseract", "firefox", "12345", "macOS Sonoma 14.6"])
    }

    func testScriptOmitsConfirmationWhenNotRequested() {
        let script = ScriptGenerator.script(for: [finding(id: "CVE-1", method: .brewFormula, target: "ffmpeg")],
                                            confirm: false)
        XCTAssertTrue(script.hasPrefix("#!/usr/bin/env bash"))
        XCTAssertFalse(script.contains("Continue? [y/N]"))
        XCTAssertTrue(script.contains("run \"$BREW\" upgrade --formula 'ffmpeg'"))
        XCTAssertTrue(script.hasSuffix("\n"))
    }
}
