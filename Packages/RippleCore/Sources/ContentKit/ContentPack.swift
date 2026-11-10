import CryptoKit
import Foundation
import RippleEngine

public struct ContentPack: Codable, Sendable {
  public var schemaVersion: Int
  public var packId: String
  public var version: Int
  public var rules: [Rule]
  public var lexicon: [Lexeme]
  public var chains: [Chain]
  public var reviewStatus: String
  public var lexiconByLemma: [String: Lexeme] {
    Dictionary(lexicon.map { ($0.lemma, $0) }, uniquingKeysWith: { first, _ in first })
  }
  public init(
    schemaVersion: Int = 1, packId: String = "de-en", version: Int = 1, rules: [Rule],
    lexicon: [Lexeme], chains: [Chain], reviewStatus: String = "pending-native-review"
  ) {
    self.schemaVersion = schemaVersion
    self.packId = packId
    self.version = version
    self.rules = rules
    self.lexicon = lexicon
    self.chains = chains
    self.reviewStatus = reviewStatus
  }
  public static func decode(_ data: Data) throws -> Self {
    let pack = try JSONDecoder().decode(Self.self, from: data)
    try ContentLint.validate(pack)
    return pack
  }
}

public enum ContentError: Error, Equatable, LocalizedError {
  case invalid(String)
  case integrity, transport, incompatibleVersion, unsafePath
  public var errorDescription: String? {
    switch self {
    case .invalid(let reason): "The lesson pack could not be opened: \(reason)"
    case .integrity: "The lesson pack did not pass its integrity check."
    case .transport:
      "The lesson update could not be downloaded. Your current lessons are ready offline."
    case .incompatibleVersion: "This lesson pack needs a newer version of Ripple."
    case .unsafePath: "The lesson update contained an invalid file address."
    }
  }
}

public enum ContentLint {
  public static func validate(_ pack: ContentPack) throws {
    func require(_ condition: Bool, _ message: String) throws {
      if !condition { throw ContentError.invalid(message) }
    }
    try require(
      pack.schemaVersion == 1 && pack.version > 0 && pack.packId == "de-en", "Unsupported pack")
    try require(
      !pack.chains.isEmpty && pack.chains.count <= 2000 && pack.rules.count <= 200,
      "Invalid pack size")
    let ids = Set(pack.rules.map(\.id))
    try require(ids.count == pack.rules.count, "Duplicate rule ID")
    try require(Set(pack.chains.map(\.id)).count == pack.chains.count, "Duplicate chain ID")
    for rule in pack.rules {
      try require(Set(rule.prerequisites).isSubset(of: ids), "Unknown prerequisite for \(rule.id)")
      try require(!(rule.explainer["en"] ?? "").isEmpty, "Missing explainer")
    }
    let byID = Dictionary(uniqueKeysWithValues: pack.rules.map { ($0.id, $0) })
    var visited = Set<String>()
    var visiting = Set<String>()
    func visit(_ id: String) throws {
      guard !visited.contains(id) else { return }
      try require(!visiting.contains(id), "Cyclic prerequisites")
      visiting.insert(id)
      for parent in byID[id]?.prerequisites ?? [] { try visit(parent) }
      visiting.remove(id)
      visited.insert(id)
    }
    for id in ids { try visit(id) }
    let lexicon = pack.lexiconByLemma
    for chain in pack.chains {
      try require(
        !chain.steps.isEmpty && chain.steps.count <= 12, "Invalid step count: \(chain.id)")
      try require(
        !chain.base.tokens.isEmpty && chain.base.tokens.count <= 32, "Invalid base sentence")
      try require(
        Set(chain.base.tokens.map(\.id)).count == chain.base.tokens.count, "Duplicate base token ID"
      )
      try require(
        chain.base.tokens.allSatisfy { !$0.id.isEmpty && $0.id.count <= 64 && !$0.text.isEmpty },
        "Invalid base token")
      var previous = chain.base.tokens
      for step in chain.steps {
        let targetIDs = Set(step.tokens.map(\.id))
        let oldIDs = Set(previous.map(\.id))
        try require(
          targetIDs.count == step.tokens.count && step.tokens.count <= 40
            && step.tokens.contains { $0.pos != "PUNCT" }, "Duplicate, empty or excessive tokens")
        try require(
          !step.acceptedOrders.isEmpty && step.acceptedOrders.count <= 24, "Missing accepted order")
        try require(
          step.acceptedOrders.allSatisfy { $0.count == targetIDs.count && Set($0) == targetIDs },
          "Invalid accepted order")
        try require(
          step.ruleIDs.isSubset(of: ids) && !step.ruleIDs.isEmpty, "Unknown or missing rule")
        try require(!(step.gloss["en"] ?? "").isEmpty, "Missing translation")
        try require(
          Set((step.fixes + step.moves).map(\.token)).isSubset(of: targetIDs),
          "Unknown dependency token")
        try require(Set(step.fixes.map(\.token)).count == step.fixes.count, "Duplicate fix")
        try require(
          oldIDs.subtracting(targetIDs).isEmpty
            || [.delete, .transform, .substitute].contains(step.card.type), "Undeclared removal")
        let old = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })
        for token in step.tokens {
          try require(
            !token.id.isEmpty && token.id.count <= 64 && !token.text.isEmpty
              && token.text.count <= 80, "Invalid token")
          if token.pos != "PUNCT" {
            try require(
              lexicon[token.lemma ?? token.text]?.forms.contains(token.text) == true,
              "Unknown token form")
          }
          if let prior = old[token.id], prior.lemma != token.lemma {
            try require(
              step.card.directIDs.contains(token.id)
                || step.fixes.contains(where: { $0.token == token.id }), "Unexplained lemma change")
          }
          let changed =
            old[token.id].map { $0.text != token.text }
            ?? ((token.initial ?? token.text) != token.text || token.spawned == true)
          if changed && !step.card.directIDs.contains(token.id) {
            try require(
              step.fixes.contains { $0.token == token.id }, "Missing fix: \(chain.id)/\(token.id)")
          }
        }
        for fix in step.fixes {
          guard let token = step.tokens.first(where: { $0.id == fix.token }) else { continue }
          for distractor in fix.distractors ?? [] {
            try require(
              Validator.normalized(distractor) != Validator.normalized(token.text),
              "Distractor equals answer")
            try require(
              lexicon[token.lemma ?? token.text]?.forms.contains(distractor) == true,
              "Unknown distractor: \(distractor)")
          }
        }
        previous = step.tokens
      }
    }
  }
}

public struct FileReference: Codable, Equatable, Sendable {
  public var path: String
  public var sha256: String
  public init(path: String, sha256: String) {
    self.path = path
    self.sha256 = sha256
  }
}
public struct PackDescriptor: Codable, Sendable {
  public var packId: String
  public var version: Int
  public var minAppVersion: String
  public var index: FileReference
  public var rules: FileReference
  public var lexicon: FileReference
}
public struct ContentManifest: Codable, Sendable {
  public var schemaVersion: Int
  public var generatedAt: String
  public var packs: [PackDescriptor]
}
public struct PackIndex: Codable, Sendable {
  public var packId: String
  public var version: Int
  public var schemaVersion: Int
  public var reviewStatus: String
  public var units: [FileReference]
}

public protocol ContentTransport: Sendable { func fetch(_ url: URL) async throws -> Data }
public struct URLContentTransport: ContentTransport {
  public init() {}
  public func fetch(_ url: URL) async throws -> Data {
    var request = URLRequest(url: url)
    request.timeoutInterval = 20
    let (bytes, response) = try await URLSession.shared.bytes(for: request)
    guard let response = response as? HTTPURLResponse, response.statusCode == 200,
      response.url?.host == url.host, response.url?.port == url.port,
      response.url?.scheme == "https",
      response.expectedContentLength <= 5_000_000
    else { throw ContentError.transport }
    var data = Data()
    for try await byte in bytes {
      guard data.count < 5_000_000 else { throw ContentError.transport }
      data.append(byte)
    }
    return data
  }
}

public actor ContentUpdater {
  private let root: URL
  private let baseURL: URL
  private let transport: any ContentTransport
  private var updating = false
  public init(root: URL, baseURL: URL, transport: any ContentTransport = URLContentTransport()) {
    self.root = root
    self.baseURL = baseURL
    self.transport = transport
  }
  public static func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
  public static func rolloutAllowed(
    installID: String, announcedAt: Date, now: Date, calendar: Calendar = .current
  ) -> Bool {
    if now.timeIntervalSince(announcedAt) >= 7 * 86_400 { return true }
    return Int(SeededRandom.hash(installID) % 7) == (calendar.component(.weekday, from: now) - 1)
  }
  public func installed() throws -> ContentPack? {
    let pointer = root.appendingPathComponent("active.json")
    guard FileManager.default.fileExists(atPath: pointer.path) else { return nil }
    let version = try JSONDecoder().decode(Int.self, from: Data(contentsOf: pointer))
    guard version > 0 else { throw ContentError.invalid("Invalid active version") }
    do {
      return try ContentPack.decode(
        Data(contentsOf: root.appendingPathComponent("v\(version)/pack.json")))
    } catch {
      let previous = try JSONDecoder().decode(
        Int.self, from: Data(contentsOf: root.appendingPathComponent("previous.json")))
      guard previous > 0, previous != version else { throw error }
      return try ContentPack.decode(
        Data(contentsOf: root.appendingPathComponent("v\(previous)/pack.json")))
    }
  }
  private func url(_ path: String) throws -> URL {
    guard baseURL.scheme == "https", baseURL.user == nil, baseURL.password == nil,
      path.hasPrefix("/content/"), !path.contains(".."), !path.contains("%"), !path.contains("?"),
      !path.contains("#"),
      let url = URL(string: path, relativeTo: baseURL)?.absoluteURL, url.host == baseURL.host,
      url.scheme == "https"
    else { throw ContentError.unsafePath }
    return url
  }
  private func download(_ reference: FileReference) async throws -> Data {
    guard reference.sha256.count == 64,
      reference.sha256.allSatisfy({ "0123456789abcdef".contains($0) })
    else { throw ContentError.integrity }
    let cache = root.appendingPathComponent("cache/\(reference.sha256).json")
    if let data = try? Data(contentsOf: cache), Self.sha256(data) == reference.sha256 {
      return data
    }
    let data = try await transport.fetch(url(reference.path))
    guard Self.sha256(data) == reference.sha256 else { throw ContentError.integrity }
    try FileManager.default.createDirectory(
      at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: cache, options: .atomic)
    return data
  }
  /// Commits the pointer only after every file and the complete pack pass validation.
  public func update(currentVersion: Int, appVersion: String) async throws -> ContentPack? {
    guard !updating else { return nil }
    updating = true
    defer { updating = false }
    let manifestData = try await transport.fetch(url("/content/manifest.json"))
    let manifest = try JSONDecoder().decode(ContentManifest.self, from: manifestData)
    guard manifest.schemaVersion == 1,
      let descriptor = manifest.packs.first(where: { $0.packId == "de-en" }),
      descriptor.version > currentVersion
    else { return nil }
    guard descriptor.minAppVersion.compare(appVersion, options: .numeric) != .orderedDescending
    else { throw ContentError.incompatibleVersion }
    let decoder = JSONDecoder()
    let index = try decoder.decode(PackIndex.self, from: await download(descriptor.index))
    guard
      index.version == descriptor.version && index.packId == descriptor.packId
        && index.schemaVersion == 1,
      !index.units.isEmpty, index.units.count <= 100
    else { throw ContentError.invalid("Invalid index") }
    struct RulesFile: Decodable { var rules: [Rule] }
    struct LexiconFile: Decodable { var lexicon: [Lexeme] }
    struct Unit: Decodable { var chains: [Chain] }
    let rules = try decoder.decode(RulesFile.self, from: await download(descriptor.rules)).rules
    let lexicon = try decoder.decode(LexiconFile.self, from: await download(descriptor.lexicon))
      .lexicon
    var chains: [Chain] = []
    var totalUnitBytes = 0
    for unit in index.units {
      let data = try await download(unit)
      totalUnitBytes += data.count
      guard totalUnitBytes <= 8_000_000 else {
        throw ContentError.invalid("Pack exceeds the supported size")
      }
      chains += try decoder.decode(Unit.self, from: data).chains
      guard chains.count <= 2000 else { throw ContentError.invalid("Too many chains") }
    }
    let pack = ContentPack(
      version: index.version, rules: rules, lexicon: lexicon, chains: chains,
      reviewStatus: index.reviewStatus)
    try ContentLint.validate(pack)
    let directory = root.appendingPathComponent("v\(pack.version)")
    let staging = root.appendingPathComponent("staging-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: staging) }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    try encoder.encode(pack).write(
      to: staging.appendingPathComponent("pack.json"), options: .atomic)
    if FileManager.default.fileExists(atPath: directory.path) {
      try FileManager.default.removeItem(at: directory)
    }
    try FileManager.default.moveItem(at: staging, to: directory)
    try encoder.encode(currentVersion).write(
      to: root.appendingPathComponent("previous.json"), options: .atomic)
    try encoder.encode(pack.version).write(
      to: root.appendingPathComponent("active.json"), options: .atomic)
    for file in try FileManager.default.contentsOfDirectory(
      at: root, includingPropertiesForKeys: nil)
    {
      if file.lastPathComponent.hasPrefix("v"), file.lastPathComponent != "v\(pack.version)",
        file.lastPathComponent != "v\(currentVersion)"
      {
        try? FileManager.default.removeItem(at: file)
      }
    }
    // Cache is content addressed and bounded to the current download's references.
    let keep = Set(
      ([descriptor.index, descriptor.rules, descriptor.lexicon] + index.units).map {
        $0.sha256 + ".json"
      })
    if let cached = try? FileManager.default.contentsOfDirectory(
      at: root.appendingPathComponent("cache"), includingPropertiesForKeys: nil)
    {
      for file in cached where !keep.contains(file.lastPathComponent) {
        try? FileManager.default.removeItem(at: file)
      }
    }
    return pack
  }
}
