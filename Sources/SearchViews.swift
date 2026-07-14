import SwiftUI

struct SearchView: View {
  var store: ParcelOpsStore

  @State private var queryText = ""
  @State private var selectedEntityType: SearchEntityType?
  @State private var selectedReviewState: ReviewState?


  private var inboxCreatedOrdersWithSourceTrail: [TrackedOrder] {
    store.inboxCreatedOrders.filter { store.sourceTrailCount(for: $0, includeWishlist: true) > 0 }
  }

  private var inboxCreatedOrdersMissingSourceTrail: [TrackedOrder] {
    store.inboxCreatedOrders.filter { store.sourceTrailCount(for: $0, includeWishlist: true) == 0 }
  }

  private var uncertainSpaceMailCount: Int {
    store.spaceMailIMAPConnections.reduce(0) { $0 + $1.uncertainMessages.count }
  }

  private var uncertainGmailCount: Int {
    store.gmailMailboxConnections.reduce(0) { total, connection in
      total + max(connection.uncertainMessages?.count ?? 0, connection.lastRefreshUncertainCount ?? 0)
    }
  }

  private var uncertainMailboxCount: Int {
    uncertainSpaceMailCount + uncertainGmailCount
  }

  private var parserIssueCount: Int {
    store.intakeParserDiagnostics.count
  }

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.spaceMailIntakeHealthSummaries.first
  }

  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.gmailIntakeHealthSummaries.first
  }

  private var resultGroups: [SearchResultGroup] {
    store.groupedSearchResults(
      query: queryText,
      entityTypeFilter: selectedEntityType,
      reviewStateFilter: selectedReviewState
    )
  }

  private var sortedSavedFilters: [SavedFilter] {
    store.savedFilters.sorted { lhs, rhs in
      if lhs.isPinned != rhs.isPinned {
        return lhs.isPinned && !rhs.isPinned
      }
      return lhs.createdDate > rhs.createdDate
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 8) {
          Label("Search", systemImage: "magnifyingglass")
            .font(.largeTitle.bold())
          Text("Find local orders, Inbox intake, dispatch handoffs, tracking events, evidence, audit history, and automation rules.")
            .foregroundStyle(.secondary)
        }

        SearchControlPanel(
          queryText: $queryText,
          selectedEntityType: $selectedEntityType,
          selectedReviewState: $selectedReviewState
        ) {
          store.addSavedFilterPlaceholder(
            queryText: queryText,
            entityTypeFilter: selectedEntityType,
            reviewStateFilter: selectedReviewState
          )
        } onClear: {
          queryText = ""
          selectedEntityType = nil
          selectedReviewState = nil
        }

        SearchReadinessPanel(
          store: store,
          inboxCreatedOrderCount: store.inboxCreatedOrders.count,
          inboxCreatedOrdersWithSourceTrailCount: inboxCreatedOrdersWithSourceTrail.count,
          inboxCreatedOrdersMissingSourceTrail: Array(inboxCreatedOrdersMissingSourceTrail.prefix(3)),
          uncertainMailboxCount: uncertainMailboxCount,
          parserIssueCount: parserIssueCount,
          latestSpaceMailSummary: latestSpaceMailSummary,
          latestGmailSummary: latestGmailSummary
        )

        SearchOperatorHintsPanel { query, entity, reviewState in
          queryText = query
          selectedEntityType = entity
          selectedReviewState = reviewState
        }

        SettingsPanel(title: "Saved filters", symbol: "line.3.horizontal.decrease.circle.fill") {
          if sortedSavedFilters.isEmpty {
            Text("No saved filters yet.")
              .foregroundStyle(.secondary)
          } else {
            VStack(spacing: 10) {
              ForEach(sortedSavedFilters) { filter in
                SavedFilterRow(filter: filter) {
                  apply(filter)
                } onTogglePin: {
                  store.toggleSavedFilterPinned(filter)
                } onRemove: {
                  store.removeSavedFilter(filter)
                } onCreateTask: {
                  store.createReviewTask(from: filter)
                }
              }
            }
          }
        }

        SettingsPanel(title: "Results", symbol: "doc.text.magnifyingglass") {
          if resultGroups.isEmpty {
            Text("No matching local records.")
              .foregroundStyle(.secondary)
          } else {
            VStack(alignment: .leading, spacing: 16) {
              ForEach(resultGroups) { group in
                VStack(alignment: .leading, spacing: 10) {
                  HStack {
                    Label(group.entityType.rawValue, systemImage: group.entityType.symbol)
                      .font(.headline)
                    Spacer()
                    Badge("\(group.results.count)", color: group.entityType.color)
                  }

                  VStack(spacing: 8) {
                    ForEach(group.results) { result in
                      SearchResultRow(result: result, store: store)
                    }
                  }
                }
              }
            }
          }
        }
      }
      .padding()
    }
    .background(.background)
  }

  private func apply(_ filter: SavedFilter) {
    queryText = filter.queryText
    selectedEntityType = filter.entityTypeFilter
    selectedReviewState = filter.reviewStateFilter
  }


}

private struct SearchReadinessPanel: View {
  var store: ParcelOpsStore
  var inboxCreatedOrderCount: Int
  var inboxCreatedOrdersWithSourceTrailCount: Int
  var inboxCreatedOrdersMissingSourceTrail: [TrackedOrder]
  var uncertainMailboxCount: Int
  var parserIssueCount: Int
  var latestSpaceMailSummary: SpaceMailIntakeHealthSummary?
  var latestGmailSummary: GmailIntakeHealthSummary?

  private var filteredCount: Int {
    (latestSpaceMailSummary?.filteredCount ?? 0) + (latestGmailSummary?.filteredCount ?? 0)
  }

  private var importedCount: Int {
    (latestSpaceMailSummary?.importedCount ?? 0) + (latestGmailSummary?.importedCount ?? 0)
  }

  private var providerReleaseNeedsReview: Bool {
    store.mailboxProviderReleaseGateSummary.tone != "success"
      || store.mailboxProviderHandoffPacketSummary.tone != "success"
      || store.gmailMailboxConnections.contains { connection in
        store.gmailReleaseSelfCheckSummary(for: connection).items.contains { !$0.isComplete }
      }
  }

  private var providerRecoveryRows: [(label: String, status: String, detail: String, symbol: String, color: Color)] {
    var rows: [(label: String, status: String, detail: String, symbol: String, color: Color)] = []

    if let summary = latestSpaceMailSummary {
      let uncertain = summary.pendingUncertainReviewCount + summary.uncertainCount
      let status: String
      let detail: String
      let color: Color
      if summary.importedCount > 0 {
        status = "\(summary.importedCount) imported"
        detail = "Search Inbox intake, linked orders, and audit events for SpaceMail source evidence."
        color = .green
      } else if uncertain > 0 {
        status = "\(uncertain) uncertain"
        detail = "Open Mailbox Monitor to import or dismiss uncertain SpaceMail previews before searching Inbox."
        color = .orange
      } else if summary.filteredCount > 0 {
        status = "\(summary.filteredCount) filtered"
        detail = "Filtered SpaceMail stayed out of Inbox. Search Audit or Mailbox Monitor filtered examples if an expected order email is missing."
        color = .teal
      } else if summary.duplicateRefreshedCount > 0 {
        status = "\(summary.duplicateRefreshedCount) refreshed"
        detail = "Duplicate SpaceMail refresh updated existing Inbox rows. Search by order/tracking text or inspect Audit for the refreshed intake source."
        color = .teal
      } else if summary.duplicateCount > 0 {
        status = "\(summary.duplicateCount) duplicate"
        detail = "Duplicate SpaceMail rows refresh existing intake only; search by order/tracking text or inspect Audit for duplicate refresh details."
        color = .teal
      } else {
        status = "\(summary.fetchedCount) fetched"
        detail = summary.nextAction
        color = .secondary
      }
      rows.append(("SpaceMail", status, detail, "server.rack", color))
    }

    if let summary = latestGmailSummary {
      let uncertain = summary.pendingUncertainReviewCount + summary.uncertainCount
      let status: String
      let detail: String
      let color: Color
      if summary.importedCount > 0 {
        status = "\(summary.importedCount) imported"
        detail = "Search Inbox intake, linked orders, and audit events for Gmail source evidence."
        color = .green
      } else if uncertain > 0 {
        status = "\(uncertain) uncertain"
        detail = "Open Mailbox Monitor to import or dismiss uncertain Gmail previews before searching Inbox."
        color = .orange
      } else if summary.filteredCount > 0 {
        status = "\(summary.filteredCount) filtered"
        detail = "Filtered Gmail stayed out of Inbox. Search Audit or Mailbox Monitor filtered examples if an expected order email is missing."
        color = .teal
      } else if summary.duplicateRefreshedCount > 0 {
        status = "\(summary.duplicateRefreshedCount) refreshed"
        detail = "Duplicate Gmail refresh updated existing Inbox rows. Search by order/tracking text or inspect Audit for the refreshed intake source."
        color = .teal
      } else if summary.duplicateCount > 0 {
        status = "\(summary.duplicateCount) duplicate"
        detail = "Duplicate Gmail rows refresh existing intake only; search by order/tracking text or inspect Audit for duplicate refresh details."
        color = .teal
      } else {
        status = "\(summary.fetchedCount) fetched"
        detail = summary.nextAction
        color = .secondary
      }
      rows.append(("Gmail", status, detail, "envelope.badge.shield.half.filled", color))
    }

    return rows
  }

  private var tone: Color {
    if providerReleaseNeedsReview { return .orange }
    if !inboxCreatedOrdersMissingSourceTrail.isEmpty || uncertainMailboxCount > 0 || parserIssueCount > 0 { return .orange }
    if inboxCreatedOrderCount > 0 || importedCount > 0 { return .green }
    return .teal
  }

  private var title: String {
    if providerReleaseNeedsReview { return "Review mailbox provider release context" }
    if !inboxCreatedOrdersMissingSourceTrail.isEmpty { return "Trace Inbox-created orders" }
    if uncertainMailboxCount > 0 { return "Review uncertain mailbox mail" }
    if parserIssueCount > 0 { return "Parser diagnostics are available" }
    if inboxCreatedOrderCount > 0 { return "Search is ready for handoff checks" }
    return "Use Search to recover local context"
  }

  private var detail: String {
    if providerReleaseNeedsReview {
      return "Search can recover mailbox source context, but provider release gates or handoff notes still need review. Confirm those before treating a test pass as complete."
    }
    if !inboxCreatedOrdersMissingSourceTrail.isEmpty {
      return "Some Inbox-created orders do not currently match intake, import, or acceptance source context. Open them here before closing related handoff work."
    }
    if uncertainMailboxCount > 0 {
      return "Uncertain mixed-mailbox messages stay out of Inbox until they are imported or dismissed from Mailbox Monitor."
    }
    if parserIssueCount > 0 {
      return "Parser diagnostics are hidden from the primary Inbox queue by default. Use Search or Mailbox Monitor when investigating a specific intake row."
    }
    if inboxCreatedOrderCount > 0 {
      return "Inbox-created orders can be searched alongside intake emails, audit events, and dispatch handoff context."
    }
    return "Search local JSON records when a user asks where an order, intake email, mailbox result, or audit event came from."
  }

  var body: some View {
    SettingsPanel(title: "Search readiness", symbol: "scope") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: tone == .green ? "checkmark.seal.fill" : "magnifyingglass.circle.fill")
            .foregroundStyle(tone)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(title)
              .font(.headline)
            Text(detail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 8)
          Badge(inboxCreatedOrdersMissingSourceTrail.isEmpty ? "Ready" : "Trace", color: tone)
        }

        MetricStrip(items: [
          ("Inbox orders", "\(inboxCreatedOrderCount)", inboxCreatedOrderCount == 0 ? .secondary : .teal),
          ("With source", "\(inboxCreatedOrdersWithSourceTrailCount)", inboxCreatedOrderCount == 0 ? .secondary : (inboxCreatedOrdersMissingSourceTrail.isEmpty ? .green : .orange)),
          ("Uncertain", "\(uncertainMailboxCount)", uncertainMailboxCount == 0 ? .green : .orange),
          ("Parser checks", "\(parserIssueCount)", parserIssueCount == 0 ? .green : .orange),
          ("Filtered", "\(filteredCount)", filteredCount == 0 ? .secondary : .teal),
          ("Imported", "\(importedCount)", importedCount == 0 ? .secondary : .green),
          ("Provider gate", providerReleaseNeedsReview ? "Review" : "Ready", providerReleaseNeedsReview ? .orange : .green)
        ])

        if providerReleaseNeedsReview {
          VStack(alignment: .leading, spacing: 8) {
            Text("Mailbox provider release context")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            MailboxProviderReleaseGateCard(summary: store.mailboxProviderReleaseGateSummary, store: store)
            MailboxProviderHandoffPacketCard(packet: store.mailboxProviderHandoffPacketSummary, store: store)

            GmailReleaseBoundaryPanel(
              store: store,
              title: "Gmail search recovery checks",
              lead: "Use this when a Gmail order email is missing from Search results. Setup, sign-in, labels, classifier review, Inbox handoff, and Audit evidence must be visible before a Gmail test pass is considered complete.",
              sourceMetricTitle: "Gmail fetched",
              sourceCount: latestGmailSummary?.fetchedCount ?? 0,
              boundaryDetail: "Local-only boundary: this panel does not open Google sign-in, fetch Gmail, store token values, change search indexes, or mutate mailbox messages."
            )

            if !store.gmailMailboxConnections.isEmpty {
              GmailPostRefreshActionCard(plan: store.gmailPostRefreshActionPlan)
            }
          }
        }

        if !providerRecoveryRows.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Mailbox provider recovery")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
              ForEach(providerRecoveryRows, id: \.label) { row in
                HStack(alignment: .top, spacing: 10) {
                  Image(systemName: row.symbol)
                    .foregroundStyle(row.color)
                    .frame(width: 22)
                  VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                      Text(row.label)
                        .font(.caption.weight(.semibold))
                      Spacer(minLength: 8)
                      Badge(row.status, color: row.color)
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

        if !inboxCreatedOrdersMissingSourceTrail.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Orders missing source context")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            ForEach(inboxCreatedOrdersMissingSourceTrail) { order in
              NavigationLink {
                OrderDetailView(order: order, store: store)
              } label: {
                HStack(alignment: .top, spacing: 8) {
                  Image(systemName: "link.badge.plus")
                    .foregroundStyle(.orange)
                  VStack(alignment: .leading, spacing: 3) {
                    Text("\(order.store) • \(order.orderNumber)")
                      .font(.caption.weight(.semibold))
                    Text("Open source trail and confirm the intake/import/acceptance handoff.")
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                  }
                  Spacer()
                }
                .padding(8)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
              }
              .buttonStyle(.plain)
            }
          }
        }

        CompactActionRow {
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Mailbox Monitor", systemImage: "server.rack")
          }
          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Audit", systemImage: "list.clipboard.fill")
          }
          NavigationLink {
            OrdersView(store: store)
          } label: {
            Label("Orders", systemImage: "shippingbox.fill")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }
}

private struct SearchOperatorHintsPanel: View {
  var onApply: (String, SearchEntityType?, ReviewState?) -> Void

  private let hints: [SearchOperatorHint] = [
    SearchOperatorHint(title: "Inbox-created orders", query: "Inbox-created order", entityType: .order, reviewState: nil, symbol: "tray.and.arrow.down.fill", detail: "Find orders created from intake, import, or acceptance handoff."),
    SearchOperatorHint(title: "Missing source trail", query: "No linked intake import acceptance source", entityType: .order, reviewState: nil, symbol: "link.badge.plus", detail: "Find Inbox-created orders that need source context checked before handoff closure."),
    SearchOperatorHint(title: "Linked Inbox orders", query: "Linked Inbox intake", entityType: .intakeEmail, reviewState: nil, symbol: "link.circle.fill", detail: "Find intake rows that already carry linked order context."),
    SearchOperatorHint(title: "Uncertain mailbox mail", query: "uncertain mixed mailbox Gmail SpaceMail", entityType: .auditEvent, reviewState: nil, symbol: "questionmark.folder.fill", detail: "Find local evidence for mixed-mailbox messages that require operator review."),
    SearchOperatorHint(title: "Gmail source trails", query: "Gmail Google Workspace mailbox source trail", entityType: .intakeEmail, reviewState: nil, symbol: "envelope.badge.shield.half.filled", detail: "Find intake rows captured through Gmail or Google Workspace manual refresh."),
    SearchOperatorHint(title: "Reopened dispatch handoffs", query: "reopened dispatch handoff", entityType: .order, reviewState: nil, symbol: "arrow.counterclockwise.circle.fill", detail: "Find Inbox-created orders whose local dispatch handoff was reopened."),
    SearchOperatorHint(title: "Missing tracking", query: "tracking number needs review", entityType: .intakeEmail, reviewState: .needsReview, symbol: "number.circle.fill", detail: "Find intake rows where the parser did not extract a usable tracking value."),
    SearchOperatorHint(title: "SpaceMail parser checks", query: "parser diagnostics", entityType: .intakeEmail, reviewState: nil, symbol: "server.rack", detail: "Find intake and audit clues from mixed-mailbox parsing and classifier work.")
  ]

  var body: some View {
    SettingsPanel(title: "Useful operator searches", symbol: "sparkle.magnifyingglass") {
      VStack(alignment: .leading, spacing: 10) {
        Text("Start with these shortcuts when tracing Inbox-created orders, dispatch handoffs, or parser follow-up. They only filter local JSON records.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], spacing: 10) {
          ForEach(hints) { hint in
            Button {
              onApply(hint.query, hint.entityType, hint.reviewState)
            } label: {
              VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                  Label(hint.title, systemImage: hint.symbol)
                    .font(.subheadline.weight(.semibold))
                  Spacer(minLength: 8)
                  Badge(hint.entityType?.rawValue ?? "All", color: hint.entityType?.color ?? .blue)
                }
                Text(hint.detail)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
                Text("Search: \(hint.query)")
                  .font(.caption2.monospaced())
                  .foregroundStyle(.tertiary)
                  .lineLimit(1)
                  .truncationMode(.tail)
              }
              .padding(10)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(.quaternary.opacity(0.24))
              .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }
}

private struct SearchOperatorHint: Identifiable {
  var id: String { title }
  var title: String
  var query: String
  var entityType: SearchEntityType?
  var reviewState: ReviewState?
  var symbol: String
  var detail: String
}

struct SearchControlPanel: View {
  @Binding var queryText: String
  @Binding var selectedEntityType: SearchEntityType?
  @Binding var selectedReviewState: ReviewState?
  var onSave: () -> Void
  var onClear: () -> Void

  var body: some View {
    SettingsPanel(title: "Search controls", symbol: "slider.horizontal.3") {
      FilterControlGrid {
        TextField("Search local records", text: $queryText)

        Picker("Entity", selection: $selectedEntityType) {
          Text("All records").tag(nil as SearchEntityType?)
          ForEach(SearchEntityType.allCases) { type in
            Text(type.rawValue).tag(type as SearchEntityType?)
          }
        }

        Picker("Review", selection: $selectedReviewState) {
          Text("All review states").tag(nil as ReviewState?)
          Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted as ReviewState?)
          Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview as ReviewState?)
          Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor as ReviewState?)
        }

        Button("Save current", systemImage: "plus", action: onSave)
        Button("Clear", systemImage: "xmark.circle", action: onClear)
          .foregroundStyle(.secondary)
      }
    }
  }
}

struct SavedFilterRow: View {
  var filter: SavedFilter
  var onApply: () -> Void
  var onTogglePin: () -> Void
  var onRemove: () -> Void
  var onCreateTask: () -> Void = {}
  @State private var feedbackMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: filter.isPinned ? "pin.fill" : "line.3.horizontal.decrease.circle")
          .foregroundStyle(filter.isPinned ? .purple : .secondary)
          .frame(width: 22)

        VStack(alignment: .leading, spacing: 5) {
          Text(filter.name)
            .font(.headline)
          Text(filterDescription)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text("Created \(filter.createdDate)")
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
      }

      CompactActionRow {
        Button("Apply", systemImage: "arrow.down.circle") {
          onApply()
          feedbackMessage = "Saved filter applied locally to the current search view."
        }
        Button(filter.isPinned ? "Unpin" : "Pin", systemImage: filter.isPinned ? "pin.slash" : "pin") {
          onTogglePin()
          feedbackMessage = filter.isPinned ? "Saved filter unpinned locally." : "Saved filter pinned locally for faster access."
        }
        Button("Remove", systemImage: "trash") {
          onRemove()
          feedbackMessage = "Saved filter removed locally. No records or external systems were changed."
        }
          .foregroundStyle(.red)
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Review task created from this saved filter for local follow-up."
        }
      }
      .buttonStyle(.borderless)

      if let feedbackMessage {
        SavedFilterActionFeedbackPanel(message: feedbackMessage)
      }
    }
    .padding(12)
    .background(.quaternary.opacity(0.35))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  private var filterDescription: String {
    let query = filter.queryText.isEmpty ? "any text" : "\"\(filter.queryText)\""
    let entity = filter.entityTypeFilter?.rawValue ?? "all records"
    let review = filter.reviewStateFilter?.rawValue ?? "all review states"
    return "\(query), \(entity), \(review)"
  }
}

private struct SavedFilterActionFeedbackPanel: View {
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

struct SearchResultRow: View {
  var result: SearchResult
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }

  private var badgeText: String {
    result.severity?.rawValue ?? result.reviewState?.rawValue ?? result.entityType.rawValue
  }

  private var badgeColor: Color {
    result.severity?.color ?? result.reviewState?.color ?? result.entityType.color
  }

  private var openActionLabel: String {
    switch result.entityType {
    case .order: return "Open order"
    case .intakeEmail: return "Open Mailbox"
    case .trackingEvent: return "Open Tracking"
    case .evidence: return "Open Evidence"
    case .auditEvent: return "Open Audit"
    case .automationRule: return "Open Automation"
    }
  }

  private var openActionSymbol: String {
    switch result.entityType {
    case .order: return "shippingbox.fill"
    case .intakeEmail: return "envelope.open.fill"
    case .trackingEvent: return "location.fill.viewfinder"
    case .evidence: return "paperclip"
    case .auditEvent: return "list.clipboard.fill"
    case .automationRule: return "flowchart.fill"
    }
  }

  @ViewBuilder
  private var openDestination: some View {
    switch result.entityType {
    case .order:
      if let id = UUID(uuidString: result.linkedEntityID),
         let order = store.orders.first(where: { $0.id == id }) {
        OrderDetailView(order: order, store: store)
      } else {
        OrdersView(store: store)
      }
    case .intakeEmail:
      MailboxView(store: store)
    case .trackingEvent:
      TrackingView(store: store)
    case .evidence:
      EvidenceView(store: store)
    case .auditEvent:
      AuditView(store: store)
    case .automationRule:
      AutomationView(store: store)
    }
  }

  private var intakeSourceChips: [(String, Color)] {
    guard result.entityType == .intakeEmail,
          let sourceLine = result.detail.lineOrSentence(after: "Inbox source:")
    else { return [] }

    let sourceParts = sourceLine
      .components(separatedBy: "•")
      .first?
      .components(separatedBy: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty } ?? []

    return sourceParts.prefix(3).map { part in
      (part, part.localizedCaseInsensitiveContains("imported") ? .green : sourceColor(for: part))
    }
  }

  private var sourceTrailDetail: String? {
    if result.entityType == .intakeEmail {
      return result.detail.lineOrSentence(after: "Inbox source:")
    }

    guard result.entityType == .order,
          result.subtitle.localizedCaseInsensitiveContains("Inbox-created")
            || result.detail.localizedCaseInsensitiveContains("Inbox handoff")
    else { return nil }

    return result.detail.lineOrSentence(after: "Inbox handoff:")
      ?? "Inbox-created order. Open the order to inspect intake, import, acceptance, and dispatch handoff context."
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: result.entityType.symbol)
          .foregroundStyle(result.entityType.color)
          .frame(width: 22)

        VStack(alignment: .leading, spacing: 4) {
          Text(result.title)
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)

          Text(result.subtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(isCompact ? 3 : 2)
        }

        if !isCompact {
          Spacer(minLength: 8)
          Badge(badgeText, color: badgeColor)
        }
      }

      if isCompact {
        Badge(badgeText, color: badgeColor)
      }

      Text(result.detail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(isCompact ? 4 : 3)

      if let sourceTrailDetail {
        VStack(alignment: .leading, spacing: 6) {
          Label(result.entityType == .order ? "Inbox order trail" : "Inbox source", systemImage: "tray.and.arrow.down.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(result.entityType == .order ? .teal : result.entityType.color)

          if !intakeSourceChips.isEmpty {
            CompactMetadataGrid(minimumWidth: 110) {
              ForEach(Array(intakeSourceChips.enumerated()), id: \.offset) { _, chip in
                Badge(chip.0, color: chip.1)
              }
            }
          }

          Text(sourceTrailDetail)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(isCompact ? 4 : 3)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((result.entityType == .order ? Color.teal : result.entityType.color).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }

      CompactActionRow {
        NavigationLink {
          openDestination
        } label: {
          Label(openActionLabel, systemImage: openActionSymbol)
        }
        .buttonStyle(.bordered)
      }

      Text(result.linkedEntityID)
        .font(.caption2.monospaced())
        .foregroundStyle(.tertiary)
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .padding(12)
    .background(.quaternary.opacity(0.24))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  private func sourceColor(for text: String) -> Color {
    if text.localizedCaseInsensitiveContains("SpaceMail") { return .teal }
    if text.localizedCaseInsensitiveContains("Graph") { return .blue }
    if text.localizedCaseInsensitiveContains("Mock") || text.localizedCaseInsensitiveContains("test") { return .purple }
    if text.localizedCaseInsensitiveContains("manual") { return .secondary }
    return result.entityType.color
  }
}

private extension String {
  func lineOrSentence(after marker: String) -> String? {
    guard let markerRange = range(of: marker, options: [.caseInsensitive]) else { return nil }
    let remainder = self[markerRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
    guard !remainder.isEmpty else { return nil }

    let newlineBound = remainder.firstIndex(of: "\n")
    let periodBound = remainder.firstIndex(of: ".")
    let end = [newlineBound, periodBound].compactMap { $0 }.min() ?? remainder.endIndex
    let value = remainder[..<end].trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : String(value)
  }
}
