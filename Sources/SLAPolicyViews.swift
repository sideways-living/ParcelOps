import SwiftUI

struct SLAPoliciesView: View {
  var store: ParcelOpsStore

  @State private var selectedEnabledState: Bool?
  @State private var selectedPriority: TaskPriority?
  @State private var selectedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedReviewState: ReviewState?
  @State private var policySearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var baseFilteredPolicies: [SLAPolicy] {
    store.slaPolicies.filter { policy in
      let matchesEnabled = selectedEnabledState == nil || policy.isEnabled == selectedEnabledState
      let matchesPriority = selectedPriority == nil || policy.priority == selectedPriority
      let matchesEntity = selectedEntityType == nil || policy.linkedEntityType == selectedEntityType
      let matchesReview = selectedReviewState == nil || policy.reviewState == selectedReviewState
      return matchesEnabled && matchesPriority && matchesEntity && matchesReview
    }
  }

  private var filteredPolicies: [SLAPolicy] {
    let query = policySearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredPolicies }
    return baseFilteredPolicies.filter { policy in
      slaPolicySearchParts(policy).joined(separator: " ").localizedLowercase.contains(query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedEnabledState != nil
      || selectedPriority != nil
      || selectedEntityType != nil
      || selectedReviewState != nil
      || !policySearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("SLA policies")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Local timing and escalation policies for manual review workflows.")
            .foregroundStyle(.secondary)
        }

        filterBar

        SettingsPanel(title: "Policies", symbol: "timer") {
          HStack {
            Text("\(filteredPolicies.count) visible policies")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredPolicies.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add policy", systemImage: "plus", action: store.addSLAPolicyPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredPolicies.isEmpty {
            MVPEmptyState(title: "No SLA policies match this view", detail: hasActiveFilters ? "Clear search or filters to return to all local SLA policies." : "Add a local SLA policy to define manual timing, review, and escalation expectations.", symbol: "timer", actionTitle: hasActiveFilters ? "Clear filters" : "Add policy", action: hasActiveFilters ? clearFilters : store.addSLAPolicyPlaceholder)
          } else {
            ForEach(filteredPolicies) { policy in
              SLAPolicyRow(policy: policy, destinationAddresses: store.suggestedDestinationAddresses(for: policy), deliveryInstructions: store.suggestedDeliveryInstructions(for: policy), packageContents: store.suggestedPackageContents(for: policy)) { updatedPolicy in
                store.updateSLAPolicy(updatedPolicy)
              } onToggle: {
                store.toggleSLAPolicy(policy)
              } onReviewed: {
                store.markSLAPolicyReviewed(policy)
              } onEvaluate: {
                store.evaluateSLAPolicyPlaceholder(policy)
              } onCreateDraft: {
                store.createDraftMessage(from: policy)
              } onCreateContact: {
                store.addContactDirectoryEntry(linkedEntityType: .slaPolicy, linkedEntityID: policy.id.uuidString, label: policy.name)
              } onRemove: {
                store.removeSLAPolicy(policy)
              }
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search policy, condition, target, priority, record, linked address, or instruction", text: $policySearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Enabled", selection: $selectedEnabledState) {
        Text("All states").tag(nil as Bool?)
        Text("Enabled").tag(true as Bool?)
        Text("Disabled").tag(false as Bool?)
      }

      Picker("Priority", selection: $selectedPriority) {
        Text("All priorities").tag(nil as TaskPriority?)
        ForEach(TaskPriority.allCases) { priority in
          Text(priority.rawValue).tag(priority as TaskPriority?)
        }
      }

      Picker("Record", selection: $selectedEntityType) {
        Text("All records").tag(nil as ReviewTaskLinkedEntityType?)
        ForEach(ReviewTaskLinkedEntityType.allCases) { entityType in
          Text(entityType.rawValue).tag(entityType as ReviewTaskLinkedEntityType?)
        }
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
    selectedPriority = nil
    selectedEntityType = nil
    selectedReviewState = nil
    policySearchText = ""
  }

  private func slaPolicySearchParts(_ policy: SLAPolicy) -> [String] {
    var parts = [
      policy.id.uuidString,
      policy.name,
      policy.linkedEntityType.rawValue,
      policy.conditionSummary,
      policy.responseTarget,
      policy.resolutionTarget,
      policy.priority.rawValue,
      policy.isEnabled ? "Enabled" : "Disabled",
      policy.createdDate,
      policy.lastEvaluatedDate,
      "\(policy.matchCount)",
      policy.reviewState.rawValue
    ]
    parts.append(contentsOf: store.suggestedDestinationAddresses(for: policy).flatMap { [$0.label, $0.addressLineSummary, $0.cityRegion, $0.preferredCarrier] })
    parts.append(contentsOf: store.suggestedDeliveryInstructions(for: policy).flatMap { [$0.title, $0.instructionSummary, $0.accessConstraintSummary, $0.carrierNotes] })
    parts.append(contentsOf: store.suggestedPackageContents(for: policy).flatMap { [$0.title, $0.itemSummary, $0.discrepancySummary] })
    return parts
  }
}

struct SLAPolicyRow: View {
  var policy: SLAPolicy
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var onSave: (SLAPolicy) -> Void
  var onToggle: () -> Void
  var onReviewed: () -> Void
  var onEvaluate: () -> Void
  var onCreateDraft: () -> Void = {}
  var onCreateContact: () -> Void = {}
  var onRemove: () -> Void
  @State private var isEditing = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: policy.linkedEntityType.symbol)
          .foregroundStyle(policy.priority.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(policy.name)
                .font(.headline)
              Text("\(policy.linkedEntityType.rawValue) • last evaluated \(policy.lastEvaluatedDate)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(policy.priority.rawValue, color: policy.priority.color)
          }

          Text(policy.conditionSummary)
            .foregroundStyle(.secondary)

          HStack(spacing: 8) {
            Badge(policy.isEnabled ? "Enabled" : "Disabled", color: policy.isEnabled ? .green : .gray)
            Badge(policy.reviewState.rawValue, color: policy.reviewState.color)
            Text("Response: \(policy.responseTarget)")
              .font(.caption)
              .foregroundStyle(.secondary)
            Text("Resolution: \(policy.resolutionTarget)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Text("\(policy.matchCount) local matches")
            .font(.caption)
            .foregroundStyle(.secondary)

          if !destinationAddresses.isEmpty {
            DestinationAddressStrip(addresses: destinationAddresses)
          }
          if !deliveryInstructions.isEmpty {
            DeliveryInstructionStrip(instructions: deliveryInstructions)
          }
          if !packageContents.isEmpty {
            PackageContentStrip(contents: packageContents)
          }
        }
      }

      HStack {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button(policy.isEnabled ? "Disable" : "Enable", systemImage: policy.isEnabled ? "pause.circle.fill" : "play.circle.fill", action: onToggle)
          .buttonStyle(.bordered)
        Button("Evaluate", systemImage: "timer", action: onEvaluate)
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.circle.fill", action: onReviewed)
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill", action: onCreateDraft)
          .buttonStyle(.bordered)
        Button("Contact", systemImage: "person.crop.circle.badge.plus", action: onCreateContact)
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", action: onRemove)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      SLAPolicyEditView(policy: policy) { updatedPolicy in
        onSave(updatedPolicy)
      }
    }
  }
}

struct SLAPolicyEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: SLAPolicy
  var onSave: (SLAPolicy) -> Void

  init(policy: SLAPolicy, onSave: @escaping (SLAPolicy) -> Void) {
    self._draft = State(initialValue: policy)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Policy") {
          TextField("Name", text: $draft.name)
          Picker("Linked record type", selection: $draft.linkedEntityType) {
            ForEach(ReviewTaskLinkedEntityType.allCases) { entityType in
              Text(entityType.rawValue).tag(entityType)
            }
          }
          TextField("Condition summary", text: $draft.conditionSummary, axis: .vertical)
            .lineLimit(3...6)
        }

        Section("Targets") {
          TextField("Response target", text: $draft.responseTarget)
          TextField("Resolution target", text: $draft.resolutionTarget)
          Picker("Priority", selection: $draft.priority) {
            ForEach(TaskPriority.allCases) { priority in
              Text(priority.rawValue).tag(priority)
            }
          }
        }

        Section("State") {
          Toggle("Enabled", isOn: $draft.isEnabled)
          TextField("Created date", text: $draft.createdDate)
          TextField("Last evaluated", text: $draft.lastEvaluatedDate)
          Stepper("Matches: \(draft.matchCount)", value: $draft.matchCount, in: 0...999)
          Picker("Review state", selection: $draft.reviewState) {
            Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted)
            Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview)
            Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor)
          }
        }
      }
      .navigationTitle("Edit SLA policy")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            onSave(draft)
            dismiss()
          }
        }
      }
      #if os(macOS)
      .frame(minWidth: 560, minHeight: 620)
      #endif
    }
  }
}
