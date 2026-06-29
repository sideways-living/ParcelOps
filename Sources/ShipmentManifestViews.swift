import SwiftUI

struct ShipmentManifestsView: View {
  var store: ParcelOpsStore
  @State private var selectedType: ShipmentManifestType?
  @State private var carrierCourier = ""
  @State private var selectedStatus: ShipmentManifestDispatchStatus?
  @State private var ownerTeam = ""
  @State private var selectedRiskLevel: ShipmentRiskLevel?
  @State private var selectedLinkedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedReviewState: ReviewState?
  @State private var manifestSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var baseFilteredRecords: [ShipmentManifestRecord] {
    store.filteredShipmentManifestRecords(manifestType: selectedType, carrierCourier: carrierCourier, dispatchStatus: selectedStatus, ownerTeam: ownerTeam, riskLevel: selectedRiskLevel, linkedEntityType: selectedLinkedEntityType, reviewState: selectedReviewState)
  }

  private var filteredRecords: [ShipmentManifestRecord] {
    let query = manifestSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return baseFilteredRecords }
    return baseFilteredRecords.filter { record in
      shipmentManifest(record, matches: query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedType != nil
      || !carrierCourier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || selectedStatus != nil
      || !ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || selectedRiskLevel != nil
      || selectedLinkedEntityType != nil
      || selectedReviewState != nil
      || !manifestSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        MVPWorkflowGuide(
          title: "Manifest workflow",
          detail: "Use manifests to bundle outbound work before checking readiness and handoff.",
          steps: [
            "Confirm included orders, shipment groups, labels, scans, and evidence.",
            "Mark prepared when the batch is ready for dispatch checks.",
            "Mark dispatched or handed off once the local handoff is complete.",
            "Block the manifest if orders, scans, or locations are missing."
          ],
          symbol: "list.bullet.clipboard.fill"
        )
        filterBar

        SettingsPanel(title: "Shipment manifest records", symbol: "list.bullet.clipboard.fill") {
          HStack {
            Text("\(filteredRecords.count) visible manifests")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredRecords.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add manifest", systemImage: "plus", action: store.addShipmentManifestPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredRecords.isEmpty {
            MVPEmptyState(
              title: "No manifests match this view",
              detail: hasActiveFilters ? "Clear search or filters to return to all shipment manifests." : "Add a placeholder manifest to test dispatch batching.",
              symbol: "list.bullet.clipboard.fill",
              actionTitle: hasActiveFilters ? "Clear filters" : "Add manifest",
              action: hasActiveFilters ? clearFilters : store.addShipmentManifestPlaceholder
            )
          } else {
            ForEach(filteredRecords) { record in
              ShipmentManifestRow(record: record, store: store, linkedOrders: linkedOrders(for: record), dispatchChecklists: store.suggestedDispatchReadinessChecklists(for: record)) { updatedRecord in
                store.updateShipmentManifestRecord(updatedRecord)
              } onPrepared: {
                store.markShipmentManifestPrepared(record)
              } onDispatched: {
                store.markShipmentManifestDispatched(record)
              } onHandedOff: {
                store.markShipmentManifestHandedOff(record)
              } onBlocked: {
                store.markShipmentManifestBlocked(record)
              } onReopen: {
                store.reopenShipmentManifest(record)
              } onReviewed: {
                store.markShipmentManifestReviewed(record)
              } onCreateTask: {
                store.createReviewTask(from: record)
              } onCreateDraft: {
                store.createDraftMessage(from: record)
              } onRemove: {
                store.removeShipmentManifestRecord(record)
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
        Text("Shipment Manifests")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Local dispatch batches for grouping orders before readiness checks and handoff.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(store.blockedShipmentManifests.count) blocked", color: .red)
        Badge("\(store.undispatchedShipmentManifests.count) undispatched", color: .orange)
      }
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search title, reference, carrier, destination, owner, order, group, label, scan, or notes", text: $manifestSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Type", selection: $selectedType) {
        Text("All types").tag(nil as ShipmentManifestType?)
        ForEach(ShipmentManifestType.allCases) { type in Text(type.rawValue).tag(type as ShipmentManifestType?) }
      }
      .pickerStyle(.menu)

      TextField("Carrier/courier", text: $carrierCourier)

      Picker("Status", selection: $selectedStatus) {
        Text("All status").tag(nil as ShipmentManifestDispatchStatus?)
        ForEach(ShipmentManifestDispatchStatus.allCases) { status in Text(status.rawValue).tag(status as ShipmentManifestDispatchStatus?) }
      }
      .pickerStyle(.menu)

      TextField("Owner/team", text: $ownerTeam)

      Picker("Risk", selection: $selectedRiskLevel) {
        Text("All risk").tag(nil as ShipmentRiskLevel?)
        ForEach(ShipmentRiskLevel.allCases) { risk in Text(risk.rawValue).tag(risk as ShipmentRiskLevel?) }
      }
      .pickerStyle(.menu)

      Picker("Linked", selection: $selectedLinkedEntityType) {
        Text("All links").tag(nil as ReviewTaskLinkedEntityType?)
        ForEach(ReviewTaskLinkedEntityType.allCases) { type in Text(type.rawValue).tag(type as ReviewTaskLinkedEntityType?) }
      }
      .pickerStyle(.menu)

      Picker("Review", selection: $selectedReviewState) {
        Text("All review").tag(nil as ReviewState?)
        ForEach(reviewStates, id: \.self) { state in Text(state.rawValue).tag(state as ReviewState?) }
      }
      .pickerStyle(.menu)

      Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle") {
        clearFilters()
      }
      .buttonStyle(.bordered)
    }
  }

  private func clearFilters() {
    selectedType = nil
    carrierCourier = ""
    selectedStatus = nil
    ownerTeam = ""
    selectedRiskLevel = nil
    selectedLinkedEntityType = nil
    selectedReviewState = nil
    manifestSearchText = ""
  }

  private func shipmentManifest(_ record: ShipmentManifestRecord, matches query: String) -> Bool {
    let linkedOrders = linkedOrders(for: record)
    let linkedGroups = record.shipmentGroupIDs.compactMap { groupID in
      store.shipmentGroups.first { $0.id == groupID }
    }
    let checklists = store.suggestedDispatchReadinessChecklists(for: record)
    let orderText = linkedOrders.map { order in
      [
        order.store,
        order.orderNumber,
        order.customer,
        order.recipientEmail,
        order.carrier,
        order.trackingNumber,
        order.destination
      ].joined(separator: " ")
    }.joined(separator: " ")
    let groupText = linkedGroups.map { group in
      [
        group.groupName,
        group.destinationSummary,
        group.recipientCustomerSummary,
        group.carrierSummary,
        group.statusSummary
      ].joined(separator: " ")
    }.joined(separator: " ")
    let checklistText = checklists.map { checklist in
      [
        checklist.title,
        checklist.checklistType.rawValue,
        checklist.checklistStatus.rawValue,
        checklist.requiredChecksSummary,
        checklist.missingRequirementsSummary
      ].joined(separator: " ")
    }.joined(separator: " ")
    let searchableText = [
      record.title,
      record.manifestType.rawValue,
      record.linkedEntityType.rawValue,
      record.linkedEntityID,
      record.carrierCourier,
      record.destinationSummary,
      record.assignedOwnerTeam,
      record.dispatchStatus.rawValue,
      record.plannedDispatchDate,
      record.actualDispatchDate,
      record.manifestReferencePlaceholder,
      record.notes,
      record.riskLevel.rawValue,
      record.reviewState.rawValue,
      record.handoffLocationStorageLocationID?.uuidString ?? "",
      record.includedOrderIDs.map(\.uuidString).joined(separator: " "),
      record.shipmentGroupIDs.map(\.uuidString).joined(separator: " "),
      record.inventoryReceiptIDs.map(\.uuidString).joined(separator: " "),
      record.packageContentIDs.map(\.uuidString).joined(separator: " "),
      record.custodyRecordIDs.map(\.uuidString).joined(separator: " "),
      record.labelReferenceIDs.map(\.uuidString).joined(separator: " "),
      record.scanSessionIDs.map(\.uuidString).joined(separator: " "),
      record.evidenceAttachmentIDs.map(\.uuidString).joined(separator: " "),
      orderText,
      groupText,
      checklistText
    ].joined(separator: " ")
    return searchableText.localizedCaseInsensitiveContains(query)
  }

  private func linkedOrders(for record: ShipmentManifestRecord) -> [TrackedOrder] {
    var ids = record.includedOrderIDs
    if record.linkedEntityType == .order, let id = UUID(uuidString: record.linkedEntityID) {
      ids.append(id)
    }
    let uniqueIDs = ids.reduce(into: [UUID]()) { result, id in
      if !result.contains(id) { result.append(id) }
    }
    return uniqueIDs.compactMap { id in
      store.orders.first { $0.id == id }
    }
  }
}

struct ShipmentManifestRow: View {
  var record: ShipmentManifestRecord
  var store: ParcelOpsStore? = nil
  var linkedOrders: [TrackedOrder] = []
  var dispatchChecklists: [DispatchReadinessChecklist] = []
  var onSave: (ShipmentManifestRecord) -> Void
  var onPrepared: () -> Void
  var onDispatched: () -> Void
  var onHandedOff: () -> Void
  var onBlocked: () -> Void
  var onReopen: () -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: record.manifestType.symbol)
          .foregroundStyle(record.riskLevel.color)
          .frame(width: 28, height: 28)
        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(record.title)
                .font(.headline)
              Text("\(record.manifestType.rawValue) • \(record.carrierCourier)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(record.dispatchStatus.rawValue, color: record.dispatchStatus.color)
          }
          Text(record.destinationSummary)
            .foregroundStyle(.secondary)
          Text("\(record.manifestReferencePlaceholder) • planned \(record.plannedDispatchDate) • actual \(record.actualDispatchDate)")
            .font(.caption)
            .foregroundStyle(.secondary)
          CompactMetadataGrid {
            Badge(record.riskLevel.rawValue, color: record.riskLevel.color)
            Badge(record.reviewState.rawValue, color: record.reviewState.color)
            Label("\(record.includedOrderIDs.count) orders", systemImage: "shippingbox.fill")
              .font(.caption)
              .foregroundStyle(.secondary)
            Label("\(record.scanSessionIDs.count) scans", systemImage: "qrcode.viewfinder")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Prepared", systemImage: "checkmark.circle.fill", action: onPrepared)
          .buttonStyle(.bordered)
        Button("Dispatched", systemImage: "paperplane.fill", action: onDispatched)
          .buttonStyle(.bordered)
        Button("Handed off", systemImage: "person.badge.shield.checkmark.fill", action: onHandedOff)
          .buttonStyle(.bordered)
        Button("Blocked", systemImage: "exclamationmark.triangle.fill", action: onBlocked)
          .buttonStyle(.bordered)
        Button("Reopen", systemImage: "arrow.counterclockwise", action: onReopen)
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.shield.fill", action: onReviewed)
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill", action: onCreateDraft)
          .buttonStyle(.bordered)
        if let store {
          ForEach(linkedOrders.prefix(3)) { order in
            NavigationLink {
              OrderDetailView(order: order, store: store)
            } label: {
              Label(order.orderNumber, systemImage: "arrow.up.right.square.fill")
            }
            .buttonStyle(.bordered)
          }
        }
        Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
          .buttonStyle(.bordered)
      }

      if !dispatchChecklists.isEmpty {
        DispatchReadinessStrip(checklists: dispatchChecklists)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      ShipmentManifestEditView(record: record) { updatedRecord in
        onSave(updatedRecord)
      }
    }
  }
}

struct ShipmentManifestEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: ShipmentManifestRecord
  var onSave: (ShipmentManifestRecord) -> Void

  init(record: ShipmentManifestRecord, onSave: @escaping (ShipmentManifestRecord) -> Void) {
    self._draft = State(initialValue: record)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Manifest") {
          TextField("Title", text: $draft.title)
          Picker("Type", selection: $draft.manifestType) {
            ForEach(ShipmentManifestType.allCases) { type in Text(type.rawValue).tag(type) }
          }
          Picker("Status", selection: $draft.dispatchStatus) {
            ForEach(ShipmentManifestDispatchStatus.allCases) { status in Text(status.rawValue).tag(status) }
          }
          TextField("Carrier/courier", text: $draft.carrierCourier)
          TextField("Destination summary", text: $draft.destinationSummary, axis: .vertical)
          TextField("Manifest reference", text: $draft.manifestReferencePlaceholder)
        }

        Section("Dispatch") {
          TextField("Owner/team", text: $draft.assignedOwnerTeam)
          TextField("Planned dispatch date", text: $draft.plannedDispatchDate)
          TextField("Actual dispatch date", text: $draft.actualDispatchDate)
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
      .navigationTitle("Edit Manifest")
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
    .frame(minWidth: 660, minHeight: 700)
  }
}
