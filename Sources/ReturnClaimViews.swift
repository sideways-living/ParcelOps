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
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var filteredClaims: [ReturnClaimRecord] {
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

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filterBar

        SettingsPanel(title: "Return and claim records", symbol: "arrow.uturn.backward.square.fill") {
          HStack {
            Text("\(filteredClaims.count) visible return/claim records")
              .font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            Button("Add claim", systemImage: "plus", action: store.addReturnClaimPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredClaims.isEmpty {
            Text("No returns or claims match the selected filters.")
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(12)
              .background(.quinary)
              .clipShape(RoundedRectangle(cornerRadius: 8))
          } else {
            ForEach(filteredClaims) { claim in
              ReturnClaimRow(claim: claim, procurementRequests: store.suggestedProcurementRequests(for: claim), receivingInspections: store.suggestedReceivingInspections(for: claim), inventoryReceipts: store.suggestedInventoryReceipts(for: claim), storageLocations: store.suggestedStorageLocations(for: claim), custodyRecords: store.suggestedCustodyRecords(for: claim)) { updatedClaim in
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
    HStack {
      Picker("Type", selection: $selectedClaimType) {
        Text("All types").tag(nil as ReturnClaimType?)
        ForEach(ReturnClaimType.allCases) { type in
          Text(type.rawValue).tag(type as ReturnClaimType?)
        }
      }
      .pickerStyle(.menu)

      Picker("Status", selection: $selectedStatus) {
        Text("All status").tag(nil as ReturnClaimStatus?)
        ForEach(ReturnClaimStatus.allCases) { status in
          Text(status.rawValue).tag(status as ReturnClaimStatus?)
        }
      }
      .pickerStyle(.menu)

      Picker("Outcome", selection: $selectedOutcome) {
        Text("All outcomes").tag(nil as ReturnClaimOutcome?)
        ForEach(ReturnClaimOutcome.allCases) { outcome in
          Text(outcome.rawValue).tag(outcome as ReturnClaimOutcome?)
        }
      }
      .pickerStyle(.menu)

      TextField("Owner/team", text: $ownerTeam)
        .textFieldStyle(.roundedBorder)
        .frame(maxWidth: 160)

      Picker("Risk", selection: $selectedRiskLevel) {
        Text("All risk").tag(nil as ShipmentRiskLevel?)
        ForEach(ShipmentRiskLevel.allCases) { risk in
          Text(risk.rawValue).tag(risk as ShipmentRiskLevel?)
        }
      }
      .pickerStyle(.menu)

      Picker("Linked", selection: $selectedLinkedEntityType) {
        Text("All links").tag(nil as ReviewTaskLinkedEntityType?)
        ForEach(ReviewTaskLinkedEntityType.allCases) { type in
          Text(type.rawValue).tag(type as ReviewTaskLinkedEntityType?)
        }
      }
      .pickerStyle(.menu)

      Picker("Review", selection: $selectedReviewState) {
        Text("All review").tag(nil as ReviewState?)
        ForEach(reviewStates, id: \.self) { state in
          Text(state.rawValue).tag(state as ReviewState?)
        }
      }
      .pickerStyle(.menu)

      Spacer()

      Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle") {
        selectedClaimType = nil
        selectedStatus = nil
        selectedOutcome = nil
        ownerTeam = ""
        selectedRiskLevel = nil
        selectedLinkedEntityType = nil
        selectedReviewState = nil
      }
      .buttonStyle(.bordered)
    }
  }
}

struct ReturnClaimRow: View {
  var claim: ReturnClaimRecord
  var procurementRequests: [ProcurementRequest] = []
  var receivingInspections: [ReceivingInspectionRecord] = []
  var inventoryReceipts: [InventoryReceiptRecord] = []
  var storageLocations: [StorageLocationRecord] = []
  var custodyRecords: [CustodyRecord] = []
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

      ProcurementRequestStrip(requests: procurementRequests)
      ReceivingInspectionStrip(inspections: receivingInspections)
      InventoryReceiptStrip(receipts: inventoryReceipts)
      StorageLocationStrip(locations: storageLocations)
      CustodyRecordStrip(records: custodyRecords)

      HStack {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Submitted", systemImage: "paperplane.fill", action: onSubmitted)
          .buttonStyle(.bordered)
        Button("Approved", systemImage: "checkmark.seal.fill", action: onApproved)
          .buttonStyle(.bordered)
        Button("Resolved", systemImage: "checkmark.circle.fill", action: onResolved)
          .buttonStyle(.bordered)
        Button("Dispute", systemImage: "exclamationmark.triangle.fill", action: onDisputed)
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.shield.fill", action: onReviewed)
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill", action: onCreateDraft)
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      ReturnClaimEditView(claim: claim) { updatedClaim in
        onSave(updatedClaim)
      }
    }
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
