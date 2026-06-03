import SwiftUI

struct ExceptionPlaybooksView: View {
  var store: ParcelOpsStore
  @State private var selectedIssueType: ReconciliationIssueType?
  @State private var selectedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedPriority: TaskPriority?
  @State private var selectedEnabledState: Bool?
  @State private var selectedReviewState: ReviewState?
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.accepted, .needsReview, .monitor]

  private var filteredPlaybooks: [ExceptionPlaybook] {
    store.filteredExceptionPlaybooks(
      issueType: selectedIssueType,
      linkedEntityType: selectedEntityType,
      priority: selectedPriority,
      enabledState: selectedEnabledState,
      reviewState: selectedReviewState
    )
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

        SettingsPanel(title: "Playbooks", symbol: "book.closed.fill") {
          HStack {
            Text("\(filteredPlaybooks.count) visible playbooks")
              .font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            Button("Add playbook", systemImage: "plus", action: store.addExceptionPlaybookPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          ForEach(filteredPlaybooks) { playbook in
            ExceptionPlaybookRow(playbook: playbook) { updatedPlaybook in
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
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private var filters: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
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
      }
      HStack {
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
        Spacer()
        Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle") {
          selectedIssueType = nil
          selectedEntityType = nil
          selectedPriority = nil
          selectedEnabledState = nil
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

struct ExceptionPlaybookRow: View {
  var playbook: ExceptionPlaybook
  var onSave: (ExceptionPlaybook) -> Void
  var onToggle: () -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false

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

      HStack {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button(playbook.isEnabled ? "Disable" : "Enable", systemImage: playbook.isEnabled ? "pause.circle.fill" : "play.circle.fill", action: onToggle)
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.circle.fill", action: onReviewed)
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
      ExceptionPlaybookEditView(playbook: playbook) { updatedPlaybook in
        onSave(updatedPlaybook)
      }
    }
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
