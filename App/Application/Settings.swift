import Foundation
import Observation
import RippleEngine

@MainActor @Observable final class AppSettings {
  private let defaults: UserDefaults
  var onboardingComplete: Bool { didSet { save() } }
  var dailyGoal: Int { didSet { save() } }
  var band: CEFR { didSet { save() } }
  var alwaysGuided: Bool { didSet { save() } }
  var hideTranslation: Bool { didSet { save() } }
  var autoplay: Bool { didSet { save() } }
  var slowSpeech: Bool { didSet { save() } }
  var voiceID: String { didSet { save() } }
  var haptics: Bool { didSet { save() } }
  var sounds: Bool { didSet { save() } }
  var analytics: Bool { didSet { save() } }
  var consentAsked: Bool { didSet { save() } }
  var reminderEnabled: Bool { didSet { save() } }
  var reminderHour: Int { didSet { save() } }
  var reminderMinute: Int { didSet { save() } }
  var reminderAsked: Bool { didSet { save() } }
  var completedSessions: Int { didSet { save() } }
  let installID: String
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    onboardingComplete = defaults.bool(forKey: "onboardingComplete")
    dailyGoal =
      [3, 6, 9].contains(defaults.integer(forKey: "dailyGoal"))
      ? defaults.integer(forKey: "dailyGoal") : 3
    band = CEFR(rawValue: defaults.string(forKey: "band") ?? "A1") ?? .a1
    alwaysGuided = defaults.bool(forKey: "alwaysGuided")
    hideTranslation = defaults.bool(forKey: "hideTranslation")
    autoplay = defaults.object(forKey: "autoplay") as? Bool ?? true
    slowSpeech = defaults.bool(forKey: "slowSpeech")
    voiceID = defaults.string(forKey: "voiceID") ?? ""
    haptics = defaults.object(forKey: "haptics") as? Bool ?? true
    sounds = defaults.object(forKey: "sounds") as? Bool ?? true
    analytics = defaults.bool(forKey: "analytics")
    consentAsked = defaults.bool(forKey: "consentAsked")
    reminderEnabled = defaults.bool(forKey: "reminderEnabled")
    reminderHour = defaults.object(forKey: "reminderHour") as? Int ?? 19
    reminderMinute = defaults.integer(forKey: "reminderMinute")
    reminderAsked = defaults.bool(forKey: "reminderAsked")
    completedSessions = defaults.integer(forKey: "completedSessions")
    installID = defaults.string(forKey: "installID") ?? UUID().uuidString
    defaults.set(installID, forKey: "installID")
  }
  private func save() {
    let values: [String: Any] = [
      "onboardingComplete": onboardingComplete, "dailyGoal": dailyGoal, "band": band.rawValue,
      "alwaysGuided": alwaysGuided, "hideTranslation": hideTranslation, "autoplay": autoplay,
      "slowSpeech": slowSpeech,
      "voiceID": voiceID, "haptics": haptics, "sounds": sounds, "analytics": analytics,
      "consentAsked": consentAsked,
      "reminderEnabled": reminderEnabled, "reminderHour": reminderHour,
      "reminderMinute": reminderMinute,
      "reminderAsked": reminderAsked, "completedSessions": completedSessions,
    ]
    values.forEach { defaults.set($0.value, forKey: $0.key) }
  }
}
