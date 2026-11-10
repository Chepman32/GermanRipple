import AVFoundation
import AudioToolbox
import ContentKit
import RippleEngine
import UIKit

@MainActor final class AudioService: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
  private let synthesizer = AVSpeechSynthesizer()
  private let catalog: RecordedAudioCatalog?
  private let recordings: RecordedAudioCache
  private let recordingOrigin: URL?
  private let recordingDownloadsEnabled: Bool
  private var player: AVAudioPlayer?
  private var speechTask: Task<Void, Never>?
  private var generation = UUID()
  init(recordingDownloadsEnabled: Bool = true) {
    self.recordingDownloadsEnabled = recordingDownloadsEnabled
    if let url = Bundle.main.url(forResource: "audio-catalog", withExtension: "json"),
      let data = try? Data(contentsOf: url) {
      catalog = try? RecordedAudioCatalog.decode(data)
    } else { catalog = nil }
    let root = URL.cachesDirectory.appendingPathComponent("RippleRecordings", isDirectory: true)
    recordings = RecordedAudioCache(root: root)
    recordingOrigin = (Bundle.main.object(forInfoDictionaryKey: "RippleContentBaseURL") as? String)
      .flatMap(URL.init(string:))
    super.init()
    synthesizer.delegate = self
  }
  static var germanVoices: [AVSpeechSynthesisVoice] {
    AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("de") }.sorted {
      $0.quality == $1.quality ? $0.name < $1.name : $0.quality.rawValue > $1.quality.rawValue
    }
  }
  func speak(tokens: [Token], terminal: String = ".", settings: AppSettings) {
    let text = Sentence.text(tokens, terminal: terminal)
    let attributed = NSMutableAttributedString(string: text)
    var cursor = text.startIndex
    for token in tokens {
      guard
        let range = text.range(
          of: token.text, options: [.caseInsensitive], range: cursor..<text.endIndex)
      else { continue }
      if let ipa = token.ipa {
        attributed.addAttribute(
          .init(AVSpeechSynthesisIPANotationAttribute), value: ipa, range: NSRange(range, in: text))
      }
      cursor = range.upperBound
    }
    speak(AVSpeechUtterance(attributedString: attributed), settings: settings)
  }
  func speak(text: String, settings: AppSettings) {
    speak(AVSpeechUtterance(string: text), settings: settings)
  }
  private func speak(_ utterance: AVSpeechUtterance, settings: AppSettings) {
    stop()
    let ticket = generation
    let voiceID = settings.voiceID
    let slow = settings.slowSpeech
    // An explicitly selected installed voice always wins. A cache miss starts
    // local speech immediately; a download never interrupts the current sentence.
    let clip = voiceID.isEmpty ? catalog?.clip(for: utterance.speechString) : nil
    speechTask = Task { @MainActor [weak self] in
      guard let self, !Task.isCancelled, generation == ticket else { return }
      if let clip, let file = try? await recordings.cachedFile(for: clip),
        !Task.isCancelled, generation == ticket, play(file, slow: slow) { return }
      guard !Task.isCancelled, generation == ticket else { return }
      synthesize(utterance, voiceID: voiceID, slow: slow)
      if let clip, let recordingOrigin, recordingDownloadsEnabled {
        _ = try? await recordings.fetch(clip, from: recordingOrigin)
      }
    }
  }
  private func activateAudio() -> Bool {
    do {
      try AVAudioSession.sharedInstance().setCategory(
        .playback, mode: .spokenAudio, options: [.duckOthers])
      try AVAudioSession.sharedInstance().setActive(true)
      return true
    } catch { return false }
  }
  private func play(_ file: URL, slow: Bool) -> Bool {
    guard activateAudio() else { return false }
    do {
      let recording = try AVAudioPlayer(contentsOf: file)
      recording.delegate = self
      recording.enableRate = true
      recording.rate = slow ? 0.8 : 1
      guard recording.prepareToPlay(), recording.play() else { return false }
      player = recording
      return true
    } catch { return false }
  }
  private func synthesize(_ utterance: AVSpeechUtterance, voiceID: String, slow: Bool) {
    guard activateAudio() else { return }
    utterance.voice =
      AVSpeechSynthesisVoice(identifier: voiceID) ?? Self.germanVoices.first
      ?? AVSpeechSynthesisVoice(language: "de-DE")
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate * (slow ? 0.8 : 1)
    synthesizer.speak(utterance)
  }
  func stop() {
    generation = UUID()
    speechTask?.cancel()
    speechTask = nil
    player?.stop()
    player = nil
    synthesizer.stopSpeaking(at: .immediate)
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
  nonisolated func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance
  ) { restoreOtherAudio() }
  nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    restoreOtherAudio()
  }
  nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    restoreOtherAudio()
  }
  nonisolated func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance
  ) { restoreOtherAudio() }
  nonisolated private func restoreOtherAudio() {
    Task { @MainActor [weak self] in
      guard let self, !self.synthesizer.isSpeaking, self.player?.isPlaying != true else { return }
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
  }
}

@MainActor enum Feedback {
  static func selection(_ settings: AppSettings) {
    if settings.haptics { UISelectionFeedbackGenerator().selectionChanged() }
  }
  static func apply(_ settings: AppSettings) {
    if settings.haptics { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
  }
  static func result(_ success: Bool, settings: AppSettings) {
    if settings.haptics {
      UINotificationFeedbackGenerator().notificationOccurred(success ? .success : .error)
    }
    if settings.sounds && success { AudioServicesPlaySystemSound(1104) }
  }
}
