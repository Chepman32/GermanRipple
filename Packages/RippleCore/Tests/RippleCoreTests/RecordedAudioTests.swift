import Foundation
import Testing
@testable import ContentKit

private actor RecordingTransport: ContentTransport {
  let data: Data
  private(set) var requests = 0
  init(_ data: Data) { self.data = data }
  func fetch(_ url: URL) async throws -> Data {
    requests += 1
    return data
  }
}

@Suite("Verified recording cache") struct RecordedAudioTests {
  private func fixture(_ label: String) -> (RecordedClip, Data) {
    let data = Data([0x49, 0x44, 0x33, 0]) + Data(label.utf8)
    let hash = ContentUpdater.sha256(data)
    return (RecordedClip(text: label, sha256: hash,
      path: "/content/de-en/v2/audio/\(hash).mp3", bytes: data.count), data)
  }

  @Test func catalogRejectsTamperedTextUnsafePathsAndVersionMismatch() throws {
    let (clip, _) = fixture("Wir hören zu.")
    let encoder = JSONEncoder()
    let catalog = RecordedAudioCatalog(packVersion: 2, clips: [RecordedClip.textID(clip.text): clip])
    let decoded = try RecordedAudioCatalog.decode(encoder.encode(catalog))
    #expect(decoded.clip(for: "Wir hören zu.") == clip)
    #expect(decoded.clip(for: "Wir hören nicht zu.") == nil)
    var wrong = catalog
    wrong.clips = [RecordedClip.textID("Different sentence."): clip]
    #expect(throws: ContentError.self) { try RecordedAudioCatalog.decode(encoder.encode(wrong)) }
    wrong = catalog
    wrong.packVersion = 3
    #expect(throws: ContentError.self) { try RecordedAudioCatalog.decode(encoder.encode(wrong)) }
    var unsafe = clip
    unsafe.path = "https://other.example/audio.mp3"
    #expect(throws: ContentError.self) { try unsafe.validated() }
    unsafe.path = "/content/de-en/v2/audio/../\(clip.sha256).mp3"
    #expect(throws: ContentError.self) { try unsafe.validated() }
    #expect(throws: ContentError.self) { try clip.url(relativeTo: URL(string: "http://example.test")!) }
    #expect(RecordedClip.textID("Mädchen") == RecordedClip.textID("Ma\u{0308}dchen"))
  }

  @Test func verifiedCacheWorksOfflineAndRepairsCorruption() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let (clip, data) = fixture("Wir lernen Deutsch.")
    let transport = RecordingTransport(data)
    let cache = RecordedAudioCache(root: root, transport: transport)
    #expect(try await cache.cachedFile(for: clip) == nil)
    let file = try #require(await cache.fetch(clip, from: URL(string: "https://lessons.example.test")!))
    #expect(try Data(contentsOf: file) == data)
    _ = try await cache.fetch(clip, from: URL(string: "https://lessons.example.test")!)
    #expect(await transport.requests == 1)
    try Data(repeating: 0, count: data.count).write(to: file)
    #expect(try await cache.cachedFile(for: clip) == nil)
    _ = try await cache.fetch(clip, from: URL(string: "https://lessons.example.test")!)
    #expect(await transport.requests == 2)
  }

  @Test func wrongBytesNeverBecomePlayableAndCacheEvictsOnlyAudio() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let (first, firstData) = fixture("First sentence.")
    let bad = RecordedAudioCache(root: root, transport: RecordingTransport(Data("<html>bad</html>".utf8)))
    await #expect(throws: ContentError.self) {
      try await bad.fetch(first, from: URL(string: "https://lessons.example.test")!)
    }
    #expect(try await bad.cachedFile(for: first) == nil)
    let good = RecordedAudioCache(root: root, maxBytes: first.bytes, transport: RecordingTransport(firstData))
    _ = try await good.fetch(first, from: URL(string: "https://lessons.example.test")!)
    let note = root.appendingPathComponent("keep.txt")
    try Data("unrelated file".utf8).write(to: note)
    let (second, secondData) = fixture("Next sentence.")
    let next = RecordedAudioCache(root: root, maxBytes: first.bytes, transport: RecordingTransport(secondData))
    _ = try await next.fetch(second, from: URL(string: "https://lessons.example.test")!)
    #expect(try await next.cachedFile(for: first) == nil)
    #expect(try await next.cachedFile(for: second) != nil)
    #expect(FileManager.default.fileExists(atPath: note.path))
  }
}
