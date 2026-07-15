import SwiftUI

struct ReturnsClaimsView: View {
  var store: ParcelOpsStore
  @State private var selectedClaimType: ReturnClaimType?
  @State private var selectedStatus: ReturnClaimStatus?
  @State private var selectedOutcome: ReturnClaimOutcome?
  @State private var ownerTeam = ""
  @State private var selectedRiskLevel: ShipmentRiskLevel?
  @State private var selectedLinkedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedReviewState: ReviewState?
  @State private var claimSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var baseFilteredClaims: [ReturnClaimRecord] {
    store.filteredReturnClaims(
      claimType: selectedClaimType,
      claimStatus: selectedStatus,
      requestedOutcome: selectedOutcome,
      ownerTeam: ownerTeam,
      riskLevel: selectedRiskLevel,
      linkedEntityType: selectedLinkedEntityType,
      reviewState: selectedReviewState
    )
  }

  private var filteredClaims: [ReturnClaimRecord] {
    let query = claimSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredClaims }
    return baseFilteredClaims.filter { claim in
      returnClaim(claim, matches: query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedClaimType != nil
      || selectedStatus != nil
      || selectedOutcome != nil
      || !ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || selectedRiskLevel != nil
      || selectedLinkedEntityType != nil
      || selectedReviewState != nil
      || !claimSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filterBar
        inboxReturnClaimCoverage
        gmailReturnClaimReadinessPanel

        SettingsPanel(title: "Return and claim records", symbol: "arrow.uturn.backward.square.fill") {
          HStack {
            Text("\(filteredClaims.count) visible return/claim records")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredClaims.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add claim", systemImage: "plus", action: store.addReturnClaimPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredClaims.isEmpty {
            MVPEmptyState(title: "No returns or claims match this view", detail: hasActiveFilters ? "Clear search or filters to return to all local return and claim records." : "Add a local return or claim to track refund, replacement, missing item, damage, evidence, and carrier claim work.", symbol: "arrow.uturn.backward.square.fill", actionTitle: hasActiveFilters ? "Clear filters" : "Add claim", action: hasActiveFilters ? clearFilters : store.addReturnClaimPlaceholder)
          } else {
            ForEach(filteredClaims) { claim in
              ReturnClaimRow(claim: claim, store: store, linkedOrder: linkedOrder(for: claim), procurementRequests: store.suggestedProcurementRequests(for: claim), receivingInspections: store.suggestedReceivingInspections(for: claim), inventoryReceipts: store.suggestedInventoryReceipts(for: claim), storageLocations: store.suggestedStorageLocations(for: claim), custodyRecords: store.suggestedCustodyRecords(for: claim), labelReferences: store.suggestedLabelReferenceRecords(for: claim), scanSessions: store.suggestedScanSessionRecords(for: claim), shipmentManifests: store.suggestedShipmentManifestRecords(for: claim), dispatchChecklists: store.suggestedDispatchReadinessChecklists(for: claim)) { updatedClaim in
                store.updateReturnClaim(updatedClaim)
              } onSubmitted: {
                store.markReturnClaimSubmitted(claim)
              } onApproved: {
                store.markReturnClaimApproved(claim)
              } onResolved: {
                store.markReturnClaimResolved(claim)
              } onDisputed: {
                store.markReturnClaimDisputed(claim)
              } onReviewed: {
                store.markReturnClaimReviewed(claim)
              } onCreateTask: {
                store.createReviewTask(from: claim)
              } onCreateDraft: {
                store.createDraftMessage(from: claim)
              } onRemove: {
                store.removeReturnClaim(claim)
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
        Text("Returns & Claims")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Local return, exchange, refund, damage, missing item, and carrier claim tracking.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(store.unresolvedReturnClaims.count) unresolved", color: .orange)
        Badge("\(store.disputedReturnClaims.count) disputed", color: .red)
      }
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search claim, reason, order, tracking, evidence, procurement, receiving, or storage", text: $claimSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Type", selection: $selectedClaimType) {
        Text("All types").tag(nil as ReturnClaimType?)
        ForEach(ReturnClaimType.allCases) { type in
          Text(type.rawValue).tag(type as ReturnClaimType?)
        }
      }

      Picker("Status", selection: $selectedStatus) {
        Text("All status").tag(nil as ReturnClaimStatus?)
        ForEach(ReturnClaimStatus.allCases) { status in
          Text(status.rawValue).tag(status as ReturnClaimStatus?)
        }
      }

      Picker("Outcome", selection: $selectedOutcome) {
        Text("All outcomes").tag(nil as ReturnClaimOutcome?)
        ForEach(ReturnClaimOutcome.allCases) { outcome in
          Text(outcome.rawValue).tag(outcome as ReturnClaimOutcome?)
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

  private func clearFilters() {
    selectedClaimType = nil
    selectedStatus = nil
    selectedOutcome = nil
    ownerTeam = ""
    selectedRiskLevel = nil
    selectedLinkedEntityType = nil
    selectedReviewState = nil
    claimSearchText = ""
  }

  private var inboxReturnClaimCoverage: some View {
    SettingsPanel(title: "Inbox and Wishlist return and claim coverage", symbol: "arrow.uturn.backward.square.fill") {
      Text("Checks whether orders created from Inbox intake or Wishlist purchase handoff have local return, refund, damage, or missing-item claim follow-up where needed.")
        .font(.caption)
        .foregroundStyle(.secondary)

      CompactMetadataGrid(minimumWidth: 150) {
        Badge("\(store.intakeLinkedOrderCount) Inbox orders", color: .blue)
        Badge("\(store.wishlistLinkedOrderCount) Wishlist orders", color: .pink)
        Badge("\(claimsLinkedToInboxOrders.count) linked claims", color: .teal)
        Badge("\(claimsNeedingAction.count) need action", color: claimsNeedingAction.isEmpty ? .green : .orange)
        Badge("\(claimsMissingEvidence.count) missing evidence", color: claimsMissingEvidence.isEmpty ? .green : .orange)
      }

      if !claimProviderRows.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Mailbox source for returns and claims")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
            ForEach(claimProviderRows, id: \.label) { row in
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

      if store.operatorSourceOrderCount == 0 {
        Text("No Inbox-created or Wishlist-linked orders need return or claim checks yet.")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else if claimsLinkedToInboxOrders.isEmpty {
        Text("No return or claim records are linked to Inbox-created or Wishlist-linked orders. Create one only when a refund, replacement, damage, missing-item, or carrier claim is actually needed.")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else if claimsNeedingAction.isEmpty && claimsMissingEvidence.isEmpty {
        Label("Linked return and claim records are resolved, reviewed, and have evidence context.", systemImage: "checkmark.seal.fill")
          .font(.caption)
          .foregroundStyle(.green)
      } else {
        VStack(alignment: .leading, spacing: 8) {
          Text("Linked claims needing follow-up")
            .font(.caption.weight(.semibold))
          CompactMetadataGrid(minimumWidth: 170) {
            ForEach(claimsNeedingAction.prefix(4)) { claim in
              Badge(claim.title, color: claim.riskLevel.color)
            }
          }
        }
      }
    }
  }

  private var claimProviderRows: [(label: String, count: Int, detail: String, symbol: String, color: Color)] {
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
        detail = "SpaceMail intake can create refund, missing-item, or carrier-claim follow-up after an Inbox order is linked or created."
      case "gmail":
        detail = "Gmail intake can create refund, missing-item, or return follow-up after an Inbox order is linked or created."
      case "mock":
        detail = "Mock mailbox intake supports local return and claim testing. Confirm live provider context before handoff."
      default:
        detail = "Local mailbox intake can create return or claim follow-up once linked to an order."
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

  private var gmailReturnClaimReadinessPanel: some View {
    GmailReleaseBoundaryPanel(
      store: store,
      title: "Gmail return and claim readiness",
      lead: "Gmail-origin intake should create return, refund, missing-item, or carrier-claim work only after Gmail setup is ready and the imported Inbox order has confirmed outcome, evidence, and owner context.",
      sourceMetricTitle: "Gmail claim sources",
      sourceCount: gmailClaimSourceCount,
      boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store tokens, process refunds, submit carrier claims, or change return/claim records automatically."
    )
  }

  private var gmailClaimSourceCount: Int {
    claimProviderRows
      .filter { $0.label.localizedCaseInsensitiveContains("Gmail") }
      .reduce(0) { total, row in total + row.count }
  }




  private var claimsLinkedToInboxOrders: [ReturnClaimRecord] {
    store.returnClaims.filter { claim in
      guard let orderID = claim.orderID ?? (claim.linkedEntityType == .order ? UUID(uuidString: claim.linkedEntityID) : nil) else {
        return false
      }
      return store.operatorSourceOrders.contains { $0.id == orderID }
    }
  }

  private var claimsNeedingAction: [ReturnClaimRecord] {
    claimsLinkedToInboxOrders.filter { claim in
      claim.claimStatus != .resolved
        || claim.reviewState != .accepted
        || claim.claimStatus == .disputed
        || claim.claimStatus == .blocked
    }
  }

  private var claimsMissingEvidence: [ReturnClaimRecord] {
    claimsLinkedToInboxOrders.filter { $0.evidenceAttachmentIDs.isEmpty }
  }


  private func linkedOrder(for claim: ReturnClaimRecord) -> TrackedOrder? {
    let orderID = claim.orderID ?? (claim.linkedEntityType == .order ? UUID(uuidString: claim.linkedEntityID) : nil)
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

  private func returnClaim(_ claim: ReturnClaimRecord, matches query: String) -> Bool {
    let order = linkedOrder(for: claim)
    let procurementRequests = store.suggestedProcurementRequests(for: claim)
    let receivingInspections = store.suggestedReceivingInspections(for: claim)
    let inventoryReceipts = store.suggestedInventoryReceipts(for: claim)
    let storageLocations = store.suggestedStorageLocations(for: claim)
    let custodyRecords = store.suggestedCustodyRecords(for: claim)
    let labelReferences = store.suggestedLabelReferenceRecords(for: claim)
    let scanSessions = store.suggestedScanSessionRecords(for: claim)
    let shipmentManifests = store.suggestedShipmentManifestRecords(for: claim)
    let dispatchChecklists = store.suggestedDispatchReadinessChecklists(for: claim)
    var searchParts: [String] = [
      claim.id.uuidString,
      claim.title,
      claim.linkedEntityType.rawValue,
      claim.linkedEntityID,
      claim.orderID?.uuidString ?? "",
      claim.shipmentGroupID?.uuidString ?? "",
      claim.packageContentID?.uuidString ?? "",
      claim.costRecordID?.uuidString ?? "",
      claim.customerProfileID?.uuidString ?? "",
      claim.vendorProfileID?.uuidString ?? "",
      claim.accountID?.uuidString ?? "",
      claim.claimType.rawValue,
      claim.reasonSummary,
      claim.requestedOutcome.rawValue,
      claim.claimStatus.rawValue,
      claim.refundReplacementAmountText,
      claim.currency,
      claim.assignedOwnerTeam,
      claim.dueDate,
      claim.riskLevel.rawValue,
      claim.createdDate,
      claim.lastReviewedDate,
      claim.reviewState.rawValue,
      order?.orderNumber ?? "",
      order?.store ?? "",
      order?.customer ?? "",
      order?.recipientEmail ?? "",
      order?.trackingNumber ?? "",
      order?.carrier ?? "",
      order?.destination ?? ""
    ]
    searchParts.append(contentsOf: claim.evidenceAttachmentIDs.map(\.uuidString))
    searchParts.append(contentsOf: claim.carrierTrackingEventIDs.map(\.uuidString))
    searchParts.append(contentsOf: procurementRequests.map(\.title))
    searchParts.append(contentsOf: procurementRequests.map(\.requestedItemsSummary))
    searchParts.append(contentsOf: receivingInspections.map(\.title))
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

struct ReturnClaimRow: View {
  var claim: ReturnClaimRecord
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
  var procurementRequests: [ProcurementRequest] = []
  var receivingInspections: [ReceivingInspectionRecord] = []
  var inventoryReceipts: [InventoryReceiptRecord] = []
  var storageLocations: [StorageLocationRecord] = []
  var custodyRecords: [CustodyRecord] = []
  var labelReferences: [LabelReferenceRecord] = []
  var scanSessions: [ScanSessionRecord] = []
  var shipmentManifests: [ShipmentManifestRecord] = []
  var dispatchChecklists: [DispatchReadinessChecklist] = []
  var onSave: (ReturnClaimRecord) -> Void
  var onSubmitted: () -> Void
  var onApproved: () -> Void
  var onResolved: () -> Void
  var onDisputed: () -> Void
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

  private var claimFollowUpWarnings: [String] {
    var warnings: [String] = []
    if claim.claimStatus == .disputed {
      warnings.append("Disputed")
    } else if claim.claimStatus == .blocked {
      warnings.append("Blocked")
    } else if claim.claimStatus != .resolved {
      warnings.append("Not resolved")
    }
    if claim.evidenceAttachmentIDs.isEmpty {
      warnings.append("Evidence missing")
    }
    if claim.reviewState != .accepted {
      warnings.append("Review pending")
    }
    return warnings
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: claim.claimType.symbol)
          .foregroundStyle(claim.riskLevel.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(claim.title)
                .font(.headline)
              Text("\(claim.claimType.rawValue) • \(claim.requestedOutcome.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(claim.claimStatus.rawValue, color: claim.claimStatus.color)
          }

          Text(claim.reasonSummary)
            .foregroundStyle(.secondary)
          Text("\(claim.refundReplacementAmountText) \(claim.currency) • Owner \(claim.assignedOwnerTeam) • Due \(claim.dueDate)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          HStack(spacing: 8) {
            Badge(claim.riskLevel.rawValue, color: claim.riskLevel.color)
            Badge(claim.reviewState.rawValue, color: claim.reviewState.color)
            Label("\(claim.evidenceAttachmentIDs.count) evidence", systemImage: "paperclip")
              .font(.caption)
              .foregroundStyle(.secondary)
            Label(claim.linkedEntityType.rawValue, systemImage: claim.linkedEntityType.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      if !linkedIntakeEmails.isEmpty || !linkedWishlistItems.isEmpty || !claimFollowUpWarnings.isEmpty {
        returnClaimInboxSourceTrail
      }

      ProcurementRequestStrip(requests: procurementRequests)
      ReceivingInspectionStrip(inspections: receivingInspections)
      InventoryReceiptStrip(receipts: inventoryReceipts)
      StorageLocationStrip(locations: storageLocations)
      CustodyRecordStrip(records: custodyRecords)
      LabelReferenceStrip(records: labelReferences)
      ScanSessionStrip(records: scanSessions)

      if let feedbackMessage {
        ReturnClaimActionFeedbackPanel(message: feedbackMessage, store: store)
      }

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Submitted", systemImage: "paperplane.fill") {
          onSubmitted()
          feedbackMessage = "Return/claim marked submitted locally."
        }
          .buttonStyle(.bordered)
        Button("Approved", systemImage: "checkmark.seal.fill") {
          onApproved()
          feedbackMessage = "Return/claim marked approved locally."
        }
          .buttonStyle(.bordered)
        Button("Resolved", systemImage: "checkmark.circle.fill") {
          onResolved()
          feedbackMessage = "Return/claim marked resolved locally."
        }
          .buttonStyle(.bordered)
        Button("Dispute", systemImage: "exclamationmark.triangle.fill") {
          onDisputed()
          feedbackMessage = "Return/claim marked disputed for local review."
        }
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.shield.fill") {
          onReviewed()
          feedbackMessage = "Return/claim marked reviewed locally."
        }
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Follow-up task created from return/claim. Check Tasks."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Draft created from return/claim. Check Drafts."
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
          feedbackMessage = "Return/claim removed locally."
        }
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      ReturnClaimEditView(claim: claim) { updatedClaim in
        onSave(updatedClaim)
        feedbackMessage = "Return/claim saved locally."
      }
    }
  }

  private var returnClaimInboxSourceTrail: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label("Inbox claim follow-up", systemImage: "envelope.open.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(sourceTrailDescription)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactMetadataGrid(minimumWidth: 140) {
        ForEach(claimFollowUpWarnings.prefix(4), id: \.self) { warning in
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
    if !linkedWishlistItems.isEmpty && !claimFollowUpWarnings.isEmpty {
      return "This return or claim is tied to a Wishlist-linked order and still needs local evidence, status, or review follow-up."
    }
    if !linkedWishlistItems.isEmpty {
      return "Wishlist purchase context is linked to this return or claim. Confirm seller, outcome, evidence, and replacement/refund tracking before closing."
    }
    if !claimFollowUpWarnings.isEmpty && !linkedIntakeEmails.isEmpty {
      return "This claim is tied to an Inbox-created order and still needs local evidence, status, or review follow-up."
    }
    if !claimFollowUpWarnings.isEmpty {
      return "This claim still needs local evidence, status, or review follow-up."
    }
    return "Inbox intake context is linked to this return or claim record. Provider IDs stay in Audit/details."
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

private struct ReturnClaimActionFeedbackPanel: View {
  var message: String
  var store: ParcelOpsStore?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(message, systemImage: "checkmark.circle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.green)
      Text("This is local return/claim tracking only. No refund, carrier claim API, supplier API, payment, outbound email, or mailbox mutation was used.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      if let store {
        CompactActionRow {
          if message.localizedCaseInsensitiveContains("task") {
            NavigationLink { TasksView(store: store) } label: { Label("Open Tasks", systemImage: "checklist") }
          }
          if message.localizedCaseInsensitiveContains("draft") {
            NavigationLink { CommunicationView(store: store) } label: { Label("Open Drafts", systemImage: "envelope.open.fill") }
          }
          NavigationLink { AuditView(store: store) } label: { Label("Open Audit", systemImage: "list.clipboard.fill") }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.green.opacity(0.10))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct ReturnClaimEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: ReturnClaimRecord
  var onSave: (ReturnClaimRecord) -> Void

  init(claim: ReturnClaimRecord, onSave: @escaping (ReturnClaimRecord) -> Void) {
    self._draft = State(initialValue: claim)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Claim") {
          TextField("Title", text: $draft.title)
          Picker("Type", selection: $draft.claimType) {
            ForEach(ReturnClaimType.allCases) { type in
              Text(type.rawValue).tag(type)
            }
          }
          Picker("Outcome", selection: $draft.requestedOutcome) {
            ForEach(ReturnClaimOutcome.allCases) { outcome in
              Text(outcome.rawValue).tag(outcome)
            }
          }
          Picker("Status", selection: $draft.claimStatus) {
            ForEach(ReturnClaimStatus.allCases) { status in
              Text(status.rawValue).tag(status)
            }
          }
          TextField("Reason", text: $draft.reasonSummary, axis: .vertical)
        }

        Section("Amount and owner") {
          TextField("Refund/replacement amount", text: $draft.refundReplacementAmountText)
          TextField("Currency", text: $draft.currency)
          TextField("Assigned owner/team", text: $draft.assignedOwnerTeam)
          TextField("Due date", text: $draft.dueDate)
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
      .navigationTitle("Edit Claim")
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
    .frame(minWidth: 580, minHeight: 600)
  }
}
