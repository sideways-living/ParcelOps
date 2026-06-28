import SwiftUI

struct OperationsWorkbenchView: View {
  var store: ParcelOpsStore
  @State private var selectedAssignee: String?
  @State private var selectedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedPrioritySeverity: String?
  @State private var selectedStatus: String?
  @State private var selectedReviewState: ReviewState?
  @State private var selectedSource: WorkbenchSource?
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

  private var queueItems: [WorkbenchItem] {
    hasActiveFilters ? filteredItems : store.openWorkbenchItems
  }

  private var inboxCreatedOrders: [TrackedOrder] {
    Array(
      store.orders
        .filter { isInboxCreatedOrder($0) && $0.reviewState != .accepted }
        .prefix(5)
    )
  }

  private var dailyAttentionCount: Int {
    store.reviewIntakeEmails.count
      + store.intakeParserDiagnostics.count
      + store.spaceMailIMAPConnections.reduce(0) { $0 + $1.uncertainMessages.count }
      + store.importQueueItemsNeedingReview.count
      + store.blockedImportQueueItems.count
      + store.acceptanceRecordsNeedingReview.count
      + store.reviewOrders.count
      + store.blockedShipmentManifests.count
      + store.blockedDispatchChecklists.count
      + store.reviewTasksNeedingAttention.count
      + store.handoffNotesNeedingAttention.count
      + store.highPriorityWorkbenchItems.count
  }

  private var advancedBacklogCount: Int {
    max(store.reviewQueueCount - dailyAttentionCount, 0)
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
        inboxCreatedOrderFollowUp
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
      MetricStrip(items: [
        ("Urgent", "\(store.overdueWorkbenchItems.count + store.highPriorityWorkbenchItems.count)", .red),
        ("Blocked", "\(store.blockedWorkbenchItems.count)", .orange),
        ("Review", "\(store.workbenchItemsNeedingReview.count)", .purple),
        ("Inbox orders", "\(inboxCreatedOrders.count)", inboxCreatedOrders.isEmpty ? .green : .teal),
        ("Open", "\(store.openWorkbenchItems.count)", .blue)
      ])
      Text("Use this queue to turn local exceptions into tasks, drafts, reviews, or the right detailed workspace.")
        .font(.callout)
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private var inboxCreatedOrderFollowUp: some View {
    if !inboxCreatedOrders.isEmpty {
      SettingsPanel(title: "Inbox-created order follow-up", symbol: "tray.and.arrow.down.fill") {
        Text("Orders created from Inbox, Import Queue, or Acceptance Review stay here until someone confirms the operational details.")
          .font(.callout)
          .foregroundStyle(.secondary)
        ForEach(inboxCreatedOrders) { order in
          WorkbenchInboxOrderRow(order: order, store: store)
        }
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

private struct WorkbenchInboxOrderRow: View {
  var order: TrackedOrder
  var store: ParcelOpsStore
  @State private var feedbackMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "shippingbox.fill")
          .foregroundStyle(order.status == .exception ? .orange : .teal)
          .frame(width: 22)

        VStack(alignment: .leading, spacing: 4) {
          Text("\(order.store) \(order.orderNumber)")
            .font(.headline)
          Text("\(order.customer) • \(order.destination)")
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text("Next: confirm tracking, destination, and linked follow-up from the order detail.")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.teal)
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 6) {
          Badge(order.status.rawValue, color: order.status == .exception ? .orange : .blue)
          Badge(order.reviewState.rawValue, color: order.reviewState.color)
        }
      }

      CompactMetadataGrid {
        Label(order.trackingNumber, systemImage: "number")
        Label(order.carrier, systemImage: "truck.box.fill")
        Label(order.latestStatus, systemImage: "waveform.path.ecg")
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

        Button("Reviewed", systemImage: "checkmark.circle.fill") {
          var reviewedOrder = order
          reviewedOrder.reviewState = .accepted
          store.updateOrder(reviewedOrder)
          feedbackMessage = "Order marked reviewed."
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
