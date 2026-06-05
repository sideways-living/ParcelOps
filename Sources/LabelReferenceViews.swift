import SwiftUI

struct LabelReferencesView: View {
  var store: ParcelOpsStore
  @State private var selectedType: LabelReferenceType?
  @State private var selectedStatus: LabelReferenceStatus?
  @State private var selectedSource: LabelReferenceSource?
  @State private var carrier = ""
  @State private var ownerTeam = ""
  @State private var selectedRiskLevel: ShipmentRiskLevel?
  @State private var selectedLinkedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedReviewState: ReviewState?
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var filteredRecords: [LabelReferenceRecord] {
    store.filteredLabelReferenceRecords(labelType: selectedType, labelStatus: selectedStatus, labelSource: selectedSource, carrier: carrier, ownerTeam: ownerTeam, riskLevel: selectedRiskLevel, linkedEntityType: selectedLinkedEntityType, reviewState: selectedReviewState)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filterBar

        SettingsPanel(title: "Label reference records", symbol: "barcode.viewfinder") {
          HStack {
            Text("\(filteredRecords.count) visible label references")
              .font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            Button("Add label", systemImage: "plus", action: store.addLabelReferencePlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredRecords.isEmpty {
            Text("No label references match the selected filters.")
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(12)
              .background(.quinary)
              .clipShape(RoundedRectangle(cornerRadius: 8))
          } else {
            ForEach(filteredRecords) { record in
              LabelReferenceRow(record: record, scanSessions: store.suggestedScanSessionRecords(for: record), shipmentManifests: store.suggestedShipmentManifestRecords(for: record), dispatchChecklists: store.suggestedDispatchReadinessChecklists(for: record)) { updatedRecord in
                store.updateLabelReferenceRecord(updatedRecord)
              } onPrinted: {
                store.markLabelReferencePrinted(record)
              } onVerified: {
                store.markLabelReferenceVerified(record)
              } onInvalid: {
                store.markLabelReferenceInvalid(record)
              } onReviewed: {
                store.markLabelReferenceReviewed(record)
              } onCreateTask: {
                store.createReviewTask(from: record)
              } onCreateDraft: {
                store.createDraftMessage(from: record)
              } onRemove: {
                store.removeLabelReferenceRecord(record)
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
        Text("Label References")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Local barcode, QR, tracking, storage, custody, receiving, return, and evidence label placeholders.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(store.invalidLabelReferences.count) invalid", color: .red)
        Badge("\(store.labelReferencesMissingValues.count) missing values", color: .orange)
      }
    }
  }

  private var filterBar: some View {
    HStack {
      Picker("Type", selection: $selectedType) {
        Text("All types").tag(nil as LabelReferenceType?)
        ForEach(LabelReferenceType.allCases) { type in Text(type.rawValue).tag(type as LabelReferenceType?) }
      }
      .pickerStyle(.menu)

      Picker("Status", selection: $selectedStatus) {
        Text("All status").tag(nil as LabelReferenceStatus?)
        ForEach(LabelReferenceStatus.allCases) { status in Text(status.rawValue).tag(status as LabelReferenceStatus?) }
      }
      .pickerStyle(.menu)

      Picker("Source", selection: $selectedSource) {
        Text("All sources").tag(nil as LabelReferenceSource?)
        ForEach(LabelReferenceSource.allCases) { source in Text(source.rawValue).tag(source as LabelReferenceSource?) }
      }
      .pickerStyle(.menu)

      TextField("Carrier", text: $carrier)
        .textFieldStyle(.roundedBorder)
        .frame(maxWidth: 120)
      TextField("Owner/team", text: $ownerTeam)
        .textFieldStyle(.roundedBorder)
        .frame(maxWidth: 140)

      Picker("Risk", selection: $selectedRiskLevel) {
        Text("All risk").tag(nil as ShipmentRiskLevel?)
        ForEach(ShipmentRiskLevel.allCases) { risk in Text(risk.rawValue).tag(risk as ShipmentRiskLevel?) }
      }
      .pickerStyle(.menu)

      Picker("Linked", selection: $selectedLinkedEntityType) {
        Text("All links").tag(nil as ReviewTaskLinkedEntityType?)
        ForEach(ReviewTaskLinkedEntityType.allCases) { type in Text(type.rawValue).tag(type as ReviewTaskLinkedEntityType?) }
      }
      .pickerStyle(.menu)

      Picker("Review", selection: $selectedReviewState) {
        Text("All review").tag(nil as ReviewState?)
        ForEach(reviewStates, id: \.self) { state in Text(state.rawValue).tag(state as ReviewState?) }
      }
      .pickerStyle(.menu)

      Spacer()
      Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle") {
        selectedType = nil
        selectedStatus = nil
        selectedSource = nil
        carrier = ""
        ownerTeam = ""
        selectedRiskLevel = nil
        selectedLinkedEntityType = nil
        selectedReviewState = nil
      }
      .buttonStyle(.bordered)
    }
  }
}

struct LabelReferenceRow: View {
  var record: LabelReferenceRecord
  var scanSessions: [ScanSessionRecord] = []
  var shipmentManifests: [ShipmentManifestRecord] = []
  var dispatchChecklists: [DispatchReadinessChecklist] = []
  var onSave: (LabelReferenceRecord) -> Void
  var onPrinted: () -> Void
  var onVerified: () -> Void
  var onInvalid: () -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: record.labelType.symbol)
          .foregroundStyle(record.riskLevel.color)
          .frame(width: 28, height: 28)
        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(record.title)
                .font(.headline)
              Text("\(record.labelType.rawValue) • \(record.labelValuePlaceholder)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(record.labelStatus.rawValue, color: record.labelStatus.color)
          }
          Text(record.notes)
            .foregroundStyle(.secondary)
          Text("\(record.labelSource.rawValue) • \(record.associatedCarrier) • Owner \(record.assignedOwnerTeam)")
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

      ScanSessionStrip(records: scanSessions)

      HStack {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Printed", systemImage: "printer.fill", action: onPrinted)
          .buttonStyle(.bordered)
        Button("Verified", systemImage: "barcode.viewfinder", action: onVerified)
          .buttonStyle(.bordered)
        Button("Invalid", systemImage: "exclamationmark.triangle.fill", action: onInvalid)
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
      LabelReferenceEditView(record: record) { updatedRecord in
        onSave(updatedRecord)
      }
    }
  }
}

struct LabelReferenceEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: LabelReferenceRecord
  var onSave: (LabelReferenceRecord) -> Void

  init(record: LabelReferenceRecord, onSave: @escaping (LabelReferenceRecord) -> Void) {
    self._draft = State(initialValue: record)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Label") {
          TextField("Title", text: $draft.title)
          Picker("Type", selection: $draft.labelType) {
            ForEach(LabelReferenceType.allCases) { type in Text(type.rawValue).tag(type) }
          }
          TextField("Value placeholder", text: $draft.labelValuePlaceholder)
          Picker("Source", selection: $draft.labelSource) {
            ForEach(LabelReferenceSource.allCases) { source in Text(source.rawValue).tag(source) }
          }
          Picker("Status", selection: $draft.labelStatus) {
            ForEach(LabelReferenceStatus.allCases) { status in Text(status.rawValue).tag(status) }
          }
          TextField("Associated carrier", text: $draft.associatedCarrier)
        }

        Section("Ownership") {
          TextField("Owner/team", text: $draft.assignedOwnerTeam)
          TextField("Created date", text: $draft.createdDate)
          TextField("Last reviewed", text: $draft.lastReviewedDate)
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
      .navigationTitle("Edit Label")
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
