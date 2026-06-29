import SwiftUI

struct AutomationView: View {
  var store: ParcelOpsStore
  @State private var selectedEnabledState: Bool?
  @State private var selectedReviewState: ReviewState?
  @State private var ruleSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var baseFilteredRules: [AutomationRule] {
    store.automationRules.filter { rule in
      let matchesEnabled = selectedEnabledState == nil || rule.isEnabled == selectedEnabledState
      let matchesReview = selectedReviewState == nil || rule.reviewState == selectedReviewState
      return matchesEnabled && matchesReview
    }
  }

  private var filteredRules: [AutomationRule] {
    let query = ruleSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredRules }
    return baseFilteredRules.filter { rule in
      [
        rule.id.uuidString,
        rule.name,
        rule.triggerType.rawValue,
        rule.conditionSummary,
        rule.actionSummary,
        rule.isEnabled ? "Enabled" : "Disabled",
        rule.lastRunDate,
        rule.reviewState.rawValue,
        "\(rule.runCount)"
      ].joined(separator: " ").localizedLowercase.contains(query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedEnabledState != nil
      || selectedReviewState != nil
      || !ruleSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var steps: [(String, String, String)] {
    [
      ("Mailbox parsing", "Extract order numbers, sender domains, totals, delivery warnings, and recipient aliases.", "envelope.open.fill"),
      ("Account sync", "Refresh supplier portals and Shopify OAuth stores without overwriting reviewed data.", "arrow.triangle.2.circlepath"),
      ("Order matching", "Compare supplier order number, checked mailbox, original recipient email, store, and customer team.", "link"),
      ("Review gate", "Risky matches enter Needs Review before changing order records.", "checkmark.shield.fill"),
      ("Delivery handoff", "Use local carrier tracking events and evidence before any live carrier integration.", "square.and.arrow.up")
    ]
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Automation rules")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Local rules define automation intent without running live integrations.")
            .foregroundStyle(.secondary)
        }

        filterBar

        SettingsPanel(title: "Rules", symbol: "arrow.triangle.branch") {
          HStack {
            Text("\(filteredRules.count) visible rules")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredRules.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add rule", systemImage: "plus", action: store.addAutomationRulePlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredRules.isEmpty {
            MVPEmptyState(title: "No automation rules match this view", detail: hasActiveFilters ? "Clear search or filters to return to all local automation intent records." : "Add a local automation rule placeholder to document future automation behavior without running integrations.", symbol: "arrow.triangle.branch", actionTitle: hasActiveFilters ? "Clear filters" : "Add rule", action: hasActiveFilters ? clearFilters : store.addAutomationRulePlaceholder)
          } else {
            ForEach(filteredRules) { rule in
              AutomationRuleRow(rule: rule) {
                store.toggleAutomationRule(rule)
              } onReviewed: {
                store.markAutomationRuleReviewed(rule)
              } onRemove: {
                store.removeAutomationRule(rule)
              } onCreateTask: {
                store.createReviewTask(from: rule)
              }
            }
          }
        }

        SettingsPanel(title: "Flow", symbol: "point.3.connected.trianglepath.dotted") {
          ForEach(steps, id: \.0) { step in
            HStack(alignment: .top, spacing: 14) {
              Image(systemName: step.2)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.teal)
                .clipShape(RoundedRectangle(cornerRadius: 8))
              VStack(alignment: .leading, spacing: 4) {
                Text(step.0)
                  .font(.headline)
                Text(step.1)
                  .foregroundStyle(.secondary)
              }
            }
            .padding(12)
            .background(.quinary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search rule, trigger, condition, action, review state, or run count", text: $ruleSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Enabled", selection: $selectedEnabledState) {
        Text("All states").tag(nil as Bool?)
        Text("Enabled").tag(true as Bool?)
        Text("Disabled").tag(false as Bool?)
      }

      Picker("Review", selection: $selectedReviewState) {
        Text("All review states").tag(nil as ReviewState?)
        Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted as ReviewState?)
        Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview as ReviewState?)
        Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor as ReviewState?)
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
    selectedEnabledState = nil
    selectedReviewState = nil
    ruleSearchText = ""
  }
}

struct AutomationRuleRow: View {
  var rule: AutomationRule
  var onToggle: () -> Void
  var onReviewed: () -> Void
  var onRemove: () -> Void
  var onCreateTask: () -> Void = {}

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: rule.triggerType.symbol)
          .foregroundStyle(rule.isEnabled ? .green : .secondary)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(rule.name)
                .font(.headline)
              Text("\(rule.triggerType.rawValue) • last run \(rule.lastRunDate)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(rule.isEnabled ? "Enabled" : "Disabled", color: rule.isEnabled ? .green : .gray)
          }

          Text(rule.conditionSummary)
            .foregroundStyle(.secondary)
          Text(rule.actionSummary)
            .font(.caption)
            .foregroundStyle(.secondary)

          HStack(spacing: 8) {
            Badge(rule.reviewState.rawValue, color: rule.reviewState.color)
            Text("\(rule.runCount) runs")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      CompactActionRow {
        Button(rule.isEnabled ? "Disable" : "Enable", systemImage: rule.isEnabled ? "pause.circle.fill" : "play.circle.fill", action: onToggle)
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.circle.fill", action: onReviewed)
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", action: onRemove)
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
