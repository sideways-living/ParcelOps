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
      ("Mailbox parsing intent", "Document how local intake should be parsed before future automation runs anything.", "envelope.open.fill"),
      ("Account sync placeholder", "Keep supplier, Shopify, and carrier sync ideas as disabled/local intent until real integrations exist.", "arrow.triangle.2.circlepath"),
      ("Order matching", "Compare supplier order number, checked mailbox, original recipient email, store, and customer team.", "link"),
      ("Review gate", "Risky matches should enter Needs Review before changing order records.", "checkmark.shield.fill"),
      ("Delivery handoff", "Use local carrier tracking events and evidence before any live carrier integration.", "square.and.arrow.up")
    ]
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Automation rules")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Local rules document future automation intent. ParcelOps does not execute background jobs, sync accounts, or call external services from this screen.")
            .foregroundStyle(.secondary)
        }

        automationReadinessPanel
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

  private var automationReadinessPanel: some View {
    let enabledRules = store.automationRules.filter(\.isEnabled)
    let disabledRules = store.automationRules.filter { !$0.isEnabled }
    let reviewRules = store.automationRules.filter { $0.reviewState != .accepted }
    let rulesWithRunHistory = store.automationRules.filter { $0.runCount > 0 }

    return SettingsPanel(title: "Automation readiness", symbol: "pause.circle.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Treat these as reviewed plans, not executable automations. Enabled means approved local intent only; no background job, mailbox mutation, Shopify sync, carrier sync, notification, or credential action runs here.")
          .font(.callout)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 135) {
          Badge("\(store.automationRules.count) rules", color: store.automationRules.isEmpty ? .secondary : .blue)
          Badge("\(enabledRules.count) enabled intent", color: enabledRules.isEmpty ? .secondary : .teal)
          Badge("\(disabledRules.count) disabled", color: disabledRules.isEmpty ? .secondary : .gray)
          Badge("\(reviewRules.count) needs review", color: reviewRules.isEmpty ? .green : .orange)
          Badge("\(rulesWithRunHistory.count) local run notes", color: rulesWithRunHistory.isEmpty ? .secondary : .purple)
        }

        if store.automationRules.isEmpty {
          MVPEmptyState(
            title: "No automation intent records yet",
            detail: "Add a rule only to document a future workflow. It will not execute or contact any external service.",
            symbol: "arrow.triangle.branch"
          )
        } else if reviewRules.isEmpty {
          Label("Automation intent records are reviewed. Execution still remains disabled/local-only.", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
        } else {
          VStack(alignment: .leading, spacing: 8) {
            Text("Review before relying on these plans")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            ForEach(reviewRules.prefix(4)) { rule in
              AutomationReadinessRow(rule: rule)
            }
            if reviewRules.count > 4 {
              Text("\(reviewRules.count - 4) more automation intent records need review.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
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

private struct AutomationReadinessRow: View {
  var rule: AutomationRule

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: rule.triggerType.symbol)
        .foregroundStyle(rule.isEnabled ? .teal : .secondary)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(rule.name)
          .font(.caption.weight(.semibold))
        Text(rule.isEnabled ? "Enabled local intent. Confirm review state before future implementation." : "Disabled local intent. Keep disabled until this workflow is intentionally implemented.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 8)
      Badge(rule.reviewState.rawValue, color: rule.reviewState.color)
    }
    .padding(8)
    .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
  }
}

struct AutomationRuleRow: View {
  var rule: AutomationRule
  var onToggle: () -> Void
  var onReviewed: () -> Void
  var onRemove: () -> Void
  var onCreateTask: () -> Void = {}
  @State private var feedbackMessage: String?

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
        Button(rule.isEnabled ? "Disable" : "Enable", systemImage: rule.isEnabled ? "pause.circle.fill" : "play.circle.fill") {
          onToggle()
          feedbackMessage = rule.isEnabled
            ? "Automation rule disabled locally. No background job, notification, or external action was stopped."
            : "Automation rule enabled as local intent only. No background job, notification, or external action will run."
        }
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.circle.fill") {
          onReviewed()
          feedbackMessage = "Automation rule marked reviewed locally. This remains planning metadata only."
        }
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash") {
          onRemove()
          feedbackMessage = "Automation rule removed locally. No scheduled task, notification, or external system was changed."
        }
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Review task created from this automation rule for local planning follow-up."
        }
          .buttonStyle(.bordered)
      }

      if let feedbackMessage {
        AutomationRuleActionFeedbackPanel(message: feedbackMessage)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct AutomationRuleActionFeedbackPanel: View {
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
