import SwiftUI

struct TimelineView: View {
  var store: ParcelOpsStore
  @State private var entityFilter: TimelineEntityType?
  @State private var riskFilter: TimelineRiskLevel?
  @State private var reviewFilter: ReviewState?
  @State private var sourceFilter: TimelineActivitySource?
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var filteredActivities: [TimelineActivity] {
    store.filteredTimelineActivities(
      entityType: entityFilter,
      risk: riskFilter,
      reviewState: reviewFilter,
      source: sourceFilter
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filters

        ForEach(store.groupedTimelineActivities(filteredActivities)) { group in
          SettingsPanel(title: group.title, symbol: group.symbol) {
            ForEach(group.activities) { activity in
              TimelineActivityRow(activity: activity) {
                store.createReviewTask(from: activity)
              } onCreateDraft: {
                store.createDraftMessage(from: activity)
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
    VStack(alignment: .leading, spacing: 10) {
      HStack {
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
      }
      HStack {
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
      }
    }
    .pickerStyle(.menu)
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct TimelineActivityRow: View {
  var activity: TimelineActivity
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
