import SwiftUI

struct DestinationAddressesView: View {
  var store: ParcelOpsStore
  @State private var selectedOrganisationTeam: String?
  @State private var selectedPreferredCarrier: String?
  @State private var selectedRiskLevel: ShipmentRiskLevel?
  @State private var selectedEnabled: Bool?
  @State private var selectedReviewState: ReviewState?
  @State private var addressSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var teams: [String] {
    Array(Set(store.destinationAddresses.map(\.organisationTeam))).sorted()
  }

  private var carriers: [String] {
    Array(Set(store.destinationAddresses.map(\.preferredCarrier))).sorted()
  }

  private var baseFilteredAddresses: [DestinationAddressRecord] {
    store.filteredDestinationAddresses(
      organisationTeam: selectedOrganisationTeam,
      preferredCarrier: selectedPreferredCarrier,
      riskLevel: selectedRiskLevel,
      isEnabled: selectedEnabled,
      reviewState: selectedReviewState
    )
  }

  private var filteredAddresses: [DestinationAddressRecord] {
    let query = addressSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredAddresses }
    return baseFilteredAddresses.filter { address in
      destinationAddressSearchParts(address).joined(separator: " ").localizedLowercase.contains(query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedOrganisationTeam != nil
      || selectedPreferredCarrier != nil
      || selectedRiskLevel != nil
      || selectedEnabled != nil
      || selectedReviewState != nil
      || !addressSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filters
        inboxAddressCoverage

        SettingsPanel(title: "Addresses", symbol: "mappin.and.ellipse") {
          HStack {
            Text("\(filteredAddresses.count) visible addresses")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredAddresses.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add address", systemImage: "plus", action: store.addDestinationAddressPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredAddresses.isEmpty {
            MVPEmptyState(title: "No destination addresses match this view", detail: hasActiveFilters ? "Clear search or filters to return to all local destination addresses." : "Add a local destination address to reuse delivery instructions, access notes, preferred carrier, and risk context.", symbol: "mappin.and.ellipse", actionTitle: hasActiveFilters ? "Clear filters" : "Add address", action: hasActiveFilters ? clearFilters : store.addDestinationAddressPlaceholder)
          } else {
            ForEach(filteredAddresses) { address in
              DestinationAddressRow(address: address, store: store, inboxOrders: inboxOrders(for: address), customerProfiles: store.customerRecipientProfiles, deliveryInstructions: store.suggestedDeliveryInstructions(for: address), packageContents: store.suggestedPackageContents(for: address)) { updatedAddress in
                store.updateDestinationAddress(updatedAddress)
              } onToggle: {
                store.toggleDestinationAddress(address)
              } onReviewed: {
                store.markDestinationAddressReviewed(address)
              } onCreateTask: {
                store.createReviewTask(from: address)
              } onCreateDraft: {
                store.createDraftMessage(from: address)
              } onRemove: {
                store.removeDestinationAddress(address)
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
        Text("Destination Addresses")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Reusable local delivery destinations, access notes, carrier preferences, and address-risk context.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 8) {
        Button("Add address", systemImage: "plus", action: store.addDestinationAddressPlaceholder)
          .buttonStyle(.borderedProminent)
        Badge("\(store.destinationAddressesNeedingReview.count) review", color: .orange)
      }
    }
  }

  private var filters: some View {
    FilterControlGrid {
      TextField("Search label, address, city, country, instructions, access notes, carrier, or customer", text: $addressSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Team", selection: $selectedOrganisationTeam) {
        Text("All teams").tag(String?.none)
        ForEach(teams, id: \.self) { team in Text(team).tag(Optional(team)) }
      }
      Picker("Carrier", selection: $selectedPreferredCarrier) {
        Text("All carriers").tag(String?.none)
        ForEach(carriers, id: \.self) { carrier in Text(carrier).tag(Optional(carrier)) }
      }
      Picker("Risk", selection: $selectedRiskLevel) {
        Text("All risk").tag(ShipmentRiskLevel?.none)
        ForEach(ShipmentRiskLevel.allCases) { risk in Text(risk.rawValue).tag(Optional(risk)) }
      }
      Picker("Enabled", selection: $selectedEnabled) {
        Text("All states").tag(Bool?.none)
        Text("Enabled").tag(Optional(true))
        Text("Disabled").tag(Optional(false))
      }
      Picker("Review", selection: $selectedReviewState) {
        Text("All review").tag(ReviewState?.none)
        ForEach([ReviewState.needsReview, .monitor, .accepted], id: \.self) { state in
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

  private func clearFilters() {
    selectedOrganisationTeam = nil
    selectedPreferredCarrier = nil
    selectedRiskLevel = nil
    selectedEnabled = nil
    selectedReviewState = nil
    addressSearchText = ""
  }

  private var inboxAddressCoverage: some View {
    let inboxOrders = inboxCreatedOrders
    let linkedAddresses = destinationAddressesLinkedToInboxOrders
    let actionAddresses = linkedAddresses.filter { !$0.isEnabled || $0.reviewState != .accepted || $0.riskLevel == .high || $0.riskLevel == .critical }
    let missingCount = inboxOrdersMissingAddress.count

    return SettingsPanel(title: "Inbox destination readiness", symbol: "mappin.and.ellipse") {
      VStack(alignment: .leading, spacing: 10) {
        Text("Checks whether orders created from Inbox intake have reusable destination records before delivery, storage, or dispatch handoff.")
          .font(.caption)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 150) {
          Badge("\(inboxOrders.count) Inbox orders", color: .blue)
          Badge("\(linkedAddresses.count) matched addresses", color: .teal)
          Badge("\(actionAddresses.count) need action", color: actionAddresses.isEmpty ? .green : .orange)
          Badge("\(missingCount) without address", color: missingCount == 0 ? .green : .orange)
        }

        if !addressProviderRows.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Mailbox source for destinations")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
              ForEach(addressProviderRows, id: \.label) { row in
                HStack(alignment: .top, spacing: 10) {
                  Image(systemName: row.symbol)
                    .foregroundStyle(row.color)
                    .frame(width: 22, height: 22)
                  VStack(alignment: .leading, spacing: 4) {
                    HStack {
                      Text(row.label)
                        .font(.caption.weight(.semibold))
                      Spacer()
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

        if inboxOrders.isEmpty {
          Text("No Inbox-created orders are present yet. Create an order from Inbox before checking destination coverage.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if linkedAddresses.isEmpty {
          Text("No destination addresses currently match Inbox-created orders by destination, city, carrier, or customer profile.")
            .font(.caption)
            .foregroundStyle(.orange)
        } else if actionAddresses.isEmpty {
          Text("Matched destination addresses are enabled, reviewed, and not high-risk for current Inbox-created orders.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          ForEach(Array(actionAddresses.prefix(3))) { address in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: address.riskLevel == .high || address.riskLevel == .critical ? "exclamationmark.triangle.fill" : "mappin.and.ellipse")
                .foregroundStyle(address.riskLevel == .high || address.riskLevel == .critical ? .red : .orange)
              VStack(alignment: .leading, spacing: 2) {
                Text(address.label)
                  .font(.caption.bold())
                Text(addressActionSummary(for: address))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Badge(address.riskLevel.rawValue, color: address.riskLevel.color)
            }
          }
        }
      }
    }
  }

  private var addressProviderRows: [(label: String, count: Int, detail: String, symbol: String, color: Color)] {
    var counts: [String: Int] = [:]
    var tones: [String: String] = [:]
    for order in inboxCreatedOrders {
      for email in linkedIntakeEmails(for: order) {
        let summary = store.intakeSourceSummary(for: email)
        counts[summary.label, default: 0] += 1
        tones[summary.label] = summary.tone
      }
    }
    return counts.map { label, count in
      let tone = tones[label] ?? ""
      let detail: String
      switch tone {
      case "spacemail":
        detail = "SpaceMail intake can provide destination hints that need local confirmation before dispatch or delivery handoff."
      case "gmail":
        detail = "Gmail intake can provide destination hints that need local confirmation before dispatch or delivery handoff."
      case "mock":
        detail = "Mock mailbox intake supports local destination testing. Confirm live provider context before relying on address records."
      default:
        detail = "Local mailbox intake can provide destination hints once linked to an order."
      }
      return (
        label: label,
        count: count,
        detail: detail,
        symbol: providerSymbol(for: tone, label: label),
        color: sourceColor(for: tone)
      )
    }
    .sorted { lhs, rhs in
      if lhs.count == rhs.count {
        return lhs.label < rhs.label
      }
      return lhs.count > rhs.count
    }
  }

  private var inboxCreatedOrders: [TrackedOrder] {
    store.orders.filter { !linkedIntakeEmails(for: $0).isEmpty }
  }

  private var destinationAddressesLinkedToInboxOrders: [DestinationAddressRecord] {
    store.destinationAddresses.filter { address in
      inboxCreatedOrders.contains { order in
        destinationAddress(address, matches: order)
      }
    }
  }

  private var inboxOrdersMissingAddress: [TrackedOrder] {
    inboxCreatedOrders.filter { order in
      !store.destinationAddresses.contains { address in
        destinationAddress(address, matches: order)
      }
    }
  }

  private func inboxOrders(for address: DestinationAddressRecord) -> [TrackedOrder] {
    inboxCreatedOrders.filter { destinationAddress(address, matches: $0) }
  }

  private func destinationAddress(_ address: DestinationAddressRecord, matches order: TrackedOrder) -> Bool {
    let line = address.addressLineSummary.trimmingCharacters(in: .whitespacesAndNewlines)
    let city = address.cityRegion.trimmingCharacters(in: .whitespacesAndNewlines)
    let carrier = address.preferredCarrier.trimmingCharacters(in: .whitespacesAndNewlines)
    let linkedProfile = address.customerProfileID.flatMap { id in
      store.customerRecipientProfiles.first { $0.id == id }
    }
    return (!line.isEmpty && !line.isPlaceholderValidationValue && (order.destination.localizedCaseInsensitiveContains(line) || line.localizedCaseInsensitiveContains(order.destination)))
      || (!city.isEmpty && !city.isPlaceholderValidationValue && order.destination.localizedCaseInsensitiveContains(city))
      || (!carrier.isEmpty && !carrier.isPlaceholderValidationValue && order.carrier.localizedCaseInsensitiveContains(carrier))
      || (linkedProfile.map { profile in
        !profile.primaryEmail.isPlaceholderValidationValue && order.recipientEmail.localizedCaseInsensitiveContains(profile.primaryEmail)
      } ?? false)
  }

  private func addressActionSummary(for address: DestinationAddressRecord) -> String {
    var parts: [String] = []
    if !address.isEnabled { parts.append("enable or confirm disabled address") }
    if address.reviewState != .accepted { parts.append("mark reviewed") }
    if address.riskLevel == .high || address.riskLevel == .critical { parts.append("review destination risk") }
    return parts.isEmpty ? "Address is enabled, reviewed, and normal-risk." : parts.joined(separator: ", ")
  }

  private func sourceColor(for tone: String) -> Color {
    switch tone {
    case "spacemail":
      return .teal
    case "gmail":
      return .blue
    case "mock":
      return .purple
    case "microsoft", "mailbox":
      return .blue
    default:
      return .secondary
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

  private func linkedIntakeEmails(for order: TrackedOrder) -> [ForwardedEmailIntake] {
    let orderNumber = order.orderNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    return store.intakeEmails.filter { email in
      email.linkedOrderID == order.id
        || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.detectedOrderNumber.localizedCaseInsensitiveContains(orderNumber))
        || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.subject.localizedCaseInsensitiveContains(orderNumber))
        || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.rawBodyPreview.localizedCaseInsensitiveContains(orderNumber))
    }
  }

  private func destinationAddressSearchParts(_ address: DestinationAddressRecord) -> [String] {
    let profile = address.customerProfileID.flatMap { profileID in
      store.customerRecipientProfiles.first { $0.id == profileID }
    }
    let instructions = store.suggestedDeliveryInstructions(for: address)
    let packageContents = store.suggestedPackageContents(for: address)
    var parts = [
      address.id.uuidString,
      address.label,
      address.customerProfileID?.uuidString ?? "",
      address.organisationTeam,
      address.addressLineSummary,
      address.cityRegion,
      address.country,
      address.deliveryInstructions,
      address.accessNotes,
      address.preferredCarrier,
      address.riskLevel.rawValue,
      address.isEnabled ? "Enabled" : "Disabled",
      address.createdDate,
      address.lastReviewedDate,
      address.reviewState.rawValue,
      profile?.displayName ?? "",
      profile?.primaryEmail ?? ""
    ]
    parts.append(contentsOf: instructions.flatMap { [$0.title, $0.instructionSummary, $0.accessConstraintSummary, $0.carrierNotes] })
    parts.append(contentsOf: packageContents.flatMap { [$0.title, $0.itemSummary, $0.discrepancySummary] })
    return parts
  }
}

struct DestinationAddressRow: View {
  var address: DestinationAddressRecord
  var store: ParcelOpsStore? = nil
  var inboxOrders: [TrackedOrder] = []
  var customerProfiles: [CustomerRecipientProfile] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var onSave: (DestinationAddressRecord) -> Void
  var onToggle: () -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false
  @State private var feedbackMessage: String?

  private var linkedProfile: CustomerRecipientProfile? {
    guard let id = address.customerProfileID else { return nil }
    return customerProfiles.first { $0.id == id }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "mappin.and.ellipse")
          .foregroundStyle(address.riskLevel.color)
          .frame(width: 28, height: 28)
        VStack(alignment: .leading, spacing: 5) {
          Text(address.label)
            .font(.headline)
          Text("\(address.addressLineSummary), \(address.cityRegion), \(address.country)")
            .foregroundStyle(.secondary)
          Text("\(address.deliveryInstructions) \(address.accessNotes)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 6) {
          Badge(address.riskLevel.rawValue, color: address.riskLevel.color)
          Badge(address.isEnabled ? "Enabled" : "Disabled", color: address.isEnabled ? .green : .gray)
          Badge(address.reviewState.rawValue, color: address.reviewState.color)
        }
      }

      HStack(spacing: 8) {
        Label(address.organisationTeam, systemImage: "person.2.fill")
        Label(address.preferredCarrier, systemImage: "truck.box.fill")
        if let linkedProfile {
          Label(linkedProfile.displayName, systemImage: "person.text.rectangle.fill")
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      if !inboxOrders.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Label("Inbox destination source", systemImage: "tray.and.arrow.down.fill")
            .font(.caption.bold())
            .foregroundStyle(.teal)
          ForEach(inboxOrders.prefix(2)) { order in
            HStack(spacing: 6) {
              Badge(order.orderNumber, color: order.orderNumber.isPlaceholderValidationValue ? .orange : .blue)
              Badge(order.destination.isPlaceholderValidationValue ? "Destination needs review" : "Destination present", color: order.destination.isPlaceholderValidationValue ? .orange : .green)
              Text(order.destination)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
          }
          if let store {
            ForEach(sourceEmails(using: store).prefix(2)) { email in
              HStack(spacing: 6) {
                let source = store.intakeSourceSummary(for: email)
                Badge(source.label, color: sourceColor(for: source.tone))
                Text(email.subject)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
            }
          }
        }
      }

      if !addressWarnings.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Label("Destination follow-up", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.bold())
            .foregroundStyle(.orange)
          ForEach(addressWarnings, id: \.self) { warning in
            Text(warning)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      if let feedbackMessage {
        DestinationAddressActionFeedbackPanel(message: feedbackMessage, store: store)
      }

      CompactActionRow {
        Button("Edit", systemImage: "pencil") { isEditing = true }
          .buttonStyle(.bordered)
        Button(address.isEnabled ? "Disable" : "Enable", systemImage: address.isEnabled ? "pause.circle" : "play.circle") {
          onToggle()
          feedbackMessage = address.isEnabled ? "Destination address disabled locally." : "Destination address enabled locally."
        }
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.circle.fill") {
          onReviewed()
          feedbackMessage = "Destination address marked reviewed locally."
        }
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Follow-up task created from destination address. Check Tasks."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Draft created from destination address. Check Drafts."
        }
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", role: .destructive) {
          onRemove()
          feedbackMessage = "Destination address removed locally."
        }
          .buttonStyle(.bordered)
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
    .sheet(isPresented: $isEditing) {
      DestinationAddressEditView(address: address, customerProfiles: customerProfiles) { updatedAddress in
        onSave(updatedAddress)
        feedbackMessage = "Destination address saved locally."
        isEditing = false
      }
    }
  }

  private var addressWarnings: [String] {
    var warnings: [String] = []
    if !address.isEnabled && !inboxOrders.isEmpty {
      warnings.append("This address matches an Inbox-created order but is disabled.")
    }
    if address.reviewState != .accepted && !inboxOrders.isEmpty {
      warnings.append("Address needs review before relying on it for dispatch or delivery handoff.")
    }
    if (address.riskLevel == .high || address.riskLevel == .critical) && !inboxOrders.isEmpty {
      warnings.append("Destination risk is \(address.riskLevel.rawValue.lowercased()); confirm access notes and delivery constraints.")
    }
    if address.addressLineSummary.isPlaceholderValidationValue && !inboxOrders.isEmpty {
      warnings.append("Address line summary needs confirmation.")
    }
    return warnings
  }

  private func sourceEmails(using store: ParcelOpsStore) -> [ForwardedEmailIntake] {
    var seen = Set<UUID>()
    return inboxOrders.flatMap { order -> [ForwardedEmailIntake] in
      let orderNumber = order.orderNumber.trimmingCharacters(in: .whitespacesAndNewlines)
      return store.intakeEmails.filter { email in
        email.linkedOrderID == order.id
          || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.detectedOrderNumber.localizedCaseInsensitiveContains(orderNumber))
          || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.subject.localizedCaseInsensitiveContains(orderNumber))
          || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.rawBodyPreview.localizedCaseInsensitiveContains(orderNumber))
      }
    }.filter { seen.insert($0.id).inserted }
  }

  private func sourceColor(for tone: String) -> Color {
    switch tone {
    case "spacemail": return .teal
    case "gmail": return .blue
    case "mock": return .purple
    case "microsoft", "mailbox": return .blue
    default: return .secondary
    }
  }
}

private struct DestinationAddressActionFeedbackPanel: View {
  var message: String
  var store: ParcelOpsStore?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(message, systemImage: "checkmark.circle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.green)
      Text("This is local address book tracking only. No address validation, geocoding, map lookup, carrier call, or external service was used.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if let store {
        CompactActionRow {
          if message.localizedCaseInsensitiveContains("task") {
            NavigationLink {
              TasksView(store: store)
            } label: {
              Label("Open Tasks", systemImage: "checklist")
            }
          }
          if message.localizedCaseInsensitiveContains("draft") {
            NavigationLink {
              CommunicationView(store: store)
            } label: {
              Label("Open Drafts", systemImage: "envelope.open.fill")
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
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.green.opacity(0.10))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct DestinationAddressEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: DestinationAddressRecord
  var customerProfiles: [CustomerRecipientProfile]
  var onSave: (DestinationAddressRecord) -> Void

  init(address: DestinationAddressRecord, customerProfiles: [CustomerRecipientProfile], onSave: @escaping (DestinationAddressRecord) -> Void) {
    _draft = State(initialValue: address)
    self.customerProfiles = customerProfiles
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        TextField("Label", text: $draft.label)
        Picker("Customer profile", selection: $draft.customerProfileID) {
          Text("No linked profile").tag(UUID?.none)
          ForEach(customerProfiles) { profile in
            Text(profile.displayName).tag(Optional(profile.id))
          }
        }
        TextField("Organisation/team", text: $draft.organisationTeam)
        TextField("Address line summary", text: $draft.addressLineSummary, axis: .vertical)
        TextField("City/region", text: $draft.cityRegion)
        TextField("Country", text: $draft.country)
        TextField("Preferred carrier", text: $draft.preferredCarrier)
        Picker("Risk", selection: $draft.riskLevel) {
          ForEach(ShipmentRiskLevel.allCases) { risk in Text(risk.rawValue).tag(risk) }
        }
        Toggle("Enabled", isOn: $draft.isEnabled)
        Picker("Review state", selection: $draft.reviewState) {
          ForEach([ReviewState.needsReview, .monitor, .accepted], id: \.self) { state in
            Text(state.rawValue).tag(state)
          }
        }
        TextField("Delivery instructions", text: $draft.deliveryInstructions, axis: .vertical)
        TextField("Access notes", text: $draft.accessNotes, axis: .vertical)
      }
      .navigationTitle("Edit Destination")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(draft) } }
      }
      .frame(minWidth: 500, minHeight: 560)
    }
  }
}
