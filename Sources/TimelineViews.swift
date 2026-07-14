import SwiftUI

struct TimelineView: View {
  var store: ParcelOpsStore
  @State private var entityFilter: TimelineEntityType?
  @State private var riskFilter: TimelineRiskLevel?
  @State private var reviewFilter: ReviewState?
  @State private var sourceFilter: TimelineActivitySource?
  @State private var timelineSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var baseFilteredActivities: [TimelineActivity] {
    store.filteredTimelineActivities(
      entityType: entityFilter,
      risk: riskFilter,
      reviewState: reviewFilter,
      source: sourceFilter
    )
  }

  private var filteredActivities: [TimelineActivity] {
    let query = timelineSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredActivities }
    return baseFilteredActivities.filter { activity in
      timelineActivity(activity, matches: query)
    }
  }

  private var hasActiveFilters: Bool {
    entityFilter != nil
      || riskFilter != nil
      || reviewFilter != nil
      || sourceFilter != nil
      || !timelineSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  private var inboxDispatchTimelineActivities: [TimelineActivity] {
    store.timelineActivities.filter(\.isInboxDispatchHandoffActivity)
  }

  private var visibleInboxDispatchTimelineActivities: [TimelineActivity] {
    Array(inboxDispatchTimelineActivities.prefix(4))
  }



  private var sourceOrders: [TrackedOrder] {
    store.operatorSourceOrders
  }

  private var sourceOrdersWithSourceTrail: [TrackedOrder] {
    sourceOrders.filter { sourceTrailCount(for: $0) > 0 }
  }

  private var sourceOrdersMissingSourceTrail: [TrackedOrder] {
    sourceOrders.filter { sourceTrailCount(for: $0) == 0 }
  }

  private var inboxSourceTimelineActivities: [TimelineActivity] {
    store.timelineActivities.filter { activity in
      let text = [
        activity.title,
        activity.subtitle,
        activity.detail,
        activity.suggestedActionText,
        activity.source.rawValue
      ].joined(separator: " ")
      return text.localizedCaseInsensitiveContains("Inbox source")
        || text.localizedCaseInsensitiveContains("Inbox-created")
        || text.localizedCaseInsensitiveContains("Wishlist")
        || text.localizedCaseInsensitiveContains("purchase handoff")
        || text.localizedCaseInsensitiveContains("forwarded email")
        || text.localizedCaseInsensitiveContains("Import Queue")
        || text.localizedCaseInsensitiveContains("Acceptance Review")
    }
  }

  private var mailboxProviderTimelineRows: [(label: String, count: Int, detail: String, symbol: String, color: Color)] {
    var counts: [String: Int] = [:]
    var tones: [String: String] = [:]

    for email in store.intakeEmails {
      let summary = store.intakeSourceSummary(for: email)
      counts[summary.label, default: 0] += 1
      tones[summary.label] = summary.tone
    }

    return counts
      .map { label, count in
        let tone = tones[label] ?? ""
        let detail: String
        switch tone {
        case "spacemail":
          detail = "SpaceMail intake can appear as intake review, order creation, tracking, dispatch, task, and audit follow-up.\(providerRefreshSuffix(for: tone))"
        case "gmail":
          detail = "Gmail intake can appear as intake review, order creation, tracking, dispatch, task, and audit follow-up.\(providerRefreshSuffix(for: tone))"
        case "mock":
          detail = "Mock mailbox intake supports local workflow testing. Confirm live work against the active mailbox provider when available."
        default:
          detail = "Local mailbox intake can appear across the timeline once it is linked to an order or follow-up record."
        }
        return (label: label, count: count, detail: detail, symbol: providerSymbol(for: tone, label: label), color: providerColor(for: tone))
      }
      .sorted { lhs, rhs in
        if lhs.count != rhs.count { return lhs.count > rhs.count }
        return lhs.label < rhs.label
      }
  }

  private func providerRefreshSuffix(for tone: String) -> String {
    let refreshedCount: Int
    switch tone {
    case "spacemail":
      refreshedCount = store.spaceMailIntakeHealthSummaries.reduce(0) { $0 + $1.duplicateRefreshedCount }
    case "gmail":
      refreshedCount = store.gmailIntakeHealthSummaries.reduce(0) { $0 + $1.duplicateRefreshedCount }
    default:
      refreshedCount = 0
    }
    guard refreshedCount > 0 else { return "" }
    return " \(refreshedCount) duplicate refresh\(refreshedCount == 1 ? "" : "es") updated existing Inbox rows without creating new timeline items."
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filters
        inboxSourceTrailTimelinePanel
        mailboxProviderReleaseTimelinePanel
        gmailTimelineReleaseBoundary
        mailboxProviderTimelinePanel
        inboxDispatchTimelinePanel

        SettingsPanel(title: "Timeline results", symbol: "calendar.badge.clock") {
          HStack {
            Text("\(filteredActivities.count) visible timeline activities")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredActivities.count) after filters", color: .blue)
            }
            Spacer()
          }
        }

        if filteredActivities.isEmpty {
          MVPEmptyState(title: "No timeline activity matches this view", detail: hasActiveFilters ? "Clear search or filters to return to the full local timeline." : "Timeline activity appears here as local intake, order, tracking, task, and audit records change.", symbol: "calendar.badge.clock", actionTitle: hasActiveFilters ? "Clear filters" : nil, action: hasActiveFilters ? clearFilters : nil)
        } else {
          ForEach(store.groupedTimelineActivities(filteredActivities)) { group in
            SettingsPanel(title: group.title, symbol: group.symbol) {
              ForEach(group.activities) { activity in
                TimelineActivityRow(activity: activity, store: store, linkedOrder: linkedOrder(for: activity), shipmentGroups: store.suggestedShipmentGroups(for: activity), importQueueItems: store.importQueueItems(for: activity), acceptanceRecords: store.acceptanceRecords(for: activity)) {
                  store.createReviewTask(from: activity)
                } onCreateDraft: {
                  store.createDraftMessage(from: activity)
                }
              }
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
    .background(.regularMaterial)
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Operational timeline")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("A unified local feed across orders, intake, tracking, evidence, tasks, policies, communication, directory records, accounts, profiles, automation, search, and audit history.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      Badge("\(store.timelineWatchlist.count)", color: .red)
    }
  }

  private var filters: some View {
    FilterControlGrid {
      TextField("Search timeline, order, tracking, intake, acceptance, source, or action", text: $timelineSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Entity", selection: $entityFilter) {
        Text("All entities").tag(TimelineEntityType?.none)
        ForEach(TimelineEntityType.allCases) { type in
          Label(type.rawValue, systemImage: type.symbol).tag(Optional(type))
        }
      }
      Picker("Risk", selection: $riskFilter) {
        Text("All risk").tag(TimelineRiskLevel?.none)
        ForEach(TimelineRiskLevel.allCases) { risk in
          Text(risk.rawValue).tag(Optional(risk))
        }
      }
      Picker("Review", selection: $reviewFilter) {
        Text("All review").tag(ReviewState?.none)
        ForEach(reviewStates, id: \.self) { state in
          Text(state.rawValue).tag(Optional(state))
        }
      }
      Picker("Source", selection: $sourceFilter) {
        Text("All sources").tag(TimelineActivitySource?.none)
        ForEach(TimelineActivitySource.allCases) { source in
          Label(source.rawValue, systemImage: source.symbol).tag(Optional(source))
        }
      }

      if hasActiveFilters {
        Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle") {
          clearFilters()
        }
        .buttonStyle(.bordered)
      }
    }
  }

  @ViewBuilder
  private var inboxSourceTrailTimelinePanel: some View {
    if !sourceOrders.isEmpty || !inboxSourceTimelineActivities.isEmpty {
      SettingsPanel(title: "Inbox/Wishlist source trail timeline", symbol: "link.badge.plus") {
        VStack(alignment: .leading, spacing: 12) {
          Text("Use this before closing handoff work: Inbox-created and Wishlist-linked orders should remain traceable to intake, import, acceptance, or purchase handoff context.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          MetricStrip(items: [
            ("Inbox orders", "\(store.inboxCreatedOrders.count)", store.inboxCreatedOrders.isEmpty ? .secondary : .teal),
            ("Wishlist orders", "\(store.wishlistLinkedOrders.count)", store.wishlistLinkedOrders.isEmpty ? .secondary : .pink),
            ("With source", "\(sourceOrdersWithSourceTrail.count)", sourceOrdersMissingSourceTrail.isEmpty ? .green : .orange),
            ("Missing source", "\(sourceOrdersMissingSourceTrail.count)", sourceOrdersMissingSourceTrail.isEmpty ? .green : .orange),
            ("Timeline events", "\(inboxSourceTimelineActivities.count)", inboxSourceTimelineActivities.isEmpty ? .secondary : .blue)
          ])

          if sourceOrdersMissingSourceTrail.isEmpty {
            Label(sourceOrders.isEmpty ? "No Inbox-created or Wishlist-linked orders exist yet." : "All current Inbox-created and Wishlist-linked orders have local source context.", systemImage: "checkmark.seal.fill")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.green)
          } else {
            ForEach(sourceOrdersMissingSourceTrail.prefix(4)) { order in
              NavigationLink {
                OrderDetailView(order: order, store: store)
              } label: {
                HStack(alignment: .top, spacing: 10) {
                  Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .frame(width: 22)
                  VStack(alignment: .leading, spacing: 4) {
                    Text("\(order.store) • \(order.orderNumber)")
                      .font(.subheadline.weight(.semibold))
                    Text("No linked intake, import, acceptance, or Wishlist purchase source currently matches this order. Open the order source trail before relying on timeline history.")
                      .font(.caption)
                      .foregroundStyle(.secondary)
                      .fixedSize(horizontal: false, vertical: true)
                  }
                  Spacer(minLength: 8)
                  Badge("Trace", color: .orange)
                }
                .padding(10)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var inboxDispatchTimelinePanel: some View {
    if !inboxDispatchTimelineActivities.isEmpty {
      SettingsPanel(title: "Inbox dispatch handoff timeline", symbol: "arrow.triangle.2.circlepath.circle.fill") {
        VStack(alignment: .leading, spacing: 12) {
          Text("Local dispatch setup created from Inbox orders is now visible as one timeline: order, manifest, readiness, task, and audit context.")
            .font(.caption)
            .foregroundStyle(.secondary)

          NavigationLink {
            DispatchView(store: store)
          } label: {
            Label("Open Dispatch queue", systemImage: "paperplane.fill")
          }
          .buttonStyle(.bordered)

          MetricStrip(items: [
            ("Trail events", "\(inboxDispatchTimelineActivities.count)", .blue),
            ("Dispatch records", "\(inboxDispatchTimelineActivities.filter { $0.entityType == .shipmentManifest || $0.entityType == .dispatchChecklist }.count)", .purple),
            ("Reopened", "\(inboxDispatchTimelineActivities.filter(\.isReopenedInboxDispatchHandoffActivity).count)", .orange),
            ("Completed", "\(inboxDispatchTimelineActivities.filter(\.isCompletedInboxDispatchHandoffActivity).count)", .green)
          ])

          VStack(alignment: .leading, spacing: 8) {
            ForEach(visibleInboxDispatchTimelineActivities) { activity in
              HStack(alignment: .top, spacing: 10) {
                Image(systemName: activity.inboxDispatchTimelineSymbol)
                  .foregroundStyle(activity.inboxDispatchTimelineColor)
                  .frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                  Text(activity.title)
                    .font(.subheadline.weight(.semibold))
                  Text(activity.inboxDispatchTimelineLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                  Text(activity.suggestedActionText)
                    .font(.caption)
                    .foregroundStyle(activity.inboxDispatchTimelineColor)
                }
                Spacer()
                Badge(activity.entityType.rawValue, color: activity.inboxDispatchTimelineColor)
              }
              .padding(10)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(.thinMaterial)
              .clipShape(RoundedRectangle(cornerRadius: 8))
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var mailboxProviderReleaseTimelinePanel: some View {
    if store.mailboxProviderReleaseGateSummary.tone != "success" || store.mailboxProviderHandoffPacketSummary.tone != "success" {
      SettingsPanel(title: "Mailbox provider release context", symbol: "checkmark.seal.fill") {
        VStack(alignment: .leading, spacing: 12) {
          Text("Use this before treating Timeline evidence as a complete mailbox-provider handoff. It summarizes setup, refresh, parser, classifier, source-trail, and follow-up readiness without fetching mail or changing mailbox state.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          MailboxProviderReleaseGateCard(summary: store.mailboxProviderReleaseGateSummary, store: store)
          MailboxProviderHandoffPacketCard(packet: store.mailboxProviderHandoffPacketSummary, store: store)
        }
      }
    }
  }

  private var gmailTimelineReleaseBoundary: some View {
    GmailReleaseBoundaryPanel(
      store: store,
      title: "Gmail timeline readiness",
      lead: "Gmail release checks are provider setup evidence. Timeline should show when Gmail is ready for daily intake, but it should not replace Inbox review, order creation, or dispatch handoff.",
      sourceMetricTitle: "Gmail timeline sources",
      sourceCount: gmailTimelineSourceCount,
      boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store tokens, mutate mail, create timeline events, or change audit history automatically."
    )
  }

  private var gmailTimelineSourceCount: Int {
    mailboxProviderTimelineRows
      .filter { $0.label.localizedCaseInsensitiveContains("Gmail") }
      .reduce(0) { total, row in total + row.count }
  }

  @ViewBuilder
  private var mailboxProviderTimelinePanel: some View {
    if !mailboxProviderTimelineRows.isEmpty {
      SettingsPanel(title: "Mailbox provider timeline context", symbol: "point.3.connected.trianglepath.dotted") {
        VStack(alignment: .leading, spacing: 12) {
          Text("Use this when tracing where a timeline item came from. Provider labels are local source context only; Timeline never mutates mailbox messages.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
            ForEach(mailboxProviderTimelineRows, id: \.label) { row in
              HStack(alignment: .top, spacing: 10) {
                Image(systemName: row.symbol)
                  .foregroundStyle(row.color)
                  .frame(width: 22)
                VStack(alignment: .leading, spacing: 4) {
                  HStack(alignment: .firstTextBaseline) {
                    Text(row.label)
                      .font(.caption.weight(.semibold))
                    Spacer(minLength: 8)
                    Badge("\(row.count) intake", color: row.color)
                  }
                  Text(row.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
              }
              .padding(10)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(row.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }
      }
    }
  }

  private func clearFilters() {
    entityFilter = nil
    riskFilter = nil
    reviewFilter = nil
    sourceFilter = nil
    timelineSearchText = ""
  }

  private func linkedOrder(for activity: TimelineActivity) -> TrackedOrder? {
    if activity.entityType == .order, let id = UUID(uuidString: activity.entityID) {
      return store.orders.first { $0.id == id }
    }

    if activity.entityType == .shipmentManifest,
       let manifestID = UUID(uuidString: activity.entityID),
       let manifest = store.shipmentManifestRecords.first(where: { $0.id == manifestID }) {
      let linkedOrderID = manifest.includedOrderIDs.first ?? (manifest.linkedEntityType == .order ? UUID(uuidString: manifest.linkedEntityID) : nil)
      return linkedOrderID.flatMap { orderID in
        store.orders.first { $0.id == orderID }
      }
    }

    if activity.entityType == .dispatchChecklist,
       let checklistID = UUID(uuidString: activity.entityID),
       let checklist = store.dispatchReadinessChecklists.first(where: { $0.id == checklistID }) {
      let linkedOrderID = checklist.orderIDs.first ?? (checklist.linkedEntityType == .order ? UUID(uuidString: checklist.linkedEntityID) : nil)
      return linkedOrderID.flatMap { orderID in
        store.orders.first { $0.id == orderID }
      }
    }

    return nil
  }

  private func timelineActivity(_ activity: TimelineActivity, matches query: String) -> Bool {
    let order = linkedOrder(for: activity)
    let shipmentGroups = store.suggestedShipmentGroups(for: activity)
    let importQueueItems = store.importQueueItems(for: activity)
    let acceptanceRecords = store.acceptanceRecords(for: activity)
    var searchParts: [String] = [
      activity.id,
      activity.timestampText,
      activity.entityType.rawValue,
      activity.entityID,
      activity.title,
      activity.subtitle,
      activity.detail,
      activity.risk.rawValue,
      activity.reviewState?.rawValue ?? "",
      activity.source.rawValue,
      activity.suggestedActionText,
      order?.orderNumber ?? "",
      order?.store ?? "",
      order?.customer ?? "",
      order?.recipientEmail ?? "",
      order?.trackingNumber ?? "",
      order?.carrier ?? "",
      order?.destination ?? ""
    ]
    searchParts.append(contentsOf: shipmentGroups.map(\.groupName))
    searchParts.append(contentsOf: shipmentGroups.map(\.statusSummary))
    searchParts.append(contentsOf: importQueueItems.map(\.rawSummary))
    searchParts.append(contentsOf: importQueueItems.map(\.detectedOrderNumber))
    searchParts.append(contentsOf: acceptanceRecords.map(\.summary))
    searchParts.append(contentsOf: acceptanceRecords.map(\.notes))
    let searchableText = searchParts.joined(separator: " ")
    return searchableText.localizedLowercase.contains(query)
  }

  private func providerColor(for tone: String) -> Color {
    switch tone {
    case "spacemail": return .teal
    case "gmail": return .blue
    case "mock": return .purple
    case "microsoft", "mailbox": return .blue
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

  private func sourceTrailCount(for order: TrackedOrder) -> Int {
    store.sourceTrailCount(for: order)
  }

  private func linkedIntakeEmails(for order: TrackedOrder) -> [ForwardedEmailIntake] {
    store.linkedIntakeEmails(for: order)
  }

}

struct TimelineActivityRow: View {
  var activity: TimelineActivity
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
  var shipmentGroups: [ShipmentGroup] = []
  var importQueueItems: [ImportQueueItem] = []
  var acceptanceRecords: [AcceptanceRecord] = []
  var onCreateTask: () -> Void = {}
  var onCreateDraft: () -> Void = {}
  @State private var feedbackMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: activity.entityType.symbol)
          .foregroundStyle(activity.risk.color)
          .frame(width: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(activity.title)
            .font(.headline)
          Text(activity.subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(activity.detail)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(3)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 6) {
          Text(activity.timestampText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Badge(activity.risk.rawValue, color: activity.risk.color)
          if let reviewState = activity.reviewState {
            Badge(reviewState.rawValue, color: reviewState.color)
          }
        }
      }

      HStack(spacing: 8) {
        Label(activity.source.rawValue, systemImage: activity.source.symbol)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(activity.suggestedActionText)
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Review task created from this timeline activity for local follow-up."
        }
          .buttonStyle(.bordered)
          .disabled(!activity.supportsReviewTask)
        Button("Draft", systemImage: "square.and.pencil") {
          onCreateDraft()
          feedbackMessage = "Draft message created from this timeline activity. It remains local until a person sends anything outside ParcelOps."
        }
          .buttonStyle(.bordered)
          .disabled(!activity.supportsDraftMessage)
        if let store, let linkedOrder {
          NavigationLink {
            OrderDetailView(order: linkedOrder, store: store)
          } label: {
            Label("Open order", systemImage: "arrow.up.right.square.fill")
          }
          .buttonStyle(.bordered)
        }
        if let store, activity.hasDispatchWorkspaceRoute {
          NavigationLink {
            DispatchView(store: store)
          } label: {
            Label(activity.dispatchWorkspaceRouteLabel, systemImage: activity.dispatchWorkspaceRouteSymbol)
          }
          .buttonStyle(.bordered)
        }
      }

      if let feedbackMessage {
        TimelineActivityActionFeedbackPanel(message: feedbackMessage)
      }

      if activity.isInboxDispatchHandoffActivity {
        TimelineInboxDispatchCallout(activity: activity)
      }

      if !shipmentGroups.isEmpty {
        ShipmentGroupContextStrip(groups: shipmentGroups)
      }
      if !importQueueItems.isEmpty {
        ImportQueueContextStrip(items: importQueueItems)
      }
      if !acceptanceRecords.isEmpty {
        AcceptanceHistoryStrip(records: acceptanceRecords, store: store)
      }
    }
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

private struct TimelineActivityActionFeedbackPanel: View {
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

private struct TimelineInboxDispatchCallout: View {
  var activity: TimelineActivity

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: activity.inboxDispatchTimelineSymbol)
        .foregroundStyle(activity.inboxDispatchTimelineColor)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 4) {
        Text(activity.inboxDispatchTimelineLabel)
          .font(.caption.weight(.semibold))
          .foregroundStyle(activity.inboxDispatchTimelineColor)
        Text(activity.inboxDispatchTimelineGuidance)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .padding(10)
    .background(activity.inboxDispatchTimelineColor.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private extension TimelineActivity {
  var isInboxDispatchHandoffActivity: Bool {
    inboxDispatchSearchText.contains("inbox dispatch")
      || inboxDispatchSearchText.contains("inbox readiness")
      || inboxDispatchSearchText.contains("inbox-created order dispatch")
      || inboxDispatchSearchText.contains("dispatch handoff")
  }

  var isReopenedInboxDispatchHandoffActivity: Bool {
    isInboxDispatchHandoffActivity && inboxDispatchSearchText.contains("reopened")
  }

  var isCompletedInboxDispatchHandoffActivity: Bool {
    isInboxDispatchHandoffActivity
      && (inboxDispatchSearchText.contains("completed") || inboxDispatchSearchText.contains("handed off"))
  }

  var inboxDispatchTimelineLabel: String {
    switch entityType {
    case .shipmentManifest:
      return "Manifest generated from Inbox order handoff"
    case .dispatchChecklist:
      return "Readiness checklist generated from Inbox order handoff"
    case .order:
      return "Inbox-created order in dispatch setup"
    case .reviewTask:
      return "Follow-up task for Inbox dispatch handoff"
    case .auditEvent:
      return "Audit trail for Inbox-to-dispatch handoff"
    default:
      return "Inbox dispatch handoff context"
    }
  }

  var inboxDispatchTimelineColor: Color {
    switch risk {
    case .critical, .high:
      return .red
    case .watch:
      return .orange
    case .normal:
      return entityType == .dispatchChecklist ? .purple : .blue
    }
  }

  var inboxDispatchTimelineSymbol: String {
    switch entityType {
    case .shipmentManifest:
      return "paperplane.fill"
    case .dispatchChecklist:
      return "checklist.checked"
    case .reviewTask:
      return "checklist"
    case .auditEvent:
      return "list.clipboard.fill"
    default:
      return "arrow.triangle.2.circlepath.circle.fill"
    }
  }

  var inboxDispatchTimelineGuidance: String {
    if inboxDispatchSearchText.contains("blocked") {
      return "Resolve the blocked local dispatch setup before treating the order as ready to send."
    }
    if inboxDispatchSearchText.contains("reopened") {
      return "Recheck the local manifest or readiness checklist before continuing dispatch."
    }
    if inboxDispatchSearchText.contains("completed") || inboxDispatchSearchText.contains("handed off") {
      return "Completed local dispatch handoff. Confirm downstream order context if needed."
    }
    return "Continue the local handoff in Dispatch or Order detail. No carrier booking, label printing, scanner, or mailbox mutation is implied."
  }

  var hasDispatchWorkspaceRoute: Bool {
    entityType == .shipmentManifest
      || entityType == .dispatchChecklist
      || isInboxDispatchHandoffActivity
  }

  var dispatchWorkspaceRouteLabel: String {
    switch entityType {
    case .shipmentManifest:
      return "Open manifests"
    case .dispatchChecklist:
      return "Open readiness"
    default:
      return "Open Dispatch"
    }
  }

  var dispatchWorkspaceRouteSymbol: String {
    switch entityType {
    case .shipmentManifest:
      return "list.bullet.clipboard.fill"
    case .dispatchChecklist:
      return "checkmark.rectangle.stack.fill"
    default:
      return "paperplane.fill"
    }
  }

  private var inboxDispatchSearchText: String {
    [
      title,
      subtitle,
      detail,
      suggestedActionText,
      source.rawValue,
      entityType.rawValue
    ]
    .joined(separator: " ")
    .localizedLowercase
  }
}

private extension TimelineActivityGroup {
  var symbol: String {
    switch title {
    case "Watchlist": "exclamationmark.triangle.fill"
    case "Today": "clock.fill"
    default: "calendar"
    }
  }
}
