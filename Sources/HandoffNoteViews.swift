import SwiftUI

struct HandoffNotesView: View {
  var store: ParcelOpsStore
  @State private var selectedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedPriority: TaskPriority?
  @State private var selectedAssignee: String?
  @State private var selectedStatus: TaskStatus?
  @State private var selectedReviewState: ReviewState?
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var assignees: [String] {
    Array(Set(store.handoffNotes.map(\.assignee))).sorted()
  }

  private var filteredNotes: [HandoffNote] {
    store.filteredHandoffNotes(
      linkedEntityType: selectedEntityType,
      priority: selectedPriority,
      assignee: selectedAssignee,
      status: selectedStatus,
      reviewState: selectedReviewState
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
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

        filters

        SettingsPanel(title: "Notes", symbol: "arrow.left.arrow.right.square.fill") {
          HStack {
            Text("\(filteredNotes.count) visible handoff notes")
              .font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            Button("Add note", systemImage: "plus", action: store.addHandoffNotePlaceholder)
              .buttonStyle(.borderedProminent)
          }

          ForEach(filteredNotes) { note in
            HandoffNoteRow(note: note) { updatedNote in
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
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private var filters: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
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
      }
      HStack {
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
        Spacer()
        Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle") {
          selectedEntityType = nil
          selectedPriority = nil
          selectedAssignee = nil
          selectedStatus = nil
          selectedReviewState = nil
        }
        .buttonStyle(.bordered)
      }
    }
    .pickerStyle(.menu)
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct HandoffNoteRow: View {
  var note: HandoffNote
  var onSave: (HandoffNote) -> Void
  var onAcknowledge: () -> Void
  var onComplete: () -> Void
  var onReopen: () -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false

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

      HStack {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Acknowledge", systemImage: "hand.thumbsup.fill", action: onAcknowledge)
          .buttonStyle(.bordered)
        if note.status == .completed {
          Button("Reopen", systemImage: "arrow.uturn.backward.circle.fill", action: onReopen)
            .buttonStyle(.bordered)
        } else {
          Button("Complete", systemImage: "checkmark.circle.fill", action: onComplete)
            .buttonStyle(.borderedProminent)
        }
        Button("Reviewed", systemImage: "checkmark.shield.fill", action: onReviewed)
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill", action: onCreateDraft)
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", action: onRemove)
          .buttonStyle(.bordered)
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
