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
        OperatorMVPReadinessCard(store: store)
        OperatorSupportSnapshotCard(store: store, detail: "Use this snapshot to confirm setup, mailbox intake, source trails, and audit state before deeper QA.")
        OperatorTestSessionChecklistCard(store: store, detail: "Use this evidence checklist for one complete hands-on MVP validation pass.")
        OperatorHandoffBriefCard(store: store, detail: "Use this before handing testing or operation to another person.")

        MVPWorkflowGuide(
          title: "First usable workflow",
          detail: "Use this path to test the current SpaceMail-first local operator workflow end to end.",
          steps: [
            "Confirm SpaceMail setup and Keychain credential, then run one manual read-only refresh.",
            "Use Inbox or Mailbox Monitor to review imported, uncertain, filtered, and parser results.",
            "Create or link one order from a confirmed intake row.",
            "Use Orders and Workbench to verify the source trail, tracking, destination, and follow-up.",
            "Use Dispatch, Tasks, and Audit to confirm handoff readiness and traceability."
          ]
        )

        MVPHandsOnReleaseChecklist(store: store)
        MVPReleaseCandidateQACard(store: store)
        MVPReleaseEvidenceReport(store: store)
        MVPReleaseRunbook(store: store)
        MVPHandsOnTroubleshootingGuide(store: store)

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

  private var intakeReadyCount: Int {
    store.intakeEmails.filter { email in
      email.reviewState == .needsReview || email.linkedOrderID != nil
    }.count
  }

  private var inboxCreatedOrderCount: Int {
    let linkedOrderIDs = Set(store.intakeEmails.compactMap(\.linkedOrderID))
    return store.orders.filter { order in
      linkedOrderIDs.contains(order.id)
        || order.source == .forwardedMailbox
        || order.checkedMailbox == "manual-import"
    }.count
  }

  private var dispatchContextCount: Int {
    store.shipmentManifestRecords.count + store.dispatchReadinessChecklists.count
  }

  private var openPrimaryWorkCount: Int {
    store.openWorkbenchItems.count + store.reviewTasksNeedingAttention.count
  }

  private var completedChecklistCount: Int {
    checklistItems.filter { $0.4 }.count
  }

  private var nextTestTitle: String {
    if !hasSpaceMailSetup { return "Next: add SpaceMail setup" }
    if !hasSpaceMailCredential { return "Next: set/check SpaceMail credential" }
    if latestSpaceMailSummary?.fetchedCount ?? 0 == 0 { return "Next: run one manual SpaceMail refresh" }
    if intakeReadyCount == 0 { return "Next: review Mailbox Monitor results" }
    if inboxCreatedOrderCount == 0 { return "Next: create or link one order from Inbox" }
    if dispatchContextCount == 0 { return "Next: create dispatch setup for one order" }
    if store.auditEvents.isEmpty { return "Next: create one local action and confirm Audit" }
    return "Next: run the hands-on loop end to end"
  }

  private var nextTestDetail: String {
    if !hasSpaceMailSetup {
      return "Create the non-secret SpaceMail setup first. Do not put passwords into setup notes."
    }
    if !hasSpaceMailCredential {
      return "Use the secure SpaceMail credential prompt. The password/app-password should live in Keychain only."
    }
    if latestSpaceMailSummary?.fetchedCount ?? 0 == 0 {
      return "Run the explicit real SpaceMail refresh. It is manual, read-only, and must not mutate the mailbox."
    }
    if intakeReadyCount == 0 {
      return "Check whether messages were filtered, uncertain, duplicate, or imported. Import only genuine order mail."
    }
    if inboxCreatedOrderCount == 0 {
      return "Use Inbox to verify detected fields and create or link one order so downstream screens have real context."
    }
    if dispatchContextCount == 0 {
      return "Open the order and create local manifest/readiness setup so Dispatch can show the outbound handoff."
    }
    if store.auditEvents.isEmpty {
      return "Create a task, draft, review action, or dispatch action, then confirm the event appears in Audit."
    }
    return "Use Dashboard, Inbox, Orders, Workbench, Dispatch, Tasks, and Audit to verify the workflow feels coherent."
  }

  private var nextTestColor: Color {
    if completedChecklistCount >= checklistItems.count { return .green }
    if !hasSpaceMailSetup || !hasSpaceMailCredential { return .orange }
    return .teal
  }

  private var checklistItems: [(String, String, String, Color, Bool)] {
    [
      (
        "1. Refresh intake",
        "Run SpaceMail manually, then confirm fetched, imported, duplicate, filtered, and uncertain counts are understandable.",
        "server.rack",
        hasSpaceMailSetup && hasSpaceMailCredential && (latestSpaceMailSummary?.fetchedCount ?? 0) > 0 ? .green : .orange,
        hasSpaceMailSetup && hasSpaceMailCredential && (latestSpaceMailSummary?.fetchedCount ?? 0) > 0
      ),
      (
        "2. Triage Inbox",
        "Review imported intake, reprocess if needed, then create or link an order only when detected fields look credible.",
        "tray.full.fill",
        intakeReadyCount == 0 ? .orange : .blue,
        intakeReadyCount > 0
      ),
      (
        "3. Confirm Orders",
        "Open the created or linked order and verify the Inbox source trail, status, customer/destination, and tracking context.",
        "shippingbox.fill",
        inboxCreatedOrderCount == 0 ? .orange : .green,
        inboxCreatedOrderCount > 0
      ),
      (
        "4. Clear exceptions",
        "Use Workbench and Needs Review for validation, reconciliation, high-risk, and handoff follow-up before dispatch work.",
        "exclamationmark.triangle.fill",
        store.openWorkbenchItems.isEmpty ? .green : .orange,
        store.openWorkbenchItems.isEmpty
      ),
      (
        "5. Prepare dispatch",
        "Check Dispatch for manifests and readiness items so outbound work has an obvious next local action.",
        "paperplane.fill",
        dispatchContextCount == 0 ? .orange : .purple,
        dispatchContextCount > 0
      ),
      (
        "6. Verify traceability",
        "Check Tasks and Audit, then quit and reopen to confirm local JSON persistence keeps the same workflow state.",
        "list.clipboard.fill",
        store.auditEvents.isEmpty ? .orange : .teal,
        !store.auditEvents.isEmpty
      )
    ]
  }

  var body: some View {
    SettingsPanel(title: "Hands-on release checklist", symbol: "checklist.checked") {
      MetricStrip(items: [
        ("Checks", "\(completedChecklistCount)/\(checklistItems.count)", completedChecklistCount == checklistItems.count ? .green : .orange),
        ("Intake records", "\(store.intakeEmails.count)", .blue),
        ("Orders", "\(store.orders.count)", .green),
        ("Open work", "\(openPrimaryWorkCount)", .orange),
        ("Audit events", "\(store.auditEvents.count)", .purple)
      ])

      Text("Use this checklist when judging whether ParcelOps is ready for normal hands-on testing in Xcode. It is still a manual, local-first workflow: no background sync, notifications, mailbox mutation, Shopify, carrier APIs, OCR, scanners, or outbound email are active.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: completedChecklistCount == checklistItems.count ? "checkmark.seal.fill" : "arrow.forward.circle.fill")
            .foregroundStyle(nextTestColor)
            .frame(width: 22)
          VStack(alignment: .leading, spacing: 4) {
            Text(nextTestTitle)
              .font(.headline)
            Text(nextTestDetail)
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Badge(completedChecklistCount == checklistItems.count ? "Ready loop" : "Next test", color: nextTestColor)
        }

        CompactActionRow {
          Button("Seed local demo workflow", systemImage: "wand.and.stars") {
            store.seedLocalInboxOrderDemoWorkflow()
          }
          .buttonStyle(.borderedProminent)

          Button("Import clear order test email", systemImage: "checklist.checked") {
            store.importClearOrderIntakeTestMessage()
          }
          .buttonStyle(.bordered)

          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Mailbox Monitor", systemImage: "server.rack")
          }
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Inbox", systemImage: "tray.full.fill")
          }
          NavigationLink {
            OrdersView(store: store)
          } label: {
            Label("Orders", systemImage: "shippingbox.fill")
          }
          NavigationLink {
            OperationsWorkbenchView(store: store)
          } label: {
            Label("Workbench", systemImage: "rectangle.stack.badge.person.crop.fill")
          }
          NavigationLink {
            DispatchView(store: store)
          } label: {
            Label("Dispatch", systemImage: "paperplane.fill")
          }
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Tasks", systemImage: "checklist")
          }
          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Audit", systemImage: "list.clipboard.fill")
          }
        }
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(nextTestColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], alignment: .leading, spacing: 10) {
        ForEach(Array(checklistItems.enumerated()), id: \.offset) { _, item in
          MVPHandsOnReleaseChecklistRow(title: item.0, detail: item.1, symbol: item.2, color: item.3, isComplete: item.4)
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
  var isComplete: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label(title, systemImage: symbol)
          .font(.caption.weight(.semibold))
          .foregroundStyle(color)
        Spacer(minLength: 0)
        Badge(isComplete ? "Done" : "Check", color: isComplete ? .green : color)
      }
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

struct MVPReleaseCandidateQACard: View {
  var store: ParcelOpsStore

  private var latestDemoOrder: TrackedOrder? {
    store.orders.first { order in
      order.source == .forwardedMailbox
        && order.orderNumber.range(of: "TEST-", options: [.caseInsensitive, .anchored]) != nil
    }
  }

  private var linkedDemoIntakeCount: Int {
    guard let order = latestDemoOrder else { return 0 }
    return store.intakeEmails.filter { $0.linkedOrderID == order.id }.count
  }

  private var demoManifestCount: Int {
    latestDemoOrder.map { store.suggestedShipmentManifestRecords(for: $0).count } ?? 0
  }

  private var demoChecklistCount: Int {
    latestDemoOrder.map { store.suggestedDispatchReadinessChecklists(for: $0).count } ?? 0
  }

  private var completedDemoDispatchCount: Int {
    guard let order = latestDemoOrder else { return 0 }
    let manifests = store.suggestedShipmentManifestRecords(for: order).filter { $0.dispatchStatus == .handedOff }.count
    let checklists = store.suggestedDispatchReadinessChecklists(for: order).filter { $0.checklistStatus == .completed }.count
    return manifests + checklists
  }

  private var demoAuditCount: Int {
    guard let order = latestDemoOrder else { return 0 }
    return store.auditEvents.filter {
      $0.entityID == order.id.uuidString
        || $0.entityLabel.localizedCaseInsensitiveContains(order.orderNumber)
        || $0.afterDetail?.localizedCaseInsensitiveContains(order.orderNumber) == true
    }.count
  }

  private var hasLiveSpaceMailEvidence: Bool {
    store.spaceMailIntakeHealthSummaries.contains { summary in
      summary.fetchedCount > 0 || summary.importedCount > 0 || summary.filteredCount > 0 || summary.duplicateCount > 0 || summary.uncertainCount > 0
    }
  }

  private var hasPersistenceEvidence: Bool {
    store.auditEvents.count > 0 && store.orders.count > 0 && store.intakeEmails.count > 0
  }

  private var qaItems: [(title: String, detail: String, symbol: String, color: Color, isComplete: Bool)] {
    [
      (
        "Local demo seed",
        latestDemoOrder == nil ? "Seed the local demo workflow to create a known-good order path without mailbox access." : "Latest demo order \(latestDemoOrder?.orderNumber ?? "") exists.",
        "wand.and.stars",
        latestDemoOrder == nil ? .orange : .green,
        latestDemoOrder != nil
      ),
      (
        "Inbox source trail",
        linkedDemoIntakeCount == 0 ? "The demo order needs a linked intake email." : "\(linkedDemoIntakeCount) linked intake row exists for the demo order.",
        "link.badge.plus",
        linkedDemoIntakeCount == 0 ? .orange : .green,
        linkedDemoIntakeCount > 0
      ),
      (
        "Dispatch handoff",
        demoManifestCount + demoChecklistCount == 0 ? "Create or seed dispatch setup for the demo order." : "\(demoManifestCount) manifest and \(demoChecklistCount) readiness checklist records are linked.",
        "paperplane.fill",
        demoManifestCount + demoChecklistCount == 0 ? .orange : .purple,
        demoManifestCount > 0 && demoChecklistCount > 0
      ),
      (
        "Handoff completion",
        completedDemoDispatchCount == 0 ? "Complete the demo dispatch handoff once setup exists." : "\(completedDemoDispatchCount) demo dispatch records are completed locally.",
        "checkmark.rectangle.stack.fill",
        completedDemoDispatchCount == 0 ? .teal : .green,
        completedDemoDispatchCount > 0
      ),
      (
        "Audit trace",
        demoAuditCount == 0 ? "Perform the demo actions and confirm Audit shows the order trail." : "\(demoAuditCount) audit entries reference the latest demo order.",
        "list.clipboard.fill",
        demoAuditCount == 0 ? .orange : .purple,
        demoAuditCount > 0
      ),
      (
        "Live mailbox evidence",
        hasLiveSpaceMailEvidence ? "SpaceMail has at least one manual refresh result." : "Optional for demo readiness: run real SpaceMail only when credentials and mailbox state are available.",
        "server.rack",
        hasLiveSpaceMailEvidence ? .green : .secondary,
        hasLiveSpaceMailEvidence
      ),
      (
        "Persistence evidence",
        hasPersistenceEvidence ? "Local JSON-backed records exist across intake, orders, and audit." : "Create local workflow evidence, quit, reopen, and confirm it remains visible.",
        "internaldrive.fill",
        hasPersistenceEvidence ? .green : .orange,
        hasPersistenceEvidence
      )
    ]
  }

  private var requiredItems: [(title: String, detail: String, symbol: String, color: Color, isComplete: Bool)] {
    Array(qaItems.prefix(5)) + Array(qaItems.suffix(1))
  }

  private var completedRequiredCount: Int {
    requiredItems.filter(\.isComplete).count
  }

  private var tone: Color {
    completedRequiredCount == requiredItems.count ? .green : completedRequiredCount >= 4 ? .teal : .orange
  }

  private var title: String {
    if completedRequiredCount == requiredItems.count { return "Release-candidate demo path is ready" }
    if latestDemoOrder == nil { return "Release-candidate QA needs a seeded demo" }
    return "Release-candidate QA is partly ready"
  }

  private var detail: String {
    if completedRequiredCount == requiredItems.count {
      return "The local demo path has enough evidence for Inbox, Orders, Dispatch, Tasks, Audit, and persistence-oriented hands-on testing."
    }
    return "Use the local demo path as the stable QA baseline. Live SpaceMail remains useful, but it should not block app usability checks."
  }

  private var canCompleteHandoff: Bool {
    latestDemoOrder != nil
      && demoManifestCount > 0
      && demoChecklistCount > 0
      && completedDemoDispatchCount == 0
  }

  private var canReopenHandoff: Bool {
    latestDemoOrder != nil && completedDemoDispatchCount > 0
  }

  var body: some View {
    SettingsPanel(title: "Release-candidate QA", symbol: "checkmark.seal.fill") {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: completedRequiredCount == requiredItems.count ? "checkmark.seal.fill" : "checklist")
          .foregroundStyle(tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.headline)
          Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge("\(completedRequiredCount)/\(requiredItems.count)", color: tone)
      }

      MetricStrip(items: [
        ("Demo order", latestDemoOrder == nil ? "No" : "Yes", latestDemoOrder == nil ? .orange : .green),
        ("Inbox links", "\(linkedDemoIntakeCount)", linkedDemoIntakeCount == 0 ? .orange : .green),
        ("Dispatch", "\(demoManifestCount + demoChecklistCount)", demoManifestCount + demoChecklistCount == 0 ? .orange : .purple),
        ("Completed", "\(completedDemoDispatchCount)", completedDemoDispatchCount == 0 ? .secondary : .green),
        ("Audit", "\(demoAuditCount)", demoAuditCount == 0 ? .orange : .purple)
      ])

      CompactActionRow {
        Button(latestDemoOrder == nil ? "Seed demo workflow" : "Seed another demo", systemImage: "wand.and.stars") {
          store.seedLocalInboxOrderDemoWorkflow()
        }
        .buttonStyle(.borderedProminent)

        if let order = latestDemoOrder {
          Button("Complete handoff", systemImage: "checkmark.rectangle.stack.fill") {
            store.completeInboxDispatchHandoff(for: order)
          }
          .buttonStyle(.bordered)
          .disabled(!canCompleteHandoff)

          Button("Reopen handoff", systemImage: "arrow.counterclockwise.circle.fill") {
            store.reopenInboxDispatchHandoff(for: order)
          }
          .buttonStyle(.bordered)
          .disabled(!canReopenHandoff)
        }

        NavigationLink {
          DashboardView(store: store)
        } label: {
          Label("Dashboard", systemImage: "square.grid.2x2.fill")
        }
        .buttonStyle(.bordered)

        NavigationLink {
          AuditView(store: store)
        } label: {
          Label("Audit", systemImage: "list.clipboard.fill")
        }
        .buttonStyle(.bordered)
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], alignment: .leading, spacing: 10) {
        ForEach(Array(qaItems.enumerated()), id: \.offset) { _, item in
          MVPHandsOnReleaseChecklistRow(title: item.title, detail: item.detail, symbol: item.symbol, color: item.color, isComplete: item.isComplete)
        }
      }

      Text("QA boundaries: this card only reads and creates local JSON-backed workflow records through existing local actions. It does not run IMAP, mutate mailboxes, call Shopify/carrier APIs, send messages, create notifications, or schedule background work.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

struct MVPReleaseEvidenceReport: View {
  var store: ParcelOpsStore

  private var latestDemoOrder: TrackedOrder? {
    store.orders.first { order in
      order.source == .forwardedMailbox
        && order.orderNumber.range(of: "TEST-", options: [.caseInsensitive, .anchored]) != nil
    }
  }

  private var linkedIntakeCount: Int {
    guard let order = latestDemoOrder else { return 0 }
    return store.intakeEmails.filter { $0.linkedOrderID == order.id }.count
  }

  private var dispatchSetupCount: Int {
    guard let order = latestDemoOrder else { return 0 }
    return store.suggestedShipmentManifestRecords(for: order).count
      + store.suggestedDispatchReadinessChecklists(for: order).count
  }

  private var completedDispatchCount: Int {
    guard let order = latestDemoOrder else { return 0 }
    return store.suggestedShipmentManifestRecords(for: order).filter { $0.dispatchStatus == .handedOff }.count
      + store.suggestedDispatchReadinessChecklists(for: order).filter { $0.checklistStatus == .completed }.count
  }

  private var openDemoTaskCount: Int {
    guard let order = latestDemoOrder else { return 0 }
    return store.reviewTasks.filter {
      $0.linkedEntityType == .order
        && $0.linkedEntityID == order.id.uuidString
        && $0.status != .completed
    }.count
  }

  private var demoAuditCount: Int {
    guard let order = latestDemoOrder else { return 0 }
    return store.auditEvents.filter {
      $0.entityID == order.id.uuidString
        || $0.entityLabel.localizedCaseInsensitiveContains(order.orderNumber)
        || $0.afterDetail?.localizedCaseInsensitiveContains(order.orderNumber) == true
    }.count
  }

  private var persistenceEvidenceReady: Bool {
    !store.orders.isEmpty && !store.intakeEmails.isEmpty && !store.auditEvents.isEmpty
  }

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.spaceMailIntakeHealthSummaries.first
  }

  private var liveMailboxEvidenceReady: Bool {
    guard let summary = latestSpaceMailSummary else { return false }
    return summary.fetchedCount > 0 || summary.importedCount > 0 || summary.filteredCount > 0 || summary.duplicateCount > 0 || summary.uncertainCount > 0
  }

  private var requiredBlockers: [String] {
    var blockers: [String] = []
    if latestDemoOrder == nil { blockers.append("Seed local demo workflow") }
    if linkedIntakeCount == 0 { blockers.append("Link Inbox source to order") }
    if dispatchSetupCount == 0 { blockers.append("Create dispatch setup") }
    if completedDispatchCount == 0 { blockers.append("Complete demo handoff") }
    if demoAuditCount == 0 { blockers.append("Confirm Audit trail") }
    if !persistenceEvidenceReady { blockers.append("Confirm local JSON evidence") }
    return blockers
  }

  private var readyCount: Int {
    [
      latestDemoOrder != nil,
      linkedIntakeCount > 0,
      dispatchSetupCount > 0,
      completedDispatchCount > 0,
      demoAuditCount > 0,
      persistenceEvidenceReady
    ].filter { $0 }.count
  }

  private var tone: Color {
    if requiredBlockers.isEmpty { return .green }
    if readyCount >= 4 { return .teal }
    return .orange
  }

  private var verdictTitle: String {
    if requiredBlockers.isEmpty { return "QA evidence supports a hands-on release-candidate pass" }
    if latestDemoOrder == nil { return "QA evidence needs a stable local demo path" }
    return "QA evidence is incomplete"
  }

  private var verdictDetail: String {
    if requiredBlockers.isEmpty {
      return "The local path has enough traceable evidence for Dashboard, Inbox, Orders, Dispatch, Tasks, Audit, and persistence checks. Live SpaceMail evidence remains optional."
    }
    return "Finish the required blockers below before treating this as a release-candidate baseline. This report avoids live integrations and uses local records only."
  }

  private var canCompleteHandoff: Bool {
    latestDemoOrder != nil && dispatchSetupCount > 0 && completedDispatchCount == 0
  }

  private var canReopenHandoff: Bool {
    latestDemoOrder != nil && completedDispatchCount > 0
  }

  var body: some View {
    SettingsPanel(title: "QA evidence report", symbol: "doc.text.magnifyingglass") {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: requiredBlockers.isEmpty ? "checkmark.seal.fill" : "doc.text.magnifyingglass")
          .foregroundStyle(tone)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: 4) {
          Text(verdictTitle)
            .font(.headline)
          Text(verdictDetail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()
        Badge("\(readyCount)/6", color: tone)
      }

      MetricStrip(items: [
        ("Demo order", latestDemoOrder == nil ? "Missing" : "Present", latestDemoOrder == nil ? .orange : .green),
        ("Source links", "\(linkedIntakeCount)", linkedIntakeCount == 0 ? .orange : .green),
        ("Dispatch setup", "\(dispatchSetupCount)", dispatchSetupCount == 0 ? .orange : .purple),
        ("Closed handoff", "\(completedDispatchCount)", completedDispatchCount == 0 ? .secondary : .green),
        ("Open tasks", "\(openDemoTaskCount)", openDemoTaskCount == 0 ? .green : .orange),
        ("Audit trail", "\(demoAuditCount)", demoAuditCount == 0 ? .orange : .purple),
        ("Persistence", persistenceEvidenceReady ? "Seen" : "Check", persistenceEvidenceReady ? .green : .orange),
        ("Live mail", liveMailboxEvidenceReady ? "Seen" : "Optional", liveMailboxEvidenceReady ? .green : .secondary)
      ])

      if requiredBlockers.isEmpty {
        evidenceLine(
          title: "Required local evidence is complete",
          detail: "Run the hands-on pass from Dashboard, then quit and reopen the app to confirm the same local JSON-backed records remain visible.",
          symbol: "checkmark.circle.fill",
          color: .green
        )
      } else {
        VStack(alignment: .leading, spacing: 8) {
          Label("Required blockers", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
          ForEach(requiredBlockers, id: \.self) { blocker in
            Label(blocker, systemImage: "circle")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], alignment: .leading, spacing: 10) {
        evidenceLine(
          title: "Stable local baseline",
          detail: latestDemoOrder.map { "\($0.orderNumber) links Inbox, Orders, Dispatch, Tasks, and Audit." } ?? "Seed the demo workflow to create a stable non-mailbox baseline.",
          symbol: "wand.and.stars",
          color: latestDemoOrder == nil ? .orange : .green
        )
        evidenceLine(
          title: "Live mailbox is not a blocker",
          detail: liveMailboxEvidenceReady ? "SpaceMail has refresh evidence for mixed-mailbox testing." : "SpaceMail evidence is useful, but release-candidate QA can continue with local demo data.",
          symbol: "server.rack",
          color: liveMailboxEvidenceReady ? .green : .secondary
        )
        evidenceLine(
          title: "No external automation required",
          detail: "The QA path does not require Shopify, carrier APIs, outbound email, notifications, scanners, OCR, calendars, or background sync.",
          symbol: "network.slash",
          color: .secondary
        )
      }

      CompactActionRow {
        Button(latestDemoOrder == nil ? "Seed demo workflow" : "Seed another demo", systemImage: "wand.and.stars") {
          store.seedLocalInboxOrderDemoWorkflow()
        }
        .buttonStyle(.borderedProminent)

        if let order = latestDemoOrder {
          Button("Complete handoff", systemImage: "checkmark.rectangle.stack.fill") {
            store.completeInboxDispatchHandoff(for: order)
          }
          .buttonStyle(.bordered)
          .disabled(!canCompleteHandoff)

          Button("Reopen handoff", systemImage: "arrow.counterclockwise.circle.fill") {
            store.reopenInboxDispatchHandoff(for: order)
          }
          .buttonStyle(.bordered)
          .disabled(!canReopenHandoff)
        }

        NavigationLink { DashboardView(store: store) } label: { Label("Dashboard", systemImage: "square.grid.2x2.fill") }
          .buttonStyle(.bordered)
        NavigationLink { AuditView(store: store) } label: { Label("Audit", systemImage: "list.clipboard.fill") }
          .buttonStyle(.bordered)
      }
    }
  }

  private func evidenceLine(title: String, detail: String, symbol: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 6) {
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

struct MVPReleaseRunbook: View {
  var store: ParcelOpsStore

  private var hasDemoOrder: Bool {
    store.orders.contains { order in
      order.source == .forwardedMailbox
        && order.orderNumber.range(of: "TEST-", options: [.caseInsensitive, .anchored]) != nil
    }
  }

  private var hasSpaceMailResult: Bool {
    store.spaceMailIntakeHealthSummaries.contains { summary in
      summary.fetchedCount > 0 || summary.importedCount > 0 || summary.filteredCount > 0 || summary.duplicateCount > 0 || summary.uncertainCount > 0
    }
  }

  private var hasAuditEvidence: Bool {
    store.auditEvents.contains { event in
      [.spaceMailIMAPConnection, .intakeEmail, .order, .reviewTask, .shipmentManifest, .dispatchChecklist].contains(event.entityType)
    }
  }

  private var hasOpenPrimaryWork: Bool {
    !store.reviewIntakeEmails.isEmpty
      || !store.openWorkbenchItems.isEmpty
      || !store.reviewTasksNeedingAttention.isEmpty
      || !store.incompleteDispatchChecklists.isEmpty
  }

  private var runbookTone: Color {
    if hasDemoOrder && hasAuditEvidence { return .green }
    if hasDemoOrder || hasSpaceMailResult { return .teal }
    return .orange
  }

  private var runbookTitle: String {
    if hasDemoOrder && hasAuditEvidence { return "Runbook is ready for a supervised MVP pass" }
    if hasDemoOrder { return "Runbook has demo data; confirm Audit next" }
    return "Runbook needs a stable local demo seed"
  }

  private var runbookDetail: String {
    if hasDemoOrder && hasAuditEvidence {
      return "Use this sequence to run a short release-candidate pass. It is deliberately local-first and does not require live mailbox success."
    }
    if hasDemoOrder {
      return "The local demo order exists. Complete or reopen the dispatch handoff, then confirm the trail in Audit."
    }
    return "Seed the local demo workflow first so testing does not depend on SpaceMail inbox contents or classifier results."
  }

  private var normalSteps: [(String, String, String, Color)] {
    [
      ("1. Start at Dashboard", "Use Start here, Hands-on status, and Release-candidate checkpoint to decide where work should begin.", "square.grid.2x2.fill", .teal),
      ("2. Prove intake", "Use Inbox or Mailbox Monitor. A local demo email is enough; SpaceMail refresh is useful but optional for release-candidate QA.", "tray.full.fill", .blue),
      ("3. Create/link order", "Confirm merchant, order number, tracking, destination, and source trail before treating the order as operational.", "shippingbox.fill", .green),
      ("4. Close dispatch handoff", "Confirm manifest and readiness setup, then complete or reopen the local handoff as needed.", "paperplane.fill", .purple),
      ("5. Resolve owned work", "Open Workbench and Tasks. Complete only assigned local follow-up; filtered non-order mailbox results should not flood task work.", "checklist", .orange),
      ("6. Confirm Audit", "Audit should show the local source trail and handoff actions without secrets, full mailbox bodies, or mailbox mutation.", "list.clipboard.fill", .purple)
    ]
  }

  private var passCriteria: [(String, String, String, Color, Bool)] {
    [
      ("Dashboard gives a next action", "A tester can identify whether to open Inbox, Orders, Workbench, Dispatch, Tasks, or Audit.", "arrow.forward.circle.fill", .teal, true),
      ("Inbox creates or links an order", "A clear local/demo intake can become an order without relying on external services.", "link.badge.plus", .green, hasDemoOrder || !store.orders.isEmpty),
      ("Order keeps source trail", "The order detail can explain where the order came from and what still needs review.", "tray.and.arrow.down.fill", .blue, hasDemoOrder),
      ("Dispatch has a handoff path", "The tester can see manifest/readiness context and complete or reopen local handoff records.", "checkmark.rectangle.stack.fill", .purple, hasDemoOrder),
      ("Audit explains the trail", "Recent local actions appear in Audit with safe non-secret details.", "list.clipboard.fill", .purple, hasAuditEvidence),
      ("Settings explains boundaries", "Local JSON storage, SpaceMail credentials, and disconnected integrations are clear from Settings/MVP Setup.", "lock.shield.fill", .green, true)
    ]
  }

  private var knownLimitations: [(String, String, String, Color)] {
    [
      ("SpaceMail is manual", "Real IMAP refresh is explicit, read-only, and mixed-mailbox filtered. There is no background sync or mailbox mutation.", "server.rack", .teal),
      ("Shopify is not connected", "Shopify records remain placeholders. No Shopify API, OAuth, store login, or order sync is active.", "cart.badge.plus", .orange),
      ("Carrier tracking is local", "Carrier events are local records only. No carrier APIs, label printing, booking, scanner, or tracking refresh is active.", "location.fill.viewfinder", .orange),
      ("Outbound communication is draft-only", "Draft messages and templates are local planning records. ParcelOps does not send email or notifications.", "paperplane.slash.fill", .secondary),
      ("Secrets stay out of JSON", "SpaceMail passwords are handled through Keychain status/actions, while JSON stores only non-secret operational records.", "key.horizontal.fill", .green),
      ("Advanced records are supporting context", "Costs, claims, procurement, receiving, custody, labels, and scans exist locally but are not the primary daily path.", "archivebox.fill", .secondary)
    ]
  }

  private var completedPassCriteriaCount: Int {
    passCriteria.filter(\.4).count
  }

  var body: some View {
    SettingsPanel(title: "MVP release runbook", symbol: "book.closed.fill") {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "book.closed.fill")
          .foregroundStyle(runbookTone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(runbookTitle)
            .font(.headline)
          Text(runbookDetail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge("\(completedPassCriteriaCount)/\(passCriteria.count)", color: runbookTone)
      }

      MetricStrip(items: [
        ("Demo order", hasDemoOrder ? "Ready" : "Needed", hasDemoOrder ? .green : .orange),
        ("SpaceMail", hasSpaceMailResult ? "Seen" : "Optional", hasSpaceMailResult ? .green : .secondary),
        ("Open work", "\(store.openWorkbenchItems.count + store.reviewTasksNeedingAttention.count)", hasOpenPrimaryWork ? .orange : .green),
        ("Audit", hasAuditEvidence ? "Ready" : "Needed", hasAuditEvidence ? .green : .orange),
        ("Records", "\(store.orders.count + store.intakeEmails.count + store.auditEvents.count)", .blue)
      ])

      CompactActionRow {
        Button(hasDemoOrder ? "Seed another demo" : "Seed demo workflow", systemImage: "wand.and.stars") {
          store.seedLocalInboxOrderDemoWorkflow()
        }
        .buttonStyle(.borderedProminent)

        NavigationLink { DashboardView(store: store) } label: { Label("Dashboard", systemImage: "square.grid.2x2.fill") }
          .buttonStyle(.bordered)
        NavigationLink { InboxView(store: store) } label: { Label("Inbox", systemImage: "tray.full.fill") }
          .buttonStyle(.bordered)
        NavigationLink { OrdersView(store: store) } label: { Label("Orders", systemImage: "shippingbox.fill") }
          .buttonStyle(.bordered)
        NavigationLink { DispatchView(store: store) } label: { Label("Dispatch", systemImage: "paperplane.fill") }
          .buttonStyle(.bordered)
        NavigationLink { AuditView(store: store) } label: { Label("Audit", systemImage: "list.clipboard.fill") }
          .buttonStyle(.bordered)
      }

      runbookSection(title: "Test sequence", symbol: "list.number", items: normalSteps)

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], alignment: .leading, spacing: 10) {
        ForEach(Array(passCriteria.enumerated()), id: \.offset) { _, item in
          MVPHandsOnReleaseChecklistRow(title: item.0, detail: item.1, symbol: item.2, color: item.3, isComplete: item.4)
        }
      }

      runbookSection(title: "Known limitations", symbol: "exclamationmark.triangle.fill", items: knownLimitations)

      Text("Pass/fail rule: this MVP is ready for hands-on testing when a tester can complete the local demo path, understand filtered/uncertain mailbox results, and confirm Audit/Settings boundaries without expecting live Shopify, carrier, notification, scanner, OCR, calendar, file-picker, outbound email, or background automation behavior.")
        .font(.caption.weight(.semibold))
        .foregroundStyle(runbookTone)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func runbookSection(title: String, symbol: String, items: [(String, String, String, Color)]) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(title, systemImage: symbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], alignment: .leading, spacing: 10) {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
          VStack(alignment: .leading, spacing: 6) {
            Label(item.0, systemImage: item.2)
              .font(.caption.weight(.semibold))
              .foregroundStyle(item.3)
            Text(item.1)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background(item.3.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }
    }
  }
}

struct MVPHandsOnTroubleshootingGuide: View {
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

  private var latestMailboxDetail: String {
    guard let summary = latestSpaceMailSummary else {
      return "No refresh summary yet. Start with the local demo workflow, then use SpaceMail only when credentials are ready."
    }
    return "\(summary.fetchedCount) fetched, \(summary.importedCount) imported, \(summary.duplicateCount) duplicate, \(summary.filteredCount) filtered, \(summary.pendingUncertainReviewCount + summary.uncertainCount) uncertain. \(summary.nextAction)"
  }

  private var issueTone: Color {
    if !hasSpaceMailSetup || !hasSpaceMailCredential { return .orange }
    if let latestSpaceMailSummary, latestSpaceMailSummary.pendingUncertainReviewCount > 0 || latestSpaceMailSummary.uncertainCount > 0 { return .orange }
    return .teal
  }

  private var issueTitle: String {
    if !hasSpaceMailSetup { return "Most issues can be tested with the local demo first" }
    if !hasSpaceMailCredential { return "SpaceMail setup exists; credential still needs attention" }
    if let latestSpaceMailSummary, latestSpaceMailSummary.pendingUncertainReviewCount > 0 || latestSpaceMailSummary.uncertainCount > 0 {
      return "SpaceMail has uncertain messages to review"
    }
    return "Use this guide when Xcode, setup, or mailbox testing stalls"
  }

  private var quickChecks: [(String, String, String, Color)] {
    [
      (
        "Xcode signing error",
        "If Xcode says a development team is required, open the ParcelOps target, choose Signing & Capabilities, select your team, then run again. This is local Xcode state and should not be committed unless deliberately shared.",
        "person.badge.key.fill",
        .orange
      ),
      (
        "LLDB already attached",
        "If Xcode says it cannot attach to a process more than once, stop the running app, quit any duplicate ParcelOps windows if needed, then run again. A clean Xcode restart is acceptable.",
        "ladybug.fill",
        .purple
      ),
      (
        "Settings sheet too tall",
        "Setup editors are intended to scroll with Save and Cancel reachable at the bottom. If actions are hidden, use the Settings setup search to narrow the page and reopen the editor.",
        "rectangle.and.pencil.and.ellipsis",
        .teal
      ),
      (
        "SwiftPM build database error",
        "A command-line build can compile/link successfully and still report a generated .build/build.db disk I/O error. Clean generated build data before treating it as a source failure.",
        "hammer.fill",
        .secondary
      ),
      (
        "SpaceMail imports nothing",
        "Mixed mailbox mode is conservative. Filtered non-order mail stays out of Inbox; uncertain messages stay in Mailbox Monitor; only strong order/tracking evidence imports automatically.",
        "line.3.horizontal.decrease.circle",
        .blue
      ),
      (
        "Duplicate mailbox rows",
        "Duplicate provider message IDs should not create duplicate intake. Use refresh summaries, reprocess, or duplicate-refresh audit entries to confirm existing rows were updated or skipped.",
        "doc.on.doc.fill",
        .green
      )
    ]
  }

  private var recoverySteps: [(String, String, String, Color)] {
    [
      ("1. Prove local flow", "Seed the demo workflow from Dashboard or MVP Setup. This avoids relying on live mailbox content while testing UI and persistence.", "wand.and.stars", .green),
      ("2. Check source trail", "Open Inbox, Orders, and order detail. Confirm the source trail points back to intake/import/acceptance context.", "link.badge.plus", .blue),
      ("3. Use Mailbox Monitor", "For SpaceMail, review latest refresh counts, uncertain examples, filtered examples, classifier tests, and credential status before changing parser rules.", "server.rack", .teal),
      ("4. Confirm Audit", "Use Audit to verify local actions. Technical SpaceMail diagnostics can stay hidden unless you are debugging parser/provider internals.", "list.clipboard.fill", .purple),
      ("5. Keep generated noise out", "Do not commit xcuserdata, DerivedData, local signing/team changes, or accidental generated project folders unless the change is intentionally shared.", "xmark.bin.fill", .orange)
    ]
  }

  var body: some View {
    SettingsPanel(title: "Hands-on troubleshooting", symbol: "wrench.and.screwdriver.fill") {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "wrench.and.screwdriver.fill")
          .foregroundStyle(issueTone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(issueTitle)
            .font(.headline)
          Text(latestMailboxDetail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge(hasSpaceMailCredential ? "Ready" : "Setup", color: issueTone)
      }

      MetricStrip(items: [
        ("SpaceMail", hasSpaceMailSetup ? "Set" : "Needed", hasSpaceMailSetup ? .green : .orange),
        ("Credential", hasSpaceMailCredential ? "Keychain" : "Needed", hasSpaceMailCredential ? .green : .orange),
        ("Fetched", "\(latestSpaceMailSummary?.fetchedCount ?? 0)", .blue),
        ("Filtered", "\(latestSpaceMailSummary?.filteredCount ?? 0)", (latestSpaceMailSummary?.filteredCount ?? 0) > 0 ? .teal : .secondary),
        ("Uncertain", "\(latestSpaceMailSummary?.pendingUncertainReviewCount ?? latestSpaceMailSummary?.uncertainCount ?? 0)", ((latestSpaceMailSummary?.pendingUncertainReviewCount ?? latestSpaceMailSummary?.uncertainCount ?? 0) > 0) ? .orange : .secondary),
        ("Audit", "\(store.auditEvents.count)", store.auditEvents.isEmpty ? .orange : .purple)
      ])

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], alignment: .leading, spacing: 10) {
        ForEach(Array(quickChecks.enumerated()), id: \.offset) { _, item in
          troubleshootingTile(title: item.0, detail: item.1, symbol: item.2, color: item.3)
        }
      }

      VStack(alignment: .leading, spacing: 10) {
        Label("Recovery order", systemImage: "arrow.triangle.2.circlepath.circle.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(Array(recoverySteps.enumerated()), id: \.offset) { _, item in
            troubleshootingTile(title: item.0, detail: item.1, symbol: item.2, color: item.3)
          }
        }
      }

      CompactActionRow {
        Button("Seed demo workflow", systemImage: "wand.and.stars") {
          store.seedLocalInboxOrderDemoWorkflow()
        }
        .buttonStyle(.borderedProminent)

        NavigationLink { MailboxView(store: store) } label: { Label("Mailbox Monitor", systemImage: "server.rack") }
          .buttonStyle(.bordered)
        NavigationLink { InboxView(store: store) } label: { Label("Inbox", systemImage: "tray.full.fill") }
          .buttonStyle(.bordered)
        NavigationLink { AuditView(store: store) } label: { Label("Audit", systemImage: "list.clipboard.fill") }
          .buttonStyle(.bordered)
        NavigationLink { IntegrationsView(store: store) } label: { Label("Settings", systemImage: "gearshape.fill") }
          .buttonStyle(.bordered)
      }

      Text("Troubleshooting boundary: this guide only explains local recovery steps and can seed local demo records. It does not run mailbox refresh, change credentials, mutate mailbox messages, clean build folders, edit signing, or touch external services.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func troubleshootingTile(title: String, detail: String, symbol: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 6) {
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
