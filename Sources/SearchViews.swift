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
    .background(.background)
  }

  private func apply(_ filter: SavedFilter) {
    queryText = filter.queryText
    selectedEntityType = filter.entityTypeFilter
    selectedReviewState = filter.reviewStateFilter
  }
}

private struct SearchOperatorHintsPanel: View {
  var onApply: (String, SearchEntityType?, ReviewState?) -> Void

  private let hints: [SearchOperatorHint] = [
    SearchOperatorHint(title: "Inbox-created orders", query: "Inbox-created order", entityType: .order, reviewState: nil, symbol: "tray.and.arrow.down.fill", detail: "Find orders created from intake, import, or acceptance handoff."),
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
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }

  private var badgeText: String {
    result.severity?.rawValue ?? result.reviewState?.rawValue ?? result.entityType.rawValue
  }

  private var badgeColor: Color {
    result.severity?.color ?? result.reviewState?.color ?? result.entityType.color
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
