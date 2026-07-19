import SwiftUI

struct CustodyChainView: View {
  var store: ParcelOpsStore
  @State private var selectedStatus: CustodyStatus?
  @State private var custodianTeam = ""
  @State private var ownerTeam = ""
  @State private var selectedHandoffMethod: CustodyHandoffMethod?
  @State private var selectedRiskLevel: ShipmentRiskLevel?
  @State private var selectedLinkedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedReviewState: ReviewState?
  @State private var custodySearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var baseFilteredRecords: [CustodyRecord] {
    store.filteredCustodyRecords(
      custodyStatus: selectedStatus,
      custodianTeam: custodianTeam,
      ownerTeam: ownerTeam,
      handoffMethod: selectedHandoffMethod,
      riskLevel: selectedRiskLevel,
      linkedEntityType: selectedLinkedEntityType,
      reviewState: selectedReviewState
    )
  }

  private var filteredRecords: [CustodyRecord] {
    let query = custodySearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredRecords }
    return baseFilteredRecords.filter { custodyRecord($0, matches: query) }
  }

  private var hasActiveFilters: Bool {
    selectedStatus != nil
      || !custodianTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || selectedHandoffMethod != nil
      || selectedRiskLevel != nil
      || selectedLinkedEntityType != nil
      || selectedReviewState != nil
      || !custodySearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filterBar
        inboxCustodyCoverage
        gmailCustodyReadinessPanel

        SettingsPanel(title: "Custody chain records", symbol: "person.badge.shield.checkmark.fill") {
          HStack {
            Text("\(filteredRecords.count) visible custody records")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredRecords.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add custody", systemImage: "plus", action: store.addCustodyRecordPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredRecords.isEmpty {
            MVPEmptyState(title: "No custody records match this view", detail: hasActiveFilters ? "Clear search or filters to return to all local custody records." : "Add a local custody record to track possession, transfer, return, and dispute ownership.", symbol: "person.badge.shield.checkmark.fill", actionTitle: hasActiveFilters ? "Clear filters" : "Add custody", action: hasActiveFilters ? clearFilters : store.addCustodyRecordPlaceholder)
          } else {
            ForEach(filteredRecords) { record in
              CustodyRecordRow(record: record, store: store, linkedOrder: linkedOrder(for: record), labelReferences: store.suggestedLabelReferenceRecords(for: record), scanSessions: store.suggestedScanSessionRecords(for: record), shipmentManifests: store.suggestedShipmentManifestRecords(for: record), dispatchChecklists: store.suggestedDispatchReadinessChecklists(for: record)) { updatedRecord in
                store.updateCustodyRecord(updatedRecord)
              } onTransferred: {
                store.markCustodyRecordTransferred(record)
              } onReceived: {
                store.markCustodyRecordReceived(record)
              } onReturnedClosed: {
                store.markCustodyRecordReturnedClosed(record)
              } onDisputed: {
                store.markCustodyRecordDisputed(record)
              } onReviewed: {
                store.markCustodyRecordReviewed(record)
              } onCreateTask: {
                store.createReviewTask(from: record)
              } onCreateDraft: {
                store.createDraftMessage(from: record)
              } onRemove: {
                store.removeCustodyRecord(record)
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
        Text("Custody Chain")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Local possession, handoff, and responsibility tracking for parcels and operational records.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(store.openCustodyTransfers.count) open transfers", color: .blue)
        Badge("\(store.disputedCustodyRecords.count) disputed", color: .red)
      }
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search custody, custodian, owner, location, receipt, label, scan, order, or evidence", text: $custodySearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Status", selection: $selectedStatus) {
        Text("All status").tag(nil as CustodyStatus?)
        ForEach(CustodyStatus.allCases) { status in
          Text(status.rawValue).tag(status as CustodyStatus?)
        }
      }

      TextField("Custodian/team", text: $custodianTeam)
        .textFieldStyle(.roundedBorder)

      TextField("Owner/team", text: $ownerTeam)
        .textFieldStyle(.roundedBorder)

      Picker("Method", selection: $selectedHandoffMethod) {
        Text("All methods").tag(nil as CustodyHandoffMethod?)
        ForEach(CustodyHandoffMethod.allCases) { method in
          Text(method.rawValue).tag(method as CustodyHandoffMethod?)
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

  private var inboxCustodyCoverage: some View {
    let sourceOrders = store.operatorSourceOrders
    let linkedRecords = custodyLinkedToInboxOrders
    let actionRecords = custodyNeedingAction
    let missingCustodyCount = inboxOrdersMissingCustody.count

    return SettingsPanel(title: "Inbox and Wishlist custody readiness", symbol: "person.badge.shield.checkmark.fill") {
      VStack(alignment: .leading, spacing: 10) {
        Text("Checks whether orders created from Inbox intake or Wishlist purchase handoff have clear local possession, custodian, transfer, and return/close status.")
          .font(.caption)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 150) {
          Badge("\(store.intakeLinkedOrderCount) Inbox orders", color: .blue)
          Badge("\(store.wishlistLinkedOrderCount) Wishlist orders", color: .pink)
          Badge("\(linkedRecords.count) linked custody", color: .teal)
          Badge("\(actionRecords.count) need action", color: actionRecords.isEmpty ? .green : .orange)
          Badge("\(missingCustodyCount) missing custody", color: missingCustodyCount == 0 ? .green : .orange)
        }

        if !custodyProviderRows.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Mailbox source for custody")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
              ForEach(custodyProviderRows, id: \.label) { row in
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
          Text("No source-created or Wishlist-linked orders are present yet. Create an order from Inbox or complete a Wishlist purchase handoff before tracking custody.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if linkedRecords.isEmpty {
          Text("Source-created or Wishlist-linked orders do not have custody records yet. Add custody when responsibility or possession changes.")
            .font(.caption)
            .foregroundStyle(.orange)
        } else {
          ForEach(Array(actionRecords.prefix(3))) { record in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: record.custodyStatus == .disputed ? "exclamationmark.triangle.fill" : "person.badge.shield.checkmark.fill")
                .foregroundStyle(record.custodyStatus == .disputed ? .red : .orange)
              VStack(alignment: .leading, spacing: 2) {
                Text(record.title)
                  .font(.caption.bold())
                Text(custodyActionSummary(for: record))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Badge(record.custodyStatus.rawValue, color: record.custodyStatus.color)
            }
          }

          if actionRecords.isEmpty {
            Text("Linked custody records look received/closed, assigned, located, and reviewed for current source-created and Wishlist-linked orders.")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else if actionRecords.count > 3 {
            Text("\(actionRecords.count - 3) more linked custody records need transfer, custodian, location, or review follow-up.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private var custodyProviderRows: [(label: String, count: Int, detail: String, symbol: String, color: Color)] {
    var counts: [String: Int] = [:]
    var tones: [String: String] = [:]
    for order in store.operatorSourceOrders {
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
        detail = "SpaceMail intake can drive custody checks after an Inbox order is linked, stocked, transferred, or prepared for dispatch."
      case "gmail":
        detail = "Gmail intake can drive custody checks after an Inbox order is linked, stocked, transferred, or prepared for dispatch."
      case "mock":
        detail = "Mock mailbox intake supports local custody testing. Confirm live provider context before physical handoff."
      default:
        detail = "Local mailbox intake can drive custody checks once linked to an order."
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

  private var gmailCustodyReadinessPanel: some View {
    VStack(alignment: .leading, spacing: 10) {
      GmailReleaseBoundaryPanel(
        store: store,
        title: "Gmail custody readiness",
        lead: "Gmail-origin intake should create custody work only after Gmail setup is ready and the imported Inbox order has confirmed possession, source, destination, and owner context.",
        sourceMetricTitle: "Gmail custody sources",
        sourceCount: gmailCustodySourceCount,
        boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store tokens, capture signatures, connect access-control systems, or change custody records automatically."
      )
      Microsoft365ReleaseBoundaryPanel(
        store: store,
        title: "Outlook custody readiness",
        lead: "Outlook-origin intake should create custody work only after Microsoft setup, Graph diagnostics, and confirmed Inbox order possession, source, destination, and owner context are clear.",
        sourceMetricTitle: "Outlook custody sources",
        sourceCount: microsoft365CustodySourceCount,
        boundaryDetail: "Local-only boundary: this panel does not start Microsoft sign-in, request tokens, fetch Outlook messages, capture signatures, connect access-control systems, or change custody records automatically."
      )
    }
  }

  private var gmailCustodySourceCount: Int {
    custodyProviderRows
      .filter { $0.label.localizedCaseInsensitiveContains("Gmail") }
      .reduce(0) { total, row in total + row.count }
  }

  private var microsoft365CustodySourceCount: Int {
    custodyProviderRows
      .filter { $0.label.localizedCaseInsensitiveContains("Microsoft 365") || $0.label.localizedCaseInsensitiveContains("Outlook") }
      .reduce(0) { total, row in total + row.count }
  }

  private func clearFilters() {
    selectedStatus = nil
    custodianTeam = ""
    ownerTeam = ""
    selectedHandoffMethod = nil
    selectedRiskLevel = nil
    selectedLinkedEntityType = nil
    selectedReviewState = nil
    custodySearchText = ""
  }

  private func linkedOrder(for record: CustodyRecord) -> TrackedOrder? {
    let orderID = record.orderID ?? (record.linkedEntityType == .order ? UUID(uuidString: record.linkedEntityID) : nil)
    guard let orderID else { return nil }
    return store.orders.first { $0.id == orderID }
  }




  private var custodyLinkedToInboxOrders: [CustodyRecord] {
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
    let locationIDs = Set(store.storageLocations.filter { location in
      !Set(location.orderIDs).isDisjoint(with: orderIDs) || !Set(location.inventoryReceiptIDs).isDisjoint(with: receiptIDs)
    }.map(\.id))

    return store.custodyRecords.filter { record in
      (record.orderID.map { orderIDs.contains($0) } ?? false)
        || (record.inventoryReceiptID.map { receiptIDs.contains($0) } ?? false)
        || (record.storageLocationID.map { locationIDs.contains($0) } ?? false)
        || (record.sourceLocationID.map { locationIDs.contains($0) } ?? false)
        || (record.destinationLocationID.map { locationIDs.contains($0) } ?? false)
        || (record.linkedEntityType == .order && UUID(uuidString: record.linkedEntityID).map { orderIDs.contains($0) } == true)
    }
  }

  private var inboxOrdersMissingCustody: [TrackedOrder] {
    let custodyOrderIDs = Set(custodyLinkedToInboxOrders.compactMap { record -> UUID? in
      record.orderID ?? (record.linkedEntityType == .order ? UUID(uuidString: record.linkedEntityID) : nil)
    })
    return store.operatorSourceOrders.filter { !custodyOrderIDs.contains($0.id) }
  }


  private var custodyNeedingAction: [CustodyRecord] {
    custodyLinkedToInboxOrders.filter { record in
      record.custodyStatus == .pendingTransfer
        || record.custodyStatus == .transferred
        || record.custodyStatus == .disputed
        || record.custodyStatus == .needsReview
        || record.reviewState != .accepted
        || record.riskLevel == .high
        || record.riskLevel == .critical
        || record.expectedReturnCloseDate.localizedCaseInsensitiveContains("overdue")
        || record.expectedReturnCloseDate.localizedCaseInsensitiveContains("today")
        || record.currentCustodianTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || record.currentCustodianTeam.localizedCaseInsensitiveContains("unassigned")
        || record.currentCustodianTeam.localizedCaseInsensitiveContains("unknown")
        || record.sourceLocationID == nil
        || record.destinationLocationID == nil
    }
  }

  private func custodyActionSummary(for record: CustodyRecord) -> String {
    var parts: [String] = []
    if record.custodyStatus == .pendingTransfer || record.custodyStatus == .transferred { parts.append("close transfer") }
    if record.custodyStatus == .disputed || record.custodyStatus == .needsReview { parts.append("resolve custody exception") }
    if record.currentCustodianTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || record.currentCustodianTeam.localizedCaseInsensitiveContains("unassigned") || record.currentCustodianTeam.localizedCaseInsensitiveContains("unknown") { parts.append("confirm custodian") }
    if record.sourceLocationID == nil || record.destinationLocationID == nil { parts.append("confirm source/destination") }
    if record.expectedReturnCloseDate.localizedCaseInsensitiveContains("overdue") || record.expectedReturnCloseDate.localizedCaseInsensitiveContains("today") { parts.append("check due date") }
    if record.riskLevel == .high || record.riskLevel == .critical { parts.append("review risk") }
    if record.reviewState != .accepted { parts.append("mark reviewed") }
    return parts.isEmpty ? "Custody is received/closed, assigned, located, and reviewed." : parts.joined(separator: ", ")
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


  private func custodyRecord(_ record: CustodyRecord, matches query: String) -> Bool {
    let order = linkedOrder(for: record)
    let labelReferences = store.suggestedLabelReferenceRecords(for: record)
    let scanSessions = store.suggestedScanSessionRecords(for: record)
    let shipmentManifests = store.suggestedShipmentManifestRecords(for: record)
    let dispatchChecklists = store.suggestedDispatchReadinessChecklists(for: record)
    var searchParts: [String] = [
      record.id.uuidString,
      record.title,
      record.linkedEntityType.rawValue,
      record.linkedEntityID,
      record.currentCustodianTeam,
      record.previousCustodianTeam,
      record.custodyStatus.rawValue,
      record.custodyReason,
      record.handoffMethod.rawValue,
      record.assignedOwnerTeam,
      record.transferDate,
      record.expectedReturnCloseDate,
      record.notes,
      record.riskLevel.rawValue,
      record.createdDate,
      record.lastReviewedDate,
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
      record.sourceLocationID?.uuidString ?? "",
      record.destinationLocationID?.uuidString ?? "",
      record.inventoryReceiptID?.uuidString ?? "",
      record.storageLocationID?.uuidString ?? "",
      record.receivingInspectionID?.uuidString ?? "",
      record.orderID?.uuidString ?? "",
      record.shipmentGroupID?.uuidString ?? "",
      record.packageContentID?.uuidString ?? ""
    ])
    searchParts.append(contentsOf: record.evidenceAttachmentIDs.map(\.uuidString))
    searchParts.append(contentsOf: labelReferences.flatMap { [$0.title, $0.labelValuePlaceholder, $0.associatedCarrier] })
    searchParts.append(contentsOf: scanSessions.flatMap { [$0.title, $0.expectedLabelReferenceValue, $0.capturedValuePlaceholder, $0.assignedOperatorTeam] })
    searchParts.append(contentsOf: shipmentManifests.flatMap { [$0.title, $0.manifestReferencePlaceholder, $0.carrierCourier, $0.destinationSummary] })
    searchParts.append(contentsOf: dispatchChecklists.flatMap { [$0.title, $0.checklistType.rawValue, $0.checklistStatus.rawValue, $0.assignedOwnerTeam] })
    if let order {
      let mailboxSummaries = store.mailboxSourceSummaries(for: order)
      searchParts.append(contentsOf: mailboxSummaries.map(\.providerName))
      searchParts.append(contentsOf: mailboxSummaries.map(\.mailboxLabel))
      searchParts.append(contentsOf: mailboxSummaries.map(\.statusLabel))
      searchParts.append(contentsOf: mailboxSummaries.map(\.detailText))
    }
    return searchParts.joined(separator: " ").localizedLowercase.contains(query)
  }
}

struct CustodyRecordRow: View {
  var record: CustodyRecord
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
  var labelReferences: [LabelReferenceRecord] = []
  var scanSessions: [ScanSessionRecord] = []
  var shipmentManifests: [ShipmentManifestRecord] = []
  var dispatchChecklists: [DispatchReadinessChecklist] = []
  var onSave: (CustodyRecord) -> Void
  var onTransferred: () -> Void
  var onReceived: () -> Void
  var onReturnedClosed: () -> Void
  var onDisputed: () -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false
  @State private var feedbackMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: record.handoffMethod.symbol)
          .foregroundStyle(record.riskLevel.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(record.title)
                .font(.headline)
              Text("\(record.currentCustodianTeam) from \(record.previousCustodianTeam)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(record.custodyStatus.rawValue, color: record.custodyStatus.color)
          }

          Text(record.custodyReason)
            .foregroundStyle(.secondary)
          Text("\(record.handoffMethod.rawValue) • Owner \(record.assignedOwnerTeam) • Expected \(record.expectedReturnCloseDate)")
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

      LabelReferenceStrip(records: labelReferences)
      ScanSessionStrip(records: scanSessions)

      if !custodyWarnings.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Label("Custody follow-up", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.bold())
            .foregroundStyle(.orange)
          ForEach(custodyWarnings, id: \.self) { warning in
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
            Label("Inbox/Wishlist custody source", systemImage: "tray.and.arrow.down.fill")
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
        OrderMailboxSourceTrailPanel(
          summaries: store.mailboxSourceSummaries(for: linkedOrder),
          title: "Mailbox provider custody trail",
          symbol: "arrow.left.arrow.right.square.fill"
        )
      }

      if let feedbackMessage {
        CustodyActionFeedbackPanel(message: feedbackMessage)
      }

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Transferred", systemImage: "arrow.right.circle.fill") {
          onTransferred()
          feedbackMessage = "Custody marked transferred locally. Confirm destination location and receiving owner before closing."
        }
          .buttonStyle(.bordered)
        Button("Received", systemImage: "checkmark.circle.fill") {
          onReceived()
          feedbackMessage = "Custody marked received locally. Check linked receipt, label, scan, or order context if follow-up remains."
        }
          .buttonStyle(.bordered)
        Button("Closed", systemImage: "checkmark.seal.fill") {
          onReturnedClosed()
          feedbackMessage = "Custody returned or closed locally. No signature capture, scanner, or warehouse system was contacted."
        }
          .buttonStyle(.bordered)
        Button("Dispute", systemImage: "exclamationmark.triangle.fill") {
          onDisputed()
          feedbackMessage = "Custody disputed locally. Create a task or draft if another person needs to resolve possession."
        }
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.shield.fill") {
          onReviewed()
          feedbackMessage = "Custody record marked reviewed locally. No external custody, scanner, or access-control system was contacted."
        }
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Review task created from this custody record for local handoff follow-up."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Draft message created from this custody record. It remains local until a person sends anything outside ParcelOps."
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
          feedbackMessage = "Custody record removed locally. No mailbox, warehouse, scanner, or order system was changed."
        }
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      CustodyRecordEditView(record: record) { updatedRecord in
        onSave(updatedRecord)
        feedbackMessage = "Custody details saved locally. Recheck source/destination location and owner context if values changed."
      }
    }
  }

  private var custodyWarnings: [String] {
    var warnings: [String] = []
    if record.custodyStatus == .pendingTransfer || record.custodyStatus == .transferred {
      warnings.append("Custody transfer is open; mark received or closed when possession is confirmed.")
    }
    if record.custodyStatus == .disputed || record.custodyStatus == .needsReview {
      warnings.append("Custody is disputed or needs review; resolve before relying on this handoff.")
    }
    if record.currentCustodianTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || record.currentCustodianTeam.localizedCaseInsensitiveContains("unassigned") || record.currentCustodianTeam.localizedCaseInsensitiveContains("unknown") {
      warnings.append("Current custodian/team needs confirmation.")
    }
    if record.sourceLocationID == nil || record.destinationLocationID == nil {
      warnings.append("Source or destination location is missing.")
    }
    if record.expectedReturnCloseDate.localizedCaseInsensitiveContains("overdue") || record.expectedReturnCloseDate.localizedCaseInsensitiveContains("today") {
      warnings.append("Expected return/close date needs immediate follow-up.")
    }
    if record.riskLevel == .high || record.riskLevel == .critical {
      warnings.append("Risk is \(record.riskLevel.rawValue.lowercased()); confirm custody handling.")
    }
    if record.reviewState != .accepted {
      warnings.append("Review state is \(record.reviewState.rawValue.lowercased()); mark reviewed after local checks are complete.")
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

private struct CustodyActionFeedbackPanel: View {
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

struct CustodyRecordEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: CustodyRecord
  var onSave: (CustodyRecord) -> Void

  init(record: CustodyRecord, onSave: @escaping (CustodyRecord) -> Void) {
    self._draft = State(initialValue: record)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Custody") {
          TextField("Title", text: $draft.title)
          Picker("Status", selection: $draft.custodyStatus) {
            ForEach(CustodyStatus.allCases) { status in
              Text(status.rawValue).tag(status)
            }
          }
          Picker("Handoff method", selection: $draft.handoffMethod) {
            ForEach(CustodyHandoffMethod.allCases) { method in
              Text(method.rawValue).tag(method)
            }
          }
          TextField("Custody reason", text: $draft.custodyReason, axis: .vertical)
        }

        Section("Teams and dates") {
          TextField("Current custodian/team", text: $draft.currentCustodianTeam)
          TextField("Previous custodian/team", text: $draft.previousCustodianTeam)
          TextField("Assigned owner/team", text: $draft.assignedOwnerTeam)
          TextField("Transfer date", text: $draft.transferDate)
          TextField("Expected return/close date", text: $draft.expectedReturnCloseDate)
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
          TextField("Notes", text: $draft.notes, axis: .vertical)
        }
      }
      .navigationTitle("Edit Custody")
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
