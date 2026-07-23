import SwiftUI

struct ImportQueueView: View {
  var store: ParcelOpsStore
  @State private var sourceFilter: ImportSourceType?
  @State private var statusFilter: ImportStatus?
  @State private var confidenceFilter: ImportConfidenceRange = .all
  @State private var reviewFilter: ReviewState?
  @State private var importSearchText = ""
  @State private var showAllImportItems = false
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

  private var displayedItems: [ImportQueueItem] {
    showAllImportItems ? filteredItems : Array(filteredItems.prefix(48))
  }

  private var hiddenDisplayedItemCount: Int {
    max(filteredItems.count - displayedItems.count, 0)
  }

  private var importItemsNeedingReview: [ImportQueueItem] {
    store.importQueueItems.filter { item in
      item.reviewState == .needsReview
        || item.importStatus == .blocked
        || item.detectedMerchant.isPlaceholderValidationValue
        || item.detectedOrderNumber.isPlaceholderValidationValue
        || item.detectedTrackingNumber.isPlaceholderValidationValue
        || item.detectedDestinationAddress.isPlaceholderValidationValue
    }
  }

  private var importItemsWithSourceTrail: [ImportQueueItem] {
    store.importQueueItems.filter { item in
      item.sourceType == .forwardedEmail || item.suggestedLinkedOrderID != nil || item.suggestedShipmentGroupID != nil
    }
  }
  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.latestSpaceMailIntakeHealthSummary
  }
  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.latestGmailIntakeHealthSummary
  }

  private var latestMicrosoft365Summary: Microsoft365IntakeHealthSummary? {
    store.latestMicrosoft365IntakeHealthSummary
  }

  private var importMailboxProviderRows: [(provider: String, status: String, detail: String, symbol: String, color: Color)] {
    var rows: [(provider: String, status: String, detail: String, symbol: String, color: Color)] = []

    if let summary = latestSpaceMailSummary {
      rows.append(spaceMailImportRow(summary))
    }

    if let summary = latestGmailSummary {
      rows.append(gmailImportRow(summary))
    }

    if let summary = latestMicrosoft365Summary {
      rows.append(microsoft365ImportRow(summary))
    }

    if rows.isEmpty {
      rows.append(("Mailbox", "No provider refresh", "Run an active mailbox provider refresh first, then promote confirmed intake into Import Queue only when staging is useful.", "envelope.badge.fill", .secondary))
    }
    return rows
  }

  private func spaceMailImportRow(_ summary: SpaceMailIntakeHealthSummary) -> (provider: String, status: String, detail: String, symbol: String, color: Color) {
    if summary.importedCount > 0 {
      return ("SpaceMail", summary.primaryOutcomeStatus, "Imported SpaceMail rows should be checked in Inbox before they become staged imports or orders.", "server.rack", .green)
    }
    if summary.totalUncertainCount > 0 {
      return ("SpaceMail", summary.primaryOutcomeStatus, "Uncertain SpaceMail previews remain in Mailbox Monitor until imported or dismissed.", "server.rack", .orange)
    }
    if summary.filteredCount > 0 {
      return ("SpaceMail", summary.primaryOutcomeStatus, "Filtered non-order SpaceMail messages should not appear in Import Queue.", "server.rack", .teal)
    }
    if summary.duplicateRefreshedCount > 0 {
      return ("SpaceMail", summary.primaryOutcomeStatus, "Duplicate SpaceMail messages updated existing Inbox rows. Stage an import only after those refreshed rows are promoted intentionally.", "server.rack", .teal)
    }
    if summary.duplicateCount > 0 {
      return ("SpaceMail", summary.primaryOutcomeStatus, "Duplicate SpaceMail messages were already captured; staged imports only change if an existing intake row is promoted.", "server.rack", .teal)
    }
    return ("SpaceMail", summary.primaryOutcomeStatus, summary.nextAction, "server.rack", .secondary)
  }

  private func gmailImportRow(_ summary: GmailIntakeHealthSummary) -> (provider: String, status: String, detail: String, symbol: String, color: Color) {
    if summary.importedCount > 0 {
      return ("Gmail", summary.primaryOutcomeStatus, "Imported Gmail rows should be checked in Inbox before they become staged imports or orders.", "envelope.badge.shield.half.filled", .green)
    }
    if summary.totalUncertainCount > 0 {
      return ("Gmail", summary.primaryOutcomeStatus, "Uncertain Gmail previews remain in Mailbox Monitor until imported or dismissed.", "envelope.badge.shield.half.filled", .orange)
    }
    if summary.filteredCount > 0 {
      return ("Gmail", summary.primaryOutcomeStatus, "Filtered non-order Gmail messages should not appear in Import Queue.", "envelope.badge.shield.half.filled", .teal)
    }
    if summary.duplicateRefreshedCount > 0 {
      return ("Gmail", summary.primaryOutcomeStatus, "Duplicate Gmail messages updated existing Inbox rows. Stage an import only after those refreshed rows are promoted intentionally.", "envelope.badge.shield.half.filled", .teal)
    }
    if summary.duplicateCount > 0 {
      return ("Gmail", summary.primaryOutcomeStatus, "Duplicate Gmail messages were already captured; staged imports only change if an existing intake row is promoted.", "envelope.badge.shield.half.filled", .teal)
    }
    return ("Gmail", summary.primaryOutcomeStatus, summary.nextAction, "envelope.badge.shield.half.filled", .secondary)
  }

  private func microsoft365ImportRow(_ summary: Microsoft365IntakeHealthSummary) -> (provider: String, status: String, detail: String, symbol: String, color: Color) {
    if summary.blockedCount > 0 {
      return ("Outlook", summary.primaryOutcomeStatus, "Outlook/Microsoft Graph needs sign-in, consent, token, or Graph diagnostics review before anything should be staged in Import Queue.", "mail.stack.fill", .orange)
    }
    if summary.importedCount > 0 {
      return ("Outlook", summary.primaryOutcomeStatus, "Imported Outlook rows should be checked in Inbox before they become staged imports or orders.", "mail.stack.fill", .green)
    }
    if summary.duplicateRefreshedCount > 0 {
      return ("Outlook", summary.primaryOutcomeStatus, "Duplicate Outlook messages updated existing Inbox rows. Stage an import only after those refreshed rows are promoted intentionally.", "mail.stack.fill", .teal)
    }
    if summary.duplicateCount > 0 {
      return ("Outlook", summary.primaryOutcomeStatus, "Duplicate Outlook messages were already captured; staged imports only change if an existing intake row is promoted.", "mail.stack.fill", .teal)
    }
    return ("Outlook", summary.primaryOutcomeStatus, summary.nextAction, "mail.stack.fill", .secondary)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        MVPWorkflowGuide(
          title: "Import queue workflow",
          detail: "Use this screen when order information is staged manually or captured from a local intake source.",
          steps: [
            "Review confidence and detected merchant/order/tracking fields.",
            "Edit notes or detected values if the staged record is wrong.",
            "Link to an order or shipment group, or create new local records.",
            "Accept, ignore, or reopen the import item."
          ],
          symbol: "tray.and.arrow.down.fill"
        )
        importSourceReadinessPanel
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
            MVPEmptyState(title: "No staged imports match this view", detail: hasActiveFilters ? "Clear search or filters to return to the full import queue." : "Add a local import item to test the acceptance workflow.", symbol: "tray.and.arrow.down.fill", actionTitle: hasActiveFilters ? "Clear filters" : "Add import item", action: hasActiveFilters ? clearFilters : store.addImportQueueItemPlaceholder)
          } else {
            if hiddenDisplayedItemCount > 0 {
              CompactActionRow {
                Label("Showing first \(displayedItems.count) import items", systemImage: "speedometer")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.secondary)
                Badge("\(hiddenDisplayedItemCount) older hidden", color: .secondary)
                Button(showAllImportItems ? "Show first 48" : "Show all \(filteredItems.count)", systemImage: showAllImportItems ? "rectangle.compress.vertical" : "rectangle.expand.vertical") {
                  withAnimation(.snappy) {
                    showAllImportItems.toggle()
                  }
                }
                .buttonStyle(.bordered)
              }
              Text("Search and filters still scan every staged import. Rendering stays capped until you choose Show all, so Import Queue opens quickly with accumulated test data.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(displayedItems) { item in
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

  private var importSourceReadinessPanel: some View {
    let linkedCount = store.importQueueItems.filter { $0.suggestedLinkedOrderID != nil }.count
    let acceptedCount = store.importQueueItems.filter { $0.importStatus == .accepted }.count
    let blockedCount = store.importQueueItems.filter { $0.importStatus == .blocked }.count
    let forwardedCount = store.importQueueItems.filter { $0.sourceType == .forwardedEmail }.count

    return SettingsPanel(title: "Inbox import readiness", symbol: "link.badge.plus") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this checkpoint before accepting staged records. Import Queue should preserve where the record came from, what still needs review, and whether an order handoff already exists.")
          .font(.callout)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 135) {
          Badge("\(store.importQueueItems.count) staged", color: store.importQueueItems.isEmpty ? .secondary : .blue)
          Badge("\(forwardedCount) from Inbox", color: forwardedCount == 0 ? .secondary : .teal)
          Badge("\(importItemsWithSourceTrail.count) source trail", color: importItemsWithSourceTrail.isEmpty ? .orange : .green)
          Badge("\(linkedCount) linked orders", color: linkedCount == 0 ? .orange : .green)
          Badge("\(acceptedCount) accepted", color: acceptedCount == 0 ? .secondary : .green)
          Badge("\(blockedCount) blocked", color: blockedCount == 0 ? .green : .orange)
          Badge("\(importItemsNeedingReview.count) needs check", color: importItemsNeedingReview.isEmpty ? .green : .orange)
        }

        VStack(alignment: .leading, spacing: 8) {
          Label("Mailbox provider source", systemImage: "point.3.connected.trianglepath.dotted")
            .font(.subheadline.weight(.semibold))
          Text("Import Queue should only contain staged records that need an extra acceptance step. Provider rows explain which mailbox path produced, filtered, or skipped intake before staging.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          ForEach(importMailboxProviderRows, id: \.provider) { row in
            HStack(alignment: .top, spacing: 10) {
              Image(systemName: row.symbol)
                .foregroundStyle(row.color)
                .frame(width: 22)
              VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                  Text(row.provider)
                    .font(.caption.weight(.semibold))
                  Badge(row.status, color: row.color)
                }
                Text(row.detail)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
              Spacer(minLength: 0)
            }
          }
        }
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))

        CollapsedProviderEvidencePanel(
          title: "Mailbox staging evidence",
          detail: "Provider setup, source counts, and local-only boundaries for mailbox providers import staging.",
          symbol: "tray.full.fill"
        ) {
          GmailReleaseBoundaryPanel(
            store: store,
            title: "Gmail staging readiness",
            lead: "Gmail release checks are provider-readiness work. Import Queue should only receive Gmail work after a real or mock Gmail row is imported into Inbox and intentionally staged.",
            sourceMetricTitle: "Gmail fetched",
            sourceCount: latestGmailSummary?.fetchedCount ?? 0,
            boundaryDetail: "Local-only boundary: this panel does not open Google sign-in, fetch Gmail, store token values, stage imports automatically, or mutate mailbox messages."
          )

          Microsoft365ReleaseBoundaryPanel(
            store: store,
            title: "Outlook staging readiness",
            lead: "Outlook release checks are provider-readiness work. Import Queue should only receive Outlook work after Graph/manual intake creates an Inbox row and an operator intentionally stages it.",
            sourceMetricTitle: "Outlook fetched",
            sourceCount: latestMicrosoft365Summary?.fetchedCount ?? 0,
            boundaryDetail: "Local-only boundary: this panel does not open Microsoft sign-in, request tokens, fetch Outlook messages, stage imports automatically, or mutate mailbox messages."
          )
        }

        if !store.gmailMailboxConnections.isEmpty {
          MailboxProviderPostRefreshDisclosure(
            title: "Gmail staging follow-up",
            detail: "Open this when Gmail refresh results affect staging. Import rows remain the primary work here.",
            symbol: "envelope.badge.shield.half.filled",
            tone: .pink,
            statusLabel: "Gmail"
          ) {
            GmailPostRefreshActionCard(plan: store.gmailPostRefreshActionPlan)
          }
        }

        if store.importQueueItems.isEmpty {
          MVPEmptyState(
            title: "No staged imports yet",
            detail: "Use Inbox or Mailbox Monitor to capture intake, or add a local import item for manual testing.",
            symbol: "tray.and.arrow.down.fill"
          )
        } else if importItemsNeedingReview.isEmpty {
          Label("Current staged imports have usable source, link, and review context.", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
        } else {
          VStack(alignment: .leading, spacing: 8) {
            Text("Next import checks")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            ForEach(importItemsNeedingReview.prefix(4)) { item in
              ImportReadinessRow(item: item, detail: importReadinessDetail(for: item))
            }
            if importItemsNeedingReview.count > 4 {
              Text("\(importItemsNeedingReview.count - 4) more staged imports need field, link, status, or review checks.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
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

  private func importReadinessDetail(for item: ImportQueueItem) -> String {
    if item.importStatus == .blocked { return "Blocked. Resolve the staged record before accepting it into Orders or Dispatch." }
    if item.suggestedLinkedOrderID == nil && item.importStatus != .accepted { return "No linked order yet. Link an existing order or create one after checking the detected fields." }
    if item.detectedOrderNumber.isPlaceholderValidationValue { return "Order number needs review before creating or linking an order." }
    if item.detectedTrackingNumber.isPlaceholderValidationValue { return "Tracking number needs review before downstream dispatch setup." }
    if item.detectedDestinationAddress.isPlaceholderValidationValue { return "Destination needs review before accepting the import." }
    if item.reviewState == .needsReview { return "Review state is still open. Mark reviewed after source and linked order context are confirmed." }
    return "Confirm the source trail and linked context before closing this staged import."
  }
}

private struct ImportReadinessRow: View {
  var item: ImportQueueItem
  var detail: String

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: item.sourceType.symbol)
        .foregroundStyle(item.importStatus.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(item.sourceLabel)
          .font(.caption.weight(.semibold))
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 8)
      Badge(item.importStatus.rawValue, color: item.importStatus.color)
    }
    .padding(8)
    .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
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
  @State private var feedbackMessage: String?

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
            feedbackMessage = "Import item saved locally."
          } else {
            draft = item
          }
          isEditing.toggle()
        }
        .buttonStyle(.bordered)

        Menu("Link order", systemImage: "link") {
          ForEach(Array(orders.prefix(40))) { order in
            Button("\(order.orderNumber) • \(order.store)") {
              onLinkOrder(order)
              feedbackMessage = "Import linked to \(order.orderNumber). Check Orders."
            }
          }
          if orders.count > 40 {
            Text("\(orders.count - 40) more orders available in Orders")
          }
        }
        Menu("Link group", systemImage: "shippingbox.and.arrow.backward.fill") {
          ForEach(Array(shipmentGroups.prefix(40))) { group in
            Button(group.groupName) {
              onLinkShipmentGroup(group)
              feedbackMessage = "Import linked to shipment group. Check linked context."
            }
          }
          if shipmentGroups.count > 40 {
            Text("\(shipmentGroups.count - 40) more groups available in Shipment Groups")
          }
        }
        Button("Order", systemImage: "shippingbox.fill") {
          onCreateOrder()
          feedbackMessage = "Order created from staged import. Check Orders."
        }
          .buttonStyle(.bordered)
        if let linkedOrder {
          NavigationLink {
            OrderDetailView(order: linkedOrder, store: store)
          } label: {
            Label("Open order", systemImage: "arrow.up.right.square.fill")
          }
          .buttonStyle(.borderedProminent)
        }
        Button("Group", systemImage: "shippingbox.and.arrow.backward.fill") {
          onCreateShipmentGroup()
          feedbackMessage = "Shipment group created from staged import."
        }
          .buttonStyle(.bordered)
      }

      CompactActionRow {
        Button("Accept", systemImage: "checkmark.seal.fill") {
          onAccepted()
          feedbackMessage = "Import accepted locally. Check Acceptance."
        }
          .buttonStyle(.borderedProminent)
        Button("Ignore", systemImage: "eye.slash.fill") {
          onIgnored()
          feedbackMessage = "Import ignored locally."
        }
          .buttonStyle(.bordered)
        Button("Reopen", systemImage: "arrow.uturn.backward.circle.fill") {
          onReopen()
          feedbackMessage = "Import reopened for review."
        }
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Follow-up task created. Check Tasks."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "square.and.pencil") {
          onCreateDraft()
          feedbackMessage = "Draft message created locally."
        }
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
          .buttonStyle(.bordered)
      }

      if let feedbackMessage {
        ImportQueueFeedbackPanel(message: feedbackMessage, store: store)
      }
    }
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

private struct ImportQueueFeedbackPanel: View {
  var message: String
  var store: ParcelOpsStore

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(message, systemImage: "checkmark.circle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.green)

      CompactActionRow {
        if message.localizedCaseInsensitiveContains("order") {
          NavigationLink {
            OrdersView(store: store)
          } label: {
            Label("Open Orders", systemImage: "shippingbox.fill")
          }
        }
        if message.localizedCaseInsensitiveContains("task") {
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
        }
        if message.localizedCaseInsensitiveContains("accept") {
          NavigationLink {
            AcceptanceReviewView(store: store)
          } label: {
            Label("Open Acceptance", systemImage: "checkmark.rectangle.stack.fill")
          }
        }
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.green.opacity(0.12))
    .clipShape(RoundedRectangle(cornerRadius: 8))
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
      if items.count > 3 {
        Badge("+\(items.count - 3) more", color: .secondary)
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
