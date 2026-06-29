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

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filters

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
    let searchableText = searchParts.joined(separator: " ")
    return searchableText.localizedLowercase.contains(query)
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
        AcceptanceHistoryStrip(records: acceptanceRecords)
      }
      if !validationIssues.isEmpty {
        CompactValidationIssueList(issues: Array(validationIssues.prefix(3)))
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
        Button("Reviewed", systemImage: "checkmark.circle.fill", action: onReviewed)
          .buttonStyle(.bordered)
          .disabled(issue.reviewState == .accepted)
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "square.and.pencil", action: onCreateDraft)
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
    }
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
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
