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
        inboxStorageCoverage
        gmailStorageReadinessPanel

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

  private var inboxStorageCoverage: some View {
    let inboxOrders = store.intakeLinkedOrders
    let wishlistOrders = store.wishlistLinkedOrders
    let linkedLocations = locationsLinkedToInboxOrders
    let actionLocations = locationsNeedingStorageAction
    let missingStorageCount = inboxOrdersMissingStorage.count

    return SettingsPanel(title: "Inbox and Wishlist storage readiness", symbol: "cabinet.fill") {
      VStack(alignment: .leading, spacing: 10) {
        Text("Checks whether orders created from Inbox intake or Wishlist purchase handoff have usable local storage, bin codes, capacity, and access context.")
          .font(.caption)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 150) {
          Badge("\(inboxOrders.count) Inbox orders", color: .blue)
          Badge("\(wishlistOrders.count) Wishlist orders", color: .pink)
          Badge("\(linkedLocations.count) linked locations", color: .teal)
          Badge("\(actionLocations.count) need action", color: actionLocations.isEmpty ? .green : .orange)
          Badge("\(missingStorageCount) missing storage", color: missingStorageCount == 0 ? .green : .orange)
        }

        if !storageProviderRows.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Mailbox source for storage")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
              ForEach(storageProviderRows, id: \.label) { row in
                HStack(alignment: .top, spacing: 10) {
                  Image(systemName: row.symbol)
                    .foregroundStyle(row.color)
                    .frame(width: 22, height: 22)
                  VStack(alignment: .leading, spacing: 4) {
                    HStack {
                      Text(row.label)
                        .font(.caption.weight(.semibold))
                      Spacer()
                      Badge("\(row.count) intake", color: row.color)
                    }
                    Text(row.detail)
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                      .fixedSize(horizontal: false, vertical: true)
                  }
                }
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(row.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
              }
            }
          }
        }

        if inboxOrders.isEmpty && wishlistOrders.isEmpty {
          Text("No Inbox-created or Wishlist-linked orders are present yet. Create an order from Inbox or complete a Wishlist purchase handoff before assigning storage.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if linkedLocations.isEmpty {
          Text("Inbox-created or Wishlist-linked orders do not have storage locations yet. Add or link a location after receiving stock.")
            .font(.caption)
            .foregroundStyle(.orange)
        } else {
          ForEach(Array(actionLocations.prefix(3))) { location in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: location.isEnabled ? "cabinet.fill" : "pause.circle.fill")
                .foregroundStyle(location.isEnabled ? .orange : .gray)
              VStack(alignment: .leading, spacing: 2) {
                Text(location.title)
                  .font(.caption.bold())
                Text(storageActionSummary(for: location))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Badge(location.isEnabled ? "Enabled" : "Disabled", color: location.isEnabled ? .green : .gray)
            }
          }

          if actionLocations.isEmpty {
            Text("Linked storage locations look enabled, coded, reviewed, and ready for current Inbox-created and Wishlist-linked orders.")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else if actionLocations.count > 3 {
            Text("\(actionLocations.count - 3) more linked storage locations need code, capacity, access, or review follow-up.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private var storageProviderRows: [(label: String, count: Int, detail: String, symbol: String, color: Color)] {
    var counts: [String: Int] = [:]
    var tones: [String: String] = [:]
    for order in store.intakeLinkedOrders {
      for email in store.linkedIntakeEmails(for: order) {
        let summary = store.intakeSourceSummary(for: email)
        counts[summary.label, default: 0] += 1
        tones[summary.label] = summary.tone
      }
    }
    return counts.map { label, count in
      let tone = tones[label] ?? ""
      let detail: String
      switch tone {
      case "spacemail":
        detail = "SpaceMail intake can drive storage assignment after an Inbox order is linked, received, or stocked."
      case "gmail":
        detail = "Gmail intake can drive storage assignment after an Inbox order is linked, received, or stocked."
      case "mock":
        detail = "Mock mailbox intake supports local storage testing. Confirm live provider context before physical handoff."
      default:
        detail = "Local mailbox intake can drive storage assignment once linked to an order."
      }
      return (
        label: label,
        count: count,
        detail: detail,
        symbol: providerSymbol(for: tone, label: label),
        color: sourceColor(for: tone)
      )
    }
    .sorted { lhs, rhs in
      if lhs.count == rhs.count {
        return lhs.label < rhs.label
      }
      return lhs.count > rhs.count
    }
  }

  private var gmailStorageReadinessPanel: some View {
    GmailReleaseBoundaryPanel(
      store: store,
      title: "Gmail storage readiness",
      lead: "Gmail-origin intake should influence storage only after Gmail setup is ready and the imported Inbox order has confirmed receipt, location, and handoff context.",
      sourceMetricTitle: "Gmail storage sources",
      sourceCount: gmailStorageSourceCount,
      boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store tokens, connect warehouse systems, geocode locations, or change storage records automatically."
    )
  }

  private var gmailStorageSourceCount: Int {
    storageProviderRows
      .filter { $0.label.localizedCaseInsensitiveContains("Gmail") }
      .reduce(0) { total, row in total + row.count }
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




  private var locationsLinkedToInboxOrders: [StorageLocationRecord] {
    let orderIDs = Set(store.operatorSourceOrders.map(\.id))
    let receiptIDs = Set(store.inventoryReceipts.filter { receipt in
      if let orderID = receipt.orderID, orderIDs.contains(orderID) {
        return true
      }
      if receipt.linkedEntityType == .order, let linkedID = UUID(uuidString: receipt.linkedEntityID), orderIDs.contains(linkedID) {
        return true
      }
      return false
    }.map(\.id))

    return store.storageLocations.filter { location in
      !Set(location.orderIDs).isDisjoint(with: orderIDs)
        || !Set(location.inventoryReceiptIDs).isDisjoint(with: receiptIDs)
        || (location.linkedEntityType == .order && UUID(uuidString: location.linkedEntityID).map { orderIDs.contains($0) } == true)
    }
  }

  private var inboxOrdersMissingStorage: [TrackedOrder] {
    let locationOrderIDs = Set(locationsLinkedToInboxOrders.flatMap(\.orderIDs))
    return store.operatorSourceOrders.filter { order in
      locationOrderIDs.contains(order.id) == false
        && locationsLinkedToInboxOrders.contains { location in
          location.linkedEntityType == .order && UUID(uuidString: location.linkedEntityID) == order.id
        } == false
    }
  }

  private var locationsNeedingStorageAction: [StorageLocationRecord] {
    locationsLinkedToInboxOrders.filter { location in
      !location.isEnabled
        || location.reviewState != .accepted
        || location.riskLevel == .high
        || location.riskLevel == .critical
        || location.locationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || location.locationCode.localizedCaseInsensitiveContains("missing")
        || location.locationCode.localizedCaseInsensitiveContains("confirm")
        || location.currentUsageSummary.localizedCaseInsensitiveContains("warning")
        || location.currentUsageSummary.localizedCaseInsensitiveContains("full")
        || location.capacitySummary.localizedCaseInsensitiveContains("warning")
        || !location.accessNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
  }

  private func storageActionSummary(for location: StorageLocationRecord) -> String {
    var parts: [String] = []
    if !location.isEnabled { parts.append("enable or choose another location") }
    if location.locationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || location.locationCode.localizedCaseInsensitiveContains("missing") || location.locationCode.localizedCaseInsensitiveContains("confirm") { parts.append("confirm code") }
    if location.currentUsageSummary.localizedCaseInsensitiveContains("warning") || location.currentUsageSummary.localizedCaseInsensitiveContains("full") || location.capacitySummary.localizedCaseInsensitiveContains("warning") { parts.append("check capacity") }
    if !location.accessNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { parts.append("review access notes") }
    if location.riskLevel == .high || location.riskLevel == .critical { parts.append("review risk") }
    if location.reviewState != .accepted { parts.append("mark reviewed") }
    return parts.isEmpty ? "Storage location is enabled, coded, and reviewed." : parts.joined(separator: ", ")
  }

  private func sourceColor(for tone: String) -> Color {
    switch tone {
    case "spacemail":
      return .teal
    case "gmail":
      return .blue
    case "mock":
      return .purple
    case "microsoft", "mailbox":
      return .blue
    default:
      return .secondary
    }
  }

  private func providerSymbol(for tone: String, label: String) -> String {
    if tone == "gmail" || label.localizedCaseInsensitiveContains("Gmail") {
      return "envelope.badge.shield.half.filled"
    }
    if tone == "spacemail" || label.localizedCaseInsensitiveContains("SpaceMail") {
      return "server.rack"
    }
    if tone == "mock" {
      return "testtube.2"
    }
    return "envelope.open.fill"
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
  @State private var feedbackMessage: String?

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

      if !storageLocationWarnings.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Label("Storage follow-up", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.bold())
            .foregroundStyle(.orange)
          ForEach(storageLocationWarnings, id: \.self) { warning in
            Text(warning)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      if let store, let linkedOrder {
        let linkedEmails = store.linkedIntakeEmails(for: linkedOrder)
        let linkedWishlistItems = store.activeWishlistItemsLinked(to: linkedOrder)
        if !linkedEmails.isEmpty || !linkedWishlistItems.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Label("Inbox/Wishlist storage source", systemImage: "tray.and.arrow.down.fill")
              .font(.caption.bold())
              .foregroundStyle(.teal)
            ForEach(linkedWishlistItems.prefix(2)) { item in
              HStack(spacing: 6) {
                Badge("Wishlist", color: .pink)
                if let handoff = item.purchaseHandoff {
                  Badge(handoff.purchaseStatus, color: .secondary)
                }
                Text(item.itemName)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
            }
            ForEach(linkedEmails.prefix(2)) { email in
              HStack(spacing: 6) {
                let sourceSummary = store.intakeSourceSummary(for: email)
                Badge(sourceSummary.label, color: sourceColor(for: sourceSummary.tone))
                if !email.detectedTrackingNumber.isPlaceholderValidationValue {
                  Badge("Tracking \(email.detectedTrackingNumber)", color: .teal)
                }
                if !email.detectedOrderNumber.isPlaceholderValidationValue {
                  Badge("Order \(email.detectedOrderNumber)", color: .blue)
                }
                Text(email.subject)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
            }
          }
        }
      }

      if let feedbackMessage {
        StorageLocationActionFeedbackPanel(message: feedbackMessage)
      }

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button(location.isEnabled ? "Disable" : "Enable", systemImage: location.isEnabled ? "pause.circle.fill" : "play.circle.fill") {
          onToggle()
          feedbackMessage = location.isEnabled
            ? "Location disabled locally. Review open receipts, custody, and dispatch handoffs before using it again."
            : "Location enabled locally. Confirm code, access notes, and capacity before assigning physical items."
        }
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.shield.fill") {
          onReviewed()
          feedbackMessage = "Storage location marked reviewed locally. No maps, access-control, or warehouse system was contacted."
        }
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Review task created from this storage location for local follow-up."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Draft message created from this storage location. It remains local until a person sends anything outside ParcelOps."
        }
          .buttonStyle(.bordered)
        if let store, let linkedOrder {
          NavigationLink {
            OrderDetailView(order: linkedOrder, store: store)
          } label: {
            Label("Open order", systemImage: "arrow.up.right.square.fill")
          }
          .buttonStyle(.bordered)
        }
        Button("Remove", systemImage: "trash", role: .destructive) {
          onRemove()
          feedbackMessage = "Storage location removed locally. No warehouse, access-control, carrier, or mailbox system was changed."
        }
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      StorageLocationEditView(location: location) { updatedLocation in
        onSave(updatedLocation)
        feedbackMessage = "Storage location details saved locally. Recheck linked receipts, custody, and dispatch context if values changed."
      }
    }
  }

  private var storageLocationWarnings: [String] {
    var warnings: [String] = []
    if !location.isEnabled {
      warnings.append("Location is disabled; choose another storage point or enable it before assigning stock.")
    }
    if location.locationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || location.locationCode.localizedCaseInsensitiveContains("missing") || location.locationCode.localizedCaseInsensitiveContains("confirm") {
      warnings.append("Location code needs confirmation.")
    }
    if location.currentUsageSummary.localizedCaseInsensitiveContains("warning") || location.currentUsageSummary.localizedCaseInsensitiveContains("full") || location.capacitySummary.localizedCaseInsensitiveContains("warning") {
      warnings.append("Capacity or usage indicates a warning.")
    }
    if !location.accessNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      warnings.append("Access notes are present; review before handoff or collection.")
    }
    if location.riskLevel == .high || location.riskLevel == .critical {
      warnings.append("Risk is \(location.riskLevel.rawValue.lowercased()); confirm storage handling.")
    }
    if location.reviewState != .accepted {
      warnings.append("Review state is \(location.reviewState.rawValue.lowercased()); mark reviewed after local checks are complete.")
    }
    return warnings
  }


  private func sourceColor(for tone: String) -> Color {
    switch tone {
    case "spacemail": return .teal
    case "gmail": return .blue
    case "mock": return .purple
    case "microsoft", "mailbox": return .blue
    default: return .secondary
    }
  }
}

private struct StorageLocationActionFeedbackPanel: View {
  var message: String

  var body: some View {
    Label {
      Text(message)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    } icon: {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
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
