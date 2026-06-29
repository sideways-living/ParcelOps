import SwiftUI

struct DispatchReadinessView: View {
  var store: ParcelOpsStore
  @State private var selectedType: DispatchChecklistType?
  @State private var selectedStatus: DispatchChecklistStatus?
  @State private var ownerTeam = ""
  @State private var selectedRiskLevel: ShipmentRiskLevel?
  @State private var selectedLinkedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedReviewState: ReviewState?
  @State private var readinessSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var baseFilteredChecklists: [DispatchReadinessChecklist] {
    store.filteredDispatchReadinessChecklists(checklistType: selectedType, checklistStatus: selectedStatus, ownerTeam: ownerTeam, riskLevel: selectedRiskLevel, linkedEntityType: selectedLinkedEntityType, reviewState: selectedReviewState)
  }

  private var filteredChecklists: [DispatchReadinessChecklist] {
    let query = readinessSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return baseFilteredChecklists }
    return baseFilteredChecklists.filter { checklist in
      dispatchChecklist(checklist, matches: query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedType != nil
      || selectedStatus != nil
      || !ownerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || selectedRiskLevel != nil
      || selectedLinkedEntityType != nil
      || selectedReviewState != nil
      || !readinessSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        MVPWorkflowGuide(
          title: "Readiness workflow",
          detail: "Use this screen as the local go/no-go check before dispatch.",
          steps: [
            "Review required checks and missing requirements.",
            "Mark ready only when scans, labels, custody, and handoff details are clear.",
            "Block anything that needs manual correction.",
            "Complete the checklist after the dispatch handoff is done."
          ],
          symbol: "checkmark.rectangle.stack.fill"
        )
        filterBar

        SettingsPanel(title: "Dispatch readiness checklists", symbol: "checkmark.rectangle.stack.fill") {
          HStack {
            Text("\(filteredChecklists.count) visible checklists")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredChecklists.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add checklist", systemImage: "plus", action: store.addDispatchReadinessChecklistPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredChecklists.isEmpty {
            MVPEmptyState(
              title: "No readiness checklists match this view",
              detail: hasActiveFilters ? "Clear search or filters to return to all readiness checklists." : "Add a placeholder checklist to test local dispatch checks.",
              symbol: "checkmark.rectangle.stack.fill",
              actionTitle: hasActiveFilters ? "Clear filters" : "Add checklist",
              action: hasActiveFilters ? clearFilters : store.addDispatchReadinessChecklistPlaceholder
            )
          } else {
            ForEach(filteredChecklists) { checklist in
              DispatchReadinessRow(checklist: checklist, store: store, linkedOrders: linkedOrders(for: checklist)) { updatedChecklist in
                store.updateDispatchReadinessChecklist(updatedChecklist)
              } onReady: {
                store.markDispatchChecklistReady(checklist)
              } onBlocked: {
                store.markDispatchChecklistBlocked(checklist)
              } onCompleted: {
                store.markDispatchChecklistCompleted(checklist)
              } onReopen: {
                store.reopenDispatchChecklist(checklist)
              } onReviewed: {
                store.markDispatchChecklistReviewed(checklist)
              } onCreateTask: {
                store.createReviewTask(from: checklist)
              } onCreateDraft: {
                store.createDraftMessage(from: checklist)
              } onRemove: {
                store.removeDispatchReadinessChecklist(checklist)
              }
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Dispatch Readiness")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Local go/no-go checks for manifests, labels, scans, custody, destinations, and handoff work.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(store.blockedDispatchChecklists.count) blocked", color: .red)
        Badge("\(store.incompleteDispatchChecklists.count) incomplete", color: .orange)
      }
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search title, required checks, missing items, owner, order, manifest, label, scan, or evidence", text: $readinessSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Type", selection: $selectedType) {
        Text("All types").tag(nil as DispatchChecklistType?)
        ForEach(DispatchChecklistType.allCases) { type in Text(type.rawValue).tag(type as DispatchChecklistType?) }
      }
      .pickerStyle(.menu)

      Picker("Status", selection: $selectedStatus) {
        Text("All status").tag(nil as DispatchChecklistStatus?)
        ForEach(DispatchChecklistStatus.allCases) { status in Text(status.rawValue).tag(status as DispatchChecklistStatus?) }
      }
      .pickerStyle(.menu)

      TextField("Owner/team", text: $ownerTeam)

      Picker("Risk", selection: $selectedRiskLevel) {
        Text("All risk").tag(nil as ShipmentRiskLevel?)
        ForEach(ShipmentRiskLevel.allCases) { risk in Text(risk.rawValue).tag(risk as ShipmentRiskLevel?) }
      }
      .pickerStyle(.menu)

      Picker("Linked", selection: $selectedLinkedEntityType) {
        Text("All links").tag(nil as ReviewTaskLinkedEntityType?)
        ForEach(ReviewTaskLinkedEntityType.allCases) { type in Text(type.rawValue).tag(type as ReviewTaskLinkedEntityType?) }
      }
      .pickerStyle(.menu)

      Picker("Review", selection: $selectedReviewState) {
        Text("All review").tag(nil as ReviewState?)
        ForEach(reviewStates, id: \.self) { state in Text(state.rawValue).tag(state as ReviewState?) }
      }
      .pickerStyle(.menu)

      Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle") {
        clearFilters()
      }
      .buttonStyle(.bordered)
    }
  }

  private func clearFilters() {
    selectedType = nil
    selectedStatus = nil
    ownerTeam = ""
    selectedRiskLevel = nil
    selectedLinkedEntityType = nil
    selectedReviewState = nil
    readinessSearchText = ""
  }

  private func dispatchChecklist(_ checklist: DispatchReadinessChecklist, matches query: String) -> Bool {
    let linkedOrders = linkedOrders(for: checklist)
    let linkedManifest = checklist.shipmentManifestID.flatMap { manifestID in
      store.shipmentManifestRecords.first { $0.id == manifestID }
    }
    let linkedGroups = checklist.shipmentGroupIDs.compactMap { groupID in
      store.shipmentGroups.first { $0.id == groupID }
    }
    let orderText = linkedOrders.map { order in
      [
        order.store,
        order.orderNumber,
        order.customer,
        order.recipientEmail,
        order.carrier,
        order.trackingNumber,
        order.destination
      ].joined(separator: " ")
    }.joined(separator: " ")
    let manifestText = [
      linkedManifest?.title ?? "",
      linkedManifest?.carrierCourier ?? "",
      linkedManifest?.destinationSummary ?? "",
      linkedManifest?.manifestReferencePlaceholder ?? "",
      linkedManifest?.dispatchStatus.rawValue ?? ""
    ].joined(separator: " ")
    let groupText = linkedGroups.map { group in
      [
        group.groupName,
        group.destinationSummary,
        group.recipientCustomerSummary,
        group.carrierSummary,
        group.statusSummary
      ].joined(separator: " ")
    }.joined(separator: " ")
    let searchableText = [
      checklist.title,
      checklist.linkedEntityType.rawValue,
      checklist.linkedEntityID,
      checklist.shipmentManifestID?.uuidString ?? "",
      checklist.orderIDs.map(\.uuidString).joined(separator: " "),
      checklist.shipmentGroupIDs.map(\.uuidString).joined(separator: " "),
      checklist.inventoryReceiptIDs.map(\.uuidString).joined(separator: " "),
      checklist.packageContentIDs.map(\.uuidString).joined(separator: " "),
      checklist.custodyRecordIDs.map(\.uuidString).joined(separator: " "),
      checklist.labelReferenceIDs.map(\.uuidString).joined(separator: " "),
      checklist.scanSessionIDs.map(\.uuidString).joined(separator: " "),
      checklist.evidenceAttachmentIDs.map(\.uuidString).joined(separator: " "),
      checklist.checklistType.rawValue,
      checklist.checklistStatus.rawValue,
      checklist.requiredChecksSummary,
      checklist.completedChecksSummary,
      checklist.missingRequirementsSummary,
      checklist.assignedOwnerTeam,
      checklist.plannedDispatchDate,
      checklist.completedDate,
      checklist.riskLevel.rawValue,
      checklist.reviewState.rawValue,
      orderText,
      manifestText,
      groupText
    ].joined(separator: " ")
    return searchableText.localizedCaseInsensitiveContains(query)
  }

  private func linkedOrders(for checklist: DispatchReadinessChecklist) -> [TrackedOrder] {
    var ids = checklist.orderIDs
    if checklist.linkedEntityType == .order, let id = UUID(uuidString: checklist.linkedEntityID) {
      ids.append(id)
    }
    let uniqueIDs = ids.reduce(into: [UUID]()) { result, id in
      if !result.contains(id) { result.append(id) }
    }
    return uniqueIDs.compactMap { id in
      store.orders.first { $0.id == id }
    }
  }
}

struct DispatchReadinessRow: View {
  var checklist: DispatchReadinessChecklist
  var store: ParcelOpsStore? = nil
  var linkedOrders: [TrackedOrder] = []
  var onSave: (DispatchReadinessChecklist) -> Void
  var onReady: () -> Void
  var onBlocked: () -> Void
  var onCompleted: () -> Void
  var onReopen: () -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: checklist.checklistType.symbol)
          .foregroundStyle(checklist.riskLevel.color)
          .frame(width: 28, height: 28)
        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(checklist.title)
                .font(.headline)
              Text("\(checklist.checklistType.rawValue) • \(checklist.assignedOwnerTeam)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(checklist.checklistStatus.rawValue, color: checklist.checklistStatus.color)
          }
          Text(checklist.requiredChecksSummary)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text("Missing: \(checklist.missingRequirementsSummary)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          CompactMetadataGrid {
            Badge(checklist.riskLevel.rawValue, color: checklist.riskLevel.color)
            Badge(checklist.reviewState.rawValue, color: checklist.reviewState.color)
            Label(checklist.plannedDispatchDate, systemImage: "calendar")
              .font(.caption)
              .foregroundStyle(.secondary)
            Label("\(checklist.scanSessionIDs.count) scans", systemImage: "qrcode.viewfinder")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Ready", systemImage: "checkmark.circle.fill", action: onReady)
          .buttonStyle(.bordered)
        Button("Blocked", systemImage: "exclamationmark.triangle.fill", action: onBlocked)
          .buttonStyle(.bordered)
        Button("Complete", systemImage: "checkmark.seal.fill", action: onCompleted)
          .buttonStyle(.bordered)
        Button("Reopen", systemImage: "arrow.counterclockwise", action: onReopen)
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.shield.fill", action: onReviewed)
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill", action: onCreateDraft)
          .buttonStyle(.bordered)
        if let store {
          ForEach(linkedOrders.prefix(3)) { order in
            NavigationLink {
              OrderDetailView(order: order, store: store)
            } label: {
              Label(order.orderNumber, systemImage: "arrow.up.right.square.fill")
            }
            .buttonStyle(.bordered)
          }
        }
        Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      DispatchReadinessEditView(checklist: checklist) { updatedChecklist in
        onSave(updatedChecklist)
      }
    }
  }
}

struct DispatchReadinessEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: DispatchReadinessChecklist
  var onSave: (DispatchReadinessChecklist) -> Void

  init(checklist: DispatchReadinessChecklist, onSave: @escaping (DispatchReadinessChecklist) -> Void) {
    self._draft = State(initialValue: checklist)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Checklist") {
          TextField("Title", text: $draft.title)
          Picker("Type", selection: $draft.checklistType) {
            ForEach(DispatchChecklistType.allCases) { type in Text(type.rawValue).tag(type) }
          }
          Picker("Status", selection: $draft.checklistStatus) {
            ForEach(DispatchChecklistStatus.allCases) { status in Text(status.rawValue).tag(status) }
          }
          TextField("Required checks", text: $draft.requiredChecksSummary, axis: .vertical)
          TextField("Completed checks", text: $draft.completedChecksSummary, axis: .vertical)
          TextField("Missing requirements", text: $draft.missingRequirementsSummary, axis: .vertical)
        }

        Section("Dispatch") {
          TextField("Owner/team", text: $draft.assignedOwnerTeam)
          TextField("Planned dispatch date", text: $draft.plannedDispatchDate)
          TextField("Completed date", text: $draft.completedDate)
        }

        Section("Review") {
          Picker("Risk", selection: $draft.riskLevel) {
            ForEach(ShipmentRiskLevel.allCases) { risk in Text(risk.rawValue).tag(risk) }
          }
          Picker("Review state", selection: $draft.reviewState) {
            ForEach([ReviewState.needsReview, .monitor, .accepted], id: \.self) { state in Text(state.rawValue).tag(state) }
          }
        }

        Section("Link") {
          Picker("Linked record type", selection: $draft.linkedEntityType) {
            ForEach(ReviewTaskLinkedEntityType.allCases) { type in Text(type.rawValue).tag(type) }
          }
          TextField("Linked record ID", text: $draft.linkedEntityID)
        }
      }
      .navigationTitle("Edit Readiness")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: { dismiss() })
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            onSave(draft)
            dismiss()
          }
        }
      }
    }
    .frame(minWidth: 660, minHeight: 700)
  }
}
