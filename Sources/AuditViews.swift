import SwiftUI

struct AuditView: View {
  var store: ParcelOpsStore
  @State private var selectedAction: AuditAction?
  @State private var selectedEntityType: AuditEntityType?
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var filteredEvents: [AuditEvent] {
    store.auditEvents.filter { event in
      let matchesAction = selectedAction == nil || event.action == selectedAction
      let matchesEntity = selectedEntityType == nil || event.entityType == selectedEntityType
      return matchesAction && matchesEntity
    }
  }

  private var recentEvents: [AuditEvent] {
    Array(store.auditEvents.prefix(18))
  }

  private var workflowEvents: [AuditEvent] {
    recentEvents.filter(\.isWorkflowAction)
  }

  private var recordChangeEvents: [AuditEvent] {
    recentEvents.filter(\.isRecordChange)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header

        MVPWorkflowGuide(
          title: "Audit workflow",
          detail: "Use this screen to confirm local workflow actions, record changes, and follow-up creation while testing the MVP.",
          steps: [
            "Start with the grouped feed to understand what happened recently.",
            "Use the detailed log when you need to filter by action or record type.",
            "Create a task from an event if the history reveals follow-up work."
          ],
          symbol: "list.clipboard.fill"
        )

        activityFeed

        SettingsPanel(title: "Detailed audit log", symbol: "line.3.horizontal.decrease.circle.fill") {
          Text("Filter the full local audit history when you need to inspect a specific action or record type.")
            .font(.subheadline)
            .foregroundStyle(.secondary)

          filterBar

          if filteredEvents.isEmpty {
            MVPEmptyState(title: "No audit events match this view", detail: "Clear filters or perform a local action such as creating a task, reviewing intake, or updating dispatch readiness.", symbol: "list.clipboard.fill")
          } else {
            ForEach(filteredEvents.prefix(30)) { event in
              AuditEventRow(event: event) {
                store.createReviewTask(from: event)
              }
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Audit")
        .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
      Text("Readable local activity history for operator actions, record changes, reviews, and follow-up work.")
        .foregroundStyle(.secondary)

      MetricStrip(items: [
        ("Recent", "\(recentEvents.count)", .blue),
        ("Workflow", "\(workflowEvents.count)", .teal),
        ("Changes", "\(recordChangeEvents.count)", .orange),
        ("Tasks", "\(recentEvents.filter { $0.entityType == .reviewTask }.count)", .purple),
        ("Removed", "\(recentEvents.filter { $0.action == .removed }.count)", .red)
      ])
    }
  }

  private var activityFeed: some View {
    SettingsPanel(title: "Activity feed", symbol: "list.clipboard.fill") {
      VStack(alignment: .leading, spacing: 14) {
        Text("A simplified view of what changed recently, grouped by operator meaning rather than raw log order.")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        if recentEvents.isEmpty {
          MVPEmptyState(title: "No audit activity yet", detail: "Create, edit, review, or complete a local record and the action will appear here.", symbol: "list.clipboard.fill")
        } else {
          AuditFeedSection(title: "Workflow actions", detail: "Reviews, links, completions, acknowledgements, task and draft work.", events: workflowEvents.prefix(8).map { $0 }, onCreateTask: { event in
            store.createReviewTask(from: event)
          })

          AuditFeedSection(title: "Record changes", detail: "Creates, edits, removals, enables, disables, and pinned changes.", events: recordChangeEvents.prefix(8).map { $0 }, onCreateTask: { event in
            store.createReviewTask(from: event)
          })

          AuditFeedSection(title: "Earlier", detail: "Most recent local events in plain chronological order.", events: Array(recentEvents.dropFirst(8).prefix(8)), onCreateTask: { event in
            store.createReviewTask(from: event)
          })
        }
      }
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      Picker("Action", selection: $selectedAction) {
        Text("All actions").tag(nil as AuditAction?)
        ForEach(AuditAction.allCases) { action in
          Text(action.rawValue).tag(action as AuditAction?)
        }
      }
      .pickerStyle(.menu)

      Picker("Record", selection: $selectedEntityType) {
        Text("All records").tag(nil as AuditEntityType?)
        ForEach(AuditEntityType.allCases) { entityType in
          Text(entityType.rawValue).tag(entityType as AuditEntityType?)
        }
      }
      .pickerStyle(.menu)

      Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle") {
        selectedAction = nil
        selectedEntityType = nil
      }
      .buttonStyle(.bordered)
    }
  }
}

private struct AuditFeedSection: View {
  var title: String
  var detail: String
  var events: [AuditEvent]
  var onCreateTask: (AuditEvent) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.headline)
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if events.isEmpty {
        Text("No matching recent events.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.quinary)
          .clipShape(RoundedRectangle(cornerRadius: 8))
      } else {
        ForEach(events) { event in
          AuditActivityRow(event: event) {
            onCreateTask(event)
          }
        }
      }
    }
  }
}

private struct AuditActivityRow: View {
  var event: AuditEvent
  var onCreateTask: () -> Void
  @State private var showDetails = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: event.entityType.symbol)
          .foregroundStyle(event.action.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
              Text(event.entityLabel)
                .font(.headline)
              Text("\(event.action.operatorLabel) • \(event.timestamp)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Badge(event.action.rawValue, color: event.action.color)
          }

          Text(event.summary)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          CompactMetadataGrid {
            Badge(event.entityType.rawValue, color: event.action.color)
            Badge(event.categoryLabel, color: event.action.color)
            Label(event.actor, systemImage: "person.crop.circle.fill")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      if showDetails {
        AuditDetailStack(event: event)
      }

      CompactActionRow {
        if event.beforeDetail != nil || event.afterDetail != nil {
          Button(showDetails ? "Hide detail" : "Show detail", systemImage: "text.alignleft") {
            showDetails.toggle()
          }
          .buttonStyle(.bordered)
        }
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct AuditEventRow: View {
  var event: AuditEvent
  var onCreateTask: () -> Void = {}
  @State private var showDetails = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: event.entityType.symbol)
          .foregroundStyle(event.action.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(event.entityLabel)
                .font(.headline)
              Text("\(event.actor) • \(event.timestamp)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(event.action.rawValue, color: event.action.color)
          }

          Text(event.summary)
            .foregroundStyle(.secondary)

          CompactMetadataGrid {
            Badge(event.entityType.rawValue, color: event.action.color)
            Badge(event.categoryLabel, color: event.action.color)
            Text(event.entityID)
              .font(.caption2.monospaced())
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          }
        }
      }

      if showDetails {
        AuditDetailStack(event: event)
      }

      CompactActionRow {
        if event.beforeDetail != nil || event.afterDetail != nil {
          Button(showDetails ? "Hide detail" : "Show detail", systemImage: "text.alignleft") {
            showDetails.toggle()
          }
          .buttonStyle(.bordered)
        }
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct AuditDetailStack: View {
  var event: AuditEvent

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let beforeDetail = event.beforeDetail {
        AuditDetailBlock(title: "Before", detail: beforeDetail)
      }
      if let afterDetail = event.afterDetail {
        AuditDetailBlock(title: "After", detail: afterDetail)
      }
    }
  }
}

struct AuditDetailBlock: View {
  var title: String
  var detail: String

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(detail)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background(.background.opacity(0.65))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private extension AuditEvent {
  var isWorkflowAction: Bool {
    switch action {
    case .linked, .reviewed, .ignored, .cleared, .acknowledged, .completed, .reopened, .evaluated:
      true
    case .created, .edited, .enabled, .disabled, .pinned, .unpinned, .removed:
      entityType == .reviewTask || entityType == .draftMessage || entityType == .handoffNote
    }
  }

  var isRecordChange: Bool {
    switch action {
    case .created, .edited, .enabled, .disabled, .pinned, .unpinned, .removed:
      true
    case .linked, .reviewed, .ignored, .cleared, .acknowledged, .completed, .reopened, .evaluated:
      false
    }
  }

  var categoryLabel: String {
    if isWorkflowAction {
      "Workflow action"
    } else if isRecordChange {
      "Record change"
    } else {
      "Local activity"
    }
  }
}

private extension AuditAction {
  var operatorLabel: String {
    switch self {
    case .created: "Created locally"
    case .edited: "Record updated"
    case .enabled: "Enabled locally"
    case .disabled: "Disabled locally"
    case .linked: "Linked record"
    case .reviewed: "Reviewed locally"
    case .ignored: "Ignored locally"
    case .cleared: "Cleared locally"
    case .pinned: "Pinned filter"
    case .unpinned: "Unpinned filter"
    case .acknowledged: "Acknowledged"
    case .completed: "Completed"
    case .reopened: "Reopened"
    case .evaluated: "Manual check"
    case .removed: "Removed locally"
    }
  }
}
