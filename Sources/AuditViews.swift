import SwiftUI

struct AuditView: View {
  var store: ParcelOpsStore
  @State private var auditSearchText = ""
  @State private var selectedAction: AuditAction?
  @State private var selectedEntityType: AuditEntityType?
  @State private var showTechnicalDiagnostics = false
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var normalizedAuditSearch: String {
    auditSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  private var searchMatchedEvents: [AuditEvent] {
    store.auditEvents.filter(eventMatchesSearch)
  }

  private var filteredEvents: [AuditEvent] {
    searchMatchedEvents.filter { event in
      let matchesAction = selectedAction == nil || event.action == selectedAction
      let matchesEntity = selectedEntityType == nil || event.entityType == selectedEntityType
      let matchesDiagnosticMode = showTechnicalDiagnostics || !event.isTechnicalSpaceMailDiagnostic
      return matchesAction && matchesEntity && matchesDiagnosticMode
    }
  }

  private var hiddenFilteredTechnicalDiagnosticCount: Int {
    searchMatchedEvents.filter { event in
      let matchesAction = selectedAction == nil || event.action == selectedAction
      let matchesEntity = selectedEntityType == nil || event.entityType == selectedEntityType
      return matchesAction && matchesEntity && event.isTechnicalSpaceMailDiagnostic
    }.count
  }

  private var visibleActivityEvents: [AuditEvent] {
    showTechnicalDiagnostics ? searchMatchedEvents : searchMatchedEvents.filter { !$0.isTechnicalSpaceMailDiagnostic }
  }

  private var recentEvents: [AuditEvent] {
    Array(visibleActivityEvents.prefix(18))
  }

  private var workflowEvents: [AuditEvent] {
    recentEvents.filter(\.isWorkflowAction)
  }

  private var recordChangeEvents: [AuditEvent] {
    recentEvents.filter(\.isRecordChange)
  }

  private var inboxOrderHandoffEvents: [AuditEvent] {
    searchMatchedEvents.filter(\.isInboxOrderHandoff)
  }

  private var inboxDispatchHandoffEvents: [AuditEvent] {
    searchMatchedEvents.filter(\.isInboxDispatchHandoffTrail)
  }

  private var visibleInboxDispatchHandoffEvents: [AuditEvent] {
    Array(inboxDispatchHandoffEvents.prefix(8))
  }

  private var spaceMailEvidenceEvents: [AuditEvent] {
    searchMatchedEvents.filter { event in
      event.entityType == .spaceMailIMAPConnection
        || (event.entityType == .intakeEmail && event.summary.localizedCaseInsensitiveContains("mailbox"))
        || event.summary.localizedCaseInsensitiveContains("spacemail")
    }
  }

  private var visibleSpaceMailEvidenceEvents: [AuditEvent] {
    showTechnicalDiagnostics ? spaceMailEvidenceEvents : spaceMailEvidenceEvents.filter { !$0.isTechnicalSpaceMailDiagnostic }
  }

  private var hiddenTechnicalDiagnosticCount: Int {
    searchMatchedEvents.filter(\.isTechnicalSpaceMailDiagnostic).count
  }

  private var auditNextCheckTitle: String {
    if !spaceMailEvidenceEvents.isEmpty {
      return "Check the latest mailbox intake result"
    }
    if !inboxDispatchHandoffEvents.isEmpty {
      return "Confirm Inbox dispatch handoff trail"
    }
    if !inboxOrderHandoffEvents.isEmpty {
      return "Confirm Inbox-to-order handoff"
    }
    if !workflowEvents.isEmpty {
      return "Review recent operator actions"
    }
    if !recordChangeEvents.isEmpty {
      return "Review recent record changes"
    }
    return "No local audit checks yet"
  }

  private var auditNextCheckDetail: String {
    if !spaceMailEvidenceEvents.isEmpty {
      return "Start with SpaceMail intake evidence to confirm fetches, filtering, parser decisions, duplicates, and imported order signals."
    }
    if !inboxDispatchHandoffEvents.isEmpty {
      return "Check reopened and completed dispatch handoff events together so Inbox-created order follow-up does not get lost across Orders, Dispatch, and Tasks."
    }
    if !inboxOrderHandoffEvents.isEmpty {
      return "Check that created or linked orders still have a clear source trail back to Inbox, Import Queue, or Acceptance Review."
    }
    if !workflowEvents.isEmpty {
      return "Scan workflow actions for reviews, completions, handoffs, task creation, and draft work that may need follow-up."
    }
    if !recordChangeEvents.isEmpty {
      return "Use record changes to confirm creates, edits, removals, enables, disables, and pinned changes were intentional."
    }
    return "Perform a local action such as reviewing intake, creating a task, or editing an order; the result will appear here."
  }

  private var auditNextCheckSymbol: String {
    if !spaceMailEvidenceEvents.isEmpty { return "tray.and.arrow.down.fill" }
    if !inboxDispatchHandoffEvents.isEmpty { return "arrow.triangle.2.circlepath.circle.fill" }
    if !inboxOrderHandoffEvents.isEmpty { return "arrow.triangle.branch" }
    if !workflowEvents.isEmpty { return "checklist" }
    if !recordChangeEvents.isEmpty { return "pencil.and.list.clipboard" }
    return "list.clipboard.fill"
  }

  private func eventMatchesSearch(_ event: AuditEvent) -> Bool {
    let query = normalizedAuditSearch
    guard !query.isEmpty else { return true }
    let searchableText = [
      event.timestamp,
      event.actor,
      event.action.rawValue,
      event.entityType.rawValue,
      event.entityID,
      event.entityLabel,
      event.summary,
      event.beforeDetail ?? "",
      event.afterDetail ?? ""
    ].joined(separator: " ").lowercased()

    return searchableText.contains(query)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header

        auditNextCheckPanel

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

        SpaceMailQACheckCard(summary: store.spaceMailQACheckSummary)

        inboxDispatchHandoffTrailPanel

        activityFeed

        SettingsPanel(title: "Detailed audit log", symbol: "line.3.horizontal.decrease.circle.fill") {
          Text("Filter local audit history for a specific action or record type. Technical SpaceMail diagnostics stay hidden here too unless Show technical diagnostics is enabled.")
            .font(.subheadline)
            .foregroundStyle(.secondary)

          filterBar

          if hiddenFilteredTechnicalDiagnosticCount > 0 && !showTechnicalDiagnostics {
            Label("\(hiddenFilteredTechnicalDiagnosticCount) matching technical diagnostics are hidden. Turn on Show technical diagnostics in the activity feed when investigating parser, duplicate, or mailbox internals.", systemImage: "eye.slash")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          if filteredEvents.isEmpty {
            MVPEmptyState(title: "No operator audit events match this view", detail: hiddenFilteredTechnicalDiagnosticCount > 0 && !showTechnicalDiagnostics ? "Matching technical diagnostics are hidden. Enable Show technical diagnostics to inspect parser, duplicate, or mailbox internals." : "Clear filters or perform a local action such as creating a task, reviewing intake, or updating dispatch readiness.", symbol: "list.clipboard.fill")
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

  private var auditNextCheckPanel: some View {
    SettingsPanel(title: "Audit next check", symbol: auditNextCheckSymbol) {
      VStack(alignment: .leading, spacing: 10) {
        Text(auditNextCheckTitle)
          .font(.headline)
        Text(auditNextCheckDetail)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Mailbox evidence", "\(spaceMailEvidenceEvents.count)", spaceMailEvidenceEvents.isEmpty ? .secondary : .teal),
          ("Hidden technical", "\(showTechnicalDiagnostics ? 0 : hiddenTechnicalDiagnosticCount)", showTechnicalDiagnostics || hiddenTechnicalDiagnosticCount == 0 ? .secondary : .orange),
          ("Inbox handoffs", "\(inboxOrderHandoffEvents.count)", inboxOrderHandoffEvents.isEmpty ? .secondary : .blue),
          ("Dispatch trail", "\(inboxDispatchHandoffEvents.count)", inboxDispatchHandoffEvents.isEmpty ? .secondary : .purple),
          ("Workflow", "\(workflowEvents.count)", workflowEvents.isEmpty ? .secondary : .teal),
          ("Record changes", "\(recordChangeEvents.count)", recordChangeEvents.isEmpty ? .secondary : .orange)
        ])

        CompactActionRow {
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Open Mailbox Monitor", systemImage: "server.rack")
          }
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Open Inbox", systemImage: "tray.full.fill")
          }
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
        }
        .buttonStyle(.bordered)

        Text("Use Show technical diagnostics only when investigating mailbox connection or parser behavior; the default feed keeps routine operator history readable.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
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
        ("SpaceMail", "\(spaceMailEvidenceEvents.count)", spaceMailEvidenceEvents.isEmpty ? .secondary : .teal),
        ("Hidden tech", "\(showTechnicalDiagnostics ? 0 : hiddenTechnicalDiagnosticCount)", showTechnicalDiagnostics || hiddenTechnicalDiagnosticCount == 0 ? .secondary : .orange),
        ("Inbox handoff", "\(inboxOrderHandoffEvents.count)", inboxOrderHandoffEvents.isEmpty ? .green : .teal),
        ("Dispatch trail", "\(inboxDispatchHandoffEvents.count)", inboxDispatchHandoffEvents.isEmpty ? .green : .purple),
        ("Changes", "\(recordChangeEvents.count)", .orange),
        ("Tasks", "\(recentEvents.filter { $0.entityType == .reviewTask }.count)", .purple),
        ("Removed", "\(recentEvents.filter { $0.action == .removed }.count)", .red)
      ])
    }
  }

  @ViewBuilder
  private var inboxDispatchHandoffTrailPanel: some View {
    if !inboxDispatchHandoffEvents.isEmpty {
      SettingsPanel(title: "Inbox dispatch handoff trail", symbol: "arrow.triangle.2.circlepath.circle.fill") {
        VStack(alignment: .leading, spacing: 12) {
          Text("Recent local events that connect Inbox-created orders to Dispatch and Tasks. Use this trail when a handoff is reopened, completed, or resolved locally.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          MetricStrip(items: [
            ("Trail events", "\(inboxDispatchHandoffEvents.count)", .purple),
            ("Reopened", "\(inboxDispatchHandoffEvents.filter(\.isReopenedInboxDispatchHandoffTrail).count)", inboxDispatchHandoffEvents.contains(where: \.isReopenedInboxDispatchHandoffTrail) ? .orange : .secondary),
            ("Completed", "\(inboxDispatchHandoffEvents.filter(\.isCompletedInboxDispatchHandoffTrail).count)", inboxDispatchHandoffEvents.contains(where: \.isCompletedInboxDispatchHandoffTrail) ? .green : .secondary),
            ("Tasks", "\(inboxDispatchHandoffEvents.filter { $0.entityType == .reviewTask }.count)", inboxDispatchHandoffEvents.contains { $0.entityType == .reviewTask } ? .purple : .secondary)
          ])

          ForEach(visibleInboxDispatchHandoffEvents.prefix(4)) { event in
            HStack(alignment: .top, spacing: 10) {
              Image(systemName: event.inboxDispatchHandoffTrailSymbol)
                .foregroundStyle(event.inboxDispatchHandoffTrailColor)
                .frame(width: 22, height: 22)
              VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                  Text(event.entityLabel)
                    .font(.subheadline.weight(.semibold))
                  Spacer(minLength: 8)
                  Badge(event.inboxDispatchHandoffTrailLabel, color: event.inboxDispatchHandoffTrailColor)
                }
                Text(event.summary)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
                Text(event.inboxDispatchHandoffTrailGuidance)
                  .font(.caption)
                  .foregroundStyle(event.inboxDispatchHandoffTrailColor)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
            .padding(10)
            .background(event.inboxDispatchHandoffTrailColor.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 8))
          }
        }
      }
    }
  }

  private var activityFeed: some View {
    SettingsPanel(title: "Activity feed", symbol: "list.clipboard.fill") {
      VStack(alignment: .leading, spacing: 14) {
        Text("A simplified view of what changed recently, grouped by operator meaning rather than raw log order.")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        if !normalizedAuditSearch.isEmpty {
          Label("\(searchMatchedEvents.count) audit events match \"\(auditSearchText)\". Clear filters to return to the full activity feed.", systemImage: "magnifyingglass")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        if recentEvents.isEmpty {
          MVPEmptyState(title: normalizedAuditSearch.isEmpty ? "No audit activity yet" : "No audit events match", detail: normalizedAuditSearch.isEmpty ? "Create, edit, review, or complete a local record and the action will appear here." : "Clear the audit search or try a broader term such as SpaceMail, order, Inbox, tracking, parser, or the record label.", symbol: "list.clipboard.fill")
        } else {
          Toggle("Show technical diagnostics", isOn: $showTechnicalDiagnostics)
            .font(.caption.weight(.semibold))
            .toggleStyle(.switch)

          if hiddenTechnicalDiagnosticCount > 0 && !showTechnicalDiagnostics {
            Label("\(hiddenTechnicalDiagnosticCount) SpaceMail parser, duplicate, and no-change diagnostics are hidden from the operator feed. Open the detailed log or enable technical diagnostics when investigating intake internals.", systemImage: "line.3.horizontal.decrease.circle")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          AuditFeedSection(title: "SpaceMail intake evidence", detail: "Credential, refresh, filtering, parser, and local intake events for the current mailbox MVP.", events: visibleSpaceMailEvidenceEvents.prefix(8).map { $0 }, onCreateTask: { event in
            store.createReviewTask(from: event)
          })

          AuditFeedSection(title: "Inbox-to-order handoff", detail: "Order creation and review events from Inbox, Import Queue, and Acceptance Review.", events: inboxOrderHandoffEvents.prefix(8).map { $0 }, onCreateTask: { event in
            store.createReviewTask(from: event)
          })

          AuditFeedSection(title: "Inbox dispatch handoff trail", detail: "Reopened, completed, blocked, and resolved dispatch follow-up for Inbox-created orders.", events: visibleInboxDispatchHandoffEvents, onCreateTask: { event in
            store.createReviewTask(from: event)
          })

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
      TextField("Search audit, SpaceMail, order, tracking, parser reason, or record ID", text: $auditSearchText)
        .textFieldStyle(.roundedBorder)

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
        auditSearchText = ""
        selectedAction = nil
        selectedEntityType = nil
      }
      .buttonStyle(.bordered)
      .disabled(normalizedAuditSearch.isEmpty && selectedAction == nil && selectedEntityType == nil)
    }
  }
}

private struct AuditDispatchHandoffTrailCallout: View {
  var event: AuditEvent

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label(event.inboxDispatchHandoffTrailLabel, systemImage: event.inboxDispatchHandoffTrailSymbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(event.inboxDispatchHandoffTrailColor)
      Text(event.inboxDispatchHandoffTrailGuidance)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(event.inboxDispatchHandoffTrailColor.opacity(0.10))
    .clipShape(RoundedRectangle(cornerRadius: 8))
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

          if !event.operatorOutcomeLines.isEmpty {
            CompactMetadataGrid {
              ForEach(event.operatorOutcomeLines, id: \.self) { line in
                Badge(line, color: event.action.color)
              }
            }
          }

          if event.isInboxDispatchHandoffTrail {
            AuditDispatchHandoffTrailCallout(event: event)
          }

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

          if !event.operatorOutcomeLines.isEmpty {
            CompactMetadataGrid {
              ForEach(event.operatorOutcomeLines, id: \.self) { line in
                Badge(line, color: event.action.color)
              }
            }
          }

          if event.isInboxDispatchHandoffTrail {
            AuditDispatchHandoffTrailCallout(event: event)
          }

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
  var isTechnicalSpaceMailDiagnostic: Bool {
    guard entityType == .spaceMailIMAPConnection || entityType == .intakeEmail || summary.localizedCaseInsensitiveContains("spacemail") else {
      return false
    }

    let searchableText = [
      summary,
      entityLabel,
      beforeDetail ?? "",
      afterDetail ?? ""
    ].joined(separator: " ")

    return searchableText.localizedCaseInsensitiveContains("duplicate fetched mailbox message skipped")
      || searchableText.localizedCaseInsensitiveContains("refreshed with no intake field changes")
      || searchableText.localizedCaseInsensitiveContains("reprocessed with no field changes")
      || searchableText.localizedCaseInsensitiveContains("parser result:")
      || searchableText.localizedCaseInsensitiveContains("provider message id:")
  }

  var operatorOutcomeLines: [String] {
    guard let afterDetail else { return [] }

    let wantedPrefixes = [
      "Status:",
      "Fetch result:",
      "Fetched messages:",
      "Imported:",
      "Duplicate skips:",
      "Filtered non-order:",
      "Uncertain:",
      "Mailbox mode:",
      "Parser result:"
    ]

    let lines = afterDetail
      .components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { line in
        wantedPrefixes.contains { line.hasPrefix($0) }
      }

    return Array(lines.prefix(5))
  }

  var isInboxOrderHandoff: Bool {
    let searchableText = [
      summary,
      entityLabel,
      beforeDetail ?? "",
      afterDetail ?? ""
    ].joined(separator: " ")

    let mentionsOrderCreation =
      searchableText.localizedCaseInsensitiveContains("created from forwarded")
        || searchableText.localizedCaseInsensitiveContains("forwarded intake email")
        || searchableText.localizedCaseInsensitiveContains("import queue item")
        || searchableText.localizedCaseInsensitiveContains("acceptance review")
        || searchableText.localizedCaseInsensitiveContains("acceptance workflow")
        || searchableText.localizedCaseInsensitiveContains("after order creation")

    let relevantEntity =
      entityType == .order
        || entityType == .intakeEmail
        || entityType == .importQueueItem
        || entityType == .acceptanceRecord

    return relevantEntity && mentionsOrderCreation
  }

  var isInboxDispatchHandoffTrail: Bool {
    let searchableText = [
      summary,
      entityLabel,
      beforeDetail ?? "",
      afterDetail ?? ""
    ].joined(separator: " ")

    let mentionsInboxDispatch =
      searchableText.localizedCaseInsensitiveContains("Inbox dispatch")
        || searchableText.localizedCaseInsensitiveContains("Inbox-created order dispatch")
        || searchableText.localizedCaseInsensitiveContains("Reopened Inbox dispatch handoff")
        || searchableText.localizedCaseInsensitiveContains("dispatch handoff was completed locally")

    let relevantEntity =
      entityType == .order
        || entityType == .shipmentManifest
        || entityType == .dispatchChecklist
        || entityType == .reviewTask

    return relevantEntity && mentionsInboxDispatch
  }

  var isReopenedInboxDispatchHandoffTrail: Bool {
    isInboxDispatchHandoffTrail && (
      action == .reopened
        || summary.localizedCaseInsensitiveContains("reopened")
        || (afterDetail ?? "").localizedCaseInsensitiveContains("reopened")
    )
  }

  var isCompletedInboxDispatchHandoffTrail: Bool {
    isInboxDispatchHandoffTrail && (
      action == .completed
        || summary.localizedCaseInsensitiveContains("completed")
        || summary.localizedCaseInsensitiveContains("resolved")
        || (afterDetail ?? "").localizedCaseInsensitiveContains("completed locally")
    )
  }

  var inboxDispatchHandoffTrailLabel: String {
    if isReopenedInboxDispatchHandoffTrail { return "Reopened handoff" }
    if summary.localizedCaseInsensitiveContains("blocked") || summary.localizedCaseInsensitiveContains("skipped") { return "Needs dispatch check" }
    if entityType == .reviewTask && isCompletedInboxDispatchHandoffTrail { return "Task resolved" }
    if isCompletedInboxDispatchHandoffTrail { return "Handoff completed" }
    return "Inbox dispatch trail"
  }

  var inboxDispatchHandoffTrailGuidance: String {
    if isReopenedInboxDispatchHandoffTrail {
      return "Open the linked order or Dispatch queue, confirm manifest/readiness setup, then complete or block the handoff locally."
    }
    if summary.localizedCaseInsensitiveContains("blocked") {
      return "Resolve the blocked manifest or readiness checklist before treating the Inbox-created order as dispatch-ready."
    }
    if summary.localizedCaseInsensitiveContains("skipped") {
      return "No linked dispatch setup was found. Open the order to create or link the local manifest and readiness checklist."
    }
    if entityType == .reviewTask && isCompletedInboxDispatchHandoffTrail {
      return "The follow-up task was resolved when the dispatch handoff was completed again."
    }
    if isCompletedInboxDispatchHandoffTrail {
      return "The local dispatch handoff is complete. Audit confirms no mailbox, carrier, label, scanner, or external service action occurred."
    }
    return "Use this event to trace how an Inbox-created order moved through local dispatch follow-up."
  }

  var inboxDispatchHandoffTrailSymbol: String {
    if isReopenedInboxDispatchHandoffTrail { return "arrow.counterclockwise.circle.fill" }
    if summary.localizedCaseInsensitiveContains("blocked") || summary.localizedCaseInsensitiveContains("skipped") { return "exclamationmark.triangle.fill" }
    if isCompletedInboxDispatchHandoffTrail { return "checkmark.seal.fill" }
    return "arrow.triangle.2.circlepath.circle.fill"
  }

  var inboxDispatchHandoffTrailColor: Color {
    if isReopenedInboxDispatchHandoffTrail { return .purple }
    if summary.localizedCaseInsensitiveContains("blocked") || summary.localizedCaseInsensitiveContains("skipped") { return .orange }
    if isCompletedInboxDispatchHandoffTrail { return .green }
    return .teal
  }

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
