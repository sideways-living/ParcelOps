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
        inboxShipmentGroupCoverage

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

  private var inboxShipmentGroupCoverage: some View {
    SettingsPanel(title: "Inbox shipment group coverage", symbol: "shippingbox.and.arrow.backward.fill") {
      Text("Checks whether orders created from Inbox intake have local shipment group context before dispatch work begins.")
        .font(.caption)
        .foregroundStyle(.secondary)

      CompactMetadataGrid(minimumWidth: 150) {
        Badge("\(inboxCreatedOrders.count) Inbox orders", color: .blue)
        Badge("\(groupsLinkedToInboxOrders.count) linked groups", color: .teal)
        Badge("\(inboxOrdersMissingGroup.count) orders without groups", color: inboxOrdersMissingGroup.isEmpty ? .green : .orange)
        Badge("\(groupsMissingPrimaryOrder.count) groups missing primary", color: groupsMissingPrimaryOrder.isEmpty ? .green : .orange)
      }

      if inboxCreatedOrders.isEmpty {
        Text("No Inbox-created orders need shipment group checks yet.")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else if inboxOrdersMissingGroup.isEmpty && groupsMissingPrimaryOrder.isEmpty {
        Label("Inbox-created orders have shipment group coverage for the current local workflow.", systemImage: "checkmark.seal.fill")
          .font(.caption)
          .foregroundStyle(.green)
      } else {
        VStack(alignment: .leading, spacing: 8) {
          if !inboxOrdersMissingGroup.isEmpty {
            Text("Orders needing shipment group setup")
              .font(.caption.weight(.semibold))
            CompactActionRow {
              ForEach(inboxOrdersMissingGroup.prefix(4)) { order in
                NavigationLink {
                  OrderDetailView(order: order, store: store)
                } label: {
                  Label(order.orderNumber, systemImage: "arrow.up.right.square.fill")
                }
                .buttonStyle(.bordered)
              }
            }
          }

          if !groupsMissingPrimaryOrder.isEmpty {
            Text("Shipment groups missing a valid primary order")
              .font(.caption.weight(.semibold))
            CompactMetadataGrid(minimumWidth: 160) {
              ForEach(groupsMissingPrimaryOrder.prefix(4)) { group in
                Badge(group.groupName, color: .orange)
              }
            }
          }
        }
      }
    }
  }

  private var inboxCreatedOrders: [TrackedOrder] {
    store.orders.filter { order in
      !linkedIntakeEmails(for: order).isEmpty
    }
  }

  private var groupsLinkedToInboxOrders: [ShipmentGroup] {
    store.shipmentGroups.filter { group in
      let groupOrderIDs = Set(([group.primaryOrderID].compactMap { $0 } + group.relatedOrderIDs))
      return !group.relatedIntakeEmailIDs.isEmpty
        || inboxCreatedOrders.contains { groupOrderIDs.contains($0.id) }
    }
  }

  private var inboxOrdersMissingGroup: [TrackedOrder] {
    inboxCreatedOrders.filter { order in
      !store.shipmentGroups.contains { group in
        group.primaryOrderID == order.id || group.relatedOrderIDs.contains(order.id)
      }
    }
  }

  private var groupsMissingPrimaryOrder: [ShipmentGroup] {
    store.shipmentGroups.filter { group in
      guard let primaryOrderID = group.primaryOrderID else { return true }
      return !store.orders.contains { $0.id == primaryOrderID }
    }
  }

  private func linkedIntakeEmails(for order: TrackedOrder) -> [ForwardedEmailIntake] {
    let orderNumber = order.orderNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    return store.intakeEmails.filter { email in
      email.linkedOrderID == order.id
        || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.detectedOrderNumber.localizedCaseInsensitiveContains(orderNumber))
        || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.subject.localizedCaseInsensitiveContains(orderNumber))
        || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.rawBodyPreview.localizedCaseInsensitiveContains(orderNumber))
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

  private var linkedOrderIntakeEmails: [ForwardedEmailIntake] {
    guard let store else { return [] }
    let linkedOrderIDs = Set(linkedOrders.map(\.id))
    return store.intakeEmails.filter { email in
      email.linkedOrderID.map { linkedOrderIDs.contains($0) } == true
    }
  }

  private var sourceTrailEmails: [ForwardedEmailIntake] {
    (linkedIntakeEmails + linkedOrderIntakeEmails).uniquedByID()
  }

  private var missingPrimaryOrder: Bool {
    guard let primaryOrderID = group.primaryOrderID else { return true }
    return !linkedOrders.contains { $0.id == primaryOrderID }
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

      if !sourceTrailEmails.isEmpty || missingPrimaryOrder {
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
      Text(sourceTrailDescription)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      CompactMetadataGrid(minimumWidth: 140) {
        if missingPrimaryOrder {
          Badge("Primary order missing", color: .orange)
        }
        ForEach(sourceTrailEmails.prefix(4)) { email in
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

  private var sourceTrailDescription: String {
    if sourceTrailEmails.isEmpty && missingPrimaryOrder {
      return "This group needs a valid primary order before dispatch context is reliable."
    }
    if missingPrimaryOrder {
      return "Inbox source rows are linked, but this group still needs a valid primary order."
    }
    return "Inbox intake rows explain how this shipment group entered the local workflow. Provider IDs stay in Audit/details."
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

private extension Array where Element == ForwardedEmailIntake {
  func uniquedByID() -> [ForwardedEmailIntake] {
    var seen: Set<UUID> = []
    return filter { seen.insert($0.id).inserted }
  }
}
