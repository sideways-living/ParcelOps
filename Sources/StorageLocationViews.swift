import SwiftUI

struct StorageLocationsView: View {
  var store: ParcelOpsStore
  @State private var selectedLocationType: StorageLocationType?
  @State private var areaZone = ""
  @State private var ownerTeam = ""
  @State private var selectedRiskLevel: ShipmentRiskLevel?
  @State private var selectedEnabledState: Bool?
  @State private var selectedLinkedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedReviewState: ReviewState?
  @State private var locationSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var baseFilteredLocations: [StorageLocationRecord] {
    store.filteredStorageLocations(
      locationType: selectedLocationType,
      areaZone: areaZone,
      ownerTeam: ownerTeam,
      riskLevel: selectedRiskLevel,
      enabledState: selectedEnabledState,
      linkedEntityType: selectedLinkedEntityType,
      reviewState: selectedReviewState
    )
  }

  private var filteredLocations: [StorageLocationRecord] {
    let query = locationSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredLocations }
    return baseFilteredLocations.filter { location in
      storageLocation(location, matches: query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedLocationType != nil
      || !areaZone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || selectedRiskLevel != nil
      || selectedEnabledState != nil
      || selectedLinkedEntityType != nil
      || selectedReviewState != nil
      || !locationSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filterBar

        SettingsPanel(title: "Storage location records", symbol: "cabinet.fill") {
          HStack {
            Text("\(filteredLocations.count) visible storage locations")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredLocations.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add location", systemImage: "plus", action: store.addStorageLocationPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredLocations.isEmpty {
            MVPEmptyState(title: "No storage locations match this view", detail: hasActiveFilters ? "Clear search or filters to return to all local storage locations." : "Add a local storage location to track bins, cages, shelves, desks, lockers, capacity, access notes, and handoff areas.", symbol: "cabinet.fill", actionTitle: hasActiveFilters ? "Clear filters" : "Add location", action: hasActiveFilters ? clearFilters : store.addStorageLocationPlaceholder)
          } else {
            ForEach(filteredLocations) { location in
              StorageLocationRow(location: location, store: store, linkedOrder: linkedOrder(for: location), custodyRecords: store.suggestedCustodyRecords(for: location), labelReferences: store.suggestedLabelReferenceRecords(for: location), scanSessions: store.suggestedScanSessionRecords(for: location), shipmentManifests: store.suggestedShipmentManifestRecords(for: location), dispatchChecklists: store.suggestedDispatchReadinessChecklists(for: location)) { updatedLocation in
                store.updateStorageLocation(updatedLocation)
              } onToggle: {
                store.toggleStorageLocation(location)
              } onReviewed: {
                store.markStorageLocationReviewed(location)
              } onCreateTask: {
                store.createReviewTask(from: location)
              } onCreateDraft: {
                store.createDraftMessage(from: location)
              } onRemove: {
                store.removeStorageLocation(location)
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
        Text("Storage Locations")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Local shelves, bins, cages, desks, lockers, and handoff areas for receipt storage.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(store.storageLocationsMissingCodes.count) missing codes", color: .orange)
        Badge("\(store.storageLocationsWithCapacityWarnings.count) capacity warnings", color: .red)
      }
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search location, code, zone, owner, access, capacity, receipt, custody, label, or order", text: $locationSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Type", selection: $selectedLocationType) {
        Text("All types").tag(nil as StorageLocationType?)
        ForEach(StorageLocationType.allCases) { type in
          Text(type.rawValue).tag(type as StorageLocationType?)
        }
      }

      TextField("Area/zone", text: $areaZone)
        .textFieldStyle(.roundedBorder)

      TextField("Owner/team", text: $ownerTeam)
        .textFieldStyle(.roundedBorder)

      Picker("Risk", selection: $selectedRiskLevel) {
        Text("All risk").tag(nil as ShipmentRiskLevel?)
        ForEach(ShipmentRiskLevel.allCases) { risk in
          Text(risk.rawValue).tag(risk as ShipmentRiskLevel?)
        }
      }

      Picker("Enabled", selection: $selectedEnabledState) {
        Text("All states").tag(nil as Bool?)
        Text("Enabled").tag(true as Bool?)
        Text("Disabled").tag(false as Bool?)
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
    selectedLocationType = nil
    areaZone = ""
    ownerTeam = ""
    selectedRiskLevel = nil
    selectedEnabledState = nil
    selectedLinkedEntityType = nil
    selectedReviewState = nil
    locationSearchText = ""
  }

  private func linkedOrder(for location: StorageLocationRecord) -> TrackedOrder? {
    let orderID = location.orderIDs.first ?? (location.linkedEntityType == .order ? UUID(uuidString: location.linkedEntityID) : nil)
    guard let orderID else { return nil }
    return store.orders.first { $0.id == orderID }
  }

  private func storageLocation(_ location: StorageLocationRecord, matches query: String) -> Bool {
    let order = linkedOrder(for: location)
    let custodyRecords = store.suggestedCustodyRecords(for: location)
    let labelReferences = store.suggestedLabelReferenceRecords(for: location)
    let scanSessions = store.suggestedScanSessionRecords(for: location)
    let shipmentManifests = store.suggestedShipmentManifestRecords(for: location)
    let dispatchChecklists = store.suggestedDispatchReadinessChecklists(for: location)
    var searchParts: [String] = [
      location.id.uuidString,
      location.title,
      location.locationType.rawValue,
      location.locationCode,
      location.areaZone,
      location.capacitySummary,
      location.currentUsageSummary,
      location.linkedEntityType.rawValue,
      location.linkedEntityID,
      location.assignedOwnerTeam,
      location.accessNotes,
      location.riskLevel.rawValue,
      location.isEnabled ? "Enabled" : "Disabled",
      location.createdDate,
      location.lastReviewedDate,
      location.reviewState.rawValue,
      order?.orderNumber ?? "",
      order?.store ?? "",
      order?.customer ?? "",
      order?.recipientEmail ?? "",
      order?.trackingNumber ?? "",
      order?.carrier ?? "",
      order?.destination ?? ""
    ]
    searchParts.append(contentsOf: location.inventoryReceiptIDs.map(\.uuidString))
    searchParts.append(contentsOf: location.receivingInspectionIDs.map(\.uuidString))
    searchParts.append(contentsOf: location.packageContentIDs.map(\.uuidString))
    searchParts.append(contentsOf: location.orderIDs.map(\.uuidString))
    searchParts.append(contentsOf: location.shipmentGroupIDs.map(\.uuidString))
    searchParts.append(contentsOf: custodyRecords.map(\.title))
    searchParts.append(contentsOf: labelReferences.map(\.title))
    searchParts.append(contentsOf: scanSessions.map(\.title))
    searchParts.append(contentsOf: shipmentManifests.map(\.title))
    searchParts.append(contentsOf: dispatchChecklists.map(\.title))
    let searchableText = searchParts.joined(separator: " ")
    return searchableText.localizedLowercase.contains(query)
  }
}

struct StorageLocationRow: View {
  var location: StorageLocationRecord
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
  var custodyRecords: [CustodyRecord] = []
  var labelReferences: [LabelReferenceRecord] = []
  var scanSessions: [ScanSessionRecord] = []
  var shipmentManifests: [ShipmentManifestRecord] = []
  var dispatchChecklists: [DispatchReadinessChecklist] = []
  var onSave: (StorageLocationRecord) -> Void
  var onToggle: () -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: location.locationType.symbol)
          .foregroundStyle(location.riskLevel.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(location.title)
                .font(.headline)
              Text("\(location.locationCode) • \(location.areaZone)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(location.isEnabled ? "Enabled" : "Disabled", color: location.isEnabled ? .green : .gray)
          }

          Text(location.currentUsageSummary)
            .foregroundStyle(.secondary)
          Text("\(location.capacitySummary) • Owner \(location.assignedOwnerTeam)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          HStack(spacing: 8) {
            Badge(location.riskLevel.rawValue, color: location.riskLevel.color)
            Badge(location.reviewState.rawValue, color: location.reviewState.color)
            Label("\(location.inventoryReceiptIDs.count) receipts", systemImage: "archivebox.fill")
              .font(.caption)
              .foregroundStyle(.secondary)
            Label(location.linkedEntityType.rawValue, systemImage: location.linkedEntityType.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      CustodyRecordStrip(records: custodyRecords)
      LabelReferenceStrip(records: labelReferences)
      ScanSessionStrip(records: scanSessions)

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button(location.isEnabled ? "Disable" : "Enable", systemImage: location.isEnabled ? "pause.circle.fill" : "play.circle.fill", action: onToggle)
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
      StorageLocationEditView(location: location) { updatedLocation in
        onSave(updatedLocation)
      }
    }
  }
}

struct StorageLocationEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: StorageLocationRecord
  var onSave: (StorageLocationRecord) -> Void

  init(location: StorageLocationRecord, onSave: @escaping (StorageLocationRecord) -> Void) {
    self._draft = State(initialValue: location)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Location") {
          TextField("Title", text: $draft.title)
          Picker("Type", selection: $draft.locationType) {
            ForEach(StorageLocationType.allCases) { type in
              Text(type.rawValue).tag(type)
            }
          }
          TextField("Location code", text: $draft.locationCode)
          TextField("Area/zone", text: $draft.areaZone)
          Toggle("Enabled", isOn: $draft.isEnabled)
        }

        Section("Capacity and access") {
          TextField("Capacity summary", text: $draft.capacitySummary, axis: .vertical)
          TextField("Current usage", text: $draft.currentUsageSummary, axis: .vertical)
          TextField("Access notes", text: $draft.accessNotes, axis: .vertical)
          TextField("Owner/team", text: $draft.assignedOwnerTeam)
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
      .navigationTitle("Edit Location")
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
