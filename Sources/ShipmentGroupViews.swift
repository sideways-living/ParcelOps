import SwiftUI

struct ShipmentGroupsView: View {
  var store: ParcelOpsStore
  @State private var riskFilter: ShipmentRiskLevel?
  @State private var statusFilter = ""
  @State private var carrierFilter = ""
  @State private var reviewFilter: ReviewState?
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var filteredGroups: [ShipmentGroup] {
    store.filteredShipmentGroups(
      riskLevel: riskFilter,
      status: statusFilter,
      carrier: carrierFilter,
      reviewState: reviewFilter
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filters

        SettingsPanel(title: "Shipment groups", symbol: "shippingbox.and.arrow.backward.fill") {
          ForEach(filteredGroups) { group in
            ShipmentGroupRow(group: group, importQueueItems: store.importQueueItems(for: group), acceptanceRecords: store.acceptanceRecords(for: group), playbooks: store.suggestedPlaybooks(for: group)) { updatedGroup in
              store.updateShipmentGroup(updatedGroup)
            } onReviewed: {
              store.markShipmentGroupReviewed(group)
            } onCreateTask: {
              store.createReviewTask(from: group)
            } onCreateDraft: {
              store.createDraftMessage(from: group)
            } onRemove: {
              store.removeShipmentGroup(group)
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
    .background(.regularMaterial)
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Shipment groups")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Local grouping for split orders, related intake emails, tracking events, evidence, and operational follow-up.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button("Add", systemImage: "plus", action: store.addShipmentGroupPlaceholder)
        .buttonStyle(.borderedProminent)
    }
  }

  private var filters: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Picker("Risk", selection: $riskFilter) {
          Text("All risk").tag(ShipmentRiskLevel?.none)
          ForEach(ShipmentRiskLevel.allCases) { risk in
            Text(risk.rawValue).tag(Optional(risk))
          }
        }
        Picker("Review", selection: $reviewFilter) {
          Text("All review").tag(ReviewState?.none)
          ForEach(reviewStates, id: \.self) { state in
            Text(state.rawValue).tag(Optional(state))
          }
        }
      }
      HStack {
        TextField("Status summary", text: $statusFilter)
          .textFieldStyle(.roundedBorder)
        TextField("Carrier summary", text: $carrierFilter)
          .textFieldStyle(.roundedBorder)
      }
    }
    .pickerStyle(.menu)
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct ShipmentGroupRow: View {
  var group: ShipmentGroup
  var importQueueItems: [ImportQueueItem] = []
  var acceptanceRecords: [AcceptanceRecord] = []
  var playbooks: [ExceptionPlaybook] = []
  var onSave: (ShipmentGroup) -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var draft: ShipmentGroup
  @State private var isEditing = false

  init(
    group: ShipmentGroup,
    importQueueItems: [ImportQueueItem] = [],
    acceptanceRecords: [AcceptanceRecord] = [],
    playbooks: [ExceptionPlaybook] = [],
    onSave: @escaping (ShipmentGroup) -> Void,
    onReviewed: @escaping () -> Void,
    onCreateTask: @escaping () -> Void,
    onCreateDraft: @escaping () -> Void,
    onRemove: @escaping () -> Void
  ) {
    self.group = group
    self.importQueueItems = importQueueItems
    self.acceptanceRecords = acceptanceRecords
    self.playbooks = playbooks
    self.onSave = onSave
    self.onReviewed = onReviewed
    self.onCreateTask = onCreateTask
    self.onCreateDraft = onCreateDraft
    self.onRemove = onRemove
    _draft = State(initialValue: group)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "shippingbox.and.arrow.backward.fill")
          .foregroundStyle(group.riskLevel.color)
          .frame(width: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(group.groupName)
            .font(.headline)
          Text("\(group.carrierSummary) • \(group.statusSummary)")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("\(group.destinationSummary) • \(group.recipientCustomerSummary)")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 6) {
          Badge(group.riskLevel.rawValue, color: group.riskLevel.color)
          Badge(group.reviewState.rawValue, color: group.reviewState.color)
        }
      }

      HStack(spacing: 8) {
        Badge("\(group.relatedOrderIDs.count) orders", color: .blue)
        Badge("\(group.relatedIntakeEmailIDs.count) intake", color: .teal)
        Badge("\(group.relatedTrackingEventIDs.count) tracking", color: .orange)
        Badge("\(group.relatedEvidenceIDs.count) evidence", color: .purple)
      }

      if isEditing {
        ShipmentGroupEditForm(group: $draft)
      }

      if !importQueueItems.isEmpty {
        ImportQueueContextStrip(items: importQueueItems)
      }

      if !acceptanceRecords.isEmpty {
        AcceptanceHistoryStrip(records: acceptanceRecords)
      }

      if !playbooks.isEmpty {
        ExceptionPlaybookStrip(playbooks: playbooks)
      }

      HStack {
        Button(isEditing ? "Save" : "Edit", systemImage: isEditing ? "checkmark" : "pencil") {
          if isEditing {
            onSave(draft)
          } else {
            draft = group
          }
          isEditing.toggle()
        }
        .buttonStyle(.bordered)

        Button("Reviewed", systemImage: "checkmark.seal.fill", action: onReviewed)
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "square.and.pencil", action: onCreateDraft)
          .buttonStyle(.bordered)
        Spacer()
        Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct ShipmentGroupContextStrip: View {
  var groups: [ShipmentGroup]

  var body: some View {
    HStack(spacing: 8) {
      Label("Shipment groups", systemImage: "shippingbox.and.arrow.backward.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      ForEach(groups.prefix(3)) { group in
        Badge(group.groupName, color: group.riskLevel.color)
      }
    }
  }
}

private struct ShipmentGroupEditForm: View {
  @Binding var group: ShipmentGroup

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      TextField("Group name", text: $group.groupName)
      TextField("Destination summary", text: $group.destinationSummary)
      TextField("Recipient/customer summary", text: $group.recipientCustomerSummary)
      TextField("Carrier summary", text: $group.carrierSummary)
      TextField("Status summary", text: $group.statusSummary)
      HStack {
        Picker("Risk", selection: $group.riskLevel) {
          ForEach(ShipmentRiskLevel.allCases) { risk in
            Text(risk.rawValue).tag(risk)
          }
        }
        Picker("Review", selection: $group.reviewState) {
          Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview)
          Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor)
          Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted)
        }
      }
      .pickerStyle(.menu)
    }
    .textFieldStyle(.roundedBorder)
    .padding(10)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
