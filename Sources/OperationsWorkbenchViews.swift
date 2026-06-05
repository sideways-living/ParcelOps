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

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filters

        ForEach(store.groupedWorkbenchItems(filteredItems)) { group in
          SettingsPanel(title: group.title, symbol: group.symbol) {
            ForEach(group.items) { item in
              WorkbenchItemRow(item: item, customerProfiles: store.suggestedCustomerProfiles(for: item), destinationAddresses: store.suggestedDestinationAddresses(for: item), deliveryInstructions: store.suggestedDeliveryInstructions(for: item), packageContents: store.suggestedPackageContents(for: item), costRecords: store.suggestedCostRecords(for: item), returnClaims: store.suggestedReturnClaims(for: item), procurementRequests: store.suggestedProcurementRequests(for: item), receivingInspections: store.suggestedReceivingInspections(for: item), inventoryReceipts: store.suggestedInventoryReceipts(for: item), storageLocations: store.suggestedStorageLocations(for: item), custodyRecords: store.suggestedCustodyRecords(for: item), labelReferences: store.suggestedLabelReferenceRecords(for: item), scanSessions: store.suggestedScanSessionRecords(for: item), shipmentManifests: store.suggestedShipmentManifestRecords(for: item), dispatchChecklists: store.suggestedDispatchReadinessChecklists(for: item)) {
                store.createReviewTask(from: item)
              } onCreateDraft: {
                store.createDraftMessage(from: item)
              } onReviewed: {
                store.markWorkbenchItemReviewed(item)
              }
            }
          }
        }
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
        Text("Actionable local work across tasks, handoffs, intake, import, acceptance, exceptions, validation, tracking, evidence, policies, drafts, contacts, accounts, and profiles.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(store.openWorkbenchItems.count) open", color: .blue)
        Badge("\(store.highPriorityWorkbenchItems.count) high", color: .orange)
      }
    }
  }

  private var filters: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
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
      }
      HStack {
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
      }
      HStack {
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
    .pickerStyle(.menu)
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
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

      HStack {
        Label(item.assignee, systemImage: "person.2.fill")
        Label(item.dueDateText, systemImage: "calendar")
        Label(item.linkedEntityType.rawValue, systemImage: item.linkedEntityType.symbol)
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      HStack {
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill", action: onCreateDraft)
          .buttonStyle(.bordered)
        if item.supportsReviewAction {
          Button("Reviewed", systemImage: "checkmark.circle.fill", action: onReviewed)
            .buttonStyle(.bordered)
        }
        Spacer()
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
