import SwiftUI

struct InboxView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var triageSearchText = ""
  @State private var showParserDiagnosticsInTriage = false
  @State private var triageGroupFilter: InboxTriageGroupFilter = .all
  @State private var triageSourceFilter: InboxTriageSourceFilter = .all
  @State private var triageQualityFilter: InboxTriageQualityFilter = .all
  @State private var providerReleaseGateFeedbackMessage: String?
  @State private var showInboxProviderEvidence = false
  @State private var showInboxGmailReleaseEvidence = false
  @State private var showInboxContextSections = false
  @State private var showFullMailboxHealthHistory = false

  private var isCompact: Bool { horizontalSizeClass == .compact }
  private var inboxTriageVisibleLimit: Int { isCompact ? 16 : 24 }

  private var triageItems: [InboxTriageItem] {
    let acceptanceItems = store.acceptanceRecordsNeedingReview.compactMap { record in
      store.acceptanceCandidates.first { $0.sourceType == record.sourceType && $0.sourceID == record.sourceID }
    }
    let acceptanceKeys = Set(acceptanceItems.map { InboxTriageItem.sourceKey(sourceType: $0.sourceType, sourceID: $0.sourceID) })

    let emailItems = store.reviewIntakeEmails
      .filter { !acceptanceKeys.contains(InboxTriageItem.sourceKey(sourceType: .intakeEmail, sourceID: $0.id)) }
      .map(InboxTriageItem.email)

    let importItems = uniqueImportItems(store.blockedImportQueueItems + store.lowConfidenceImportQueueItems + store.importQueueItemsNeedingReview)
      .filter { !acceptanceKeys.contains(InboxTriageItem.sourceKey(sourceType: .importQueueItem, sourceID: $0.id)) }
      .map(InboxTriageItem.importQueue)

    let parserItems = showParserDiagnosticsInTriage ? store.intakeParserDiagnostics.map(InboxTriageItem.parserDiagnostic) : []

    return (acceptanceItems.map(InboxTriageItem.acceptance) + parserItems + emailItems + importItems)
      .sorted { lhs, rhs in
        if lhs.sortPriority == rhs.sortPriority {
          return lhs.capturedDate > rhs.capturedDate
        }
        return lhs.sortPriority > rhs.sortPriority
      }
  }

  private var filteredTriageItems: [InboxTriageItem] {
    let query = triageSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    let filteredItems = triageItems.filter { item in
      triageGroupFilter.matches(item)
        && triageSourceFilter.matches(item)
        && triageQualityFilter.matches(item)
    }
    guard !query.isEmpty else { return filteredItems }
    return filteredItems.filter { item in
      [
        item.sourceLabel,
        item.title,
        item.subtitle,
        item.detail,
        item.capturedDate,
        item.reviewLabel,
        item.nextAction,
        item.readinessLabel,
        item.readinessDetail,
        item.parserQualityLabel,
        item.parserQualityDetail,
        item.triageGroup.rawValue
      ].joined(separator: " ").localizedLowercase.contains(query)
    }
  }

  private var visibleTriageItems: [InboxTriageItem] {
    Array(filteredTriageItems.prefix(inboxTriageVisibleLimit))
  }

  private var hiddenTriageItemCount: Int {
    max(filteredTriageItems.count - visibleTriageItems.count, 0)
  }

  private var hasActiveTriageFilters: Bool {
    triageGroupFilter != .all || triageSourceFilter != .all || triageQualityFilter != .all
  }

  private var hasActiveInboxFilters: Bool {
    hasActiveTriageFilters
      || !triageSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || showParserDiagnosticsInTriage
  }

  private var shouldShowInboxContextSections: Bool {
    showInboxContextSections || hasActiveInboxFilters
  }

  private var visibleTriageGroups: [InboxTriageGroupBucket] {
    InboxTriageGroup.displayOrder.compactMap { group in
      let items = visibleTriageItems.filter { $0.triageGroup == group }
      guard !items.isEmpty else { return nil }
      return InboxTriageGroupBucket(group: group, items: items)
    }
  }

  private var parserIssueCount: Int {
    store.intakeParserDiagnostics.count
  }

  private var hasSpaceMailSetup: Bool {
    store.hasSpaceMailSetup
  }

  private var hasSpaceMailCredentialReference: Bool {
    store.hasSpaceMailCredentialReadiness
  }

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.latestSpaceMailIntakeHealthSummary
  }

  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.latestGmailIntakeHealthSummary
  }

  private var latestGmailConnection: GmailMailboxConnection? {
    guard let summary = latestGmailSummary else { return store.gmailMailboxConnections.first }
    return store.gmailMailboxConnections.first { $0.id == summary.connectionID }
  }

  private var hasGmailSetup: Bool {
    store.hasGmailSetup
  }

  private var inboxGmailReadiness: GmailOAuthReadinessSummary? {
    latestGmailConnection.map { store.gmailOAuthReadinessSummary(for: $0) }
  }

  private var inboxGmailCompileBlockers: [String] {
    guard let readiness = inboxGmailReadiness else { return [] }
    return readiness.missingFields.filter { field in
      field.localizedCaseInsensitiveContains("compiled App Info.plist")
        || field.localizedCaseInsensitiveContains("callback URL scheme matching")
        || field.localizedCaseInsensitiveContains("OAuth iOS client ID ending")
    }
  }

  private var inboxGmailCompileColor: Color {
    guard let readiness = inboxGmailReadiness else { return .secondary }
    return readiness.isReady ? .green : .orange
  }

  private var inboxGmailCompileTitle: String {
    guard let readiness = inboxGmailReadiness else { return "Gmail app setup is optional" }
    if readiness.isReady { return "Gmail app setup is ready for Inbox intake" }
    if !inboxGmailCompileBlockers.isEmpty { return "Gmail app setup blocks Inbox intake" }
    return "Gmail setup values need review"
  }

  private var inboxGmailCompileDetail: String {
    guard let readiness = inboxGmailReadiness else {
      return "Use Gmail only for Google-hosted mailboxes. Use the provider that hosts the active intake mailbox."
    }
    if readiness.isReady {
      return "The saved Gmail setup matches the compiled client ID and callback scheme. Run sign-in and manual refresh only when Gmail is the active mailbox provider."
    }
    if !inboxGmailCompileBlockers.isEmpty {
      return "Fix before testing Gmail Inbox intake: \(inboxGmailCompileBlockers.joined(separator: "; ")). Update App/Info.plist and Project.json, rebuild, then run the explicit Gmail readiness/sign-in steps."
    }
    return readiness.detailText
  }

  private var hasGmailConnectedAuth: Bool {
    store.hasGmailConnectedAuth
  }

  private var hasMicrosoft365Setup: Bool {
    store.hasMicrosoft365Setup
  }

  private var hasMicrosoft365ConnectedAuth: Bool {
    store.hasMicrosoft365ConnectedAuth
  }

  private var hasMicrosoft365RefreshEvidence: Bool {
    store.hasMicrosoft365ManualRefreshEvidence
  }

  private var uncertainSpaceMailCount: Int {
    store.pendingSpaceMailUncertainReviewCount
  }

  private var uncertainGmailCount: Int {
    store.pendingGmailUncertainReviewCount
  }

  private var uncertainMicrosoft365Count: Int {
    store.pendingMicrosoft365UncertainReviewCount
  }

  private var filteredSpaceMailCount: Int {
    store.pendingSpaceMailFilteredReviewCount
  }

  private var filteredGmailCount: Int {
    store.gmailFilteredMailboxSignalCount
  }

  private var filteredMicrosoft365Count: Int {
    store.microsoft365FilteredMailboxSignalCount
  }

  private var latestMailboxFetchedCount: Int {
    store.latestMailboxFetchedCount
  }

  private var latestMailboxImportedCount: Int {
    store.latestMailboxImportedCount
  }

  private var latestMailboxDuplicateCount: Int {
    store.latestMailboxDuplicateCount
  }

  private var latestMailboxFilteredCount: Int {
    store.latestMailboxFilteredCount
  }

  private var latestMailboxUncertainCount: Int {
    store.latestMailboxUncertainCount
  }

  private var displayedSpaceMailHealthSummaries: [SpaceMailIntakeHealthSummary] {
    showFullMailboxHealthHistory ? store.spaceMailIntakeHealthSummaries : Array(store.spaceMailIntakeHealthSummaries.prefix(4))
  }

  private var displayedGmailHealthSummaries: [GmailIntakeHealthSummary] {
    showFullMailboxHealthHistory ? store.gmailIntakeHealthSummaries : Array(store.gmailIntakeHealthSummaries.prefix(4))
  }

  private var displayedMicrosoft365HealthSummaries: [Microsoft365IntakeHealthSummary] {
    showFullMailboxHealthHistory ? store.microsoft365IntakeHealthSummaries : Array(store.microsoft365IntakeHealthSummaries.prefix(4))
  }

  private var hiddenMailboxHealthSummaryCount: Int {
    max(store.spaceMailIntakeHealthSummaries.count - displayedSpaceMailHealthSummaries.count, 0)
      + max(store.gmailIntakeHealthSummaries.count - displayedGmailHealthSummaries.count, 0)
      + max(store.microsoft365IntakeHealthSummaries.count - displayedMicrosoft365HealthSummaries.count, 0)
  }

  private var pendingFilteredGmailReviewCount: Int {
    store.pendingGmailFilteredReviewCount
  }

  private var mailboxHealthAttentionCount: Int {
    store.mailboxHealthAttentionCount
  }

  private var mailboxProviderTestQueue: MailboxProviderTestQueueSummary {
    store.mailboxProviderTestQueueSummary
  }

  private var mailboxProviderNextItems: [MailboxProviderTestQueueItem] {
    let incomplete = mailboxProviderTestQueue.items.filter { !$0.isComplete }
    return Array((incomplete.isEmpty ? mailboxProviderTestQueue.items : incomplete).prefix(isCompact ? 3 : 4))
  }

  private var blockedIncomingCount: Int {
    store.blockedImportQueueItems.count
  }

  private var readyAcceptanceCount: Int {
    store.acceptanceRecordsNeedingReview.count
  }

  private var inboxLinkedOrderCount: Int {
    Set(store.intakeEmails.compactMap(\.linkedOrderID)).count
  }

  private var hasInboxAuditEvidence: Bool {
    store.auditEvents.contains(where: { event in
      event.entityType.rawValue.localizedCaseInsensitiveContains("intake")
        || event.summary.localizedCaseInsensitiveContains("Inbox")
        || event.summary.localizedCaseInsensitiveContains("SpaceMail")
        || event.summary.localizedCaseInsensitiveContains("Gmail")
        || event.summary.localizedCaseInsensitiveContains("Microsoft 365")
        || event.summary.localizedCaseInsensitiveContains("Outlook")
        || event.afterDetail?.localizedCaseInsensitiveContains("SpaceMail") == true
        || event.afterDetail?.localizedCaseInsensitiveContains("Gmail") == true
        || event.afterDetail?.localizedCaseInsensitiveContains("Microsoft 365") == true
        || event.afterDetail?.localizedCaseInsensitiveContains("Outlook") == true
    })
  }

  private var dailyFlowSteps: [(title: String, detail: String, symbol: String, color: Color, isComplete: Bool)] {
    let hasMailboxSetup = store.hasMailboxProviderSetup
    let hasMailboxAuth = (hasSpaceMailSetup && hasSpaceMailCredentialReference)
      || (hasGmailSetup && hasGmailConnectedAuth)
      || (hasMicrosoft365Setup && hasMicrosoft365ConnectedAuth)
    let hasRefreshEvidence = latestSpaceMailSummary != nil || latestGmailSummary != nil || hasMicrosoft365RefreshEvidence
    let hasMailboxDecisionEvidence = (latestSpaceMailSummary?.importedCount ?? 0) > 0
      || (latestGmailSummary?.importedCount ?? 0) > 0
      || (latestSpaceMailSummary?.filteredCount ?? 0) > 0
      || (latestGmailSummary?.filteredCount ?? 0) > 0
      || (latestSpaceMailSummary?.duplicateCount ?? 0) > 0
      || (latestGmailSummary?.duplicateCount ?? 0) > 0
      || hasMicrosoft365RefreshEvidence
      || uncertainSpaceMailCount + uncertainGmailCount + uncertainMicrosoft365Count > 0
      || filteredSpaceMailCount + filteredGmailCount + filteredMicrosoft365Count > 0
      || !triageItems.isEmpty

    return [
      (
        "Setup",
        hasMailboxSetup ? "A manual mailbox setup exists." : "Add an active mailbox provider in Mailbox Monitor.",
        "server.rack",
        hasMailboxSetup ? .green : .orange,
        hasMailboxSetup
      ),
      (
        "Auth",
        hasMailboxAuth ? "Credential or sign-in is ready." : "Set SpaceMail credential, complete Gmail sign-in, or complete Microsoft sign-in.",
        "key.horizontal.fill",
        hasMailboxAuth ? .green : .orange,
        hasMailboxAuth
      ),
      (
        "Refresh",
        latestSpaceMailSummary.map { "SpaceMail: \($0.compactRefreshCountsText)." }
          ?? latestGmailSummary.map { "Gmail: \($0.compactRefreshCountsText)." }
          ?? store.microsoft365MailboxConnections.first(where: { $0.lastManualRefreshDate != "Never" }).map { "Outlook: manual Graph refresh ran \($0.lastManualRefreshDate)." }
          ?? "Run a manual read-only mailbox refresh.",
        "arrow.triangle.2.circlepath",
        hasRefreshEvidence ? .green : .orange,
        hasRefreshEvidence
      ),
      (
        "Review",
        hasMailboxDecisionEvidence ? "\(triageItems.count) triage, \(uncertainSpaceMailCount + uncertainGmailCount + uncertainMicrosoft365Count) uncertain, \(filteredSpaceMailCount + pendingFilteredGmailReviewCount + store.pendingMicrosoft365FilteredReviewCount) filtered review rows." : "Review imported, uncertain, and filtered decisions after refresh.",
        "tray.full.fill",
        hasMailboxDecisionEvidence ? .teal : .orange,
        hasMailboxDecisionEvidence
      ),
      (
        "Order",
        inboxLinkedOrderCount > 0 ? "\(inboxLinkedOrderCount) intake source\(inboxLinkedOrderCount == 1 ? "" : "s") linked to orders." : "Create or link one confirmed intake row to an order.",
        "shippingbox.fill",
        inboxLinkedOrderCount > 0 ? .green : .orange,
        inboxLinkedOrderCount > 0
      ),
      (
        "Audit",
        hasInboxAuditEvidence ? "Inbox or mailbox activity is visible in Audit." : "Confirm local activity appears in Audit.",
        "list.clipboard.fill",
        hasInboxAuditEvidence ? .green : .orange,
        hasInboxAuditEvidence
      )
    ]
  }

  private var dailyFlowCompleteCount: Int {
    dailyFlowSteps.filter(\.isComplete).count
  }

  private var inboxSummaryTone: Color {
    if blockedIncomingCount > 0 { return .orange }
    if readyAcceptanceCount > 0 || !triageItems.isEmpty || uncertainSpaceMailCount + uncertainGmailCount + uncertainMicrosoft365Count > 0 { return .teal }
    if parserIssueCount > 0 { return .orange }
    return .green
  }

  private var inboxSummaryTitle: String {
    if blockedIncomingCount > 0 { return "Clear blocked incoming records" }
    if readyAcceptanceCount > 0 { return "Accept or link ready intake" }
    if uncertainSpaceMailCount + uncertainGmailCount + uncertainMicrosoft365Count > 0 { return "Review uncertain mailbox messages" }
    if !triageItems.isEmpty { return "Work the triage queue" }
    if parserIssueCount > 0 { return "Parser diagnostics are available" }
    return "Inbox is clear"
  }

  private var inboxSummaryDetail: String {
    if blockedIncomingCount > 0 {
      return "Start with blocked import rows because they can prevent otherwise valid intake from becoming orders."
    }
    if readyAcceptanceCount > 0 {
      return "Acceptance rows are closest to becoming operational records. Link to an existing order or create a new local order."
    }
    if uncertainSpaceMailCount + uncertainGmailCount + uncertainMicrosoft365Count > 0 {
      return "Uncertain mixed-mailbox messages stay out of Inbox until you explicitly import or dismiss them in Mailbox Monitor."
    }
    if !triageItems.isEmpty {
      return "Use the top triage row first, then create/link orders, mark reviewed, or create follow-up tasks as needed."
    }
    if parserIssueCount > 0 {
      return "The primary Inbox queue is clear. Parser diagnostics are hidden by default and should only be opened when investigating a specific intake problem."
    }
    return "No forwarded emails, staged imports, acceptance records, or parser checks currently need operator action."
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: isCompact ? 14 : 18) {
        header
        inboxSummaryPanel
        inboxContextSectionsPanel
        triagePanel
        if shouldShowInboxContextSections {
          inboxSupportingContextSections
        }
        detailRoutes
      }
      .padding(isCompact ? 14 : 24)
    }
    .background(.regularMaterial)
  }

  private var inboxContextSectionsPanel: some View {
    SettingsPanel(title: "Inbox context sections", symbol: "line.3.horizontal.decrease.circle.fill") {
      Text(shouldShowInboxContextSections ? "Provider health, parser diagnostics, mixed-mailbox decisions, and Wishlist order watch context are visible." : "Inbox opens with the daily triage queue first. Open context sections when you need mailbox provider health, parser diagnostics, mixed-mailbox decisions, or Wishlist order watch context.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      MetricStrip(items: [
        ("Triage", "\(triageItems.count)", triageItems.isEmpty ? .green : .teal),
        ("Visible", "\(visibleTriageItems.count)", visibleTriageItems.isEmpty ? .secondary : .blue),
        ("Uncertain", "\(uncertainSpaceMailCount + uncertainGmailCount + uncertainMicrosoft365Count)", uncertainSpaceMailCount + uncertainGmailCount + uncertainMicrosoft365Count == 0 ? .green : .orange),
        ("Filtered", "\(filteredSpaceMailCount + pendingFilteredGmailReviewCount + store.pendingMicrosoft365FilteredReviewCount)", filteredSpaceMailCount + pendingFilteredGmailReviewCount + store.pendingMicrosoft365FilteredReviewCount == 0 ? .secondary : .teal),
        ("Parser", "\(parserIssueCount)", parserIssueCount == 0 ? .green : .purple)
      ])

      CompactActionRow {
        Button(shouldShowInboxContextSections ? "Hide context sections" : "Show context sections", systemImage: shouldShowInboxContextSections ? "chevron.up.circle" : "chevron.down.circle") {
          showInboxContextSections.toggle()
        }
        .buttonStyle(.bordered)

        if hasActiveInboxFilters && !showInboxContextSections {
          Badge("Filters active", color: .orange)
        }
      }
    }
  }

  @ViewBuilder
  private var inboxSupportingContextSections: some View {
    MailboxProviderQuickStatusCard(summary: store.mailboxProviderComparisonSummary, store: store, showInboxLink: false)
    mailboxProviderNextStepPanel
    mailboxProviderReleaseGatePanel
    inboxProviderEvidencePanel
    SpaceMailPrimaryStatusStrip(store: store)
    SpaceMailMVPReadinessCard(summary: store.liveMailboxMVPReadinessSummary, showChecklist: false)
    SpaceMailQACheckCard(summary: store.mailboxIntakeQualitySummary)
    InboxSpaceMailDecisionGuide(store: store, showParserDiagnosticsInTriage: $showParserDiagnosticsInTriage)
    mailboxHealthPanel
    missingOrderDiagnosticPanel
    wishlistPurchaseReadinessPanel
    wishlistOrderWatchPanel
  }

  private var wishlistOrderWatchItems: [WishlistItem] {
    store.wishlistOrderWatchItems
  }

  private var wishlistOrderWatchMatchCount: Int {
    store.wishlistOrderWatchMatchCount
  }

  private var wishlistPurchaseReadinessItems: [WishlistItem] {
    store.wishlistPurchaseReadinessItems
  }

  private var wishlistPurchaseDecisionGapCount: Int {
    store.wishlistPurchaseDecisionGapCount
  }

  private var wishlistPurchaseHandoffGapCount: Int {
    store.wishlistPurchaseHandoffGapCount
  }

  private func wishlistPurchaseReadinessPriority(for item: WishlistItem) -> Int {
    store.wishlistPurchaseReadinessPriority(for: item)
  }

  private func wishlistPurchaseReadinessStage(for item: WishlistItem) -> String {
    store.wishlistPurchaseReadinessStage(for: item)
  }

  private func wishlistPurchaseReadinessColor(for item: WishlistItem) -> Color {
    wishlistPurchaseReadinessToneColor(store.wishlistPurchaseReadinessTone(for: item))
  }

  private func wishlistPurchaseReadinessToneColor(_ tone: String) -> Color {
    switch tone {
    case "setup": return .blue
    case "warning": return .orange
    case "critical": return .red
    case "decision": return .purple
    case "handoff": return .teal
    case "success": return .green
    default: return .secondary
    }
  }

  private func runWishlistPurchaseReadinessAction(for item: WishlistItem) {
    store.runWishlistPurchaseReadinessAction(for: item)
  }

  @ViewBuilder
  private var wishlistPurchaseReadinessPanel: some View {
    if !wishlistPurchaseReadinessItems.isEmpty {
      SettingsPanel(title: "Wishlist purchase readiness", symbol: "checklist.checked") {
        Text("Wishlist items that need comparison, seller choice, readiness checks, decision review, manual purchase handoff, or order confirmation matching are shown here so they do not get buried in the full Wishlist workspace.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("To review", "\(wishlistPurchaseReadinessItems.count)", .orange),
          ("Decision", "\(wishlistPurchaseDecisionGapCount)", wishlistPurchaseDecisionGapCount == 0 ? .green : .purple),
          ("Handoff", "\(wishlistPurchaseHandoffGapCount)", wishlistPurchaseHandoffGapCount == 0 ? .green : .purple),
          ("Order link", "\(wishlistOrderWatchItems.count)", wishlistOrderWatchItems.isEmpty ? .secondary : .teal)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 230 : 310), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(wishlistPurchaseReadinessItems.prefix(isCompact ? 3 : 6)) { item in
            VStack(alignment: .leading, spacing: 8) {
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: "star.square.fill")
                  .foregroundStyle(wishlistPurchaseReadinessColor(for: item))
                  .frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                  Text(item.itemName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                  Text(item.operatorPurchaseNextAction)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                Badge(wishlistPurchaseReadinessStage(for: item), color: wishlistPurchaseReadinessColor(for: item))
              }

              CompactMetadataGrid(minimumWidth: 105) {
                Label(item.storefront, systemImage: "storefront.fill")
                Label(item.purchaseReadiness ?? item.status, systemImage: "cart.badge.questionmark")
              }
              .font(.caption2)
              .foregroundStyle(.secondary)

              CompactActionRow {
                Button(wishlistPurchaseReadinessStage(for: item), systemImage: "arrow.forward.circle.fill") {
                  runWishlistPurchaseReadinessAction(for: item)
                }
                NavigationLink {
                  WishlistView(store: store)
                } label: {
                  Label("Wishlist", systemImage: "star.square.fill")
                }
              }
              .buttonStyle(.bordered)
              .controlSize(.small)
            }
            .padding(10)
            .background(wishlistPurchaseReadinessColor(for: item).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }

        Text("This panel only updates local Wishlist records, tasks, drafts, and audit history. It does not compare live sellers, buy items, open retailer accounts, send payments, mutate mailbox messages, or monitor orders in the background.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  @ViewBuilder
  private var wishlistOrderWatchPanel: some View {
    if !wishlistOrderWatchItems.isEmpty {
      SettingsPanel(title: "Wishlist order links", symbol: "star.square.on.square.fill") {
        Text("Wishlist purchases with a local handoff but no linked order appear here. Match them to already-imported Inbox confirmations; ParcelOps does not monitor retailer accounts or fetch mail in the background.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Need order link", "\(wishlistOrderWatchItems.count)", .orange),
          ("Inbox matches", "\(wishlistOrderWatchMatchCount)", wishlistOrderWatchMatchCount > 0 ? .green : .secondary),
          ("Source", "local intake", .blue)
        ])

        ForEach(wishlistOrderWatchItems.prefix(isCompact ? 3 : 5)) { item in
          WishlistOrderWatchMatchRow(
            item: item,
            matches: Array(store.suggestedWishlistOrderConfirmations(for: item).prefix(3)),
            onUseConfirmation: { email in
              store.confirmWishlistOrderFromIntake(item, email: email)
            },
            onMarkSeen: {
              store.markWishlistOrderConfirmationSeen(item)
            }
          )
        }

        CompactActionRow {
          NavigationLink {
            WishlistView(store: store)
          } label: {
            Label("Open Wishlist", systemImage: "star.square.fill")
          }
          .buttonStyle(.bordered)
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Open Mailbox Monitor", systemImage: "envelope.open.fill")
          }
          .buttonStyle(.bordered)
        }
      }
    }
  }

  private var mailboxProviderNextStepPanel: some View {
    let summary = mailboxProviderTestQueue
    let color = mailboxProviderReleaseGateColor(for: summary.tone)

    return SettingsPanel(title: "Active mailbox provider next step", symbol: "point.3.connected.trianglepath.dotted") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: summary.tone == "success" ? "checkmark.seal.fill" : "arrow.forward.circle.fill")
            .font(.title3)
            .foregroundStyle(color)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(summary.title)
              .font(.headline)
            Text(summary.detail)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Badge(summary.currentProvider, color: color)
        }

        MetricStrip(items: summary.metrics.map { metric in
          (metric.title, metric.value, mailboxProviderReleaseGateColor(for: metric.tone))
        })

        if !mailboxProviderNextItems.isEmpty {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 190 : 240), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(mailboxProviderNextItems) { item in
              VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 8) {
                  Image(systemName: item.isComplete ? "checkmark.circle.fill" : item.symbol)
                    .foregroundStyle(mailboxProviderReleaseGateColor(for: item.tone))
                    .frame(width: 18)
                  VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                      .font(.caption.weight(.semibold))
                      .fixedSize(horizontal: false, vertical: true)
                    Text("\(item.providerName) • \(item.phase)")
                      .font(.caption2.weight(.semibold))
                      .foregroundStyle(mailboxProviderReleaseGateColor(for: item.tone))
                  }
                }
                Text(item.detail)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
                Label(item.nextAction, systemImage: "arrow.forward.circle.fill")
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(mailboxProviderReleaseGateColor(for: item.tone))
                  .fixedSize(horizontal: false, vertical: true)
              }
              .padding(10)
              .frame(maxWidth: .infinity, alignment: .topLeading)
              .background(mailboxProviderReleaseGateColor(for: item.tone).opacity(item.isComplete ? 0.05 : 0.1), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }

        Text("Use this as the Inbox-level provider decision point. It does not start sign-in, run IMAP/Gmail refresh, read credentials, mutate mailboxes, or import messages.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        CompactActionRow {
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Mailbox Monitor", systemImage: "server.rack")
          }
          NavigationLink {
            SettingsView(store: store)
          } label: {
            Label("Settings", systemImage: "gearshape.2.fill")
          }
          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Audit", systemImage: "list.clipboard.fill")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private var inboxSummaryPanel: some View {
    SettingsPanel(title: "Inbox next action", symbol: "arrow.forward.circle.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: inboxSummaryTone == .green ? "checkmark.seal.fill" : "tray.full.fill")
            .foregroundStyle(inboxSummaryTone)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(inboxSummaryTitle)
              .font(.headline)
            Text(inboxSummaryDetail)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Badge(triageItems.isEmpty ? "Clear" : "\(triageItems.count) open", color: inboxSummaryTone)
        }

        MetricStrip(items: [
          ("Triage rows", "\(triageItems.count)", triageItems.isEmpty ? .green : .teal),
          ("Parser checks", "\(parserIssueCount)", parserIssueCount == 0 ? .green : .orange),
          ("Acceptance", "\(readyAcceptanceCount)", readyAcceptanceCount == 0 ? .green : .blue),
          ("Uncertain", "\(uncertainSpaceMailCount + uncertainGmailCount + uncertainMicrosoft365Count)", uncertainSpaceMailCount + uncertainGmailCount + uncertainMicrosoft365Count == 0 ? .green : .orange),
          ("Blocked", "\(blockedIncomingCount)", blockedIncomingCount == 0 ? .green : .red)
        ])

        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Label("Daily Inbox flow", systemImage: "checklist.checked")
              .font(.caption.weight(.semibold))
            Spacer()
            Badge("\(dailyFlowCompleteCount)/\(dailyFlowSteps.count)", color: dailyFlowCompleteCount == dailyFlowSteps.count ? .green : .orange)
          }

          LazyVGrid(columns: dailyFlowGridColumns, alignment: .leading, spacing: 8) {
            ForEach(dailyFlowSteps, id: \.title) { step in
              VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                  Image(systemName: step.isComplete ? "checkmark.circle.fill" : step.symbol)
                    .foregroundStyle(step.color)
                    .frame(width: 18, height: 18)
                  Text(step.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                Text(step.detail)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .lineLimit(3)
                  .minimumScaleFactor(0.86)
                  .fixedSize(horizontal: false, vertical: true)
                  .frame(maxWidth: .infinity, alignment: .topLeading)
              }
              .padding(8)
              .frame(maxWidth: .infinity, minHeight: dailyFlowCardHeight, maxHeight: dailyFlowCardHeight, alignment: .topLeading)
              .background(step.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }

        if hasGmailSetup {
          VStack(alignment: .leading, spacing: 6) {
            Label(inboxGmailCompileTitle, systemImage: inboxGmailReadiness?.isReady == true ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
              .font(.caption.weight(.semibold))
              .foregroundStyle(inboxGmailCompileColor)
            Text(inboxGmailCompileDetail)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            if let readiness = inboxGmailReadiness {
              CompactMetadataGrid(minimumWidth: isCompact ? 150 : 175) {
                Badge(readiness.compiledClientIDStatus, color: readiness.compiledClientIDStatus.localizedCaseInsensitiveContains("matches") || readiness.compiledClientIDStatus.localizedCaseInsensitiveContains("present") ? .green : .orange)
                Badge(readiness.compiledCallbackSchemeStatus, color: readiness.compiledCallbackSchemeStatus.localizedCaseInsensitiveContains("includes") || readiness.compiledCallbackSchemeStatus.localizedCaseInsensitiveContains("present") ? .green : .orange)
                Badge(readiness.expectedCallbackScheme, color: .secondary)
              }
            }
          }
          .padding(10)
          .background(inboxGmailCompileColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        CompactActionRow {
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Open Mailbox Monitor", systemImage: "server.rack")
          }
          NavigationLink {
            ImportQueueView(store: store)
          } label: {
            Label("Open Imports", systemImage: "tray.and.arrow.down.fill")
          }
          NavigationLink {
            AcceptanceReviewView(store: store)
          } label: {
            Label("Open Acceptance", systemImage: "checkmark.rectangle.stack.fill")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private var dailyFlowGridColumns: [GridItem] {
    let count = isCompact ? 2 : 3
    return Array(repeating: GridItem(.flexible(), spacing: 8), count: count)
  }

  private var dailyFlowCardHeight: CGFloat {
    isCompact ? 142 : 132
  }

  private var mailboxProviderReleaseGatePanel: some View {
    let gate = store.mailboxProviderReleaseGateSummary
    let color = mailboxProviderReleaseGateColor(for: gate.tone)
    let openGates = gate.gates.filter { !$0.isPassed }

    return SettingsPanel(title: "Mailbox provider release gate", symbol: "checkmark.seal.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: gate.tone == "success" ? "checkmark.seal.fill" : gate.tone == "warning" ? "exclamationmark.triangle.fill" : "checklist")
            .foregroundStyle(color)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(gate.title)
              .font(.headline)
            Text(gate.detail)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Badge(gate.verdict, color: color)
        }

        MetricStrip(items: gate.metrics.dropFirst().map { metric in
          (metric.title, metric.value, mailboxProviderReleaseGateColor(for: metric.tone))
        })

        DisclosureGroup(isExpanded: $showInboxGmailReleaseEvidence) {
          GmailReleaseBoundaryPanel(
            store: store,
            title: "Gmail provider release checks",
            lead: "These checks explain whether Google setup, sign-in, labels, classifier review, Inbox handoff, and audit evidence are ready before Gmail becomes a daily intake path.",
            sourceMetricTitle: "Open gates",
            sourceCount: openGates.count,
            boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store token values, create provider handoff notes automatically, or mutate mailbox messages."
          )
          .padding(.top, 8)
          Microsoft365ReleaseBoundaryPanel(
            store: store,
            title: "Outlook provider release checks",
            lead: "These checks explain whether Microsoft setup, sign-in, Graph diagnostics, mixed-mailbox review, Inbox handoff, and audit evidence are ready before Outlook becomes a daily intake path.",
            sourceMetricTitle: "Open gates",
            sourceCount: openGates.count,
            boundaryDetail: "Local-only boundary: this panel does not start Microsoft sign-in, request tokens, fetch Graph messages, store token values, create provider handoff notes automatically, or mutate mailbox messages."
          )
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            Text(showInboxGmailReleaseEvidence ? "Hide provider release evidence" : "Show provider release evidence")
              .font(.caption.weight(.semibold))
            Text("Open only when validating SpaceMail, Gmail, or Outlook setup, classifier review, Inbox handoff, and audit evidence.")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .tint(.teal)
        .padding(8)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))

        if openGates.isEmpty {
          Label("Provider setup, refresh evidence, Inbox handoff, diagnostics, blockers, and release plan checks currently pass from local evidence.", systemImage: "checkmark.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
            .fixedSize(horizontal: false, vertical: true)
        } else {
          VStack(alignment: .leading, spacing: 8) {
            Label("Open gate actions", systemImage: "arrow.forward.circle.fill")
              .font(.caption.weight(.semibold))
              .foregroundStyle(color)
            ForEach(Array(openGates.prefix(3)), id: \.title) { item in
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: item.symbol)
                  .foregroundStyle(mailboxProviderReleaseGateColor(for: item.tone))
                  .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                  Text(item.title)
                    .font(.caption.weight(.semibold))
                  Text(item.nextAction)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
              }
              .padding(8)
              .frame(maxWidth: .infinity, alignment: .topLeading)
              .background(mailboxProviderReleaseGateColor(for: item.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }

        if let providerReleaseGateFeedbackMessage {
          Label(providerReleaseGateFeedbackMessage, systemImage: "checkmark.circle.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.green)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        CompactActionRow {
          Button("Create gate task", systemImage: "checklist") {
            store.createReviewTaskFromMailboxProviderReleaseGate()
            providerReleaseGateFeedbackMessage = "Mailbox provider release gate task created. Check Tasks."
          }
          .buttonStyle(.bordered)

          Button("Create handoff note", systemImage: "arrow.left.arrow.right.square.fill") {
            store.createHandoffNoteFromMailboxProviderHandoffPacket()
            providerReleaseGateFeedbackMessage = "Mailbox provider handoff note created or refreshed. Check Handoff Notes or Tasks."
          }
          .buttonStyle(.bordered)

          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Mailbox Monitor", systemImage: "server.rack")
          }
          .buttonStyle(.bordered)

          NavigationLink {
            OperationsWorkbenchView(store: store)
          } label: {
            Label("Workbench", systemImage: "rectangle.stack.badge.person.crop.fill")
          }
          .buttonStyle(.bordered)

          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Tasks", systemImage: "checklist")
          }
          .buttonStyle(.bordered)

          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Audit", systemImage: "list.clipboard.fill")
          }
          .buttonStyle(.bordered)

          NavigationLink {
            SettingsView(store: store)
          } label: {
            Label("Settings", systemImage: "gearshape.2.fill")
          }
          .buttonStyle(.bordered)
        }

        Text("Inbox uses this gate as context only. It does not fetch mail, read credentials, change classifier rules, or mutate mailbox messages.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var inboxProviderEvidencePanel: some View {
    SettingsPanel(title: "Inbox provider evidence", symbol: "doc.text.magnifyingglass") {
      DisclosureGroup(isExpanded: $showInboxProviderEvidence) {
        MailboxProviderAdvancedDiagnosticsDisclosure(
          store: store,
          detail: "Open this when the Inbox provider handoff or troubleshooting detail is needed. The primary Inbox queue stays focused on messages that need action.",
          showReleaseGate: false
        )
        .padding(.top, 8)
      } label: {
        VStack(alignment: .leading, spacing: 4) {
          Text(showInboxProviderEvidence ? "Hide advanced Inbox evidence" : "Show advanced Inbox evidence")
            .font(.subheadline.weight(.semibold))
          Text("Daily triage can use the counts and release gate above. Open this only for provider diagnostics, handoff evidence, or troubleshooting.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .tint(.teal)
    }
  }

  private func mailboxProviderReleaseGateColor(for tone: String) -> Color {
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

  private var missingOrderDiagnosticTitle: String {
    if latestMailboxImportedCount > 0 { return "Review imported mailbox items first" }
    if latestMailboxUncertainCount > 0 { return "Expected order may be in uncertain review" }
    if latestMailboxFilteredCount > 0 { return "Expected order may have been filtered" }
    if parserIssueCount > 0 { return "Expected order may need parser review" }
    if latestMailboxFetchedCount > 0 { return "Latest refresh found no order candidates" }
    return "No mailbox refresh result to inspect yet"
  }

  private var missingOrderDiagnosticDetail: String {
    if latestMailboxImportedCount > 0 {
      return "\(latestMailboxImportedCount) mailbox message\(latestMailboxImportedCount == 1 ? "" : "s") reached Inbox. Work those rows before tuning filters."
    }
    if latestMailboxUncertainCount > 0 {
      return "\(latestMailboxUncertainCount) uncertain preview\(latestMailboxUncertainCount == 1 ? "" : "s") stayed out of the primary Inbox until manually imported or dismissed."
    }
    if latestMailboxFilteredCount > 0 {
      return "\(latestMailboxFilteredCount) fetched message\(latestMailboxFilteredCount == 1 ? "" : "s") were classified as non-order. Open Mailbox Monitor to inspect safe examples and import only true order mail."
    }
    if parserIssueCount > 0 {
      return "\(parserIssueCount) parser check\(parserIssueCount == 1 ? "" : "s") may explain missing order/tracking values on already-imported rows."
    }
    if latestMailboxFetchedCount > 0 {
      return "The latest refresh fetched \(latestMailboxFetchedCount) message\(latestMailboxFetchedCount == 1 ? "" : "s") but produced no Inbox work. Send a known test order or inspect Mailbox Monitor diagnostics."
    }
    return "Run a manual mailbox refresh from Mailbox Monitor after setup is ready."
  }

  private var missingOrderDiagnosticTone: Color {
    if latestMailboxImportedCount > 0 { return .green }
    if latestMailboxUncertainCount > 0 || parserIssueCount > 0 { return .orange }
    if latestMailboxFilteredCount > 0 || latestMailboxFetchedCount > 0 { return .teal }
    return .secondary
  }

  private var missingOrderProviderBreakdown: [(provider: String, detail: String, color: Color)] {
    var rows: [(provider: String, detail: String, color: Color)] = []

    if let latestSpaceMailSummary {
      rows.append((
        "SpaceMail",
        "\(latestSpaceMailSummary.compactRefreshCountsText).",
        latestSpaceMailSummary.importedCount > 0 ? .green : latestSpaceMailSummary.totalUncertainCount > 0 ? .orange : latestSpaceMailSummary.filteredCount > 0 ? .teal : .secondary
      ))
    }

    if let latestGmailSummary {
      rows.append((
        "Gmail",
        "\(latestGmailSummary.compactRefreshCountsText).",
        latestGmailSummary.importedCount > 0 ? .green : latestGmailSummary.totalUncertainCount > 0 ? .orange : latestGmailSummary.filteredCount > 0 ? .teal : .secondary
      ))
    }

    if !store.microsoft365MailboxConnections.isEmpty {
      let signedInCount = store.microsoft365ConnectedAuthCount
      let readyCount = store.microsoft365ReadySetupCount
      rows.append((
        "Microsoft 365",
        signedInCount > 0
          ? "\(signedInCount) Outlook/Microsoft setup signed in; Graph refresh still has to import a row before Orders change."
          : readyCount > 0
            ? "\(readyCount) Outlook/Microsoft setup ready for explicit sign-in; no Inbox row has been imported yet."
            : "Outlook/Microsoft setup exists, but readiness must be completed before sign-in or Graph refresh.",
        signedInCount > 0 ? .purple : .orange
      ))
    }

    return rows
  }

  private var missingOrderDiagnosticPanel: some View {
    SettingsPanel(title: "Expected order missing?", symbol: "magnifyingglass.circle.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: latestMailboxImportedCount > 0 ? "tray.and.arrow.down.fill" : "magnifyingglass.circle.fill")
            .foregroundStyle(missingOrderDiagnosticTone)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(missingOrderDiagnosticTitle)
              .font(.headline)
            Text(missingOrderDiagnosticDetail)
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Badge(latestMailboxImportedCount > 0 ? "Inbox" : latestMailboxUncertainCount > 0 ? "Review" : latestMailboxFilteredCount > 0 ? "Filtered" : "Check", color: missingOrderDiagnosticTone)
        }

        MetricStrip(items: [
          ("Fetched", "\(latestMailboxFetchedCount)", latestMailboxFetchedCount > 0 ? .blue : .secondary),
          ("Imported", "\(latestMailboxImportedCount)", latestMailboxImportedCount > 0 ? .green : .secondary),
          ("Duplicates", "\(latestMailboxDuplicateCount)", latestMailboxDuplicateCount > 0 ? .orange : .secondary),
          ("Filtered", "\(latestMailboxFilteredCount)", latestMailboxFilteredCount > 0 ? .teal : .secondary),
          ("Uncertain", "\(latestMailboxUncertainCount)", latestMailboxUncertainCount > 0 ? .orange : .secondary),
          ("Parser", "\(parserIssueCount)", parserIssueCount > 0 ? .orange : .green)
        ])

        if !missingOrderProviderBreakdown.isEmpty {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 170 : 220), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(missingOrderProviderBreakdown, id: \.provider) { row in
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: row.provider == "Gmail" ? "envelope.badge.shield.half.filled" : row.provider == "Microsoft 365" ? "mail.stack.fill" : "server.rack")
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

        CompactMetadataGrid(minimumWidth: isCompact ? 150 : 180) {
          inboxDiagnosticStep(
            title: "Inbox",
            detail: latestMailboxImportedCount > 0 ? "Work imported rows here." : "No imported rows from latest refresh.",
            isActive: latestMailboxImportedCount > 0
          )
          inboxDiagnosticStep(
            title: "Uncertain",
            detail: latestMailboxUncertainCount > 0 ? "Review in Mailbox Monitor." : "No uncertain previews pending.",
            isActive: latestMailboxUncertainCount > 0
          )
          inboxDiagnosticStep(
            title: "Filtered",
            detail: latestMailboxFilteredCount > 0 ? "Inspect examples if an order is missing." : "No filtered evidence to inspect.",
            isActive: latestMailboxFilteredCount > 0
          )
          inboxDiagnosticStep(
            title: "Parser",
            detail: parserIssueCount > 0 ? "Enable diagnostics or reprocess." : "Parser queue is clear.",
            isActive: parserIssueCount > 0
          )
        }

        Text("This panel is a shortcut to local refresh diagnostics. It does not fetch mail, mutate mailbox messages, or change duplicate metadata.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        CompactActionRow {
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Investigate in Mailbox Monitor", systemImage: "server.rack")
          }
          if parserIssueCount > 0 {
            Button(showParserDiagnosticsInTriage ? "Hide parser rows" : "Show parser rows", systemImage: "text.magnifyingglass") {
              showParserDiagnosticsInTriage.toggle()
            }
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private func inboxDiagnosticStep(title: String, detail: String, isActive: Bool) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: isActive ? "exclamationmark.circle.fill" : "checkmark.circle")
        .foregroundStyle(isActive ? missingOrderDiagnosticTone : Color.secondary)
        .frame(width: 18)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption.weight(.semibold))
        Text(detail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background((isActive ? missingOrderDiagnosticTone : Color.secondary).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private var triagePanel: some View {
    SettingsPanel(title: "Unified triage queue", symbol: "tray.full.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Work the highest-risk incoming order signals here, then open a detailed view when a record needs correction or linking.")
          .font(.callout)
          .foregroundStyle(.secondary)

        FilterControlGrid {
          TextField("Search inbox triage", text: $triageSearchText)
            .textFieldStyle(.roundedBorder)
          Picker("Group", selection: $triageGroupFilter) {
            ForEach(InboxTriageGroupFilter.allCases) { filter in
              Text(filter.label).tag(filter)
            }
          }
          .pickerStyle(.menu)
          Picker("Source", selection: $triageSourceFilter) {
            ForEach(InboxTriageSourceFilter.allCases) { filter in
              Text(filter.label).tag(filter)
            }
          }
          .pickerStyle(.menu)
          Picker("Parse", selection: $triageQualityFilter) {
            ForEach(InboxTriageQualityFilter.allCases) { filter in
              Text(filter.label).tag(filter)
            }
          }
          .pickerStyle(.menu)
          Toggle("Show parser diagnostics", isOn: $showParserDiagnosticsInTriage)
            .toggleStyle(.switch)
            .disabled(parserIssueCount == 0)
          if !triageSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasActiveTriageFilters {
            Button("Reset filters", systemImage: "xmark.circle") {
              triageSearchText = ""
              triageGroupFilter = .all
              triageSourceFilter = .all
              triageQualityFilter = .all
            }
            .buttonStyle(.bordered)
          }
        }

        if visibleTriageItems.isEmpty {
          MVPEmptyState(
            title: triageItems.isEmpty ? "Inbox triage is clear" : "No matching triage rows",
            detail: triageItems.isEmpty ? "Forwarded emails, staged imports, and acceptance decisions that need action will appear here. Turn on parser diagnostics when you want to inspect parsing issues." : "Reset filters or clear the search to return to the full Inbox triage queue.",
            symbol: "checkmark.seal.fill"
          )
        } else {
          if hiddenTriageItemCount > 0 {
            CompactActionRow {
              Label("Showing first \(visibleTriageItems.count) matched rows", systemImage: "speedometer")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
              Badge("\(hiddenTriageItemCount) hidden", color: .secondary)
              Text("Use search or filters to narrow the queue before opening detailed records.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          if parserIssueCount > 0 && !showParserDiagnosticsInTriage {
            Label("\(parserIssueCount) parser checks are hidden from this primary queue. Turn on parser diagnostics when you need reprocess/task actions, or use Mailbox Monitor for detailed parser review.", systemImage: "text.magnifyingglass")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          ForEach(visibleTriageGroups) { bucket in
            InboxTriageGroupSection(bucket: bucket, store: store)
          }
        }
      }
    }
  }

  private var mailboxHealthPanel: some View {
    SettingsPanel(title: "Mailbox intake health", symbol: "server.rack") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Manual mailbox refreshes can come from the active provider rows. This summary shows whether recent refreshes produced actionable intake or mostly filtered normal mail. Use Mailbox Monitor for setup, classifier tuning, and detailed diagnostics.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        if store.spaceMailIntakeHealthSummaries.isEmpty && store.gmailIntakeHealthSummaries.isEmpty && store.microsoft365IntakeHealthSummaries.isEmpty {
          MVPEmptyState(
            title: "No manual mailbox refresh history",
            detail: "Add SpaceMail for IMAP mailboxes, Gmail for Google-hosted mailboxes, or Outlook for Microsoft-hosted mailboxes in Mailbox Monitor or Settings when you are ready to use real intake.",
            symbol: "server.rack"
          )
        } else {
          if !store.spaceMailIntakeHealthSummaries.isEmpty {
            CompactSpaceMailActionPlan(plan: store.spaceMailPostRefreshActionPlan)
          }

          if !store.spaceMailIntakeHealthSummaries.isEmpty {
            SpaceMailRefreshTrendCard(summary: store.spaceMailRefreshTrendSummary)
          }

          Text("Trend rows show recent manual refresh outcomes only. Filtered mixed-mailbox mail stays out of Inbox; imported and uncertain counts are the signals to act on.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if hiddenMailboxHealthSummaryCount > 0 {
            CompactActionRow {
              Label("Showing recent provider refresh rows", systemImage: "speedometer")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
              Badge("\(hiddenMailboxHealthSummaryCount) older hidden", color: .secondary)
              Button(showFullMailboxHealthHistory ? "Show recent" : "Show all history", systemImage: showFullMailboxHealthHistory ? "rectangle.compress.vertical" : "rectangle.expand.vertical") {
                showFullMailboxHealthHistory.toggle()
              }
              .buttonStyle(.bordered)
            }
          }

          ForEach(displayedSpaceMailHealthSummaries) { summary in
            InboxMailboxHealthRow(summary: summary)
          }

          ForEach(displayedGmailHealthSummaries) { summary in
            InboxGmailHealthRow(
              summary: summary,
              reasonBreakdown: store.gmailMailboxConnections.first { $0.id == summary.connectionID }?.lastRefreshReasonBreakdown ?? []
            )
          }

          ForEach(displayedMicrosoft365HealthSummaries) { summary in
            InboxOutlookHealthRow(summary: summary)
          }
        }

        CompactActionRow {
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Open Mailbox Monitor", systemImage: "server.rack")
          }
          .buttonStyle(.bordered)

          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Open Audit", systemImage: "list.clipboard.fill")
          }
          .buttonStyle(.bordered)
        }
      }
    }
  }

  private var detailRoutes: some View {
    SettingsPanel(title: "Detailed inbox views", symbol: "rectangle.stack.fill") {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 220 : 260), spacing: 12)], alignment: .leading, spacing: 12) {
        OperatorRouteCard(title: "Mailbox Monitor", detail: "Review forwarded order emails and detected fields.", symbol: "envelope.badge.fill", badge: "\(store.intakeEmails.count) emails") {
          MailboxView(store: store)
        }

        OperatorRouteCard(title: "Import Queue", detail: "Review manually staged order records before accepting them.", symbol: "tray.and.arrow.down.fill", badge: "\(store.importQueueItems.count) imports") {
          ImportQueueView(store: store)
        }

        OperatorRouteCard(title: "Acceptance Review", detail: "Link intake to existing orders or create new local records.", symbol: "checkmark.rectangle.stack.fill", badge: "\(store.acceptanceRecordsNeedingReview.count) to review") {
          AcceptanceReviewView(store: store)
        }
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Inbox")
        .font(isCompact ? .title.bold() : .largeTitle.bold())
      Text("Triage incoming order signals, staged imports, and acceptance decisions before they become operational records.")
        .foregroundStyle(.secondary)

      MetricStrip(items: [
        ("Triage", "\(triageItems.count)", triageItems.isEmpty ? .green : .teal),
        ("Emails", "\(store.reviewIntakeEmails.count)", store.reviewIntakeEmails.isEmpty ? .green : .blue),
        ("Parser", "\(store.intakeParserDiagnostics.count)", store.intakeParserDiagnostics.isEmpty ? .green : .secondary),
        ("Mailbox", "\(mailboxHealthAttentionCount)", .purple),
        ("Imports", "\(store.importQueueItemsNeedingReview.count)", store.importQueueItemsNeedingReview.isEmpty ? .green : .teal),
        ("Acceptance", "\(store.acceptanceRecordsNeedingReview.count)", store.acceptanceRecordsNeedingReview.isEmpty ? .green : .orange),
        ("All records", "\(store.intakeEmails.count + store.importQueueItems.count)", .gray)
      ])
    }
  }

  private func uniqueImportItems(_ items: [ImportQueueItem]) -> [ImportQueueItem] {
    var seen: Set<UUID> = []
    var unique: [ImportQueueItem] = []
    for item in items where !seen.contains(item.id) {
      seen.insert(item.id)
      unique.append(item)
    }
    return unique
  }
}

private struct InboxSpaceMailDecisionGuide: View {
  var store: ParcelOpsStore
  @Binding var showParserDiagnosticsInTriage: Bool

  private var fetchedCount: Int {
    store.totalMailboxFetchedCount
  }

  private var importedCount: Int {
    store.totalMailboxImportedCount
  }

  private var duplicateCount: Int {
    store.totalMailboxDuplicateCount
  }

  private var filteredCount: Int {
    store.totalMailboxFilteredSignalCount
  }

  private var uncertainCount: Int {
    store.pendingMailboxUncertainReviewCount
  }

  private var parserIssueCount: Int {
    store.intakeParserDiagnostics.count
  }

  private var parserSuiteResults: [SpaceMailClassifierTestResult] {
    store.spaceMailIMAPConnections.flatMap(\.classifierTestResults)
  }

  private var parserSuiteChecks: [SpaceMailClassifierTestResult] {
    parserSuiteResults.filter { !$0.parserStatus.localizedCaseInsensitiveContains("No parser expectation") }
  }

  private var parserSuitePasses: [SpaceMailClassifierTestResult] {
    parserSuiteChecks.filter { $0.parserStatus.localizedCaseInsensitiveContains("passed") }
  }

  private var parserSuiteFailures: [SpaceMailClassifierTestResult] {
    parserSuiteChecks.filter { $0.parserStatus.localizedCaseInsensitiveContains("needs review") }
  }

  private var parserExtractedIDCount: Int {
    parserSuiteResults.filter {
      !$0.detectedOrderNumber.isPlaceholderValidationValue || !$0.detectedTrackingNumber.isPlaceholderValidationValue
    }.count
  }

  private var parserQATitle: String {
    if parserSuiteChecks.isEmpty { return "Parser QA not run yet" }
    if !parserSuiteFailures.isEmpty { return "Parser QA needs review" }
    return "Parser QA passed"
  }

  private var parserQADetail: String {
    if parserSuiteChecks.isEmpty {
      return "Run the SpaceMail parser/classifier suite in Mailbox Monitor before relying on live IMAP extraction for order and tracking numbers."
    }
    if !parserSuiteFailures.isEmpty {
      return "\(parserSuiteFailures.count) parser expectation failed. Review the sample result before creating orders from similar email text."
    }
    return "\(parserSuitePasses.count) parser expectations passed, including built-in samples for order and tracking extraction."
  }

  private var parserQAColor: Color {
    if parserSuiteChecks.isEmpty { return .secondary }
    return parserSuiteFailures.isEmpty ? .green : .orange
  }

  private var topActionTitle: String {
    if importedCount > 0 { return "Start with imported intake rows" }
    if uncertainCount > 0 { return "Review uncertain mailbox messages" }
    if parserIssueCount > 0 { return "Open parser diagnostics only for investigation" }
    if filteredCount > 0 { return "Filtered mail stayed out of Inbox" }
    if duplicateCount > 0 { return "Duplicates were already captured" }
    if fetchedCount > 0 { return "Refresh ran with no action needed" }
    return "Run a manual mailbox refresh when ready"
  }

  private var topActionDetail: String {
    if importedCount > 0 {
      return "Confirm detected order and tracking fields before creating or linking an order."
    }
    if uncertainCount > 0 {
      return "Use Mailbox Monitor to import only the messages that clearly relate to an order."
    }
    if parserIssueCount > 0 {
      return "Parser diagnostics are not primary work; use them when an expected order email did not classify correctly."
    }
    if filteredCount > 0 {
      return "Filtered mixed-mailbox messages were counted only and did not enter primary Inbox triage."
    }
    if duplicateCount > 0 {
      return "Duplicate prevention avoided repeated Inbox rows. Existing intake can still be refreshed or reprocessed locally."
    }
    if fetchedCount > 0 {
      return "No imported or uncertain order mail was found in the latest mailbox result."
    }
    return "Run a mailbox refresh from Mailbox Monitor after confirming credential, sign-in, and setup status."
  }

  private var topActionColor: Color {
    if importedCount > 0 { return .green }
    if uncertainCount > 0 || parserIssueCount > 0 { return .orange }
    if filteredCount > 0 || duplicateCount > 0 || fetchedCount > 0 { return .teal }
    return .secondary
  }

  var body: some View {
    SettingsPanel(title: "Mailbox triage decision guide", symbol: "signpost.right.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: "signpost.right.fill")
            .foregroundStyle(topActionColor)
            .frame(width: 24)

          VStack(alignment: .leading, spacing: 4) {
            Text(topActionTitle)
              .font(.headline)
            Text(topActionDetail)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer()
          Badge(importedCount > 0 || uncertainCount > 0 ? "Action" : "Monitor", color: topActionColor)
        }

        MetricStrip(items: [
          ("Imported", "\(importedCount)", importedCount > 0 ? .green : .secondary),
          ("Uncertain", "\(uncertainCount)", uncertainCount > 0 ? .orange : .secondary),
          ("Filtered", "\(filteredCount)", filteredCount > 0 ? .teal : .secondary),
          ("Duplicates", "\(duplicateCount)", duplicateCount > 0 ? .orange : .secondary),
          ("Parser", "\(parserIssueCount)", parserIssueCount > 0 ? .orange : .secondary),
          ("Providers", "\(store.mailboxProviderSetupCount)", !store.hasMailboxProviderSetup ? .secondary : .blue)
        ])

        HStack(alignment: .top, spacing: 10) {
          Image(systemName: parserSuiteFailures.isEmpty && !parserSuiteChecks.isEmpty ? "checkmark.seal.fill" : "text.magnifyingglass")
            .foregroundStyle(parserQAColor)
            .frame(width: 24)

          VStack(alignment: .leading, spacing: 4) {
            Text(parserQATitle)
              .font(.subheadline.weight(.semibold))
            Text(parserQADetail)
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer()
          CompactMetadataGrid(minimumWidth: 100) {
            Badge(parserSuiteChecks.isEmpty ? "Not run" : "\(parserSuitePasses.count)/\(parserSuiteChecks.count)", color: parserQAColor)
            Badge("\(parserExtractedIDCount) IDs", color: parserExtractedIDCount == 0 ? .secondary : .blue)
          }
        }
        .padding(10)
        .background(parserQAColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], alignment: .leading, spacing: 10) {
          InboxDecisionGuideItem(
            title: "Imported",
            detail: "Treat as primary work. Confirm merchant, order number, tracking number, and destination before create/link order.",
            symbol: "tray.full.fill",
            color: .green
          )
          InboxDecisionGuideItem(
            title: "Uncertain",
            detail: "Keep out of Inbox until reviewed. Import only if the subject or preview clearly indicates an order/update.",
            symbol: "questionmark.diamond.fill",
            color: .orange
          )
          InboxDecisionGuideItem(
            title: "Filtered",
            detail: "No primary action. Check examples only when an expected order email is missing after refresh.",
            symbol: "line.3.horizontal.decrease.circle.fill",
            color: .teal
          )
          InboxDecisionGuideItem(
            title: "Duplicate",
            detail: "No duplicate row was created. Reprocess existing intake if parser hints changed or fields look stale.",
            symbol: "doc.on.doc.fill",
            color: .purple
          )
        }

        CompactActionRow {
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label(parserSuiteChecks.isEmpty ? "Run parser QA in Mailbox Monitor" : "Review SpaceMail results", systemImage: "server.rack")
          }

          Button(showParserDiagnosticsInTriage ? "Hide parser diagnostics" : "Show parser diagnostics", systemImage: "text.magnifyingglass") {
            showParserDiagnosticsInTriage.toggle()
          }
          .disabled(parserIssueCount == 0)
          .help("Toggles parser diagnostic rows in the unified triage queue below.")
        }
        .buttonStyle(.bordered)

        Text("This guide uses local mailbox refresh summaries only. It does not fetch mail, mutate the mailbox, call external classifiers, or send messages.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

private struct InboxDecisionGuideItem: View {
  var title: String
  var detail: String
  var symbol: String
  var color: Color

  var body: some View {
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

private struct InboxMailboxHealthRow: View {
  var summary: SpaceMailIntakeHealthSummary

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label(summary.displayName, systemImage: "server.rack")
          .font(.subheadline.weight(.semibold))
        Spacer()
        Badge(summary.verdict, color: color)
      }
      Text(summary.detail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      CompactMetadataGrid(minimumWidth: 110) {
        Badge("\(summary.fetchedCount) fetched", color: .blue)
        Badge("\(summary.importedCount) imported", color: summary.importedCount > 0 ? .green : .secondary)
        Badge("\(summary.filteredCount) filtered", color: summary.filteredCount > 0 ? .teal : .secondary)
        Badge("\(summary.duplicateCount) duplicates", color: summary.duplicateCount > 0 ? .orange : .secondary)
        Badge("\(summary.totalUncertainCount) uncertain", color: summary.totalUncertainCount > 0 ? .orange : .secondary)
        Badge("\(summary.parserIssueCount) parser checks", color: summary.parserIssueCount > 0 ? .orange : .secondary)
      }
      Text(summary.nextAction)
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .fixedSize(horizontal: false, vertical: true)
      HStack(alignment: .top, spacing: 8) {
        Image(systemName: nextActionSymbol)
          .foregroundStyle(color)
          .frame(width: 18)
        VStack(alignment: .leading, spacing: 3) {
          Text(nextActionTitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
          Text(nextActionDetail)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 0)
      }
      .padding(8)
      .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      if !summary.topReasonLabels.isEmpty {
        Text("Latest reasons: \(summary.topReasonLabels.joined(separator: "; "))")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(3)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private var color: Color {
    switch summary.tone {
    case "success":
      return .green
    case "attention":
      return .orange
    case "warning":
      return .red
    default:
      return .blue
    }
  }

  private var nextActionTitle: String {
    if summary.importedCount > 0 { return "Work imported SpaceMail rows" }
    if summary.totalUncertainCount > 0 { return "Review uncertain SpaceMail previews" }
    if summary.parserIssueCount > 0 { return "Use parser diagnostics only if needed" }
    if summary.filteredCount > 0 { return "Filtered mail stayed out of Inbox" }
    if summary.duplicateCount > 0 { return "Duplicates did not create Inbox rows" }
    return "No SpaceMail Inbox work from latest refresh"
  }

  private var nextActionDetail: String {
    if summary.importedCount > 0 {
      return "Open Inbox triage, confirm detected order fields, then create or link orders."
    }
    if summary.totalUncertainCount > 0 {
      return "Open Mailbox Monitor and import only messages that clearly relate to orders."
    }
    if summary.parserIssueCount > 0 {
      return "Use parser diagnostics when an expected order did not classify or extract correctly."
    }
    if summary.filteredCount > 0 {
      return "No Inbox action is needed unless a filtered example should be promoted manually."
    }
    if summary.duplicateCount > 0 {
      return "Duplicate prevention is working; no duplicate cleanup is required."
    }
    return "Run manual refresh again only when new mailbox activity is expected."
  }

  private var nextActionSymbol: String {
    if summary.importedCount > 0 { return "tray.and.arrow.down.fill" }
    if summary.totalUncertainCount > 0 { return "questionmark.folder.fill" }
    if summary.parserIssueCount > 0 { return "text.magnifyingglass" }
    if summary.filteredCount > 0 { return "line.3.horizontal.decrease.circle" }
    if summary.duplicateCount > 0 { return "arrow.triangle.2.circlepath" }
    return "checkmark.circle"
  }
}

private struct InboxGmailHealthRow: View {
  var summary: GmailIntakeHealthSummary
  var reasonBreakdown: [SpaceMailClassifierReasonCount] = []

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label(summary.displayName, systemImage: "envelope.badge.shield.half.filled")
          .font(.subheadline.weight(.semibold))
        Spacer()
        Badge(summary.verdict, color: color)
      }
      Text(summary.detail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      CompactMetadataGrid(minimumWidth: 110) {
        Badge("\(summary.fetchedCount) fetched", color: .blue)
        Badge("\(summary.importedCount) imported", color: summary.importedCount > 0 ? .green : .secondary)
        Badge("\(summary.filteredCount) filtered", color: summary.filteredCount > 0 ? .teal : .secondary)
        Badge("\(summary.duplicateCount) duplicates", color: summary.duplicateCount > 0 ? .orange : .secondary)
        Badge("\(summary.totalUncertainCount) uncertain", color: summary.totalUncertainCount > 0 ? .orange : .secondary)
      }
      Text(summary.nextAction)
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .fixedSize(horizontal: false, vertical: true)
      HStack(alignment: .top, spacing: 8) {
        Image(systemName: nextActionSymbol)
          .foregroundStyle(color)
          .frame(width: 18)
        VStack(alignment: .leading, spacing: 3) {
          Text(nextActionTitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
          Text(nextActionDetail)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 0)
      }
      .padding(8)
      .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      Text("Gmail refresh is manual and read-only. Filtered mixed-mailbox mail stays out of Inbox; imported and uncertain counts are the operator signals.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      if !reasonBreakdown.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Label("Classifier reasons", systemImage: "line.3.horizontal.decrease.circle.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.teal)
          ForEach(Array(reasonBreakdown.prefix(4))) { item in
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Badge(item.decision, color: classifierReasonColor(item.decision))
              Text("\(item.count)x \(item.reason)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
              Spacer(minLength: 0)
            }
          }

          let hiddenReasonCount = max(reasonBreakdown.count - 4, 0)
          if hiddenReasonCount > 0 {
            Text("\(hiddenReasonCount) more classifier reason\(hiddenReasonCount == 1 ? "" : "s") are available in Mailbox Monitor diagnostics.")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        .padding(8)
        .background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }
      if summary.filteredCount > 0 {
        Text("Filtered Gmail examples are reviewable in Mailbox Monitor and Needs Review. Import one only when the classifier was too strict.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.teal)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private var color: Color {
    switch summary.tone {
    case "success":
      return .green
    case "attention":
      return .orange
    case "warning":
      return .red
    default:
      return .blue
    }
  }

  private var nextActionTitle: String {
    if summary.importedCount > 0 { return "Work imported Gmail rows" }
    if summary.totalUncertainCount > 0 { return "Review uncertain Gmail previews" }
    if summary.filteredCount > 0 { return "Filtered Gmail stayed out of Inbox" }
    if summary.duplicateCount > 0 { return "Duplicates did not create Inbox rows" }
    if summary.fetchedCount > 0 { return "No Gmail order candidates found" }
    return "No Gmail Inbox work from latest refresh"
  }

  private var nextActionDetail: String {
    if summary.importedCount > 0 {
      return "Open Inbox triage, confirm detected details, then create or link orders."
    }
    if summary.totalUncertainCount > 0 {
      return "Open Mailbox Monitor and import or dismiss uncertain Gmail previews before they reach Inbox."
    }
    if summary.filteredCount > 0 {
      return "No Inbox action is needed unless a filtered example should be promoted manually."
    }
    if summary.duplicateCount > 0 {
      return "Duplicate prevention is working; no duplicate cleanup is required."
    }
    if summary.fetchedCount > 0 {
      return "The latest Gmail pass fetched mail but found no order intake candidates."
    }
    return "Run manual Gmail refresh again only when new mailbox activity is expected."
  }

  private var nextActionSymbol: String {
    if summary.importedCount > 0 { return "tray.and.arrow.down.fill" }
    if summary.totalUncertainCount > 0 { return "questionmark.folder.fill" }
    if summary.filteredCount > 0 { return "line.3.horizontal.decrease.circle" }
    if summary.duplicateCount > 0 { return "arrow.triangle.2.circlepath" }
    return "checkmark.circle"
  }

  private func classifierReasonColor(_ decision: String) -> Color {
    if decision.localizedCaseInsensitiveContains("import") { return .green }
    if decision.localizedCaseInsensitiveContains("uncertain") { return .orange }
    if decision.localizedCaseInsensitiveContains("filter") { return .teal }
    return .secondary
  }
}

private struct InboxOutlookHealthRow: View {
  var summary: Microsoft365IntakeHealthSummary

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label(summary.displayName, systemImage: "mail.stack.fill")
          .font(.subheadline.weight(.semibold))
        Spacer()
        Badge(summary.verdict, color: color)
      }
      Text(summary.detail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      CompactMetadataGrid(minimumWidth: 110) {
        Badge("\(summary.fetchedCount) fetched", color: .blue)
        Badge("\(summary.importedCount) imported", color: summary.importedCount > 0 ? .green : .secondary)
        Badge("\(summary.duplicateCount) duplicates", color: summary.duplicateCount > 0 ? .orange : .secondary)
        Badge("\(summary.duplicateRefreshedCount) refreshed", color: summary.duplicateRefreshedCount > 0 ? .teal : .secondary)
        Badge("\(summary.blockedCount) blockers", color: summary.blockedCount > 0 ? .red : .secondary)
      }
      Text(summary.nextAction)
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .fixedSize(horizontal: false, vertical: true)
      HStack(alignment: .top, spacing: 8) {
        Image(systemName: nextActionSymbol)
          .foregroundStyle(color)
          .frame(width: 18)
        VStack(alignment: .leading, spacing: 3) {
          Text(nextActionTitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
          Text(nextActionDetail)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 0)
      }
      .padding(8)
      .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      Text("Outlook refresh uses explicit Microsoft 365 sign-in and read-only Graph calls. It does not mutate mailbox messages, send mail, or store token values in ParcelOps JSON.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private var color: Color {
    switch summary.tone {
    case "success":
      return .green
    case "attention":
      return .orange
    case "warning":
      return .red
    default:
      return .blue
    }
  }

  private var nextActionTitle: String {
    if summary.blockedCount > 0 { return "Review Outlook diagnostics" }
    if summary.importedCount > 0 { return "Work imported Outlook rows" }
    if summary.duplicateRefreshedCount > 0 { return "Review refreshed Outlook rows" }
    if summary.duplicateCount > 0 { return "Duplicates did not create Inbox rows" }
    if summary.fetchedCount > 0 { return "No Outlook order candidates found" }
    return "Outlook is ready when needed"
  }

  private var nextActionDetail: String {
    if summary.blockedCount > 0 {
      return "Use Mailbox Monitor or Audit to check sign-in, consent, token metadata, and Graph-read diagnostics before relying on Outlook."
    }
    if summary.importedCount > 0 {
      return "Open Inbox triage, confirm detected details, then create or link orders."
    }
    if summary.duplicateRefreshedCount > 0 {
      return "Duplicate-safe refresh updated existing Inbox rows; review only if field changes need confirmation."
    }
    if summary.duplicateCount > 0 {
      return "Duplicate prevention is working; no duplicate cleanup is required."
    }
    if summary.fetchedCount > 0 {
      return "The latest Outlook pass produced no actionable Inbox intake."
    }
    return "Run Microsoft sign-in and manual Graph refresh only for Microsoft-hosted mailboxes."
  }

  private var nextActionSymbol: String {
    if summary.blockedCount > 0 { return "exclamationmark.triangle.fill" }
    if summary.importedCount > 0 { return "tray.and.arrow.down.fill" }
    if summary.duplicateRefreshedCount > 0 { return "arrow.triangle.2.circlepath.circle.fill" }
    if summary.duplicateCount > 0 { return "arrow.triangle.2.circlepath" }
    return "checkmark.circle"
  }
}

private enum InboxTriageGroup: String, CaseIterable {
  case needsCorrection = "Needs correction"
  case readyToLink = "Ready to create or link"
  case readyToProcess = "Ready to process"
  case parserChecks = "Parser checks"

  static let displayOrder: [InboxTriageGroup] = [
    .needsCorrection,
    .readyToLink,
    .readyToProcess,
    .parserChecks
  ]

  var detail: String {
    switch self {
    case .needsCorrection:
      return "Fix weak or partial fields before creating operational records."
    case .readyToLink:
      return "Detected order signals look usable; create or link local order context."
    case .readyToProcess:
      return "Linked or high-confidence records that are ready for the next local action."
    case .parserChecks:
      return "Optional diagnostics for parser tuning and follow-up tasks."
    }
  }

  var symbol: String {
    switch self {
    case .needsCorrection:
      return "exclamationmark.triangle.fill"
    case .readyToLink:
      return "link.circle.fill"
    case .readyToProcess:
      return "checkmark.seal.fill"
    case .parserChecks:
      return "text.magnifyingglass"
    }
  }

  var color: Color {
    switch self {
    case .needsCorrection:
      return .orange
    case .readyToLink:
      return .blue
    case .readyToProcess:
      return .green
    case .parserChecks:
      return .purple
    }
  }
}

private struct InboxTriageGroupBucket: Identifiable {
  var group: InboxTriageGroup
  var items: [InboxTriageItem]

  var id: String { group.rawValue }
}

private struct InboxTriageGroupSection: View {
  var bucket: InboxTriageGroupBucket
  var store: ParcelOpsStore

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label(bucket.group.rawValue, systemImage: bucket.group.symbol)
          .font(.headline)
          .foregroundStyle(bucket.group.color)
        Badge("\(bucket.items.count)", color: bucket.group.color)
      }

      Text(bucket.group.detail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      ForEach(bucket.items.prefix(8)) { item in
        InboxTriageRow(item: item, store: store)
      }
    }
    .padding(.top, 4)
  }
}

private enum InboxTriageGroupFilter: String, CaseIterable, Identifiable {
  case all
  case needsCorrection
  case readyToLink
  case readyToProcess
  case parserChecks

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all:
      return "All groups"
    case .needsCorrection:
      return "Needs correction"
    case .readyToLink:
      return "Ready to link"
    case .readyToProcess:
      return "Ready to process"
    case .parserChecks:
      return "Parser checks"
    }
  }

  func matches(_ item: InboxTriageItem) -> Bool {
    switch self {
    case .all:
      return true
    case .needsCorrection:
      return item.triageGroup == .needsCorrection
    case .readyToLink:
      return item.triageGroup == .readyToLink
    case .readyToProcess:
      return item.triageGroup == .readyToProcess
    case .parserChecks:
      return item.triageGroup == .parserChecks
    }
  }
}

private enum InboxTriageSourceFilter: String, CaseIterable, Identifiable {
  case all
  case mailbox
  case imports
  case acceptance
  case parser

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all:
      return "All sources"
    case .mailbox:
      return "Mailbox"
    case .imports:
      return "Imports"
    case .acceptance:
      return "Acceptance"
    case .parser:
      return "Parser"
    }
  }

  func matches(_ item: InboxTriageItem) -> Bool {
    switch (self, item.source) {
    case (.all, _):
      return true
    case (.mailbox, .email):
      return true
    case (.imports, .importQueue):
      return true
    case (.acceptance, .acceptance):
      return true
    case (.parser, .parserDiagnostic):
      return true
    default:
      return false
    }
  }
}

private enum InboxTriageQualityFilter: String, CaseIterable, Identifiable {
  case all
  case weakOrPartial
  case cleanOrLinked
  case ignored

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all:
      return "All parse states"
    case .weakOrPartial:
      return "Weak or partial"
    case .cleanOrLinked:
      return "Clean or linked"
    case .ignored:
      return "Ignored"
    }
  }

  func matches(_ item: InboxTriageItem) -> Bool {
    let label = item.parserQualityLabel.localizedLowercase
    switch self {
    case .all:
      return true
    case .weakOrPartial:
      return label.contains("weak") || label.contains("partial") || label.contains("check")
    case .cleanOrLinked:
      return label.contains("clean") || label.contains("linked")
    case .ignored:
      return label.contains("ignored")
    }
  }
}

private struct InboxTriageItem: Identifiable {
  var id: String
  var source: InboxTriageSource
  var triageGroup: InboxTriageGroup
  var sourceLabel: String
  var title: String
  var subtitle: String
  var detail: String
  var capturedDate: String
  var confidenceScore: Int?
  var reviewLabel: String
  var linkedOrderID: UUID?
  var linkedShipmentGroupID: UUID?
  var nextAction: String
  var parserQualityLabel: String
  var parserQualityDetail: String
  var parserQualityTone: InboxTriageTone
  var readinessLabel: String
  var readinessDetail: String
  var readinessTone: InboxTriageTone
  var sortPriority: Int

  static func email(_ email: ForwardedEmailIntake) -> InboxTriageItem {
    let readiness = emailReadiness(email)
    let missingFields = missingDetectedFields(
      merchant: email.detectedMerchant,
      order: email.detectedOrderNumber,
      tracking: email.detectedTrackingNumber,
      destination: email.detectedDestinationAddress
    )
    let missingCriticalFields = missingFields.contains("order number") || missingFields.contains("tracking number")
    return InboxTriageItem(
      id: "email-\(email.id.uuidString)",
      source: .email(email),
      triageGroup: email.triageGroup,
      sourceLabel: "Mailbox",
      title: "\(email.detectedMerchant) • \(email.detectedOrderNumber)",
      subtitle: email.subject,
      detail: "Tracking \(email.detectedTrackingNumber) • \(email.detectedDestinationAddress)",
      capturedDate: email.receivedDate,
      confidenceScore: email.localInboxConfidence,
      reviewLabel: email.reviewState.rawValue,
      linkedOrderID: email.linkedOrderID,
      linkedShipmentGroupID: nil,
      nextAction: email.linkedOrderID != nil
        ? "Review linked order context"
        : missingCriticalFields
          ? "Reprocess or edit before order creation"
          : "Create or link order",
      parserQualityLabel: email.parserQualityLabel,
      parserQualityDetail: email.parserQualityDetail,
      parserQualityTone: email.parserQualityTone,
      readinessLabel: readiness.label,
      readinessDetail: readiness.detail,
      readinessTone: readiness.tone,
      sortPriority: missingCriticalFields ? 88 : email.reviewState == .needsReview ? 80 : 35
    )
  }

  static func importQueue(_ item: ImportQueueItem) -> InboxTriageItem {
    let readiness = importReadiness(item)
    return InboxTriageItem(
      id: "import-\(item.id.uuidString)",
      source: .importQueue(item),
      triageGroup: item.importStatus == .blocked || item.confidenceScore < 70 ? .needsCorrection : item.suggestedLinkedOrderID == nil ? .readyToLink : .readyToProcess,
      sourceLabel: "Import",
      title: "\(item.detectedMerchant) • \(item.detectedOrderNumber)",
      subtitle: item.sourceLabel,
      detail: "Tracking \(item.detectedTrackingNumber) • \(item.detectedDestinationAddress)",
      capturedDate: item.capturedDate,
      confidenceScore: item.confidenceScore,
      reviewLabel: item.importStatus.rawValue,
      linkedOrderID: item.suggestedLinkedOrderID,
      linkedShipmentGroupID: item.suggestedShipmentGroupID,
      nextAction: item.importStatus == .blocked ? "Resolve blocked import" : item.confidenceScore < 70 ? "Check low-confidence fields" : "Accept or link import",
      parserQualityLabel: item.confidenceScore < 70 ? "Check fields" : "Clean import",
      parserQualityDetail: item.confidenceScore < 70 ? "Import confidence is below 70%; compare detected order, tracking, and destination before accepting." : "Import confidence is high enough for normal acceptance review.",
      parserQualityTone: item.confidenceScore < 70 ? .attention : .success,
      readinessLabel: readiness.label,
      readinessDetail: readiness.detail,
      readinessTone: readiness.tone,
      sortPriority: item.importStatus == .blocked ? 95 : item.confidenceScore < 70 ? 85 : 65
    )
  }

  static func acceptance(_ candidate: AcceptanceCandidate) -> InboxTriageItem {
    let readiness = acceptanceReadiness(candidate)
    return InboxTriageItem(
      id: "acceptance-\(candidate.id)",
      source: .acceptance(candidate),
      triageGroup: candidate.decision == .blocked || candidate.confidenceScore < 70 ? .needsCorrection : candidate.suggestedLinkedOrderID == nil ? .readyToLink : .readyToProcess,
      sourceLabel: "Acceptance",
      title: "\(candidate.detectedMerchant) • \(candidate.detectedOrderNumber)",
      subtitle: candidate.sourceLabel,
      detail: "Tracking \(candidate.detectedTrackingNumber) • \(candidate.detectedDestinationAddress)",
      capturedDate: candidate.capturedDate,
      confidenceScore: candidate.confidenceScore,
      reviewLabel: candidate.decision.rawValue,
      linkedOrderID: candidate.suggestedLinkedOrderID,
      linkedShipmentGroupID: candidate.suggestedShipmentGroupID,
      nextAction: candidate.suggestedLinkedOrderID == nil ? "Choose order or create one" : "Accept into operations",
      parserQualityLabel: candidate.confidenceScore < 70 ? "Check fields" : "Clean candidate",
      parserQualityDetail: candidate.confidenceScore < 70 ? "Acceptance confidence is below 70%; compare detected fields before accepting." : "Acceptance candidate has usable detected fields for the next decision.",
      parserQualityTone: candidate.confidenceScore < 70 ? .attention : .success,
      readinessLabel: readiness.label,
      readinessDetail: readiness.detail,
      readinessTone: readiness.tone,
      sortPriority: candidate.decision == .blocked ? 100 : candidate.reviewState == .needsReview ? 90 : 70
    )
  }

  static func parserDiagnostic(_ diagnostic: IntakeParserDiagnostic) -> InboxTriageItem {
    let readiness = parserReadiness(diagnostic)
    return InboxTriageItem(
      id: "parser-\(diagnostic.id)",
      source: .parserDiagnostic(diagnostic),
      triageGroup: diagnostic.severity == .critical || diagnostic.severity == .high ? .needsCorrection : .parserChecks,
      sourceLabel: "Parser",
      title: diagnostic.title,
      subtitle: diagnostic.subjectPreview,
      detail: diagnostic.summary,
      capturedDate: diagnostic.capturedDate,
      confidenceScore: nil,
      reviewLabel: diagnostic.severity.rawValue,
      linkedOrderID: nil,
      linkedShipmentGroupID: nil,
      nextAction: diagnostic.recommendedAction,
      parserQualityLabel: diagnostic.severity.rawValue,
      parserQualityDetail: diagnostic.summary,
      parserQualityTone: readiness.tone,
      readinessLabel: readiness.label,
      readinessDetail: readiness.detail,
      readinessTone: readiness.tone,
      sortPriority: diagnostic.severity == .critical ? 98 : diagnostic.severity == .high ? 92 : 72
    )
  }

  static func sourceKey(sourceType: AcceptanceSourceType, sourceID: UUID) -> String {
    "\(sourceType.rawValue)-\(sourceID.uuidString)"
  }

  private static func emailReadiness(_ email: ForwardedEmailIntake) -> (label: String, detail: String, tone: InboxTriageTone) {
    if email.reviewState == .ignored {
      return ("Ignored locally", "This email is not active unless reopened from the detailed mailbox view.", .muted)
    }

    let missingFields = missingDetectedFields(
      merchant: email.detectedMerchant,
      order: email.detectedOrderNumber,
      tracking: email.detectedTrackingNumber,
      destination: email.detectedDestinationAddress
    )
    if !missingFields.isEmpty {
      return ("Needs correction", "Check \(missingFields.joined(separator: ", ")) before creating or linking an order.", .warning)
    }
    if email.linkedOrderID == nil {
      return ("Ready to link", "Detected order details look usable; link to an existing order or create a new one.", .attention)
    }
    return ("Ready to review", "Linked order context exists; review once and move it forward.", .success)
  }

  private static func importReadiness(_ item: ImportQueueItem) -> (label: String, detail: String, tone: InboxTriageTone) {
    if item.importStatus == .blocked {
      return ("Blocked", "Resolve the blocked import before accepting it into operations.", .warning)
    }
    if item.confidenceScore < 70 {
      return ("Low confidence", "Check detected fields before accepting this staged import.", .attention)
    }
    if item.suggestedLinkedOrderID == nil {
      return ("Ready to link", "Choose an existing order or create a new local order from this import.", .attention)
    }
    return ("Ready to accept", "Suggested order context exists; accept when the fields look right.", .success)
  }

  private static func acceptanceReadiness(_ candidate: AcceptanceCandidate) -> (label: String, detail: String, tone: InboxTriageTone) {
    if candidate.decision == .blocked {
      return ("Blocked", "Resolve the acceptance blocker before moving this record forward.", .warning)
    }
    if candidate.confidenceScore < 70 {
      return ("Check fields", "Compare detected fields before accepting this source record.", .attention)
    }
    if candidate.suggestedLinkedOrderID == nil {
      return ("Choose order", "Select an existing order or create one during acceptance.", .attention)
    }
    return ("Ready to accept", "Linked order context is present; accept when the comparison looks right.", .success)
  }

  private static func parserReadiness(_ diagnostic: IntakeParserDiagnostic) -> (label: String, detail: String, tone: InboxTriageTone) {
    let hints = (diagnostic.issueLabels + diagnostic.parserHintLabels + diagnostic.nextStepLabels)
      .prefix(3)
      .joined(separator: ", ")
    let detail = hints.isEmpty ? diagnostic.summary : hints
    return ("Parser check", detail, diagnostic.severity == .critical || diagnostic.severity == .high ? .warning : .attention)
  }

  private static func missingDetectedFields(merchant: String, order: String, tracking: String, destination: String) -> [String] {
    [
      merchant.isPlaceholderValidationValue ? "merchant" : nil,
      order.isPlaceholderValidationValue ? "order number" : nil,
      tracking.isPlaceholderValidationValue ? "tracking number" : nil,
      destination.isPlaceholderValidationValue ? "destination" : nil
    ].compactMap { $0 }
  }
}

private enum InboxTriageTone {
  case success
  case attention
  case warning
  case muted

  var color: Color {
    switch self {
    case .success:
      return .green
    case .attention:
      return .orange
    case .warning:
      return .red
    case .muted:
      return .secondary
    }
  }
}

private enum InboxTriageSource {
  case email(ForwardedEmailIntake)
  case importQueue(ImportQueueItem)
  case acceptance(AcceptanceCandidate)
  case parserDiagnostic(IntakeParserDiagnostic)

  var symbol: String {
    switch self {
    case .email: "envelope.open.fill"
    case .importQueue: "tray.and.arrow.down.fill"
    case .acceptance: "checkmark.rectangle.stack.fill"
    case .parserDiagnostic: "text.magnifyingglass"
    }
  }

  var color: Color {
    switch self {
    case .email(let email):
      email.reviewState.color
    case .importQueue(let item):
      item.importStatus.color
    case .acceptance(let candidate):
      candidate.decision.color
    case .parserDiagnostic(let diagnostic):
      diagnostic.severity.color
    }
  }
}

private struct InboxTriageRow: View {
  var item: InboxTriageItem
  var store: ParcelOpsStore
  @State private var feedbackMessage: String?

  private var linkedOrderLabel: String? {
    item.linkedOrderID.flatMap { store.orderLabel(for: $0) }
  }

  private var linkedOrder: TrackedOrder? {
    item.linkedOrderID.flatMap { orderID in
      store.orders.first { $0.id == orderID }
    }
  }

  private var linkedShipmentGroupLabel: String? {
    item.linkedShipmentGroupID.flatMap { store.shipmentGroupLabel(for: $0) }
  }

  private var intakeSourceSummary: (label: String, detail: String, tone: String, status: String, captured: String)? {
    if case .email(let email) = item.source {
      return store.intakeSourceSummary(for: email)
    }
    return nil
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: item.source.symbol)
          .foregroundStyle(item.source.color)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: 5) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
              Text(item.title)
                .font(.headline)
              Text(item.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer(minLength: 8)
            Badge(intakeSourceSummary?.label ?? item.sourceLabel, color: intakeSourceColor)
          }

          Text(item.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)

          if case .email(let email) = item.source {
            IntakeSourceContextPanel(
              email: email,
              store: store,
              manualDetail: "No mailbox ingest record is linked to this intake row. Treat it as local/manual until a source record is linked.",
              linkedDetailSuffix: "Duplicate-safe source metadata is present; provider message IDs are not shown in the primary queue.",
              compact: true
            )
          }

          CompactMetadataGrid {
            if let confidenceScore = item.confidenceScore {
              Badge("\(confidenceScore)% confidence", color: confidenceColor(confidenceScore))
            }
            Badge(item.parserQualityLabel, color: item.parserQualityTone.color)
            Badge(item.reviewLabel, color: item.source.color)
            Badge(item.readinessLabel, color: item.readinessTone.color)
            if let intakeSourceSummary {
              Badge(intakeSourceSummary.status, color: intakeSourceSummary.status == MailboxIngestStatus.imported.rawValue ? .green : .orange)
            }
            if let linkedOrderLabel {
              Label(linkedOrderLabel, systemImage: "shippingbox.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            if let linkedShipmentGroupLabel {
              Label(linkedShipmentGroupLabel, systemImage: "shippingbox.and.arrow.backward.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          Text(item.readinessDetail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          Label(item.parserQualityDetail, systemImage: "text.magnifyingglass")
            .font(.caption2)
            .foregroundStyle(item.parserQualityTone.color)
            .fixedSize(horizontal: false, vertical: true)

          if let intakeSourceSummary {
            Label(intakeSourceSummary.detail, systemImage: "server.rack")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          if case .email(let email) = item.source {
            IntakeReadinessStrip(email: email, hasLinkedOrder: linkedOrder != nil)
          }

          if case .parserDiagnostic = item.source {
            EmptyView()
          } else {
            LinkedOrderContextPanel(
              order: linkedOrder,
              sourceLabel: item.sourceLabel,
              emptyDetail: "No order is linked yet. Open the detailed view to link known work, or create a new local order from this queue when the intake details are ready.",
              linkedDetail: "This queue item already has linked order context. Open the order before completing the intake action if tracking, destination, or dispatch setup still needs confirmation.",
              store: store
            )
          }

          Label(item.nextAction, systemImage: "arrow.forward.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(item.readinessTone.color)
        }
      }

      inboxOperatorDecisionPanel

      CompactActionRow {
        NavigationLink {
          detailDestination
        } label: {
          Label("Open intake record", systemImage: "arrow.up.right.square.fill")
        }
        .buttonStyle(.bordered)

        switch item.source {
        case .email(let email):
          let missingCriticalFields = email.detectedOrderNumber.isPlaceholderValidationValue || email.detectedTrackingNumber.isPlaceholderValidationValue
          if missingCriticalFields {
            Button("Create partial order", systemImage: "plus.circle.fill") {
              store.createOrder(from: email)
              feedbackMessage = "Partial order created and linked locally. Check Orders."
            }
            .buttonStyle(.bordered)
            .disabled(email.linkedOrderID != nil)
          } else {
            Button("Create order", systemImage: "plus.circle.fill") {
              store.createOrder(from: email)
              feedbackMessage = "Order created and linked locally. Check Orders."
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.linkedOrderID != nil)
          }
          Button("Mark reviewed", systemImage: "checkmark.circle.fill") {
            store.markIntakeEmailReviewed(email)
            feedbackMessage = "Email marked reviewed locally."
          }
          .buttonStyle(.bordered)
          Button("Ignore", systemImage: "eye.slash.fill") {
            store.ignoreIntakeEmail(email)
            feedbackMessage = "Email ignored locally."
          }
          .buttonStyle(.bordered)
          Button("Reprocess", systemImage: "arrow.triangle.2.circlepath") {
            store.reprocessIntakeEmail(email)
            feedbackMessage = "Email reprocessed from stored preview."
          }
          .buttonStyle(.bordered)
          Button("Create task", systemImage: "checklist") {
            store.createReviewTask(from: email)
            feedbackMessage = "Follow-up task created. Check Tasks."
          }
          .buttonStyle(.bordered)
          Button("Create draft", systemImage: "envelope.open.fill") {
            store.createDraftMessage(from: email)
            feedbackMessage = "Draft message created locally."
          }
          .buttonStyle(.bordered)

        case .importQueue(let importItem):
          Button("Create order", systemImage: "plus.circle.fill") {
            store.createOrder(from: importItem)
            feedbackMessage = "Order created from import. Check Orders."
          }
          .buttonStyle(.borderedProminent)
          .disabled(importItem.suggestedLinkedOrderID != nil)
          Button("Accept import", systemImage: "checkmark.seal.fill") {
            store.markImportQueueItemAccepted(importItem)
            feedbackMessage = "Import accepted locally."
          }
          .buttonStyle(.borderedProminent)
          Button("Ignore", systemImage: "eye.slash.fill") {
            store.ignoreImportQueueItem(importItem)
            feedbackMessage = "Import ignored locally."
          }
          .buttonStyle(.bordered)
          Button("Reopen", systemImage: "arrow.uturn.backward.circle.fill") {
            store.reopenImportQueueItem(importItem)
            feedbackMessage = "Import reopened for review."
          }
          .buttonStyle(.bordered)
          Button("Create task", systemImage: "checklist") {
            store.createReviewTask(from: importItem)
            feedbackMessage = "Follow-up task created. Check Tasks."
          }
          .buttonStyle(.bordered)
          Button("Create draft", systemImage: "square.and.pencil") {
            store.createDraftMessage(from: importItem)
            feedbackMessage = "Draft message created locally."
          }
          .buttonStyle(.bordered)

        case .acceptance(let candidate):
          Button("Create order", systemImage: "plus.circle.fill") {
            store.createOrder(from: candidate)
            feedbackMessage = "Order created from acceptance. Check Orders."
          }
          .buttonStyle(.borderedProminent)
          .disabled(candidate.suggestedLinkedOrderID != nil)
          Button("Accept record", systemImage: "checkmark.circle.fill") {
            store.acceptCandidate(candidate)
            feedbackMessage = "Acceptance record accepted locally."
          }
          .buttonStyle(.borderedProminent)
          Button("Ignore", systemImage: "eye.slash.fill") {
            store.ignoreCandidate(candidate)
            feedbackMessage = "Acceptance record ignored locally."
          }
          .buttonStyle(.bordered)
          Button("Reopen", systemImage: "arrow.counterclockwise") {
            store.reopenCandidate(candidate)
            feedbackMessage = "Acceptance record reopened for review."
          }
          .buttonStyle(.bordered)
          Button("Create task", systemImage: "checklist") {
            store.createReviewTask(from: candidate)
            feedbackMessage = "Follow-up task created. Check Tasks."
          }
          .buttonStyle(.bordered)
          Button("Create draft", systemImage: "envelope.open.fill") {
            store.createDraftMessage(from: candidate)
            feedbackMessage = "Draft message created locally."
          }
          .buttonStyle(.bordered)

        case .parserDiagnostic(let diagnostic):
          Button("Reprocess", systemImage: "arrow.triangle.2.circlepath") {
            if let email = store.intakeEmails.first(where: { $0.id == diagnostic.intakeEmailID }) {
              store.reprocessIntakeEmail(email)
              feedbackMessage = "Email reprocessed from stored preview."
            }
          }
          .buttonStyle(.borderedProminent)
          Button("Create task", systemImage: "checklist") {
            if let email = store.intakeEmails.first(where: { $0.id == diagnostic.intakeEmailID }) {
              store.createReviewTask(from: email)
              feedbackMessage = "Parser follow-up task created. Check Tasks."
            }
          }
          .buttonStyle(.bordered)
        }
      }

      if let feedbackMessage {
        VStack(alignment: .leading, spacing: 8) {
          Label(feedbackMessage, systemImage: "checkmark.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)

          if feedbackMessage.localizedCaseInsensitiveContains("order") {
            NavigationLink {
              OrdersView(store: store)
            } label: {
              Label("Open Orders", systemImage: "shippingbox.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
          }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.green.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }

  @ViewBuilder
  private var detailDestination: some View {
    switch item.source {
    case .email:
      MailboxView(store: store)
    case .importQueue:
      ImportQueueView(store: store)
    case .acceptance:
      AcceptanceReviewView(store: store)
    case .parserDiagnostic:
      MailboxView(store: store)
    }
  }

  private func confidenceColor(_ score: Int) -> Color {
    if score < 50 {
      return .red
    }
    if score < 75 {
      return .orange
    }
    return .green
  }

  private var intakeSourceColor: Color {
    guard let tone = intakeSourceSummary?.tone else { return item.source.color }
    switch tone {
    case "spacemail":
      return .teal
    case "gmail":
      return .blue
    case "mock":
      return .purple
    case "microsoft", "mailbox":
      return .blue
    default:
      return .secondary
    }
  }

  private var inboxOperatorDecisionPanel: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: operatorDecisionSymbol)
        .foregroundStyle(operatorDecisionColor)
        .frame(width: 22)

      VStack(alignment: .leading, spacing: 4) {
        Text(operatorDecisionTitle)
          .font(.caption.weight(.semibold))
        Text(operatorDecisionDetail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 8)
      Badge(operatorDecisionBadge, color: operatorDecisionColor)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(operatorDecisionColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private var operatorDecisionTitle: String {
    switch item.source {
    case .email(let email):
      if email.linkedOrderID != nil { return "Linked order exists" }
      if email.detectedOrderNumber.isPlaceholderValidationValue || email.detectedTrackingNumber.isPlaceholderValidationValue {
        return "Confirm details before order creation"
      }
      return "Ready to create or link order"
    case .importQueue(let importItem):
      if importItem.importStatus == .blocked { return "Resolve blocked import first" }
      if importItem.suggestedLinkedOrderID != nil { return "Suggested order context exists" }
      return "Ready for import decision"
    case .acceptance(let candidate):
      if candidate.decision == .blocked { return "Resolve acceptance blocker first" }
      if candidate.suggestedLinkedOrderID != nil { return "Ready to accept into operations" }
      return "Choose or create the order"
    case .parserDiagnostic:
      return "Parser diagnostic only"
    }
  }

  private var operatorDecisionDetail: String {
    switch item.source {
    case .email(let email):
      if email.linkedOrderID != nil {
        return "Open the linked order, verify dispatch and tracking context, then mark the intake reviewed when the source trail is clear."
      }
      let missing = [
        email.detectedMerchant.isPlaceholderValidationValue ? "merchant" : nil,
        email.detectedOrderNumber.isPlaceholderValidationValue ? "order number" : nil,
        email.detectedTrackingNumber.isPlaceholderValidationValue ? "tracking number" : nil,
        email.detectedDestinationAddress.isPlaceholderValidationValue ? "destination" : nil
      ].compactMap { $0 }
      if !missing.isEmpty {
        return "Missing or weak: \(missing.joined(separator: ", ")). Use Reprocess/Edit in the detailed mailbox view, or create a partial order only when that is useful."
      }
      return "Detected fields look usable. Create a local order from this row or open the detailed intake record to link it to an existing order."
    case .importQueue(let importItem):
      if importItem.importStatus == .blocked {
        return "Open Import Queue, correct the blocker, then accept or ignore the staged record."
      }
      if importItem.confidenceScore < 70 {
        return "Confidence is below 70%. Check merchant, order, tracking, and destination before accepting."
      }
      return "Accept the import when fields look right, or create/link an order if the suggested context is missing."
    case .acceptance(let candidate):
      if candidate.decision == .blocked {
        return "Open Acceptance Review and resolve the blocker before accepting this source record."
      }
      if candidate.suggestedLinkedOrderID == nil {
        return "Create a new local order or link an existing one before accepting the source record."
      }
      return "The source record has linked order context. Accept it when the comparison looks correct."
    case .parserDiagnostic:
      return "This row does not represent a new email. Reprocess the stored preview or create a task for parser follow-up."
    }
  }

  private var operatorDecisionBadge: String {
    switch item.source {
    case .email(let email):
      if email.linkedOrderID != nil { return "Verify" }
      if email.detectedOrderNumber.isPlaceholderValidationValue || email.detectedTrackingNumber.isPlaceholderValidationValue { return "Check" }
      return "Ready"
    case .importQueue(let importItem):
      return importItem.importStatus == .blocked ? "Blocked" : "Decide"
    case .acceptance(let candidate):
      return candidate.decision == .blocked ? "Blocked" : "Accept"
    case .parserDiagnostic:
      return "Diagnostic"
    }
  }

  private var operatorDecisionColor: Color {
    switch item.source {
    case .email(let email):
      if email.linkedOrderID != nil { return .blue }
      if email.detectedOrderNumber.isPlaceholderValidationValue || email.detectedTrackingNumber.isPlaceholderValidationValue { return .orange }
      return .green
    case .importQueue(let importItem):
      return importItem.importStatus == .blocked ? .red : .teal
    case .acceptance(let candidate):
      return candidate.decision == .blocked ? .red : .green
    case .parserDiagnostic:
      return .orange
    }
  }

  private var operatorDecisionSymbol: String {
    switch item.source {
    case .email(let email):
      if email.linkedOrderID != nil { return "link.circle.fill" }
      if email.detectedOrderNumber.isPlaceholderValidationValue || email.detectedTrackingNumber.isPlaceholderValidationValue { return "exclamationmark.triangle.fill" }
      return "checkmark.circle.fill"
    case .importQueue(let importItem):
      return importItem.importStatus == .blocked ? "xmark.octagon.fill" : "tray.and.arrow.down.fill"
    case .acceptance(let candidate):
      return candidate.decision == .blocked ? "xmark.octagon.fill" : "checkmark.seal.fill"
    case .parserDiagnostic:
      return "text.magnifyingglass"
    }
  }
}

private extension ForwardedEmailIntake {
  var localInboxConfidence: Int {
    var score = 90
    if detectedMerchant.isPlaceholderValidationValue { score -= 18 }
    if detectedOrderNumber.isPlaceholderValidationValue { score -= 18 }
    if detectedTrackingNumber.isPlaceholderValidationValue { score -= 12 }
    if detectedDestinationAddress.isPlaceholderValidationValue { score -= 16 }
    if linkedOrderID == nil { score -= 8 }
    if reviewState == .needsReview { score -= 6 }
    return max(10, min(100, score))
  }

  var triageGroup: InboxTriageGroup {
    if reviewState == .ignored {
      return .parserChecks
    }
    if hasCriticalParserGaps || localInboxConfidence < 65 {
      return .needsCorrection
    }
    if linkedOrderID == nil {
      return .readyToLink
    }
    return .readyToProcess
  }

  var parserQualityLabel: String {
    if reviewState == .ignored {
      return "Ignored parse"
    }
    if hasCriticalParserGaps {
      return "Weak parse"
    }
    if !missingParserFields.isEmpty {
      return "Partial parse"
    }
    if linkedOrderID != nil {
      return "Linked parse"
    }
    return "Clean parse"
  }

  var parserQualityDetail: String {
    if reviewState == .ignored {
      return "Ignored emails stay out of normal intake work unless reopened from the detailed mailbox view."
    }
    if hasCriticalParserGaps {
      return "Parser is missing \(criticalParserGaps.joined(separator: " and ")); reprocess or edit before creating an order."
    }
    if !missingParserFields.isEmpty {
      return "Parser found order evidence but still needs \(missingParserFields.joined(separator: ", ")) checked before final review."
    }
    if linkedOrderID != nil {
      return "Detected intake fields are linked to an order; review the handoff context before closing the row."
    }
    return "Merchant, order, tracking, and destination fields look usable for create or link actions."
  }

  var parserQualityTone: InboxTriageTone {
    if reviewState == .ignored {
      return .muted
    }
    if hasCriticalParserGaps {
      return .warning
    }
    if !missingParserFields.isEmpty {
      return .attention
    }
    return .success
  }

  var hasCriticalParserGaps: Bool {
    !criticalParserGaps.isEmpty
  }

  private var criticalParserGaps: [String] {
    [
      detectedOrderNumber.isPlaceholderValidationValue ? "order number" : nil,
      detectedTrackingNumber.isPlaceholderValidationValue ? "tracking number" : nil
    ].compactMap { $0 }
  }

  private var missingParserFields: [String] {
    [
      detectedMerchant.isPlaceholderValidationValue ? "merchant" : nil,
      detectedOrderNumber.isPlaceholderValidationValue ? "order number" : nil,
      detectedTrackingNumber.isPlaceholderValidationValue ? "tracking number" : nil,
      detectedDestinationAddress.isPlaceholderValidationValue ? "destination" : nil
    ].compactMap { $0 }
  }
}

struct DispatchView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var dispatchSearchText = ""
  @State private var showDispatchProviderEvidence = false
  @State private var showDispatchContextSections = false

  private var isCompact: Bool { horizontalSizeClass == .compact }
  private var dispatchItems: [DispatchQueueItem] {
    let manifestItems = uniqueManifests(
      store.blockedShipmentManifests
        + store.highRiskShipmentManifests
        + store.undispatchedShipmentManifests
        + store.shipmentManifestsNeedingReview
        + store.shipmentManifestsMissingIncludedOrders
        + store.shipmentManifestsMissingHandoffLocation
        + store.shipmentManifestsWithIncompleteScans
    ).map(DispatchQueueItem.manifest)

    let checklistItems = uniqueChecklists(
      store.blockedDispatchChecklists
        + store.highRiskDispatchChecklists
        + store.incompleteDispatchChecklists
        + store.dispatchChecklistsNeedingReview
        + store.dispatchChecklistsMissingRequirements
        + store.dispatchChecklistsLinkedToBlockedManifests
    ).map(DispatchQueueItem.checklist)

    return (manifestItems + checklistItems)
      .sorted { lhs, rhs in
        if lhs.sortPriority == rhs.sortPriority {
          return lhs.plannedDate > rhs.plannedDate
        }
        return lhs.sortPriority > rhs.sortPriority
      }
  }

  private var visibleDispatchItems: [DispatchQueueItem] {
    let query = dispatchSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return dispatchItems }
    return dispatchItems.filter { item in
      [
        item.title,
        item.subtitle,
        item.detail,
        item.plannedDate,
        item.statusLabel,
        item.sourceLabel,
        item.nextAction
      ].joined(separator: " ").localizedLowercase.contains(query)
    }
  }

  private var visibleInboxDispatchSetupOrders: [TrackedOrder] {
    let query = dispatchSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return inboxDispatchSetupOrders }
    return inboxDispatchSetupOrders.filter { order in
      [
        order.orderNumber,
        order.store,
        order.customer,
        order.destination,
        order.carrier,
        order.trackingNumber,
        order.status.rawValue,
        order.reviewState.rawValue,
        order.latestStatus
      ].joined(separator: " ").localizedLowercase.contains(query)
    }
  }

  private var hasActiveDispatchFilters: Bool {
    !dispatchSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var shouldShowDispatchContextSections: Bool {
    showDispatchContextSections || hasActiveDispatchFilters
  }

  private var inboxDispatchSetupOrders: [TrackedOrder] {
    Array(
      store.orders
        .filter { order in
          guard order.isInboxCreatedLocalOrder || orderHasWishlistSource(order) else { return false }
          return orderNeedsPreDispatchVerification(order) || orderNeedsDispatchSetup(order)
        }
        .sorted { first, second in
          let firstPriority = dispatchSetupPriority(for: first)
          let secondPriority = dispatchSetupPriority(for: second)
          if firstPriority == secondPriority {
            return first.orderNumber.localizedCaseInsensitiveCompare(second.orderNumber) == .orderedAscending
          }
          return firstPriority > secondPriority
        }
        .prefix(5)
    )
  }

  private var partialInboxDispatchBlockerCount: Int {
    store.orders.filter { order in
      (order.isInboxCreatedLocalOrder || orderHasWishlistSource(order)) && orderNeedsPreDispatchVerification(order)
    }.count
  }

  private var wishlistDispatchSetupOrderCount: Int {
    inboxDispatchSetupOrders.filter(orderHasWishlistSource).count
  }

  private var wishlistDispatchHandoffSanityGapCount: Int {
    inboxDispatchSetupOrders.reduce(0) { total, order in
      total + store.wishlistHandoffSanityIssueCount(for: order)
    }
  }

  private var blockedDispatchCount: Int {
    store.blockedDispatchWorkCount
  }

  private var readyDispatchCount: Int {
    store.readyDispatchWorkCount
  }

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.latestSpaceMailIntakeHealthSummary
  }

  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.latestGmailIntakeHealthSummary
  }

  private var dispatchGmailConnection: GmailMailboxConnection? {
    guard let summary = latestGmailSummary else { return store.gmailMailboxConnections.first }
    return store.gmailMailboxConnections.first { $0.id == summary.connectionID }
  }

  private var dispatchGmailReadiness: GmailOAuthReadinessSummary? {
    dispatchGmailConnection.map { store.gmailOAuthReadinessSummary(for: $0) }
  }

  private var dispatchGmailCompileBlockers: [String] {
    guard let readiness = dispatchGmailReadiness else { return [] }
    return readiness.missingFields.filter { field in
      field.localizedCaseInsensitiveContains("compiled App Info.plist")
        || field.localizedCaseInsensitiveContains("callback URL scheme matching")
        || field.localizedCaseInsensitiveContains("OAuth iOS client ID ending")
    }
  }

  private var dispatchGmailCompileColor: Color {
    guard let readiness = dispatchGmailReadiness else { return .secondary }
    return readiness.isReady ? .green : .orange
  }

  private var dispatchGmailCompileTitle: String {
    guard let readiness = dispatchGmailReadiness else { return "Gmail setup is optional for dispatch" }
    if readiness.isReady { return "Gmail setup can feed dispatch after Inbox" }
    if !dispatchGmailCompileBlockers.isEmpty { return "Gmail setup cannot feed dispatch yet" }
    return "Gmail setup needs review before dispatch handoff"
  }

  private var dispatchGmailCompileDetail: String {
    guard let readiness = dispatchGmailReadiness else {
      return "Dispatch starts from local orders. Add Gmail only when a Google-hosted mailbox should create or link orders through Inbox first."
    }
    if readiness.isReady {
      return "The compiled Gmail client ID and callback scheme match setup. Dispatch still waits for a Gmail message to become an Inbox-created or linked order."
    }
    if !dispatchGmailCompileBlockers.isEmpty {
      return "Before Gmail can create dispatch candidates, fix: \(dispatchGmailCompileBlockers.joined(separator: "; ")). Rebuild, then run Gmail sign-in and manual refresh from Mailbox Monitor."
    }
    return readiness.detailText
  }

  private var dispatchMailboxProviderRows: [(provider: String, status: String, detail: String, symbol: String, color: Color)] {
    var rows: [(provider: String, status: String, detail: String, symbol: String, color: Color)] = []

    if let summary = latestSpaceMailSummary {
      if summary.importedCount > 0 {
        rows.append(("SpaceMail", summary.primaryOutcomeStatus, "Imported SpaceMail rows can become dispatch work only after Inbox creates or links an order.", "server.rack", .green))
      } else if summary.totalUncertainCount > 0 {
        rows.append(("SpaceMail", summary.primaryOutcomeStatus, "Review uncertain SpaceMail previews before expecting dispatch setup for those messages.", "server.rack", .orange))
      } else if summary.filteredCount > 0 {
        rows.append(("SpaceMail", summary.primaryOutcomeStatus, "Filtered SpaceMail stayed out of Inbox, Orders, and Dispatch.", "server.rack", .teal))
      } else if summary.duplicateRefreshedCount > 0 {
        rows.append(("SpaceMail", summary.primaryOutcomeStatus, "Duplicate SpaceMail refreshed existing Inbox rows; Dispatch still waits for a linked or created order.", "server.rack", .green))
      } else if summary.duplicateCount > 0 {
        rows.append(("SpaceMail", summary.primaryOutcomeStatus, "Duplicate SpaceMail does not create new dispatch setup unless an existing order is linked.", "server.rack", .teal))
      } else {
        rows.append(("SpaceMail", summary.primaryOutcomeStatus, summary.nextAction, "server.rack", .secondary))
      }
    }

    if let summary = latestGmailSummary {
      if summary.importedCount > 0 {
        rows.append(("Gmail", summary.primaryOutcomeStatus, "Imported Gmail rows can become dispatch work only after Inbox creates or links an order.", "envelope.badge.shield.half.filled", .green))
      } else if summary.totalUncertainCount > 0 {
        rows.append(("Gmail", summary.primaryOutcomeStatus, "Review uncertain Gmail previews before expecting dispatch setup for those messages.", "envelope.badge.shield.half.filled", .orange))
      } else if summary.filteredCount > 0 {
        rows.append(("Gmail", summary.primaryOutcomeStatus, "Filtered Gmail stayed out of Inbox, Orders, and Dispatch.", "envelope.badge.shield.half.filled", .teal))
      } else if summary.duplicateRefreshedCount > 0 {
        rows.append(("Gmail", summary.primaryOutcomeStatus, "Duplicate Gmail refreshed existing Inbox rows; Dispatch still waits for a linked or created order.", "envelope.badge.shield.half.filled", .green))
      } else if summary.duplicateCount > 0 {
        rows.append(("Gmail", summary.primaryOutcomeStatus, "Duplicate Gmail does not create new dispatch setup unless an existing order is linked.", "envelope.badge.shield.half.filled", .teal))
      } else {
        rows.append(("Gmail", summary.primaryOutcomeStatus, summary.nextAction, "envelope.badge.shield.half.filled", .secondary))
      }
    }

    if !store.microsoft365MailboxConnections.isEmpty {
      let signedInCount = store.microsoft365ConnectedAuthCount
      let readyCount = store.microsoft365ReadySetupCount
      rows.append((
        "Microsoft 365",
        signedInCount > 0 ? "Signed in" : readyCount > 0 ? "Sign-in needed" : "Setup needed",
        signedInCount > 0
          ? "Outlook/Microsoft Graph can create dispatch work only after manual read-only refresh imports an Inbox row and that row becomes an order."
          : "Outlook/Microsoft remains an advanced provider path. Complete setup and sign-in before expecting Dispatch context.",
        "mail.stack.fill",
        signedInCount > 0 ? .purple : .orange
      ))
    }

    if rows.isEmpty {
      rows.append(("Mailbox", "No provider refresh", "Dispatch setup starts after Inbox creates or links an order from mailbox intake.", "envelope.badge.fill", .secondary))
    }
    return rows
  }

  private var reopenedInboxDispatchHandoffCount: Int {
    store.reopenedInboxDispatchHandoffCount
  }

  private var openDispatchCount: Int {
    dispatchItems.count + inboxDispatchSetupOrders.count
  }

  private var dispatchSummaryTone: Color {
    if blockedDispatchCount > 0 { return .red }
    if reopenedInboxDispatchHandoffCount > 0 { return .purple }
    if partialInboxDispatchBlockerCount > 0 { return .orange }
    if readyDispatchCount > 0 || openDispatchCount > 0 { return .orange }
    return .green
  }

  private var dispatchSummaryTitle: String {
    if blockedDispatchCount > 0 { return "Dispatch has blockers" }
    if reopenedInboxDispatchHandoffCount > 0 { return "Reopened Inbox handoffs need review" }
    if partialInboxDispatchBlockerCount > 0 { return "Verify source orders before dispatch" }
    if readyDispatchCount > 0 { return "Dispatch has work ready to move" }
    if !inboxDispatchSetupOrders.isEmpty { return "Source orders need dispatch setup" }
    if !dispatchItems.isEmpty { return "Dispatch queue needs review" }
    return "Dispatch flow is clear"
  }

  private var dispatchSummaryDetail: String {
    if blockedDispatchCount > 0 {
      return "Clear blocked manifests and readiness checklists before preparing new outbound work."
    }
    if reopenedInboxDispatchHandoffCount > 0 {
      return "\(reopenedInboxDispatchHandoffCount) Inbox dispatch handoff record was reopened. Open the linked order, confirm the dispatch setup, then complete or block the handoff."
    }
    if partialInboxDispatchBlockerCount > 0 {
      return "\(partialInboxDispatchBlockerCount) Inbox-created or Wishlist-linked order\(partialInboxDispatchBlockerCount == 1 ? "" : "s") \(partialInboxDispatchBlockerCount == 1 ? "has" : "have") missing intake details or an open verification task. Confirm those details before manifest or readiness setup."
    }
    if readyDispatchCount > 0 {
      return "Prepared manifests or ready checklists can move to dispatch, completion, handoff, or review."
    }
    if !inboxDispatchSetupOrders.isEmpty {
      return "Create or link manifest/readiness context for Inbox-created and Wishlist-linked orders before treating them as dispatch-ready."
    }
    if !dispatchItems.isEmpty {
      return "Work the highest-risk queue rows first, then open detailed views only when you need the full record."
    }
    return "No blocked, incomplete, or high-risk dispatch records are currently waiting in the primary queue."
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: isCompact ? 14 : 18) {
        header
        dispatchSummaryPanel
        dispatchContextSectionsPanel
        dispatchQueuePanel
        if shouldShowDispatchContextSections {
          dispatchSupportingContextSections
        }
        detailRoutes
      }
      .padding(isCompact ? 14 : 24)
    }
    .background(.regularMaterial)
  }

  private var dispatchContextSectionsPanel: some View {
    SettingsPanel(title: "Dispatch context sections", symbol: "line.3.horizontal.decrease.circle.fill") {
      Text(shouldShowDispatchContextSections ? "Provider status, readiness ladder, and Inbox-created order dispatch setup are visible." : "Dispatch opens with the outbound queue first. Open context sections when you need provider status, readiness rules, or Inbox-created order setup guidance.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      MetricStrip(items: [
        ("Queue", "\(dispatchItems.count)", dispatchItems.isEmpty ? .green : .orange),
        ("Visible", "\(visibleDispatchItems.count)", visibleDispatchItems.isEmpty ? .secondary : .blue),
        ("Blocked", "\(blockedDispatchCount)", blockedDispatchCount == 0 ? .green : .red),
        ("Ready", "\(readyDispatchCount)", readyDispatchCount == 0 ? .secondary : .green),
        ("Setup", "\(inboxDispatchSetupOrders.count)", inboxDispatchSetupOrders.isEmpty ? .green : .teal)
      ])

      CompactActionRow {
        Button(shouldShowDispatchContextSections ? "Hide context sections" : "Show context sections", systemImage: shouldShowDispatchContextSections ? "chevron.up.circle" : "chevron.down.circle") {
          showDispatchContextSections.toggle()
        }
        .buttonStyle(.bordered)

        if hasActiveDispatchFilters && !showDispatchContextSections {
          Badge("Search active", color: .orange)
        }
      }
    }
  }

  @ViewBuilder
  private var dispatchSupportingContextSections: some View {
    MailboxProviderQuickStatusCard(summary: store.mailboxProviderComparisonSummary, store: store)
    dispatchProviderEvidencePanel
    dispatchReadinessLadderPanel
    inboxDispatchSetupPanel
  }

  private var dispatchReadinessItems: [(title: String, detail: String, count: Int, destination: String, symbol: String, color: Color)] {
    let verifyFirstCount = partialInboxDispatchBlockerCount
    let setupMissingCount = inboxDispatchSetupOrders.filter(orderNeedsDispatchSetup).count
    let blockedCount = blockedDispatchCount
    let readyToMoveCount = readyDispatchCount
    let incompleteChecklistCount = store.incompleteDispatchChecklists.count
    let handoffReviewCount = reopenedInboxDispatchHandoffCount
      + store.shipmentManifestRecords.filter { $0.dispatchStatus == .dispatched && $0.reviewState != .accepted }.count
      + store.dispatchReadinessChecklists.filter { $0.checklistStatus == .completed && $0.reviewState != .accepted }.count

    return [
      (
        "Verify first",
        "Inbox-created or Wishlist-linked orders with missing intake details or open verification tasks should not move to manifest/readiness setup yet.",
        verifyFirstCount,
        "Orders",
        "checkmark.shield.fill",
        verifyFirstCount == 0 ? .green : .orange
      ),
      (
        "Create setup",
        "Inbox-created or Wishlist-linked shipped, in-transit, or exception orders need manifest or readiness context before dispatch is ready.",
        setupMissingCount,
        "Dispatch setup",
        "tray.and.arrow.down.fill",
        setupMissingCount == 0 ? .green : .teal
      ),
      (
        "Resolve blockers",
        "Blocked manifests and readiness checklists should be fixed or assigned before routine outbound work.",
        blockedCount,
        "Manifests or Readiness",
        "exclamationmark.triangle.fill",
        blockedCount == 0 ? .green : .red
      ),
      (
        "Complete checks",
        "Draft, reopened, or incomplete readiness checklists need labels, scans, custody, requirements, or handoff confirmation.",
        incompleteChecklistCount,
        "Dispatch Readiness",
        "checkmark.rectangle.stack.fill",
        incompleteChecklistCount == 0 ? .green : .orange
      ),
      (
        "Move ready work",
        "Prepared manifests and ready checklists can be dispatched, completed, handed off, or blocked with a reason.",
        readyToMoveCount,
        "Dispatch queue",
        "paperplane.fill",
        readyToMoveCount == 0 ? .secondary : .blue
      ),
      (
        "Review handoff",
        "Dispatched, completed, or reopened Inbox handoffs need local review before they disappear from the operator queue.",
        handoffReviewCount,
        "Audit or linked order",
        "arrow.left.arrow.right.square.fill",
        handoffReviewCount == 0 ? .green : .purple
      )
    ]
  }

  private var dispatchReadinessCompleteCount: Int {
    dispatchReadinessItems.filter { $0.count == 0 || $0.title == "Move ready work" }.count
  }

  private var dispatchReadinessGridColumns: [GridItem] {
    let count = isCompact ? 2 : 3
    return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
  }

  private var dispatchReadinessCardHeight: CGFloat {
    isCompact ? 138 : 128
  }

  private var dispatchReadinessLadderPanel: some View {
    SettingsPanel(title: "Dispatch readiness ladder", symbol: "checklist.checked") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: dispatchReadinessCompleteCount == dispatchReadinessItems.count ? "checkmark.seal.fill" : "list.bullet.clipboard.fill")
            .foregroundStyle(dispatchReadinessCompleteCount == dispatchReadinessItems.count ? .green : .orange)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text("Check dispatch in this order")
              .font(.headline)
            Text("This panel explains what must be true before a local outbound record should be considered ready. It reads existing records only.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Badge("\(dispatchReadinessCompleteCount)/\(dispatchReadinessItems.count)", color: dispatchReadinessCompleteCount == dispatchReadinessItems.count ? .green : .orange)
        }

        LazyVGrid(columns: dispatchReadinessGridColumns, alignment: .leading, spacing: 10) {
          ForEach(dispatchReadinessItems, id: \.title) { item in
            VStack(alignment: .leading, spacing: 8) {
              HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(item.title, systemImage: item.symbol)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(item.color)
                Spacer()
                Badge("\(item.count)", color: item.color)
              }
              Text(item.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
              Text("Check \(item.destination)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(item.color)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: dispatchReadinessCardHeight, maxHeight: dispatchReadinessCardHeight, alignment: .topLeading)
            .background(item.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }

        Text("Local boundary: this does not create manifests, complete checklists, mutate mailbox messages, call carriers, print labels, scan barcodes, or run background work.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var dispatchSummaryPanel: some View {
    SettingsPanel(title: "Dispatch next action", symbol: "arrow.forward.circle.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: blockedDispatchCount > 0 ? "exclamationmark.triangle.fill" : "shippingbox.and.arrow.backward.fill")
            .foregroundStyle(dispatchSummaryTone)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(dispatchSummaryTitle)
              .font(.headline)
            Text(dispatchSummaryDetail)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Badge(openDispatchCount == 0 ? "Clear" : "\(openDispatchCount) open", color: dispatchSummaryTone)
        }

        MetricStrip(items: [
          ("Blocked", "\(blockedDispatchCount)", blockedDispatchCount == 0 ? .green : .red),
          ("Reopened", "\(reopenedInboxDispatchHandoffCount)", reopenedInboxDispatchHandoffCount == 0 ? .green : .purple),
          ("Verify first", "\(partialInboxDispatchBlockerCount)", partialInboxDispatchBlockerCount == 0 ? .green : .orange),
          ("Ready", "\(readyDispatchCount)", readyDispatchCount == 0 ? .secondary : .orange),
          ("Inbox setup", "\(inboxDispatchSetupOrders.count)", inboxDispatchSetupOrders.isEmpty ? .green : .teal),
          ("Wishlist", "\(wishlistDispatchSetupOrderCount)", wishlistDispatchSetupOrderCount == 0 ? .green : .pink),
          ("Wishlist handoff gaps", "\(wishlistDispatchHandoffSanityGapCount)", wishlistDispatchHandoffSanityGapCount == 0 ? .green : .orange),
          ("Queue rows", "\(dispatchItems.count)", dispatchItems.isEmpty ? .green : .blue)
        ])

        VStack(alignment: .leading, spacing: 8) {
          Label("Mailbox provider dispatch context", systemImage: "point.3.connected.trianglepath.dotted")
            .font(.subheadline.weight(.semibold))
          Text("Dispatch should only act on orders that already came through Inbox or were linked manually. Provider rows explain why latest mailbox refreshes did or did not create dispatch setup work.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          ForEach(dispatchMailboxProviderRows, id: \.provider) { row in
            HStack(alignment: .top, spacing: 10) {
              Image(systemName: row.symbol)
                .foregroundStyle(row.color)
                .frame(width: 22)
              VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                  Text(row.provider)
                    .font(.caption.weight(.semibold))
                  Badge(row.status, color: row.color)
                }
                Text(row.detail)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
              Spacer(minLength: 0)
            }
          }
        }
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))

        if !store.gmailMailboxConnections.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Label(dispatchGmailCompileTitle, systemImage: dispatchGmailReadiness?.isReady == true ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
              .font(.caption.weight(.semibold))
              .foregroundStyle(dispatchGmailCompileColor)
            Text(dispatchGmailCompileDetail)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            if let readiness = dispatchGmailReadiness {
              CompactMetadataGrid(minimumWidth: isCompact ? 150 : 175) {
                Badge(readiness.compiledClientIDStatus, color: readiness.compiledClientIDStatus.localizedCaseInsensitiveContains("matches") || readiness.compiledClientIDStatus.localizedCaseInsensitiveContains("present") ? .green : .orange)
                Badge(readiness.compiledCallbackSchemeStatus, color: readiness.compiledCallbackSchemeStatus.localizedCaseInsensitiveContains("includes") || readiness.compiledCallbackSchemeStatus.localizedCaseInsensitiveContains("present") ? .green : .orange)
                Badge(readiness.expectedCallbackScheme, color: .secondary)
              }
            }
          }
          .padding(10)
          .background(dispatchGmailCompileColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

          MailboxProviderPostRefreshDisclosure(
            title: "Gmail refresh follow-up",
            detail: "Open this when Gmail refresh results need dispatch follow-up. Keep it collapsed while working the dispatch queue.",
            symbol: "envelope.badge.shield.half.filled",
            tone: dispatchGmailCompileColor,
            statusLabel: "Gmail"
          ) {
            GmailPostRefreshActionCard(plan: store.gmailPostRefreshActionPlan)
          }
        }

        CompactActionRow {
          NavigationLink {
            ShipmentManifestsView(store: store)
          } label: {
            Label("Open Manifests", systemImage: "list.bullet.clipboard.fill")
          }
          NavigationLink {
            DispatchReadinessView(store: store)
          } label: {
            Label("Open Readiness", systemImage: "checkmark.rectangle.stack.fill")
          }
          if !store.gmailMailboxConnections.isEmpty {
            Button {
              store.recordGmailReleaseReadinessSnapshot()
            } label: {
              Label("Record Gmail snapshot", systemImage: "camera.metering.center.weighted")
            }
            Button {
              store.createReviewTaskFromGmailReleaseReadinessSnapshot()
            } label: {
              Label("Create Gmail snapshot task", systemImage: "checklist")
            }
          }
          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Open Audit", systemImage: "list.clipboard.fill")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private var gmailDispatchReadinessPanel: some View {
    GmailReleaseBoundaryPanel(
      store: store,
      title: "Gmail dispatch readiness",
      lead: "Gmail release checks are mailbox-provider readiness. They should create Dispatch work only after Gmail imports a real Inbox row and that row is created or linked as an order.",
      sourceMetricTitle: "Gmail imported",
      sourceCount: latestGmailSummary?.importedCount ?? 0,
      boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store token values, create dispatch records automatically, or mutate mailbox messages."
    )
  }

  private var microsoft365DispatchReadinessPanel: some View {
    Microsoft365ReleaseBoundaryPanel(
      store: store,
      title: "Outlook dispatch readiness",
      lead: "Outlook release checks are mailbox-provider readiness. They should create Dispatch work only after Outlook imports a real Inbox row and that row is created or linked as an order.",
      sourceMetricTitle: "Outlook imported",
      sourceCount: store.microsoft365LastRefreshImportedCount,
      boundaryDetail: "Local-only boundary: this panel does not start Microsoft sign-in, request tokens, fetch Graph messages, store token values, create dispatch records automatically, or mutate mailbox messages."
    )
  }

  private var dispatchProviderEvidencePanel: some View {
    SettingsPanel(title: "Dispatch provider evidence", symbol: "doc.text.magnifyingglass") {
      DisclosureGroup(isExpanded: $showDispatchProviderEvidence) {
        VStack(alignment: .leading, spacing: 14) {
          MailboxProviderAdvancedDiagnosticsDisclosure(
            store: store,
            detail: "Open this when dispatch needs mailbox handoff evidence or troubleshooting detail. The dispatch queue stays focused on outbound work.",
            showReleaseGate: false
          )
          if !store.gmailMailboxConnections.isEmpty {
            gmailDispatchReadinessPanel
          }
          if !store.microsoft365MailboxConnections.isEmpty {
            microsoft365DispatchReadinessPanel
          }
        }
        .padding(.top, 8)
      } label: {
        VStack(alignment: .leading, spacing: 4) {
          Text(showDispatchProviderEvidence ? "Hide advanced dispatch evidence" : "Show advanced dispatch evidence")
            .font(.subheadline.weight(.semibold))
          Text("Dispatch operators can use the queue and readiness ladder first. Open this only for mailbox handoff diagnostics or provider release evidence.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .tint(.teal)
    }
  }

  private var dispatchQueuePanel: some View {
    SettingsPanel(title: "Unified dispatch queue", symbol: "shippingbox.and.arrow.backward.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Work blocked, high-risk, incomplete, upcoming outbound records, and Inbox/Wishlist orders that still need dispatch setup.")
          .font(.callout)
          .foregroundStyle(.secondary)

        FilterControlGrid {
          TextField("Search dispatch queue", text: $dispatchSearchText)
            .textFieldStyle(.roundedBorder)
          Badge("\(visibleDispatchItems.count + visibleInboxDispatchSetupOrders.count) shown", color: visibleDispatchItems.isEmpty && visibleInboxDispatchSetupOrders.isEmpty ? .orange : .blue)
          if !dispatchSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Button("Clear search", systemImage: "xmark.circle") {
              dispatchSearchText = ""
            }
            .buttonStyle(.bordered)
          }
        }

        if visibleDispatchItems.isEmpty && visibleInboxDispatchSetupOrders.isEmpty {
          MVPEmptyState(
            title: dispatchItems.isEmpty ? "Dispatch queue is clear" : "No matching dispatch rows",
            detail: dispatchItems.isEmpty ? "Shipment manifests and readiness checklists that need outbound action will appear here." : "Clear the search to return to the full dispatch queue.",
            symbol: "checkmark.seal.fill"
          )
        } else if visibleDispatchItems.isEmpty {
          Label(
            dispatchItems.isEmpty
              ? "No manifest or readiness rows need action yet. Inbox-created or Wishlist-linked orders needing dispatch setup are shown above."
              : "No manifest or readiness rows match this search. Inbox/Wishlist order setup results are shown above when they match.",
            systemImage: "tray.and.arrow.down.fill"
          )
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        } else {
          ForEach(visibleDispatchItems.prefix(12)) { item in
            DispatchQueueRow(item: item, store: store)
          }
        }
      }
    }
  }

  @ViewBuilder
  private var inboxDispatchSetupPanel: some View {
    if !visibleInboxDispatchSetupOrders.isEmpty {
      SettingsPanel(title: "Inbox and Wishlist orders needing dispatch setup", symbol: "tray.and.arrow.down.fill") {
        VStack(alignment: .leading, spacing: 12) {
          Text("These orders came from Inbox intake or a Wishlist purchase handoff. Verify partial details first; then add manifest or readiness context when the order is dispatch-ready.")
            .font(.callout)
            .foregroundStyle(.secondary)

          ForEach(visibleInboxDispatchSetupOrders) { order in
            DispatchInboxOrderRow(order: order, store: store)
          }
        }
      }
    }
  }

  private var detailRoutes: some View {
    SettingsPanel(title: "Detailed dispatch views", symbol: "rectangle.stack.fill") {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 220 : 260), spacing: 12)], alignment: .leading, spacing: 12) {
        OperatorRouteCard(title: "Shipment Manifests", detail: "Prepare outbound batches and courier handoff groups.", symbol: "list.bullet.clipboard.fill", badge: "\(store.shipmentManifestRecords.count) manifests") {
          ShipmentManifestsView(store: store)
        }

        OperatorRouteCard(title: "Dispatch Readiness", detail: "Confirm scans, labels, custody, and handoff readiness.", symbol: "checkmark.rectangle.stack.fill", badge: "\(store.incompleteDispatchChecklists.count) incomplete") {
          DispatchReadinessView(store: store)
        }
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Dispatch")
        .font(isCompact ? .title.bold() : .largeTitle.bold())
      Text("Triage outbound batches and readiness checks before dispatch, courier handoff, or internal transfer.")
        .foregroundStyle(.secondary)

      MetricStrip(items: [
        ("Queue", "\(dispatchItems.count)", dispatchItems.isEmpty ? .green : .blue),
        ("Reopened", "\(reopenedInboxDispatchHandoffCount)", reopenedInboxDispatchHandoffCount == 0 ? .green : .purple),
        ("Verify first", "\(partialInboxDispatchBlockerCount)", partialInboxDispatchBlockerCount == 0 ? .green : .orange),
        ("Inbox setup", "\(inboxDispatchSetupOrders.count)", inboxDispatchSetupOrders.isEmpty ? .green : .teal),
        ("Wishlist", "\(wishlistDispatchSetupOrderCount)", wishlistDispatchSetupOrderCount == 0 ? .green : .pink),
        ("Wishlist gaps", "\(wishlistDispatchHandoffSanityGapCount)", wishlistDispatchHandoffSanityGapCount == 0 ? .green : .orange),
        ("Undispatched", "\(store.undispatchedShipmentManifests.count)", store.undispatchedShipmentManifests.isEmpty ? .green : .purple),
        ("Blocked", "\(store.blockedShipmentManifests.count)", store.blockedShipmentManifests.isEmpty ? .green : .red),
        ("Incomplete", "\(store.incompleteDispatchChecklists.count)", store.incompleteDispatchChecklists.isEmpty ? .green : .orange),
        ("High risk", "\(store.highRiskShipmentManifests.count + store.highRiskDispatchChecklists.count)", store.highRiskShipmentManifests.isEmpty && store.highRiskDispatchChecklists.isEmpty ? .green : .pink)
      ])
    }
  }

  private func uniqueManifests(_ records: [ShipmentManifestRecord]) -> [ShipmentManifestRecord] {
    var seen: Set<UUID> = []
    var unique: [ShipmentManifestRecord] = []
    for record in records where !seen.contains(record.id) {
      seen.insert(record.id)
      unique.append(record)
    }
    return unique
  }

  private func uniqueChecklists(_ checklists: [DispatchReadinessChecklist]) -> [DispatchReadinessChecklist] {
    var seen: Set<UUID> = []
    var unique: [DispatchReadinessChecklist] = []
    for checklist in checklists where !seen.contains(checklist.id) {
      seen.insert(checklist.id)
      unique.append(checklist)
    }
    return unique
  }

  private func dispatchSetupPriority(for order: TrackedOrder) -> Int {
    if order.status == .exception { return 100 }
    if orderNeedsPreDispatchVerification(order) { return 95 }
    if order.reviewState != .accepted { return 90 }
    if order.status == .inTransit { return 80 }
    if order.status == .shipped { return 70 }
    return 40
  }

  private func orderNeedsDispatchSetup(_ order: TrackedOrder) -> Bool {
    [.shipped, .inTransit, .exception].contains(order.status)
      && store.suggestedShipmentManifestRecords(for: order).isEmpty
      && store.suggestedDispatchReadinessChecklists(for: order).isEmpty
  }

  private func orderNeedsPreDispatchVerification(_ order: TrackedOrder) -> Bool {
    let hasPartialTask = store.tasks(for: .order, linkedEntityID: order.id.uuidString).contains { task in
      task.status != .completed && task.isPartialInboxOrderFollowUp
    }
    return hasPartialTask || order.missingInboxOrderFieldCount > 0
  }

  private func orderHasWishlistSource(_ order: TrackedOrder) -> Bool {
    !store.activeWishlistItemsLinked(to: order).isEmpty
  }

  private func wishlistDispatchHandoffSanityGaps(for item: WishlistItem) -> [String] {
    store.wishlistHandoffSanityGaps(for: item)
  }
}

private struct DispatchInboxOrderRow: View {
  var order: TrackedOrder
  var store: ParcelOpsStore
  @State private var feedbackMessage: String?

  private var partialFollowUpTasks: [ReviewTask] {
    store.tasks(for: .order, linkedEntityID: order.id.uuidString)
      .filter { $0.status != .completed && $0.isPartialInboxOrderFollowUp }
  }

  private var needsPreDispatchVerification: Bool {
    !partialFollowUpTasks.isEmpty || order.missingInboxOrderFieldCount > 0
  }
  private var sourceTrailCount: Int {
    linkedIntakeEmails.count + store.importQueueItems(for: order).count + store.acceptanceRecords(for: order).count + linkedWishlistItems.count
  }
  private var linkedWishlistItems: [WishlistItem] {
    store.activeWishlistItemsLinked(to: order)
  }
  private var wishlistHandoffSanityGaps: [(item: WishlistItem, gaps: [String])] {
    linkedWishlistItems.compactMap { item in
      let gaps = wishlistDispatchHandoffSanityGaps(for: item)
      return gaps.isEmpty ? nil : (item, gaps)
    }
  }
  private var wishlistDispatchSetupGaps: [(item: WishlistItem, gaps: [String])] {
    linkedWishlistItems.compactMap { item in
      let gaps = wishlistDispatchSetupGaps(for: item)
      return gaps.isEmpty ? nil : (item, gaps)
    }
  }
  private var linkedIntakeEmails: [ForwardedEmailIntake] {
    store.linkedIntakeEmails(for: order)
  }
  private var mailboxSourceSummaries: [OrderMailboxSourceSummary] {
    store.mailboxSourceSummaries(for: order)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "shippingbox.fill")
          .foregroundStyle(rowColor)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: 5) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
              Text("\(order.store) • \(order.orderNumber)")
                .font(.headline)
              Text("\(order.customer) • \(order.destination)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer(minLength: 8)
            Badge(rowBadgeLabel, color: needsPreDispatchVerification ? .orange : rowColor)
          }

          Text(nextActionText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(needsPreDispatchVerification || sourceTrailCount == 0 ? .orange : .teal)

          CompactMetadataGrid {
            Badge(order.status.rawValue, color: rowColor)
            Badge(order.reviewState.rawValue, color: order.reviewState.color)
            Badge(sourceTrailCount > 0 ? "\(sourceTrailCount) source" : "Source trail missing", color: sourceTrailCount > 0 ? .green : .orange)
            if let mailboxBadge {
              Badge(mailboxBadge.label, color: mailboxBadge.color)
            }
            if !linkedWishlistItems.isEmpty {
              Badge("\(linkedWishlistItems.count) Wishlist", color: .pink)
            }
            if !wishlistHandoffSanityGaps.isEmpty {
              Badge("\(wishlistHandoffSanityGaps.count) handoff gap", color: .orange)
            }
            if !wishlistDispatchSetupGaps.isEmpty {
              Badge("\(wishlistDispatchSetupGaps.count) dispatch setup", color: .blue)
            }
            if !partialFollowUpTasks.isEmpty {
              Badge("\(partialFollowUpTasks.count) verify task", color: .orange)
            }
            if order.missingInboxOrderFieldCount > 0 {
              Badge("\(order.missingInboxOrderFieldCount) missing", color: .orange)
            }
            if order.reviewState == .accepted {
              Badge("Reviewed, dispatch gap", color: .purple)
            }
            Label(order.carrier, systemImage: "truck.box.fill")
              .font(.caption)
              .foregroundStyle(.secondary)
            Label(order.trackingNumber, systemImage: "number")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      if sourceTrailCount == 0 {
        Label("Source trail missing: open the order before preparing manifest or readiness records.", systemImage: "link.badge.plus")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }

      if !mailboxSourceSummaries.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Label("Mailbox provider source", systemImage: "envelope.badge.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(mailboxSourceColor(mailboxSourceSummaries[0]))
          CompactMetadataGrid(minimumWidth: 130) {
            ForEach(mailboxSourceSummaries.prefix(3)) { source in
              Badge(source.badgeLabel, color: mailboxSourceColor(source))
              Badge(source.statusLabel, color: mailboxSourceColor(source))
            }
          }

          let hiddenSourceCount = max(mailboxSourceSummaries.count - 3, 0)
          if hiddenSourceCount > 0 {
            Text("\(hiddenSourceCount) more mailbox source\(hiddenSourceCount == 1 ? "" : "s") are tracked on this order.")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }

          Text(mailboxSourceDetailText)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .background(mailboxSourceColor(mailboxSourceSummaries[0]).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }

      if !linkedWishlistItems.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Label("Wishlist purchase context", systemImage: "star.square.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.pink)
          ForEach(linkedWishlistItems.prefix(2)) { item in
            VStack(alignment: .leading, spacing: 5) {
              Text("\(item.itemName) • \(item.purchaseHandoff?.purchaseStatus ?? item.purchaseReadiness ?? item.status)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
              let setupGaps = wishlistDispatchSetupGaps(for: item)
              if !setupGaps.isEmpty {
                Text("Dispatch setup gaps: \(setupGaps.joined(separator: ", "))")
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(.blue)
                  .fixedSize(horizontal: false, vertical: true)
                CompactActionRow {
                  if setupGaps.contains("manifest") {
                    Button("Stage manifest", systemImage: "list.bullet.clipboard.fill") {
                      store.createWishlistShipmentManifest(item)
                      feedbackMessage = "Wishlist dispatch manifest staged locally."
                    }
                  }
                  if setupGaps.contains("readiness checklist") {
                    Button("Stage readiness", systemImage: "checkmark.rectangle.stack.fill") {
                      store.createWishlistDispatchReadinessChecklist(item)
                      feedbackMessage = "Wishlist dispatch readiness checklist staged locally."
                    }
                  }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
              }
            }
          }
          ForEach(wishlistHandoffSanityGaps.prefix(2), id: \.item.id) { entry in
            Text("Handoff sanity gaps for \(entry.item.itemName): \(entry.gaps.prefix(4).joined(separator: ", "))")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.orange)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .padding(8)
        .background(.pink.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }

      CompactActionRow {
        NavigationLink {
          OrderDetailView(order: order, store: store)
        } label: {
          Label("Open order", systemImage: "arrow.up.right.square.fill")
        }
        .buttonStyle(.bordered)

        if !needsPreDispatchVerification {
          NavigationLink {
            ShipmentManifestsView(store: store)
          } label: {
            Label("Manifests", systemImage: "list.bullet.clipboard.fill")
          }
          .buttonStyle(.bordered)

          NavigationLink {
            DispatchReadinessView(store: store)
          } label: {
            Label("Readiness", systemImage: "checkmark.rectangle.stack.fill")
          }
          .buttonStyle(.bordered)
        }

        Button("Create task", systemImage: "checklist") {
          store.createReviewTask(from: order)
          feedbackMessage = "Dispatch setup task created."
        }
        .buttonStyle(.bordered)

        Button("Create draft", systemImage: "envelope.open.fill") {
          store.createDraftMessage(from: order)
          feedbackMessage = "Draft created."
        }
        .buttonStyle(.bordered)
      }

      if let feedbackMessage {
        Text(feedbackMessage)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }

  private var rowColor: Color {
    if needsPreDispatchVerification { return .orange }
    if !wishlistHandoffSanityGaps.isEmpty { return .orange }
    if !wishlistDispatchSetupGaps.isEmpty { return .blue }
    if !linkedWishlistItems.isEmpty { return .pink }
    return order.status == .exception ? .orange : .teal
  }

  private var rowBadgeLabel: String {
    if needsPreDispatchVerification { return "Verify before dispatch" }
    if !linkedWishlistItems.isEmpty { return "Wishlist order" }
    return "Inbox order"
  }

  private var nextActionText: String {
    if needsPreDispatchVerification {
      return "Next: open the order and confirm missing details before manifest or readiness setup."
    }
    if sourceTrailCount == 0 {
      return "Next: confirm the Inbox, Import Queue, Acceptance, or Wishlist source trail before creating dispatch setup."
    }
    if !linkedWishlistItems.isEmpty {
      if !wishlistHandoffSanityGaps.isEmpty {
        let gapSummary = wishlistHandoffSanityGaps.flatMap(\.gaps).prefix(3).joined(separator: ", ")
        return "Next: resolve Wishlist handoff sanity gaps before manifest or readiness setup: \(gapSummary)."
      }
      if !wishlistDispatchSetupGaps.isEmpty {
        let gapSummary = wishlistDispatchSetupGaps.flatMap(\.gaps).prefix(3).joined(separator: ", ")
        return "Next: stage missing Wishlist dispatch setup locally: \(gapSummary)."
      }
      return "Next: confirm the Wishlist purchase handoff, then decide whether this order needs manifest or readiness setup."
    }
    return "Next: confirm whether this order needs a shipment manifest or dispatch readiness checklist."
  }

  private var mailboxBadge: (label: String, color: Color)? {
    guard let first = mailboxSourceSummaries.first else { return nil }
    if mailboxSourceSummaries.count == 1 {
      return (first.badgeLabel, mailboxSourceColor(first))
    }
    return ("\(mailboxSourceSummaries.count) mailbox sources", mailboxSourceColor(first))
  }

  private var mailboxSourceDetailText: String {
    mailboxSourceSummaries.prefix(3)
      .map { "\($0.providerName) via \($0.detailText)" }
      .joined(separator: " ")
  }

  private func mailboxSourceColor(_ summary: OrderMailboxSourceSummary) -> Color {
    if summary.importedCount > 0 { return .green }
    if summary.duplicateRefreshedCount > 0 { return .teal }
    if summary.duplicateCount > 0 { return .orange }
    switch summary.providerName {
    case "Gmail": return .blue
    case "SpaceMail": return .teal
    case "Microsoft 365": return .purple
    default: return .secondary
    }
  }

  private func wishlistDispatchSetupGaps(for item: WishlistItem) -> [String] {
    store.wishlistLinkedOrderDispatchGaps(for: item)
  }

  private func wishlistDispatchHandoffSanityGaps(for item: WishlistItem) -> [String] {
    store.wishlistHandoffSanityGaps(for: item)
  }
}

private struct DispatchQueueItem: Identifiable {
  var id: String
  var source: DispatchQueueSource
  var sourceLabel: String
  var title: String
  var subtitle: String
  var detail: String
  var plannedDate: String
  var statusLabel: String
  var riskLevel: ShipmentRiskLevel
  var reviewState: ReviewState
  var orderCount: Int
  var shipmentGroupCount: Int
  var scanCount: Int
  var nextAction: String
  var sortPriority: Int

  static func manifest(_ record: ShipmentManifestRecord) -> DispatchQueueItem {
    DispatchQueueItem(
      id: "manifest-\(record.id.uuidString)",
      source: .manifest(record),
      sourceLabel: record.isInboxHandoffSetup ? "Inbox manifest" : "Manifest",
      title: record.isInboxHandoffSetup ? "Inbox handoff • \(record.carrierCourier)" : "\(record.carrierCourier) • \(record.manifestType.rawValue)",
      subtitle: record.title,
      detail: record.isInboxHandoffSetup ? "Destination: \(record.destinationSummary). Next: confirm readiness, labels, scans, custody, and handoff." : record.destinationSummary,
      plannedDate: record.plannedDispatchDate,
      statusLabel: record.dispatchStatus.rawValue,
      riskLevel: record.riskLevel,
      reviewState: record.reviewState,
      orderCount: record.includedOrderIDs.count,
      shipmentGroupCount: record.shipmentGroupIDs.count,
      scanCount: record.scanSessionIDs.count,
      nextAction: manifestNextAction(record),
      sortPriority: manifestSortPriority(record)
    )
  }

  static func checklist(_ checklist: DispatchReadinessChecklist) -> DispatchQueueItem {
    DispatchQueueItem(
      id: "checklist-\(checklist.id.uuidString)",
      source: .checklist(checklist),
      sourceLabel: checklist.isInboxHandoffSetup ? "Inbox readiness" : "Readiness",
      title: checklist.isInboxHandoffSetup ? "Inbox readiness • \(checklist.assignedOwnerTeam)" : "\(checklist.checklistType.rawValue) • \(checklist.assignedOwnerTeam)",
      subtitle: checklist.title,
      detail: checklist.isInboxHandoffSetup
        ? "Confirmed intake fields are ready. Missing: \(checklist.missingRequirementsSummary)"
        : checklist.missingRequirementsSummary.isPlaceholderValidationValue ? checklist.requiredChecksSummary : "Missing: \(checklist.missingRequirementsSummary)",
      plannedDate: checklist.plannedDispatchDate,
      statusLabel: checklist.checklistStatus.rawValue,
      riskLevel: checklist.riskLevel,
      reviewState: checklist.reviewState,
      orderCount: checklist.orderIDs.count,
      shipmentGroupCount: checklist.shipmentGroupIDs.count,
      scanCount: checklist.scanSessionIDs.count,
      nextAction: checklistNextAction(checklist),
      sortPriority: checklistSortPriority(checklist)
    )
  }

  private static func manifestNextAction(_ record: ShipmentManifestRecord) -> String {
    if record.isInboxHandoffSetup && (record.dispatchStatus == .draft || record.dispatchStatus == .reopened) {
      return "Confirm readiness checklist"
    }
    switch record.dispatchStatus {
    case .blockedNeedsReview:
      return "Resolve blocked manifest"
    case .draft, .reopened:
      return "Prepare manifest"
    case .prepared:
      return "Dispatch or block"
    case .dispatched:
      return "Confirm handoff"
    case .handedOff:
      return record.reviewState == .accepted ? "Handoff complete" : "Mark reviewed"
    }
  }

  private static func checklistNextAction(_ checklist: DispatchReadinessChecklist) -> String {
    if checklist.isInboxHandoffSetup && (checklist.checklistStatus == .draft || checklist.checklistStatus == .reopened) {
      return "Confirm labels, scans, custody, and handoff"
    }
    switch checklist.checklistStatus {
    case .blockedNeedsReview:
      return "Resolve blocked checklist"
    case .draft, .reopened:
      return "Mark ready or block"
    case .ready:
      return "Complete readiness checks"
    case .completed:
      return checklist.reviewState == .accepted ? "Checklist complete" : "Mark reviewed"
    }
  }

  private static func manifestSortPriority(_ record: ShipmentManifestRecord) -> Int {
    if record.dispatchStatus == .blockedNeedsReview { return 100 }
    if record.riskLevel == .critical { return 95 }
    if record.riskLevel == .high { return 90 }
    if record.isInboxHandoffSetup && (record.dispatchStatus == .draft || record.dispatchStatus == .reopened) { return 86 }
    if record.dispatchStatus == .prepared { return 82 }
    if record.dispatchStatus == .draft || record.dispatchStatus == .reopened { return 75 }
    if record.reviewState != .accepted { return 65 }
    return 35
  }

  private static func checklistSortPriority(_ checklist: DispatchReadinessChecklist) -> Int {
    if checklist.checklistStatus == .blockedNeedsReview { return 100 }
    if checklist.riskLevel == .critical { return 95 }
    if checklist.riskLevel == .high { return 90 }
    if checklist.isInboxHandoffSetup && (checklist.checklistStatus == .draft || checklist.checklistStatus == .reopened) { return 86 }
    if checklist.checklistStatus == .ready { return 82 }
    if checklist.checklistStatus == .draft || checklist.checklistStatus == .reopened { return 75 }
    if checklist.reviewState != .accepted { return 65 }
    return 35
  }

  var decisionTitle: String {
    switch source {
    case .manifest(let record):
      if record.dispatchStatus == .blockedNeedsReview { return "Manifest is blocked" }
      if record.isInboxHandoffSetup && (record.dispatchStatus == .draft || record.dispatchStatus == .reopened) { return "Confirm Inbox handoff before dispatch" }
      switch record.dispatchStatus {
      case .draft:
        return "Prepare manifest when details are ready"
      case .prepared:
        return "Ready to dispatch or block"
      case .dispatched:
        return "Confirm courier or team handoff"
      case .handedOff:
        return record.reviewState == .accepted ? "Handoff complete" : "Review completed handoff"
      case .reopened:
        return "Reopened manifest needs review"
      case .blockedNeedsReview:
        return "Manifest is blocked"
      }
    case .checklist(let checklist):
      if checklist.checklistStatus == .blockedNeedsReview { return "Readiness checklist is blocked" }
      if checklist.isInboxHandoffSetup && (checklist.checklistStatus == .draft || checklist.checklistStatus == .reopened) { return "Confirm Inbox order readiness" }
      switch checklist.checklistStatus {
      case .draft:
        return "Complete required checks"
      case .ready:
        return "Ready to complete or block"
      case .completed:
        return checklist.reviewState == .accepted ? "Checklist complete" : "Review completed checklist"
      case .reopened:
        return "Reopened checklist needs review"
      case .blockedNeedsReview:
        return "Readiness checklist is blocked"
      }
    }
  }

  var decisionDetail: String {
    switch source {
    case .manifest(let record):
      if record.dispatchStatus == .blockedNeedsReview {
        return "Open the manifest, resolve the blocker or assign a task, then prepare it again when the outbound work is safe."
      }
      if record.includedOrderIDs.isEmpty {
        return "No included orders are linked. Add or confirm order context before treating this manifest as dispatch-ready."
      }
      if record.handoffLocationStorageLocationID == nil {
        return "Handoff location is missing. Confirm where the parcel leaves custody before dispatch."
      }
      if record.isInboxHandoffSetup && (record.dispatchStatus == .draft || record.dispatchStatus == .reopened) {
        return "This manifest came from order source setup. Open the linked order and confirm source details before dispatch."
      }
      switch record.dispatchStatus {
      case .draft, .reopened:
        return "Prepare only after carrier/courier, destination, included orders, label references, and handoff location are usable."
      case .prepared:
        return "Dispatch if outbound details are confirmed. Use Blocked if labels, scans, custody, or carrier details are not ready."
      case .dispatched:
        return "Record handoff once the courier, internal team, or handoff area has taken responsibility."
      case .handedOff:
        return "Mark reviewed when the local handoff trail is complete and no follow-up task is needed."
      case .blockedNeedsReview:
        return "Open the manifest, resolve the blocker or assign a task, then prepare it again when the outbound work is safe."
      }
    case .checklist(let checklist):
      if checklist.checklistStatus == .blockedNeedsReview {
        return "Open the checklist, record what is missing, and keep it blocked until labels, scans, custody, or requirements are fixed."
      }
      if checklist.orderIDs.isEmpty {
        return "No orders are linked. Confirm order context before marking readiness complete."
      }
      if !checklist.missingRequirementsSummary.isPlaceholderValidationValue && !checklist.missingRequirementsSummary.isEmpty {
        return "Missing requirements are recorded: \(checklist.missingRequirementsSummary). Mark ready only after they are resolved."
      }
      if checklist.isInboxHandoffSetup && (checklist.checklistStatus == .draft || checklist.checklistStatus == .reopened) {
        return "This checklist came from order source setup. Confirm the linked order source trail before marking ready."
      }
      switch checklist.checklistStatus {
      case .draft, .reopened:
        return "Mark ready only after required checks, labels, scan/custody evidence, and handoff requirements look complete."
      case .ready:
        return "Complete once the final local checks are done, or block it if a requirement has failed."
      case .completed:
        return "Mark reviewed when the completed checklist has no missing local follow-up."
      case .blockedNeedsReview:
        return "Open the checklist, record what is missing, and keep it blocked until labels, scans, custody, or requirements are fixed."
      }
    }
  }

  var decisionBadge: String {
    switch source {
    case .manifest(let record):
      switch record.dispatchStatus {
      case .blockedNeedsReview: return "Blocked"
      case .draft, .reopened: return record.isInboxHandoffSetup ? "Verify" : "Prepare"
      case .prepared: return "Move"
      case .dispatched: return "Handoff"
      case .handedOff: return record.reviewState == .accepted ? "Done" : "Review"
      }
    case .checklist(let checklist):
      switch checklist.checklistStatus {
      case .blockedNeedsReview: return "Blocked"
      case .draft, .reopened: return checklist.isInboxHandoffSetup ? "Verify" : "Check"
      case .ready: return "Complete"
      case .completed: return checklist.reviewState == .accepted ? "Done" : "Review"
      }
    }
  }

  var decisionColor: Color {
    switch source {
    case .manifest(let record):
      if record.dispatchStatus == .blockedNeedsReview { return .red }
      if record.riskLevel == .critical || record.riskLevel == .high { return .orange }
      if record.dispatchStatus == .prepared || record.dispatchStatus == .dispatched { return .blue }
      if record.dispatchStatus == .handedOff && record.reviewState == .accepted { return .green }
      return record.isInboxHandoffSetup ? .purple : .teal
    case .checklist(let checklist):
      if checklist.checklistStatus == .blockedNeedsReview { return .red }
      if checklist.riskLevel == .critical || checklist.riskLevel == .high { return .orange }
      if checklist.checklistStatus == .ready { return .blue }
      if checklist.checklistStatus == .completed && checklist.reviewState == .accepted { return .green }
      return checklist.isInboxHandoffSetup ? .purple : .teal
    }
  }

  var decisionSymbol: String {
    switch source {
    case .manifest(let record):
      switch record.dispatchStatus {
      case .blockedNeedsReview: return "exclamationmark.triangle.fill"
      case .draft, .reopened: return record.isInboxHandoffSetup ? "tray.and.arrow.down.fill" : "list.bullet.clipboard.fill"
      case .prepared: return "paperplane.fill"
      case .dispatched: return "person.badge.shield.checkmark.fill"
      case .handedOff: return "checkmark.seal.fill"
      }
    case .checklist(let checklist):
      switch checklist.checklistStatus {
      case .blockedNeedsReview: return "exclamationmark.triangle.fill"
      case .draft, .reopened: return checklist.isInboxHandoffSetup ? "tray.and.arrow.down.fill" : "checklist.unchecked"
      case .ready: return "checkmark.circle.fill"
      case .completed: return "checkmark.seal.fill"
      }
    }
  }
}

private enum DispatchQueueSource {
  case manifest(ShipmentManifestRecord)
  case checklist(DispatchReadinessChecklist)

  var symbol: String {
    switch self {
    case .manifest: "list.bullet.clipboard.fill"
    case .checklist: "checkmark.rectangle.stack.fill"
    }
  }
}

private struct DispatchQueueRow: View {
  var item: DispatchQueueItem
  var store: ParcelOpsStore
  @State private var feedbackMessage: String?

  private var linkedOrder: TrackedOrder? {
    switch item.source {
    case .manifest(let record):
      guard let orderID = record.includedOrderIDs.first ?? UUID(uuidString: record.linkedEntityID) else { return nil }
      return store.orders.first { $0.id == orderID }
    case .checklist(let checklist):
      guard let orderID = checklist.orderIDs.first ?? UUID(uuidString: checklist.linkedEntityID) else { return nil }
      return store.orders.first { $0.id == orderID }
    }
  }

  private var isInboxHandoff: Bool {
    switch item.source {
    case .manifest(let record):
      return record.isInboxHandoffSetup
    case .checklist(let checklist):
      return checklist.isInboxHandoffSetup
    }
  }

  private var isReopenedInboxHandoff: Bool {
    switch item.source {
    case .manifest(let record):
      return record.isInboxHandoffSetup && record.dispatchStatus == .reopened
    case .checklist(let checklist):
      return checklist.isInboxHandoffSetup && checklist.checklistStatus == .reopened
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: item.source.symbol)
          .foregroundStyle(item.riskLevel.color)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: 5) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
              Text(item.title)
                .font(.headline)
              Text(item.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer(minLength: 8)
            Badge(item.sourceLabel, color: item.riskLevel.color)
          }

          Text(item.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)

          CompactMetadataGrid {
            Badge(item.statusLabel, color: item.riskLevel.color)
            Badge(item.riskLevel.rawValue, color: item.riskLevel.color)
            Badge(item.reviewState.rawValue, color: item.reviewState.color)
            Label(item.plannedDate, systemImage: "calendar")
              .font(.caption)
              .foregroundStyle(.secondary)
            Label("\(item.orderCount) orders", systemImage: "shippingbox.fill")
              .font(.caption)
              .foregroundStyle(.secondary)
            Label("\(item.shipmentGroupCount) groups", systemImage: "shippingbox.and.arrow.backward.fill")
              .font(.caption)
              .foregroundStyle(.secondary)
            Label("\(item.scanCount) scans", systemImage: "qrcode.viewfinder")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Label(item.nextAction, systemImage: "arrow.forward.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(item.riskLevel.color)

          if isInboxHandoff {
            DispatchQueueInboxOrderContext(order: linkedOrder, store: store, isReopened: isReopenedInboxHandoff)
          }
        }
      }

      dispatchDecisionPanel

      CompactActionRow {
        NavigationLink {
          detailDestination
        } label: {
          Label("Open dispatch record", systemImage: "arrow.up.right.square.fill")
        }
        .buttonStyle(.bordered)

        if let linkedOrder {
          NavigationLink {
            OrderDetailView(order: linkedOrder, store: store)
          } label: {
            Label("Open order", systemImage: "shippingbox.fill")
          }
          .buttonStyle(.bordered)
        }

        switch item.source {
        case .manifest(let record):
          Button("Prepared", systemImage: "checkmark.circle.fill") {
            store.markShipmentManifestPrepared(record)
            feedbackMessage = "Manifest marked prepared locally."
          }
          .buttonStyle(.bordered)
          Button("Dispatched", systemImage: "paperplane.fill") {
            store.markShipmentManifestDispatched(record)
            feedbackMessage = "Manifest marked dispatched locally."
          }
          .buttonStyle(.bordered)
          Button("Handed off", systemImage: "person.badge.shield.checkmark.fill") {
            store.markShipmentManifestHandedOff(record)
            feedbackMessage = "Manifest handoff recorded locally."
          }
          .buttonStyle(.borderedProminent)
          Button("Blocked", systemImage: "exclamationmark.triangle.fill") {
            store.markShipmentManifestBlocked(record)
            feedbackMessage = "Manifest blocked for review."
          }
          .buttonStyle(.bordered)
          Button("Reopen", systemImage: "arrow.counterclockwise") {
            store.reopenShipmentManifest(record)
            feedbackMessage = "Manifest reopened for review."
          }
          .buttonStyle(.bordered)
          Button("Mark reviewed", systemImage: "checkmark.shield.fill") {
            store.markShipmentManifestReviewed(record)
            feedbackMessage = "Manifest marked reviewed locally."
          }
          .buttonStyle(.bordered)
          Button("Create task", systemImage: "checklist") {
            store.createReviewTask(from: record)
            feedbackMessage = "Manifest follow-up task created. Check Tasks."
          }
          .buttonStyle(.bordered)
          Button("Create draft", systemImage: "envelope.open.fill") {
            store.createDraftMessage(from: record)
            feedbackMessage = "Manifest draft message created locally."
          }
          .buttonStyle(.bordered)

        case .checklist(let checklist):
          Button("Ready", systemImage: "checkmark.circle.fill") {
            store.markDispatchChecklistReady(checklist)
            feedbackMessage = "Readiness checklist marked ready locally."
          }
          .buttonStyle(.bordered)
          Button("Complete", systemImage: "checkmark.seal.fill") {
            store.markDispatchChecklistCompleted(checklist)
            feedbackMessage = "Readiness checklist completed locally."
          }
          .buttonStyle(.borderedProminent)
          Button("Blocked", systemImage: "exclamationmark.triangle.fill") {
            store.markDispatchChecklistBlocked(checklist)
            feedbackMessage = "Readiness checklist blocked for review."
          }
          .buttonStyle(.bordered)
          Button("Reopen", systemImage: "arrow.counterclockwise") {
            store.reopenDispatchChecklist(checklist)
            feedbackMessage = "Readiness checklist reopened for review."
          }
          .buttonStyle(.bordered)
          Button("Mark reviewed", systemImage: "checkmark.shield.fill") {
            store.markDispatchChecklistReviewed(checklist)
            feedbackMessage = "Readiness checklist marked reviewed locally."
          }
          .buttonStyle(.bordered)
          Button("Create task", systemImage: "checklist") {
            store.createReviewTask(from: checklist)
            feedbackMessage = "Readiness follow-up task created. Check Tasks."
          }
          .buttonStyle(.bordered)
          Button("Create draft", systemImage: "envelope.open.fill") {
            store.createDraftMessage(from: checklist)
            feedbackMessage = "Readiness draft message created locally."
          }
          .buttonStyle(.bordered)
        }
      }

      if let feedbackMessage {
        DispatchQueueFeedbackPanel(message: feedbackMessage, store: store)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }

  @ViewBuilder
  private var detailDestination: some View {
    switch item.source {
    case .manifest:
      ShipmentManifestsView(store: store)
    case .checklist:
      DispatchReadinessView(store: store)
    }
  }

  private var dispatchDecisionPanel: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: item.decisionSymbol)
        .foregroundStyle(item.decisionColor)
        .frame(width: 22)

      VStack(alignment: .leading, spacing: 4) {
        Text(item.decisionTitle)
          .font(.caption.weight(.semibold))
        Text(item.decisionDetail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 8)
      Badge(item.decisionBadge, color: item.decisionColor)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(item.decisionColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct DispatchQueueFeedbackPanel: View {
  var message: String
  var store: ParcelOpsStore

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(message, systemImage: "checkmark.circle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.green)

      CompactActionRow {
        NavigationLink {
          ShipmentManifestsView(store: store)
        } label: {
          Label("Open Manifests", systemImage: "list.bullet.clipboard.fill")
        }
        NavigationLink {
          DispatchReadinessView(store: store)
        } label: {
          Label("Open Readiness", systemImage: "checkmark.rectangle.stack.fill")
        }
        if message.localizedCaseInsensitiveContains("task") {
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
        }
        NavigationLink {
          AuditView(store: store)
        } label: {
          Label("Open Audit", systemImage: "list.clipboard.fill")
        }
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.green.opacity(0.12))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct DispatchQueueInboxOrderContext: View {
  var order: TrackedOrder?
  var store: ParcelOpsStore
  var isReopened: Bool

  private var mailboxSourceSummaries: [OrderMailboxSourceSummary] {
    guard let order else { return [] }
    return store.mailboxSourceSummaries(for: order)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(isReopened ? "Reopened source dispatch handoff" : "Inbox-created order handoff", systemImage: isReopened ? "arrow.counterclockwise.circle.fill" : "tray.and.arrow.down.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(isReopened ? .purple : .teal)

      if let order {
        CompactMetadataGrid(minimumWidth: 130) {
          Badge(order.orderNumber, color: .teal)
          Badge(order.status.rawValue, color: order.status.color)
          Badge(order.reviewState.rawValue, color: order.reviewState.color)
          Badge(order.latestStatus, color: isReopened ? .purple : .secondary)
          if let firstSource = mailboxSourceSummaries.first {
            Badge(mailboxSourceSummaries.count == 1 ? firstSource.badgeLabel : "\(mailboxSourceSummaries.count) mailbox sources", color: mailboxSourceColor(firstSource))
          }
        }

        if !mailboxSourceSummaries.isEmpty {
          VStack(alignment: .leading, spacing: 5) {
            Label("Provider source trail", systemImage: "envelope.badge.fill")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(mailboxSourceColor(mailboxSourceSummaries[0]))
            ForEach(mailboxSourceSummaries.prefix(3)) { source in
              CompactMetadataGrid(minimumWidth: 130) {
                Badge(source.badgeLabel, color: mailboxSourceColor(source))
                Badge(source.statusLabel, color: mailboxSourceColor(source))
              }
              Text(source.detailText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            let hiddenSourceCount = max(mailboxSourceSummaries.count - 3, 0)
            if hiddenSourceCount > 0 {
              Text("\(hiddenSourceCount) more provider source\(hiddenSourceCount == 1 ? "" : "s") are tracked on this handoff.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
          .padding(8)
          .background(mailboxSourceColor(mailboxSourceSummaries[0]).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        Text(isReopened
          ? "Open the order to inspect the order source trail and complete or block the reopened handoff."
          : "This dispatch row is linked to an Inbox-created or Wishlist-linked order. Use Open order when source context matters.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        Text("Linked order context was not found. Open the detailed dispatch record to review the linked IDs before completing the handoff.")
          .font(.caption2)
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(10)
    .background((isReopened ? Color.purple : Color.teal).opacity(0.10))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  private func mailboxSourceColor(_ summary: OrderMailboxSourceSummary) -> Color {
    if summary.importedCount > 0 { return .green }
    if summary.duplicateRefreshedCount > 0 { return .teal }
    if summary.duplicateCount > 0 { return .orange }
    switch summary.providerName {
    case "Gmail": return .blue
    case "SpaceMail": return .teal
    case "Microsoft 365": return .purple
    default: return .secondary
    }
  }
}

private struct OperatorRouteCard<Destination: View>: View {
  var title: String
  var detail: String
  var symbol: String
  var badge: String
  @ViewBuilder var destination: Destination
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }

  var body: some View {
    NavigationLink {
      destination
    } label: {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: symbol)
          .foregroundStyle(.teal)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 5) {
          if isCompact {
            VStack(alignment: .leading, spacing: 6) {
              Text(title)
                .font(.headline)
              Badge(badge, color: .teal)
            }
          } else {
            Text(title)
              .font(.headline)
          }
          Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        if !isCompact {
          Spacer(minLength: 8)
          Badge(badge, color: .teal)
        }
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.background)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }
    .buttonStyle(.plain)
  }
}
