import SwiftUI

struct AcceptanceReviewView: View {
  var store: ParcelOpsStore
  @State private var selectedSourceType: AcceptanceSourceType?
  @State private var selectedDecision: AcceptanceDecision?
  @State private var selectedConfidenceRange: ImportConfidenceRange = .all
  @State private var selectedReviewState: ReviewState?
  @State private var grouping: AcceptanceGrouping = .confidence
  @State private var acceptanceSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var baseFilteredCandidates: [AcceptanceCandidate] {
    store.filteredAcceptanceCandidates(
      sourceType: selectedSourceType,
      decision: selectedDecision,
      confidenceRange: selectedConfidenceRange,
      reviewState: selectedReviewState
    )
  }

  private var filteredCandidates: [AcceptanceCandidate] {
    let query = acceptanceSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredCandidates }
    return baseFilteredCandidates.filter { candidate in
      acceptanceCandidate(candidate, matches: query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedSourceType != nil
      || selectedDecision != nil
      || selectedConfidenceRange != .all
      || selectedReviewState != nil
      || !acceptanceSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var candidatesNeedingDecision: [AcceptanceCandidate] {
    store.acceptanceCandidates.filter { candidate in
      candidate.reviewState == .needsReview
        || candidate.decision == .blocked
        || candidate.decision == .reopened
        || candidate.suggestedLinkedOrderID == nil
        || candidate.detectedMerchant.isPlaceholderValidationValue
        || candidate.detectedOrderNumber.isPlaceholderValidationValue
        || candidate.detectedTrackingNumber.isPlaceholderValidationValue
        || candidate.detectedDestinationAddress.isPlaceholderValidationValue
    }
  }
  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.spaceMailIntakeHealthSummaries.first
  }
  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.gmailIntakeHealthSummaries.first
  }
  private var acceptanceMailboxProviderRows: [(provider: String, status: String, detail: String, symbol: String, color: Color)] {
    var rows: [(provider: String, status: String, detail: String, symbol: String, color: Color)] = []

    if let summary = latestSpaceMailSummary {
      let uncertain = summary.pendingUncertainReviewCount + summary.uncertainCount
      if summary.importedCount > 0 {
        rows.append(("SpaceMail", "\(summary.importedCount) imported", "Imported SpaceMail rows should be accepted only after order/tracking fields and linked order decisions are clear.", "server.rack", .green))
      } else if uncertain > 0 {
        rows.append(("SpaceMail", "\(uncertain) uncertain", "Uncertain SpaceMail previews are not acceptance candidates until imported from Mailbox Monitor.", "server.rack", .orange))
      } else if summary.filteredCount > 0 {
        rows.append(("SpaceMail", "\(summary.filteredCount) filtered", "Filtered non-order SpaceMail messages should not reach Acceptance Review.", "server.rack", .teal))
      } else if summary.duplicateCount > 0 {
        rows.append(("SpaceMail", "\(summary.duplicateCount) duplicate", "Duplicate SpaceMail messages should not create new acceptance candidates.", "server.rack", .teal))
      } else {
        rows.append(("SpaceMail", "\(summary.fetchedCount) fetched", summary.nextAction, "server.rack", .secondary))
      }
    }

    if let summary = latestGmailSummary {
      let uncertain = summary.pendingUncertainReviewCount + summary.uncertainCount
      if summary.importedCount > 0 {
        rows.append(("Gmail", "\(summary.importedCount) imported", "Imported Gmail rows should be accepted only after order/tracking fields and linked order decisions are clear.", "envelope.badge.shield.half.filled", .green))
      } else if uncertain > 0 {
        rows.append(("Gmail", "\(uncertain) uncertain", "Uncertain Gmail previews are not acceptance candidates until imported from Mailbox Monitor.", "envelope.badge.shield.half.filled", .orange))
      } else if summary.filteredCount > 0 {
        rows.append(("Gmail", "\(summary.filteredCount) filtered", "Filtered non-order Gmail messages should not reach Acceptance Review.", "envelope.badge.shield.half.filled", .teal))
      } else if summary.duplicateCount > 0 {
        rows.append(("Gmail", "\(summary.duplicateCount) duplicate", "Duplicate Gmail messages should not create new acceptance candidates.", "envelope.badge.shield.half.filled", .teal))
      } else {
        rows.append(("Gmail", "\(summary.fetchedCount) fetched", summary.nextAction, "envelope.badge.shield.half.filled", .secondary))
      }
    }

    if rows.isEmpty {
      rows.append(("Mailbox", "No provider refresh", "Run SpaceMail or Gmail refresh, then review imported Inbox rows before they become acceptance candidates.", "envelope.badge.fill", .secondary))
    }
    return rows
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        header
        MVPWorkflowGuide(
          title: "Acceptance decision",
          detail: "This is the handoff between captured intake and operational records.",
          steps: [
            "Compare detected merchant, order, tracking, and destination values.",
            "Choose an existing order/group when the record is already represented.",
            "Create a new order/group only when it is genuinely new.",
            "Accept when linked context is clear, or ignore/reopen when it is not."
          ],
          symbol: "checkmark.rectangle.stack.fill"
        )
        acceptanceReadinessPanel
        filters

        if filteredCandidates.isEmpty {
          SettingsPanel(title: "Acceptance candidates", symbol: "checkmark.rectangle.stack.fill") {
            MVPEmptyState(
              title: "No acceptance candidates match this view",
              detail: hasActiveFilters ? "Clear search or filters to return to all acceptance candidates." : "Review Mailbox Monitor and Import Queue to create local intake candidates.",
              symbol: "checkmark.rectangle.stack.fill",
              actionTitle: hasActiveFilters ? "Clear filters" : nil,
              action: hasActiveFilters ? clearFilters : nil
            )
          }
        } else {
          ForEach(store.groupedAcceptanceCandidates(filteredCandidates, by: grouping), id: \.title) { group in
            SettingsPanel(title: "\(group.title) (\(group.candidates.count))", symbol: grouping.symbol) {
              VStack(spacing: 12) {
                ForEach(group.candidates) { candidate in
                  AcceptanceCandidateRow(
                    candidate: candidate,
                    store: store,
                    orders: store.orders,
                    shipmentGroups: store.shipmentGroups,
                    linkedOrderLabel: candidate.suggestedLinkedOrderID.flatMap { store.orderLabel(for: $0) },
                    linkedShipmentGroupLabel: candidate.suggestedShipmentGroupID.flatMap { store.shipmentGroupLabel(for: $0) },
                    history: store.acceptanceHistory(sourceType: candidate.sourceType, sourceID: candidate.sourceID),
                    playbooks: store.suggestedPlaybooks(for: candidate),
                    handoffNotes: store.handoffNotes(for: candidate),
                    customerProfiles: store.suggestedCustomerProfiles(for: candidate),
                    destinationAddresses: store.suggestedDestinationAddresses(for: candidate),
                    deliveryInstructions: store.suggestedDeliveryInstructions(for: candidate),
                    packageContents: store.suggestedPackageContents(for: candidate),
                    onLinkOrder: { order in store.linkAcceptanceCandidate(candidate, to: order) },
                    onLinkShipmentGroup: { group in store.linkAcceptanceCandidate(candidate, to: group) },
                    onCreateOrder: { store.createOrder(from: candidate) },
                    onCreateShipmentGroup: { store.createShipmentGroup(from: candidate) },
                    onAccept: { store.acceptCandidate(candidate) },
                    onIgnore: { store.ignoreCandidate(candidate) },
                    onReopen: { store.reopenCandidate(candidate) },
                    onTask: { store.createReviewTask(from: candidate) },
                    onDraft: { store.createDraftMessage(from: candidate) }
                  )
                }
              }
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private var acceptanceReadinessPanel: some View {
    let inboxCandidates = store.acceptanceCandidates.filter { $0.sourceType == .intakeEmail }.count
    let importCandidates = store.acceptanceCandidates.filter { $0.sourceType == .importQueueItem }.count
    let linkedCount = store.acceptanceCandidates.filter { $0.suggestedLinkedOrderID != nil }.count
    let acceptedCount = store.acceptanceCandidates.filter { $0.decision == .accepted }.count
    let blockedCount = store.acceptanceCandidates.filter { $0.decision == .blocked }.count

    return SettingsPanel(title: "Inbox acceptance readiness", symbol: "checkmark.rectangle.stack.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this checkpoint before accepting local intake into operational records. A candidate is ready when source context, order/tracking fields, and linked order decisions are clear.")
          .font(.callout)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 135) {
          Badge("\(store.acceptanceCandidates.count) candidates", color: store.acceptanceCandidates.isEmpty ? .secondary : .blue)
          Badge("\(inboxCandidates) from Inbox", color: inboxCandidates == 0 ? .secondary : .teal)
          Badge("\(importCandidates) from Import", color: importCandidates == 0 ? .secondary : .purple)
          Badge("\(linkedCount) linked orders", color: linkedCount == 0 ? .orange : .green)
          Badge("\(acceptedCount) accepted", color: acceptedCount == 0 ? .secondary : .green)
          Badge("\(blockedCount) blocked", color: blockedCount == 0 ? .green : .orange)
        }

        VStack(alignment: .leading, spacing: 8) {
          Label("Mailbox provider acceptance context", systemImage: "point.3.connected.trianglepath.dotted")
            .font(.subheadline.weight(.semibold))
          Text("Acceptance Review should only close records after source, detected fields, and linked order decisions are clear. Provider rows explain what the latest SpaceMail or Gmail refresh contributed before acceptance.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          ForEach(acceptanceMailboxProviderRows, id: \.provider) { row in
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

        if store.acceptanceCandidates.isEmpty {
          MVPEmptyState(
            title: "No acceptance candidates yet",
            detail: "Review Inbox and Import Queue first. Accepted candidates should stay traceable back to local intake or staged import records.",
            symbol: "checkmark.rectangle.stack.fill"
          )
        } else if candidatesNeedingDecision.isEmpty {
          Label("Acceptance candidates have usable source, link, and decision context.", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
        } else {
          VStack(alignment: .leading, spacing: 8) {
            Text("Next acceptance checks")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            ForEach(candidatesNeedingDecision.prefix(4)) { candidate in
              AcceptanceReadinessRow(candidate: candidate, detail: acceptanceReadinessDetail(for: candidate))
            }
            if candidatesNeedingDecision.count > 4 {
              Text("\(candidatesNeedingDecision.count - 4) more candidates need field, link, decision, or review checks.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Acceptance Review")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Compare staged imports and forwarded emails before accepting them into orders and shipment groups.")
            .foregroundStyle(.secondary)
        }
        Spacer()
        Badge("\(store.acceptanceRecordsNeedingReview.count)", color: .orange)
      }

      CompactActionRow {
        NavigationLink {
          InboxView(store: store)
        } label: {
          Label("Open Inbox", systemImage: "tray.full.fill")
        }
        NavigationLink {
          ImportQueueView(store: store)
        } label: {
          Label("Open Imports", systemImage: "tray.and.arrow.down.fill")
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
      TextField("Search source, summary, order, tracking, destination, notes, or linked order", text: $acceptanceSearchText)
        .textFieldStyle(.roundedBorder)
      Picker("Source", selection: $selectedSourceType) {
        Text("All sources").tag(nil as AcceptanceSourceType?)
        ForEach(AcceptanceSourceType.allCases) { sourceType in
          Text(sourceType.rawValue).tag(sourceType as AcceptanceSourceType?)
        }
      }

      Picker("Decision", selection: $selectedDecision) {
        Text("All decisions").tag(nil as AcceptanceDecision?)
        ForEach(AcceptanceDecision.allCases) { decision in
          Text(decision.rawValue).tag(decision as AcceptanceDecision?)
        }
      }

      Picker("Confidence", selection: $selectedConfidenceRange) {
        ForEach(ImportConfidenceRange.allCases) { range in
          Text(range.rawValue).tag(range)
        }
      }

      Picker("Review", selection: $selectedReviewState) {
        Text("All review").tag(nil as ReviewState?)
        ForEach(reviewStates, id: \.self) { state in
          Text(state.rawValue).tag(state as ReviewState?)
        }
      }

      Picker("Group", selection: $grouping) {
        ForEach(AcceptanceGrouping.allCases) { group in
          Text(group.rawValue).tag(group)
        }
      }
      Badge("\(filteredCandidates.count) shown", color: filteredCandidates.isEmpty ? .orange : .blue)
      if hasActiveFilters {
        Button("Clear filters", systemImage: "xmark.circle") {
          clearFilters()
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private func clearFilters() {
    selectedSourceType = nil
    selectedDecision = nil
    selectedConfidenceRange = .all
    selectedReviewState = nil
    acceptanceSearchText = ""
  }

  private func acceptanceCandidate(_ candidate: AcceptanceCandidate, matches query: String) -> Bool {
    let linkedOrder = candidate.suggestedLinkedOrderID.flatMap { orderID in
      store.orders.first { $0.id == orderID }
    }
    let linkedShipmentGroup = candidate.suggestedShipmentGroupID.flatMap { groupID in
      store.shipmentGroups.first { $0.id == groupID }
    }
    let history = store.acceptanceHistory(sourceType: candidate.sourceType, sourceID: candidate.sourceID)
    let searchableText = [
      candidate.sourceType.rawValue,
      candidate.sourceLabel,
      candidate.capturedDate,
      candidate.rawSummary,
      candidate.detectedMerchant,
      candidate.detectedOrderNumber,
      candidate.detectedTrackingNumber,
      candidate.detectedDestinationAddress,
      candidate.decision.rawValue,
      candidate.reviewState.rawValue,
      candidate.notes,
      candidate.sourceID.uuidString,
      candidate.suggestedLinkedOrderID?.uuidString ?? "",
      candidate.suggestedShipmentGroupID?.uuidString ?? "",
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
      linkedShipmentGroup?.statusSummary ?? "",
      history.map { "\($0.decision.rawValue) \($0.reviewState.rawValue) \($0.summary) \($0.notes)" }.joined(separator: " ")
    ].joined(separator: " ")
    return searchableText.localizedLowercase.contains(query)
  }

  private func acceptanceReadinessDetail(for candidate: AcceptanceCandidate) -> String {
    if candidate.decision == .blocked { return "Blocked. Resolve the reason before accepting this candidate." }
    if candidate.decision == .reopened { return "Reopened. Confirm the source trail and local decision before closing it again." }
    if candidate.suggestedLinkedOrderID == nil && candidate.decision != .accepted { return "No linked order yet. Link an existing order or create one before accepting." }
    if candidate.detectedOrderNumber.isPlaceholderValidationValue { return "Order number needs review before the candidate becomes an order handoff." }
    if candidate.detectedTrackingNumber.isPlaceholderValidationValue { return "Tracking number needs review before dispatch setup depends on it." }
    if candidate.detectedDestinationAddress.isPlaceholderValidationValue { return "Destination needs review before accepting the candidate." }
    if candidate.reviewState == .needsReview { return "Review state is still open. Mark reviewed after decision and linked context are confirmed." }
    return "Confirm source, linked order, and decision state before closing acceptance review."
  }
}

private struct AcceptanceReadinessRow: View {
  var candidate: AcceptanceCandidate
  var detail: String

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: candidate.sourceType.symbol)
        .foregroundStyle(candidate.decision.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(candidate.sourceLabel)
          .font(.caption.weight(.semibold))
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 8)
      Badge(candidate.decision.rawValue, color: candidate.decision.color)
    }
    .padding(8)
    .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
  }
}

struct AcceptanceCandidateRow: View {
  var candidate: AcceptanceCandidate
  var store: ParcelOpsStore
  var orders: [TrackedOrder]
  var shipmentGroups: [ShipmentGroup]
  var linkedOrderLabel: String?
  var linkedShipmentGroupLabel: String?
  var history: [AcceptanceRecord]
  var playbooks: [ExceptionPlaybook] = []
  var handoffNotes: [HandoffNote] = []
  var customerProfiles: [CustomerRecipientProfile] = []
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var onLinkOrder: (TrackedOrder) -> Void
  var onLinkShipmentGroup: (ShipmentGroup) -> Void
  var onCreateOrder: () -> Void
  var onCreateShipmentGroup: () -> Void
  var onAccept: () -> Void
  var onIgnore: () -> Void
  var onReopen: () -> Void
  var onTask: () -> Void
  var onDraft: () -> Void
  @State private var feedbackMessage: String?

  private var linkedOrder: TrackedOrder? {
    candidate.suggestedLinkedOrderID.flatMap { orderID in
      orders.first { $0.id == orderID }
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: candidate.sourceType.symbol)
          .font(.title3)
          .foregroundStyle(candidate.decision.color)
          .frame(width: 28)

        VStack(alignment: .leading, spacing: 5) {
          Text(candidate.sourceLabel)
            .font(.headline)
          Text("\(candidate.sourceType.rawValue) • Captured \(candidate.capturedDate)")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(candidate.rawSummary)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 6) {
          Badge(candidate.decision.rawValue, color: candidate.decision.color)
          Badge("\(candidate.confidenceScore)% confidence", color: candidate.confidenceScore < 50 ? .red : candidate.confidenceScore < 75 ? .orange : .green)
        }
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 10)], alignment: .leading, spacing: 10) {
        AcceptanceFact(title: "Merchant", value: candidate.detectedMerchant)
        AcceptanceFact(title: "Order", value: candidate.detectedOrderNumber)
        AcceptanceFact(title: "Tracking", value: candidate.detectedTrackingNumber)
        AcceptanceFact(title: "Destination", value: candidate.detectedDestinationAddress)
        AcceptanceFact(title: "Linked order", value: linkedOrderLabel ?? "None")
        AcceptanceFact(title: "Shipment group", value: linkedShipmentGroupLabel ?? "None")
      }

      if !candidate.notes.isEmpty {
        Text(candidate.notes)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      LinkedOrderContextPanel(
        order: linkedOrder,
        sourceLabel: "Acceptance review",
        emptyDetail: "No order is linked yet. Choose an existing order when this candidate represents known work, or create a new local order before accepting it.",
        linkedDetail: "This candidate has linked order context. Confirm the order details before accepting the record into operations.",
        store: store
      )

      AcceptanceHistoryStrip(records: history)

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
        Menu("Link order", systemImage: "shippingbox.fill") {
          ForEach(orders) { order in
            Button("\(order.store) \(order.orderNumber)") {
              onLinkOrder(order)
              feedbackMessage = "Candidate linked to \(order.orderNumber). Check Orders."
            }
          }
        }

        Menu("Link group", systemImage: "shippingbox.and.arrow.backward.fill") {
          ForEach(shipmentGroups) { group in
            Button(group.groupName) {
              onLinkShipmentGroup(group)
              feedbackMessage = "Candidate linked to shipment group. Check linked context."
            }
          }
        }

        Button("Create order", systemImage: "plus.square.fill") {
          onCreateOrder()
          feedbackMessage = "Order created from acceptance candidate. Check Orders."
        }
        if let linkedOrder {
          NavigationLink {
            OrderDetailView(order: linkedOrder, store: store)
          } label: {
            Label("Open order", systemImage: "arrow.up.right.square.fill")
          }
        }
        Button("Create group", systemImage: "square.stack.3d.up.fill") {
          onCreateShipmentGroup()
          feedbackMessage = "Shipment group created from acceptance candidate."
        }
        Button("Task", systemImage: "checklist") {
          onTask()
          feedbackMessage = "Follow-up task created. Check Tasks."
        }
        Button("Draft", systemImage: "envelope.open.fill") {
          onDraft()
          feedbackMessage = "Draft message created locally."
        }
        Button("Accept", systemImage: "checkmark.circle.fill") {
          onAccept()
          feedbackMessage = "Candidate accepted locally. Check Orders if an order was linked or created."
        }
        Button("Ignore", systemImage: "eye.slash.fill") {
          onIgnore()
          feedbackMessage = "Candidate ignored locally."
        }
        Button("Reopen", systemImage: "arrow.counterclockwise") {
          onReopen()
          feedbackMessage = "Candidate reopened for review."
        }
      }
      .font(.caption)
      .buttonStyle(.bordered)

      if let feedbackMessage {
        AcceptanceFeedbackPanel(message: feedbackMessage, store: store)
      }
    }
    .padding()
    .background(.background, in: RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(.quaternary)
    )
  }
}

private struct AcceptanceFeedbackPanel: View {
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
        NavigationLink {
          AuditView(store: store)
        } label: {
          Label("Open Audit", systemImage: "list.clipboard.fill")
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

private struct AcceptanceFact: View {
  var title: String
  var value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(value)
        .font(.caption)
        .lineLimit(3)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(8)
    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
  }
}

private extension AcceptanceGrouping {
  var symbol: String {
    switch self {
    case .confidence: "gauge.with.dots.needle.67percent"
    case .linkedOrder: "shippingbox.fill"
    case .shipmentGroup: "shippingbox.and.arrow.backward.fill"
    case .reviewState: "checkmark.shield.fill"
    }
  }
}
