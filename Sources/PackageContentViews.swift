import SwiftUI

struct PackageContentsView: View {
  var store: ParcelOpsStore
  @State private var selectedCategory: PackageItemCategory?
  @State private var selectedValueBand: PackageValueBand?
  @State private var selectedVerificationStatus: PackageVerificationStatus?
  @State private var selectedRiskLevel: ShipmentRiskLevel?
  @State private var selectedLinkedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedReviewState: ReviewState?
  @State private var packageSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var baseFilteredContents: [PackageContentRecord] {
    store.filteredPackageContents(
      itemCategory: selectedCategory,
      valueBand: selectedValueBand,
      verificationStatus: selectedVerificationStatus,
      riskLevel: selectedRiskLevel,
      linkedEntityType: selectedLinkedEntityType,
      reviewState: selectedReviewState
    )
  }

  private var filteredContents: [PackageContentRecord] {
    let query = packageSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredContents }
    return baseFilteredContents.filter { content in
      packageContent(content, matches: query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedCategory != nil
      || selectedValueBand != nil
      || selectedVerificationStatus != nil
      || selectedRiskLevel != nil
      || selectedLinkedEntityType != nil
      || selectedReviewState != nil
      || !packageSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filterBar

        SettingsPanel(title: "Content records", symbol: "shippingbox.circle.fill") {
          HStack {
            Text("\(filteredContents.count) visible content records")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredContents.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add content", systemImage: "plus", action: store.addPackageContentPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredContents.isEmpty {
            MVPEmptyState(title: "No package contents match this view", detail: hasActiveFilters ? "Clear search or filters to return to all local package content records." : "Add a package content record to track item verification, quantities, discrepancies, evidence, and receiving context.", symbol: "shippingbox.circle.fill", actionTitle: hasActiveFilters ? "Clear filters" : "Add content", action: hasActiveFilters ? clearFilters : store.addPackageContentPlaceholder)
          } else {
            ForEach(filteredContents) { content in
              PackageContentRow(content: content, store: store, linkedOrder: linkedOrder(for: content), costRecords: store.suggestedCostRecords(for: content), returnClaims: store.suggestedReturnClaims(for: content), procurementRequests: store.suggestedProcurementRequests(for: content), receivingInspections: store.suggestedReceivingInspections(for: content), inventoryReceipts: store.suggestedInventoryReceipts(for: content), storageLocations: store.suggestedStorageLocations(for: content), custodyRecords: store.suggestedCustodyRecords(for: content), labelReferences: store.suggestedLabelReferenceRecords(for: content), scanSessions: store.suggestedScanSessionRecords(for: content), shipmentManifests: store.suggestedShipmentManifestRecords(for: content), dispatchChecklists: store.suggestedDispatchReadinessChecklists(for: content)) { updatedContent in
                store.updatePackageContent(updatedContent)
              } onVerified: {
                store.markPackageContentVerified(content)
              } onDiscrepancy: {
                store.markPackageContentDiscrepancy(content)
              } onReviewed: {
                store.markPackageContentReviewed(content)
              } onCreateTask: {
                store.createReviewTask(from: content)
              } onCreateDraft: {
                store.createDraftMessage(from: content)
              } onRemove: {
                store.removePackageContent(content)
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
        Text("Package Contents")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Local item verification, quantity checks, evidence links, and discrepancy review for packages.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(store.unverifiedPackageContents.count) unverified", color: .orange)
        Badge("\(store.packageContentDiscrepancies.count) discrepancies", color: .red)
      }
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search item, order, shipment, destination, evidence, cost, claim, procurement, or storage", text: $packageSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Category", selection: $selectedCategory) {
        Text("All categories").tag(nil as PackageItemCategory?)
        ForEach(PackageItemCategory.allCases) { category in
          Text(category.rawValue).tag(category as PackageItemCategory?)
        }
      }

      Picker("Value", selection: $selectedValueBand) {
        Text("All value").tag(nil as PackageValueBand?)
        ForEach(PackageValueBand.allCases) { value in
          Text(value.rawValue).tag(value as PackageValueBand?)
        }
      }

      Picker("Verification", selection: $selectedVerificationStatus) {
        Text("All verification").tag(nil as PackageVerificationStatus?)
        ForEach(PackageVerificationStatus.allCases) { status in
          Text(status.rawValue).tag(status as PackageVerificationStatus?)
        }
      }

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
    selectedCategory = nil
    selectedValueBand = nil
    selectedVerificationStatus = nil
    selectedRiskLevel = nil
    selectedLinkedEntityType = nil
    selectedReviewState = nil
    packageSearchText = ""
  }

  private func linkedOrder(for content: PackageContentRecord) -> TrackedOrder? {
    let orderID = content.orderID ?? (content.linkedEntityType == .order ? UUID(uuidString: content.linkedEntityID) : nil)
    guard let orderID else { return nil }
    return store.orders.first { $0.id == orderID }
  }

  private func packageContent(_ content: PackageContentRecord, matches query: String) -> Bool {
    let order = linkedOrder(for: content)
    let costRecords = store.suggestedCostRecords(for: content)
    let returnClaims = store.suggestedReturnClaims(for: content)
    let procurementRequests = store.suggestedProcurementRequests(for: content)
    let receivingInspections = store.suggestedReceivingInspections(for: content)
    let inventoryReceipts = store.suggestedInventoryReceipts(for: content)
    let storageLocations = store.suggestedStorageLocations(for: content)
    let custodyRecords = store.suggestedCustodyRecords(for: content)
    let labelReferences = store.suggestedLabelReferenceRecords(for: content)
    let scanSessions = store.suggestedScanSessionRecords(for: content)
    let shipmentManifests = store.suggestedShipmentManifestRecords(for: content)
    let dispatchChecklists = store.suggestedDispatchReadinessChecklists(for: content)
    var searchParts: [String] = [
      content.id.uuidString,
      content.title,
      content.linkedEntityType.rawValue,
      content.linkedEntityID,
      content.orderID?.uuidString ?? "",
      content.shipmentGroupID?.uuidString ?? "",
      content.destinationAddressID?.uuidString ?? "",
      content.deliveryInstructionID?.uuidString ?? "",
      content.customerProfileID?.uuidString ?? "",
      content.itemSummary,
      "\(content.expectedQuantity)",
      "\(content.verifiedQuantity)",
      content.itemCategory.rawValue,
      content.valueBand.rawValue,
      content.verificationStatus.rawValue,
      content.discrepancySummary,
      content.riskLevel.rawValue,
      content.createdDate,
      content.lastReviewedDate,
      content.reviewState.rawValue,
      order?.orderNumber ?? "",
      order?.store ?? "",
      order?.customer ?? "",
      order?.recipientEmail ?? "",
      order?.trackingNumber ?? "",
      order?.carrier ?? "",
      order?.destination ?? ""
    ]
    searchParts.append(contentsOf: content.evidenceAttachmentIDs.map(\.uuidString))
    searchParts.append(contentsOf: costRecords.map(\.title))
    searchParts.append(contentsOf: costRecords.map(\.budgetCode))
    searchParts.append(contentsOf: returnClaims.map(\.title))
    searchParts.append(contentsOf: procurementRequests.map(\.title))
    searchParts.append(contentsOf: receivingInspections.map(\.title))
    searchParts.append(contentsOf: inventoryReceipts.map(\.title))
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

struct PackageContentRow: View {
  var content: PackageContentRecord
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
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
  var onSave: (PackageContentRecord) -> Void
  var onVerified: () -> Void
  var onDiscrepancy: () -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: content.itemCategory.symbol)
          .foregroundStyle(content.riskLevel.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(content.title)
                .font(.headline)
              Text("\(content.itemCategory.rawValue) • \(content.valueBand.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(content.verificationStatus.rawValue, color: content.verificationStatus.color)
          }

          Text(content.itemSummary)
            .foregroundStyle(.secondary)
          Text(content.discrepancySummary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          HStack(spacing: 8) {
            Badge(content.riskLevel.rawValue, color: content.riskLevel.color)
            Badge(content.reviewState.rawValue, color: content.reviewState.color)
            Label("\(content.verifiedQuantity)/\(content.expectedQuantity)", systemImage: "number.circle.fill")
              .font(.caption)
              .foregroundStyle(.secondary)
            Label(content.linkedEntityType.rawValue, systemImage: content.linkedEntityType.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      CostRecordStrip(costs: costRecords)
      ReturnClaimStrip(claims: returnClaims)
      ProcurementRequestStrip(requests: procurementRequests)
      ReceivingInspectionStrip(inspections: receivingInspections)
      InventoryReceiptStrip(receipts: inventoryReceipts)
      StorageLocationStrip(locations: storageLocations)
      CustodyRecordStrip(records: custodyRecords)
      LabelReferenceStrip(records: labelReferences)
      ScanSessionStrip(records: scanSessions)

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Verified", systemImage: "checkmark.seal.fill", action: onVerified)
          .buttonStyle(.bordered)
        Button("Discrepancy", systemImage: "exclamationmark.triangle.fill", action: onDiscrepancy)
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
      PackageContentEditView(content: content) { updatedContent in
        onSave(updatedContent)
      }
    }
  }
}

struct PackageContentEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: PackageContentRecord
  var onSave: (PackageContentRecord) -> Void

  init(content: PackageContentRecord, onSave: @escaping (PackageContentRecord) -> Void) {
    self._draft = State(initialValue: content)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Content") {
          TextField("Title", text: $draft.title)
          TextField("Item summary", text: $draft.itemSummary, axis: .vertical)
          Stepper("Expected quantity: \(draft.expectedQuantity)", value: $draft.expectedQuantity, in: 0...999)
          Stepper("Verified quantity: \(draft.verifiedQuantity)", value: $draft.verifiedQuantity, in: 0...999)
          Picker("Category", selection: $draft.itemCategory) {
            ForEach(PackageItemCategory.allCases) { category in
              Text(category.rawValue).tag(category)
            }
          }
          Picker("Value band", selection: $draft.valueBand) {
            ForEach(PackageValueBand.allCases) { band in
              Text(band.rawValue).tag(band)
            }
          }
        }

        Section("Verification") {
          Picker("Status", selection: $draft.verificationStatus) {
            ForEach(PackageVerificationStatus.allCases) { status in
              Text(status.rawValue).tag(status)
            }
          }
          TextField("Discrepancy summary", text: $draft.discrepancySummary, axis: .vertical)
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
      .navigationTitle("Edit Content")
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
    .frame(minWidth: 560, minHeight: 560)
  }
}
