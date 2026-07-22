import SwiftUI

struct CostsBudgetsView: View {
  var store: ParcelOpsStore
  @State private var selectedCategory: CostCategory?
  @State private var selectedReimbursementStatus: ReimbursementStatus?
  @State private var selectedApprovalStatus: CostApprovalStatus?
  @State private var budgetCode = ""
  @State private var ownerTeam = ""
  @State private var selectedRiskLevel: ShipmentRiskLevel?
  @State private var selectedLinkedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedReviewState: ReviewState?
  @State private var costSearchText = ""
  @State private var showAllCostRecords = false
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var baseFilteredCosts: [CostRecord] {
    store.filteredCostRecords(
      costCategory: selectedCategory,
      reimbursementStatus: selectedReimbursementStatus,
      approvalStatus: selectedApprovalStatus,
      budgetCode: budgetCode,
      ownerTeam: ownerTeam,
      riskLevel: selectedRiskLevel,
      linkedEntityType: selectedLinkedEntityType,
      reviewState: selectedReviewState
    )
  }

  private var filteredCosts: [CostRecord] {
    let query = costSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredCosts }
    return baseFilteredCosts.filter { cost in
      costRecord(cost, matches: query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedCategory != nil
      || selectedReimbursementStatus != nil
      || selectedApprovalStatus != nil
      || !budgetCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || selectedRiskLevel != nil
      || selectedLinkedEntityType != nil
      || selectedReviewState != nil
      || !costSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var displayedCosts: [CostRecord] {
    guard !showAllCostRecords && !hasActiveFilters else { return filteredCosts }
    return Array(filteredCosts.prefix(48))
  }

  private var hiddenDisplayedCostCount: Int {
    max(filteredCosts.count - displayedCosts.count, 0)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filterBar
        inboxCostCoverage
        gmailCostReadinessPanel

        SettingsPanel(title: "Cost records", symbol: "creditcard.and.123") {
          HStack {
            Text("\(filteredCosts.count) visible cost records")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredCosts.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add cost", systemImage: "plus", action: store.addCostRecordPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredCosts.isEmpty {
            MVPEmptyState(title: "No costs match this view", detail: hasActiveFilters ? "Clear search or filters to return to all local cost and budget records." : "Add a local cost record to track approvals, reimbursements, budget codes, evidence, and claims.", symbol: "creditcard.and.123", actionTitle: hasActiveFilters ? "Clear filters" : "Add cost", action: hasActiveFilters ? clearFilters : store.addCostRecordPlaceholder)
          } else {
            if hiddenDisplayedCostCount > 0 {
              CompactActionRow {
                Label("Showing first \(displayedCosts.count) cost records", systemImage: "speedometer")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.secondary)
                Badge("\(hiddenDisplayedCostCount) older hidden", color: .secondary)
                Button(showAllCostRecords ? "Show first 48" : "Show all \(filteredCosts.count)", systemImage: showAllCostRecords ? "rectangle.compress.vertical" : "rectangle.expand.vertical") {
                  withAnimation(.snappy) {
                    showAllCostRecords.toggle()
                  }
                }
                .buttonStyle(.bordered)
              }
              Text("Search and filters still scan every local cost record. The default list is capped so Costs & Budgets opens quickly with accumulated test data.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(displayedCosts) { cost in
              CostRecordRow(cost: cost, store: store, linkedOrder: linkedOrder(for: cost), returnClaims: store.suggestedReturnClaims(for: cost), procurementRequests: store.suggestedProcurementRequests(for: cost)) { updatedCost in
                store.updateCostRecord(updatedCost)
              } onApproved: {
                store.markCostRecordApproved(cost)
              } onReimbursed: {
                store.markCostRecordReimbursed(cost)
              } onDisputed: {
                store.markCostRecordDisputed(cost)
              } onReviewed: {
                store.markCostRecordReviewed(cost)
              } onCreateTask: {
                store.createReviewTask(from: cost)
              } onCreateDraft: {
                store.createDraftMessage(from: cost)
              } onRemove: {
                store.removeCostRecord(cost)
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
        Text("Costs & Budgets")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Local cost, approval, budget code, evidence, and reimbursement review for parcel operations.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(store.unapprovedCostRecords.count) unapproved", color: .orange)
        Badge("\(store.disputedCostRecords.count) disputed", color: .red)
      }
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search cost, budget, owner, order, vendor, account, evidence, claim, or procurement", text: $costSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Category", selection: $selectedCategory) {
        Text("All categories").tag(nil as CostCategory?)
        ForEach(CostCategory.allCases) { category in
          Text(category.rawValue).tag(category as CostCategory?)
        }
      }

      Picker("Reimbursement", selection: $selectedReimbursementStatus) {
        Text("All reimbursement").tag(nil as ReimbursementStatus?)
        ForEach(ReimbursementStatus.allCases) { status in
          Text(status.rawValue).tag(status as ReimbursementStatus?)
        }
      }

      Picker("Approval", selection: $selectedApprovalStatus) {
        Text("All approval").tag(nil as CostApprovalStatus?)
        ForEach(CostApprovalStatus.allCases) { status in
          Text(status.rawValue).tag(status as CostApprovalStatus?)
        }
      }

      TextField("Budget code", text: $budgetCode)
        .textFieldStyle(.roundedBorder)

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
    selectedCategory = nil
    selectedReimbursementStatus = nil
    selectedApprovalStatus = nil
    budgetCode = ""
    ownerTeam = ""
    selectedRiskLevel = nil
    selectedLinkedEntityType = nil
    selectedReviewState = nil
    costSearchText = ""
  }

  private var inboxCostCoverage: some View {
    SettingsPanel(title: "Inbox and Wishlist cost readiness", symbol: "creditcard.and.123") {
      Text("Checks whether orders created from Inbox intake or Wishlist purchase handoff have local cost, approval, reimbursement, and budget-code context.")
        .font(.caption)
        .foregroundStyle(.secondary)

      CompactMetadataGrid(minimumWidth: 150) {
        Badge("\(store.intakeLinkedOrderCount) Inbox orders", color: .blue)
        Badge("\(store.wishlistLinkedOrderCount) Wishlist orders", color: .pink)
        Badge("\(costsLinkedToInboxOrders.count) linked costs", color: .teal)
        Badge("\(costsNeedingAction.count) need action", color: costsNeedingAction.isEmpty ? .green : .orange)
        Badge("\(inboxOrdersMissingCost.count) missing costs", color: inboxOrdersMissingCost.isEmpty ? .green : .orange)
      }

      if !costProviderRows.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Mailbox source for costs")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
            ForEach(costProviderRows, id: \.label) { row in
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
        Text("No Inbox-created or Wishlist-linked orders need cost checks yet.")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else if inboxOrdersMissingCost.isEmpty && costsNeedingAction.isEmpty {
        Label("Inbox-created and Wishlist-linked orders have cost and budget coverage for this local workflow.", systemImage: "checkmark.seal.fill")
          .font(.caption)
          .foregroundStyle(.green)
      } else {
        VStack(alignment: .leading, spacing: 8) {
          if !inboxOrdersMissingCost.isEmpty {
            Text("Inbox/Wishlist orders missing cost records")
              .font(.caption.weight(.semibold))
            CompactActionRow {
              ForEach(inboxOrdersMissingCost.prefix(4)) { order in
                NavigationLink {
                  OrderDetailView(order: order, store: store)
                } label: {
                  Label(order.orderNumber, systemImage: "arrow.up.right.square.fill")
                }
                .buttonStyle(.bordered)
              }
            }
          }

          if !costsNeedingAction.isEmpty {
            Text("Linked costs needing local action")
              .font(.caption.weight(.semibold))
            CompactMetadataGrid(minimumWidth: 170) {
              ForEach(costsNeedingAction.prefix(4)) { cost in
                Badge(cost.title, color: cost.riskLevel.color)
              }
            }
          }
        }
      }
    }
  }

  private var costProviderRows: [(label: String, count: Int, detail: String, symbol: String, color: Color)] {
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
        detail = "SpaceMail intake can create cost or reimbursement checks after an Inbox order is linked or created."
      case "gmail":
        detail = "Gmail intake can create cost or reimbursement checks after an Inbox order is linked or created."
      case "mock":
        detail = "Mock mailbox intake supports local cost testing. Confirm live provider context before operational handoff."
      default:
        detail = "Local mailbox intake can create cost checks once linked to an order."
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

  private var gmailCostReadinessPanel: some View {
    CollapsedProviderEvidencePanel(
      title: "Mailbox cost evidence",
      detail: "Open provider release evidence only when cost, budget, or reimbursement work depends on mailbox provider source trails."
    ) {
      VStack(alignment: .leading, spacing: 10) {
        GmailReleaseBoundaryPanel(
          store: store,
          title: "Gmail cost readiness",
          lead: "Gmail-origin intake should create cost, budget, or reimbursement work only after Gmail setup is ready and the imported Inbox order has confirmed charge, vendor, evidence, and owner context.",
          sourceMetricTitle: "Gmail cost sources",
          sourceCount: gmailCostSourceCount,
          boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store tokens, process payments, connect accounting systems, or change cost records automatically."
        )
        Microsoft365ReleaseBoundaryPanel(
          store: store,
          title: "Outlook cost readiness",
          lead: "Outlook-origin intake should create cost, budget, or reimbursement work only after Microsoft setup, Graph diagnostics, and confirmed Inbox order charge, vendor, evidence, and owner context are clear.",
          sourceMetricTitle: "Outlook cost sources",
          sourceCount: microsoft365CostSourceCount,
          boundaryDetail: "Local-only boundary: this panel does not start Microsoft sign-in, request tokens, fetch Outlook messages, process payments, connect accounting systems, or change cost records automatically."
        )
      }
    }
  }

  private var gmailCostSourceCount: Int {
    costProviderRows
      .filter { $0.label.localizedCaseInsensitiveContains("Gmail") }
      .reduce(0) { total, row in total + row.count }
  }

  private var microsoft365CostSourceCount: Int {
    costProviderRows
      .filter { $0.label.localizedCaseInsensitiveContains("Microsoft 365") || $0.label.localizedCaseInsensitiveContains("Outlook") }
      .reduce(0) { total, row in total + row.count }
  }




  private var costsLinkedToInboxOrders: [CostRecord] {
    store.costRecords.filter { cost in
      guard let orderID = cost.orderID ?? (cost.linkedEntityType == .order ? UUID(uuidString: cost.linkedEntityID) : nil) else {
        return false
      }
      return store.operatorSourceOrders.contains { $0.id == orderID }
    }
  }

  private var costsNeedingAction: [CostRecord] {
    costsLinkedToInboxOrders.filter { cost in
      cost.approvalStatus != .approved
        || cost.reimbursementStatus != .reimbursed
        || cost.budgetCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || cost.reviewState != .accepted
    }
  }

  private var inboxOrdersMissingCost: [TrackedOrder] {
    store.operatorSourceOrders.filter { order in
      !store.costRecords.contains { cost in
        cost.orderID == order.id || (cost.linkedEntityType == .order && cost.linkedEntityID == order.id.uuidString)
      }
    }
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

  private func linkedOrder(for cost: CostRecord) -> TrackedOrder? {
    let orderID = cost.orderID ?? (cost.linkedEntityType == .order ? UUID(uuidString: cost.linkedEntityID) : nil)
    guard let orderID else { return nil }
    return store.orders.first { $0.id == orderID }
  }

  private func costRecord(_ cost: CostRecord, matches query: String) -> Bool {
    let order = linkedOrder(for: cost)
    let returnClaims = store.suggestedReturnClaims(for: cost)
    let procurementRequests = store.suggestedProcurementRequests(for: cost)
    var searchParts: [String] = [
      cost.id.uuidString,
      cost.title,
      cost.linkedEntityType.rawValue,
      cost.linkedEntityID,
      cost.orderID?.uuidString ?? "",
      cost.shipmentGroupID?.uuidString ?? "",
      cost.packageContentID?.uuidString ?? "",
      cost.customerProfileID?.uuidString ?? "",
      cost.vendorProfileID?.uuidString ?? "",
      cost.accountID?.uuidString ?? "",
      cost.costCategory.rawValue,
      cost.amountText,
      cost.currency,
      cost.taxGSTText,
      cost.reimbursementStatus.rawValue,
      cost.approvalStatus.rawValue,
      cost.budgetCode,
      cost.costOwnerTeam,
      cost.notes,
      cost.riskLevel.rawValue,
      cost.createdDate,
      cost.lastReviewedDate,
      cost.reviewState.rawValue,
      order?.orderNumber ?? "",
      order?.store ?? "",
      order?.customer ?? "",
      order?.recipientEmail ?? "",
      order?.trackingNumber ?? "",
      order?.carrier ?? "",
      order?.destination ?? ""
    ]
    searchParts.append(contentsOf: cost.evidenceAttachmentIDs.map(\.uuidString))
    searchParts.append(contentsOf: returnClaims.map(\.title))
    searchParts.append(contentsOf: returnClaims.map(\.reasonSummary))
    searchParts.append(contentsOf: procurementRequests.map(\.title))
    searchParts.append(contentsOf: procurementRequests.map(\.requestedItemsSummary))
    if let order {
      let mailboxSummaries = store.mailboxSourceSummaries(for: order)
      searchParts.append(contentsOf: mailboxSummaries.map(\.providerName))
      searchParts.append(contentsOf: mailboxSummaries.map(\.mailboxLabel))
      searchParts.append(contentsOf: mailboxSummaries.map(\.statusLabel))
      searchParts.append(contentsOf: mailboxSummaries.map(\.detailText))
    }
    let searchableText = searchParts.joined(separator: " ")
    return searchableText.localizedLowercase.contains(query)
  }
}

struct CostRecordRow: View {
  var cost: CostRecord
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
  var returnClaims: [ReturnClaimRecord] = []
  var procurementRequests: [ProcurementRequest] = []
  var onSave: (CostRecord) -> Void
  var onApproved: () -> Void
  var onReimbursed: () -> Void
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

  private var costReadinessWarnings: [String] {
    var warnings: [String] = []
    if cost.approvalStatus != .approved {
      warnings.append("Approval pending")
    }
    if cost.reimbursementStatus != .reimbursed {
      warnings.append("Reimbursement open")
    }
    if cost.budgetCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      warnings.append("Budget code missing")
    }
    if cost.reviewState != .accepted {
      warnings.append("Review pending")
    }
    return warnings
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: cost.costCategory.symbol)
          .foregroundStyle(cost.riskLevel.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(cost.title)
                .font(.headline)
              Text("\(cost.amountText) \(cost.currency) • \(cost.costCategory.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(cost.approvalStatus.rawValue, color: cost.approvalStatus.color)
          }

          Text(cost.notes)
            .foregroundStyle(.secondary)
          Text("Budget \(cost.budgetCode) • Owner \(cost.costOwnerTeam) • Tax/GST \(cost.taxGSTText)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          HStack(spacing: 8) {
            Badge(cost.reimbursementStatus.rawValue, color: cost.reimbursementStatus.color)
            Badge(cost.riskLevel.rawValue, color: cost.riskLevel.color)
            Badge(cost.reviewState.rawValue, color: cost.reviewState.color)
            Label(cost.linkedEntityType.rawValue, systemImage: cost.linkedEntityType.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      if !linkedIntakeEmails.isEmpty || !linkedWishlistItems.isEmpty || !costReadinessWarnings.isEmpty {
        costInboxSourceTrail
      }
      if let store, let linkedOrder {
        OrderMailboxSourceTrailPanel(
          summaries: store.mailboxSourceSummaries(for: linkedOrder),
          title: "Mailbox provider cost trail",
          symbol: "dollarsign.arrow.circlepath"
        )
      }

      ReturnClaimStrip(claims: returnClaims)
      ProcurementRequestStrip(requests: procurementRequests)

      if let feedbackMessage {
        CostActionFeedbackPanel(message: feedbackMessage, store: store)
      }

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Approved", systemImage: "checkmark.seal.fill") {
          onApproved()
          feedbackMessage = "Cost marked approved locally."
        }
          .buttonStyle(.bordered)
        Button("Reimbursed", systemImage: "arrow.uturn.backward.circle.fill") {
          onReimbursed()
          feedbackMessage = "Cost marked reimbursed locally."
        }
          .buttonStyle(.bordered)
        Button("Dispute", systemImage: "exclamationmark.triangle.fill") {
          onDisputed()
          feedbackMessage = "Cost marked disputed for local review."
        }
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.circle.fill") {
          onReviewed()
          feedbackMessage = "Cost marked reviewed locally."
        }
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Follow-up task created from cost. Check Tasks."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Draft created from cost. Check Drafts."
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
          feedbackMessage = "Cost removed locally."
        }
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      CostRecordEditView(cost: cost) { updatedCost in
        onSave(updatedCost)
        feedbackMessage = "Cost saved locally."
      }
    }
  }

  private var costInboxSourceTrail: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label("Inbox cost readiness", systemImage: "envelope.open.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(sourceTrailDescription)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactMetadataGrid(minimumWidth: 140) {
        ForEach(costReadinessWarnings.prefix(4), id: \.self) { warning in
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
          Badge(email.detectedOrderNumber, color: email.detectedOrderNumber.isPlaceholderValidationValue ? .orange : .teal)
        }
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
  }

  private var sourceTrailDescription: String {
    if !linkedWishlistItems.isEmpty && !costReadinessWarnings.isEmpty {
      return "This cost is tied to a Wishlist-linked order and still needs local budget, approval, reimbursement, or review action."
    }
    if !linkedWishlistItems.isEmpty {
      return "Wishlist purchase context is linked to this cost record. Confirm AUD landed cost, budget code, and reimbursement state before closing."
    }
    if !costReadinessWarnings.isEmpty && !linkedIntakeEmails.isEmpty {
      return "This cost is tied to an Inbox-created order and still needs local cost readiness checks."
    }
    if !costReadinessWarnings.isEmpty {
      return "This cost still needs local budget, approval, reimbursement, or review action."
    }
    return "Inbox intake context is linked to this cost record. Provider IDs stay in Audit/details."
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

private struct CostActionFeedbackPanel: View {
  var message: String
  var store: ParcelOpsStore?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(message, systemImage: "checkmark.circle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.green)
      Text("This is local cost and reimbursement tracking only. No payment, bank feed, accounting platform, supplier API, refund, or external service was used.")
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

struct CostRecordEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: CostRecord
  var onSave: (CostRecord) -> Void

  init(cost: CostRecord, onSave: @escaping (CostRecord) -> Void) {
    self._draft = State(initialValue: cost)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Cost") {
          TextField("Title", text: $draft.title)
          TextField("Amount", text: $draft.amountText)
          TextField("Currency", text: $draft.currency)
          TextField("Tax/GST", text: $draft.taxGSTText)
          Picker("Category", selection: $draft.costCategory) {
            ForEach(CostCategory.allCases) { category in
              Text(category.rawValue).tag(category)
            }
          }
        }

        Section("Budget") {
          TextField("Budget code", text: $draft.budgetCode)
          TextField("Owner/team", text: $draft.costOwnerTeam)
          Picker("Approval", selection: $draft.approvalStatus) {
            ForEach(CostApprovalStatus.allCases) { status in
              Text(status.rawValue).tag(status)
            }
          }
          Picker("Reimbursement", selection: $draft.reimbursementStatus) {
            ForEach(ReimbursementStatus.allCases) { status in
              Text(status.rawValue).tag(status)
            }
          }
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
          TextField("Notes", text: $draft.notes, axis: .vertical)
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
      .navigationTitle("Edit Cost")
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
