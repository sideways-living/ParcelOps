import SwiftUI

struct MVPSetupView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }
  private var statusColumns: [GridItem] {
    Array(repeating: GridItem(.flexible(), spacing: 12), count: isCompact ? 1 : 2)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        MVPUsableVersionPanel(store: store)

        MVPWorkflowGuide(
          title: "First usable workflow",
          detail: "This is the shortest route for testing whether ParcelOps works as a local operational tool.",
          steps: [
            "Review Mailbox Monitor and Import Queue records.",
            "Use Acceptance Review to link or create orders and shipment groups.",
            "Use Needs Review and Operations Workbench to clear exceptions.",
            "Prepare dispatch through Shipment Manifests and Dispatch Readiness.",
            "Use Tasks and Audit to confirm follow-up and traceability."
          ]
        )

        MVPHandsOnReleaseChecklist(store: store)

        SpaceMailOperatorGuidanceStack(store: store)

        LocalDataSafetyCard(store: store, compact: isCompact)

        LazyVGrid(columns: statusColumns, spacing: 12) {
          MVPStatusCard(title: "Local data store", detail: "Orders, intake, review work, manifests, tasks, and audit events are persisted as local JSON.", status: "Available", symbol: "internaldrive.fill", color: .green)
          MVPStatusCard(title: "Manual operations", detail: "You can create, edit, review, link, and remove local operational records.", status: "Available", symbol: "hand.tap.fill", color: .green)
          MVPStatusCard(title: "SpaceMail intake", detail: "SpaceMail IMAP can run a manual read-only refresh, filter mixed mailbox mail, and import likely order messages into local Inbox review.", status: "Manual", symbol: "envelope.badge.fill", color: .green)
          MVPStatusCard(title: "Shopify", detail: "Shopify records and account placeholders exist, but no Shopify API or OAuth flow is connected.", status: "Placeholder", symbol: "cart.badge.plus", color: .orange)
          MVPStatusCard(title: "Carrier tracking", detail: "Tracking events are local records only. Carrier APIs and live refresh are not connected.", status: "Placeholder", symbol: "location.fill.viewfinder", color: .orange)
          MVPStatusCard(title: "Store logins", detail: "Account records are placeholders only. No browser automation or credential sync is active.", status: "Placeholder", symbol: "key.horizontal.fill", color: .orange)
          MVPStatusCard(title: "Credential storage", detail: "SpaceMail password/app-password storage uses Keychain. Tokens, API keys, OAuth secrets, and mailbox credentials are not stored in JSON.", status: "SpaceMail only", symbol: "lock.shield.fill", color: .green)
          MVPStatusCard(title: "Background work", detail: "No background sync, notifications, reminders, calendars, OCR, scanners, or file pickers are active.", status: "Not connected", symbol: "bell.slash.fill", color: .red)
        }

        SettingsPanel(title: "MVP health snapshot", symbol: "gauge.with.dots.needle.67percent") {
          MetricStrip(items: [
            ("Orders", "\(store.orders.count)", .blue),
            ("Review queue", "\(store.reviewQueueCount)", .orange),
            ("Open work", "\(store.openWorkbenchItems.count)", .teal),
            ("Audit events", "\(store.auditEvents.count)", .purple)
          ])

          Text("Use this pass to judge whether the workflow is understandable before connecting real systems. The best next product work is simplifying confusing screens, then connecting one real intake source.")
            .foregroundStyle(.secondary)
        }
      }
      .padding(isCompact ? 14 : 24)
    }
    .background(.background)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("MVP Setup")
        .font(isCompact ? .title.bold() : .largeTitle.bold())
      Text("ParcelOps is currently a local-first operations prototype. Use these screens to test the order intake, review, dispatch, task, and audit workflow before connecting live systems.")
        .foregroundStyle(.secondary)
    }
  }
}

struct MVPUsableVersionPanel: View {
  var store: ParcelOpsStore

  private var hasSpaceMailSetup: Bool {
    !store.spaceMailIMAPConnections.isEmpty
  }

  private var hasSpaceMailCredential: Bool {
    store.spaceMailIMAPConnections.contains {
      $0.credentialStorageStatus.localizedCaseInsensitiveContains("available")
        || $0.credentialStorageStatus.localizedCaseInsensitiveContains("ready")
    }
  }

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.spaceMailIntakeHealthSummaries.first
  }

  private var inboxOrderCount: Int {
    let linkedOrderIDs = Set(store.intakeEmails.compactMap(\.linkedOrderID))
    return store.orders.filter { order in
      linkedOrderIDs.contains(order.id)
        || order.source == .forwardedMailbox
        || order.checkedMailbox == "manual-import"
    }.count
  }

  private var operatorWorkCount: Int {
    store.reviewQueueCount + store.openWorkbenchItems.count + store.reviewTasksNeedingAttention.count
  }

  private var readinessTitle: String {
    if !hasSpaceMailSetup { return "Usable locally, mailbox setup still needed" }
    if !hasSpaceMailCredential { return "Usable locally, SpaceMail credential needed" }
    if inboxOrderCount == 0 { return "Ready for a supervised Inbox-to-order test" }
    if operatorWorkCount > 0 { return "Usable for hands-on operator testing" }
    return "Primary MVP path is usable"
  }

  private var readinessDetail: String {
    if !hasSpaceMailSetup {
      return "The local records, navigation, Tasks, Audit, and Settings flows are usable. Add a SpaceMail setup before relying on live mailbox intake."
    }
    if !hasSpaceMailCredential {
      return "The SpaceMail setup exists, but real manual refresh needs a Keychain password or app-password reference."
    }
    if inboxOrderCount == 0 {
      return "Run a manual SpaceMail refresh, review one imported intake row, then create or link an order to prove the daily flow."
    }
    return "The main daily flow now covers mailbox intake, Inbox triage, order handoff, Workbench follow-up, Tasks, Dispatch context, Audit, and local Settings."
  }

  private var readinessColor: Color {
    if !hasSpaceMailSetup || !hasSpaceMailCredential { return .orange }
    if inboxOrderCount == 0 { return .teal }
    return .green
  }

  var body: some View {
    SettingsPanel(title: "Usable version status", symbol: "checkmark.seal.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: "checkmark.seal.fill")
            .foregroundStyle(readinessColor)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(readinessTitle)
              .font(.headline)
            Text(readinessDetail)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Badge(inboxOrderCount > 0 ? "Hands-on" : "Setup", color: readinessColor)
        }

        MetricStrip(items: [
          ("SpaceMail", hasSpaceMailSetup ? "Set" : "Needed", hasSpaceMailSetup ? .green : .orange),
          ("Credential", hasSpaceMailCredential ? "Keychain" : "Needed", hasSpaceMailCredential ? .green : .orange),
          ("Last fetched", "\(latestSpaceMailSummary?.fetchedCount ?? 0)", (latestSpaceMailSummary?.fetchedCount ?? 0) > 0 ? .blue : .secondary),
          ("Imported", "\(latestSpaceMailSummary?.importedCount ?? 0)", (latestSpaceMailSummary?.importedCount ?? 0) > 0 ? .green : .secondary),
          ("Inbox orders", "\(inboxOrderCount)", inboxOrderCount > 0 ? .green : .orange),
          ("Open review", "\(operatorWorkCount)", operatorWorkCount == 0 ? .green : .orange)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], alignment: .leading, spacing: 10) {
          statusLine(
            title: "Usable today",
            detail: "Manual SpaceMail intake, mixed-mailbox filtering, Inbox triage, local order creation/linking, Tasks, Dispatch context, Audit, and JSON persistence.",
            symbol: "hand.thumbsup.fill",
            color: .green
          )
          statusLine(
            title: "Needs operator judgement",
            detail: "Uncertain messages, parser misses, filtered examples, duplicate refreshes, and order fields still need local review before accepting records.",
            symbol: "person.crop.circle.badge.exclamationmark",
            color: .orange
          )
          statusLine(
            title: "Still not connected",
            detail: "No background sync, mailbox mutation, Shopify API, carrier API, outbound email, OCR, scanner, calendar, notification, or file-picker workflow is active.",
            symbol: "network.slash",
            color: .secondary
          )
        }
      }
    }
  }

  private func statusLine(title: String, detail: String, symbol: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Label(title, systemImage: symbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
      Text(detail)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct MVPHandsOnReleaseChecklist: View {
  var store: ParcelOpsStore

  private var intakeReadyCount: Int {
    store.intakeEmails.filter { email in
      email.reviewState == .needsReview || email.linkedOrderID != nil
    }.count
  }

  private var openPrimaryWorkCount: Int {
    store.openWorkbenchItems.count + store.reviewTasksNeedingAttention.count
  }

  private var checklistItems: [(String, String, String, Color)] {
    [
      (
        "1. Refresh intake",
        "Run SpaceMail manually, then confirm fetched, imported, duplicate, filtered, and uncertain counts are understandable.",
        "server.rack",
        store.spaceMailIMAPConnections.isEmpty ? .orange : .green
      ),
      (
        "2. Triage Inbox",
        "Review imported intake, reprocess if needed, then create or link an order only when detected fields look credible.",
        "tray.full.fill",
        intakeReadyCount == 0 ? .orange : .blue
      ),
      (
        "3. Confirm Orders",
        "Open the created or linked order and verify the Inbox source trail, status, customer/destination, and tracking context.",
        "shippingbox.fill",
        store.orders.isEmpty ? .orange : .green
      ),
      (
        "4. Clear exceptions",
        "Use Workbench and Needs Review for validation, reconciliation, high-risk, and handoff follow-up before dispatch work.",
        "exclamationmark.triangle.fill",
        store.openWorkbenchItems.isEmpty ? .green : .orange
      ),
      (
        "5. Prepare dispatch",
        "Check Dispatch for manifests and readiness items so outbound work has an obvious next local action.",
        "paperplane.fill",
        store.shipmentManifestRecords.isEmpty && store.dispatchReadinessChecklists.isEmpty ? .orange : .purple
      ),
      (
        "6. Verify traceability",
        "Check Tasks and Audit, then quit and reopen to confirm local JSON persistence keeps the same workflow state.",
        "list.clipboard.fill",
        store.auditEvents.isEmpty ? .orange : .teal
      )
    ]
  }

  var body: some View {
    SettingsPanel(title: "Hands-on release checklist", symbol: "checklist.checked") {
      MetricStrip(items: [
        ("Intake records", "\(store.intakeEmails.count)", .blue),
        ("Orders", "\(store.orders.count)", .green),
        ("Open work", "\(openPrimaryWorkCount)", .orange),
        ("Audit events", "\(store.auditEvents.count)", .purple)
      ])

      Text("Use this checklist when judging whether ParcelOps is ready for normal hands-on testing in Xcode. It is still a manual, local-first workflow: no background sync, notifications, mailbox mutation, Shopify, carrier APIs, OCR, scanners, or outbound email are active.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], alignment: .leading, spacing: 10) {
        ForEach(Array(checklistItems.enumerated()), id: \.offset) { _, item in
          MVPHandsOnReleaseChecklistRow(title: item.0, detail: item.1, symbol: item.2, color: item.3)
        }
      }
    }
  }
}

struct MVPHandsOnReleaseChecklistRow: View {
  var title: String
  var detail: String
  var symbol: String
  var color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(title, systemImage: symbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
      Text(detail)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct MVPStatusCard: View {
  var title: String
  var detail: String
  var status: String
  var symbol: String
  var color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top) {
        Image(systemName: symbol)
          .foregroundStyle(color)
          .frame(width: 24)
        Spacer()
        Badge(status, color: color)
      }
      Text(title)
        .font(.headline)
      Text(detail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}
