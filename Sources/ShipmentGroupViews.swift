import SwiftUI

struct ShipmentGroupsView: View {
  var store: ParcelOpsStore
  @State private var riskFilter: ShipmentRiskLevel?
  @State private var statusFilter = ""
  @State private var carrierFilter = ""
  @State private var reviewFilter: ReviewState?
  @State private var groupSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var baseFilteredGroups: [ShipmentGroup] {
    store.filteredShipmentGroups(
      riskLevel: riskFilter,
      status: statusFilter,
      carrier: carrierFilter,
      reviewState: reviewFilter
    )
  }

  private var filteredGroups: [ShipmentGroup] {
    let query = groupSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredGroups }
    return baseFilteredGroups.filter { group in
      shipmentGroup(group, matches: query)
    }
  }

  private var hasActiveFilters: Bool {
    riskFilter != nil
      || !statusFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !carrierFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || reviewFilter != nil
      || !groupSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filters

        SettingsPanel(title: "Shipment groups", symbol: "shippingbox.and.arrow.backward.fill") {
          HStack {
            Text("\(filteredGroups.count) visible groups")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredGroups.count) after filters", color: .blue)
            }
            Spacer()
          }

          if filteredGroups.isEmpty {
            MVPEmptyState(
              title: "No shipment groups match this view",
              detail: hasActiveFilters ? "Clear search or filters to return to all shipment groups." : "Add a placeholder group to test split-order and dispatch context.",
              symbol: "shippingbox.and.arrow.backward.fill",
              actionTitle: hasActiveFilters ? "Clear filters" : "Add group",
              action: hasActiveFilters ? clearFilters : store.addShipmentGroupPlaceholder
            )
          } else {
            ForEach(filteredGroups) { group in
              ShipmentGroupRow(group: group, store: store, linkedOrders: linkedOrders(for: group), importQueueItems: store.importQueueItems(for: group), acceptanceRecords: store.acceptanceRecords(for: group), playbooks: store.suggestedPlaybooks(for: group), handoffNotes: store.handoffNotes(for: group), customerProfiles: store.suggestedCustomerProfiles(for: group), destinationAddresses: store.suggestedDestinationAddresses(for: group), deliveryInstructions: store.suggestedDeliveryInstructions(for: group), packageContents: store.suggestedPackageContents(for: group)) { updatedGroup in
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
    FilterControlGrid {
      TextField("Search group, order, intake, tracking, evidence, destination, customer, carrier, or status", text: $groupSearchText)
        .textFieldStyle(.roundedBorder)
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
      TextField("Status summary", text: $statusFilter)
      TextField("Carrier summary", text: $carrierFilter)
      if hasActiveFilters {
        Button("Clear filters", systemImage: "xmark.circle") {
          clearFilters()
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private func clearFilters() {
    riskFilter = nil
    statusFilter = ""
    carrierFilter = ""
    reviewFilter = nil
    groupSearchText = ""
  }

  private func shipmentGroup(_ group: ShipmentGroup, matches query: String) -> Bool {
    let linkedOrders = linkedOrders(for: group)
    let importItems = store.importQueueItems(for: group)
    let acceptanceRecords = store.acceptanceRecords(for: group)
    let orderText = linkedOrders.map { order in
      [
        order.store,
        order.orderNumber,
        order.customer,
        order.recipientEmail,
        order.carrier,
        order.trackingNumber,
        order.destination,
        order.status.rawValue,
        order.latestStatus
      ].joined(separator: " ")
    }.joined(separator: " ")
    let importText = importItems.map { item in
      [
        item.sourceLabel,
        item.rawSummary,
        item.detectedMerchant,
        item.detectedOrderNumber,
        item.detectedTrackingNumber,
        item.detectedDestinationAddress,
        item.importStatus.rawValue,
        item.notes
      ].joined(separator: " ")
    }.joined(separator: " ")
    let acceptanceText = acceptanceRecords.map { record in
      [
        record.sourceLabel,
        record.summary,
        record.decision.rawValue,
        record.reviewState.rawValue,
        record.notes
      ].joined(separator: " ")
    }.joined(separator: " ")
    let searchableText = [
      group.id.uuidString,
      group.groupName,
      group.primaryOrderID?.uuidString ?? "",
      group.relatedOrderIDs.map(\.uuidString).joined(separator: " "),
      group.relatedIntakeEmailIDs.map(\.uuidString).joined(separator: " "),
      group.relatedTrackingEventIDs.map(\.uuidString).joined(separator: " "),
      group.relatedEvidenceIDs.map(\.uuidString).joined(separator: " "),
      group.destinationSummary,
      group.recipientCustomerSummary,
      group.carrierSummary,
      group.statusSummary,
      group.riskLevel.rawValue,
      group.reviewState.rawValue,
      group.createdDate,
      group.lastReviewedDate,
      orderText,
      importText,
      acceptanceText
    ].joined(separator: " ")
    return searchableText.localizedLowercase.contains(query)
  }

  private func linkedOrders(for group: ShipmentGroup) -> [TrackedOrder] {
    let orderIDs = ([group.primaryOrderID].compactMap { $0 } + group.relatedOrderIDs).reduce(into: [UUID]()) { result, orderID in
      if !result.contains(orderID) {
        result.append(orderID)
      }
    }
    return orderIDs.compactMap { orderID in
      store.orders.first { $0.id == orderID }
    }
  }
}

struct ShipmentGroupRow: View {
  var group: ShipmentGroup
  var store: ParcelOpsStore? = nil
  var linkedOrders: [TrackedOrder] = []
  var importQueueItems: [ImportQueueItem] = []
  var acceptanceRecords: [AcceptanceRecord] = []
  var playbooks: [ExceptionPlaybook] = []
  var handoffNotes: [HandoffNote] = []
  var customerProfiles: [CustomerRecipientProfile] = []
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var onSave: (ShipmentGroup) -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var draft: ShipmentGroup
  @State private var isEditing = false

  private var linkedIntakeEmails: [ForwardedEmailIntake] {
    guard let store else { return [] }
    return store.intakeEmails.filter { group.relatedIntakeEmailIDs.contains($0.id) }
  }

  init(
    group: ShipmentGroup,
    store: ParcelOpsStore? = nil,
    linkedOrders: [TrackedOrder] = [],
    importQueueItems: [ImportQueueItem] = [],
    acceptanceRecords: [AcceptanceRecord] = [],
    playbooks: [ExceptionPlaybook] = [],
    handoffNotes: [HandoffNote] = [],
    customerProfiles: [CustomerRecipientProfile] = [],
    destinationAddresses: [DestinationAddressRecord] = [],
    deliveryInstructions: [DeliveryInstructionRecord] = [],
    packageContents: [PackageContentRecord] = [],
    onSave: @escaping (ShipmentGroup) -> Void,
    onReviewed: @escaping () -> Void,
    onCreateTask: @escaping () -> Void,
    onCreateDraft: @escaping () -> Void,
    onRemove: @escaping () -> Void
  ) {
    self.group = group
    self.store = store
    self.linkedOrders = linkedOrders
    self.importQueueItems = importQueueItems
    self.acceptanceRecords = acceptanceRecords
    self.playbooks = playbooks
    self.handoffNotes = handoffNotes
    self.customerProfiles = customerProfiles
    self.destinationAddresses = destinationAddresses
    self.deliveryInstructions = deliveryInstructions
    self.packageContents = packageContents
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

      if !linkedIntakeEmails.isEmpty {
        shipmentGroupInboxSourceTrail
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

      if !handoffNotes.isEmpty {
        HandoffNoteStrip(notes: handoffNotes)
      }

      if !customerProfiles.isEmpty {
        CustomerProfileStrip(profiles: customerProfiles)
      }
      if !destinationAddresses.isEmpty {
        DestinationAddressStrip(addresses: destinationAddresses)
      }
      if !deliveryInstructions.isEmpty {
        DeliveryInstructionStrip(instructions: deliveryInstructions)
      }
      if !packageContents.isEmpty {
        PackageContentStrip(contents: packageContents)
      }

      CompactActionRow {
        if let store {
          ForEach(linkedOrders.prefix(3)) { order in
            NavigationLink {
              OrderDetailView(order: order, store: store)
            } label: {
              Label(order.orderNumber, systemImage: "arrow.up.right.square.fill")
            }
            .buttonStyle(.bordered)
          }
        }
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
        Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }

  private var shipmentGroupInboxSourceTrail: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label("Inbox source trail", systemImage: "envelope.open.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text("Linked intake rows explain how this shipment group entered the local workflow. Provider IDs stay in Audit/details.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      CompactMetadataGrid(minimumWidth: 140) {
        ForEach(linkedIntakeEmails.prefix(4)) { email in
          if let store {
            let source = store.intakeSourceSummary(for: email)
            Badge(source.label, color: sourceColor(for: source.tone))
            Badge(source.status, color: source.status == MailboxIngestStatus.imported.rawValue ? .green : .orange)
          }
          Badge(email.detectedOrderNumber, color: email.detectedOrderNumber.isPlaceholderValidationValue ? .orange : .blue)
        }
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
  }

  private func sourceColor(for tone: String) -> Color {
    switch tone {
    case "spacemail":
      return .teal
    case "mock":
      return .purple
    case "microsoft", "mailbox":
      return .blue
    default:
      return .secondary
    }
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
