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

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filterBar

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
            ForEach(filteredCosts) { cost in
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

      ReturnClaimStrip(claims: returnClaims)
      ProcurementRequestStrip(requests: procurementRequests)

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Approved", systemImage: "checkmark.seal.fill", action: onApproved)
          .buttonStyle(.bordered)
        Button("Reimbursed", systemImage: "arrow.uturn.backward.circle.fill", action: onReimbursed)
          .buttonStyle(.bordered)
        Button("Dispute", systemImage: "exclamationmark.triangle.fill", action: onDisputed)
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
      CostRecordEditView(cost: cost) { updatedCost in
        onSave(updatedCost)
      }
    }
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
