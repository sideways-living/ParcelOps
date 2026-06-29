import SwiftUI

struct EvidenceView: View {
  var store: ParcelOpsStore
  @State private var selectedEntityType: EvidenceLinkedEntityType?
  @State private var selectedReviewState: ReviewState?
  @State private var evidenceSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var baseFilteredAttachments: [EvidenceAttachment] {
    store.evidenceAttachments.filter { attachment in
      let matchesEntity = selectedEntityType == nil || attachment.linkedEntityType == selectedEntityType
      let matchesReview = selectedReviewState == nil || attachment.reviewState == selectedReviewState
      return matchesEntity && matchesReview
    }
  }

  private var filteredAttachments: [EvidenceAttachment] {
    let query = evidenceSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredAttachments }
    return baseFilteredAttachments.filter { attachment in
      evidenceAttachment(attachment, matches: query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedEntityType != nil
      || selectedReviewState != nil
      || !evidenceSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Evidence")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Local attachments linked to orders and forwarded intake emails.")
            .foregroundStyle(.secondary)
        }

        filterBar

        SettingsPanel(title: "Attachments", symbol: "paperclip") {
          HStack {
            Text("\(filteredAttachments.count) visible attachments")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredAttachments.count) after filters", color: .blue)
            }
            Spacer()
          }

          if filteredAttachments.isEmpty {
            MVPEmptyState(title: "No evidence matches this view", detail: hasActiveFilters ? "Clear search or filters to return to all local evidence records." : "Evidence appears here when local attachments or placeholder file references are linked to operational records.", symbol: "paperclip", actionTitle: hasActiveFilters ? "Clear filters" : nil, action: hasActiveFilters ? clearFilters : nil)
          } else {
            ForEach(filteredAttachments) { attachment in
              EvidenceAttachmentRow(attachment: attachment, store: store, linkedOrder: linkedOrder(for: attachment), shipmentGroups: store.suggestedShipmentGroups(for: attachment), customerProfiles: store.suggestedCustomerProfiles(for: attachment), destinationAddresses: store.suggestedDestinationAddresses(for: attachment), deliveryInstructions: store.suggestedDeliveryInstructions(for: attachment), packageContents: store.suggestedPackageContents(for: attachment)) {
                store.markEvidenceReviewed(attachment)
              } onRemove: {
                store.removeEvidence(attachment)
              } onCreateTask: {
                store.createReviewTask(from: attachment)
              } onCreateDraft: {
                store.createDraftMessage(from: attachment)
              } onCreateContact: {
                store.addContactDirectoryEntry(linkedEntityType: .evidence, linkedEntityID: attachment.id.uuidString, label: attachment.fileName)
              }
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private func linkedOrder(for attachment: EvidenceAttachment) -> TrackedOrder? {
    guard attachment.linkedEntityType == .order else { return nil }
    return store.orders.first { $0.id == attachment.linkedEntityID }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search file, summary, linked record, order, customer, destination, or item", text: $evidenceSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Record", selection: $selectedEntityType) {
        Text("All records").tag(nil as EvidenceLinkedEntityType?)
        ForEach(EvidenceLinkedEntityType.allCases) { entityType in
          Text(entityType.rawValue).tag(entityType as EvidenceLinkedEntityType?)
        }
      }

      Picker("Review", selection: $selectedReviewState) {
        Text("All review states").tag(nil as ReviewState?)
        Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted as ReviewState?)
        Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview as ReviewState?)
        Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor as ReviewState?)
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
    selectedEntityType = nil
    selectedReviewState = nil
    evidenceSearchText = ""
  }

  private func evidenceAttachment(_ attachment: EvidenceAttachment, matches query: String) -> Bool {
    let order = linkedOrder(for: attachment)
    let shipmentGroups = store.suggestedShipmentGroups(for: attachment)
    let customerProfiles = store.suggestedCustomerProfiles(for: attachment)
    let destinationAddresses = store.suggestedDestinationAddresses(for: attachment)
    let deliveryInstructions = store.suggestedDeliveryInstructions(for: attachment)
    let packageContents = store.suggestedPackageContents(for: attachment)
    var searchParts: [String] = [
      attachment.id.uuidString,
      attachment.linkedEntityType.rawValue,
      attachment.linkedEntityID.uuidString,
      attachment.fileName,
      attachment.fileType,
      attachment.source.rawValue,
      attachment.addedDate,
      attachment.summary,
      attachment.reviewState.rawValue,
      attachment.localFilePath,
      order?.orderNumber ?? "",
      order?.store ?? "",
      order?.customer ?? "",
      order?.recipientEmail ?? "",
      order?.trackingNumber ?? "",
      order?.carrier ?? "",
      order?.destination ?? ""
    ]
    searchParts.append(contentsOf: shipmentGroups.map(\.groupName))
    searchParts.append(contentsOf: customerProfiles.map(\.displayName))
    searchParts.append(contentsOf: destinationAddresses.map(\.label))
    searchParts.append(contentsOf: destinationAddresses.map(\.addressLineSummary))
    searchParts.append(contentsOf: deliveryInstructions.map(\.title))
    searchParts.append(contentsOf: deliveryInstructions.map(\.instructionSummary))
    searchParts.append(contentsOf: packageContents.map(\.title))
    searchParts.append(contentsOf: packageContents.map(\.itemSummary))
    let searchableText = searchParts.joined(separator: " ")
    return searchableText.localizedLowercase.contains(query)
  }
}

struct EvidenceAttachmentRow: View {
  var attachment: EvidenceAttachment
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
  var shipmentGroups: [ShipmentGroup] = []
  var customerProfiles: [CustomerRecipientProfile] = []
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var onReviewed: () -> Void
  var onRemove: () -> Void
  var onCreateTask: () -> Void = {}
  var onCreateDraft: () -> Void = {}
  var onCreateContact: () -> Void = {}

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: attachment.source.symbol)
          .foregroundStyle(attachment.reviewState.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(attachment.fileName)
                .font(.headline)
              Text("\(attachment.fileType) • \(attachment.addedDate)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(attachment.reviewState.rawValue, color: attachment.reviewState.color)
          }

          Text(attachment.summary)
            .foregroundStyle(.secondary)

          HStack(spacing: 8) {
            Badge(attachment.linkedEntityType.rawValue, color: attachment.reviewState.color)
            Label(attachment.source.rawValue, systemImage: attachment.source.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(attachment.localFilePath)
              .font(.caption2.monospaced())
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          }

          if !shipmentGroups.isEmpty {
            ShipmentGroupContextStrip(groups: shipmentGroups)
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
      }

      CompactActionRow {
        if let store, let linkedOrder {
          NavigationLink {
            OrderDetailView(order: linkedOrder, store: store)
          } label: {
            Label("Open order", systemImage: "arrow.up.right.square.fill")
          }
          .buttonStyle(.bordered)
        }
        Button("Reviewed", systemImage: "checkmark.circle.fill", action: onReviewed)
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", action: onRemove)
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill", action: onCreateDraft)
          .buttonStyle(.bordered)
        Button("Contact", systemImage: "person.crop.circle.badge.plus", action: onCreateContact)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
