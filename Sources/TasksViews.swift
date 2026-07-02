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

  private var spaceMailHealthSummaries: [SpaceMailIntakeHealthSummary] {
    store.spaceMailIntakeHealthSummaries
  }

  private var spaceMailPostRefreshPlan: SpaceMailPostRefreshActionPlan {
    store.spaceMailPostRefreshActionPlan
  }

  private var spaceMailFetchedCount: Int {
    spaceMailHealthSummaries.reduce(0) { $0 + $1.fetchedCount }
  }

  private var spaceMailImportedCount: Int {
    spaceMailHealthSummaries.reduce(0) { $0 + $1.importedCount }
  }

  private var spaceMailFilteredCount: Int {
    spaceMailHealthSummaries.reduce(0) { $0 + $1.filteredCount }
  }

  private var spaceMailUncertainCount: Int {
    spaceMailHealthSummaries.reduce(0) { $0 + $1.uncertainCount + $1.pendingUncertainReviewCount }
  }

  private var pendingFilteredSpaceMailCount: Int {
    spaceMailHealthSummaries.reduce(0) { $0 + $1.pendingFilteredReviewCount }
  }

  private var spaceMailParserIssueCount: Int {
    spaceMailHealthSummaries.reduce(0) { $0 + $1.parserIssueCount }
  }

  private var spaceMailFilteredOnlyOutcome: Bool {
    spaceMailFetchedCount > 0
      && spaceMailImportedCount == 0
      && spaceMailUncertainCount == 0
      && spaceMailFilteredCount > 0
  }

  private var visibleDraftFollowUpItems: [DraftMessage] {
    let query = queueSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return draftFollowUpItems }
    return draftFollowUpItems.filter { draft in
      let linkedOrder = linkedOrder(for: draft)
      return [
        draft.subject,
        draft.body,
        draft.recipient,
        draft.channel.rawValue,
        draft.status.rawValue,
        draft.reviewState.rawValue,
        draft.linkedEntityType.rawValue,
        draft.linkedEntityID,
        linkedOrder?.orderNumber ?? "",
        linkedOrder?.store ?? "",
        linkedOrder?.customer ?? ""
      ].joined(separator: " ").localizedLowercase.contains(query)
    }
  }

  private var visibleQueueItems: [TaskQueueItem] {
    let query = queueSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return queueItems }
    return queueItems.filter { item in
      [
        item.title,
        item.summary,
        item.assignee,
        item.linkedEntityType.rawValue,
        item.linkedEntityID,
        item.sourceLabel
      ].joined(separator: " ").localizedLowercase.contains(query)
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
        taskScopePanel
        spaceMailTaskEscalationPanel
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
      return order.isInboxCreatedLocalOrder
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

        CompactActionRow {
          NavigationLink {
            OperationsWorkbenchView(store: store)
          } label: {
            Label("Open Workbench", systemImage: "rectangle.stack.badge.person.crop.fill")
          }
          .buttonStyle(.bordered)

          NavigationLink {
            CommunicationView(store: store)
          } label: {
            Label("Open Drafts", systemImage: "envelope.open.fill")
          }
          .buttonStyle(.bordered)

          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Open Audit", systemImage: "list.clipboard.fill")
          }
          .buttonStyle(.bordered)
        }
      }
    }
  }

  private var taskScopePanel: some View {
    SettingsPanel(title: "Task scope", symbol: "checklist.checked") {
      VStack(alignment: .leading, spacing: 10) {
        Text("Tasks should represent work someone owns. Parser checks, filtered SpaceMail messages, and classifier diagnostics stay in Inbox, Mailbox Monitor, Workbench, and Audit unless a person creates a follow-up task from them.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Open tasks", "\(store.openReviewTasks.count)", store.openReviewTasks.isEmpty ? .green : .orange),
          ("Handoffs", "\(handoffActionCount)", handoffActionCount == 0 ? .green : .blue),
          ("Drafts", "\(draftActionCount)", draftActionCount == 0 ? .green : .blue),
          ("Parser context", "\(store.intakeParserDiagnostics.count)", store.intakeParserDiagnostics.isEmpty ? .green : .secondary),
          ("Uncertain mail", "\(store.spaceMailIMAPConnections.reduce(0) { $0 + $1.uncertainMessages.count })", store.spaceMailIMAPConnections.contains { !$0.uncertainMessages.isEmpty } ? .orange : .secondary)
        ])

        Text(store.intakeParserDiagnostics.isEmpty && !store.spaceMailIMAPConnections.contains { !$0.uncertainMessages.isEmpty }
          ? "No parser or uncertain-mail context currently needs escalation into a task."
          : "Create a task only when parser or uncertain-mail context needs a named owner, due date, or handoff.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(store.intakeParserDiagnostics.isEmpty && !store.spaceMailIMAPConnections.contains { !$0.uncertainMessages.isEmpty } ? .green : .orange)
          .fixedSize(horizontal: false, vertical: true)

        CompactActionRow {
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Open Inbox triage", systemImage: "tray.full.fill")
          }
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Open Mailbox Monitor", systemImage: "server.rack")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private var spaceMailTaskEscalationPanel: some View {
    SettingsPanel(title: "Mailbox-to-task boundary", symbol: "tray.and.arrow.down.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: spaceMailTaskEscalationSymbol)
            .font(.title3)
            .foregroundStyle(spaceMailTaskEscalationTone)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text(spaceMailTaskEscalationTitle)
              .font(.headline)
            Text(spaceMailTaskEscalationDetail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        MetricStrip(items: [
          ("Fetched", "\(spaceMailFetchedCount)", spaceMailFetchedCount == 0 ? .secondary : .blue),
          ("Imported", "\(spaceMailImportedCount)", spaceMailImportedCount == 0 ? .secondary : .green),
          ("Uncertain", "\(spaceMailUncertainCount)", spaceMailUncertainCount == 0 ? .secondary : .orange),
          ("Filtered", "\(spaceMailFilteredCount)", spaceMailFilteredCount == 0 ? .secondary : .teal),
          ("Filtered review", "\(pendingFilteredSpaceMailCount)", pendingFilteredSpaceMailCount == 0 ? .secondary : .teal),
          ("Parser issues", "\(spaceMailParserIssueCount)", spaceMailParserIssueCount == 0 ? .secondary : .orange),
          ("Task links", "\(spaceMailLinkedTaskCount)", spaceMailLinkedTaskCount == 0 ? .secondary : .purple)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 180 : 230), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(spaceMailPostRefreshPlan.items) { item in
            VStack(alignment: .leading, spacing: 6) {
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: item.symbol)
                  .foregroundStyle(taskColor(for: item.tone))
                  .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                  Text(item.title)
                    .font(.caption.weight(.semibold))
                  Text(item.actionLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(taskColor(for: item.tone))
                  Text(item.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Badge("\(item.count)", color: taskColor(for: item.tone))
              }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(taskColor(for: item.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }

        Text("Create a task only when a person must own the follow-up. Imported order mail starts in Inbox, uncertain mail starts in Mailbox Monitor, and filtered mixed-mailbox examples stay out of Tasks unless manually promoted or converted into follow-up.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(spaceMailTaskEscalationTone)
          .fixedSize(horizontal: false, vertical: true)

        CompactActionRow {
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Review imported mail", systemImage: "tray.full.fill")
          }
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label(spaceMailUncertainCount > 0 || pendingFilteredSpaceMailCount > 0 ? "Review SpaceMail examples" : "Open Mailbox Monitor", systemImage: "server.rack")
          }
          NavigationLink {
            OperationsWorkbenchView(store: store)
          } label: {
            Label("Open Workbench", systemImage: "rectangle.stack.badge.person.crop.fill")
          }
          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Check Audit", systemImage: "list.clipboard.fill")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private var spaceMailLinkedTaskCount: Int {
    queueItems.filter { item in
      item.linkedEntityType == .intakeEmail
        || item.summary.localizedCaseInsensitiveContains("spacemail")
        || item.title.localizedCaseInsensitiveContains("spacemail")
        || item.summary.localizedCaseInsensitiveContains("intake")
    }.count
  }

  private var spaceMailTaskEscalationTitle: String {
    if spaceMailLinkedTaskCount > 0 { return "SpaceMail follow-up is assigned" }
    if spaceMailImportedCount > 0 { return "Imported mail is waiting in Inbox" }
    if spaceMailUncertainCount > 0 { return "Uncertain mail needs mailbox review" }
    if spaceMailParserIssueCount > 0 { return "Parser diagnostics may need ownership" }
    if spaceMailFilteredOnlyOutcome { return "Filtered mail did not create tasks" }
    if spaceMailFetchedCount > 0 { return "Latest refresh did not create task work" }
    return "Mailbox task escalation is clear"
  }

  private var spaceMailTaskEscalationDetail: String {
    if spaceMailLinkedTaskCount > 0 {
      return "\(spaceMailLinkedTaskCount) task or handoff references SpaceMail, intake, or forwarded-email context. Work those rows from the queue below."
    }
    if spaceMailImportedCount > 0 {
      return "\(spaceMailImportedCount) likely order message reached Inbox. Create a task only if review needs a named owner or due date."
    }
    if spaceMailUncertainCount > 0 {
      return "\(spaceMailUncertainCount) ambiguous SpaceMail preview is waiting outside Inbox. Import it, dismiss it, or create a task from Mailbox Monitor if someone must investigate."
    }
    if spaceMailParserIssueCount > 0 {
      return "\(spaceMailParserIssueCount) parser diagnostic is present. Keep it as diagnostic context unless it needs assigned follow-up."
    }
    if spaceMailFilteredOnlyOutcome {
      return "\(spaceMailFilteredCount) mixed-mailbox message was filtered out. That is a normal non-order outcome, not task backlog."
    }
    if spaceMailFetchedCount > 0 {
      return "SpaceMail fetched mail but did not produce imported, uncertain, parser, or assigned follow-up work."
    }
    return "Run manual SpaceMail refresh from Mailbox Monitor when you need new intake; Tasks should remain focused on assigned work."
  }

  private var spaceMailTaskEscalationTone: Color {
    if spaceMailLinkedTaskCount > 0 || spaceMailImportedCount > 0 || spaceMailUncertainCount > 0 { return .orange }
    if spaceMailParserIssueCount > 0 { return .purple }
    if spaceMailFilteredOnlyOutcome { return .green }
    if spaceMailFetchedCount > 0 { return .teal }
    return .secondary
  }

  private var spaceMailTaskEscalationSymbol: String {
    if spaceMailLinkedTaskCount > 0 { return "checklist" }
    if spaceMailImportedCount > 0 { return "tray.full.fill" }
    if spaceMailUncertainCount > 0 { return "questionmark.folder.fill" }
    if spaceMailParserIssueCount > 0 { return "text.magnifyingglass" }
    if spaceMailFilteredOnlyOutcome { return "checkmark.seal.fill" }
    return "tray.and.arrow.down.fill"
  }

  private func taskColor(for tone: String) -> Color {
    switch tone.localizedLowercase {
    case "success":
      return .green
    case "attention":
      return .orange
    case "warning":
      return .red
    case "neutral":
      return .teal
    default:
      return .blue
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
      nextAction: task.isReopenedInboxDispatchHandoff
        ? "Open the order, inspect dispatch setup, then complete or block the handoff"
        : task.isPartialInboxOrderFollowUp
        ? "Open the order, confirm missing fields, then complete this handoff"
        : nextAction(status: task.status, reviewState: task.reviewState, isOverdue: task.isLocallyOverdue, completedVerb: "Reopen if more work is needed"),
      sortPriority: sortPriority(priority: task.priority, status: task.status, reviewState: task.reviewState, isOverdue: task.isLocallyOverdue) + (task.isReopenedInboxDispatchHandoff ? 12 : task.isPartialInboxOrderFollowUp ? 8 : 0)
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
  @State private var feedbackMessage: String?

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

          if linkedOrder != nil {
            LinkedOrderContextPanel(
              order: linkedOrder,
              sourceLabel: "Draft follow-up",
              emptyDetail: "No order is linked to this draft. Return to the source record if the message should reference an order before it is marked ready.",
              linkedDetail: "This draft is tied to order context. Open the order before marking the draft ready if tracking, destination, or dispatch setup still needs confirmation.",
              store: store
            )
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
        Button("Ready", systemImage: "checkmark.seal.fill") {
          store.markDraftMessageReady(draft)
          feedbackMessage = "Draft marked ready locally."
        }
        .buttonStyle(.bordered)
        .disabled(draft.status == .ready)

        Button("Sent locally", systemImage: "paperplane.fill") {
          store.markDraftMessageSentLocally(draft)
          feedbackMessage = "Draft marked sent locally."
        }
        .buttonStyle(.borderedProminent)
        .disabled(draft.status == .sentLocally)

        Button("Reopen", systemImage: "arrow.uturn.backward.circle.fill") {
          store.reopenDraftMessage(draft)
          feedbackMessage = "Draft reopened for follow-up."
        }
        .buttonStyle(.bordered)
        .disabled(draft.status == .reopened)
      }

      if let feedbackMessage {
        TaskActionFeedbackPanel(message: feedbackMessage, store: store)
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
  @State private var feedbackMessage: String?

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

          if item.linkedEntityType == .order || linkedOrder != nil {
            LinkedOrderContextPanel(
              order: linkedOrder,
              sourceLabel: item.sourceLabel,
              emptyDetail: "This action is tied to an order ID, but the matching local order was not found. Open the detailed task or handoff before completing the work.",
              linkedDetail: linkedOrder?.isInboxCreatedLocalOrder == true
                ? "Inbox-created order follow-up. Open the order before completing this task if tracking, destination, or dispatch setup still needs confirmation."
                : "This action has linked order context. Open the order before completing the task if tracking, destination, or dispatch setup still needs confirmation.",
              store: store
            )
          }

          if let linkedOrder, linkedOrder.isInboxCreatedLocalOrder {
            TaskInboxSourceTrail(order: linkedOrder, store: store)
          }

          if case .task(let task) = item.source, task.isPartialInboxOrderFollowUp {
            PartialInboxOrderTaskCallout(task: task, linkedOrder: linkedOrder)
          }

          if case .task(let task) = item.source, task.isReopenedInboxDispatchHandoff {
            ReopenedDispatchHandoffTaskCallout(linkedOrder: linkedOrder)
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
              feedbackMessage = "Task reopened for follow-up."
            }
            .buttonStyle(.bordered)
          } else {
            Button("Complete", systemImage: "checkmark.circle.fill") {
              store.completeReviewTask(task)
              feedbackMessage = "Task completed locally."
            }
            .buttonStyle(.borderedProminent)
          }
          Button("Reviewed", systemImage: "checkmark.shield.fill") {
            store.markReviewTaskReviewed(task)
            feedbackMessage = "Task marked reviewed locally."
          }
          .buttonStyle(.bordered)
          Button("Draft", systemImage: "envelope.open.fill") {
            store.createDraftMessage(from: task)
            feedbackMessage = "Draft message created from task. Check Drafts."
          }
          .buttonStyle(.bordered)

        case .handoff(let note):
          Button("Edit", systemImage: "pencil") {
            editingHandoff = note
          }
          .buttonStyle(.bordered)
          Button("Acknowledge", systemImage: "hand.thumbsup.fill") {
            store.acknowledgeHandoffNote(note)
            feedbackMessage = "Handoff acknowledged locally."
          }
          .buttonStyle(.bordered)
          if note.status == .completed {
            Button("Reopen", systemImage: "arrow.uturn.backward.circle.fill") {
              store.reopenHandoffNote(note)
              feedbackMessage = "Handoff reopened for follow-up."
            }
            .buttonStyle(.bordered)
          } else {
            Button("Complete", systemImage: "checkmark.circle.fill") {
              store.completeHandoffNote(note)
              feedbackMessage = "Handoff completed locally."
            }
            .buttonStyle(.borderedProminent)
          }
          Button("Reviewed", systemImage: "checkmark.shield.fill") {
            store.markHandoffNoteReviewed(note)
            feedbackMessage = "Handoff marked reviewed locally."
          }
          .buttonStyle(.bordered)
          Button("Task", systemImage: "checklist") {
            store.createReviewTask(from: note)
            feedbackMessage = "Follow-up task created from handoff. Check Tasks."
          }
          .buttonStyle(.bordered)
          Button("Draft", systemImage: "envelope.open.fill") {
            store.createDraftMessage(from: note)
            feedbackMessage = "Draft message created from handoff. Check Drafts."
          }
          .buttonStyle(.bordered)
        }
      }

      if let feedbackMessage {
        TaskActionFeedbackPanel(message: feedbackMessage, store: store)
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

private struct TaskActionFeedbackPanel: View {
  var message: String
  var store: ParcelOpsStore

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(message, systemImage: "checkmark.circle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.green)

      CompactActionRow {
        if message.localizedCaseInsensitiveContains("draft") {
          NavigationLink {
            CommunicationView(store: store)
          } label: {
            Label("Open Drafts", systemImage: "envelope.open.fill")
          }
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
      .controlSize(.small)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.green.opacity(0.12))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct TaskInboxSourceTrail: View {
  var order: TrackedOrder
  var store: ParcelOpsStore

  private var linkedEmails: [ForwardedEmailIntake] {
    let orderNumber = order.orderNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    return Array(
      store.intakeEmails
        .filter { email in
          email.linkedOrderID == order.id
            || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.detectedOrderNumber.localizedCaseInsensitiveContains(orderNumber))
            || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.subject.localizedCaseInsensitiveContains(orderNumber))
            || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.rawBodyPreview.localizedCaseInsensitiveContains(orderNumber))
        }
        .prefix(3)
    )
  }
  private var importItems: [ImportQueueItem] {
    Array(store.importQueueItems(for: order).prefix(3))
  }
  private var acceptanceRecords: [AcceptanceRecord] {
    Array(store.acceptanceRecords(for: order).prefix(3))
  }
  private var sourceTrailCount: Int {
    linkedEmails.count + importItems.count + acceptanceRecords.count
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Inbox source for this task", systemImage: "tray.and.arrow.down.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(sourceTrailCount == 0 ? .orange : .teal)

      CompactMetadataGrid(minimumWidth: 130) {
        Badge("\(linkedEmails.count) intake", color: linkedEmails.isEmpty ? .secondary : .teal)
        Badge("\(importItems.count) import", color: importItems.isEmpty ? .secondary : .blue)
        Badge("\(acceptanceRecords.count) acceptance", color: acceptanceRecords.isEmpty ? .secondary : .purple)
      }

      if sourceTrailCount == 0 {
        Text("This order was created from Inbox workflow, but no intake, import, or acceptance source matched the current order number. Open the order source trail before closing this task.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        ForEach(linkedEmails) { email in
          IntakeSourceContextPanel(
            email: email,
            store: store,
            manualDetail: "No mailbox ingest record is linked to this intake row. Treat it as local/manual evidence for this task.",
            linkedDetailSuffix: "Duplicate-safe source metadata is linked to this task handoff.",
            compact: true
          )
        }
        if !importItems.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Text("Import queue context")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            ImportQueueContextStrip(items: importItems)
          }
        }
        if !acceptanceRecords.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Text("Acceptance context")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            AcceptanceHistoryStrip(records: acceptanceRecords)
          }
        }
      }
    }
    .padding(10)
    .background((sourceTrailCount == 0 ? Color.orange : Color.teal).opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct PartialInboxOrderTaskCallout: View {
  var task: ReviewTask
  var linkedOrder: TrackedOrder?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Partial Inbox order handoff", systemImage: "exclamationmark.triangle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.orange)

      Text("Missing detail to confirm: \(task.partialInboxMissingSummary).")
        .font(.caption)
        .foregroundStyle(.secondary)

      if let linkedOrder {
        CompactMetadataGrid(minimumWidth: 130) {
          Badge(linkedOrder.trackingNumber.isPlaceholderValidationValue ? "Tracking missing" : "Tracking present", color: linkedOrder.trackingNumber.isPlaceholderValidationValue ? .orange : .green)
          Badge(linkedOrder.destination.isPlaceholderValidationValue ? "Destination missing" : "Destination present", color: linkedOrder.destination.isPlaceholderValidationValue ? .orange : .green)
          Badge(linkedOrder.reviewState.rawValue, color: linkedOrder.reviewState.color)
        }
      }

      Text("Open the order, edit the missing values, then complete and review this task.")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(10)
    .background(Color.orange.opacity(0.10))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct ReopenedDispatchHandoffTaskCallout: View {
  var linkedOrder: TrackedOrder?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Reopened dispatch handoff", systemImage: "arrow.counterclockwise.circle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.purple)

      Text("This task was created because an Inbox-created order handoff was reopened after dispatch setup had already been prepared. Check the order, linked manifest, and dispatch readiness before closing it again.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if let linkedOrder {
        CompactMetadataGrid(minimumWidth: 130) {
          Badge(linkedOrder.latestStatus, color: linkedOrder.reviewState == .accepted ? .green : .orange)
          Badge(linkedOrder.reviewState.rawValue, color: linkedOrder.reviewState.color)
          Badge(linkedOrder.carrier.isPlaceholderValidationValue ? "Carrier needs review" : linkedOrder.carrier, color: linkedOrder.carrier.isPlaceholderValidationValue ? .orange : .blue)
          Badge(linkedOrder.trackingNumber.isPlaceholderValidationValue ? "Tracking needs review" : "Tracking present", color: linkedOrder.trackingNumber.isPlaceholderValidationValue ? .orange : .green)
        }
      }

      Text("Use Open order to inspect the source trail and linked dispatch records. Complete this task after the handoff is complete again.")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(10)
    .background(Color.purple.opacity(0.10))
    .clipShape(RoundedRectangle(cornerRadius: 8))
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
            MVPEmptyState(title: "No tasks match this view", detail: "Clear filters or add a local task to test follow-up ownership.", symbol: "checklist", actionTitle: "Add task", action: store.addReviewTaskPlaceholder)
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
  @State private var feedbackMessage: String?

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

          if task.linkedEntityType == .order || linkedOrder != nil {
            LinkedOrderContextPanel(
              order: linkedOrder,
              sourceLabel: "Review task",
              emptyDetail: "This task references an order ID, but the matching local order was not found. Check the task details before completing it.",
              linkedDetail: "This task has linked order context. Open the order before completing it if tracking, destination, or dispatch setup still needs confirmation.",
              store: store
            )
          }

          if let store, let linkedOrder, linkedOrder.isInboxCreatedLocalOrder {
            TaskInboxSourceTrail(order: linkedOrder, store: store)
          }

          if task.isPartialInboxOrderFollowUp {
            PartialInboxOrderTaskCallout(task: task, linkedOrder: linkedOrder)
          }
        }
      }

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        if task.status == .completed {
          Button("Reopen", systemImage: "arrow.uturn.backward.circle.fill") {
            onReopen()
            feedbackMessage = "Task reopened for follow-up."
          }
            .buttonStyle(.bordered)
        } else {
          Button("Complete", systemImage: "checkmark.circle.fill") {
            onComplete()
            feedbackMessage = "Task completed locally."
          }
            .buttonStyle(.borderedProminent)
        }
        Button("Reviewed", systemImage: "checkmark.shield.fill") {
          onReviewed()
          feedbackMessage = "Task marked reviewed locally."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Draft message created from task. Check Drafts."
        }
          .buttonStyle(.bordered)
        Button("Contact", systemImage: "person.crop.circle.badge.plus") {
          onCreateContact()
          feedbackMessage = "Contact placeholder created from task."
        }
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", action: onRemove)
          .buttonStyle(.bordered)
      }

      if let feedbackMessage, let store {
        TaskActionFeedbackPanel(message: feedbackMessage, store: store)
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
