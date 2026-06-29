import SwiftUI

struct TasksView: View {
  var store: ParcelOpsStore

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var queueSearchText = ""

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

  private var draftFollowUpItems: [DraftMessage] {
    Array(store.draftMessagesNeedingReview.prefix(6))
  }

  private var visibleDraftFollowUpItems: [DraftMessage] {
    let query = queueSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return draftFollowUpItems }
    return draftFollowUpItems.filter { draft in
      let linkedOrder = linkedOrder(for: draft)
      return draft.subject.localizedCaseInsensitiveContains(query)
        || draft.body.localizedCaseInsensitiveContains(query)
        || draft.recipient.localizedCaseInsensitiveContains(query)
        || draft.channel.rawValue.localizedCaseInsensitiveContains(query)
        || draft.status.rawValue.localizedCaseInsensitiveContains(query)
        || draft.reviewState.rawValue.localizedCaseInsensitiveContains(query)
        || draft.linkedEntityType.rawValue.localizedCaseInsensitiveContains(query)
        || draft.linkedEntityID.localizedCaseInsensitiveContains(query)
        || (linkedOrder?.orderNumber.localizedCaseInsensitiveContains(query) ?? false)
        || (linkedOrder?.store.localizedCaseInsensitiveContains(query) ?? false)
        || (linkedOrder?.customer.localizedCaseInsensitiveContains(query) ?? false)
    }
  }

  private var visibleQueueItems: [TaskQueueItem] {
    let query = queueSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return queueItems }
    return queueItems.filter { item in
      item.title.localizedCaseInsensitiveContains(query)
        || item.summary.localizedCaseInsensitiveContains(query)
        || item.assignee.localizedCaseInsensitiveContains(query)
        || item.linkedEntityType.rawValue.localizedCaseInsensitiveContains(query)
        || item.linkedEntityID.localizedCaseInsensitiveContains(query)
        || item.sourceLabel.localizedCaseInsensitiveContains(query)
    }
  }

  private func linkedOrder(for draft: DraftMessage) -> TrackedOrder? {
    guard draft.linkedEntityType == .order,
      let orderID = UUID(uuidString: draft.linkedEntityID)
    else { return nil }
    return store.orders.first { $0.id == orderID }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        taskNextActionPanel
        draftFollowUpPanel
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
        ("Inbox orders", "\(inboxOrderActionCount)", inboxOrderActionCount == 0 ? .green : .teal),
        ("Drafts", "\(draftFollowUpItems.count)", draftFollowUpItems.isEmpty ? .green : .blue),
        ("Review", "\(queueItems.filter { $0.reviewState != .accepted }.count)", .purple)
      ])
    }
  }

  private var inboxOrderActionCount: Int {
    queueItems.filter { item in
      guard item.linkedEntityType == .order,
        let orderID = UUID(uuidString: item.linkedEntityID),
        let order = store.orders.first(where: { $0.id == orderID })
      else { return false }
      return order.isInboxCreatedForOperations
    }.count
  }

  private var overdueActionCount: Int {
    queueItems.filter(\.isOverdue).count
  }

  private var blockedActionCount: Int {
    queueItems.filter { $0.status == .blocked }.count
  }

  private var urgentActionCount: Int {
    queueItems.filter { $0.priority == .urgent || $0.priority == .high }.count
  }

  private var handoffActionCount: Int {
    queueItems.filter { item in
      if case .handoff = item.source { return true }
      return false
    }.count
  }

  private var reviewActionCount: Int {
    queueItems.filter { $0.reviewState != .accepted }.count
  }

  private var draftActionCount: Int {
    draftFollowUpItems.count
  }

  private var nextActionTone: Color {
    if overdueActionCount > 0 || blockedActionCount > 0 { return .red }
    if urgentActionCount > 0 || inboxOrderActionCount > 0 { return .orange }
    if reviewActionCount > 0 { return .purple }
    if draftActionCount > 0 { return .blue }
    if !queueItems.isEmpty { return .teal }
    return .green
  }

  private var nextActionTitle: String {
    if overdueActionCount > 0 { return "Start with overdue follow-up" }
    if blockedActionCount > 0 { return "Clear blocked work first" }
    if urgentActionCount > 0 { return "Handle high-priority work" }
    if inboxOrderActionCount > 0 { return "Finish Inbox-created order handoffs" }
    if reviewActionCount > 0 { return "Review open task context" }
    if draftActionCount > 0 { return "Review draft messages" }
    if !queueItems.isEmpty { return "Work the open queue" }
    return "Task queue is clear"
  }

  private var nextActionDetail: String {
    if overdueActionCount > 0 {
      return "\(overdueActionCount) open task or handoff is overdue. Complete it, reassign it, or create a draft so the follow-up is visible."
    }
    if blockedActionCount > 0 {
      return "\(blockedActionCount) item is blocked. Open the row, resolve the blocker, or create a draft/task for the owner."
    }
    if urgentActionCount > 0 {
      return "\(urgentActionCount) high-priority item needs attention before routine handoffs."
    }
    if inboxOrderActionCount > 0 {
      return "\(inboxOrderActionCount) task is linked to an Inbox-created order. Open the order, confirm dispatch context, then complete the follow-up."
    }
    if reviewActionCount > 0 {
      return "\(reviewActionCount) item still needs local review. Check the row summary and mark reviewed once the context is clear."
    }
    if draftActionCount > 0 {
      return "\(draftActionCount) draft message was created from local workflow actions. Mark it ready, sent locally, or reopen it for follow-up."
    }
    if !queueItems.isEmpty {
      return "No overdue or blocked work is at the top of the queue. Continue completing open tasks and handoffs."
    }
    return "There are no open review tasks or handoff notes waiting for daily operator action."
  }

  private var taskNextActionPanel: some View {
    SettingsPanel(title: "Task next action", symbol: "arrow.forward.circle.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: nextActionTone == .green ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            .font(.title3)
            .foregroundStyle(nextActionTone)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text(nextActionTitle)
              .font(.headline)
            Text(nextActionDetail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }

        MetricStrip(items: [
          ("Overdue", "\(overdueActionCount)", overdueActionCount == 0 ? .green : .red),
          ("Blocked", "\(blockedActionCount)", blockedActionCount == 0 ? .green : .red),
          ("High priority", "\(urgentActionCount)", urgentActionCount == 0 ? .green : .orange),
          ("Handoffs", "\(handoffActionCount)", handoffActionCount == 0 ? .green : .blue),
          ("Drafts", "\(draftActionCount)", draftActionCount == 0 ? .green : .blue),
          ("Needs review", "\(reviewActionCount)", reviewActionCount == 0 ? .green : .purple)
        ])
      }
    }
  }

  @ViewBuilder
  private var draftFollowUpPanel: some View {
    if !visibleDraftFollowUpItems.isEmpty {
      SettingsPanel(title: "Draft message follow-up", symbol: "envelope.open.fill") {
        VStack(alignment: .leading, spacing: 12) {
          Text("Drafts created from Inbox, Orders, Tasks, Workbench, and Dispatch appear here so local communication follow-up is visible in the daily flow.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          ForEach(visibleDraftFollowUpItems) { draft in
            TaskDraftFollowUpRow(draft: draft, store: store)
          }

          NavigationLink {
            CommunicationView(store: store)
          } label: {
            Label("Open Drafts & Templates", systemImage: "envelope.open.fill")
          }
          .buttonStyle(.bordered)
        }
      }
    }
  }

  private var taskQueuePanel: some View {
    SettingsPanel(title: "Unified action queue", symbol: "checklist") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Work this list from the top: overdue, blocked, urgent, and review-needed items are promoted first.")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        FilterControlGrid {
          TextField("Search tasks and handoffs", text: $queueSearchText)
            .textFieldStyle(.roundedBorder)
          Badge("\(visibleQueueItems.count + visibleDraftFollowUpItems.count) shown", color: visibleQueueItems.isEmpty && visibleDraftFollowUpItems.isEmpty ? .orange : .blue)
          if !queueSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Button("Clear search", systemImage: "xmark.circle") {
              queueSearchText = ""
            }
            .buttonStyle(.bordered)
          }
        }

        if visibleQueueItems.isEmpty {
          MVPEmptyState(
            title: queueItems.isEmpty ? "No open actions" : "No matching actions",
            detail: queueItems.isEmpty ? "Review tasks and handoff notes that need operator attention will appear here." : "Clear the search to return to the full task and handoff queue.",
            symbol: "checkmark.circle.fill",
            actionTitle: "Add task",
            action: store.addReviewTaskPlaceholder
          )
        } else {
          ForEach(visibleQueueItems.prefix(16)) { item in
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

private struct TaskDraftFollowUpRow: View {
  var draft: DraftMessage
  var store: ParcelOpsStore

  private var statusColor: Color {
    switch draft.status {
    case .draft:
      return .orange
    case .ready:
      return .green
    case .sentLocally:
      return .secondary
    case .reopened:
      return .purple
    }
  }

  private var linkedOrder: TrackedOrder? {
    guard draft.linkedEntityType == .order,
      let orderID = UUID(uuidString: draft.linkedEntityID)
    else { return nil }
    return store.orders.first { $0.id == orderID }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "envelope.open.fill")
          .foregroundStyle(statusColor)
          .frame(width: 30, height: 30)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
              Text(draft.subject)
                .font(.headline)
              Text("\(draft.channel.rawValue) • \(draft.recipient)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 8)
            Badge(draft.status.rawValue, color: statusColor)
          }

          Text(draft.body)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          if let linkedOrder {
            Label("\(linkedOrder.store) \(linkedOrder.orderNumber) • \(linkedOrder.customer)", systemImage: "shippingbox.fill")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.teal)
          }

          CompactMetadataGrid {
            Badge(draft.reviewState.rawValue, color: draft.reviewState.color)
            Label(draft.linkedEntityType.rawValue, systemImage: draft.linkedEntityType.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(draft.createdDate)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      CompactActionRow {
        if let linkedOrder {
          NavigationLink {
            OrderDetailView(order: linkedOrder, store: store)
          } label: {
            Label("Open order", systemImage: "shippingbox.fill")
          }
          .buttonStyle(.bordered)
        }

        Button("Ready", systemImage: "checkmark.seal.fill") {
          store.markDraftMessageReady(draft)
        }
        .buttonStyle(.bordered)
        .disabled(draft.status == .ready)

        Button("Sent locally", systemImage: "paperplane.fill") {
          store.markDraftMessageSentLocally(draft)
        }
        .buttonStyle(.borderedProminent)
        .disabled(draft.status == .sentLocally)

        Button("Reopen", systemImage: "arrow.uturn.backward.circle.fill") {
          store.reopenDraftMessage(draft)
        }
        .buttonStyle(.bordered)
        .disabled(draft.status == .reopened)
      }
    }
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

private struct TaskQueueRow: View {
  var item: TaskQueueItem
  var store: ParcelOpsStore
  @State private var editingTask: ReviewTask?
  @State private var editingHandoff: HandoffNote?

  private var linkedOrder: TrackedOrder? {
    guard item.linkedEntityType == .order,
      let orderID = UUID(uuidString: item.linkedEntityID)
    else { return nil }
    return store.orders.first { $0.id == orderID }
  }

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

          if let linkedOrder {
            VStack(alignment: .leading, spacing: 4) {
              Label("\(linkedOrder.store) \(linkedOrder.orderNumber) • \(linkedOrder.customer)", systemImage: "shippingbox.fill")
                .font(.caption.weight(.semibold))
              Text("\(linkedOrder.carrier) • \(linkedOrder.trackingNumber) • \(linkedOrder.destination)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
              if linkedOrder.isInboxCreatedForOperations {
                Label("Inbox-created order follow-up", systemImage: "tray.and.arrow.down.fill")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.teal)
              }
            }
            .padding(10)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
          }

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
    if let linkedOrder {
      NavigationLink {
        OrderDetailView(order: linkedOrder, store: store)
      } label: {
        Label("Open order", systemImage: "arrow.up.right.square.fill")
      }
      .buttonStyle(.bordered)
    } else {
      switch item.source {
      case .task:
        NavigationLink {
          ReviewTasksDetailView(store: store)
        } label: {
          Label("Open task", systemImage: "arrow.right.circle.fill")
        }
        .buttonStyle(.bordered)
      case .handoff:
        NavigationLink {
          HandoffNotesView(store: store)
        } label: {
          Label("Open handoff", systemImage: "arrow.right.circle.fill")
        }
        .buttonStyle(.bordered)
      }
    }
  }
}

private extension TrackedOrder {
  var isInboxCreatedForOperations: Bool {
    source == .forwardedMailbox
      || checkedMailbox == "manual-import"
      || latestStatus.localizedCaseInsensitiveContains("import queue")
      || latestStatus.localizedCaseInsensitiveContains("acceptance")
      || latestStatus.localizedCaseInsensitiveContains("forwarded email")
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
              ReviewTaskRow(task: task, store: store, linkedOrder: linkedOrder(for: task), matchingPolicies: store.policies(for: task.linkedEntityType), shipmentGroups: store.suggestedShipmentGroups(for: task), handoffNotes: store.handoffNotes(for: task), customerProfiles: store.suggestedCustomerProfiles(for: task), destinationAddresses: store.suggestedDestinationAddresses(for: task), deliveryInstructions: store.suggestedDeliveryInstructions(for: task), packageContents: store.suggestedPackageContents(for: task)) { updatedTask in
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

  private func linkedOrder(for task: ReviewTask) -> TrackedOrder? {
    guard task.linkedEntityType == .order, let orderID = UUID(uuidString: task.linkedEntityID) else { return nil }
    return store.orders.first { $0.id == orderID }
  }
}

struct ReviewTaskRow: View {
  var task: ReviewTask
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
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
