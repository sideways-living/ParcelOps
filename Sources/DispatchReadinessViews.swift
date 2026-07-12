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
    let query = readinessSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
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
        inboxReadinessCoverage
        gmailReadinessReleaseBoundary
        if !store.gmailMailboxConnections.isEmpty {
          GmailPostRefreshActionCard(plan: store.gmailPostRefreshActionPlan)
        }

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
              detail: hasActiveFilters ? "Clear search or filters to return to all readiness checklists." : "Add a local checklist to confirm dispatch requirements.",
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
    VStack(alignment: .leading, spacing: 10) {
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

      CompactActionRow {
        NavigationLink {
          DispatchView(store: store)
        } label: {
          Label("Open Dispatch", systemImage: "paperplane.fill")
        }
        NavigationLink {
          ShipmentManifestsView(store: store)
        } label: {
          Label("Open Manifests", systemImage: "list.bullet.clipboard.fill")
        }
        NavigationLink {
          AuditView(store: store)
        } label: {
          Label("Open Audit", systemImage: "list.clipboard.fill")
        }
      }
      .buttonStyle(.bordered)
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

      Picker("Status", selection: $selectedStatus) {
        Text("All status").tag(nil as DispatchChecklistStatus?)
        ForEach(DispatchChecklistStatus.allCases) { status in Text(status.rawValue).tag(status as DispatchChecklistStatus?) }
      }

      TextField("Owner/team", text: $ownerTeam)
        .textFieldStyle(.roundedBorder)

      Picker("Risk", selection: $selectedRiskLevel) {
        Text("All risk").tag(nil as ShipmentRiskLevel?)
        ForEach(ShipmentRiskLevel.allCases) { risk in Text(risk.rawValue).tag(risk as ShipmentRiskLevel?) }
      }

      Picker("Linked", selection: $selectedLinkedEntityType) {
        Text("All links").tag(nil as ReviewTaskLinkedEntityType?)
        ForEach(ReviewTaskLinkedEntityType.allCases) { type in Text(type.rawValue).tag(type as ReviewTaskLinkedEntityType?) }
      }

      Picker("Review", selection: $selectedReviewState) {
        Text("All review").tag(nil as ReviewState?)
        ForEach(reviewStates, id: \.self) { state in Text(state.rawValue).tag(state as ReviewState?) }
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
    selectedType = nil
    selectedStatus = nil
    ownerTeam = ""
    selectedRiskLevel = nil
    selectedLinkedEntityType = nil
    selectedReviewState = nil
    readinessSearchText = ""
  }

  private var inboxReadinessCoverage: some View {
    let inboxOrders = inboxCreatedOrders
    let linkedChecklists = checklistsLinkedToInboxOrders
    let actionChecklists = checklistsNeedingAction
    let missingChecklistCount = inboxOrdersMissingChecklist.count

    return SettingsPanel(title: "Inbox readiness coverage", symbol: "checkmark.rectangle.stack.fill") {
      VStack(alignment: .leading, spacing: 10) {
        Text("Checks whether orders created from Inbox intake have a local go/no-go checklist for labels, scans, custody, manifests, and handoff requirements.")
          .font(.caption)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 150) {
          Badge("\(inboxOrders.count) Inbox orders", color: .blue)
          Badge("\(linkedChecklists.count) linked checks", color: .teal)
          Badge("\(actionChecklists.count) need action", color: actionChecklists.isEmpty ? .green : .orange)
          Badge("\(missingChecklistCount) missing checks", color: missingChecklistCount == 0 ? .green : .orange)
        }

        if inboxOrders.isEmpty {
          Text("No Inbox-created orders are present yet. Create an order from Inbox before checking dispatch readiness.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if linkedChecklists.isEmpty {
          Text("Inbox-created orders do not have readiness checklists yet. Add or create a checklist before outbound handoff.")
            .font(.caption)
            .foregroundStyle(.orange)
        } else {
          ForEach(Array(actionChecklists.prefix(3))) { checklist in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: checklist.checklistStatus == .blockedNeedsReview ? "exclamationmark.triangle.fill" : "checkmark.rectangle.stack.fill")
                .foregroundStyle(checklist.checklistStatus == .blockedNeedsReview ? .red : .orange)
              VStack(alignment: .leading, spacing: 2) {
                Text(checklist.title)
                  .font(.caption.bold())
                Text(readinessActionSummary(for: checklist))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Badge(checklist.checklistStatus.rawValue, color: checklist.checklistStatus.color)
            }
          }

          if actionChecklists.isEmpty {
            Text("Linked readiness checklists look complete, reviewed, and clear for current Inbox-created orders.")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else if actionChecklists.count > 3 {
            Text("\(actionChecklists.count - 3) more linked readiness checklists need missing requirements, status, owner, or review follow-up.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private var gmailReadinessReleaseBoundary: some View {
    GmailReleaseBoundaryPanel(
      store: store,
      title: "Gmail dispatch readiness",
      lead: "Gmail release checks are setup and evidence work. Dispatch readiness checklists should only be created for concrete orders, manifests, labels, scans, custody, or handoff requirements after Inbox intake has been confirmed.",
      sourceMetricTitle: "Gmail readiness sources",
      sourceCount: gmailReadinessSourceCount,
      boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store tokens, call carrier APIs, book couriers, print labels, scan barcodes, or change dispatch readiness automatically."
    )
  }

  private var gmailReadinessSourceCount: Int {
    inboxCreatedOrders
      .flatMap { linkedIntakeEmails(for: $0) }
      .filter { store.intakeSourceSummary(for: $0).label.localizedCaseInsensitiveContains("Gmail") }
      .count
  }

  private var inboxCreatedOrders: [TrackedOrder] {
    store.orders.filter { !linkedIntakeEmails(for: $0).isEmpty }
  }

  private var checklistsLinkedToInboxOrders: [DispatchReadinessChecklist] {
    let orderIDs = Set(inboxCreatedOrders.map(\.id))
    let receiptIDs = Set(store.inventoryReceipts.filter { receipt in
      if let orderID = receipt.orderID, orderIDs.contains(orderID) {
        return true
      }
      if receipt.linkedEntityType == .order, let linkedID = UUID(uuidString: receipt.linkedEntityID), orderIDs.contains(linkedID) {
        return true
      }
      return false
    }.map(\.id))
    let custodyIDs = Set(store.custodyRecords.filter { record in
      (record.orderID.map { orderIDs.contains($0) } ?? false)
        || (record.inventoryReceiptID.map { receiptIDs.contains($0) } ?? false)
    }.map(\.id))
    let labelIDs = Set(store.labelReferenceRecords.filter { record in
      (record.orderID.map { orderIDs.contains($0) } ?? false)
        || (record.inventoryReceiptID.map { receiptIDs.contains($0) } ?? false)
        || (record.custodyRecordID.map { custodyIDs.contains($0) } ?? false)
    }.map(\.id))
    let scanIDs = Set(store.scanSessionRecords.filter { record in
      (record.orderID.map { orderIDs.contains($0) } ?? false)
        || (record.inventoryReceiptID.map { receiptIDs.contains($0) } ?? false)
        || (record.custodyRecordID.map { custodyIDs.contains($0) } ?? false)
        || (record.linkedLabelReferenceID.map { labelIDs.contains($0) } ?? false)
    }.map(\.id))
    let manifestIDs = Set(store.shipmentManifestRecords.filter { manifest in
      !Set(manifest.includedOrderIDs).isDisjoint(with: orderIDs)
        || !Set(manifest.inventoryReceiptIDs).isDisjoint(with: receiptIDs)
        || !Set(manifest.custodyRecordIDs).isDisjoint(with: custodyIDs)
        || !Set(manifest.labelReferenceIDs).isDisjoint(with: labelIDs)
        || !Set(manifest.scanSessionIDs).isDisjoint(with: scanIDs)
        || (manifest.linkedEntityType == .order && UUID(uuidString: manifest.linkedEntityID).map { orderIDs.contains($0) } == true)
    }.map(\.id))

    return store.dispatchReadinessChecklists.filter { checklist in
      !Set(checklist.orderIDs).isDisjoint(with: orderIDs)
        || !Set(checklist.inventoryReceiptIDs).isDisjoint(with: receiptIDs)
        || !Set(checklist.custodyRecordIDs).isDisjoint(with: custodyIDs)
        || !Set(checklist.labelReferenceIDs).isDisjoint(with: labelIDs)
        || !Set(checklist.scanSessionIDs).isDisjoint(with: scanIDs)
        || (checklist.shipmentManifestID.map { manifestIDs.contains($0) } ?? false)
        || (checklist.linkedEntityType == .order && UUID(uuidString: checklist.linkedEntityID).map { orderIDs.contains($0) } == true)
    }
  }

  private var inboxOrdersMissingChecklist: [TrackedOrder] {
    let checklistOrderIDs = Set(checklistsLinkedToInboxOrders.flatMap(\.orderIDs))
    return inboxCreatedOrders.filter { order in
      !checklistOrderIDs.contains(order.id)
        && !checklistsLinkedToInboxOrders.contains { checklist in
          checklist.linkedEntityType == .order && UUID(uuidString: checklist.linkedEntityID) == order.id
        }
    }
  }

  private var checklistsNeedingAction: [DispatchReadinessChecklist] {
    checklistsLinkedToInboxOrders.filter { checklist in
      checklist.checklistStatus == .draft
        || checklist.checklistStatus == .ready
        || checklist.checklistStatus == .blockedNeedsReview
        || checklist.checklistStatus == .reopened
        || checklist.reviewState != .accepted
        || checklist.riskLevel == .high
        || checklist.riskLevel == .critical
        || checklist.assignedOwnerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || hasMissingRequirements(checklist)
        || checklist.orderIDs.isEmpty
        || checklist.labelReferenceIDs.isEmpty
        || checklist.scanSessionIDs.isEmpty
    }
  }

  private func readinessActionSummary(for checklist: DispatchReadinessChecklist) -> String {
    var parts: [String] = []
    if checklist.checklistStatus == .draft || checklist.checklistStatus == .reopened { parts.append("mark ready") }
    if checklist.checklistStatus == .ready { parts.append("complete after handoff") }
    if checklist.checklistStatus == .blockedNeedsReview { parts.append("resolve block") }
    if hasMissingRequirements(checklist) { parts.append("clear missing requirements") }
    if checklist.orderIDs.isEmpty { parts.append("link orders") }
    if checklist.labelReferenceIDs.isEmpty { parts.append("link labels") }
    if checklist.scanSessionIDs.isEmpty { parts.append("link scans") }
    if checklist.assignedOwnerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { parts.append("assign owner") }
    if checklist.riskLevel == .high || checklist.riskLevel == .critical { parts.append("review risk") }
    if checklist.reviewState != .accepted { parts.append("mark reviewed") }
    return parts.isEmpty ? "Readiness checklist is complete and reviewed." : parts.joined(separator: ", ")
  }

  private func hasMissingRequirements(_ checklist: DispatchReadinessChecklist) -> Bool {
    let missing = checklist.missingRequirementsSummary.trimmingCharacters(in: .whitespacesAndNewlines)
    return !missing.isEmpty && !missing.localizedCaseInsensitiveContains("no missing")
  }

  private func linkedIntakeEmails(for order: TrackedOrder) -> [ForwardedEmailIntake] {
    let orderNumber = order.orderNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    return store.intakeEmails.filter { email in
      email.linkedOrderID == order.id
        || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.detectedOrderNumber.localizedCaseInsensitiveContains(orderNumber))
        || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.subject.localizedCaseInsensitiveContains(orderNumber))
        || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.rawBodyPreview.localizedCaseInsensitiveContains(orderNumber))
    }
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
    return searchableText.localizedLowercase.contains(query)
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
  @State private var feedbackMessage: String?

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
            if checklist.isInboxDispatchHandoffSetup {
              Badge("Inbox handoff", color: .teal)
            }
            if checklist.isWishlistDispatchSetup {
              Badge("Wishlist dispatch", color: .pink)
            }
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

      if checklist.isInboxDispatchHandoffSetup {
        LinkedOrdersContextPanel(
          title: "Inbox-created order readiness check",
          linkedOrders: linkedOrders,
          sourceLabel: checklist.checklistStatus.rawValue,
          emptyDetail: "This checklist was created from Inbox handoff context, but no matching local order was found. Check the checklist before completing readiness.",
          linkedDetail: readinessHandoffDetail,
          tone: checklist.checklistStatus.color,
          store: store
        )
      }

      if checklist.isWishlistDispatchSetup {
        LinkedOrdersContextPanel(
          title: "Wishlist dispatch source",
          linkedOrders: linkedOrders,
          sourceLabel: checklist.checklistStatus.rawValue,
          emptyDetail: "This readiness checklist was staged from a Wishlist item, but no linked local order was found. Confirm the purchase handoff before marking dispatch ready.",
          linkedDetail: "This readiness checklist was staged from a Wishlist purchase handoff. Open the linked order to confirm source trail, tracking, destination, labels, scans, and custody before completing readiness.",
          tone: .pink,
          store: store
        )
      }

      if !readinessWarnings.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Label("Readiness follow-up", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.bold())
            .foregroundStyle(.orange)
          ForEach(readinessWarnings, id: \.self) { warning in
            Text(warning)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Ready", systemImage: "checkmark.circle.fill") {
          onReady()
          feedbackMessage = "Readiness checklist marked ready locally."
        }
          .buttonStyle(.bordered)
        Button("Blocked", systemImage: "exclamationmark.triangle.fill") {
          onBlocked()
          feedbackMessage = "Readiness checklist blocked for review."
        }
          .buttonStyle(.bordered)
        Button("Complete", systemImage: "checkmark.seal.fill") {
          onCompleted()
          feedbackMessage = "Readiness checklist completed locally."
        }
          .buttonStyle(.bordered)
        Button("Reopen", systemImage: "arrow.counterclockwise") {
          onReopen()
          feedbackMessage = "Readiness checklist reopened for review."
        }
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.shield.fill") {
          onReviewed()
          feedbackMessage = "Readiness checklist marked reviewed locally."
        }
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Readiness follow-up task created. Check Tasks."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Readiness draft message created locally."
        }
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
          .buttonStyle(.bordered)
      }

      if let feedbackMessage {
        DispatchReadinessFeedbackPanel(message: feedbackMessage, store: store)
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

  private var readinessHandoffDetail: String {
    switch checklist.checklistStatus {
    case .draft, .reopened:
      return "Confirm labels, scans, custody, destination, and handoff requirements. Open linked orders here when source context needs confirmation."
    case .ready:
      return "Checklist is ready. Open linked orders here before completing readiness if tracking, destination, or handoff setup still needs confirmation."
    case .completed:
      return "Readiness is complete. The linked Inbox-created order can move through dispatch monitoring."
    case .blockedNeedsReview:
      return "Resolve the blocked readiness item before progressing dispatch."
    }
  }

  private var readinessWarnings: [String] {
    var warnings: [String] = []
    if checklist.checklistStatus == .draft || checklist.checklistStatus == .reopened {
      warnings.append("Checklist is not ready yet.")
    }
    if checklist.checklistStatus == .ready {
      warnings.append("Checklist is ready but not completed.")
    }
    if checklist.checklistStatus == .blockedNeedsReview {
      warnings.append("Checklist is blocked and needs review before dispatch.")
    }
    let missing = checklist.missingRequirementsSummary.trimmingCharacters(in: .whitespacesAndNewlines)
    if !missing.isEmpty && !missing.localizedCaseInsensitiveContains("no missing") {
      warnings.append("Missing requirements: \(missing)")
    }
    if checklist.orderIDs.isEmpty {
      warnings.append("No orders are linked.")
    }
    if checklist.labelReferenceIDs.isEmpty {
      warnings.append("No label references are linked.")
    }
    if checklist.scanSessionIDs.isEmpty {
      warnings.append("No scan sessions are linked.")
    }
    if checklist.assignedOwnerTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      warnings.append("Owner/team is missing.")
    }
    if checklist.riskLevel == .high || checklist.riskLevel == .critical {
      warnings.append("Risk is \(checklist.riskLevel.rawValue.lowercased()); confirm dispatch readiness handling.")
    }
    if checklist.reviewState != .accepted {
      warnings.append("Review state is \(checklist.reviewState.rawValue.lowercased()); mark reviewed after local checks are complete.")
    }
    return warnings
  }
}

private extension DispatchReadinessChecklist {
  var isInboxDispatchHandoffSetup: Bool {
    linkedEntityType == .order
      && (
        title.localizedCaseInsensitiveContains("Readiness for")
          || completedChecksSummary.localizedCaseInsensitiveContains("Inbox handoff")
          || missingRequirementsSummary.localizedCaseInsensitiveContains("handoff location")
      )
  }

  var isWishlistDispatchSetup: Bool {
    linkedEntityType == .wishlistItem
      || title.localizedCaseInsensitiveContains("Wishlist dispatch")
      || requiredChecksSummary.localizedCaseInsensitiveContains("purchase/order evidence")
      || missingRequirementsSummary.localizedCaseInsensitiveContains("Wishlist")
  }
}

private struct DispatchReadinessFeedbackPanel: View {
  var message: String
  var store: ParcelOpsStore?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(message, systemImage: "checkmark.circle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.green)

      if let store {
        CompactActionRow {
          NavigationLink {
            DispatchView(store: store)
          } label: {
            Label("Open Dispatch", systemImage: "paperplane.fill")
          }
          if message.localizedCaseInsensitiveContains("task") {
            NavigationLink {
              TasksView(store: store)
            } label: {
              Label("Open Tasks", systemImage: "checklist")
            }
          }
          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Open Audit", systemImage: "list.clipboard.fill")
          }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.green.opacity(0.12))
    .clipShape(RoundedRectangle(cornerRadius: 8))
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
