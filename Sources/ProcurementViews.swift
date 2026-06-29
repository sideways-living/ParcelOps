import SwiftUI

struct ProcurementView: View {
  var store: ParcelOpsStore
  @State private var selectedApprovalStatus: ProcurementApprovalStatus?
  @State private var selectedProcurementStatus: ProcurementStatus?
  @State private var requesterTeam = ""
  @State private var assignedBuyerTeam = ""
  @State private var budgetCode = ""
  @State private var selectedRiskLevel: ShipmentRiskLevel?
  @State private var selectedLinkedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedReviewState: ReviewState?
  @State private var procurementSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var baseFilteredRequests: [ProcurementRequest] {
    store.filteredProcurementRequests(
      approvalStatus: selectedApprovalStatus,
      procurementStatus: selectedProcurementStatus,
      requesterTeam: requesterTeam,
      assignedBuyerTeam: assignedBuyerTeam,
      budgetCode: budgetCode,
      riskLevel: selectedRiskLevel,
      linkedEntityType: selectedLinkedEntityType,
      reviewState: selectedReviewState
    )
  }

  private var filteredRequests: [ProcurementRequest] {
    let query = procurementSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return baseFilteredRequests }
    return baseFilteredRequests.filter { request in
      procurementRequest(request, matches: query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedApprovalStatus != nil
      || selectedProcurementStatus != nil
      || !requesterTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !assignedBuyerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !budgetCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || selectedRiskLevel != nil
      || selectedLinkedEntityType != nil
      || selectedReviewState != nil
      || !procurementSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filterBar

        SettingsPanel(title: "Procurement requests", symbol: "cart.badge.plus") {
          HStack {
            Text("\(filteredRequests.count) visible procurement requests")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredRequests.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add request", systemImage: "plus", action: store.addProcurementRequestPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredRequests.isEmpty {
            MVPEmptyState(title: "No procurement requests match this view", detail: hasActiveFilters ? "Clear search or filters to return to all local procurement requests." : "Add a local procurement request to track approval, buyer assignment, ordering, receiving, and budget follow-up.", symbol: "cart.badge.plus", actionTitle: hasActiveFilters ? "Clear filters" : "Add request", action: hasActiveFilters ? clearFilters : store.addProcurementRequestPlaceholder)
          } else {
            ForEach(filteredRequests) { request in
              ProcurementRequestRow(request: request, store: store, linkedOrder: linkedOrder(for: request), receivingInspections: store.suggestedReceivingInspections(for: request), inventoryReceipts: store.suggestedInventoryReceipts(for: request), storageLocations: store.suggestedStorageLocations(for: request), custodyRecords: store.suggestedCustodyRecords(for: request), labelReferences: store.suggestedLabelReferenceRecords(for: request), scanSessions: store.suggestedScanSessionRecords(for: request), shipmentManifests: store.suggestedShipmentManifestRecords(for: request), dispatchChecklists: store.suggestedDispatchReadinessChecklists(for: request)) { updatedRequest in
                store.updateProcurementRequest(updatedRequest)
              } onApproved: {
                store.markProcurementRequestApproved(request)
              } onOrdered: {
                store.markProcurementRequestOrdered(request)
              } onReceived: {
                store.markProcurementRequestReceived(request)
              } onRejected: {
                store.markProcurementRequestRejected(request)
              } onReviewed: {
                store.markProcurementRequestReviewed(request)
              } onCreateTask: {
                store.createReviewTask(from: request)
              } onCreateDraft: {
                store.createDraftMessage(from: request)
              } onRemove: {
                store.removeProcurementRequest(request)
              }
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Procurement")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Local request, budget, approval, ordering, and receiving workflow tracking.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(store.unapprovedProcurementRequests.count) unapproved", color: .orange)
        Badge("\(store.rejectedProcurementRequests.count) rejected", color: .red)
      }
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search request, item, budget, requester, buyer, order, receiving, storage, or dispatch", text: $procurementSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Approval", selection: $selectedApprovalStatus) {
        Text("All approval").tag(nil as ProcurementApprovalStatus?)
        ForEach(ProcurementApprovalStatus.allCases) { status in
          Text(status.rawValue).tag(status as ProcurementApprovalStatus?)
        }
      }

      Picker("Procurement", selection: $selectedProcurementStatus) {
        Text("All status").tag(nil as ProcurementStatus?)
        ForEach(ProcurementStatus.allCases) { status in
          Text(status.rawValue).tag(status as ProcurementStatus?)
        }
      }

      TextField("Requester/team", text: $requesterTeam)
        .textFieldStyle(.roundedBorder)

      TextField("Buyer/team", text: $assignedBuyerTeam)
        .textFieldStyle(.roundedBorder)

      TextField("Budget", text: $budgetCode)
        .textFieldStyle(.roundedBorder)

      Picker("Risk", selection: $selectedRiskLevel) {
        Text("All risk").tag(nil as ShipmentRiskLevel?)
        ForEach(ShipmentRiskLevel.allCases) { risk in
          Text(risk.rawValue).tag(risk as ShipmentRiskLevel?)
        }
      }

      Picker("Linked", selection: $selectedLinkedEntityType) {
        Text("All links").tag(nil as ReviewTaskLinkedEntityType?)
        ForEach(ReviewTaskLinkedEntityType.allCases) { type in
          Text(type.rawValue).tag(type as ReviewTaskLinkedEntityType?)
        }
      }

      Picker("Review", selection: $selectedReviewState) {
        Text("All review").tag(nil as ReviewState?)
        ForEach(reviewStates, id: \.self) { state in
          Text(state.rawValue).tag(state as ReviewState?)
        }
      }

      if hasActiveFilters {
        Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle") {
          clearFilters()
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private func clearFilters() {
    selectedApprovalStatus = nil
    selectedProcurementStatus = nil
    requesterTeam = ""
    assignedBuyerTeam = ""
    budgetCode = ""
    selectedRiskLevel = nil
    selectedLinkedEntityType = nil
    selectedReviewState = nil
    procurementSearchText = ""
  }

  private func linkedOrder(for request: ProcurementRequest) -> TrackedOrder? {
    guard request.linkedEntityType == .order,
          let orderID = UUID(uuidString: request.linkedEntityID) else { return nil }
    return store.orders.first { $0.id == orderID }
  }

  private func procurementRequest(_ request: ProcurementRequest, matches query: String) -> Bool {
    let order = linkedOrder(for: request)
    let receivingInspections = store.suggestedReceivingInspections(for: request)
    let inventoryReceipts = store.suggestedInventoryReceipts(for: request)
    let storageLocations = store.suggestedStorageLocations(for: request)
    let custodyRecords = store.suggestedCustodyRecords(for: request)
    let labelReferences = store.suggestedLabelReferenceRecords(for: request)
    let scanSessions = store.suggestedScanSessionRecords(for: request)
    let shipmentManifests = store.suggestedShipmentManifestRecords(for: request)
    let dispatchChecklists = store.suggestedDispatchReadinessChecklists(for: request)
    var searchParts: [String] = [
      request.id.uuidString,
      request.title,
      request.linkedEntityType.rawValue,
      request.linkedEntityID,
      request.requesterTeam,
      request.requestedDate,
      request.neededByDate,
      request.vendorProfileID?.uuidString ?? "",
      request.accountID?.uuidString ?? "",
      request.customerProfileID?.uuidString ?? "",
      request.destinationAddressID?.uuidString ?? "",
      request.packageContentID?.uuidString ?? "",
      request.costRecordID?.uuidString ?? "",
      request.returnClaimID?.uuidString ?? "",
      request.requestedItemsSummary,
      request.estimatedCostText,
      request.currency,
      request.budgetCode,
      request.approvalStatus.rawValue,
      request.procurementStatus.rawValue,
      request.assignedBuyerTeam,
      request.notes,
      request.riskLevel.rawValue,
      request.createdDate,
      request.lastReviewedDate,
      request.reviewState.rawValue,
      order?.orderNumber ?? "",
      order?.store ?? "",
      order?.customer ?? "",
      order?.recipientEmail ?? "",
      order?.trackingNumber ?? "",
      order?.carrier ?? "",
      order?.destination ?? ""
    ]
    searchParts.append(contentsOf: request.evidenceAttachmentIDs.map(\.uuidString))
    searchParts.append(contentsOf: receivingInspections.map(\.title))
    searchParts.append(contentsOf: inventoryReceipts.map(\.title))
    searchParts.append(contentsOf: storageLocations.map(\.title))
    searchParts.append(contentsOf: custodyRecords.map(\.title))
    searchParts.append(contentsOf: labelReferences.map(\.title))
    searchParts.append(contentsOf: scanSessions.map(\.title))
    searchParts.append(contentsOf: shipmentManifests.map(\.title))
    searchParts.append(contentsOf: dispatchChecklists.map(\.title))
    let searchableText = searchParts.joined(separator: " ")
    return searchableText.localizedCaseInsensitiveContains(query)
  }
}

struct ProcurementRequestRow: View {
  var request: ProcurementRequest
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
  var receivingInspections: [ReceivingInspectionRecord] = []
  var inventoryReceipts: [InventoryReceiptRecord] = []
  var storageLocations: [StorageLocationRecord] = []
  var custodyRecords: [CustodyRecord] = []
  var labelReferences: [LabelReferenceRecord] = []
  var scanSessions: [ScanSessionRecord] = []
  var shipmentManifests: [ShipmentManifestRecord] = []
  var dispatchChecklists: [DispatchReadinessChecklist] = []
  var onSave: (ProcurementRequest) -> Void
  var onApproved: () -> Void
  var onOrdered: () -> Void
  var onReceived: () -> Void
  var onRejected: () -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: request.procurementStatus.symbol)
          .foregroundStyle(request.riskLevel.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(request.title)
                .font(.headline)
              Text("\(request.estimatedCostText) \(request.currency) • \(request.budgetCode)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(request.approvalStatus.rawValue, color: request.approvalStatus.color)
          }

          Text(request.requestedItemsSummary)
            .foregroundStyle(.secondary)
          Text("Requester \(request.requesterTeam) • Buyer \(request.assignedBuyerTeam) • Needed \(request.neededByDate)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          HStack(spacing: 8) {
            Badge(request.procurementStatus.rawValue, color: request.procurementStatus.color)
            Badge(request.riskLevel.rawValue, color: request.riskLevel.color)
            Badge(request.reviewState.rawValue, color: request.reviewState.color)
            Label(request.linkedEntityType.rawValue, systemImage: request.linkedEntityType.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      ReceivingInspectionStrip(inspections: receivingInspections)
      InventoryReceiptStrip(receipts: inventoryReceipts)
      StorageLocationStrip(locations: storageLocations)
      CustodyRecordStrip(records: custodyRecords)
      LabelReferenceStrip(records: labelReferences)
      ScanSessionStrip(records: scanSessions)

      HStack {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Approved", systemImage: "checkmark.seal.fill", action: onApproved)
          .buttonStyle(.bordered)
        Button("Ordered", systemImage: "cart.fill", action: onOrdered)
          .buttonStyle(.bordered)
        Button("Received", systemImage: "shippingbox.fill", action: onReceived)
          .buttonStyle(.bordered)
        Button("Reject", systemImage: "xmark.circle.fill", action: onRejected)
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.circle.fill", action: onReviewed)
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill", action: onCreateDraft)
          .buttonStyle(.bordered)
        if let store, let linkedOrder {
          NavigationLink {
            OrderDetailView(order: linkedOrder, store: store)
          } label: {
            Label("Open order", systemImage: "arrow.up.right.square.fill")
          }
          .buttonStyle(.bordered)
        }
        Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      ProcurementRequestEditView(request: request) { updatedRequest in
        onSave(updatedRequest)
      }
    }
  }
}

struct ProcurementRequestEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: ProcurementRequest
  var onSave: (ProcurementRequest) -> Void

  init(request: ProcurementRequest, onSave: @escaping (ProcurementRequest) -> Void) {
    self._draft = State(initialValue: request)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Request") {
          TextField("Title", text: $draft.title)
          TextField("Requested items", text: $draft.requestedItemsSummary, axis: .vertical)
          TextField("Requester/team", text: $draft.requesterTeam)
          TextField("Requested date", text: $draft.requestedDate)
          TextField("Needed by", text: $draft.neededByDate)
        }

        Section("Budget and buyer") {
          TextField("Estimated cost", text: $draft.estimatedCostText)
          TextField("Currency", text: $draft.currency)
          TextField("Budget code", text: $draft.budgetCode)
          TextField("Assigned buyer/team", text: $draft.assignedBuyerTeam)
          Picker("Approval", selection: $draft.approvalStatus) {
            ForEach(ProcurementApprovalStatus.allCases) { status in
              Text(status.rawValue).tag(status)
            }
          }
          Picker("Procurement status", selection: $draft.procurementStatus) {
            ForEach(ProcurementStatus.allCases) { status in
              Text(status.rawValue).tag(status)
            }
          }
        }

        Section("Review") {
          Picker("Risk", selection: $draft.riskLevel) {
            ForEach(ShipmentRiskLevel.allCases) { risk in
              Text(risk.rawValue).tag(risk)
            }
          }
          Picker("Review state", selection: $draft.reviewState) {
            ForEach([ReviewState.needsReview, .monitor, .accepted], id: \.self) { state in
              Text(state.rawValue).tag(state)
            }
          }
          TextField("Last reviewed", text: $draft.lastReviewedDate)
          TextField("Notes", text: $draft.notes, axis: .vertical)
        }

        Section("Link") {
          Picker("Linked record type", selection: $draft.linkedEntityType) {
            ForEach(ReviewTaskLinkedEntityType.allCases) { type in
              Text(type.rawValue).tag(type)
            }
          }
          TextField("Linked record ID", text: $draft.linkedEntityID)
        }
      }
      .navigationTitle("Edit Procurement")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: { dismiss() })
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            onSave(draft)
            dismiss()
          }
        }
      }
    }
    .frame(minWidth: 580, minHeight: 620)
  }
}
