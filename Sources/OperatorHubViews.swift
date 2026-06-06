import SwiftUI

struct InboxView: View {
  var store: ParcelOpsStore
  @State private var selectedTab: InboxTab = .mailbox
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }

  var body: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 14) {
        header
        Picker("Inbox area", selection: $selectedTab) {
          ForEach(InboxTab.allCases) { tab in
            Label(tab.title, systemImage: tab.symbol).tag(tab)
          }
        }
        .pickerStyle(.segmented)
      }
      .padding(isCompact ? 14 : 24)
      .padding(.bottom, 0)

      Divider()

      switch selectedTab {
      case .mailbox:
        MailboxView(store: store)
      case .importQueue:
        ImportQueueView(store: store)
      case .acceptance:
        AcceptanceReviewView(store: store)
      }
    }
    .background(.regularMaterial)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Inbox")
        .font(isCompact ? .title.bold() : .largeTitle.bold())
      Text("Review incoming order signals, staged imports, and acceptance decisions before they become operational records.")
        .foregroundStyle(.secondary)

      MetricStrip(items: [
        ("Emails", "\(store.intakeEmails.count)", .blue),
        ("Imports", "\(store.importQueueItems.count)", .teal),
        ("Acceptance", "\(store.acceptanceRecordsNeedingReview.count)", .orange),
        ("Review", "\(store.reviewIntakeEmails.count)", .red)
      ])
    }
  }
}

private enum InboxTab: String, CaseIterable, Identifiable {
  case mailbox
  case importQueue
  case acceptance

  var id: String { rawValue }

  var title: String {
    switch self {
    case .mailbox: "Mailbox"
    case .importQueue: "Import"
    case .acceptance: "Accept"
    }
  }

  var symbol: String {
    switch self {
    case .mailbox: "envelope.badge.fill"
    case .importQueue: "tray.and.arrow.down.fill"
    case .acceptance: "checkmark.rectangle.stack.fill"
    }
  }
}

struct DispatchView: View {
  var store: ParcelOpsStore
  @State private var selectedTab: DispatchTab = .manifests
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }

  var body: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 14) {
        header
        Picker("Dispatch area", selection: $selectedTab) {
          ForEach(DispatchTab.allCases) { tab in
            Label(tab.title, systemImage: tab.symbol).tag(tab)
          }
        }
        .pickerStyle(.segmented)
      }
      .padding(isCompact ? 14 : 24)
      .padding(.bottom, 0)

      Divider()

      switch selectedTab {
      case .manifests:
        ShipmentManifestsView(store: store)
      case .readiness:
        DispatchReadinessView(store: store)
      }
    }
    .background(.regularMaterial)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Dispatch")
        .font(isCompact ? .title.bold() : .largeTitle.bold())
      Text("Prepare outbound batches and confirm local readiness before handoff.")
        .foregroundStyle(.secondary)

      MetricStrip(items: [
        ("Manifests", "\(store.shipmentManifestRecords.count)", .purple),
        ("Blocked", "\(store.blockedShipmentManifests.count)", .red),
        ("Checklists", "\(store.dispatchReadinessChecklists.count)", .teal),
        ("Incomplete", "\(store.incompleteDispatchChecklists.count)", .orange)
      ])
    }
  }
}

private enum DispatchTab: String, CaseIterable, Identifiable {
  case manifests
  case readiness

  var id: String { rawValue }

  var title: String {
    switch self {
    case .manifests: "Manifests"
    case .readiness: "Readiness"
    }
  }

  var symbol: String {
    switch self {
    case .manifests: "list.bullet.clipboard.fill"
    case .readiness: "checkmark.rectangle.stack.fill"
    }
  }
}
