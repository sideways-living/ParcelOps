import SwiftUI

struct SearchView: View {
  var store: ParcelOpsStore

  @State private var queryText = ""
  @State private var selectedEntityType: SearchEntityType?
  @State private var selectedReviewState: ReviewState?

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
          Text("Find local orders, intake emails, tracking events, evidence, audit history, and automation rules.")
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
                      SearchResultRow(result: result)
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
    .background(Color(nsColor: .windowBackgroundColor))
  }

  private func apply(_ filter: SavedFilter) {
    queryText = filter.queryText
    selectedEntityType = filter.entityTypeFilter
    selectedReviewState = filter.reviewStateFilter
  }
}

struct SearchControlPanel: View {
  @Binding var queryText: String
  @Binding var selectedEntityType: SearchEntityType?
  @Binding var selectedReviewState: ReviewState?
  var onSave: () -> Void
  var onClear: () -> Void

  var body: some View {
    SettingsPanel(title: "Search controls", symbol: "slider.horizontal.3") {
      VStack(alignment: .leading, spacing: 12) {
        TextField("Search local records", text: $queryText)
          .textFieldStyle(.roundedBorder)

        HStack(spacing: 12) {
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

          Spacer()
        }

        HStack {
          Button("Save current", systemImage: "plus", action: onSave)
          Button("Clear", systemImage: "xmark.circle", action: onClear)
            .foregroundStyle(.secondary)
          Spacer()
        }
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

  var body: some View {
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

      Spacer()

      HStack(spacing: 8) {
        Button("Apply", systemImage: "arrow.down.circle", action: onApply)
        Button(filter.isPinned ? "Unpin" : "Pin", systemImage: filter.isPinned ? "pin.slash" : "pin", action: onTogglePin)
        Button("Remove", systemImage: "trash", action: onRemove)
          .foregroundStyle(.red)
        Button("Task", systemImage: "checklist", action: onCreateTask)
      }
      .buttonStyle(.borderless)
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

struct SearchResultRow: View {
  var result: SearchResult

  private var badgeText: String {
    result.severity?.rawValue ?? result.reviewState?.rawValue ?? result.entityType.rawValue
  }

  private var badgeColor: Color {
    result.severity?.color ?? result.reviewState?.color ?? result.entityType.color
  }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: result.entityType.symbol)
        .foregroundStyle(result.entityType.color)
        .frame(width: 22)

      VStack(alignment: .leading, spacing: 5) {
        HStack(alignment: .firstTextBaseline) {
          Text(result.title)
            .font(.headline)
          Spacer()
          Badge(badgeText, color: badgeColor)
        }

        Text(result.subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(2)

        Text(result.detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(3)

        Text(result.linkedEntityID)
          .font(.caption2.monospaced())
          .foregroundStyle(.tertiary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
    }
    .padding(12)
    .background(.quaternary.opacity(0.24))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
