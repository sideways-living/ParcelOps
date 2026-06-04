import SwiftUI

struct AcceptanceReviewView: View {
  var store: ParcelOpsStore
  @State private var selectedSourceType: AcceptanceSourceType?
  @State private var selectedDecision: AcceptanceDecision?
  @State private var selectedConfidenceRange: ImportConfidenceRange = .all
  @State private var selectedReviewState: ReviewState?
  @State private var grouping: AcceptanceGrouping = .confidence
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var filteredCandidates: [AcceptanceCandidate] {
    store.filteredAcceptanceCandidates(
      sourceType: selectedSourceType,
      decision: selectedDecision,
      confidenceRange: selectedConfidenceRange,
      reviewState: selectedReviewState
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        header
        filters

        ForEach(store.groupedAcceptanceCandidates(filteredCandidates, by: grouping), id: \.title) { group in
          SettingsPanel(title: group.title, symbol: grouping.symbol) {
            VStack(spacing: 12) {
              ForEach(group.candidates) { candidate in
                AcceptanceCandidateRow(
                  candidate: candidate,
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
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private var header: some View {
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
  }

  private var filters: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
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
      }

      HStack {
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
      }
    }
    .pickerStyle(.menu)
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct AcceptanceCandidateRow: View {
  var candidate: AcceptanceCandidate
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

      HStack {
        Menu("Link order", systemImage: "shippingbox.fill") {
          ForEach(orders) { order in
            Button("\(order.store) \(order.orderNumber)") {
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

        Button("Create order", systemImage: "plus.square.fill", action: onCreateOrder)
        Button("Create group", systemImage: "square.stack.3d.up.fill", action: onCreateShipmentGroup)
        Spacer()
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
        Button("Accept", systemImage: "checkmark.circle.fill", action: onAccept)
        Button("Ignore", systemImage: "eye.slash.fill", action: onIgnore)
        Button("Reopen", systemImage: "arrow.counterclockwise", action: onReopen)
      }
      .font(.caption)
      .buttonStyle(.bordered)
    }
    .padding()
    .background(.background, in: RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(.quaternary)
    )
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
