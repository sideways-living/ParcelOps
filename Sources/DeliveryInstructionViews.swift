import SwiftUI

struct DeliveryInstructionsView: View {
  var store: ParcelOpsStore
  @State private var selectedType: DeliveryInstructionType?
  @State private var selectedProfileID: UUID?
  @State private var selectedCarrierContext: String?
  @State private var selectedRiskLevel: ShipmentRiskLevel?
  @State private var selectedEnabledState: Bool?
  @State private var selectedReviewState: ReviewState?
  @State private var instructionSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var carrierContexts: [String] {
    Array(Set(store.deliveryInstructions.map(\.carrierNotes).filter { !$0.isEmpty })).sorted()
  }

  private var baseFilteredInstructions: [DeliveryInstructionRecord] {
    store.filteredDeliveryInstructions(
      instructionType: selectedType,
      profileID: selectedProfileID,
      carrierContext: selectedCarrierContext,
      riskLevel: selectedRiskLevel,
      isEnabled: selectedEnabledState,
      reviewState: selectedReviewState
    )
  }

  private var filteredInstructions: [DeliveryInstructionRecord] {
    let query = instructionSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredInstructions }
    return baseFilteredInstructions.filter { instruction in
      deliveryInstructionSearchParts(instruction).joined(separator: " ").localizedLowercase.contains(query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedType != nil
      || selectedProfileID != nil
      || selectedCarrierContext != nil
      || selectedRiskLevel != nil
      || selectedEnabledState != nil
      || selectedReviewState != nil
      || !instructionSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filterBar
        inboxInstructionCoverage
        gmailInstructionReadinessPanel

        SettingsPanel(title: "Reusable instructions", symbol: "signpost.right.and.left.fill") {
          HStack {
            Text("\(filteredInstructions.count) visible instructions")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredInstructions.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add instruction", systemImage: "plus", action: store.addDeliveryInstructionPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredInstructions.isEmpty {
            MVPEmptyState(title: "No delivery instructions match this view", detail: hasActiveFilters ? "Clear search or filters to return to all local delivery instructions." : "Add a local instruction to reuse delivery windows, access constraints, and carrier notes.", symbol: "signpost.right.and.left.fill", actionTitle: hasActiveFilters ? "Clear filters" : "Add instruction", action: hasActiveFilters ? clearFilters : store.addDeliveryInstructionPlaceholder)
          } else {
            ForEach(filteredInstructions) { instruction in
              DeliveryInstructionRow(
                instruction: instruction,
                store: store,
                linkedOrder: linkedOrder(for: instruction),
                inboxOrders: inboxOrders(for: instruction),
                destinationAddress: store.destinationAddresses.first { $0.id == instruction.destinationAddressID },
                customerProfile: store.customerRecipientProfiles.first { $0.id == instruction.customerProfileID },
                packageContents: store.suggestedPackageContents(for: instruction)
              ) { updatedInstruction in
                store.updateDeliveryInstruction(updatedInstruction)
              } onToggle: {
                store.toggleDeliveryInstruction(instruction)
              } onReviewed: {
                store.markDeliveryInstructionReviewed(instruction)
              } onCreateTask: {
                store.createReviewTask(from: instruction)
              } onCreateDraft: {
                store.createDraftMessage(from: instruction)
              } onRemove: {
                store.removeDeliveryInstruction(instruction)
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
        Text("Delivery Instructions")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Reusable local delivery windows, access constraints, and carrier notes linked to destinations and operational records.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(store.deliveryInstructionsNeedingReview.count) review", color: .orange)
        Badge("\(store.highRiskDeliveryInstructions.count) high risk", color: .red)
      }
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search title, instruction, access constraint, window, carrier, customer, address, or order", text: $instructionSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Type", selection: $selectedType) {
        Text("All types").tag(nil as DeliveryInstructionType?)
        ForEach(DeliveryInstructionType.allCases) { type in
          Text(type.rawValue).tag(type as DeliveryInstructionType?)
        }
      }

      Picker("Profile", selection: $selectedProfileID) {
        Text("All profiles").tag(nil as UUID?)
        ForEach(store.customerRecipientProfiles) { profile in
          Text(profile.displayName).tag(profile.id as UUID?)
        }
      }

      Picker("Carrier/context", selection: $selectedCarrierContext) {
        Text("All contexts").tag(nil as String?)
        ForEach(carrierContexts, id: \.self) { context in
          Text(context).tag(context as String?)
        }
      }

      Picker("Risk", selection: $selectedRiskLevel) {
        Text("All risk").tag(nil as ShipmentRiskLevel?)
        ForEach(ShipmentRiskLevel.allCases) { risk in
          Text(risk.rawValue).tag(risk as ShipmentRiskLevel?)
        }
      }

      Picker("Enabled", selection: $selectedEnabledState) {
        Text("All states").tag(nil as Bool?)
        Text("Enabled").tag(true as Bool?)
        Text("Disabled").tag(false as Bool?)
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
    selectedType = nil
    selectedProfileID = nil
    selectedCarrierContext = nil
    selectedRiskLevel = nil
    selectedEnabledState = nil
    selectedReviewState = nil
    instructionSearchText = ""
  }

  private var gmailInstructionReadinessPanel: some View {
    VStack(alignment: .leading, spacing: 10) {
      GmailReleaseBoundaryPanel(
        store: store,
        title: "Gmail delivery instruction readiness",
        lead: "Gmail-origin intake should create or update delivery instructions only after Gmail setup is ready and the Inbox order has confirmed destination, carrier, and delivery context.",
        sourceMetricTitle: "Gmail instruction sources",
        sourceCount: gmailInstructionSourceCount,
        boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store tokens, validate addresses, contact carriers, or change delivery instructions automatically."
      )
      Microsoft365ReleaseBoundaryPanel(
        store: store,
        title: "Outlook delivery instruction readiness",
        lead: "Outlook-origin intake should create or update delivery instructions only after Microsoft setup, Graph diagnostics, and confirmed Inbox order context are clear.",
        sourceMetricTitle: "Outlook instruction sources",
        sourceCount: microsoft365InstructionSourceCount,
        boundaryDetail: "Local-only boundary: this panel does not start Microsoft sign-in, request tokens, fetch Outlook messages, validate addresses, contact carriers, or change delivery instructions automatically."
      )
    }
  }

  private var gmailInstructionSourceCount: Int {
    instructionProviderRows
      .filter { $0.label.localizedCaseInsensitiveContains("Gmail") }
      .reduce(0) { total, row in total + row.count }
  }

  private var microsoft365InstructionSourceCount: Int {
    instructionProviderRows
      .filter { $0.label.localizedCaseInsensitiveContains("Microsoft 365") || $0.label.localizedCaseInsensitiveContains("Outlook") }
      .reduce(0) { total, row in total + row.count }
  }

  private func linkedOrder(for instruction: DeliveryInstructionRecord) -> TrackedOrder? {
    guard instruction.linkedEntityType == .order, let orderID = UUID(uuidString: instruction.linkedEntityID) else { return nil }
    return store.orders.first { $0.id == orderID }
  }

  private var inboxInstructionCoverage: some View {
    let sourceOrders = store.operatorSourceOrders
    let linkedInstructions = deliveryInstructionsLinkedToInboxOrders
    let actionInstructions = linkedInstructions.filter { instruction in
      !instruction.isEnabled
        || instruction.reviewState != .accepted
        || instruction.riskLevel == .high
        || instruction.riskLevel == .critical
        || !instruction.accessConstraintSummary.isPlaceholderValidationValue
    }
    let missingCount = inboxOrdersMissingInstruction.count

    return SettingsPanel(title: "Inbox and Wishlist delivery instruction readiness", symbol: "signpost.right.and.left.fill") {
      VStack(alignment: .leading, spacing: 10) {
        Text("Checks whether orders created from Inbox intake or Wishlist purchase handoff have reusable delivery windows, access constraints, and carrier notes before dispatch handoff.")
          .font(.caption)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 150) {
          Badge("\(store.intakeLinkedOrderCount) Inbox orders", color: .blue)
          Badge("\(store.wishlistLinkedOrderCount) Wishlist orders", color: .pink)
          Badge("\(linkedInstructions.count) matched instructions", color: .teal)
          Badge("\(actionInstructions.count) need action", color: actionInstructions.isEmpty ? .green : .orange)
          Badge("\(missingCount) without instruction", color: missingCount == 0 ? .green : .orange)
        }

        if !instructionProviderRows.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Mailbox source for instructions")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
              ForEach(instructionProviderRows, id: \.label) { row in
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

        if sourceOrders.isEmpty {
          Text("No source-created or Wishlist-linked orders are present yet. Create an order from Inbox or complete a Wishlist purchase handoff before checking instruction coverage.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if linkedInstructions.isEmpty {
          Text("No delivery instructions currently match source-created or Wishlist-linked orders by order link, destination, customer profile, or carrier context.")
            .font(.caption)
            .foregroundStyle(.orange)
        } else if actionInstructions.isEmpty {
          Text("Matched delivery instructions are enabled, reviewed, and low-risk for current source-created and Wishlist-linked orders.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          ForEach(Array(actionInstructions.prefix(3))) { instruction in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: instruction.accessConstraintSummary.isPlaceholderValidationValue ? instruction.instructionType.symbol : "lock.trianglebadge.exclamationmark.fill")
                .foregroundStyle(instruction.riskLevel == .high || instruction.riskLevel == .critical ? .red : .orange)
              VStack(alignment: .leading, spacing: 2) {
                Text(instruction.title)
                  .font(.caption.bold())
                Text(instructionActionSummary(for: instruction))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Badge(instruction.riskLevel.rawValue, color: instruction.riskLevel.color)
            }
          }
        }
      }
    }
  }

  private var instructionProviderRows: [(label: String, count: Int, detail: String, symbol: String, color: Color)] {
    var counts: [String: Int] = [:]
    var tones: [String: String] = [:]
    for order in store.operatorSourceOrders {
      for email in store.linkedIntakeEmails(for: order) {
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
        detail = "SpaceMail intake can surface destination, access, and delivery-window hints before dispatch handoff."
      case "gmail":
        detail = "Gmail intake can surface destination, access, and delivery-window hints before dispatch handoff."
      case "mock":
        detail = "Mock mailbox intake supports local instruction testing. Confirm live provider context before relying on constraints."
      default:
        detail = "Local mailbox intake can provide delivery-instruction hints once linked to an order."
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




  private var deliveryInstructionsLinkedToInboxOrders: [DeliveryInstructionRecord] {
    store.deliveryInstructions.filter { instruction in
      store.operatorSourceOrders.contains { order in
        deliveryInstruction(instruction, matches: order)
      }
    }
  }

  private var inboxOrdersMissingInstruction: [TrackedOrder] {
    store.operatorSourceOrders.filter { order in
      !store.deliveryInstructions.contains { instruction in
        deliveryInstruction(instruction, matches: order)
      }
    }
  }

  private func inboxOrders(for instruction: DeliveryInstructionRecord) -> [TrackedOrder] {
    store.operatorSourceOrders.filter { deliveryInstruction(instruction, matches: $0) }
  }

  private func deliveryInstruction(_ instruction: DeliveryInstructionRecord, matches order: TrackedOrder) -> Bool {
    if instruction.linkedEntityType == .order, let linkedID = UUID(uuidString: instruction.linkedEntityID), linkedID == order.id {
      return true
    }

    let addressMatch = instruction.destinationAddressID.flatMap { addressID in
      store.destinationAddresses.first { $0.id == addressID }
    }.map { address in
      let line = address.addressLineSummary.trimmingCharacters(in: .whitespacesAndNewlines)
      let city = address.cityRegion.trimmingCharacters(in: .whitespacesAndNewlines)
      return (!line.isEmpty && !line.isPlaceholderValidationValue && (order.destination.localizedCaseInsensitiveContains(line) || line.localizedCaseInsensitiveContains(order.destination)))
        || (!city.isEmpty && !city.isPlaceholderValidationValue && order.destination.localizedCaseInsensitiveContains(city))
    } ?? false

    let profileMatch = instruction.customerProfileID.flatMap { profileID in
      store.customerRecipientProfiles.first { $0.id == profileID }
    }.map { profile in
      (!profile.primaryEmail.isPlaceholderValidationValue && order.recipientEmail.localizedCaseInsensitiveContains(profile.primaryEmail))
        || (!profile.displayName.isPlaceholderValidationValue && order.customer.localizedCaseInsensitiveContains(profile.displayName))
    } ?? false

    let carrier = instruction.carrierNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    let carrierMatch = !carrier.isEmpty && !carrier.isPlaceholderValidationValue && order.carrier.localizedCaseInsensitiveContains(carrier)
    return addressMatch || profileMatch || carrierMatch
  }

  private func instructionActionSummary(for instruction: DeliveryInstructionRecord) -> String {
    var parts: [String] = []
    if !instruction.isEnabled { parts.append("enable or confirm disabled instruction") }
    if instruction.reviewState != .accepted { parts.append("mark reviewed") }
    if instruction.riskLevel == .high || instruction.riskLevel == .critical { parts.append("review risk") }
    if !instruction.accessConstraintSummary.isPlaceholderValidationValue { parts.append("confirm access constraint") }
    return parts.isEmpty ? "Instruction is enabled, reviewed, and low-risk." : parts.joined(separator: ", ")
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


  private func deliveryInstructionSearchParts(_ instruction: DeliveryInstructionRecord) -> [String] {
    let order = linkedOrder(for: instruction)
    let address = store.destinationAddresses.first { $0.id == instruction.destinationAddressID }
    let profile = store.customerRecipientProfiles.first { $0.id == instruction.customerProfileID }
    let packageContents = store.suggestedPackageContents(for: instruction)
    var parts = [
      instruction.id.uuidString,
      instruction.title,
      instruction.destinationAddressID?.uuidString ?? "",
      instruction.customerProfileID?.uuidString ?? "",
      instruction.linkedEntityType.rawValue,
      instruction.linkedEntityID,
      instruction.instructionType.rawValue,
      instruction.instructionSummary,
      instruction.accessConstraintSummary,
      instruction.preferredDeliveryWindow,
      instruction.restrictedDeliveryWindow,
      instruction.carrierNotes,
      instruction.riskLevel.rawValue,
      instruction.isEnabled ? "Enabled" : "Disabled",
      instruction.createdDate,
      instruction.lastReviewedDate,
      instruction.reviewState.rawValue,
      order?.orderNumber ?? "",
      order?.store ?? "",
      order?.customer ?? "",
      order?.recipientEmail ?? "",
      order?.trackingNumber ?? "",
      order?.carrier ?? "",
      order?.destination ?? "",
      address?.label ?? "",
      address?.addressLineSummary ?? "",
      address?.cityRegion ?? "",
      profile?.displayName ?? "",
      profile?.primaryEmail ?? ""
    ]
    parts.append(contentsOf: packageContents.flatMap { [$0.title, $0.itemSummary, $0.discrepancySummary] })
    if let order {
      let mailboxSummaries = store.mailboxSourceSummaries(for: order)
      parts.append(contentsOf: mailboxSummaries.map(\.providerName))
      parts.append(contentsOf: mailboxSummaries.map(\.mailboxLabel))
      parts.append(contentsOf: mailboxSummaries.map(\.statusLabel))
      parts.append(contentsOf: mailboxSummaries.map(\.detailText))
    }
    return parts
  }
}

struct DeliveryInstructionRow: View {
  var instruction: DeliveryInstructionRecord
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
  var inboxOrders: [TrackedOrder] = []
  var destinationAddress: DestinationAddressRecord?
  var customerProfile: CustomerRecipientProfile?
  var packageContents: [PackageContentRecord] = []
  var onSave: (DeliveryInstructionRecord) -> Void
  var onToggle: () -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false
  @State private var feedbackMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: instruction.instructionType.symbol)
          .foregroundStyle(instruction.riskLevel.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(instruction.title)
                .font(.headline)
              Text("\(instruction.instructionType.rawValue) • \(destinationAddress?.label ?? instruction.linkedEntityType.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(instruction.isEnabled ? "Enabled" : "Disabled", color: instruction.isEnabled ? .green : .gray)
          }

          Text(instruction.instructionSummary)
            .foregroundStyle(.secondary)
          Text(instruction.accessConstraintSummary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          HStack(spacing: 8) {
            Badge(instruction.riskLevel.rawValue, color: instruction.riskLevel.color)
            Badge(instruction.reviewState.rawValue, color: instruction.reviewState.color)
            Label(instruction.linkedEntityType.rawValue, systemImage: instruction.linkedEntityType.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          HStack(spacing: 8) {
            Text("Preferred \(instruction.preferredDeliveryWindow)")
            Text("Restricted \(instruction.restrictedDeliveryWindow)")
            if let customerProfile {
              Text(customerProfile.displayName)
            }
          }
          .font(.caption)
          .foregroundStyle(.secondary)

          Text(instruction.carrierNotes)
            .font(.caption)
            .foregroundStyle(.secondary)
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
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button(instruction.isEnabled ? "Disable" : "Enable", systemImage: instruction.isEnabled ? "pause.circle.fill" : "play.circle.fill") {
          onToggle()
          feedbackMessage = instruction.isEnabled ? "Delivery instruction disabled locally." : "Delivery instruction enabled locally."
        }
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.circle.fill") {
          onReviewed()
          feedbackMessage = "Delivery instruction marked reviewed locally."
        }
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Follow-up task created from delivery instruction. Check Tasks."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Draft created from delivery instruction. Check Drafts."
        }
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash") {
          onRemove()
          feedbackMessage = "Delivery instruction removed locally."
        }
          .buttonStyle(.bordered)
      }

      if let feedbackMessage {
        DeliveryInstructionActionFeedbackPanel(message: feedbackMessage, store: store)
      }

      if !packageContents.isEmpty {
        PackageContentStrip(contents: packageContents)
      }

      if !inboxOrders.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Label("Inbox/Wishlist instruction source", systemImage: "tray.and.arrow.down.fill")
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

      if let store {
        OrderMailboxSourceTrailPanel(
          summaries: mailboxSummaries(using: store),
          title: "Mailbox provider instruction trail",
          symbol: "envelope.badge.shield.half.filled"
        )
      }

      if !instructionWarnings.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Label("Instruction follow-up", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.bold())
            .foregroundStyle(.orange)
          ForEach(instructionWarnings, id: \.self) { warning in
            Text(warning)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      DeliveryInstructionEditView(
        instruction: instruction,
        destinationAddresses: [],
        customerProfiles: []
      ) { updatedInstruction in
        onSave(updatedInstruction)
        feedbackMessage = "Delivery instruction saved locally."
      }
    }
  }

  private var instructionWarnings: [String] {
    var warnings: [String] = []
    if !instruction.isEnabled && !inboxOrders.isEmpty {
      warnings.append("This instruction matches a source-created or Wishlist-linked order but is disabled.")
    }
    if instruction.reviewState != .accepted && !inboxOrders.isEmpty {
      warnings.append("Instruction needs review before relying on it for delivery or dispatch handoff.")
    }
    if (instruction.riskLevel == .high || instruction.riskLevel == .critical) && !inboxOrders.isEmpty {
      warnings.append("Instruction risk is \(instruction.riskLevel.rawValue.lowercased()); confirm delivery handling.")
    }
    if !instruction.accessConstraintSummary.isPlaceholderValidationValue && !inboxOrders.isEmpty {
      warnings.append("Access constraint is present; confirm it before dispatch.")
    }
    return warnings
  }

  private func sourceEmails(using store: ParcelOpsStore) -> [ForwardedEmailIntake] {
    var seen = Set<UUID>()
    return inboxOrders.flatMap { order -> [ForwardedEmailIntake] in
      return store.linkedIntakeEmails(for: order)
    }.filter { seen.insert($0.id).inserted }
  }

  private func mailboxSummaries(using store: ParcelOpsStore) -> [OrderMailboxSourceSummary] {
    var seen = Set<String>()
    return inboxOrders.flatMap { order in
      store.mailboxSourceSummaries(for: order)
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

private struct DeliveryInstructionActionFeedbackPanel: View {
  var message: String
  var store: ParcelOpsStore?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(message, systemImage: "checkmark.circle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.green)
      Text("This is local delivery instruction tracking only. No address validation, carrier call, map lookup, notification, or external service was used.")
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

struct DeliveryInstructionEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: DeliveryInstructionRecord
  var destinationAddresses: [DestinationAddressRecord]
  var customerProfiles: [CustomerRecipientProfile]
  var onSave: (DeliveryInstructionRecord) -> Void

  init(instruction: DeliveryInstructionRecord, destinationAddresses: [DestinationAddressRecord], customerProfiles: [CustomerRecipientProfile], onSave: @escaping (DeliveryInstructionRecord) -> Void) {
    self._draft = State(initialValue: instruction)
    self.destinationAddresses = destinationAddresses
    self.customerProfiles = customerProfiles
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Instruction") {
          TextField("Title", text: $draft.title)
          Picker("Instruction type", selection: $draft.instructionType) {
            ForEach(DeliveryInstructionType.allCases) { type in
              Text(type.rawValue).tag(type)
            }
          }
          TextField("Instruction summary", text: $draft.instructionSummary, axis: .vertical)
          TextField("Access constraint summary", text: $draft.accessConstraintSummary, axis: .vertical)
          TextField("Carrier notes", text: $draft.carrierNotes, axis: .vertical)
        }

        Section("Links") {
          Picker("Linked record type", selection: $draft.linkedEntityType) {
            ForEach(ReviewTaskLinkedEntityType.allCases) { entityType in
              Text(entityType.rawValue).tag(entityType)
            }
          }
          TextField("Linked record ID", text: $draft.linkedEntityID)
        }

        Section("Timing") {
          TextField("Preferred delivery window", text: $draft.preferredDeliveryWindow)
          TextField("Restricted delivery window", text: $draft.restrictedDeliveryWindow)
        }

        Section("State") {
          Picker("Risk", selection: $draft.riskLevel) {
            ForEach(ShipmentRiskLevel.allCases) { risk in
              Text(risk.rawValue).tag(risk)
            }
          }
          Picker("Review state", selection: $draft.reviewState) {
            ForEach([ReviewState.needsReview, .monitor, .accepted], id: \.self) { state in
              Text(state.rawValue).tag(state)
            }
          }
          Toggle("Enabled", isOn: $draft.isEnabled)
          TextField("Last reviewed", text: $draft.lastReviewedDate)
        }
      }
      .navigationTitle("Edit Instruction")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: { dismiss() })
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            onSave(draft)
            dismiss()
          }
        }
      }
    }
    .frame(minWidth: 560, minHeight: 560)
  }
}
