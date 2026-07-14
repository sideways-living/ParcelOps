import SwiftUI

struct ExceptionPlaybooksView: View {
  var store: ParcelOpsStore
  @State private var selectedIssueType: ReconciliationIssueType?
  @State private var selectedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedPriority: TaskPriority?
  @State private var selectedEnabledState: Bool?
  @State private var selectedReviewState: ReviewState?
  @State private var playbookSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.accepted, .needsReview, .monitor]

  private var baseFilteredPlaybooks: [ExceptionPlaybook] {
    store.filteredExceptionPlaybooks(
      issueType: selectedIssueType,
      linkedEntityType: selectedEntityType,
      priority: selectedPriority,
      enabledState: selectedEnabledState,
      reviewState: selectedReviewState
    )
  }

  private var filteredPlaybooks: [ExceptionPlaybook] {
    let query = playbookSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredPlaybooks }
    return baseFilteredPlaybooks.filter { playbook in
      playbookSearchParts(playbook).joined(separator: " ").localizedLowercase.contains(query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedIssueType != nil
      || selectedEntityType != nil
      || selectedPriority != nil
      || selectedEnabledState != nil
      || selectedReviewState != nil
      || !playbookSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 6) {
            Text("Exception playbooks")
              .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
            Text("Reusable local guidance for common parcel, intake, carrier, and reconciliation exceptions.")
              .foregroundStyle(.secondary)
          }
          Spacer()
          Badge("\(store.playbooksNeedingReview.count) review", color: .orange)
        }

        filters
        inboxPlaybookCoverage

        SettingsPanel(title: "Playbooks", symbol: "book.closed.fill") {
          HStack {
            Text("\(filteredPlaybooks.count) visible playbooks")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredPlaybooks.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add playbook", systemImage: "plus", action: store.addExceptionPlaybookPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredPlaybooks.isEmpty {
            MVPEmptyState(title: "No playbooks match this view", detail: hasActiveFilters ? "Clear search or filters to return to all local exception playbooks." : "Add a local playbook to guide staff through common intake, tracking, dispatch, and reconciliation exceptions.", symbol: "book.closed.fill", actionTitle: hasActiveFilters ? "Clear filters" : "Add playbook", action: hasActiveFilters ? clearFilters : store.addExceptionPlaybookPlaceholder)
          } else {
            ForEach(filteredPlaybooks) { playbook in
              ExceptionPlaybookRow(playbook: playbook, store: store, inboxOrders: inboxOrders(for: playbook), handoffNotes: store.handoffNotes(for: playbook), destinationAddresses: store.suggestedDestinationAddresses(for: playbook), deliveryInstructions: store.suggestedDeliveryInstructions(for: playbook), packageContents: store.suggestedPackageContents(for: playbook)) { updatedPlaybook in
                store.updateExceptionPlaybook(updatedPlaybook)
              } onToggle: {
                store.toggleExceptionPlaybook(playbook)
              } onReviewed: {
                store.markExceptionPlaybookReviewed(playbook)
              } onCreateTask: {
                store.createReviewTask(from: playbook)
              } onCreateDraft: {
                store.createDraftMessage(from: playbook)
              } onRemove: {
                store.removeExceptionPlaybook(playbook)
              }
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private var filters: some View {
    FilterControlGrid {
      TextField("Search playbook, trigger, steps, escalation, issue, record, or linked guidance", text: $playbookSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Issue", selection: $selectedIssueType) {
        Text("All issues").tag(nil as ReconciliationIssueType?)
        ForEach(ReconciliationIssueType.allCases) { issueType in
          Text(issueType.rawValue).tag(issueType as ReconciliationIssueType?)
        }
      }
      Picker("Record", selection: $selectedEntityType) {
        Text("All records").tag(nil as ReviewTaskLinkedEntityType?)
        ForEach(ReviewTaskLinkedEntityType.allCases) { entityType in
          Text(entityType.rawValue).tag(entityType as ReviewTaskLinkedEntityType?)
        }
      }
      Picker("Priority", selection: $selectedPriority) {
        Text("All priorities").tag(nil as TaskPriority?)
        ForEach(TaskPriority.allCases) { priority in
          Text(priority.rawValue).tag(priority as TaskPriority?)
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
    selectedIssueType = nil
    selectedEntityType = nil
    selectedPriority = nil
    selectedEnabledState = nil
    selectedReviewState = nil
    playbookSearchText = ""
  }

  private var inboxPlaybookCoverage: some View {
    let inboxOrders = store.intakeLinkedOrders
    let wishlistOrders = store.wishlistLinkedOrders
    let linkedPlaybooks = playbooksLinkedToInboxOrders
    let actionPlaybooks = linkedPlaybooks.filter { !$0.isEnabled || $0.reviewState != .accepted || $0.priority == .high || $0.priority == .urgent }

    return SettingsPanel(title: "Inbox and Wishlist exception readiness", symbol: "book.closed.fill") {
      VStack(alignment: .leading, spacing: 10) {
        Text("Checks whether orders created from Inbox intake or Wishlist purchase handoff have local exception guidance for missing details, tracking, validation, reconciliation, or dispatch problems.")
          .font(.caption)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 150) {
          Badge("\(inboxOrders.count) Inbox orders", color: .blue)
          Badge("\(wishlistOrders.count) Wishlist orders", color: .pink)
          Badge("\(linkedPlaybooks.count) matched playbooks", color: .teal)
          Badge("\(actionPlaybooks.count) need action", color: actionPlaybooks.isEmpty ? .green : .orange)
          Badge("\(store.playbooksNeedingReview.count) review", color: store.playbooksNeedingReview.isEmpty ? .green : .orange)
        }

        if !playbookProviderRows.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Mailbox source for exception playbooks")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
              ForEach(playbookProviderRows, id: \.label) { row in
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
          Text("No Inbox-created or Wishlist-linked orders are present yet. Create an order from Inbox or complete a Wishlist purchase handoff before checking exception playbook coverage.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if linkedPlaybooks.isEmpty {
          Text("No exception playbooks currently match Inbox-created or Wishlist-linked order gaps, tracking issues, or dispatch context.")
            .font(.caption)
            .foregroundStyle(.orange)
        } else if actionPlaybooks.isEmpty {
          Text("Matched playbooks are enabled, reviewed, and ready as local operator guidance.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          ForEach(Array(actionPlaybooks.prefix(3))) { playbook in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: playbook.isEnabled ? playbook.issueType.symbol : "pause.circle.fill")
                .foregroundStyle(playbook.isEnabled ? .orange : .red)
              VStack(alignment: .leading, spacing: 2) {
                Text(playbook.name)
                  .font(.caption.bold())
                Text(playbookActionSummary(for: playbook))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Badge(playbook.priority.rawValue, color: playbook.priority.color)
            }
          }
        }
      }
    }
  }



  private var playbookSourceOrders: [TrackedOrder] {
    store.operatorSourceOrders
  }

  private var playbooksLinkedToInboxOrders: [ExceptionPlaybook] {
    store.exceptionPlaybooks.filter { playbook in
      playbookSourceOrders.contains { order in
        exceptionPlaybook(playbook, matches: order)
      }
    }
  }

  private func inboxOrders(for playbook: ExceptionPlaybook) -> [TrackedOrder] {
    playbookSourceOrders.filter { exceptionPlaybook(playbook, matches: $0) }
  }

  private func exceptionPlaybook(_ playbook: ExceptionPlaybook, matches order: TrackedOrder) -> Bool {
    if playbook.linkedEntityType == .order { return true }
    let missingTracking = order.trackingNumber.isPlaceholderValidationValue
    let missingDestination = order.destination.isPlaceholderValidationValue
    let searchable = [playbook.name, playbook.triggerSummary, playbook.recommendedSteps, playbook.issueType.rawValue].joined(separator: " ")
    return (missingTracking && searchable.localizedCaseInsensitiveContains("tracking"))
      || (missingDestination && searchable.localizedCaseInsensitiveContains("address"))
      || searchable.localizedCaseInsensitiveContains(order.status.rawValue)
      || searchable.localizedCaseInsensitiveContains(order.carrier)
      || searchable.localizedCaseInsensitiveContains("inbox")
      || searchable.localizedCaseInsensitiveContains("dispatch")
      || searchable.localizedCaseInsensitiveContains("validation")
      || searchable.localizedCaseInsensitiveContains("reconciliation")
  }

  private func playbookActionSummary(for playbook: ExceptionPlaybook) -> String {
    var parts: [String] = []
    if !playbook.isEnabled { parts.append("enable or confirm disabled playbook") }
    if playbook.reviewState != .accepted { parts.append("mark reviewed") }
    if playbook.priority == .high || playbook.priority == .urgent { parts.append("confirm escalation path") }
    return parts.isEmpty ? "Playbook is enabled and reviewed." : parts.joined(separator: ", ")
  }


  private var playbookProviderRows: [(label: String, count: Int, detail: String, symbol: String, color: Color)] {
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
        detail = "SpaceMail intake can suggest exception playbook context for order, delivery, tracking, and dispatch issues."
      case "gmail":
        detail = "Gmail intake can suggest exception playbook context for order, delivery, tracking, and dispatch issues."
      case "mock":
        detail = "Mock mailbox intake supports local playbook testing. Confirm live provider context before relying on exception guidance."
      default:
        detail = "Local mailbox intake can suggest exception playbook context once linked to an order."
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
      if lhs.count == rhs.count { return lhs.label < rhs.label }
      return lhs.count > rhs.count
    }
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

  private func playbookSearchParts(_ playbook: ExceptionPlaybook) -> [String] {
    var parts = [
      playbook.id.uuidString,
      playbook.name,
      playbook.issueType.rawValue,
      playbook.linkedEntityType.rawValue,
      playbook.triggerSummary,
      playbook.recommendedSteps,
      playbook.escalationContact,
      playbook.priority.rawValue,
      playbook.isEnabled ? "Enabled" : "Disabled",
      playbook.createdDate,
      playbook.lastReviewedDate,
      "\(playbook.usageCount)",
      playbook.reviewState.rawValue
    ]
    parts.append(contentsOf: store.handoffNotes(for: playbook).flatMap { [$0.title, $0.summary, $0.assignee, $0.notes] })
    parts.append(contentsOf: store.suggestedDestinationAddresses(for: playbook).flatMap { [$0.label, $0.addressLineSummary, $0.cityRegion, $0.preferredCarrier] })
    parts.append(contentsOf: store.suggestedDeliveryInstructions(for: playbook).flatMap { [$0.title, $0.instructionSummary, $0.accessConstraintSummary, $0.carrierNotes] })
    parts.append(contentsOf: store.suggestedPackageContents(for: playbook).flatMap { [$0.title, $0.itemSummary, $0.discrepancySummary] })
    return parts
  }
}

struct ExceptionPlaybookRow: View {
  var playbook: ExceptionPlaybook
  var store: ParcelOpsStore? = nil
  var inboxOrders: [TrackedOrder] = []
  var handoffNotes: [HandoffNote] = []
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var onSave: (ExceptionPlaybook) -> Void
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
        Image(systemName: playbook.issueType.symbol)
          .foregroundStyle(playbook.priority.color)
          .frame(width: 28, height: 28)
        VStack(alignment: .leading, spacing: 5) {
          Text(playbook.name)
            .font(.headline)
          Text("\(playbook.issueType.rawValue) • \(playbook.linkedEntityType.rawValue)")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(playbook.triggerSummary)
            .foregroundStyle(.secondary)
          Text(playbook.recommendedSteps)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 6) {
          Badge(playbook.priority.rawValue, color: playbook.priority.color)
          Badge(playbook.isEnabled ? "Enabled" : "Disabled", color: playbook.isEnabled ? .green : .gray)
          Badge(playbook.reviewState.rawValue, color: playbook.reviewState.color)
        }
      }

      HStack(spacing: 8) {
        Text("Escalate: \(playbook.escalationContact)")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text("Used \(playbook.usageCount)x")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text("Last reviewed \(playbook.lastReviewedDate)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if !handoffNotes.isEmpty {
        HandoffNoteStrip(notes: handoffNotes)
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

      if !inboxOrders.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Label("Inbox/Wishlist exception source", systemImage: "tray.and.arrow.down.fill")
            .font(.caption.bold())
            .foregroundStyle(.teal)
          ForEach(inboxOrders.prefix(2)) { order in
            HStack(spacing: 6) {
              Badge(order.orderNumber, color: order.orderNumber.isPlaceholderValidationValue ? .orange : .blue)
              Badge(order.trackingNumber.isPlaceholderValidationValue ? "Tracking needs review" : "Tracking present", color: order.trackingNumber.isPlaceholderValidationValue ? .orange : .green)
              Text(order.status.rawValue)
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

      if !playbookWarnings.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Label("Playbook follow-up", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.bold())
            .foregroundStyle(.orange)
          ForEach(playbookWarnings, id: \.self) { warning in
            Text(warning)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      if let feedbackMessage {
        ExceptionPlaybookActionFeedbackPanel(message: feedbackMessage)
      }

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button(playbook.isEnabled ? "Disable" : "Enable", systemImage: playbook.isEnabled ? "pause.circle.fill" : "play.circle.fill") {
          onToggle()
          feedbackMessage = playbook.isEnabled
            ? "Exception playbook disabled locally. It remains in reference records but should not guide current operator action."
            : "Exception playbook enabled locally. Confirm escalation and recommended steps before using it with live work."
        }
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.circle.fill") {
          onReviewed()
          feedbackMessage = "Exception playbook marked reviewed locally. No automation, notification, or external escalation was triggered."
        }
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Review task created from this exception playbook for local follow-up."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Draft message created from this playbook. It remains local until a person sends anything outside ParcelOps."
        }
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash") {
          onRemove()
          feedbackMessage = "Exception playbook removed locally. No tasks, automations, or external systems were changed outside ParcelOps."
        }
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      ExceptionPlaybookEditView(playbook: playbook) { updatedPlaybook in
        onSave(updatedPlaybook)
        feedbackMessage = "Exception playbook details saved locally. Recheck trigger summary, recommended steps, and escalation contact."
      }
    }
  }

  private var playbookWarnings: [String] {
    var warnings: [String] = []
    if !playbook.isEnabled && !inboxOrders.isEmpty {
      warnings.append("This playbook matches Inbox-created or Wishlist-linked order context but is disabled.")
    }
    if playbook.reviewState != .accepted && !inboxOrders.isEmpty {
      warnings.append("Playbook needs review before relying on it for operator guidance.")
    }
    if (playbook.priority == .high || playbook.priority == .urgent) && !inboxOrders.isEmpty {
      warnings.append("Playbook priority is \(playbook.priority.rawValue.lowercased()); confirm escalation contact.")
    }
    if playbook.escalationContact.isPlaceholderValidationValue && !inboxOrders.isEmpty {
      warnings.append("Escalation team/person needs confirmation.")
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
    case "spacemail": return .teal
    case "gmail": return .blue
    case "mock": return .purple
    case "microsoft", "mailbox": return .blue
    default: return .secondary
    }
  }
}

private struct ExceptionPlaybookActionFeedbackPanel: View {
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

struct ExceptionPlaybookEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: ExceptionPlaybook
  var onSave: (ExceptionPlaybook) -> Void

  init(playbook: ExceptionPlaybook, onSave: @escaping (ExceptionPlaybook) -> Void) {
    self._draft = State(initialValue: playbook)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Playbook") {
          TextField("Name", text: $draft.name)
          Picker("Issue type", selection: $draft.issueType) {
            ForEach(ReconciliationIssueType.allCases) { issueType in
              Text(issueType.rawValue).tag(issueType)
            }
          }
          Picker("Linked record type", selection: $draft.linkedEntityType) {
            ForEach(ReviewTaskLinkedEntityType.allCases) { entityType in
              Text(entityType.rawValue).tag(entityType)
            }
          }
          Picker("Priority", selection: $draft.priority) {
            ForEach(TaskPriority.allCases) { priority in
              Text(priority.rawValue).tag(priority)
            }
          }
        }

        Section("Guidance") {
          TextField("Trigger summary", text: $draft.triggerSummary, axis: .vertical)
            .lineLimit(3...6)
          TextField("Recommended steps", text: $draft.recommendedSteps, axis: .vertical)
            .lineLimit(4...8)
          TextField("Escalation team/person", text: $draft.escalationContact)
        }

        Section("State") {
          Toggle("Enabled", isOn: $draft.isEnabled)
          TextField("Created date", text: $draft.createdDate)
          TextField("Last reviewed", text: $draft.lastReviewedDate)
          Stepper("Usage: \(draft.usageCount)", value: $draft.usageCount, in: 0...999)
          Picker("Review state", selection: $draft.reviewState) {
            Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted)
            Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview)
            Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor)
          }
        }
      }
      .navigationTitle("Edit playbook")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            onSave(draft)
            dismiss()
          }
        }
      }
    }
    .frame(minWidth: 540, minHeight: 620)
  }
}
