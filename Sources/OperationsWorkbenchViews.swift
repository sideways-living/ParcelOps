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
          isInboxCreatedOrder(order)
            && (needsPreDispatchVerification(order) || order.reviewState != .accepted || needsDispatchSetup(order) || needsInboxDispatchReadiness(order))
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
    if !partialInboxOrderBlockers.isEmpty { return .orange }
    if !inboxDispatchReadinessOrders.isEmpty { return .teal }
    if !inboxCreatedOrders.isEmpty { return .teal }
    if !draftFollowUpItems.isEmpty { return .orange }
    if defaultQueueItems.filter({ $0.reviewState == .needsReview }).count > 0 { return .purple }
    if defaultQueueItems.isEmpty { return .green }
    return .blue
  }

  private var workbenchNextActionTitle: String {
    if urgentWorkbenchCount > 0 { return "Start with urgent work" }
    if defaultQueueItems.filter(\.isBlocked).count > 0 { return "Clear blocked work" }
    if !partialInboxOrderBlockers.isEmpty { return "Verify partial Inbox orders" }
    if !inboxDispatchReadinessOrders.isEmpty { return "Finish Inbox dispatch readiness" }
    if !inboxCreatedOrders.isEmpty { return "Confirm Inbox-created orders" }
    if !draftFollowUpItems.isEmpty { return "Send or review draft follow-up" }
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
          detail: "This is the daily triage surface for the local MVP. Start here when you want the most actionable work, not every record in the system.",
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
        SpaceMailPrimaryStatusStrip(store: store)
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
          ("Verify first", "\(partialInboxOrderBlockers.count)", partialInboxOrderBlockers.isEmpty ? .green : .orange),
          ("Readiness", "\(inboxDispatchReadinessOrders.count)", inboxDispatchReadinessOrders.isEmpty ? .green : .teal),
          ("Inbox orders", "\(inboxCreatedOrders.count)", inboxCreatedOrders.isEmpty ? .green : .teal),
          ("Drafts", "\(draftFollowUpItems.count)", draftFollowUpItems.isEmpty ? .green : .orange),
          ("Open", "\(defaultQueueItems.count)", defaultQueueItems.isEmpty ? .green : .blue)
        ])
      }
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
          ("Uncertain mail", "\(store.spaceMailIMAPConnections.reduce(0) { $0 + $1.uncertainMessages.count })", store.spaceMailIMAPConnections.contains { !$0.uncertainMessages.isEmpty } ? .orange : .green),
          ("Filtered mail", "\(store.spaceMailIMAPConnections.reduce(0) { $0 + $1.filteredMessages.count })", .teal),
          ("Inbox review", "\(store.reviewIntakeEmails.count)", store.reviewIntakeEmails.isEmpty ? .green : .teal),
          ("Primary work", "\(store.openWorkbenchItems.count)", store.openWorkbenchItems.isEmpty ? .green : .blue)
        ])

        Text(store.intakeParserDiagnostics.isEmpty && !store.spaceMailIMAPConnections.contains { !$0.uncertainMessages.isEmpty }
          ? "No parser or uncertain-message diagnostics are currently pulling attention away from the operator queue."
          : "Use Inbox for optional parser diagnostics and Mailbox Monitor for uncertain/filtered SpaceMail review. Do not treat filtered non-order mail as Workbench work.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(store.intakeParserDiagnostics.isEmpty && !store.spaceMailIMAPConnections.contains { !$0.uncertainMessages.isEmpty } ? .green : .orange)
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
            needsPreDispatchVerification: needsPreDispatchVerification(order),
            partialTaskCount: partialInboxTaskCount(for: order),
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

  private func isInboxCreatedOrder(_ order: TrackedOrder) -> Bool {
    order.source == .forwardedMailbox
      || order.checkedMailbox == "manual-import"
      || order.latestStatus.localizedCaseInsensitiveContains("import queue")
      || order.latestStatus.localizedCaseInsensitiveContains("acceptance")
      || order.latestStatus.localizedCaseInsensitiveContains("forwarded email")
  }

  private func needsDispatchSetup(_ order: TrackedOrder) -> Bool {
    [.shipped, .inTransit, .exception].contains(order.status)
      && store.suggestedShipmentManifestRecords(for: order).isEmpty
      && store.suggestedDispatchReadinessChecklists(for: order).isEmpty
  }

  private func needsInboxDispatchReadiness(_ order: TrackedOrder) -> Bool {
    !needsPreDispatchVerification(order)
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

  private func partialInboxTaskCount(for order: TrackedOrder) -> Int {
    store.tasks(for: .order, linkedEntityID: order.id.uuidString).filter { task in
      task.status != .completed && task.isPartialInboxOrderFollowUp
    }.count
  }

  private func needsPreDispatchVerification(_ order: TrackedOrder) -> Bool {
    partialInboxTaskCount(for: order) > 0 || order.missingWorkbenchInboxOrderFieldCount > 0
  }

  @ViewBuilder
  private func workbenchRow(for item: WorkbenchItem) -> some View {
    WorkbenchItemRow(
      item: item,
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
      contextDestination: AnyView(workbenchDestination(for: item))
    ) {
      store.createReviewTask(from: item)
    } onCreateDraft: {
      store.createDraftMessage(from: item)
    } onReviewed: {
      store.markWorkbenchItemReviewed(item)
    }
  }

  @ViewBuilder
  private func workbenchDestination(for item: WorkbenchItem) -> some View {
    switch item.source {
    case .reviewTask, .handoffNote:
      TasksView(store: store)
    case .intakeEmail, .intakeParser, .spaceMailIntake, .importQueue, .acceptanceReview:
      InboxView(store: store)
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
    }
  }
}

private extension ShipmentManifestRecord {
  var isInboxHandoffSetup: Bool {
    linkedEntityType == .order
      && (
        title.localizedCaseInsensitiveContains("Dispatch setup for")
          || manifestReferencePlaceholder.localizedCaseInsensitiveContains("INBOX-")
          || notes.localizedCaseInsensitiveContains("Inbox handoff")
      )
  }
}

private extension DispatchReadinessChecklist {
  var isInboxHandoffSetup: Bool {
    linkedEntityType == .order
      && (
        title.localizedCaseInsensitiveContains("Readiness for")
          || completedChecksSummary.localizedCaseInsensitiveContains("Inbox handoff")
          || missingRequirementsSummary.localizedCaseInsensitiveContains("handoff location")
      )
  }
}

private struct WorkbenchInboxOrderRow: View {
  var order: TrackedOrder
  var needsDispatchSetup: Bool
  var needsInboxDispatchReadiness: Bool
  var needsPreDispatchVerification: Bool
  var partialTaskCount: Int
  var store: ParcelOpsStore
  @State private var feedbackMessage: String?

  private var rowColor: Color {
    if needsPreDispatchVerification { return .orange }
    if needsInboxDispatchReadiness { return .teal }
    if needsDispatchSetup { return .purple }
    return order.status == .exception ? .orange : .teal
  }

  private var nextActionText: String {
    if needsPreDispatchVerification {
      return "Next: verify missing Inbox details from the order before dispatch setup."
    }
    if needsDispatchSetup {
      return "Next: add or link dispatch manifest/readiness context."
    }
    if needsInboxDispatchReadiness {
      return "Next: finish readiness, label, scan, custody, and handoff checks in Dispatch."
    }
    return "Next: confirm tracking, destination, and linked follow-up from the order detail."
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
        if partialTaskCount > 0 {
          Badge("\(partialTaskCount) verify task", color: .orange)
        }
        if order.missingWorkbenchInboxOrderFieldCount > 0 {
          Badge("\(order.missingWorkbenchInboxOrderFieldCount) missing", color: .orange)
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)

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
        } else if needsDispatchSetup || needsInboxDispatchReadiness {
          NavigationLink {
            DispatchView(store: store)
          } label: {
            Label(needsInboxDispatchReadiness ? "Open Readiness" : "Open Dispatch", systemImage: "shippingbox.and.arrow.backward.fill")
          }
          .buttonStyle(.bordered)
        }

        Button("Task", systemImage: "checklist") {
          store.createReviewTask(from: order)
          feedbackMessage = "Review task created."
        }
        .buttonStyle(.bordered)

        Button("Draft", systemImage: "envelope.open.fill") {
          store.createDraftMessage(from: order)
          feedbackMessage = "Draft created."
        }
        .buttonStyle(.bordered)

        if !needsPreDispatchVerification {
          Button("Reviewed", systemImage: "checkmark.circle.fill") {
            var reviewedOrder = order
            reviewedOrder.reviewState = .accepted
            store.updateOrder(reviewedOrder)
            feedbackMessage = "Order marked reviewed."
          }
          .buttonStyle(.bordered)
        }
      }

      if let feedbackMessage {
        Text(feedbackMessage)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
    }
    .padding(12)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private extension ReviewTask {
  var isPartialInboxOrderFollowUp: Bool {
    linkedEntityType == .order
      && title.localizedCaseInsensitiveContains("Verify Inbox-created order")
      && summary.localizedCaseInsensitiveContains("Confirm missing")
  }
}

private extension TrackedOrder {
  var missingWorkbenchInboxOrderFieldCount: Int {
    [orderNumber, trackingNumber, destination]
      .filter { value in
        value == "Pending" || value == "Pending review" || value.isPlaceholderValidationValue
      }
      .count
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
        if let linkedOrder {
          Label("\(linkedOrder.store) \(linkedOrder.orderNumber)", systemImage: "shippingbox.fill")
            .foregroundStyle(.teal)
        } else {
          Label(draft.linkedEntityType.rawValue, systemImage: draft.linkedEntityType.symbol)
        }
        Label(draft.createdDate, systemImage: "calendar")
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      CompactActionRow {
        if let linkedOrder {
          NavigationLink {
            OrderDetailView(order: linkedOrder, store: store)
          } label: {
            Label("Open order", systemImage: "shippingbox.fill")
          }
          .buttonStyle(.bordered)
        }

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
        Text(feedbackMessage)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
    }
    .padding(12)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct WorkbenchItemRow: View {
  var item: WorkbenchItem
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
  var contextDestination: AnyView?
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onReviewed: () -> Void

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
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      CompactActionRow {
        if let contextDestination {
          NavigationLink {
            contextDestination
          } label: {
            Label("Open", systemImage: "arrow.up.right.square.fill")
          }
          .buttonStyle(.bordered)
        }
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill", action: onCreateDraft)
          .buttonStyle(.bordered)
        if item.supportsReviewAction {
          Button("Reviewed", systemImage: "checkmark.circle.fill", action: onReviewed)
            .buttonStyle(.bordered)
        }
        Text(item.source.rawValue)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
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
}
