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
    let query = manifestSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
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
        inboxManifestCoverage
        gmailManifestReleaseBoundary
        if !store.gmailMailboxConnections.isEmpty {
          GmailPostRefreshActionCard(plan: store.gmailPostRefreshActionPlan)
        }

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
              detail: hasActiveFilters ? "Clear search or filters to return to all shipment manifests." : "Add a local manifest to prepare an outbound dispatch batch.",
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
    VStack(alignment: .leading, spacing: 10) {
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

      CompactActionRow {
        NavigationLink {
          DispatchView(store: store)
        } label: {
          Label("Open Dispatch", systemImage: "paperplane.fill")
        }
        NavigationLink {
          DispatchReadinessView(store: store)
        } label: {
          Label("Open Readiness", systemImage: "checkmark.rectangle.stack.fill")
        }
        NavigationLink {
          AuditView(store: store)
        } label: {
          Label("Open Audit", systemImage: "list.clipboard.fill")
        }
      }
      .buttonStyle(.bordered)
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

      TextField("Carrier/courier", text: $carrierCourier)
        .textFieldStyle(.roundedBorder)

      Picker("Status", selection: $selectedStatus) {
        Text("All status").tag(nil as ShipmentManifestDispatchStatus?)
        ForEach(ShipmentManifestDispatchStatus.allCases) { status in Text(status.rawValue).tag(status as ShipmentManifestDispatchStatus?) }
      }

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
    carrierCourier = ""
    selectedStatus = nil
    ownerTeam = ""
    selectedRiskLevel = nil
    selectedLinkedEntityType = nil
    selectedReviewState = nil
    manifestSearchText = ""
  }

  private var inboxManifestCoverage: some View {
    let sourceOrders = store.operatorSourceOrders
    let linkedManifests = manifestsLinkedToInboxOrders
    let actionManifests = manifestsNeedingAction
    let missingManifestCount = inboxOrdersMissingManifest.count

    return SettingsPanel(title: "Order manifest readiness", symbol: "list.bullet.clipboard.fill") {
      VStack(alignment: .leading, spacing: 10) {
        Text("Checks whether orders created from mailbox intake or Wishlist handoffs have outbound manifest setup, included orders, handoff location, labels, scans, and dispatch status.")
          .font(.caption)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 150) {
          Badge("\(store.intakeLinkedOrderCount) Inbox orders", color: .blue)
          Badge("\(store.wishlistLinkedOrderCount) Wishlist orders", color: .pink)
          Badge("\(linkedManifests.count) linked manifests", color: .teal)
          Badge("\(actionManifests.count) need action", color: actionManifests.isEmpty ? .green : .orange)
          Badge("\(missingManifestCount) missing manifests", color: missingManifestCount == 0 ? .green : .orange)
        }

        if sourceOrders.isEmpty {
          Text("No source-created or Wishlist-linked orders are present yet. Create or link an order from Inbox or Wishlist before checking manifest readiness.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if linkedManifests.isEmpty {
          Text("Source-created and Wishlist-linked orders do not have shipment manifests yet. Add or create dispatch setup before outbound handoff.")
            .font(.caption)
            .foregroundStyle(.orange)
        } else {
          ForEach(Array(actionManifests.prefix(3))) { manifest in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: manifest.dispatchStatus == .blockedNeedsReview ? "exclamationmark.triangle.fill" : "list.bullet.clipboard.fill")
                .foregroundStyle(manifest.dispatchStatus == .blockedNeedsReview ? .red : .orange)
              VStack(alignment: .leading, spacing: 2) {
                Text(manifest.title)
                  .font(.caption.bold())
                Text(manifestActionSummary(for: manifest))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Badge(manifest.dispatchStatus.rawValue, color: manifest.dispatchStatus.color)
            }
          }

          if actionManifests.isEmpty {
            Text("Linked manifests look prepared or handed off with orders, scans, labels, and handoff locations in place.")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else if actionManifests.count > 3 {
            Text("\(actionManifests.count - 3) more linked manifests need order, label, scan, handoff location, status, or review follow-up.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private var gmailManifestReleaseBoundary: some View {
    VStack(alignment: .leading, spacing: 10) {
      GmailReleaseBoundaryPanel(
        store: store,
        title: "Gmail manifest readiness",
        lead: "Gmail setup, sign-in, labels, classifier review, Inbox handoff, and audit evidence should not create shipment manifests directly. Manifest work starts after a confirmed Inbox row or Wishlist source becomes an order or shipment group.",
        sourceMetricTitle: "Gmail manifest sources",
        sourceCount: gmailManifestSourceCount,
        boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store tokens, call carrier APIs, book couriers, print labels, or change shipment manifests automatically."
      )

      Microsoft365ReleaseBoundaryPanel(
        store: store,
        title: "Outlook manifest readiness",
        lead: "Microsoft setup, sign-in, Graph diagnostics, Inbox handoff, and audit evidence should not create shipment manifests directly. Manifest work starts after a confirmed Inbox row or Wishlist source becomes an order or shipment group.",
        sourceMetricTitle: "Outlook manifest sources",
        sourceCount: microsoft365ManifestSourceCount,
        boundaryDetail: "Local-only boundary: this panel does not start Microsoft sign-in, request tokens, fetch Outlook messages, call carrier APIs, book couriers, print labels, mutate mail, or change shipment manifests automatically."
      )
    }
  }

  private var gmailManifestSourceCount: Int {
    store.operatorSourceOrders
      .flatMap { store.linkedIntakeEmails(for: $0) }
      .filter { store.intakeSourceSummary(for: $0).label.localizedCaseInsensitiveContains("Gmail") }
      .count
  }

  private var microsoft365ManifestSourceCount: Int {
    store.operatorSourceOrders
      .flatMap { store.linkedIntakeEmails(for: $0) }
      .filter {
        let label = store.intakeSourceSummary(for: $0).label
        return label.localizedCaseInsensitiveContains("Microsoft 365") || label.localizedCaseInsensitiveContains("Outlook")
      }
      .count
  }


  private var manifestsLinkedToInboxOrders: [ShipmentManifestRecord] {
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
    let custodyIDs = Set(store.custodyRecords.filter { record in
      (record.orderID.map { orderIDs.contains($0) } ?? false)
        || (record.inventoryReceiptID.map { receiptIDs.contains($0) } ?? false)
    }.map(\.id))
    let labelIDs = Set(store.labelReferenceRecords.filter { record in
      (record.orderID.map { orderIDs.contains($0) } ?? false)
        || (record.inventoryReceiptID.map { receiptIDs.contains($0) } ?? false)
        || (record.custodyRecordID.map { custodyIDs.contains($0) } ?? false)
    }.map(\.id))
    let scanIDs = Set(store.scanSessionRecords.filter { record in
      (record.orderID.map { orderIDs.contains($0) } ?? false)
        || (record.inventoryReceiptID.map { receiptIDs.contains($0) } ?? false)
        || (record.custodyRecordID.map { custodyIDs.contains($0) } ?? false)
        || (record.linkedLabelReferenceID.map { labelIDs.contains($0) } ?? false)
    }.map(\.id))

    return store.shipmentManifestRecords.filter { manifest in
      !Set(manifest.includedOrderIDs).isDisjoint(with: orderIDs)
        || !Set(manifest.inventoryReceiptIDs).isDisjoint(with: receiptIDs)
        || !Set(manifest.custodyRecordIDs).isDisjoint(with: custodyIDs)
        || !Set(manifest.labelReferenceIDs).isDisjoint(with: labelIDs)
        || !Set(manifest.scanSessionIDs).isDisjoint(with: scanIDs)
        || (manifest.linkedEntityType == .order && UUID(uuidString: manifest.linkedEntityID).map { orderIDs.contains($0) } == true)
    }
  }

  private var inboxOrdersMissingManifest: [TrackedOrder] {
    let manifestOrderIDs = Set(manifestsLinkedToInboxOrders.flatMap(\.includedOrderIDs))
    return store.operatorSourceOrders.filter { order in
      !manifestOrderIDs.contains(order.id)
        && !manifestsLinkedToInboxOrders.contains { manifest in
          manifest.linkedEntityType == .order && UUID(uuidString: manifest.linkedEntityID) == order.id
        }
    }
  }

  private var manifestsNeedingAction: [ShipmentManifestRecord] {
    manifestsLinkedToInboxOrders.filter { manifest in
      manifest.dispatchStatus == .draft
        || manifest.dispatchStatus == .prepared
        || manifest.dispatchStatus == .blockedNeedsReview
        || manifest.dispatchStatus == .reopened
        || manifest.reviewState != .accepted
        || manifest.riskLevel == .high
        || manifest.riskLevel == .critical
        || manifest.includedOrderIDs.isEmpty
        || manifest.handoffLocationStorageLocationID == nil
        || manifest.labelReferenceIDs.isEmpty
        || manifest.scanSessionIDs.isEmpty
        || manifest.assignedOwnerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
  }

  private func manifestActionSummary(for manifest: ShipmentManifestRecord) -> String {
    var parts: [String] = []
    if manifest.dispatchStatus == .draft || manifest.dispatchStatus == .reopened { parts.append("prepare manifest") }
    if manifest.dispatchStatus == .prepared { parts.append("dispatch or hand off") }
    if manifest.dispatchStatus == .blockedNeedsReview { parts.append("resolve block") }
    if manifest.includedOrderIDs.isEmpty { parts.append("add included orders") }
    if manifest.handoffLocationStorageLocationID == nil { parts.append("confirm handoff location") }
    if manifest.labelReferenceIDs.isEmpty { parts.append("link labels") }
    if manifest.scanSessionIDs.isEmpty { parts.append("link scans") }
    if manifest.assignedOwnerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { parts.append("assign owner") }
    if manifest.riskLevel == .high || manifest.riskLevel == .critical { parts.append("review risk") }
    if manifest.reviewState != .accepted { parts.append("mark reviewed") }
    return parts.isEmpty ? "Manifest is ready for the current dispatch path." : parts.joined(separator: ", ")
  }


  private func shipmentManifest(_ record: ShipmentManifestRecord, matches query: String) -> Bool {
    let linkedOrders = linkedOrders(for: record)
    let mailboxText = linkedOrders.flatMap { order in
      store.mailboxSourceSummaries(for: order).flatMap { summary in
        [
          summary.providerName,
          summary.mailboxLabel,
          summary.statusLabel,
          summary.detailText
        ]
      }
    }.joined(separator: " ")
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
      mailboxText,
      groupText,
      checklistText
    ].joined(separator: " ")
    return searchableText.localizedLowercase.contains(query)
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
  @State private var feedbackMessage: String?

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
            if record.isInboxDispatchHandoffSetup {
              Badge("Inbox handoff", color: .teal)
            }
            if record.isWishlistDispatchSetup {
              Badge("Wishlist dispatch", color: .pink)
            }
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

      if record.isInboxDispatchHandoffSetup {
        LinkedOrdersContextPanel(
          title: "Order source dispatch setup",
          linkedOrders: linkedOrders,
          sourceLabel: record.dispatchStatus.rawValue,
          emptyDetail: "This manifest was created from order source handoff context, but no matching local order was found. Check the manifest before dispatching.",
          linkedDetail: manifestHandoffDetail,
          tone: record.dispatchStatus.color,
          store: store
        )
      }

      if record.isWishlistDispatchSetup {
        LinkedOrdersContextPanel(
          title: "Wishlist dispatch source",
          linkedOrders: linkedOrders,
          sourceLabel: record.dispatchStatus.rawValue,
          emptyDetail: "This manifest was staged from a Wishlist item, but no linked local order was found. Confirm the purchase handoff before preparing dispatch.",
          linkedDetail: "This manifest was staged from a Wishlist purchase handoff. Open the linked order to confirm the source trail, tracking, destination, and local dispatch setup before progressing.",
          tone: .pink,
          store: store
        )
      }

      if let store {
        OrderMailboxSourceTrailPanel(
          summaries: mailboxSummaries(using: store),
          title: "Mailbox provider manifest trail",
          symbol: "shippingbox.and.arrow.backward.fill"
        )
      }

      if !manifestWarnings.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Label("Manifest follow-up", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.bold())
            .foregroundStyle(.orange)
          ForEach(manifestWarnings, id: \.self) { warning in
            Text(warning)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Prepared", systemImage: "checkmark.circle.fill") {
          onPrepared()
          feedbackMessage = "Manifest marked prepared locally."
        }
          .buttonStyle(.bordered)
        Button("Dispatched", systemImage: "paperplane.fill") {
          onDispatched()
          feedbackMessage = "Manifest marked dispatched locally."
        }
          .buttonStyle(.bordered)
        Button("Handed off", systemImage: "person.badge.shield.checkmark.fill") {
          onHandedOff()
          feedbackMessage = "Manifest handoff recorded locally."
        }
          .buttonStyle(.bordered)
        Button("Blocked", systemImage: "exclamationmark.triangle.fill") {
          onBlocked()
          feedbackMessage = "Manifest blocked for dispatch review."
        }
          .buttonStyle(.bordered)
        Button("Reopen", systemImage: "arrow.counterclockwise") {
          onReopen()
          feedbackMessage = "Manifest reopened for dispatch review."
        }
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.shield.fill") {
          onReviewed()
          feedbackMessage = "Manifest marked reviewed locally."
        }
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Manifest follow-up task created. Check Tasks."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Manifest draft message created locally."
        }
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
          .buttonStyle(.bordered)
      }

      if let feedbackMessage {
        ShipmentManifestFeedbackPanel(message: feedbackMessage, store: store)
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

  private var manifestHandoffDetail: String {
    switch record.dispatchStatus {
    case .draft, .reopened:
      return "Prepare this manifest after readiness checks are clear. Open linked orders here when source context or dispatch setup needs confirmation."
    case .prepared:
      return "Manifest is prepared. Open linked orders here before dispatching if tracking, destination, or handoff setup still needs confirmation."
    case .dispatched:
      return "Manifest is dispatched. Confirm courier/internal handoff and monitor the linked order from Orders."
    case .handedOff:
      return "Handoff is complete. The linked source-created or Wishlist-linked order can be monitored from Orders."
    case .blockedNeedsReview:
      return "Resolve the blocked handoff before progressing the linked order."
    }
  }

  private var manifestWarnings: [String] {
    var warnings: [String] = []
    if record.dispatchStatus == .draft || record.dispatchStatus == .reopened {
      warnings.append("Manifest is not prepared yet.")
    }
    if record.dispatchStatus == .prepared {
      warnings.append("Manifest is prepared but not dispatched or handed off.")
    }
    if record.dispatchStatus == .blockedNeedsReview {
      warnings.append("Manifest is blocked and needs review before dispatch.")
    }
    if record.includedOrderIDs.isEmpty {
      warnings.append("No included orders are attached.")
    }
    if record.handoffLocationStorageLocationID == nil {
      warnings.append("Handoff/storage location is missing.")
    }
    if record.labelReferenceIDs.isEmpty {
      warnings.append("No label references are linked.")
    }
    if record.scanSessionIDs.isEmpty {
      warnings.append("No scan sessions are linked.")
    }
    if record.assignedOwnerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      warnings.append("Owner/team is missing.")
    }
    if record.riskLevel == .high || record.riskLevel == .critical {
      warnings.append("Risk is \(record.riskLevel.rawValue.lowercased()); confirm manifest handling.")
    }
    if record.reviewState != .accepted {
      warnings.append("Review state is \(record.reviewState.rawValue.lowercased()); mark reviewed after local checks are complete.")
    }
    return warnings
  }

  private func mailboxSummaries(using store: ParcelOpsStore) -> [OrderMailboxSourceSummary] {
    var seen = Set<String>()
    return linkedOrders.flatMap { order in
      store.mailboxSourceSummaries(for: order)
    }.filter { seen.insert($0.id).inserted }
  }
}

private extension ShipmentManifestRecord {
  var isInboxDispatchHandoffSetup: Bool {
    linkedEntityType == .order
      && (
        title.localizedCaseInsensitiveContains("Dispatch setup for")
          || manifestReferencePlaceholder.localizedCaseInsensitiveContains("INBOX-")
          || notes.localizedCaseInsensitiveContains("Inbox handoff")
      )
  }

  var isWishlistDispatchSetup: Bool {
    linkedEntityType == .wishlistItem
      || title.localizedCaseInsensitiveContains("Wishlist dispatch")
      || manifestReferencePlaceholder.localizedCaseInsensitiveContains("WISHLIST-")
      || notes.localizedCaseInsensitiveContains("Wishlist item")
  }
}

private struct ShipmentManifestFeedbackPanel: View {
  var message: String
  var store: ParcelOpsStore?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(message, systemImage: "checkmark.circle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.green)

      if let store {
        CompactActionRow {
          NavigationLink {
            DispatchView(store: store)
          } label: {
            Label("Open Dispatch", systemImage: "paperplane.fill")
          }
          if message.localizedCaseInsensitiveContains("task") {
            NavigationLink {
              TasksView(store: store)
            } label: {
              Label("Open Tasks", systemImage: "checklist")
            }
          }
          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Open Audit", systemImage: "list.clipboard.fill")
          }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.green.opacity(0.12))
    .clipShape(RoundedRectangle(cornerRadius: 8))
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
