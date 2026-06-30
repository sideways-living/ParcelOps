import SwiftUI

struct ImportQueueView: View {
  var store: ParcelOpsStore
  @State private var sourceFilter: ImportSourceType?
  @State private var statusFilter: ImportStatus?
  @State private var confidenceFilter: ImportConfidenceRange = .all
  @State private var reviewFilter: ReviewState?
  @State private var importSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var baseFilteredItems: [ImportQueueItem] {
    store.filteredImportQueueItems(
      sourceType: sourceFilter,
      status: statusFilter,
      confidenceRange: confidenceFilter,
      reviewState: reviewFilter
    )
  }

  private var filteredItems: [ImportQueueItem] {
    let query = importSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredItems }
    return baseFilteredItems.filter { item in
      importQueueItem(item, matches: query)
    }
  }

  private var hasActiveFilters: Bool {
    sourceFilter != nil
      || statusFilter != nil
      || confidenceFilter != .all
      || reviewFilter != nil
      || !importSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        MVPWorkflowGuide(
          title: "Import queue workflow",
          detail: "Use this screen when order information is staged manually or captured from a local placeholder source.",
          steps: [
            "Review confidence and detected merchant/order/tracking fields.",
            "Edit notes or detected values if the staged record is wrong.",
            "Link to an order or shipment group, or create new local records.",
            "Accept, ignore, or reopen the import item."
          ],
          symbol: "tray.and.arrow.down.fill"
        )
        filters

        SettingsPanel(title: "Staged imports", symbol: "tray.and.arrow.down.fill") {
          HStack {
            Text("\(filteredItems.count) visible import items")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredItems.count) after filters", color: .blue)
            }
            Spacer()
          }

          if filteredItems.isEmpty {
            MVPEmptyState(title: "No staged imports match this view", detail: hasActiveFilters ? "Clear search or filters to return to the full import queue." : "Add a placeholder import item to test the local acceptance workflow.", symbol: "tray.and.arrow.down.fill", actionTitle: hasActiveFilters ? "Clear filters" : "Add import item", action: hasActiveFilters ? clearFilters : store.addImportQueueItemPlaceholder)
          } else {
            ForEach(filteredItems) { item in
              ImportQueueItemRow(
                item: item,
                store: store,
                orders: store.orders,
                shipmentGroups: store.shipmentGroups,
                playbooks: store.suggestedPlaybooks(for: item),
                handoffNotes: store.handoffNotes(for: item),
                customerProfiles: store.suggestedCustomerProfiles(for: item),
                destinationAddresses: store.suggestedDestinationAddresses(for: item),
                deliveryInstructions: store.suggestedDeliveryInstructions(for: item),
                packageContents: store.suggestedPackageContents(for: item),
                onSave: store.updateImportQueueItem,
                onLinkOrder: { order in store.linkImportQueueItem(item, to: order) },
                onLinkShipmentGroup: { group in store.linkImportQueueItem(item, to: group) },
                onCreateOrder: { store.createOrder(from: item) },
                onCreateShipmentGroup: { store.createShipmentGroup(from: item) },
                onAccepted: { store.markImportQueueItemAccepted(item) },
                onIgnored: { store.ignoreImportQueueItem(item) },
                onReopen: { store.reopenImportQueueItem(item) },
                onRemove: { store.removeImportQueueItem(item) },
                onCreateTask: { store.createReviewTask(from: item) },
                onCreateDraft: { store.createDraftMessage(from: item) }
              )
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
    .background(.regularMaterial)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Import queue")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Stage local order records before accepting them into orders, shipment groups, tasks, and communications.")
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button("Add local import", systemImage: "plus", action: store.addImportQueueItemPlaceholder)
          .buttonStyle(.borderedProminent)
      }

      CompactActionRow {
        NavigationLink {
          InboxView(store: store)
        } label: {
          Label("Open Inbox", systemImage: "tray.full.fill")
        }
        NavigationLink {
          AcceptanceReviewView(store: store)
        } label: {
          Label("Open Acceptance", systemImage: "checkmark.rectangle.stack.fill")
        }
        NavigationLink {
          AuditView(store: store)
        } label: {
          Label("Open Audit", systemImage: "list.clipboard.fill")
        }
      }
      .buttonStyle(.bordered)
    }
  }

  private var filters: some View {
    FilterControlGrid {
      TextField("Search source, summary, order, tracking, destination, notes, or linked order", text: $importSearchText)
        .textFieldStyle(.roundedBorder)
      Picker("Source", selection: $sourceFilter) {
        Text("All sources").tag(ImportSourceType?.none)
        ForEach(ImportSourceType.allCases) { source in
          Label(source.rawValue, systemImage: source.symbol).tag(Optional(source))
        }
      }
      Picker("Status", selection: $statusFilter) {
        Text("All statuses").tag(ImportStatus?.none)
        ForEach(ImportStatus.allCases) { status in
          Text(status.rawValue).tag(Optional(status))
        }
      }
      Picker("Confidence", selection: $confidenceFilter) {
        ForEach(ImportConfidenceRange.allCases) { range in
          Text(range.rawValue).tag(range)
        }
      }
      Picker("Review", selection: $reviewFilter) {
        Text("All review").tag(ReviewState?.none)
        ForEach(reviewStates, id: \.self) { state in
          Text(state.rawValue).tag(Optional(state))
        }
      }
      if hasActiveFilters {
        Button("Clear filters", systemImage: "xmark.circle") {
          clearFilters()
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private func clearFilters() {
    sourceFilter = nil
    statusFilter = nil
    confidenceFilter = .all
    reviewFilter = nil
    importSearchText = ""
  }

  private func importQueueItem(_ item: ImportQueueItem, matches query: String) -> Bool {
    let linkedOrder = item.suggestedLinkedOrderID.flatMap { orderID in
      store.orders.first { $0.id == orderID }
    }
    let linkedShipmentGroup = item.suggestedShipmentGroupID.flatMap { groupID in
      store.shipmentGroups.first { $0.id == groupID }
    }
    let searchableText = [
      item.sourceType.rawValue,
      item.sourceLabel,
      item.capturedDate,
      item.rawSummary,
      item.detectedMerchant,
      item.detectedOrderNumber,
      item.detectedTrackingNumber,
      item.detectedDestinationAddress,
      item.importStatus.rawValue,
      item.reviewState.rawValue,
      item.notes,
      item.suggestedLinkedOrderID?.uuidString ?? "",
      item.suggestedShipmentGroupID?.uuidString ?? "",
      linkedOrder?.orderNumber ?? "",
      linkedOrder?.store ?? "",
      linkedOrder?.customer ?? "",
      linkedOrder?.recipientEmail ?? "",
      linkedOrder?.trackingNumber ?? "",
      linkedOrder?.carrier ?? "",
      linkedOrder?.destination ?? "",
      linkedShipmentGroup?.groupName ?? "",
      linkedShipmentGroup?.destinationSummary ?? "",
      linkedShipmentGroup?.recipientCustomerSummary ?? "",
      linkedShipmentGroup?.carrierSummary ?? "",
      linkedShipmentGroup?.statusSummary ?? ""
    ].joined(separator: " ")
    return searchableText.localizedLowercase.contains(query)
  }
}

struct ImportQueueItemRow: View {
  var item: ImportQueueItem
  var store: ParcelOpsStore
  var orders: [TrackedOrder] = []
  var shipmentGroups: [ShipmentGroup] = []
  var playbooks: [ExceptionPlaybook] = []
  var handoffNotes: [HandoffNote] = []
  var customerProfiles: [CustomerRecipientProfile] = []
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var onSave: (ImportQueueItem) -> Void = { _ in }
  var onLinkOrder: (TrackedOrder) -> Void = { _ in }
  var onLinkShipmentGroup: (ShipmentGroup) -> Void = { _ in }
  var onCreateOrder: () -> Void = {}
  var onCreateShipmentGroup: () -> Void = {}
  var onAccepted: () -> Void = {}
  var onIgnored: () -> Void = {}
  var onReopen: () -> Void = {}
  var onRemove: () -> Void = {}
  var onCreateTask: () -> Void = {}
  var onCreateDraft: () -> Void = {}
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var draft: ImportQueueItem
  @State private var isEditing = false

  private var factColumns: [GridItem] {
    Array(repeating: GridItem(.flexible()), count: horizontalSizeClass == .compact ? 1 : 2)
  }

  private var linkedOrder: TrackedOrder? {
    item.suggestedLinkedOrderID.flatMap { orderID in
      orders.first { $0.id == orderID }
    }
  }

  init(
    item: ImportQueueItem,
    store: ParcelOpsStore,
    orders: [TrackedOrder] = [],
    shipmentGroups: [ShipmentGroup] = [],
    playbooks: [ExceptionPlaybook] = [],
    handoffNotes: [HandoffNote] = [],
    customerProfiles: [CustomerRecipientProfile] = [],
    destinationAddresses: [DestinationAddressRecord] = [],
    deliveryInstructions: [DeliveryInstructionRecord] = [],
    packageContents: [PackageContentRecord] = [],
    onSave: @escaping (ImportQueueItem) -> Void = { _ in },
    onLinkOrder: @escaping (TrackedOrder) -> Void = { _ in },
    onLinkShipmentGroup: @escaping (ShipmentGroup) -> Void = { _ in },
    onCreateOrder: @escaping () -> Void = {},
    onCreateShipmentGroup: @escaping () -> Void = {},
    onAccepted: @escaping () -> Void = {},
    onIgnored: @escaping () -> Void = {},
    onReopen: @escaping () -> Void = {},
    onRemove: @escaping () -> Void = {},
    onCreateTask: @escaping () -> Void = {},
    onCreateDraft: @escaping () -> Void = {}
  ) {
    self.item = item
    self.store = store
    self.orders = orders
    self.shipmentGroups = shipmentGroups
    self.playbooks = playbooks
    self.handoffNotes = handoffNotes
    self.customerProfiles = customerProfiles
    self.destinationAddresses = destinationAddresses
    self.deliveryInstructions = deliveryInstructions
    self.packageContents = packageContents
    self.onSave = onSave
    self.onLinkOrder = onLinkOrder
    self.onLinkShipmentGroup = onLinkShipmentGroup
    self.onCreateOrder = onCreateOrder
    self.onCreateShipmentGroup = onCreateShipmentGroup
    self.onAccepted = onAccepted
    self.onIgnored = onIgnored
    self.onReopen = onReopen
    self.onRemove = onRemove
    self.onCreateTask = onCreateTask
    self.onCreateDraft = onCreateDraft
    _draft = State(initialValue: item)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: item.sourceType.symbol)
          .foregroundStyle(item.importStatus.color)
          .frame(width: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(item.sourceLabel)
            .font(.headline)
          Text("\(item.sourceType.rawValue) • \(item.capturedDate)")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(item.rawSummary)
            .foregroundStyle(.secondary)
            .lineLimit(3)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 6) {
          Badge("\(item.confidenceScore)%", color: item.confidenceScore >= 75 ? .green : .orange)
          Badge(item.importStatus.rawValue, color: item.importStatus.color)
          Badge(item.reviewState.rawValue, color: item.reviewState.color)
        }
      }

      LazyVGrid(columns: factColumns, alignment: .leading, spacing: 8) {
        ImportFact(title: "Merchant", value: item.detectedMerchant, symbol: "storefront.fill")
        ImportFact(title: "Order", value: item.detectedOrderNumber, symbol: "number")
        ImportFact(title: "Tracking", value: item.detectedTrackingNumber, symbol: "barcode.viewfinder")
        ImportFact(title: "Destination", value: item.detectedDestinationAddress, symbol: "mappin.and.ellipse")
      }

      if !item.notes.isEmpty {
        Text(item.notes)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      LinkedOrderContextPanel(
        order: linkedOrder,
        sourceLabel: "Import queue",
        emptyDetail: "No order is linked yet. Link to an existing order when this staged import matches known work, or create a new local order when it is genuinely new.",
        linkedDetail: "This staged import already has linked order context. Open the order before accepting if tracking, destination, or review status needs confirmation.",
        store: store
      )

      if isEditing {
        ImportQueueEditForm(item: $draft)
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
        Button(isEditing ? "Save" : "Edit", systemImage: isEditing ? "checkmark" : "pencil") {
          if isEditing {
            onSave(draft)
          } else {
            draft = item
          }
          isEditing.toggle()
        }
        .buttonStyle(.bordered)

        Menu("Link order", systemImage: "link") {
          ForEach(orders) { order in
            Button("\(order.orderNumber) • \(order.store)") {
              onLinkOrder(order)
            }
          }
        }
        Menu("Link group", systemImage: "shippingbox.and.arrow.backward.fill") {
          ForEach(shipmentGroups) { group in
            Button(group.groupName) {
              onLinkShipmentGroup(group)
            }
          }
        }
        Button("Order", systemImage: "shippingbox.fill", action: onCreateOrder)
          .buttonStyle(.bordered)
        if let linkedOrder {
          NavigationLink {
            OrderDetailView(order: linkedOrder, store: store)
          } label: {
            Label("Open order", systemImage: "arrow.up.right.square.fill")
          }
          .buttonStyle(.borderedProminent)
        }
        Button("Group", systemImage: "shippingbox.and.arrow.backward.fill", action: onCreateShipmentGroup)
          .buttonStyle(.bordered)
      }

      CompactActionRow {
        Button("Accept", systemImage: "checkmark.seal.fill", action: onAccepted)
          .buttonStyle(.borderedProminent)
        Button("Ignore", systemImage: "eye.slash.fill", action: onIgnored)
          .buttonStyle(.bordered)
        Button("Reopen", systemImage: "arrow.uturn.backward.circle.fill", action: onReopen)
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
}

struct ImportQueueContextStrip: View {
  var items: [ImportQueueItem]

  var body: some View {
    HStack(spacing: 8) {
      Label("Import queue", systemImage: "tray.and.arrow.down.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      ForEach(items.prefix(3)) { item in
        Badge(item.sourceLabel, color: item.importStatus.color)
      }
    }
  }
}

private struct ImportFact: View {
  var title: String
  var value: String
  var symbol: String

  var body: some View {
    Label {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption2)
          .foregroundStyle(.secondary)
        Text(value)
          .font(.caption.weight(.semibold))
          .lineLimit(1)
      }
    } icon: {
      Image(systemName: symbol)
        .foregroundStyle(.secondary)
    }
    .padding(8)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct ImportQueueEditForm: View {
  @Binding var item: ImportQueueItem

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      TextField("Source label", text: $item.sourceLabel)
      TextField("Raw summary", text: $item.rawSummary)
      TextField("Detected merchant", text: $item.detectedMerchant)
      TextField("Detected order number", text: $item.detectedOrderNumber)
      TextField("Detected tracking number", text: $item.detectedTrackingNumber)
      TextField("Detected destination", text: $item.detectedDestinationAddress)
      TextField("Notes", text: $item.notes)
      HStack {
        Picker("Source", selection: $item.sourceType) {
          ForEach(ImportSourceType.allCases) { source in
            Text(source.rawValue).tag(source)
          }
        }
        Picker("Status", selection: $item.importStatus) {
          ForEach(ImportStatus.allCases) { status in
            Text(status.rawValue).tag(status)
          }
        }
        Stepper("Confidence \(item.confidenceScore)%", value: $item.confidenceScore, in: 0...100, step: 5)
      }
    }
    .textFieldStyle(.roundedBorder)
    .pickerStyle(.menu)
    .padding(10)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
