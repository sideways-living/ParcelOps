import SwiftUI

struct ValidationView: View {
  var store: ParcelOpsStore
  @State private var entityFilter: ValidationEntityType?
  @State private var severityFilter: ValidationSeverity?
  @State private var statusFilter: ValidationStatus?
  @State private var reviewFilter: ReviewState?
  @State private var validationSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var baseFilteredIssues: [ValidationIssue] {
    store.filteredValidationIssues(
      entityType: entityFilter,
      severity: severityFilter,
      status: statusFilter,
      reviewState: reviewFilter
    )
  }

  private var filteredIssues: [ValidationIssue] {
    let query = validationSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredIssues }
    return baseFilteredIssues.filter { issue in
      validationIssue(issue, matches: query)
    }
  }

  private var hasActiveFilters: Bool {
    entityFilter != nil
      || severityFilter != nil
      || statusFilter != nil
      || reviewFilter != nil
      || !validationSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var inboxCreatedOrders: [TrackedOrder] {
    store.inboxCreatedOrders
  }

  private var wishlistLinkedOrders: [TrackedOrder] {
    store.wishlistLinkedOrders
  }

  private var sourceOrders: [TrackedOrder] {
    store.operatorSourceOrders
  }

  private var sourceOrdersWithSourceTrail: [TrackedOrder] {
    sourceOrders.filter { sourceTrailCount(for: $0) > 0 }
  }

  private var sourceOrdersMissingSourceTrail: [TrackedOrder] {
    sourceOrders.filter { sourceTrailCount(for: $0) == 0 }
  }

  private var inboxLinkedValidationIssues: [ValidationIssue] {
    let sourceOrderIDs = Set(sourceOrders.map(\.id))
    return store.validationIssues.filter { issue in
      guard let order = linkedOrder(for: issue) else { return false }
      return sourceOrderIDs.contains(order.id)
    }
  }

  private var validationProviderRows: [(label: String, count: Int, detail: String, symbol: String, color: Color)] {
    var counts: [String: Int] = [:]
    var tones: [String: String] = [:]

    for order in sourceOrders {
      for email in linkedIntakeEmails(for: order) {
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
          detail = "SpaceMail intake can produce parser, tracking, destination, or order-number validation checks.\(providerRefreshSuffix(for: tone))"
        case "gmail":
          detail = "Gmail intake can produce parser, tracking, destination, or order-number validation checks.\(providerRefreshSuffix(for: tone))"
        case "mock":
          detail = "Mock mailbox intake is local test evidence; confirm live provider context before closing real validation work."
        default:
          detail = "Local mailbox intake can produce validation checks once linked to an order."
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
      refreshedCount = store.spaceMailIntakeHealthSummaries.reduce(0) { $0 + $1.duplicateRefreshedCount }
    case "gmail":
      refreshedCount = store.gmailIntakeHealthSummaries.reduce(0) { $0 + $1.duplicateRefreshedCount }
    default:
      refreshedCount = 0
    }
    guard refreshedCount > 0 else { return "" }
    return " \(refreshedCount) duplicate refresh\(refreshedCount == 1 ? "" : "es") updated existing Inbox rows; review refreshed fields before closing validation."
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filters
        inboxSourceValidationPanel
        mailboxProviderReleaseValidationPanel
        gmailValidationReleaseBoundary

        SettingsPanel(title: "Validation results", symbol: "checkmark.shield.fill") {
          HStack {
            Text("\(filteredIssues.count) visible validation issues")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredIssues.count) after filters", color: .blue)
            }
            Spacer()
          }
        }

        if filteredIssues.isEmpty {
          MVPEmptyState(title: "No validation issues match this view", detail: hasActiveFilters ? "Clear search or filters to return to all local validation issues." : "Validation issues appear here when local intake, order, tracking, and profile checks need attention.", symbol: "checkmark.shield.fill", actionTitle: hasActiveFilters ? "Clear filters" : nil, action: hasActiveFilters ? clearFilters : nil)
        } else {
          ForEach(store.groupedValidationIssues(filteredIssues)) { group in
            SettingsPanel(title: group.severity.rawValue, symbol: group.severity.symbol) {
              ForEach(group.issues) { issue in
                ValidationIssueRow(issue: issue, store: store, linkedOrder: linkedOrder(for: issue), shipmentGroups: store.suggestedShipmentGroups(for: issue), importQueueItems: store.importQueueItems(for: issue), acceptanceRecords: store.acceptanceRecords(for: issue), playbooks: store.suggestedPlaybooks(for: issue), handoffNotes: store.handoffNotes(for: issue), customerProfiles: store.suggestedCustomerProfiles(for: issue), destinationAddresses: store.suggestedDestinationAddresses(for: issue), deliveryInstructions: store.suggestedDeliveryInstructions(for: issue), packageContents: store.suggestedPackageContents(for: issue)) {
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
  private var mailboxProviderReleaseValidationPanel: some View {
    if store.mailboxProviderReleaseGateSummary.tone != "success" || store.mailboxProviderHandoffPacketSummary.tone != "success" {
      SettingsPanel(title: "Mailbox provider validation context", symbol: "checkmark.seal.fill") {
        VStack(alignment: .leading, spacing: 12) {
          Text("Use this before closing mailbox-derived validation issues. It shows whether mailbox setup, refresh evidence, parser checks, classifier review, and handoff follow-up are ready enough for a real operator pass.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          MailboxProviderReleaseGateCard(summary: store.mailboxProviderReleaseGateSummary, store: store)
          MailboxProviderHandoffPacketCard(packet: store.mailboxProviderHandoffPacketSummary, store: store)
        }
      }
    }
  }

  private var gmailValidationReleaseBoundary: some View {
    GmailReleaseBoundaryPanel(
      store: store,
      title: "Gmail validation readiness",
      lead: "Gmail self-checks should be complete before Gmail-derived parser, order-number, tracking, destination, or confidence validation rows are treated as release-ready.",
      sourceMetricTitle: "Gmail validation sources",
      sourceCount: gmailValidationSourceCount,
      boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store tokens, mutate mail, create validation issues, or change review state automatically."
    )
  }

  private var gmailValidationSourceCount: Int {
    validationProviderRows
      .filter { $0.label.localizedCaseInsensitiveContains("Gmail") }
      .reduce(0) { total, row in total + row.count }
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Validation")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Local confidence and correction checks across intake, orders, tracking, destinations, contacts, accounts, and vendor profile matches.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(store.validationHealthScore)%", color: store.validationHealthScore >= 80 ? .green : .orange)
        Badge("\(store.highSeverityValidationIssues.count) high", color: .red)
      }
    }
  }

  private var filters: some View {
    FilterControlGrid {
      TextField("Search validation, order, tracking, intake, destination, playbook, or action", text: $validationSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Entity", selection: $entityFilter) {
        Text("All entities").tag(ValidationEntityType?.none)
        ForEach(ValidationEntityType.allCases) { type in
          Label(type.rawValue, systemImage: type.symbol).tag(Optional(type))
        }
      }
      Picker("Severity", selection: $severityFilter) {
        Text("All severity").tag(ValidationSeverity?.none)
        ForEach(ValidationSeverity.allCases) { severity in
          Text(severity.rawValue).tag(Optional(severity))
        }
      }
      Picker("Status", selection: $statusFilter) {
        Text("All status").tag(ValidationStatus?.none)
        ForEach(ValidationStatus.allCases) { status in
          Text(status.rawValue).tag(Optional(status))
        }
      }
      Picker("Review", selection: $reviewFilter) {
        Text("All review").tag(ReviewState?.none)
        ForEach(reviewStates, id: \.self) { state in
          Text(state.rawValue).tag(Optional(state))
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

  private var inboxSourceValidationPanel: some View {
    SettingsPanel(title: "Inbox/Wishlist source validation", symbol: "link.badge.plus") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this check before resolving validation rows for Inbox-created or Wishlist-linked orders. The order should still be traceable to intake, import, acceptance, or Wishlist purchase context.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Inbox orders", "\(inboxCreatedOrders.count)", inboxCreatedOrders.isEmpty ? .secondary : .teal),
          ("Wishlist orders", "\(wishlistLinkedOrders.count)", wishlistLinkedOrders.isEmpty ? .secondary : .pink),
          ("With source", "\(sourceOrdersWithSourceTrail.count)", sourceOrdersMissingSourceTrail.isEmpty ? .green : .orange),
          ("Missing source", "\(sourceOrdersMissingSourceTrail.count)", sourceOrdersMissingSourceTrail.isEmpty ? .green : .orange),
          ("Related issues", "\(inboxLinkedValidationIssues.count)", inboxLinkedValidationIssues.isEmpty ? .secondary : .orange)
        ])

        if !validationProviderRows.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Mailbox source for validation checks")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
              ForEach(validationProviderRows, id: \.label) { row in
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
          Label(sourceOrders.isEmpty ? "No Inbox-created or Wishlist-linked orders exist yet." : "All current Inbox-created and Wishlist-linked orders have local source context.", systemImage: "checkmark.seal.fill")
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
                  Text("No linked intake, import, acceptance, or Wishlist purchase source currently matches this order. Open the order source trail before marking validation follow-up complete.")
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
    entityFilter = nil
    severityFilter = nil
    statusFilter = nil
    reviewFilter = nil
    validationSearchText = ""
  }

  private func linkedOrder(for issue: ValidationIssue) -> TrackedOrder? {
    guard issue.entityType == .order || issue.linkedEntityType == .order,
          let id = UUID(uuidString: issue.entityID) else { return nil }
    return store.orders.first { $0.id == id }
  }

  private func validationIssue(_ issue: ValidationIssue, matches query: String) -> Bool {
    let order = linkedOrder(for: issue)
    let shipmentGroups = store.suggestedShipmentGroups(for: issue)
    let importQueueItems = store.importQueueItems(for: issue)
    let acceptanceRecords = store.acceptanceRecords(for: issue)
    let playbooks = store.suggestedPlaybooks(for: issue)
    let handoffNotes = store.handoffNotes(for: issue)
    var searchParts: [String] = [
      issue.id,
      issue.entityType.rawValue,
      issue.entityID,
      issue.title,
      issue.subtitle,
      issue.detail,
      "\(issue.confidenceScore)",
      issue.severity.rawValue,
      issue.status.rawValue,
      issue.reviewState?.rawValue ?? "",
      issue.linkedEntityType?.rawValue ?? "",
      issue.suggestedActionText,
      order?.orderNumber ?? "",
      order?.store ?? "",
      order?.customer ?? "",
      order?.recipientEmail ?? "",
      order?.trackingNumber ?? "",
      order?.carrier ?? "",
      order?.destination ?? ""
    ]
    searchParts.append(contentsOf: shipmentGroups.map(\.groupName))
    searchParts.append(contentsOf: shipmentGroups.map(\.destinationSummary))
    searchParts.append(contentsOf: importQueueItems.map(\.rawSummary))
    searchParts.append(contentsOf: importQueueItems.map(\.detectedOrderNumber))
    searchParts.append(contentsOf: acceptanceRecords.map(\.summary))
    searchParts.append(contentsOf: acceptanceRecords.map(\.notes))
    searchParts.append(contentsOf: playbooks.map(\.name))
    searchParts.append(contentsOf: handoffNotes.map(\.title))
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

  private func sourceTrailCount(for order: TrackedOrder) -> Int {
    store.sourceTrailCount(for: order, includeWishlist: true)
  }

  private func linkedIntakeEmails(for order: TrackedOrder) -> [ForwardedEmailIntake] {
    store.linkedIntakeEmails(for: order)
  }

}

struct ValidationIssueRow: View {
  var issue: ValidationIssue
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
  var shipmentGroups: [ShipmentGroup] = []
  var importQueueItems: [ImportQueueItem] = []
  var acceptanceRecords: [AcceptanceRecord] = []
  var playbooks: [ExceptionPlaybook] = []
  var handoffNotes: [HandoffNote] = []
  var customerProfiles: [CustomerRecipientProfile] = []
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var onCreateTask: () -> Void = {}
  var onCreateDraft: () -> Void = {}
  @State private var feedbackMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: issue.entityType.symbol)
          .foregroundStyle(issue.severity.color)
          .frame(width: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(issue.title)
            .font(.headline)
          Text(issue.subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(issue.detail)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(3)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 6) {
          Badge("\(issue.confidenceScore)%", color: issue.confidenceScore >= 75 ? .green : .orange)
          Badge(issue.status.rawValue, color: issue.status.color)
          Badge(issue.severity.rawValue, color: issue.severity.color)
          if let reviewState = issue.reviewState {
            Badge(reviewState.rawValue, color: reviewState.color)
          }
        }
      }

      HStack(spacing: 8) {
        Label(issue.entityType.rawValue, systemImage: issue.entityType.symbol)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(issue.suggestedActionText)
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Review task created from this validation issue for local follow-up."
        }
          .buttonStyle(.bordered)
          .disabled(!issue.supportsReviewTask)
        Button("Draft", systemImage: "square.and.pencil") {
          onCreateDraft()
          feedbackMessage = "Draft message created from this validation issue. It remains local until a person sends anything outside ParcelOps."
        }
          .buttonStyle(.bordered)
          .disabled(!issue.supportsDraftMessage)
        if let store, let linkedOrder {
          NavigationLink {
            OrderDetailView(order: linkedOrder, store: store)
          } label: {
            Label("Open order", systemImage: "arrow.up.right.square.fill")
          }
          .buttonStyle(.bordered)
        }
      }

      if let feedbackMessage {
        ValidationIssueActionFeedbackPanel(message: feedbackMessage)
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
    }
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

private struct ValidationIssueActionFeedbackPanel: View {
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

private extension ValidationSeverity {
  var symbol: String {
    switch self {
    case .info: "info.circle.fill"
    case .warning: "exclamationmark.triangle.fill"
    case .high: "exclamationmark.octagon.fill"
    case .critical: "xmark.octagon.fill"
    }
  }
}
