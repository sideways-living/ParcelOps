import SwiftUI

struct ReceivingInspectionsView: View {
  var store: ParcelOpsStore
  @State private var selectedInspectionType: ReceivingInspectionType?
  @State private var selectedInspectionStatus: ReceivingInspectionStatus?
  @State private var selectedDiscrepancyType: ReceivingDiscrepancyType?
  @State private var inspectorTeam = ""
  @State private var selectedRiskLevel: ShipmentRiskLevel?
  @State private var selectedLinkedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedReviewState: ReviewState?
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var filteredInspections: [ReceivingInspectionRecord] {
    store.filteredReceivingInspections(
      inspectionType: selectedInspectionType,
      inspectionStatus: selectedInspectionStatus,
      discrepancyType: selectedDiscrepancyType,
      inspectorTeam: inspectorTeam,
      riskLevel: selectedRiskLevel,
      linkedEntityType: selectedLinkedEntityType,
      reviewState: selectedReviewState
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filterBar

        SettingsPanel(title: "Receiving inspection records", symbol: "checklist.checked") {
          HStack {
            Text("\(filteredInspections.count) visible receiving inspections")
              .font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            Button("Add inspection", systemImage: "plus", action: store.addReceivingInspectionPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredInspections.isEmpty {
            Text("No receiving inspections match the selected filters.")
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(12)
              .background(.quinary)
              .clipShape(RoundedRectangle(cornerRadius: 8))
          } else {
            ForEach(filteredInspections) { inspection in
              ReceivingInspectionRow(inspection: inspection, store: store, linkedOrder: linkedOrder(for: inspection), inventoryReceipts: store.suggestedInventoryReceipts(for: inspection), storageLocations: store.suggestedStorageLocations(for: inspection), custodyRecords: store.suggestedCustodyRecords(for: inspection), labelReferences: store.suggestedLabelReferenceRecords(for: inspection), scanSessions: store.suggestedScanSessionRecords(for: inspection), shipmentManifests: store.suggestedShipmentManifestRecords(for: inspection), dispatchChecklists: store.suggestedDispatchReadinessChecklists(for: inspection)) { updatedInspection in
                store.updateReceivingInspection(updatedInspection)
              } onInspected: {
                store.markReceivingInspectionInspected(inspection)
              } onDiscrepancy: {
                store.markReceivingInspectionDiscrepancy(inspection)
              } onResolved: {
                store.markReceivingInspectionResolved(inspection)
              } onBlocked: {
                store.markReceivingInspectionBlocked(inspection)
              } onReviewed: {
                store.markReceivingInspectionReviewed(inspection)
              } onCreateTask: {
                store.createReviewTask(from: inspection)
              } onCreateDraft: {
                store.createDraftMessage(from: inspection)
              } onRemove: {
                store.removeReceivingInspection(inspection)
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
        Text("Receiving Inspections")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Local package receipt, condition checks, quantity discrepancies, and inspection follow-up.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(store.unresolvedInspectionDiscrepancies.count) discrepancies", color: .red)
        Badge("\(store.blockedReceivingInspections.count) blocked", color: .purple)
      }
    }
  }

  private var filterBar: some View {
    HStack {
      Picker("Type", selection: $selectedInspectionType) {
        Text("All types").tag(nil as ReceivingInspectionType?)
        ForEach(ReceivingInspectionType.allCases) { type in
          Text(type.rawValue).tag(type as ReceivingInspectionType?)
        }
      }
      .pickerStyle(.menu)

      Picker("Status", selection: $selectedInspectionStatus) {
        Text("All status").tag(nil as ReceivingInspectionStatus?)
        ForEach(ReceivingInspectionStatus.allCases) { status in
          Text(status.rawValue).tag(status as ReceivingInspectionStatus?)
        }
      }
      .pickerStyle(.menu)

      Picker("Discrepancy", selection: $selectedDiscrepancyType) {
        Text("All discrepancy").tag(nil as ReceivingDiscrepancyType?)
        ForEach(ReceivingDiscrepancyType.allCases) { type in
          Text(type.rawValue).tag(type as ReceivingDiscrepancyType?)
        }
      }
      .pickerStyle(.menu)

      TextField("Inspector/team", text: $inspectorTeam)
        .textFieldStyle(.roundedBorder)
        .frame(maxWidth: 150)

      Picker("Risk", selection: $selectedRiskLevel) {
        Text("All risk").tag(nil as ShipmentRiskLevel?)
        ForEach(ShipmentRiskLevel.allCases) { risk in
          Text(risk.rawValue).tag(risk as ShipmentRiskLevel?)
        }
      }
      .pickerStyle(.menu)

      Picker("Linked", selection: $selectedLinkedEntityType) {
        Text("All links").tag(nil as ReviewTaskLinkedEntityType?)
        ForEach(ReviewTaskLinkedEntityType.allCases) { type in
          Text(type.rawValue).tag(type as ReviewTaskLinkedEntityType?)
        }
      }
      .pickerStyle(.menu)

      Picker("Review", selection: $selectedReviewState) {
        Text("All review").tag(nil as ReviewState?)
        ForEach(reviewStates, id: \.self) { state in
          Text(state.rawValue).tag(state as ReviewState?)
        }
      }
      .pickerStyle(.menu)

      Spacer()

      Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle") {
        selectedInspectionType = nil
        selectedInspectionStatus = nil
        selectedDiscrepancyType = nil
        inspectorTeam = ""
        selectedRiskLevel = nil
        selectedLinkedEntityType = nil
        selectedReviewState = nil
      }
      .buttonStyle(.bordered)
    }
  }

  private func linkedOrder(for inspection: ReceivingInspectionRecord) -> TrackedOrder? {
    let orderID = inspection.orderID ?? (inspection.linkedEntityType == .order ? UUID(uuidString: inspection.linkedEntityID) : nil)
    guard let orderID else { return nil }
    return store.orders.first { $0.id == orderID }
  }
}

struct ReceivingInspectionRow: View {
  var inspection: ReceivingInspectionRecord
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
  var inventoryReceipts: [InventoryReceiptRecord] = []
  var storageLocations: [StorageLocationRecord] = []
  var custodyRecords: [CustodyRecord] = []
  var labelReferences: [LabelReferenceRecord] = []
  var scanSessions: [ScanSessionRecord] = []
  var shipmentManifests: [ShipmentManifestRecord] = []
  var dispatchChecklists: [DispatchReadinessChecklist] = []
  var onSave: (ReceivingInspectionRecord) -> Void
  var onInspected: () -> Void
  var onDiscrepancy: () -> Void
  var onResolved: () -> Void
  var onBlocked: () -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: inspection.inspectionType.symbol)
          .foregroundStyle(inspection.riskLevel.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(inspection.title)
                .font(.headline)
              Text("\(inspection.inspectionType.rawValue) • \(inspection.quantityReceived)/\(inspection.quantityExpected) received")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(inspection.inspectionStatus.rawValue, color: inspection.inspectionStatus.color)
          }

          Text(inspection.expectedItemSummary)
            .foregroundStyle(.secondary)
          Text(inspection.discrepancyType == .none ? inspection.conditionSummary : inspection.discrepancySummary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          HStack(spacing: 8) {
            Badge(inspection.discrepancyType.rawValue, color: inspection.discrepancyType.color)
            Badge(inspection.riskLevel.rawValue, color: inspection.riskLevel.color)
            Badge(inspection.reviewState.rawValue, color: inspection.reviewState.color)
            Label("Due \(inspection.dueDate)", systemImage: "calendar")
              .font(.caption)
              .foregroundStyle(.secondary)
            Label(inspection.linkedEntityType.rawValue, systemImage: inspection.linkedEntityType.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      InventoryReceiptStrip(receipts: inventoryReceipts)
      StorageLocationStrip(locations: storageLocations)
      CustodyRecordStrip(records: custodyRecords)
      LabelReferenceStrip(records: labelReferences)
      ScanSessionStrip(records: scanSessions)

      HStack {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Inspected", systemImage: "checkmark.seal.fill", action: onInspected)
          .buttonStyle(.bordered)
        Button("Discrepancy", systemImage: "exclamationmark.triangle.fill", action: onDiscrepancy)
          .buttonStyle(.bordered)
        Button("Resolved", systemImage: "checkmark.circle.fill", action: onResolved)
          .buttonStyle(.bordered)
        Button("Blocked", systemImage: "hand.raised.fill", action: onBlocked)
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
      ReceivingInspectionEditView(inspection: inspection) { updatedInspection in
        onSave(updatedInspection)
      }
    }
  }
}

struct ReceivingInspectionEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: ReceivingInspectionRecord
  var onSave: (ReceivingInspectionRecord) -> Void

  init(inspection: ReceivingInspectionRecord, onSave: @escaping (ReceivingInspectionRecord) -> Void) {
    self._draft = State(initialValue: inspection)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Inspection") {
          TextField("Title", text: $draft.title)
          TextField("Expected items", text: $draft.expectedItemSummary, axis: .vertical)
          TextField("Received items", text: $draft.receivedItemSummary, axis: .vertical)
          Picker("Type", selection: $draft.inspectionType) {
            ForEach(ReceivingInspectionType.allCases) { type in
              Text(type.rawValue).tag(type)
            }
          }
          Picker("Status", selection: $draft.inspectionStatus) {
            ForEach(ReceivingInspectionStatus.allCases) { status in
              Text(status.rawValue).tag(status)
            }
          }
        }

        Section("Quantity and condition") {
          Stepper("Expected quantity: \(draft.quantityExpected)", value: $draft.quantityExpected, in: 0...999)
          Stepper("Received quantity: \(draft.quantityReceived)", value: $draft.quantityReceived, in: 0...999)
          TextField("Condition summary", text: $draft.conditionSummary, axis: .vertical)
          Picker("Discrepancy type", selection: $draft.discrepancyType) {
            ForEach(ReceivingDiscrepancyType.allCases) { type in
              Text(type.rawValue).tag(type)
            }
          }
          TextField("Discrepancy summary", text: $draft.discrepancySummary, axis: .vertical)
        }

        Section("Review") {
          TextField("Inspector/team", text: $draft.assignedInspectorTeam)
          TextField("Inspection date", text: $draft.inspectionDate)
          TextField("Due date", text: $draft.dueDate)
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
      .navigationTitle("Edit Inspection")
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
