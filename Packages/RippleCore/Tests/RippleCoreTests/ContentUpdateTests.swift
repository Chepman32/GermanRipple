import Foundation
import RippleEngine
import Testing

@testable import ContentKit

private actor FixtureTransport: ContentTransport {
  var files: [String: Data]
  var requests: [String] = []
  init(_ files: [String: Data]) { self.files = files }
  func fetch(_ url: URL) async throws -> Data {
    requests.append(url.path)
    guard let data = files[url.path] else { throw ContentError.transport }
    return data
  }
  func replace(_ path: String, data: Data) { files[path] = data }
}

@Suite("Atomic content updates") struct ContentUpdateTests {
  @Test func malformedContentIsRejectedBeforeIndexingTokens() throws {
    var pack = try fixture()
    pack.chains[0].base.tokens.append(pack.chains[0].base.tokens[0])
    #expect(throws: ContentError.self) { try ContentLint.validate(pack) }
    pack = try fixture()
    pack.chains[0].steps[0].tokens = []
    pack.chains[0].steps[0].acceptedOrders = [[]]
    #expect(throws: ContentError.self) { try ContentLint.validate(pack) }
    pack = try fixture()
    pack.chains[0].steps[0].tokens[0].text = "Not an authored form"
    #expect(throws: ContentError.self) { try ContentLint.validate(pack) }
  }
  private func server(version: Int = 2) throws -> ([String: Data], ContentPack) {
    var pack = try fixture()
    pack.version = version
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let rules = try encoder.encode(["rules": pack.rules])
    let lexicon = try encoder.encode(["lexicon": pack.lexicon])
    let unit = try encoder.encode(["chains": pack.chains])
    func ref(_ path: String, _ data: Data) -> [String: String] {
      ["path": path, "sha256": ContentUpdater.sha256(data)]
    }
    let index = try JSONSerialization.data(withJSONObject: [
      "packId": "de-en", "version": version, "schemaVersion": 1,
      "reviewStatus": "pending-native-review", "units": [ref("/content/unit.json", unit)],
    ])
    let descriptor: [String: Any] = [
      "packId": "de-en", "version": version, "minAppVersion": "1.0.0",
      "index": ref("/content/index.json", index), "rules": ref("/content/rules.json", rules),
      "lexicon": ref("/content/lexicon.json", lexicon),
    ]
    let manifest = try JSONSerialization.data(withJSONObject: [
      "schemaVersion": 1, "generatedAt": "2026-11-07T12:00:00Z", "packs": [descriptor],
    ])
    return (
      [
        "/content/manifest.json": manifest, "/content/index.json": index,
        "/content/rules.json": rules, "/content/lexicon.json": lexicon, "/content/unit.json": unit,
      ], pack
    )
  }
  @Test func validatedUpdateCommitsAndFailedNextVersionKeepsCurrent() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let (files, _) = try server()
    let transport = FixtureTransport(files)
    let updater = ContentUpdater(
      root: root, baseURL: URL(string: "https://lessons.example.test")!, transport: transport)
    let result = try await updater.update(currentVersion: 1, appVersion: "1.0.0")
    #expect(result?.version == 2)
    #expect(try await updater.installed()?.version == 2)
    let (next, _) = try server(version: 3)
    for (path, data) in next { await transport.replace(path, data: data) }
    // New version's metadata still points at the original hash, while bytes are corrupt.
    await transport.replace("/content/unit.json", data: Data("bad unit".utf8))
    // Existing content-addressed unit is valid and may be reused. Corrupt the index,
    // whose version changed, to exercise integrity failure before the atomic commit.
    await transport.replace("/content/index.json", data: Data("bad index".utf8))
    await #expect(throws: ContentError.self) {
      try await updater.update(currentVersion: 2, appVersion: "1.0.0")
    }
    #expect(try await updater.installed()?.version == 2)
  }
  @Test func unsafeReferenceAndIncompatibleAppNeverCommit() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    var (files, _) = try server()
    var manifest =
      try JSONSerialization.jsonObject(with: files["/content/manifest.json"]!) as! [String: Any]
    var packs = manifest["packs"] as! [[String: Any]]
    packs[0]["minAppVersion"] = "9.0.0"
    manifest["packs"] = packs
    files["/content/manifest.json"] = try JSONSerialization.data(withJSONObject: manifest)
    let transport = FixtureTransport(files)
    let updater = ContentUpdater(
      root: root, baseURL: URL(string: "https://lessons.example.test")!, transport: transport)
    await #expect(throws: ContentError.incompatibleVersion) {
      try await updater.update(currentVersion: 1, appVersion: "1.0.0")
    }
    packs[0]["minAppVersion"] = "1.0.0"
    packs[0]["index"] = [
      "path": "https://other.example.test/x", "sha256": String(repeating: "a", count: 64),
    ]
    manifest["packs"] = packs
    await transport.replace(
      "/content/manifest.json", data: try JSONSerialization.data(withJSONObject: manifest))
    await #expect(throws: ContentError.unsafePath) {
      try await updater.update(currentVersion: 1, appVersion: "1.0.0")
    }
    #expect(try await updater.installed() == nil)
  }
  @Test func rolloutUsesStableHashAndEventuallyReleasesToEveryone() {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    #expect(
      ContentUpdater.rolloutAllowed(
        installID: "x", announcedAt: date, now: date.addingTimeInterval(7 * 86400)))
    #expect(
      ContentUpdater.rolloutAllowed(installID: "x", announcedAt: date, now: date)
        == ContentUpdater.rolloutAllowed(installID: "x", announcedAt: date, now: date))
  }
}
