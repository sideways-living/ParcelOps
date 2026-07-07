import SwiftUI

struct HandoffNotesView: View {
  var store: ParcelOpsStore
  @State private var selectedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedPriority: TaskPriority?
  @State private var selectedAssignee: String?
  @State private var selectedStatus: TaskStatus?
  @State private var selectedReviewState: ReviewState?
  @State private var handoffSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var assignees: [String] {
    Array(Set(store.handoffNotes.map(\.assignee))).sorted()
  }

  private var baseFilteredNotes: [HandoffNote] {
    store.filteredHandoffNotes(
      linkedEntityType: selectedEntityType,
      priority: selectedPriority,
      assignee: selectedAssignee,
      status: selectedStatus,
      reviewState: selectedReviewState
    )
  }

  private var filteredNotes: [HandoffNote] {
    let query = handoffSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredNotes }
    return baseFilteredNotes.filter { note in
      handoffNote(note, matches: query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedEntityType != nil
      || selectedPriority != nil
      || selectedAssignee != nil
      || selectedStatus != nil
      || selectedReviewState != nil
      || !handoffSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 10) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
              Text("Handoff Notes")
                .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
              Text("Local shift notes and operational handoffs for records that need continuity between teams.")
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge("\(store.handoffNotesNeedingAttention.count) attention", color: .orange)
          }

          CompactActionRow {
            NavigationLink {
              TasksView(store: store)
            } label: {
              Label("Open Tasks", systemImage: "checklist")
            }
            NavigationLink {
              OperationsWorkbenchView(store: store)
            } label: {
              Label("Open Workbench", systemImage: "rectangle.stack.badge.person.crop.fill")
            }
            NavigationLink {
              AuditView(store: store)
            } label: {
              Label("Open Audit", systemImage: "list.clipboard.fill")
            }
          }
          .buttonStyle(.bordered)
        }

        providerHandoffPacketPanel
        filters
        inboxHandoffCoverage

        SettingsPanel(title: "Notes", symbol: "arrow.left.arrow.right.square.fill") {
          HStack {
            Text("\(filteredNotes.count) visible handoff notes")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredNotes.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add note", systemImage: "plus", action: store.addHandoffNotePlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredNotes.isEmpty {
            MVPEmptyState(title: "No handoff notes match this view", detail: hasActiveFilters ? "Clear search or filters to return to open local handoff notes." : "Add a local handoff note when a shift, team, or operator needs continuity on an order or exception.", symbol: "arrow.left.arrow.right.square.fill", actionTitle: hasActiveFilters ? "Clear filters" : "Add note", action: hasActiveFilters ? clearFilters : store.addHandoffNotePlaceholder)
          } else {
            ForEach(filteredNotes) { note in
              HandoffNoteRow(note: note, store: store, linkedOrder: linkedOrder(for: note), customerProfiles: store.suggestedCustomerProfiles(for: note), destinationAddresses: store.suggestedDestinationAddresses(for: note), deliveryInstructions: store.suggestedDeliveryInstructions(for: note), packageContents: store.suggestedPackageContents(for: note)) { updatedNote in
                store.updateHandoffNote(updatedNote)
              } onAcknowledge: {
                store.acknowledgeHandoffNote(note)
              } onComplete: {
                store.completeHandoffNote(note)
              } onReopen: {
                store.reopenHandoffNote(note)
              } onReviewed: {
                store.markHandoffNoteReviewed(note)
              } onCreateTask: {
                store.createReviewTask(from: note)
              } onCreateDraft: {
                store.createDraftMessage(from: note)
              } onRemove: {
                store.removeHandoffNote(note)
              }
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private var providerHandoffPacketPanel: some View {
    let packet = store.mailboxProviderHandoffPacketSummary
    let color = handoffToneColor(packet.tone)
    let activeProviderNotes = store.handoffNotes.filter { note in
      note.linkedEntityType == .integration
        && note.linkedEntityID == "mailbox-provider-handoff-packet"
        && note.status != .completed
    }

    return SettingsPanel(title: "Mailbox provider handoff", symbol: "checkmark.seal.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: packet.tone == "success" ? "checkmark.seal.fill" : packet.tone == "warning" ? "exclamationmark.triangle.fill" : "arrow.left.arrow.right.square.fill")
            .foregroundStyle(color)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(packet.title)
              .font(.headline)
            Text(packet.detail)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Badge(packet.tone == "success" ? "Ready" : packet.tone == "warning" ? "Blocked" : "Review", color: color)
        }

        MetricStrip(items: packet.metrics.map { metric in
          (metric.title, metric.value, handoffToneColor(metric.tone))
        })

        if !activeProviderNotes.isEmpty {
          Label("\(activeProviderNotes.count) active provider handoff note\(activeProviderNotes.count == 1 ? "" : "s") already exist. The action below refreshes the current note instead of creating duplicates.", systemImage: "checkmark.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
            .fixedSize(horizontal: false, vertical: true)
        } else {
          Text("Create one handoff note when the next operator or shift needs the provider state, open queue items, release blockers, and mailbox boundaries in one place.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        if !packet.sections.isEmpty {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 190 : 250), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(packet.sections.prefix(3), id: \.title) { section in
              VStack(alignment: .leading, spacing: 6) {
                Label(section.title, systemImage: section.symbol)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(handoffToneColor(section.tone))
                Text(section.detail)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
                if let line = section.lines.first {
                  Text(line)
                    .font(.caption2)
                    .foregroundStyle(handoffToneColor(section.tone))
                    .fixedSize(horizontal: false, vertical: true)
                }
              }
              .padding(10)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(handoffToneColor(section.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }

        CompactActionRow {
          Button(activeProviderNotes.isEmpty ? "Create provider handoff" : "Refresh provider handoff", systemImage: "arrow.left.arrow.right.square.fill") {
            store.createHandoffNoteFromMailboxProviderHandoffPacket()
          }
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Mailbox Monitor", systemImage: "server.rack")
          }
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Tasks", systemImage: "checklist")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private var filters: some View {
    FilterControlGrid {
      TextField("Search title, summary, linked record, assignee, notes, order, or destination", text: $handoffSearchText)
        .textFieldStyle(.roundedBorder)

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
      Picker("Assignee", selection: $selectedAssignee) {
        Text("All assignees").tag(nil as String?)
        ForEach(assignees, id: \.self) { assignee in
          Text(assignee).tag(assignee as String?)
        }
      }
      Picker("Status", selection: $selectedStatus) {
        Text("All statuses").tag(nil as TaskStatus?)
        ForEach(TaskStatus.allCases) { status in
          Text(status.rawValue).tag(status as TaskStatus?)
        }
      }
      Picker("Review", selection: $selectedReviewState) {
        Text("All review").tag(nil as ReviewState?)
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
    selectedPriority = nil
    selectedAssignee = nil
    selectedStatus = nil
    selectedReviewState = nil
    handoffSearchText = ""
  }

  private var inboxHandoffCoverage: some View {
    let inboxOrders = inboxCreatedOrders
    let linkedNotes = handoffNotesLinkedToInboxOrders
    let actionNotes = handoffNotesNeedingSourceAction
    let missingCount = inboxOrdersMissingHandoff.count

    return SettingsPanel(title: "Inbox handoff readiness", symbol: "arrow.left.arrow.right.square.fill") {
      VStack(alignment: .leading, spacing: 10) {
        Text("Checks whether orders created from Inbox intake have a local shift/team note when continuity is needed.")
          .font(.caption)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 150) {
          Badge("\(inboxOrders.count) Inbox orders", color: .blue)
          Badge("\(linkedNotes.count) linked notes", color: .teal)
          Badge("\(actionNotes.count) need action", color: actionNotes.isEmpty ? .green : .orange)
          Badge("\(missingCount) without handoff", color: missingCount == 0 ? .green : .orange)
        }

        if !handoffProviderRows.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Mailbox source for handoffs")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
              ForEach(handoffProviderRows, id: \.label) { row in
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
          Text("No Inbox-created orders are present yet. Create an order from Inbox before tracking handoff coverage.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if linkedNotes.isEmpty {
          Text("Inbox-created orders do not have handoff notes yet. Add a note when another team or shift needs context.")
            .font(.caption)
            .foregroundStyle(.orange)
        } else {
          ForEach(Array(actionNotes.prefix(3))) { note in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: note.isLocallyOverdue ? "clock.badge.exclamationmark.fill" : "arrow.left.arrow.right.square.fill")
                .foregroundStyle(note.isLocallyOverdue ? .red : .orange)
              VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                  .font(.caption.bold())
                Text(handoffActionSummary(for: note))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Badge(note.status.rawValue, color: note.status.color)
            }
          }

          if actionNotes.isEmpty {
            Text("Linked handoff notes look assigned, current, reviewed, and closed or actively monitored for Inbox-created orders.")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else if actionNotes.count > 3 {
            Text("\(actionNotes.count - 3) more linked handoff notes need assignment, review, completion, or due-date follow-up.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private func linkedOrder(for note: HandoffNote) -> TrackedOrder? {
    guard note.linkedEntityType == .order, let orderID = UUID(uuidString: note.linkedEntityID) else { return nil }
    return store.orders.first { $0.id == orderID }
  }

  private var inboxCreatedOrders: [TrackedOrder] {
    store.orders.filter { !linkedIntakeEmails(for: $0).isEmpty }
  }

  private var handoffNotesLinkedToInboxOrders: [HandoffNote] {
    let orderIDs = Set(inboxCreatedOrders.map(\.id))
    let orderNumbers = Set(inboxCreatedOrders.map(\.orderNumber).filter { !$0.isPlaceholderValidationValue })
    return store.handoffNotes.filter { note in
      if note.linkedEntityType == .order, let linkedID = UUID(uuidString: note.linkedEntityID), orderIDs.contains(linkedID) {
        return true
      }
      let searchable = [note.title, note.summary, note.linkedEntityID, note.notes].joined(separator: " ")
      return orderNumbers.contains { orderNumber in
        searchable.localizedCaseInsensitiveContains(orderNumber)
      }
    }
  }

  private var inboxOrdersMissingHandoff: [TrackedOrder] {
    let linkedOrderIDs = Set(handoffNotesLinkedToInboxOrders.compactMap { note -> UUID? in
      guard note.linkedEntityType == .order else { return nil }
      return UUID(uuidString: note.linkedEntityID)
    })
    let linkedText = handoffNotesLinkedToInboxOrders.map { [$0.title, $0.summary, $0.linkedEntityID, $0.notes].joined(separator: " ") }
    return inboxCreatedOrders.filter { order in
      if linkedOrderIDs.contains(order.id) { return false }
      let orderNumber = order.orderNumber.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !orderNumber.isEmpty, !orderNumber.isPlaceholderValidationValue else { return true }
      return !linkedText.contains { $0.localizedCaseInsensitiveContains(orderNumber) }
    }
  }

  private var handoffNotesNeedingSourceAction: [HandoffNote] {
    handoffNotesLinkedToInboxOrders.filter { note in
      note.status == .open
        || note.status == .inProgress
        || note.reviewState != .accepted
        || note.priority == .high
        || note.priority == .urgent
        || note.isLocallyOverdue
        || note.assignee.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || note.assignee.localizedCaseInsensitiveContains("unassigned")
        || note.assignee.localizedCaseInsensitiveContains("unknown")
    }
  }

  private func handoffActionSummary(for note: HandoffNote) -> String {
    var parts: [String] = []
    if note.status == .open || note.status == .inProgress { parts.append("close or acknowledge handoff") }
    if note.reviewState != .accepted { parts.append("mark reviewed") }
    if note.isLocallyOverdue { parts.append("check due date") }
    if note.priority == .high || note.priority == .urgent { parts.append("priority follow-up") }
    if note.assignee.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || note.assignee.localizedCaseInsensitiveContains("unassigned") || note.assignee.localizedCaseInsensitiveContains("unknown") {
      parts.append("assign owner")
    }
    return parts.isEmpty ? "Handoff is assigned, current, and reviewed." : parts.joined(separator: ", ")
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

  private var handoffProviderRows: [(label: String, count: Int, detail: String, symbol: String, color: Color)] {
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
        detail = "SpaceMail intake can create handoff context when an Inbox-created order needs shift, dispatch, or exception continuity."
      case "gmail":
        detail = "Gmail intake can create handoff context when an Inbox-created order needs shift, dispatch, or exception continuity."
      case "mock":
        detail = "Mock mailbox intake supports local handoff testing without contacting a mailbox provider."
      default:
        detail = "Local mailbox intake can create handoff context once an order is confirmed from Inbox."
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

  private func handoffToneColor(_ tone: String) -> Color {
    switch tone {
    case "warning": return .red
    case "attention": return .orange
    case "success": return .green
    case "neutral": return .blue
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

  private func handoffNote(_ note: HandoffNote, matches query: String) -> Bool {
    let order = linkedOrder(for: note)
    let customerProfiles = store.suggestedCustomerProfiles(for: note)
    let destinationAddresses = store.suggestedDestinationAddresses(for: note)
    let deliveryInstructions = store.suggestedDeliveryInstructions(for: note)
    let packageContents = store.suggestedPackageContents(for: note)
    var searchParts: [String] = [
      note.id.uuidString,
      note.title,
      note.summary,
      note.linkedEntityType.rawValue,
      note.linkedEntityID,
      note.priority.rawValue,
      note.assignee,
      note.createdDate,
      note.dueDate,
      note.status.rawValue,
      note.reviewState.rawValue,
      note.notes,
      order?.orderNumber ?? "",
      order?.store ?? "",
      order?.customer ?? "",
      order?.recipientEmail ?? "",
      order?.trackingNumber ?? "",
      order?.carrier ?? "",
      order?.destination ?? ""
    ]
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

struct HandoffNoteRow: View {
  var note: HandoffNote
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
  var customerProfiles: [CustomerRecipientProfile] = []
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var onSave: (HandoffNote) -> Void
  var onAcknowledge: () -> Void
  var onComplete: () -> Void
  var onReopen: () -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false
  @State private var feedbackMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: note.linkedEntityType.symbol)
          .foregroundStyle(note.priority.color)
          .frame(width: 28, height: 28)
        VStack(alignment: .leading, spacing: 5) {
          Text(note.title)
            .font(.headline)
          Text("\(note.assignee) • due \(note.dueDate)")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(note.summary)
            .foregroundStyle(.secondary)
          Text(note.notes)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 6) {
          Badge(note.priority.rawValue, color: note.priority.color)
          Badge(note.status.rawValue, color: note.status.color)
          Badge(note.reviewState.rawValue, color: note.reviewState.color)
          if note.isLocallyOverdue {
            Badge("Overdue", color: .red)
          }
        }
      }

      HStack(spacing: 8) {
        Label(note.linkedEntityType.rawValue, systemImage: note.linkedEntityType.symbol)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(note.linkedEntityID)
          .font(.caption2.monospaced())
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
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

      if !handoffWarnings.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Label("Handoff follow-up", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.bold())
            .foregroundStyle(.orange)
          ForEach(handoffWarnings, id: \.self) { warning in
            Text(warning)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      if let store, let linkedOrder {
        let linkedEmails = linkedIntakeEmails(for: linkedOrder, store: store)
        if !linkedEmails.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Label("Inbox handoff source", systemImage: "tray.and.arrow.down.fill")
              .font(.caption.bold())
              .foregroundStyle(.teal)
            ForEach(linkedEmails.prefix(2)) { email in
              HStack(spacing: 6) {
                let sourceSummary = store.intakeSourceSummary(for: email)
                Badge(sourceSummary.label, color: sourceColor(for: sourceSummary.tone))
                if !email.detectedOrderNumber.isPlaceholderValidationValue {
                  Badge("Order \(email.detectedOrderNumber)", color: .blue)
                }
                if !email.detectedTrackingNumber.isPlaceholderValidationValue {
                  Badge("Tracking \(email.detectedTrackingNumber)", color: .teal)
                }
                Text(email.subject)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
            }
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
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Acknowledge", systemImage: "hand.thumbsup.fill") {
          onAcknowledge()
          feedbackMessage = "Handoff acknowledged locally."
        }
          .buttonStyle(.bordered)
        if note.status == .completed {
          Button("Reopen", systemImage: "arrow.uturn.backward.circle.fill") {
            onReopen()
            feedbackMessage = "Handoff reopened for follow-up."
          }
            .buttonStyle(.bordered)
        } else {
          Button("Complete", systemImage: "checkmark.circle.fill") {
            onComplete()
            feedbackMessage = "Handoff completed locally."
          }
            .buttonStyle(.borderedProminent)
        }
        Button("Reviewed", systemImage: "checkmark.shield.fill") {
          onReviewed()
          feedbackMessage = "Handoff marked reviewed locally."
        }
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Follow-up task created from handoff. Check Tasks."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Draft message created from handoff. Check Drafts."
        }
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", action: onRemove)
          .buttonStyle(.bordered)
      }

      if let feedbackMessage, let store {
        HandoffActionFeedbackPanel(message: feedbackMessage, store: store)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      HandoffNoteEditView(note: note) { updatedNote in
        onSave(updatedNote)
      }
    }
  }

  private var handoffWarnings: [String] {
    var warnings: [String] = []
    if note.status == .open {
      warnings.append("Handoff is open; acknowledge or complete it once the next team has the context.")
    }
    if note.status == .inProgress {
      warnings.append("Handoff is acknowledged but still in progress.")
    }
    if note.isLocallyOverdue {
      warnings.append("Due date needs immediate follow-up.")
    }
    if note.priority == .high || note.priority == .urgent {
      warnings.append("Priority is \(note.priority.rawValue.lowercased()); keep this visible in shift handoff.")
    }
    if note.assignee.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || note.assignee.localizedCaseInsensitiveContains("unassigned") || note.assignee.localizedCaseInsensitiveContains("unknown") {
      warnings.append("Assigned team/person needs confirmation.")
    }
    if note.reviewState != .accepted {
      warnings.append("Review state is \(note.reviewState.rawValue.lowercased()); mark reviewed after local checks.")
    }
    return warnings
  }

  private func linkedIntakeEmails(for order: TrackedOrder, store: ParcelOpsStore) -> [ForwardedEmailIntake] {
    let orderNumber = order.orderNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    return store.intakeEmails.filter { email in
      email.linkedOrderID == order.id
        || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.detectedOrderNumber.localizedCaseInsensitiveContains(orderNumber))
        || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.subject.localizedCaseInsensitiveContains(orderNumber))
        || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.rawBodyPreview.localizedCaseInsensitiveContains(orderNumber))
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
}

private struct HandoffActionFeedbackPanel: View {
  var message: String
  var store: ParcelOpsStore

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(message, systemImage: "checkmark.circle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.green)

      CompactActionRow {
        NavigationLink {
          TasksView(store: store)
        } label: {
          Label("Open Tasks", systemImage: "checklist")
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
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.green.opacity(0.12))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct HandoffNoteEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: HandoffNote
  var onSave: (HandoffNote) -> Void

  init(note: HandoffNote, onSave: @escaping (HandoffNote) -> Void) {
    self._draft = State(initialValue: note)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Handoff") {
          TextField("Title", text: $draft.title)
          TextField("Summary", text: $draft.summary, axis: .vertical)
            .lineLimit(3...6)
          TextField("Assigned team/person", text: $draft.assignee)
          TextField("Due date", text: $draft.dueDate)
        }

        Section("Linked record") {
          Picker("Record type", selection: $draft.linkedEntityType) {
            ForEach(ReviewTaskLinkedEntityType.allCases) { entityType in
              Text(entityType.rawValue).tag(entityType)
            }
          }
          TextField("Record ID", text: $draft.linkedEntityID)
        }

        Section("State") {
          Picker("Priority", selection: $draft.priority) {
            ForEach(TaskPriority.allCases) { priority in
              Text(priority.rawValue).tag(priority)
            }
          }
          Picker("Status", selection: $draft.status) {
            ForEach(TaskStatus.allCases) { status in
              Text(status.rawValue).tag(status)
            }
          }
          Picker("Review", selection: $draft.reviewState) {
            Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted)
            Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview)
            Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor)
          }
          TextField("Created date", text: $draft.createdDate)
          TextField("Notes", text: $draft.notes, axis: .vertical)
            .lineLimit(4...8)
        }
      }
      .navigationTitle("Edit handoff")
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
