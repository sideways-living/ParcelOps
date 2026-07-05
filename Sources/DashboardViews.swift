import SwiftUI

struct DashboardView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var dashboardSearchText = ""
  @State private var feedbackMessage: String?

  private var isCompact: Bool { horizontalSizeClass == .compact }
  private var normalizedDashboardSearch: String {
    dashboardSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }
  private var metricColumns: [GridItem] {
    Array(repeating: GridItem(.flexible(), spacing: 12), count: isCompact ? 2 : 4)
  }
  private var sectionColumns: [GridItem] {
    Array(repeating: GridItem(.flexible(), spacing: 14), count: isCompact ? 1 : 2)
  }
  private var incomingAttentionCount: Int {
    store.reviewIntakeEmails.count + spaceMailHealthAttentionCount + store.importQueueItemsNeedingReview.count + store.blockedImportQueueItems.count + store.acceptanceRecordsNeedingReview.count
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
  private var blockedInboxSourceCount: Int {
    store.blockedImportQueueItems.count
      + store.lowConfidenceImportQueueItems.count
      + store.intakeParserDiagnostics.filter { $0.severity == .critical || $0.severity == .high }.count
  }
  private var readyAcceptanceOrImportCount: Int {
    store.importQueueItemsNeedingReview.count
      + store.acceptanceRecordsNeedingReview.count
  }
  private var inboxTriageQualityTone: Color {
    if blockedInboxSourceCount > 0 || weakInboxParseCount > 0 { return .orange }
    if readyInboxLinkCount > 0 || readyAcceptanceOrImportCount > 0 { return .teal }
    return .green
  }
  private var inboxTriageQualityTitle: String {
    if blockedInboxSourceCount > 0 || weakInboxParseCount > 0 { return "Fix weak Inbox parses first" }
    if readyInboxLinkCount > 0 { return "Create or link ready Inbox records" }
    if readyAcceptanceOrImportCount > 0 { return "Accept staged Inbox records" }
    if linkedInboxIntakeCount > 0 { return "Review linked Inbox handoffs" }
    return "Inbox triage quality is clear"
  }
  private var inboxTriageQualityDetail: String {
    if blockedInboxSourceCount > 0 || weakInboxParseCount > 0 {
      return "\(weakInboxParseCount) mailbox row\(weakInboxParseCount == 1 ? "" : "s") need order/tracking correction and \(blockedInboxSourceCount) import/parser source\(blockedInboxSourceCount == 1 ? "" : "s") need attention before order creation."
    }
    if readyInboxLinkCount > 0 || readyAcceptanceOrImportCount > 0 {
      return "\(readyInboxLinkCount) mailbox row\(readyInboxLinkCount == 1 ? "" : "s") look ready to create/link and \(readyAcceptanceOrImportCount) import or acceptance row\(readyAcceptanceOrImportCount == 1 ? "" : "s") can be reviewed."
    }
    if linkedInboxIntakeCount > 0 {
      return "\(linkedInboxIntakeCount) intake row\(linkedInboxIntakeCount == 1 ? "" : "s") already link to orders. Confirm the source trail and close review when done."
    }
    return "No current intake row is asking for parser correction, order creation, import acceptance, or linked-order review."
  }
  private var hasSpaceMailSetup: Bool {
    !store.spaceMailIMAPConnections.isEmpty
  }
  private var hasSpaceMailCredentialReference: Bool {
    store.spaceMailIMAPConnections.contains {
      $0.credentialStorageStatus.localizedCaseInsensitiveContains("available")
        || $0.credentialStorageStatus.localizedCaseInsensitiveContains("ready")
    }
  }
  private var hasSpaceMailManualRefreshEvidence: Bool {
    store.spaceMailIMAPConnections.contains { $0.lastManualRefreshDate != "Never" }
  }
  private var spaceMailHealthAttentionCount: Int {
    store.spaceMailIntakeHealthSummaries.filter {
      $0.tone == "warning" || $0.pendingUncertainReviewCount > 0 || $0.parserIssueCount > 0 || $0.importedCount > 0
    }.count
  }
  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.spaceMailIntakeHealthSummaries.first
  }
  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.gmailIntakeHealthSummaries.first
  }
  private var gmailSetupBlockerCount: Int {
    store.gmailMailboxConnections.filter { !store.gmailOAuthReadinessSummary(for: $0).isReady }.count
  }
  private var pendingGmailUncertainReviewCount: Int {
    store.gmailMailboxConnections.reduce(0) { $0 + max($1.uncertainMessages?.count ?? 0, $1.lastRefreshUncertainCount ?? 0) }
  }
  private var pendingGmailFilteredReviewCount: Int {
    store.gmailMailboxConnections.reduce(0) { $0 + ($1.filteredMessages?.count ?? 0) }
  }
  private var latestSpaceMailTone: Color {
    guard let summary = latestSpaceMailSummary else { return hasSpaceMailSetup ? .orange : .secondary }
    switch summary.tone {
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
  private var latestGmailTone: Color {
    guard let summary = latestGmailSummary else { return store.gmailMailboxConnections.isEmpty ? .secondary : .orange }
    switch summary.tone {
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
  private var latestSpaceMailTitle: String {
    guard let summary = latestSpaceMailSummary else {
      if !hasSpaceMailSetup { return "SpaceMail setup not started" }
      if !hasSpaceMailCredentialReference { return "SpaceMail credential needed" }
      return "Run a manual SpaceMail refresh"
    }
    if summary.importedCount > 0 { return "Latest SpaceMail refresh imported order mail" }
    if summary.pendingUncertainReviewCount > 0 || summary.uncertainCount > 0 { return "Latest SpaceMail refresh needs uncertain review" }
    if summary.filteredCount > 0 && summary.importedCount == 0 { return "Latest SpaceMail refresh filtered non-order mail" }
    if summary.duplicateCount > 0 { return "Latest SpaceMail refresh found duplicates" }
    return summary.verdict
  }
  private var latestSpaceMailDetail: String {
    guard let summary = latestSpaceMailSummary else {
      if !hasSpaceMailSetup {
        return "Add a SpaceMail IMAP setup in Mailbox Monitor or Settings before testing live mailbox intake."
      }
      if !hasSpaceMailCredentialReference {
        return "Set or check the Keychain credential, then run an explicit read-only refresh."
      }
      return "No real SpaceMail refresh summary is available yet. Run manual refresh from Mailbox Monitor."
    }
    return "\(summary.displayName): \(summary.fetchedCount) fetched, \(summary.importedCount) imported, \(summary.duplicateCount) duplicate, \(summary.filteredCount) filtered, \(summary.pendingUncertainReviewCount + summary.uncertainCount) uncertain. \(summary.nextAction)"
  }
  private var latestGmailTitle: String {
    guard let summary = latestGmailSummary else {
      if store.gmailMailboxConnections.isEmpty { return "Gmail setup not started" }
      return "Run a Gmail readiness check"
    }
    if pendingGmailUncertainReviewCount > 0 { return "Latest Gmail refresh needs uncertain review" }
    if pendingGmailFilteredReviewCount > 0 && summary.importedCount == 0 { return "Latest Gmail refresh has filtered examples" }
    return summary.verdict
  }
  private var latestGmailDetail: String {
    guard let summary = latestGmailSummary else {
      if store.gmailMailboxConnections.isEmpty {
        return "Add a Gmail setup in Mailbox Monitor or Settings when a mailbox is hosted by Gmail or Google Workspace."
      }
      return "No Gmail readiness or refresh summary is available yet. Use Mailbox Monitor to check setup."
    }
    let filteredDetail = pendingGmailFilteredReviewCount > 0 ? " \(pendingGmailFilteredReviewCount) filtered preview\(pendingGmailFilteredReviewCount == 1 ? "" : "s") can be reviewed in Mailbox Monitor if an expected order email is missing." : ""
    return "\(summary.displayName): \(summary.fetchedCount) fetched, \(summary.importedCount) imported, \(summary.duplicateCount) duplicate, \(summary.filteredCount) filtered, \(pendingGmailUncertainReviewCount) uncertain.\(filteredDetail) \(summary.nextAction)"
  }
  private var problemOrdersCount: Int {
    store.reviewOrders.count + store.orders.filter { $0.status == .exception }.count + store.trackingWarningCount + store.criticalTrackingCount
  }
  private var inboxCreatedOrders: [TrackedOrder] {
    store.orders.filter(\.isInboxCreatedLocalOrder)
  }
  private var inboxCreatedOrdersWithSourceTrail: [TrackedOrder] {
    inboxCreatedOrders.filter(hasInboxSourceTrail)
  }
  private var inboxCreatedOrdersMissingSourceTrail: [TrackedOrder] {
    inboxCreatedOrders.filter { !hasInboxSourceTrail($0) }
  }
  private var partialInboxOrderBlockers: [TrackedOrder] {
    inboxCreatedOrders.filter { order in
      hasPartialInboxOrderTask(order) || order.missingInboxOrderFieldCount > 0
    }
  }
  private var inboxDispatchGapOrders: [TrackedOrder] {
    store.orders.filter { order in
      order.isInboxCreatedLocalOrder
        && [.shipped, .inTransit, .exception].contains(order.status)
        && store.suggestedShipmentManifestRecords(for: order).isEmpty
        && store.suggestedDispatchReadinessChecklists(for: order).isEmpty
    }
  }
  private var inboxDispatchSetupPendingOrders: [TrackedOrder] {
    store.orders.filter { order in
      order.isInboxCreatedLocalOrder
        && !hasPartialInboxOrderTask(order)
        && order.missingInboxOrderFieldCount == 0
        && !inboxDispatchHandoffCompleted(order)
        && (
          store.suggestedShipmentManifestRecords(for: order).contains(where: \.isInboxHandoffSetup)
            || store.suggestedDispatchReadinessChecklists(for: order).contains(where: \.isInboxHandoffSetup)
        )
        && store.suggestedDispatchReadinessChecklists(for: order).contains { checklist in
          checklist.isInboxHandoffSetup && checklist.checklistStatus != .completed
        }
    }
  }
  private var reopenedInboxDispatchManifests: [ShipmentManifestRecord] {
    store.shipmentManifestRecords.filter { $0.isInboxHandoffSetup && $0.dispatchStatus == .reopened }
  }
  private var reopenedInboxDispatchChecklists: [DispatchReadinessChecklist] {
    store.dispatchReadinessChecklists.filter { $0.isInboxHandoffSetup && $0.checklistStatus == .reopened }
  }
  private var reopenedInboxDispatchHandoffCount: Int {
    reopenedInboxDispatchManifests.count + reopenedInboxDispatchChecklists.count
  }
  private var dispatchAttentionCount: Int {
    store.blockedShipmentManifests.count + store.undispatchedShipmentManifests.count + store.blockedDispatchChecklists.count + store.incompleteDispatchChecklists.count + inboxDispatchGapOrders.count + inboxDispatchSetupPendingOrders.count + partialInboxOrderBlockers.count + reopenedInboxDispatchHandoffCount
  }
  private var taskAttentionCount: Int {
    store.reviewTasksNeedingAttention.count
      + store.handoffNotesNeedingAttention.count
      + store.draftMessagesNeedingReview.count
  }
  private var openSpaceMailAssignedTasks: [ReviewTask] {
    store.reviewTasks.filter { task in
      task.status != .completed
        && (
          task.title.localizedCaseInsensitiveContains("spacemail")
            || task.summary.localizedCaseInsensitiveContains("spacemail")
            || store.spaceMailIMAPConnections.contains { task.linkedEntityID == $0.id.uuidString }
        )
    }
  }
  private var openSpaceMailAssignedHandoffs: [HandoffNote] {
    store.handoffNotes.filter { note in
      note.status != .completed
        && (
          note.title.localizedCaseInsensitiveContains("spacemail")
            || note.summary.localizedCaseInsensitiveContains("spacemail")
            || note.notes.localizedCaseInsensitiveContains("spacemail")
            || store.spaceMailIMAPConnections.contains { note.linkedEntityID == $0.id.uuidString }
        )
    }
  }
  private var pendingSpaceMailUncertainCount: Int {
    store.spaceMailIMAPConnections.reduce(0) { $0 + $1.uncertainMessages.count }
  }
  private var pendingSpaceMailFilteredCount: Int {
    store.spaceMailIMAPConnections.reduce(0) { $0 + $1.filteredMessages.count }
  }
  private var spaceMailAssignedFollowUpCount: Int {
    openSpaceMailAssignedTasks.count + openSpaceMailAssignedHandoffs.count
  }
  private var spaceMailFollowUpNeedsDashboardAttention: Bool {
    spaceMailAssignedFollowUpCount > 0 || pendingSpaceMailUncertainCount > 0
  }
  private var spaceMailParserSuiteResults: [SpaceMailClassifierTestResult] {
    store.spaceMailIMAPConnections.flatMap(\.classifierTestResults)
  }
  private var spaceMailParserSuiteChecks: [SpaceMailClassifierTestResult] {
    spaceMailParserSuiteResults.filter { !$0.parserStatus.localizedCaseInsensitiveContains("No parser expectation") }
  }
  private var spaceMailParserSuitePasses: [SpaceMailClassifierTestResult] {
    spaceMailParserSuiteChecks.filter { $0.parserStatus.localizedCaseInsensitiveContains("passed") }
  }
  private var spaceMailParserSuiteFailures: [SpaceMailClassifierTestResult] {
    spaceMailParserSuiteChecks.filter { $0.parserStatus.localizedCaseInsensitiveContains("needs review") }
  }
  private var spaceMailParserExtractedIDCount: Int {
    spaceMailParserSuiteResults.filter {
      !$0.detectedOrderNumber.isPlaceholderValidationValue || !$0.detectedTrackingNumber.isPlaceholderValidationValue
    }.count
  }
  private var spaceMailParserQANeedsDashboardAttention: Bool {
    spaceMailParserSuiteChecks.isEmpty || !spaceMailParserSuiteFailures.isEmpty
  }
  private var spaceMailParserQATone: Color {
    if spaceMailParserSuiteChecks.isEmpty { return .secondary }
    return spaceMailParserSuiteFailures.isEmpty ? .green : .orange
  }
  private var spaceMailParserQATitle: String {
    if spaceMailParserSuiteChecks.isEmpty { return "Run parser QA before relying on live intake" }
    if !spaceMailParserSuiteFailures.isEmpty { return "Review parser QA failures" }
    return "Parser QA passed"
  }
  private var spaceMailParserQADetail: String {
    if spaceMailParserSuiteChecks.isEmpty {
      return "The parser/classifier suite has not been run for SpaceMail. Run it from Mailbox Monitor before treating extracted order and tracking numbers as trusted."
    }
    if !spaceMailParserSuiteFailures.isEmpty {
      return "\(spaceMailParserSuiteFailures.count) parser expectation failed. Review the sample result before creating orders from similar SpaceMail messages."
    }
    return "\(spaceMailParserSuitePasses.count) parser expectations passed with \(spaceMailParserExtractedIDCount) sample ID extraction result\(spaceMailParserExtractedIDCount == 1 ? "" : "s")."
  }
  private var setupPlaceholderReviewItems: [WorkbenchItem] {
    store.openWorkbenchItems.filter { $0.source == .setupPlaceholder }
  }
  private var setupAttentionCount: Int {
    setupPlaceholderReviewItems.count
  }
  private var operatorWorkbenchItems: [WorkbenchItem] {
    store.openWorkbenchItems.filter { $0.source != .intakeParser }
  }
  private var highPriorityOperatorWorkbenchItems: [WorkbenchItem] {
    operatorWorkbenchItems.filter { $0.rank >= 3 }
  }
  private var overdueOperatorWorkbenchItems: [WorkbenchItem] {
    operatorWorkbenchItems.filter(\.isDueOrOverdue)
  }
  private var blockedOperatorWorkbenchItems: [WorkbenchItem] {
    operatorWorkbenchItems.filter(\.isBlocked)
  }
  private var operatorWorkbenchReviewItems: [WorkbenchItem] {
    operatorWorkbenchItems.filter { $0.reviewState == .needsReview }
  }
  private var attentionNowCount: Int {
    incomingAttentionCount + problemOrdersCount + dispatchAttentionCount + taskAttentionCount + highPriorityOperatorWorkbenchItems.count + setupAttentionCount
  }
  private var advancedBacklogCount: Int {
    max(store.reviewQueueCount - attentionNowCount, 0)
  }
  private var visibleDashboardMatchCount: Int {
    [
      dashboardMatches("inbox", "mailbox", "spacemail", "email", "parser", "import", "acceptance", "triage", "intake"),
      dashboardMatches("orders", "order", "tracking", "customer", "destination", "inbox-created"),
      dashboardMatches("workbench", "exception", "validation", "reconciliation", "high-priority"),
      dashboardMatches("dispatch", "manifest", "readiness", "outbound", "handoff", "reopened"),
      dashboardMatches("tasks", "task", "handoff", "draft", "follow-up", "overdue"),
      dashboardMatches("settings", "setup", "placeholder", "shopify", "folder", "login", "local-only"),
      dashboardMatches("audit", "activity", "history", "record change", "workflow"),
      dashboardMatches("incoming order intake", "inbox", "mailbox", "spacemail", "parser", "import", "acceptance"),
      dashboardMatches("active problem orders", "orders", "tracking", "inbox-created", "source", "trail", "customer", "destination"),
      dashboardMatches("dispatch readiness", "dispatch", "manifest", "readiness", "blocked", "undispatched", "reopened"),
      dashboardMatches("open tasks handoffs drafts", "tasks", "handoff", "draft", "overdue", "high"),
      dashboardMatches("recent local activity", "audit", "activity", "recent", "history")
    ].filter { $0 }.count
  }

  private var dailyStartTone: Color {
    if !hasSpaceMailSetup || !hasSpaceMailCredentialReference || !hasSpaceMailManualRefreshEvidence { return .orange }
    if incomingAttentionCount > 0 { return .orange }
    if !partialInboxOrderBlockers.isEmpty { return .orange }
    if problemOrdersCount > 0 { return .red }
    if highPriorityOperatorWorkbenchItems.count > 0 { return .purple }
    if reopenedInboxDispatchHandoffCount > 0 { return .purple }
    if dispatchAttentionCount > 0 { return .blue }
    if taskAttentionCount > 0 { return .orange }
    if setupAttentionCount > 0 { return .teal }
    return .green
  }

  private var dailyStartTitle: String {
    if !hasSpaceMailSetup { return "Set up SpaceMail first" }
    if !hasSpaceMailCredentialReference { return "Add the SpaceMail Keychain credential" }
    if !hasSpaceMailManualRefreshEvidence { return "Run one manual SpaceMail refresh" }
    if incomingAttentionCount > 0 { return "Start in Inbox" }
    if !partialInboxOrderBlockers.isEmpty { return "Verify Inbox-created orders" }
    if problemOrdersCount > 0 { return "Start with Orders" }
    if highPriorityOperatorWorkbenchItems.count > 0 { return "Start in Workbench" }
    if reopenedInboxDispatchHandoffCount > 0 { return "Review reopened dispatch handoffs" }
    if dispatchAttentionCount > 0 { return "Start with Dispatch" }
    if taskAttentionCount > 0 { return "Start with Tasks" }
    if setupAttentionCount > 0 { return "Review local setup placeholders" }
    return "Daily queue is clear"
  }

  private var dailyStartDetail: String {
    if !hasSpaceMailSetup {
      return "Add the non-secret SpaceMail IMAP setup from Settings or Mailbox Monitor before relying on live intake. You can still test the local demo flow."
    }
    if !hasSpaceMailCredentialReference {
      return "Use the secure SpaceMail credential action. Do not put passwords or app passwords into setup notes or JSON-backed fields."
    }
    if !hasSpaceMailManualRefreshEvidence {
      return "Run the explicit read-only SpaceMail refresh once so Dashboard, Mailbox Monitor, and Audit have a real refresh result."
    }
    if incomingAttentionCount > 0 {
      return "\(incomingAttentionCount) incoming item needs triage from mailbox intake, SpaceMail review, import queue, or acceptance review."
    }
    if !partialInboxOrderBlockers.isEmpty {
      return "\(partialInboxOrderBlockers.count) Inbox-created order has missing details or an open verification task. Confirm those before dispatch setup."
    }
    if problemOrdersCount > 0 {
      return "\(problemOrdersCount) order signal needs attention from review state, exceptions, tracking warnings, or Inbox-created order handoff."
    }
    if highPriorityOperatorWorkbenchItems.count > 0 {
      return "\(highPriorityOperatorWorkbenchItems.count) high-priority exception, validation, reconciliation, or operational workbench item is open."
    }
    if reopenedInboxDispatchHandoffCount > 0 {
      return "\(reopenedInboxDispatchHandoffCount) Inbox dispatch handoff record was reopened. Open Dispatch or the linked order to complete or block it."
    }
    if dispatchAttentionCount > 0 {
      return "\(dispatchAttentionCount) dispatch item needs preparation, readiness review, or blocked-manifest follow-up."
    }
    if taskAttentionCount > 0 {
      return "\(taskAttentionCount) task, handoff, or draft message needs ownership, completion, local send status, or review."
    }
    if setupAttentionCount > 0 {
      return "\(setupAttentionCount) setup placeholder needs local review or cleanup. These are planning records only; no live integration is implied."
    }
    return "No primary daily operator queue has promoted work right now. Use Audit or advanced routes only when checking detailed history."
  }

  private var dailyFlowCheckpointItems: [(title: String, detail: String, count: Int, destination: String, symbol: String, color: Color)] {
    let setupBlockers = (hasSpaceMailSetup ? 0 : 1)
      + (hasSpaceMailCredentialReference ? 0 : 1)
      + (hasSpaceMailManualRefreshEvidence ? 0 : 1)
      + setupAttentionCount
    let orderBlockers = problemOrdersCount + partialInboxOrderBlockers.count
    let workbenchBlockers = highPriorityOperatorWorkbenchItems.count + overdueOperatorWorkbenchItems.count + blockedOperatorWorkbenchItems.count

    return [
      (
        "Settings",
        "Confirm SpaceMail setup, Keychain credential, manual refresh evidence, and planning-only placeholders.",
        setupBlockers,
        "Settings",
        "gearshape.fill",
        setupBlockers == 0 ? .green : .orange
      ),
      (
        "Inbox",
        "Triage imported order mail, uncertain mixed-mailbox items, import queue items, and acceptance review.",
        incomingAttentionCount,
        "Inbox",
        "tray.full.fill",
        incomingAttentionCount == 0 ? .green : .orange
      ),
      (
        "Orders",
        "Verify Inbox-created orders, source trails, tracking warnings, exceptions, and missing dispatch context.",
        orderBlockers,
        "Orders",
        "shippingbox.fill",
        orderBlockers == 0 ? .green : .red
      ),
      (
        "Workbench",
        "Resolve high-priority, overdue, blocked, validation, reconciliation, parser, and setup follow-up.",
        workbenchBlockers,
        "Workbench",
        "rectangle.stack.badge.person.crop.fill",
        workbenchBlockers == 0 ? .green : .purple
      ),
      (
        "Dispatch",
        "Prepare manifests, readiness checklists, reopened handoffs, and missing dispatch setup.",
        dispatchAttentionCount,
        "Dispatch",
        "paperplane.fill",
        dispatchAttentionCount == 0 ? .green : .blue
      ),
      (
        "Tasks",
        "Complete or assign review tasks, handoff notes, draft follow-up, and overdue local work.",
        taskAttentionCount,
        "Tasks",
        "checklist",
        taskAttentionCount == 0 ? .green : .orange
      ),
      (
        "Audit",
        "Use the activity feed to confirm local actions, record changes, imports, reviews, and task creation.",
        store.auditEvents.count,
        "Audit",
        "list.clipboard.fill",
        store.auditEvents.isEmpty ? .secondary : .teal
      )
    ]
  }

  private var dailyFlowClearCount: Int {
    dailyFlowCheckpointItems.filter { item in
      item.count == 0 || item.title == "Audit"
    }.count
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        header
        dailyStartDecisionPanel
        inboxTriageQualityPanel
        dailyFlowCheckpointPanel
        liveMailboxStatusPanel
        MVPDevelopmentStatusPanel(store: store)
        MVPWorkflowGuide(
          title: "Daily operator path",
          detail: "Use these screens in order for the current manual mailbox workflow. SpaceMail and Gmail are the active live intake paths; Microsoft 365 remains an advanced provider path.",
          steps: [
            "Run or review the latest manual SpaceMail or Gmail refresh.",
            "Triage imported intake and decide on uncertain mixed-mailbox messages.",
            "Create or link an order from confirmed intake.",
            "Clear Workbench, Tasks, and Dispatch follow-up for that order.",
            "Check Audit and Settings when you need traceability or setup context."
          ],
          symbol: "map.fill"
        )
        MVPReadinessCallout(store: store)
        OperatorSupportSnapshotCard(store: store, detail: "Current support snapshot for the daily operator workflow.")
        OperatorTestSessionChecklistCard(store: store, detail: "Run this checklist when validating the current operator flow.")
        OperatorHandoffBriefCard(store: store, detail: "Current handoff notes for the next operator or test session.")
        OperatorMVPReadinessCard(store: store)
        LocalDataHygieneSummaryCard(
          store: store,
          title: "Testing data hygiene",
          detail: "Use this before judging the app by old mailbox/parser test data. It points to noisy local records without changing them."
        )
        MVPHandsOnDashboardStatus(store: store)
        LocalDemoWorkflowStatusCard(store: store)
        DashboardReleaseCandidateQACard(store: store)
        FirstLiveMailboxTestCard(store: store)
        spaceMailParserQAPanel
        spaceMailFollowUpPanel
        dailyOperatorStart

        VStack(alignment: .leading, spacing: 6) {
          Text("Detailed local analytics")
            .font(.title2.bold())
          Text("Broader local record summaries remain available below for deeper review.")
            .foregroundStyle(.secondary)
        }

        AnalyticsSection(title: "Operations", symbol: "shippingbox.fill") {
          LazyVGrid(columns: metricColumns, spacing: 12) {
            NavigationLink {
              OrdersView(store: store)
            } label: {
              MetricCard(title: "Active", value: "\(store.activeCount)", symbol: "shippingbox.fill", color: .teal)
            }
            .buttonStyle(.plain)

            NavigationLink {
              OrdersView(store: store)
            } label: {
              MetricCard(title: "Delivered", value: "\(store.deliveredCount)", symbol: "checkmark.circle.fill", color: .green)
            }
            .buttonStyle(.plain)

            NavigationLink {
              OrdersView(store: store)
            } label: {
              MetricCard(title: "Orders review", value: "\(store.reviewOrders.count)", symbol: "checkmark.shield.fill", color: .orange)
            }
            .buttonStyle(.plain)

            NavigationLink {
              OrdersView(store: store)
            } label: {
              MetricCard(title: "Total orders", value: "\(store.orders.count)", symbol: "tray.full.fill", color: .blue)
            }
            .buttonStyle(.plain)
          }
        }

        LazyVGrid(columns: sectionColumns, alignment: .leading, spacing: 14) {
          AnalyticsSection(title: "Operations Workbench", symbol: "rectangle.stack.badge.person.crop.fill") {
            MetricStrip(items: [
              ("Open", "\(operatorWorkbenchItems.count)", .blue),
              ("Overdue", "\(overdueOperatorWorkbenchItems.count)", overdueOperatorWorkbenchItems.isEmpty ? .green : .red),
              ("Blocked", "\(blockedOperatorWorkbenchItems.count)", blockedOperatorWorkbenchItems.isEmpty ? .green : .red),
              ("Review", "\(operatorWorkbenchReviewItems.count)", operatorWorkbenchReviewItems.isEmpty ? .green : .orange)
            ])
            CompactWorkbenchList(items: Array(highPriorityOperatorWorkbenchItems.prefix(4)), store: store)
          }

          AnalyticsSection(title: "Review workload", symbol: "exclamationmark.triangle.fill") {
            MetricStrip(items: [
              ("Queue", "\(store.reviewQueueCount)", .orange),
              ("Intake", "\(store.reviewIntakeEmails.count)", .blue),
              ("Evidence", "\(store.reviewEvidenceAttachments.count)", .purple),
              ("Watchlist", "\(store.timelineWatchlist.count)", .red)
            ])
            CompactIntakeList(emails: store.newestIntakeEmails, store: store)
          }

          AnalyticsSection(title: "Tracking health", symbol: "location.fill.viewfinder") {
            MetricStrip(items: [
              ("Warnings", "\(store.trackingWarningCount)", .orange),
              ("Critical", "\(store.criticalTrackingCount)", .red),
              ("Events", "\(store.carrierTrackingEvents.count)", .blue)
            ])
            CompactTrackingList(events: store.highestRiskTrackingEvents, orders: store.orders, store: store)
          }

          AnalyticsSection(title: "Evidence", symbol: "paperclip") {
            MetricStrip(items: [
              ("Total", "\(store.evidenceAttachments.count)", .blue),
              ("Needs review", "\(store.reviewEvidenceAttachments.count)", .orange)
            ])
            CompactEvidenceList(attachments: Array(store.evidenceAttachments.prefix(4)), store: store)
          }

          AnalyticsSection(title: "Automation", symbol: "arrow.triangle.branch") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledAutomationRuleCount)", .green),
              ("Disabled", "\(store.disabledAutomationRuleCount)", .gray),
              ("Rules", "\(store.automationRules.count)", .teal)
            ])
            CompactAutomationList(rules: Array(store.automationRules.prefix(4)), store: store)
          }

          AnalyticsSection(title: "Tasks", symbol: "checklist") {
            MetricStrip(items: [
              ("Open", "\(store.openReviewTasks.count)", .blue),
              ("Attention", "\(store.reviewTasksNeedingAttention.count)", .orange),
              ("SpaceMail", "\(spaceMailAssignedFollowUpCount)", spaceMailAssignedFollowUpCount == 0 ? .green : .purple),
              ("Total", "\(store.reviewTasks.count)", .teal)
            ])
            CompactSpaceMailDashboardFollowUp(
              tasks: Array(openSpaceMailAssignedTasks.prefix(2)),
              handoffs: Array(openSpaceMailAssignedHandoffs.prefix(2)),
              store: store
            )
            CompactTaskList(tasks: Array(store.reviewTasksNeedingAttention.prefix(4)), store: store)
          }

          AnalyticsSection(title: "Handoff notes", symbol: "arrow.left.arrow.right.square.fill") {
            MetricStrip(items: [
              ("Open", "\(store.openHandoffNotes.count)", .blue),
              ("Attention", "\(store.handoffNotesNeedingAttention.count)", .orange),
              ("Overdue", "\(store.overdueHandoffNotes.count)", .red),
              ("High", "\(store.highPriorityHandoffNotes.count)", .red)
            ])
            CompactHandoffNoteList(notes: Array(store.handoffNotesNeedingAttention.prefix(4)), store: store)
          }

          AnalyticsSection(title: "SLA policies", symbol: "timer") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledSLAPolicyCount)", .green),
              ("Disabled", "\(store.disabledSLAPolicyCount)", .gray),
              ("Review", "\(store.policiesNeedingReview.count)", .orange),
              ("Overdue", "\(store.overdueOpenReviewTasks.count)", .red)
            ])
            CompactSLAPolicyList(policies: store.recentPolicyMatches, store: store)
          }

          AnalyticsSection(title: "Exception playbooks", symbol: "book.closed.fill") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledPlaybookCount)", .green),
              ("Disabled", "\(store.disabledPlaybookCount)", .gray),
              ("Review", "\(store.playbooksNeedingReview.count)", .orange),
              ("High", "\(store.enabledHighPriorityPlaybooks.count)", .red)
            ])
            CompactExceptionPlaybookList(playbooks: Array((store.playbooksNeedingReview + store.enabledHighPriorityPlaybooks).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Drafts & Templates", symbol: "bubble.left.and.text.bubble.right.fill") {
            MetricStrip(items: [
              ("Templates", "\(store.enabledCommunicationTemplateCount)", .green),
              ("Disabled", "\(store.disabledCommunicationTemplateCount)", .gray),
              ("Drafts", "\(store.draftMessages.count)", .blue),
              ("Review", "\(store.draftMessagesNeedingReview.count)", .orange)
            ])
            CompactDraftMessageList(drafts: Array(store.draftMessagesNeedingReview.prefix(4)), store: store)
          }

          AnalyticsSection(title: "Contacts", symbol: "person.crop.circle.badge.checkmark") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledContactCount)", .green),
              ("Disabled", "\(store.disabledContactCount)", .gray),
              ("Review", "\(store.contactsNeedingReview.count)", .orange),
              ("Total", "\(store.contactDirectoryEntries.count)", .blue)
            ])
            CompactContactList(contacts: Array(store.contactsNeedingReview.prefix(4)), store: store)
          }

          AnalyticsSection(title: "Customer profiles", symbol: "person.text.rectangle.fill") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledCustomerProfileCount)", .green),
              ("Disabled", "\(store.disabledCustomerProfileCount)", .gray),
              ("Review", "\(store.customerProfilesNeedingReview.count)", .orange),
              ("Total", "\(store.customerRecipientProfiles.count)", .blue)
            ])
            CompactCustomerProfileList(profiles: Array((store.customerProfilesNeedingReview + store.customerRecipientProfiles.filter { !$0.isEnabled }).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Destination addresses", symbol: "mappin.and.ellipse") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledDestinationAddressCount)", .green),
              ("Disabled", "\(store.disabledDestinationAddressCount)", .gray),
              ("Review", "\(store.destinationAddressesNeedingReview.count)", .orange),
              ("High risk", "\(store.highRiskDestinationAddresses.count)", .red)
            ])
            CompactDestinationAddressList(addresses: Array((store.destinationAddressesNeedingReview + store.highRiskDestinationAddresses + store.destinationAddresses.filter { !$0.isEnabled }).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Delivery instructions", symbol: "signpost.right.and.left.fill") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledDeliveryInstructionCount)", .green),
              ("Disabled", "\(store.disabledDeliveryInstructionCount)", .gray),
              ("Review", "\(store.deliveryInstructionsNeedingReview.count)", .orange),
              ("Access", "\(store.deliveryInstructionsWithAccessConstraints.count)", .red)
            ])
            CompactDeliveryInstructionList(instructions: Array((store.deliveryInstructionsNeedingReview + store.highRiskDeliveryInstructions + store.deliveryInstructions.filter { !$0.isEnabled }).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Package contents", symbol: "shippingbox.circle.fill") {
            MetricStrip(items: [
              ("Unverified", "\(store.unverifiedPackageContents.count)", .orange),
              ("Discrepancy", "\(store.packageContentDiscrepancies.count)", .red),
              ("High risk", "\(store.highRiskPackageContents.count)", .red),
              ("High value", "\(store.highValuePackageContents.count)", .purple)
            ])
            CompactPackageContentList(contents: Array((store.packageContentsNeedingReview + store.unverifiedPackageContents + store.packageContentDiscrepancies + store.highRiskPackageContents + store.highValuePackageContents).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Costs & budgets", symbol: "creditcard.and.123") {
            MetricStrip(items: [
              ("Review", "\(store.costRecordsNeedingReview.count)", .orange),
              ("Disputed", "\(store.disputedCostRecords.count)", .red),
              ("Unreimbursed", "\(store.unreimbursedCostRecords.count)", .orange),
              ("Missing budget", "\(store.missingBudgetCodeCostRecords.count)", .red)
            ])
            CompactCostRecordList(costs: Array((store.costRecordsNeedingReview + store.disputedCostRecords + store.unreimbursedCostRecords + store.unapprovedCostRecords + store.highRiskCostRecords + store.missingBudgetCodeCostRecords).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Returns & claims", symbol: "arrow.uturn.backward.square.fill") {
            MetricStrip(items: [
              ("Review", "\(store.returnClaimsNeedingReview.count)", .orange),
              ("Disputed", "\(store.disputedReturnClaims.count)", .red),
              ("Unresolved", "\(store.unresolvedReturnClaims.count)", .orange),
              ("Missing evidence", "\(store.returnClaimsMissingEvidence.count)", .red)
            ])
            CompactReturnClaimList(claims: Array((store.returnClaimsNeedingReview + store.disputedReturnClaims + store.unresolvedReturnClaims + store.overdueReturnClaims + store.highRiskReturnClaims + store.returnClaimsMissingEvidence).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Procurement", symbol: "cart.badge.plus") {
            MetricStrip(items: [
              ("Review", "\(store.procurementRequestsNeedingReview.count)", .orange),
              ("Unapproved", "\(store.unapprovedProcurementRequests.count)", .orange),
              ("Rejected", "\(store.rejectedProcurementRequests.count)", .red),
              ("Missing budget", "\(store.missingBudgetCodeProcurementRequests.count)", .red)
            ])
            CompactProcurementRequestList(requests: Array((store.procurementRequestsNeedingReview + store.unapprovedProcurementRequests + store.rejectedProcurementRequests + store.notYetOrderedProcurementRequests + store.overdueProcurementRequests + store.highRiskProcurementRequests + store.missingBudgetCodeProcurementRequests).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Receiving inspections", symbol: "checklist.checked") {
            MetricStrip(items: [
              ("Review", "\(store.receivingInspectionsNeedingReview.count)", .orange),
              ("Blocked", "\(store.blockedReceivingInspections.count)", .purple),
              ("Discrepancies", "\(store.unresolvedInspectionDiscrepancies.count)", .red),
              ("Qty mismatch", "\(store.quantityMismatchReceivingInspections.count)", .orange)
            ])
            CompactReceivingInspectionList(inspections: Array((store.receivingInspectionsNeedingReview + store.blockedReceivingInspections + store.unresolvedInspectionDiscrepancies + store.highRiskReceivingInspections + store.overdueReceivingInspections + store.quantityMismatchReceivingInspections).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Inventory receipts", symbol: "archivebox.fill") {
            MetricStrip(items: [
              ("Review", "\(store.inventoryReceiptsNeedingReview.count)", .orange),
              ("Rejected", "\(store.rejectedInventoryReceipts.count)", .red),
              ("Partial", "\(store.partiallyAcceptedInventoryReceipts.count)", .orange),
              ("Missing storage", "\(store.inventoryReceiptsMissingStorage.count)", .red)
            ])
            CompactInventoryReceiptList(receipts: Array((store.inventoryReceiptsNeedingReview + store.rejectedInventoryReceipts + store.partiallyAcceptedInventoryReceipts + store.highRiskInventoryReceipts + store.unassignedInventoryReceipts + store.inventoryReceiptsMissingStorage).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Storage locations", symbol: "cabinet.fill") {
            MetricStrip(items: [
              ("Review", "\(store.storageLocationsNeedingReview.count)", .orange),
              ("Disabled", "\(store.disabledStorageLocations.count)", .gray),
              ("Missing code", "\(store.storageLocationsMissingCodes.count)", .red),
              ("Capacity", "\(store.storageLocationsWithCapacityWarnings.count)", .red)
            ])
            CompactStorageLocationList(locations: Array((store.storageLocationsNeedingReview + store.disabledStorageLocations + store.highRiskStorageLocations + store.storageLocationsMissingCodes + store.storageLocationsWithAccessNotes + store.storageLocationsWithCapacityWarnings).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Custody chain", symbol: "person.badge.shield.checkmark.fill") {
            MetricStrip(items: [
              ("Review", "\(store.custodyRecordsNeedingReview.count)", .orange),
              ("Disputed", "\(store.disputedCustodyRecords.count)", .red),
              ("Open", "\(store.openCustodyTransfers.count)", .blue),
              ("Missing", "\(store.custodyRecordsMissingCustodians.count + store.custodyRecordsMissingLocations.count)", .red)
            ])
            CompactCustodyRecordList(records: Array((store.custodyRecordsNeedingReview + store.disputedCustodyRecords + store.openCustodyTransfers + store.overdueCustodyRecords + store.highRiskCustodyRecords + store.custodyRecordsMissingCustodians + store.custodyRecordsMissingLocations).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Label references", symbol: "barcode.viewfinder") {
            MetricStrip(items: [
              ("Review", "\(store.labelReferencesNeedingReview.count)", .orange),
              ("Invalid", "\(store.invalidLabelReferences.count)", .red),
              ("Unverified", "\(store.unverifiedLabelReferences.count)", .blue),
              ("Missing", "\(store.labelReferencesMissingValues.count + store.labelReferencesMissingLinkedRecords.count)", .red)
            ])
            CompactLabelReferenceList(records: Array((store.labelReferencesNeedingReview + store.invalidLabelReferences + store.unverifiedLabelReferences + store.highRiskLabelReferences + store.labelReferencesMissingValues + store.labelReferencesMissingLinkedRecords).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Scan sessions", symbol: "qrcode.viewfinder") {
            MetricStrip(items: [
              ("Review", "\(store.scanSessionsNeedingReview.count)", .orange),
              ("Mismatch", "\(store.mismatchScanSessions.count)", .red),
              ("Incomplete", "\(store.incompleteScanSessions.count)", .blue),
              ("Missing", "\(store.scanSessionsMissingCapturedValues.count + store.scanSessionsMissingLabelReferences.count)", .red)
            ])
            CompactScanSessionList(records: Array((store.scanSessionsNeedingReview + store.mismatchScanSessions + store.incompleteScanSessions + store.highRiskScanSessions + store.scanSessionsMissingCapturedValues + store.scanSessionsMissingLabelReferences).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Shipment manifests", symbol: "list.bullet.clipboard.fill") {
            MetricStrip(items: [
              ("Review", "\(store.shipmentManifestsNeedingReview.count)", .orange),
              ("Blocked", "\(store.blockedShipmentManifests.count)", .red),
              ("Undispatched", "\(store.undispatchedShipmentManifests.count)", .blue),
              ("Missing", "\(store.shipmentManifestsMissingIncludedOrders.count + store.shipmentManifestsMissingHandoffLocation.count)", .red)
            ])
            CompactShipmentManifestList(records: Array((store.shipmentManifestsNeedingReview + store.blockedShipmentManifests + store.undispatchedShipmentManifests + store.highRiskShipmentManifests + store.shipmentManifestsMissingIncludedOrders + store.shipmentManifestsMissingHandoffLocation + store.shipmentManifestsWithIncompleteScans).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Dispatch readiness", symbol: "checkmark.rectangle.stack.fill") {
            MetricStrip(items: [
              ("Review", "\(store.dispatchChecklistsNeedingReview.count)", .orange),
              ("Blocked", "\(store.blockedDispatchChecklists.count)", .red),
              ("Incomplete", "\(store.incompleteDispatchChecklists.count)", .blue),
              ("Missing", "\(store.dispatchChecklistsMissingRequirements.count)", .red)
            ])
            CompactDispatchReadinessList(checklists: Array((store.dispatchChecklistsNeedingReview + store.blockedDispatchChecklists + store.incompleteDispatchChecklists + store.highRiskDispatchChecklists + store.dispatchChecklistsMissingRequirements + store.dispatchChecklistsLinkedToBlockedManifests).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Accounts", symbol: "key.horizontal.fill") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledAccountRecordCount)", .green),
              ("Disabled", "\(store.disabledAccountRecordCount)", .gray),
              ("Review", "\(store.accountRecordsNeedingReview.count)", .orange),
              ("Total", "\(store.accountCredentialRecords.count)", .blue)
            ])
            CompactAccountList(accounts: Array(store.accountRecordsNeedingReview.prefix(4)), store: store)
          }

          AnalyticsSection(title: "Vendor profiles", symbol: "building.2.crop.circle.fill") {
            MetricStrip(items: [
              ("Enabled", "\(store.enabledVendorProfileCount)", .green),
              ("Disabled", "\(store.disabledVendorProfileCount)", .gray),
              ("Review", "\(store.vendorProfilesNeedingReview.count)", .orange),
              ("High risk", "\(store.highRiskEnabledVendorProfiles.count)", .red)
            ])
            CompactVendorProfileList(profiles: Array((store.vendorProfilesNeedingReview + store.highRiskEnabledVendorProfiles).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Shipment groups", symbol: "shippingbox.and.arrow.backward.fill") {
            MetricStrip(items: [
              ("Total", "\(store.shipmentGroups.count)", .blue),
              ("Review", "\(store.shipmentGroupsNeedingReview.count)", .orange),
              ("High risk", "\(store.highRiskShipmentGroups.count)", .red),
              ("Critical", "\(store.shipmentGroups.filter { $0.riskLevel == .critical }.count)", .red)
            ])
            CompactShipmentGroupList(groups: Array((store.shipmentGroupsNeedingReview + store.highRiskShipmentGroups).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Import queue", symbol: "tray.and.arrow.down.fill") {
            MetricStrip(items: [
              ("Total", "\(store.importQueueItems.count)", .blue),
              ("Review", "\(store.importQueueItemsNeedingReview.count)", .orange),
              ("Low conf", "\(store.lowConfidenceImportQueueItems.count)", .orange),
              ("Blocked", "\(store.blockedImportQueueItems.count)", .red)
            ])
            CompactImportQueueList(items: Array((store.blockedImportQueueItems + store.lowConfidenceImportQueueItems + store.importQueueItemsNeedingReview).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Acceptance review", symbol: "checkmark.rectangle.stack.fill") {
            MetricStrip(items: [
              ("Ready", "\(store.acceptanceCandidates.filter { $0.decision == .ready }.count)", .blue),
              ("Accepted", "\(store.acceptedAcceptanceRecords.count)", .green),
              ("Blocked", "\(store.blockedAcceptanceRecords.count)", .red),
              ("Reopened", "\(store.reopenedAcceptanceRecords.count)", .orange)
            ])
            CompactAcceptanceList(records: Array((store.blockedAcceptanceRecords + store.reopenedAcceptanceRecords + store.ignoredAcceptanceRecords + store.acceptanceRecordsNeedingReview).prefix(4)), store: store)
          }

          AnalyticsSection(title: "Reconciliation", symbol: "arrow.triangle.2.circlepath.circle.fill") {
            MetricStrip(items: [
              ("Unresolved", "\(store.unresolvedReconciliationIssues.count)", .orange),
              ("High", "\(store.highSeverityReconciliationIssues.count)", .red),
              ("Conflicts", "\(store.reconciliationIssues.filter { $0.issueType == .orderNumberConflict || $0.issueType == .trackingNumberConflict || $0.issueType == .destinationConflict }.count)", .purple),
              ("Total", "\(store.reconciliationIssues.count)", .blue)
            ])
            CompactReconciliationIssueList(issues: Array(store.unresolvedReconciliationIssues.prefix(4)), store: store)
          }

          AnalyticsSection(title: "Timeline", symbol: "clock.badge.exclamationmark.fill") {
            MetricStrip(items: [
              ("Recent", "\(store.recentTimelineActivities.count)", .blue),
              ("Watchlist", "\(store.timelineWatchlist.count)", .red),
              ("Critical", "\(store.timelineWatchlist.filter { $0.risk == .critical }.count)", .red),
              ("High", "\(store.timelineWatchlist.filter { $0.risk == .high }.count)", .orange)
            ])
            CompactTimelineList(activities: store.recentTimelineActivities, store: store)
          }

          AnalyticsSection(title: "Validation health", symbol: "checkmark.seal.fill") {
            MetricStrip(items: [
              ("Health", "\(store.validationHealthScore)%", store.validationHealthScore >= 80 ? .green : .orange),
              ("High", "\(store.highSeverityValidationIssues.count)", .red),
              ("Low conf", "\(store.lowConfidenceValidationCount)", .orange),
              ("Duplicates", "\(store.duplicateValidationCount)", .purple)
            ])
            CompactValidationIssueList(issues: Array(store.validationIssues.prefix(4)), store: store)
          }
        }

        AnalyticsSection(title: "Recent activity", symbol: "list.clipboard.fill") {
          CompactAuditList(events: store.recentAuditEvents, store: store)
        }
      }
      .padding(isCompact ? 14 : 24)
    }
    .background(.regularMaterial)
  }

  private var dailyFlowCheckpointPanel: some View {
    SettingsPanel(title: "Daily flow checkpoints", symbol: "map.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: dailyFlowClearCount == dailyFlowCheckpointItems.count ? "checkmark.seal.fill" : "arrow.triangle.branch")
            .font(.title3)
            .foregroundStyle(dailyFlowClearCount == dailyFlowCheckpointItems.count ? .green : .orange)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text("Follow the primary queue from setup to audit")
              .font(.headline)
            Text("This summarizes the daily operator path without exposing every supporting record type as the starting point.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer(minLength: 8)
          Badge("\(dailyFlowClearCount)/\(dailyFlowCheckpointItems.count)", color: dailyFlowClearCount == dailyFlowCheckpointItems.count ? .green : .orange)
        }

        LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 160 : 215), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(dailyFlowCheckpointItems, id: \.title) { item in
            VStack(alignment: .leading, spacing: 8) {
              HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(item.title, systemImage: item.symbol)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(item.color)
                Spacer()
                Badge(item.title == "Audit" ? "\(item.count)" : (item.count == 0 ? "Clear" : "\(item.count)"), color: item.color)
              }

              Text(item.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

              Text("Open \(item.destination)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(item.color)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(item.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }

        Text("Local boundary: this is a read-only summary of existing local queues and audit history. It does not fetch mail, create orders, mutate mailbox messages, send notifications, or call external services.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Daily operations")
          .font(isCompact ? .title.bold() : .largeTitle.bold())
        Text("Start here, then move through Inbox, Orders, Workbench, Dispatch, Tasks, and Audit.")
          .foregroundStyle(.secondary)
      }
      CompactActionRow {
        Button("Create manual order", systemImage: "plus") {
          store.createManualOrderPlaceholder()
          feedbackMessage = "Manual order placeholder created locally. Open Orders to confirm customer, destination, tracking, and dispatch setup."
        }
          .buttonStyle(.borderedProminent)
        Button("Import clear order test email", systemImage: "checklist.checked") {
          store.importClearOrderIntakeTestMessage()
          feedbackMessage = "Clear local order test email imported. Open Inbox to review the detected order and tracking number, then create or link an order."
        }
          .buttonStyle(.bordered)
          .help("Imports one clear local order/tracking test email through the provider-neutral intake path.")
        Button("Seed demo workflow", systemImage: "wand.and.stars") {
          store.seedLocalInboxOrderDemoWorkflow()
          feedbackMessage = "Local demo workflow seeded. Check Inbox, Orders, Dispatch, Tasks, and Audit for the linked handoff trail."
        }
          .buttonStyle(.bordered)
          .help("Creates a local intake email, linked order, dispatch setup, and follow-up task without contacting external services.")
        Button("Import sample mail batch", systemImage: "tray.and.arrow.down.fill") {
          store.syncSources()
          feedbackMessage = "Local sample mailbox batch imported through the same intake path used for manual testing. No external mailbox was contacted."
        }
          .buttonStyle(.bordered)
          .help("Imports simulated mailbox messages through local intake only.")
      }
      if let feedbackMessage {
        DashboardActionFeedbackPanel(message: feedbackMessage)
      }
    }
  }

  private var dailyStartDecisionPanel: some View {
    SettingsPanel(title: "Start here", symbol: "arrow.forward.circle.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: dailyStartTone == .green ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            .font(.title3)
            .foregroundStyle(dailyStartTone)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text(dailyStartTitle)
              .font(.headline)
            Text(dailyStartDetail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        MetricStrip(items: [
          ("Setup", hasSpaceMailSetup ? "Set" : "Needed", hasSpaceMailSetup ? .green : .orange),
          ("Credential", hasSpaceMailCredentialReference ? "Keychain" : "Needed", hasSpaceMailCredentialReference ? .green : .orange),
          ("Refresh", hasSpaceMailManualRefreshEvidence ? "Seen" : "Needed", hasSpaceMailManualRefreshEvidence ? .green : .orange),
          ("Inbox", "\(incomingAttentionCount)", incomingAttentionCount == 0 ? .green : .orange),
          ("Orders", "\(problemOrdersCount)", problemOrdersCount == 0 ? .green : .red),
          ("Workbench", "\(store.highPriorityWorkbenchItems.count)", store.highPriorityWorkbenchItems.isEmpty ? .green : .purple),
          ("Dispatch", "\(dispatchAttentionCount)", dispatchAttentionCount == 0 ? .green : .blue),
          ("Reopened", "\(reopenedInboxDispatchHandoffCount)", reopenedInboxDispatchHandoffCount == 0 ? .green : .purple),
          ("Tasks", "\(taskAttentionCount)", taskAttentionCount == 0 ? .green : .orange)
        ])

        CompactActionRow {
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Open Inbox", systemImage: "tray.full.fill")
          }
          NavigationLink {
            OrdersView(store: store)
          } label: {
            Label("Open Orders", systemImage: "shippingbox.fill")
          }
          NavigationLink {
            OperationsWorkbenchView(store: store)
          } label: {
            Label("Open Workbench", systemImage: "rectangle.stack.badge.person.crop.fill")
          }
          NavigationLink {
            SettingsView(store: store)
          } label: {
            Label("Open Settings", systemImage: "gearshape.fill")
          }
          NavigationLink {
            DispatchView(store: store)
          } label: {
            Label("Open Dispatch", systemImage: "paperplane.fill")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private var inboxTriageQualityPanel: some View {
    SettingsPanel(title: "Inbox triage quality", symbol: "text.magnifyingglass") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: inboxTriageQualityTone == .green ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .font(.title3)
            .foregroundStyle(inboxTriageQualityTone)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text(inboxTriageQualityTitle)
              .font(.headline)
            Text(inboxTriageQualityDetail)
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
          ("Import/accept", "\(readyAcceptanceOrImportCount)", readyAcceptanceOrImportCount == 0 ? .secondary : .blue),
          ("Parser checks", "\(store.intakeParserDiagnostics.count)", store.intakeParserDiagnostics.isEmpty ? .green : .purple)
        ])

        Text("This is a local summary only. It does not fetch mail or change records; it mirrors the grouped Inbox queue so weak parser results do not look equally ready as clean intake.")
          .font(.caption2)
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
            Label("Open Mailbox Monitor", systemImage: "server.rack")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private var liveMailboxStatusPanel: some View {
    SettingsPanel(title: "Live mailbox status", symbol: "server.rack") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: latestSpaceMailTone == .green ? "checkmark.seal.fill" : "tray.and.arrow.down.fill")
            .font(.title3)
            .foregroundStyle(latestSpaceMailTone)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text(latestSpaceMailTitle)
              .font(.headline)
            Text(latestSpaceMailDetail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer()
          Badge(latestSpaceMailSummary?.lastRefreshDate ?? "No refresh", color: latestSpaceMailTone)
        }

        MetricStrip(items: [
          ("Fetched", "\(latestSpaceMailSummary?.fetchedCount ?? 0)", (latestSpaceMailSummary?.fetchedCount ?? 0) > 0 ? .blue : .secondary),
          ("Imported", "\(latestSpaceMailSummary?.importedCount ?? 0)", (latestSpaceMailSummary?.importedCount ?? 0) > 0 ? .green : .secondary),
          ("Duplicates", "\(latestSpaceMailSummary?.duplicateCount ?? 0)", (latestSpaceMailSummary?.duplicateCount ?? 0) > 0 ? .teal : .secondary),
          ("Filtered", "\(latestSpaceMailSummary?.filteredCount ?? 0)", (latestSpaceMailSummary?.filteredCount ?? 0) > 0 ? .teal : .secondary),
          ("Uncertain", "\((latestSpaceMailSummary?.pendingUncertainReviewCount ?? 0) + (latestSpaceMailSummary?.uncertainCount ?? 0))", ((latestSpaceMailSummary?.pendingUncertainReviewCount ?? 0) + (latestSpaceMailSummary?.uncertainCount ?? 0)) > 0 ? .orange : .secondary),
          ("Parser", "\(latestSpaceMailSummary?.parserIssueCount ?? store.intakeParserDiagnostics.count)", (latestSpaceMailSummary?.parserIssueCount ?? store.intakeParserDiagnostics.count) > 0 ? .orange : .green)
        ])

        VStack(alignment: .leading, spacing: 8) {
          HStack(alignment: .top, spacing: 12) {
            Image(systemName: "envelope.badge.shield.half.filled")
              .font(.title3)
              .foregroundStyle(latestGmailTone)
              .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
              Text(latestGmailTitle)
                .font(.subheadline.weight(.semibold))
              Text(latestGmailDetail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
            Badge(latestGmailSummary?.lastRefreshDate ?? "No Gmail refresh", color: latestGmailTone)
          }

          MetricStrip(items: [
            ("Gmail setup", "\(gmailSetupBlockerCount)", gmailSetupBlockerCount > 0 ? .orange : .green),
            ("Gmail fetched", "\(latestGmailSummary?.fetchedCount ?? 0)", (latestGmailSummary?.fetchedCount ?? 0) > 0 ? .blue : .secondary),
            ("Gmail imported", "\(latestGmailSummary?.importedCount ?? 0)", (latestGmailSummary?.importedCount ?? 0) > 0 ? .green : .secondary),
            ("Gmail filtered", "\(latestGmailSummary?.filteredCount ?? 0)", (latestGmailSummary?.filteredCount ?? 0) > 0 ? .teal : .secondary),
            ("Gmail review", "\(pendingGmailFilteredReviewCount)", pendingGmailFilteredReviewCount > 0 ? .teal : .secondary),
            ("Gmail uncertain", "\(pendingGmailUncertainReviewCount)", pendingGmailUncertainReviewCount > 0 ? .orange : .secondary)
          ])
          if pendingGmailFilteredReviewCount > 0 {
            Label("Filtered Gmail examples are not Inbox work unless an operator imports one from Mailbox Monitor or Needs Review.", systemImage: "line.3.horizontal.decrease.circle.fill")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.teal)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .padding(10)
        .background(latestGmailTone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        CompactSpaceMailActionPlan(plan: store.spaceMailPostRefreshActionPlan)
        GmailPostRefreshActionCard(plan: store.gmailPostRefreshActionPlan)

        DisclosureGroup {
          GmailOperationsRunbook()
            .padding(.top, 8)
        } label: {
          Label("Gmail operator runbook", systemImage: "envelope.badge.shield.half.filled")
            .font(.subheadline.weight(.semibold))
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))

        DisclosureGroup {
          SpaceMailOperationsRunbook()
            .padding(.top, 8)
        } label: {
          Label("SpaceMail operator runbook", systemImage: "list.bullet.clipboard.fill")
            .font(.subheadline.weight(.semibold))
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))

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

        Text("Manual read-only boundary: Dashboard only summarizes local refresh results. It does not start IMAP, read passwords, mutate mailbox messages, send mail, call Shopify/carriers, schedule background work, or create notifications.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  @ViewBuilder
  private var spaceMailFollowUpPanel: some View {
    if spaceMailFollowUpNeedsDashboardAttention {
      SettingsPanel(title: "SpaceMail follow-up", symbol: "person.2.wave.2.fill") {
        VStack(alignment: .leading, spacing: 12) {
          Text("Assigned SpaceMail review tasks and handoffs should be worked from Tasks, while uncertain mixed-mailbox previews stay in Mailbox Monitor until an operator imports or dismisses them.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          MetricStrip(items: [
            ("Assigned", "\(spaceMailAssignedFollowUpCount)", spaceMailAssignedFollowUpCount == 0 ? .green : .purple),
            ("Tasks", "\(openSpaceMailAssignedTasks.count)", openSpaceMailAssignedTasks.isEmpty ? .green : .orange),
            ("Handoffs", "\(openSpaceMailAssignedHandoffs.count)", openSpaceMailAssignedHandoffs.isEmpty ? .green : .blue),
            ("Uncertain", "\(pendingSpaceMailUncertainCount)", pendingSpaceMailUncertainCount == 0 ? .green : .orange),
            ("Filtered", "\(pendingSpaceMailFilteredCount)", pendingSpaceMailFilteredCount == 0 ? .secondary : .teal)
          ])

          CompactSpaceMailDashboardFollowUp(
            tasks: Array(openSpaceMailAssignedTasks.prefix(3)),
            handoffs: Array(openSpaceMailAssignedHandoffs.prefix(3)),
            store: store
          )

          CompactActionRow {
            if spaceMailAssignedFollowUpCount > 0 {
              NavigationLink {
                TasksView(store: store)
              } label: {
                Label("Open Tasks", systemImage: "checklist")
              }
            }
            NavigationLink {
              MailboxView(store: store)
            } label: {
              Label(pendingSpaceMailUncertainCount > 0 ? "Review uncertain mail" : "Open Mailbox Monitor", systemImage: "server.rack")
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
  }

  @ViewBuilder
  private var spaceMailParserQAPanel: some View {
    if spaceMailParserQANeedsDashboardAttention {
      SettingsPanel(title: "SpaceMail parser QA", symbol: "text.magnifyingglass") {
        VStack(alignment: .leading, spacing: 12) {
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: spaceMailParserSuiteChecks.isEmpty ? "exclamationmark.magnifyingglass" : "exclamationmark.triangle.fill")
              .foregroundStyle(spaceMailParserQATone)
              .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
              Text(spaceMailParserQATitle)
                .font(.headline)
              Text(spaceMailParserQADetail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
            Badge(spaceMailParserSuiteChecks.isEmpty ? "Not run" : "Needs review", color: spaceMailParserQATone)
          }

          MetricStrip(items: [
            ("Checks", "\(spaceMailParserSuiteChecks.count)", spaceMailParserSuiteChecks.isEmpty ? .secondary : .blue),
            ("Passed", "\(spaceMailParserSuitePasses.count)", spaceMailParserSuiteFailures.isEmpty && !spaceMailParserSuiteChecks.isEmpty ? .green : .secondary),
            ("Failures", "\(spaceMailParserSuiteFailures.count)", spaceMailParserSuiteFailures.isEmpty ? .green : .orange),
            ("IDs", "\(spaceMailParserExtractedIDCount)", spaceMailParserExtractedIDCount == 0 ? .secondary : .blue)
          ])

          if !spaceMailParserSuiteFailures.isEmpty {
            CompactList(title: "Parser failures", symbol: "exclamationmark.triangle.fill") {
              ForEach(spaceMailParserSuiteFailures.prefix(3)) { result in
                NavigationLink {
                  MailboxView(store: store)
                } label: {
                  CompactRow(
                    title: result.sampleName,
                    detail: result.parserStatus,
                    badge: "Parser",
                    color: .orange
                  )
                }
                .buttonStyle(.plain)
              }
            }
          }

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
          }
          .buttonStyle(.bordered)
        }
      }
    }
  }

  private var dailyOperatorStart: some View {
    VStack(alignment: .leading, spacing: 16) {
      AnalyticsSection(title: "What needs attention now", symbol: "exclamationmark.triangle.fill") {
        OperatorDailyWorkloadSummary(
          dailyAttentionCount: attentionNowCount,
          advancedBacklogCount: advancedBacklogCount,
          reviewQueueCount: store.reviewQueueCount,
          detailWhenBusy: "Start with the cards below. The advanced backlog is still available, but it is not the first daily operating queue."
        )

        FilterControlGrid {
          TextField("Find daily work: Inbox, SpaceMail, orders, dispatch, tasks", text: $dashboardSearchText)
            .textFieldStyle(.roundedBorder)
          Badge("\(visibleDashboardMatchCount) daily areas", color: visibleDashboardMatchCount == 0 ? .orange : .blue)
          if !normalizedDashboardSearch.isEmpty {
            Button("Clear filter", systemImage: "xmark.circle") {
              dashboardSearchText = ""
            }
            .buttonStyle(.bordered)
          }
        }

        if visibleDashboardMatchCount == 0 {
          MVPEmptyState(
            title: "No daily areas match",
            detail: "Clear the Dashboard filter or try Inbox, SpaceMail, order, dispatch, task, workbench, or audit.",
            symbol: "magnifyingglass"
          )
        }

        LazyVGrid(columns: sectionColumns, alignment: .leading, spacing: 12) {
          if dashboardMatches("inbox", "mailbox", "spacemail", "email", "parser", "import", "acceptance", "triage", "intake") {
            OperatorDashboardCard(
              title: "Inbox",
              count: incomingAttentionCount,
              detail: "SpaceMail refresh results, imported order emails, uncertain mixed-mailbox messages, parser checks, and staged intake waiting for triage.",
              nextAction: incomingAttentionCount == 0 ? "Review SpaceMail status" : "Triage SpaceMail intake",
              symbol: "tray.full.fill",
              tint: incomingAttentionCount == 0 ? .green : .orange
            ) {
              InboxView(store: store)
            }
          }

          if dashboardMatches("orders", "order", "tracking", "customer", "destination", "inbox-created") {
            OperatorDashboardCard(
              title: "Orders",
              count: problemOrdersCount,
              detail: "Review-needed orders, exceptions, warning tracking events, and orders newly created from Inbox.",
              nextAction: partialInboxOrderBlockers.isEmpty ? (inboxCreatedOrders.isEmpty ? (problemOrdersCount == 0 ? "Orders look steady" : "Review problem orders") : "Review Inbox-created orders") : "Verify missing Inbox details",
              symbol: "shippingbox.fill",
              tint: partialInboxOrderBlockers.isEmpty ? (inboxCreatedOrders.isEmpty ? (problemOrdersCount == 0 ? .green : .red) : .purple) : .orange
            ) {
              OrdersView(store: store)
            }
          }

          if dashboardMatches("workbench", "exception", "validation", "reconciliation", "high-priority") {
            OperatorDashboardCard(
              title: "Workbench",
              count: store.highPriorityWorkbenchItems.count,
              detail: "Highest-priority local work from exceptions, validation, reconciliation, and follow-up records.",
              nextAction: store.highPriorityWorkbenchItems.isEmpty ? "No urgent workbench items" : "Open high-priority work",
              symbol: "rectangle.stack.badge.person.crop.fill",
              tint: store.highPriorityWorkbenchItems.isEmpty ? .green : .purple
            ) {
              OperationsWorkbenchView(store: store)
            }
          }

          if dashboardMatches("dispatch", "manifest", "readiness", "outbound", "handoff", "reopened") {
            OperatorDashboardCard(
              title: "Dispatch",
              count: dispatchAttentionCount,
              detail: "Blocked manifests, reopened handoffs, undispatched batches, incomplete checklists, and Inbox-created orders that need verification or dispatch setup.",
              nextAction: reopenedInboxDispatchHandoffCount > 0 ? "Review reopened handoffs" : partialInboxOrderBlockers.isEmpty ? (inboxDispatchGapOrders.isEmpty ? (dispatchAttentionCount == 0 ? "Dispatch queue is steady" : "Prepare outbound work") : "Add dispatch setup") : "Verify order details first",
              symbol: "shippingbox.and.arrow.backward.fill",
              tint: reopenedInboxDispatchHandoffCount > 0 ? .purple : partialInboxOrderBlockers.isEmpty ? (dispatchAttentionCount == 0 ? .green : .blue) : .orange
            ) {
              DispatchView(store: store)
            }
          }

          if dashboardMatches("tasks", "task", "handoff", "draft", "follow-up", "overdue") {
            OperatorDashboardCard(
              title: "Tasks",
              count: taskAttentionCount,
              detail: "Open review tasks, handoff notes, and draft messages that need ownership, completion, or local send status.",
              nextAction: taskAttentionCount == 0 ? "No task escalations" : "Work follow-ups and drafts",
              symbol: "checklist",
              tint: taskAttentionCount == 0 ? .green : .orange
            ) {
              TasksView(store: store)
            }
          }

          if dashboardMatches("settings", "setup", "placeholder", "shopify", "folder", "login", "local-only") {
            OperatorDashboardCard(
              title: "Settings",
              count: setupAttentionCount,
              detail: "Local setup placeholders that need review or cleanup before operators treat them as ready planning context.",
              nextAction: setupAttentionCount == 0 ? "Setup placeholders reviewed" : "Review local setup placeholders",
              symbol: "gearshape.2.fill",
              tint: setupAttentionCount == 0 ? .green : .teal
            ) {
              SettingsView(store: store)
            }
          }

          if dashboardMatches("audit", "activity", "history", "record change", "workflow") {
            OperatorDashboardCard(
              title: "Audit",
              count: store.recentAuditEvents.count,
              detail: "Recent local actions, record changes, reviews, creates, removes, tasks, and drafts.",
              nextAction: "Check recent activity",
              symbol: "list.clipboard.fill",
              tint: .teal
            ) {
              AuditView(store: store)
            }
          }
        }
      }

      LazyVGrid(columns: sectionColumns, alignment: .leading, spacing: 14) {
        if dashboardMatches("incoming order intake", "inbox", "mailbox", "spacemail", "parser", "import", "acceptance") {
          AnalyticsSection(title: "Incoming order intake", symbol: "tray.full.fill") {
            MetricStrip(items: [
              ("Triage", "\(incomingAttentionCount)", incomingAttentionCount == 0 ? .green : .orange),
              ("Emails", "\(store.reviewIntakeEmails.count)", .blue),
              ("Mailbox", "\(spaceMailHealthAttentionCount)", spaceMailHealthAttentionCount == 0 ? .green : .orange),
              ("Parser QA", spaceMailParserSuiteChecks.isEmpty ? "Not run" : "\(spaceMailParserSuitePasses.count)/\(spaceMailParserSuiteChecks.count)", spaceMailParserQATone),
              ("Imports", "\(store.importQueueItemsNeedingReview.count + store.blockedImportQueueItems.count)", .purple),
              ("Acceptance", "\(store.acceptanceRecordsNeedingReview.count)", .teal)
            ])
            SpaceMailPrimaryStatusStrip(store: store, showTitle: false)
            CompactSpaceMailActionPlan(plan: store.spaceMailPostRefreshActionPlan)
            GmailPostRefreshActionCard(plan: store.gmailPostRefreshActionPlan)
            GmailShiftHandoffCard(summary: store.gmailShiftHandoffSummary)
            SpaceMailRefreshTrendCard(summary: store.spaceMailRefreshTrendSummary)
            CompactSpaceMailHealthList(summaries: store.spaceMailIntakeHealthSummaries, store: store)
            CompactIntakeList(emails: store.newestIntakeEmails, store: store)
          }
        }

        if dashboardMatches("active problem orders", "orders", "tracking", "inbox-created", "source", "trail", "customer", "destination") {
          AnalyticsSection(title: "Active/problem orders", symbol: "shippingbox.fill") {
            MetricStrip(items: [
              ("Active", "\(store.activeCount)", .teal),
              ("Review", "\(store.reviewOrders.count)", .orange),
              ("From Inbox", "\(inboxCreatedOrders.count)", inboxCreatedOrders.isEmpty ? .green : .purple),
              ("Source trail", "\(inboxCreatedOrdersWithSourceTrail.count)", inboxCreatedOrdersMissingSourceTrail.isEmpty ? .green : .orange),
              ("Verify first", "\(partialInboxOrderBlockers.count)", partialInboxOrderBlockers.isEmpty ? .green : .orange),
              ("Tracking", "\(store.trackingWarningCount + store.criticalTrackingCount)", .red),
              ("Delivered", "\(store.deliveredCount)", .green)
            ])
            CompactInboxSourceTrailCoverage(
              total: inboxCreatedOrders.count,
              withSourceTrail: inboxCreatedOrdersWithSourceTrail.count,
              missingSourceTrailOrders: Array(inboxCreatedOrdersMissingSourceTrail.prefix(3)),
              store: store
            )
            CompactPartialInboxOrderList(orders: Array(partialInboxOrderBlockers.prefix(4)), store: store)
            CompactInboxCreatedOrderList(orders: Array(inboxCreatedOrders.prefix(3)), store: store)
            CompactOrderList(orders: Array((store.reviewOrders + store.orders.filter { $0.status == .exception || $0.status == .inTransit || $0.status == .shipped }).prefix(4)), store: store)
          }
        }

        if dashboardMatches("dispatch readiness", "dispatch", "manifest", "readiness", "blocked", "undispatched", "reopened") {
          AnalyticsSection(title: "Dispatch readiness", symbol: "shippingbox.and.arrow.backward.fill") {
            MetricStrip(items: [
              ("Blocked", "\(store.blockedShipmentManifests.count + store.blockedDispatchChecklists.count)", .red),
              ("Reopened", "\(reopenedInboxDispatchHandoffCount)", reopenedInboxDispatchHandoffCount == 0 ? .green : .purple),
              ("Verify first", "\(partialInboxOrderBlockers.count)", partialInboxOrderBlockers.isEmpty ? .green : .orange),
              ("Inbox gaps", "\(inboxDispatchGapOrders.count)", inboxDispatchGapOrders.isEmpty ? .green : .purple),
              ("Inbox setup", "\(inboxDispatchSetupPendingOrders.count)", inboxDispatchSetupPendingOrders.isEmpty ? .green : .teal),
              ("Undispatched", "\(store.undispatchedShipmentManifests.count)", .blue),
              ("Incomplete", "\(store.incompleteDispatchChecklists.count)", .orange),
              ("Review", "\(store.shipmentManifestsNeedingReview.count + store.dispatchChecklistsNeedingReview.count)", .purple)
            ])
            CompactPartialInboxOrderList(orders: Array(partialInboxOrderBlockers.prefix(4)), store: store)
            CompactReopenedInboxDispatchHandoffList(manifests: Array(reopenedInboxDispatchManifests.prefix(3)), checklists: Array(reopenedInboxDispatchChecklists.prefix(3)), store: store)
            CompactInboxDispatchGapList(orders: Array(inboxDispatchGapOrders.prefix(4)), store: store)
            CompactInboxDispatchSetupList(orders: Array(inboxDispatchSetupPendingOrders.prefix(4)), store: store)
            CompactShipmentManifestList(records: Array((store.blockedShipmentManifests + store.undispatchedShipmentManifests + store.highRiskShipmentManifests).prefix(4)), store: store)
          }
        }

        if dashboardMatches("open tasks handoffs drafts", "tasks", "handoff", "draft", "overdue", "high") {
          AnalyticsSection(title: "Open tasks, handoffs, and drafts", symbol: "checklist") {
            MetricStrip(items: [
              ("Tasks", "\(store.reviewTasksNeedingAttention.count)", .orange),
              ("Handoffs", "\(store.handoffNotesNeedingAttention.count)", .blue),
              ("Drafts", "\(store.draftMessagesNeedingReview.count)", store.draftMessagesNeedingReview.isEmpty ? .green : .purple),
              ("Overdue", "\(store.overdueOpenReviewTasks.count + store.overdueHandoffNotes.count)", .red),
              ("High", "\(store.highPriorityHandoffNotes.count + store.reviewTasks.filter { $0.priority == .high || $0.priority == .urgent }.count)", .red)
            ])
            CompactTaskList(tasks: Array(store.reviewTasksNeedingAttention.prefix(3)), store: store)
            CompactHandoffNoteList(notes: Array(store.handoffNotesNeedingAttention.prefix(3)), store: store)
            CompactDraftMessageList(drafts: Array(store.draftMessagesNeedingReview.prefix(3)), store: store)
          }
        }
      }

      if dashboardMatches("recent local activity", "audit", "activity", "recent", "history") {
        AnalyticsSection(title: "Recent local activity", symbol: "list.clipboard.fill") {
          if store.recentAuditEvents.isEmpty {
            MVPEmptyState(title: "No recent local activity", detail: "Create, edit, review, accept, dispatch, or complete a local record and it will appear here.", symbol: "list.clipboard.fill")
          } else {
            CompactAuditList(events: store.recentAuditEvents, store: store)
          }
        }
      }
    }
  }

  private func dashboardMatches(_ terms: String...) -> Bool {
    let query = normalizedDashboardSearch
    guard !query.isEmpty else { return true }
    return terms.contains { $0.localizedLowercase.contains(query) }
  }

  private func hasPartialInboxOrderTask(_ order: TrackedOrder) -> Bool {
    store.tasks(for: .order, linkedEntityID: order.id.uuidString).contains { task in
      task.status != .completed && task.isPartialInboxOrderFollowUp
    }
  }

  private func hasInboxSourceTrail(_ order: TrackedOrder) -> Bool {
    !linkedIntakeEmails(for: order).isEmpty
      || !store.importQueueItems(for: order).isEmpty
      || !store.acceptanceRecords(for: order).isEmpty
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
}

private struct DashboardActionFeedbackPanel: View {
  var message: String

  var body: some View {
    Label {
      Text(message)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    } icon: {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct CompactInboxSourceTrailCoverage: View {
  var total: Int
  var withSourceTrail: Int
  var missingSourceTrailOrders: [TrackedOrder]
  var store: ParcelOpsStore

  private var missingCount: Int { max(total - withSourceTrail, 0) }
  private var coverageLabel: String {
    guard total > 0 else { return "No Inbox-created orders yet" }
    return "\(withSourceTrail) of \(total) Inbox-created orders have a local source trail"
  }

  var body: some View {
    CompactList(title: "Inbox source trail coverage", symbol: "link.badge.plus") {
      CompactRow(
        title: coverageLabel,
        detail: missingCount == 0
          ? "Inbox-created orders are traceable back to intake, import, or acceptance context."
          : "\(missingCount) Inbox-created order needs source context linked or reviewed before relying on the handoff.",
        badge: missingCount == 0 ? "Covered" : "\(missingCount) gap",
        color: missingCount == 0 ? .green : .orange
      )

      ForEach(missingSourceTrailOrders) { order in
        DashboardOrderCompactLink(order: order, store: store) {
          CompactRow(
            title: "\(order.store) • \(order.orderNumber)",
            detail: "No linked intake, import, or acceptance source found yet. Open the order to confirm the handoff trail.",
            badge: "Trace",
            color: .orange
          )
        }
      }
    }
  }
}

private struct OperatorDashboardCard<Destination: View>: View {
  var title: String
  var count: Int
  var detail: String
  var nextAction: String
  var symbol: String
  var tint: Color
  @ViewBuilder var destination: Destination
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }

  var body: some View {
    NavigationLink {
      destination
    } label: {
      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: symbol)
            .foregroundStyle(tint)
            .frame(width: 26)
          VStack(alignment: .leading, spacing: 3) {
            Text(title)
              .font(.headline)
            Text(detail)
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 8)
          Text("\(count)")
            .font(.title2.bold())
            .foregroundStyle(tint)
        }

        Label(nextAction, systemImage: "arrow.right.circle.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(tint)
          .lineLimit(isCompact ? 2 : 1)
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

struct MVPReadinessCallout: View {
  var store: ParcelOpsStore

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "checklist")
          .foregroundStyle(.teal)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text("Local readiness")
            .font(.headline)
          Text("ParcelOps is local-only right now. Use it for order intake, exception review, dispatch preparation, tasks, and audit before connecting live services.")
            .foregroundStyle(.secondary)
        }
        Spacer()
        Badge("Local prototype", color: .orange)
      }

      MetricStrip(items: [
        ("Review queue", "\(store.reviewQueueCount)", .orange),
        ("Open work", "\(store.openWorkbenchItems.count)", .blue),
        ("Manifests", "\(store.shipmentManifestRecords.count)", .purple),
        ("Readiness", "\(store.dispatchReadinessChecklists.count)", .teal)
      ])

      SpaceMailMVPReadinessCard(summary: store.liveMailboxMVPReadinessSummary, showChecklist: false)
      SpaceMailQACheckCard(summary: store.liveMailboxQACheckSummary)
    }
    .padding(16)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct MVPHandsOnDashboardStatus: View {
  var store: ParcelOpsStore

  private var clearIntakeCount: Int {
    store.reviewIntakeEmails.filter { email in
      !email.detectedOrderNumber.isPlaceholderValidationValue
        && !email.detectedTrackingNumber.isPlaceholderValidationValue
    }.count
  }

  private var inboxCreatedOrdersCount: Int {
    store.orders.filter { order in
      order.source == .forwardedMailbox || order.checkedMailbox == "manual-import" || order.isInboxCreatedLocalOrder
    }.count
  }

  private var hasManualRefresh: Bool {
    store.spaceMailIMAPConnections.contains { $0.lastManualRefreshDate != "Never" }
  }

  private var blockedDailyCount: Int {
    store.blockedWorkbenchItems.count + store.blockedShipmentManifests.count + store.blockedDispatchChecklists.count
  }

  private var tone: Color {
    if clearIntakeCount == 0 && inboxCreatedOrdersCount == 0 { return .orange }
    if blockedDailyCount > 0 { return .red }
    if !hasManualRefresh { return .teal }
    return .green
  }

  private var title: String {
    if clearIntakeCount == 0 && inboxCreatedOrdersCount == 0 { return "Seed one clear Inbox test email" }
    if inboxCreatedOrdersCount == 0 { return "Create or link one intake order" }
    if blockedDailyCount > 0 { return "Resolve blocked daily work" }
    if !hasManualRefresh { return "Local workflow ready; live refresh optional" }
    return "Hands-on workflow is ready"
  }

  private var detail: String {
    if clearIntakeCount == 0 && inboxCreatedOrdersCount == 0 {
      return "Use the local clear order test email to verify Inbox parsing, then create or link one order. This avoids depending on SpaceMail while testing the core flow."
    }
    if inboxCreatedOrdersCount == 0 {
      return "Use Inbox to review detected fields and create or link one order so the Dashboard, Orders, Workbench, Tasks, and Audit trail can be verified."
    }
    if blockedDailyCount > 0 {
      return "\(blockedDailyCount) blocked work item needs review before this is ready for regular hands-on use."
    }
    if !hasManualRefresh {
      return "The local Inbox-to-Orders flow has enough test data. Run SpaceMail refresh later when you want to verify the live mailbox path."
    }
    return "Use MVP Setup for the full checklist, then quit and reopen the app to confirm local JSON persistence."
  }

  var body: some View {
    SettingsPanel(title: "Hands-on test status", symbol: "checklist.checked") {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: tone == .green ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
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
        Badge(tone == .green ? "Ready" : "Check", color: tone)
      }

      MetricStrip(items: [
        ("SpaceMail runs", "\(store.spaceMailIMAPConnections.filter { $0.lastManualRefreshDate != "Never" }.count)", hasManualRefresh ? .green : .orange),
        ("Clear intake", "\(clearIntakeCount)", clearIntakeCount == 0 ? .orange : .green),
        ("Inbox orders", "\(inboxCreatedOrdersCount)", inboxCreatedOrdersCount == 0 ? .orange : .green),
        ("Blocked", "\(blockedDailyCount)", blockedDailyCount == 0 ? .green : .red),
        ("Audit", "\(store.auditEvents.count)", store.auditEvents.isEmpty ? .orange : .purple)
      ])

      CompactActionRow {
        Button("Import clear order test email", systemImage: "checklist.checked") {
          store.importClearOrderIntakeTestMessage()
        }
        .buttonStyle(.borderedProminent)

        Button("Seed demo workflow", systemImage: "wand.and.stars") {
          store.seedLocalInboxOrderDemoWorkflow()
        }
        .buttonStyle(.bordered)

        NavigationLink {
          InboxView(store: store)
        } label: {
          Label("Open Inbox", systemImage: "tray.full.fill")
        }
        .buttonStyle(.bordered)

        NavigationLink {
          OrdersView(store: store)
        } label: {
          Label("Open Orders", systemImage: "shippingbox.fill")
        }
        .buttonStyle(.bordered)
      }

      Text("This card is local-only. It does not trigger refresh, background sync, mailbox mutation, Shopify, carrier APIs, OCR, scanners, notifications, or outbound email.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

private struct LocalDemoWorkflowStatusCard: View {
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

  private var manifestCount: Int {
    latestDemoOrder.map { store.suggestedShipmentManifestRecords(for: $0).count } ?? 0
  }

  private var completedManifestCount: Int {
    latestDemoOrder.map { order in
      store.suggestedShipmentManifestRecords(for: order).filter { $0.dispatchStatus == .handedOff }.count
    } ?? 0
  }

  private var checklistCount: Int {
    latestDemoOrder.map { store.suggestedDispatchReadinessChecklists(for: $0).count } ?? 0
  }

  private var completedChecklistCount: Int {
    latestDemoOrder.map { order in
      store.suggestedDispatchReadinessChecklists(for: order).filter { $0.checklistStatus == .completed }.count
    } ?? 0
  }

  private var openTaskCount: Int {
    guard let order = latestDemoOrder else { return 0 }
    return store.reviewTasks.filter {
      $0.linkedEntityType == .order
        && $0.linkedEntityID == order.id.uuidString
        && $0.status != .completed
    }.count
  }

  private var auditCount: Int {
    guard let order = latestDemoOrder else { return 0 }
    return store.auditEvents.filter {
      $0.entityID == order.id.uuidString
        || $0.entityLabel.localizedCaseInsensitiveContains(order.orderNumber)
        || $0.afterDetail?.localizedCaseInsensitiveContains(order.orderNumber) == true
    }.count
  }

  private var completedCount: Int {
    [
      latestDemoOrder != nil,
      linkedIntakeCount > 0,
      manifestCount > 0 && checklistCount > 0,
      completedManifestCount > 0 && completedChecklistCount > 0,
      auditCount > 0
    ].filter { $0 }.count
  }

  private var tone: Color {
    if latestDemoOrder == nil { return .orange }
    if completedCount >= 5 { return .green }
    return .teal
  }

  private var title: String {
    guard let order = latestDemoOrder else { return "No local demo workflow seeded yet" }
    return "Latest demo workflow: \(order.orderNumber)"
  }

  private var detail: String {
    guard let order = latestDemoOrder else {
      return "Seed a local demo workflow to create a clear intake email, linked order, dispatch setup, follow-up task, and audit trail without relying on SpaceMail."
    }
    return "\(order.store) • \(order.trackingNumber) • \(order.destination). Use this as the known-good path when testing Inbox, Orders, Dispatch, Tasks, and Audit."
  }

  private var canCompleteHandoff: Bool {
    latestDemoOrder != nil
      && manifestCount > 0
      && checklistCount > 0
      && (completedManifestCount < manifestCount || completedChecklistCount < checklistCount)
  }

  private var canReopenHandoff: Bool {
    latestDemoOrder != nil
      && completedManifestCount > 0
      && completedChecklistCount > 0
  }

  var body: some View {
    SettingsPanel(title: "Local demo workflow", symbol: "wand.and.stars") {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: latestDemoOrder == nil ? "wand.and.stars" : "checkmark.seal.fill")
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
        Badge("\(completedCount)/5", color: tone)
      }

      MetricStrip(items: [
        ("Order", latestDemoOrder == nil ? "Missing" : "Ready", latestDemoOrder == nil ? .orange : .green),
        ("Inbox link", "\(linkedIntakeCount)", linkedIntakeCount == 0 ? .orange : .green),
        ("Dispatch", "\(manifestCount + checklistCount)", manifestCount + checklistCount == 0 ? .orange : .purple),
        ("Completed", "\(completedManifestCount + completedChecklistCount)", completedManifestCount + completedChecklistCount == 0 ? .secondary : .green),
        ("Open tasks", "\(openTaskCount)", openTaskCount == 0 ? .green : .orange),
        ("Audit", "\(auditCount)", auditCount == 0 ? .orange : .purple)
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
          InboxView(store: store)
        } label: {
          Label("Inbox", systemImage: "tray.full.fill")
        }
        .buttonStyle(.bordered)

        NavigationLink {
          OrdersView(store: store)
        } label: {
          Label("Orders", systemImage: "shippingbox.fill")
        }
        .buttonStyle(.bordered)

        NavigationLink {
          DispatchView(store: store)
        } label: {
          Label("Dispatch", systemImage: "paperplane.fill")
        }
        .buttonStyle(.bordered)

        NavigationLink {
          AuditView(store: store)
        } label: {
          Label("Audit", systemImage: "list.clipboard.fill")
        }
        .buttonStyle(.bordered)
      }

      Text("This demo status only reads local JSON-backed records. It does not contact mailboxes, mutate mailbox messages, call carrier or Shopify APIs, send messages, schedule jobs, or store credentials.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

private struct DashboardReleaseCandidateQACard: View {
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

  private var liveMailboxEvidenceReady: Bool {
    store.spaceMailIntakeHealthSummaries.contains { summary in
      summary.fetchedCount > 0 || summary.importedCount > 0 || summary.filteredCount > 0 || summary.duplicateCount > 0 || summary.uncertainCount > 0
    }
  }

  private var checkpoints: [(title: String, detail: String, symbol: String, color: Color, isComplete: Bool, required: Bool)] {
    [
      (
        "Seed demo order",
        latestDemoOrder == nil ? "Seed the local demo workflow before hands-on QA." : "\(latestDemoOrder?.orderNumber ?? "Demo order") is available.",
        "wand.and.stars",
        latestDemoOrder == nil ? .orange : .green,
        latestDemoOrder != nil,
        true
      ),
      (
        "Inbox source linked",
        linkedIntakeCount == 0 ? "The demo order needs a linked intake source." : "\(linkedIntakeCount) intake source is linked.",
        "link.badge.plus",
        linkedIntakeCount == 0 ? .orange : .green,
        linkedIntakeCount > 0,
        true
      ),
      (
        "Dispatch setup exists",
        dispatchSetupCount == 0 ? "Manifest and readiness records need local setup." : "\(dispatchSetupCount) dispatch setup records are linked.",
        "paperplane.fill",
        dispatchSetupCount == 0 ? .orange : .purple,
        dispatchSetupCount > 0,
        true
      ),
      (
        "Handoff can close",
        completedDispatchCount == 0 ? "Complete the local dispatch handoff before final QA." : "\(completedDispatchCount) dispatch records are completed.",
        "checkmark.rectangle.stack.fill",
        completedDispatchCount == 0 ? .teal : .green,
        completedDispatchCount > 0,
        true
      ),
      (
        "Audit trail exists",
        demoAuditCount == 0 ? "Audit should show the local demo order trail." : "\(demoAuditCount) audit entries reference the demo order.",
        "list.clipboard.fill",
        demoAuditCount == 0 ? .orange : .purple,
        demoAuditCount > 0,
        true
      ),
      (
        "Persistence evidence",
        persistenceEvidenceReady ? "Local JSON-backed intake, order, and audit records exist." : "Create local records, quit, reopen, and confirm they remain visible.",
        "internaldrive.fill",
        persistenceEvidenceReady ? .green : .orange,
        persistenceEvidenceReady,
        true
      ),
      (
        "Live SpaceMail evidence",
        liveMailboxEvidenceReady ? "A real or diagnostic SpaceMail refresh result exists." : "Optional: live mailbox evidence is useful but should not block local QA.",
        "server.rack",
        liveMailboxEvidenceReady ? .green : .secondary,
        liveMailboxEvidenceReady,
        false
      )
    ]
  }

  private var requiredCheckpoints: [(title: String, detail: String, symbol: String, color: Color, isComplete: Bool, required: Bool)] {
    checkpoints.filter(\.required)
  }

  private var completedRequiredCount: Int {
    requiredCheckpoints.filter(\.isComplete).count
  }

  private var tone: Color {
    completedRequiredCount == requiredCheckpoints.count ? .green : completedRequiredCount >= 4 ? .teal : .orange
  }

  private var title: String {
    if completedRequiredCount == requiredCheckpoints.count { return "Release-candidate path is ready to test" }
    if latestDemoOrder == nil { return "Release-candidate path needs a demo seed" }
    return "Release-candidate path needs final checks"
  }

  private var detail: String {
    if completedRequiredCount == requiredCheckpoints.count {
      return "The Dashboard has enough local evidence for a hands-on pass through Inbox, Orders, Dispatch, Tasks, Audit, and persistence."
    }
    return "Use this compact checklist before asking someone to test the app. Live SpaceMail evidence is optional; the local demo path is the stable baseline."
  }

  private var canCompleteHandoff: Bool {
    latestDemoOrder != nil && dispatchSetupCount > 0 && completedDispatchCount == 0
  }

  var body: some View {
    SettingsPanel(title: "Release-candidate checkpoint", symbol: "checkmark.seal.fill") {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: completedRequiredCount == requiredCheckpoints.count ? "checkmark.seal.fill" : "checklist")
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
        Badge("\(completedRequiredCount)/\(requiredCheckpoints.count)", color: tone)
      }

      MetricStrip(items: [
        ("Demo", latestDemoOrder == nil ? "No" : "Yes", latestDemoOrder == nil ? .orange : .green),
        ("Inbox link", "\(linkedIntakeCount)", linkedIntakeCount == 0 ? .orange : .green),
        ("Dispatch", "\(dispatchSetupCount)", dispatchSetupCount == 0 ? .orange : .purple),
        ("Closed", "\(completedDispatchCount)", completedDispatchCount == 0 ? .secondary : .green),
        ("Audit", "\(demoAuditCount)", demoAuditCount == 0 ? .orange : .purple),
        ("Live mail", liveMailboxEvidenceReady ? "Seen" : "Optional", liveMailboxEvidenceReady ? .green : .secondary)
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
        }

        NavigationLink { MVPSetupView(store: store) } label: { Label("Full QA", systemImage: "checklist.checked") }
          .buttonStyle(.bordered)
        NavigationLink { DispatchView(store: store) } label: { Label("Dispatch", systemImage: "paperplane.fill") }
          .buttonStyle(.bordered)
        NavigationLink { AuditView(store: store) } label: { Label("Audit", systemImage: "list.clipboard.fill") }
          .buttonStyle(.bordered)
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 10)], alignment: .leading, spacing: 10) {
        ForEach(Array(checkpoints.enumerated()), id: \.offset) { _, item in
          MVPHandsOnReleaseChecklistRow(title: item.title, detail: item.detail, symbol: item.symbol, color: item.color, isComplete: item.isComplete)
        }
      }

      Text("This checkpoint only reads local state or runs explicit local demo actions. It does not refresh mail, mutate mailboxes, send messages, call Shopify or carriers, create notifications, or run background work.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

struct FirstLiveMailboxTestCard: View {
  var store: ParcelOpsStore

  private var hasSpaceMailSetup: Bool {
    !store.spaceMailIMAPConnections.isEmpty
  }

  private var hasGmailSetup: Bool {
    !store.gmailMailboxConnections.isEmpty
  }

  private var hasSpaceMailCredential: Bool {
    store.spaceMailIMAPConnections.contains {
      $0.credentialStorageStatus.localizedCaseInsensitiveContains("available")
        || $0.credentialStorageStatus.localizedCaseInsensitiveContains("ready")
    }
  }

  private var hasGmailConnectedAuth: Bool {
    store.gmailMailboxConnections.contains { connection in
      store.gmailAuthSessionState(for: connection).status == .connected
    }
  }

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.spaceMailIntakeHealthSummaries.first
  }

  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.gmailIntakeHealthSummaries.first
  }

  private var hasMailboxSetup: Bool {
    hasSpaceMailSetup || hasGmailSetup
  }

  private var hasMailboxCredentialOrAuth: Bool {
    (hasSpaceMailSetup && hasSpaceMailCredential) || (hasGmailSetup && hasGmailConnectedAuth)
  }

  private var fetchedCount: Int {
    (latestSpaceMailSummary?.fetchedCount ?? 0) + (latestGmailSummary?.fetchedCount ?? 0)
  }

  private var importedCount: Int {
    (latestSpaceMailSummary?.importedCount ?? 0) + (latestGmailSummary?.importedCount ?? 0)
  }

  private var filteredCount: Int {
    (latestSpaceMailSummary?.filteredCount ?? 0) + (latestGmailSummary?.filteredCount ?? 0)
  }

  private var duplicateCount: Int {
    (latestSpaceMailSummary?.duplicateCount ?? 0) + (latestGmailSummary?.duplicateCount ?? 0)
  }

  private var hasRealRefresh: Bool {
    store.spaceMailIMAPConnections.contains { $0.lastManualRefreshDate != "Never" }
      || store.gmailMailboxConnections.contains { $0.lastManualRefreshDate != "Never" }
      || (latestSpaceMailSummary?.fetchedCount ?? 0) > 0
      || (latestGmailSummary?.fetchedCount ?? 0) > 0
  }

  private var hasImportEvidence: Bool {
    (latestSpaceMailSummary?.importedCount ?? 0) > 0
      || (latestGmailSummary?.importedCount ?? 0) > 0
      || store.intakeEmails.contains { email in
        let source = store.intakeSourceSummary(for: email)
        return source.label.localizedCaseInsensitiveContains("SpaceMail")
          || source.label.localizedCaseInsensitiveContains("Gmail")
      }
  }

  private var pendingUncertainCount: Int {
    (latestSpaceMailSummary?.pendingUncertainReviewCount ?? latestSpaceMailSummary?.uncertainCount ?? 0)
      + (latestGmailSummary?.pendingUncertainReviewCount ?? latestGmailSummary?.uncertainCount ?? 0)
  }

  private var hasRefreshOutcome: Bool {
    hasRealRefresh
      && (
        fetchedCount > 0
          || importedCount > 0
          || filteredCount > 0
          || duplicateCount > 0
          || pendingUncertainCount > 0
      )
  }

  private var hasActionableIntake: Bool {
    hasImportEvidence || pendingUncertainCount > 0
  }

  private var hasOnlyNonOrderOutcome: Bool {
    hasRefreshOutcome && !hasActionableIntake
  }

  private var hasInboxOrder: Bool {
    store.orders.contains { order in
      order.isInboxCreatedLocalOrder || order.source == .forwardedMailbox || order.checkedMailbox == "manual-import"
    }
  }

  private var hasMailboxAudit: Bool {
    store.recentAuditEvents.contains { event in
      event.summary.localizedCaseInsensitiveContains("SpaceMail")
        || event.summary.localizedCaseInsensitiveContains("Gmail")
        || event.entityLabel.localizedCaseInsensitiveContains("SpaceMail")
        || event.entityLabel.localizedCaseInsensitiveContains("Gmail")
        || event.afterDetail?.localizedCaseInsensitiveContains("SpaceMail") == true
        || event.afterDetail?.localizedCaseInsensitiveContains("Gmail") == true
    }
  }

  private var completedCount: Int {
    checklistItems.filter(\.isComplete).count
  }

  private var statusTitle: String {
    if !hasMailboxSetup { return "First live mailbox test: setup needed" }
    if !hasMailboxCredentialOrAuth { return "First live mailbox test: credential or sign-in needed" }
    if !hasRealRefresh { return "First live mailbox test: run refresh" }
    if hasOnlyNonOrderOutcome { return "First live mailbox test: no order mail found" }
    if pendingUncertainCount > 0 && !hasImportEvidence { return "First live mailbox test: review uncertain mail" }
    if !hasRefreshOutcome { return "First live mailbox test: review results" }
    if !hasInboxOrder { return "First live mailbox test: create or link order" }
    if !hasMailboxAudit { return "First live mailbox test: confirm Audit" }
    return "First live mailbox test: ready to repeat"
  }

  private var statusDetail: String {
    if !hasMailboxSetup {
      return "Open Mailbox Monitor or Settings and confirm a SpaceMail IMAP setup or Gmail setup for the mailbox you want to test."
    }
    if !hasMailboxCredentialOrAuth {
      return "Set/check the SpaceMail Keychain credential or complete Gmail sign-in. Do not place passwords, tokens, or app secrets in notes or JSON-backed fields."
    }
    if !hasRealRefresh {
      return "Run the explicit real SpaceMail or Gmail refresh. It is manual and read-only."
    }
    if hasOnlyNonOrderOutcome {
      return "The mixed-mailbox filter ran and kept non-order mail out of Inbox. Send or forward one clear order/tracking test email when you want to verify order creation."
    }
    if pendingUncertainCount > 0 && !hasImportEvidence {
      return "Open Mailbox Monitor and import only the uncertain messages that clearly relate to an order."
    }
    if !hasRefreshOutcome {
      return "Review the latest fetched, duplicate, filtered, and uncertain counts before changing Inbox records."
    }
    if !hasInboxOrder {
      return "Use Inbox to import, reprocess, create, or link one order from confirmed intake."
    }
    if !hasMailboxAudit {
      return "Use Audit to confirm the refresh, Inbox, and order handoff events are traceable."
    }
    return "The core mailbox to Inbox to Orders loop has enough local evidence for hands-on testing."
  }

  private var statusColor: Color {
    completedCount == checklistItems.count ? .green : completedCount >= 3 ? .teal : .orange
  }

  private var checklistItems: [FirstLiveMailboxTestItem] {
    [
      FirstLiveMailboxTestItem(
        title: "Confirm setup",
        detail: "SpaceMail IMAP or Gmail setup exists with the non-secret mailbox settings needed for manual refresh.",
        symbol: "mail.stack.fill",
        isComplete: hasMailboxSetup
      ),
      FirstLiveMailboxTestItem(
        title: "Check credential or sign-in",
        detail: "SpaceMail has a Keychain password reference or Gmail has connected sign-in; no secret is stored in JSON.",
        symbol: "lock.shield.fill",
        isComplete: hasMailboxCredentialOrAuth
      ),
      FirstLiveMailboxTestItem(
        title: "Run refresh",
        detail: "Manual read-only refresh has run; fetched count and filter outcome are visible.",
        symbol: "arrow.clockwise",
        isComplete: hasRealRefresh
      ),
      FirstLiveMailboxTestItem(
        title: "Review intake",
        detail: "Imported, uncertain, filtered, or duplicate SpaceMail/Gmail results are visible enough to explain the refresh outcome.",
        symbol: "tray.full.fill",
        isComplete: hasRefreshOutcome
      ),
      FirstLiveMailboxTestItem(
        title: hasOnlyNonOrderOutcome ? "Wait for order mail" : "Create order",
        detail: hasOnlyNonOrderOutcome ? "No likely order email was imported. Use a clear order/tracking test email before expecting an Inbox-created order." : "At least one confirmed intake row has become a local order or linked order.",
        symbol: "shippingbox.fill",
        isComplete: hasInboxOrder
      ),
      FirstLiveMailboxTestItem(
        title: "Verify audit",
        detail: "Recent Audit history includes mailbox refresh or Inbox handoff evidence.",
        symbol: "list.clipboard.fill",
        isComplete: hasMailboxAudit
      )
    ]
  }

  var body: some View {
    SettingsPanel(title: "First live mailbox test", symbol: "checklist.checked") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: completedCount == checklistItems.count ? "checkmark.seal.fill" : "play.circle.fill")
            .foregroundStyle(statusColor)
            .frame(width: 24)

          VStack(alignment: .leading, spacing: 4) {
            Text(statusTitle)
              .font(.headline)
            Text(statusDetail)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer()
          Badge("\(completedCount)/\(checklistItems.count)", color: statusColor)
        }

        MetricStrip(items: [
          ("Fetched", "\(fetchedCount)", fetchedCount > 0 ? .blue : .secondary),
          ("Imported", "\(importedCount)", importedCount > 0 ? .green : .secondary),
          ("Filtered", "\(filteredCount)", filteredCount > 0 ? .teal : .secondary),
          ("Uncertain", "\(pendingUncertainCount)", pendingUncertainCount > 0 ? .orange : .secondary)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(checklistItems) { item in
            FirstLiveMailboxTestStep(item: item)
          }
        }

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
          NavigationLink { MailboxView(store: store) } label: { Label("Mailbox Monitor", systemImage: "server.rack") }
          NavigationLink { InboxView(store: store) } label: { Label("Inbox", systemImage: "tray.full.fill") }
          NavigationLink { OrdersView(store: store) } label: { Label("Orders", systemImage: "shippingbox.fill") }
          NavigationLink { AuditView(store: store) } label: { Label("Audit", systemImage: "list.clipboard.fill") }
        }
        .buttonStyle(.bordered)

        Text("This checklist is manual and read-only. It does not start background sync, mutate mailbox messages, call Shopify or carriers, send email, scan files, trigger notifications, or store mailbox passwords in JSON.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

private struct FirstLiveMailboxTestItem: Identifiable {
  var id: String { title }
  var title: String
  var detail: String
  var symbol: String
  var isComplete: Bool
}

private struct FirstLiveMailboxTestStep: View {
  var item: FirstLiveMailboxTestItem

  var body: some View {
    HStack(alignment: .top, spacing: 9) {
      Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
        .foregroundStyle(item.isComplete ? .green : .secondary)
        .frame(width: 20)

      VStack(alignment: .leading, spacing: 3) {
        Text(item.title)
          .font(.caption.weight(.semibold))
        Text(item.detail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background((item.isComplete ? Color.green : Color.secondary).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct AnalyticsSection<Content: View>: View {
  var title: String
  var symbol: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label(title, systemImage: symbol)
        .font(.headline)
      content
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
  }
}

struct MetricCard: View {
  var title: String
  var value: String
  var symbol: String
  var color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Image(systemName: symbol)
        .foregroundStyle(color)
      Text(value)
        .font(.system(size: 34, weight: .bold, design: .rounded))
      Text(title)
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct MetricStrip: View {
  var items: [(String, String, Color)]
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }
  private var columns: [GridItem] {
    if isCompact {
      return [GridItem(.adaptive(minimum: 116), spacing: 8)]
    }
    return Array(repeating: GridItem(.flexible()), count: max(items.count, 1))
  }

  var body: some View {
    LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
      ForEach(items, id: \.0) { item in
        VStack(alignment: .leading, spacing: 4) {
          Text(item.1)
            .font(.title3.bold())
            .foregroundStyle(item.2)
          Text(item.0)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
      }
    }
  }
}

struct CompactIntakeList: View {
  var emails: [ForwardedEmailIntake]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Newest intake", symbol: "envelope.open.fill") {
      ForEach(emails) { email in
        let source = store.intakeSourceSummary(for: email)
        NavigationLink {
          MailboxView(store: store)
        } label: {
          CompactRow(
            title: email.detectedOrderNumber,
            detail: "\(source.label) • \(email.detectedMerchant) • \(email.subject)",
            badge: email.reviewState.rawValue,
            color: email.reviewState.color,
            secondaryBadge: source.status,
            secondaryColor: source.status == MailboxIngestStatus.imported.rawValue ? .green : .orange
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactSpaceMailHealthList: View {
  var summaries: [SpaceMailIntakeHealthSummary]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Mailbox intake health", symbol: "server.rack") {
      if summaries.isEmpty {
        NavigationLink {
          MailboxView(store: store)
        } label: {
          CompactRow(
            title: "No SpaceMail mailbox",
            detail: "Add a SpaceMail setup when you are ready to use real IMAP intake.",
            badge: "Setup",
            color: .secondary
          )
        }
        .buttonStyle(.plain)
      } else {
        ForEach(summaries.prefix(3)) { summary in
          NavigationLink {
            MailboxView(store: store)
          } label: {
            CompactRow(
              title: summary.verdict,
              detail: "\(summary.displayName) • \(summary.nextAction)",
              badge: "\(summary.importedCount) in / \(summary.filteredCount) filtered",
              color: color(for: summary)
            )
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private func color(for summary: SpaceMailIntakeHealthSummary) -> Color {
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
}

struct CompactSpaceMailActionPlan: View {
  var plan: SpaceMailPostRefreshActionPlan

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "arrow.triangle.branch")
          .foregroundStyle(color(for: plan.tone))
          .frame(width: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(plan.title)
            .font(.subheadline.weight(.semibold))
          Text(plan.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Text("Next: \(plan.primaryAction)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(color(for: plan.tone))
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge("SpaceMail", color: color(for: plan.tone))
      }

      CompactMetadataGrid(minimumWidth: 150) {
        ForEach(plan.items) { item in
          Label("\(item.title): \(item.count)", systemImage: item.symbol)
            .font(.caption)
            .foregroundStyle(color(for: item.tone))
            .lineLimit(2)
        }
      }

      Text("Use Mailbox Monitor for uncertain or filtered message review; use Inbox for imported order emails.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color(for: plan.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
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
}

private func dashboardOrderTimelineSignalCount(for order: TrackedOrder, store: ParcelOpsStore) -> Int {
  let taskCount = store.tasks(for: .order, linkedEntityID: order.id.uuidString).count
  let manifestCount = store.suggestedShipmentManifestRecords(for: order).count
  let checklistCount = store.suggestedDispatchReadinessChecklists(for: order).count
  let warningTrackingCount = store.trackingEvents(for: order.id).filter { event in
    event.severity == .watch || event.severity == .critical
  }.count

  return 1
    + (order.isInboxCreatedLocalOrder ? 1 : 0)
    + taskCount
    + manifestCount
    + checklistCount
    + warningTrackingCount
}

private func dashboardOrderTimelineDetail(for order: TrackedOrder, store: ParcelOpsStore) -> String {
  let taskCount = store.tasks(for: .order, linkedEntityID: order.id.uuidString).count
  let manifestCount = store.suggestedShipmentManifestRecords(for: order).count
  let checklistCount = store.suggestedDispatchReadinessChecklists(for: order).count
  let warningTrackingCount = store.trackingEvents(for: order.id).filter { event in
    event.severity == .watch || event.severity == .critical
  }.count

  if order.isInboxCreatedLocalOrder && (manifestCount + checklistCount) > 0 {
    return "Inbox handoff linked to dispatch setup • \(order.trackingNumber)"
  }
  if order.isInboxCreatedLocalOrder {
    return "Inbox-created order needs local follow-up • \(order.trackingNumber)"
  }
  if taskCount > 0 {
    return "\(taskCount) linked task signal • \(order.customer)"
  }
  if (manifestCount + checklistCount) > 0 {
    return "Linked dispatch context • \(order.carrier) • \(order.trackingNumber)"
  }
  if warningTrackingCount > 0 {
    return "\(warningTrackingCount) tracking warning signal • \(order.carrier)"
  }
  return "\(order.customer) • \(order.carrier) • \(order.trackingNumber)"
}

struct CompactOrderList: View {
  var orders: [TrackedOrder]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Active/problem orders", symbol: "shippingbox.fill") {
      if orders.isEmpty {
        CompactRow(
          title: "No problem orders",
          detail: "Active and review-needed orders will appear here.",
          badge: "Clear",
          color: .green
        )
      } else {
        ForEach(orders) { order in
          let timelineCount = dashboardOrderTimelineSignalCount(for: order, store: store)
          DashboardOrderCompactLink(order: order, store: store) {
            CompactRow(
              title: "\(order.store) • \(order.orderNumber)",
              detail: dashboardOrderTimelineDetail(for: order, store: store),
              badge: timelineCount > 1 ? "\(timelineCount) timeline" : order.status.rawValue,
              color: timelineCount > 1 ? .blue : order.status.color
            )
          }
        }
      }
    }
  }
}

struct CompactInboxCreatedOrderList: View {
  var orders: [TrackedOrder]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Inbox-created orders", symbol: "tray.and.arrow.down.fill") {
      if orders.isEmpty {
        CompactRow(
          title: "No Inbox-created orders waiting",
          detail: "Orders created from Inbox triage will appear here for quick follow-up.",
          badge: "Clear",
          color: .green
        )
      } else {
        ForEach(orders) { order in
          let timelineCount = dashboardOrderTimelineSignalCount(for: order, store: store)
          DashboardOrderCompactLink(order: order, store: store) {
            CompactRow(
              title: "\(order.store) • \(order.orderNumber)",
              detail: dashboardOrderTimelineDetail(for: order, store: store),
              badge: timelineCount > 1 ? "\(timelineCount) timeline" : order.reviewState.rawValue,
              color: timelineCount > 1 ? .purple : order.reviewState.color
            )
          }
        }
      }
    }
  }
}

struct CompactPartialInboxOrderList: View {
  var orders: [TrackedOrder]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Verify before dispatch", symbol: "exclamationmark.triangle.fill") {
      if orders.isEmpty {
        CompactRow(
          title: "No partial Inbox order blockers",
          detail: "Inbox-created orders have no promoted missing-detail blocker.",
          badge: "Clear",
          color: .green
        )
      } else {
        ForEach(orders) { order in
          let timelineCount = dashboardOrderTimelineSignalCount(for: order, store: store)
          DashboardOrderCompactLink(order: order, store: store) {
            CompactRow(
              title: "\(order.store) • \(order.orderNumber)",
              detail: "\(dashboardOrderTimelineDetail(for: order, store: store)) • \(order.destination)",
              badge: timelineCount > 1 ? "\(timelineCount) timeline" : "\(order.missingInboxOrderFieldCount) missing",
              color: .orange
            )
          }
        }
      }
    }
  }
}

struct CompactInboxDispatchGapList: View {
  var orders: [TrackedOrder]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Inbox orders missing dispatch setup", symbol: "tray.and.arrow.down.fill") {
      if orders.isEmpty {
        CompactRow(
          title: "No Inbox dispatch gaps",
          detail: "Reviewed or active Inbox-created orders have no promoted dispatch setup gap.",
          badge: "Clear",
          color: .green
        )
      } else {
        ForEach(orders) { order in
          let timelineCount = dashboardOrderTimelineSignalCount(for: order, store: store)
          DashboardOrderCompactLink(order: order, store: store) {
            CompactRow(
              title: "\(order.store) • \(order.orderNumber)",
              detail: dashboardOrderTimelineDetail(for: order, store: store),
              badge: timelineCount > 1 ? "\(timelineCount) timeline" : (order.reviewState == .accepted ? "Dispatch gap" : "Review first"),
              color: order.reviewState == .accepted ? .purple : .orange
            )
          }
        }
      }
    }
  }
}

struct CompactInboxDispatchSetupList: View {
  var orders: [TrackedOrder]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Inbox dispatch setup pending", symbol: "checkmark.rectangle.stack.fill") {
      if orders.isEmpty {
        CompactRow(
          title: "No Inbox dispatch setup pending",
          detail: "Verified Inbox-created orders have no promoted readiness follow-up.",
          badge: "Clear",
          color: .green
        )
      } else {
        ForEach(orders) { order in
          let checklists = store.suggestedDispatchReadinessChecklists(for: order).filter(\.isInboxHandoffSetup)
          DashboardOrderCompactLink(order: order, store: store) {
            CompactRow(
              title: "\(order.store) • \(order.orderNumber)",
              detail: checklists.first?.missingRequirementsSummary ?? "\(order.carrier) • \(order.trackingNumber)",
              badge: checklists.first?.checklistStatus.rawValue ?? "Readiness",
              color: .teal
            )
          }
        }
      }
    }
  }
}

struct CompactReopenedInboxDispatchHandoffList: View {
  var manifests: [ShipmentManifestRecord]
  var checklists: [DispatchReadinessChecklist]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Reopened Inbox dispatch handoffs", symbol: "arrow.counterclockwise.circle.fill") {
      if manifests.isEmpty && checklists.isEmpty {
        CompactRow(
          title: "No reopened handoffs",
          detail: "Inbox-created dispatch handoffs have no promoted reopened records.",
          badge: "Clear",
          color: .green
        )
      } else {
        ForEach(manifests) { manifest in
          NavigationLink {
            ShipmentManifestsView(store: store)
          } label: {
            CompactRow(
              title: manifest.title,
              detail: "\(manifest.carrierCourier) • planned \(manifest.plannedDispatchDate)",
              badge: manifest.dispatchStatus.rawValue,
              color: .purple
            )
          }
          .buttonStyle(.plain)
        }
        ForEach(checklists) { checklist in
          NavigationLink {
            DispatchReadinessView(store: store)
          } label: {
            CompactRow(
              title: checklist.title,
              detail: "\(checklist.assignedOwnerTeam) • \(checklist.missingRequirementsSummary)",
              badge: checklist.checklistStatus.rawValue,
              color: .purple
            )
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
}

private struct DashboardOrderCompactLink<Content: View>: View {
  var order: TrackedOrder
  var store: ParcelOpsStore
  @ViewBuilder var content: Content

  var body: some View {
    NavigationLink {
      OrderDetailView(order: order, store: store)
    } label: {
      content
    }
    .buttonStyle(.plain)
  }
}

struct CompactWorkbenchList: View {
  var items: [WorkbenchItem]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Highest priority work", symbol: "rectangle.stack.badge.person.crop.fill") {
      ForEach(items) { item in
        NavigationLink {
          OperationsWorkbenchView(store: store)
        } label: {
          CompactRow(
            title: item.title,
            detail: "\(item.source.rawValue) • \(item.suggestedNextAction)",
            badge: item.prioritySeverity,
            color: item.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactTrackingList: View {
  var events: [CarrierTrackingEvent]
  var orders: [TrackedOrder]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Highest risk tracking", symbol: "location.fill.viewfinder") {
      ForEach(events) { event in
        if let order = orders.first(where: { $0.id == event.orderID }) {
          NavigationLink {
            OrderDetailView(order: order, store: store)
          } label: {
            CompactRow(
              title: event.status,
              detail: "\(order.orderNumber) • \(event.carrier) • \(event.location)",
              badge: event.severity.rawValue,
              color: event.severity.color
            )
          }
          .buttonStyle(.plain)
        } else {
          NavigationLink {
            TrackingView(store: store)
          } label: {
            CompactRow(
              title: event.status,
              detail: "Unlinked • \(event.carrier) • \(event.location)",
              badge: event.severity.rawValue,
              color: event.severity.color
            )
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
}

struct CompactEvidenceList: View {
  var attachments: [EvidenceAttachment]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Latest evidence", symbol: "paperclip") {
      ForEach(attachments) { attachment in
        NavigationLink {
          EvidenceView(store: store)
        } label: {
          CompactRow(
            title: attachment.fileName,
            detail: "\(attachment.fileType) • \(attachment.source.rawValue)",
            badge: attachment.reviewState.rawValue,
            color: attachment.reviewState.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactAutomationList: View {
  var rules: [AutomationRule]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Automation rules", symbol: "arrow.triangle.branch") {
      ForEach(rules) { rule in
        NavigationLink {
          AutomationView(store: store)
        } label: {
          CompactRow(
            title: rule.name,
            detail: "\(rule.triggerType.rawValue) • \(rule.runCount) runs",
            badge: rule.isEnabled ? "Enabled" : "Disabled",
            color: rule.isEnabled ? .green : .gray
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactTaskList: View {
  var tasks: [ReviewTask]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Task escalations", symbol: "checklist") {
      ForEach(tasks) { task in
        NavigationLink {
          TasksView(store: store)
        } label: {
          CompactRow(
            title: task.title,
            detail: "\(task.assignee) • due \(task.dueDate)",
            badge: task.priority.rawValue,
            color: task.priority.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactSpaceMailDashboardFollowUp: View {
  var tasks: [ReviewTask]
  var handoffs: [HandoffNote]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Assigned SpaceMail work", symbol: "person.2.wave.2.fill") {
      ForEach(tasks) { task in
        NavigationLink {
          TasksView(store: store)
        } label: {
          CompactRow(
            title: task.title,
            detail: "\(task.assignee) • \(task.status.rawValue) • due \(task.dueDate)",
            badge: task.priority.rawValue,
            color: task.priority.color
          )
        }
        .buttonStyle(.plain)
      }

      ForEach(handoffs) { note in
        NavigationLink {
          TasksView(store: store)
        } label: {
          CompactRow(
            title: note.title,
            detail: "\(note.assignee) • \(note.status.rawValue) • due \(note.dueDate)",
            badge: note.priority.rawValue,
            color: note.priority.color
          )
        }
        .buttonStyle(.plain)
      }

      if tasks.isEmpty && handoffs.isEmpty {
        NavigationLink {
          MailboxView(store: store)
        } label: {
          CompactRow(
            title: "No assigned SpaceMail tasks yet",
            detail: "Use Mailbox Monitor to review uncertain mixed-mailbox previews or create follow-up tasks.",
            badge: "Mailbox",
            color: .teal
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactHandoffNoteList: View {
  var notes: [HandoffNote]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Handoff notes", symbol: "arrow.left.arrow.right.square.fill") {
      ForEach(notes) { note in
        NavigationLink {
          HandoffNotesView(store: store)
        } label: {
          CompactRow(
            title: note.title,
            detail: "\(note.assignee) • due \(note.dueDate)",
            badge: note.status.rawValue,
            color: note.status.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactSLAPolicyList: View {
  var policies: [SLAPolicy]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Recent policy matches", symbol: "timer") {
      ForEach(policies) { policy in
        NavigationLink {
          SLAPoliciesView(store: store)
        } label: {
          CompactRow(
            title: policy.name,
            detail: "\(policy.linkedEntityType.rawValue) • \(policy.lastEvaluatedDate)",
            badge: "\(policy.matchCount)",
            color: policy.priority.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactExceptionPlaybookList: View {
  var playbooks: [ExceptionPlaybook]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Exception playbooks", symbol: "book.closed.fill") {
      ForEach(playbooks) { playbook in
        NavigationLink {
          ExceptionPlaybooksView(store: store)
        } label: {
          CompactRow(
            title: playbook.name,
            detail: "\(playbook.issueType.rawValue) • \(playbook.escalationContact)",
            badge: playbook.priority.rawValue,
            color: playbook.priority.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactDraftMessageList: View {
  var drafts: [DraftMessage]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Draft messages", symbol: "envelope.open.fill") {
      ForEach(drafts) { draft in
        NavigationLink {
          CommunicationView(store: store)
        } label: {
          CompactRow(
            title: draft.subject,
            detail: "\(draft.recipient) • \(draft.channel.rawValue)",
            badge: draft.status.rawValue,
            color: draft.status.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactContactList: View {
  var contacts: [ContactDirectoryEntry]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Contacts needing review", symbol: "person.crop.circle.badge.checkmark") {
      ForEach(contacts) { contact in
        NavigationLink {
          ContactsView(store: store)
        } label: {
          CompactRow(
            title: contact.name,
            detail: "\(contact.organisation) • \(contact.channelPreference.rawValue)",
            badge: contact.reviewState.rawValue,
            color: contact.reviewState.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactCustomerProfileList: View {
  var profiles: [CustomerRecipientProfile]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Customer profiles", symbol: "person.text.rectangle.fill") {
      ForEach(profiles) { profile in
        NavigationLink {
          CustomerProfilesView(store: store)
        } label: {
          CompactRow(
            title: profile.displayName,
            detail: "\(profile.organisationTeam) • \(profile.deliveryPreference.rawValue)",
            badge: profile.isEnabled ? profile.reviewState.rawValue : "Disabled",
            color: profile.isEnabled ? profile.reviewState.color : .gray
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactDestinationAddressList: View {
  var addresses: [DestinationAddressRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Destination addresses", symbol: "mappin.and.ellipse") {
      ForEach(addresses) { address in
        NavigationLink {
          DestinationAddressesView(store: store)
        } label: {
          CompactRow(
            title: address.label,
            detail: "\(address.addressLineSummary), \(address.cityRegion) • \(address.preferredCarrier)",
            badge: address.riskLevel.rawValue,
            color: address.riskLevel.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactDeliveryInstructionList: View {
  var instructions: [DeliveryInstructionRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Delivery instructions", symbol: "signpost.right.and.left.fill") {
      ForEach(instructions) { instruction in
        NavigationLink {
          DeliveryInstructionsView(store: store)
        } label: {
          CompactRow(
            title: instruction.title,
            detail: "\(instruction.instructionType.rawValue) • \(instruction.preferredDeliveryWindow)",
            badge: instruction.riskLevel.rawValue,
            color: instruction.riskLevel.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactPackageContentList: View {
  var contents: [PackageContentRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Package contents", symbol: "shippingbox.circle.fill") {
      ForEach(contents) { content in
        NavigationLink {
          PackageContentsView(store: store)
        } label: {
          CompactRow(
            title: content.title,
            detail: "\(content.itemCategory.rawValue) • \(content.verifiedQuantity)/\(content.expectedQuantity) verified",
            badge: content.verificationStatus.rawValue,
            color: content.verificationStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactCostRecordList: View {
  var costs: [CostRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Costs needing action", symbol: "creditcard.and.123") {
      ForEach(costs) { cost in
        NavigationLink {
          CostsBudgetsView(store: store)
        } label: {
          CompactRow(
            title: cost.title,
            detail: "\(cost.amountText) \(cost.currency) • \(cost.budgetCode)",
            badge: cost.approvalStatus.rawValue,
            color: cost.approvalStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactReturnClaimList: View {
  var claims: [ReturnClaimRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Returns and claims", symbol: "arrow.uturn.backward.square.fill") {
      ForEach(claims) { claim in
        NavigationLink {
          ReturnsClaimsView(store: store)
        } label: {
          CompactRow(
            title: claim.title,
            detail: "\(claim.claimType.rawValue) • \(claim.requestedOutcome.rawValue)",
            badge: claim.claimStatus.rawValue,
            color: claim.claimStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactProcurementRequestList: View {
  var requests: [ProcurementRequest]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Procurement requests", symbol: "cart.badge.plus") {
      ForEach(requests) { request in
        NavigationLink {
          ProcurementView(store: store)
        } label: {
          CompactRow(
            title: request.title,
            detail: "\(request.estimatedCostText) \(request.currency) • \(request.budgetCode)",
            badge: request.procurementStatus.rawValue,
            color: request.procurementStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactReceivingInspectionList: View {
  var inspections: [ReceivingInspectionRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Receiving inspections", symbol: "checklist.checked") {
      ForEach(inspections) { inspection in
        NavigationLink {
          ReceivingInspectionsView(store: store)
        } label: {
          CompactRow(
            title: inspection.title,
            detail: "\(inspection.inspectionType.rawValue) • \(inspection.quantityReceived)/\(inspection.quantityExpected) received",
            badge: inspection.inspectionStatus.rawValue,
            color: inspection.inspectionStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactInventoryReceiptList: View {
  var receipts: [InventoryReceiptRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Inventory receipts", symbol: "archivebox.fill") {
      ForEach(receipts) { receipt in
        NavigationLink {
          InventoryReceiptsView(store: store)
        } label: {
          CompactRow(
            title: receipt.title,
            detail: "\(receipt.quantityAccepted)/\(receipt.quantityReceived) accepted • \(receipt.storageLocationSummary)",
            badge: receipt.stockHandoffStatus.rawValue,
            color: receipt.stockHandoffStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactStorageLocationList: View {
  var locations: [StorageLocationRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Storage locations", symbol: "cabinet.fill") {
      ForEach(locations) { location in
        NavigationLink {
          StorageLocationsView(store: store)
        } label: {
          CompactRow(
            title: location.title,
            detail: "\(location.locationCode) • \(location.areaZone)",
            badge: location.isEnabled ? "Enabled" : "Disabled",
            color: location.isEnabled ? .green : .gray
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactCustodyRecordList: View {
  var records: [CustodyRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Custody chain", symbol: "person.badge.shield.checkmark.fill") {
      ForEach(records) { record in
        NavigationLink {
          CustodyChainView(store: store)
        } label: {
          CompactRow(
            title: record.title,
            detail: "\(record.currentCustodianTeam) • \(record.expectedReturnCloseDate)",
            badge: record.custodyStatus.rawValue,
            color: record.custodyStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactLabelReferenceList: View {
  var records: [LabelReferenceRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Label references", symbol: "barcode.viewfinder") {
      ForEach(records) { record in
        NavigationLink {
          LabelReferencesView(store: store)
        } label: {
          CompactRow(
            title: record.title,
            detail: "\(record.labelType.rawValue) • \(record.labelValuePlaceholder)",
            badge: record.labelStatus.rawValue,
            color: record.labelStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactScanSessionList: View {
  var records: [ScanSessionRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Scan sessions", symbol: "qrcode.viewfinder") {
      ForEach(records) { record in
        NavigationLink {
          ScanSessionsView(store: store)
        } label: {
          CompactRow(
            title: record.title,
            detail: "\(record.scanPurpose.rawValue) • \(record.capturedValuePlaceholder.isEmpty ? "Missing captured value" : record.capturedValuePlaceholder)",
            badge: record.scanStatus.rawValue,
            color: record.scanStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactShipmentManifestList: View {
  var records: [ShipmentManifestRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Shipment manifests", symbol: "list.bullet.clipboard.fill") {
      ForEach(records) { record in
        NavigationLink {
          ShipmentManifestsView(store: store)
        } label: {
          CompactRow(
            title: record.title,
            detail: "\(record.carrierCourier) • \(record.destinationSummary)",
            badge: record.dispatchStatus.rawValue,
            color: record.dispatchStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactDispatchReadinessList: View {
  var checklists: [DispatchReadinessChecklist]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Dispatch readiness", symbol: "checkmark.rectangle.stack.fill") {
      ForEach(checklists) { checklist in
        NavigationLink {
          DispatchReadinessView(store: store)
        } label: {
          CompactRow(
            title: checklist.title,
            detail: "\(checklist.checklistType.rawValue) • \(checklist.plannedDispatchDate)",
            badge: checklist.checklistStatus.rawValue,
            color: checklist.checklistStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactAccountList: View {
  var accounts: [AccountCredentialRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Accounts needing review", symbol: "key.horizontal.fill") {
      ForEach(accounts) { account in
        NavigationLink {
          AccountsView(store: store)
        } label: {
          CompactRow(
            title: account.accountName,
            detail: "\(account.organisation) • \(account.credentialStorageStatus.rawValue)",
            badge: account.mfaStatus.rawValue,
            color: account.mfaStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactVendorProfileList: View {
  var profiles: [VendorProfile]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Profile watchlist", symbol: "building.2.crop.circle.fill") {
      ForEach(profiles) { profile in
        NavigationLink {
          VendorProfilesView(store: store)
        } label: {
          CompactRow(
            title: profile.name,
            detail: "\(profile.profileType.rawValue) • \(profile.primaryOrganisation)",
            badge: profile.riskLevel.rawValue,
            color: profile.riskLevel.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactShipmentGroupList: View {
  var groups: [ShipmentGroup]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Shipment group watchlist", symbol: "shippingbox.and.arrow.backward.fill") {
      ForEach(groups) { group in
        NavigationLink {
          ShipmentGroupsView(store: store)
        } label: {
          CompactRow(
            title: group.groupName,
            detail: "\(group.carrierSummary) • \(group.statusSummary)",
            badge: group.riskLevel.rawValue,
            color: group.riskLevel.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactImportQueueList: View {
  var items: [ImportQueueItem]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Import queue", symbol: "tray.and.arrow.down.fill") {
      ForEach(items) { item in
        NavigationLink {
          ImportQueueView(store: store)
        } label: {
          CompactRow(
            title: item.sourceLabel,
            detail: "\(item.detectedMerchant) • \(item.detectedOrderNumber) • \(item.confidenceScore)%",
            badge: item.importStatus.rawValue,
            color: item.importStatus.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactAcceptanceList: View {
  var records: [AcceptanceRecord]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Acceptance history", symbol: "checkmark.rectangle.stack.fill") {
      ForEach(records) { record in
        NavigationLink {
          AcceptanceReviewView(store: store)
        } label: {
          CompactRow(
            title: record.sourceLabel,
            detail: "\(record.sourceType.rawValue) • \(record.confidenceScore)% • \(record.decidedDate)",
            badge: record.decision.rawValue,
            color: record.decision.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactAuditList: View {
  var events: [AuditEvent]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Recent audit", symbol: "list.clipboard.fill") {
      ForEach(events) { event in
        NavigationLink {
          AuditView(store: store)
        } label: {
          CompactRow(
            title: event.summary,
            detail: "\(event.entityType.rawValue) • \(event.entityLabel) • \(event.timestamp)",
            badge: event.action.rawValue,
            color: event.action.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactTimelineList: View {
  var activities: [TimelineActivity]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Recent timeline", symbol: "clock.badge.exclamationmark.fill") {
      ForEach(activities) { activity in
        NavigationLink {
          TimelineView(store: store)
        } label: {
          CompactRow(
            title: activity.title,
            detail: "\(activity.entityType.rawValue) • \(activity.source.rawValue) • \(activity.timestampText)",
            badge: activity.risk.rawValue,
            color: activity.risk.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactValidationIssueList: View {
  var issues: [ValidationIssue]
  var store: ParcelOpsStore?

  var body: some View {
    CompactList(title: "Validation issues", symbol: "checkmark.seal.fill") {
      ForEach(issues) { issue in
        if let store {
          NavigationLink {
            ValidationView(store: store)
          } label: {
            CompactRow(
              title: issue.title,
              detail: "\(issue.entityType.rawValue) • \(issue.status.rawValue) • confidence \(issue.confidenceScore)%",
              badge: issue.severity.rawValue,
              color: issue.severity.color
            )
          }
          .buttonStyle(.plain)
        } else {
          CompactRow(
            title: issue.title,
            detail: "\(issue.entityType.rawValue) • \(issue.status.rawValue) • confidence \(issue.confidenceScore)%",
            badge: issue.severity.rawValue,
            color: issue.severity.color
          )
        }
      }
    }
  }
}

struct CompactReconciliationIssueList: View {
  var issues: [ReconciliationIssue]
  var store: ParcelOpsStore

  var body: some View {
    CompactList(title: "Reconciliation issues", symbol: "arrow.triangle.2.circlepath.circle.fill") {
      ForEach(issues) { issue in
        NavigationLink {
          ReconciliationView(store: store)
        } label: {
          CompactRow(
            title: issue.title,
            detail: "\(issue.issueType.rawValue) • \(issue.sourceEntityType.rawValue) → \(issue.targetEntityType?.rawValue ?? "None")",
            badge: issue.severity.rawValue,
            color: issue.severity.color
          )
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct CompactList<Content: View>: View {
  var title: String
  var symbol: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(title, systemImage: symbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      VStack(spacing: 8) {
        content
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct CompactRow: View {
  var title: String
  var detail: String
  var badge: String
  var color: Color
  var secondaryBadge: String? = nil
  var secondaryColor: Color = .secondary

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.callout.weight(.semibold))
          .lineLimit(1)
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 4) {
        Badge(badge, color: color)
        if let secondaryBadge {
          Badge(secondaryBadge, color: secondaryColor)
        }
      }
    }
    .padding(10)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
