import Foundation
import UserNotifications

@MainActor enum ReminderService {
  private static var generation = 0
  static func update(enabled: Bool, hour: Int, minute: Int, requestPermission: Bool) async throws
    -> Bool
  {
    generation += 1
    let currentGeneration = generation
    let center = UNUserNotificationCenter.current()
    let pending = await center.pendingNotificationRequests()
    guard currentGeneration == generation else { return false }
    center.removePendingNotificationRequests(
      withIdentifiers: pending.filter { $0.identifier.hasPrefix("ripple.daily") }.map(\.identifier))
    guard enabled else { return false }
    guard (0...23).contains(hour), (0...59).contains(minute) else { return false }
    let settings = await center.notificationSettings()
    var authorized =
      settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    if settings.authorizationStatus == .notDetermined && requestPermission {
      authorized = try await center.requestAuthorization(options: [.alert, .sound])
    }
    guard authorized, currentGeneration == generation else { return false }
    let content = UNMutableNotificationContent()
    content.title = "A small change. A longer sentence."
    content.body = "Today’s 3 chains are ready — about 5 minutes."
    content.sound = .default
    let trigger = UNCalendarNotificationTrigger(
      dateMatching: DateComponents(hour: hour, minute: minute), repeats: true)
    let identifier = "ripple.daily." + UUID().uuidString
    try await center.add(
      UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    guard currentGeneration == generation else {
      center.removePendingNotificationRequests(withIdentifiers: [identifier])
      return false
    }
    return true
  }
}
