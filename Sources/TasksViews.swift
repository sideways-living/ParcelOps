import SwiftUI

struct TasksView: View {
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

          HStack(spacing: 8) {
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

      HStack {
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
