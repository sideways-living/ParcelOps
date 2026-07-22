import SwiftUI

private struct ReleaseBlockerRow: Identifiable {
  let id = UUID()
  var title: String
  var detail: String
  var count: Int
  var symbol: String
  var color: Color
  var isClear: Bool
}

struct OperationsWorkbenchView: View {
  var store: ParcelOpsStore
  @State private var selectedAssignee: String?
  @State private var selectedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedPrioritySeverity: String?
  @State private var selectedStatus: String?
  @State private var selectedReviewState: ReviewState?
  @State private var selectedSource: WorkbenchSource?
  @State private var workbenchSearchText = ""
  @State private var showWorkbenchProviderEvidence = false
  @State private var showWorkbenchContextSections = false
  @State private var developmentStatusFeedbackMessage: String?
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var assignees: [String] {
    Array(Set(store.workbenchItems.map(\.assignee).filter { !$0.isEmpty })).sorted()
  }

  private var prioritySeverities: [String] {
    Array(Set(store.workbenchItems.map(\.prioritySeverity))).sorted()
  }

  private var statuses: [String] {
    Array(Set(store.workbenchItems.map(\.status))).sorted()
  }

  private var hasActiveFilters: Bool {
    selectedAssignee != nil
      || selectedEntityType != nil
      || selectedPrioritySeverity != nil
      || selectedStatus != nil
      || selectedReviewState != nil
      || selectedSource != nil
      || !workbenchSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var filteredItems: [WorkbenchItem] {
    store.filteredWorkbenchItems(
      assignee: selectedAssignee,
      linkedEntityType: selectedEntityType,
      prioritySeverity: selectedPrioritySeverity,
      status: selectedStatus,
      reviewState: selectedReviewState,
      source: selectedSource
    )
  }

  private var defaultQueueItems: [WorkbenchItem] {
    store.openWorkbenchItems.filter { item in
      item.source != .intakeParser
    }
  }

  private var queueItems: [WorkbenchItem] {
    let baseItems = hasStructuredFilters ? filteredItems : defaultQueueItems
    let query = workbenchSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else {
      return baseItems
    }
    let searchableItems = hasStructuredFilters ? filteredItems : store.openWorkbenchItems
    return searchableItems.filter { item in
      [
        item.title,
        item.summary,
        item.linkedEntityType.rawValue,
        item.linkedEntityID,
        item.prioritySeverity,
        item.status,
        item.assignee,
        item.source.rawValue,
        item.suggestedNextAction
      ].joined(separator: " ").localizedLowercase.contains(query)
    }
  }

  private var hasStructuredFilters: Bool {
    selectedAssignee != nil
      || selectedEntityType != nil
      || selectedPrioritySeverity != nil
      || selectedStatus != nil
      || selectedReviewState != nil
      || selectedSource != nil
  }

  private var shouldShowWorkbenchContextSections: Bool {
    showWorkbenchContextSections || hasActiveFilters
  }

  private var inboxCreatedOrders: [TrackedOrder] {
    Array(
      store.operatorSourceOrders
        .filter { order in
          needsPreDispatchVerification(order)
            || order.reviewState != .accepted
            || needsDispatchSetup(order)
            || needsInboxDispatchReadiness(order)
            || hasReopenedInboxDispatchHandoff(order)
        }
        .sorted { first, second in
          let firstPriority = inboxOrderFollowUpPriority(first)
          let secondPriority = inboxOrderFollowUpPriority(second)
          if firstPriority == secondPriority {
            return first.orderNumber.localizedCaseInsensitiveCompare(second.orderNumber) == .orderedAscending
          }
          return firstPriority > secondPriority
        }
        .prefix(5)
    )
  }

  private var draftFollowUpItems: [DraftMessage] {
    let providerDrafts = store.mailboxProviderDraftMessagesNeedingReview
    let otherDrafts = store.draftMessagesNeedingReview.filter { draft in
      !providerDrafts.contains(where: { $0.id == draft.id })
    }
    return Array((providerDrafts + otherDrafts).prefix(5))
  }

  private var developmentStatusTasks: [ReviewTask] {
    store.reviewTasks.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == "development-status-checkpoint"
        && $0.status != .completed
    }
  }

  private var developmentStatusHandoffs: [HandoffNote] {
    store.handoffNotes.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == "development-status-checkpoint"
        && $0.status != .completed
    }
  }

  private var developmentStatusDrafts: [DraftMessage] {
    store.draftMessages.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == "development-status-checkpoint"
        && $0.status != .sentLocally
    }
  }

  private var developmentStatusFollowUpCount: Int {
    developmentStatusTasks.count + developmentStatusHandoffs.count + developmentStatusDrafts.count
  }

  private var developmentStatusWorkbenchTone: Color {
    if developmentStatusTasks.contains(where: { $0.status == .blocked || $0.priority == .urgent || $0.priority == .high }) { return .orange }
    if developmentStatusFollowUpCount > 0 { return .teal }
    return .secondary
  }

  private var developmentStatusWorkbenchTitle: String {
    if developmentStatusTasks.contains(where: { $0.status == .blocked }) { return "Development status follow-up is blocked" }
    if !developmentStatusTasks.isEmpty { return "Development status follow-up is assigned" }
    if !developmentStatusHandoffs.isEmpty { return "Development status handoff is active" }
    if !developmentStatusDrafts.isEmpty { return "Development status draft is ready" }
    return "Development status is not promoted to Workbench"
  }

  private var developmentStatusWorkbenchDetail: String {
    if developmentStatusFollowUpCount > 0 {
      return "Use this when app readiness itself becomes operator work. The checkpoint links to the current status task, handoff, and local draft packet."
    }
    return "Create a status task, handoff, or draft only when someone needs to own the current development state. Routine app status stays in Dashboard, Settings, and Audit."
  }
  private var wishlistWorkbenchItems: [WishlistItem] {
    store.wishlistTaskContextItems
  }

  private var wishlistResearchWorkbenchRequests: [WishlistResearchRequest] {
    store.wishlistResearchAttentionRequests
  }

  private var wishlistBatchResearchDrafts: [DraftMessage] {
    store.wishlistBatchResearchDrafts
  }

  private var wishlistBatchBriefNeeded: Bool {
    store.wishlistBatchBriefNeeded
  }

  private var wishlistWorkbenchPurchaseFollowUpVisible: Bool {
    store.wishlistWorkbenchPurchaseFollowUpVisible
  }

  private var wishlistBatchBriefWorkbenchColor: Color {
    switch store.wishlistBatchBriefWorkbenchTone {
    case "warning":
      return .orange
    case "success":
      return .green
    default:
      return .secondary
    }
  }

  private var wishlistWorkbenchMetrics: [(String, String, Color)] {
    store.wishlistWorkbenchMetricSummaries.map { title, value, tone in
      (title, value, wishlistWorkbenchMetricColor(tone))
    }
  }

  private func wishlistWorkbenchMetricColor(_ tone: String) -> Color {
    switch tone {
    case "attention":
      return .purple
    case "critical":
      return .red
    case "success":
      return .green
    case "warning":
      return .orange
    case "handoff":
      return .teal
    case "dispatch":
      return .blue
    case "packet":
      return .indigo
    case "decisionMuted":
      return .brown
    case "muted":
      return .secondary
    default:
      return .secondary
    }
  }

  private var wishlistAgentReadiness: WishlistAgentReadinessSummary {
    store.wishlistAgentReadinessSummary
  }

  private var wishlistAgentReadinessTint: Color {
    switch wishlistAgentReadiness.tone {
    case "success":
      return .green
    case "warning":
      return .orange
    case "attention":
      return .purple
    default:
      return .secondary
    }
  }

  private var wishlistTopReadinessBlocker: WishlistAgentReadinessItem? {
    wishlistAgentReadiness.items.first { $0.tone == "warning" }
      ?? wishlistAgentReadiness.items.first { $0.tone == "attention" }
      ?? wishlistAgentReadiness.items.first { $0.tone != "success" }
  }

  private var wishlistTopReadinessBlockerTint: Color {
    guard let item = wishlistTopReadinessBlocker else {
      return wishlistAgentReadinessTint
    }

    switch item.tone {
    case "success":
      return .green
    case "warning":
      return .orange
    case "attention":
      return .purple
    default:
      return .secondary
    }
  }

  private var wishlistPurchasePacketNeededItems: [WishlistItem] {
    store.wishlistPurchasePacketNeededItems
  }

  private var spaceMailHealthSummaries: [SpaceMailIntakeHealthSummary] {
    store.spaceMailIntakeHealthSummaries
  }

  private var spaceMailPostRefreshPlan: SpaceMailPostRefreshActionPlan {
    store.spaceMailPostRefreshActionPlan
  }

  private var spaceMailFetchedCount: Int {
    store.totalSpaceMailFetchedCount
  }

  private var spaceMailImportedCount: Int {
    store.totalSpaceMailImportedCount
  }

  private var spaceMailDuplicateCount: Int {
    store.totalSpaceMailDuplicateCount
  }

  private var spaceMailFilteredCount: Int {
    store.totalSpaceMailFilteredCount
  }

  private var spaceMailUncertainCount: Int {
    store.totalSpaceMailUncertainCount
  }

  private var gmailHealthSummaries: [GmailIntakeHealthSummary] {
    store.gmailIntakeHealthSummaries
  }

  private var microsoft365HealthSummaries: [Microsoft365IntakeHealthSummary] {
    store.microsoft365IntakeHealthSummaries
  }

  private var gmailFetchedCount: Int {
    store.totalGmailFetchedCount
  }

  private var gmailImportedCount: Int {
    store.totalGmailImportedCount
  }

  private var gmailFilteredCount: Int {
    store.gmailFilteredMailboxSignalCount
  }

  private var gmailUncertainCount: Int {
    store.pendingGmailUncertainReviewCount
  }

  private var pendingGmailFilteredReviewCount: Int {
    store.pendingGmailFilteredReviewCount
  }

  private var gmailClassifierHintCount: Int {
    store.gmailClassifierHintCount
  }

  private var gmailClassifierTestIssueCount: Int {
    store.gmailClassifierDecisionIssueCount
  }

  private var gmailClassifierTuningCount: Int {
    gmailClassifierTestIssueCount + gmailUncertainCount + pendingGmailFilteredReviewCount
  }

  private var gmailWarningCount: Int {
    gmailHealthSummaries.filter { $0.tone == "warning" || $0.tone == "attention" }.count
  }

  private var gmailReleaseSelfChecks: [GmailReleaseSelfCheckSummary] {
    store.gmailMailboxConnections.map { store.gmailReleaseSelfCheckSummary(for: $0) }
  }

  private var microsoft365ReleaseSelfChecks: [Microsoft365ReleaseSelfCheckSummary] {
    store.microsoft365MailboxConnections.map { store.microsoft365ReleaseSelfCheckSummary(for: $0) }
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

  private var gmailProviderFitAttentionCount: Int {
    gmailReleaseSelfChecks.reduce(0) { total, summary in
      total + summary.items.filter { !$0.isComplete && $0.title == "Provider fit" }.count
    }
  }

  private var activeGmailRefreshTasks: [ReviewTask] {
    store.reviewTasks.filter { task in
      task.linkedEntityType == .integration
        && task.linkedEntityID.localizedCaseInsensitiveContains("gmail-latest-refresh-")
        && task.status != .completed
    }
  }

  private var microsoft365ReleaseBlockingCount: Int {
    microsoft365ReleaseSelfChecks.reduce(0) { total, summary in
      total + summary.items.filter { !$0.isComplete && $0.tone == "warning" }.count
    }
  }

  private var microsoft365ReleaseAttentionCount: Int {
    microsoft365ReleaseSelfChecks.reduce(0) { total, summary in
      total + summary.items.filter { !$0.isComplete && $0.tone == "attention" }.count
    }
  }

  private var microsoft365GraphBlockerCount: Int {
    microsoft365ReleaseSelfChecks.reduce(0) { $0 + $1.graphBlockerCount }
  }

  private var microsoft365ImportedCount: Int {
    store.microsoft365IntakeHealthSummaries.reduce(0) { $0 + $1.importedCount }
  }

  private var microsoft365BlockedCount: Int {
    store.microsoft365IntakeHealthSummaries.reduce(0) { $0 + $1.blockedCount }
  }

  private var microsoft365UncertainCount: Int {
    store.pendingMicrosoft365UncertainReviewCount
  }

  private var microsoft365FilteredReviewCount: Int {
    store.pendingMicrosoft365FilteredReviewCount
  }

  private var activeMicrosoft365ReleaseTasks: [ReviewTask] {
    store.reviewTasks.filter { task in
      task.linkedEntityType == .integration
        && task.title.localizedCaseInsensitiveContains("Outlook release self-check")
        && task.status != .completed
    }
  }

  private var mailboxFetchedCount: Int {
    store.totalMailboxFetchedCount
  }

  private var mailboxImportedCount: Int {
    store.totalMailboxImportedCount
  }

  private var mailboxFilteredCount: Int {
    store.totalMailboxFilteredSignalCount
  }

  private var mailboxUncertainCount: Int {
    store.totalMailboxUncertainSignalCount
  }

  private var mailboxDuplicateCount: Int {
    store.totalMailboxDuplicateCount
  }

  private var spaceMailMailboxCountsText: String {
    "\(spaceMailFetchedCount) fetched, \(spaceMailImportedCount) imported, \(spaceMailDuplicateCount) duplicate, \(store.totalSpaceMailDuplicateRefreshedCount) refreshed, \(spaceMailFilteredCount) filtered, \(spaceMailUncertainCount) uncertain."
  }

  private var gmailMailboxCountsText: String {
    "\(gmailFetchedCount) fetched, \(gmailImportedCount) imported, \(store.totalGmailDuplicateCount) duplicate, \(store.totalGmailDuplicateRefreshedCount) refreshed, \(gmailFilteredCount) filtered, \(gmailUncertainCount) uncertain."
  }

  private var microsoft365MailboxCountsText: String {
    "\(store.totalMicrosoft365FetchedCount) fetched, \(store.totalMicrosoft365ImportedCount) imported, \(store.totalMicrosoft365DuplicateCount) duplicate, \(store.totalMicrosoft365DuplicateRefreshedCount) refreshed, \(store.totalMicrosoft365FilteredCount) filtered, \(store.totalMicrosoft365UncertainCount) uncertain, \(store.totalMicrosoft365BlockedCount) blocker."
  }

  private var mailboxWarningCount: Int {
    gmailWarningCount + store.totalMicrosoft365BlockedCount + store.intakeParserDiagnostics.count
  }

  private var weakInboxParseCount: Int {
    store.reviewIntakeEmails.filter { email in
      email.detectedOrderNumber.isPlaceholderValidationValue
        || email.detectedTrackingNumber.isPlaceholderValidationValue
    }.count
  }

  private var partialInboxParseCount: Int {
    store.reviewIntakeEmails.filter { email in
      !email.detectedOrderNumber.isPlaceholderValidationValue
        && !email.detectedTrackingNumber.isPlaceholderValidationValue
        && (
          email.detectedMerchant.isPlaceholderValidationValue
            || email.detectedDestinationAddress.isPlaceholderValidationValue
        )
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

  private var intakeParserQualityTone: Color {
    if weakInboxParseCount > 0 || store.intakeParserDiagnostics.contains(where: { $0.severity == .critical || $0.severity == .high }) { return .orange }
    if readyInboxLinkCount > 0 || partialInboxParseCount > 0 { return .teal }
    return .green
  }

  private var intakeParserQualityTitle: String {
    if weakInboxParseCount > 0 { return "Inbox parser corrections before Workbench" }
    if readyInboxLinkCount > 0 { return "Inbox rows are ready to become order work" }
    if partialInboxParseCount > 0 { return "Partial Inbox parses need confirmation" }
    if linkedInboxIntakeCount > 0 { return "Linked order source trails are ready for review" }
    return "No mailbox intake handoff is blocking Workbench"
  }

  private var intakeParserQualityDetail: String {
    if weakInboxParseCount > 0 {
      return "\(weakInboxParseCount) intake row\(weakInboxParseCount == 1 ? "" : "s") still lack order or tracking numbers. Fix these in Inbox before creating Workbench exception work."
    }
    if readyInboxLinkCount > 0 {
      return "\(readyInboxLinkCount) intake row\(readyInboxLinkCount == 1 ? "" : "s") have usable order/tracking signals. Create or link orders before dispatch or exception follow-up."
    }
    if partialInboxParseCount > 0 {
      return "\(partialInboxParseCount) intake row\(partialInboxParseCount == 1 ? "" : "s") have order/tracking signals but need merchant or destination confirmation."
    }
    if linkedInboxIntakeCount > 0 {
      return "\(linkedInboxIntakeCount) intake row\(linkedInboxIntakeCount == 1 ? "" : "s") already link to orders. Use Workbench only when the linked order has a real exception or follow-up."
    }
    return "Mailbox parser, link, and source-trail handoff counts are clear. Workbench can stay focused on real operational exceptions."
  }

  private var pendingFilteredSpaceMailCount: Int {
    store.totalSpaceMailPendingFilteredReviewCount
  }

  private var spaceMailFilteredOnlyOutcome: Bool {
    spaceMailFetchedCount > 0
      && spaceMailImportedCount == 0
      && spaceMailUncertainCount == 0
      && spaceMailFilteredCount > 0
  }

  private var mailboxFilteredOnlyOutcome: Bool {
    mailboxFetchedCount > 0
      && mailboxImportedCount == 0
      && mailboxUncertainCount == 0
      && mailboxFilteredCount > 0
  }

  private var mailboxWorkbenchBoundaryTone: String {
    if mailboxWarningCount > 0 { return "warning" }
    if mailboxImportedCount > 0 || mailboxUncertainCount > 0 || !inboxCreatedOrders.isEmpty { return "attention" }
    if mailboxFilteredOnlyOutcome { return "success" }
    if mailboxFetchedCount > 0 || mailboxDuplicateCount > 0 { return "neutral" }
    return "neutral"
  }

  private var mailboxWorkbenchBoundaryTitle: String {
    if mailboxWarningCount > 0 { return "Mailbox diagnostics need review" }
    if mailboxImportedCount > 0 { return "Mailbox intake created Inbox work" }
    if mailboxUncertainCount > 0 { return "Mailbox has uncertain order mail" }
    if !inboxCreatedOrders.isEmpty { return "Source orders need follow-up" }
    if mailboxFilteredOnlyOutcome { return "Mixed mailbox filtering kept Workbench clean" }
    if mailboxDuplicateCount > 0 { return "Mailbox refresh found existing messages" }
    if mailboxFetchedCount > 0 { return "Latest refresh created no Workbench work" }
    return "Mailbox handoff has no current pressure"
  }

  private var mailboxWorkbenchBoundaryDetail: String {
    if mailboxWarningCount > 0 {
      return "\(mailboxWarningCount) mailbox diagnostic or parser issue\(mailboxWarningCount == 1 ? "" : "s") should be reviewed in Mailbox Monitor before creating Workbench exceptions."
    }
    if mailboxImportedCount > 0 {
      return "\(mailboxImportedCount) likely order message\(mailboxImportedCount == 1 ? "" : "s") reached Inbox from an active mailbox provider. Review or create/link orders there before expecting Workbench exceptions."
    }
    if mailboxUncertainCount > 0 {
      return "\(mailboxUncertainCount) ambiguous mailbox preview\(mailboxUncertainCount == 1 ? "" : "s") is waiting outside Inbox. Import genuine order mail from Mailbox Monitor or dismiss it locally."
    }
    if !inboxCreatedOrders.isEmpty {
      return "\(inboxCreatedOrders.count) Inbox-created or Wishlist-linked order\(inboxCreatedOrders.count == 1 ? "" : "s") already \(inboxCreatedOrders.count == 1 ? "exists" : "exist"). Confirm source trail, order detail, and dispatch setup before treating them as exceptions."
    }
    if mailboxFilteredOnlyOutcome {
      return "\(mailboxFilteredCount) mixed-mailbox message\(mailboxFilteredCount == 1 ? "" : "s") were filtered out of Inbox. There is no Workbench exception until order mail is imported, promoted, or created."
    }
    let refreshedDuplicateCount = store.totalMailboxDuplicateRefreshedCount
    if refreshedDuplicateCount > 0 {
      return "\(refreshedDuplicateCount) duplicate mailbox message\(refreshedDuplicateCount == 1 ? "" : "s") refreshed existing intake rows. Confirm the intake row or linked order before creating Workbench work."
    }
    if mailboxDuplicateCount > 0 {
      return "\(mailboxDuplicateCount) duplicate mailbox message\(mailboxDuplicateCount == 1 ? "" : "s") were already captured or reviewed. No new Workbench work was created."
    }
    if mailboxFetchedCount > 0 {
      return "The latest mailbox refresh fetched mail but produced no imported or uncertain order work. Use Mailbox Monitor only if an expected order is missing."
    }
    return "Run a manual mailbox refresh from Mailbox Monitor when mailbox intake needs checking."
  }

  private var mailboxProviderWorkbenchBreakdown: [(provider: String, detail: String, color: Color)] {
    var rows: [(provider: String, detail: String, color: Color)] = []

    if !spaceMailHealthSummaries.isEmpty {
      rows.append((
        "SpaceMail",
        spaceMailMailboxCountsText,
        spaceMailImportedCount > 0 ? .green : spaceMailUncertainCount > 0 ? .orange : spaceMailFilteredCount > 0 ? .teal : .secondary
      ))
    }

    if !gmailHealthSummaries.isEmpty {
      rows.append((
        "Gmail",
        gmailMailboxCountsText,
        gmailImportedCount > 0 ? .green : gmailUncertainCount > 0 ? .orange : gmailFilteredCount > 0 ? .teal : gmailWarningCount > 0 ? .orange : .secondary
      ))
    }

    if !microsoft365HealthSummaries.isEmpty {
      rows.append((
        "Microsoft 365",
        microsoft365MailboxCountsText,
        store.totalMicrosoft365BlockedCount > 0 ? .red : store.totalMicrosoft365ImportedCount > 0 ? .green : store.totalMicrosoft365DuplicateCount > 0 ? .teal : .secondary
      ))
    }

    return rows
  }

  private var setupPlaceholderReviewItems: [WorkbenchItem] {
    defaultQueueItems.filter { $0.source == .setupPlaceholder }
  }

  private var dailyAttentionCount: Int {
    store.reviewIntakeEmails.count
      + store.pendingMailboxReviewCount
      + store.importQueueItemsNeedingReview.count
      + store.blockedImportQueueItems.count
      + store.acceptanceRecordsNeedingReview.count
      + store.reviewOrders.count
      + store.blockedShipmentManifests.count
      + store.blockedDispatchChecklists.count
      + store.reviewTasksNeedingAttention.count
      + store.handoffNotesNeedingAttention.count
      + store.draftMessagesNeedingReview.count
      + store.highPriorityWorkbenchItems.count
      + setupPlaceholderReviewItems.count
      + reopenedInboxDispatchHandoffCount
  }

  private var releaseProviderReadyCount: Int {
    let spaceMailReady = store.spaceMailIMAPConnections.contains { connection in
      !connection.emailAddressUsername.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
        && !connection.imapHost.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
        && connection.credentialStorageStatus.localizedCaseInsensitiveContains("available")
    }
    let gmailReady = store.gmailMailboxConnections.contains { connection in
      store.gmailAuthSessionState(for: connection).status == .connected
    }
    return [spaceMailReady, gmailReady].filter { $0 }.count
  }

  private var releaseMailboxEvidenceCount: Int {
    mailboxFetchedCount + mailboxImportedCount + mailboxFilteredCount + mailboxUncertainCount + mailboxDuplicateCount
  }

  private var releaseInboxOrderCount: Int {
    store.inboxCreatedOrderCount
  }

  private var releaseDispatchBlockerCount: Int {
    store.blockedShipmentManifests.count + store.blockedDispatchChecklists.count + reopenedInboxDispatchHandoffCount + inboxDispatchReadinessOrders.count
  }

  private var releaseTaskBlockerCount: Int {
    store.reviewTasksNeedingAttention.count + store.handoffNotesNeedingAttention.count + draftFollowUpItems.count
  }

  private var releaseCleanupSignalCount: Int {
    store.localDataHygieneSummary.signalCount + store.intakeParserDiagnostics.count
  }

  private var releaseReadyStepCount: Int {
    releaseBlockerRows.filter(\.isClear).count
  }

  private var releaseBlockerTone: Color {
    if releaseReadyStepCount >= releaseBlockerRows.count - 1 && releaseCleanupSignalCount < 20 { return .green }
    if releaseProviderReadyCount > 0 && releaseMailboxEvidenceCount > 0 && releaseInboxOrderCount > 0 { return .teal }
    return .orange
  }

  private var releaseBlockerTitle: String {
    if releaseReadyStepCount >= releaseBlockerRows.count - 1 && releaseCleanupSignalCount < 20 {
      return "Release path is mostly clear"
    }
    if releaseProviderReadyCount > 0 && releaseMailboxEvidenceCount > 0 && releaseInboxOrderCount > 0 {
      return "Core flow works; clear follow-up before RC"
    }
    return "Prove the mailbox-to-order path first"
  }

  private var releaseBlockerDetail: String {
    if releaseReadyStepCount >= releaseBlockerRows.count - 1 && releaseCleanupSignalCount < 20 {
      return "Provider setup, refresh evidence, Inbox-created orders, and operational routing are visible. Run a focused hands-on pass and avoid expanding scope until remaining review work is intentional."
    }
    if releaseProviderReadyCount > 0 && releaseMailboxEvidenceCount > 0 && releaseInboxOrderCount > 0 {
      return "The daily path has live intake evidence and at least one Inbox-created order. Work down dispatch, task, and cleanup signals before treating this as a release candidate."
    }
    return "Start with Mailbox Monitor, import one likely order email, create or link the order from Inbox, then check Orders, Dispatch, Tasks, and Audit."
  }

  private var releaseBlockerRows: [ReleaseBlockerRow] {
    [
      ReleaseBlockerRow(
        title: "Mailbox provider ready",
        detail: releaseProviderReadyCount > 0 ? "\(releaseProviderReadyCount) provider path has usable local credential or sign-in state." : "Set up SpaceMail, Gmail, or Outlook before relying on live intake.",
        count: releaseProviderReadyCount,
        symbol: "server.rack",
        color: releaseProviderReadyCount > 0 ? .green : .orange,
        isClear: releaseProviderReadyCount > 0
      ),
      ReleaseBlockerRow(
        title: "Refresh evidence captured",
        detail: releaseMailboxEvidenceCount > 0 ? "\(releaseMailboxEvidenceCount) mailbox refresh signal\(releaseMailboxEvidenceCount == 1 ? "" : "s") are available across fetched, imported, filtered, uncertain, or duplicate results." : "Run a manual provider refresh from Mailbox Monitor.",
        count: releaseMailboxEvidenceCount,
        symbol: "arrow.clockwise.circle.fill",
        color: releaseMailboxEvidenceCount > 0 ? .green : .orange,
        isClear: releaseMailboxEvidenceCount > 0
      ),
      ReleaseBlockerRow(
        title: "Inbox-to-order handoff",
        detail: releaseInboxOrderCount > 0 ? "\(releaseInboxOrderCount) order\(releaseInboxOrderCount == 1 ? "" : "s") exist from Inbox/import handoff." : "Create or link one order from Inbox so downstream screens have real local context.",
        count: releaseInboxOrderCount,
        symbol: "shippingbox.fill",
        color: releaseInboxOrderCount > 0 ? .green : .orange,
        isClear: releaseInboxOrderCount > 0
      ),
      ReleaseBlockerRow(
        title: "Dispatch blockers",
        detail: releaseDispatchBlockerCount == 0 ? "No blocked manifest, readiness, reopened handoff, or Inbox dispatch setup signals are promoted." : "\(releaseDispatchBlockerCount) dispatch signal\(releaseDispatchBlockerCount == 1 ? "" : "s") still need local confirmation.",
        count: releaseDispatchBlockerCount,
        symbol: "paperplane.fill",
        color: releaseDispatchBlockerCount == 0 ? .green : .blue,
        isClear: releaseDispatchBlockerCount == 0
      ),
      ReleaseBlockerRow(
        title: "Owned follow-up",
        detail: releaseTaskBlockerCount == 0 ? "Tasks, handoffs, and drafts are quiet enough for a release-candidate pass." : "\(releaseTaskBlockerCount) task, handoff, or draft signal\(releaseTaskBlockerCount == 1 ? "" : "s") still need owner review.",
        count: releaseTaskBlockerCount,
        symbol: "checklist",
        color: releaseTaskBlockerCount == 0 ? .green : .purple,
        isClear: releaseTaskBlockerCount == 0
      ),
      ReleaseBlockerRow(
        title: "Cleanup pressure",
        detail: releaseCleanupSignalCount == 0 ? "No local hygiene or parser diagnostic signal is open." : "\(releaseCleanupSignalCount) hygiene/parser signal\(releaseCleanupSignalCount == 1 ? "" : "s") remain. Clean only active confusion; preserve useful audit history.",
        count: releaseCleanupSignalCount,
        symbol: "stethoscope",
        color: releaseCleanupSignalCount < 20 ? .teal : .orange,
        isClear: releaseCleanupSignalCount < 20
      )
    ]
  }

  private var advancedBacklogCount: Int {
    max(store.reviewQueueCount - dailyAttentionCount, 0)
  }

  private var urgentWorkbenchCount: Int {
    defaultQueueItems.filter { $0.isDueOrOverdue }.count
      + defaultQueueItems.filter { $0.rank >= 3 }.count
  }

  private var workbenchNextActionTone: Color {
    if urgentWorkbenchCount > 0 || defaultQueueItems.filter(\.isBlocked).count > 0 { return .red }
    if reopenedInboxDispatchHandoffCount > 0 { return .purple }
    if !partialInboxOrderBlockers.isEmpty { return .orange }
    if !inboxDispatchReadinessOrders.isEmpty { return .teal }
    if !inboxCreatedOrders.isEmpty { return .teal }
    if !draftFollowUpItems.isEmpty { return .orange }
    if !setupPlaceholderReviewItems.isEmpty { return .teal }
    if defaultQueueItems.filter({ $0.reviewState == .needsReview }).count > 0 { return .purple }
    if defaultQueueItems.isEmpty { return .green }
    return .blue
  }

  private var workbenchNextActionTitle: String {
    if urgentWorkbenchCount > 0 { return "Start with urgent work" }
    if defaultQueueItems.filter(\.isBlocked).count > 0 { return "Clear blocked work" }
    if reopenedInboxDispatchHandoffCount > 0 { return "Review reopened dispatch handoffs" }
    if !partialInboxOrderBlockers.isEmpty { return "Verify partial source orders" }
    if !inboxDispatchReadinessOrders.isEmpty { return "Finish source dispatch readiness" }
    if !inboxCreatedOrders.isEmpty { return "Confirm source orders" }
    if !draftFollowUpItems.isEmpty { return "Send or review draft follow-up" }
    if !setupPlaceholderReviewItems.isEmpty { return "Review setup placeholders" }
    if defaultQueueItems.filter({ $0.reviewState == .needsReview }).count > 0 { return "Review open exceptions" }
    if defaultQueueItems.isEmpty { return "Workbench is clear" }
    return "Work the open exception queue"
  }

  private var workbenchNextActionDetail: String {
    if urgentWorkbenchCount > 0 {
      return "\(urgentWorkbenchCount) overdue or high-priority item\(urgentWorkbenchCount == 1 ? " is" : "s are") promoted. Open the first row, create a task or draft, then mark reviewed where supported."
    }
    let blockedCount = defaultQueueItems.filter(\.isBlocked).count
    let needsReviewCount = defaultQueueItems.filter { $0.reviewState == .needsReview }.count
    if blockedCount > 0 {
      return "\(blockedCount) item\(blockedCount == 1 ? " is" : "s are") blocked. Resolve the blocker or route it to the detailed screen before reviewing routine work."
    }
    if reopenedInboxDispatchHandoffCount > 0 {
      return "\(reopenedInboxDispatchHandoffCount) source dispatch handoff record\(reopenedInboxDispatchHandoffCount == 1 ? " was" : "s were") reopened. Open the linked order and Dispatch context before closing \(reopenedInboxDispatchHandoffCount == 1 ? "it" : "them") again."
    }
    if !partialInboxOrderBlockers.isEmpty {
      return "\(partialInboxOrderBlockers.count) Inbox-created or Wishlist-linked order\(partialInboxOrderBlockers.count == 1 ? "" : "s") \(partialInboxOrderBlockers.count == 1 ? "has" : "have") missing details or an open verification task. Open the order before dispatch setup."
    }
    if !inboxDispatchReadinessOrders.isEmpty {
      return "\(inboxDispatchReadinessOrders.count) Inbox-created or Wishlist-linked order\(inboxDispatchReadinessOrders.count == 1 ? "" : "s") \(inboxDispatchReadinessOrders.count == 1 ? "has" : "have") local dispatch setup but still \(inboxDispatchReadinessOrders.count == 1 ? "needs" : "need") readiness, label, scan, custody, or handoff confirmation."
    }
    if !inboxCreatedOrders.isEmpty {
      return "\(inboxCreatedOrders.count) Inbox-created or Wishlist-linked order\(inboxCreatedOrders.count == 1 ? "" : "s") \(inboxCreatedOrders.count == 1 ? "needs" : "need") operational confirmation or dispatch setup before \(inboxCreatedOrders.count == 1 ? "it disappears" : "they disappear") from daily follow-up."
    }
    if !draftFollowUpItems.isEmpty {
      return "\(draftFollowUpItems.count) draft\(draftFollowUpItems.count == 1 ? "" : "s") \(draftFollowUpItems.count == 1 ? "needs" : "need") review, sending, or reopening before the related work can be closed."
    }
    if !setupPlaceholderReviewItems.isEmpty {
      return "\(setupPlaceholderReviewItems.count) setup placeholder needs local review or removal. Open Settings to confirm it remains planning-only."
    }
    if needsReviewCount > 0 {
      return "\(needsReviewCount) item still needs local review after context is checked."
    }
    if defaultQueueItems.isEmpty {
      return "No open workbench exceptions are promoted. Use filters only when you need supporting record detail."
    }
    return "\(defaultQueueItems.count) open item is available for routine exception review."
  }

  private var operatorSections: [WorkbenchItemGroup] {
    let urgent = unique(queueItems.filter { $0.isDueOrOverdue || $0.rank >= 3 })
    let blocked = unique(queueItems.filter { $0.isBlocked }, excluding: urgent)
    let exceptions = unique(queueItems.filter { $0.isException }, excluding: urgent + blocked)
    let highRiskShipments = unique(queueItems.filter {
      [.shipmentGroup, .shipmentManifest, .dispatchChecklist, .tracking].contains($0.source)
        && ($0.rank >= 3 || $0.reviewState == .needsReview)
    }, excluding: urgent + blocked + exceptions)
    let needsReview = unique(queueItems.filter { $0.reviewState == .needsReview }, excluding: urgent + blocked + exceptions + highRiskShipments)
    let recent = unique(Array(queueItems.prefix(8)), excluding: urgent + blocked + exceptions + highRiskShipments + needsReview)

    return [
      WorkbenchItemGroup(title: "Urgent now", symbol: "flame.fill", items: urgent),
      WorkbenchItemGroup(title: "Blocked work", symbol: "hand.raised.fill", items: blocked),
      WorkbenchItemGroup(title: "Exceptions and mismatches", symbol: "arrow.triangle.2.circlepath.circle.fill", items: exceptions),
      WorkbenchItemGroup(title: "High-risk shipments", symbol: "shippingbox.and.arrow.backward.fill", items: highRiskShipments),
      WorkbenchItemGroup(title: "Needs review", symbol: "checkmark.shield.fill", items: needsReview),
      WorkbenchItemGroup(title: "Recently updated", symbol: "clock.fill", items: recent)
    ].filter { !$0.items.isEmpty }
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 16) {
        header
        MVPWorkflowGuide(
          title: "How to use the workbench",
          detail: "This is the daily triage surface. Start here when you want the most actionable work, not every record in the system.",
          steps: [
            "Start with Due or overdue, High priority, and Blocked sections.",
            "Create a task when work needs ownership.",
            "Create a draft when someone needs to be contacted.",
            "Mark supported records reviewed after the local follow-up is complete."
          ],
          symbol: "rectangle.stack.badge.person.crop.fill"
        )
        OperatorDailyWorkloadSummary(
          dailyAttentionCount: dailyAttentionCount,
          advancedBacklogCount: advancedBacklogCount,
          reviewQueueCount: store.reviewQueueCount,
          titleWhenClear: "Workbench primary flow is clear",
          titleWhenBusy: "Workbench has daily exceptions to clear",
          detailWhenClear: "No primary workflow exceptions are waiting. Use advanced filters only when you need supporting records.",
          detailWhenBusy: "Clear urgent, blocked, needs-review, and Inbox-created order work before opening advanced record queues."
        )
        operatorSummary
        workbenchContextSectionsPanel
        operatorQueue
        if shouldShowWorkbenchContextSections {
          workbenchSupportingContextSections
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
    .background(.regularMaterial)
  }

  private var workbenchContextSectionsPanel: some View {
    SettingsPanel(title: "Workbench context sections", symbol: "line.3.horizontal.decrease.circle.fill") {
      Text(shouldShowWorkbenchContextSections ? "Supporting diagnostics, provider follow-up, release checks, drafts, Wishlist purchase follow-up, and advanced filters are visible." : "Workbench opens with workload summary and the exception queue first. Open context sections when you need diagnostics, provider setup evidence, release checks, drafts, Wishlist purchase follow-up, or advanced filters.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      MetricStrip(items: [
        ("Primary queue", "\(defaultQueueItems.count)", defaultQueueItems.isEmpty ? .green : .orange),
        ("Due/high", "\(urgentWorkbenchCount)", urgentWorkbenchCount == 0 ? .green : .red),
        ("Blocked", "\(defaultQueueItems.filter(\.isBlocked).count)", defaultQueueItems.contains(where: \.isBlocked) ? .red : .green),
        ("Review", "\(defaultQueueItems.filter { $0.reviewState == .needsReview }.count)", defaultQueueItems.contains { $0.reviewState == .needsReview } ? .purple : .green),
        ("Advanced", "\(advancedBacklogCount)", advancedBacklogCount == 0 ? .green : .secondary)
      ])

      CompactActionRow {
        Button(shouldShowWorkbenchContextSections ? "Hide context sections" : "Show context sections", systemImage: shouldShowWorkbenchContextSections ? "chevron.up.circle" : "chevron.down.circle") {
          showWorkbenchContextSections.toggle()
        }
        .buttonStyle(.bordered)

        if hasActiveFilters && !showWorkbenchContextSections {
          Badge("Filters active", color: .orange)
        }
      }
    }
  }

  @ViewBuilder
  private var workbenchSupportingContextSections: some View {
    releaseCandidateBlockersPanel
    developmentStatusWorkbenchPanel
    resolutionLadderPanel
    workbenchProviderEvidencePanel
    mailboxWorkbenchBoundary
    gmailWorkbenchBoundary
    microsoft365WorkbenchBoundary
    inboxParserQualityHandoff
    mailboxAssignedFollowUpPanel
    workbenchDiagnosticsBoundary
    inboxCreatedOrderFollowUp
    draftFollowUpPanel
    wishlistPurchaseFollowUpPanel
    advancedFilters
  }

  private var workbenchProviderEvidencePanel: some View {
    SettingsPanel(title: "Mailbox provider evidence", symbol: "point.3.connected.trianglepath.dotted") {
      DisclosureGroup(isExpanded: $showWorkbenchProviderEvidence) {
        VStack(alignment: .leading, spacing: 14) {
          MailboxProviderQuickStatusCard(summary: store.mailboxProviderComparisonSummary, store: store)
          MailboxProviderAdvancedDiagnosticsDisclosure(store: store)
          SpaceMailPrimaryStatusStrip(store: store)
          SpaceMailQACheckCard(summary: store.mailboxIntakeQualitySummary)
          SpaceMailRefreshTrendCard(summary: store.spaceMailRefreshTrendSummary)
          MailboxProviderPostRefreshDisclosure(
            title: "SpaceMail refresh follow-up",
            detail: "Open this when SpaceMail refresh results need Workbench follow-up. The exception queue remains the primary work here.",
            symbol: "server.rack",
            tone: .teal,
            statusLabel: "SpaceMail"
          ) {
            SpaceMailPostRefreshActionCard(plan: spaceMailPostRefreshPlan)
            SpaceMailShiftHandoffCard(
              summary: store.spaceMailShiftHandoffSummary,
              onCreateDraft: { store.createSpaceMailShiftDraftMessage() }
            )
          }
          GmailRefreshTrendCard(summary: store.gmailRefreshTrendSummary)
          Microsoft365RefreshTrendCard(summary: store.microsoft365RefreshTrendSummary)
          MailboxProviderPostRefreshDisclosure(
            title: "Gmail refresh follow-up",
            detail: "Open this when Gmail refresh results need Workbench follow-up. Keep it collapsed while working operational exceptions.",
            symbol: "envelope.badge.shield.half.filled",
            tone: .pink,
            statusLabel: "Gmail"
          ) {
            GmailPostRefreshActionCard(plan: store.gmailPostRefreshActionPlan)
            GmailShiftHandoffCard(
              summary: store.gmailShiftHandoffSummary,
              onCreateHandoffNote: { store.createGmailShiftHandoffNote() },
              onCreateTask: { store.createGmailShiftReviewTask() },
              onCreateDraft: { store.createGmailShiftDraftMessage() }
            )
          }
          Text("Mailbox refresh trends are context for triage across active providers. Imported and uncertain messages can create work; filtered mixed-mailbox messages remain out of Workbench unless promoted from Mailbox Monitor.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
      } label: {
        VStack(alignment: .leading, spacing: 4) {
          Text(showWorkbenchProviderEvidence ? "Hide provider evidence" : "Show provider evidence")
            .font(.subheadline.weight(.semibold))
          Text("Use this only when mailbox setup, parser quality, or refresh evidence explains an exception. Daily triage should start with the workload summary and queue sections.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .tint(.teal)
    }
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Operations Workbench")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("A focused queue for the most actionable local work across intake, orders, dispatch, exceptions, tasks, and handoffs.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(store.openWorkbenchItems.count) open", color: .blue)
        Badge("\(store.highPriorityWorkbenchItems.count) high", color: .orange)
      }
    }
  }

  private var resolutionLadderItems: [(title: String, detail: String, count: Int, destination: String, symbol: String, color: Color)] {
    let inboxCount = store.reviewIntakeEmails.count
      + store.importQueueItemsNeedingReview.count
      + store.blockedImportQueueItems.count
      + store.acceptanceRecordsNeedingReview.count
    let mailboxReviewCount = store.pendingMailboxReviewCount + store.intakeParserDiagnostics.count
    let orderCount = inboxCreatedOrders.count + partialInboxOrderBlockers.count
    let dispatchCount = reopenedInboxDispatchHandoffCount + inboxDispatchReadinessOrders.count + store.blockedShipmentManifests.count + store.blockedDispatchChecklists.count
    let taskCount = store.reviewTasksNeedingAttention.count + store.handoffNotesNeedingAttention.count + draftFollowUpItems.count
    let auditCount = store.auditEvents.filter { event in
      event.summary.localizedCaseInsensitiveContains("SpaceMail")
        || event.summary.localizedCaseInsensitiveContains("Inbox")
        || event.entityType == .intakeEmail
        || event.entityType == .spaceMailIMAPConnection
    }.count

    return [
      (
        "Incoming records",
        "Use Inbox for imported order mail, blocked imports, and acceptance decisions before treating them as exceptions.",
        inboxCount,
        "Inbox",
        "tray.full.fill",
        inboxCount == 0 ? .green : .teal
      ),
      (
        "Mailbox review",
        "Use Mailbox Monitor for uncertain, filtered, or parser-diagnostic mailbox evidence that should not flood Workbench.",
        mailboxReviewCount,
        "Mailbox Monitor",
        "server.rack",
        mailboxReviewCount == 0 ? .green : .orange
      ),
      (
        "Order handoff",
        "Use Orders when a mailbox-created or Wishlist-linked order needs source trail, customer, destination, tracking, or dispatch setup confirmation.",
        orderCount,
        "Orders",
        "shippingbox.fill",
        orderCount == 0 ? .green : .purple
      ),
      (
        "Dispatch follow-up",
        "Use Dispatch when manifests, readiness, labels, custody, or reopened handoffs block outbound completion.",
        dispatchCount,
        "Dispatch",
        "paperplane.fill",
        dispatchCount == 0 ? .green : .blue
      ),
      (
        "Owned work",
        "Use Tasks when someone needs a due date, acknowledgement, draft, completion, or shift handoff.",
        taskCount,
        "Tasks",
        "checklist",
        taskCount == 0 ? .green : .orange
      ),
      (
        "Traceability",
        "Use Audit when the question is what changed, who acted locally, or why a mailbox/intake decision happened.",
        auditCount,
        "Audit",
        "list.clipboard.fill",
        auditCount == 0 ? .secondary : .teal
      )
    ]
  }

  private var resolutionLadderPanel: some View {
    SettingsPanel(title: "Workbench resolution ladder", symbol: "arrow.triangle.branch") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this to choose the right screen before opening advanced record queues. Workbench should point to the owner of the next local action, not become a dumping ground for every supporting record.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        LazyVGrid(columns: resolutionLadderGridColumns, alignment: .leading, spacing: 10) {
          ForEach(resolutionLadderItems, id: \.title) { item in
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
              Text("Go to \(item.destination)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(item.color)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: resolutionLadderCardHeight, maxHeight: resolutionLadderCardHeight, alignment: .topLeading)
            .background(item.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }

        Text("Local boundary: this panel reads existing local counts only. It does not fetch mail, modify mailbox messages, create records, or call external services.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var resolutionLadderGridColumns: [GridItem] {
    let count = horizontalSizeClass == .compact ? 2 : 3
    return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
  }

  private var resolutionLadderCardHeight: CGFloat {
    horizontalSizeClass == .compact ? 138 : 128
  }

  private var operatorSummary: some View {
    SettingsPanel(title: "Exception queue summary", symbol: "exclamationmark.triangle.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: workbenchNextActionTone == .green ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            .font(.title3)
            .foregroundStyle(workbenchNextActionTone)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text(workbenchNextActionTitle)
              .font(.headline)
            Text(workbenchNextActionDetail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        MetricStrip(items: [
          ("Urgent", "\(urgentWorkbenchCount)", urgentWorkbenchCount == 0 ? .green : .red),
          ("Blocked", "\(defaultQueueItems.filter(\.isBlocked).count)", defaultQueueItems.contains(where: \.isBlocked) ? .orange : .green),
          ("Review", "\(defaultQueueItems.filter { $0.reviewState == .needsReview }.count)", defaultQueueItems.contains { $0.reviewState == .needsReview } ? .purple : .green),
          ("Reopened", "\(reopenedInboxDispatchHandoffCount)", reopenedInboxDispatchHandoffCount == 0 ? .green : .purple),
          ("Verify first", "\(partialInboxOrderBlockers.count)", partialInboxOrderBlockers.isEmpty ? .green : .orange),
          ("Readiness", "\(inboxDispatchReadinessOrders.count)", inboxDispatchReadinessOrders.isEmpty ? .green : .teal),
          ("Inbox orders", "\(inboxCreatedOrders.count)", inboxCreatedOrders.isEmpty ? .green : .teal),
          ("Drafts", "\(draftFollowUpItems.count)", draftFollowUpItems.isEmpty ? .green : .orange),
          ("Setup", "\(setupPlaceholderReviewItems.count)", setupPlaceholderReviewItems.isEmpty ? .green : .teal),
          ("Open", "\(defaultQueueItems.count)", defaultQueueItems.isEmpty ? .green : .blue)
        ])

        CompactActionRow {
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Open Inbox", systemImage: "tray.full.fill")
          }
          NavigationLink {
            DispatchView(store: store)
          } label: {
            Label("Open Dispatch", systemImage: "paperplane.fill")
          }
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Open Audit", systemImage: "list.clipboard.fill")
          }
          NavigationLink {
            SettingsView(store: store)
          } label: {
            Label("Open Settings", systemImage: "gearshape.2.fill")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private var mailboxWorkbenchBoundary: some View {
    SettingsPanel(title: "Mailbox-to-Workbench overview", symbol: "tray.and.arrow.down.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: mailboxFilteredOnlyOutcome ? "checkmark.seal.fill" : "arrow.triangle.branch")
            .foregroundStyle(color(for: mailboxWorkbenchBoundaryTone))
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(mailboxWorkbenchBoundaryTitle)
              .font(.headline)
            Text(mailboxWorkbenchBoundaryDetail)
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
          ("Diagnostics", "\(mailboxWarningCount)", mailboxWarningCount == 0 ? .green : .orange),
          ("Inbox orders", "\(inboxCreatedOrders.count)", inboxCreatedOrders.isEmpty ? .secondary : .purple)
        ])

        if !mailboxProviderWorkbenchBreakdown.isEmpty {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 180 : 230), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(mailboxProviderWorkbenchBreakdown, id: \.provider) { row in
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: mailboxProviderIcon(row.provider))
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

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 190 : 240), spacing: 10)], alignment: .leading, spacing: 10) {
          WorkbenchMailboxRouteCard(
            title: "Imported mail",
            detail: "Review in Inbox and create or link orders before treating anything as an exception.",
            count: mailboxImportedCount,
            symbol: "tray.full.fill",
            color: mailboxImportedCount > 0 ? .green : .secondary
          )
          WorkbenchMailboxRouteCard(
            title: "Uncertain mail",
            detail: "Import or dismiss in Mailbox Monitor. It stays out of Inbox and Workbench until promoted.",
            count: mailboxUncertainCount,
            symbol: "questionmark.folder.fill",
            color: mailboxUncertainCount > 0 ? .orange : .secondary
          )
          WorkbenchMailboxRouteCard(
            title: "Filtered mail",
            detail: "Counted only for diagnostics. It should not create Workbench pressure unless manually imported.",
            count: mailboxFilteredCount,
            symbol: "line.3.horizontal.decrease.circle.fill",
            color: mailboxFilteredCount > 0 ? .teal : .secondary
          )
          WorkbenchMailboxRouteCard(
            title: "Assigned follow-up",
            detail: "Only tasks, handoffs, Inbox-created orders, or dispatch gaps should become Workbench work.",
            count: inboxCreatedOrders.count + mailboxWarningCount,
            symbol: "checklist",
            color: inboxCreatedOrders.isEmpty && mailboxWarningCount == 0 ? .secondary : .purple
          )
        }

        Text("This overview reads local mailbox-provider results only. It does not fetch mail, change classifier rules, create records, or mutate mailbox messages.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(color(for: mailboxWorkbenchBoundaryTone))
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
            OrdersView(store: store)
          } label: {
            Label("Orders", systemImage: "shippingbox.fill")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private func mailboxProviderIcon(_ provider: String) -> String {
    switch provider {
    case "Gmail":
      return "envelope.badge.shield.half.filled"
    case "Microsoft 365":
      return "mail.stack.fill"
    default:
      return "server.rack"
    }
  }

  private var releaseCandidateBlockersPanel: some View {
    SettingsPanel(title: "Release-candidate blocker routing", symbol: "checkmark.seal.text.page.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: releaseBlockerTone == .green ? "checkmark.seal.fill" : "arrow.triangle.branch")
            .font(.title3)
            .foregroundStyle(releaseBlockerTone)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(releaseBlockerTitle)
              .font(.headline)
            Text(releaseBlockerDetail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Badge("\(releaseReadyStepCount)/\(releaseBlockerRows.count) clear", color: releaseBlockerTone)
        }

        MetricStrip(items: [
          ("Providers", "\(releaseProviderReadyCount)", releaseProviderReadyCount > 0 ? .green : .orange),
          ("Refresh", "\(releaseMailboxEvidenceCount)", releaseMailboxEvidenceCount > 0 ? .green : .orange),
          ("Inbox orders", "\(releaseInboxOrderCount)", releaseInboxOrderCount > 0 ? .green : .orange),
          ("Dispatch", "\(releaseDispatchBlockerCount)", releaseDispatchBlockerCount == 0 ? .green : .blue),
          ("Tasks", "\(releaseTaskBlockerCount)", releaseTaskBlockerCount == 0 ? .green : .purple),
          ("Cleanup", "\(releaseCleanupSignalCount)", releaseCleanupSignalCount < 20 ? .teal : .orange)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 190 : 240), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(releaseBlockerRows) { row in
            VStack(alignment: .leading, spacing: 6) {
              HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(row.title, systemImage: row.symbol)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(row.color)
                Spacer()
                Badge("\(row.count)", color: row.color)
              }
              Text(row.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(row.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }

        LocalDataHygieneSummaryCard(
          store: store,
          title: "Workbench cleanup pressure",
          detail: "Use this before release testing to separate current operator blockers from old parser noise, ignored mail, duplicate ingest, and partial Inbox order follow-up.",
          showExamples: false
        )

        CompactActionRow {
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
        .buttonStyle(.bordered)

        Text("Local-only boundary: this panel reads existing local state only. It does not fetch mail, read credentials, create orders, mutate mailbox messages, or call external services.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var developmentStatusWorkbenchPanel: some View {
    SettingsPanel(title: "Development status routing", symbol: "checkmark.seal.text.page.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: developmentStatusFollowUpCount > 0 ? "arrow.triangle.branch" : "doc.badge.plus")
            .font(.title3)
            .foregroundStyle(developmentStatusWorkbenchTone)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(developmentStatusWorkbenchTitle)
              .font(.headline)
            Text(developmentStatusWorkbenchDetail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Badge(developmentStatusFollowUpCount > 0 ? "\(developmentStatusFollowUpCount) active" : "Optional", color: developmentStatusWorkbenchTone)
        }

        MetricStrip(items: [
          ("Task", "\(developmentStatusTasks.count)", developmentStatusTasks.isEmpty ? .secondary : .orange),
          ("Handoff", "\(developmentStatusHandoffs.count)", developmentStatusHandoffs.isEmpty ? .secondary : .teal),
          ("Draft", "\(developmentStatusDrafts.count)", developmentStatusDrafts.isEmpty ? .secondary : .blue),
          ("Workbench", "\(defaultQueueItems.count)", defaultQueueItems.isEmpty ? .green : .orange)
        ])

        if let task = developmentStatusTasks.first {
          CompactRow(
            title: task.title,
            detail: task.summary,
            badge: task.priority.rawValue,
            color: task.priority.color
          )
        } else if let handoff = developmentStatusHandoffs.first {
          CompactRow(
            title: handoff.title,
            detail: handoff.summary,
            badge: handoff.status.rawValue,
            color: handoff.status.color
          )
        } else if let draft = developmentStatusDrafts.first {
          CompactRow(
            title: draft.subject,
            detail: "Local development status packet. Review or copy outside ParcelOps if needed; no outbound email is sent.",
            badge: draft.status.rawValue,
            color: draft.status.color
          )
        }

        CompactActionRow {
          Button(developmentStatusTasks.isEmpty ? "Create status task" : "Refresh status task", systemImage: "checklist") {
            store.createReviewTaskFromDevelopmentStatusCheckpoint()
            developmentStatusFeedbackMessage = "Development status task refreshed from current local state."
          }
          .buttonStyle(.borderedProminent)

          Button(developmentStatusHandoffs.isEmpty ? "Create handoff" : "Refresh handoff", systemImage: "arrow.left.arrow.right.square.fill") {
            store.createHandoffNoteFromDevelopmentStatusCheckpoint()
            developmentStatusFeedbackMessage = "Development status handoff refreshed from current local state."
          }
          .buttonStyle(.bordered)

          Button(developmentStatusDrafts.isEmpty ? "Create status draft" : "Refresh draft", systemImage: "envelope.open.fill") {
            store.createDraftMessageFromDevelopmentStatusCheckpoint()
            developmentStatusFeedbackMessage = "Development status draft refreshed locally. No outbound email was sent."
          }
          .buttonStyle(.bordered)

          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Tasks", systemImage: "checklist")
          }
          .buttonStyle(.bordered)
        }

        Text("Local-only boundary: this panel reads existing app state and creates local follow-up records only. It does not run mailbox refreshes, credentials, network calls, orders, notifications, or outbound email.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        if let developmentStatusFeedbackMessage {
          Label(developmentStatusFeedbackMessage, systemImage: "checkmark.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
        }
      }
    }
  }

  private var spaceMailWorkbenchBoundary: some View {
    SettingsPanel(title: "Mailbox-to-Workbench handoff", symbol: "tray.and.arrow.down.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: spaceMailFilteredOnlyOutcome ? "checkmark.seal.fill" : "arrow.triangle.branch")
            .foregroundStyle(color(for: spaceMailWorkbenchBoundaryTone))
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(spaceMailWorkbenchBoundaryTitle)
              .font(.headline)
            Text(spaceMailWorkbenchBoundaryDetail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        MetricStrip(items: [
          ("Fetched", "\(spaceMailFetchedCount)", spaceMailFetchedCount == 0 ? .secondary : .blue),
          ("Imported", "\(spaceMailImportedCount)", spaceMailImportedCount == 0 ? .secondary : .green),
          ("Uncertain", "\(spaceMailUncertainCount)", spaceMailUncertainCount == 0 ? .secondary : .orange),
          ("Filtered", "\(spaceMailFilteredCount)", spaceMailFilteredCount == 0 ? .secondary : .teal),
          ("Duplicates", "\(spaceMailDuplicateCount)", spaceMailDuplicateCount == 0 ? .secondary : .teal),
          ("Inbox orders", "\(inboxCreatedOrders.count)", inboxCreatedOrders.isEmpty ? .secondary : .purple)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 180 : 230), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(spaceMailPostRefreshPlan.items) { item in
            VStack(alignment: .leading, spacing: 6) {
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: item.symbol)
                  .foregroundStyle(color(for: item.tone))
                  .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                  Text(item.title)
                    .font(.caption.weight(.semibold))
                  Text(item.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Badge("\(item.count)", color: color(for: item.tone))
              }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(color(for: item.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }

        Text("Workbench should start after intake creates a real local follow-up: an imported order email, an uncertain message promoted from Mailbox Monitor, an Inbox-created order, a task, or dispatch setup. Filtered non-order mail stays out of this queue by design.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(color(for: spaceMailWorkbenchBoundaryTone))
          .fixedSize(horizontal: false, vertical: true)

        CompactActionRow {
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Review Inbox intake", systemImage: "tray.full.fill")
          }
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label(pendingFilteredSpaceMailCount > 0 || spaceMailUncertainCount > 0 ? "Review Mailbox examples" : "Open Mailbox Monitor", systemImage: "server.rack")
          }
          NavigationLink {
            OrdersView(store: store)
          } label: {
            Label("Open Orders", systemImage: "shippingbox.fill")
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

  private var spaceMailWorkbenchBoundaryTone: String {
    if spaceMailImportedCount > 0 || spaceMailUncertainCount > 0 || !inboxCreatedOrders.isEmpty { return "attention" }
    if spaceMailFilteredOnlyOutcome { return "success" }
    if spaceMailFetchedCount > 0 { return "neutral" }
    return spaceMailPostRefreshPlan.tone
  }

  private var spaceMailWorkbenchBoundaryTitle: String {
    if spaceMailImportedCount > 0 {
      return "SpaceMail created Inbox work"
    }
    if spaceMailUncertainCount > 0 {
      return "SpaceMail needs Mailbox Monitor review"
    }
    if !inboxCreatedOrders.isEmpty {
      return "Inbox-created orders need follow-up"
    }
    if spaceMailFilteredOnlyOutcome {
      return "Mixed mailbox filtering did its job"
    }
    if spaceMailFetchedCount > 0 {
      return "Latest refresh created no Workbench work"
    }
    return spaceMailPostRefreshPlan.title
  }

  private var spaceMailWorkbenchBoundaryDetail: String {
    if spaceMailImportedCount > 0 {
      return "\(spaceMailImportedCount) likely order message reached Inbox. Review or create/link the order there before expecting Workbench exceptions."
    }
    if spaceMailUncertainCount > 0 {
      return "\(spaceMailUncertainCount) ambiguous SpaceMail preview is waiting outside Inbox. Import genuine order mail from Mailbox Monitor or dismiss it locally."
    }
    if !inboxCreatedOrders.isEmpty {
      return "\(inboxCreatedOrders.count) Mailbox-created order is already in the handoff path. Confirm the order detail, source trail, and dispatch setup below."
    }
    if spaceMailFilteredOnlyOutcome {
      return "\(spaceMailFilteredCount) mixed-mailbox message was filtered out of Inbox. There is no Workbench exception until an order email is imported, promoted, or created."
    }
    if spaceMailFetchedCount > 0 {
      return "The latest refresh fetched mail but did not produce imported or uncertain order work. Use Mailbox Monitor only if an expected order is missing."
    }
    return spaceMailPostRefreshPlan.detail
  }

  private var gmailWorkbenchBoundary: some View {
    SettingsPanel(title: "Gmail-to-Workbench handoff", symbol: "envelope.badge.shield.half.filled") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: gmailWorkbenchTone == .green ? "checkmark.seal.fill" : "arrow.triangle.branch")
            .foregroundStyle(gmailWorkbenchTone)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(gmailWorkbenchTitle)
              .font(.headline)
            Text(gmailWorkbenchDetail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        MetricStrip(items: [
          ("Fetched", "\(gmailFetchedCount)", gmailFetchedCount == 0 ? .secondary : .blue),
          ("Imported", "\(gmailImportedCount)", gmailImportedCount == 0 ? .secondary : .green),
          ("Uncertain", "\(gmailUncertainCount)", gmailUncertainCount == 0 ? .secondary : .orange),
          ("Filtered", "\(gmailFilteredCount)", gmailFilteredCount == 0 ? .secondary : .teal),
          ("Warnings", "\(gmailWarningCount)", gmailWarningCount == 0 ? .green : .orange),
          ("Tuning", "\(gmailClassifierTuningCount)", gmailClassifierTuningCount == 0 ? .green : .orange),
          ("Refresh tasks", "\(activeGmailRefreshTasks.count)", activeGmailRefreshTasks.isEmpty ? .green : .purple),
          ("Release blockers", "\(gmailReleaseBlockingCount)", gmailReleaseBlockingCount == 0 ? .green : .red),
          ("Release attention", "\(gmailReleaseAttentionCount)", gmailReleaseAttentionCount == 0 ? .green : .orange),
          ("Host checks", "\(gmailProviderFitAttentionCount)", gmailProviderFitAttentionCount == 0 ? .green : .teal)
        ])

        if let blocker = store.gmailReleaseBlockerSummary.blockers.first(where: { $0.tone == "warning" || $0.tone == "attention" }) {
          MailboxTopReleaseBlockerCallout(blocker: blocker)
        }

        if !activeGmailRefreshTasks.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Label("Active Gmail refresh follow-up", systemImage: "checklist")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.purple)
            Text("These tasks were created from the latest Gmail refresh result. Work them in Tasks; use Mailbox Monitor only to refresh the source evidence.")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 180 : 240), spacing: 8)], alignment: .leading, spacing: 8) {
              ForEach(activeGmailRefreshTasks.prefix(3)) { task in
                VStack(alignment: .leading, spacing: 6) {
                  Text(task.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                  Text("Owner: \(task.assignee) • Due: \(task.dueDate)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                  CompactMetadataGrid(minimumWidth: 105) {
                    Badge(task.status.rawValue, color: gmailRefreshTaskWorkbenchColor(task))
                    Badge(task.priority.rawValue, color: gmailRefreshTaskWorkbenchColor(task))
                    Badge(task.reviewState.rawValue, color: task.reviewState == .accepted ? .green : .orange)
                  }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(gmailRefreshTaskWorkbenchColor(task).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
              }
            }
          }
          .padding(10)
          .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        VStack(alignment: .leading, spacing: 6) {
          Label("Gmail label handoff", systemImage: gmailLabelWorkbenchStatus == "Label issue" ? "tag.slash.fill" : "tag.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(gmailLabelWorkbenchColor)
          CompactMetadataGrid(minimumWidth: 145) {
            Badge("Label: \(gmailWorkbenchPrimaryLabel)", color: gmailLabelWorkbenchColor)
            Badge(gmailLabelWorkbenchStatus, color: gmailLabelWorkbenchColor)
            Badge(gmailWorkbenchMailboxModeLabel, color: .teal)
            Badge(gmailWorkbenchRefreshLabel, color: gmailWorkbenchTone)
          }
          Text(gmailLabelWorkbenchDetail)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(gmailLabelWorkbenchColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 6) {
          Label(gmailWorkbenchCompileTitle, systemImage: gmailWorkbenchReadiness?.isReady == true ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(gmailWorkbenchCompileColor)
          Text(gmailWorkbenchCompileDetail)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          if let readiness = gmailWorkbenchReadiness {
            CompactMetadataGrid(minimumWidth: 165) {
              Badge(readiness.compiledClientIDStatus, color: readiness.compiledClientIDStatus.localizedCaseInsensitiveContains("matches") || readiness.compiledClientIDStatus.localizedCaseInsensitiveContains("present") ? .green : .orange)
              Badge(readiness.compiledCallbackSchemeStatus, color: readiness.compiledCallbackSchemeStatus.localizedCaseInsensitiveContains("includes") || readiness.compiledCallbackSchemeStatus.localizedCaseInsensitiveContains("present") ? .green : .orange)
              Badge(readiness.expectedCallbackScheme, color: .secondary)
            }
          }
        }
        .padding(10)
        .background(gmailWorkbenchCompileColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        if gmailClassifierTuningCount > 0 || gmailClassifierHintCount > 0 {
          VStack(alignment: .leading, spacing: 6) {
            Label(gmailClassifierWorkbenchTitle, systemImage: "slider.horizontal.3")
              .font(.caption.weight(.semibold))
              .foregroundStyle(gmailClassifierTuningCount > 0 ? .orange : .teal)
            Text(gmailClassifierWorkbenchDetail)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            MetricStrip(items: [
              ("Hints", "\(gmailClassifierHintCount)", gmailClassifierHintCount > 0 ? .teal : .secondary),
              ("Test issues", "\(gmailClassifierTestIssueCount)", gmailClassifierTestIssueCount > 0 ? .orange : .green),
              ("Uncertain", "\(gmailUncertainCount)", gmailUncertainCount > 0 ? .orange : .secondary),
              ("Filtered review", "\(pendingGmailFilteredReviewCount)", pendingGmailFilteredReviewCount > 0 ? .teal : .secondary)
            ])
          }
          .padding(10)
          .background((gmailClassifierTuningCount > 0 ? Color.orange : Color.teal).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        if !gmailHealthSummaries.isEmpty {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 180 : 230), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(gmailHealthSummaries.prefix(3)) { summary in
              VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                  Text(summary.displayName)
                    .font(.caption.weight(.semibold))
                  Spacer()
                  Badge(summary.verdict, color: gmailToneColor(summary.tone))
                }
                Text(summary.nextAction)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
              .padding(10)
              .frame(maxWidth: .infinity, alignment: .topLeading)
              .background(gmailToneColor(summary.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }

        gmailWorkbenchReadinessPanel

        Text(pendingGmailFilteredReviewCount > 0
          ? "Filtered Gmail examples are waiting for optional review, but they stay out of Workbench until an operator imports one into Inbox or creates follow-up."
          : "Gmail becomes Workbench work only after it creates actionable local state: imported Inbox intake, uncertain previews needing review, setup failures, or assigned follow-up. Filtered non-order Gmail stays out of the operator exception queue.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(gmailWorkbenchTone)
          .fixedSize(horizontal: false, vertical: true)

        CompactActionRow {
          Button {
            store.recordGmailReleaseReadinessSnapshot()
          } label: {
            Label("Record Gmail snapshot", systemImage: "camera.metering.center.weighted")
          }
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Open Gmail setup", systemImage: "server.rack")
          }
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Review Inbox intake", systemImage: "tray.full.fill")
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

  private var gmailWorkbenchReadinessPanel: some View {
    GmailReleaseBoundaryPanel(
      store: store,
      title: "Gmail Workbench readiness",
      lead: "Release self-check failures are setup and readiness work first. Turn them into Workbench exceptions only when a named owner, blocker, or handoff is needed.",
      sourceMetricTitle: "Gmail issues",
      sourceCount: gmailWarningCount + gmailUncertainCount + gmailClassifierTuningCount,
      boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store token values, create Workbench exceptions automatically, or mutate mailbox messages."
    )
  }

  private var microsoft365WorkbenchBoundary: some View {
    SettingsPanel(title: "Outlook-to-Workbench handoff", symbol: "mail.stack.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: microsoft365WorkbenchTone == .green ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
            .foregroundStyle(microsoft365WorkbenchTone)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(microsoft365WorkbenchTitle)
              .font(.headline)
            Text(microsoft365WorkbenchDetail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        MetricStrip(items: [
          ("Setups", "\(store.microsoft365MailboxConnections.count)", store.microsoft365MailboxConnections.isEmpty ? .secondary : .purple),
          ("Release blockers", "\(microsoft365ReleaseBlockingCount)", microsoft365ReleaseBlockingCount == 0 ? .green : .red),
          ("Needs action", "\(microsoft365ReleaseAttentionCount)", microsoft365ReleaseAttentionCount == 0 ? .green : .orange),
          ("Graph blockers", "\(microsoft365GraphBlockerCount)", microsoft365GraphBlockerCount == 0 ? .green : .orange),
          ("Imported", "\(microsoft365ImportedCount)", microsoft365ImportedCount == 0 ? .secondary : .green),
          ("Uncertain", "\(microsoft365UncertainCount)", microsoft365UncertainCount == 0 ? .green : .orange),
          ("Filtered", "\(microsoft365FilteredReviewCount)", microsoft365FilteredReviewCount == 0 ? .secondary : .teal),
          ("Open tasks", "\(activeMicrosoft365ReleaseTasks.count)", activeMicrosoft365ReleaseTasks.isEmpty ? .green : .purple)
        ])

        if let summary = microsoft365ReleaseSelfChecks.first {
          Microsoft365ReleaseSelfCheckCard(summary: summary)
        } else {
          MVPEmptyState(
            title: "No Outlook mailbox setup",
            detail: "Use Outlook / Microsoft 365 only when the active mailbox is Microsoft-hosted. Use SpaceMail or Gmail only when they host the active mailbox.",
            symbol: "mail.stack"
          )
        }

        if !activeMicrosoft365ReleaseTasks.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Label("Open Outlook release follow-up", systemImage: "checklist")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.purple)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 180 : 240), spacing: 8)], alignment: .leading, spacing: 8) {
              ForEach(activeMicrosoft365ReleaseTasks.prefix(3)) { task in
                VStack(alignment: .leading, spacing: 6) {
                  Text(task.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                  Text("Owner: \(task.assignee) • Due: \(task.dueDate)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                  CompactMetadataGrid(minimumWidth: 105) {
                    Badge(task.status.rawValue, color: .purple)
                    Badge(task.priority.rawValue, color: microsoft365ReleaseTaskPriorityColor(task))
                    Badge(task.reviewState.rawValue, color: task.reviewState == .accepted ? .green : .orange)
                  }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
              }
            }
          }
          .padding(10)
          .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        Text("Outlook becomes Workbench work only when release checks, Graph diagnostics, imported Inbox rows, or assigned follow-up need operator attention. This panel does not start Microsoft sign-in, request tokens, fetch messages, mutate mailboxes, or store secrets.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(microsoft365WorkbenchTone)
          .fixedSize(horizontal: false, vertical: true)

        CompactActionRow {
          if let connection = store.microsoft365MailboxConnections.first {
            Button {
              store.createReviewTaskFromMicrosoft365ReleaseSelfCheck(connection)
            } label: {
              Label("Create Outlook release task", systemImage: "checklist")
            }
          }
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Open Outlook setup", systemImage: "mail.stack.fill")
          }
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Review Inbox intake", systemImage: "tray.full.fill")
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

  private var microsoft365WorkbenchTone: Color {
    if microsoft365ReleaseBlockingCount > 0 { return .red }
    if microsoft365ReleaseAttentionCount > 0 || microsoft365GraphBlockerCount > 0 || microsoft365BlockedCount > 0 { return .orange }
    if microsoft365UncertainCount > 0 { return .orange }
    if microsoft365ImportedCount > 0 { return .teal }
    if microsoft365FilteredReviewCount > 0 { return .teal }
    if !store.microsoft365MailboxConnections.isEmpty { return .purple }
    return .secondary
  }

  private var microsoft365WorkbenchTitle: String {
    if store.microsoft365MailboxConnections.isEmpty { return "Outlook setup is optional" }
    if microsoft365ReleaseBlockingCount > 0 { return "Outlook release checks have blockers" }
    if microsoft365GraphBlockerCount > 0 || microsoft365BlockedCount > 0 { return "Outlook Graph diagnostics need review" }
    if microsoft365ReleaseAttentionCount > 0 { return "Outlook release checks need action" }
    if microsoft365UncertainCount > 0 { return "Outlook uncertain review is waiting" }
    if microsoft365ImportedCount > 0 { return "Outlook created Inbox work" }
    if microsoft365FilteredReviewCount > 0 { return "Outlook filtered examples are available" }
    return "Outlook release path has no Workbench exception"
  }

  private var microsoft365WorkbenchDetail: String {
    if store.microsoft365MailboxConnections.isEmpty {
      return "Add Outlook / Microsoft 365 setup only when the mailbox is Microsoft-hosted. Use SpaceMail or Gmail for their own mailbox hosts."
    }
    if microsoft365ReleaseBlockingCount > 0 {
      return "\(microsoft365ReleaseBlockingCount) Outlook release check\(microsoft365ReleaseBlockingCount == 1 ? "" : "s") still block daily use. Finish OAuth readiness, Mail.Read consent, sign-in, or refresh diagnostics before relying on this provider."
    }
    if microsoft365GraphBlockerCount > 0 || microsoft365BlockedCount > 0 {
      return "Microsoft Graph has safe diagnostic evidence that needs review in Mailbox Monitor or Audit before this provider is trusted for daily intake."
    }
    if microsoft365ReleaseAttentionCount > 0 {
      return "\(microsoft365ReleaseAttentionCount) Outlook release check\(microsoft365ReleaseAttentionCount == 1 ? "" : "s") need operator action, usually sign-in, implementation plan review, release task ownership, or Audit evidence."
    }
    if microsoft365UncertainCount > 0 {
      return "\(microsoft365UncertainCount) ambiguous Outlook preview\(microsoft365UncertainCount == 1 ? "" : "s") are waiting outside Inbox. Import genuine order mail or dismiss non-order mail in Mailbox Monitor."
    }
    if microsoft365ImportedCount > 0 {
      return "\(microsoft365ImportedCount) Outlook message\(microsoft365ImportedCount == 1 ? "" : "s") reached Inbox. Review or create/link the order there before expecting Workbench exceptions."
    }
    if microsoft365FilteredReviewCount > 0 {
      return "\(microsoft365FilteredReviewCount) filtered Outlook preview\(microsoft365FilteredReviewCount == 1 ? "" : "s") can be inspected when an expected order email is missing. This is classifier review, not an operational exception."
    }
    return "Outlook setup exists, but current local evidence did not create imported or blocked order work."
  }

  private func microsoft365ReleaseTaskPriorityColor(_ task: ReviewTask) -> Color {
    switch task.priority {
    case .urgent, .high:
      return .orange
    case .normal:
      return .teal
    case .low:
      return .secondary
    }
  }

  private var gmailWorkbenchTone: Color {
    if gmailWarningCount > 0 || gmailUncertainCount > 0 { return .orange }
    if gmailReleaseBlockingCount > 0 { return .red }
    if gmailReleaseAttentionCount > 0 { return .orange }
    if gmailImportedCount > 0 { return .teal }
    if gmailFilteredCount > 0 { return .green }
    return .secondary
  }

  private var gmailWorkbenchTitle: String {
    if gmailWarningCount > 0 { return "Gmail setup or refresh needs review" }
    if gmailUncertainCount > 0 { return "Gmail needs Mailbox Monitor review" }
    if gmailReleaseBlockingCount > 0 { return "Gmail release checks have blockers" }
    if gmailReleaseAttentionCount > 0 { return "Gmail release checks need attention" }
    if gmailImportedCount > 0 { return "Gmail created Inbox work" }
    if gmailFilteredCount > 0 { return "Gmail mixed-mailbox filter is working" }
    if gmailHealthSummaries.isEmpty { return "Gmail setup is optional" }
    return "Latest Gmail state created no Workbench work"
  }

  private var gmailWorkbenchDetail: String {
    if gmailWarningCount > 0 {
      return "\(gmailWarningCount) Gmail connection or refresh result needs setup review before it should become order work."
    }
    if gmailUncertainCount > 0 {
      return "\(gmailUncertainCount) ambiguous Gmail preview is waiting outside Inbox. Import genuine order mail from Mailbox Monitor or dismiss it locally."
    }
    if gmailReleaseBlockingCount > 0 || gmailReleaseAttentionCount > 0 {
      let count = gmailReleaseBlockingCount + gmailReleaseAttentionCount
      return "\(count) Gmail release self-check item\(count == 1 ? "" : "s") still need setup, sign-in, labels, classifier review, Inbox handoff, or audit evidence before Gmail should be treated as a daily intake path."
    }
    if gmailImportedCount > 0 {
      return "\(gmailImportedCount) likely Gmail order message reached Inbox. Review or create/link the order there before expecting Workbench exceptions."
    }
    if gmailFilteredCount > 0 {
      if pendingGmailFilteredReviewCount > 0 {
        return "\(pendingGmailFilteredReviewCount) filtered Gmail preview is available for optional review. It is not Workbench work unless imported into Inbox."
      }
      return "\(gmailFilteredCount) mixed-mailbox Gmail message was filtered out of Inbox. There is no Workbench exception until an order email is imported, promoted, or created."
    }
    let refreshedDuplicateCount = store.totalGmailDuplicateRefreshedCount
    if refreshedDuplicateCount > 0 {
      return "\(refreshedDuplicateCount) duplicate Gmail message\(refreshedDuplicateCount == 1 ? "" : "s") refreshed existing Inbox rows. Review the linked Inbox or order context before creating Workbench exceptions."
    }
    if gmailHealthSummaries.isEmpty {
      return "Add Gmail setup only for mailboxes hosted by Gmail or Google Workspace. Use whichever provider hosts the active mailbox."
    }
    return "Gmail setup exists, but the latest state did not produce imported or uncertain order work."
  }

  private var gmailWorkbenchConnection: GmailMailboxConnection? {
    guard let firstSummary = gmailHealthSummaries.first else {
      return store.gmailMailboxConnections.first
    }
    return store.gmailMailboxConnections.first { $0.id == firstSummary.connectionID }
  }

  private var gmailWorkbenchReadiness: GmailOAuthReadinessSummary? {
    gmailWorkbenchConnection.map { store.gmailOAuthReadinessSummary(for: $0) }
  }

  private var gmailWorkbenchCompileBlockers: [String] {
    guard let readiness = gmailWorkbenchReadiness else { return [] }
    return readiness.missingFields.filter { field in
      field.localizedCaseInsensitiveContains("compiled App Info.plist")
        || field.localizedCaseInsensitiveContains("callback URL scheme matching")
        || field.localizedCaseInsensitiveContains("OAuth iOS client ID ending")
    }
  }

  private var gmailWorkbenchCompileColor: Color {
    guard let readiness = gmailWorkbenchReadiness else { return .secondary }
    return readiness.isReady ? .green : .orange
  }

  private var gmailWorkbenchCompileTitle: String {
    guard let readiness = gmailWorkbenchReadiness else { return "Gmail compiled setup not started" }
    if readiness.isReady { return "Gmail compiled setup is ready" }
    if !gmailWorkbenchCompileBlockers.isEmpty { return "Gmail compiled setup blocks real sign-in" }
    return "Gmail setup values need review"
  }

  private var gmailWorkbenchCompileDetail: String {
    guard let readiness = gmailWorkbenchReadiness else {
      return "Gmail setup is only needed for Gmail or Google Workspace mailboxes."
    }
    if readiness.isReady {
      return "Saved Gmail setup matches the compiled client ID and callback scheme. Workbench can focus on refresh, classifier, and Inbox handoff evidence."
    }
    if !gmailWorkbenchCompileBlockers.isEmpty {
      return "Fix before creating operational follow-up: \(gmailWorkbenchCompileBlockers.joined(separator: "; ")). Update App/Info.plist and Project.json with the Google iOS client ID and reversed client ID scheme, then rebuild."
    }
    return readiness.detailText
  }

  private var gmailWorkbenchPrimaryLabel: String {
    guard let connection = gmailWorkbenchConnection else { return "None" }
    return connection.monitoredLabelNames
      .split(separator: ",")
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
      .first { !$0.isEmpty } ?? "INBOX"
  }

  private var gmailWorkbenchMailboxModeLabel: String {
    gmailWorkbenchConnection?.mailboxMode.rawValue ?? "No Gmail setup"
  }

  private var gmailWorkbenchRefreshLabel: String {
    guard let connection = gmailWorkbenchConnection else { return "No refresh" }
    return connection.lastManualRefreshDate == "Never" ? "No refresh" : connection.lastManualRefreshDate
  }

  private var gmailLabelWorkbenchStatus: String {
    guard let connection = gmailWorkbenchConnection else { return "No Gmail setup" }
    let summary = connection.lastRefreshSummary
    let status = connection.connectionStatus
    if status.localizedCaseInsensitiveContains("Label not found") ||
        summary.localizedCaseInsensitiveContains("was not found in safe label metadata") {
      return "Label issue"
    }
    if summary.localizedCaseInsensitiveContains("matched configured label") {
      return "Custom label resolved"
    }
    if summary.localizedCaseInsensitiveContains("used configured label ID directly") {
      return "Label ID used"
    }
    if summary.localizedCaseInsensitiveContains("used system label") || gmailWorkbenchPrimaryLabel.uppercased() == "INBOX" {
      return "System label direct"
    }
    if connection.lastManualRefreshDate == "Never" {
      return "Label not checked"
    }
    return "Audit has label detail"
  }

  private var gmailLabelWorkbenchDetail: String {
    switch gmailLabelWorkbenchStatus {
    case "No Gmail setup":
      return "Gmail setup is only needed for Gmail or Google Workspace mailboxes."
    case "Label issue":
      return "Fix the Gmail label in Mailbox Monitor before turning Gmail refreshes into operational exceptions. Use INBOX or an exact existing Gmail label."
    case "Custom label resolved":
      return "The custom Gmail label resolved before message listing. Workbench should only act after Inbox intake, uncertain review, or setup failures create local work."
    case "Label ID used":
      return "The configured Gmail label ID was used directly. Refresh remains read-only and manual."
    case "System label direct":
      return "System labels such as INBOX are used directly, so label setup is not the current Workbench blocker."
    case "Label not checked":
      return "Run Gmail readiness or manual refresh from Mailbox Monitor after sign-in to confirm the label before relying on refresh results."
    default:
      return "Open Mailbox Monitor or Audit for safe label-resolution detail. Do not create Workbench work from filtered Gmail alone."
    }
  }

  private var gmailLabelWorkbenchColor: Color {
    switch gmailLabelWorkbenchStatus {
    case "Label issue":
      return .orange
    case "Custom label resolved", "Label ID used", "System label direct":
      return .green
    case "Audit has label detail":
      return .teal
    default:
      return .secondary
    }
  }

  private var gmailClassifierWorkbenchTitle: String {
    if gmailClassifierTestIssueCount > 0 { return "Gmail classifier tests need tuning" }
    if gmailUncertainCount > 0 { return "Gmail uncertain review is waiting" }
    if pendingGmailFilteredReviewCount > 0 { return "Gmail filtered examples are available" }
    if gmailClassifierHintCount > 0 { return "Gmail classifier hints are saved" }
    return "Gmail classifier is quiet"
  }

  private var gmailClassifierWorkbenchDetail: String {
    if gmailClassifierTestIssueCount > 0 {
      return "\(gmailClassifierTestIssueCount) Gmail classifier test\(gmailClassifierTestIssueCount == 1 ? "" : "s") need review. Tune hints in Mailbox Monitor before treating mixed Gmail refreshes as reliable."
    }
    if gmailUncertainCount > 0 {
      return "\(gmailUncertainCount) ambiguous Gmail preview\(gmailUncertainCount == 1 ? "" : "s") are waiting outside Inbox. Import genuine order mail or dismiss non-order mail before creating Workbench exceptions."
    }
    if pendingGmailFilteredReviewCount > 0 {
      return "\(pendingGmailFilteredReviewCount) filtered Gmail preview\(pendingGmailFilteredReviewCount == 1 ? "" : "s") can be inspected when an expected order email is missing. This is classifier tuning work, not an operational exception."
    }
    if gmailClassifierHintCount > 0 {
      return "\(gmailClassifierHintCount) local Gmail hint\(gmailClassifierHintCount == 1 ? "" : "s") are saved. Run the local Gmail classifier suite after hint changes to verify the decision path."
    }
    return "No Gmail uncertain, filtered-review, or failing classifier-test work is currently open."
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

  private func gmailRefreshTaskWorkbenchColor(_ task: ReviewTask) -> Color {
    if task.status == .blocked { return .red }
    if task.priority == .urgent || task.priority == .high { return .orange }
    if task.status == .inProgress { return .blue }
    if task.reviewState != .accepted { return .orange }
    return .purple
  }

  private var inboxParserQualityHandoff: some View {
    SettingsPanel(title: "Inbox parser quality handoff", symbol: "text.magnifyingglass") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: intakeParserQualityTone == .green ? "checkmark.circle.fill" : "arrow.triangle.branch")
            .font(.title3)
            .foregroundStyle(intakeParserQualityTone)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(intakeParserQualityTitle)
              .font(.headline)
            Text(intakeParserQualityDetail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        MetricStrip(items: [
          ("Weak parse", "\(weakInboxParseCount)", weakInboxParseCount == 0 ? .green : .orange),
          ("Partial", "\(partialInboxParseCount)", partialInboxParseCount == 0 ? .green : .orange),
          ("Ready link", "\(readyInboxLinkCount)", readyInboxLinkCount == 0 ? .secondary : .teal),
          ("Linked", "\(linkedInboxIntakeCount)", linkedInboxIntakeCount == 0 ? .secondary : .green),
          ("Parser checks", "\(store.intakeParserDiagnostics.count)", store.intakeParserDiagnostics.isEmpty ? .green : .purple)
        ])

        Text("Workbench does not duplicate the Inbox triage queue. Use this handoff to decide whether to fix parsing in Inbox, create/link an order, or keep Workbench focused on exceptions after the order exists.")
          .font(.caption)
          .foregroundStyle(.secondary)
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
            Label("Open Mailbox diagnostics", systemImage: "server.rack")
          }
          NavigationLink {
            OrdersView(store: store)
          } label: {
            Label("Open Orders", systemImage: "shippingbox.fill")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private var mailboxAssignedWorkbenchItems: [WorkbenchItem] {
    store.openWorkbenchItems.filter { item in
      (item.source == .reviewTask || item.source == .handoffNote)
        && (item.title.localizedCaseInsensitiveContains("spacemail")
          || item.title.localizedCaseInsensitiveContains("gmail")
          || item.summary.localizedCaseInsensitiveContains("spacemail")
          || item.summary.localizedCaseInsensitiveContains("gmail")
          || item.suggestedNextAction.localizedCaseInsensitiveContains("spacemail")
          || item.suggestedNextAction.localizedCaseInsensitiveContains("gmail")
          || item.suggestedNextAction.localizedCaseInsensitiveContains("mailbox monitor"))
    }
  }

  @ViewBuilder
  private var mailboxAssignedFollowUpPanel: some View {
    if !mailboxAssignedWorkbenchItems.isEmpty {
      SettingsPanel(title: "Mailbox assigned follow-up", symbol: "person.2.wave.2.fill") {
        VStack(alignment: .leading, spacing: 12) {
          Text("Mailbox shift handoffs and review tasks are assigned work once an active mailbox provider needs operator follow-up. Use this panel to see them in Workbench, then open Tasks to complete, acknowledge, draft, or review them.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          MetricStrip(items: [
            ("Assigned", "\(mailboxAssignedWorkbenchItems.count)", .purple),
            ("Needs review", "\(mailboxAssignedWorkbenchItems.filter { $0.reviewState == .needsReview }.count)", mailboxAssignedWorkbenchItems.contains { $0.reviewState == .needsReview } ? .orange : .green),
            ("High priority", "\(mailboxAssignedWorkbenchItems.filter { $0.rank >= 3 }.count)", mailboxAssignedWorkbenchItems.contains { $0.rank >= 3 } ? .orange : .green),
            ("Blocked", "\(mailboxAssignedWorkbenchItems.filter(\.isBlocked).count)", mailboxAssignedWorkbenchItems.contains(where: \.isBlocked) ? .red : .green)
          ])

          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 190 : 250), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(mailboxAssignedWorkbenchItems.prefix(4)) { item in
              VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                  Label(item.source.rawValue, systemImage: item.source.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color(for: "attention"))
                  Spacer()
                  Badge(item.prioritySeverity, color: item.rank >= 3 ? .orange : .purple)
                }
                Text(item.title)
                  .font(.caption.weight(.semibold))
                  .lineLimit(2)
                Text(item.suggestedNextAction)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
              .padding(10)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }

          CompactActionRow {
            NavigationLink {
              TasksView(store: store)
            } label: {
              Label("Open Tasks", systemImage: "checklist")
            }
            NavigationLink {
              MailboxView(store: store)
            } label: {
              Label("Open Mailbox Monitor", systemImage: "server.rack")
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
  }

  private func color(for tone: String) -> Color {
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

  private var workbenchDiagnosticsBoundary: some View {
    SettingsPanel(title: "Diagnostics boundary", symbol: "text.magnifyingglass") {
      VStack(alignment: .leading, spacing: 10) {
        Text("Parser diagnostics and mixed-mailbox classifier checks are supporting evidence. Keep the Workbench focused on urgent, blocked, exception, review, and dispatch work; open Inbox or Mailbox Monitor when you need to tune intake parsing.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        let hasParserOrUncertainDiagnostics = !store.intakeParserDiagnostics.isEmpty || store.pendingMailboxUncertainReviewCount > 0
        MetricStrip(items: [
          ("Parser checks", "\(store.intakeParserDiagnostics.count)", store.intakeParserDiagnostics.isEmpty ? .green : .orange),
          ("Uncertain mail", "\(store.pendingMailboxUncertainReviewCount)", store.pendingMailboxUncertainReviewCount > 0 ? .orange : .green),
          ("Filtered mail", "\(store.pendingMailboxFilteredReviewCount)", .teal),
          ("Inbox review", "\(store.reviewIntakeEmails.count)", store.reviewIntakeEmails.isEmpty ? .green : .teal),
          ("Primary work", "\(store.openWorkbenchItems.count)", store.openWorkbenchItems.isEmpty ? .green : .blue)
        ])

        Text(!hasParserOrUncertainDiagnostics
          ? "No parser or uncertain-message diagnostics are currently pulling attention away from the operator queue."
          : "Use Inbox for optional parser diagnostics and Mailbox Monitor for uncertain/filtered mailbox review. Do not treat filtered non-order mail as Workbench work.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(!hasParserOrUncertainDiagnostics ? .green : .orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  @ViewBuilder
  private var inboxCreatedOrderFollowUp: some View {
    if !inboxCreatedOrders.isEmpty {
      SettingsPanel(title: partialInboxOrderBlockers.isEmpty ? "Source order follow-up" : "Source order verification", symbol: partialInboxOrderBlockers.isEmpty ? "tray.and.arrow.down.fill" : "exclamationmark.triangle.fill") {
        Text(partialInboxOrderBlockers.isEmpty
          ? "Orders created from Inbox, Import Queue, Acceptance Review, or Wishlist source context stay here until someone confirms the operational details and dispatch setup."
          : "Partial Inbox-created or Wishlist-linked orders stay here until missing order, tracking, or destination details are confirmed. Do this before dispatch setup.")
          .font(.callout)
          .foregroundStyle(.secondary)
        ForEach(inboxCreatedOrders) { order in
          WorkbenchInboxOrderRow(
            order: order,
            needsDispatchSetup: needsDispatchSetup(order),
            needsInboxDispatchReadiness: needsInboxDispatchReadiness(order),
            hasReopenedInboxDispatchHandoff: hasReopenedInboxDispatchHandoff(order),
            needsPreDispatchVerification: needsPreDispatchVerification(order),
            partialTaskCount: partialInboxTaskCount(for: order),
            sourceTrailCount: store.sourceTrailCount(for: order, includeWishlist: true),
            mailboxSourceSummaries: store.mailboxSourceSummaries(for: order),
            store: store
          )
        }
      }
    }
  }

  @ViewBuilder
  private var draftFollowUpPanel: some View {
    if !draftFollowUpItems.isEmpty {
      SettingsPanel(title: "Draft follow-up", symbol: "envelope.open.fill") {
        Text("Drafts created from local work stay visible here until they are marked ready, sent locally, or reopened for another pass.")
          .font(.callout)
          .foregroundStyle(.secondary)
        ForEach(draftFollowUpItems) { draft in
          WorkbenchDraftFollowUpRow(draft: draft, store: store)
        }
        NavigationLink {
          CommunicationView(store: store)
        } label: {
          Label("Open Drafts & Templates", systemImage: "bubble.left.and.bubble.right.fill")
        }
        .buttonStyle(.bordered)
      }
    }
  }

  @ViewBuilder
  private var wishlistPurchaseFollowUpPanel: some View {
    if wishlistWorkbenchPurchaseFollowUpVisible {
      SettingsPanel(title: "Wishlist purchase follow-up", symbol: "star.square.fill") {
        Text("Wishlist items and comparison briefs become Workbench-visible when they are blocked before purchase, missing agent research scope, ready for a packet, prepared for manual handoff, purchased externally, or waiting for order confirmation. This is local planning only; no checkout, account login, browser automation, external agent, or mailbox monitoring runs here.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: wishlistWorkbenchMetrics)

        HStack(alignment: .top, spacing: 10) {
          Image(systemName: wishlistAgentReadiness.tone == "success" ? "checkmark.seal.fill" : "sparkles.rectangle.stack.fill")
            .foregroundStyle(wishlistAgentReadinessTint)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(wishlistAgentReadiness.title)
              .font(.subheadline.weight(.semibold))
            Text(wishlistAgentReadiness.verdict)
              .font(.caption.weight(.semibold))
              .foregroundStyle(wishlistAgentReadinessTint)
            Text(wishlistAgentReadiness.detail)
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 8)
          Badge(wishlistAgentReadiness.tone.capitalized, color: wishlistAgentReadinessTint)
        }
        .padding(10)
        .background(wishlistAgentReadinessTint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        if let blocker = wishlistTopReadinessBlocker {
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: blocker.tone == "warning" ? "exclamationmark.triangle.fill" : "arrow.forward.circle.fill")
              .foregroundStyle(wishlistTopReadinessBlockerTint)
              .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
              Text("Top Wishlist blocker")
                .font(.subheadline.weight(.semibold))
              Text("\(blocker.title) - \(blocker.status)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(wishlistTopReadinessBlockerTint)
              Text("Next: \(blocker.nextAction)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Badge(blocker.tone.capitalized, color: wishlistTopReadinessBlockerTint)
          }
          .padding(10)
          .background(wishlistTopReadinessBlockerTint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        if wishlistBatchBriefNeeded || !wishlistBatchResearchDrafts.isEmpty {
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: wishlistBatchBriefNeeded ? "doc.badge.plus" : "doc.text.fill")
              .foregroundStyle(wishlistBatchBriefWorkbenchColor)
              .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
              Text(store.wishlistBatchBriefWorkbenchTitle)
                .font(.subheadline.weight(.semibold))
              Text(store.wishlistBatchBriefWorkbenchDetail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if wishlistBatchBriefNeeded {
              Button("Create packet", systemImage: "doc.badge.plus") {
                store.createWishlistBatchResearchBriefDraft()
              }
              .buttonStyle(.bordered)
              .controlSize(.small)
            } else if let latest = wishlistBatchResearchDrafts.first {
              Badge(latest.createdDate, color: .green)
            }
          }
          .padding(10)
          .background(wishlistBatchBriefWorkbenchColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        ForEach(wishlistResearchWorkbenchRequests.prefix(3)) { request in
          WishlistResearchWorkbenchRow(request: request, store: store)
        }

        ForEach(wishlistPurchasePacketNeededItems.prefix(3)) { item in
          WishlistWorkbenchPurchasePacketRow(item: item, store: store)
        }

        ForEach(wishlistWorkbenchItems.prefix(4)) { item in
          WishlistWorkbenchFollowUpRow(item: item, store: store)
        }

        CompactActionRow {
          Button("Record readiness snapshot", systemImage: "camera.metering.center.weighted") {
            store.recordWishlistAgentReadinessSnapshot()
          }
          NavigationLink {
            WishlistView(store: store)
          } label: {
            Label("Open Wishlist", systemImage: "star.square.fill")
          }
          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Audit trail", systemImage: "list.clipboard.fill")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private var operatorQueue: some View {
    Group {
      if queueItems.isEmpty {
        SettingsPanel(title: "Operator queue", symbol: "rectangle.stack.badge.person.crop.fill") {
          MVPEmptyState(
            title: hasActiveFilters ? "No workbench items match this view" : "No open workbench items",
            detail: hasActiveFilters ? "Clear filters to return to the daily exception queue." : "Blocked intake, exceptions, high-risk shipments, handoffs, and review work will appear here.",
            symbol: "rectangle.stack.badge.person.crop.fill"
          )
        }
      } else {
        ForEach(operatorSections) { group in
          SettingsPanel(title: "\(group.title) (\(group.items.count))", symbol: group.symbol) {
            Text(sectionDetail(for: group.title))
              .font(.caption)
              .foregroundStyle(.secondary)
            ForEach(group.items) { item in
              workbenchRow(for: item)
            }
          }
        }
      }
    }
  }

  private var advancedFilters: some View {
    DisclosureGroup {
      VStack(alignment: .leading, spacing: 12) {
        filters
        if hasActiveFilters {
          Button("Clear workbench filters", systemImage: "xmark.circle") {
            selectedAssignee = nil
            selectedEntityType = nil
            selectedPrioritySeverity = nil
            selectedStatus = nil
            selectedReviewState = nil
            selectedSource = nil
            workbenchSearchText = ""
          }
          .buttonStyle(.bordered)
        }
      }
      .padding(.top, 8)
    } label: {
      Label(hasActiveFilters ? "Filtered detailed queue" : "Detailed filters", systemImage: "line.3.horizontal.decrease.circle")
        .font(.headline)
    }
    .padding(16)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }

  private var filters: some View {
    FilterControlGrid {
      TextField("Search workbench items", text: $workbenchSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Assignee", selection: $selectedAssignee) {
        Text("All assignees").tag(String?.none)
        ForEach(assignees, id: \.self) { assignee in
          Text(assignee).tag(Optional(assignee))
        }
      }
      Picker("Entity", selection: $selectedEntityType) {
        Text("All entities").tag(ReviewTaskLinkedEntityType?.none)
        ForEach(ReviewTaskLinkedEntityType.allCases) { entityType in
          Label(entityType.rawValue, systemImage: entityType.symbol).tag(Optional(entityType))
        }
      }
      Picker("Priority", selection: $selectedPrioritySeverity) {
        Text("All priority").tag(String?.none)
        ForEach(prioritySeverities, id: \.self) { priority in
          Text(priority).tag(Optional(priority))
        }
      }
      Picker("Status", selection: $selectedStatus) {
        Text("All status").tag(String?.none)
        ForEach(statuses, id: \.self) { status in
          Text(status).tag(Optional(status))
        }
      }
      Picker("Review", selection: $selectedReviewState) {
        Text("All review").tag(ReviewState?.none)
        ForEach([ReviewState.needsReview, .monitor, .accepted], id: \.self) { state in
          Text(state.rawValue).tag(Optional(state))
        }
      }
      Picker("Source", selection: $selectedSource) {
        Text("All sources").tag(WorkbenchSource?.none)
        ForEach(WorkbenchSource.allCases) { source in
          Label(source.rawValue, systemImage: source.symbol).tag(Optional(source))
        }
      }
    }
  }

  private func sectionDetail(for title: String) -> String {
    switch title {
    case "Urgent now":
      return "Due, overdue, high, urgent, or critical work that should be handled first."
    case "Blocked work":
      return "Items that cannot move forward until someone resolves the blocker."
    case "Exceptions and mismatches":
      return "Validation, reconciliation, tracking, and playbook items that need a decision."
    case "High-risk shipments":
      return "Shipment, manifest, dispatch, and tracking records with elevated risk or review state."
    case "Needs review":
      return "Records waiting for a local review mark-off after follow-up."
    default:
      return "Recent open work that did not fall into a higher-priority section."
    }
  }

  private func unique(_ items: [WorkbenchItem], excluding excluded: [WorkbenchItem] = []) -> [WorkbenchItem] {
    let excludedIDs = Set(excluded.map(\.id))
    var seen = Set<String>()
    return items.filter { item in
      guard !excludedIDs.contains(item.id) else { return false }
      return seen.insert(item.id).inserted
    }
  }

  private func needsDispatchSetup(_ order: TrackedOrder) -> Bool {
    [.shipped, .inTransit, .exception].contains(order.status)
      && store.suggestedShipmentManifestRecords(for: order).isEmpty
      && store.suggestedDispatchReadinessChecklists(for: order).isEmpty
  }

  private func needsInboxDispatchReadiness(_ order: TrackedOrder) -> Bool {
    !needsPreDispatchVerification(order)
      && !inboxDispatchHandoffCompleted(order)
      && (
        store.suggestedShipmentManifestRecords(for: order).contains(where: \.isInboxHandoffSetup)
          || store.suggestedDispatchReadinessChecklists(for: order).contains(where: \.isInboxHandoffSetup)
      )
      && store.suggestedDispatchReadinessChecklists(for: order).contains { checklist in
        checklist.isInboxHandoffSetup && checklist.checklistStatus != .completed
      }
  }

  private func inboxOrderFollowUpPriority(_ order: TrackedOrder) -> Int {
    if order.status == .exception { return 120 }
    if needsPreDispatchVerification(order) { return 115 }
    if store.sourceTrailCount(for: order, includeWishlist: true) == 0 { return 112 }
    if order.reviewState != .accepted { return 110 }
    if needsDispatchSetup(order) { return 100 }
    if order.status == .inTransit { return 80 }
    if order.status == .shipped { return 70 }
    return 40
  }

  private var partialInboxOrderBlockers: [TrackedOrder] {
    inboxCreatedOrders.filter(needsPreDispatchVerification)
  }

  private var inboxDispatchReadinessOrders: [TrackedOrder] {
    inboxCreatedOrders.filter(needsInboxDispatchReadiness)
  }

  private var reopenedInboxDispatchHandoffCount: Int {
    store.shipmentManifestRecords.filter { $0.isInboxHandoffSetup && $0.dispatchStatus == .reopened }.count
      + store.dispatchReadinessChecklists.filter { $0.isInboxHandoffSetup && $0.checklistStatus == .reopened }.count
  }

  private func hasReopenedInboxDispatchHandoff(_ order: TrackedOrder) -> Bool {
    store.suggestedShipmentManifestRecords(for: order).contains { $0.isInboxHandoffSetup && $0.dispatchStatus == .reopened }
      || store.suggestedDispatchReadinessChecklists(for: order).contains { $0.isInboxHandoffSetup && $0.checklistStatus == .reopened }
      || store.tasks(for: .order, linkedEntityID: order.id.uuidString).contains { task in
        task.status != .completed && task.summary.localizedCaseInsensitiveContains("Reopened Inbox dispatch handoff")
      }
  }

  private func partialInboxTaskCount(for order: TrackedOrder) -> Int {
    store.tasks(for: .order, linkedEntityID: order.id.uuidString).filter { task in
      task.status != .completed && task.isPartialInboxOrderFollowUp
    }.count
  }

  private func needsPreDispatchVerification(_ order: TrackedOrder) -> Bool {
    partialInboxTaskCount(for: order) > 0 || order.missingInboxOrderFieldCount > 0
  }



  private func inboxDispatchHandoffCompleted(_ order: TrackedOrder) -> Bool {
    if order.latestStatus.localizedCaseInsensitiveContains("Inbox dispatch handoff completed") {
      return true
    }

    let manifests = store.suggestedShipmentManifestRecords(for: order).filter(\.isInboxHandoffSetup)
    let checklists = store.suggestedDispatchReadinessChecklists(for: order).filter(\.isInboxHandoffSetup)
    guard !manifests.isEmpty || !checklists.isEmpty else { return false }
    return manifests.allSatisfy { $0.dispatchStatus == .handedOff }
      && checklists.allSatisfy { $0.checklistStatus == .completed }
  }

  @ViewBuilder
  private func workbenchRow(for item: WorkbenchItem) -> some View {
    WorkbenchItemRow(
      item: item,
      store: store,
      customerProfiles: store.suggestedCustomerProfiles(for: item),
      destinationAddresses: store.suggestedDestinationAddresses(for: item),
      deliveryInstructions: store.suggestedDeliveryInstructions(for: item),
      packageContents: store.suggestedPackageContents(for: item),
      costRecords: store.suggestedCostRecords(for: item),
      returnClaims: store.suggestedReturnClaims(for: item),
      procurementRequests: store.suggestedProcurementRequests(for: item),
      receivingInspections: store.suggestedReceivingInspections(for: item),
      inventoryReceipts: store.suggestedInventoryReceipts(for: item),
      storageLocations: store.suggestedStorageLocations(for: item),
      custodyRecords: store.suggestedCustodyRecords(for: item),
      labelReferences: store.suggestedLabelReferenceRecords(for: item),
      scanSessions: store.suggestedScanSessionRecords(for: item),
      shipmentManifests: store.suggestedShipmentManifestRecords(for: item),
      dispatchChecklists: store.suggestedDispatchReadinessChecklists(for: item),
      intakeSourceSummary: intakeSourceSummary(for: item),
      contextDestination: AnyView(workbenchDestination(for: item))
    ) {
      if item.id == "local-data-hygiene" {
        store.createReviewTaskFromLocalDataHygiene()
      } else {
        store.createReviewTask(from: item)
      }
    } onCreateDraft: {
      store.createDraftMessage(from: item)
    } onReviewed: {
      store.markWorkbenchItemReviewed(item)
    }
  }

  private func intakeSourceSummary(for item: WorkbenchItem) -> (label: String, detail: String, tone: String, status: String, captured: String)? {
    guard item.source == .intakeEmail || item.source == .intakeParser,
          let intakeID = UUID(uuidString: item.linkedEntityID),
          let email = store.intakeEmails.first(where: { $0.id == intakeID })
    else {
      return nil
    }
    return store.intakeSourceSummary(for: email)
  }

  @ViewBuilder
  private func workbenchDestination(for item: WorkbenchItem) -> some View {
    switch item.source {
    case .reviewTask, .handoffNote:
      TasksView(store: store)
    case .intakeEmail, .intakeParser, .importQueue, .acceptanceReview:
      InboxView(store: store)
    case .spaceMailIntake, .gmailIntake:
      MailboxView(store: store)
    case .reconciliation:
      ReconciliationView(store: store)
    case .validation:
      ValidationView(store: store)
    case .shipmentGroup:
      ShipmentGroupsView(store: store)
    case .tracking:
      TrackingView(store: store)
    case .evidence:
      EvidenceView(store: store)
    case .slaPolicy:
      SLAPoliciesView(store: store)
    case .exceptionPlaybook:
      ExceptionPlaybooksView(store: store)
    case .draftMessage:
      CommunicationView(store: store)
    case .contact:
      ContactsView(store: store)
    case .customerProfile:
      CustomerProfilesView(store: store)
    case .destinationAddress:
      DestinationAddressesView(store: store)
    case .deliveryInstruction:
      DeliveryInstructionsView(store: store)
    case .packageContent:
      PackageContentsView(store: store)
    case .costRecord:
      CostsBudgetsView(store: store)
    case .returnClaim:
      ReturnsClaimsView(store: store)
    case .procurementRequest:
      ProcurementView(store: store)
    case .receivingInspection:
      ReceivingInspectionsView(store: store)
    case .inventoryReceipt:
      InventoryReceiptsView(store: store)
    case .storageLocation:
      StorageLocationsView(store: store)
    case .custodyRecord:
      CustodyChainView(store: store)
    case .labelReference:
      LabelReferencesView(store: store)
    case .scanSession:
      ScanSessionsView(store: store)
    case .shipmentManifest, .dispatchChecklist:
      DispatchView(store: store)
    case .account:
      AccountsView(store: store)
    case .vendorProfile:
      VendorProfilesView(store: store)
    case .mailboxProviderGate:
      SettingsView(store: store)
    case .setupPlaceholder:
      SettingsView(store: store)
    }
  }
}

private struct WorkbenchInboxOrderRow: View {
  var order: TrackedOrder
  var needsDispatchSetup: Bool
  var needsInboxDispatchReadiness: Bool
  var hasReopenedInboxDispatchHandoff: Bool
  var needsPreDispatchVerification: Bool
  var partialTaskCount: Int
  var sourceTrailCount: Int
  var mailboxSourceSummaries: [OrderMailboxSourceSummary]
  var store: ParcelOpsStore
  @State private var feedbackMessage: String?

  private var rowColor: Color {
    if hasReopenedInboxDispatchHandoff { return .purple }
    if needsPreDispatchVerification { return .orange }
    if needsInboxDispatchReadiness { return .teal }
    if needsDispatchSetup { return .purple }
    return order.status == .exception ? .orange : .teal
  }

  private var nextActionText: String {
    if hasReopenedInboxDispatchHandoff {
      return "Next: inspect the reopened dispatch handoff from the order and Dispatch before closing it again."
    }
    if needsPreDispatchVerification {
      return "Next: verify missing mailbox intake details from the order before dispatch setup."
    }
    if sourceTrailCount == 0 {
      return "Next: confirm the local Inbox, Import Queue, Acceptance, or Wishlist source trail before closing this handoff."
    }
    if needsDispatchSetup {
      return "Next: add or link dispatch manifest/readiness context."
    }
    if needsInboxDispatchReadiness {
      return "Next: finish readiness, label, scan, custody, and handoff checks in Dispatch."
    }
    return "Next: confirm tracking, destination, and linked follow-up from the order detail."
  }

  private var operationalTimelineSignalCount: Int {
    1
      + 1
      + sourceTrailCount
      + store.tasks(for: .order, linkedEntityID: order.id.uuidString).count
      + store.suggestedShipmentManifestRecords(for: order).count
      + store.suggestedDispatchReadinessChecklists(for: order).count
      + store.trackingEvents(for: order.id).filter { $0.severity == .watch || $0.severity == .critical }.count
  }

  private var operationalTimelineDetail: String {
    if hasReopenedInboxDispatchHandoff {
      return "Order timeline includes reopened dispatch handoff context."
    }
    if needsPreDispatchVerification {
      return "Order timeline includes Inbox handoff and verification work."
    }
    if sourceTrailCount == 0 {
      return "Order timeline is missing linked intake, import, or acceptance source context."
    }
    if needsInboxDispatchReadiness || needsDispatchSetup {
      return "Order timeline links Inbox handoff and dispatch setup."
    }
    return "Order timeline has linked local follow-up context."
  }

  private var mailboxSourceText: String {
    mailboxSourceSummaries.prefix(2)
      .map { "\($0.providerName) via \($0.mailboxLabel)" }
      .joined(separator: "; ")
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

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "shippingbox.fill")
          .foregroundStyle(rowColor)
          .frame(width: 22)

        VStack(alignment: .leading, spacing: 4) {
          Text("\(order.store) \(order.orderNumber)")
            .font(.headline)
          Text("\(order.customer) • \(order.destination)")
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text(nextActionText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(rowColor)
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 6) {
          Badge(order.status.rawValue, color: rowColor)
          Badge(order.reviewState.rawValue, color: order.reviewState.color)
          if needsPreDispatchVerification {
            Badge("Verify first", color: .orange)
          }
          if hasReopenedInboxDispatchHandoff {
            Badge("Reopened handoff", color: .purple)
          }
          if needsDispatchSetup {
            Badge("Dispatch gap", color: .purple)
          }
          if needsInboxDispatchReadiness {
            Badge("Readiness", color: .teal)
          }
        }
      }

      CompactMetadataGrid {
        Label(order.trackingNumber, systemImage: "number")
        Label(order.carrier, systemImage: "truck.box.fill")
        Label(order.latestStatus, systemImage: "waveform.path.ecg")
        if operationalTimelineSignalCount > 1 {
          Badge("\(operationalTimelineSignalCount) timeline", color: hasReopenedInboxDispatchHandoff ? .purple : .blue)
        }
        if partialTaskCount > 0 {
          Badge("\(partialTaskCount) verify task", color: .orange)
        }
        Badge(sourceTrailCount > 0 ? "\(sourceTrailCount) source" : "Source trail missing", color: sourceTrailCount > 0 ? .green : .orange)
        ForEach(mailboxSourceSummaries.prefix(2)) { source in
          Badge(source.badgeLabel, color: mailboxSourceColor(source))
        }
        if order.missingInboxOrderFieldCount > 0 {
          Badge("\(order.missingInboxOrderFieldCount) missing", color: .orange)
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      if operationalTimelineSignalCount > 1 {
        Label(operationalTimelineDetail, systemImage: "calendar.badge.clock")
          .font(.caption)
          .foregroundStyle(hasReopenedInboxDispatchHandoff ? .purple : rowColor)
          .fixedSize(horizontal: false, vertical: true)
      }

      if sourceTrailCount == 0 {
        Label("Source trail missing: open the order before marking this handoff complete.", systemImage: "link.badge.plus")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      } else if !mailboxSourceSummaries.isEmpty {
        Label(mailboxSourceText, systemImage: "envelope.badge.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.teal)
          .fixedSize(horizontal: false, vertical: true)
      }

      CompactActionRow {
        NavigationLink {
          OrderDetailView(order: order, store: store)
        } label: {
          Label("Open order", systemImage: "arrow.up.right.square.fill")
        }
        .buttonStyle(.bordered)

        if needsPreDispatchVerification {
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
          .buttonStyle(.bordered)
        } else if needsDispatchSetup || needsInboxDispatchReadiness || hasReopenedInboxDispatchHandoff {
          NavigationLink {
            DispatchView(store: store)
          } label: {
            Label(needsInboxDispatchReadiness || hasReopenedInboxDispatchHandoff ? "Open Readiness" : "Open Dispatch", systemImage: "shippingbox.and.arrow.backward.fill")
          }
          .buttonStyle(.bordered)
        }

        Button("Create task", systemImage: "checklist") {
          store.createReviewTask(from: order)
          feedbackMessage = "Review task created."
        }
        .buttonStyle(.bordered)

        Button("Create draft", systemImage: "envelope.open.fill") {
          store.createDraftMessage(from: order)
          feedbackMessage = "Draft created."
        }
        .buttonStyle(.bordered)

        if !needsPreDispatchVerification {
          Button("Mark reviewed", systemImage: "checkmark.circle.fill") {
            var reviewedOrder = order
            reviewedOrder.reviewState = .accepted
            store.updateOrder(reviewedOrder)
            feedbackMessage = "Order marked reviewed."
          }
          .buttonStyle(.bordered)
        }
      }

      if let feedbackMessage {
        WorkbenchActionFeedbackPanel(message: feedbackMessage, store: store)
      }
    }
    .padding(12)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct WorkbenchDraftFollowUpRow: View {
  var draft: DraftMessage
  var store: ParcelOpsStore
  @State private var feedbackMessage: String?

  private var isMailboxProviderDraft: Bool {
    store.isMailboxProviderDraft(draft)
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
        Image(systemName: isMailboxProviderDraft ? "stethoscope" : "envelope.open.fill")
          .foregroundStyle(statusColor)
          .frame(width: 22)

        VStack(alignment: .leading, spacing: 4) {
          Text(draft.subject)
            .font(.headline)
          Text("\(isMailboxProviderDraft ? "Mailbox provider diagnostic draft" : draft.channel.rawValue) • \(draft.recipient)")
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Text(isMailboxProviderDraft ? "Next: use this diagnostic packet to hand off provider setup, refresh, parser, Inbox, and release evidence before closing related work." : "Next: confirm the message is ready, mark it sent locally, or reopen it for another edit.")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 6) {
          Badge(draft.status.rawValue, color: statusColor)
          Badge(draft.reviewState.rawValue, color: draft.reviewState.color)
        }
      }

      Text(draft.body)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(3)

      CompactMetadataGrid {
        Label(draft.linkedEntityType.rawValue, systemImage: draft.linkedEntityType.symbol)
        Label(draft.createdDate, systemImage: "calendar")
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      if linkedOrder != nil {
        LinkedOrderContextPanel(
          order: linkedOrder,
          sourceLabel: "Workbench draft",
          emptyDetail: "No order is linked to this draft. Open drafts or the source record before marking it ready if the message should reference an order.",
          linkedDetail: "This draft has linked order context. Open the order before marking the draft ready if tracking, destination, or dispatch setup still needs confirmation.",
          store: store
        )
      }

      CompactActionRow {
        NavigationLink {
          CommunicationView(store: store)
        } label: {
          Label("Open drafts", systemImage: "bubble.left.and.bubble.right.fill")
        }
        .buttonStyle(.bordered)

        Button("Ready", systemImage: "checkmark.seal.fill") {
          store.markDraftMessageReady(draft)
          feedbackMessage = "Draft marked ready."
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
          feedbackMessage = "Draft reopened."
        }
        .buttonStyle(.bordered)
        .disabled(draft.status == .reopened)
      }

      if let feedbackMessage {
        WorkbenchActionFeedbackPanel(message: feedbackMessage, store: store)
      }
    }
    .padding(12)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistWorkbenchFollowUpRow: View {
  var item: WishlistItem
  var store: ParcelOpsStore

  private var handoff: WishlistPurchaseHandoff? {
    item.purchaseHandoff
  }

  private var linkedOrder: TrackedOrder? {
    handoff?.linkedOrderID.flatMap { orderID in
      store.orders.first { $0.id == orderID }
    }
  }

  private var linkedOrderNeedsTrackingReview: Bool {
    guard let linkedOrder else { return false }
    return linkedOrder.trackingNumber.isPlaceholderValidationValue
      || linkedOrder.trackingNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var tone: Color {
    if item.operatorPurchaseBlockers.isEmpty { return .green }
    if item.status.localizedCaseInsensitiveContains("blocked") { return .red }
    if item.status.localizedCaseInsensitiveContains("confirmation") { return .orange }
    if linkedOrderNeedsTrackingReview { return .orange }
    if handoff != nil { return .purple }
    return .teal
  }

  private var sellerEvidenceGaps: [String] {
    Array(Set((item.comparisonOptions ?? []).flatMap(\.operatorSellerEvidenceGaps))).sorted()
  }

  private var needsDecision: Bool {
    let checks = item.purchaseChecks ?? []
    return !(item.comparisonOptions ?? []).isEmpty
      && !checks.isEmpty
      && !checks.contains { $0.status != "Passed" }
      && item.purchaseDecision == nil
  }

  private var handoffGaps: [String] {
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

  private var handoffSanityGaps: [String] {
    guard item.purchaseHandoff != nil
      || item.purchaseDecision?.reviewState == .accepted
      || item.status.localizedCaseInsensitiveContains("purchase")
      || item.status.localizedCaseInsensitiveContains("order confirmation") else {
      return []
    }

    let linkedOrder = item.purchaseHandoff?.linkedOrderID.flatMap { orderID in
      store.orders.first { $0.id == orderID }
    }
    var gaps: [String] = []
    let seller = item.purchaseHandoff?.sellerName ?? item.purchaseDecision?.selectedSellerName ?? item.storefront
    if seller.isPlaceholderValidationValue { gaps.append("seller route") }
    if item.purchaseHandoff?.accountLabel.isPlaceholderValidationValue != false && store.suggestedAccounts(for: item).isEmpty {
      gaps.append("account label")
    }
    if item.purchaseHandoff?.expectedOrderSignals.isPlaceholderValidationValue != false {
      gaps.append("order link")
    }
    if store.suggestedCostRecords(for: item).isEmpty { gaps.append("cost") }
    if store.suggestedProcurementRequests(for: item).isEmpty { gaps.append("procurement") }
    if store.suggestedReceivingInspections(for: item).isEmpty { gaps.append("receiving") }
    if linkedOrder == nil && item.purchaseHandoff?.purchaseStatus.localizedCaseInsensitiveContains("purchased") == true {
      gaps.append("order link")
    }
    return gaps
  }

  private var linkedOrderDispatchGaps: [String] {
    guard handoff?.linkedOrderID != nil else { return [] }
    var gaps: [String] = []
    if store.suggestedShipmentManifestRecords(for: item).isEmpty { gaps.append("manifest") }
    if store.suggestedDispatchReadinessChecklists(for: item).isEmpty { gaps.append("readiness checklist") }
    return gaps
  }

  private var failedReadinessChecks: [WishlistPurchaseCheck] {
    (item.purchaseChecks ?? []).filter { $0.status != "Passed" }
  }

  private var nextAction: String {
    if !sellerEvidenceGaps.isEmpty {
      return "Confirm seller evidence: \(sellerEvidenceGaps.prefix(3).joined(separator: ", "))."
    }
    if needsDecision {
      return "Draft the local purchase decision before handoff."
    }
    if !failedReadinessChecks.isEmpty {
      return "Clear readiness checks: \(failedReadinessChecks.prefix(2).map(\.title).joined(separator: ", "))."
    }
    if item.purchaseDecision?.reviewState == .needsReview {
      return "Review and accept the local purchase decision."
    }
    if !handoffGaps.isEmpty {
      return "Complete handoff pack: \(handoffGaps.prefix(3).joined(separator: ", "))."
    }
    if !handoffSanityGaps.isEmpty {
      return "Resolve handoff sanity gaps: \(handoffSanityGaps.prefix(3).joined(separator: ", "))."
    }
    if linkedOrderNeedsTrackingReview {
      return "Confirm tracking on linked order \(linkedOrder?.orderNumber ?? "") before dispatch handoff."
    }
    if !linkedOrderDispatchGaps.isEmpty {
      return "Stage dispatch setup for the linked order: \(linkedOrderDispatchGaps.prefix(2).joined(separator: ", "))."
    }
    if handoff != nil && handoff?.linkedOrderID == nil {
      return "Ready for manual purchase handoff; link the order confirmation when it appears locally."
    }
    if !item.operatorPurchaseBlockers.isEmpty {
      return item.operatorPurchaseNextAction
    }
    if item.status.localizedCaseInsensitiveContains("blocked") {
      return "Resolve purchase readiness blockers before manual buying."
    }
    if item.status.localizedCaseInsensitiveContains("confirmation") {
      return "Link the seen order confirmation to an order record."
    }
    if handoff != nil {
      return "Confirm account, payment, seller, and order-watch context."
    }
    return "Review seller comparison and readiness."
  }

  var body: some View {
    NavigationLink {
      WishlistView(store: store)
    } label: {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Label(item.itemName, systemImage: "star.square.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone)
          Spacer(minLength: 8)
          Badge(item.status, color: tone)
        }
        Text("\(item.storefront) • \(item.estimatedCost) • \(item.owner)")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        if !item.operatorPurchaseBlockers.isEmpty {
          Text("Blockers: \(item.operatorPurchaseBlockers.prefix(3).joined(separator: ", "))")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        if let handoff {
          Text("Handoff: \(handoff.sellerName) • \(handoff.purchaseStatus) • \(handoff.orderWatchStatus)")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        if let linkedOrder {
          Text("Linked order: \(linkedOrder.orderNumber) • \(linkedOrder.status.rawValue) • \(linkedOrderNeedsTrackingReview ? "tracking needs review" : linkedOrder.trackingNumber)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(linkedOrderNeedsTrackingReview ? .orange : .green)
            .fixedSize(horizontal: false, vertical: true)
        }
        if !sellerEvidenceGaps.isEmpty {
          Text("Seller evidence gaps: \(sellerEvidenceGaps.prefix(4).joined(separator: ", "))")
            .font(.caption2)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
        }
        if !failedReadinessChecks.isEmpty {
          Text("Readiness blockers: \(failedReadinessChecks.prefix(4).map(\.title).joined(separator: ", "))")
            .font(.caption2)
            .foregroundStyle(failedReadinessChecks.contains { $0.status == "Blocked" || $0.severity == "High" } ? .red : .orange)
            .fixedSize(horizontal: false, vertical: true)
        }
        if !handoffGaps.isEmpty {
          Text("Handoff pack gaps: \(handoffGaps.prefix(4).joined(separator: ", "))")
            .font(.caption2)
            .foregroundStyle(.purple)
            .fixedSize(horizontal: false, vertical: true)
        }
        if !handoffSanityGaps.isEmpty {
          Text("Handoff sanity gaps: \(handoffSanityGaps.prefix(4).joined(separator: ", "))")
            .font(.caption2)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
        }
        if !linkedOrderDispatchGaps.isEmpty {
          Text("Linked order dispatch setup: \(linkedOrderDispatchGaps.prefix(3).joined(separator: ", "))")
            .font(.caption2)
            .foregroundStyle(.blue)
            .fixedSize(horizontal: false, vertical: true)
        }
        if handoff != nil && handoff?.linkedOrderID == nil && handoffGaps.isEmpty {
          Text("Release checklist: ready for manual purchase; waiting for order confirmation link.")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.green)
            .fixedSize(horizontal: false, vertical: true)
        }
        Label(nextAction, systemImage: "arrow.turn.down.right")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(tone)
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
  }
}

private struct WishlistWorkbenchPurchasePacketRow: View {
  var item: WishlistItem
  var store: ParcelOpsStore

  private var optionCount: Int {
    (item.comparisonOptions ?? []).count
  }

  private var selectedSeller: String {
    item.purchaseDecision?.selectedSellerName
      ?? item.preferredOptionID.flatMap { preferredID in
        item.comparisonOptions?.first { $0.id == preferredID }?.sellerName
      }
      ?? item.comparisonOptions?.first?.sellerName
      ?? item.storefront
  }

  private var summary: String {
    let total = item.purchaseDecision?.totalAUDSummary
      ?? item.preferredOptionID.flatMap { preferredID in
        item.comparisonOptions?.first { $0.id == preferredID }?.estimatedAUDTotal
      }
      ?? item.estimatedCost
    return "\(optionCount) seller option\(optionCount == 1 ? "" : "s") • \(selectedSeller) • \(total)"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label(item.itemName, systemImage: "doc.badge.plus")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.indigo)
        Spacer(minLength: 8)
        Badge("Packet needed", color: .indigo)
      }
      Text(summary)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Text("Create one local packet before manual buying so seller choice, AUD total, postage, trust, approvals, links, and order-watch notes are reviewed together.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      CompactActionRow {
        Button("Create packet", systemImage: "doc.badge.plus") {
          store.createWishlistPurchasePacketDraft(item)
        }
        NavigationLink {
          WishlistView(store: store)
        } label: {
          Label("Open Wishlist", systemImage: "star.square.fill")
        }
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistResearchWorkbenchRow: View {
  var request: WishlistResearchRequest
  var store: ParcelOpsStore

  private var tone: Color {
    if request.requestStatus.localizedCaseInsensitiveContains("blocked") { return .red }
    return request.isAgentBriefReady ? .green : .orange
  }

  var body: some View {
    NavigationLink {
      WishlistView(store: store)
    } label: {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Label(request.itemName, systemImage: "doc.text.magnifyingglass")
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone)
          Spacer(minLength: 8)
          Badge(request.agentBriefStatus, color: tone)
        }
        Text(request.agentBriefNextAction)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        if !request.agentBriefGaps.isEmpty {
          Text("Scope gaps: \(request.agentBriefGaps.prefix(4).joined(separator: ", "))")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Text("Future agent boundary: compare AU/overseas sellers, AUD landed cost, postage, delivery time, returns/warranty, and trust. No live browsing or purchase automation runs here.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
  }
}

struct WorkbenchItemRow: View {
  var item: WorkbenchItem
  var store: ParcelOpsStore? = nil
  var customerProfiles: [CustomerRecipientProfile] = []
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var costRecords: [CostRecord] = []
  var returnClaims: [ReturnClaimRecord] = []
  var procurementRequests: [ProcurementRequest] = []
  var receivingInspections: [ReceivingInspectionRecord] = []
  var inventoryReceipts: [InventoryReceiptRecord] = []
  var storageLocations: [StorageLocationRecord] = []
  var custodyRecords: [CustodyRecord] = []
  var labelReferences: [LabelReferenceRecord] = []
  var scanSessions: [ScanSessionRecord] = []
  var shipmentManifests: [ShipmentManifestRecord] = []
  var dispatchChecklists: [DispatchReadinessChecklist] = []
  var intakeSourceSummary: (label: String, detail: String, tone: String, status: String, captured: String)?
  var contextDestination: AnyView?
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onReviewed: () -> Void
  @State private var feedbackMessage: String?

  private var isSetupPlaceholder: Bool {
    item.source == .setupPlaceholder
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: item.source.symbol)
          .foregroundStyle(item.color)
          .frame(width: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(item.title)
            .font(.headline)
          Text(item.summary)
            .foregroundStyle(.secondary)
            .lineLimit(3)
          Text(item.suggestedNextAction)
            .font(.caption.weight(.semibold))
            .foregroundStyle(item.color)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 6) {
          Badge(item.prioritySeverity, color: item.color)
          Badge(item.status, color: item.color)
          if let reviewState = item.reviewState {
            Badge(reviewState.rawValue, color: reviewState.color)
          }
        }
      }

      CompactMetadataGrid {
        Label(item.assignee, systemImage: "person.2.fill")
        Label(item.dueDateText, systemImage: "calendar")
        Label(item.linkedEntityType.rawValue, systemImage: item.linkedEntityType.symbol)
        if let intakeSourceSummary {
          Label(intakeSourceSummary.label, systemImage: "tray.full.fill")
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      if let intakeSourceSummary {
        WorkbenchInboxSourcePanel(summary: intakeSourceSummary)
      }

      if isSetupPlaceholder {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "lock.shield.fill")
            .foregroundStyle(.teal)
            .frame(width: 18)
          Text("Local planning item only. Reviewing or removing this placeholder changes JSON state and Audit history; it does not connect Shopify, read folders, open logins, store credentials, or contact external services.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }

      workbenchDecisionPanel

      CompactActionRow {
        if let contextDestination {
          NavigationLink {
            contextDestination
          } label: {
            Label(isSetupPlaceholder ? "Open Settings" : "Open work item", systemImage: isSetupPlaceholder ? "gearshape.2.fill" : "arrow.up.right.square.fill")
          }
          .buttonStyle(.bordered)
        }
        Button("Create task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Workbench follow-up task created. Check Tasks."
        }
          .buttonStyle(.bordered)
        if !isSetupPlaceholder {
          Button("Create draft", systemImage: "envelope.open.fill") {
            onCreateDraft()
            feedbackMessage = "Draft message created from workbench item. Check Drafts."
          }
            .buttonStyle(.bordered)
        }
        if item.supportsReviewAction {
          Button(isSetupPlaceholder ? "Review setup" : "Mark reviewed", systemImage: "checkmark.circle.fill") {
            onReviewed()
            feedbackMessage = isSetupPlaceholder ? "Setup placeholder reviewed locally." : "Workbench item marked reviewed locally."
          }
            .buttonStyle(.bordered)
        }
        Text(item.source.rawValue)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }

      if let feedbackMessage {
        WorkbenchActionFeedbackPanel(message: feedbackMessage, store: store)
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
      if !costRecords.isEmpty {
        CostRecordStrip(costs: costRecords)
      }
      if !returnClaims.isEmpty {
        ReturnClaimStrip(claims: returnClaims)
      }
      if !procurementRequests.isEmpty {
        ProcurementRequestStrip(requests: procurementRequests)
      }
      if !receivingInspections.isEmpty {
        ReceivingInspectionStrip(inspections: receivingInspections)
      }
      if !inventoryReceipts.isEmpty {
        InventoryReceiptStrip(receipts: inventoryReceipts)
      }
      if !storageLocations.isEmpty {
        StorageLocationStrip(locations: storageLocations)
      }
      if !custodyRecords.isEmpty {
        CustodyRecordStrip(records: custodyRecords)
      }
      if !labelReferences.isEmpty {
        LabelReferenceStrip(records: labelReferences)
      }
      if !scanSessions.isEmpty {
        ScanSessionStrip(records: scanSessions)
      }
      if !shipmentManifests.isEmpty {
        ShipmentManifestStrip(records: shipmentManifests)
      }
      if !dispatchChecklists.isEmpty {
        DispatchReadinessStrip(checklists: dispatchChecklists)
      }
    }
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }

  private var workbenchDecisionPanel: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: decisionSymbol)
        .foregroundStyle(decisionColor)
        .frame(width: 22)

      VStack(alignment: .leading, spacing: 4) {
        Text(decisionTitle)
          .font(.caption.weight(.semibold))
        Text(decisionDetail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 8)
      Badge(decisionBadge, color: decisionColor)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(decisionColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private var decisionTitle: String {
    if isSetupPlaceholder { return "Setup placeholder needs review" }
    if item.isBlocked { return "Blocked work needs an owner" }
    if item.isException { return "Exception or mismatch needs a decision" }
    if item.reviewState == .needsReview { return "Local review is required" }
    if item.rank >= 4 { return "Urgent work should move first" }
    if item.rank >= 3 { return "High-priority work needs action" }

    switch item.source {
    case .intakeEmail, .intakeParser, .spaceMailIntake, .importQueue, .acceptanceReview:
      return "Route through Inbox"
    case .shipmentManifest, .dispatchChecklist:
      return "Route through Dispatch"
    case .reviewTask, .handoffNote:
      return "Route through Tasks"
    case .tracking:
      return "Check tracking context"
    case .validation, .reconciliation:
      return "Resolve data mismatch"
    case .evidence:
      return "Review supporting evidence"
    case .shipmentGroup:
      return "Review shipment group risk"
    default:
      return "Review linked local record"
    }
  }

  private var decisionDetail: String {
    if isSetupPlaceholder {
      return "This is a local planning/setup item. Open Settings, complete or review the placeholder, then mark it reviewed when no further setup follow-up is needed."
    }
    if item.isBlocked {
      return "Create or assign a task, open the linked context, and clear the blocker before moving this item through the daily flow."
    }
    if item.isException {
      return "Open the linked record and decide whether to correct data, create a task, draft a message, or mark reviewed after the exception is understood."
    }
    if item.reviewState == .needsReview {
      return "Open the work item, confirm the local evidence, then mark reviewed only when no follow-up remains."
    }
    if item.rank >= 4 {
      return "Treat this as urgent. Open context first, then create a task or draft if another person needs to own the work."
    }
    if item.rank >= 3 {
      return "Handle this before routine monitoring. The suggested action is: \(item.suggestedNextAction)"
    }

    switch item.source {
    case .intakeEmail, .intakeParser, .spaceMailIntake, .importQueue, .acceptanceReview:
      return "Use Inbox or Mailbox Monitor to confirm source details before creating, linking, accepting, or ignoring records."
    case .shipmentManifest, .dispatchChecklist:
      return "Use Dispatch to prepare, complete, block, or review outbound work. Do not treat it as ready until linked order and handoff context is clear."
    case .reviewTask, .handoffNote:
      return "Use Tasks to complete, reopen, acknowledge, or create follow-up ownership."
    case .tracking:
      return "Open tracking context and compare severity, carrier state, and linked order before creating follow-up work."
    case .validation, .reconciliation:
      return "Compare detected and expected local values, then correct the linked record or create a task if someone must verify it."
    case .evidence:
      return "Open the evidence record and confirm whether it supports an order, dispatch, claim, or review task."
    case .shipmentGroup:
      return "Open shipment group context and check high-risk, blocked, or review-needed group state before dispatch."
    default:
      return "Open the linked local context and use task/draft/review actions only when they help the daily operator flow."
    }
  }

  private var decisionBadge: String {
    if isSetupPlaceholder { return "Setup" }
    if item.isBlocked { return "Blocked" }
    if item.isException { return "Exception" }
    if item.reviewState == .needsReview { return "Review" }
    if item.rank >= 4 { return "Urgent" }
    if item.rank >= 3 { return "High" }
    switch item.source {
    case .intakeEmail, .intakeParser, .spaceMailIntake, .importQueue, .acceptanceReview:
      return "Inbox"
    case .shipmentManifest, .dispatchChecklist:
      return "Dispatch"
    case .reviewTask, .handoffNote:
      return "Tasks"
    default:
      return "Open"
    }
  }

  private var decisionColor: Color {
    if item.isBlocked { return .red }
    if item.isException || item.rank >= 4 { return .orange }
    if item.reviewState == .needsReview || item.rank >= 3 { return .orange }
    if isSetupPlaceholder { return .teal }
    switch item.source {
    case .intakeEmail, .intakeParser, .spaceMailIntake, .importQueue, .acceptanceReview:
      return .teal
    case .shipmentManifest, .dispatchChecklist:
      return .purple
    case .reviewTask, .handoffNote:
      return .blue
    default:
      return item.color
    }
  }

  private var decisionSymbol: String {
    if isSetupPlaceholder { return "gearshape.2.fill" }
    if item.isBlocked { return "hand.raised.fill" }
    if item.isException { return "arrow.triangle.2.circlepath.circle.fill" }
    if item.reviewState == .needsReview { return "checkmark.shield.fill" }
    if item.rank >= 3 { return "flame.fill" }
    switch item.source {
    case .intakeEmail, .intakeParser, .spaceMailIntake, .importQueue, .acceptanceReview:
      return "tray.full.fill"
    case .shipmentManifest, .dispatchChecklist:
      return "paperplane.fill"
    case .reviewTask, .handoffNote:
      return "checklist"
    case .tracking:
      return "location.north.line.fill"
    case .validation, .reconciliation:
      return "exclamationmark.arrow.triangle.2.circlepath"
    default:
      return item.source.symbol
    }
  }
}

private struct WorkbenchActionFeedbackPanel: View {
  var message: String
  var store: ParcelOpsStore?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(message, systemImage: "checkmark.circle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.green)

      if let store {
        CompactActionRow {
          if message.localizedCaseInsensitiveContains("task") {
            NavigationLink {
              TasksView(store: store)
            } label: {
              Label("Open Tasks", systemImage: "checklist")
            }
          }
          if message.localizedCaseInsensitiveContains("draft") {
            NavigationLink {
              CommunicationView(store: store)
            } label: {
              Label("Open Drafts", systemImage: "envelope.open.fill")
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
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.green.opacity(0.12))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct WorkbenchMailboxRouteCard: View {
  var title: String
  var detail: String
  var count: Int
  var symbol: String
  var color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .top, spacing: 8) {
        Image(systemName: symbol)
          .foregroundStyle(color)
          .frame(width: 18)
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.caption.weight(.semibold))
          Text(detail)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge("\(count)", color: color)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WorkbenchInboxSourcePanel: View {
  var summary: (label: String, detail: String, tone: String, status: String, captured: String)

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Label("Inbox source", systemImage: "tray.full.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Badge(summary.label, color: sourceColor)
        Badge(summary.status, color: sourceColor)
      }

      Text("\(summary.detail) Captured \(summary.captured).")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(sourceColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private var sourceColor: Color {
    switch summary.tone {
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
}
