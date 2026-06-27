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
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var filteredRecords: [CustodyRecord] {
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

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filterBar

        SettingsPanel(title: "Custody chain records", symbol: "person.badge.shield.checkmark.fill") {
          HStack {
            Text("\(filteredRecords.count) visible custody records")
              .font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            Button("Add custody", systemImage: "plus", action: store.addCustodyRecordPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredRecords.isEmpty {
            Text("No custody records match the selected filters.")
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(12)
              .background(.quinary)
              .clipShape(RoundedRectangle(cornerRadius: 8))
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
    HStack {
      Picker("Status", selection: $selectedStatus) {
        Text("All status").tag(nil as CustodyStatus?)
        ForEach(CustodyStatus.allCases) { status in
          Text(status.rawValue).tag(status as CustodyStatus?)
        }
      }
      .pickerStyle(.menu)

      TextField("Custodian/team", text: $custodianTeam)
        .textFieldStyle(.roundedBorder)
        .frame(maxWidth: 155)

      TextField("Owner/team", text: $ownerTeam)
        .textFieldStyle(.roundedBorder)
        .frame(maxWidth: 145)

      Picker("Method", selection: $selectedHandoffMethod) {
        Text("All methods").tag(nil as CustodyHandoffMethod?)
        ForEach(CustodyHandoffMethod.allCases) { method in
          Text(method.rawValue).tag(method as CustodyHandoffMethod?)
        }
      }
      .pickerStyle(.menu)

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
        selectedStatus = nil
        custodianTeam = ""
        ownerTeam = ""
        selectedHandoffMethod = nil
        selectedRiskLevel = nil
        selectedLinkedEntityType = nil
        selectedReviewState = nil
      }
      .buttonStyle(.bordered)
    }
  }

  private func linkedOrder(for record: CustodyRecord) -> TrackedOrder? {
    let orderID = record.orderID ?? (record.linkedEntityType == .order ? UUID(uuidString: record.linkedEntityID) : nil)
    guard let orderID else { return nil }
    return store.orders.first { $0.id == orderID }
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

      HStack {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Transferred", systemImage: "arrow.right.circle.fill", action: onTransferred)
          .buttonStyle(.bordered)
        Button("Received", systemImage: "checkmark.circle.fill", action: onReceived)
          .buttonStyle(.bordered)
        Button("Closed", systemImage: "checkmark.seal.fill", action: onReturnedClosed)
          .buttonStyle(.bordered)
        Button("Dispute", systemImage: "exclamationmark.triangle.fill", action: onDisputed)
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.shield.fill", action: onReviewed)
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
      CustodyRecordEditView(record: record) { updatedRecord in
        onSave(updatedRecord)
      }
    }
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
