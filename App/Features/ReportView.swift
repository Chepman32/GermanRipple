import SwiftUI

struct ReportView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let chainID: String
  let step: Int
  @State private var reason = "other_answer_ok"
  @State private var note = ""
  @State private var busy = false
  @State private var saved = false
  private let reasons = [
    ("other_answer_ok", "My answer should also be correct"),
    ("answer_wrong", "The correct answer is wrong"), ("bad_translation", "Bad translation"),
    ("audio", "Audio problem"), ("other", "Other"),
  ]
  var body: some View {
    NavigationStack {
      Form {
        if saved {
          Section {
            Label(
              store.backend.isConfigured && store.reports.first?.sent == true
                ? "Report sent. Thank you." : "Report saved on this device.",
              systemImage: "checkmark.circle")
            Text("Find it again in Settings → Content Report History.").font(.caption)
              .foregroundStyle(Palette.secondary)
          }
        } else {
          Section("What needs a closer look?") {
            Picker("Reason", selection: $reason) {
              ForEach(reasons, id: \.0) { Text($0.1).tag($0.0) }
            }.pickerStyle(.inline).labelsHidden()
          }
          Section {
            TextField("Optional note", text: $note, axis: .vertical).lineLimit(4...8).onChange(
              of: note
            ) { _, value in if value.count > 500 { note = String(value.prefix(500)) } }
            Text("\(note.count)/500").font(.caption).foregroundStyle(Palette.secondary).frame(
              maxWidth: .infinity, alignment: .trailing)
          } header: {
            Text("Anything else?")
          } footer: {
            Text(
              "Please don’t include personal or sensitive information. This report includes the lesson, step and content version."
            )
          }
          Section {
            Button(store.backend.isConfigured ? "Send Report" : "Save Report on This Device") {
              Task {
                busy = true
                saved = await store.submitReport(
                  chainID: chainID, step: step, reason: reason, note: note)
                busy = false
              }
            }.disabled(busy)
            if busy { ProgressView() }
          }
        }
      }.navigationTitle("Content Report").navigationBarTitleDisplayMode(.inline).toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(saved ? "Done" : "Cancel") { dismiss() }.disabled(busy)
        }
      }
    }.interactiveDismissDisabled(busy)
  }
}

struct ReportHistoryView: View {
  @Environment(AppStore.self) private var store
  var body: some View {
    Group {
      if store.reports.isEmpty {
        EmptyState(
          symbol: "flag", title: "No reports yet",
          message:
            "Use the info button in a lesson to report a grammar, translation or audio problem.")
      } else {
        List(store.reports, id: \.id) { report in
          VStack(alignment: .leading, spacing: 10) {
            Text(store.pack.chains.first { $0.id == report.chainId }?.name ?? "Demo lesson").font(
              .headline)
            Text(
              "Step \(report.step+1) · \(report.createdAt.formatted(date:.abbreviated,time:.omitted))"
            ).font(.caption).foregroundStyle(Palette.secondary)
            Text(report.reason.replacingOccurrences(of: "_", with: " ").capitalized).font(
              .subheadline)
            if !report.note.isEmpty {
              Text(report.note).font(.subheadline).foregroundStyle(Palette.secondary)
            }
            Label(
              report.sent ? "Sent" : "Saved on this device",
              systemImage: report.sent ? "checkmark.circle" : "iphone"
            ).font(.caption)
            if !report.sent && store.backend.isConfigured {
              Button("Send report") { Task { await store.resendReport(report) } }
            }
          }.padding(.vertical, 8)
        }
      }
    }.navigationTitle("Report History")
  }
}
