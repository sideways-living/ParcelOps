import SwiftUI

struct OperationsWorkbenchView: View {
  var store: ParcelOpsStore
  @State private var selectedAssignee: String?
  @State private var selectedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedPrioritySeverity: String?
  @State private var selectedStatus: String?
  @State private var selectedReviewState: ReviewState?
  @State private var selectedSource: WorkbenchSource?
  @State private var workbenchSearchText = ""
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

  private var inboxCreatedOrders: [TrackedOrder] {
    Array(
      store.orders
        .filter { order in
          order.isInboxCreatedLocalOrder
            && (needsPreDispatchVerification(order) || order.reviewState != .accepted || needsDispatchSetup(order) || needsInboxDispatchReadiness(order) || hasReopenedInboxDispatchHandoff(order))
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
    Array(store.draftMessagesNeedingReview.prefix(5))
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

  private var spaceMailDuplicateCount: Int {
    spaceMailHealthSummaries.reduce(0) { $0 + $1.duplicateCount }
  }

  private var spaceMailFilteredCount: Int {
    spaceMailHealthSummaries.reduce(0) { $0 + $1.filteredCount }
  }

  private var spaceMailUncertainCount: Int {
    spaceMailHealthSummaries.reduce(0) { $0 + $1.uncertainCount + $1.pendingUncertainReviewCount }
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

  private var gmailFilteredCount: Int {
    store.gmailMailboxConnections.reduce(0) { $0 + max($1.filteredMessages?.count ?? 0, $1.lastRefreshFilteredNonOrderCount) }
  }

  private var gmailUncertainCount: Int {
    store.gmailMailboxConnections.reduce(0) { $0 + max($1.uncertainMessages?.count ?? 0, $1.lastRefreshUncertainCount ?? 0) }
  }

  private var pendingGmailFilteredReviewCount: Int {
    store.gmailMailboxConnections.reduce(0) { $0 + ($1.filteredMessages?.count ?? 0) }
  }

  private var gmailWarningCount: Int {
    gmailHealthSummaries.filter { $0.tone == "warning" || $0.tone == "attention" }.count
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
    if linkedInboxIntakeCount > 0 { return "Linked Inbox source trails are ready for review" }
    return "No Inbox parser handoff is blocking Workbench"
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
    return "Inbox parser, link, and source-trail handoff counts are clear. Workbench can stay focused on real operational exceptions."
  }

  private var pendingFilteredSpaceMailCount: Int {
    spaceMailHealthSummaries.reduce(0) { $0 + $1.pendingFilteredReviewCount }
  }

  private var spaceMailFilteredOnlyOutcome: Bool {
    spaceMailFetchedCount > 0
      && spaceMailImportedCount == 0
      && spaceMailUncertainCount == 0
      && spaceMailFilteredCount > 0
  }

  private var setupPlaceholderReviewItems: [WorkbenchItem] {
    defaultQueueItems.filter { $0.source == .setupPlaceholder }
  }

  private var dailyAttentionCount: Int {
    store.reviewIntakeEmails.count
      + store.spaceMailIMAPConnections.reduce(0) { $0 + $1.uncertainMessages.count }
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
    if !partialInboxOrderBlockers.isEmpty { return "Verify partial Inbox orders" }
    if !inboxDispatchReadinessOrders.isEmpty { return "Finish Inbox dispatch readiness" }
    if !inboxCreatedOrders.isEmpty { return "Confirm Inbox-created orders" }
    if !draftFollowUpItems.isEmpty { return "Send or review draft follow-up" }
    if !setupPlaceholderReviewItems.isEmpty { return "Review setup placeholders" }
    if defaultQueueItems.filter({ $0.reviewState == .needsReview }).count > 0 { return "Review open exceptions" }
    if defaultQueueItems.isEmpty { return "Workbench is clear" }
    return "Work the open exception queue"
  }

  private var workbenchNextActionDetail: String {
    if urgentWorkbenchCount > 0 {
      return "\(urgentWorkbenchCount) overdue or high-priority item is promoted. Open the first row, create a task or draft, then mark reviewed where supported."
    }
    let blockedCount = defaultQueueItems.filter(\.isBlocked).count
    let needsReviewCount = defaultQueueItems.filter { $0.reviewState == .needsReview }.count
    if blockedCount > 0 {
      return "\(blockedCount) item is blocked. Resolve the blocker or route it to the detailed screen before reviewing routine work."
    }
    if reopenedInboxDispatchHandoffCount > 0 {
      return "\(reopenedInboxDispatchHandoffCount) Inbox dispatch handoff record was reopened. Open the linked order and Dispatch context before closing it again."
    }
    if !partialInboxOrderBlockers.isEmpty {
      return "\(partialInboxOrderBlockers.count) Inbox-created order has missing details or an open verification task. Open the order before dispatch setup."
    }
    if !inboxDispatchReadinessOrders.isEmpty {
      return "\(inboxDispatchReadinessOrders.count) Inbox-created order has local dispatch setup but still needs readiness, label, scan, custody, or handoff confirmation."
    }
    if !inboxCreatedOrders.isEmpty {
      return "\(inboxCreatedOrders.count) Inbox-created order needs operational confirmation or dispatch setup before it disappears from daily follow-up."
    }
    if !draftFollowUpItems.isEmpty {
      return "\(draftFollowUpItems.count) draft needs review, sending, or reopening before the related work can be closed."
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
      VStack(alignment: .leading, spacing: 16) {
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
        resolutionLadderPanel
        SpaceMailPrimaryStatusStrip(store: store)
        SpaceMailRefreshTrendCard(summary: store.spaceMailRefreshTrendSummary)
        Text("SpaceMail refresh trend is context for triage. Imported and uncertain messages can create work; filtered mixed-mailbox messages remain out of Workbench unless promoted from Mailbox Monitor.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        spaceMailWorkbenchBoundary
        gmailWorkbenchBoundary
        inboxParserQualityHandoff
        spaceMailAssignedFollowUpPanel
        workbenchDiagnosticsBoundary
        inboxCreatedOrderFollowUp
        draftFollowUpPanel
        operatorQueue
        advancedFilters
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
    .background(.regularMaterial)
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
    let mailboxReviewCount = spaceMailUncertainCount + pendingFilteredSpaceMailCount + store.intakeParserDiagnostics.count
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
        "Use Mailbox Monitor for uncertain, filtered, or parser-diagnostic SpaceMail evidence that should not flood Workbench.",
        mailboxReviewCount,
        "Mailbox Monitor",
        "server.rack",
        mailboxReviewCount == 0 ? .green : .orange
      ),
      (
        "Order handoff",
        "Use Orders when an Inbox-created order needs source trail, customer, destination, tracking, or dispatch setup confirmation.",
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

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 170 : 220), spacing: 10)], alignment: .leading, spacing: 10) {
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
            .frame(maxWidth: .infinity, alignment: .topLeading)
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
      return "\(inboxCreatedOrders.count) Inbox-created order is already in the handoff path. Confirm the order detail, source trail, and dispatch setup below."
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
          ("Warnings", "\(gmailWarningCount)", gmailWarningCount == 0 ? .green : .orange)
        ])

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

        Text(pendingGmailFilteredReviewCount > 0
          ? "Filtered Gmail examples are waiting for optional review, but they stay out of Workbench until an operator imports one into Inbox or creates follow-up."
          : "Gmail becomes Workbench work only after it creates actionable local state: imported Inbox intake, uncertain previews needing review, setup failures, or assigned follow-up. Filtered non-order Gmail stays out of the operator exception queue.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(gmailWorkbenchTone)
          .fixedSize(horizontal: false, vertical: true)

        CompactActionRow {
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

  private var gmailWorkbenchTone: Color {
    if gmailWarningCount > 0 || gmailUncertainCount > 0 { return .orange }
    if gmailImportedCount > 0 { return .teal }
    if gmailFilteredCount > 0 { return .green }
    return .secondary
  }

  private var gmailWorkbenchTitle: String {
    if gmailWarningCount > 0 { return "Gmail setup or refresh needs review" }
    if gmailUncertainCount > 0 { return "Gmail needs Mailbox Monitor review" }
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
    if gmailImportedCount > 0 {
      return "\(gmailImportedCount) likely Gmail order message reached Inbox. Review or create/link the order there before expecting Workbench exceptions."
    }
    if gmailFilteredCount > 0 {
      if pendingGmailFilteredReviewCount > 0 {
        return "\(pendingGmailFilteredReviewCount) filtered Gmail preview is available for optional review. It is not Workbench work unless imported into Inbox."
      }
      return "\(gmailFilteredCount) mixed-mailbox Gmail message was filtered out of Inbox. There is no Workbench exception until an order email is imported, promoted, or created."
    }
    if gmailHealthSummaries.isEmpty {
      return "Add Gmail setup only for mailboxes hosted by Gmail or Google Workspace. SpaceMail can remain the primary path."
    }
    return "Gmail setup exists, but the latest state did not produce imported or uncertain order work."
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

  private var spaceMailAssignedWorkbenchItems: [WorkbenchItem] {
    store.openWorkbenchItems.filter { item in
      (item.source == .reviewTask || item.source == .handoffNote)
        && (item.title.localizedCaseInsensitiveContains("spacemail")
          || item.summary.localizedCaseInsensitiveContains("spacemail")
          || item.suggestedNextAction.localizedCaseInsensitiveContains("spacemail")
          || item.suggestedNextAction.localizedCaseInsensitiveContains("mailbox monitor"))
    }
  }

  @ViewBuilder
  private var spaceMailAssignedFollowUpPanel: some View {
    if !spaceMailAssignedWorkbenchItems.isEmpty {
      SettingsPanel(title: "SpaceMail assigned follow-up", symbol: "person.2.wave.2.fill") {
        VStack(alignment: .leading, spacing: 12) {
          Text("SpaceMail shift handoffs and review tasks are now assigned work. Use this panel to see them in Workbench, then open Tasks to complete, acknowledge, draft, or review them.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          MetricStrip(items: [
            ("Assigned", "\(spaceMailAssignedWorkbenchItems.count)", .purple),
            ("Needs review", "\(spaceMailAssignedWorkbenchItems.filter { $0.reviewState == .needsReview }.count)", spaceMailAssignedWorkbenchItems.contains { $0.reviewState == .needsReview } ? .orange : .green),
            ("High priority", "\(spaceMailAssignedWorkbenchItems.filter { $0.rank >= 3 }.count)", spaceMailAssignedWorkbenchItems.contains { $0.rank >= 3 } ? .orange : .green),
            ("Blocked", "\(spaceMailAssignedWorkbenchItems.filter(\.isBlocked).count)", spaceMailAssignedWorkbenchItems.contains(where: \.isBlocked) ? .red : .green)
          ])

          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 190 : 250), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(spaceMailAssignedWorkbenchItems.prefix(4)) { item in
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

        MetricStrip(items: [
          ("Parser checks", "\(store.intakeParserDiagnostics.count)", store.intakeParserDiagnostics.isEmpty ? .green : .orange),
          ("Uncertain mail", "\(store.spaceMailIMAPConnections.reduce(0) { $0 + $1.uncertainMessages.count } + store.gmailMailboxConnections.reduce(0) { $0 + ($1.uncertainMessages?.count ?? 0) })", store.spaceMailIMAPConnections.contains { !$0.uncertainMessages.isEmpty } || store.gmailMailboxConnections.contains { ($0.uncertainMessages?.isEmpty == false) } ? .orange : .green),
          ("Filtered mail", "\(store.spaceMailIMAPConnections.reduce(0) { $0 + $1.filteredMessages.count } + pendingGmailFilteredReviewCount)", .teal),
          ("Inbox review", "\(store.reviewIntakeEmails.count)", store.reviewIntakeEmails.isEmpty ? .green : .teal),
          ("Primary work", "\(store.openWorkbenchItems.count)", store.openWorkbenchItems.isEmpty ? .green : .blue)
        ])

        Text(store.intakeParserDiagnostics.isEmpty && !store.spaceMailIMAPConnections.contains { !$0.uncertainMessages.isEmpty } && !store.gmailMailboxConnections.contains { $0.uncertainMessages?.isEmpty == false }
          ? "No parser or uncertain-message diagnostics are currently pulling attention away from the operator queue."
          : "Use Inbox for optional parser diagnostics and Mailbox Monitor for uncertain/filtered SpaceMail or Gmail review. Do not treat filtered non-order mail as Workbench work.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(store.intakeParserDiagnostics.isEmpty && !store.spaceMailIMAPConnections.contains { !$0.uncertainMessages.isEmpty } && !store.gmailMailboxConnections.contains { $0.uncertainMessages?.isEmpty == false } ? .green : .orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  @ViewBuilder
  private var inboxCreatedOrderFollowUp: some View {
    if !inboxCreatedOrders.isEmpty {
      SettingsPanel(title: partialInboxOrderBlockers.isEmpty ? "Inbox-created order follow-up" : "Inbox-created order verification", symbol: partialInboxOrderBlockers.isEmpty ? "tray.and.arrow.down.fill" : "exclamationmark.triangle.fill") {
        Text(partialInboxOrderBlockers.isEmpty
          ? "Orders created from Inbox, Import Queue, or Acceptance Review stay here until someone confirms the operational details and dispatch setup."
          : "Partial Inbox-created orders stay here until missing order, tracking, or destination details are confirmed. Do this before dispatch setup.")
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
            sourceTrailCount: sourceTrailCount(for: order),
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
    if sourceTrailCount(for: order) == 0 { return 112 }
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
      return "Next: verify missing Inbox details from the order before dispatch setup."
    }
    if sourceTrailCount == 0 {
      return "Next: confirm the local Inbox, Import Queue, or Acceptance source trail before closing this handoff."
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
        Image(systemName: "envelope.open.fill")
          .foregroundStyle(statusColor)
          .frame(width: 22)

        VStack(alignment: .leading, spacing: 4) {
          Text(draft.subject)
            .font(.headline)
          Text("\(draft.channel.rawValue) • \(draft.recipient)")
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Text("Next: confirm the message is ready, mark it sent locally, or reopen it for another edit.")
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
    case "mock":
      return .purple
    case "microsoft", "mailbox":
      return .blue
    default:
      return .secondary
    }
  }
}
