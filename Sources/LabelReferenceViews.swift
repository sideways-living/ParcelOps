import SwiftUI

struct LabelReferencesView: View {
  var store: ParcelOpsStore
  @State private var selectedType: LabelReferenceType?
  @State private var selectedStatus: LabelReferenceStatus?
  @State private var selectedSource: LabelReferenceSource?
  @State private var carrier = ""
  @State private var ownerTeam = ""
  @State private var selectedRiskLevel: ShipmentRiskLevel?
  @State private var selectedLinkedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedReviewState: ReviewState?
  @State private var labelSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var baseFilteredRecords: [LabelReferenceRecord] {
    store.filteredLabelReferenceRecords(labelType: selectedType, labelStatus: selectedStatus, labelSource: selectedSource, carrier: carrier, ownerTeam: ownerTeam, riskLevel: selectedRiskLevel, linkedEntityType: selectedLinkedEntityType, reviewState: selectedReviewState)
  }

  private var filteredRecords: [LabelReferenceRecord] {
    let query = labelSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredRecords }
    return baseFilteredRecords.filter { labelReference($0, matches: query) }
  }

  private var hasActiveFilters: Bool {
    selectedType != nil
      || selectedStatus != nil
      || selectedSource != nil
      || !carrier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || selectedRiskLevel != nil
      || selectedLinkedEntityType != nil
      || selectedReviewState != nil
      || !labelSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filterBar

        SettingsPanel(title: "Label reference records", symbol: "barcode.viewfinder") {
          HStack {
            Text("\(filteredRecords.count) visible label references")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredRecords.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add label", systemImage: "plus", action: store.addLabelReferencePlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredRecords.isEmpty {
            MVPEmptyState(title: "No label references match this view", detail: hasActiveFilters ? "Clear search or filters to return to all local label references." : "Add a local label placeholder to track barcodes, QR codes, shelf labels, return labels, custody labels, or evidence labels.", symbol: "barcode.viewfinder", actionTitle: hasActiveFilters ? "Clear filters" : "Add label", action: hasActiveFilters ? clearFilters : store.addLabelReferencePlaceholder)
          } else {
            ForEach(filteredRecords) { record in
              LabelReferenceRow(record: record, store: store, linkedOrder: linkedOrder(for: record), scanSessions: store.suggestedScanSessionRecords(for: record), shipmentManifests: store.suggestedShipmentManifestRecords(for: record), dispatchChecklists: store.suggestedDispatchReadinessChecklists(for: record)) { updatedRecord in
                store.updateLabelReferenceRecord(updatedRecord)
              } onPrinted: {
                store.markLabelReferencePrinted(record)
              } onVerified: {
                store.markLabelReferenceVerified(record)
              } onInvalid: {
                store.markLabelReferenceInvalid(record)
              } onReviewed: {
                store.markLabelReferenceReviewed(record)
              } onCreateTask: {
                store.createReviewTask(from: record)
              } onCreateDraft: {
                store.createDraftMessage(from: record)
              } onRemove: {
                store.removeLabelReferenceRecord(record)
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
        Text("Label References")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Local barcode, QR, tracking, storage, custody, receiving, return, and evidence label placeholders.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(store.invalidLabelReferences.count) invalid", color: .red)
        Badge("\(store.labelReferencesMissingValues.count) missing values", color: .orange)
      }
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search label, value, source, carrier, owner, scan, manifest, order, or evidence", text: $labelSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Type", selection: $selectedType) {
        Text("All types").tag(nil as LabelReferenceType?)
        ForEach(LabelReferenceType.allCases) { type in Text(type.rawValue).tag(type as LabelReferenceType?) }
      }

      Picker("Status", selection: $selectedStatus) {
        Text("All status").tag(nil as LabelReferenceStatus?)
        ForEach(LabelReferenceStatus.allCases) { status in Text(status.rawValue).tag(status as LabelReferenceStatus?) }
      }

      Picker("Source", selection: $selectedSource) {
        Text("All sources").tag(nil as LabelReferenceSource?)
        ForEach(LabelReferenceSource.allCases) { source in Text(source.rawValue).tag(source as LabelReferenceSource?) }
      }

      TextField("Carrier", text: $carrier)
        .textFieldStyle(.roundedBorder)
      TextField("Owner/team", text: $ownerTeam)
        .textFieldStyle(.roundedBorder)

      Picker("Risk", selection: $selectedRiskLevel) {
        Text("All risk").tag(nil as ShipmentRiskLevel?)
        ForEach(ShipmentRiskLevel.allCases) { risk in Text(risk.rawValue).tag(risk as ShipmentRiskLevel?) }
      }

      Picker("Linked", selection: $selectedLinkedEntityType) {
        Text("All links").tag(nil as ReviewTaskLinkedEntityType?)
        ForEach(ReviewTaskLinkedEntityType.allCases) { type in Text(type.rawValue).tag(type as ReviewTaskLinkedEntityType?) }
      }

      Picker("Review", selection: $selectedReviewState) {
        Text("All review").tag(nil as ReviewState?)
        ForEach(reviewStates, id: \.self) { state in Text(state.rawValue).tag(state as ReviewState?) }
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
    selectedType = nil
    selectedStatus = nil
    selectedSource = nil
    carrier = ""
    ownerTeam = ""
    selectedRiskLevel = nil
    selectedLinkedEntityType = nil
    selectedReviewState = nil
    labelSearchText = ""
  }

  private func linkedOrder(for record: LabelReferenceRecord) -> TrackedOrder? {
    let orderID = record.orderID ?? (record.linkedEntityType == .order ? UUID(uuidString: record.linkedEntityID) : nil)
    guard let orderID else { return nil }
    return store.orders.first { $0.id == orderID }
  }

  private func labelReference(_ record: LabelReferenceRecord, matches query: String) -> Bool {
    let order = linkedOrder(for: record)
    let scanSessions = store.suggestedScanSessionRecords(for: record)
    let shipmentManifests = store.suggestedShipmentManifestRecords(for: record)
    let dispatchChecklists = store.suggestedDispatchReadinessChecklists(for: record)
    var searchParts: [String] = [
      record.id.uuidString,
      record.title,
      record.linkedEntityType.rawValue,
      record.linkedEntityID,
      record.labelType.rawValue,
      record.labelValuePlaceholder,
      record.labelSource.rawValue,
      record.labelStatus.rawValue,
      record.associatedCarrier,
      record.assignedOwnerTeam,
      record.createdDate,
      record.lastReviewedDate,
      record.notes,
      record.riskLevel.rawValue,
      record.reviewState.rawValue,
      order?.orderNumber ?? "",
      order?.store ?? "",
      order?.customer ?? "",
      order?.recipientEmail ?? "",
      order?.trackingNumber ?? "",
      order?.carrier ?? "",
      order?.destination ?? ""
    ]
    searchParts.append(contentsOf: [
      record.storageLocationID?.uuidString ?? "",
      record.inventoryReceiptID?.uuidString ?? "",
      record.custodyRecordID?.uuidString ?? "",
      record.orderID?.uuidString ?? "",
      record.shipmentGroupID?.uuidString ?? "",
      record.packageContentID?.uuidString ?? ""
    ])
    searchParts.append(contentsOf: record.evidenceAttachmentIDs.map(\.uuidString))
    searchParts.append(contentsOf: scanSessions.flatMap { [$0.title, $0.expectedLabelReferenceValue, $0.capturedValuePlaceholder, $0.assignedOperatorTeam] })
    searchParts.append(contentsOf: shipmentManifests.flatMap { [$0.title, $0.manifestReferencePlaceholder, $0.carrierCourier, $0.destinationSummary] })
    searchParts.append(contentsOf: dispatchChecklists.flatMap { [$0.title, $0.checklistType.rawValue, $0.checklistStatus.rawValue, $0.assignedOwnerTeam] })
    return searchParts.joined(separator: " ").localizedLowercase.contains(query)
  }
}

struct LabelReferenceRow: View {
  var record: LabelReferenceRecord
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
  var scanSessions: [ScanSessionRecord] = []
  var shipmentManifests: [ShipmentManifestRecord] = []
  var dispatchChecklists: [DispatchReadinessChecklist] = []
  var onSave: (LabelReferenceRecord) -> Void
  var onPrinted: () -> Void
  var onVerified: () -> Void
  var onInvalid: () -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: record.labelType.symbol)
          .foregroundStyle(record.riskLevel.color)
          .frame(width: 28, height: 28)
        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(record.title)
                .font(.headline)
              Text("\(record.labelType.rawValue) • \(record.labelValuePlaceholder)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(record.labelStatus.rawValue, color: record.labelStatus.color)
          }
          Text(record.notes)
            .foregroundStyle(.secondary)
          Text("\(record.labelSource.rawValue) • \(record.associatedCarrier) • Owner \(record.assignedOwnerTeam)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          HStack(spacing: 8) {
            Badge(record.riskLevel.rawValue, color: record.riskLevel.color)
            Badge(record.reviewState.rawValue, color: record.reviewState.color)
            Label(record.linkedEntityType.rawValue, systemImage: record.linkedEntityType.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
            Label("\(record.evidenceAttachmentIDs.count) evidence", systemImage: "paperclip")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      ScanSessionStrip(records: scanSessions)

      HStack {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Printed", systemImage: "printer.fill", action: onPrinted)
          .buttonStyle(.bordered)
        Button("Verified", systemImage: "barcode.viewfinder", action: onVerified)
          .buttonStyle(.bordered)
        Button("Invalid", systemImage: "exclamationmark.triangle.fill", action: onInvalid)
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
      LabelReferenceEditView(record: record) { updatedRecord in
        onSave(updatedRecord)
      }
    }
  }
}

struct LabelReferenceEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: LabelReferenceRecord
  var onSave: (LabelReferenceRecord) -> Void

  init(record: LabelReferenceRecord, onSave: @escaping (LabelReferenceRecord) -> Void) {
    self._draft = State(initialValue: record)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Label") {
          TextField("Title", text: $draft.title)
          Picker("Type", selection: $draft.labelType) {
            ForEach(LabelReferenceType.allCases) { type in Text(type.rawValue).tag(type) }
          }
          TextField("Value placeholder", text: $draft.labelValuePlaceholder)
          Picker("Source", selection: $draft.labelSource) {
            ForEach(LabelReferenceSource.allCases) { source in Text(source.rawValue).tag(source) }
          }
          Picker("Status", selection: $draft.labelStatus) {
            ForEach(LabelReferenceStatus.allCases) { status in Text(status.rawValue).tag(status) }
          }
          TextField("Associated carrier", text: $draft.associatedCarrier)
        }

        Section("Ownership") {
          TextField("Owner/team", text: $draft.assignedOwnerTeam)
          TextField("Created date", text: $draft.createdDate)
          TextField("Last reviewed", text: $draft.lastReviewedDate)
          TextField("Notes", text: $draft.notes, axis: .vertical)
        }

        Section("Review") {
          Picker("Risk", selection: $draft.riskLevel) {
            ForEach(ShipmentRiskLevel.allCases) { risk in Text(risk.rawValue).tag(risk) }
          }
          Picker("Review state", selection: $draft.reviewState) {
            ForEach([ReviewState.needsReview, .monitor, .accepted], id: \.self) { state in Text(state.rawValue).tag(state) }
          }
        }

        Section("Link") {
          Picker("Linked record type", selection: $draft.linkedEntityType) {
            ForEach(ReviewTaskLinkedEntityType.allCases) { type in Text(type.rawValue).tag(type) }
          }
          TextField("Linked record ID", text: $draft.linkedEntityID)
        }
      }
      .navigationTitle("Edit Label")
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
    .frame(minWidth: 620, minHeight: 660)
  }
}
