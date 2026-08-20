import Foundation
import Darwin

struct TestSuite {
    private(set) var assertions = 0
    private(set) var failures: [String] = []

    mutating func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        if !condition() { failures.append(message) }
    }

    mutating func expectThrows(_ message: String, operation: () throws -> Void) {
        assertions += 1
        do {
            try operation()
            failures.append(message)
        } catch { }
    }

    func finish(layer: String) -> Never {
        if failures.isEmpty {
            print("✓ \(layer): \(assertions) assertions passed")
            Darwin.exit(EXIT_SUCCESS)
        }
        print("✗ \(layer): \(failures.count) of \(assertions) assertions failed")
        failures.forEach { print("  - \($0)") }
        Darwin.exit(EXIT_FAILURE)
    }
}

enum TestFiles {
    static func temporaryDirectory(named name: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CleanSweepTests-\(name)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func createFile(at url: URL, bytes: Int = 64, modified: Date? = nil) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: bytes).write(to: url)
        if let modified {
            try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        }
    }

    static func createExtension(at root: URL, publisher: String, name: String, version: String) throws -> URL {
        let directory = root.appendingPathComponent("\(publisher).\(name)-\(version)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let manifest: [String: Any] = ["publisher": publisher, "name": name, "version": version]
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted])
        try data.write(to: directory.appendingPathComponent("package.json"))
        return directory
    }

    static func createApplication(at url: URL, identifier: String, name: String) throws {
        let contents = url.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "CFBundleIdentifier": identifier,
            "CFBundleName": name,
            "CFBundlePackageType": "APPL",
            "CFBundleVersion": "1"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
    }
}
