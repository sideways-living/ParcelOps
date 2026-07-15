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
        inboxInventoryReceiptCoverage
        gmailInventoryReceiptReadinessPanel

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

  private var inboxInventoryReceiptCoverage: some View {
    let inboxOrders = store.intakeLinkedOrders
    let sourceOrders = store.operatorSourceOrders
    let linkedReceipts = receiptsLinkedToInboxOrders
    let actionReceipts = receiptsNeedingInventoryAction
    let missingReceiptCount = inboxOrdersMissingReceipt.count

    return SettingsPanel(title: "Inbox and Wishlist inventory handoff", symbol: "tray.and.arrow.down.fill") {
      VStack(alignment: .leading, spacing: 10) {
        Text("Shows whether orders created from Inbox intake or Wishlist purchase handoff have a local receipt, storage, acceptance, and handoff path.")
          .font(.caption)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 150) {
          Badge("\(store.intakeLinkedOrderCount) Inbox orders", color: .blue)
          Badge("\(store.wishlistLinkedOrderCount) Wishlist orders", color: .pink)
          Badge("\(linkedReceipts.count) linked receipts", color: .teal)
          Badge("\(actionReceipts.count) need action", color: actionReceipts.isEmpty ? .green : .orange)
          Badge("\(missingReceiptCount) missing receipt", color: missingReceiptCount == 0 ? .green : .orange)
        }

        if !receiptProviderRows.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Mailbox source for inventory")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
              ForEach(receiptProviderRows, id: \.label) { row in
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

        if sourceOrders.isEmpty {
          Text("No Inbox-created or Wishlist-linked orders are present yet. Create or link an order from Inbox/Wishlist to track receiving and stock handoff here.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if linkedReceipts.isEmpty {
          Text("Inbox-created or Wishlist-linked orders do not have inventory receipts yet. Add a receipt when stock is received or handed to a team.")
            .font(.caption)
            .foregroundStyle(.orange)
        } else {
          ForEach(Array(actionReceipts.prefix(3))) { receipt in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: receipt.stockHandoffStatus == .rejected ? "xmark.circle.fill" : "archivebox.fill")
                .foregroundStyle(receipt.stockHandoffStatus == .rejected ? .red : .orange)
              VStack(alignment: .leading, spacing: 2) {
                Text(receipt.title)
                  .font(.caption.bold())
                Text(inventoryActionSummary(for: receipt))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Badge(receipt.stockHandoffStatus.rawValue, color: receipt.stockHandoffStatus.color)
            }
          }

          if actionReceipts.isEmpty {
            Text("Linked inventory receipts look stocked, assigned, and reviewed for the current Inbox-created and Wishlist-linked orders.")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else if actionReceipts.count > 3 {
            Text("\(actionReceipts.count - 3) more linked inventory receipts need stock, storage, owner, or review follow-up.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private var receiptProviderRows: [(label: String, count: Int, detail: String, symbol: String, color: Color)] {
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
        detail = "SpaceMail intake can start inventory receipt and handoff checks after an Inbox order is linked or created."
      case "gmail":
        detail = "Gmail intake can start inventory receipt and handoff checks after an Inbox order is linked or created."
      case "mock":
        detail = "Mock mailbox intake supports local inventory receipt testing. Confirm live provider context before handoff."
      default:
        detail = "Local mailbox intake can start inventory receipt checks once linked to an order."
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

  private var gmailInventoryReceiptReadinessPanel: some View {
    GmailReleaseBoundaryPanel(
      store: store,
      title: "Gmail inventory receipt readiness",
      lead: "Gmail-origin intake should start inventory receipt or handoff work only after Gmail setup is ready and the imported Inbox order has confirmed receipt, storage, and owner context.",
      sourceMetricTitle: "Gmail receipt sources",
      sourceCount: gmailInventoryReceiptSourceCount,
      boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store tokens, connect inventory systems, scan barcodes, or change inventory receipt records automatically."
    )
  }

  private var gmailInventoryReceiptSourceCount: Int {
    receiptProviderRows
      .filter { $0.label.localizedCaseInsensitiveContains("Gmail") }
      .reduce(0) { total, row in total + row.count }
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




  private var receiptsLinkedToInboxOrders: [InventoryReceiptRecord] {
    let orderIDs = Set(store.operatorSourceOrders.map(\.id))
    return store.inventoryReceipts.filter { receipt in
      if let orderID = receipt.orderID, orderIDs.contains(orderID) {
        return true
      }
      if receipt.linkedEntityType == .order, let linkedID = UUID(uuidString: receipt.linkedEntityID), orderIDs.contains(linkedID) {
        return true
      }
      return false
    }
  }

  private var inboxOrdersMissingReceipt: [TrackedOrder] {
    let receiptOrderIDs = Set(receiptsLinkedToInboxOrders.compactMap { receipt -> UUID? in
      receipt.orderID ?? (receipt.linkedEntityType == .order ? UUID(uuidString: receipt.linkedEntityID) : nil)
    })
    return store.operatorSourceOrders.filter { !receiptOrderIDs.contains($0.id) }
  }


  private var receiptsNeedingInventoryAction: [InventoryReceiptRecord] {
    receiptsLinkedToInboxOrders.filter { receipt in
      receipt.stockHandoffStatus == .pending
        || receipt.stockHandoffStatus == .partiallyAccepted
        || receipt.stockHandoffStatus == .rejected
        || receipt.stockHandoffStatus == .needsReview
        || receipt.reviewState != .accepted
        || receipt.quantityRejected > 0
        || receipt.storageLocationSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || receipt.storageLocationSummary.localizedCaseInsensitiveContains("confirm")
        || receipt.assignedOwnerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || receipt.assignedOwnerTeam.localizedCaseInsensitiveContains("unassigned")
    }
  }

  private func inventoryActionSummary(for receipt: InventoryReceiptRecord) -> String {
    var parts: [String] = []
    if receipt.stockHandoffStatus == .pending { parts.append("stock or hand off") }
    if receipt.stockHandoffStatus == .partiallyAccepted || receipt.quantityRejected > 0 { parts.append("resolve partial/rejected quantity") }
    if receipt.stockHandoffStatus == .rejected || receipt.stockHandoffStatus == .needsReview { parts.append("review exception") }
    if receipt.storageLocationSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || receipt.storageLocationSummary.localizedCaseInsensitiveContains("confirm") { parts.append("confirm storage") }
    if receipt.assignedOwnerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || receipt.assignedOwnerTeam.localizedCaseInsensitiveContains("unassigned") { parts.append("assign owner") }
    if receipt.reviewState != .accepted { parts.append("mark reviewed") }
    return parts.isEmpty ? "Inventory receipt is stocked, assigned, and reviewed." : parts.joined(separator: ", ")
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
  @State private var feedbackMessage: String?

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

      if !inventoryReceiptWarnings.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Label("Inventory follow-up", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.bold())
            .foregroundStyle(.orange)
          ForEach(inventoryReceiptWarnings, id: \.self) { warning in
            Text(warning)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      if let store, let linkedOrder {
        let linkedEmails = store.linkedIntakeEmails(for: linkedOrder)
        let linkedWishlistItems = store.activeWishlistItemsLinked(to: linkedOrder)
        if !linkedEmails.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Label("Inbox inventory handoff", systemImage: "tray.and.arrow.down.fill")
              .font(.caption.bold())
              .foregroundStyle(.teal)
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
        if !linkedWishlistItems.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Label("Wishlist inventory handoff", systemImage: "star.square.fill")
              .font(.caption.bold())
              .foregroundStyle(.pink)
            CompactMetadataGrid(minimumWidth: 150) {
              ForEach(linkedWishlistItems.prefix(3)) { item in
                Badge(item.itemName, color: .pink)
                Badge(item.purchaseHandoff?.purchaseStatus ?? item.purchaseReadiness ?? item.status, color: .secondary)
              }
            }
            Text("Confirm the received item, accepted quantity, storage, and owner against the Wishlist purchase handoff before closing this receipt.")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.pink.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }

      if let feedbackMessage {
        InventoryReceiptActionFeedbackPanel(message: feedbackMessage)
      }

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Stocked", systemImage: "archivebox.fill") {
          onStocked()
          feedbackMessage = "Receipt marked stocked locally. Confirm storage location and custody before dispatch or handoff."
        }
          .buttonStyle(.bordered)
        Button("Handed off", systemImage: "arrow.left.arrow.right.square.fill") {
          onHandedOff()
          feedbackMessage = "Receipt marked handed off locally. Confirm custody and destination context if the item leaves storage."
        }
          .buttonStyle(.bordered)
        Button("Partial", systemImage: "plusminus.circle.fill") {
          onPartiallyAccepted()
          feedbackMessage = "Receipt marked partially accepted locally. Review rejected quantity and discrepancy follow-up."
        }
          .buttonStyle(.bordered)
        Button("Reject", systemImage: "xmark.circle.fill") {
          onRejected()
          feedbackMessage = "Receipt rejected locally. Create a task or draft if procurement, returns, or claims follow-up is needed."
        }
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.shield.fill") {
          onReviewed()
          feedbackMessage = "Receipt marked reviewed locally. No inventory API, scanner, or warehouse system was contacted."
        }
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Review task created from this inventory receipt for local follow-up."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Draft message created from this receipt. It remains local until a person sends anything outside ParcelOps."
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
          feedbackMessage = "Inventory receipt removed locally. No mailbox, warehouse, carrier, or order system was changed."
        }
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      InventoryReceiptEditView(receipt: receipt) { updatedReceipt in
        onSave(updatedReceipt)
        feedbackMessage = "Receipt details saved locally. Recheck storage, custody, and linked order context if values changed."
      }
    }
  }

  private var inventoryReceiptWarnings: [String] {
    var warnings: [String] = []
    if receipt.stockHandoffStatus == .pending {
      warnings.append("Receipt is pending; stock it or hand it off when the item is physically accounted for.")
    }
    if receipt.stockHandoffStatus == .partiallyAccepted || receipt.quantityRejected > 0 {
      warnings.append("Quantity is partially accepted or rejected; confirm discrepancy follow-up before closing.")
    }
    if receipt.stockHandoffStatus == .rejected || receipt.stockHandoffStatus == .needsReview {
      warnings.append("Receipt is rejected or needs review; route the exception before dispatch or handoff.")
    }
    if receipt.storageLocationSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || receipt.storageLocationSummary.localizedCaseInsensitiveContains("confirm") {
      warnings.append("Storage/location still needs confirmation.")
    }
    if receipt.assignedOwnerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || receipt.assignedOwnerTeam.localizedCaseInsensitiveContains("unassigned") {
      warnings.append("Owner or team is missing.")
    }
    if receipt.reviewState != .accepted {
      warnings.append("Review state is \(receipt.reviewState.rawValue.lowercased()); mark reviewed after local checks are complete.")
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

private struct InventoryReceiptActionFeedbackPanel: View {
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
