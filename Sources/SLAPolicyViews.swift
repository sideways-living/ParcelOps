import SwiftUI

struct SLAPoliciesView: View {
  var store: ParcelOpsStore

  @State private var selectedEnabledState: Bool?
  @State private var selectedPriority: TaskPriority?
  @State private var selectedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedReviewState: ReviewState?
  @State private var policySearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var baseFilteredPolicies: [SLAPolicy] {
    store.slaPolicies.filter { policy in
      let matchesEnabled = selectedEnabledState == nil || policy.isEnabled == selectedEnabledState
      let matchesPriority = selectedPriority == nil || policy.priority == selectedPriority
      let matchesEntity = selectedEntityType == nil || policy.linkedEntityType == selectedEntityType
      let matchesReview = selectedReviewState == nil || policy.reviewState == selectedReviewState
      return matchesEnabled && matchesPriority && matchesEntity && matchesReview
    }
  }

  private var filteredPolicies: [SLAPolicy] {
    let query = policySearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredPolicies }
    return baseFilteredPolicies.filter { policy in
      slaPolicySearchParts(policy).joined(separator: " ").localizedLowercase.contains(query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedEnabledState != nil
      || selectedPriority != nil
      || selectedEntityType != nil
      || selectedReviewState != nil
      || !policySearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("SLA policies")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Local timing and escalation policies for manual review workflows.")
            .foregroundStyle(.secondary)
        }

        filterBar
        inboxPolicyCoverage

        SettingsPanel(title: "Policies", symbol: "timer") {
          HStack {
            Text("\(filteredPolicies.count) visible policies")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredPolicies.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add policy", systemImage: "plus", action: store.addSLAPolicyPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredPolicies.isEmpty {
            MVPEmptyState(title: "No SLA policies match this view", detail: hasActiveFilters ? "Clear search or filters to return to all local SLA policies." : "Add a local SLA policy to define manual timing, review, and escalation expectations.", symbol: "timer", actionTitle: hasActiveFilters ? "Clear filters" : "Add policy", action: hasActiveFilters ? clearFilters : store.addSLAPolicyPlaceholder)
          } else {
            ForEach(filteredPolicies) { policy in
              SLAPolicyRow(policy: policy, store: store, inboxOrders: inboxOrders(for: policy), destinationAddresses: store.suggestedDestinationAddresses(for: policy), deliveryInstructions: store.suggestedDeliveryInstructions(for: policy), packageContents: store.suggestedPackageContents(for: policy)) { updatedPolicy in
                store.updateSLAPolicy(updatedPolicy)
              } onToggle: {
                store.toggleSLAPolicy(policy)
              } onReviewed: {
                store.markSLAPolicyReviewed(policy)
              } onEvaluate: {
                store.evaluateSLAPolicyPlaceholder(policy)
              } onCreateDraft: {
                store.createDraftMessage(from: policy)
              } onCreateContact: {
                store.addContactDirectoryEntry(linkedEntityType: .slaPolicy, linkedEntityID: policy.id.uuidString, label: policy.name)
              } onRemove: {
                store.removeSLAPolicy(policy)
              }
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search policy, condition, target, priority, record, linked address, or instruction", text: $policySearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Enabled", selection: $selectedEnabledState) {
        Text("All states").tag(nil as Bool?)
        Text("Enabled").tag(true as Bool?)
        Text("Disabled").tag(false as Bool?)
      }

      Picker("Priority", selection: $selectedPriority) {
        Text("All priorities").tag(nil as TaskPriority?)
        ForEach(TaskPriority.allCases) { priority in
          Text(priority.rawValue).tag(priority as TaskPriority?)
        }
      }

      Picker("Record", selection: $selectedEntityType) {
        Text("All records").tag(nil as ReviewTaskLinkedEntityType?)
        ForEach(ReviewTaskLinkedEntityType.allCases) { entityType in
          Text(entityType.rawValue).tag(entityType as ReviewTaskLinkedEntityType?)
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
    selectedEnabledState = nil
    selectedPriority = nil
    selectedEntityType = nil
    selectedReviewState = nil
    policySearchText = ""
  }

  private var inboxPolicyCoverage: some View {
    let inboxOrders = store.intakeLinkedOrders
    let wishlistOrders = store.wishlistLinkedOrders
    let linkedPolicies = policiesLinkedToInboxOrders
    let actionPolicies = linkedPolicies.filter { !$0.isEnabled || $0.reviewState != .accepted || $0.priority == .high || $0.priority == .urgent }

    return SettingsPanel(title: "Inbox and Wishlist SLA readiness", symbol: "timer") {
      VStack(alignment: .leading, spacing: 10) {
        Text("Checks whether orders created from Inbox intake or Wishlist purchase handoff have local response, resolution, or escalation policy context. Policies remain manual guidance only.")
          .font(.caption)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 150) {
          Badge("\(store.intakeLinkedOrderCount) Inbox orders", color: .blue)
          Badge("\(store.wishlistLinkedOrderCount) Wishlist orders", color: .pink)
          Badge("\(linkedPolicies.count) matched policies", color: .teal)
          Badge("\(actionPolicies.count) need action", color: actionPolicies.isEmpty ? .green : .orange)
          Badge("\(store.policiesNeedingReview.count) review", color: store.policiesNeedingReview.isEmpty ? .green : .orange)
        }

        if !slaProviderRows.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Mailbox source for SLA policies")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
              ForEach(slaProviderRows, id: \.label) { row in
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

        if inboxOrders.isEmpty && wishlistOrders.isEmpty {
          Text("No Inbox-created or Wishlist-linked orders are present yet. Create an order from Inbox or complete a Wishlist purchase handoff before checking SLA coverage.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if linkedPolicies.isEmpty {
          Text("No SLA policies currently match Inbox-created or Wishlist-linked orders by linked record type or condition wording.")
            .font(.caption)
            .foregroundStyle(.orange)
        } else if actionPolicies.isEmpty {
          Text("Matched SLA policies are enabled, reviewed, and ready as local operator guidance.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          ForEach(Array(actionPolicies.prefix(3))) { policy in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: policy.isEnabled ? "timer" : "pause.circle.fill")
                .foregroundStyle(policy.isEnabled ? .orange : .red)
              VStack(alignment: .leading, spacing: 2) {
                Text(policy.name)
                  .font(.caption.bold())
                Text(policyActionSummary(for: policy))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Badge(policy.priority.rawValue, color: policy.priority.color)
            }
          }
        }
      }
    }
  }

  private var slaProviderRows: [(label: String, count: Int, detail: String, symbol: String, color: Color)] {
    var counts: [String: Int] = [:]
    var tones: [String: String] = [:]
    for order in store.intakeLinkedOrders {
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
        detail = "SpaceMail intake can suggest local response, resolution, and escalation policy context for Inbox-created orders."
      case "gmail":
        detail = "Gmail intake can suggest local response, resolution, and escalation policy context for Inbox-created orders."
      case "mock":
        detail = "Mock mailbox intake supports local SLA testing. Confirm live provider context before relying on policy guidance."
      default:
        detail = "Local mailbox intake can suggest SLA policy context once linked to an order."
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




  private var policiesLinkedToInboxOrders: [SLAPolicy] {
    store.slaPolicies.filter { policy in
      store.operatorSourceOrders.contains { order in
        slaPolicy(policy, matches: order)
      }
    }
  }

  private func inboxOrders(for policy: SLAPolicy) -> [TrackedOrder] {
    store.operatorSourceOrders.filter { slaPolicy(policy, matches: $0) }
  }


  private func slaPolicy(_ policy: SLAPolicy, matches order: TrackedOrder) -> Bool {
    if policy.linkedEntityType == .order { return true }
    let searchable = [policy.conditionSummary, policy.responseTarget, policy.resolutionTarget, policy.name].joined(separator: " ")
    return searchable.localizedCaseInsensitiveContains(order.store)
      || searchable.localizedCaseInsensitiveContains(order.carrier)
      || searchable.localizedCaseInsensitiveContains(order.status.rawValue)
      || searchable.localizedCaseInsensitiveContains("inbox")
      || searchable.localizedCaseInsensitiveContains("tracking")
      || searchable.localizedCaseInsensitiveContains("dispatch")
  }

  private func policyActionSummary(for policy: SLAPolicy) -> String {
    var parts: [String] = []
    if !policy.isEnabled { parts.append("enable or confirm disabled policy") }
    if policy.reviewState != .accepted { parts.append("mark reviewed") }
    if policy.priority == .high || policy.priority == .urgent { parts.append("confirm escalation priority") }
    return parts.isEmpty ? "Policy is enabled and reviewed." : parts.joined(separator: ", ")
  }


  private func slaPolicySearchParts(_ policy: SLAPolicy) -> [String] {
    var parts = [
      policy.id.uuidString,
      policy.name,
      policy.linkedEntityType.rawValue,
      policy.conditionSummary,
      policy.responseTarget,
      policy.resolutionTarget,
      policy.priority.rawValue,
      policy.isEnabled ? "Enabled" : "Disabled",
      policy.createdDate,
      policy.lastEvaluatedDate,
      "\(policy.matchCount)",
      policy.reviewState.rawValue
    ]
    parts.append(contentsOf: store.suggestedDestinationAddresses(for: policy).flatMap { [$0.label, $0.addressLineSummary, $0.cityRegion, $0.preferredCarrier] })
    parts.append(contentsOf: store.suggestedDeliveryInstructions(for: policy).flatMap { [$0.title, $0.instructionSummary, $0.accessConstraintSummary, $0.carrierNotes] })
    parts.append(contentsOf: store.suggestedPackageContents(for: policy).flatMap { [$0.title, $0.itemSummary, $0.discrepancySummary] })
    return parts
  }
}

struct SLAPolicyRow: View {
  var policy: SLAPolicy
  var store: ParcelOpsStore? = nil
  var inboxOrders: [TrackedOrder] = []
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var onSave: (SLAPolicy) -> Void
  var onToggle: () -> Void
  var onReviewed: () -> Void
  var onEvaluate: () -> Void
  var onCreateDraft: () -> Void = {}
  var onCreateContact: () -> Void = {}
  var onRemove: () -> Void
  @State private var isEditing = false
  @State private var feedbackMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: policy.linkedEntityType.symbol)
          .foregroundStyle(policy.priority.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(policy.name)
                .font(.headline)
              Text("\(policy.linkedEntityType.rawValue) • last evaluated \(policy.lastEvaluatedDate)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(policy.priority.rawValue, color: policy.priority.color)
          }

          Text(policy.conditionSummary)
            .foregroundStyle(.secondary)

          HStack(spacing: 8) {
            Badge(policy.isEnabled ? "Enabled" : "Disabled", color: policy.isEnabled ? .green : .gray)
            Badge(policy.reviewState.rawValue, color: policy.reviewState.color)
            Text("Response: \(policy.responseTarget)")
              .font(.caption)
              .foregroundStyle(.secondary)
            Text("Resolution: \(policy.resolutionTarget)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Text("\(policy.matchCount) local matches")
            .font(.caption)
            .foregroundStyle(.secondary)

          if !destinationAddresses.isEmpty {
            DestinationAddressStrip(addresses: destinationAddresses)
          }
          if !deliveryInstructions.isEmpty {
            DeliveryInstructionStrip(instructions: deliveryInstructions)
          }
          if !packageContents.isEmpty {
            PackageContentStrip(contents: packageContents)
          }

          if !inboxOrders.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
              Label("Inbox/Wishlist SLA source", systemImage: "tray.and.arrow.down.fill")
                .font(.caption.bold())
                .foregroundStyle(.teal)
              ForEach(inboxOrders.prefix(2)) { order in
                HStack(spacing: 6) {
                  Badge(order.orderNumber, color: order.orderNumber.isPlaceholderValidationValue ? .orange : .blue)
                  Badge(order.status.rawValue, color: order.status.color)
                  Text(order.trackingNumber)
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

          if !policyWarnings.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
              Label("SLA follow-up", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.bold())
                .foregroundStyle(.orange)
              ForEach(policyWarnings, id: \.self) { warning in
                Text(warning)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
      }

      if let feedbackMessage {
        SLAPolicyActionFeedbackPanel(message: feedbackMessage)
      }

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button(policy.isEnabled ? "Disable" : "Enable", systemImage: policy.isEnabled ? "pause.circle.fill" : "play.circle.fill") {
          onToggle()
          feedbackMessage = policy.isEnabled
            ? "SLA policy disabled locally. It remains available for review but should not guide operator follow-up."
            : "SLA policy enabled locally. Review response and escalation targets before relying on it operationally."
        }
          .buttonStyle(.bordered)
        Button("Evaluate", systemImage: "timer") {
          onEvaluate()
          feedbackMessage = "SLA policy evaluated locally against current ParcelOps records. No background job, notification, or external service ran."
        }
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.circle.fill") {
          onReviewed()
          feedbackMessage = "SLA policy marked reviewed locally. Confirm targets still match the manual operating process."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Draft message created from this SLA policy. It remains local until a person sends anything outside ParcelOps."
        }
          .buttonStyle(.bordered)
        Button("Contact", systemImage: "person.crop.circle.badge.plus") {
          onCreateContact()
          feedbackMessage = "Contact placeholder created from this SLA policy for local escalation reference."
        }
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash") {
          onRemove()
          feedbackMessage = "SLA policy removed locally. No notifications, calendars, or automation were changed."
        }
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      SLAPolicyEditView(policy: policy) { updatedPolicy in
        onSave(updatedPolicy)
        feedbackMessage = "SLA policy details saved locally. Recheck priority, targets, and review state before using it in daily flow."
      }
    }
  }

  private var policyWarnings: [String] {
    var warnings: [String] = []
    if !policy.isEnabled && !inboxOrders.isEmpty {
      warnings.append("This SLA policy matches Inbox-created or Wishlist-linked order context but is disabled.")
    }
    if policy.reviewState != .accepted && !inboxOrders.isEmpty {
      warnings.append("Policy needs review before relying on it for local response or escalation guidance.")
    }
    if (policy.priority == .high || policy.priority == .urgent) && !inboxOrders.isEmpty {
      warnings.append("Policy priority is \(policy.priority.rawValue.lowercased()); confirm manual escalation path.")
    }
    return warnings
  }

  private func sourceEmails(using store: ParcelOpsStore) -> [ForwardedEmailIntake] {
    var seen = Set<UUID>()
    return inboxOrders.flatMap { order -> [ForwardedEmailIntake] in
      return store.linkedIntakeEmails(for: order)
    }.filter { seen.insert($0.id).inserted }
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
}

private struct SLAPolicyActionFeedbackPanel: View {
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

struct SLAPolicyEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: SLAPolicy
  var onSave: (SLAPolicy) -> Void

  init(policy: SLAPolicy, onSave: @escaping (SLAPolicy) -> Void) {
    self._draft = State(initialValue: policy)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Policy") {
          TextField("Name", text: $draft.name)
          Picker("Linked record type", selection: $draft.linkedEntityType) {
            ForEach(ReviewTaskLinkedEntityType.allCases) { entityType in
              Text(entityType.rawValue).tag(entityType)
            }
          }
          TextField("Condition summary", text: $draft.conditionSummary, axis: .vertical)
            .lineLimit(3...6)
        }

        Section("Targets") {
          TextField("Response target", text: $draft.responseTarget)
          TextField("Resolution target", text: $draft.resolutionTarget)
          Picker("Priority", selection: $draft.priority) {
            ForEach(TaskPriority.allCases) { priority in
              Text(priority.rawValue).tag(priority)
            }
          }
        }

        Section("State") {
          Toggle("Enabled", isOn: $draft.isEnabled)
          TextField("Created date", text: $draft.createdDate)
          TextField("Last evaluated", text: $draft.lastEvaluatedDate)
          Stepper("Matches: \(draft.matchCount)", value: $draft.matchCount, in: 0...999)
          Picker("Review state", selection: $draft.reviewState) {
            Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted)
            Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview)
            Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor)
          }
        }
      }
      .navigationTitle("Edit SLA policy")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            onSave(draft)
            dismiss()
          }
        }
      }
      #if os(macOS)
      .frame(minWidth: 560, minHeight: 620)
      #endif
    }
  }
}
