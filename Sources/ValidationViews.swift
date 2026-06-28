import SwiftUI

struct ValidationView: View {
  var store: ParcelOpsStore
  @State private var entityFilter: ValidationEntityType?
  @State private var severityFilter: ValidationSeverity?
  @State private var statusFilter: ValidationStatus?
  @State private var reviewFilter: ReviewState?
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var filteredIssues: [ValidationIssue] {
    store.filteredValidationIssues(
      entityType: entityFilter,
      severity: severityFilter,
      status: statusFilter,
      reviewState: reviewFilter
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filters

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
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
    .background(.regularMaterial)
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
    }
  }

  private func linkedOrder(for issue: ValidationIssue) -> TrackedOrder? {
    guard issue.entityType == .order || issue.linkedEntityType == .order,
          let id = UUID(uuidString: issue.entityID) else { return nil }
    return store.orders.first { $0.id == id }
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
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
          .disabled(!issue.supportsReviewTask)
        Button("Draft", systemImage: "square.and.pencil", action: onCreateDraft)
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

      if !shipmentGroups.isEmpty {
        ShipmentGroupContextStrip(groups: shipmentGroups)
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
    }
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
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
