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
  @State private var inspectionSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var baseFilteredInspections: [ReceivingInspectionRecord] {
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

  private var filteredInspections: [ReceivingInspectionRecord] {
    let query = inspectionSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredInspections }
    return baseFilteredInspections.filter { inspection in
      receivingInspection(inspection, matches: query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedInspectionType != nil
      || selectedInspectionStatus != nil
      || selectedDiscrepancyType != nil
      || !inspectorTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || selectedRiskLevel != nil
      || selectedLinkedEntityType != nil
      || selectedReviewState != nil
      || !inspectionSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filterBar
        inboxInspectionCoverage
        gmailInspectionReadinessPanel

        SettingsPanel(title: "Receiving inspection records", symbol: "checklist.checked") {
          HStack {
            Text("\(filteredInspections.count) visible receiving inspections")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredInspections.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add inspection", systemImage: "plus", action: store.addReceivingInspectionPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredInspections.isEmpty {
            MVPEmptyState(title: "No receiving inspections match this view", detail: hasActiveFilters ? "Clear search or filters to return to all local receiving inspection records." : "Add a receiving inspection to track item condition, quantity checks, discrepancies, and receiving follow-up.", symbol: "checklist.checked", actionTitle: hasActiveFilters ? "Clear filters" : "Add inspection", action: hasActiveFilters ? clearFilters : store.addReceivingInspectionPlaceholder)
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
    FilterControlGrid {
      TextField("Search inspection, item, discrepancy, inspector, order, receipt, storage, or dispatch", text: $inspectionSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Type", selection: $selectedInspectionType) {
        Text("All types").tag(nil as ReceivingInspectionType?)
        ForEach(ReceivingInspectionType.allCases) { type in
          Text(type.rawValue).tag(type as ReceivingInspectionType?)
        }
      }

      Picker("Status", selection: $selectedInspectionStatus) {
        Text("All status").tag(nil as ReceivingInspectionStatus?)
        ForEach(ReceivingInspectionStatus.allCases) { status in
          Text(status.rawValue).tag(status as ReceivingInspectionStatus?)
        }
      }

      Picker("Discrepancy", selection: $selectedDiscrepancyType) {
        Text("All discrepancy").tag(nil as ReceivingDiscrepancyType?)
        ForEach(ReceivingDiscrepancyType.allCases) { type in
          Text(type.rawValue).tag(type as ReceivingDiscrepancyType?)
        }
      }

      TextField("Inspector/team", text: $inspectorTeam)
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
    selectedInspectionType = nil
    selectedInspectionStatus = nil
    selectedDiscrepancyType = nil
    inspectorTeam = ""
    selectedRiskLevel = nil
    selectedLinkedEntityType = nil
    selectedReviewState = nil
    inspectionSearchText = ""
  }

  private var inboxInspectionCoverage: some View {
    SettingsPanel(title: "Inbox and Wishlist receiving inspection coverage", symbol: "checklist.checked") {
      Text("Checks whether orders created from Inbox intake or Wishlist purchase handoff have local inspection coverage for condition, quantity, and discrepancy follow-up.")
        .font(.caption)
        .foregroundStyle(.secondary)

      CompactMetadataGrid(minimumWidth: 150) {
        Badge("\(inboxCreatedOrders.count) Inbox orders", color: .blue)
        Badge("\(wishlistLinkedOrders.count) Wishlist orders", color: .pink)
        Badge("\(inspectionsLinkedToInboxOrders.count) linked inspections", color: .teal)
        Badge("\(inspectionsNeedingAction.count) need action", color: inspectionsNeedingAction.isEmpty ? .green : .orange)
        Badge("\(inboxOrdersMissingInspection.count) missing inspections", color: inboxOrdersMissingInspection.isEmpty ? .green : .orange)
      }

      if !inspectionProviderRows.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Mailbox source for receiving")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
            ForEach(inspectionProviderRows, id: \.label) { row in
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

      if receivingSourceOrders.isEmpty {
        Text("No Inbox-created or Wishlist-linked orders need receiving inspection checks yet.")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else if inboxOrdersMissingInspection.isEmpty && inspectionsNeedingAction.isEmpty {
        Label("Inbox-created and Wishlist-linked orders have receiving inspection coverage with no open local inspection warnings.", systemImage: "checkmark.seal.fill")
          .font(.caption)
          .foregroundStyle(.green)
      } else {
        VStack(alignment: .leading, spacing: 8) {
          if !inboxOrdersMissingInspection.isEmpty {
            Text("Inbox/Wishlist orders missing receiving inspection records")
              .font(.caption.weight(.semibold))
            CompactActionRow {
              ForEach(inboxOrdersMissingInspection.prefix(4)) { order in
                NavigationLink {
                  OrderDetailView(order: order, store: store)
                } label: {
                  Label(order.orderNumber, systemImage: "arrow.up.right.square.fill")
                }
                .buttonStyle(.bordered)
              }
            }
          }

          if !inspectionsNeedingAction.isEmpty {
            Text("Linked inspections needing follow-up")
              .font(.caption.weight(.semibold))
            CompactMetadataGrid(minimumWidth: 170) {
              ForEach(inspectionsNeedingAction.prefix(4)) { inspection in
                Badge(inspection.title, color: inspection.riskLevel.color)
              }
            }
          }
        }
      }
    }
  }

  private var inspectionProviderRows: [(label: String, count: Int, detail: String, symbol: String, color: Color)] {
    var counts: [String: Int] = [:]
    var tones: [String: String] = [:]
    for order in inboxCreatedOrders {
      for email in linkedIntakeEmails(for: order) {
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
        detail = "SpaceMail intake can trigger receiving checks after an Inbox order is linked, created, or routed to inspection."
      case "gmail":
        detail = "Gmail intake can trigger receiving checks after an Inbox order is linked, created, or routed to inspection."
      case "mock":
        detail = "Mock mailbox intake supports local receiving tests. Confirm live provider context before warehouse handoff."
      default:
        detail = "Local mailbox intake can trigger receiving checks once linked to an order."
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

  private var gmailInspectionReadinessPanel: some View {
    GmailReleaseBoundaryPanel(
      store: store,
      title: "Gmail receiving inspection readiness",
      lead: "Gmail-origin intake should create receiving inspection work only after Gmail setup is ready and the imported Inbox order has confirmed item, quantity, and condition context.",
      sourceMetricTitle: "Gmail inspection sources",
      sourceCount: gmailInspectionSourceCount,
      boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store tokens, contact suppliers, scan barcodes, or change receiving inspection records automatically."
    )
  }

  private var gmailInspectionSourceCount: Int {
    inspectionProviderRows
      .filter { $0.label.localizedCaseInsensitiveContains("Gmail") }
      .reduce(0) { total, row in total + row.count }
  }

  private var inboxCreatedOrders: [TrackedOrder] {
    store.orders.filter { order in
      !linkedIntakeEmails(for: order).isEmpty
    }
  }

  private var wishlistLinkedOrders: [TrackedOrder] {
    store.orders.filter { order in
      !store.activeWishlistItemsLinked(to: order).isEmpty
    }
  }

  private var receivingSourceOrders: [TrackedOrder] {
    store.operatorSourceOrders
  }

  private var inspectionsLinkedToInboxOrders: [ReceivingInspectionRecord] {
    store.receivingInspections.filter { inspection in
      guard let orderID = inspection.orderID ?? (inspection.linkedEntityType == .order ? UUID(uuidString: inspection.linkedEntityID) : nil) else {
        return false
      }
      return receivingSourceOrders.contains { $0.id == orderID }
    }
  }

  private var inspectionsNeedingAction: [ReceivingInspectionRecord] {
    inspectionsLinkedToInboxOrders.filter { inspection in
      inspection.inspectionStatus == .blocked
        || inspection.inspectionStatus == .pending
        || inspection.inspectionStatus == .discrepancy
        || inspection.discrepancyType != .none
        || inspection.quantityExpected != inspection.quantityReceived
        || inspection.reviewState != .accepted
    }
  }

  private var inboxOrdersMissingInspection: [TrackedOrder] {
    receivingSourceOrders.filter { order in
      !store.receivingInspections.contains { inspection in
        inspection.orderID == order.id || (inspection.linkedEntityType == .order && inspection.linkedEntityID == order.id.uuidString)
      }
    }
  }


  private func linkedIntakeEmails(for order: TrackedOrder) -> [ForwardedEmailIntake] {
    store.linkedIntakeEmails(for: order)
  }

  private func linkedOrder(for inspection: ReceivingInspectionRecord) -> TrackedOrder? {
    let orderID = inspection.orderID ?? (inspection.linkedEntityType == .order ? UUID(uuidString: inspection.linkedEntityID) : nil)
    guard let orderID else { return nil }
    return store.orders.first { $0.id == orderID }
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

  private func receivingInspection(_ inspection: ReceivingInspectionRecord, matches query: String) -> Bool {
    let order = linkedOrder(for: inspection)
    let inventoryReceipts = store.suggestedInventoryReceipts(for: inspection)
    let storageLocations = store.suggestedStorageLocations(for: inspection)
    let custodyRecords = store.suggestedCustodyRecords(for: inspection)
    let labelReferences = store.suggestedLabelReferenceRecords(for: inspection)
    let scanSessions = store.suggestedScanSessionRecords(for: inspection)
    let shipmentManifests = store.suggestedShipmentManifestRecords(for: inspection)
    let dispatchChecklists = store.suggestedDispatchReadinessChecklists(for: inspection)
    var searchParts: [String] = [
      inspection.id.uuidString,
      inspection.title,
      inspection.linkedEntityType.rawValue,
      inspection.linkedEntityID,
      inspection.orderID?.uuidString ?? "",
      inspection.shipmentGroupID?.uuidString ?? "",
      inspection.packageContentID?.uuidString ?? "",
      inspection.procurementRequestID?.uuidString ?? "",
      inspection.returnClaimID?.uuidString ?? "",
      inspection.destinationAddressID?.uuidString ?? "",
      inspection.customerProfileID?.uuidString ?? "",
      inspection.inspectionType.rawValue,
      inspection.inspectionStatus.rawValue,
      inspection.expectedItemSummary,
      inspection.receivedItemSummary,
      "\(inspection.quantityExpected)",
      "\(inspection.quantityReceived)",
      inspection.conditionSummary,
      inspection.discrepancyType.rawValue,
      inspection.discrepancySummary,
      inspection.assignedInspectorTeam,
      inspection.inspectionDate,
      inspection.dueDate,
      inspection.riskLevel.rawValue,
      inspection.createdDate,
      inspection.lastReviewedDate,
      inspection.reviewState.rawValue,
      order?.orderNumber ?? "",
      order?.store ?? "",
      order?.customer ?? "",
      order?.recipientEmail ?? "",
      order?.trackingNumber ?? "",
      order?.carrier ?? "",
      order?.destination ?? ""
    ]
    searchParts.append(contentsOf: inspection.carrierTrackingEventIDs.map(\.uuidString))
    searchParts.append(contentsOf: inspection.evidenceAttachmentIDs.map(\.uuidString))
    searchParts.append(contentsOf: inventoryReceipts.map(\.title))
    searchParts.append(contentsOf: storageLocations.map(\.title))
    searchParts.append(contentsOf: custodyRecords.map(\.title))
    searchParts.append(contentsOf: labelReferences.map(\.title))
    searchParts.append(contentsOf: scanSessions.map(\.title))
    searchParts.append(contentsOf: shipmentManifests.map(\.title))
    searchParts.append(contentsOf: dispatchChecklists.map(\.title))
    let searchableText = searchParts.joined(separator: " ")
    return searchableText.localizedLowercase.contains(query)
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
  @State private var feedbackMessage: String?

  private var linkedIntakeEmails: [ForwardedEmailIntake] {
    guard let store, let linkedOrder else { return [] }
    return store.linkedIntakeEmails(for: linkedOrder)
  }

  private var linkedWishlistItems: [WishlistItem] {
    guard let store, let linkedOrder else { return [] }
    return store.activeWishlistItemsLinked(to: linkedOrder)
  }

  private var inspectionReadinessWarnings: [String] {
    var warnings: [String] = []
    if inspection.inspectionStatus == .blocked {
      warnings.append("Blocked")
    } else if inspection.inspectionStatus == .pending {
      warnings.append("Inspection pending")
    } else if inspection.inspectionStatus == .discrepancy {
      warnings.append("Discrepancy open")
    }
    if inspection.discrepancyType != .none {
      warnings.append(inspection.discrepancyType.rawValue)
    }
    if inspection.quantityExpected != inspection.quantityReceived {
      warnings.append("Quantity mismatch")
    }
    if inspection.reviewState != .accepted {
      warnings.append("Review pending")
    }
    return warnings
  }

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

      if !linkedIntakeEmails.isEmpty || !linkedWishlistItems.isEmpty || !inspectionReadinessWarnings.isEmpty {
        receivingInspectionInboxSourceTrail
      }

      InventoryReceiptStrip(receipts: inventoryReceipts)
      StorageLocationStrip(locations: storageLocations)
      CustodyRecordStrip(records: custodyRecords)
      LabelReferenceStrip(records: labelReferences)
      ScanSessionStrip(records: scanSessions)

      if let feedbackMessage {
        ReceivingInspectionActionFeedbackPanel(message: feedbackMessage)
      }

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Inspected", systemImage: "checkmark.seal.fill") {
          onInspected()
          feedbackMessage = "Inspection marked inspected locally. Confirm quantities, condition, and evidence before closing related follow-up."
        }
          .buttonStyle(.bordered)
        Button("Discrepancy", systemImage: "exclamationmark.triangle.fill") {
          onDiscrepancy()
          feedbackMessage = "Inspection marked with a local discrepancy. Route task, draft, or custody follow-up if the issue blocks receiving."
        }
          .buttonStyle(.bordered)
        Button("Resolved", systemImage: "checkmark.circle.fill") {
          onResolved()
          feedbackMessage = "Inspection discrepancy resolved locally. Check inventory receipt and custody context before dispatch handoff."
        }
          .buttonStyle(.bordered)
        Button("Blocked", systemImage: "hand.raised.fill") {
          onBlocked()
          feedbackMessage = "Inspection blocked locally. Use a task or draft if someone needs to act on the receiving exception."
        }
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.shield.fill") {
          onReviewed()
          feedbackMessage = "Inspection marked reviewed locally. No scanner, inventory system, or external service was contacted."
        }
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Review task created from this inspection for local receiving follow-up."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Draft message created from this inspection. It remains local until a person sends anything outside ParcelOps."
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
          feedbackMessage = "Inspection removed locally. Linked mailbox, warehouse, carrier, and order systems were not changed."
        }
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      ReceivingInspectionEditView(inspection: inspection) { updatedInspection in
        onSave(updatedInspection)
        feedbackMessage = "Inspection details saved locally. Recheck any linked order, receipt, or evidence context if values changed."
      }
    }
  }

  private var receivingInspectionInboxSourceTrail: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label("Inbox inspection follow-up", systemImage: "envelope.open.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(sourceTrailDescription)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactMetadataGrid(minimumWidth: 140) {
        ForEach(Array(inspectionReadinessWarnings.prefix(4)), id: \.self) { warning in
          Badge(warning, color: .orange)
        }
        if let linkedOrder {
          Badge(linkedOrder.orderNumber, color: .blue)
        }
        ForEach(linkedWishlistItems.prefix(2)) { item in
          Badge("Wishlist \(item.itemName)", color: .pink)
        }
        ForEach(linkedIntakeEmails.prefix(3)) { email in
          if let store {
            let source = store.intakeSourceSummary(for: email)
            Badge(source.label, color: sourceColor(for: source.tone))
          }
          Badge(email.detectedTrackingNumber, color: email.detectedTrackingNumber.isPlaceholderValidationValue ? .orange : .teal)
        }
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
  }

  private var sourceTrailDescription: String {
    if !linkedWishlistItems.isEmpty && !inspectionReadinessWarnings.isEmpty {
      return "This inspection is tied to a Wishlist-linked order and still needs local condition, quantity, discrepancy, or review follow-up."
    }
    if !linkedWishlistItems.isEmpty {
      return "Wishlist purchase context is linked to this receiving inspection. Confirm the item physically matches the purchase handoff before closing."
    }
    if !inspectionReadinessWarnings.isEmpty && !linkedIntakeEmails.isEmpty {
      return "This inspection is tied to an Inbox-created order and still needs local condition, quantity, discrepancy, or review follow-up."
    }
    if !inspectionReadinessWarnings.isEmpty {
      return "This inspection still needs local condition, quantity, discrepancy, or review follow-up."
    }
    return "Inbox intake context is linked to this receiving inspection. Provider IDs stay in Audit/details."
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
}

private struct ReceivingInspectionActionFeedbackPanel: View {
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
