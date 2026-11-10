import Foundation

public struct RecordedClip: Codable, Sendable, Equatable {
  public var text: String
  public var sha256: String
  public var path: String
  public var bytes: Int

  public init(text: String, sha256: String, path: String, bytes: Int) {
    self.text = text
    self.sha256 = sha256
    self.path = path
    self.bytes = bytes
  }

  public static func textID(_ text: String) -> String {
    ContentUpdater.sha256(Data(text.precomposedStringWithCanonicalMapping.utf8))
  }

  public func validated() throws -> Self {
    let hex = CharacterSet(charactersIn: "0123456789abcdef")
    guard !text.isEmpty, text.count <= 4_000, sha256.count == 64,
      sha256.unicodeScalars.allSatisfy(hex.contains), (4...2_000_000).contains(bytes),
      path.range(of: #"^/content/de-en/v[1-9][0-9]*/audio/[0-9a-f]{64}\.mp3$"#,
        options: .regularExpression) != nil,
      path.hasSuffix("/\(sha256).mp3")
    else { throw ContentError.invalid("Invalid recorded audio reference") }
    return self
  }

  public func url(relativeTo origin: URL) throws -> URL {
    _ = try validated()
    guard origin.scheme == "https", origin.host != nil, origin.user == nil,
      origin.password == nil, origin.query == nil, origin.fragment == nil,
      let url = URL(string: path, relativeTo: origin)?.absoluteURL,
      url.scheme == origin.scheme, url.host == origin.host, url.port == origin.port
    else { throw ContentError.invalid("Unsafe audio origin") }
    return url
  }
}

public struct RecordedAudioCatalog: Codable, Sendable {
  public var schemaVersion: Int
  public var packVersion: Int
  public var clips: [String: RecordedClip]

  public init(packVersion: Int, clips: [String: RecordedClip] = [:]) {
    schemaVersion = 1
    self.packVersion = packVersion
    self.clips = clips
  }

  public static func decode(_ data: Data) throws -> Self {
    guard data.count <= 5_000_000 else { throw ContentError.invalid("Audio catalog too large") }
    let value = try JSONDecoder().decode(Self.self, from: data)
    guard value.schemaVersion == 1, value.packVersion > 0, value.clips.count <= 10_000 else {
      throw ContentError.invalid("Unsupported audio catalog")
    }
    for (key, clip) in value.clips {
      _ = try clip.validated()
      guard key == RecordedClip.textID(clip.text),
        clip.path.hasPrefix("/content/de-en/v\(value.packVersion)/audio/")
      else { throw ContentError.invalid("Mismatched audio text or version") }
    }
    return value
  }

  public func clip(for text: String) -> RecordedClip? {
    clips[RecordedClip.textID(text)]
  }
}

/// Recordings are disposable cache files, separate from learning data. A miss
/// never prevents speech: the app starts device TTS and fills this cache later.
public actor RecordedAudioCache {
  private let root: URL
  private let transport: any ContentTransport
  private let maxBytes: Int
  private var fetching = Set<String>()

  public init(root: URL, maxBytes: Int = 20_000_000,
    transport: any ContentTransport = URLContentTransport()) {
    self.root = root
    self.maxBytes = max(4, maxBytes)
    self.transport = transport
  }

  public func cachedFile(for clip: RecordedClip) throws -> URL? {
    _ = try clip.validated()
    let file = root.appendingPathComponent(clip.sha256 + ".mp3")
    guard FileManager.default.fileExists(atPath: file.path) else { return nil }
    let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    guard size == clip.bytes else {
      try? FileManager.default.removeItem(at: file)
      return nil
    }
    let data = try Data(contentsOf: file)
    guard ContentUpdater.sha256(data) == clip.sha256, Self.isMP3(data) else {
      try? FileManager.default.removeItem(at: file)
      return nil
    }
    try? FileManager.default.setAttributes([.modificationDate: Date.now], ofItemAtPath: file.path)
    return file
  }

  @discardableResult public func fetch(_ clip: RecordedClip, from origin: URL) async throws -> URL? {
    if let file = try cachedFile(for: clip) { return file }
    let url = try clip.url(relativeTo: origin)
    guard clip.bytes <= maxBytes, !fetching.contains(clip.sha256) else { return nil }
    fetching.insert(clip.sha256)
    defer { fetching.remove(clip.sha256) }
    let data = try await transport.fetch(url)
    try Task.checkCancellation()
    guard data.count == clip.bytes, ContentUpdater.sha256(data) == clip.sha256, Self.isMP3(data)
    else { throw ContentError.integrity }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let file = root.appendingPathComponent(clip.sha256 + ".mp3")
    try data.write(to: file, options: .atomic)
    try evict(keeping: file)
    return file
  }

  private func evict(keeping kept: URL) throws {
    let files = try FileManager.default.contentsOfDirectory(at: root,
      includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
      .filter { $0.pathExtension == "mp3" }
    var sizes = [(URL, Int, Date)]()
    for file in files {
      let values = try file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
      sizes.append((file, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast))
    }
    var total = sizes.reduce(0) { $0 + $1.1 }
    for item in sizes.sorted(by: { $0.2 < $1.2 }) where total > maxBytes && item.0 != kept {
      try FileManager.default.removeItem(at: item.0)
      total -= item.1
    }
  }

  private static func isMP3(_ data: Data) -> Bool {
    guard data.count >= 4 else { return false }
    let bytes = Array(data.prefix(3))
    return bytes == [0x49, 0x44, 0x33] || (bytes[0] == 0xff && bytes[1] & 0xe0 == 0xe0)
  }
}
