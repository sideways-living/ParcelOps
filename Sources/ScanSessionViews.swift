import SwiftUI

struct ScanSessionsView: View {
  var store: ParcelOpsStore
  @State private var selectedPurpose: ScanPurpose?
  @State private var selectedMethod: ScanMethodPlaceholder?
  @State private var selectedStatus: ScanSessionStatus?
  @State private var operatorTeam = ""
  @State private var selectedRiskLevel: ShipmentRiskLevel?
  @State private var selectedLinkedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedReviewState: ReviewState?
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var filteredRecords: [ScanSessionRecord] {
    store.filteredScanSessionRecords(scanPurpose: selectedPurpose, scanMethod: selectedMethod, scanStatus: selectedStatus, operatorTeam: operatorTeam, riskLevel: selectedRiskLevel, linkedEntityType: selectedLinkedEntityType, reviewState: selectedReviewState)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filterBar

        SettingsPanel(title: "Scan session records", symbol: "qrcode.viewfinder") {
          HStack {
            Text("\(filteredRecords.count) visible scan sessions")
              .font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            Button("Add scan", systemImage: "plus", action: store.addScanSessionPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredRecords.isEmpty {
            Text("No scan sessions match the selected filters.")
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(12)
              .background(.quinary)
              .clipShape(RoundedRectangle(cornerRadius: 8))
          } else {
            ForEach(filteredRecords) { record in
              ScanSessionRow(record: record, shipmentManifests: store.suggestedShipmentManifestRecords(for: record)) { updatedRecord in
                store.updateScanSessionRecord(updatedRecord)
              } onMatched: {
                store.markScanSessionMatched(record)
              } onMismatch: {
                store.markScanSessionMismatch(record)
              } onCompleted: {
                store.markScanSessionCompleted(record)
              } onReopen: {
                store.reopenScanSession(record)
              } onReviewed: {
                store.markScanSessionReviewed(record)
              } onCreateTask: {
                store.createReviewTask(from: record)
              } onCreateDraft: {
                store.createDraftMessage(from: record)
              } onRemove: {
                store.removeScanSessionRecord(record)
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
        Text("Scan Sessions")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Local manual verification sessions for barcode, QR, label, order, custody, receiving, and inventory checks.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(store.mismatchScanSessions.count) mismatch", color: .red)
        Badge("\(store.incompleteScanSessions.count) incomplete", color: .orange)
      }
    }
  }

  private var filterBar: some View {
    HStack {
      Picker("Purpose", selection: $selectedPurpose) {
        Text("All purposes").tag(nil as ScanPurpose?)
        ForEach(ScanPurpose.allCases) { purpose in Text(purpose.rawValue).tag(purpose as ScanPurpose?) }
      }
      .pickerStyle(.menu)

      Picker("Method", selection: $selectedMethod) {
        Text("All methods").tag(nil as ScanMethodPlaceholder?)
        ForEach(ScanMethodPlaceholder.allCases) { method in Text(method.rawValue).tag(method as ScanMethodPlaceholder?) }
      }
      .pickerStyle(.menu)

      Picker("Status", selection: $selectedStatus) {
        Text("All status").tag(nil as ScanSessionStatus?)
        ForEach(ScanSessionStatus.allCases) { status in Text(status.rawValue).tag(status as ScanSessionStatus?) }
      }
      .pickerStyle(.menu)

      TextField("Operator/team", text: $operatorTeam)
        .textFieldStyle(.roundedBorder)
        .frame(maxWidth: 150)

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
        selectedPurpose = nil
        selectedMethod = nil
        selectedStatus = nil
        operatorTeam = ""
        selectedRiskLevel = nil
        selectedLinkedEntityType = nil
        selectedReviewState = nil
      }
      .buttonStyle(.bordered)
    }
  }
}

struct ScanSessionRow: View {
  var record: ScanSessionRecord
  var shipmentManifests: [ShipmentManifestRecord] = []
  var onSave: (ScanSessionRecord) -> Void
  var onMatched: () -> Void
  var onMismatch: () -> Void
  var onCompleted: () -> Void
  var onReopen: () -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: record.scanPurpose.symbol)
          .foregroundStyle(record.riskLevel.color)
          .frame(width: 28, height: 28)
        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(record.title)
                .font(.headline)
              Text("\(record.scanPurpose.rawValue) • \(record.scanMethodPlaceholder.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(record.scanStatus.rawValue, color: record.scanStatus.color)
          }
          Text("Expected \(record.expectedLabelReferenceValue) • captured \(record.capturedValuePlaceholder.isEmpty ? "missing" : record.capturedValuePlaceholder)")
            .foregroundStyle(.secondary)
          Text("\(record.mismatchSummary) • Operator \(record.assignedOperatorTeam)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)
          HStack(spacing: 8) {
            Badge(record.riskLevel.rawValue, color: record.riskLevel.color)
            Badge(record.reviewState.rawValue, color: record.reviewState.color)
            Label(record.linkedEntityType.rawValue, systemImage: record.linkedEntityType.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
            Label(record.completedDate, systemImage: "calendar")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      HStack {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Matched", systemImage: "checkmark.circle.fill", action: onMatched)
          .buttonStyle(.bordered)
        Button("Mismatch", systemImage: "exclamationmark.triangle.fill", action: onMismatch)
          .buttonStyle(.bordered)
        Button("Complete", systemImage: "checkmark.seal.fill", action: onCompleted)
          .buttonStyle(.bordered)
        Button("Reopen", systemImage: "arrow.counterclockwise", action: onReopen)
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

      if !shipmentManifests.isEmpty {
        ShipmentManifestStrip(records: shipmentManifests)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      ScanSessionEditView(record: record) { updatedRecord in
        onSave(updatedRecord)
      }
    }
  }
}

struct ScanSessionEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: ScanSessionRecord
  var onSave: (ScanSessionRecord) -> Void

  init(record: ScanSessionRecord, onSave: @escaping (ScanSessionRecord) -> Void) {
    self._draft = State(initialValue: record)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Scan") {
          TextField("Title", text: $draft.title)
          Picker("Purpose", selection: $draft.scanPurpose) {
            ForEach(ScanPurpose.allCases) { purpose in Text(purpose.rawValue).tag(purpose) }
          }
          Picker("Method", selection: $draft.scanMethodPlaceholder) {
            ForEach(ScanMethodPlaceholder.allCases) { method in Text(method.rawValue).tag(method) }
          }
          Picker("Status", selection: $draft.scanStatus) {
            ForEach(ScanSessionStatus.allCases) { status in Text(status.rawValue).tag(status) }
          }
          TextField("Expected value", text: $draft.expectedLabelReferenceValue)
          TextField("Captured value", text: $draft.capturedValuePlaceholder)
          TextField("Mismatch summary", text: $draft.mismatchSummary, axis: .vertical)
        }

        Section("Ownership") {
          TextField("Operator/team", text: $draft.assignedOperatorTeam)
          TextField("Created date", text: $draft.createdDate)
          TextField("Completed date", text: $draft.completedDate)
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
      .navigationTitle("Edit Scan")
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
    .frame(minWidth: 640, minHeight: 680)
  }
}
