import SwiftUI

struct InventoryReceiptsView: View {
  var store: ParcelOpsStore
  @State private var selectedReceiptType: InventoryReceiptType?
  @State private var selectedStatus: InventoryStockHandoffStatus?
  @State private var ownerTeam = ""
  @State private var selectedRiskLevel: ShipmentRiskLevel?
  @State private var selectedLinkedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedReviewState: ReviewState?
  @State private var receiptSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var baseFilteredReceipts: [InventoryReceiptRecord] {
    store.filteredInventoryReceipts(
      receiptType: selectedReceiptType,
      stockHandoffStatus: selectedStatus,
      ownerTeam: ownerTeam,
      riskLevel: selectedRiskLevel,
      linkedEntityType: selectedLinkedEntityType,
      reviewState: selectedReviewState
    )
  }

  private var filteredReceipts: [InventoryReceiptRecord] {
    let query = receiptSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredReceipts }
    return baseFilteredReceipts.filter { receipt in
      inventoryReceipt(receipt, matches: query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedReceiptType != nil
      || selectedStatus != nil
      || !ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || selectedRiskLevel != nil
      || selectedLinkedEntityType != nil
      || selectedReviewState != nil
      || !receiptSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filterBar

        SettingsPanel(title: "Inventory receipt records", symbol: "archivebox.fill") {
          HStack {
            Text("\(filteredReceipts.count) visible inventory receipts")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredReceipts.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add receipt", systemImage: "plus", action: store.addInventoryReceiptPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredReceipts.isEmpty {
            MVPEmptyState(title: "No inventory receipts match this view", detail: hasActiveFilters ? "Clear search or filters to return to all local inventory receipts." : "Add an inventory receipt to track received stock, accepted/rejected quantities, storage, and handoff status.", symbol: "archivebox.fill", actionTitle: hasActiveFilters ? "Clear filters" : "Add receipt", action: hasActiveFilters ? clearFilters : store.addInventoryReceiptPlaceholder)
          } else {
            ForEach(filteredReceipts) { receipt in
              InventoryReceiptRow(receipt: receipt, store: store, linkedOrder: linkedOrder(for: receipt), storageLocations: store.suggestedStorageLocations(for: receipt), custodyRecords: store.suggestedCustodyRecords(for: receipt), labelReferences: store.suggestedLabelReferenceRecords(for: receipt), scanSessions: store.suggestedScanSessionRecords(for: receipt), shipmentManifests: store.suggestedShipmentManifestRecords(for: receipt), dispatchChecklists: store.suggestedDispatchReadinessChecklists(for: receipt)) { updatedReceipt in
                store.updateInventoryReceipt(updatedReceipt)
              } onStocked: {
                store.markInventoryReceiptStocked(receipt)
              } onHandedOff: {
                store.markInventoryReceiptHandedOff(receipt)
              } onPartiallyAccepted: {
                store.markInventoryReceiptPartiallyAccepted(receipt)
              } onRejected: {
                store.markInventoryReceiptRejected(receipt)
              } onReviewed: {
                store.markInventoryReceiptReviewed(receipt)
              } onCreateTask: {
                store.createReviewTask(from: receipt)
              } onCreateDraft: {
                store.createDraftMessage(from: receipt)
              } onRemove: {
                store.removeInventoryReceipt(receipt)
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
        Text("Inventory Receipts")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Local stock receipt, storage assignment, acceptance, rejection, and team handoff tracking.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(store.rejectedInventoryReceipts.count) rejected", color: .red)
        Badge("\(store.inventoryReceiptsMissingStorage.count) missing storage", color: .orange)
      }
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search receipt, item, owner, storage, order, custody, label, scan, or dispatch", text: $receiptSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Type", selection: $selectedReceiptType) {
        Text("All types").tag(nil as InventoryReceiptType?)
        ForEach(InventoryReceiptType.allCases) { type in
          Text(type.rawValue).tag(type as InventoryReceiptType?)
        }
      }

      Picker("Status", selection: $selectedStatus) {
        Text("All status").tag(nil as InventoryStockHandoffStatus?)
        ForEach(InventoryStockHandoffStatus.allCases) { status in
          Text(status.rawValue).tag(status as InventoryStockHandoffStatus?)
        }
      }

      TextField("Owner/team", text: $ownerTeam)
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
    selectedReceiptType = nil
    selectedStatus = nil
    ownerTeam = ""
    selectedRiskLevel = nil
    selectedLinkedEntityType = nil
    selectedReviewState = nil
    receiptSearchText = ""
  }

  private func linkedOrder(for receipt: InventoryReceiptRecord) -> TrackedOrder? {
    let orderID = receipt.orderID ?? (receipt.linkedEntityType == .order ? UUID(uuidString: receipt.linkedEntityID) : nil)
    guard let orderID else { return nil }
    return store.orders.first { $0.id == orderID }
  }

  private func inventoryReceipt(_ receipt: InventoryReceiptRecord, matches query: String) -> Bool {
    let order = linkedOrder(for: receipt)
    let storageLocations = store.suggestedStorageLocations(for: receipt)
    let custodyRecords = store.suggestedCustodyRecords(for: receipt)
    let labelReferences = store.suggestedLabelReferenceRecords(for: receipt)
    let scanSessions = store.suggestedScanSessionRecords(for: receipt)
    let shipmentManifests = store.suggestedShipmentManifestRecords(for: receipt)
    let dispatchChecklists = store.suggestedDispatchReadinessChecklists(for: receipt)
    var searchParts: [String] = [
      receipt.id.uuidString,
      receipt.title,
      receipt.linkedEntityType.rawValue,
      receipt.linkedEntityID,
      receipt.receivingInspectionID?.uuidString ?? "",
      receipt.orderID?.uuidString ?? "",
      receipt.shipmentGroupID?.uuidString ?? "",
      receipt.packageContentID?.uuidString ?? "",
      receipt.procurementRequestID?.uuidString ?? "",
      receipt.returnClaimID?.uuidString ?? "",
      receipt.destinationAddressID?.uuidString ?? "",
      receipt.customerProfileID?.uuidString ?? "",
      receipt.receiptType.rawValue,
      receipt.stockHandoffStatus.rawValue,
      receipt.itemSummary,
      "\(receipt.quantityReceived)",
      "\(receipt.quantityAccepted)",
      "\(receipt.quantityRejected)",
      receipt.storageLocationSummary,
      receipt.assignedOwnerTeam,
      receipt.receivedDate,
      receipt.handoffDate,
      receipt.discrepancySummary,
      receipt.riskLevel.rawValue,
      receipt.createdDate,
      receipt.lastReviewedDate,
      receipt.reviewState.rawValue,
      order?.orderNumber ?? "",
      order?.store ?? "",
      order?.customer ?? "",
      order?.recipientEmail ?? "",
      order?.trackingNumber ?? "",
      order?.carrier ?? "",
      order?.destination ?? ""
    ]
    searchParts.append(contentsOf: receipt.evidenceAttachmentIDs.map(\.uuidString))
    searchParts.append(contentsOf: storageLocations.map(\.title))
    searchParts.append(contentsOf: storageLocations.map(\.locationCode))
    searchParts.append(contentsOf: custodyRecords.map(\.title))
    searchParts.append(contentsOf: labelReferences.map(\.title))
    searchParts.append(contentsOf: scanSessions.map(\.title))
    searchParts.append(contentsOf: shipmentManifests.map(\.title))
    searchParts.append(contentsOf: dispatchChecklists.map(\.title))
    let searchableText = searchParts.joined(separator: " ")
    return searchableText.localizedLowercase.contains(query)
  }
}

struct InventoryReceiptRow: View {
  var receipt: InventoryReceiptRecord
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
  var storageLocations: [StorageLocationRecord] = []
  var custodyRecords: [CustodyRecord] = []
  var labelReferences: [LabelReferenceRecord] = []
  var scanSessions: [ScanSessionRecord] = []
  var shipmentManifests: [ShipmentManifestRecord] = []
  var dispatchChecklists: [DispatchReadinessChecklist] = []
  var onSave: (InventoryReceiptRecord) -> Void
  var onStocked: () -> Void
  var onHandedOff: () -> Void
  var onPartiallyAccepted: () -> Void
  var onRejected: () -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: receipt.receiptType.symbol)
          .foregroundStyle(receipt.riskLevel.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(receipt.title)
                .font(.headline)
              Text("\(receipt.receiptType.rawValue) • \(receipt.quantityAccepted)/\(receipt.quantityReceived) accepted")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(receipt.stockHandoffStatus.rawValue, color: receipt.stockHandoffStatus.color)
          }

          Text(receipt.itemSummary)
            .foregroundStyle(.secondary)
          Text("\(receipt.storageLocationSummary) • Owner \(receipt.assignedOwnerTeam)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          HStack(spacing: 8) {
            Badge(receipt.riskLevel.rawValue, color: receipt.riskLevel.color)
            Badge(receipt.reviewState.rawValue, color: receipt.reviewState.color)
            Label("Rejected \(receipt.quantityRejected)", systemImage: "xmark.circle.fill")
              .font(.caption)
              .foregroundStyle(.secondary)
            Label(receipt.linkedEntityType.rawValue, systemImage: receipt.linkedEntityType.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      StorageLocationStrip(locations: storageLocations)
      CustodyRecordStrip(records: custodyRecords)
      LabelReferenceStrip(records: labelReferences)
      ScanSessionStrip(records: scanSessions)

      HStack {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Stocked", systemImage: "archivebox.fill", action: onStocked)
          .buttonStyle(.bordered)
        Button("Handed off", systemImage: "arrow.left.arrow.right.square.fill", action: onHandedOff)
          .buttonStyle(.bordered)
        Button("Partial", systemImage: "plusminus.circle.fill", action: onPartiallyAccepted)
          .buttonStyle(.bordered)
        Button("Reject", systemImage: "xmark.circle.fill", action: onRejected)
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.shield.fill", action: onReviewed)
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
      InventoryReceiptEditView(receipt: receipt) { updatedReceipt in
        onSave(updatedReceipt)
      }
    }
  }
}

struct InventoryReceiptEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: InventoryReceiptRecord
  var onSave: (InventoryReceiptRecord) -> Void

  init(receipt: InventoryReceiptRecord, onSave: @escaping (InventoryReceiptRecord) -> Void) {
    self._draft = State(initialValue: receipt)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Receipt") {
          TextField("Title", text: $draft.title)
          TextField("Item summary", text: $draft.itemSummary, axis: .vertical)
          Picker("Type", selection: $draft.receiptType) {
            ForEach(InventoryReceiptType.allCases) { type in
              Text(type.rawValue).tag(type)
            }
          }
          Picker("Stock/handoff status", selection: $draft.stockHandoffStatus) {
            ForEach(InventoryStockHandoffStatus.allCases) { status in
              Text(status.rawValue).tag(status)
            }
          }
        }

        Section("Quantities and location") {
          Stepper("Received: \(draft.quantityReceived)", value: $draft.quantityReceived, in: 0...999)
          Stepper("Accepted: \(draft.quantityAccepted)", value: $draft.quantityAccepted, in: 0...999)
          Stepper("Rejected: \(draft.quantityRejected)", value: $draft.quantityRejected, in: 0...999)
          TextField("Storage/location", text: $draft.storageLocationSummary, axis: .vertical)
          TextField("Discrepancy summary", text: $draft.discrepancySummary, axis: .vertical)
        }

        Section("Ownership and dates") {
          TextField("Owner/team", text: $draft.assignedOwnerTeam)
          TextField("Received date", text: $draft.receivedDate)
          TextField("Handoff date", text: $draft.handoffDate)
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
      .navigationTitle("Edit Receipt")
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
