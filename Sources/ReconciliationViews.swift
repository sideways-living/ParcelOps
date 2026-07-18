import SwiftUI

struct ReconciliationView: View {
  var store: ParcelOpsStore
  @State private var selectedIssueType: ReconciliationIssueType?
  @State private var selectedSeverity: ValidationSeverity?
  @State private var selectedSourceType: ReconciliationEntityType?
  @State private var selectedTargetType: ReconciliationEntityType?
  @State private var selectedReviewState: ReviewState?
  @State private var reconciliationSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var baseFilteredIssues: [ReconciliationIssue] {
    store.filteredReconciliationIssues(
      issueType: selectedIssueType,
      severity: selectedSeverity,
      sourceEntityType: selectedSourceType,
      targetEntityType: selectedTargetType,
      reviewState: selectedReviewState
    )
  }

  private var filteredIssues: [ReconciliationIssue] {
    let query = reconciliationSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredIssues }
    return baseFilteredIssues.filter { issue in
      reconciliationIssue(issue, matches: query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedIssueType != nil
      || selectedSeverity != nil
      || selectedSourceType != nil
      || selectedTargetType != nil
      || selectedReviewState != nil
      || !reconciliationSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }




  private var sourceOrdersWithSourceTrail: [TrackedOrder] {
    store.operatorSourceOrdersWithSourceTrail(includeWishlist: true)
  }

  private var sourceOrdersWithMailboxSourceTrail: [TrackedOrder] {
    sourceOrdersWithSourceTrail.filter { order in
      !store.mailboxSourceSummaries(for: order).isEmpty
    }
  }

  private var sourceOrdersMissingSourceTrail: [TrackedOrder] {
    store.operatorSourceOrdersMissingSourceTrail(includeWishlist: true)
  }

  private var inboxLinkedReconciliationIssues: [ReconciliationIssue] {
    let sourceOrderIDs = Set(store.operatorSourceOrders.map(\.id))
    return store.reconciliationIssues.filter { issue in
      guard let order = linkedOrder(for: issue) else { return false }
      return sourceOrderIDs.contains(order.id)
    }
  }

  private var reconciliationProviderRows: [(label: String, count: Int, detail: String, symbol: String, color: Color)] {
    var counts: [String: Int] = [:]
    var tones: [String: String] = [:]

    for order in store.operatorSourceOrders {
      for email in store.linkedIntakeEmails(for: order) {
        let summary = store.intakeSourceSummary(for: email)
        counts[summary.label, default: 0] += 1
        tones[summary.label] = summary.tone
      }
    }

    return counts
      .map { label, count in
        let tone = tones[label] ?? ""
        let detail: String
        switch tone {
        case "spacemail":
          detail = "SpaceMail intake can create mismatches between parsed email values, order detail, tracking, and acceptance context.\(providerRefreshSuffix(for: tone))"
        case "gmail":
          detail = "Gmail intake can create mismatches between parsed email values, order detail, tracking, and acceptance context.\(providerRefreshSuffix(for: tone))"
        case "mock":
          detail = "Mock mailbox intake is local test evidence; confirm live provider context before closing real mismatches."
        default:
          detail = "Local mailbox intake can create reconciliation work once linked to an order."
        }
        return (label: label, count: count, detail: detail, symbol: providerSymbol(for: tone, label: label), color: providerColor(for: tone))
      }
      .sorted { lhs, rhs in
        if lhs.count != rhs.count { return lhs.count > rhs.count }
        return lhs.label < rhs.label
      }
  }

  private func providerRefreshSuffix(for tone: String) -> String {
    let refreshedCount: Int
    switch tone {
    case "spacemail":
      refreshedCount = store.totalSpaceMailDuplicateRefreshedCount
    case "gmail":
      refreshedCount = store.totalGmailDuplicateRefreshedCount
    default:
      refreshedCount = 0
    }
    guard refreshedCount > 0 else { return "" }
    return " \(refreshedCount) duplicate refresh\(refreshedCount == 1 ? "" : "es") updated existing Inbox rows; verify refreshed source values before resolving mismatches."
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filters
        inboxSourceReconciliationPanel
        mailboxProviderReleaseReconciliationPanel
        gmailReconciliationReleaseBoundary
        microsoft365ReconciliationReleaseBoundary

        SettingsPanel(title: "Reconciliation results", symbol: "arrow.triangle.2.circlepath") {
          HStack {
            Text("\(filteredIssues.count) visible reconciliation issues")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredIssues.count) after filters", color: .blue)
            }
            Spacer()
          }
        }

        if filteredIssues.isEmpty {
          MVPEmptyState(title: "No reconciliation issues match this view", detail: hasActiveFilters ? "Clear search or filters to return to unresolved local mismatches." : "Reconciliation issues appear here when local intake, acceptance, orders, tracking, or validation values disagree.", symbol: "arrow.triangle.2.circlepath", actionTitle: hasActiveFilters ? "Clear filters" : nil, action: hasActiveFilters ? clearFilters : nil)
        } else {
          ForEach(store.groupedReconciliationIssues(filteredIssues)) { group in
            SettingsPanel(title: group.issueType.rawValue, symbol: group.issueType.symbol) {
              ForEach(group.issues) { issue in
                ReconciliationIssueRow(
                  issue: issue,
                  store: store,
                  linkedOrder: linkedOrder(for: issue),
                  shipmentGroups: store.suggestedShipmentGroups(for: issue),
                  importQueueItems: store.importQueueItems(for: issue),
                  acceptanceRecords: store.acceptanceRecords(for: issue),
                  validationIssues: store.relatedValidationIssues(for: issue),
                  playbooks: store.suggestedPlaybooks(for: issue),
                  handoffNotes: store.handoffNotes(for: issue),
                  customerProfiles: store.suggestedCustomerProfiles(for: issue),
                  destinationAddresses: store.suggestedDestinationAddresses(for: issue),
                  deliveryInstructions: store.suggestedDeliveryInstructions(for: issue),
                  packageContents: store.suggestedPackageContents(for: issue)
                ) {
                  store.markReconciliationIssueReviewed(issue)
                } onCreateTask: {
                  store.createReviewTask(from: issue)
                } onCreateDraft: {
                  store.createDraftMessage(from: issue)
                }
              }
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
    .background(.regularMaterial)
  }

  @ViewBuilder
  private var mailboxProviderReleaseReconciliationPanel: some View {
    if store.mailboxProviderReleaseGateSummary.tone != "success" || store.mailboxProviderHandoffPacketSummary.tone != "success" {
      SettingsPanel(title: "Mailbox provider reconciliation context", symbol: "checkmark.seal.fill") {
        VStack(alignment: .leading, spacing: 12) {
          Text("Use this before resolving mailbox-derived mismatches. It keeps provider release gates, handoff notes, parser/classifier evidence, and source-trail follow-up visible beside reconciliation work.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          MailboxProviderReleaseGateCard(summary: store.mailboxProviderReleaseGateSummary, store: store)
          MailboxProviderHandoffPacketCard(packet: store.mailboxProviderHandoffPacketSummary, store: store)
        }
      }
    }
  }

  private var gmailReconciliationReleaseBoundary: some View {
    GmailReleaseBoundaryPanel(
      store: store,
      title: "Gmail reconciliation readiness",
      lead: "Gmail self-checks should be complete before Gmail-derived source values, order links, tracking values, or acceptance handoffs are treated as reconciled release evidence.",
      sourceMetricTitle: "Gmail reconciliation sources",
      sourceCount: gmailReconciliationSourceCount,
      boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store tokens, mutate mail, resolve reconciliation issues, or change order/source links automatically."
    )
  }

  private var gmailReconciliationSourceCount: Int {
    reconciliationProviderRows
      .filter { $0.label.localizedCaseInsensitiveContains("Gmail") }
      .reduce(0) { total, row in total + row.count }
  }

  private var microsoft365ReconciliationReleaseBoundary: some View {
    Microsoft365ReleaseBoundaryPanel(
      store: store,
      title: "Outlook reconciliation readiness",
      lead: "Outlook self-checks should be complete before Graph-derived source values, order links, tracking values, or acceptance handoffs are treated as reconciled release evidence.",
      sourceMetricTitle: "Outlook reconciliation sources",
      sourceCount: microsoft365ReconciliationSourceCount,
      boundaryDetail: "Local-only boundary: this panel does not start Microsoft sign-in, request tokens, fetch Outlook messages, mutate mail, resolve reconciliation issues, or change order/source links automatically."
    )
  }

  private var microsoft365ReconciliationSourceCount: Int {
    reconciliationProviderRows
      .filter { $0.label.localizedCaseInsensitiveContains("Microsoft 365") || $0.label.localizedCaseInsensitiveContains("Outlook") }
      .reduce(0) { total, row in total + row.count }
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Reconciliation")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Compare local intake, imports, acceptance history, orders, shipment groups, tracking, evidence, and validation context before resolving mismatches.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(store.unresolvedReconciliationIssues.count) unresolved", color: .orange)
        Badge("\(store.highSeverityReconciliationIssues.count) high", color: .red)
      }
    }
  }

  private var filters: some View {
    FilterControlGrid {
      TextField("Search mismatch, value, resolution, source, target, order, tracking, or handoff", text: $reconciliationSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Issue", selection: $selectedIssueType) {
        Text("All issues").tag(nil as ReconciliationIssueType?)
        ForEach(ReconciliationIssueType.allCases) { issueType in
          Label(issueType.rawValue, systemImage: issueType.symbol).tag(issueType as ReconciliationIssueType?)
        }
      }

      Picker("Severity", selection: $selectedSeverity) {
        Text("All severity").tag(nil as ValidationSeverity?)
        ForEach(ValidationSeverity.allCases) { severity in
          Text(severity.rawValue).tag(severity as ValidationSeverity?)
        }
      }

      Picker("Source", selection: $selectedSourceType) {
        Text("All sources").tag(nil as ReconciliationEntityType?)
        ForEach(ReconciliationEntityType.allCases) { entityType in
          Label(entityType.rawValue, systemImage: entityType.symbol).tag(entityType as ReconciliationEntityType?)
        }
      }

      Picker("Target", selection: $selectedTargetType) {
        Text("All targets").tag(nil as ReconciliationEntityType?)
        ForEach(ReconciliationEntityType.allCases) { entityType in
          Label(entityType.rawValue, systemImage: entityType.symbol).tag(entityType as ReconciliationEntityType?)
        }
      }

      Picker("Review", selection: $selectedReviewState) {
        Text("All review").tag(nil as ReviewState?)
        ForEach(reviewStates, id: \.self) { state in
          Text(state.rawValue).tag(state as ReviewState?)
        }
      }

      if hasActiveFilters {
        Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle") {
          clearFilters()
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private var inboxSourceReconciliationPanel: some View {
    SettingsPanel(title: "Inbox/Wishlist source reconciliation", symbol: "link.badge.plus") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this before resolving mismatches for source-created or Wishlist-linked orders. Missing source context can make order, import, acceptance, or Wishlist purchase conflicts look resolved when the handoff trail is incomplete.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Inbox orders", "\(store.inboxCreatedOrderCount)", store.inboxCreatedOrderCount == 0 ? .secondary : .teal),
          ("Wishlist orders", "\(store.wishlistLinkedOrderCount)", store.wishlistLinkedOrderCount == 0 ? .secondary : .pink),
          ("With source", "\(sourceOrdersWithSourceTrail.count)", sourceOrdersMissingSourceTrail.isEmpty ? .green : .orange),
          ("Mailbox source", "\(sourceOrdersWithMailboxSourceTrail.count)", sourceOrdersWithMailboxSourceTrail.isEmpty ? .secondary : .blue),
          ("Missing source", "\(sourceOrdersMissingSourceTrail.count)", sourceOrdersMissingSourceTrail.isEmpty ? .green : .orange),
          ("Related issues", "\(inboxLinkedReconciliationIssues.count)", inboxLinkedReconciliationIssues.isEmpty ? .secondary : .orange)
        ])

        if !reconciliationProviderRows.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Mailbox source for reconciliation")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
              ForEach(reconciliationProviderRows, id: \.label) { row in
                HStack(alignment: .top, spacing: 10) {
                  Image(systemName: row.symbol)
                    .foregroundStyle(row.color)
                    .frame(width: 22)
                  VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                      Text(row.label)
                        .font(.caption.weight(.semibold))
                      Spacer(minLength: 8)
                      Badge("\(row.count) intake", color: row.color)
                    }
                    Text(row.detail)
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                      .fixedSize(horizontal: false, vertical: true)
                  }
                }
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(row.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
              }
            }
          }
        }

        if sourceOrdersMissingSourceTrail.isEmpty {
          Label(store.operatorSourceOrderCount == 0 ? "No source-created or Wishlist-linked orders exist yet." : "All current source-created and Wishlist-linked orders have local source context.", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
        } else {
          ForEach(sourceOrdersMissingSourceTrail.prefix(4)) { order in
            NavigationLink {
              OrderDetailView(order: order, store: store)
            } label: {
              HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundStyle(.orange)
                  .frame(width: 22)
                VStack(alignment: .leading, spacing: 4) {
                  Text("\(order.store) • \(order.orderNumber)")
                    .font(.subheadline.weight(.semibold))
                  Text("No linked intake, import, acceptance, or Wishlist purchase source currently matches this order. Open the order source trail before marking reconciliation follow-up reviewed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Badge("Trace", color: .orange)
              }
              .padding(10)
              .background(Color.orange.opacity(0.08))
              .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }

  private func clearFilters() {
    selectedIssueType = nil
    selectedSeverity = nil
    selectedSourceType = nil
    selectedTargetType = nil
    selectedReviewState = nil
    reconciliationSearchText = ""
  }

  private func linkedOrder(for issue: ReconciliationIssue) -> TrackedOrder? {
    let orderID: String?
    if issue.sourceEntityType == .order {
      orderID = issue.sourceEntityID
    } else if issue.targetEntityType == .order {
      orderID = issue.targetEntityID
    } else {
      orderID = nil
    }
    guard let orderID, let id = UUID(uuidString: orderID) else { return nil }
    return store.orders.first { $0.id == id }
  }

  private func reconciliationIssue(_ issue: ReconciliationIssue, matches query: String) -> Bool {
    let order = linkedOrder(for: issue)
    let shipmentGroups = store.suggestedShipmentGroups(for: issue)
    let importQueueItems = store.importQueueItems(for: issue)
    let acceptanceRecords = store.acceptanceRecords(for: issue)
    let validationIssues = store.relatedValidationIssues(for: issue)
    let playbooks = store.suggestedPlaybooks(for: issue)
    let handoffNotes = store.handoffNotes(for: issue)
    var searchParts: [String] = [
      issue.id,
      issue.issueType.rawValue,
      issue.severity.rawValue,
      issue.sourceEntityType.rawValue,
      issue.sourceEntityID,
      issue.targetEntityType?.rawValue ?? "",
      issue.targetEntityID ?? "",
      issue.title,
      issue.summary,
      issue.detectedValue,
      issue.currentOperationalValue,
      issue.suggestedResolution,
      issue.reviewState.rawValue,
      issue.createdDate,
      order?.orderNumber ?? "",
      order?.store ?? "",
      order?.customer ?? "",
      order?.trackingNumber ?? "",
      order?.carrier ?? "",
      order?.destination ?? ""
    ]
    searchParts.append(contentsOf: shipmentGroups.map(\.groupName))
    searchParts.append(contentsOf: shipmentGroups.map(\.destinationSummary))
    searchParts.append(contentsOf: importQueueItems.map(\.rawSummary))
    searchParts.append(contentsOf: acceptanceRecords.map(\.summary))
    searchParts.append(contentsOf: validationIssues.map(\.title))
    searchParts.append(contentsOf: playbooks.map(\.name))
    searchParts.append(contentsOf: handoffNotes.map(\.title))
    if let order {
      let mailboxSummaries = store.mailboxSourceSummaries(for: order)
      searchParts.append(contentsOf: mailboxSummaries.map(\.providerName))
      searchParts.append(contentsOf: mailboxSummaries.map(\.mailboxLabel))
      searchParts.append(contentsOf: mailboxSummaries.map(\.statusLabel))
      searchParts.append(contentsOf: mailboxSummaries.map(\.detailText))
    }
    let searchableText = searchParts.joined(separator: " ")
    return searchableText.localizedLowercase.contains(query)
  }

  private func providerColor(for tone: String) -> Color {
    switch tone {
    case "spacemail": return .teal
    case "gmail": return .blue
    case "mock": return .purple
    case "microsoft", "mailbox": return .blue
    default: return .secondary
    }
  }

  private func providerSymbol(for tone: String, label: String) -> String {
    if tone == "gmail" || label.localizedCaseInsensitiveContains("Gmail") {
      return "envelope.badge.shield.half.filled"
    }
    if tone == "spacemail" || label.localizedCaseInsensitiveContains("SpaceMail") {
      return "server.rack"
    }
    if tone == "mock" {
      return "testtube.2"
    }
    return "envelope.open.fill"
  }



}

struct ReconciliationIssueRow: View {
  var issue: ReconciliationIssue
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
  var shipmentGroups: [ShipmentGroup] = []
  var importQueueItems: [ImportQueueItem] = []
  var acceptanceRecords: [AcceptanceRecord] = []
  var validationIssues: [ValidationIssue] = []
  var playbooks: [ExceptionPlaybook] = []
  var handoffNotes: [HandoffNote] = []
  var customerProfiles: [CustomerRecipientProfile] = []
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var onReviewed: () -> Void = {}
  var onCreateTask: () -> Void = {}
  var onCreateDraft: () -> Void = {}
  @State private var feedbackMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: issue.issueType.symbol)
          .foregroundStyle(issue.severity.color)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(issue.title)
            .font(.headline)
          Text("\(issue.sourceEntityType.rawValue) → \(issue.targetEntityType?.rawValue ?? "No target")")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(issue.summary)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 6) {
          Badge(issue.severity.rawValue, color: issue.severity.color)
          Badge(issue.reviewState.rawValue, color: issue.reviewState.color)
        }
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 10)], alignment: .leading, spacing: 10) {
        ReconciliationFact(title: "Detected", value: issue.detectedValue)
        ReconciliationFact(title: "Operational", value: issue.currentOperationalValue)
        ReconciliationFact(title: "Resolution", value: issue.suggestedResolution)
        ReconciliationFact(title: "Created", value: issue.createdDate)
      }

      if !shipmentGroups.isEmpty {
        ShipmentGroupContextStrip(groups: shipmentGroups)
      }
      if !importQueueItems.isEmpty {
        ImportQueueContextStrip(items: importQueueItems)
      }
      if !acceptanceRecords.isEmpty {
        AcceptanceHistoryStrip(records: acceptanceRecords, store: store)
      }
      if !validationIssues.isEmpty {
        CompactValidationIssueList(issues: Array(validationIssues.prefix(3)), store: store)
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
        Button("Reviewed", systemImage: "checkmark.circle.fill") {
          onReviewed()
          feedbackMessage = "Reconciliation issue marked reviewed locally. Confirm linked order and intake context before closing related work."
        }
          .buttonStyle(.bordered)
          .disabled(issue.reviewState == .accepted)
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Review task created from this reconciliation issue for local mismatch follow-up."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "square.and.pencil") {
          onCreateDraft()
          feedbackMessage = "Draft message created from this reconciliation issue. It remains local until a person sends anything outside ParcelOps."
        }
          .buttonStyle(.bordered)
        if let store, let linkedOrder {
          NavigationLink {
            OrderDetailView(order: linkedOrder, store: store)
          } label: {
            Label("Open order", systemImage: "arrow.up.right.square.fill")
          }
          .buttonStyle(.bordered)
        }
      }
      .font(.caption)

      if let feedbackMessage {
        ReconciliationIssueActionFeedbackPanel(message: feedbackMessage)
      }

      if let store, let linkedOrder {
        let mailboxSummaries = store.mailboxSourceSummaries(for: linkedOrder)
        if !mailboxSummaries.isEmpty {
          ReconciliationMailboxSourceTrail(summaries: mailboxSummaries)
        }
      }
    }
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

private struct ReconciliationMailboxSourceTrail: View {
  var summaries: [OrderMailboxSourceSummary]

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Label("Mailbox provider trail", systemImage: "envelope.badge.shield.half.filled")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.blue)
      CompactMetadataGrid(minimumWidth: 130) {
        ForEach(summaries) { summary in
          Badge(summary.badgeLabel, color: color(for: summary.providerName))
        }
      }
      ForEach(summaries) { summary in
        Text("\(summary.statusLabel): \(summary.detailText)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(10)
    .background(Color.blue.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  private func color(for providerName: String) -> Color {
    if providerName.localizedCaseInsensitiveContains("Gmail") { return .blue }
    if providerName.localizedCaseInsensitiveContains("SpaceMail") { return .teal }
    if providerName.localizedCaseInsensitiveContains("Mock") { return .purple }
    if providerName.localizedCaseInsensitiveContains("Microsoft") { return .blue }
    return .secondary
  }
}

private struct ReconciliationIssueActionFeedbackPanel: View {
  var message: String

  var body: some View {
    Label {
      Text(message)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    } icon: {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct ReconciliationFact: View {
  var title: String
  var value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(value)
        .font(.caption)
        .lineLimit(4)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(8)
    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
  }
}
