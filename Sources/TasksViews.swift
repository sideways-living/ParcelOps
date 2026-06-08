import SwiftUI

struct TasksView: View {
  var store: ParcelOpsStore

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var queueItems: [TaskQueueItem] {
    let tasks = store.reviewTasks
      .filter { $0.status != .completed || $0.reviewState != .accepted }
      .map(TaskQueueItem.task)
    let notes = store.handoffNotes
      .filter { $0.status != .completed || $0.reviewState != .accepted }
      .map(TaskQueueItem.handoff)

    return (tasks + notes).sorted { first, second in
      if first.sortPriority == second.sortPriority {
        return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
      }
      return first.sortPriority > second.sortPriority
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        taskQueuePanel
        detailRoutes
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
    .background(.regularMaterial)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Tasks")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("A focused action queue for open follow-up tasks and shift handoffs.")
          .foregroundStyle(.secondary)
      }

      MetricStrip(items: [
        ("Queue", "\(queueItems.count)", .orange),
        ("Overdue", "\(queueItems.filter(\.isOverdue).count)", .red),
        ("Blocked", "\(queueItems.filter { $0.status == .blocked }.count)", .red),
        ("Urgent", "\(queueItems.filter { $0.priority == .urgent }.count)", .pink),
        ("Review", "\(queueItems.filter { $0.reviewState != .accepted }.count)", .purple)
      ])
    }
  }

  private var taskQueuePanel: some View {
    SettingsPanel(title: "Unified action queue", symbol: "checklist") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Work this list from the top: overdue, blocked, urgent, and review-needed items are promoted first.")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        if queueItems.isEmpty {
          MVPEmptyState(
            title: "No open actions",
            detail: "Review tasks and handoff notes that need operator attention will appear here.",
            symbol: "checkmark.circle.fill",
            actionTitle: "Add task",
            action: store.addReviewTaskPlaceholder
          )
        } else {
          ForEach(queueItems.prefix(16)) { item in
            TaskQueueRow(item: item, store: store)
          }
        }
      }
    }
  }

  private var detailRoutes: some View {
    SettingsPanel(title: "Detailed task views", symbol: "rectangle.stack.fill") {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 220 : 240), spacing: 12)], spacing: 12) {
        NavigationLink {
          ReviewTasksDetailView(store: store)
        } label: {
          TaskRouteCard(title: "Review Tasks", detail: "Filter, edit, complete, reopen, review, or remove local task records.", symbol: "checklist", badge: "\(store.reviewTasks.count) tasks", tint: .orange)
        }
        .buttonStyle(.plain)

        NavigationLink {
          HandoffNotesView(store: store)
        } label: {
          TaskRouteCard(title: "Handoff Notes", detail: "Manage shift notes, acknowledgements, and local team continuity.", symbol: "arrow.left.arrow.right.square.fill", badge: "\(store.handoffNotes.count) notes", tint: .blue)
        }
        .buttonStyle(.plain)
      }
    }
  }
}

private struct TaskQueueItem: Identifiable {
  var id: String
  var source: TaskQueueSource
  var sourceLabel: String
  var title: String
  var summary: String
  var linkedEntityType: ReviewTaskLinkedEntityType
  var linkedEntityID: String
  var assignee: String
  var priority: TaskPriority
  var dueDate: String
  var status: TaskStatus
  var reviewState: ReviewState
  var isOverdue: Bool
  var nextAction: String
  var sortPriority: Int

  static func task(_ task: ReviewTask) -> TaskQueueItem {
    TaskQueueItem(
      id: "task-\(task.id.uuidString)",
      source: .task(task),
      sourceLabel: "Task",
      title: task.title,
      summary: task.summary,
      linkedEntityType: task.linkedEntityType,
      linkedEntityID: task.linkedEntityID,
      assignee: task.assignee,
      priority: task.priority,
      dueDate: task.isLocallyOverdue ? "Overdue: \(task.dueDate)" : task.dueDate,
      status: task.status,
      reviewState: task.reviewState,
      isOverdue: task.isLocallyOverdue,
      nextAction: nextAction(status: task.status, reviewState: task.reviewState, isOverdue: task.isLocallyOverdue, completedVerb: "Reopen if more work is needed"),
      sortPriority: sortPriority(priority: task.priority, status: task.status, reviewState: task.reviewState, isOverdue: task.isLocallyOverdue)
    )
  }

  static func handoff(_ note: HandoffNote) -> TaskQueueItem {
    TaskQueueItem(
      id: "handoff-\(note.id.uuidString)",
      source: .handoff(note),
      sourceLabel: "Handoff",
      title: note.title,
      summary: note.summary,
      linkedEntityType: note.linkedEntityType,
      linkedEntityID: note.linkedEntityID,
      assignee: note.assignee,
      priority: note.priority,
      dueDate: note.isLocallyOverdue ? "Overdue: \(note.dueDate)" : note.dueDate,
      status: note.status,
      reviewState: note.reviewState,
      isOverdue: note.isLocallyOverdue,
      nextAction: nextAction(status: note.status, reviewState: note.reviewState, isOverdue: note.isLocallyOverdue, completedVerb: "Reopen if the handoff is active again"),
      sortPriority: sortPriority(priority: note.priority, status: note.status, reviewState: note.reviewState, isOverdue: note.isLocallyOverdue)
    )
  }

  private static func nextAction(status: TaskStatus, reviewState: ReviewState, isOverdue: Bool, completedVerb: String) -> String {
    if status == .completed {
      return reviewState == .accepted ? completedVerb : "Mark reviewed"
    }
    if status == .blocked {
      return "Resolve blocker or create a draft"
    }
    if isOverdue {
      return "Complete or reassign today"
    }
    if reviewState != .accepted {
      return "Review details and act"
    }
    return "Complete when follow-up is done"
  }

  private static func sortPriority(priority: TaskPriority, status: TaskStatus, reviewState: ReviewState, isOverdue: Bool) -> Int {
    if isOverdue { return 110 }
    if status == .blocked { return 100 }
    if priority == .urgent { return 95 }
    if priority == .high { return 85 }
    if reviewState != .accepted { return 70 }
    if status == .inProgress { return 60 }
    if status == .open { return 50 }
    return 20
  }
}

private enum TaskQueueSource {
  case task(ReviewTask)
  case handoff(HandoffNote)

  var symbol: String {
    switch self {
    case .task: "checklist"
    case .handoff: "arrow.left.arrow.right.square.fill"
    }
  }
}

private struct TaskQueueRow: View {
  var item: TaskQueueItem
  var store: ParcelOpsStore
  @State private var editingTask: ReviewTask?
  @State private var editingHandoff: HandoffNote?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: item.source.symbol)
          .foregroundStyle(item.priority.color)
          .frame(width: 30, height: 30)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
              Text(item.title)
                .font(.headline)
              Text("\(item.assignee) • due \(item.dueDate)")
                .font(.caption)
                .foregroundStyle(item.isOverdue ? .red : .secondary)
            }
            Spacer(minLength: 8)
            Badge(item.sourceLabel, color: item.priority.color)
          }

          Text(item.summary)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          CompactMetadataGrid {
            Badge(item.priority.rawValue, color: item.priority.color)
            Badge(item.status.rawValue, color: item.status.color)
            Badge(item.reviewState.rawValue, color: item.reviewState.color)
            if item.isOverdue {
              Badge("Overdue", color: .red)
            }
            Label(item.linkedEntityType.rawValue, systemImage: item.linkedEntityType.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(item.linkedEntityID)
              .font(.caption2.monospaced())
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          }

          Label(item.nextAction, systemImage: "arrow.forward.circle.fill")
            .font(.caption)
            .foregroundStyle(item.priority.color)
        }
      }

      CompactActionRow {
        openLink

        switch item.source {
        case .task(let task):
          Button("Edit", systemImage: "pencil") {
            editingTask = task
          }
          .buttonStyle(.bordered)
          if task.status == .completed {
            Button("Reopen", systemImage: "arrow.uturn.backward.circle.fill") {
              store.reopenReviewTask(task)
            }
            .buttonStyle(.bordered)
          } else {
            Button("Complete", systemImage: "checkmark.circle.fill") {
              store.completeReviewTask(task)
            }
            .buttonStyle(.borderedProminent)
          }
          Button("Reviewed", systemImage: "checkmark.shield.fill") {
            store.markReviewTaskReviewed(task)
          }
          .buttonStyle(.bordered)
          Button("Draft", systemImage: "envelope.open.fill") {
            store.createDraftMessage(from: task)
          }
          .buttonStyle(.bordered)

        case .handoff(let note):
          Button("Edit", systemImage: "pencil") {
            editingHandoff = note
          }
          .buttonStyle(.bordered)
          Button("Acknowledge", systemImage: "hand.thumbsup.fill") {
            store.acknowledgeHandoffNote(note)
          }
          .buttonStyle(.bordered)
          if note.status == .completed {
            Button("Reopen", systemImage: "arrow.uturn.backward.circle.fill") {
              store.reopenHandoffNote(note)
            }
            .buttonStyle(.bordered)
          } else {
            Button("Complete", systemImage: "checkmark.circle.fill") {
              store.completeHandoffNote(note)
            }
            .buttonStyle(.borderedProminent)
          }
          Button("Reviewed", systemImage: "checkmark.shield.fill") {
            store.markHandoffNoteReviewed(note)
          }
          .buttonStyle(.bordered)
          Button("Task", systemImage: "checklist") {
            store.createReviewTask(from: note)
          }
          .buttonStyle(.bordered)
          Button("Draft", systemImage: "envelope.open.fill") {
            store.createDraftMessage(from: note)
          }
          .buttonStyle(.bordered)
        }
      }
    }
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    .sheet(item: $editingTask) { task in
      ReviewTaskEditView(task: task) { updatedTask in
        store.updateReviewTask(updatedTask)
      }
    }
    .sheet(item: $editingHandoff) { note in
      HandoffNoteEditView(note: note) { updatedNote in
        store.updateHandoffNote(updatedNote)
      }
    }
  }

  @ViewBuilder
  private var openLink: some View {
    switch item.source {
    case .task:
      NavigationLink {
        ReviewTasksDetailView(store: store)
      } label: {
        Label("Open", systemImage: "arrow.right.circle.fill")
      }
      .buttonStyle(.bordered)
    case .handoff:
      NavigationLink {
        HandoffNotesView(store: store)
      } label: {
        Label("Open", systemImage: "arrow.right.circle.fill")
      }
      .buttonStyle(.bordered)
    }
  }
}

struct ReviewTasksDetailView: View {
  var store: ParcelOpsStore

  @State private var selectedStatus: TaskStatus?
  @State private var selectedPriority: TaskPriority?
  @State private var selectedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedAssignee: String?
  @State private var selectedReviewState: ReviewState?
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var assignees: [String] {
    Array(Set(store.reviewTasks.map(\.assignee))).sorted()
  }

  private var filteredTasks: [ReviewTask] {
    store.reviewTasks.filter { task in
      let matchesStatus = selectedStatus == nil || task.status == selectedStatus
      let matchesPriority = selectedPriority == nil || task.priority == selectedPriority
      let matchesEntity = selectedEntityType == nil || task.linkedEntityType == selectedEntityType
      let matchesAssignee = selectedAssignee == nil || task.assignee == selectedAssignee
      let matchesReview = selectedReviewState == nil || task.reviewState == selectedReviewState
      return matchesStatus && matchesPriority && matchesEntity && matchesAssignee && matchesReview
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Tasks")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Local ownership and follow-up work created from intake, orders, dispatch, exceptions, and audit events.")
            .foregroundStyle(.secondary)
        }

        MVPWorkflowGuide(
          title: "Task workflow",
          detail: "Tasks are the simplest way to turn a confusing record into assigned follow-up.",
          steps: [
            "Filter to open, urgent, or overdue work.",
            "Edit the assignee, priority, due date, or summary when ownership is unclear.",
            "Create a draft if the task needs a supplier, customer, or team message.",
            "Complete and mark reviewed when the work is done."
          ],
          symbol: "checklist"
        )

        filterBar

        SettingsPanel(title: "Review tasks", symbol: "checklist") {
          HStack {
            Text("\(filteredTasks.count) visible tasks")
              .font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            Button("Add task", systemImage: "plus", action: store.addReviewTaskPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredTasks.isEmpty {
            MVPEmptyState(title: "No tasks match this view", detail: "Clear filters or add a placeholder task to test local follow-up ownership.", symbol: "checklist", actionTitle: "Add task", action: store.addReviewTaskPlaceholder)
          } else {
            ForEach(filteredTasks) { task in
              ReviewTaskRow(task: task, matchingPolicies: store.policies(for: task.linkedEntityType), shipmentGroups: store.suggestedShipmentGroups(for: task), handoffNotes: store.handoffNotes(for: task), customerProfiles: store.suggestedCustomerProfiles(for: task), destinationAddresses: store.suggestedDestinationAddresses(for: task), deliveryInstructions: store.suggestedDeliveryInstructions(for: task), packageContents: store.suggestedPackageContents(for: task)) { updatedTask in
                store.updateReviewTask(updatedTask)
              } onComplete: {
                store.completeReviewTask(task)
              } onReopen: {
                store.reopenReviewTask(task)
              } onReviewed: {
                store.markReviewTaskReviewed(task)
              } onCreateDraft: {
                store.createDraftMessage(from: task)
              } onCreateContact: {
                store.addContactDirectoryEntry(linkedEntityType: .reviewTask, linkedEntityID: task.id.uuidString, label: task.title)
              } onRemove: {
                store.removeReviewTask(task)
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
      Picker("Status", selection: $selectedStatus) {
        Text("All statuses").tag(nil as TaskStatus?)
        ForEach(TaskStatus.allCases) { status in
          Text(status.rawValue).tag(status as TaskStatus?)
        }
      }
      .pickerStyle(.menu)

      Picker("Priority", selection: $selectedPriority) {
        Text("All priorities").tag(nil as TaskPriority?)
        ForEach(TaskPriority.allCases) { priority in
          Text(priority.rawValue).tag(priority as TaskPriority?)
        }
      }
      .pickerStyle(.menu)

      Picker("Record", selection: $selectedEntityType) {
        Text("All records").tag(nil as ReviewTaskLinkedEntityType?)
        ForEach(ReviewTaskLinkedEntityType.allCases) { entityType in
          Text(entityType.rawValue).tag(entityType as ReviewTaskLinkedEntityType?)
        }
      }
      .pickerStyle(.menu)

      Picker("Assignee", selection: $selectedAssignee) {
        Text("All assignees").tag(nil as String?)
        ForEach(assignees, id: \.self) { assignee in
          Text(assignee).tag(assignee as String?)
        }
      }
      .pickerStyle(.menu)

      Picker("Review", selection: $selectedReviewState) {
        Text("All review states").tag(nil as ReviewState?)
        Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted as ReviewState?)
        Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview as ReviewState?)
        Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor as ReviewState?)
      }
      .pickerStyle(.menu)

      Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle") {
        selectedStatus = nil
        selectedPriority = nil
        selectedEntityType = nil
        selectedAssignee = nil
        selectedReviewState = nil
      }
      .buttonStyle(.bordered)
    }
  }
}

struct ReviewTaskRow: View {
  var task: ReviewTask
  var matchingPolicies: [SLAPolicy] = []
  var shipmentGroups: [ShipmentGroup] = []
  var handoffNotes: [HandoffNote] = []
  var customerProfiles: [CustomerRecipientProfile] = []
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var onSave: (ReviewTask) -> Void
  var onComplete: () -> Void
  var onReopen: () -> Void
  var onReviewed: () -> Void
  var onCreateDraft: () -> Void = {}
  var onCreateContact: () -> Void = {}
  var onRemove: () -> Void
  @State private var isEditing = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: task.linkedEntityType.symbol)
          .foregroundStyle(task.priority.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(task.title)
                .font(.headline)
              Text("\(task.assignee) • due \(task.dueDate)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(task.priority.rawValue, color: task.priority.color)
            if task.isLocallyOverdue {
              Badge("Overdue", color: .red)
            }
          }

          Text(task.summary)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          CompactMetadataGrid {
            Badge(task.status.rawValue, color: task.status.color)
            Badge(task.reviewState.rawValue, color: task.reviewState.color)
            Label(task.linkedEntityType.rawValue, systemImage: task.linkedEntityType.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(task.linkedEntityID)
              .font(.caption2.monospaced())
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          }

          if let policy = matchingPolicies.first {
            Text("SLA: \(policy.responseTarget); \(policy.resolutionTarget)")
              .font(.caption)
              .foregroundStyle(policy.priority.color)
          }

          if !shipmentGroups.isEmpty {
            ShipmentGroupContextStrip(groups: shipmentGroups)
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
      }

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        if task.status == .completed {
          Button("Reopen", systemImage: "arrow.uturn.backward.circle.fill", action: onReopen)
            .buttonStyle(.bordered)
        } else {
          Button("Complete", systemImage: "checkmark.circle.fill", action: onComplete)
            .buttonStyle(.borderedProminent)
        }
        Button("Reviewed", systemImage: "checkmark.shield.fill", action: onReviewed)
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill", action: onCreateDraft)
          .buttonStyle(.bordered)
        Button("Contact", systemImage: "person.crop.circle.badge.plus", action: onCreateContact)
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", action: onRemove)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      ReviewTaskEditView(task: task) { updatedTask in
        onSave(updatedTask)
      }
    }
  }
}

struct ReviewTaskEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: ReviewTask
  var onSave: (ReviewTask) -> Void

  init(task: ReviewTask, onSave: @escaping (ReviewTask) -> Void) {
    self._draft = State(initialValue: task)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Task") {
          TextField("Title", text: $draft.title)
          TextField("Summary", text: $draft.summary, axis: .vertical)
            .lineLimit(3...6)
          TextField("Due date", text: $draft.dueDate)
          TextField("Assigned team/person", text: $draft.assignee)
        }

        Section("Linked record") {
          Picker("Record type", selection: $draft.linkedEntityType) {
            ForEach(ReviewTaskLinkedEntityType.allCases) { entityType in
              Text(entityType.rawValue).tag(entityType)
            }
          }
          TextField("Linked record ID", text: $draft.linkedEntityID)
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
          Picker("Review state", selection: $draft.reviewState) {
            Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted)
            Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview)
            Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor)
          }
          TextField("Completed date", text: Binding(
            get: { draft.completedDate ?? "" },
            set: { draft.completedDate = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
          ))
        }
      }
      .navigationTitle("Edit task")
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

private struct TaskRouteCard: View {
  var title: String
  var detail: String
  var symbol: String
  var badge: String
  var tint: Color
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: symbol)
        .foregroundStyle(tint)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 5) {
        if isCompact {
          VStack(alignment: .leading, spacing: 6) {
            Text(title)
              .font(.headline)
            Badge(badge, color: tint)
          }
        } else {
          Text(title)
            .font(.headline)
        }

        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      if !isCompact {
        Spacer(minLength: 8)
        Badge(badge, color: tint)
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}
