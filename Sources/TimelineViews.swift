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
    let query = timelineSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
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

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filters

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

  private func clearFilters() {
    entityFilter = nil
    riskFilter = nil
    reviewFilter = nil
    sourceFilter = nil
    timelineSearchText = ""
  }

  private func linkedOrder(for activity: TimelineActivity) -> TrackedOrder? {
    guard activity.entityType == .order, let id = UUID(uuidString: activity.entityID) else { return nil }
    return store.orders.first { $0.id == id }
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
    return searchableText.localizedCaseInsensitiveContains(query)
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
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
          .disabled(!activity.supportsReviewTask)
        Button("Draft", systemImage: "square.and.pencil", action: onCreateDraft)
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
      }

      if !shipmentGroups.isEmpty {
        ShipmentGroupContextStrip(groups: shipmentGroups)
      }
      if !importQueueItems.isEmpty {
        ImportQueueContextStrip(items: importQueueItems)
      }
      if !acceptanceRecords.isEmpty {
        AcceptanceHistoryStrip(records: acceptanceRecords)
      }
    }
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
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
