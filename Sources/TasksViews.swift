import SwiftUI

struct TasksView: View {
  var store: ParcelOpsStore

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var queueSearchText = ""
  @State private var mvpFeedbackMessage: String?

  private var queueItems: [TaskQueueItem] {
    let tasks = store.reviewTasks
      .filter { store.isActiveWishlistTask($0) && ($0.status != .completed || $0.reviewState != .accepted) }
      .map(TaskQueueItem.task)
    let notes = store.handoffNotes
      .filter { store.isActiveWishlistHandoff($0) && ($0.status != .completed || $0.reviewState != .accepted) }
      .map(TaskQueueItem.handoff)

    return (tasks + notes).sorted { first, second in
      if first.sortPriority == second.sortPriority {
        return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
      }
      return first.sortPriority > second.sortPriority
    }
  }

  private var draftFollowUpItems: [DraftMessage] {
    let reviewDrafts = Array(store.draftMessagesNeedingReview.filter { store.isActiveWishlistDraft($0) }.prefix(6))
    let batchDrafts = wishlistBatchResearchDrafts.filter { draft in
      draft.status != .sentLocally || draft.reviewState != .accepted
    }
    return (batchDrafts + reviewDrafts).reduce(into: [DraftMessage]()) { result, draft in
      if !result.contains(where: { $0.id == draft.id }) {
        result.append(draft)
      }
    }
    .prefix(8)
    .map { $0 }
  }

  private var wishlistBatchResearchDrafts: [DraftMessage] {
    store.draftMessages.filter {
      $0.linkedEntityType == .wishlistItem && $0.linkedEntityID == "wishlist-research-batch"
    }
  }
  private var wishlistTaskContextItems: [WishlistItem] {
    store.wishlistItems.filter { item in
      store.isActiveWishlistItem(item) && (
        item.status.localizedCaseInsensitiveContains("purchase blocked")
        || item.status.localizedCaseInsensitiveContains("handoff")
        || item.status.localizedCaseInsensitiveContains("awaiting order")
        || item.status.localizedCaseInsensitiveContains("confirmation")
        || (item.purchaseReadiness ?? "").localizedCaseInsensitiveContains("blocker")
        || (item.purchaseReadiness ?? "").localizedCaseInsensitiveContains("review")
        || wishlistSellerEvidenceGapCount(for: item) > 0
        || wishlistNeedsPurchaseDecision(item)
        || !wishlistHandoffPackGaps(for: item).isEmpty
        || !wishlistHandoffSanityGaps(for: item).isEmpty
        || (item.purchaseHandoff != nil && item.purchaseHandoff?.linkedOrderID == nil)
      )
    }
  }
  private var wishlistLinkedQueueItems: [TaskQueueItem] {
    queueItems.filter { $0.linkedEntityType == .wishlistItem }
  }
  private var wishlistDraftItems: [DraftMessage] {
    store.draftMessages.filter {
      $0.linkedEntityType == .wishlistItem
        && store.isActiveWishlistDraft($0)
        && ($0.reviewState != .accepted || $0.status != .sentLocally || $0.linkedEntityID == "wishlist-research-batch")
    }
  }

  private var wishlistReadyPacketItems: [WishlistItem] {
    store.wishlistItems.filter { item in
      store.isActiveWishlistItem(item) && (
        item.operatorPurchaseBlockers.isEmpty
        || item.purchaseReadiness?.localizedCaseInsensitiveContains("ready") == true
        || item.purchaseDecision?.reviewState == .accepted
      )
    }
  }

  private var wishlistNeedsHandoffItems: [WishlistItem] {
    store.wishlistItems.filter { item in
      store.isActiveWishlistItem(item) && item.purchaseDecision?.reviewState == .accepted && item.purchaseHandoff == nil
    }
  }

  private var wishlistAwaitingOrderItems: [WishlistItem] {
    store.wishlistItems.filter { item in
      store.isActiveWishlistItem(item) && item.purchaseHandoff != nil && item.purchaseHandoff?.linkedOrderID == nil
    }
  }

  private var wishlistEvidenceGapCount: Int {
    wishlistTaskContextItems.reduce(0) { total, item in
      total + wishlistSellerEvidenceGapCount(for: item)
    }
  }

  private var wishlistDecisionGapCount: Int {
    wishlistTaskContextItems.filter(wishlistNeedsPurchaseDecision).count
  }

  private var wishlistHandoffGapCount: Int {
    wishlistTaskContextItems.reduce(0) { total, item in
      total + wishlistHandoffPackGaps(for: item).count
    }
  }

  private var wishlistHandoffSanityGapCount: Int {
    wishlistTaskContextItems.reduce(0) { total, item in
      total + wishlistHandoffSanityGaps(for: item).count
    }
  }

  private func wishlistSellerEvidenceGapCount(for item: WishlistItem) -> Int {
    (item.comparisonOptions ?? []).reduce(0) { total, option in
      total + option.operatorSellerEvidenceGaps.count
    }
  }

  private func wishlistNeedsPurchaseDecision(_ item: WishlistItem) -> Bool {
    let options = item.comparisonOptions ?? []
    guard !options.isEmpty else { return false }
    let checks = item.purchaseChecks ?? []
    let checksClear = !checks.isEmpty && !checks.contains { $0.status != "Passed" }
    return checksClear && item.purchaseDecision == nil
  }

  private func wishlistHandoffPackGaps(for item: WishlistItem) -> [String] {
    var gaps: [String] = []
    guard item.purchaseHandoff != nil
      || item.purchaseDecision?.reviewState == .accepted
      || item.status.localizedCaseInsensitiveContains("purchase")
      || item.status.localizedCaseInsensitiveContains("order confirmation") else {
      return gaps
    }
    if item.purchaseHandoff == nil { gaps.append("handoff") }
    if store.suggestedAccounts(for: item).isEmpty { gaps.append("account") }
    if store.suggestedCostRecords(for: item).isEmpty { gaps.append("cost") }
    if store.suggestedProcurementRequests(for: item).isEmpty { gaps.append("procurement") }
    if store.suggestedReceivingInspections(for: item).isEmpty { gaps.append("receiving") }
    if item.purchaseHandoff?.linkedOrderID == nil { gaps.append("order link") }
    return gaps
  }

  private func wishlistHandoffSanityGaps(for item: WishlistItem) -> [String] {
    guard item.purchaseHandoff != nil
      || item.purchaseDecision?.reviewState == .accepted
      || item.status.localizedCaseInsensitiveContains("purchase")
      || item.status.localizedCaseInsensitiveContains("order confirmation") else {
      return []
    }

    let handoff = item.purchaseHandoff
    let linkedOrder = handoff?.linkedOrderID.flatMap { orderID in
      store.orders.first { $0.id == orderID }
    }
    var gaps: [String] = []
    let seller = handoff?.sellerName ?? item.purchaseDecision?.selectedSellerName ?? item.storefront
    if seller.isPlaceholderValidationValue { gaps.append("seller route") }
    if handoff?.accountLabel.isPlaceholderValidationValue != false && store.suggestedAccounts(for: item).isEmpty {
      gaps.append("account label")
    }
    if handoff?.expectedOrderSignals.isPlaceholderValidationValue != false {
      gaps.append("order watch")
    }
    if store.suggestedCostRecords(for: item).isEmpty { gaps.append("cost") }
    if store.suggestedProcurementRequests(for: item).isEmpty { gaps.append("procurement") }
    if store.suggestedReceivingInspections(for: item).isEmpty { gaps.append("receiving") }
    if linkedOrder == nil && handoff?.purchaseStatus.localizedCaseInsensitiveContains("purchased") == true {
      gaps.append("order link")
    }
    return gaps
  }

  private var spaceMailHealthSummaries: [SpaceMailIntakeHealthSummary] {
    store.spaceMailIntakeHealthSummaries
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

  private var spaceMailDuplicateRefreshedCount: Int {
    spaceMailHealthSummaries.reduce(0) { $0 + $1.duplicateRefreshedCount }
  }

  private var spaceMailFilteredCount: Int {
    spaceMailHealthSummaries.reduce(0) { $0 + $1.filteredCount }
  }

  private var spaceMailUncertainCount: Int {
    spaceMailHealthSummaries.reduce(0) { $0 + $1.uncertainCount + $1.pendingUncertainReviewCount }
  }

  private var pendingFilteredSpaceMailCount: Int {
    spaceMailHealthSummaries.reduce(0) { $0 + $1.pendingFilteredReviewCount }
  }

  private var spaceMailParserIssueCount: Int {
    spaceMailHealthSummaries.reduce(0) { $0 + $1.parserIssueCount }
  }

  private var gmailHealthSummaries: [GmailIntakeHealthSummary] {
    store.gmailIntakeHealthSummaries
  }

  private var gmailFetchedCount: Int {
    gmailHealthSummaries.reduce(0) { $0 + $1.fetchedCount }
  }

  private var gmailImportedCount: Int {
    gmailHealthSummaries.reduce(0) { $0 + $1.importedCount }
  }

  private var gmailDuplicateRefreshedCount: Int {
    gmailHealthSummaries.reduce(0) { $0 + $1.duplicateRefreshedCount }
  }

  private var gmailFilteredCount: Int {
    max(gmailHealthSummaries.reduce(0) { $0 + $1.filteredCount }, pendingFilteredGmailCount)
  }

  private var gmailUncertainCount: Int {
    max(gmailHealthSummaries.reduce(0) { $0 + $1.uncertainCount + $1.pendingUncertainReviewCount }, pendingUncertainGmailCount)
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

  private var gmailClassifierHintCount: Int {
    store.gmailMailboxConnections.reduce(0) { total, connection in
      total
        + (connection.trustedSenderHints ?? []).count
        + (connection.importKeywordHints ?? []).count
        + (connection.uncertainKeywordHints ?? []).count
        + (connection.filterKeywordHints ?? []).count
    }
  }

  private var gmailClassifierTestIssueCount: Int {
    store.gmailMailboxConnections.reduce(0) { total, connection in
      total + (connection.classifierTestResults ?? []).filter {
        $0.decisionStatus.localizedCaseInsensitiveContains("needs review")
      }.count
    }
  }

  private var gmailClassifierTaskConnection: GmailMailboxConnection? {
    store.gmailMailboxConnections.first { connection in
      (connection.classifierTestResults ?? []).contains { $0.decisionStatus.localizedCaseInsensitiveContains("needs review") }
        || (connection.uncertainMessages?.isEmpty == false)
        || (connection.filteredMessages?.isEmpty == false)
    } ?? store.gmailMailboxConnections.first
  }

  private var gmailTaskReadinessConnection: GmailMailboxConnection? {
    gmailClassifierTaskConnection ?? store.gmailMailboxConnections.first
  }

  private var gmailTaskOAuthReadiness: GmailOAuthReadinessSummary? {
    gmailTaskReadinessConnection.map { store.gmailOAuthReadinessSummary(for: $0) }
  }

  private var gmailTaskCompileBlockers: [String] {
    guard let readiness = gmailTaskOAuthReadiness else { return [] }
    return readiness.missingFields.filter { field in
      field.localizedCaseInsensitiveContains("compiled App Info.plist")
        || field.localizedCaseInsensitiveContains("callback URL scheme matching")
        || field.localizedCaseInsensitiveContains("OAuth iOS client ID ending")
    }
  }

  private var gmailTaskCompileColor: Color {
    guard let readiness = gmailTaskOAuthReadiness else { return .secondary }
    return readiness.isReady ? .green : .orange
  }

  private var gmailTaskCompileTitle: String {
    guard let readiness = gmailTaskOAuthReadiness else { return "Gmail app setup is optional" }
    if readiness.isReady { return "Gmail app setup is ready" }
    if !gmailTaskCompileBlockers.isEmpty { return "Gmail app setup needs configuration before tasking refresh work" }
    return "Gmail readiness needs review before assigning refresh work"
  }

  private var gmailTaskCompileDetail: String {
    guard let readiness = gmailTaskOAuthReadiness else {
      return "Add Gmail setup only when a Google-hosted mailbox should feed Inbox. Use the provider that hosts the active mailbox."
    }
    if readiness.isReady {
      return "The saved Gmail setup matches the compiled client ID and callback scheme. Assign tasks only for named follow-up after sign-in, refresh, classifier review, or Inbox handoff."
    }
    if !gmailTaskCompileBlockers.isEmpty {
      return "Do not assign Gmail refresh work yet. Fix: \(gmailTaskCompileBlockers.joined(separator: "; ")). Update App/Info.plist and Project.json, rebuild, then retest Gmail readiness."
    }
    return readiness.detailText
  }

  private var pendingMailboxReviewCount: Int {
    spaceMailUncertainCount
      + pendingFilteredSpaceMailCount
      + pendingUncertainGmailCount
      + pendingFilteredGmailCount
  }

  private var gmailWarningCount: Int {
    gmailHealthSummaries.filter { $0.tone == "warning" || $0.tone == "attention" }.count
  }

  private var gmailSetupCount: Int {
    store.gmailMailboxConnections.count
  }

  private var gmailReadySetupCount: Int {
    store.gmailMailboxConnections.filter { store.gmailOAuthReadinessSummary(for: $0).isReady }.count
  }

  private var gmailConnectedAuthCount: Int {
    store.gmailMailboxConnections.filter { store.gmailAuthSessionState(for: $0).status == .connected }.count
  }

  private var gmailManualRefreshCount: Int {
    store.gmailMailboxConnections.filter { $0.lastManualRefreshDate != "Never" }.count
  }

  private var gmailReleaseSelfChecks: [GmailReleaseSelfCheckSummary] {
    store.gmailMailboxConnections.map { store.gmailReleaseSelfCheckSummary(for: $0) }
  }

  private var gmailReleaseBlockingCount: Int {
    gmailReleaseSelfChecks.reduce(0) { total, summary in
      total + summary.items.filter { !$0.isComplete && $0.tone == "warning" }.count
    }
  }

  private var gmailReleaseAttentionCount: Int {
    gmailReleaseSelfChecks.reduce(0) { total, summary in
      total + summary.items.filter { !$0.isComplete && $0.tone == "attention" }.count
    }
  }

  private var weakInboxParseCount: Int {
    store.reviewIntakeEmails.filter { email in
      email.detectedOrderNumber.isPlaceholderValidationValue
        || email.detectedTrackingNumber.isPlaceholderValidationValue
    }.count
  }

  private var readyInboxLinkCount: Int {
    store.reviewIntakeEmails.filter { email in
      email.linkedOrderID == nil
        && !email.detectedOrderNumber.isPlaceholderValidationValue
        && !email.detectedTrackingNumber.isPlaceholderValidationValue
    }.count
  }

  private var linkedInboxIntakeCount: Int {
    store.reviewIntakeEmails.filter { $0.linkedOrderID != nil }.count
  }

  private var mailboxFetchedCount: Int {
    spaceMailFetchedCount + gmailFetchedCount
  }

  private var mailboxImportedCount: Int {
    spaceMailImportedCount + gmailImportedCount
  }

  private var mailboxFilteredCount: Int {
    spaceMailFilteredCount + gmailFilteredCount
  }

  private var mailboxDuplicateRefreshedCount: Int {
    spaceMailDuplicateRefreshedCount + gmailDuplicateRefreshedCount
  }

  private var mailboxUncertainCount: Int {
    spaceMailUncertainCount + gmailUncertainCount
  }

  private var mailboxWarningCount: Int {
    gmailWarningCount + spaceMailParserIssueCount
  }

  private var mailboxTaskReadinessTone: Color {
    if mailboxWarningCount > 0 { return .orange }
    if mailboxUncertainCount > 0 || pendingMailboxReviewCount > 0 { return .teal }
    if mailboxImportedCount > 0 || readyInboxLinkCount > 0 { return .green }
    if mailboxDuplicateRefreshedCount > 0 { return .teal }
    if mailboxFilteredCount > 0 { return .teal }
    return .secondary
  }

  private var mailboxTaskReadinessTitle: String {
    if mailboxWarningCount > 0 { return "Mailbox setup or parser context needs review" }
    if mailboxUncertainCount > 0 || pendingMailboxReviewCount > 0 { return "Mailbox review belongs in Mailbox Monitor first" }
    if mailboxImportedCount > 0 || readyInboxLinkCount > 0 { return "Imported mailbox work belongs in Inbox first" }
    if mailboxDuplicateRefreshedCount > 0 { return "Duplicate refresh updated existing Inbox rows" }
    if mailboxFilteredCount > 0 { return "Mixed-mailbox filtering is keeping Tasks clean" }
    return "Mailbox intake has no task pressure"
  }

  private var mailboxTaskReadinessDetail: String {
    if mailboxWarningCount > 0 {
      return "\(mailboxWarningCount) mailbox warning or parser context item\(mailboxWarningCount == 1 ? "" : "s") should be checked before creating assigned task backlog."
    }
    if mailboxUncertainCount > 0 || pendingMailboxReviewCount > 0 {
      let count = max(mailboxUncertainCount, pendingMailboxReviewCount)
      return "\(count) uncertain or filtered message preview\(count == 1 ? "" : "s") are review context. Import or dismiss them locally before creating follow-up tasks."
    }
    if mailboxImportedCount > 0 || readyInboxLinkCount > 0 {
      let count = max(mailboxImportedCount, readyInboxLinkCount)
      return "\(count) mailbox intake item\(count == 1 ? "" : "s") should be triaged in Inbox and converted into orders before task ownership is needed."
    }
    if mailboxDuplicateRefreshedCount > 0 {
      return "\(mailboxDuplicateRefreshedCount) duplicate mailbox message\(mailboxDuplicateRefreshedCount == 1 ? "" : "s") refreshed existing Inbox rows. Create a task only if a refreshed row now needs named ownership."
    }
    if mailboxFilteredCount > 0 {
      return "\(mailboxFilteredCount) mixed-mailbox message\(mailboxFilteredCount == 1 ? "" : "s") were filtered out of Inbox, so they should not appear as task work unless manually promoted."
    }
    return "Manual mailbox refreshes have not produced assigned follow-up. Use Mailbox Monitor only when setup, refresh, or classifier checks are needed."
  }

  private var mailboxTaskRoutingItems: [(title: String, detail: String, symbol: String, color: Color)] {
    [
      (
        "Setup and refresh",
        "Use Mailbox Monitor for mailbox credentials, sign-in, labels, manual refresh, and classifier diagnostics.",
        "server.rack",
        mailboxWarningCount > 0 ? .orange : .teal
      ),
      (
        "Imported mail",
        "Use Inbox to review detected order fields and create or link local orders before assigning follow-up.",
        "tray.full.fill",
        mailboxImportedCount > 0 || readyInboxLinkCount > 0 ? .green : .secondary
      ),
      (
        "Uncertain mail",
        "Use Mailbox Monitor to import or dismiss uncertain previews. They stay out of Inbox until an operator chooses.",
        "questionmark.folder.fill",
        mailboxUncertainCount > 0 ? .orange : .secondary
      ),
      (
        "Assigned ownership",
        "Create Tasks only when a named owner, due date, blocker, or handoff is needed after mailbox review.",
        "checklist",
        intakeLinkedTaskItems.isEmpty ? .secondary : .purple
      )
    ]
  }

  private var intakeLinkedTaskItems: [TaskQueueItem] {
    queueItems.filter { item in
      item.linkedEntityType == .intakeEmail
        || item.title.localizedCaseInsensitiveContains("parser")
        || item.summary.localizedCaseInsensitiveContains("parser")
        || item.title.localizedCaseInsensitiveContains("intake")
        || item.summary.localizedCaseInsensitiveContains("intake")
    }
  }

  private var intakeParserTaskTone: Color {
    if intakeLinkedTaskItems.contains(where: \.isOverdue) || intakeLinkedTaskItems.contains(where: { $0.status == .blocked }) { return .red }
    if !intakeLinkedTaskItems.isEmpty { return .orange }
    if weakInboxParseCount > 0 || spaceMailParserIssueCount > 0 || !store.intakeParserDiagnostics.isEmpty { return .purple }
    return .green
  }

  private var intakeParserTaskTitle: String {
    if !intakeLinkedTaskItems.isEmpty { return "Inbox parser follow-up is assigned" }
    if weakInboxParseCount > 0 { return "Weak Inbox parses are not assigned yet" }
    if readyInboxLinkCount > 0 { return "Ready Inbox rows do not need tasks yet" }
    return "No Inbox parser task handoff is active"
  }

  private var intakeParserTaskDetail: String {
    if !intakeLinkedTaskItems.isEmpty {
      return "\(intakeLinkedTaskItems.count) task or handoff references intake/parser context. Work those assigned rows here, then use Inbox or Mailbox Monitor for source details."
    }
    if weakInboxParseCount > 0 {
      return "\(weakInboxParseCount) intake row\(weakInboxParseCount == 1 ? "" : "s") need parser correction in Inbox. Create a task only if someone must own the follow-up."
    }
    if readyInboxLinkCount > 0 {
      return "\(readyInboxLinkCount) intake row\(readyInboxLinkCount == 1 ? "" : "s") are ready to create or link orders. That is Inbox work, not task backlog unless ownership is needed."
    }
    return "Parser diagnostics and intake rows are either clear or remain as review context outside the assigned task queue."
  }

  private var spaceMailFilteredOnlyOutcome: Bool {
    spaceMailFetchedCount > 0
      && spaceMailImportedCount == 0
      && spaceMailUncertainCount == 0
      && spaceMailFilteredCount > 0
  }

  private var visibleDraftFollowUpItems: [DraftMessage] {
    let query = queueSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return draftFollowUpItems }
    return draftFollowUpItems.filter { draft in
      let linkedOrder = linkedOrder(for: draft)
      return [
        draft.subject,
        draft.body,
        draft.recipient,
        draft.channel.rawValue,
        draft.status.rawValue,
        draft.reviewState.rawValue,
        draft.linkedEntityType.rawValue,
        draft.linkedEntityID,
        linkedOrder?.orderNumber ?? "",
        linkedOrder?.store ?? "",
        linkedOrder?.customer ?? ""
      ].joined(separator: " ").localizedLowercase.contains(query)
    }
  }

  private var visibleQueueItems: [TaskQueueItem] {
    let query = queueSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return queueItems }
    return queueItems.filter { item in
      [
        item.title,
        item.summary,
        item.assignee,
        item.linkedEntityType.rawValue,
        item.linkedEntityID,
        item.sourceLabel
      ].joined(separator: " ").localizedLowercase.contains(query)
    }
  }

  private var mvpFollowUpItems: [TaskQueueItem] {
    queueItems.filter(\.isMVPFollowUp)
  }

  private var visibleMVPFollowUpItems: [TaskQueueItem] {
    let query = queueSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return mvpFollowUpItems }
    return mvpFollowUpItems.filter { item in
      [
        item.title,
        item.summary,
        item.assignee,
        item.linkedEntityID,
        item.nextAction
      ].joined(separator: " ").localizedLowercase.contains(query)
    }
  }

  private var releaseSnapshot: SpaceMailReleaseSnapshot {
    store.spaceMailReleaseSnapshot
  }

  private var releaseSnapshotTone: Color {
    switch releaseSnapshot.tone {
    case "success":
      return .green
    case "warning":
      return .orange
    case "attention":
      return .teal
    default:
      return .secondary
    }
  }

  private var openReleaseSnapshotTaskCount: Int {
    mvpFollowUpItems.filter { item in
      item.linkedEntityID == "spacemail-release-snapshot" && item.status != .completed
    }.count
  }

  private func linkedOrder(for draft: DraftMessage) -> TrackedOrder? {
    guard draft.linkedEntityType == .order,
      let orderID = UUID(uuidString: draft.linkedEntityID)
    else { return nil }
    return store.orders.first { $0.id == orderID }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        OperatorHandoffBriefCard(store: store, detail: "Summarize open follow-up before handing work to the next operator.")
        MailboxProviderReleaseGateCard(summary: store.mailboxProviderReleaseGateSummary, store: store, showTasksLink: false)
        MailboxProviderHandoffPacketCard(packet: store.mailboxProviderHandoffPacketSummary, store: store, showTasksLink: false)
        taskNextActionPanel
        taskResolutionLadderPanel
        taskScopePanel
        wishlistTaskContextPanel
        mailboxIntakeTaskReadinessPanel
        inboxParserTaskContextPanel
        gmailTaskContextPanel
        mvpValidationPanel
        mailboxProviderTaskPanel
        gmailAssignedFollowUpPanel
        spaceMailTaskEscalationPanel
        spaceMailAssignedFollowUpPanel
        draftFollowUpPanel
        mvpFollowUpPanel
        taskQueuePanel
        detailRoutes
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
    .background(.regularMaterial)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Tasks")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("A focused action queue for open follow-up tasks and shift handoffs.")
          .foregroundStyle(.secondary)
      }

      MetricStrip(items: [
        ("Queue", "\(queueItems.count)", .orange),
        ("Overdue", "\(queueItems.filter(\.isOverdue).count)", .red),
        ("Blocked", "\(queueItems.filter { $0.status == .blocked }.count)", .red),
        ("Urgent", "\(queueItems.filter { $0.priority == .urgent }.count)", .pink),
        ("Inbox orders", "\(inboxOrderActionCount)", inboxOrderActionCount == 0 ? .green : .teal),
        ("Drafts", "\(draftFollowUpItems.count)", draftFollowUpItems.isEmpty ? .green : .blue),
        ("Review", "\(queueItems.filter { $0.reviewState != .accepted }.count)", .purple)
      ])
    }
  }

  private var inboxOrderActionCount: Int {
    queueItems.filter { item in
      guard item.linkedEntityType == .order,
        let orderID = UUID(uuidString: item.linkedEntityID),
        let order = store.orders.first(where: { $0.id == orderID })
      else { return false }
      return order.isInboxCreatedLocalOrder
    }.count
  }

  private var wishlistTaskContextPanel: some View {
    SettingsPanel(title: "Wishlist task boundary", symbol: "star.square.fill") {
      VStack(alignment: .leading, spacing: 10) {
        Text("Wishlist purchase planning stays in Wishlist until a named owner, blocker, draft, or handoff needs follow-up. Use this panel to avoid turning every wanted item into task backlog.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Wishlist follow-up", "\(wishlistTaskContextItems.count)", wishlistTaskContextItems.isEmpty ? .green : .purple),
          ("Linked tasks", "\(wishlistLinkedQueueItems.count)", wishlistLinkedQueueItems.isEmpty ? .green : .orange),
          ("Drafts", "\(wishlistDraftItems.count)", wishlistDraftItems.isEmpty ? .green : .blue),
          ("Evidence gaps", "\(wishlistEvidenceGapCount)", wishlistEvidenceGapCount == 0 ? .green : .orange),
          ("Decision gaps", "\(wishlistDecisionGapCount)", wishlistDecisionGapCount == 0 ? .green : .purple),
          ("Handoff gaps", "\(wishlistHandoffGapCount)", wishlistHandoffGapCount == 0 ? .green : .orange),
          ("Sanity gaps", "\(wishlistHandoffSanityGapCount)", wishlistHandoffSanityGapCount == 0 ? .green : .orange),
          ("Ready packets", "\(wishlistReadyPacketItems.count)", wishlistReadyPacketItems.isEmpty ? .secondary : .green),
          ("Need handoff", "\(wishlistNeedsHandoffItems.count)", wishlistNeedsHandoffItems.isEmpty ? .green : .purple),
          ("Awaiting order", "\(wishlistAwaitingOrderItems.count)", wishlistAwaitingOrderItems.isEmpty ? .green : .orange),
          ("Blocked", "\(wishlistTaskContextItems.filter { $0.status.localizedCaseInsensitiveContains("blocked") }.count)", wishlistTaskContextItems.contains { $0.status.localizedCaseInsensitiveContains("blocked") } ? .red : .green)
        ])

        if wishlistTaskContextItems.isEmpty && wishlistLinkedQueueItems.isEmpty && wishlistDraftItems.isEmpty {
          Label("No Wishlist work is currently promoted into Tasks. Keep purchase comparison and readiness review in Wishlist until ownership is needed.", systemImage: "checkmark.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
        } else {
          ForEach(wishlistTaskContextItems.prefix(3)) { item in
            NavigationLink {
              WishlistView(store: store)
            } label: {
              CompactRow(
                title: item.itemName,
                detail: wishlistTaskContextDetail(for: item),
                badge: wishlistTaskContextBadge(for: item),
                color: wishlistTaskContextColor(for: item)
              )
            }
            .buttonStyle(.plain)
          }

          let packetRows = (wishlistNeedsHandoffItems + wishlistAwaitingOrderItems + wishlistReadyPacketItems)
            .reduce(into: [WishlistItem]()) { result, item in
              if !result.contains(where: { $0.id == item.id }) {
                result.append(item)
              }
            }
          if !packetRows.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
              Label("Purchase packet follow-up", systemImage: "doc.text.image.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.purple)
              ForEach(packetRows.prefix(3)) { item in
                NavigationLink {
                  WishlistView(store: store)
                } label: {
                  CompactRow(
                    title: item.itemName,
                    detail: wishlistPacketTaskDetail(for: item),
                    badge: wishlistPacketTaskBadge(for: item),
                    color: wishlistPacketTaskColor(for: item)
                  )
                }
                .buttonStyle(.plain)
              }
            }
            .padding(8)
            .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }

        CompactActionRow {
          NavigationLink {
            WishlistView(store: store)
          } label: {
            Label("Open Wishlist", systemImage: "star.square.fill")
          }
          NavigationLink {
            CommunicationView(store: store)
          } label: {
            Label("Open Drafts", systemImage: "envelope.open.fill")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private func wishlistPacketTaskBadge(for item: WishlistItem) -> String {
    if !wishlistHandoffSanityGaps(for: item).isEmpty { return "Sanity gaps" }
    if !wishlistHandoffPackGaps(for: item).isEmpty { return "Handoff gaps" }
    if wishlistNeedsPurchaseDecision(item) { return "Decision" }
    if wishlistSellerEvidenceGapCount(for: item) > 0 { return "Evidence" }
    if item.purchaseHandoff?.linkedOrderID != nil { return "Linked order" }
    if item.purchaseHandoff != nil { return "Order watch" }
    if item.purchaseDecision?.reviewState == .accepted { return "Handoff" }
    if item.operatorPurchaseBlockers.isEmpty { return "Ready" }
    return "Wishlist"
  }

  private func wishlistPacketTaskColor(for item: WishlistItem) -> Color {
    if !wishlistHandoffSanityGaps(for: item).isEmpty { return .orange }
    if !wishlistHandoffPackGaps(for: item).isEmpty { return .orange }
    if wishlistNeedsPurchaseDecision(item) { return .purple }
    if wishlistSellerEvidenceGapCount(for: item) > 0 { return .orange }
    if item.purchaseHandoff?.linkedOrderID != nil { return .green }
    if item.purchaseHandoff != nil { return .orange }
    if item.purchaseDecision?.reviewState == .accepted { return .purple }
    if item.operatorPurchaseBlockers.isEmpty { return .green }
    return .orange
  }

  private func wishlistPacketTaskDetail(for item: WishlistItem) -> String {
    let sanityGaps = wishlistHandoffSanityGaps(for: item)
    if !sanityGaps.isEmpty {
      return "Resolve handoff sanity before assigning purchase follow-up: \(sanityGaps.prefix(4).joined(separator: ", "))"
    }
    let handoffGaps = wishlistHandoffPackGaps(for: item)
    if !handoffGaps.isEmpty {
      return "Complete handoff pack: \(handoffGaps.prefix(4).joined(separator: ", "))"
    }
    if wishlistNeedsPurchaseDecision(item) {
      return "Ready for a local purchase decision before handoff."
    }
    let evidenceGaps = wishlistSellerEvidenceGaps(for: item)
    if !evidenceGaps.isEmpty {
      return "Seller evidence to check: \(evidenceGaps.prefix(4).joined(separator: ", "))"
    }
    let seller = item.purchaseHandoff?.sellerName
      ?? item.purchaseDecision?.selectedSellerName
      ?? item.preferredOptionID.flatMap { preferredID in
        item.comparisonOptions?.first { $0.id == preferredID }?.sellerName
      }
      ?? item.storefront
    let total = item.purchaseDecision?.totalAUDSummary
      ?? item.preferredOptionID.flatMap { preferredID in
        item.comparisonOptions?.first { $0.id == preferredID }?.estimatedAUDTotal
      }
      ?? item.estimatedCost
    return "\(seller) • \(total) • \(item.operatorPurchaseNextAction)"
  }

  private func wishlistTaskContextDetail(for item: WishlistItem) -> String {
    let evidenceGaps = wishlistSellerEvidenceGaps(for: item)
    if !evidenceGaps.isEmpty {
      return "\(item.status) • Seller evidence: \(evidenceGaps.prefix(3).joined(separator: ", "))"
    }
    if wishlistNeedsPurchaseDecision(item) {
      return "\(item.status) • Draft the local purchase decision before handoff."
    }
    let sanityGaps = wishlistHandoffSanityGaps(for: item)
    if !sanityGaps.isEmpty {
      return "\(item.status) • Handoff sanity: \(sanityGaps.prefix(3).joined(separator: ", "))"
    }
    let handoffGaps = wishlistHandoffPackGaps(for: item)
    if !handoffGaps.isEmpty {
      return "\(item.status) • Handoff pack: \(handoffGaps.prefix(3).joined(separator: ", "))"
    }
    return "\(item.status) • \(item.operatorPurchaseNextAction)"
  }

  private func wishlistTaskContextBadge(for item: WishlistItem) -> String {
    if !wishlistSellerEvidenceGaps(for: item).isEmpty { return "Evidence" }
    if wishlistNeedsPurchaseDecision(item) { return "Decision" }
    if !wishlistHandoffSanityGaps(for: item).isEmpty { return "Sanity gaps" }
    if !wishlistHandoffPackGaps(for: item).isEmpty { return "Handoff pack" }
    if item.purchaseHandoff != nil { return "Order watch" }
    return "Wishlist"
  }

  private func wishlistTaskContextColor(for item: WishlistItem) -> Color {
    if item.status.localizedCaseInsensitiveContains("blocked") { return .red }
    if !wishlistSellerEvidenceGaps(for: item).isEmpty { return .orange }
    if wishlistNeedsPurchaseDecision(item) { return .purple }
    if !wishlistHandoffSanityGaps(for: item).isEmpty { return .orange }
    if !wishlistHandoffPackGaps(for: item).isEmpty { return .orange }
    if item.purchaseHandoff != nil { return .teal }
    return item.operatorPurchaseBlockers.isEmpty ? .green : .purple
  }

  private func wishlistSellerEvidenceGaps(for item: WishlistItem) -> [String] {
    Array(Set((item.comparisonOptions ?? []).flatMap(\.operatorSellerEvidenceGaps))).sorted()
  }

  private var overdueActionCount: Int {
    queueItems.filter(\.isOverdue).count
  }

  private var blockedActionCount: Int {
    queueItems.filter { $0.status == .blocked }.count
  }

  private var urgentActionCount: Int {
    queueItems.filter { $0.priority == .urgent || $0.priority == .high }.count
  }

  private var handoffActionCount: Int {
    queueItems.filter { item in
      if case .handoff = item.source { return true }
      return false
    }.count
  }

  private var reviewActionCount: Int {
    queueItems.filter { $0.reviewState != .accepted }.count
  }

  private var draftActionCount: Int {
    draftFollowUpItems.count
  }

  private var taskAuditTrailCount: Int {
    store.auditEvents.filter { event in
      [
        event.entityType.rawValue,
        event.summary,
        event.action.rawValue
      ].joined(separator: " ").localizedCaseInsensitiveContains("task")
        || event.summary.localizedCaseInsensitiveContains("handoff")
        || event.summary.localizedCaseInsensitiveContains("draft")
    }.count
  }

  private var taskResolutionItems: [(title: String, detail: String, count: Int, destination: String, symbol: String, color: Color)] {
    [
      (
        "Overdue or blocked",
        "Open the row, resolve the blocker, reassign ownership, or create a draft/task so the follow-up is explicit.",
        overdueActionCount + blockedActionCount,
        "Tasks or Workbench",
        "exclamationmark.triangle.fill",
        overdueActionCount + blockedActionCount == 0 ? .green : .red
      ),
      (
        "High priority",
        "Handle urgent and high-priority tasks before routine handoffs or review-only rows.",
        urgentActionCount,
        "Tasks",
        "flag.fill",
        urgentActionCount == 0 ? .green : .orange
      ),
      (
        "Inbox order handoff",
        "Open the linked order, confirm the Inbox-created source trail and dispatch context, then complete the follow-up.",
        inboxOrderActionCount,
        "Orders",
        "shippingbox.fill",
        inboxOrderActionCount == 0 ? .green : .teal
      ),
      (
        "Shift handoff",
        "Acknowledge the note, complete it when the next owner has the context, or reopen it if the issue comes back.",
        handoffActionCount,
        "Tasks",
        "arrow.left.arrow.right.square.fill",
        handoffActionCount == 0 ? .green : .blue
      ),
      (
        "Draft follow-up",
        "Review local draft messages created from workflow actions and mark them ready, sent locally, or reopened.",
        draftActionCount,
        "Drafts",
        "envelope.open.fill",
        draftActionCount == 0 ? .green : .blue
      ),
      (
        "Review closure",
        "Read the row context and mark reviewed once the local evidence, order, or handoff state is clear.",
        reviewActionCount,
        "Tasks",
        "checkmark.shield.fill",
        reviewActionCount == 0 ? .green : .purple
      ),
      (
        "Audit trail",
        "Use Audit when the question is what changed, who acted locally, or why a task/draft/handoff exists.",
        taskAuditTrailCount,
        "Audit",
        "list.clipboard.fill",
        taskAuditTrailCount == 0 ? .secondary : .teal
      )
    ]
  }

  private var taskResolutionCompleteCount: Int {
    taskResolutionItems.filter { item in
      item.count == 0 || item.title == "Audit trail"
    }.count
  }

  private var nextActionTone: Color {
    if overdueActionCount > 0 || blockedActionCount > 0 { return .red }
    if urgentActionCount > 0 || inboxOrderActionCount > 0 { return .orange }
    if reviewActionCount > 0 { return .purple }
    if draftActionCount > 0 { return .blue }
    if !queueItems.isEmpty { return .teal }
    return .green
  }

  private var nextActionTitle: String {
    if overdueActionCount > 0 { return "Start with overdue follow-up" }
    if blockedActionCount > 0 { return "Clear blocked work first" }
    if urgentActionCount > 0 { return "Handle high-priority work" }
    if inboxOrderActionCount > 0 { return "Finish Inbox-created order handoffs" }
    if reviewActionCount > 0 { return "Review open task context" }
    if draftActionCount > 0 { return "Review draft messages" }
    if !queueItems.isEmpty { return "Work the open queue" }
    return "Task queue is clear"
  }

  private var nextActionDetail: String {
    if overdueActionCount > 0 {
      return "\(overdueActionCount) open task or handoff is overdue. Complete it, reassign it, or create a draft so the follow-up is visible."
    }
    if blockedActionCount > 0 {
      return "\(blockedActionCount) item is blocked. Open the row, resolve the blocker, or create a draft/task for the owner."
    }
    if urgentActionCount > 0 {
      return "\(urgentActionCount) high-priority item needs attention before routine handoffs."
    }
    if inboxOrderActionCount > 0 {
      return "\(inboxOrderActionCount) task is linked to an Inbox-created order. Open the order, confirm dispatch context, then complete the follow-up."
    }
    if reviewActionCount > 0 {
      return "\(reviewActionCount) item still needs local review. Check the row summary and mark reviewed once the context is clear."
    }
    if draftActionCount > 0 {
      return "\(draftActionCount) draft message was created from local workflow actions. Mark it ready, sent locally, or reopen it for follow-up."
    }
    if !queueItems.isEmpty {
      return "No overdue or blocked work is at the top of the queue. Continue completing open tasks and handoffs."
    }
    return "There are no open review tasks or handoff notes waiting for daily operator action."
  }

  private var taskNextActionPanel: some View {
    SettingsPanel(title: "Task next action", symbol: "arrow.forward.circle.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: nextActionTone == .green ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            .font(.title3)
            .foregroundStyle(nextActionTone)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text(nextActionTitle)
              .font(.headline)
            Text(nextActionDetail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }

        MetricStrip(items: [
          ("Overdue", "\(overdueActionCount)", overdueActionCount == 0 ? .green : .red),
          ("Blocked", "\(blockedActionCount)", blockedActionCount == 0 ? .green : .red),
          ("High priority", "\(urgentActionCount)", urgentActionCount == 0 ? .green : .orange),
          ("Handoffs", "\(handoffActionCount)", handoffActionCount == 0 ? .green : .blue),
          ("Drafts", "\(draftActionCount)", draftActionCount == 0 ? .green : .blue),
          ("Needs review", "\(reviewActionCount)", reviewActionCount == 0 ? .green : .purple)
        ])

        CompactActionRow {
          NavigationLink {
            OperationsWorkbenchView(store: store)
          } label: {
            Label("Open Workbench", systemImage: "rectangle.stack.badge.person.crop.fill")
          }
          .buttonStyle(.bordered)

          NavigationLink {
            CommunicationView(store: store)
          } label: {
            Label("Open Drafts", systemImage: "envelope.open.fill")
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

  private var taskResolutionLadderPanel: some View {
    SettingsPanel(title: "Task resolution ladder", symbol: "checklist.checked") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: taskResolutionCompleteCount == taskResolutionItems.count ? "checkmark.seal.fill" : "list.bullet.clipboard.fill")
            .foregroundStyle(taskResolutionCompleteCount == taskResolutionItems.count ? .green : .orange)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text("Clear follow-up in this order")
              .font(.headline)
            Text("Use this to decide why an item is still in the task queue and which primary screen should close the loop. It reads existing local tasks, handoffs, drafts, orders, and audit entries only.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Badge("\(taskResolutionCompleteCount)/\(taskResolutionItems.count)", color: taskResolutionCompleteCount == taskResolutionItems.count ? .green : .orange)
        }

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 160 : 215), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(taskResolutionItems, id: \.title) { item in
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
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(item.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }

        Text("Local boundary: this panel does not send email, run automation, fetch mail, mutate mailbox messages, call external services, or create records.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var taskScopePanel: some View {
    SettingsPanel(title: "Task scope", symbol: "checklist.checked") {
      VStack(alignment: .leading, spacing: 10) {
        Text("Tasks should represent work someone owns. Parser checks, filtered mailbox messages, and classifier diagnostics stay in Inbox, Mailbox Monitor, Workbench, and Audit unless a person creates a follow-up task from them.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Open tasks", "\(store.openReviewTasks.count)", store.openReviewTasks.isEmpty ? .green : .orange),
          ("Handoffs", "\(handoffActionCount)", handoffActionCount == 0 ? .green : .blue),
          ("Drafts", "\(draftActionCount)", draftActionCount == 0 ? .green : .blue),
          ("Parser context", "\(store.intakeParserDiagnostics.count)", store.intakeParserDiagnostics.isEmpty ? .green : .secondary),
          ("Mailbox review", "\(pendingMailboxReviewCount)", pendingMailboxReviewCount == 0 ? .secondary : .orange)
        ])

        Text(store.intakeParserDiagnostics.isEmpty && pendingMailboxReviewCount == 0
          ? "No parser or uncertain-mail context currently needs escalation into a task."
          : "Create a task only when parser or uncertain-mail context needs a named owner, due date, or handoff.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(store.intakeParserDiagnostics.isEmpty && pendingMailboxReviewCount == 0 ? .green : .orange)
          .fixedSize(horizontal: false, vertical: true)

        CompactActionRow {
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Open Inbox triage", systemImage: "tray.full.fill")
          }
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Open Mailbox Monitor", systemImage: "server.rack")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private var mailboxIntakeTaskReadinessPanel: some View {
    SettingsPanel(title: "Mailbox intake task readiness", symbol: "tray.and.arrow.down.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: mailboxTaskReadinessTone == .green ? "checkmark.circle.fill" : "arrow.triangle.branch")
            .font(.title3)
            .foregroundStyle(mailboxTaskReadinessTone)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text(mailboxTaskReadinessTitle)
              .font(.headline)
            Text(mailboxTaskReadinessDetail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        MetricStrip(items: [
          ("Fetched", "\(mailboxFetchedCount)", mailboxFetchedCount > 0 ? .blue : .secondary),
          ("Imported", "\(mailboxImportedCount)", mailboxImportedCount > 0 ? .green : .secondary),
          ("Refreshed", "\(mailboxDuplicateRefreshedCount)", mailboxDuplicateRefreshedCount > 0 ? .teal : .secondary),
          ("Ready Inbox", "\(readyInboxLinkCount)", readyInboxLinkCount > 0 ? .teal : .secondary),
          ("Uncertain", "\(mailboxUncertainCount)", mailboxUncertainCount > 0 ? .orange : .secondary),
          ("Filtered", "\(mailboxFilteredCount)", mailboxFilteredCount > 0 ? .teal : .secondary),
          ("Warnings", "\(mailboxWarningCount)", mailboxWarningCount > 0 ? .orange : .green),
          ("Assigned", "\(intakeLinkedTaskItems.count)", intakeLinkedTaskItems.isEmpty ? .secondary : .purple)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 190 : 230), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(Array(mailboxTaskRoutingItems.enumerated()), id: \.offset) { _, item in
            VStack(alignment: .leading, spacing: 6) {
              Label(item.title, systemImage: item.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(item.color)
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

        Text("This panel is a routing check, not an automation. ParcelOps still requires an operator to import, dismiss, link, create an order, or create a task locally.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(mailboxTaskReadinessTone)
          .fixedSize(horizontal: false, vertical: true)

        CompactActionRow {
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Mailbox Monitor", systemImage: "server.rack")
          }
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Inbox triage", systemImage: "tray.full.fill")
          }
          NavigationLink {
            OperationsWorkbenchView(store: store)
          } label: {
            Label("Workbench", systemImage: "rectangle.stack.badge.person.crop.fill")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private var inboxParserTaskContextPanel: some View {
    SettingsPanel(title: "Inbox parser task context", symbol: "text.magnifyingglass") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: intakeParserTaskTone == .green ? "checkmark.circle.fill" : "checklist")
            .font(.title3)
            .foregroundStyle(intakeParserTaskTone)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text(intakeParserTaskTitle)
              .font(.headline)
            Text(intakeParserTaskDetail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        MetricStrip(items: [
          ("Assigned", "\(intakeLinkedTaskItems.count)", intakeLinkedTaskItems.isEmpty ? .green : .orange),
          ("Overdue", "\(intakeLinkedTaskItems.filter(\.isOverdue).count)", intakeLinkedTaskItems.contains(where: \.isOverdue) ? .red : .green),
          ("Weak parse", "\(weakInboxParseCount)", weakInboxParseCount == 0 ? .green : .purple),
          ("Ready link", "\(readyInboxLinkCount)", readyInboxLinkCount == 0 ? .secondary : .teal),
          ("Linked", "\(linkedInboxIntakeCount)", linkedInboxIntakeCount == 0 ? .secondary : .green),
          ("Parser checks", "\(store.intakeParserDiagnostics.count)", store.intakeParserDiagnostics.isEmpty ? .green : .purple)
        ])

        Text("This panel does not create tasks automatically. It separates parser context from assigned ownership so Tasks stays focused on work a person must complete.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        if !intakeLinkedTaskItems.isEmpty {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 190 : 250), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(intakeLinkedTaskItems.prefix(4)) { item in
              VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                  Label(item.sourceLabel, systemImage: item.source.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.decisionColor)
                  Spacer()
                  Badge(item.decisionBadge, color: item.decisionColor)
                }
                Text(item.title)
                  .font(.caption.weight(.semibold))
                  .lineLimit(2)
                Text(item.nextAction)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
              .padding(10)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(item.decisionColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }

        CompactActionRow {
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Open Inbox triage", systemImage: "tray.full.fill")
          }
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Open Mailbox diagnostics", systemImage: "server.rack")
          }
          NavigationLink {
            OperationsWorkbenchView(store: store)
          } label: {
            Label("Open Workbench", systemImage: "rectangle.stack.badge.person.crop.fill")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private var gmailTaskContextPanel: some View {
    SettingsPanel(title: "Gmail task context", symbol: "envelope.badge.shield.half.filled") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: gmailTaskContextSymbol)
            .font(.title3)
            .foregroundStyle(gmailTaskContextColor)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text(gmailTaskContextTitle)
              .font(.headline)
            Text(gmailTaskContextDetail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        MetricStrip(items: [
          ("Fetched", "\(gmailFetchedCount)", gmailFetchedCount > 0 ? .blue : .secondary),
          ("Imported", "\(gmailImportedCount)", gmailImportedCount > 0 ? .green : .secondary),
          ("Filtered review", "\(pendingFilteredGmailCount)", pendingFilteredGmailCount > 0 ? .teal : .secondary),
          ("Uncertain", "\(pendingUncertainGmailCount)", pendingUncertainGmailCount > 0 ? .orange : .secondary),
          ("Warnings", "\(gmailWarningCount)", gmailWarningCount > 0 ? .orange : .green),
          ("Classifier issues", "\(gmailClassifierTestIssueCount)", gmailClassifierTestIssueCount > 0 ? .orange : .green)
        ])

        MetricStrip(items: [
          ("Setups", "\(gmailSetupCount)", gmailSetupCount > 0 ? .blue : .secondary),
          ("Ready", "\(gmailReadySetupCount)", gmailReadySetupCount == gmailSetupCount && gmailSetupCount > 0 ? .green : gmailSetupCount > 0 ? .orange : .secondary),
          ("Signed in", "\(gmailConnectedAuthCount)", gmailConnectedAuthCount > 0 ? .green : gmailSetupCount > 0 ? .orange : .secondary),
          ("Refresh seen", "\(gmailManualRefreshCount)", gmailManualRefreshCount > 0 ? .green : gmailConnectedAuthCount > 0 ? .orange : .secondary),
          ("Release blockers", "\(gmailReleaseBlockingCount)", gmailReleaseBlockingCount > 0 ? .red : .green),
          ("Release attention", "\(gmailReleaseAttentionCount)", gmailReleaseAttentionCount > 0 ? .orange : .green)
        ])

        if gmailSetupCount > 0 && (gmailReadySetupCount < gmailSetupCount || gmailConnectedAuthCount == 0 || gmailManualRefreshCount == 0) {
          Label(gmailReadinessTaskHint, systemImage: "arrow.triangle.2.circlepath.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        if gmailSetupCount > 0 {
          VStack(alignment: .leading, spacing: 6) {
            Label(gmailTaskCompileTitle, systemImage: gmailTaskOAuthReadiness?.isReady == true ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
              .font(.caption.weight(.semibold))
              .foregroundStyle(gmailTaskCompileColor)
            Text(gmailTaskCompileDetail)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            if let readiness = gmailTaskOAuthReadiness {
              CompactMetadataGrid(minimumWidth: horizontalSizeClass == .compact ? 150 : 175) {
                Badge(readiness.compiledClientIDStatus, color: readiness.compiledClientIDStatus.localizedCaseInsensitiveContains("matches") || readiness.compiledClientIDStatus.localizedCaseInsensitiveContains("present") ? .green : .orange)
                Badge(readiness.compiledCallbackSchemeStatus, color: readiness.compiledCallbackSchemeStatus.localizedCaseInsensitiveContains("includes") || readiness.compiledCallbackSchemeStatus.localizedCaseInsensitiveContains("present") ? .green : .orange)
                Badge(readiness.expectedCallbackScheme, color: .secondary)
              }
            }
          }
          .padding(10)
          .background(gmailTaskCompileColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        if !gmailHealthSummaries.isEmpty {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 190 : 250), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(gmailHealthSummaries.prefix(3)) { summary in
              VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                  Text(summary.displayName)
                    .font(.caption.weight(.semibold))
                  Spacer()
                  Badge(summary.verdict, color: gmailToneColor(summary.tone))
                }
                Text(summary.detail)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
                Text(summary.nextAction)
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(gmailToneColor(summary.tone))
                  .fixedSize(horizontal: false, vertical: true)
              }
              .padding(10)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(gmailToneColor(summary.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }

        GmailPostRefreshActionCard(plan: store.gmailPostRefreshActionPlan)
        GmailShiftHandoffCard(summary: store.gmailShiftHandoffSummary)

        gmailTaskReadinessPanel

        Text("Gmail refresh and sign-in are explicit Mailbox Monitor actions. Filtered and uncertain Gmail previews are review context first, not assigned backlog.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        if gmailSetupCount > 0 {
          VStack(alignment: .leading, spacing: 6) {
            Label(gmailClassifierTaskTitle, systemImage: "slider.horizontal.3")
              .font(.caption.weight(.semibold))
              .foregroundStyle(gmailClassifierTestIssueCount > 0 || pendingUncertainGmailCount > 0 ? .orange : .teal)
            Text(gmailClassifierTaskDetail)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            MetricStrip(items: [
              ("Hints", "\(gmailClassifierHintCount)", gmailClassifierHintCount > 0 ? .teal : .secondary),
              ("Test issues", "\(gmailClassifierTestIssueCount)", gmailClassifierTestIssueCount > 0 ? .orange : .green),
              ("Uncertain", "\(pendingUncertainGmailCount)", pendingUncertainGmailCount > 0 ? .orange : .secondary),
              ("Filtered review", "\(pendingFilteredGmailCount)", pendingFilteredGmailCount > 0 ? .teal : .secondary)
            ])
          }
          .padding(10)
          .background((gmailClassifierTestIssueCount > 0 || pendingUncertainGmailCount > 0 ? Color.orange : Color.teal).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        CompactActionRow {
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Open Gmail setup", systemImage: "server.rack")
          }
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Open Inbox triage", systemImage: "tray.full.fill")
          }
          if let connection = gmailClassifierTaskConnection {
            Button("Create tuning task", systemImage: "checklist") {
              store.createReviewTaskFromGmailClassifierTuning(connection)
              mvpFeedbackMessage = "Gmail classifier tuning task created or refreshed."
            }
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private var gmailTaskReadinessPanel: some View {
    GmailReleaseBoundaryPanel(
      store: store,
      title: "Gmail task readiness",
      lead: "Create a task from the release self-check only when Gmail setup, labels, sign-in, classifier review, Inbox handoff, or audit evidence needs a named owner.",
      sourceMetricTitle: "Task signals",
      sourceCount: pendingUncertainGmailCount + pendingFilteredGmailCount + gmailWarningCount,
      boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store token values, assign tasks automatically, or mutate mailbox messages.",
      showTasksLink: false
    )
  }

  private var gmailTaskContextDetail: String {
    if gmailHealthSummaries.isEmpty {
      return "No Gmail setup exists yet. Add one only for mailboxes hosted by Gmail or Google Workspace."
    }
    if pendingUncertainGmailCount > 0 {
      return "\(pendingUncertainGmailCount) Gmail message\(pendingUncertainGmailCount == 1 ? "" : "s") are held outside Inbox as uncertain. Review them in Mailbox Monitor before creating tasks or orders."
    }
    if pendingFilteredGmailCount > 0 {
      return "\(pendingFilteredGmailCount) filtered Gmail example\(pendingFilteredGmailCount == 1 ? "" : "s") can be reviewed in Mailbox Monitor. Create a task only if a person must follow up on one."
    }
    if gmailReleaseBlockingCount > 0 || gmailReleaseAttentionCount > 0 {
      let count = gmailReleaseBlockingCount + gmailReleaseAttentionCount
      return "\(count) Gmail release self-check item\(count == 1 ? "" : "s") need setup, refresh, classifier, Inbox handoff, or audit evidence before Gmail is treated as daily intake."
    }
    if gmailWarningCount > 0 {
      return "\(gmailWarningCount) Gmail setup or refresh result needs mailbox review before it should become assigned task work."
    }
    if gmailImportedCount > 0 {
      return "\(gmailImportedCount) Gmail message\(gmailImportedCount == 1 ? "" : "s") reached Inbox. Review triage there before creating task backlog."
    }
    if gmailFilteredCount > 0 {
      return "The mixed Gmail filter kept \(gmailFilteredCount) non-order message\(gmailFilteredCount == 1 ? "" : "s") out of Inbox."
    }
    return "Use Mailbox Monitor for Gmail setup/readiness; no Gmail result currently requires assigned follow-up."
  }

  private var gmailTaskContextTitle: String {
    if pendingUncertainGmailCount > 0 { return "Gmail uncertain mail needs review" }
    if pendingFilteredGmailCount > 0 { return "Gmail filtered examples are reviewable" }
    if gmailReleaseBlockingCount > 0 { return "Gmail release checks have blockers" }
    if gmailReleaseAttentionCount > 0 { return "Gmail release checks need attention" }
    if gmailWarningCount > 0 { return "Gmail setup or intake needs review" }
    return "Gmail has no assigned task pressure"
  }

  private var gmailClassifierTaskTitle: String {
    if gmailClassifierTestIssueCount > 0 { return "Gmail classifier task can capture failing tests" }
    if pendingUncertainGmailCount > 0 { return "Gmail uncertain review can be assigned" }
    if pendingFilteredGmailCount > 0 { return "Gmail filtered review can be assigned if needed" }
    if gmailClassifierHintCount > 0 { return "Gmail hints are ready for suite verification" }
    return "Gmail classifier task is optional"
  }

  private var gmailClassifierTaskDetail: String {
    if gmailClassifierTestIssueCount > 0 {
      return "\(gmailClassifierTestIssueCount) Gmail classifier test\(gmailClassifierTestIssueCount == 1 ? "" : "s") need review. Create one task when someone should own hint tuning and suite verification."
    }
    if pendingUncertainGmailCount > 0 {
      return "\(pendingUncertainGmailCount) uncertain Gmail preview\(pendingUncertainGmailCount == 1 ? "" : "s") are waiting outside Inbox. Create a task only if this needs a named owner."
    }
    if pendingFilteredGmailCount > 0 {
      return "\(pendingFilteredGmailCount) filtered Gmail preview\(pendingFilteredGmailCount == 1 ? "" : "s") are reviewable. Assign this only when an expected order may have been filtered."
    }
    if gmailClassifierHintCount > 0 {
      return "\(gmailClassifierHintCount) local Gmail hint\(gmailClassifierHintCount == 1 ? "" : "s") are saved. Create a task if someone should run the classifier suite and confirm the result."
    }
    return "No Gmail classifier issue requires assigned ownership right now."
  }

  private var gmailReadinessTaskHint: String {
    if !gmailTaskCompileBlockers.isEmpty {
      return "Fix the compiled Gmail client ID and callback scheme before assigning refresh follow-up."
    }
    if gmailReadySetupCount < gmailSetupCount {
      return "Finish Gmail setup and callback readiness before assigning refresh follow-up."
    }
    if gmailConnectedAuthCount == 0 {
      return "Run Test real Google sign-in in Mailbox Monitor before assigning real Gmail refresh work."
    }
    if gmailManualRefreshCount == 0 {
      return "Run one manual read-only Gmail refresh before treating Gmail as a live intake source."
    }
    return "Review Gmail setup and refresh evidence in Mailbox Monitor before assigning follow-up."
  }

  private var gmailTaskContextSymbol: String {
    if pendingUncertainGmailCount > 0 || gmailWarningCount > 0 { return "exclamationmark.triangle.fill" }
    if gmailReleaseBlockingCount > 0 || gmailReleaseAttentionCount > 0 { return "exclamationmark.shield.fill" }
    if pendingFilteredGmailCount > 0 { return "line.3.horizontal.decrease.circle.fill" }
    return "checkmark.circle.fill"
  }

  private var gmailTaskContextColor: Color {
    if pendingUncertainGmailCount > 0 || gmailWarningCount > 0 { return .orange }
    if gmailReleaseBlockingCount > 0 { return .red }
    if gmailReleaseAttentionCount > 0 { return .orange }
    if pendingFilteredGmailCount > 0 { return .teal }
    return .green
  }

  private func gmailToneColor(_ tone: String) -> Color {
    switch tone {
    case "success":
      return .green
    case "warning":
      return .orange
    case "attention":
      return .teal
    default:
      return .secondary
    }
  }

  private var mvpValidationPanel: some View {
    SettingsPanel(title: "MVP validation follow-up", symbol: "checkmark.seal.text.page.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: openReleaseSnapshotTaskCount > 0 ? "checklist.checked" : "doc.badge.plus")
            .font(.title3)
            .foregroundStyle(releaseSnapshotTone)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text(openReleaseSnapshotTaskCount > 0 ? "Release snapshot task is active" : "Create a release snapshot task when QA starts")
              .font(.headline)
            Text(openReleaseSnapshotTaskCount > 0
              ? "The SpaceMail MVP release snapshot has an open task in this queue. Refresh it when setup or test evidence changes."
              : "Use this to turn the current MVP snapshot into owned work before a hands-on test session.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer()
          Badge(releaseSnapshot.tone.capitalized, color: releaseSnapshotTone)
        }

        MetricStrip(items: releaseSnapshot.metrics.map { metric in
          (metric.title, metric.value, taskMetricColor(for: metric.tone))
        })

        Text(releaseSnapshot.detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        CompactActionRow {
          Button(openReleaseSnapshotTaskCount > 0 ? "Refresh QA task" : "Create QA task", systemImage: "checklist") {
            store.createReviewTaskFromSpaceMailReleaseSnapshot()
            mvpFeedbackMessage = openReleaseSnapshotTaskCount > 0
              ? "Existing release snapshot task refreshed from current local state."
              : "Release snapshot QA task created. It now appears in the MVP follow-up section."
          }
          .buttonStyle(.borderedProminent)

          NavigationLink {
            MVPSetupView(store: store)
          } label: {
            Label("MVP Setup", systemImage: "wrench.and.screwdriver.fill")
          }
          .buttonStyle(.bordered)

          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Audit", systemImage: "list.clipboard.fill")
          }
          .buttonStyle(.bordered)
        }

        if let mvpFeedbackMessage {
          Label(mvpFeedbackMessage, systemImage: "checkmark.circle.fill")
            .font(.caption)
            .foregroundStyle(.green)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }
    }
  }

  private func taskMetricColor(for tone: String) -> Color {
    switch tone {
    case "success":
      return .green
    case "warning":
      return .orange
    case "attention":
      return .teal
    default:
      return .secondary
    }
  }

  private var spaceMailTaskEscalationPanel: some View {
    SettingsPanel(title: "Mailbox-to-task boundary", symbol: "tray.and.arrow.down.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: mailboxTaskEscalationSymbol)
            .font(.title3)
            .foregroundStyle(mailboxTaskEscalationTone)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text(mailboxTaskEscalationTitle)
              .font(.headline)
            Text(mailboxTaskEscalationDetail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        MetricStrip(items: [
          ("Fetched", "\(mailboxFetchedCount)", mailboxFetchedCount == 0 ? .secondary : .blue),
          ("Imported", "\(mailboxImportedCount)", mailboxImportedCount == 0 ? .secondary : .green),
          ("Refreshed", "\(mailboxDuplicateRefreshedCount)", mailboxDuplicateRefreshedCount == 0 ? .secondary : .teal),
          ("Uncertain", "\(mailboxUncertainCount)", mailboxUncertainCount == 0 ? .secondary : .orange),
          ("Filtered", "\(mailboxFilteredCount)", mailboxFilteredCount == 0 ? .secondary : .teal),
          ("Filtered review", "\(pendingMailboxReviewCount)", pendingMailboxReviewCount == 0 ? .secondary : .teal),
          ("Diagnostics", "\(mailboxWarningCount)", mailboxWarningCount == 0 ? .secondary : .orange),
          ("Task links", "\(mailboxLinkedTaskCount)", mailboxLinkedTaskCount == 0 ? .secondary : .purple)
        ])

        SpaceMailPostRefreshActionCard(plan: spaceMailPostRefreshPlan)
        SpaceMailShiftHandoffCard(summary: store.spaceMailShiftHandoffSummary)

        Text("Create a task only when a person must own the follow-up. Imported order mail starts in Inbox, uncertain mail starts in Mailbox Monitor, and filtered mixed-mailbox examples stay out of Tasks unless manually promoted or converted into follow-up.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(mailboxTaskEscalationTone)
          .fixedSize(horizontal: false, vertical: true)

        CompactActionRow {
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Review imported mail", systemImage: "tray.full.fill")
          }
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label(mailboxUncertainCount > 0 || pendingMailboxReviewCount > 0 ? "Review mailbox examples" : "Open Mailbox Monitor", systemImage: "server.rack")
          }
          NavigationLink {
            OperationsWorkbenchView(store: store)
          } label: {
            Label("Open Workbench", systemImage: "rectangle.stack.badge.person.crop.fill")
          }
          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Check Audit", systemImage: "list.clipboard.fill")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private var mailboxLinkedTaskCount: Int {
    queueItems.filter { item in
      item.linkedEntityType == .intakeEmail
        || item.isSpaceMailFollowUp
        || item.isGmailFollowUp
        || item.isMailboxProviderFollowUp
        || item.summary.localizedCaseInsensitiveContains("spacemail")
        || item.title.localizedCaseInsensitiveContains("spacemail")
        || item.summary.localizedCaseInsensitiveContains("gmail")
        || item.title.localizedCaseInsensitiveContains("gmail")
        || item.summary.localizedCaseInsensitiveContains("mailbox")
        || item.title.localizedCaseInsensitiveContains("mailbox")
        || item.summary.localizedCaseInsensitiveContains("intake")
    }.count
  }

  private var mailboxProviderFollowUpItems: [TaskQueueItem] {
    queueItems.filter { item in
      item.isMailboxProviderFollowUp && !item.isGmailFollowUp
    }
  }

  @ViewBuilder
  private var mailboxProviderTaskPanel: some View {
    if !mailboxProviderFollowUpItems.isEmpty {
      SettingsPanel(title: "Mailbox provider follow-up", symbol: "checkmark.seal.fill") {
        VStack(alignment: .leading, spacing: 12) {
          Text("These tasks were created from provider release gates, provider test queues, handoff packets, troubleshooting, or mailbox release readiness. Use the release gate and Mailbox Monitor before closing them.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          MetricStrip(items: [
            ("Provider tasks", "\(mailboxProviderFollowUpItems.count)", .purple),
            ("Overdue", "\(mailboxProviderFollowUpItems.filter(\.isOverdue).count)", mailboxProviderFollowUpItems.contains(where: \.isOverdue) ? .red : .green),
            ("Blocked", "\(mailboxProviderFollowUpItems.filter { $0.status == .blocked }.count)", mailboxProviderFollowUpItems.contains { $0.status == .blocked } ? .red : .green),
            ("Needs review", "\(mailboxProviderFollowUpItems.filter { $0.reviewState != .accepted }.count)", mailboxProviderFollowUpItems.contains { $0.reviewState != .accepted } ? .orange : .green)
          ])

          ForEach(mailboxProviderFollowUpItems.prefix(4)) { item in
            TaskQueueRow(item: item, store: store)
          }

          CompactActionRow {
            NavigationLink {
              MailboxView(store: store)
            } label: {
              Label("Mailbox Monitor", systemImage: "server.rack")
            }
            NavigationLink {
              OperationsWorkbenchView(store: store)
            } label: {
              Label("Workbench", systemImage: "rectangle.stack.badge.person.crop.fill")
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
  }

  private var gmailAssignedFollowUpItems: [TaskQueueItem] {
    queueItems.filter { item in
      item.isGmailFollowUp
    }
  }

  @ViewBuilder
  private var gmailAssignedFollowUpPanel: some View {
    if !gmailAssignedFollowUpItems.isEmpty {
      SettingsPanel(title: "Gmail assigned follow-up", symbol: "envelope.badge.shield.half.filled") {
        VStack(alignment: .leading, spacing: 12) {
          Text("These tasks or handoffs reference Gmail setup, Google sign-in, Gmail refresh, classifier review, or Gmail provider release checks. Use Mailbox Monitor for the source evidence, then complete the assigned work here.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          MetricStrip(items: [
            ("Assigned", "\(gmailAssignedFollowUpItems.count)", .purple),
            ("Overdue", "\(gmailAssignedFollowUpItems.filter(\.isOverdue).count)", gmailAssignedFollowUpItems.contains(where: \.isOverdue) ? .red : .green),
            ("Blocked", "\(gmailAssignedFollowUpItems.filter { $0.status == .blocked }.count)", gmailAssignedFollowUpItems.contains { $0.status == .blocked } ? .red : .green),
            ("Needs review", "\(gmailAssignedFollowUpItems.filter { $0.reviewState != .accepted }.count)", gmailAssignedFollowUpItems.contains { $0.reviewState != .accepted } ? .orange : .green)
          ])

          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 190 : 250), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(gmailAssignedFollowUpItems.prefix(4)) { item in
              VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                  Label(item.sourceLabel, systemImage: item.source.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.priority.color)
                  Spacer()
                  Badge(item.status.rawValue, color: item.status.color)
                }
                Text(item.title)
                  .font(.caption.weight(.semibold))
                  .lineLimit(2)
                Text(item.nextAction)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
              .padding(10)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(item.priority.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }

          CompactActionRow {
            NavigationLink {
              MailboxView(store: store)
            } label: {
              Label("Open Mailbox Monitor", systemImage: "server.rack")
            }
            NavigationLink {
              IntegrationsView(store: store)
            } label: {
              Label("Open Settings", systemImage: "gearshape.2.fill")
            }
            NavigationLink {
              AuditView(store: store)
            } label: {
              Label("Check Audit trail", systemImage: "list.clipboard.fill")
            }
          }
          .buttonStyle(.bordered)

          Text("Gmail follow-up remains local operator work. This panel does not open Google sign-in, fetch Gmail, store token values, or change mailbox messages.")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }

  private var spaceMailAssignedFollowUpItems: [TaskQueueItem] {
    queueItems.filter { item in
      item.isSpaceMailFollowUp
    }
  }

  @ViewBuilder
  private var spaceMailAssignedFollowUpPanel: some View {
    if !spaceMailAssignedFollowUpItems.isEmpty {
      SettingsPanel(title: "SpaceMail assigned follow-up", symbol: "person.2.wave.2.fill") {
        VStack(alignment: .leading, spacing: 12) {
          Text("These tasks or handoffs were created from SpaceMail intake, classifier review, or shift handoff context. Use Mailbox Monitor for the source refresh state, then complete the assigned work here.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          MetricStrip(items: [
            ("Assigned", "\(spaceMailAssignedFollowUpItems.count)", .purple),
            ("Overdue", "\(spaceMailAssignedFollowUpItems.filter(\.isOverdue).count)", spaceMailAssignedFollowUpItems.contains(where: \.isOverdue) ? .red : .green),
            ("Handoffs", "\(spaceMailAssignedFollowUpItems.filter { if case .handoff = $0.source { return true }; return false }.count)", .blue),
            ("Tasks", "\(spaceMailAssignedFollowUpItems.filter { if case .task = $0.source { return true }; return false }.count)", .orange)
          ])

          SpaceMailShiftHandoffCard(summary: store.spaceMailShiftHandoffSummary)

          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 190 : 250), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(spaceMailAssignedFollowUpItems.prefix(4)) { item in
              VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                  Label(item.sourceLabel, systemImage: item.source.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.priority.color)
                  Spacer()
                  Badge(item.status.rawValue, color: item.status.color)
                }
                Text(item.title)
                  .font(.caption.weight(.semibold))
                  .lineLimit(2)
                Text(item.nextAction)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
              .padding(10)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(item.priority.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }

          CompactActionRow {
            NavigationLink {
              MailboxView(store: store)
            } label: {
              Label("Open Mailbox Monitor", systemImage: "server.rack")
            }
            NavigationLink {
              AuditView(store: store)
            } label: {
              Label("Check Audit trail", systemImage: "list.clipboard.fill")
            }
          }
          .buttonStyle(.bordered)
        }
      }
    }
  }

  private var mailboxTaskEscalationTitle: String {
    if mailboxLinkedTaskCount > 0 { return "Mailbox follow-up is assigned" }
    if mailboxImportedCount > 0 { return "Imported mail is waiting in Inbox" }
    if mailboxUncertainCount > 0 { return "Uncertain mail needs mailbox review" }
    if mailboxWarningCount > 0 { return "Mailbox diagnostics may need ownership" }
    if mailboxDuplicateRefreshedCount > 0 { return "Duplicate refresh stayed out of task backlog" }
    if mailboxFilteredCount > 0 && mailboxImportedCount == 0 && mailboxUncertainCount == 0 { return "Filtered mail did not create tasks" }
    if mailboxFetchedCount > 0 { return "Latest refresh did not create task work" }
    return "Mailbox task escalation is clear"
  }

  private var mailboxTaskEscalationDetail: String {
    if mailboxLinkedTaskCount > 0 {
      return "\(mailboxLinkedTaskCount) task or handoff references mailbox intake, provider setup, or forwarded-email context. Work those rows from the queue below."
    }
    if mailboxImportedCount > 0 {
      return "\(mailboxImportedCount) likely order message reached Inbox. Create a task only if review needs a named owner or due date."
    }
    if mailboxUncertainCount > 0 {
      return "\(mailboxUncertainCount) ambiguous mailbox preview is waiting outside Inbox. Import it, dismiss it, or create a task from Mailbox Monitor if someone must investigate."
    }
    if mailboxWarningCount > 0 {
      return "\(mailboxWarningCount) mailbox diagnostic is present. Keep it as diagnostic context unless it needs assigned follow-up."
    }
    if mailboxDuplicateRefreshedCount > 0 {
      return "\(mailboxDuplicateRefreshedCount) duplicate mailbox message refreshed an existing Inbox row. That should remain Inbox review unless a person needs to own follow-up."
    }
    if mailboxFilteredCount > 0 && mailboxImportedCount == 0 && mailboxUncertainCount == 0 {
      return "\(mailboxFilteredCount) mixed-mailbox message was filtered out. That is a normal non-order outcome, not task backlog."
    }
    if mailboxFetchedCount > 0 {
      return "Mailbox refresh fetched mail but did not produce imported, uncertain, diagnostic, or assigned follow-up work."
    }
    return "Run manual mailbox refresh from Mailbox Monitor when you need new intake; Tasks should remain focused on assigned work."
  }

  private var mailboxTaskEscalationTone: Color {
    if mailboxLinkedTaskCount > 0 || mailboxImportedCount > 0 || mailboxUncertainCount > 0 { return .orange }
    if mailboxWarningCount > 0 { return .purple }
    if mailboxDuplicateRefreshedCount > 0 { return .teal }
    if mailboxFilteredCount > 0 && mailboxImportedCount == 0 && mailboxUncertainCount == 0 { return .green }
    if mailboxFetchedCount > 0 { return .teal }
    return .secondary
  }

  private var mailboxTaskEscalationSymbol: String {
    if mailboxLinkedTaskCount > 0 { return "checklist" }
    if mailboxImportedCount > 0 { return "tray.full.fill" }
    if mailboxUncertainCount > 0 { return "questionmark.folder.fill" }
    if mailboxWarningCount > 0 { return "text.magnifyingglass" }
    if mailboxDuplicateRefreshedCount > 0 { return "arrow.triangle.2.circlepath" }
    if mailboxFilteredCount > 0 && mailboxImportedCount == 0 && mailboxUncertainCount == 0 { return "checkmark.seal.fill" }
    return "tray.and.arrow.down.fill"
  }

  private func taskColor(for tone: String) -> Color {
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
  private var draftFollowUpPanel: some View {
    if !visibleDraftFollowUpItems.isEmpty {
      SettingsPanel(title: "Draft message follow-up", symbol: "envelope.open.fill") {
        VStack(alignment: .leading, spacing: 12) {
          Text("Drafts created from Inbox, Orders, Tasks, Workbench, and Dispatch appear here so local communication follow-up is visible in the daily flow.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          ForEach(visibleDraftFollowUpItems) { draft in
            TaskDraftFollowUpRow(draft: draft, store: store)
          }

          NavigationLink {
            CommunicationView(store: store)
          } label: {
            Label("Open Drafts & Templates", systemImage: "envelope.open.fill")
          }
          .buttonStyle(.bordered)
        }
      }
    }
  }

  @ViewBuilder
  private var mvpFollowUpPanel: some View {
    if !visibleMVPFollowUpItems.isEmpty {
      SettingsPanel(title: "MVP follow-up tasks", symbol: "checkmark.seal.text.page.fill") {
        VStack(alignment: .leading, spacing: 12) {
          Text("Tasks created from data hygiene, operator test sessions, or release snapshot checks appear here before the general queue.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          MetricStrip(items: [
            ("Follow-ups", "\(visibleMVPFollowUpItems.count)", .teal),
            ("Overdue", "\(visibleMVPFollowUpItems.filter(\.isOverdue).count)", visibleMVPFollowUpItems.contains(where: \.isOverdue) ? .red : .green),
            ("Blocked", "\(visibleMVPFollowUpItems.filter { $0.status == .blocked }.count)", visibleMVPFollowUpItems.contains { $0.status == .blocked } ? .red : .green),
            ("Needs review", "\(visibleMVPFollowUpItems.filter { $0.reviewState != .accepted }.count)", visibleMVPFollowUpItems.contains { $0.reviewState != .accepted } ? .orange : .green)
          ])

          ForEach(visibleMVPFollowUpItems.prefix(4)) { item in
            TaskQueueRow(item: item, store: store)
          }
        }
      }
    }
  }

  private var taskQueuePanel: some View {
    SettingsPanel(title: "Unified action queue", symbol: "checklist") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Work this list from the top: overdue, blocked, urgent, and review-needed items are promoted first.")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        FilterControlGrid {
          TextField("Search tasks and handoffs", text: $queueSearchText)
            .textFieldStyle(.roundedBorder)
          Badge("\(visibleQueueItems.count + visibleDraftFollowUpItems.count) shown", color: visibleQueueItems.isEmpty && visibleDraftFollowUpItems.isEmpty ? .orange : .blue)
          if !queueSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Button("Clear search", systemImage: "xmark.circle") {
              queueSearchText = ""
            }
            .buttonStyle(.bordered)
          }
        }

        if visibleQueueItems.isEmpty {
          MVPEmptyState(
            title: queueItems.isEmpty ? "No open actions" : "No matching actions",
            detail: queueItems.isEmpty ? "Review tasks and handoff notes that need operator attention will appear here." : "Clear the search to return to the full task and handoff queue.",
            symbol: "checkmark.circle.fill",
            actionTitle: "Add task",
            action: store.addReviewTaskPlaceholder
          )
        } else {
          ForEach(visibleQueueItems.prefix(16)) { item in
            TaskQueueRow(item: item, store: store)
          }
        }
      }
    }
  }

  private var detailRoutes: some View {
    SettingsPanel(title: "Detailed task views", symbol: "rectangle.stack.fill") {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 220 : 240), spacing: 12)], spacing: 12) {
        NavigationLink {
          ReviewTasksDetailView(store: store)
        } label: {
          TaskRouteCard(title: "Review Tasks", detail: "Filter, edit, complete, reopen, review, or remove local task records.", symbol: "checklist", badge: "\(store.reviewTasks.count) tasks", tint: .orange)
        }
        .buttonStyle(.plain)

        NavigationLink {
          HandoffNotesView(store: store)
        } label: {
          TaskRouteCard(title: "Handoff Notes", detail: "Manage shift notes, acknowledgements, and local team continuity.", symbol: "arrow.left.arrow.right.square.fill", badge: "\(store.handoffNotes.count) notes", tint: .blue)
        }
        .buttonStyle(.plain)
      }
    }
  }
}

private struct TaskQueueItem: Identifiable {
  var id: String
  var source: TaskQueueSource
  var sourceLabel: String
  var title: String
  var summary: String
  var linkedEntityType: ReviewTaskLinkedEntityType
  var linkedEntityID: String
  var assignee: String
  var priority: TaskPriority
  var dueDate: String
  var status: TaskStatus
  var reviewState: ReviewState
  var isOverdue: Bool
  var nextAction: String
  var sortPriority: Int

  var isSpaceMailFollowUp: Bool {
    title.localizedCaseInsensitiveContains("spacemail")
      || summary.localizedCaseInsensitiveContains("spacemail")
      || nextAction.localizedCaseInsensitiveContains("spacemail")
  }

  var isGmailFollowUp: Bool {
    title.localizedCaseInsensitiveContains("gmail")
      || summary.localizedCaseInsensitiveContains("gmail")
      || nextAction.localizedCaseInsensitiveContains("gmail")
      || linkedEntityID.localizedCaseInsensitiveContains("gmail")
  }

  var isMVPFollowUp: Bool {
    guard linkedEntityType == .integration else { return false }

    let knownIDs = [
      "local-data-hygiene",
      "operator-test-session",
      "spacemail-release-snapshot"
    ]
    if knownIDs.contains(linkedEntityID) { return true }

    let searchableText = [
      title,
      summary,
      nextAction,
      linkedEntityID
    ].joined(separator: " ").localizedLowercase

    return searchableText.contains("local data hygiene")
      || searchableText.contains("operator mvp test")
      || searchableText.contains("operator test-session")
      || searchableText.contains("operator test session")
      || searchableText.contains("release snapshot")
      || searchableText.contains("mvp release")
  }

  var isMailboxProviderFollowUp: Bool {
    guard linkedEntityType == .integration else { return false }
    if linkedEntityID.localizedCaseInsensitiveContains("mailbox-provider") { return true }
    if linkedEntityID.localizedCaseInsensitiveContains("mailbox-release") { return true }
    if linkedEntityID.localizedCaseInsensitiveContains("gmail") { return true }

    let searchableText = [
      title,
      summary,
      nextAction,
      linkedEntityID
    ].joined(separator: " ").localizedLowercase

    return searchableText.contains("mailbox provider")
      || searchableText.contains("provider release")
      || searchableText.contains("release gate")
      || searchableText.contains("release self-check")
      || searchableText.contains("gmail release self-check")
      || searchableText.contains("gmail release")
      || searchableText.contains("gmail setup handoff")
      || searchableText.contains("provider test queue")
      || searchableText.contains("mailbox release")
  }

  static func task(_ task: ReviewTask) -> TaskQueueItem {
    let isSpaceMailFollowUp = task.title.localizedCaseInsensitiveContains("spacemail")
      || task.summary.localizedCaseInsensitiveContains("spacemail")
    let isGmailFollowUp = task.linkedEntityID.localizedCaseInsensitiveContains("gmail")
      || task.title.localizedCaseInsensitiveContains("gmail")
      || task.summary.localizedCaseInsensitiveContains("gmail")
    let isMailboxProviderFollowUp = task.linkedEntityType == .integration
      && (
        task.linkedEntityID.localizedCaseInsensitiveContains("mailbox-provider")
          || task.linkedEntityID.localizedCaseInsensitiveContains("mailbox-release")
          || task.title.localizedCaseInsensitiveContains("mailbox provider")
          || task.summary.localizedCaseInsensitiveContains("mailbox provider")
          || task.title.localizedCaseInsensitiveContains("release gate")
          || task.summary.localizedCaseInsensitiveContains("release gate")
          || task.title.localizedCaseInsensitiveContains("release self-check")
          || task.summary.localizedCaseInsensitiveContains("release self-check")
          || task.title.localizedCaseInsensitiveContains("Gmail release")
          || task.summary.localizedCaseInsensitiveContains("Gmail release")
          || task.title.localizedCaseInsensitiveContains("Gmail setup handoff")
          || task.summary.localizedCaseInsensitiveContains("Gmail setup handoff")
      )
    let isMVPFollowUp = task.linkedEntityType == .integration
      && [
        "local-data-hygiene",
        "operator-test-session",
        "spacemail-release-snapshot"
      ].contains(task.linkedEntityID)
    return TaskQueueItem(
      id: "task-\(task.id.uuidString)",
      source: .task(task),
      sourceLabel: isGmailFollowUp ? "Gmail task" : isMailboxProviderFollowUp ? "Provider task" : isMVPFollowUp ? "MVP follow-up" : isSpaceMailFollowUp ? "SpaceMail task" : "Task",
      title: task.title,
      summary: task.summary,
      linkedEntityType: task.linkedEntityType,
      linkedEntityID: task.linkedEntityID,
      assignee: task.assignee,
      priority: task.priority,
      dueDate: task.isLocallyOverdue ? "Overdue: \(task.dueDate)" : task.dueDate,
      status: task.status,
      reviewState: task.reviewState,
      isOverdue: task.isLocallyOverdue,
      nextAction: isMailboxProviderFollowUp
        ? (isGmailFollowUp ? "Open Gmail setup or release self-check in Mailbox Monitor, then complete or refresh this follow-up" : "Open the provider release/self-check context and Mailbox Monitor, then complete or refresh this follow-up")
        : isSpaceMailFollowUp
        ? "Open Mailbox Monitor for source context, then complete or draft follow-up"
        : isMVPFollowUp
        ? "Complete this validation task or create a draft if someone needs the result"
        : task.isReopenedInboxDispatchHandoff
        ? "Open the order, inspect dispatch setup, then complete or block the handoff"
        : task.isPartialInboxOrderFollowUp
        ? "Open the order, confirm missing fields, then complete this handoff"
        : nextAction(status: task.status, reviewState: task.reviewState, isOverdue: task.isLocallyOverdue, completedVerb: "Reopen if more work is needed"),
      sortPriority: sortPriority(priority: task.priority, status: task.status, reviewState: task.reviewState, isOverdue: task.isLocallyOverdue) + (task.isReopenedInboxDispatchHandoff ? 12 : task.isPartialInboxOrderFollowUp ? 8 : isGmailFollowUp ? 9 : isMailboxProviderFollowUp ? 8 : isMVPFollowUp ? 7 : isSpaceMailFollowUp ? 6 : 0)
    )
  }

  static func handoff(_ note: HandoffNote) -> TaskQueueItem {
    let isSpaceMailFollowUp = note.title.localizedCaseInsensitiveContains("spacemail")
      || note.summary.localizedCaseInsensitiveContains("spacemail")
      || note.notes.localizedCaseInsensitiveContains("spacemail")
    let isGmailFollowUp = note.linkedEntityID.localizedCaseInsensitiveContains("gmail")
      || note.title.localizedCaseInsensitiveContains("gmail")
      || note.summary.localizedCaseInsensitiveContains("gmail")
      || note.notes.localizedCaseInsensitiveContains("gmail")
    let isMailboxProviderFollowUp = note.linkedEntityType == .integration
      && (
        note.linkedEntityID.localizedCaseInsensitiveContains("mailbox-provider")
          || note.linkedEntityID.localizedCaseInsensitiveContains("mailbox-release")
          || note.linkedEntityID.localizedCaseInsensitiveContains("gmail")
          || note.title.localizedCaseInsensitiveContains("mailbox provider")
          || note.summary.localizedCaseInsensitiveContains("mailbox provider")
          || note.notes.localizedCaseInsensitiveContains("mailbox provider")
          || note.title.localizedCaseInsensitiveContains("release gate")
          || note.summary.localizedCaseInsensitiveContains("release gate")
          || note.notes.localizedCaseInsensitiveContains("release gate")
          || note.title.localizedCaseInsensitiveContains("release self-check")
          || note.summary.localizedCaseInsensitiveContains("release self-check")
          || note.notes.localizedCaseInsensitiveContains("release self-check")
          || note.title.localizedCaseInsensitiveContains("gmail")
          || note.summary.localizedCaseInsensitiveContains("gmail")
          || note.notes.localizedCaseInsensitiveContains("gmail")
      )
    return TaskQueueItem(
      id: "handoff-\(note.id.uuidString)",
      source: .handoff(note),
      sourceLabel: isGmailFollowUp ? "Gmail handoff" : isMailboxProviderFollowUp ? "Provider handoff" : isSpaceMailFollowUp ? "SpaceMail handoff" : "Handoff",
      title: note.title,
      summary: note.summary,
      linkedEntityType: note.linkedEntityType,
      linkedEntityID: note.linkedEntityID,
      assignee: note.assignee,
      priority: note.priority,
      dueDate: note.isLocallyOverdue ? "Overdue: \(note.dueDate)" : note.dueDate,
      status: note.status,
      reviewState: note.reviewState,
      isOverdue: note.isLocallyOverdue,
      nextAction: isMailboxProviderFollowUp
        ? (isGmailFollowUp ? "Open Mailbox Monitor for Gmail setup, sign-in, or refresh context, then acknowledge or complete handoff" : "Open Mailbox Monitor for provider setup or refresh context, then acknowledge or complete handoff")
        : isSpaceMailFollowUp
        ? "Open Mailbox Monitor for source context, then acknowledge or complete handoff"
        : nextAction(status: note.status, reviewState: note.reviewState, isOverdue: note.isLocallyOverdue, completedVerb: "Reopen if the handoff is active again"),
      sortPriority: sortPriority(priority: note.priority, status: note.status, reviewState: note.reviewState, isOverdue: note.isLocallyOverdue) + (isGmailFollowUp ? 9 : isMailboxProviderFollowUp ? 8 : isSpaceMailFollowUp ? 6 : 0)
    )
  }

  private static func nextAction(status: TaskStatus, reviewState: ReviewState, isOverdue: Bool, completedVerb: String) -> String {
    if status == .completed {
      return reviewState == .accepted ? completedVerb : "Mark reviewed"
    }
    if status == .blocked {
      return "Resolve blocker or create a draft"
    }
    if isOverdue {
      return "Complete or reassign today"
    }
    if reviewState != .accepted {
      return "Review details and act"
    }
    return "Complete when follow-up is done"
  }

  private static func sortPriority(priority: TaskPriority, status: TaskStatus, reviewState: ReviewState, isOverdue: Bool) -> Int {
    if isOverdue { return 110 }
    if status == .blocked { return 100 }
    if priority == .urgent { return 95 }
    if priority == .high { return 85 }
    if reviewState != .accepted { return 70 }
    if status == .inProgress { return 60 }
    if status == .open { return 50 }
    return 20
  }

  var decisionTitle: String {
    switch source {
    case .task(let task):
      if task.isReopenedInboxDispatchHandoff { return "Reopened dispatch handoff" }
      if task.isPartialInboxOrderFollowUp { return "Verify Inbox-created order" }
      if isGmailFollowUp { return "Gmail follow-up" }
      if isMailboxProviderFollowUp { return "Mailbox provider follow-up" }
      if isSpaceMailFollowUp { return "SpaceMail follow-up" }
      if isMVPFollowUp { return "MVP validation follow-up" }
      if isOverdue { return "Task is overdue" }
      if status == .blocked { return "Task is blocked" }
      if status == .completed { return reviewState == .accepted ? "Task is complete" : "Completed task needs review" }
      return "Owned follow-up work"
    case .handoff:
      if isGmailFollowUp { return "Gmail shift handoff" }
      if isMailboxProviderFollowUp { return "Mailbox provider handoff" }
      if isSpaceMailFollowUp { return "SpaceMail shift handoff" }
      if isOverdue { return "Handoff is overdue" }
      if status == .blocked { return "Handoff is blocked" }
      if status == .completed { return reviewState == .accepted ? "Handoff is complete" : "Completed handoff needs review" }
      return "Shift handoff needs action"
    }
  }

  var decisionDetail: String {
    switch source {
    case .task(let task):
      if task.isReopenedInboxDispatchHandoff {
        return "Open the linked order and dispatch records before completing this task. The handoff was reopened after dispatch setup had started."
      }
      if task.isPartialInboxOrderFollowUp {
        return "Confirm the missing order, tracking, or destination details on the linked Inbox-created order before completing this task."
      }
      if isGmailFollowUp {
        return "Use Gmail setup, sign-in, refresh, classifier, or release self-check context in Mailbox Monitor before completing this task."
      }
      if isMailboxProviderFollowUp {
        return "Use the mailbox provider release gate or Gmail self-check plus Mailbox Monitor to confirm the provider path before completing this task."
      }
      if isSpaceMailFollowUp {
        return "Use Mailbox Monitor or Inbox to inspect the source refresh/intake context, then complete the task or create a draft for follow-up."
      }
      if isMVPFollowUp {
        return "Use this to record local test or release-candidate follow-up. Complete it when the check is done, or create a draft if someone else needs the result."
      }
      if status == .blocked {
        return "Resolve the blocker, create a draft, or leave the task open with the owner/team clear."
      }
      if isOverdue {
        return "Complete, reassign, or create a draft today so this does not disappear into the queue."
      }
      if status == .completed && reviewState != .accepted {
        return "Review the completed work and mark reviewed when no further local follow-up is needed."
      }
      return "Confirm the linked record context, then complete the task when the owner has finished the work."
    case .handoff:
      if isGmailFollowUp {
        return "Review Gmail setup, Google sign-in, refresh evidence, or classifier context before acknowledging/completing this shift note."
      }
      if isMailboxProviderFollowUp {
        return "Review Mailbox Monitor provider setup, Gmail/SpaceMail refresh evidence, or release gate context before acknowledging/completing this shift note."
      }
      if isSpaceMailFollowUp {
        return "Review the mailbox refresh or classifier context before acknowledging/completing this shift note."
      }
      if status == .blocked {
        return "Clarify why the handoff is blocked, create a task if ownership is needed, or reopen once work resumes."
      }
      if isOverdue {
        return "Acknowledge or complete this handoff today, or create a task if another person owns the follow-up."
      }
      if status == .completed && reviewState != .accepted {
        return "Review the completed handoff before it leaves the operator queue."
      }
      return "Acknowledge when the next operator has read it; complete when the handoff no longer needs action."
    }
  }

  var decisionBadge: String {
    if status == .blocked { return "Blocked" }
    if isOverdue { return "Overdue" }
    if status == .completed { return reviewState == .accepted ? "Done" : "Review" }
    if isGmailFollowUp { return "Gmail" }
    if isMailboxProviderFollowUp { return "Provider" }
    if isSpaceMailFollowUp { return "SpaceMail" }
    if isMVPFollowUp { return "MVP" }
    switch source {
    case .task(let task):
      if task.isPartialInboxOrderFollowUp || task.isReopenedInboxDispatchHandoff { return "Verify" }
      return "Do"
    case .handoff:
      return "Handoff"
    }
  }

  var decisionColor: Color {
    if status == .blocked { return .red }
    if isOverdue { return .red }
    if status == .completed && reviewState == .accepted { return .green }
    if status == .completed { return .orange }
    if isGmailFollowUp { return .teal }
    if isMailboxProviderFollowUp { return .purple }
    if isSpaceMailFollowUp { return .teal }
    if isMVPFollowUp { return .purple }
    switch source {
    case .task(let task):
      if task.isPartialInboxOrderFollowUp || task.isReopenedInboxDispatchHandoff { return .orange }
      return priority.color
    case .handoff:
      return .blue
    }
  }

  var decisionSymbol: String {
    if status == .blocked { return "xmark.octagon.fill" }
    if isOverdue { return "clock.badge.exclamationmark.fill" }
    if status == .completed { return reviewState == .accepted ? "checkmark.seal.fill" : "checkmark.shield.fill" }
    if isGmailFollowUp { return "envelope.badge.shield.half.filled" }
    if isMailboxProviderFollowUp { return "checkmark.seal.fill" }
    if isSpaceMailFollowUp { return "server.rack" }
    if isMVPFollowUp { return "checklist.checked" }
    switch source {
    case .task(let task):
      if task.isReopenedInboxDispatchHandoff { return "arrow.counterclockwise.circle.fill" }
      if task.isPartialInboxOrderFollowUp { return "tray.and.arrow.down.fill" }
      return "checklist"
    case .handoff:
      return "arrow.left.arrow.right.square.fill"
    }
  }
}

private enum TaskQueueSource {
  case task(ReviewTask)
  case handoff(HandoffNote)

  var symbol: String {
    switch self {
    case .task: "checklist"
    case .handoff: "arrow.left.arrow.right.square.fill"
    }
  }
}

private struct TaskDraftFollowUpRow: View {
  var draft: DraftMessage
  var store: ParcelOpsStore
  @State private var feedbackMessage: String?

  private var isWishlistBatchResearchDraft: Bool {
    draft.linkedEntityType == .wishlistItem && draft.linkedEntityID == "wishlist-research-batch"
  }

  private var draftIcon: String {
    isWishlistBatchResearchDraft ? "star.square.on.square.fill" : "envelope.open.fill"
  }

  private var sourceTitle: String {
    isWishlistBatchResearchDraft ? "Wishlist batch research packet" : draft.channel.rawValue
  }

  private var nextActionDetail: String {
    if isWishlistBatchResearchDraft {
      switch draft.status {
      case .draft:
        return "Review the local batch brief, then mark it ready when it can be handed to an external research agent or copied into a manual research workflow."
      case .ready:
        return "Use the ready packet outside ParcelOps. After external research is handled, mark it sent locally so Tasks knows the handoff left the queue."
      case .sentLocally:
        return "The batch packet was marked sent locally. Reopen it only if the Wishlist comparison research needs another pass."
      case .reopened:
        return "The batch packet is reopened. Update the brief or Wishlist request details before marking it ready again."
      }
    }
    switch draft.status {
    case .draft:
      return "Review the local draft and mark ready when the message can be sent outside ParcelOps."
    case .ready:
      return "Send this outside ParcelOps, then mark it sent locally."
    case .sentLocally:
      return "The draft is marked sent locally. Reopen only if more follow-up is needed."
    case .reopened:
      return "The draft was reopened. Update or mark ready when follow-up is clear."
    }
  }

  private var statusColor: Color {
    switch draft.status {
    case .draft:
      return .orange
    case .ready:
      return .green
    case .sentLocally:
      return .secondary
    case .reopened:
      return .purple
    }
  }

  private var linkedOrder: TrackedOrder? {
    guard draft.linkedEntityType == .order,
      let orderID = UUID(uuidString: draft.linkedEntityID)
    else { return nil }
    return store.orders.first { $0.id == orderID }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: draftIcon)
          .foregroundStyle(statusColor)
          .frame(width: 30, height: 30)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
              Text(draft.subject)
                .font(.headline)
              Text("\(sourceTitle) • \(draft.recipient)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 8)
            Badge(draft.status.rawValue, color: statusColor)
          }

          Text(draft.body)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          Text(nextActionDetail)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isWishlistBatchResearchDraft ? .purple : .secondary)
            .fixedSize(horizontal: false, vertical: true)

          if linkedOrder != nil {
            LinkedOrderContextPanel(
              order: linkedOrder,
              sourceLabel: "Draft follow-up",
              emptyDetail: "No order is linked to this draft. Return to the source record if the message should reference an order before it is marked ready.",
              linkedDetail: "This draft is tied to order context. Open the order before marking the draft ready if tracking, destination, or dispatch setup still needs confirmation.",
              store: store
            )
          }

          CompactMetadataGrid {
            Badge(draft.reviewState.rawValue, color: draft.reviewState.color)
            Label(draft.linkedEntityType.rawValue, systemImage: draft.linkedEntityType.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(draft.createdDate)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      CompactActionRow {
        Button("Ready", systemImage: "checkmark.seal.fill") {
          store.markDraftMessageReady(draft)
          feedbackMessage = "Draft marked ready locally."
        }
        .buttonStyle(.bordered)
        .disabled(draft.status == .ready)

        Button("Sent locally", systemImage: "paperplane.fill") {
          store.markDraftMessageSentLocally(draft)
          feedbackMessage = "Draft marked sent locally."
        }
        .buttonStyle(.borderedProminent)
        .disabled(draft.status == .sentLocally)

        Button("Reopen", systemImage: "arrow.uturn.backward.circle.fill") {
          store.reopenDraftMessage(draft)
          feedbackMessage = "Draft reopened for follow-up."
        }
        .buttonStyle(.bordered)
        .disabled(draft.status == .reopened)
      }

      if let feedbackMessage {
        TaskActionFeedbackPanel(message: feedbackMessage, store: store)
      }
    }
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

private struct TaskQueueRow: View {
  var item: TaskQueueItem
  var store: ParcelOpsStore
  @State private var editingTask: ReviewTask?
  @State private var editingHandoff: HandoffNote?
  @State private var feedbackMessage: String?

  private var linkedOrder: TrackedOrder? {
    guard item.linkedEntityType == .order,
      let orderID = UUID(uuidString: item.linkedEntityID)
    else { return nil }
    return store.orders.first { $0.id == orderID }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: item.source.symbol)
          .foregroundStyle(item.priority.color)
          .frame(width: 30, height: 30)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
              Text(item.title)
                .font(.headline)
              Text("\(item.assignee) • due \(item.dueDate)")
                .font(.caption)
                .foregroundStyle(item.isOverdue ? .red : .secondary)
            }
            Spacer(minLength: 8)
            Badge(item.sourceLabel, color: item.priority.color)
          }

          Text(item.summary)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          if item.linkedEntityType == .order || linkedOrder != nil {
            LinkedOrderContextPanel(
              order: linkedOrder,
              sourceLabel: item.sourceLabel,
              emptyDetail: "This action is tied to an order ID, but the matching local order was not found. Open the detailed task or handoff before completing the work.",
              linkedDetail: linkedOrder?.isInboxCreatedLocalOrder == true
                ? "Inbox-created order follow-up. Open the order before completing this task if tracking, destination, or dispatch setup still needs confirmation."
                : "This action has linked order context. Open the order before completing the task if tracking, destination, or dispatch setup still needs confirmation.",
              store: store
            )
          }

          if let linkedOrder, linkedOrder.isInboxCreatedLocalOrder {
            TaskInboxSourceTrail(order: linkedOrder, store: store)
          }

          if case .task(let task) = item.source, task.isPartialInboxOrderFollowUp {
            PartialInboxOrderTaskCallout(task: task, linkedOrder: linkedOrder)
          }

          if case .task(let task) = item.source, task.isReopenedInboxDispatchHandoff {
            ReopenedDispatchHandoffTaskCallout(linkedOrder: linkedOrder)
          }

          CompactMetadataGrid {
            Badge(item.priority.rawValue, color: item.priority.color)
            Badge(item.status.rawValue, color: item.status.color)
            Badge(item.reviewState.rawValue, color: item.reviewState.color)
            if item.isOverdue {
              Badge("Overdue", color: .red)
            }
            Label(item.linkedEntityType.rawValue, systemImage: item.linkedEntityType.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(item.linkedEntityID)
              .font(.caption2.monospaced())
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          }

          Label(item.nextAction, systemImage: "arrow.forward.circle.fill")
            .font(.caption)
            .foregroundStyle(item.priority.color)
        }
      }

      taskDecisionPanel

      CompactActionRow {
        openLink

        switch item.source {
        case .task(let task):
          Button("Edit", systemImage: "pencil") {
            editingTask = task
          }
          .buttonStyle(.bordered)
          if task.status == .completed {
            Button("Reopen", systemImage: "arrow.uturn.backward.circle.fill") {
              store.reopenReviewTask(task)
              feedbackMessage = "Task reopened for follow-up."
            }
            .buttonStyle(.bordered)
          } else {
            Button("Complete", systemImage: "checkmark.circle.fill") {
              store.completeReviewTask(task)
              feedbackMessage = "Task completed locally."
            }
            .buttonStyle(.borderedProminent)
          }
          Button("Reviewed", systemImage: "checkmark.shield.fill") {
            store.markReviewTaskReviewed(task)
            feedbackMessage = "Task marked reviewed locally."
          }
          .buttonStyle(.bordered)
          Button("Draft", systemImage: "envelope.open.fill") {
            store.createDraftMessage(from: task)
            feedbackMessage = "Draft message created from task. Check Drafts."
          }
          .buttonStyle(.bordered)

        case .handoff(let note):
          Button("Edit", systemImage: "pencil") {
            editingHandoff = note
          }
          .buttonStyle(.bordered)
          Button("Acknowledge", systemImage: "hand.thumbsup.fill") {
            store.acknowledgeHandoffNote(note)
            feedbackMessage = "Handoff acknowledged locally."
          }
          .buttonStyle(.bordered)
          if note.status == .completed {
            Button("Reopen", systemImage: "arrow.uturn.backward.circle.fill") {
              store.reopenHandoffNote(note)
              feedbackMessage = "Handoff reopened for follow-up."
            }
            .buttonStyle(.bordered)
          } else {
            Button("Complete", systemImage: "checkmark.circle.fill") {
              store.completeHandoffNote(note)
              feedbackMessage = "Handoff completed locally."
            }
            .buttonStyle(.borderedProminent)
          }
          Button("Reviewed", systemImage: "checkmark.shield.fill") {
            store.markHandoffNoteReviewed(note)
            feedbackMessage = "Handoff marked reviewed locally."
          }
          .buttonStyle(.bordered)
          Button("Task", systemImage: "checklist") {
            store.createReviewTask(from: note)
            feedbackMessage = "Follow-up task created from handoff. Check Tasks."
          }
          .buttonStyle(.bordered)
          Button("Draft", systemImage: "envelope.open.fill") {
            store.createDraftMessage(from: note)
            feedbackMessage = "Draft message created from handoff. Check Drafts."
          }
          .buttonStyle(.bordered)
        }
      }

      if let feedbackMessage {
        TaskActionFeedbackPanel(message: feedbackMessage, store: store)
      }
    }
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    .sheet(item: $editingTask) { task in
      ReviewTaskEditView(task: task) { updatedTask in
        store.updateReviewTask(updatedTask)
      }
    }
    .sheet(item: $editingHandoff) { note in
      HandoffNoteEditView(note: note) { updatedNote in
        store.updateHandoffNote(updatedNote)
      }
    }
  }

  private var taskDecisionPanel: some View {
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

  @ViewBuilder
  private var openLink: some View {
    switch item.source {
    case .task:
      NavigationLink {
        ReviewTasksDetailView(store: store)
      } label: {
        Label("Open task", systemImage: "arrow.right.circle.fill")
      }
      .buttonStyle(.bordered)
    case .handoff:
      NavigationLink {
        HandoffNotesView(store: store)
      } label: {
        Label("Open handoff", systemImage: "arrow.right.circle.fill")
      }
      .buttonStyle(.bordered)
    }
  }
}

private struct TaskActionFeedbackPanel: View {
  var message: String
  var store: ParcelOpsStore

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(message, systemImage: "checkmark.circle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.green)

      CompactActionRow {
        if message.localizedCaseInsensitiveContains("draft") {
          NavigationLink {
            CommunicationView(store: store)
          } label: {
            Label("Open Drafts", systemImage: "envelope.open.fill")
          }
        }
        NavigationLink {
          OperationsWorkbenchView(store: store)
        } label: {
          Label("Open Workbench", systemImage: "rectangle.stack.badge.person.crop.fill")
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

private struct TaskInboxSourceTrail: View {
  var order: TrackedOrder
  var store: ParcelOpsStore

  private var linkedEmails: [ForwardedEmailIntake] {
    let orderNumber = order.orderNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    return Array(
      store.intakeEmails
        .filter { email in
          email.linkedOrderID == order.id
            || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.detectedOrderNumber.localizedCaseInsensitiveContains(orderNumber))
            || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.subject.localizedCaseInsensitiveContains(orderNumber))
            || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.rawBodyPreview.localizedCaseInsensitiveContains(orderNumber))
        }
        .prefix(3)
    )
  }
  private var importItems: [ImportQueueItem] {
    Array(store.importQueueItems(for: order).prefix(3))
  }
  private var acceptanceRecords: [AcceptanceRecord] {
    Array(store.acceptanceRecords(for: order).prefix(3))
  }
  private var sourceTrailCount: Int {
    linkedEmails.count + importItems.count + acceptanceRecords.count
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Inbox source for this task", systemImage: "tray.and.arrow.down.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(sourceTrailCount == 0 ? .orange : .teal)

      CompactMetadataGrid(minimumWidth: 130) {
        Badge("\(linkedEmails.count) intake", color: linkedEmails.isEmpty ? .secondary : .teal)
        Badge("\(importItems.count) import", color: importItems.isEmpty ? .secondary : .blue)
        Badge("\(acceptanceRecords.count) acceptance", color: acceptanceRecords.isEmpty ? .secondary : .purple)
      }

      if sourceTrailCount == 0 {
        Text("This order was created from Inbox workflow, but no intake, import, or acceptance source matched the current order number. Open the order source trail before closing this task.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        ForEach(linkedEmails) { email in
          IntakeSourceContextPanel(
            email: email,
            store: store,
            manualDetail: "No mailbox ingest record is linked to this intake row. Treat it as local/manual evidence for this task.",
            linkedDetailSuffix: "Duplicate-safe source metadata is linked to this task handoff.",
            compact: true
          )
        }
        if !importItems.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Text("Import queue context")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            ImportQueueContextStrip(items: importItems)
          }
        }
        if !acceptanceRecords.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Text("Acceptance context")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            AcceptanceHistoryStrip(records: acceptanceRecords)
          }
        }
      }
    }
    .padding(10)
    .background((sourceTrailCount == 0 ? Color.orange : Color.teal).opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct PartialInboxOrderTaskCallout: View {
  var task: ReviewTask
  var linkedOrder: TrackedOrder?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Partial Inbox order handoff", systemImage: "exclamationmark.triangle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.orange)

      Text("Missing detail to confirm: \(task.partialInboxMissingSummary).")
        .font(.caption)
        .foregroundStyle(.secondary)

      if let linkedOrder {
        CompactMetadataGrid(minimumWidth: 130) {
          Badge(linkedOrder.trackingNumber.isPlaceholderValidationValue ? "Tracking missing" : "Tracking present", color: linkedOrder.trackingNumber.isPlaceholderValidationValue ? .orange : .green)
          Badge(linkedOrder.destination.isPlaceholderValidationValue ? "Destination missing" : "Destination present", color: linkedOrder.destination.isPlaceholderValidationValue ? .orange : .green)
          Badge(linkedOrder.reviewState.rawValue, color: linkedOrder.reviewState.color)
        }
      }

      Text("Open the order, edit the missing values, then complete and review this task.")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(10)
    .background(Color.orange.opacity(0.10))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct ReopenedDispatchHandoffTaskCallout: View {
  var linkedOrder: TrackedOrder?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Reopened dispatch handoff", systemImage: "arrow.counterclockwise.circle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.purple)

      Text("This task was created because an Inbox-created order handoff was reopened after dispatch setup had already been prepared. Check the order, linked manifest, and dispatch readiness before closing it again.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if let linkedOrder {
        CompactMetadataGrid(minimumWidth: 130) {
          Badge(linkedOrder.latestStatus, color: linkedOrder.reviewState == .accepted ? .green : .orange)
          Badge(linkedOrder.reviewState.rawValue, color: linkedOrder.reviewState.color)
          Badge(linkedOrder.carrier.isPlaceholderValidationValue ? "Carrier needs review" : linkedOrder.carrier, color: linkedOrder.carrier.isPlaceholderValidationValue ? .orange : .blue)
          Badge(linkedOrder.trackingNumber.isPlaceholderValidationValue ? "Tracking needs review" : "Tracking present", color: linkedOrder.trackingNumber.isPlaceholderValidationValue ? .orange : .green)
        }
      }

      Text("Use Open order to inspect the source trail and linked dispatch records. Complete this task after the handoff is complete again.")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(10)
    .background(Color.purple.opacity(0.10))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct ReviewTasksDetailView: View {
  var store: ParcelOpsStore

  @State private var selectedStatus: TaskStatus?
  @State private var selectedPriority: TaskPriority?
  @State private var selectedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedAssignee: String?
  @State private var selectedReviewState: ReviewState?
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var assignees: [String] {
    Array(Set(store.reviewTasks.map(\.assignee))).sorted()
  }

  private var filteredTasks: [ReviewTask] {
    store.reviewTasks.filter { task in
      let matchesStatus = selectedStatus == nil || task.status == selectedStatus
      let matchesPriority = selectedPriority == nil || task.priority == selectedPriority
      let matchesEntity = selectedEntityType == nil || task.linkedEntityType == selectedEntityType
      let matchesAssignee = selectedAssignee == nil || task.assignee == selectedAssignee
      let matchesReview = selectedReviewState == nil || task.reviewState == selectedReviewState
      return matchesStatus && matchesPriority && matchesEntity && matchesAssignee && matchesReview
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Tasks")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Local ownership and follow-up work created from intake, orders, dispatch, exceptions, and audit events.")
            .foregroundStyle(.secondary)
        }

        CompactActionRow {
          NavigationLink {
            OperationsWorkbenchView(store: store)
          } label: {
            Label("Open Workbench", systemImage: "rectangle.stack.badge.person.crop.fill")
          }
          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Open Audit", systemImage: "list.clipboard.fill")
          }
        }
        .buttonStyle(.bordered)

        MVPWorkflowGuide(
          title: "Task workflow",
          detail: "Tasks are the simplest way to turn a confusing record into assigned follow-up.",
          steps: [
            "Filter to open, urgent, or overdue work.",
            "Edit the assignee, priority, due date, or summary when ownership is unclear.",
            "Create a draft if the task needs a supplier, customer, or team message.",
            "Complete and mark reviewed when the work is done."
          ],
          symbol: "checklist"
        )

        filterBar

        SettingsPanel(title: "Review tasks", symbol: "checklist") {
          HStack {
            Text("\(filteredTasks.count) visible tasks")
              .font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            Button("Add task", systemImage: "plus", action: store.addReviewTaskPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredTasks.isEmpty {
            MVPEmptyState(title: "No tasks match this view", detail: "Clear filters or add a local task to test follow-up ownership.", symbol: "checklist", actionTitle: "Add task", action: store.addReviewTaskPlaceholder)
          } else {
            ForEach(filteredTasks) { task in
              ReviewTaskRow(task: task, store: store, linkedOrder: linkedOrder(for: task), matchingPolicies: store.policies(for: task.linkedEntityType), shipmentGroups: store.suggestedShipmentGroups(for: task), handoffNotes: store.handoffNotes(for: task), customerProfiles: store.suggestedCustomerProfiles(for: task), destinationAddresses: store.suggestedDestinationAddresses(for: task), deliveryInstructions: store.suggestedDeliveryInstructions(for: task), packageContents: store.suggestedPackageContents(for: task)) { updatedTask in
                store.updateReviewTask(updatedTask)
              } onComplete: {
                store.completeReviewTask(task)
              } onReopen: {
                store.reopenReviewTask(task)
              } onReviewed: {
                store.markReviewTaskReviewed(task)
              } onCreateDraft: {
                store.createDraftMessage(from: task)
              } onCreateContact: {
                store.addContactDirectoryEntry(linkedEntityType: .reviewTask, linkedEntityID: task.id.uuidString, label: task.title)
              } onRemove: {
                store.removeReviewTask(task)
              }
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      Picker("Status", selection: $selectedStatus) {
        Text("All statuses").tag(nil as TaskStatus?)
        ForEach(TaskStatus.allCases) { status in
          Text(status.rawValue).tag(status as TaskStatus?)
        }
      }
      .pickerStyle(.menu)

      Picker("Priority", selection: $selectedPriority) {
        Text("All priorities").tag(nil as TaskPriority?)
        ForEach(TaskPriority.allCases) { priority in
          Text(priority.rawValue).tag(priority as TaskPriority?)
        }
      }
      .pickerStyle(.menu)

      Picker("Record", selection: $selectedEntityType) {
        Text("All records").tag(nil as ReviewTaskLinkedEntityType?)
        ForEach(ReviewTaskLinkedEntityType.allCases) { entityType in
          Text(entityType.rawValue).tag(entityType as ReviewTaskLinkedEntityType?)
        }
      }
      .pickerStyle(.menu)

      Picker("Assignee", selection: $selectedAssignee) {
        Text("All assignees").tag(nil as String?)
        ForEach(assignees, id: \.self) { assignee in
          Text(assignee).tag(assignee as String?)
        }
      }
      .pickerStyle(.menu)

      Picker("Review", selection: $selectedReviewState) {
        Text("All review states").tag(nil as ReviewState?)
        Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted as ReviewState?)
        Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview as ReviewState?)
        Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor as ReviewState?)
      }
      .pickerStyle(.menu)

      Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle") {
        selectedStatus = nil
        selectedPriority = nil
        selectedEntityType = nil
        selectedAssignee = nil
        selectedReviewState = nil
      }
      .buttonStyle(.bordered)
    }
  }

  private func linkedOrder(for task: ReviewTask) -> TrackedOrder? {
    guard task.linkedEntityType == .order, let orderID = UUID(uuidString: task.linkedEntityID) else { return nil }
    return store.orders.first { $0.id == orderID }
  }
}

struct ReviewTaskRow: View {
  var task: ReviewTask
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
  var matchingPolicies: [SLAPolicy] = []
  var shipmentGroups: [ShipmentGroup] = []
  var handoffNotes: [HandoffNote] = []
  var customerProfiles: [CustomerRecipientProfile] = []
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var onSave: (ReviewTask) -> Void
  var onComplete: () -> Void
  var onReopen: () -> Void
  var onReviewed: () -> Void
  var onCreateDraft: () -> Void = {}
  var onCreateContact: () -> Void = {}
  var onRemove: () -> Void
  @State private var isEditing = false
  @State private var feedbackMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: task.linkedEntityType.symbol)
          .foregroundStyle(task.priority.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(task.title)
                .font(.headline)
              Text("\(task.assignee) • due \(task.dueDate)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(task.priority.rawValue, color: task.priority.color)
            if task.isLocallyOverdue {
              Badge("Overdue", color: .red)
            }
          }

          Text(task.summary)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          CompactMetadataGrid {
            Badge(task.status.rawValue, color: task.status.color)
            Badge(task.reviewState.rawValue, color: task.reviewState.color)
            Label(task.linkedEntityType.rawValue, systemImage: task.linkedEntityType.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(task.linkedEntityID)
              .font(.caption2.monospaced())
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          }

          if let policy = matchingPolicies.first {
            Text("SLA: \(policy.responseTarget); \(policy.resolutionTarget)")
              .font(.caption)
              .foregroundStyle(policy.priority.color)
          }

          if !shipmentGroups.isEmpty {
            ShipmentGroupContextStrip(groups: shipmentGroups)
          }

          if !handoffNotes.isEmpty {
            HandoffNoteStrip(notes: handoffNotes)
          }

          if !customerProfiles.isEmpty {
            CustomerProfileStrip(profiles: customerProfiles)
          }
          if !destinationAddresses.isEmpty {
            DestinationAddressStrip(addresses: destinationAddresses)
          }
          if !deliveryInstructions.isEmpty {
            DeliveryInstructionStrip(instructions: deliveryInstructions)
          }
          if !packageContents.isEmpty {
            PackageContentStrip(contents: packageContents)
          }

          if task.linkedEntityType == .order || linkedOrder != nil {
            LinkedOrderContextPanel(
              order: linkedOrder,
              sourceLabel: "Review task",
              emptyDetail: "This task references an order ID, but the matching local order was not found. Check the task details before completing it.",
              linkedDetail: "This task has linked order context. Open the order before completing it if tracking, destination, or dispatch setup still needs confirmation.",
              store: store
            )
          }

          if let store, let linkedOrder, linkedOrder.isInboxCreatedLocalOrder {
            TaskInboxSourceTrail(order: linkedOrder, store: store)
          }

          if task.isPartialInboxOrderFollowUp {
            PartialInboxOrderTaskCallout(task: task, linkedOrder: linkedOrder)
          }
        }
      }

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        if task.status == .completed {
          Button("Reopen", systemImage: "arrow.uturn.backward.circle.fill") {
            onReopen()
            feedbackMessage = "Task reopened for follow-up."
          }
            .buttonStyle(.bordered)
        } else {
          Button("Complete", systemImage: "checkmark.circle.fill") {
            onComplete()
            feedbackMessage = "Task completed locally."
          }
            .buttonStyle(.borderedProminent)
        }
        Button("Reviewed", systemImage: "checkmark.shield.fill") {
          onReviewed()
          feedbackMessage = "Task marked reviewed locally."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Draft message created from task. Check Drafts."
        }
          .buttonStyle(.bordered)
        Button("Contact", systemImage: "person.crop.circle.badge.plus") {
          onCreateContact()
          feedbackMessage = "Contact placeholder created from task."
        }
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", action: onRemove)
          .buttonStyle(.bordered)
      }

      if let feedbackMessage, let store {
        TaskActionFeedbackPanel(message: feedbackMessage, store: store)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      ReviewTaskEditView(task: task) { updatedTask in
        onSave(updatedTask)
      }
    }
  }
}

struct ReviewTaskEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: ReviewTask
  var onSave: (ReviewTask) -> Void

  init(task: ReviewTask, onSave: @escaping (ReviewTask) -> Void) {
    self._draft = State(initialValue: task)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Task") {
          TextField("Title", text: $draft.title)
          TextField("Summary", text: $draft.summary, axis: .vertical)
            .lineLimit(3...6)
          TextField("Due date", text: $draft.dueDate)
          TextField("Assigned team/person", text: $draft.assignee)
        }

        Section("Linked record") {
          Picker("Record type", selection: $draft.linkedEntityType) {
            ForEach(ReviewTaskLinkedEntityType.allCases) { entityType in
              Text(entityType.rawValue).tag(entityType)
            }
          }
          TextField("Linked record ID", text: $draft.linkedEntityID)
        }

        Section("State") {
          Picker("Priority", selection: $draft.priority) {
            ForEach(TaskPriority.allCases) { priority in
              Text(priority.rawValue).tag(priority)
            }
          }
          Picker("Status", selection: $draft.status) {
            ForEach(TaskStatus.allCases) { status in
              Text(status.rawValue).tag(status)
            }
          }
          Picker("Review state", selection: $draft.reviewState) {
            Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted)
            Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview)
            Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor)
          }
          TextField("Completed date", text: Binding(
            get: { draft.completedDate ?? "" },
            set: { draft.completedDate = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
          ))
        }
      }
      .navigationTitle("Edit task")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            onSave(draft)
            dismiss()
          }
        }
      }
      #if os(macOS)
      .frame(minWidth: 560, minHeight: 620)
      #endif
    }
  }
}

private struct TaskRouteCard: View {
  var title: String
  var detail: String
  var symbol: String
  var badge: String
  var tint: Color
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: symbol)
        .foregroundStyle(tint)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 5) {
        if isCompact {
          VStack(alignment: .leading, spacing: 6) {
            Text(title)
              .font(.headline)
            Badge(badge, color: tint)
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
        Badge(badge, color: tint)
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}
