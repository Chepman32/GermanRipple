import Foundation
import SwiftData

@Model final class VocabularyExposureRecord {
  @Attribute(.unique) var key: String
  var lemma: String
  var count: Int
  var lastSeen: Date
  init(lemma: String, at: Date) {
    self.lemma = lemma
    key = "de-en|" + lemma
    count = 1
    lastSeen = at
  }
}
