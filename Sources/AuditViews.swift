import SwiftUI

struct AuditView: View {
  var store: ParcelOpsStore
  @State private var auditSearchText = ""
  @State private var selectedAction: AuditAction?
  @State private var selectedEntityType: AuditEntityType?
  @State private var showTechnicalDiagnostics = false
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var normalizedAuditSearch: String {
    auditSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  private var searchMatchedEvents: [AuditEvent] {
    store.auditEvents.filter(eventMatchesSearch)
  }

  private var filteredEvents: [AuditEvent] {
    searchMatchedEvents.filter { event in
      let matchesAction = selectedAction == nil || event.action == selectedAction
      let matchesEntity = selectedEntityType == nil || event.entityType == selectedEntityType
      let matchesDiagnosticMode = showTechnicalDiagnostics || !event.isTechnicalMailboxDiagnostic
      return matchesAction && matchesEntity && matchesDiagnosticMode
    }
  }

  private var hiddenFilteredTechnicalDiagnosticCount: Int {
    searchMatchedEvents.filter { event in
      let matchesAction = selectedAction == nil || event.action == selectedAction
      let matchesEntity = selectedEntityType == nil || event.entityType == selectedEntityType
      return matchesAction && matchesEntity && event.isTechnicalMailboxDiagnostic
    }.count
  }

  private var visibleActivityEvents: [AuditEvent] {
    showTechnicalDiagnostics ? searchMatchedEvents : searchMatchedEvents.filter { !$0.isTechnicalMailboxDiagnostic }
  }

  private var recentEvents: [AuditEvent] {
    Array(visibleActivityEvents.prefix(18))
  }

  private var workflowEvents: [AuditEvent] {
    recentEvents.filter(\.isWorkflowAction)
  }

  private var recordChangeEvents: [AuditEvent] {
    recentEvents.filter(\.isRecordChange)
  }

  private var mvpFollowUpEvents: [AuditEvent] {
    searchMatchedEvents.filter(\.isMVPTestOrReleaseFollowUp)
  }

  private var visibleMVPFollowUpEvents: [AuditEvent] {
    Array(mvpFollowUpEvents.prefix(8))
  }

  private var inboxOrderHandoffEvents: [AuditEvent] {
    searchMatchedEvents.filter(\.isInboxOrderHandoff)
  }

  private var inboxDispatchHandoffEvents: [AuditEvent] {
    searchMatchedEvents.filter(\.isInboxDispatchHandoffTrail)
  }

  private var visibleInboxDispatchHandoffEvents: [AuditEvent] {
    Array(inboxDispatchHandoffEvents.prefix(8))
  }

  private var wishlistPurchaseTrailEvents: [AuditEvent] {
    searchMatchedEvents.filter(\.isWishlistPurchaseTrail)
  }

  private var visibleWishlistPurchaseTrailEvents: [AuditEvent] {
    Array(wishlistPurchaseTrailEvents.prefix(8))
  }

  private var inboxCreatedOrders: [TrackedOrder] {
    store.orders.filter(\.isInboxCreatedLocalOrder)
  }

  private var inboxCreatedOrdersWithSourceTrail: [TrackedOrder] {
    inboxCreatedOrders.filter { sourceTrailCount(for: $0) > 0 }
  }

  private var inboxCreatedOrdersMissingSourceTrail: [TrackedOrder] {
    inboxCreatedOrders.filter { sourceTrailCount(for: $0) == 0 }
  }

  private var mailboxEvidenceEvents: [AuditEvent] {
    searchMatchedEvents.filter { event in
      event.entityType == .spaceMailIMAPConnection
        || event.entityType == .gmailMailboxConnection
        || (event.entityType == .intakeEmail && event.summary.localizedCaseInsensitiveContains("mailbox"))
        || event.summary.localizedCaseInsensitiveContains("spacemail")
        || event.summary.localizedCaseInsensitiveContains("gmail")
    }
  }

  private var visibleMailboxEvidenceEvents: [AuditEvent] {
    showTechnicalDiagnostics ? mailboxEvidenceEvents : mailboxEvidenceEvents.filter { !$0.isTechnicalMailboxDiagnostic }
  }

  private var mailboxProviderReleaseGateEvents: [AuditEvent] {
    searchMatchedEvents.filter(\.isMailboxProviderReleaseGateEvent)
  }

  private var visibleMailboxProviderReleaseGateEvents: [AuditEvent] {
    showTechnicalDiagnostics ? mailboxProviderReleaseGateEvents : mailboxProviderReleaseGateEvents.filter { !$0.isTechnicalMailboxDiagnostic }
  }

  private var hiddenTechnicalDiagnosticCount: Int {
    searchMatchedEvents.filter(\.isTechnicalMailboxDiagnostic).count
  }

  private var spaceMailHealthSummaries: [SpaceMailIntakeHealthSummary] {
    store.spaceMailIntakeHealthSummaries
  }

  private var gmailHealthSummaries: [GmailIntakeHealthSummary] {
    store.gmailIntakeHealthSummaries
  }

  private var latestGmailConnection: GmailMailboxConnection? {
    guard let summary = gmailHealthSummaries.first else { return store.gmailMailboxConnections.first }
    return store.gmailMailboxConnections.first { $0.id == summary.connectionID }
  }

  private var auditGmailReadiness: GmailOAuthReadinessSummary? {
    latestGmailConnection.map { store.gmailOAuthReadinessSummary(for: $0) }
  }

  private var auditGmailCompileBlockers: [String] {
    guard let readiness = auditGmailReadiness else { return [] }
    return readiness.missingFields.filter { field in
      field.localizedCaseInsensitiveContains("compiled App Info.plist")
        || field.localizedCaseInsensitiveContains("callback URL scheme matching")
        || field.localizedCaseInsensitiveContains("OAuth iOS client ID ending")
    }
  }

  private var auditGmailCompileColor: Color {
    guard let readiness = auditGmailReadiness else { return .secondary }
    return readiness.isReady ? .green : .orange
  }

  private var auditGmailCompileTitle: String {
    guard let readiness = auditGmailReadiness else { return "Gmail compiled setup not started" }
    if readiness.isReady { return "Gmail compiled setup is ready" }
    if !auditGmailCompileBlockers.isEmpty { return "Gmail compiled setup blocks real sign-in" }
    return "Gmail setup values need review"
  }

  private var auditGmailCompileDetail: String {
    guard let readiness = auditGmailReadiness else {
      return "Gmail setup is only needed for Gmail or Google Workspace mailboxes. Use the provider that hosts the mailbox being tested."
    }
    if readiness.isReady {
      return "Saved Gmail setup matches the compiled client ID and callback scheme. Audit can focus on sign-in, refresh, classifier, and Inbox handoff evidence."
    }
    if !auditGmailCompileBlockers.isEmpty {
      return "Fix before relying on Gmail audit evidence: \(auditGmailCompileBlockers.joined(separator: "; ")). Update App/Info.plist and Project.json with the Google iOS client ID and reversed client ID scheme, then rebuild."
    }
    return readiness.detailText
  }

  private var spaceMailPostRefreshPlan: SpaceMailPostRefreshActionPlan {
    store.spaceMailPostRefreshActionPlan
  }

  private var spaceMailFetchedCount: Int {
    spaceMailHealthSummaries.reduce(0) { $0 + $1.fetchedCount }
  }

  private var spaceMailImportedCount: Int {
    spaceMailHealthSummaries.reduce(0) { $0 + $1.importedCount }
  }

  private var spaceMailDuplicateCount: Int {
    spaceMailHealthSummaries.reduce(0) { $0 + $1.duplicateCount }
  }

  private var spaceMailDuplicateRefreshedCount: Int {
    spaceMailHealthSummaries.reduce(0) { $0 + $1.duplicateRefreshedCount }
  }

  private var spaceMailFilteredCount: Int {
    spaceMailHealthSummaries.reduce(0) { $0 + $1.filteredCount }
  }

  private var spaceMailUncertainCount: Int {
    spaceMailHealthSummaries.reduce(0) { $0 + $1.uncertainCount + $1.pendingUncertainReviewCount }
  }

  private var spaceMailParserIssueCount: Int {
    spaceMailHealthSummaries.reduce(0) { $0 + $1.parserIssueCount }
  }

  private var spaceMailFilteredOnlyOutcome: Bool {
    spaceMailFetchedCount > 0
      && spaceMailImportedCount == 0
      && spaceMailUncertainCount == 0
      && spaceMailFilteredCount > 0
  }

  private var gmailFetchedCount: Int {
    gmailHealthSummaries.reduce(0) { $0 + $1.fetchedCount }
  }

  private var gmailImportedCount: Int {
    gmailHealthSummaries.reduce(0) { $0 + $1.importedCount }
  }

  private var gmailDuplicateCount: Int {
    gmailHealthSummaries.reduce(0) { $0 + $1.duplicateCount }
  }

  private var gmailDuplicateRefreshedCount: Int {
    gmailHealthSummaries.reduce(0) { $0 + $1.duplicateRefreshedCount }
  }

  private var pendingFilteredGmailCount: Int {
    store.gmailMailboxConnections.reduce(0) { total, connection in
      total + (connection.filteredMessages?.count ?? 0)
    }
  }

  private var pendingUncertainGmailCount: Int {
    store.gmailMailboxConnections.reduce(0) { total, connection in
      total + (connection.uncertainMessages?.count ?? 0)
    }
  }

  private var gmailFilteredCount: Int {
    max(gmailHealthSummaries.reduce(0) { $0 + $1.filteredCount }, pendingFilteredGmailCount)
  }

  private var gmailUncertainCount: Int {
    max(gmailHealthSummaries.reduce(0) { $0 + $1.uncertainCount + $1.pendingUncertainReviewCount }, pendingUncertainGmailCount)
  }

  private var mailboxFetchedCount: Int {
    spaceMailFetchedCount + gmailFetchedCount
  }

  private var mailboxImportedCount: Int {
    spaceMailImportedCount + gmailImportedCount
  }

  private var mailboxDuplicateCount: Int {
    spaceMailDuplicateCount + gmailDuplicateCount
  }

  private var mailboxDuplicateRefreshedCount: Int {
    spaceMailDuplicateRefreshedCount + gmailDuplicateRefreshedCount
  }

  private var mailboxFilteredCount: Int {
    spaceMailFilteredCount + gmailFilteredCount
  }

  private var mailboxUncertainCount: Int {
    spaceMailUncertainCount + gmailUncertainCount
  }

  private var mailboxFilteredOnlyOutcome: Bool {
    mailboxFetchedCount > 0
      && mailboxImportedCount == 0
      && mailboxUncertainCount == 0
      && mailboxFilteredCount > 0
  }

  private var mailboxAuditProviderBreakdown: [(provider: String, detail: String, color: Color)] {
    var rows: [(provider: String, detail: String, color: Color)] = []

    if !spaceMailHealthSummaries.isEmpty {
      rows.append((
        "SpaceMail",
        "\(spaceMailFetchedCount) fetched, \(spaceMailImportedCount) imported, \(spaceMailDuplicateCount) duplicate, \(spaceMailDuplicateRefreshedCount) refreshed, \(spaceMailFilteredCount) filtered, \(spaceMailUncertainCount) uncertain.",
        spaceMailImportedCount > 0 ? .green : spaceMailUncertainCount > 0 ? .orange : spaceMailFilteredCount > 0 ? .teal : .secondary
      ))
    }

    if !gmailHealthSummaries.isEmpty {
      rows.append((
        "Gmail",
        "\(gmailFetchedCount) fetched, \(gmailImportedCount) imported, \(gmailDuplicateCount) duplicate, \(gmailDuplicateRefreshedCount) refreshed, \(gmailFilteredCount) filtered, \(gmailUncertainCount) uncertain.",
        gmailImportedCount > 0 ? .green : gmailUncertainCount > 0 ? .orange : gmailFilteredCount > 0 ? .teal : .secondary
      ))
    }

    return rows
  }

  private var auditNextCheckTitle: String {
    if !mvpFollowUpEvents.isEmpty {
      return "Review MVP test and release follow-ups"
    }
    if store.mailboxProviderReleaseGateSummary.tone != "success" || !mailboxProviderReleaseGateEvents.isEmpty {
      return "Check mailbox provider release gate"
    }
    if !mailboxEvidenceEvents.isEmpty {
      return "Check the latest mailbox intake result"
    }
    if !inboxDispatchHandoffEvents.isEmpty {
      return "Confirm Inbox dispatch handoff trail"
    }
    if !inboxOrderHandoffEvents.isEmpty {
      return "Confirm Inbox-to-order handoff"
    }
    if !workflowEvents.isEmpty {
      return "Review recent operator actions"
    }
    if !recordChangeEvents.isEmpty {
      return "Review recent record changes"
    }
    return "No local audit checks yet"
  }

  private var auditNextCheckDetail: String {
    if !mvpFollowUpEvents.isEmpty {
      return "Start with local data hygiene, operator test-session, and release snapshot tasks so readiness gaps stay visible in Tasks instead of being buried in Audit."
    }
    if store.mailboxProviderReleaseGateSummary.tone != "success" || !mailboxProviderReleaseGateEvents.isEmpty {
      return "Use the release gate focus to confirm whether active mailbox providers, Inbox intake, task follow-up, and provider evidence are ready for operator testing."
    }
    if !mailboxEvidenceEvents.isEmpty {
      return "Start with mailbox intake evidence to confirm fetches, filtering, parser decisions, duplicates, and imported order signals across the active providers."
    }
    if !inboxDispatchHandoffEvents.isEmpty {
      return "Check reopened and completed dispatch handoff events together so Inbox-created order follow-up does not get lost across Orders, Dispatch, and Tasks."
    }
    if !inboxOrderHandoffEvents.isEmpty {
      return "Check that created or linked orders still have a clear source trail back to Inbox, Import Queue, or Acceptance Review."
    }
    if !workflowEvents.isEmpty {
      return "Scan workflow actions for reviews, completions, handoffs, task creation, and draft work that may need follow-up."
    }
    if !recordChangeEvents.isEmpty {
      return "Use record changes to confirm creates, edits, removals, enables, disables, and pinned changes were intentional."
    }
    return "Perform a local action such as reviewing intake, creating a task, or editing an order; the result will appear here."
  }

  private var auditNextCheckSymbol: String {
    if !mvpFollowUpEvents.isEmpty { return "checkmark.rectangle.stack.fill" }
    if store.mailboxProviderReleaseGateSummary.tone != "success" || !mailboxProviderReleaseGateEvents.isEmpty { return "checkmark.seal.fill" }
    if !mailboxEvidenceEvents.isEmpty { return "tray.and.arrow.down.fill" }
    if !inboxDispatchHandoffEvents.isEmpty { return "arrow.triangle.2.circlepath.circle.fill" }
    if !inboxOrderHandoffEvents.isEmpty { return "arrow.triangle.branch" }
    if !workflowEvents.isEmpty { return "checklist" }
    if !recordChangeEvents.isEmpty { return "pencil.and.list.clipboard" }
    return "list.clipboard.fill"
  }

  private var auditEvidenceItems: [(title: String, detail: String, count: Int, symbol: String, color: Color)] {
    [
      (
        "Mailbox release gate",
        "\(store.mailboxProviderReleaseGateSummary.verdict): \(store.mailboxProviderReleaseGateSummary.detail)",
        store.mailboxProviderReleaseGateSummary.gates.filter(\.isPassed).count,
        "checkmark.seal.fill",
        color(for: store.mailboxProviderReleaseGateSummary.tone)
      ),
      (
        "Mailbox refresh evidence",
        "Active mailbox-provider events show fetched, imported, filtered, duplicate, parser, credential, or sign-in activity.",
        mailboxEvidenceEvents.count,
        "server.rack",
        mailboxEvidenceEvents.isEmpty ? .orange : .teal
      ),
      (
        "Inbox-to-order handoff",
        "Audit can explain when intake became a linked or created local order.",
        inboxOrderHandoffEvents.count,
        "link.badge.plus",
        inboxOrderHandoffEvents.isEmpty ? .orange : .blue
      ),
      (
        "Dispatch handoff trail",
        "Dispatch actions show whether Inbox-created orders gained manifest/readiness context.",
        inboxDispatchHandoffEvents.count,
        "paperplane.fill",
        inboxDispatchHandoffEvents.isEmpty ? .secondary : .purple
      ),
      (
        "Workflow actions",
        "Operator reviews, task creation, acknowledgements, completions, drafts, and handoffs are grouped separately from raw logs.",
        workflowEvents.count,
        "checklist",
        workflowEvents.isEmpty ? .secondary : .teal
      ),
      (
        "Record changes",
        "Creates, edits, removals, enables, disables, and local corrections remain visible for traceability.",
        recordChangeEvents.count,
        "pencil.and.list.clipboard",
        recordChangeEvents.isEmpty ? .secondary : .orange
      ),
      (
        "Technical diagnostics",
        "Parser, duplicate, and mailbox internals are hidden by default so daily audit review stays readable.",
        hiddenTechnicalDiagnosticCount,
        "eye.slash.fill",
        hiddenTechnicalDiagnosticCount == 0 ? .secondary : .orange
      )
    ]
  }

  private func color(for tone: String) -> Color {
    switch tone {
    case "success":
      return .green
    case "attention":
      return .orange
    case "warning":
      return .red
    default:
      return .secondary
    }
  }

  private var auditEvidenceReadyCount: Int {
    auditEvidenceItems.filter { item in
      item.count > 0 || item.title == "Technical diagnostics"
    }.count
  }

  private func eventMatchesSearch(_ event: AuditEvent) -> Bool {
    let query = normalizedAuditSearch
    guard !query.isEmpty else { return true }
    let searchableText = [
      event.timestamp,
      event.actor,
      event.action.rawValue,
      event.entityType.rawValue,
      event.entityID,
      event.entityLabel,
      event.summary,
      event.beforeDetail ?? "",
      event.afterDetail ?? ""
    ].joined(separator: " ").lowercased()

    return searchableText.contains(query)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header

        auditNextCheckPanel
        mailboxProviderReleaseGateAuditPanel
        auditEvidenceChecklistPanel

        MVPWorkflowGuide(
          title: "Audit workflow",
          detail: "Use this screen to confirm local workflow actions, record changes, and follow-up creation.",
          steps: [
            "Start with the grouped feed to understand what happened recently.",
            "Use the detailed log when you need to filter by action or record type.",
            "Create a task from an event if the history reveals follow-up work."
          ],
          symbol: "list.clipboard.fill"
        )

        SpaceMailQACheckCard(summary: store.spaceMailQACheckSummary)
        SpaceMailRefreshTrendCard(summary: store.spaceMailRefreshTrendSummary)
        spaceMailAuditOutcomePanel

        inboxSourceTrailAuditPanel

        inboxDispatchHandoffTrailPanel

        activityFeed

        SettingsPanel(title: "Detailed audit log", symbol: "line.3.horizontal.decrease.circle.fill") {
          Text("Filter local audit history for a specific action or record type. Technical mailbox diagnostics stay hidden here too unless Show technical diagnostics is enabled.")
            .font(.subheadline)
            .foregroundStyle(.secondary)

          filterBar

          if hiddenFilteredTechnicalDiagnosticCount > 0 && !showTechnicalDiagnostics {
            Label("\(hiddenFilteredTechnicalDiagnosticCount) matching technical diagnostics are hidden. Turn on Show technical diagnostics in the activity feed when investigating parser, duplicate, or mailbox internals.", systemImage: "eye.slash")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          if filteredEvents.isEmpty {
            MVPEmptyState(title: "No operator audit events match this view", detail: hiddenFilteredTechnicalDiagnosticCount > 0 && !showTechnicalDiagnostics ? "Matching technical diagnostics are hidden. Enable Show technical diagnostics to inspect parser, duplicate, or mailbox internals." : "Clear filters or perform a local action such as creating a task, reviewing intake, or updating dispatch readiness.", symbol: "list.clipboard.fill")
          } else {
            ForEach(filteredEvents.prefix(30)) { event in
              AuditEventRow(event: event) {
                store.createReviewTask(from: event)
              }
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private var auditNextCheckPanel: some View {
    SettingsPanel(title: "Audit next check", symbol: auditNextCheckSymbol) {
      VStack(alignment: .leading, spacing: 10) {
        Text(auditNextCheckTitle)
          .font(.headline)
        Text(auditNextCheckDetail)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("MVP follow-up", "\(mvpFollowUpEvents.count)", mvpFollowUpEvents.isEmpty ? .secondary : .purple),
          ("Release gate", "\(mailboxProviderReleaseGateEvents.count)", mailboxProviderReleaseGateEvents.isEmpty ? color(for: store.mailboxProviderReleaseGateSummary.tone) : .orange),
          ("Mailbox evidence", "\(mailboxEvidenceEvents.count)", mailboxEvidenceEvents.isEmpty ? .secondary : .teal),
          ("Hidden technical", "\(showTechnicalDiagnostics ? 0 : hiddenTechnicalDiagnosticCount)", showTechnicalDiagnostics || hiddenTechnicalDiagnosticCount == 0 ? .secondary : .orange),
          ("Inbox handoffs", "\(inboxOrderHandoffEvents.count)", inboxOrderHandoffEvents.isEmpty ? .secondary : .blue),
          ("Dispatch trail", "\(inboxDispatchHandoffEvents.count)", inboxDispatchHandoffEvents.isEmpty ? .secondary : .purple),
          ("Workflow", "\(workflowEvents.count)", workflowEvents.isEmpty ? .secondary : .teal),
          ("Record changes", "\(recordChangeEvents.count)", recordChangeEvents.isEmpty ? .secondary : .orange)
        ])

        CompactActionRow {
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Open Mailbox Monitor", systemImage: "server.rack")
          }
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Open Inbox", systemImage: "tray.full.fill")
          }
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
          NavigationLink {
            SettingsView(store: store)
          } label: {
            Label("Open Settings", systemImage: "gearshape.2.fill")
          }
        }
        .buttonStyle(.bordered)

        Text("Use Show technical diagnostics only when investigating mailbox connection or parser behavior; the default feed keeps routine operator history readable.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var auditEvidenceChecklistPanel: some View {
    SettingsPanel(title: "Audit evidence checklist", symbol: "checkmark.seal.text.page.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: auditEvidenceReadyCount >= auditEvidenceItems.count - 1 ? "checkmark.seal.fill" : "list.clipboard.fill")
            .font(.title3)
            .foregroundStyle(auditEvidenceReadyCount >= auditEvidenceItems.count - 1 ? .green : .orange)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text(auditEvidenceReadyCount >= auditEvidenceItems.count - 1 ? "Audit has usable workflow evidence" : "Audit still needs more operator evidence")
              .font(.headline)
            Text("Use this checklist to decide whether Audit proves the daily flow, rather than just showing technical mailbox diagnostics.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer(minLength: 8)
          Badge("\(auditEvidenceReadyCount)/\(auditEvidenceItems.count)", color: auditEvidenceReadyCount >= auditEvidenceItems.count - 1 ? .green : .orange)
        }

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 170 : 220), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(auditEvidenceItems, id: \.title) { item in
            VStack(alignment: .leading, spacing: 8) {
              HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(item.title, systemImage: item.symbol)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(item.color)
                Spacer()
                Badge(item.count == 0 ? "None" : "\(item.count)", color: item.color)
              }
              Text(item.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(item.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }

        Text("Local boundary: Audit only displays local events already recorded by ParcelOps. This panel does not create records, fetch mail, mutate mailbox messages, send notifications, or call external services.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Audit")
        .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
      Text("Readable local activity history for operator actions, record changes, reviews, and follow-up work.")
        .foregroundStyle(.secondary)

      MetricStrip(items: [
        ("Recent", "\(recentEvents.count)", .blue),
        ("Workflow", "\(workflowEvents.count)", .teal),
        ("MVP follow-up", "\(mvpFollowUpEvents.count)", mvpFollowUpEvents.isEmpty ? .secondary : .purple),
        ("Release gate", store.mailboxProviderReleaseGateSummary.verdict, color(for: store.mailboxProviderReleaseGateSummary.tone)),
        ("Mailbox", "\(mailboxEvidenceEvents.count)", mailboxEvidenceEvents.isEmpty ? .secondary : .teal),
        ("Hidden tech", "\(showTechnicalDiagnostics ? 0 : hiddenTechnicalDiagnosticCount)", showTechnicalDiagnostics || hiddenTechnicalDiagnosticCount == 0 ? .secondary : .orange),
        ("Inbox handoff", "\(inboxOrderHandoffEvents.count)", inboxOrderHandoffEvents.isEmpty ? .green : .teal),
        ("Dispatch trail", "\(inboxDispatchHandoffEvents.count)", inboxDispatchHandoffEvents.isEmpty ? .green : .purple),
        ("Source trail", "\(inboxCreatedOrdersWithSourceTrail.count)", inboxCreatedOrdersMissingSourceTrail.isEmpty ? .green : .orange),
        ("Changes", "\(recordChangeEvents.count)", .orange),
        ("Tasks", "\(recentEvents.filter { $0.entityType == .reviewTask }.count)", .purple),
        ("Removed", "\(recentEvents.filter { $0.action == .removed }.count)", .red)
      ])
    }
  }

  private var mailboxProviderReleaseGateAuditPanel: some View {
    SettingsPanel(title: "Mailbox provider release gate", symbol: "checkmark.seal.fill") {
      VStack(alignment: .leading, spacing: 12) {
        MailboxProviderReleaseGateCard(summary: store.mailboxProviderReleaseGateSummary, store: nil)
        MailboxProviderHandoffPacketCard(packet: store.mailboxProviderHandoffPacketSummary, store: store, showAuditLink: false)

        gmailAuditReadinessPanel

        CompactActionRow {
          Button("Create gate task", systemImage: "checklist") {
            store.createReviewTaskFromMailboxProviderReleaseGate()
          }
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Open Mailbox Monitor", systemImage: "server.rack")
          }
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
          NavigationLink {
            OperationsWorkbenchView(store: store)
          } label: {
            Label("Open Workbench", systemImage: "rectangle.stack.badge.person.crop.fill")
          }
        }
        .buttonStyle(.bordered)

        if visibleMailboxProviderReleaseGateEvents.isEmpty {
          Label("No release-gate audit events yet. Create or refresh the gate task when you want a local review trail for provider readiness.", systemImage: "list.clipboard")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        } else {
          VStack(alignment: .leading, spacing: 8) {
            Label("Recent release-gate audit trail", systemImage: "clock.arrow.circlepath")
              .font(.caption.weight(.semibold))
              .foregroundStyle(color(for: store.mailboxProviderReleaseGateSummary.tone))

            ForEach(visibleMailboxProviderReleaseGateEvents.prefix(3)) { event in
              HStack(alignment: .top, spacing: 10) {
                Image(systemName: event.entityType.symbol)
                  .foregroundStyle(event.action.color)
                  .frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                  Text(event.entityLabel)
                    .font(.caption.weight(.semibold))
                  Text(event.summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                  Text(event.timestamp)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(event.action.color)
                }
                Spacer(minLength: 8)
                Badge(event.action.rawValue, color: event.action.color)
              }
              .padding(10)
              .background(event.action.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }

        Text("Audit focus: this is a local evidence view for provider readiness. It does not run mailbox refreshes, read credentials, call external services, or mutate mailbox messages.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var gmailAuditReadinessPanel: some View {
    VStack(alignment: .leading, spacing: 10) {
      GmailReleaseBoundaryPanel(
        store: store,
        title: "Gmail audit readiness",
        lead: "Use this to confirm local audit evidence for Gmail setup, sign-in, label resolution, classifier review, Inbox handoff, and release task creation.",
        sourceMetricTitle: "Audit events",
        sourceCount: mailboxProviderReleaseGateEvents.count,
        boundaryDetail: "Local-only boundary: this panel displays local audit readiness only. It does not start Google sign-in, fetch Gmail, store token values, mutate mailbox messages, or create hidden workflow actions."
      )

      if !store.gmailMailboxConnections.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Label(auditGmailCompileTitle, systemImage: auditGmailReadiness?.isReady == true ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(auditGmailCompileColor)
          Text(auditGmailCompileDetail)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          if let readiness = auditGmailReadiness {
            CompactMetadataGrid(minimumWidth: horizontalSizeClass == .compact ? 150 : 175) {
              Badge(readiness.compiledClientIDStatus, color: readiness.compiledClientIDStatus.localizedCaseInsensitiveContains("matches") || readiness.compiledClientIDStatus.localizedCaseInsensitiveContains("present") ? .green : .orange)
              Badge(readiness.compiledCallbackSchemeStatus, color: readiness.compiledCallbackSchemeStatus.localizedCaseInsensitiveContains("includes") || readiness.compiledCallbackSchemeStatus.localizedCaseInsensitiveContains("present") ? .green : .orange)
              Badge(readiness.expectedCallbackScheme, color: .secondary)
            }
          }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(auditGmailCompileColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }
    }
  }

  private var inboxSourceTrailAuditPanel: some View {
    SettingsPanel(title: "Inbox source trail audit", symbol: "link.badge.plus") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Current Inbox-created orders should remain traceable back to forwarded intake, Import Queue, or Acceptance Review. Use this check before relying on handoff history alone.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Inbox orders", "\(inboxCreatedOrders.count)", inboxCreatedOrders.isEmpty ? .secondary : .teal),
          ("With source", "\(inboxCreatedOrdersWithSourceTrail.count)", inboxCreatedOrdersWithSourceTrail.isEmpty ? .secondary : .green),
          ("Missing source", "\(inboxCreatedOrdersMissingSourceTrail.count)", inboxCreatedOrdersMissingSourceTrail.isEmpty ? .green : .orange)
        ])

        if inboxCreatedOrdersMissingSourceTrail.isEmpty {
          Label(inboxCreatedOrders.isEmpty ? "No Inbox-created orders exist yet." : "All current Inbox-created orders have local source context.", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
        } else {
          ForEach(inboxCreatedOrdersMissingSourceTrail.prefix(4)) { order in
            NavigationLink {
              OrderDetailView(order: order, store: store)
            } label: {
              HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundStyle(.orange)
                  .frame(width: 22)
                VStack(alignment: .leading, spacing: 4) {
                  Text("\(order.store) • \(order.orderNumber)")
                    .font(.subheadline.weight(.semibold))
                  Text("No linked intake, import, or acceptance source currently matches this order. Open the order source trail before closing related audit follow-up.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Badge("Trace", color: .orange)
              }
              .padding(10)
              .background(Color.orange.opacity(0.08))
              .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }

  private var spaceMailAuditOutcomePanel: some View {
    SettingsPanel(title: "Mailbox audit outcome", symbol: "tray.and.arrow.down.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: spaceMailAuditOutcomeSymbol)
            .font(.title3)
            .foregroundStyle(spaceMailAuditOutcomeColor)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text(spaceMailAuditOutcomeTitle)
              .font(.headline)
            Text(spaceMailAuditOutcomeDetail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        MetricStrip(items: [
          ("Fetched", "\(mailboxFetchedCount)", mailboxFetchedCount == 0 ? .secondary : .blue),
          ("Imported", "\(mailboxImportedCount)", mailboxImportedCount == 0 ? .secondary : .green),
          ("Uncertain", "\(mailboxUncertainCount)", mailboxUncertainCount == 0 ? .secondary : .orange),
          ("Filtered", "\(mailboxFilteredCount)", mailboxFilteredCount == 0 ? .secondary : .teal),
          ("Duplicates", "\(mailboxDuplicateCount)", mailboxDuplicateCount == 0 ? .secondary : .teal),
          ("Refreshed", "\(mailboxDuplicateRefreshedCount)", mailboxDuplicateRefreshedCount == 0 ? .secondary : .green),
          ("Parser", "\(spaceMailParserIssueCount)", spaceMailParserIssueCount == 0 ? .secondary : .purple),
          ("Hidden tech", "\(showTechnicalDiagnostics ? 0 : hiddenTechnicalDiagnosticCount)", showTechnicalDiagnostics || hiddenTechnicalDiagnosticCount == 0 ? .secondary : .orange)
        ])

        if !mailboxAuditProviderBreakdown.isEmpty {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 180 : 230), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(mailboxAuditProviderBreakdown, id: \.provider) { row in
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: row.provider == "Gmail" ? "envelope.badge.shield.half.filled" : "server.rack")
                  .foregroundStyle(row.color)
                  .frame(width: 18)
                VStack(alignment: .leading, spacing: 3) {
                  Text(row.provider)
                    .font(.caption.weight(.semibold))
                  Text(row.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
              }
              .padding(8)
              .frame(maxWidth: .infinity, alignment: .topLeading)
              .background(row.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 180 : 230), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(spaceMailPostRefreshPlan.items) { item in
            VStack(alignment: .leading, spacing: 6) {
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: item.symbol)
                  .foregroundStyle(auditColor(for: item.tone))
                  .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                  Text(item.title)
                    .font(.caption.weight(.semibold))
                  Text(item.actionLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(auditColor(for: item.tone))
                  Text(item.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Badge("\(item.count)", color: auditColor(for: item.tone))
              }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(auditColor(for: item.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }

        if !gmailHealthSummaries.isEmpty {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 180 : 230), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(gmailHealthSummaries.prefix(3)) { summary in
              VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                  Image(systemName: "envelope.badge.shield.half.filled")
                    .foregroundStyle(auditColor(for: summary.tone))
                    .frame(width: 18)
                  VStack(alignment: .leading, spacing: 2) {
                    Text(summary.displayName)
                      .font(.caption.weight(.semibold))
                    Text(summary.verdict)
                      .font(.caption2.weight(.semibold))
                      .foregroundStyle(auditColor(for: summary.tone))
                    Text(summary.nextAction)
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                      .fixedSize(horizontal: false, vertical: true)
                  }
                  Spacer()
                  Badge("Gmail", color: auditColor(for: summary.tone))
                }
              }
              .padding(10)
              .frame(maxWidth: .infinity, alignment: .topLeading)
              .background(auditColor(for: summary.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }

          GmailPostRefreshActionCard(plan: store.gmailPostRefreshActionPlan)
        }

        Text(spaceMailAuditOutcomeFootnote)
          .font(.caption.weight(.semibold))
          .foregroundStyle(spaceMailAuditOutcomeColor)
          .fixedSize(horizontal: false, vertical: true)

        CompactActionRow {
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Open Mailbox Monitor", systemImage: "server.rack")
          }
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Open Inbox", systemImage: "tray.full.fill")
          }
          NavigationLink {
            OperationsWorkbenchView(store: store)
          } label: {
            Label("Open Workbench", systemImage: "rectangle.stack.badge.person.crop.fill")
          }
          Button(showTechnicalDiagnostics ? "Hide technical diagnostics" : "Show technical diagnostics", systemImage: showTechnicalDiagnostics ? "eye.slash" : "eye") {
            showTechnicalDiagnostics.toggle()
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private var spaceMailAuditOutcomeTitle: String {
    if mailboxImportedCount > 0 { return "Mailbox imported order candidates" }
    if mailboxUncertainCount > 0 { return "Mailbox has uncertain previews" }
    if spaceMailParserIssueCount > 0 { return "Mailbox parser diagnostics need review" }
    if mailboxFilteredOnlyOutcome { return "Mailbox refresh was mostly non-order mail" }
    if mailboxFetchedCount > 0 { return "Mailbox refresh created no operator work" }
    return spaceMailPostRefreshPlan.title
  }

  private var spaceMailAuditOutcomeDetail: String {
    if mailboxImportedCount > 0 {
      return "\(mailboxImportedCount) message reached Inbox as likely order intake across configured mailboxes. Use Audit to confirm the import happened, then continue in Inbox or Orders."
    }
    if mailboxUncertainCount > 0 {
      return "\(mailboxUncertainCount) ambiguous message is held outside Inbox. Review it in Mailbox Monitor before creating tasks or orders."
    }
    if spaceMailParserIssueCount > 0 {
      return "\(spaceMailParserIssueCount) parser diagnostic is available. Keep technical diagnostics hidden unless you need the full evidence trail."
    }
    if mailboxFilteredOnlyOutcome {
      return "\(mailboxFilteredCount) fetched message was filtered as non-order mail. That is expected for mixed mailboxes and does not require task or Workbench follow-up."
    }
    if mailboxFetchedCount > 0 {
      return "The latest refresh fetched mail but did not import, hold uncertain, or create parser work."
    }
    return spaceMailPostRefreshPlan.detail
  }

  private var spaceMailAuditOutcomeFootnote: String {
    if hiddenTechnicalDiagnosticCount > 0 && !showTechnicalDiagnostics {
      return "\(hiddenTechnicalDiagnosticCount) duplicate, parser, no-change, or provider-ID diagnostics are hidden from the default operator feed. Turn them on only when investigating intake internals."
    }
    return "Audit keeps the operator outcome visible first. Detailed duplicate, parser, and provider-ID evidence remains available without storing passwords, auth strings, or full message bodies."
  }

  private var spaceMailAuditOutcomeSymbol: String {
    if mailboxImportedCount > 0 { return "tray.full.fill" }
    if mailboxUncertainCount > 0 { return "questionmark.folder.fill" }
    if spaceMailParserIssueCount > 0 { return "text.magnifyingglass" }
    if mailboxFilteredOnlyOutcome { return "checkmark.seal.fill" }
    return "tray.and.arrow.down.fill"
  }

  private var spaceMailAuditOutcomeColor: Color {
    if mailboxImportedCount > 0 || mailboxUncertainCount > 0 { return .orange }
    if spaceMailParserIssueCount > 0 { return .purple }
    if mailboxFilteredOnlyOutcome { return .green }
    if mailboxFetchedCount > 0 { return .teal }
    return auditColor(for: spaceMailPostRefreshPlan.tone)
  }

  private func auditColor(for tone: String) -> Color {
    switch tone.localizedLowercase {
    case "success":
      return .green
    case "attention":
      return .orange
    case "warning":
      return .red
    case "neutral":
      return .teal
    default:
      return .blue
    }
  }

  @ViewBuilder
  private var inboxDispatchHandoffTrailPanel: some View {
    if !inboxDispatchHandoffEvents.isEmpty {
      SettingsPanel(title: "Inbox dispatch handoff trail", symbol: "arrow.triangle.2.circlepath.circle.fill") {
        VStack(alignment: .leading, spacing: 12) {
          Text("Recent local events that connect Inbox-created orders to Dispatch and Tasks. Use this trail when a handoff is reopened, completed, or resolved locally.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          MetricStrip(items: [
            ("Trail events", "\(inboxDispatchHandoffEvents.count)", .purple),
            ("Reopened", "\(inboxDispatchHandoffEvents.filter(\.isReopenedInboxDispatchHandoffTrail).count)", inboxDispatchHandoffEvents.contains(where: \.isReopenedInboxDispatchHandoffTrail) ? .orange : .secondary),
            ("Completed", "\(inboxDispatchHandoffEvents.filter(\.isCompletedInboxDispatchHandoffTrail).count)", inboxDispatchHandoffEvents.contains(where: \.isCompletedInboxDispatchHandoffTrail) ? .green : .secondary),
            ("Tasks", "\(inboxDispatchHandoffEvents.filter { $0.entityType == .reviewTask }.count)", inboxDispatchHandoffEvents.contains { $0.entityType == .reviewTask } ? .purple : .secondary)
          ])

          ForEach(visibleInboxDispatchHandoffEvents.prefix(4)) { event in
            HStack(alignment: .top, spacing: 10) {
              Image(systemName: event.inboxDispatchHandoffTrailSymbol)
                .foregroundStyle(event.inboxDispatchHandoffTrailColor)
                .frame(width: 22, height: 22)
              VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                  Text(event.entityLabel)
                    .font(.subheadline.weight(.semibold))
                  Spacer(minLength: 8)
                  Badge(event.inboxDispatchHandoffTrailLabel, color: event.inboxDispatchHandoffTrailColor)
                }
                Text(event.summary)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
                Text(event.inboxDispatchHandoffTrailGuidance)
                  .font(.caption)
                  .foregroundStyle(event.inboxDispatchHandoffTrailColor)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
            .padding(10)
            .background(event.inboxDispatchHandoffTrailColor.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 8))
          }
        }
      }
    }
  }

  private var activityFeed: some View {
    SettingsPanel(title: "Activity feed", symbol: "list.clipboard.fill") {
      VStack(alignment: .leading, spacing: 14) {
        Text("A simplified view of what changed recently, grouped by operator meaning rather than raw log order.")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        if !normalizedAuditSearch.isEmpty {
          Label("\(searchMatchedEvents.count) audit events match \"\(auditSearchText)\". Clear filters to return to the full activity feed.", systemImage: "magnifyingglass")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        if recentEvents.isEmpty {
          MVPEmptyState(title: normalizedAuditSearch.isEmpty ? "No audit activity yet" : "No audit events match", detail: normalizedAuditSearch.isEmpty ? "Create, edit, review, or complete a local record and the action will appear here." : "Clear the audit search or try a broader term such as mailbox, Gmail, SpaceMail, order, Inbox, tracking, parser, or the record label.", symbol: "list.clipboard.fill")
        } else {
          Toggle("Show technical diagnostics", isOn: $showTechnicalDiagnostics)
            .font(.caption.weight(.semibold))
            .toggleStyle(.switch)

          if hiddenTechnicalDiagnosticCount > 0 && !showTechnicalDiagnostics {
            Label("\(hiddenTechnicalDiagnosticCount) mailbox parser, duplicate, and no-change diagnostics are hidden from the operator feed. Open the detailed log or enable technical diagnostics when investigating intake internals.", systemImage: "line.3.horizontal.decrease.circle")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          AuditFeedSection(title: "MVP test and release follow-up", detail: "Local tasks created from data hygiene, operator test-session, or release snapshot evidence.", events: visibleMVPFollowUpEvents, onCreateTask: { event in
            store.createReviewTask(from: event)
          })

          AuditFeedSection(title: "Mailbox provider release gate", detail: "Release-gate task creation, refreshes, reviews, and provider-readiness actions for active mailbox providers, Inbox evidence, and operator follow-up.", events: visibleMailboxProviderReleaseGateEvents.prefix(8).map { $0 }, onCreateTask: { event in
            store.createReviewTask(from: event)
          })

          AuditFeedSection(title: "Mailbox intake evidence", detail: "Credential, sign-in, refresh, filtering, parser, and local intake events for active mailbox-provider setup.", events: visibleMailboxEvidenceEvents.prefix(8).map { $0 }, onCreateTask: { event in
            store.createReviewTask(from: event)
          })

          AuditFeedSection(title: "Inbox-to-order handoff", detail: "Order creation and review events from Inbox, Import Queue, and Acceptance Review.", events: inboxOrderHandoffEvents.prefix(8).map { $0 }, onCreateTask: { event in
            store.createReviewTask(from: event)
          })

          AuditFeedSection(title: "Inbox dispatch handoff trail", detail: "Reopened, completed, blocked, and resolved dispatch follow-up for Inbox-created orders.", events: visibleInboxDispatchHandoffEvents, onCreateTask: { event in
            store.createReviewTask(from: event)
          })

          AuditFeedSection(title: "Wishlist purchase trail", detail: "Local comparison, purchase packet, handoff, closure, reopen, task, draft, and order-watch activity for Wishlist items.", events: visibleWishlistPurchaseTrailEvents, onCreateTask: { event in
            store.createReviewTask(from: event)
          })

          AuditFeedSection(title: "Workflow actions", detail: "Reviews, links, completions, acknowledgements, task and draft work.", events: workflowEvents.prefix(8).map { $0 }, onCreateTask: { event in
            store.createReviewTask(from: event)
          })

          AuditFeedSection(title: "Record changes", detail: "Creates, edits, removals, enables, disables, and pinned changes.", events: recordChangeEvents.prefix(8).map { $0 }, onCreateTask: { event in
            store.createReviewTask(from: event)
          })

          AuditFeedSection(title: "Earlier", detail: "Most recent local events in plain chronological order.", events: Array(recentEvents.dropFirst(8).prefix(8)), onCreateTask: { event in
            store.createReviewTask(from: event)
          })
        }
      }
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search audit, mailbox, Gmail, order, tracking, parser reason, or record ID", text: $auditSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Action", selection: $selectedAction) {
        Text("All actions").tag(nil as AuditAction?)
        ForEach(AuditAction.allCases) { action in
          Text(action.rawValue).tag(action as AuditAction?)
        }
      }
      .pickerStyle(.menu)

      Picker("Record", selection: $selectedEntityType) {
        Text("All records").tag(nil as AuditEntityType?)
        ForEach(AuditEntityType.allCases) { entityType in
          Text(entityType.rawValue).tag(entityType as AuditEntityType?)
        }
      }
      .pickerStyle(.menu)

      Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle") {
        auditSearchText = ""
        selectedAction = nil
        selectedEntityType = nil
      }
      .buttonStyle(.bordered)
      .disabled(normalizedAuditSearch.isEmpty && selectedAction == nil && selectedEntityType == nil)
    }
  }

  private func sourceTrailCount(for order: TrackedOrder) -> Int {
    linkedIntakeEmails(for: order).count
      + store.importQueueItems(for: order).count
      + store.acceptanceRecords(for: order).count
  }

  private func linkedIntakeEmails(for order: TrackedOrder) -> [ForwardedEmailIntake] {
    let orderNumber = order.orderNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    return store.intakeEmails.filter { email in
      email.linkedOrderID == order.id
        || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.detectedOrderNumber.localizedCaseInsensitiveContains(orderNumber))
        || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.subject.localizedCaseInsensitiveContains(orderNumber))
        || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.rawBodyPreview.localizedCaseInsensitiveContains(orderNumber))
    }
  }
}

private struct AuditDispatchHandoffTrailCallout: View {
  var event: AuditEvent

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label(event.inboxDispatchHandoffTrailLabel, systemImage: event.inboxDispatchHandoffTrailSymbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(event.inboxDispatchHandoffTrailColor)
      Text(event.inboxDispatchHandoffTrailGuidance)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(event.inboxDispatchHandoffTrailColor.opacity(0.10))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct AuditInboxOrderHandoffCallout: View {
  var event: AuditEvent

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label(event.inboxOrderHandoffLabel, systemImage: event.inboxOrderHandoffSymbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(event.inboxOrderHandoffColor)
      Text(event.inboxOrderHandoffGuidance)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(event.inboxOrderHandoffColor.opacity(0.10))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct AuditWishlistPurchaseTrailCallout: View {
  var event: AuditEvent

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label(event.wishlistPurchaseTrailLabel, systemImage: event.wishlistPurchaseTrailSymbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(event.wishlistPurchaseTrailColor)
      Text(event.wishlistPurchaseTrailGuidance)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(event.wishlistPurchaseTrailColor.opacity(0.10))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct AuditFeedSection: View {
  var title: String
  var detail: String
  var events: [AuditEvent]
  var onCreateTask: (AuditEvent) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.headline)
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if events.isEmpty {
        Text("No matching recent events.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.quinary)
          .clipShape(RoundedRectangle(cornerRadius: 8))
      } else {
        ForEach(events) { event in
          AuditActivityRow(event: event) {
            onCreateTask(event)
          }
        }
      }
    }
  }
}

private struct AuditActivityRow: View {
  var event: AuditEvent
  var onCreateTask: () -> Void
  @State private var showDetails = false
  @State private var feedbackMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: event.entityType.symbol)
          .foregroundStyle(event.action.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
              Text(event.entityLabel)
                .font(.headline)
              Text("\(event.action.operatorLabel) • \(event.timestamp)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Badge(event.action.rawValue, color: event.action.color)
          }

          Text(event.summary)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if !event.operatorOutcomeLines.isEmpty {
            CompactMetadataGrid {
              ForEach(event.operatorOutcomeLines, id: \.self) { line in
                Badge(line, color: event.action.color)
              }
            }
          }

          if event.isInboxDispatchHandoffTrail {
            AuditDispatchHandoffTrailCallout(event: event)
          } else if event.isInboxOrderHandoff {
            AuditInboxOrderHandoffCallout(event: event)
          } else if event.isWishlistPurchaseTrail {
            AuditWishlistPurchaseTrailCallout(event: event)
          }

          CompactMetadataGrid {
            Badge(event.entityType.rawValue, color: event.action.color)
            Badge(event.categoryLabel, color: event.action.color)
            Label(event.actor, systemImage: "person.crop.circle.fill")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      if showDetails {
        AuditDetailStack(event: event)
      }

      if let feedbackMessage {
        AuditTaskFeedbackPanel(message: feedbackMessage)
      }

      CompactActionRow {
        if event.beforeDetail != nil || event.afterDetail != nil {
          Button(showDetails ? "Hide detail" : "Show detail", systemImage: "text.alignleft") {
            showDetails.toggle()
          }
          .buttonStyle(.bordered)
        }
        Button("Create task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Audit follow-up task created. Check Tasks."
        }
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct AuditEventRow: View {
  var event: AuditEvent
  var onCreateTask: () -> Void = {}
  @State private var showDetails = false
  @State private var feedbackMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: event.entityType.symbol)
          .foregroundStyle(event.action.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(event.entityLabel)
                .font(.headline)
              Text("\(event.actor) • \(event.timestamp)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(event.action.rawValue, color: event.action.color)
          }

          Text(event.summary)
            .foregroundStyle(.secondary)

          if !event.operatorOutcomeLines.isEmpty {
            CompactMetadataGrid {
              ForEach(event.operatorOutcomeLines, id: \.self) { line in
                Badge(line, color: event.action.color)
              }
            }
          }

          if event.isInboxDispatchHandoffTrail {
            AuditDispatchHandoffTrailCallout(event: event)
          } else if event.isInboxOrderHandoff {
            AuditInboxOrderHandoffCallout(event: event)
          } else if event.isWishlistPurchaseTrail {
            AuditWishlistPurchaseTrailCallout(event: event)
          }

          CompactMetadataGrid {
            Badge(event.entityType.rawValue, color: event.action.color)
            Badge(event.categoryLabel, color: event.action.color)
            Text(event.entityID)
              .font(.caption2.monospaced())
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          }
        }
      }

      if showDetails {
        AuditDetailStack(event: event)
      }

      if let feedbackMessage {
        AuditTaskFeedbackPanel(message: feedbackMessage)
      }

      CompactActionRow {
        if event.beforeDetail != nil || event.afterDetail != nil {
          Button(showDetails ? "Hide detail" : "Show detail", systemImage: "text.alignleft") {
            showDetails.toggle()
          }
          .buttonStyle(.bordered)
        }
        Button("Create task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Audit follow-up task created. Check Tasks."
        }
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct AuditTaskFeedbackPanel: View {
  var message: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Label(message, systemImage: "checkmark.circle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.green)
      Text("The task is a local follow-up from this audit event. Open Tasks from the primary navigation to continue it.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.green.opacity(0.10))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct AuditDetailStack: View {
  var event: AuditEvent

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let beforeDetail = event.beforeDetail {
        AuditDetailBlock(title: "Before", detail: beforeDetail)
      }
      if let afterDetail = event.afterDetail {
        AuditDetailBlock(title: "After", detail: afterDetail)
      }
    }
  }
}

struct AuditDetailBlock: View {
  var title: String
  var detail: String

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(detail)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background(.background.opacity(0.65))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private extension AuditEvent {
  var isMVPTestOrReleaseFollowUp: Bool {
    guard entityType == .reviewTask || entityType == .settings || entityType == .auditEvent else {
      return false
    }
    let searchableText = [
      summary,
      entityLabel,
      beforeDetail ?? "",
      afterDetail ?? ""
    ].joined(separator: " ")

    return searchableText.localizedCaseInsensitiveContains("local data hygiene")
      || searchableText.localizedCaseInsensitiveContains("operator MVP test")
      || searchableText.localizedCaseInsensitiveContains("operator test-session")
      || searchableText.localizedCaseInsensitiveContains("SpaceMail MVP release snapshot")
      || searchableText.localizedCaseInsensitiveContains("release snapshot follow-up")
      || searchableText.localizedCaseInsensitiveContains("spacemail-release-snapshot")
      || searchableText.localizedCaseInsensitiveContains("operator-test-session")
      || searchableText.localizedCaseInsensitiveContains("local-data-hygiene")
  }

  var isMailboxProviderReleaseGateEvent: Bool {
    let searchableText = [
      summary,
      entityLabel,
      beforeDetail ?? "",
      afterDetail ?? "",
      entityType.rawValue,
      action.rawValue
    ].joined(separator: " ")

    return searchableText.localizedCaseInsensitiveContains("mailbox provider release gate")
      || searchableText.localizedCaseInsensitiveContains("mailbox provider gate")
      || searchableText.localizedCaseInsensitiveContains("mailbox release gate")
      || searchableText.localizedCaseInsensitiveContains("provider release gate")
      || searchableText.localizedCaseInsensitiveContains("release gate task")
      || searchableText.localizedCaseInsensitiveContains("mailbox-provider-release-gate")
  }

  var isTechnicalMailboxDiagnostic: Bool {
    guard entityType == .spaceMailIMAPConnection
      || entityType == .gmailMailboxConnection
      || entityType == .intakeEmail
      || summary.localizedCaseInsensitiveContains("spacemail")
      || summary.localizedCaseInsensitiveContains("gmail") else {
      return false
    }

    let searchableText = [
      summary,
      entityLabel,
      beforeDetail ?? "",
      afterDetail ?? ""
    ].joined(separator: " ")

    return searchableText.localizedCaseInsensitiveContains("duplicate fetched mailbox message skipped")
      || searchableText.localizedCaseInsensitiveContains("refreshed with no intake field changes")
      || searchableText.localizedCaseInsensitiveContains("reprocessed with no field changes")
      || searchableText.localizedCaseInsensitiveContains("parser result:")
      || searchableText.localizedCaseInsensitiveContains("provider message id:")
  }

  var operatorOutcomeLines: [String] {
    guard let afterDetail else { return [] }

    let wantedPrefixes = [
      "Status:",
      "Fetch result:",
      "Fetched messages:",
      "Imported:",
      "Duplicate skips:",
      "Filtered non-order:",
      "Uncertain:",
      "Mailbox mode:",
      "Parser result:"
    ]

    let lines = afterDetail
      .components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { line in
        wantedPrefixes.contains { line.hasPrefix($0) }
      }

    return Array(lines.prefix(5))
  }

  var isInboxOrderHandoff: Bool {
    let searchableText = [
      summary,
      entityLabel,
      beforeDetail ?? "",
      afterDetail ?? ""
    ].joined(separator: " ")

    let mentionsOrderCreation =
      searchableText.localizedCaseInsensitiveContains("created from forwarded")
        || searchableText.localizedCaseInsensitiveContains("forwarded intake email")
        || searchableText.localizedCaseInsensitiveContains("import queue item")
        || searchableText.localizedCaseInsensitiveContains("acceptance review")
        || searchableText.localizedCaseInsensitiveContains("acceptance workflow")
        || searchableText.localizedCaseInsensitiveContains("after order creation")

    let relevantEntity =
      entityType == .order
        || entityType == .intakeEmail
        || entityType == .importQueueItem
        || entityType == .acceptanceRecord

    return relevantEntity && mentionsOrderCreation
  }

  var inboxOrderHandoffLabel: String {
    if entityType == .order && action == .created { return "Order created from Inbox" }
    if entityType == .intakeEmail && action == .linked { return "Intake linked to order" }
    if entityType == .importQueueItem { return "Import handoff" }
    if entityType == .acceptanceRecord { return "Acceptance handoff" }
    return "Inbox-to-order handoff"
  }

  var inboxOrderHandoffGuidance: String {
    if entityType == .order && action == .created {
      return "Open the order and confirm the Inbox source trail, tracking, destination, customer, and dispatch setup before treating it as operationally ready."
    }
    if entityType == .intakeEmail && action == .linked {
      return "The intake email is now tied to local order context. Check the order source trail before marking related follow-up reviewed."
    }
    if entityType == .importQueueItem {
      return "This import queue event contributed to order handoff. Confirm the linked order or create a follow-up task if fields still need review."
    }
    if entityType == .acceptanceRecord {
      return "Acceptance review moved intake/import context toward an order. Verify the linked order and dispatch setup before closing the handoff."
    }
    return "Use this event to trace how Inbox, Import Queue, or Acceptance Review context became order work."
  }

  var inboxOrderHandoffSymbol: String {
    if entityType == .order && action == .created { return "shippingbox.fill" }
    if entityType == .intakeEmail { return "envelope.open.fill" }
    if entityType == .importQueueItem { return "tray.and.arrow.down.fill" }
    if entityType == .acceptanceRecord { return "checkmark.seal.fill" }
    return "arrow.triangle.branch"
  }

  var inboxOrderHandoffColor: Color {
    if entityType == .order && action == .created { return .teal }
    if entityType == .intakeEmail { return .blue }
    if entityType == .importQueueItem { return .orange }
    if entityType == .acceptanceRecord { return .purple }
    return .teal
  }

  var isInboxDispatchHandoffTrail: Bool {
    let searchableText = [
      summary,
      entityLabel,
      beforeDetail ?? "",
      afterDetail ?? ""
    ].joined(separator: " ")

    let mentionsInboxDispatch =
      searchableText.localizedCaseInsensitiveContains("Inbox dispatch")
        || searchableText.localizedCaseInsensitiveContains("Inbox-created order dispatch")
        || searchableText.localizedCaseInsensitiveContains("Reopened Inbox dispatch handoff")
        || searchableText.localizedCaseInsensitiveContains("dispatch handoff was completed locally")

    let relevantEntity =
      entityType == .order
        || entityType == .shipmentManifest
        || entityType == .dispatchChecklist
        || entityType == .reviewTask

    return relevantEntity && mentionsInboxDispatch
  }

  var isReopenedInboxDispatchHandoffTrail: Bool {
    isInboxDispatchHandoffTrail && (
      action == .reopened
        || summary.localizedCaseInsensitiveContains("reopened")
        || (afterDetail ?? "").localizedCaseInsensitiveContains("reopened")
    )
  }

  var isCompletedInboxDispatchHandoffTrail: Bool {
    isInboxDispatchHandoffTrail && (
      action == .completed
        || summary.localizedCaseInsensitiveContains("completed")
        || summary.localizedCaseInsensitiveContains("resolved")
        || (afterDetail ?? "").localizedCaseInsensitiveContains("completed locally")
    )
  }

  var inboxDispatchHandoffTrailLabel: String {
    if isReopenedInboxDispatchHandoffTrail { return "Reopened handoff" }
    if summary.localizedCaseInsensitiveContains("blocked") || summary.localizedCaseInsensitiveContains("skipped") { return "Needs dispatch check" }
    if entityType == .reviewTask && isCompletedInboxDispatchHandoffTrail { return "Task resolved" }
    if isCompletedInboxDispatchHandoffTrail { return "Handoff completed" }
    return "Inbox dispatch trail"
  }

  var inboxDispatchHandoffTrailGuidance: String {
    if isReopenedInboxDispatchHandoffTrail {
      return "Open the linked order or Dispatch queue, confirm manifest/readiness setup, then complete or block the handoff locally."
    }
    if summary.localizedCaseInsensitiveContains("blocked") {
      return "Resolve the blocked manifest or readiness checklist before treating the Inbox-created order as dispatch-ready."
    }
    if summary.localizedCaseInsensitiveContains("skipped") {
      return "No linked dispatch setup was found. Open the order to create or link the local manifest and readiness checklist."
    }
    if entityType == .reviewTask && isCompletedInboxDispatchHandoffTrail {
      return "The follow-up task was resolved when the dispatch handoff was completed again."
    }
    if isCompletedInboxDispatchHandoffTrail {
      return "The local dispatch handoff is complete. Audit confirms no mailbox, carrier, label, scanner, or external service action occurred."
    }
    return "Use this event to trace how an Inbox-created order moved through local dispatch follow-up."
  }

  var inboxDispatchHandoffTrailSymbol: String {
    if isReopenedInboxDispatchHandoffTrail { return "arrow.counterclockwise.circle.fill" }
    if summary.localizedCaseInsensitiveContains("blocked") || summary.localizedCaseInsensitiveContains("skipped") { return "exclamationmark.triangle.fill" }
    if isCompletedInboxDispatchHandoffTrail { return "checkmark.seal.fill" }
    return "arrow.triangle.2.circlepath.circle.fill"
  }

  var inboxDispatchHandoffTrailColor: Color {
    if isReopenedInboxDispatchHandoffTrail { return .purple }
    if summary.localizedCaseInsensitiveContains("blocked") || summary.localizedCaseInsensitiveContains("skipped") { return .orange }
    if isCompletedInboxDispatchHandoffTrail { return .green }
    return .teal
  }

  var isWishlistPurchaseTrail: Bool {
    let searchableText = [
      summary,
      entityLabel,
      beforeDetail ?? "",
      afterDetail ?? "",
      entityType.rawValue,
      action.rawValue
    ].joined(separator: " ")

    let relevantEntity =
      entityType == .wishlistItem
        || (entityType == .reviewTask && searchableText.localizedCaseInsensitiveContains("wishlist"))
        || (entityType == .draftMessage && searchableText.localizedCaseInsensitiveContains("wishlist"))
        || (entityType == .costRecord && searchableText.localizedCaseInsensitiveContains("wishlist"))
        || (entityType == .procurementRequest && searchableText.localizedCaseInsensitiveContains("wishlist"))
        || (entityType == .receivingInspection && searchableText.localizedCaseInsensitiveContains("wishlist"))

    let mentionsPurchaseTrail =
      searchableText.localizedCaseInsensitiveContains("wishlist purchase")
        || searchableText.localizedCaseInsensitiveContains("purchase packet")
        || searchableText.localizedCaseInsensitiveContains("purchase handoff")
        || searchableText.localizedCaseInsensitiveContains("handoff pack")
        || searchableText.localizedCaseInsensitiveContains("seller evidence")
        || searchableText.localizedCaseInsensitiveContains("purchase decision")
        || searchableText.localizedCaseInsensitiveContains("order confirmation")
        || searchableText.localizedCaseInsensitiveContains("order watch")
        || searchableText.localizedCaseInsensitiveContains("closed wishlist")
        || searchableText.localizedCaseInsensitiveContains("closed locally")
        || searchableText.localizedCaseInsensitiveContains("closure readiness")
        || searchableText.localizedCaseInsensitiveContains("reopened locally")
        || searchableText.localizedCaseInsensitiveContains("wishlist purchase cost")
        || searchableText.localizedCaseInsensitiveContains("wishlist procurement")
        || searchableText.localizedCaseInsensitiveContains("wishlist receiving")

    return relevantEntity && mentionsPurchaseTrail
  }

  var wishlistPurchaseTrailLabel: String {
    let searchableText = [summary, entityLabel, afterDetail ?? ""].joined(separator: " ")
    if searchableText.localizedCaseInsensitiveContains("purchase packet") { return "Purchase packet" }
    if searchableText.localizedCaseInsensitiveContains("handoff pack") { return "Handoff pack" }
    if searchableText.localizedCaseInsensitiveContains("purchase handoff") { return "Purchase handoff" }
    if searchableText.localizedCaseInsensitiveContains("closure readiness") { return "Closure readiness" }
    if searchableText.localizedCaseInsensitiveContains("closed wishlist") || searchableText.localizedCaseInsensitiveContains("closed locally") { return "Wishlist closed" }
    if searchableText.localizedCaseInsensitiveContains("reopened locally") { return "Wishlist reopened" }
    if searchableText.localizedCaseInsensitiveContains("purchase decision") { return "Purchase decision" }
    if searchableText.localizedCaseInsensitiveContains("wishlist purchase cost") || entityType == .costRecord { return "Wishlist cost" }
    if searchableText.localizedCaseInsensitiveContains("wishlist procurement") || entityType == .procurementRequest { return "Wishlist procurement" }
    if searchableText.localizedCaseInsensitiveContains("wishlist receiving") || entityType == .receivingInspection { return "Wishlist receiving" }
    if searchableText.localizedCaseInsensitiveContains("seller evidence") { return "Seller evidence" }
    if searchableText.localizedCaseInsensitiveContains("order confirmation") || searchableText.localizedCaseInsensitiveContains("order watch") { return "Order watch" }
    if entityType == .draftMessage { return "Wishlist draft" }
    if entityType == .reviewTask { return "Wishlist task" }
    return "Wishlist purchase trail"
  }

  var wishlistPurchaseTrailGuidance: String {
    let searchableText = [summary, entityLabel, afterDetail ?? ""].joined(separator: " ")
    if searchableText.localizedCaseInsensitiveContains("purchase packet") {
      return "Use this event to verify the local buying packet: preferred seller, AUD total, postage, trust, blockers, handoff, and order-watch state. It is not evidence of checkout or payment."
    }
    if searchableText.localizedCaseInsensitiveContains("handoff pack") {
      return "Use this event to confirm account, cost, procurement, receiving, and linked-order context before a human purchase or order-confirmation handoff."
    }
    if searchableText.localizedCaseInsensitiveContains("purchase handoff") {
      return "The item has moved into manual handoff follow-up. Confirm account, payment method, delivery address, returns, warranty, and order confirmation outside ParcelOps."
    }
    if searchableText.localizedCaseInsensitiveContains("closure readiness") {
      return "This local check verifies whether the Wishlist item has enough linked operational evidence to leave the active queue. It does not close external orders, inventory, dispatch, payments, or seller activity."
    }
    if searchableText.localizedCaseInsensitiveContains("closed wishlist") || searchableText.localizedCaseInsensitiveContains("closed locally") {
      return "The Wishlist item was closed inside ParcelOps and should no longer count as active work. Its JSON record and audit trail remain available for linked order and handoff history."
    }
    if searchableText.localizedCaseInsensitiveContains("reopened locally") {
      return "The closed Wishlist item was returned to local follow-up. Review the linked order and handoff state before treating it as active purchase or dispatch work."
    }
    if searchableText.localizedCaseInsensitiveContains("purchase decision") {
      return "The seller decision changed locally. Check that live price, stock, postage, trust, returns, and AUD total are still current before handoff."
    }
    if searchableText.localizedCaseInsensitiveContains("wishlist purchase cost") || entityType == .costRecord {
      return "A local cost placeholder was created for Wishlist purchase planning. Confirm price, postage, currency, tax, and reimbursement before purchase."
    }
    if searchableText.localizedCaseInsensitiveContains("wishlist procurement") || entityType == .procurementRequest {
      return "A local procurement request is linked to Wishlist planning. Use it to track approval and buyer ownership; no supplier or payment API is active."
    }
    if searchableText.localizedCaseInsensitiveContains("wishlist receiving") || entityType == .receivingInspection {
      return "A local receiving inspection placeholder is ready for the future delivered item. It does not imply warehouse, scanner, or carrier integration."
    }
    if searchableText.localizedCaseInsensitiveContains("seller evidence") {
      return "Seller evidence needs a human check. Confirm product link, landed AUD cost, postage, trust, and returns/warranty before treating the option as ready."
    }
    if searchableText.localizedCaseInsensitiveContains("order confirmation") || searchableText.localizedCaseInsensitiveContains("order watch") {
      return "Use Wishlist, Inbox, Mailbox Monitor, or Orders to link the external confirmation to a local order. No background mailbox or retailer monitoring is implied."
    }
    return "This is local Wishlist purchase-planning evidence. Continue in Wishlist unless a named task, draft, handoff, or linked order needs follow-up."
  }

  var wishlistPurchaseTrailSymbol: String {
    let searchableText = [summary, entityLabel, afterDetail ?? ""].joined(separator: " ")
    if searchableText.localizedCaseInsensitiveContains("purchase packet") { return "doc.text.image.fill" }
    if searchableText.localizedCaseInsensitiveContains("handoff pack") { return "shippingbox.and.arrow.backward.fill" }
    if searchableText.localizedCaseInsensitiveContains("purchase handoff") { return "person.crop.circle.badge.checkmark" }
    if searchableText.localizedCaseInsensitiveContains("closure readiness") { return "checklist.checked" }
    if searchableText.localizedCaseInsensitiveContains("closed wishlist") || searchableText.localizedCaseInsensitiveContains("closed locally") { return "checkmark.circle.fill" }
    if searchableText.localizedCaseInsensitiveContains("reopened locally") { return "arrow.uturn.backward.circle.fill" }
    if searchableText.localizedCaseInsensitiveContains("purchase decision") { return "doc.text.magnifyingglass" }
    if searchableText.localizedCaseInsensitiveContains("wishlist purchase cost") || entityType == .costRecord { return "dollarsign.circle.fill" }
    if searchableText.localizedCaseInsensitiveContains("wishlist procurement") || entityType == .procurementRequest { return "cart.badge.plus" }
    if searchableText.localizedCaseInsensitiveContains("wishlist receiving") || entityType == .receivingInspection { return "shippingbox.and.arrow.down.fill" }
    if searchableText.localizedCaseInsensitiveContains("seller evidence") { return "checklist" }
    if searchableText.localizedCaseInsensitiveContains("order confirmation") || searchableText.localizedCaseInsensitiveContains("order watch") { return "envelope.badge.fill" }
    return "star.square.fill"
  }

  var wishlistPurchaseTrailColor: Color {
    let searchableText = [summary, afterDetail ?? "", action.rawValue].joined(separator: " ")
    if searchableText.localizedCaseInsensitiveContains("blocked") || searchableText.localizedCaseInsensitiveContains("needs review") {
      return .orange
    }
    if searchableText.localizedCaseInsensitiveContains("linked") || searchableText.localizedCaseInsensitiveContains("reviewed") {
      return .green
    }
    if searchableText.localizedCaseInsensitiveContains("closed locally") {
      return .green
    }
    if searchableText.localizedCaseInsensitiveContains("reopened") {
      return .orange
    }
    if searchableText.localizedCaseInsensitiveContains("draft") {
      return .blue
    }
    return .purple
  }

  var isWorkflowAction: Bool {
    switch action {
    case .linked, .reviewed, .ignored, .cleared, .acknowledged, .completed, .reopened, .evaluated:
      true
    case .created, .edited, .enabled, .disabled, .pinned, .unpinned, .removed:
      entityType == .reviewTask || entityType == .draftMessage || entityType == .handoffNote
    }
  }

  var isRecordChange: Bool {
    switch action {
    case .created, .edited, .enabled, .disabled, .pinned, .unpinned, .removed:
      true
    case .linked, .reviewed, .ignored, .cleared, .acknowledged, .completed, .reopened, .evaluated:
      false
    }
  }

  var categoryLabel: String {
    if isWorkflowAction {
      "Workflow action"
    } else if isRecordChange {
      "Record change"
    } else {
      "Local activity"
    }
  }
}

private extension AuditAction {
  var operatorLabel: String {
    switch self {
    case .created: "Created locally"
    case .edited: "Record updated"
    case .enabled: "Enabled locally"
    case .disabled: "Disabled locally"
    case .linked: "Linked record"
    case .reviewed: "Reviewed locally"
    case .ignored: "Ignored locally"
    case .cleared: "Cleared locally"
    case .pinned: "Pinned filter"
    case .unpinned: "Unpinned filter"
    case .acknowledged: "Acknowledged"
    case .completed: "Completed"
    case .reopened: "Reopened"
    case .evaluated: "Manual check"
    case .removed: "Removed locally"
    }
  }
}
