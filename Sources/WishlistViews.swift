import SwiftUI

private enum WishlistWorkflowFocus: String, CaseIterable, Identifiable {
  case all = "All"
  case capture = "Capture"
  case compare = "Compare"
  case buy = "Buy"
  case watch = "Watch"
  case operations = "Operations"

  var id: String { rawValue }
  var title: String { rawValue }

  var detail: String {
    switch self {
    case .all:
      return "Show every active Wishlist item."
    case .capture:
      return "Items still need basic item, seller, source, or capture details before comparison."
    case .compare:
      return "Items need seller options, landed cost, postage, trust, or recommendation review."
    case .buy:
      return "Items are in purchase decision, checklist, or manual handoff preparation."
    case .watch:
      return "Items have purchase handoff/order-watch state and need order confirmation linking."
    case .operations:
      return "Items are linked or confirmed enough to stage receiving, storage, custody, and dispatch records."
    }
  }

  var color: Color {
    switch self {
    case .all: return .blue
    case .capture: return .blue
    case .compare: return .orange
    case .buy: return .purple
    case .watch: return .green
    case .operations: return .teal
    }
  }

  func matches(item: WishlistItem, in store: ParcelOpsStore) -> Bool {
    switch self {
    case .all:
      return true
    case .capture:
      return item.comparisonOptions?.isEmpty != false
        && item.purchaseDecision == nil
        && item.purchaseHandoff == nil
    case .compare:
      return item.comparisonOptions?.isEmpty == false
        && (item.purchaseDecision == nil || item.purchaseDecision?.reviewState == .needsReview)
        && item.purchaseHandoff == nil
    case .buy:
      return item.purchaseDecision != nil
        && item.purchaseHandoff == nil
        || item.purchaseReadiness?.localizedCaseInsensitiveContains("purchase") == true
          && item.purchaseHandoff == nil
    case .watch:
      return item.purchaseHandoff != nil
        && item.purchaseHandoff?.linkedOrderID == nil
    case .operations:
      return item.purchaseHandoff?.linkedOrderID != nil
        || !store.suggestedReceivingInspections(for: item).isEmpty
        || !store.suggestedInventoryReceipts(for: item).isEmpty
        || !store.suggestedShipmentManifestRecords(for: item).isEmpty
        || !store.suggestedDispatchReadinessChecklists(for: item).isEmpty
    }
  }
}

private struct WishlistLocalActivityRow: View {
  var event: AuditEvent
  var onCreateTask: () -> Void
  @State private var showDetails = false
  @State private var feedbackMessage: String?

  private var outcomeLines: [String] {
    guard let detail = event.afterDetail else { return [] }
    let wantedPrefixes = [
      "Status:",
      "Readiness result:",
      "Scoring basis:",
      "Linked order:",
      "Created order:",
      "Manual record only.",
      "Review only."
    ]
    return detail
      .components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { line in wantedPrefixes.contains { line.hasPrefix($0) } }
      .prefix(4)
      .map { $0 }
  }

  private var shortDetail: String {
    let detail = event.afterDetail ?? event.beforeDetail ?? ""
    let clean = detail
      .components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .prefix(3)
      .joined(separator: " ")
    return clean.isEmpty ? "No detail recorded." : clean
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: event.entityType.symbol)
          .foregroundStyle(event.action.color)
          .frame(width: 22, height: 22)
        VStack(alignment: .leading, spacing: 3) {
          Text(event.entityLabel)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("\(event.action.rawValue) • \(event.timestamp)")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(event.summary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(event.entityType.rawValue, color: event.action.color)
      }

      if !outcomeLines.isEmpty {
        CompactMetadataGrid(minimumWidth: 135) {
          ForEach(outcomeLines, id: \.self) { line in
            Badge(line, color: event.action.color)
          }
        }
      }

      if showDetails {
        Text(shortDetail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
      }

      if let feedbackMessage {
        Label(feedbackMessage, systemImage: "checkmark.circle.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.green)
      }

      CompactActionRow {
        Button(showDetails ? "Hide detail" : "Show detail", systemImage: "text.alignleft") {
          showDetails.toggle()
        }
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Wishlist follow-up task created locally. Check Tasks."
        }
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .background(event.action.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistDataQualityIssue: Identifiable {
  var id: String { title }
  var title: String
  var detail: String
  var symbol: String
  var color: Color
  var priority: Int
}

private struct WishlistDataQualityEntry: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var issues: [WishlistDataQualityIssue]
  var stage: String
  var nextAction: String
  var nextSymbol: String
  var tone: Color
  var sortPriority: Int
}

private struct WishlistDataQualityRow: View {
  var entry: WishlistDataQualityEntry
  var onFocus: () -> Void
  var onAction: () -> Void
  var onTask: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.issues.first?.symbol ?? "checklist")
          .foregroundStyle(entry.tone)
          .frame(width: 24, height: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("\(entry.stage) • \(entry.item.storefront)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text(entry.issues.first?.detail ?? entry.item.operatorPurchaseNextAction)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge("\(entry.issues.count) gap\(entry.issues.count == 1 ? "" : "s")", color: entry.tone)
      }

      CompactMetadataGrid(minimumWidth: 150) {
        ForEach(entry.issues.prefix(4)) { issue in
          Label(issue.title, systemImage: issue.symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(issue.color)
            .lineLimit(1)
        }
      }

      CompactActionRow {
        Button("Focus", systemImage: "scope", action: onFocus)
        Button(entry.nextAction, systemImage: entry.nextSymbol, action: onAction)
        Button("Task", systemImage: "checklist", action: onTask)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct WishlistView: View {
  var store: ParcelOpsStore
  @State private var showDeletedItems = false
  @State private var wishlistSearchText = ""
  @State private var selectedSource: WishlistSource?
  @State private var selectedStatus: String?
  @State private var selectedWorkflowFocus: WishlistWorkflowFocus = .all
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var statuses: [String] {
    Array(Set(store.wishlistItems.map(\.status))).sorted()
  }

  private let wishlistSources: [WishlistSource] = [.pdf, .screenshot, .shareSheet, .browserExtension, .manual]

  private var baseFilteredItems: [WishlistItem] {
    store.wishlistItems.filter { item in
      let matchesSource = selectedSource == nil || item.source == selectedSource
      let matchesStatus = selectedStatus == nil || item.status == selectedStatus
      let matchesWorkflow = selectedWorkflowFocus.matches(item: item, in: store)
      return matchesSource && matchesStatus && matchesWorkflow
    }
  }

  private var filteredItems: [WishlistItem] {
    let query = wishlistSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredItems }
    return baseFilteredItems.filter { item in
      [
        item.id.uuidString,
        item.itemName,
        item.storefront,
        item.storefrontURL,
        item.estimatedCost,
        item.owner,
        item.pool,
        item.source.rawValue,
        item.status,
        item.capturedDetail
      ].joined(separator: " ").localizedLowercase.contains(query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedSource != nil
      || selectedStatus != nil
      || selectedWorkflowFocus != .all
      || !wishlistSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var gmailWishlistCandidateEmails: [ForwardedEmailIntake] {
    store.intakeEmails
      .filter { email in
        store.intakeSourceSummary(for: email).tone == "gmail"
          && gmailWishlistCandidateScore(for: email) > 0
      }
      .sorted(by: { first, second in
        let firstScore = gmailWishlistCandidateScore(for: first)
        let secondScore = gmailWishlistCandidateScore(for: second)
        if firstScore == secondScore {
          return first.receivedDate > second.receivedDate
        }
        return firstScore > secondScore
      })
  }

  private var gmailWishlistReadyCount: Int {
    gmailWishlistCandidateEmails.filter { email in
      !email.detectedMerchant.isPlaceholderValidationValue
        || !email.detectedOrderNumber.isPlaceholderValidationValue
        || !email.subject.isPlaceholderValidationValue
    }.count
  }

  private var wishlistPurchaseBlockerQueueItems: [WishlistItem] {
    store.wishlistItems
      .filter { !$0.operatorPurchaseBlockers.isEmpty }
      .sorted { first, second in
        if first.operatorPurchaseBlockers.count == second.operatorPurchaseBlockers.count {
          return first.itemName.localizedCaseInsensitiveCompare(second.itemName) == .orderedAscending
        }
        return first.operatorPurchaseBlockers.count > second.operatorPurchaseBlockers.count
      }
  }

  private var wishlistPipelineItems: [WishlistPipelineItem] {
    store.wishlistItems
      .map(wishlistPipelineItem(for:))
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistDataQualityEntries: [WishlistDataQualityEntry] {
    store.wishlistItems
      .compactMap { item in
        let issues = wishlistDataQualityIssues(for: item)
        guard !issues.isEmpty else { return nil }
        let firstIssue = issues.sorted { $0.priority < $1.priority }.first
        return WishlistDataQualityEntry(
          item: item,
          issues: issues.sorted { first, second in
            if first.priority == second.priority {
              return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
            }
            return first.priority < second.priority
          },
          stage: wishlistDataQualityStage(for: item),
          nextAction: wishlistDataQualityActionTitle(for: item, firstIssue: firstIssue),
          nextSymbol: wishlistDataQualityActionSymbol(for: item, firstIssue: firstIssue),
          tone: firstIssue?.color ?? .blue,
          sortPriority: firstIssue?.priority ?? 100
        )
      }
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Wishlist")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Per-user purchase ideas can be staged locally before becoming orders. File, screenshot, share, and extension capture are placeholder paths unless explicitly implemented.")
            .foregroundStyle(.secondary)
        }

        HStack {
          Button("PDF placeholder", systemImage: "doc.badge.plus", action: store.uploadWishlistPDFPlaceholder)
          Button("Screenshot placeholder", systemImage: "photo.badge.plus", action: store.addWishlistScreenshotPlaceholder)
          Button("Browser capture", systemImage: "puzzlepiece.extension.fill", action: store.addBrowserExtensionWishlistCapturePlaceholder)
          Button("Manual item", systemImage: "plus", action: store.addManualWishlistItemPlaceholder)
        }
        .buttonStyle(.bordered)

        wishlistWorkflowFocusPanel
        wishlistLocalActivityPanel
        wishlistDataQualityPanel
        wishlistReadinessPanel
        wishlistPipelineBoardPanel
        wishlistPurchaseBlockerQueuePanel
        wishlistCaptureCandidatesPanel
        wishlistComparisonPlanningPanel
        wishlistSellerOptionReviewPanel
        wishlistSellerSafetyRubricPanel
        wishlistComparisonMatrixPanel
        wishlistLandedCostReviewPanel
        wishlistPurchaseDecisionQueuePanel
        wishlistPurchaseDecisionSummaryPanel
        wishlistPrePurchaseOperatorChecklistPanel
        wishlistPurchaseReleaseChecklistPanel
        wishlistPurchaseHandoffPackPanel
        wishlistPurchaseAccountLedgerPanel
        wishlistPostPurchaseOrderWatchPanel
        wishlistPurchaseOperationsHandoffPanel
        wishlistAgentHandoffPacketPanel
        wishlistAgentBatchBriefPanel
        wishlistResearchRequestsPanel
        gmailWishlistFocusPanel
        filterBar

        SettingsPanel(title: "Capture channels", symbol: "square.and.arrow.down.fill") {
          CaptureChannelRow(symbol: "doc.richtext.fill", title: "PDF placeholder", detail: "Creates a local test item only. No file picker, OCR, or PDF parser runs from this screen.")
          CaptureChannelRow(symbol: "photo.fill", title: "Screenshot placeholder", detail: "Creates a local test item only. No screenshot picker, OCR, or image parser runs from this screen.")
          CaptureChannelRow(symbol: "square.and.arrow.up.fill", title: "Share path placeholder", detail: "Documents a future share-sheet flow. ParcelOps does not receive shared browser pages yet.")
          CaptureChannelRow(symbol: "puzzlepiece.extension.fill", title: "Browser capture staging", detail: "Creates or reviews local capture candidates in the staging queue. No browser extension, scraping, or external sync is active here.")
        }

        SettingsPanel(title: "Wishlist items", symbol: "star.square.fill") {
          HStack {
            Text("\(filteredItems.count) visible wishlist items")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredItems.count) after filters", color: .blue)
            }
            Spacer()
            Button("Manual item", systemImage: "plus", action: store.addManualWishlistItemPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredItems.isEmpty {
            MVPEmptyState(title: "No wishlist items match this view", detail: hasActiveFilters ? "Clear search or filters to return to all active wishlist items." : "Add a manual wishlist item or use a placeholder capture action to test wishlist-to-order handoff.", symbol: "star.square.fill", actionTitle: hasActiveFilters ? "Clear filters" : "Manual item", action: hasActiveFilters ? clearFilters : store.addManualWishlistItemPlaceholder)
          } else {
            ForEach(filteredItems) { item in
              WishlistItemRow(
                item: item,
                linkedOrder: item.purchaseHandoff?.linkedOrderID.flatMap { orderID in
                  store.orders.first { $0.id == orderID }
                },
                store: store,
                confirmationMatches: store.suggestedWishlistOrderConfirmations(for: item),
                suggestedAccounts: store.suggestedAccounts(for: item),
                suggestedCosts: store.suggestedCostRecords(for: item),
                suggestedProcurementRequests: store.suggestedProcurementRequests(for: item),
                suggestedReceivingInspections: store.suggestedReceivingInspections(for: item),
                suggestedInventoryReceipts: store.suggestedInventoryReceipts(for: item),
                suggestedStorageLocations: store.suggestedStorageLocations(for: item),
                suggestedCustodyRecords: store.suggestedCustodyRecords(for: item),
                suggestedLabelReferences: store.suggestedLabelReferenceRecords(for: item),
                suggestedScanSessions: store.suggestedScanSessionRecords(for: item),
                suggestedShipmentManifests: store.suggestedShipmentManifestRecords(for: item),
                suggestedDispatchChecklists: store.suggestedDispatchReadinessChecklists(for: item)
              ) {
                store.convertWishlistToOrder(item)
              } onLink: {
                store.linkWishlistItemToOrder(item)
              } onCompare: {
                store.createWishlistComparisonPlan(item)
                store.createWishlistResearchRequest(from: item)
              } onAddOption: {
                store.addManualWishlistSellerOptionPlaceholder(item)
              } onScore: {
                store.evaluateWishlistComparisonOptions(item)
              } onEvidenceTask: {
                store.createWishlistSellerEvidenceReviewTask(item)
              } onCheck: {
                store.runWishlistPurchaseReadinessCheck(item)
              } onDecision: {
                store.createWishlistPurchaseDecision(item)
              } onDecisionReviewed: {
                store.markWishlistPurchaseDecisionReviewed(item)
              } onDecisionNeedsReview: {
                store.markWishlistPurchaseDecisionNeedsReview(item)
              } onDecisionTask: {
                store.createWishlistPurchaseDecisionReviewTask(item)
              } onHandoff: {
                store.prepareWishlistPurchaseHandoff(item)
              } onHandoffTask: {
                store.createWishlistPurchaseHandoffReviewTask(item)
              } onPurchased: {
                store.recordWishlistPurchasedExternally(item)
              } onOrderSeen: {
                store.markWishlistOrderConfirmationSeen(item)
              } onUseConfirmation: { email in
                store.confirmWishlistOrderFromIntake(item, email: email)
              } onAddAccount: {
                store.addAccountCredentialRecord(
                  linkedEntityType: .supplier,
                  linkedEntityID: item.id.uuidString,
                  organisation: item.purchaseHandoff?.sellerName ?? item.storefront,
                  label: item.itemName
                )
              } onAccountTask: { account in
                store.createReviewTask(from: account)
              } onAccountDraft: { account in
                store.createDraftMessage(from: account)
              } onAddCost: {
                store.createWishlistPurchaseCostRecord(item)
              } onCostTask: { cost in
                store.createReviewTask(from: cost)
              } onCostDraft: { cost in
                store.createDraftMessage(from: cost)
              } onAddProcurement: {
                store.createWishlistProcurementRequest(item)
              } onProcurementTask: { request in
                store.createReviewTask(from: request)
              } onProcurementDraft: { request in
                store.createDraftMessage(from: request)
              } onAddInspection: {
                store.createWishlistReceivingInspection(item)
              } onInspectionTask: { inspection in
                store.createReviewTask(from: inspection)
              } onInspectionDraft: { inspection in
                store.createDraftMessage(from: inspection)
              } onAddInventoryReceipt: {
                store.createWishlistInventoryReceipt(item)
              } onInventoryReceiptTask: { receipt in
                store.createReviewTask(from: receipt)
              } onInventoryReceiptDraft: { receipt in
                store.createDraftMessage(from: receipt)
              } onAddStorageLocation: {
                store.createWishlistStorageLocation(item)
              } onStorageLocationTask: { location in
                store.createReviewTask(from: location)
              } onStorageLocationDraft: { location in
                store.createDraftMessage(from: location)
              } onAddCustody: {
                store.createWishlistCustodyRecord(item)
              } onCustodyTask: { custody in
                store.createReviewTask(from: custody)
              } onCustodyDraft: { custody in
                store.createDraftMessage(from: custody)
              } onAddLabelReference: {
                store.createWishlistLabelReference(item)
              } onLabelReferenceTask: { label in
                store.createReviewTask(from: label)
              } onLabelReferenceDraft: { label in
                store.createDraftMessage(from: label)
              } onAddScanSession: {
                store.createWishlistScanSession(item)
              } onScanSessionTask: { scan in
                store.createReviewTask(from: scan)
              } onScanSessionDraft: { scan in
                store.createDraftMessage(from: scan)
              } onAddShipmentManifest: {
                store.createWishlistShipmentManifest(item)
              } onShipmentManifestTask: { manifest in
                store.createReviewTask(from: manifest)
              } onShipmentManifestDraft: { manifest in
                store.createDraftMessage(from: manifest)
              } onAddDispatchChecklist: {
                store.createWishlistDispatchReadinessChecklist(item)
              } onDispatchChecklistTask: { checklist in
                store.createReviewTask(from: checklist)
              } onDispatchChecklistDraft: { checklist in
                store.createDraftMessage(from: checklist)
              } onReady: {
                store.markWishlistReadyForPurchase(item)
              } onPreferredOption: { option in
                store.markWishlistPreferredOption(item, option: option)
              } onDuplicateOption: { option in
                store.duplicateWishlistSellerOption(item, option: option)
              } onUpdateOption: { option in
                store.updateWishlistSellerOption(item, option: option)
              } onRemoveOption: { option in
                store.removeWishlistSellerOption(item, option: option)
              } onTask: {
                store.createReviewTask(from: item)
              } onDraft: {
                store.createDraftMessage(from: item)
              } onDelete: {
                store.deleteWishlistItem(item)
              }
            }
          }
        }

        SettingsPanel(title: "Deleted items", symbol: "trash.fill") {
          Button {
            withAnimation(.snappy) {
              showDeletedItems.toggle()
            }
          } label: {
            HStack {
              Label("\(store.deletedWishlistItems.count) deleted item", systemImage: showDeletedItems ? "folder.fill.badge.minus" : "folder.fill")
              Spacer()
              Image(systemName: showDeletedItems ? "chevron.up" : "chevron.down")
                .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)

          if showDeletedItems {
            Text("Deleted wishlist items are retained for 90 days before permanent removal.")
              .font(.caption)
              .foregroundStyle(.secondary)
            ForEach(store.deletedWishlistItems) { item in
              WishlistItemRow(item: item, isDeleted: true) {
                store.restoreWishlistItem(item)
              } onLink: {
                store.permanentlyDeleteWishlistItem(item)
              } onCompare: {
                store.restoreWishlistItem(item)
              } onAddOption: {
                store.restoreWishlistItem(item)
              } onScore: {
                store.restoreWishlistItem(item)
              } onEvidenceTask: {
                store.restoreWishlistItem(item)
              } onCheck: {
                store.restoreWishlistItem(item)
              } onDecision: {
                store.restoreWishlistItem(item)
              } onDecisionReviewed: {
                store.restoreWishlistItem(item)
              } onDecisionNeedsReview: {
                store.restoreWishlistItem(item)
              } onDecisionTask: {
                store.restoreWishlistItem(item)
              } onHandoff: {
                store.restoreWishlistItem(item)
              } onHandoffTask: {
                store.restoreWishlistItem(item)
              } onPurchased: {
                store.restoreWishlistItem(item)
              } onOrderSeen: {
                store.restoreWishlistItem(item)
              } onUseConfirmation: { _ in
                store.restoreWishlistItem(item)
              } onAddAccount: {
                store.restoreWishlistItem(item)
              } onAccountTask: { _ in
                store.restoreWishlistItem(item)
              } onAccountDraft: { _ in
                store.restoreWishlistItem(item)
              } onAddCost: {
                store.restoreWishlistItem(item)
              } onCostTask: { _ in
                store.restoreWishlistItem(item)
              } onCostDraft: { _ in
                store.restoreWishlistItem(item)
              } onAddProcurement: {
                store.restoreWishlistItem(item)
              } onProcurementTask: { _ in
                store.restoreWishlistItem(item)
              } onProcurementDraft: { _ in
                store.restoreWishlistItem(item)
              } onAddInspection: {
                store.restoreWishlistItem(item)
              } onInspectionTask: { _ in
                store.restoreWishlistItem(item)
              } onInspectionDraft: { _ in
                store.restoreWishlistItem(item)
              } onAddInventoryReceipt: {
                store.restoreWishlistItem(item)
              } onInventoryReceiptTask: { _ in
                store.restoreWishlistItem(item)
              } onInventoryReceiptDraft: { _ in
                store.restoreWishlistItem(item)
              } onAddStorageLocation: {
                store.restoreWishlistItem(item)
              } onStorageLocationTask: { _ in
                store.restoreWishlistItem(item)
              } onStorageLocationDraft: { _ in
                store.restoreWishlistItem(item)
              } onAddCustody: {
                store.restoreWishlistItem(item)
              } onCustodyTask: { _ in
                store.restoreWishlistItem(item)
              } onCustodyDraft: { _ in
                store.restoreWishlistItem(item)
              } onAddLabelReference: {
                store.restoreWishlistItem(item)
              } onLabelReferenceTask: { _ in
                store.restoreWishlistItem(item)
              } onLabelReferenceDraft: { _ in
                store.restoreWishlistItem(item)
              } onAddScanSession: {
                store.restoreWishlistItem(item)
              } onScanSessionTask: { _ in
                store.restoreWishlistItem(item)
              } onScanSessionDraft: { _ in
                store.restoreWishlistItem(item)
              } onAddShipmentManifest: {
                store.restoreWishlistItem(item)
              } onShipmentManifestTask: { _ in
                store.restoreWishlistItem(item)
              } onShipmentManifestDraft: { _ in
                store.restoreWishlistItem(item)
              } onAddDispatchChecklist: {
                store.restoreWishlistItem(item)
              } onDispatchChecklistTask: { _ in
                store.restoreWishlistItem(item)
              } onDispatchChecklistDraft: { _ in
                store.restoreWishlistItem(item)
              } onReady: {
                store.restoreWishlistItem(item)
              } onPreferredOption: { _ in
                store.restoreWishlistItem(item)
              } onDuplicateOption: { _ in
                store.restoreWishlistItem(item)
              } onUpdateOption: { _ in
                store.restoreWishlistItem(item)
              } onRemoveOption: { _ in
                store.restoreWishlistItem(item)
              } onTask: {
                store.restoreWishlistItem(item)
              } onDraft: {
                store.restoreWishlistItem(item)
              } onDelete: {
                store.permanentlyDeleteWishlistItem(item)
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
      TextField("Search item, store, URL, cost, owner, pool, source, or captured detail", text: $wishlistSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Source", selection: $selectedSource) {
        Text("All sources").tag(nil as WishlistSource?)
        ForEach(wishlistSources, id: \.self) { source in
          Text(source.rawValue).tag(source as WishlistSource?)
        }
      }

      Picker("Status", selection: $selectedStatus) {
        Text("All status").tag(nil as String?)
        ForEach(statuses, id: \.self) { status in
          Text(status).tag(status as String?)
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
    wishlistSearchText = ""
    selectedSource = nil
    selectedStatus = nil
    selectedWorkflowFocus = .all
  }

  private var wishlistWorkflowFocusPanel: some View {
    let all = store.wishlistItems
    let capture = all.filter { WishlistWorkflowFocus.capture.matches(item: $0, in: store) }.count
    let compare = all.filter { WishlistWorkflowFocus.compare.matches(item: $0, in: store) }.count
    let buy = all.filter { WishlistWorkflowFocus.buy.matches(item: $0, in: store) }.count
    let watch = all.filter { WishlistWorkflowFocus.watch.matches(item: $0, in: store) }.count
    let operations = all.filter { WishlistWorkflowFocus.operations.matches(item: $0, in: store) }.count
    let selectedCount = all.filter { selectedWorkflowFocus.matches(item: $0, in: store) }.count

    return SettingsPanel(title: "Workflow focus", symbol: "point.3.connected.trianglepath.dotted") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this as the daily Wishlist map: capture the item, compare seller options, decide whether to buy, watch for order confirmation, then stage receiving and dispatch records.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("All", "\(all.count)", selectedWorkflowFocus == .all ? .blue : .secondary),
          ("Capture", "\(capture)", capture == 0 ? .secondary : .blue),
          ("Compare", "\(compare)", compare == 0 ? .secondary : .orange),
          ("Buy", "\(buy)", buy == 0 ? .secondary : .purple),
          ("Watch", "\(watch)", watch == 0 ? .secondary : .green),
          ("Ops", "\(operations)", operations == 0 ? .secondary : .teal)
        ])

        Picker("Wishlist workflow focus", selection: $selectedWorkflowFocus) {
          ForEach(WishlistWorkflowFocus.allCases) { focus in
            Text(focus.title).tag(focus)
          }
        }
        .pickerStyle(.segmented)

        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Badge("\(selectedCount) in \(selectedWorkflowFocus.title)", color: selectedWorkflowFocus == .all ? .blue : selectedWorkflowFocus.color)
          Text(selectedWorkflowFocus.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Spacer(minLength: 8)
          if selectedWorkflowFocus != .all {
            Button("Show all", systemImage: "line.3.horizontal.decrease.circle") {
              selectedWorkflowFocus = .all
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
          }
        }

        Text("This is a view filter only. It does not search retailers, buy anything, log in, store payment details, fetch mail, or modify downstream records.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistLocalActivityEvents: [AuditEvent] {
    store.auditEvents
      .filter { event in
        let searchable = [
          event.entityLabel,
          event.summary,
          event.beforeDetail ?? "",
          event.afterDetail ?? "",
          event.entityType.rawValue
        ].joined(separator: " ")
        return event.entityType == .wishlistItem
          || searchable.localizedCaseInsensitiveContains("wishlist")
          || searchable.localizedCaseInsensitiveContains("purchase handoff")
          || searchable.localizedCaseInsensitiveContains("purchase decision")
          || searchable.localizedCaseInsensitiveContains("seller option")
          || searchable.localizedCaseInsensitiveContains("order confirmation")
      }
      .prefix(8)
      .map { $0 }
  }

  private var wishlistLocalActivityPanel: some View {
    let events = wishlistLocalActivityEvents
    let purchaseEvents = events.filter { event in
      [event.summary, event.afterDetail ?? ""].joined(separator: " ").localizedCaseInsensitiveContains("purchase")
    }.count
    let orderEvents = events.filter { event in
      [event.summary, event.afterDetail ?? ""].joined(separator: " ").localizedCaseInsensitiveContains("order")
    }.count

    return SettingsPanel(title: "Recent Wishlist activity", symbol: "clock.arrow.circlepath") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Recent local Wishlist actions are shown here so purchase, comparison, handoff, and order-watch changes can be checked without leaving this screen.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Recent", "\(events.count)", events.isEmpty ? .secondary : .blue),
          ("Purchase", "\(purchaseEvents)", purchaseEvents == 0 ? .secondary : .purple),
          ("Order trail", "\(orderEvents)", orderEvents == 0 ? .secondary : .teal)
        ])

        if events.isEmpty {
          MVPEmptyState(
            title: "No recent Wishlist activity",
            detail: "Wishlist creates, edits, comparison plans, purchase checks, handoffs, and order-watch actions will appear here after local actions are taken.",
            symbol: "clock.arrow.circlepath"
          )
        } else {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(events) { event in
              WishlistLocalActivityRow(event: event) {
                store.createReviewTask(from: event)
              }
            }
          }
        }

        Text("This is a read-only activity summary except for creating a local follow-up task. It does not contact retailers, fetch mail, access accounts, or change orders.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistDataQualityPanel: some View {
    let entries = wishlistDataQualityEntries
    let captureGaps = entries.filter { $0.stage == "Capture quality" }.count
    let comparisonGaps = entries.filter { $0.stage == "Comparison quality" }.count
    let purchaseGaps = entries.filter { $0.stage == "Purchase handoff" }.count

    return SettingsPanel(title: "Wishlist data quality", symbol: "checkmark.shield.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Fix weak item, seller, link, cost, comparison, and handoff fields before a Wishlist item becomes an order. Actions here are local checks, tasks, and planning records only.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Items with gaps", "\(entries.count)", entries.isEmpty ? .green : .orange),
          ("Capture", "\(captureGaps)", captureGaps == 0 ? .green : .blue),
          ("Compare", "\(comparisonGaps)", comparisonGaps == 0 ? .green : .orange),
          ("Handoff", "\(purchaseGaps)", purchaseGaps == 0 ? .green : .purple)
        ])

        if entries.isEmpty {
          Label("No prominent Wishlist data-quality gaps are currently flagged. Continue with comparison, decision, or order-watch work below.", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 360), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(6)) { entry in
              WishlistDataQualityRow(entry: entry) {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              } onAction: {
                runWishlistDataQualityAction(for: entry)
              } onTask: {
                runWishlistDataQualityTask(for: entry)
              }
            }
          }

          let remaining = max(entries.count - 6, 0)
          if remaining > 0 {
            Text("\(remaining) more Wishlist item\(remaining == 1 ? "" : "s") have quality gaps in the detailed list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("This panel does not verify live seller data, scrape pages, quote postage, log in, store payment details, or purchase items.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistDataQualityIssues(for item: WishlistItem) -> [WishlistDataQualityIssue] {
    let options = item.comparisonOptions ?? []
    var issues: [WishlistDataQualityIssue] = []

    func add(_ title: String, detail: String, symbol: String, color: Color, priority: Int) {
      issues.append(WishlistDataQualityIssue(title: title, detail: detail, symbol: symbol, color: color, priority: priority))
    }

    if item.itemName.isPlaceholderValidationValue || item.itemName.localizedCaseInsensitiveContains("placeholder") {
      add("Item name", detail: "Replace the placeholder item name before comparison or purchase handoff.", symbol: "text.cursor", color: .orange, priority: 10)
    }
    if item.storefront.isPlaceholderValidationValue || item.storefront.localizedCaseInsensitiveContains("placeholder") {
      add("Seller/source", detail: "Confirm the retailer, direct product source, or expected purchase channel.", symbol: "storefront", color: .orange, priority: 12)
    }
    if item.storefrontURL.isPlaceholderValidationValue || !item.storefrontURL.localizedCaseInsensitiveContains("http") {
      add("Product link", detail: "Add a usable product or retailer URL before seller comparison.", symbol: "link", color: .orange, priority: 14)
    }
    if item.estimatedCost.isPlaceholderValidationValue || item.estimatedCost.localizedCaseInsensitiveContains("pending") {
      add("Cost note", detail: "Record an estimated price, AUD total, or cost note before purchase review.", symbol: "dollarsign.circle", color: .orange, priority: 16)
    }
    if item.owner.isPlaceholderValidationValue || item.pool.isPlaceholderValidationValue {
      add("Owner/pool", detail: "Confirm who wants the item and which local pool/team owns follow-up.", symbol: "person.crop.circle", color: .blue, priority: 18)
    }
    if item.capturedDetail.isPlaceholderValidationValue || item.capturedDetail.localizedCaseInsensitiveContains("placeholder") {
      add("Capture detail", detail: "Add the reason, product notes, or source context for the item.", symbol: "doc.text", color: .blue, priority: 20)
    }
    if options.isEmpty {
      add("Seller options", detail: "Create a local comparison plan or manual seller option before choosing where to buy.", symbol: "chart.bar.doc.horizontal", color: .purple, priority: 30)
    } else if item.preferredOptionID == nil {
      add("Preferred seller", detail: "Score or choose the preferred seller option after checking cost, postage, and trust.", symbol: "checkmark.seal", color: .purple, priority: 32)
    }
    if item.purchaseChecks?.isEmpty != false {
      add("Readiness check", detail: "Run the local purchase readiness check before drafting a purchase decision.", symbol: "checklist.checked", color: .brown, priority: 40)
    }
    if !options.isEmpty && item.purchaseDecision == nil {
      add("Purchase decision", detail: "Draft a local purchase decision once options and readiness are clear.", symbol: "doc.text.magnifyingglass", color: .brown, priority: 42)
    } else if item.purchaseDecision?.reviewState != nil && item.purchaseDecision?.reviewState != .accepted {
      add("Decision review", detail: "Review the local purchase decision before handoff.", symbol: "person.badge.clock", color: .brown, priority: 44)
    }
    if item.purchaseDecision?.reviewState == .accepted && item.purchaseHandoff == nil {
      add("Handoff", detail: "Prepare seller/account/order-watch handoff after the decision is accepted.", symbol: "person.crop.circle.badge.checkmark", color: .teal, priority: 50)
    }
    if item.purchaseHandoff != nil && item.purchaseHandoff?.linkedOrderID == nil {
      add("Order link", detail: "Watch for the confirmation email and link the created order once available.", symbol: "envelope.badge.fill", color: .teal, priority: 52)
    }

    return issues
  }

  private func wishlistDataQualityStage(for item: WishlistItem) -> String {
    if item.purchaseHandoff != nil || item.purchaseDecision?.reviewState == .accepted {
      return "Purchase handoff"
    }
    if item.comparisonOptions?.isEmpty == false {
      return "Comparison quality"
    }
    return "Capture quality"
  }

  private func wishlistDataQualityActionTitle(for item: WishlistItem, firstIssue: WishlistDataQualityIssue?) -> String {
    guard let title = firstIssue?.title else { return "Focus" }
    if ["Item name", "Seller/source", "Product link", "Cost note", "Owner/pool", "Capture detail"].contains(title) { return "Readiness" }
    if title == "Seller options" { return "Compare" }
    if title == "Preferred seller" { return "Score" }
    if title == "Readiness check" { return "Readiness" }
    if title == "Purchase decision" { return "Decision" }
    if title == "Decision review" { return "Decision task" }
    if title == "Handoff" { return "Handoff" }
    if title == "Order link" { return "Order seen" }
    return item.operatorPurchaseBlockers.isEmpty ? "Focus" : "Review"
  }

  private func wishlistDataQualityActionSymbol(for item: WishlistItem, firstIssue: WishlistDataQualityIssue?) -> String {
    guard let title = firstIssue?.title else { return "scope" }
    if ["Item name", "Seller/source", "Product link", "Cost note", "Owner/pool", "Capture detail", "Readiness check"].contains(title) { return "checklist.checked" }
    if title == "Seller options" { return "magnifyingglass.circle" }
    if title == "Preferred seller" { return "chart.bar.doc.horizontal" }
    if title == "Purchase decision" { return "doc.text.magnifyingglass" }
    if title == "Decision review" { return "checklist" }
    if title == "Handoff" { return "person.crop.circle.badge.checkmark" }
    if title == "Order link" { return "envelope.badge.fill" }
    return item.operatorPurchaseBlockers.isEmpty ? "scope" : "arrow.right.circle"
  }

  private func runWishlistDataQualityAction(for entry: WishlistDataQualityEntry) {
    guard let firstIssue = entry.issues.first else { return }
    switch firstIssue.title {
    case "Seller options":
      store.createWishlistComparisonPlan(entry.item)
      store.createWishlistResearchRequest(from: entry.item)
    case "Preferred seller":
      store.evaluateWishlistComparisonOptions(entry.item)
    case "Readiness check", "Item name", "Seller/source", "Product link", "Cost note", "Owner/pool", "Capture detail":
      store.runWishlistPurchaseReadinessCheck(entry.item)
    case "Purchase decision":
      store.createWishlistPurchaseDecision(entry.item)
    case "Decision review":
      store.createWishlistPurchaseDecisionReviewTask(entry.item)
    case "Handoff":
      store.prepareWishlistPurchaseHandoff(entry.item)
    case "Order link":
      store.markWishlistOrderConfirmationSeen(entry.item)
    default:
      wishlistSearchText = entry.item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private func runWishlistDataQualityTask(for entry: WishlistDataQualityEntry) {
    if entry.issues.contains(where: { $0.title == "Handoff" || $0.title == "Order link" }) {
      store.createWishlistPurchaseHandoffReviewTask(entry.item)
    } else if entry.issues.contains(where: { $0.title == "Decision review" || $0.title == "Purchase decision" }) {
      store.createWishlistPurchaseDecisionReviewTask(entry.item)
    } else {
      store.createReviewTask(from: entry.item)
    }
  }

  private var wishlistReadinessPanel: some View {
    let activeItems = store.wishlistItems
    let readyItems = activeItems.filter { $0.status.localizedCaseInsensitiveContains("ready") }
    let reviewItems = activeItems.filter { $0.status.localizedCaseInsensitiveContains("review") }
    let linkedItems = activeItems.filter { $0.status.localizedCaseInsensitiveContains("linked") }
    let placeholderItems = activeItems.filter { item in
      item.storefront.isPlaceholderValidationValue
        || item.estimatedCost.isPlaceholderValidationValue
        || item.capturedDetail.localizedCaseInsensitiveContains("placeholder")
    }
    let itemsNeedingReadiness = uniqueWishlistItems(reviewItems + placeholderItems)

    return SettingsPanel(title: "Wishlist-to-order readiness", symbol: "star.square.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use Wishlist as a local staging area only. Convert to an order when item, storefront, owner, cost, and purchase intent are clear enough to hand off into Orders.")
          .font(.callout)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 135) {
          Badge("\(activeItems.count) active", color: activeItems.isEmpty ? .secondary : .blue)
          Badge("\(readyItems.count) ready", color: readyItems.isEmpty ? .secondary : .green)
          Badge("\(reviewItems.count) needs review", color: reviewItems.isEmpty ? .green : .orange)
          Badge("\(linkedItems.count) linked", color: linkedItems.isEmpty ? .secondary : .teal)
          Badge("\(placeholderItems.count) placeholders", color: placeholderItems.isEmpty ? .green : .orange)
          Badge("\(store.deletedWishlistItems.count) deleted", color: store.deletedWishlistItems.isEmpty ? .secondary : .gray)
        }

        if activeItems.isEmpty {
          MVPEmptyState(
            title: "No active wishlist items",
            detail: "Add a manual item or placeholder capture item to test wishlist-to-order handoff locally.",
            symbol: "star.square.fill"
          )
        } else if reviewItems.isEmpty && placeholderItems.isEmpty {
          Label("Active wishlist items look ready for local linking or order conversion.", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
        } else {
          VStack(alignment: .leading, spacing: 8) {
            Text("Review before converting")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            ForEach(Array(itemsNeedingReadiness.prefix(4))) { item in
              WishlistReadinessRow(item: item)
            }
            let remaining = max(itemsNeedingReadiness.count - 4, 0)
            if remaining > 0 {
              Text("\(remaining) more wishlist items need review before conversion.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
    }
  }

  private var wishlistPipelineBoardPanel: some View {
    let items = wishlistPipelineItems
    let capture = items.filter { $0.stage == "Capture" }.count
    let compare = items.filter { $0.stage == "Compare" }.count
    let decide = items.filter { $0.stage == "Decide" }.count
    let handoff = items.filter { $0.stage == "Handoff" }.count
    let orderWatch = items.filter { $0.stage == "Order watch" }.count
    let linked = items.filter { $0.stage == "Linked order" }.count

    return SettingsPanel(title: "Wishlist purchase pipeline", symbol: "rectangle.stack.badge.person.crop.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("This board shows the daily operator path from idea capture to seller comparison, purchase decision, handoff, order-confirmation watch, and linked order. It is local workflow tracking only; it does not search retailers, buy items, access accounts, or monitor mail in the background.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Capture", "\(capture)", capture == 0 ? .secondary : .blue),
          ("Compare", "\(compare)", compare == 0 ? .secondary : .orange),
          ("Decide", "\(decide)", decide == 0 ? .secondary : .brown),
          ("Handoff", "\(handoff)", handoff == 0 ? .secondary : .purple),
          ("Order watch", "\(orderWatch)", orderWatch == 0 ? .secondary : .green),
          ("Linked", "\(linked)", linked == 0 ? .secondary : .teal)
        ])

        if items.isEmpty {
          MVPEmptyState(
            title: "No Wishlist pipeline items",
            detail: "Add a manual item or capture placeholder to start the local Wishlist workflow.",
            symbol: "star.square.fill",
            actionTitle: "Manual item",
            action: store.addManualWishlistItemPlaceholder
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 360), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(items.prefix(8)) { pipelineItem in
              WishlistPipelineRow(pipelineItem: pipelineItem) {
                runWishlistPipelineAction(for: pipelineItem.item)
              } onFocus: {
                wishlistSearchText = pipelineItem.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(items.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more Wishlist pipeline item\(remaining == 1 ? "" : "s") are available in the detailed list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private func wishlistPipelineItem(for item: WishlistItem) -> WishlistPipelineItem {
    let options = item.comparisonOptions ?? []
    let blockers = item.operatorPurchaseBlockers
    let linkedOrder = item.purchaseHandoff?.linkedOrderID != nil
    let gate = wishlistPurchaseReleaseGate(for: item)

    if linkedOrder {
      return WishlistPipelineItem(
        item: item,
        stage: "Linked order",
        detail: "A local order is linked. Continue work from Orders, Dispatch, Tasks, and Audit.",
        nextAction: "Focus item",
        symbol: "link.circle.fill",
        tone: .teal,
        sortPriority: 60
      )
    }

    if item.purchaseHandoff != nil {
      let matches = store.suggestedWishlistOrderConfirmations(for: item).count
      return WishlistPipelineItem(
        item: item,
        stage: "Order watch",
        detail: matches > 0 ? "\(matches) imported Inbox confirmation match\(matches == 1 ? "" : "es") need linking." : "Manual purchase handoff is ready; wait for or import the order confirmation.",
        nextAction: matches > 0 ? "Use confirmation" : "Order seen",
        symbol: "envelope.badge.fill",
        tone: matches > 0 ? .green : .orange,
        sortPriority: matches > 0 ? 10 : 50
      )
    }

    if item.purchaseDecision?.reviewState == .accepted {
      return WishlistPipelineItem(
        item: item,
        stage: "Handoff",
        detail: "Purchase decision is accepted. Prepare account, seller, and expected order-confirmation handoff.",
        nextAction: "Prepare handoff",
        symbol: "person.crop.circle.badge.checkmark",
        tone: .purple,
        sortPriority: 20
      )
    }

    if item.purchaseDecision != nil {
      return WishlistPipelineItem(
        item: item,
        stage: "Decide",
        detail: "Purchase decision exists but still needs local review before handoff.",
        nextAction: "Review decision",
        symbol: "checkmark.seal",
        tone: .brown,
        sortPriority: 30
      )
    }

    if !options.isEmpty {
      let firstBlocker = blockers.first ?? gate.detail
      let needsDecision = blockers.contains { $0.localizedCaseInsensitiveContains("decision") }
      return WishlistPipelineItem(
        item: item,
        stage: needsDecision ? "Decide" : "Compare",
        detail: firstBlocker,
        nextAction: gate.actionTitle,
        symbol: needsDecision ? "doc.text.magnifyingglass" : "chart.bar.doc.horizontal",
        tone: needsDecision ? .brown : .orange,
        sortPriority: needsDecision ? 35 : 40
      )
    }

    return WishlistPipelineItem(
      item: item,
      stage: "Capture",
      detail: item.capturedDetail.isPlaceholderValidationValue ? "Confirm item details, seller link, owner, and purchase intent." : "Create seller options or a comparison research request before purchase review.",
      nextAction: "Compare",
      symbol: "square.and.arrow.down.fill",
      tone: .blue,
      sortPriority: 45
    )
  }

  private func runWishlistPipelineAction(for item: WishlistItem) {
    let pipelineItem = wishlistPipelineItem(for: item)
    if pipelineItem.stage == "Capture" {
      store.createWishlistComparisonPlan(item)
      store.createWishlistResearchRequest(from: item)
    } else if pipelineItem.stage == "Order watch", store.suggestedWishlistOrderConfirmations(for: item).first != nil {
      if let email = store.suggestedWishlistOrderConfirmations(for: item).first {
        store.confirmWishlistOrderFromIntake(item, email: email)
      }
    } else if pipelineItem.stage == "Linked order" {
      wishlistSearchText = item.itemName
      selectedSource = nil
      selectedStatus = nil
    } else {
      runWishlistPurchaseReleaseAction(for: item)
    }
  }

  private var wishlistPurchaseBlockerQueuePanel: some View {
    let blockerItems = wishlistPurchaseBlockerQueueItems

    return SettingsPanel(title: "Purchase blocker queue", symbol: "exclamationmark.triangle.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this queue to clear Wishlist purchase blockers without opening every item. Actions are local only and do not buy, scrape, log in, quote postage, or contact retailers.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Blocked items", "\(blockerItems.count)", blockerItems.isEmpty ? .green : .orange),
          ("Seller evidence", "\(blockerItems.filter { $0.operatorPurchaseBlockers.contains { $0.localizedCaseInsensitiveContains("confirm") } }.count)", .orange),
          ("Decision", "\(blockerItems.filter { $0.operatorPurchaseBlockers.contains { $0.localizedCaseInsensitiveContains("decision") } }.count)", .brown),
          ("Handoff", "\(blockerItems.filter { $0.operatorPurchaseBlockers.contains { $0.localizedCaseInsensitiveContains("handoff") || $0.localizedCaseInsensitiveContains("link order") } }.count)", .purple)
        ])

        if blockerItems.isEmpty {
          Label("No Wishlist purchase blockers are currently promoted. Use the detailed item rows for normal comparison and capture work.", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
        } else {
          ForEach(blockerItems.prefix(5)) { item in
            WishlistPurchaseBlockerQueueRow(
              item: item,
              actionTitle: wishlistBlockerActionTitle(for: item),
              actionSymbol: wishlistBlockerActionSymbol(for: item)
            ) {
              wishlistSearchText = item.itemName
              selectedSource = nil
              selectedStatus = nil
            } onAction: {
              runWishlistBlockerAction(for: item)
            }
          }

          let remaining = max(blockerItems.count - 5, 0)
          if remaining > 0 {
            Text("\(remaining) more blocked Wishlist item\(remaining == 1 ? "" : "s") are in the detailed list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private func wishlistBlockerActionTitle(for item: WishlistItem) -> String {
    guard let blocker = item.operatorPurchaseBlockers.first else { return "Review" }
    if blocker.localizedCaseInsensitiveContains("add seller") { return "Compare" }
    if blocker.localizedCaseInsensitiveContains("choose preferred") { return "Score" }
    if blocker.localizedCaseInsensitiveContains("confirm") { return "Evidence task" }
    if blocker.localizedCaseInsensitiveContains("readiness") { return "Readiness" }
    if blocker.localizedCaseInsensitiveContains("draft purchase") { return "Decision" }
    if blocker.localizedCaseInsensitiveContains("review purchase") { return "Decision task" }
    if blocker.localizedCaseInsensitiveContains("prepare handoff") { return "Handoff" }
    if blocker.localizedCaseInsensitiveContains("link order") { return "Order seen" }
    return "Review"
  }

  private func wishlistBlockerActionSymbol(for item: WishlistItem) -> String {
    guard let blocker = item.operatorPurchaseBlockers.first else { return "arrow.right.circle" }
    if blocker.localizedCaseInsensitiveContains("add seller") { return "magnifyingglass.circle" }
    if blocker.localizedCaseInsensitiveContains("choose preferred") { return "chart.bar.doc.horizontal" }
    if blocker.localizedCaseInsensitiveContains("confirm") { return "checklist" }
    if blocker.localizedCaseInsensitiveContains("readiness") { return "checklist.checked" }
    if blocker.localizedCaseInsensitiveContains("decision") { return "doc.text.magnifyingglass" }
    if blocker.localizedCaseInsensitiveContains("handoff") { return "person.crop.circle.badge.checkmark" }
    if blocker.localizedCaseInsensitiveContains("link order") { return "envelope.badge.fill" }
    return "arrow.right.circle"
  }

  private func runWishlistBlockerAction(for item: WishlistItem) {
    guard let blocker = item.operatorPurchaseBlockers.first else {
      wishlistSearchText = item.itemName
      selectedSource = nil
      selectedStatus = nil
      return
    }

    if blocker.localizedCaseInsensitiveContains("add seller") {
      store.createWishlistComparisonPlan(item)
      store.createWishlistResearchRequest(from: item)
    } else if blocker.localizedCaseInsensitiveContains("choose preferred") {
      store.evaluateWishlistComparisonOptions(item)
    } else if blocker.localizedCaseInsensitiveContains("confirm") {
      store.createWishlistSellerEvidenceReviewTask(item)
    } else if blocker.localizedCaseInsensitiveContains("readiness") {
      store.runWishlistPurchaseReadinessCheck(item)
    } else if blocker.localizedCaseInsensitiveContains("draft purchase") {
      store.createWishlistPurchaseDecision(item)
    } else if blocker.localizedCaseInsensitiveContains("review purchase") {
      store.createWishlistPurchaseDecisionReviewTask(item)
    } else if blocker.localizedCaseInsensitiveContains("prepare handoff") {
      store.prepareWishlistPurchaseHandoff(item)
    } else if blocker.localizedCaseInsensitiveContains("link order") {
      store.markWishlistOrderConfirmationSeen(item)
    } else {
      wishlistSearchText = item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private var wishlistComparisonPlanningPanel: some View {
    let activeItems = store.wishlistItems
    let comparedItems = activeItems.filter { !($0.comparisonOptions ?? []).isEmpty }
    let purchaseReadyItems = activeItems.filter {
      $0.status.localizedCaseInsensitiveContains("ready to purchase")
        || ($0.purchaseReadiness ?? "").localizedCaseInsensitiveContains("ready")
    }
    let trustReviewItems = activeItems.filter {
      ($0.comparisonOptions ?? []).contains { option in
        option.trustRating.localizedCaseInsensitiveContains("unknown")
          || option.trustRating.localizedCaseInsensitiveContains("review")
      }
    }

    return SettingsPanel(title: "Purchase comparison planning", symbol: "magnifyingglass.circle.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this as the local planning boundary for the future shopping agent. A real agent should compare Australian and overseas sellers, convert totals to AUD, include postage costs and delivery times, and reject low-trust sellers before a human buys anything.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Wishlist", "\(activeItems.count)", activeItems.isEmpty ? .secondary : .blue),
          ("Compared", "\(comparedItems.count)", comparedItems.isEmpty ? .secondary : .teal),
          ("Ready", "\(purchaseReadyItems.count)", purchaseReadyItems.isEmpty ? .secondary : .green),
          ("Trust review", "\(trustReviewItems.count)", trustReviewItems.isEmpty ? .green : .orange)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 190 : 240), spacing: 10)], alignment: .leading, spacing: 10) {
          WishlistPlanningStep(number: "1", title: "Capture item", detail: "Manual entry, share sheet, screenshot, PDF, or future browser extension records item and source URL locally.")
          WishlistPlanningStep(number: "2", title: "Compare sellers", detail: "Future agent should check AU and overseas retailers, AUD landed cost, postage, delivery time, returns, and warranty.")
          WishlistPlanningStep(number: "3", title: "Trust filter", detail: "Seller trust must beat price. Low-trust or unknown sellers should stay blocked until reviewed.")
          WishlistPlanningStep(number: "4", title: "Purchase handoff", detail: "Only after a seller is selected should the item become ready to purchase or convert to a local order draft.")
        }

        Text("Not active yet: live web search, retailer scraping, currency feeds, postage quote APIs, browser extension capture, account detection, checkout automation, purchase monitoring, and payment handling.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistSellerOptionReviewPanel: some View {
    let issues = wishlistSellerOptionIssues
    let readyOptions = wishlistReadySellerOptions
    let totalOptions = store.wishlistItems.reduce(0) { count, item in
      count + (item.comparisonOptions?.count ?? 0)
    }
    let missingAUD = issues.filter { $0.kind == "AUD total" }.count
    let missingPostage = issues.filter { $0.kind == "Postage" }.count
    let trustReview = issues.filter { $0.kind == "Trust" }.count

    return SettingsPanel(title: "Seller option review", symbol: "storefront.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this to clean up manual seller options before purchase handoff. Each option should have a real product link, total AUD cost, postage cost/time, and explicit seller trust notes before it becomes the preferred purchase route.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Options", "\(totalOptions)", totalOptions == 0 ? .secondary : .blue),
          ("Missing AUD", "\(missingAUD)", missingAUD == 0 ? .green : .orange),
          ("Postage gaps", "\(missingPostage)", missingPostage == 0 ? .green : .orange),
          ("Trust review", "\(trustReview)", trustReview == 0 ? .green : .red),
          ("Ready-looking", "\(readyOptions.count)", readyOptions.isEmpty ? .secondary : .green)
        ])

        if totalOptions == 0 {
          MVPEmptyState(
            title: "No seller options yet",
            detail: "Add a seller option or create a comparison plan on a Wishlist item before scoring and purchase handoff.",
            symbol: "storefront.fill"
          )
        } else {
          if issues.isEmpty {
            Label("No obvious seller option gaps. Run local scoring and confirm live prices before buying externally.", systemImage: "checkmark.seal.fill")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.green)
          } else {
            VStack(alignment: .leading, spacing: 8) {
              Text("Needs cleanup")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
              ForEach(Array(issues.prefix(6))) { issue in
                WishlistSellerOptionIssueRow(issue: issue)
              }
              let remaining = max(issues.count - 6, 0)
              if remaining > 0 {
                Text("\(remaining) more seller option issue\(remaining == 1 ? "" : "s") need review.")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
          }

          if !readyOptions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Text("Ready-looking local candidates")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
              ForEach(Array(readyOptions.prefix(4))) { candidate in
                WishlistSellerOptionIssueRow(issue: candidate)
              }
            }
          }
        }

        Text("This panel is local guidance only. It does not verify live retailer prices, exchange rates, postage, delivery times, seller reviews, account access, checkout state, or payment readiness.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistSellerOptionIssues: [WishlistSellerOptionIssue] {
    store.wishlistItems.flatMap { item in
      (item.comparisonOptions ?? []).flatMap { option -> [WishlistSellerOptionIssue] in
        var issues: [WishlistSellerOptionIssue] = []
        let audText = option.estimatedAUDTotal.trimmingCharacters(in: .whitespacesAndNewlines)
        let postageText = "\(option.postageCost) \(option.postageTime)".localizedLowercase
        let trustText = option.trustRating.localizedLowercase

        if audText.isEmpty || audText.localizedCaseInsensitiveContains("pending") || !audText.localizedCaseInsensitiveContains("aud") {
          issues.append(WishlistSellerOptionIssue(
            item: item,
            option: option,
            kind: "AUD total",
            title: "AUD total missing",
            detail: "Record total landed AUD cost including item, currency conversion, postage, and likely fees.",
            symbol: "dollarsign.circle.fill",
            color: .orange
          ))
        }

        if postageText.contains("pending") || option.postageCost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || option.postageTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          issues.append(WishlistSellerOptionIssue(
            item: item,
            option: option,
            kind: "Postage",
            title: "Postage details missing",
            detail: "Add postage cost and estimated delivery time before choosing this seller.",
            symbol: "shippingbox.fill",
            color: .orange
          ))
        }

        if trustText.contains("unknown") || trustText.contains("review") || trustText.contains("needs") {
          issues.append(WishlistSellerOptionIssue(
            item: item,
            option: option,
            kind: "Trust",
            title: "Seller trust needs review",
            detail: "Confirm seller reputation, returns, warranty, contact details, and delivery evidence before purchase.",
            symbol: "exclamationmark.shield.fill",
            color: .red
          ))
        }

        return issues
      }
    }
  }

  private var wishlistReadySellerOptions: [WishlistSellerOptionIssue] {
    store.wishlistItems.flatMap { item in
      (item.comparisonOptions ?? []).compactMap { option in
        let searchable = [
          option.estimatedAUDTotal,
          option.postageCost,
          option.postageTime,
          option.trustRating,
          option.trustNotes
        ].joined(separator: " ").localizedLowercase
        let hasAUD = searchable.contains("aud") && !searchable.contains("pending aud")
        let hasPostage = !option.postageCost.localizedCaseInsensitiveContains("pending")
          && !option.postageTime.localizedCaseInsensitiveContains("pending")
        let trusted = option.trustRating.localizedCaseInsensitiveContains("trusted")
          || option.trustRating.localizedCaseInsensitiveContains("high")
          || option.trustRating.localizedCaseInsensitiveContains("accepted")
        guard hasAUD && hasPostage && trusted else { return nil }
        return WishlistSellerOptionIssue(
          item: item,
          option: option,
          kind: "Ready",
          title: "Ready-looking seller option",
          detail: "Local fields look complete. Still confirm live price, stock, postage, returns, and account/payment details before buying externally.",
          symbol: "checkmark.seal.fill",
          color: .green
        )
      }
    }
  }

  private var wishlistSellerSafetyRubricEntries: [WishlistSellerSafetyRubricEntry] {
    store.wishlistItems.flatMap { item in
      (item.comparisonOptions ?? []).map { option in
        wishlistSellerSafetyRubricEntry(item: item, option: option)
      }
    }
    .sorted { first, second in
      if first.sortPriority == second.sortPriority {
        return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
      }
      return first.sortPriority < second.sortPriority
    }
  }

  private var wishlistSellerSafetyRubricPanel: some View {
    let entries = wishlistSellerSafetyRubricEntries
    let ready = entries.filter { $0.decision == "Acceptable local candidate" }.count
    let caution = entries.filter { $0.decision == "Caution" }.count
    let reject = entries.filter { $0.decision == "Reject or manual review" }.count
    let preferredNeedsReview = entries.filter { $0.isPreferred && $0.decision != "Acceptable local candidate" }.count

    return SettingsPanel(title: "Seller trust and landed-cost rubric", symbol: "shield.lefthalf.filled") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this local rubric before purchase handoff. Cheap sellers are not considered safe until total AUD cost, postage time, returns/warranty, and seller trust evidence are explicit.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Acceptable", "\(ready)", ready == 0 ? .secondary : .green),
          ("Caution", "\(caution)", caution == 0 ? .green : .orange),
          ("Reject/review", "\(reject)", reject == 0 ? .green : .red),
          ("Preferred review", "\(preferredNeedsReview)", preferredNeedsReview == 0 ? .green : .purple)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No seller options to score",
            detail: "Create a comparison plan or add manual seller options before using the trust and landed-cost rubric.",
            symbol: "shield.lefthalf.filled"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 380), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              WishlistSellerSafetyRubricRow(entry: entry) {
                runWishlistSellerSafetyAction(for: entry)
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more seller option\(remaining == 1 ? "" : "s") are available in detailed Wishlist rows.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Rubric scoring is local only. ParcelOps does not verify live stock, real-time prices, exchange rates, postage quotes, independent reviews, or seller identity.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistSellerSafetyRubricEntry(item: WishlistItem, option: WishlistComparisonOption) -> WishlistSellerSafetyRubricEntry {
    let gaps = option.operatorSellerEvidenceGaps
    let score = option.operatorSellerMatrixScore
    let trust = option.trustRating.localizedLowercase
    let recommendation = option.recommendation.localizedLowercase
    let hasAUD = option.estimatedAUDTotal.localizedCaseInsensitiveContains("aud")
      && !option.estimatedAUDTotal.localizedCaseInsensitiveContains("pending")
    let hasPostage = !option.postageCost.localizedCaseInsensitiveContains("pending")
      && !option.postageTime.localizedCaseInsensitiveContains("pending")
    let trustLooksGood = trust.contains("trusted")
      || trust.contains("high")
      || trust.contains("accepted")
    let trustLooksWeak = trust.contains("unknown")
      || trust.contains("review")
      || trust.contains("needs")
      || recommendation.contains("avoid")
      || recommendation.contains("reject")
    let isPreferred = item.preferredOptionID == option.id

    let decision: String
    let detail: String
    let tone: Color
    let sortPriority: Int

    if gaps.isEmpty && score >= 70 && trustLooksGood && hasAUD && hasPostage {
      decision = "Acceptable local candidate"
      detail = "Local fields are complete enough for manual live verification before purchase."
      tone = .green
      sortPriority = isPreferred ? 20 : 40
    } else if score < 55 || trustLooksWeak || gaps.contains("seller trust") {
      decision = "Reject or manual review"
      detail = "Do not prefer this seller until trust evidence, delivery reliability, and returns/warranty are manually confirmed."
      tone = .red
      sortPriority = isPreferred ? 1 : 10
    } else {
      decision = "Caution"
      detail = gaps.isEmpty ? "Local score is moderate. Reconfirm live price, postage, and seller trust before purchase." : "Missing \(gaps.prefix(3).joined(separator: ", "))."
      tone = .orange
      sortPriority = isPreferred ? 5 : 30
    }

    return WishlistSellerSafetyRubricEntry(
      item: item,
      option: option,
      isPreferred: isPreferred,
      decision: decision,
      detail: detail,
      gaps: gaps,
      tone: tone,
      sortPriority: sortPriority
    )
  }

  private func runWishlistSellerSafetyAction(for entry: WishlistSellerSafetyRubricEntry) {
    if entry.gaps.isEmpty && entry.decision == "Acceptable local candidate" {
      store.runWishlistPurchaseReadinessCheck(entry.item)
    } else if entry.gaps.contains("seller trust") || entry.decision == "Reject or manual review" {
      store.createWishlistSellerEvidenceReviewTask(entry.item)
    } else {
      store.evaluateWishlistComparisonOptions(entry.item)
    }
  }

  private var wishlistComparisonMatrixEntries: [WishlistComparisonMatrixEntry] {
    store.wishlistItems.flatMap { item in
      (item.comparisonOptions ?? []).map { option in
        WishlistComparisonMatrixEntry(
          item: item,
          option: option,
          isPreferred: item.preferredOptionID == option.id
        )
      }
    }
    .sorted { first, second in
      if first.isPreferred != second.isPreferred {
        return first.isPreferred
      }
      if first.option.operatorSellerMatrixScore == second.option.operatorSellerMatrixScore {
        return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
      }
      return first.option.operatorSellerMatrixScore > second.option.operatorSellerMatrixScore
    }
  }

  private var wishlistComparisonMatrixPanel: some View {
    let entries = wishlistComparisonMatrixEntries
    let readyCount = entries.filter { $0.option.operatorSellerEvidenceGaps.isEmpty && $0.option.operatorSellerMatrixScore >= 70 }.count
    let highRiskCount = entries.filter { $0.option.operatorSellerMatrixScore < 55 || $0.option.operatorSellerMatrixRisk.localizedCaseInsensitiveContains("high") }.count
    let gapCount = entries.filter { !$0.option.operatorSellerEvidenceGaps.isEmpty }.count

    return SettingsPanel(title: "Seller comparison matrix", symbol: "tablecells.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Compare manual seller options in one place before purchase handoff. Scores are local guidance only and must be checked against live price, AUD landed cost, postage, delivery time, seller trust, returns, and account readiness before buying.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Options", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Ready-looking", "\(readyCount)", readyCount == 0 ? .secondary : .green),
          ("Evidence gaps", "\(gapCount)", gapCount == 0 ? .green : .orange),
          ("High risk", "\(highRiskCount)", highRiskCount == 0 ? .green : .red)
        ])

        CompactActionRow {
          Button("Score all options", systemImage: "chart.bar.doc.horizontal") {
            scoreAllWishlistOptions()
          }
          .disabled(entries.isEmpty)
          Button("Show gaps", systemImage: "exclamationmark.triangle.fill") {
            wishlistSearchText = ""
            selectedSource = nil
            selectedStatus = nil
          }
          .disabled(gapCount == 0)
        }
        .buttonStyle(.bordered)

        if entries.isEmpty {
          MVPEmptyState(
            title: "No seller options to compare",
            detail: "Add seller options to Wishlist items before using the comparison matrix. Nothing here performs live retailer search, scraping, currency conversion, or postage lookup.",
            symbol: "tablecells.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 240 : 340), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(12)) { entry in
              WishlistComparisonMatrixRow(entry: entry) {
                store.markWishlistPreferredOption(entry.item, option: entry.option)
              } onScore: {
                store.evaluateWishlistComparisonOptions(entry.item)
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 12, 0)
          if remaining > 0 {
            Text("\(remaining) more seller option\(remaining == 1 ? "" : "s") are available in the detailed Wishlist item rows below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Matrix scoring is local only. ParcelOps has not checked stock, current price, exchange rates, postage quote, seller reviews, checkout, payment, or account login.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func scoreAllWishlistOptions() {
    let itemsWithOptions = store.wishlistItems.filter { !($0.comparisonOptions ?? []).isEmpty }
    for item in itemsWithOptions {
      store.evaluateWishlistComparisonOptions(item)
    }
  }

  private var wishlistLandedCostReviewEntries: [WishlistLandedCostReviewEntry] {
    store.wishlistItems.flatMap { item in
      let options = item.comparisonOptions ?? []
      let cheapestID = options
        .compactMap { option -> (UUID, Double)? in
          guard let audValue = wishlistAUDValue(option.estimatedAUDTotal) else { return nil }
          return (option.id, audValue)
        }
        .min { $0.1 < $1.1 }?.0
      let safestID = options
        .max { first, second in
          first.operatorSellerMatrixScore < second.operatorSellerMatrixScore
        }?.id
      let fastestID = options
        .compactMap { option -> (UUID, Int)? in
          guard let days = wishlistPostageDays(option.postageTime) else { return nil }
          return (option.id, days)
        }
        .min { $0.1 < $1.1 }?.0

      return options.map { option in
        wishlistLandedCostReviewEntry(
          item: item,
          option: option,
          isPreferred: item.preferredOptionID == option.id,
          isCheapest: cheapestID == option.id,
          isSafest: safestID == option.id,
          isFastest: fastestID == option.id
        )
      }
    }
    .sorted { first, second in
      if first.sortPriority == second.sortPriority {
        if first.item.itemName == second.item.itemName {
          return first.option.sellerName.localizedCaseInsensitiveCompare(second.option.sellerName) == .orderedAscending
        }
        return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
      }
      return first.sortPriority < second.sortPriority
    }
  }

  private var wishlistLandedCostReviewPanel: some View {
    let entries = wishlistLandedCostReviewEntries
    let preferred = entries.filter(\.isPreferred).count
    let cheapest = entries.filter(\.isCheapest).count
    let safest = entries.filter(\.isSafest).count
    let blocked = entries.filter { !$0.blockers.isEmpty || $0.tone == .red }.count

    return SettingsPanel(title: "Landed-cost option review", symbol: "dollarsign.arrow.circlepath") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Review seller options as purchase candidates, not just rows of data. This highlights cheapest, safest, fastest-looking, preferred, and blocked options using local fields only.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Options", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Preferred", "\(preferred)", preferred == 0 ? .secondary : .purple),
          ("Cheapest", "\(cheapest)", cheapest == 0 ? .secondary : .green),
          ("Safest", "\(safest)", safest == 0 ? .secondary : .teal),
          ("Blocked", "\(blocked)", blocked == 0 ? .green : .red)
        ])

        CompactActionRow {
          Button("Score all", systemImage: "chart.bar.doc.horizontal") {
            scoreAllWishlistOptions()
          }
          .disabled(entries.isEmpty)
          Button("Show risky", systemImage: "exclamationmark.triangle.fill") {
            wishlistSearchText = ""
            selectedSource = nil
            selectedStatus = nil
          }
          .disabled(blocked == 0)
        }
        .buttonStyle(.bordered)

        if entries.isEmpty {
          MVPEmptyState(
            title: "No landed-cost options to review",
            detail: "Add manual seller options or create a comparison plan before reviewing landed cost, postage, and trust tradeoffs.",
            symbol: "dollarsign.arrow.circlepath"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 390), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(10)) { entry in
              WishlistLandedCostReviewRow(entry: entry) {
                store.markWishlistPreferredOption(entry.item, option: entry.option)
              } onScore: {
                store.evaluateWishlistComparisonOptions(entry.item)
              } onEvidenceTask: {
                store.createWishlistSellerEvidenceReviewTask(entry.item)
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 10, 0)
          if remaining > 0 {
            Text("\(remaining) more landed-cost option\(remaining == 1 ? "" : "s") are available in the detailed Wishlist list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("This review does not perform live retailer search, exchange-rate conversion, postage quote lookup, review scraping, account login, checkout, or payment.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistLandedCostReviewEntry(
    item: WishlistItem,
    option: WishlistComparisonOption,
    isPreferred: Bool,
    isCheapest: Bool,
    isSafest: Bool,
    isFastest: Bool
  ) -> WishlistLandedCostReviewEntry {
    var badges: [String] = []
    if isPreferred { badges.append("Preferred") }
    if isCheapest { badges.append("Cheapest") }
    if isSafest { badges.append("Safest") }
    if isFastest { badges.append("Fastest") }

    let gaps = option.operatorSellerEvidenceGaps
    var blockers: [String] = gaps
    if wishlistAUDValue(option.estimatedAUDTotal) == nil {
      blockers.append("AUD total")
    }
    if wishlistPostageDays(option.postageTime) == nil && option.postageTime.localizedCaseInsensitiveContains("pending") {
      blockers.append("postage time")
    }
    if option.trustRating.localizedCaseInsensitiveContains("unknown") || option.trustRating.localizedCaseInsensitiveContains("review") {
      blockers.append("seller trust")
    }

    let tone: Color
    let recommendation: String
    let sortPriority: Int
    if isPreferred && blockers.isEmpty {
      tone = .green
      recommendation = "Preferred option looks locally complete. Reconfirm live stock, price, postage, returns, and account/payment readiness before buying."
      sortPriority = 5
    } else if blockers.contains("seller trust") || option.operatorSellerMatrixScore < 55 {
      tone = .red
      recommendation = "Do not buy from this seller until trust, returns, warranty, and delivery reliability are manually confirmed."
      sortPriority = isPreferred ? 1 : 20
    } else if !blockers.isEmpty {
      tone = .orange
      recommendation = "Fill \(Array(Set(blockers)).prefix(3).joined(separator: ", ")) before this can become a preferred purchase option."
      sortPriority = isPreferred ? 2 : 30
    } else if isCheapest && !isSafest {
      tone = .orange
      recommendation = "Cheapest is not automatically best. Compare trust, postage time, returns, and warranty before preferring it."
      sortPriority = 35
    } else {
      tone = .teal
      recommendation = "Candidate is usable for decision review once live seller details are manually checked."
      sortPriority = isSafest ? 10 : 40
    }

    return WishlistLandedCostReviewEntry(
      item: item,
      option: option,
      badges: badges,
      blockers: Array(Set(blockers)).sorted(),
      recommendation: recommendation,
      tone: tone,
      sortPriority: sortPriority
    )
  }

  private func wishlistAUDValue(_ value: String) -> Double? {
    let filtered = value.replacingOccurrences(of: ",", with: "")
    let match = filtered.firstMatch(of: /[0-9]+(\.[0-9]+)?/)
    guard let text = match.map({ String($0.output.0) }) else { return nil }
    return Double(text)
  }

  private func wishlistPostageDays(_ value: String) -> Int? {
    let lower = value.localizedLowercase
    if lower.contains("same day") { return 0 }
    if lower.contains("overnight") { return 1 }
    if let match = lower.firstMatch(of: /[0-9]+/) {
      return Int(String(match.output))
    }
    return nil
  }

  private var wishlistPurchaseDecisionQueueItems: [WishlistItem] {
    store.wishlistItems
      .filter { item in
        !(item.comparisonOptions ?? []).isEmpty
          || item.purchaseDecision != nil
          || item.purchaseHandoff != nil
          || item.status.localizedCaseInsensitiveContains("purchase")
      }
      .sorted { first, second in
        let firstPriority = wishlistPurchaseDecisionPriority(for: first)
        let secondPriority = wishlistPurchaseDecisionPriority(for: second)
        if firstPriority == secondPriority {
          return first.itemName.localizedCaseInsensitiveCompare(second.itemName) == .orderedAscending
        }
        return firstPriority < secondPriority
      }
  }

  private var wishlistPurchaseDecisionQueuePanel: some View {
    let queueItems = wishlistPurchaseDecisionQueueItems
    let decisionNeeded = queueItems.filter { $0.purchaseDecision == nil }.count
    let reviewNeeded = queueItems.filter { $0.purchaseDecision?.reviewState == .needsReview }.count
    let handoffNeeded = queueItems.filter { $0.purchaseDecision?.reviewState == .accepted && $0.purchaseHandoff == nil }.count
    let orderWatch = queueItems.filter { $0.purchaseHandoff?.linkedOrderID == nil && $0.purchaseHandoff != nil }.count

    return SettingsPanel(title: "Purchase decision queue", symbol: "bag.badge.questionmark.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this queue after seller options exist. It keeps the local path explicit: score sellers, run readiness, draft/review a purchase decision, prepare handoff, then watch for the order confirmation.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("In queue", "\(queueItems.count)", queueItems.isEmpty ? .secondary : .blue),
          ("Need decision", "\(decisionNeeded)", decisionNeeded == 0 ? .green : .orange),
          ("Need review", "\(reviewNeeded)", reviewNeeded == 0 ? .green : .brown),
          ("Need handoff", "\(handoffNeeded)", handoffNeeded == 0 ? .green : .purple),
          ("Order watch", "\(orderWatch)", orderWatch == 0 ? .secondary : .teal)
        ])

        if queueItems.isEmpty {
          MVPEmptyState(
            title: "No Wishlist purchases are in decision flow",
            detail: "Add seller options to a Wishlist item before purchase readiness, decision, and handoff work appears here.",
            symbol: "bag.badge.questionmark.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 240 : 360), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(queueItems.prefix(8)) { item in
              WishlistPurchaseDecisionQueueRow(
                item: item,
                stageTitle: wishlistPurchaseDecisionStageTitle(for: item),
                stageDetail: wishlistPurchaseDecisionStageDetail(for: item),
                stageColor: wishlistPurchaseDecisionStageColor(for: item),
                actionTitle: wishlistPurchaseDecisionActionTitle(for: item),
                actionSymbol: wishlistPurchaseDecisionActionSymbol(for: item)
              ) {
                runWishlistPurchaseDecisionAction(for: item)
              } onFocus: {
                wishlistSearchText = item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(queueItems.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more Wishlist purchase item\(remaining == 1 ? "" : "s") are in the detailed list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("This queue does not buy anything. It only records local review, handoff, account, budget, and order-watch readiness before a human purchases externally.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistPurchaseDecisionPriority(for item: WishlistItem) -> Int {
    if (item.comparisonOptions ?? []).isEmpty { return 0 }
    if item.preferredOptionID == nil { return 1 }
    if (item.comparisonOptions ?? []).contains(where: { !$0.operatorSellerEvidenceGaps.isEmpty }) { return 2 }
    let checks = item.purchaseChecks ?? []
    if checks.isEmpty || checks.contains(where: { $0.status != "Passed" }) { return 3 }
    if item.purchaseDecision == nil { return 4 }
    if item.purchaseDecision?.reviewState != .accepted { return 5 }
    if item.purchaseHandoff == nil { return 6 }
    if item.purchaseHandoff?.linkedOrderID == nil { return 7 }
    return 8
  }

  private func wishlistPurchaseDecisionStageTitle(for item: WishlistItem) -> String {
    switch wishlistPurchaseDecisionPriority(for: item) {
    case 0: return "Seller options needed"
    case 1: return "Preferred seller needed"
    case 2: return "Seller evidence gaps"
    case 3: return "Readiness check needed"
    case 4: return "Purchase decision needed"
    case 5: return "Decision review needed"
    case 6: return "Purchase handoff needed"
    case 7: return "Order confirmation watch"
    default: return "Linked order ready"
    }
  }

  private func wishlistPurchaseDecisionStageDetail(for item: WishlistItem) -> String {
    let preferred = item.preferredOptionID.flatMap { preferredID in
      item.comparisonOptions?.first { $0.id == preferredID }
    }
    switch wishlistPurchaseDecisionPriority(for: item) {
    case 0:
      return "Create local seller options or a research brief before comparing purchase routes."
    case 1:
      return "Run local scoring or choose the preferred seller option."
    case 2:
      let gaps = (item.comparisonOptions ?? []).flatMap(\.operatorSellerEvidenceGaps)
      return "Confirm \(Array(Set(gaps)).prefix(3).joined(separator: ", ")) before buying."
    case 3:
      return "Run the local readiness checklist for \(preferred?.sellerName ?? "the preferred seller")."
    case 4:
      return "Draft the purchase decision with seller, AUD total, postage, trust, and rejected options."
    case 5:
      return "Review and accept the local decision before preparing handoff."
    case 6:
      return "Prepare account/order-watch handoff for \(item.purchaseDecision?.selectedSellerName ?? preferred?.sellerName ?? item.storefront)."
    case 7:
      return "Watch mailbox/order intake for the confirmation, then link the order."
    default:
      return "Order is linked. Continue tracking through Orders, Dispatch, and Tasks."
    }
  }

  private func wishlistPurchaseDecisionStageColor(for item: WishlistItem) -> Color {
    switch wishlistPurchaseDecisionPriority(for: item) {
    case 0...3: return .orange
    case 4...5: return .brown
    case 6: return .purple
    case 7: return .teal
    default: return .green
    }
  }

  private func wishlistPurchaseDecisionActionTitle(for item: WishlistItem) -> String {
    switch wishlistPurchaseDecisionPriority(for: item) {
    case 0: return "Compare"
    case 1: return "Score"
    case 2: return "Evidence task"
    case 3: return "Readiness"
    case 4: return "Decision"
    case 5: return "Review"
    case 6: return "Handoff"
    case 7: return "Order seen"
    default: return "Open item"
    }
  }

  private func wishlistPurchaseDecisionActionSymbol(for item: WishlistItem) -> String {
    switch wishlistPurchaseDecisionPriority(for: item) {
    case 0: return "magnifyingglass.circle"
    case 1: return "chart.bar.doc.horizontal"
    case 2: return "checklist"
    case 3: return "checklist.checked"
    case 4: return "doc.text.magnifyingglass"
    case 5: return "checkmark.seal"
    case 6: return "person.crop.circle.badge.checkmark"
    case 7: return "envelope.badge.fill"
    default: return "line.3.horizontal.decrease.circle"
    }
  }

  private func runWishlistPurchaseDecisionAction(for item: WishlistItem) {
    switch wishlistPurchaseDecisionPriority(for: item) {
    case 0:
      store.createWishlistComparisonPlan(item)
      store.createWishlistResearchRequest(from: item)
    case 1:
      store.evaluateWishlistComparisonOptions(item)
    case 2:
      store.createWishlistSellerEvidenceReviewTask(item)
    case 3:
      store.runWishlistPurchaseReadinessCheck(item)
    case 4:
      store.createWishlistPurchaseDecision(item)
    case 5:
      store.markWishlistPurchaseDecisionReviewed(item)
    case 6:
      store.prepareWishlistPurchaseHandoff(item)
    case 7:
      store.markWishlistOrderConfirmationSeen(item)
    default:
      wishlistSearchText = item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private var wishlistPurchaseDecisionSummaries: [WishlistPurchaseDecisionSummary] {
    wishlistPurchaseDecisionQueueItems
      .map(wishlistPurchaseDecisionSummary(for:))
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistPurchaseDecisionSummaryPanel: some View {
    let summaries = wishlistPurchaseDecisionSummaries
    let draftedCount = summaries.filter { $0.item.purchaseDecision != nil }.count
    let acceptedCount = summaries.filter { $0.item.purchaseDecision?.reviewState == .accepted }.count
    let missingVerificationCount = summaries.filter { !$0.verificationGaps.isEmpty }.count
    let handoffReadyCount = summaries.filter { $0.item.purchaseHandoff != nil }.count

    return SettingsPanel(title: "Purchase decision summary", symbol: "checkmark.seal.text.page.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Review the selected seller and the manual verification still required before buying. ParcelOps records the decision, evidence, and handoff path only; it does not check live retailer data or purchase anything.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Summaries", "\(summaries.count)", summaries.isEmpty ? .secondary : .blue),
          ("Drafted", "\(draftedCount)", draftedCount == 0 ? .secondary : .brown),
          ("Accepted", "\(acceptedCount)", acceptedCount == 0 ? .secondary : .green),
          ("Need checks", "\(missingVerificationCount)", missingVerificationCount == 0 ? .green : .orange),
          ("Handoff ready", "\(handoffReadyCount)", handoffReadyCount == 0 ? .secondary : .purple)
        ])

        if summaries.isEmpty {
          MVPEmptyState(
            title: "No purchase decisions to summarise",
            detail: "Create seller options first. The decision summary appears once a Wishlist item enters comparison, purchase decision, or handoff flow.",
            symbol: "checkmark.seal.text.page.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 380), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(summaries.prefix(8)) { summary in
              WishlistPurchaseDecisionSummaryRow(summary: summary) {
                runWishlistPurchaseDecisionSummaryAction(for: summary.item)
              } onReviewTask: {
                store.createWishlistPurchaseDecisionReviewTask(summary.item)
              } onNeedsReview: {
                store.markWishlistPurchaseDecisionNeedsReview(summary.item)
              } onFocus: {
                wishlistSearchText = summary.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(summaries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more purchase decision summar\(remaining == 1 ? "y is" : "ies are") available in the detailed Wishlist list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Required before buying: confirm live stock and price, AUD landed cost, postage cost/time, seller trust, account access, payment method, delivery address, returns, and warranty outside ParcelOps.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistPurchaseDecisionSummary(for item: WishlistItem) -> WishlistPurchaseDecisionSummary {
    let options = item.comparisonOptions ?? []
    let preferred = item.preferredOptionID.flatMap { preferredID in
      options.first { $0.id == preferredID }
    } ?? options.first
    let decision = item.purchaseDecision
    let seller = decision?.selectedSellerName ?? preferred?.sellerName ?? item.storefront
    let total = decision?.totalAUDSummary ?? preferred?.estimatedAUDTotal ?? item.estimatedCost
    let postage = decision?.postageSummary ?? preferred.map { "\($0.postageCost), \($0.postageTime)" } ?? "Postage not recorded"
    let trust = decision?.trustSummary ?? preferred.map { "\($0.trustRating): \($0.trustNotes)" } ?? "Seller trust not assessed"
    let rejected = decision?.rejectedOptionsSummary ?? rejectedWishlistSellerSummary(for: item, selectedOption: preferred)
    let gaps = wishlistPurchaseDecisionVerificationGaps(item: item, preferred: preferred)

    let stage: String
    let detail: String
    let color: Color
    let actionTitle: String
    let actionSymbol: String
    let sortPriority: Int

    if decision == nil {
      stage = "Decision needed"
      detail = preferred == nil
        ? "Choose or add a seller option before drafting the purchase decision."
        : "Draft a local decision for \(seller), then review live price, stock, postage, trust, account, and payment readiness."
      color = .brown
      actionTitle = "Draft decision"
      actionSymbol = "doc.text.magnifyingglass"
      sortPriority = preferred == nil ? 0 : 10
    } else if decision?.reviewState != .accepted {
      stage = "Review decision"
      detail = "Decision exists but still needs operator review before purchase handoff."
      color = .orange
      actionTitle = "Accept decision"
      actionSymbol = "checkmark.seal"
      sortPriority = 20
    } else if item.purchaseHandoff == nil {
      stage = "Prepare handoff"
      detail = "Decision is accepted. Prepare account and order-watch handoff before buying externally."
      color = .purple
      actionTitle = "Prepare handoff"
      actionSymbol = "person.crop.circle.badge.checkmark"
      sortPriority = 30
    } else if item.purchaseHandoff?.linkedOrderID == nil {
      stage = "Watch for order"
      detail = "Handoff is ready. After purchase, watch Inbox and Orders for confirmation and link the order."
      color = .teal
      actionTitle = "Order seen"
      actionSymbol = "envelope.badge.fill"
      sortPriority = 40
    } else {
      stage = "Linked order"
      detail = "Decision and handoff are linked to an order. Continue through Orders, Dispatch, and Tasks."
      color = .green
      actionTitle = "Focus item"
      actionSymbol = "line.3.horizontal.decrease.circle"
      sortPriority = 50
    }

    return WishlistPurchaseDecisionSummary(
      item: item,
      selectedSeller: seller,
      totalAUD: total,
      postage: postage,
      trust: trust,
      rejectedOptions: rejected,
      verificationGaps: gaps,
      stage: stage,
      detail: detail,
      color: color,
      actionTitle: actionTitle,
      actionSymbol: actionSymbol,
      sortPriority: sortPriority
    )
  }

  private func rejectedWishlistSellerSummary(for item: WishlistItem, selectedOption: WishlistComparisonOption?) -> String {
    let rejected = (item.comparisonOptions ?? [])
      .filter { $0.id != selectedOption?.id }
      .map { "\($0.sellerName): \($0.estimatedAUDTotal), trust \($0.trustRating)" }
    return rejected.isEmpty ? "No alternate seller options recorded." : rejected.joined(separator: " | ")
  }

  private func wishlistPurchaseDecisionVerificationGaps(item: WishlistItem, preferred: WishlistComparisonOption?) -> [String] {
    var gaps: [String] = []
    let decision = item.purchaseDecision

    if preferred == nil {
      gaps.append("seller option")
    }
    if item.preferredOptionID == nil {
      gaps.append("preferred seller")
    }
    if item.purchaseReadiness?.localizedCaseInsensitiveContains("ready") != true {
      gaps.append("readiness check")
    }
    if decision == nil {
      gaps.append("decision draft")
    } else if decision?.reviewState != .accepted {
      gaps.append("decision review")
    }
    if wishlistPurchaseDecisionValueNeedsReview(decision?.totalAUDSummary ?? preferred?.estimatedAUDTotal) {
      gaps.append("AUD landed cost")
    }
    if wishlistPurchaseDecisionValueNeedsReview(decision?.postageSummary ?? preferred?.postageCost) {
      gaps.append("postage cost/time")
    }
    if wishlistPurchaseDecisionValueNeedsReview(decision?.trustSummary ?? preferred?.trustRating) {
      gaps.append("seller trust")
    }
    if !(preferred?.operatorSellerEvidenceGaps.isEmpty ?? true) {
      gaps.append(contentsOf: preferred?.operatorSellerEvidenceGaps ?? [])
    }
    if item.purchaseHandoff == nil {
      gaps.append("account/order-watch handoff")
    }

    return Array(Set(gaps)).sorted()
  }

  private func wishlistPurchaseDecisionValueNeedsReview(_ value: String?) -> Bool {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if trimmed.isEmpty { return true }
    let lower = trimmed.localizedLowercase
    return lower.contains("pending")
      || lower.contains("unknown")
      || lower.contains("not recorded")
      || lower.contains("not assessed")
      || lower.contains("to confirm")
      || lower.contains("review")
      || lower.contains("no seller")
  }

  private func runWishlistPurchaseDecisionSummaryAction(for item: WishlistItem) {
    if item.purchaseDecision == nil {
      store.createWishlistPurchaseDecision(item)
    } else if item.purchaseDecision?.reviewState != .accepted {
      store.markWishlistPurchaseDecisionReviewed(item)
    } else if item.purchaseHandoff == nil {
      store.prepareWishlistPurchaseHandoff(item)
    } else if item.purchaseHandoff?.linkedOrderID == nil {
      store.markWishlistOrderConfirmationSeen(item)
    } else {
      wishlistSearchText = item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private var wishlistPrePurchaseOperatorChecklistItems: [WishlistPurchaseOperatorChecklist] {
    wishlistPurchaseReleaseChecklistItems
      .map { gate in
        let item = gate.item
        let decision = item.purchaseDecision
        let handoff = item.purchaseHandoff
        let preferred = item.preferredOptionID.flatMap { optionID in
          item.comparisonOptions?.first { $0.id == optionID }
        } ?? item.comparisonOptions?.first
        let checks = item.purchaseChecks ?? []
        let failedChecks = checks.filter { $0.status != "Passed" }
        let hasReadyDecision = decision?.reviewState == .accepted
        let hasHandoff = handoff != nil
        let hasOrder = handoff?.linkedOrderID != nil

        let manualChecks: [(String, Bool)] = [
          ("Seller chosen", preferred != nil && item.preferredOptionID != nil),
          ("Decision accepted", hasReadyDecision),
          ("AUD/postage/trust checked", !checks.isEmpty && failedChecks.isEmpty),
          ("Account/payment/delivery noted", hasHandoff),
          ("Order watch ready", hasHandoff),
          ("Order linked", hasOrder)
        ]

        let blockers = manualChecks.filter { !$0.1 }.map(\.0)
        let liveVerification = [
          "live stock",
          "current price",
          "AUD landed total",
          "postage cost/time",
          "seller trust",
          "returns/warranty",
          "account access",
          "payment method",
          "delivery address"
        ]

        let stage: String
        let detail: String
        let tone: Color
        let actionTitle: String
        let actionSymbol: String
        let sortPriority: Int

        if !hasReadyDecision {
          stage = "Decision not accepted"
          detail = decision == nil
            ? "Draft and review the selected seller decision before handoff."
            : "Accept or reopen the purchase decision after confirming seller and cost details."
          tone = .orange
          actionTitle = decision == nil ? "Draft decision" : "Accept decision"
          actionSymbol = decision == nil ? "doc.text.magnifyingglass" : "checkmark.seal"
          sortPriority = 10
        } else if failedChecks.isEmpty == false || checks.isEmpty {
          stage = "Checks need review"
          detail = checks.isEmpty ? "Run the local readiness check before handoff." : "Clear failed readiness checks before buying externally."
          tone = .orange
          actionTitle = "Run checks"
          actionSymbol = "checklist.checked"
          sortPriority = 20
        } else if !hasHandoff {
          stage = "Handoff needed"
          detail = "Prepare account, payment, delivery, and order-watch notes before the external purchase."
          tone = .purple
          actionTitle = "Prepare handoff"
          actionSymbol = "person.crop.circle.badge.checkmark"
          sortPriority = 30
        } else if !hasOrder {
          stage = "Ready to buy externally"
          detail = "Handoff is ready. Buy outside ParcelOps only after final live checks, then watch Inbox/Orders for confirmation."
          tone = .green
          actionTitle = "Order seen"
          actionSymbol = "envelope.badge.fill"
          sortPriority = 40
        } else {
          stage = "Order linked"
          detail = "Order confirmation has been linked. Continue operational tracking in Orders, Dispatch, and Tasks."
          tone = .teal
          actionTitle = "Focus item"
          actionSymbol = "scope"
          sortPriority = 50
        }

        return WishlistPurchaseOperatorChecklist(
          item: item,
          stage: stage,
          detail: detail,
          selectedSeller: decision?.selectedSellerName ?? preferred?.sellerName ?? item.storefront,
          totalAUD: decision?.totalAUDSummary ?? preferred?.estimatedAUDTotal ?? item.estimatedCost,
          postage: decision?.postageSummary ?? preferred.map { "\($0.postageCost), \($0.postageTime)" } ?? "Postage not recorded",
          trust: decision?.trustSummary ?? preferred?.trustRating ?? "Seller trust not assessed",
          handoff: handoff?.accountLabel ?? "Account/payment/delivery not prepared",
          manualChecks: manualChecks,
          blockers: blockers,
          liveVerification: liveVerification,
          tone: tone,
          actionTitle: actionTitle,
          actionSymbol: actionSymbol,
          sortPriority: sortPriority
        )
      }
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistPrePurchaseOperatorChecklistPanel: some View {
    let items = wishlistPrePurchaseOperatorChecklistItems
    let ready = items.filter { $0.stage == "Ready to buy externally" }.count
    let linked = items.filter { $0.stage == "Order linked" }.count
    let blocked = items.filter { $0.sortPriority < 40 }.count
    let handoffMissing = items.filter { $0.blockers.contains("Account/payment/delivery noted") }.count

    return SettingsPanel(title: "Operator pre-purchase checklist", symbol: "checklist.checked") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this as the human buying checklist. It separates local readiness from real-world verification: ParcelOps can stage the decision and order watch, but a person must still confirm live seller, account, payment, and delivery details outside the app.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Checklist items", "\(items.count)", items.isEmpty ? .secondary : .blue),
          ("Ready", "\(ready)", ready == 0 ? .secondary : .green),
          ("Linked", "\(linked)", linked == 0 ? .secondary : .teal),
          ("Blocked", "\(blocked)", blocked == 0 ? .green : .orange),
          ("Need handoff", "\(handoffMissing)", handoffMissing == 0 ? .green : .purple)
        ])

        if items.isEmpty {
          MVPEmptyState(
            title: "No pre-purchase checklist items",
            detail: "Wishlist items appear here once they have seller options, purchase decisions, handoff setup, or release readiness.",
            symbol: "checklist.checked"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 390), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(items.prefix(8)) { item in
              WishlistPurchaseOperatorChecklistRow(checklist: item) {
                runWishlistPrePurchaseChecklistAction(for: item.item)
              } onTask: {
                store.createWishlistPurchaseDecisionReviewTask(item.item)
              } onFocus: {
                wishlistSearchText = item.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(items.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more pre-purchase checklist item\(remaining == 1 ? "" : "s") are available in the detailed Wishlist list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("No checkout, payment, account login, seller trust lookup, currency conversion, postage quote, browser automation, or retailer contact runs from this checklist.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func runWishlistPrePurchaseChecklistAction(for item: WishlistItem) {
    if item.purchaseDecision == nil {
      store.createWishlistPurchaseDecision(item)
    } else if item.purchaseDecision?.reviewState != .accepted {
      store.markWishlistPurchaseDecisionReviewed(item)
    } else if item.purchaseChecks?.isEmpty != false || item.purchaseChecks?.contains(where: { $0.status != "Passed" }) == true {
      store.runWishlistPurchaseReadinessCheck(item)
    } else if item.purchaseHandoff == nil {
      store.prepareWishlistPurchaseHandoff(item)
    } else if item.purchaseHandoff?.linkedOrderID == nil {
      store.markWishlistOrderConfirmationSeen(item)
    } else {
      wishlistSearchText = item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private var wishlistPurchaseReleaseChecklistItems: [WishlistPurchaseReleaseGate] {
    store.wishlistItems
      .filter { item in
        !(item.comparisonOptions ?? []).isEmpty
          || item.purchaseDecision != nil
          || item.purchaseHandoff != nil
          || item.status.localizedCaseInsensitiveContains("purchase")
          || item.status.localizedCaseInsensitiveContains("ready")
      }
      .map(wishlistPurchaseReleaseGate(for:))
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistPurchaseReleaseChecklistPanel: some View {
    let gates = wishlistPurchaseReleaseChecklistItems
    let handoffReady = gates.filter(\.isReadyForManualPurchase).count
    let linkedOrders = gates.filter(\.isLinkedOrder).count
    let blocked = gates.filter { !$0.isReadyForManualPurchase && !$0.isLinkedOrder }.count
    let highRisk = gates.filter { $0.tone == .red || $0.tone == .orange }.count

    return SettingsPanel(title: "Purchase release checklist", symbol: "checkmark.seal.text.page.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("This is the final local gate before a human purchase or order-confirmation watch. It checks source details, preferred seller evidence, readiness checks, decision review, handoff setup, and linked order state without buying anything or contacting retailers.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Release items", "\(gates.count)", gates.isEmpty ? .secondary : .blue),
          ("Ready handoff", "\(handoffReady)", handoffReady == 0 ? .secondary : .green),
          ("Linked orders", "\(linkedOrders)", linkedOrders == 0 ? .secondary : .teal),
          ("Blocked", "\(blocked)", blocked == 0 ? .green : .orange),
          ("Risk", "\(highRisk)", highRisk == 0 ? .green : .red)
        ])

        if gates.isEmpty {
          MVPEmptyState(
            title: "No Wishlist items are near purchase release",
            detail: "Add seller options and run comparison before an item appears in this final purchase gate.",
            symbol: "checkmark.seal.text.page.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 260 : 390), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(gates.prefix(8)) { gate in
              WishlistPurchaseReleaseChecklistRow(gate: gate) {
                runWishlistPurchaseReleaseAction(for: gate.item)
              } onFocus: {
                wishlistSearchText = gate.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(gates.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more Wishlist release item\(remaining == 1 ? "" : "s") are available in the detailed list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Release means local readiness only. ParcelOps has not verified live price, stock, postage, seller reputation, account login, payment, checkout, or delivery status.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistPurchaseReleaseGate(for item: WishlistItem) -> WishlistPurchaseReleaseGate {
    let options = item.comparisonOptions ?? []
    let preferred = item.preferredOptionID.flatMap { preferredID in
      options.first { $0.id == preferredID }
    } ?? options.first
    let checks = item.purchaseChecks ?? []
    let sourceOK = !item.itemName.isPlaceholderValidationValue
      && !item.storefrontURL.isPlaceholderValidationValue
      && !item.owner.isPlaceholderValidationValue
    let sellerOK = preferred != nil && preferred?.operatorSellerEvidenceGaps.isEmpty == true
    let readinessOK = !checks.isEmpty && !checks.contains { $0.status != "Passed" }
    let decisionOK = item.purchaseDecision?.reviewState == .accepted
    let handoffOK = item.purchaseHandoff != nil
    let orderLinked = item.purchaseHandoff?.linkedOrderID != nil

    var checksSummary: [(String, Bool)] = [
      ("Source", sourceOK),
      ("Seller", sellerOK),
      ("Readiness", readinessOK),
      ("Decision", decisionOK),
      ("Handoff", handoffOK),
      ("Order", orderLinked)
    ]

    let stage: String
    let detail: String
    let actionTitle: String
    let actionSymbol: String
    let tone: Color
    let sortPriority: Int

    if options.isEmpty {
      stage = "Seller comparison needed"
      detail = "Add seller options or a research request before this item can be released for purchase review."
      actionTitle = "Compare"
      actionSymbol = "magnifyingglass.circle"
      tone = .orange
      sortPriority = 1
    } else if preferred == nil || item.preferredOptionID == nil {
      stage = "Preferred seller needed"
      detail = "Score or choose the preferred seller before release."
      actionTitle = "Score"
      actionSymbol = "chart.bar.doc.horizontal"
      tone = .orange
      sortPriority = 2
    } else if !sellerOK {
      let gaps = preferred?.operatorSellerEvidenceGaps ?? []
      stage = "Seller evidence needed"
      detail = "Confirm \(gaps.prefix(3).joined(separator: ", ")) before purchase handoff."
      actionTitle = "Evidence task"
      actionSymbol = "checklist"
      tone = .orange
      sortPriority = 3
    } else if !readinessOK {
      stage = "Readiness check needed"
      detail = checks.isEmpty ? "Run the local purchase readiness check." : "Clear failed readiness checks before release."
      actionTitle = "Readiness"
      actionSymbol = "checklist.checked"
      tone = .orange
      sortPriority = 4
    } else if item.purchaseDecision == nil {
      stage = "Purchase decision needed"
      detail = "Draft the selected seller, AUD total, postage, trust, and rejected alternatives."
      actionTitle = "Decision"
      actionSymbol = "doc.text.magnifyingglass"
      tone = .brown
      sortPriority = 5
    } else if !decisionOK {
      stage = "Decision review needed"
      detail = "Review and accept the local decision before handoff."
      actionTitle = "Review"
      actionSymbol = "checkmark.seal"
      tone = .brown
      sortPriority = 6
    } else if !handoffOK {
      stage = "Handoff setup needed"
      detail = "Prepare the manual purchase handoff and expected order-confirmation watch."
      actionTitle = "Handoff"
      actionSymbol = "person.crop.circle.badge.checkmark"
      tone = .purple
      sortPriority = 7
    } else if !orderLinked {
      stage = "Ready for manual purchase"
      detail = "Handoff is ready. After external purchase, watch Inbox/Mailbox Monitor for confirmation and link the order."
      actionTitle = "Order seen"
      actionSymbol = "envelope.badge.fill"
      tone = .green
      sortPriority = 8
    } else {
      stage = "Linked order released"
      detail = "A local order is linked. Continue through Orders, Dispatch, Tasks, and Audit."
      actionTitle = "Open item"
      actionSymbol = "scope"
      tone = .teal
      sortPriority = 9
    }

    if orderLinked {
      checksSummary[5] = ("Order", true)
    }

    return WishlistPurchaseReleaseGate(
      item: item,
      stage: stage,
      detail: detail,
      actionTitle: actionTitle,
      actionSymbol: actionSymbol,
      checks: checksSummary,
      tone: tone,
      sortPriority: sortPriority
    )
  }

  private func runWishlistPurchaseReleaseAction(for item: WishlistItem) {
    let gate = wishlistPurchaseReleaseGate(for: item)
    switch gate.sortPriority {
    case 1:
      store.createWishlistComparisonPlan(item)
      store.createWishlistResearchRequest(from: item)
    case 2:
      store.evaluateWishlistComparisonOptions(item)
    case 3:
      store.createWishlistSellerEvidenceReviewTask(item)
    case 4:
      store.runWishlistPurchaseReadinessCheck(item)
    case 5:
      store.createWishlistPurchaseDecision(item)
    case 6:
      store.markWishlistPurchaseDecisionReviewed(item)
    case 7:
      store.prepareWishlistPurchaseHandoff(item)
    case 8:
      store.markWishlistOrderConfirmationSeen(item)
    default:
      wishlistSearchText = item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private var wishlistPurchaseHandoffPackItems: [WishlistItem] {
    store.wishlistItems
      .filter { item in
        item.purchaseHandoff != nil
          || item.purchaseDecision?.reviewState == .accepted
          || item.status.localizedCaseInsensitiveContains("purchase")
          || item.status.localizedCaseInsensitiveContains("order confirmation")
      }
      .sorted { first, second in
        let firstGaps = wishlistPurchaseHandoffPackGaps(for: first).count
        let secondGaps = wishlistPurchaseHandoffPackGaps(for: second).count
        if firstGaps == secondGaps {
          return first.itemName.localizedCaseInsensitiveCompare(second.itemName) == .orderedAscending
        }
        return firstGaps > secondGaps
      }
  }

  private var wishlistPurchaseHandoffPackPanel: some View {
    let items = wishlistPurchaseHandoffPackItems
    let missingOrder = items.filter { $0.purchaseHandoff?.linkedOrderID == nil }.count
    let missingCost = items.filter { store.suggestedCostRecords(for: $0).isEmpty }.count
    let missingProcurement = items.filter { store.suggestedProcurementRequests(for: $0).isEmpty }.count
    let missingReceiving = items.filter { store.suggestedReceivingInspections(for: $0).isEmpty }.count

    return SettingsPanel(title: "Purchase handoff pack", symbol: "shippingbox.and.arrow.backward.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("After a Wishlist item is ready to buy or has been bought externally, use this pack to stage the local records ParcelOps needs: account context, cost/budget, procurement, receiving, and order-confirmation watch.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Handoff items", "\(items.count)", items.isEmpty ? .secondary : .blue),
          ("No linked order", "\(missingOrder)", missingOrder == 0 ? .green : .teal),
          ("Cost gaps", "\(missingCost)", missingCost == 0 ? .green : .orange),
          ("Procurement gaps", "\(missingProcurement)", missingProcurement == 0 ? .green : .purple),
          ("Receiving gaps", "\(missingReceiving)", missingReceiving == 0 ? .green : .brown)
        ])

        if items.isEmpty {
          MVPEmptyState(
            title: "No purchase handoffs yet",
            detail: "Review a purchase decision or prepare a manual purchase handoff before staging cost, procurement, receiving, and order watch records.",
            symbol: "shippingbox.and.arrow.backward.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 250 : 380), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(items.prefix(8)) { item in
              WishlistPurchaseHandoffPackRow(
                item: item,
                linkedOrder: item.purchaseHandoff?.linkedOrderID.flatMap { orderID in
                  store.orders.first { $0.id == orderID }
                },
                gaps: wishlistPurchaseHandoffPackGaps(for: item),
                accountCount: store.suggestedAccounts(for: item).count,
                costCount: store.suggestedCostRecords(for: item).count,
                procurementCount: store.suggestedProcurementRequests(for: item).count,
                receivingCount: store.suggestedReceivingInspections(for: item).count
              ) {
                runWishlistHandoffPackAction(for: item)
              } onTask: {
                store.createWishlistPurchaseHandoffReviewTask(item)
              } onOrderSeen: {
                store.markWishlistOrderConfirmationSeen(item)
              } onFocus: {
                wishlistSearchText = item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(items.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more Wishlist handoff item\(remaining == 1 ? "" : "s") are available in the detailed list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("This pack creates local planning records only. It does not buy items, log in to retailers, store payment details, send email, mutate mailboxes, book carriers, or run background monitoring.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistPurchaseHandoffPackGaps(for item: WishlistItem) -> [String] {
    var gaps: [String] = []
    if item.purchaseHandoff == nil { gaps.append("handoff") }
    if store.suggestedAccounts(for: item).isEmpty { gaps.append("account") }
    if store.suggestedCostRecords(for: item).isEmpty { gaps.append("cost") }
    if store.suggestedProcurementRequests(for: item).isEmpty { gaps.append("procurement") }
    if store.suggestedReceivingInspections(for: item).isEmpty { gaps.append("receiving") }
    if item.purchaseHandoff?.linkedOrderID == nil { gaps.append("order link") }
    return gaps
  }

  private func runWishlistHandoffPackAction(for item: WishlistItem) {
    let gaps = wishlistPurchaseHandoffPackGaps(for: item)
    if gaps.contains("handoff") {
      store.prepareWishlistPurchaseHandoff(item)
    } else if gaps.contains("cost") {
      store.createWishlistPurchaseCostRecord(item)
    } else if gaps.contains("procurement") {
      store.createWishlistProcurementRequest(item)
    } else if gaps.contains("receiving") {
      store.createWishlistReceivingInspection(item)
    } else if gaps.contains("order link") {
      store.markWishlistOrderConfirmationSeen(item)
    } else {
      store.createWishlistPurchaseHandoffReviewTask(item)
    }
  }

  private var wishlistPurchaseAccountLedgerItems: [WishlistPurchaseAccountLedgerEntry] {
    store.wishlistItems
      .compactMap { item -> WishlistPurchaseAccountLedgerEntry? in
        let decision = item.purchaseDecision
        let handoff = item.purchaseHandoff
        let isPurchaseRelated = handoff != nil
          || decision?.reviewState == .accepted
          || item.status.localizedCaseInsensitiveContains("purchase")
          || item.status.localizedCaseInsensitiveContains("order confirmation")
          || item.status.localizedCaseInsensitiveContains("purchased")
        guard isPurchaseRelated else { return nil }

        let linkedOrder = handoff?.linkedOrderID.flatMap { orderID in
          store.orders.first { $0.id == orderID }
        }
        let candidateCount = store.suggestedWishlistOrderConfirmations(for: item).count

        if handoff == nil {
          return WishlistPurchaseAccountLedgerEntry(
            item: item,
            handoff: nil,
            linkedOrder: linkedOrder,
            candidateCount: candidateCount,
            stage: "Handoff needed",
            detail: "Prepare the local account/order-watch handoff before buying externally.",
            tone: .purple,
            actionTitle: "Prepare handoff",
            actionSymbol: "person.crop.circle.badge.checkmark",
            sortPriority: 1
          )
        }

        if linkedOrder == nil && candidateCount > 0 {
          return WishlistPurchaseAccountLedgerEntry(
            item: item,
            handoff: handoff,
            linkedOrder: nil,
            candidateCount: candidateCount,
            stage: "Confirmation candidates",
            detail: "Inbox has possible order confirmations. Review and link one before closing purchase follow-up.",
            tone: .teal,
            actionTitle: "Order seen",
            actionSymbol: "envelope.badge.fill",
            sortPriority: 2
          )
        }

        if linkedOrder == nil && (handoff?.purchaseStatus.localizedCaseInsensitiveContains("purchased") == true || handoff?.orderWatchStatus.localizedCaseInsensitiveContains("watch") == true) {
          return WishlistPurchaseAccountLedgerEntry(
            item: item,
            handoff: handoff,
            linkedOrder: nil,
            candidateCount: candidateCount,
            stage: "Awaiting confirmation",
            detail: "External purchase has been recorded. Watch Inbox for an order confirmation from the selected seller/account.",
            tone: .orange,
            actionTitle: "Order seen",
            actionSymbol: "envelope.badge.fill",
            sortPriority: 3
          )
        }

        if linkedOrder == nil {
          return WishlistPurchaseAccountLedgerEntry(
            item: item,
            handoff: handoff,
            linkedOrder: nil,
            candidateCount: candidateCount,
            stage: "Ready for order watch",
            detail: "Handoff is staged. Record the external purchase when it happens, then watch for confirmation.",
            tone: .green,
            actionTitle: "Purchased",
            actionSymbol: "bag.fill",
            sortPriority: 4
          )
        }

        return WishlistPurchaseAccountLedgerEntry(
          item: item,
          handoff: handoff,
          linkedOrder: linkedOrder,
          candidateCount: candidateCount,
          stage: "Linked order",
          detail: "Wishlist purchase has a linked order trail. Keep the order open for dispatch and receipt follow-up.",
          tone: .green,
          actionTitle: "Focus item",
          actionSymbol: "scope",
          sortPriority: 5
        )
      }
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistPurchaseAccountLedgerPanel: some View {
    let entries = wishlistPurchaseAccountLedgerItems
    let needHandoff = entries.filter { $0.handoff == nil }.count
    let watching = entries.filter { $0.stage == "Awaiting confirmation" || $0.stage == "Ready for order watch" }.count
    let candidates = entries.filter { $0.candidateCount > 0 && $0.linkedOrder == nil }.count
    let linked = entries.filter { $0.linkedOrder != nil }.count

    return SettingsPanel(title: "Purchase account and order-watch ledger", symbol: "person.crop.circle.badge.clock.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Track the local trail from selected seller to account label, external purchase, expected confirmation signals, and linked order. This ledger does not log in, buy, send email, store payment details, or monitor mail in the background.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Ledger items", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Need handoff", "\(needHandoff)", needHandoff == 0 ? .green : .purple),
          ("Watching", "\(watching)", watching == 0 ? .secondary : .orange),
          ("Inbox candidates", "\(candidates)", candidates == 0 ? .secondary : .teal),
          ("Linked orders", "\(linked)", linked == 0 ? .secondary : .green)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No purchase account ledger yet",
            detail: "Prepare a Wishlist purchase handoff or accept a purchase decision to start tracking account labels and order-confirmation watch locally.",
            symbol: "person.crop.circle.badge.clock.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 252 : 385), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              WishlistPurchaseAccountLedgerRow(entry: entry) {
                runWishlistPurchaseAccountLedgerAction(for: entry)
              } onPurchased: {
                store.recordWishlistPurchasedExternally(entry.item)
              } onTask: {
                store.createWishlistPurchaseHandoffReviewTask(entry.item)
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more ledger item\(remaining == 1 ? "" : "s") are available in the detailed Wishlist list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private func runWishlistPurchaseAccountLedgerAction(for entry: WishlistPurchaseAccountLedgerEntry) {
    if entry.handoff == nil {
      store.prepareWishlistPurchaseHandoff(entry.item)
    } else if entry.linkedOrder == nil && entry.stage == "Ready for order watch" {
      store.recordWishlistPurchasedExternally(entry.item)
    } else if entry.linkedOrder == nil {
      store.markWishlistOrderConfirmationSeen(entry.item)
    } else {
      wishlistSearchText = entry.item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private var wishlistPostPurchaseOrderWatchEntries: [WishlistPostPurchaseOrderWatchEntry] {
    store.wishlistItems
      .compactMap { item -> WishlistPostPurchaseOrderWatchEntry? in
        guard let handoff = item.purchaseHandoff,
              handoff.linkedOrderID == nil else { return nil }
        let matches = store.suggestedWishlistOrderConfirmations(for: item)
        let isPurchased = handoff.purchaseStatus.localizedCaseInsensitiveContains("purchased")
          || item.status.localizedCaseInsensitiveContains("awaiting order")
          || item.status.localizedCaseInsensitiveContains("confirmation")
        let stage = matches.isEmpty
          ? (isPurchased ? "Awaiting confirmation" : "Ready to watch")
          : "Match review"
        let tone: Color = matches.isEmpty ? (isPurchased ? .orange : .blue) : .green
        let detail = matches.isEmpty
          ? "No imported Inbox confirmation currently matches this purchase handoff."
          : "\(matches.count) imported Inbox row\(matches.count == 1 ? "" : "s") may confirm this purchase."
        let priority = matches.isEmpty ? (isPurchased ? 2 : 3) : 1
        return WishlistPostPurchaseOrderWatchEntry(
          item: item,
          handoff: handoff,
          matches: matches,
          stage: stage,
          detail: detail,
          tone: tone,
          sortPriority: priority
        )
      }
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          if first.matches.count == second.matches.count {
            return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
          }
          return first.matches.count > second.matches.count
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistPostPurchaseOrderWatchPanel: some View {
    let entries = wishlistPostPurchaseOrderWatchEntries
    let matched = entries.filter { !$0.matches.isEmpty }.count
    let purchased = entries.filter { $0.handoff.purchaseStatus.localizedCaseInsensitiveContains("purchased") }.count
    let ready = entries.filter { $0.matches.isEmpty && !$0.handoff.purchaseStatus.localizedCaseInsensitiveContains("purchased") }.count

    return SettingsPanel(title: "Post-purchase order watch", symbol: "envelope.badge.shield.half.filled") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use this queue after a Wishlist item is bought outside ParcelOps. It keeps order-confirmation follow-up visible until a local Inbox confirmation or order is linked.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Watching", "\(entries.count)", entries.isEmpty ? .secondary : .orange),
          ("Inbox matches", "\(matched)", matched == 0 ? .secondary : .green),
          ("Purchased", "\(purchased)", purchased == 0 ? .secondary : .orange),
          ("Ready", "\(ready)", ready == 0 ? .secondary : .blue)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No Wishlist purchases waiting for order confirmation",
            detail: "When an external purchase is recorded, it will appear here until an Inbox confirmation or local order is linked.",
            symbol: "envelope.badge.shield.half.filled"
          )
        } else {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(entries.prefix(6)) { entry in
              WishlistOrderWatchMatchRow(
                item: entry.item,
                matches: Array(entry.matches.prefix(3))
              ) { email in
                store.confirmWishlistOrderFromIntake(entry.item, email: email)
              } onMarkSeen: {
                if let email = entry.matches.first {
                  store.confirmWishlistOrderFromIntake(entry.item, email: email)
                } else {
                  store.markWishlistOrderConfirmationSeen(entry.item)
                }
              }
            }
          }

          let remaining = max(entries.count - 6, 0)
          if remaining > 0 {
            Text("\(remaining) more post-purchase watch item\(remaining == 1 ? "" : "s") are available in the detailed Wishlist list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Manual and local only. This queue does not monitor mailboxes in the background, contact retailers, log in to accounts, store payment data, or mutate mailbox messages.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var wishlistPurchaseOperationsHandoffItems: [WishlistPurchaseOperationsHandoffEntry] {
    store.wishlistItems
      .compactMap { item -> WishlistPurchaseOperationsHandoffEntry? in
        guard item.purchaseHandoff != nil
          || item.status.localizedCaseInsensitiveContains("order confirmation")
          || item.status.localizedCaseInsensitiveContains("awaiting order")
          || item.status.localizedCaseInsensitiveContains("purchased")
          || item.purchaseDecision?.reviewState == .accepted else { return nil }

        let orderLinked = item.purchaseHandoff?.linkedOrderID != nil
        let inspectionCount = store.suggestedReceivingInspections(for: item).count
        let receiptCount = store.suggestedInventoryReceipts(for: item).count
        let storageCount = store.suggestedStorageLocations(for: item).count
        let custodyCount = store.suggestedCustodyRecords(for: item).count
        let labelCount = store.suggestedLabelReferenceRecords(for: item).count
        let scanCount = store.suggestedScanSessionRecords(for: item).count
        let manifestCount = store.suggestedShipmentManifestRecords(for: item).count
        let dispatchCount = store.suggestedDispatchReadinessChecklists(for: item).count

        var gaps: [String] = []
        if item.purchaseHandoff == nil { gaps.append("handoff") }
        if !orderLinked { gaps.append("order") }
        if inspectionCount == 0 { gaps.append("receiving") }
        if receiptCount == 0 { gaps.append("inventory") }
        if storageCount == 0 { gaps.append("storage") }
        if custodyCount == 0 { gaps.append("custody") }
        if labelCount == 0 { gaps.append("label") }
        if scanCount == 0 { gaps.append("manual check") }
        if manifestCount == 0 { gaps.append("manifest") }
        if dispatchCount == 0 { gaps.append("dispatch") }

        let stage: String
        let detail: String
        let tone: Color
        let actionTitle: String
        let actionSymbol: String
        let priority: Int

        if item.purchaseHandoff == nil {
          stage = "Handoff first"
          detail = "Prepare the purchase handoff before staging receiving, storage, custody, or dispatch records."
          tone = .purple
          actionTitle = "Prepare handoff"
          actionSymbol = "person.crop.circle.badge.checkmark"
          priority = 1
        } else if !orderLinked {
          stage = "Order link needed"
          detail = "Link an order confirmation before this can become a clean receiving and dispatch trail."
          tone = .orange
          actionTitle = "Order seen"
          actionSymbol = "envelope.badge.fill"
          priority = 2
        } else if !gaps.isEmpty {
          stage = "Ops setup gaps"
          detail = "Create the next local downstream record: \(gaps.prefix(3).joined(separator: ", "))."
          tone = .teal
          actionTitle = wishlistPurchaseOperationsActionTitle(for: gaps)
          actionSymbol = wishlistPurchaseOperationsActionSymbol(for: gaps)
          priority = 3
        } else {
          stage = "Ops trail ready"
          detail = "Order, receiving, storage, custody, label, manual check, manifest, and dispatch records are all staged locally."
          tone = .green
          actionTitle = "Focus item"
          actionSymbol = "scope"
          priority = 4
        }

        return WishlistPurchaseOperationsHandoffEntry(
          item: item,
          linkedOrder: item.purchaseHandoff?.linkedOrderID.flatMap { orderID in store.orders.first { $0.id == orderID } },
          stage: stage,
          detail: detail,
          gaps: gaps,
          inspectionCount: inspectionCount,
          receiptCount: receiptCount,
          storageCount: storageCount,
          custodyCount: custodyCount,
          labelCount: labelCount,
          scanCount: scanCount,
          manifestCount: manifestCount,
          dispatchCount: dispatchCount,
          tone: tone,
          actionTitle: actionTitle,
          actionSymbol: actionSymbol,
          sortPriority: priority
        )
      }
      .sorted { first, second in
        if first.sortPriority == second.sortPriority {
          if first.gaps.count == second.gaps.count {
            return first.item.itemName.localizedCaseInsensitiveCompare(second.item.itemName) == .orderedAscending
          }
          return first.gaps.count > second.gaps.count
        }
        return first.sortPriority < second.sortPriority
      }
  }

  private var wishlistPurchaseOperationsHandoffPanel: some View {
    let entries = wishlistPurchaseOperationsHandoffItems
    let orderGaps = entries.filter { $0.gaps.contains("order") }.count
    let receivingGaps = entries.filter { $0.gaps.contains("receiving") || $0.gaps.contains("inventory") }.count
    let custodyGaps = entries.filter { $0.gaps.contains("storage") || $0.gaps.contains("custody") || $0.gaps.contains("label") || $0.gaps.contains("manual check") }.count
    let dispatchGaps = entries.filter { $0.gaps.contains("manifest") || $0.gaps.contains("dispatch") }.count

    return SettingsPanel(title: "Purchase-to-operations handoff", symbol: "arrow.triangle.branch") {
      VStack(alignment: .leading, spacing: 12) {
        Text("After a Wishlist item is bought and confirmed, use this panel to stage the local receiving, inventory, storage, custody, label, manual verification, manifest, and dispatch readiness trail.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Handoff items", "\(entries.count)", entries.isEmpty ? .secondary : .blue),
          ("Order gaps", "\(orderGaps)", orderGaps == 0 ? .green : .orange),
          ("Receiving gaps", "\(receivingGaps)", receivingGaps == 0 ? .green : .teal),
          ("Custody gaps", "\(custodyGaps)", custodyGaps == 0 ? .green : .purple),
          ("Dispatch gaps", "\(dispatchGaps)", dispatchGaps == 0 ? .green : .brown)
        ])

        if entries.isEmpty {
          MVPEmptyState(
            title: "No purchase-to-operations handoff items yet",
            detail: "Items appear here after a purchase decision, purchase handoff, or order-confirmation state exists.",
            symbol: "arrow.triangle.branch"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 252 : 390), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(entries.prefix(8)) { entry in
              WishlistPurchaseOperationsHandoffRow(entry: entry) {
                runWishlistPurchaseOperationsHandoffAction(for: entry)
              } onTask: {
                store.createWishlistPurchaseHandoffReviewTask(entry.item)
              } onFocus: {
                wishlistSearchText = entry.item.itemName
                selectedSource = nil
                selectedStatus = nil
              }
            }
          }

          let remaining = max(entries.count - 8, 0)
          if remaining > 0 {
            Text("\(remaining) more operations handoff item\(remaining == 1 ? "" : "s") are available in the detailed Wishlist list below.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text("Local planning only. This panel does not book carriers, print labels, scan items, access warehouses, contact retailers, mutate mailboxes, or run background monitoring.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistPurchaseOperationsActionTitle(for gaps: [String]) -> String {
    if gaps.contains("handoff") { return "Handoff" }
    if gaps.contains("order") { return "Order seen" }
    if gaps.contains("receiving") { return "Receiving" }
    if gaps.contains("inventory") { return "Inventory" }
    if gaps.contains("storage") { return "Storage" }
    if gaps.contains("custody") { return "Custody" }
    if gaps.contains("label") { return "Label" }
    if gaps.contains("manual check") { return "Manual check" }
    if gaps.contains("manifest") { return "Manifest" }
    if gaps.contains("dispatch") { return "Dispatch" }
    return "Focus item"
  }

  private func wishlistPurchaseOperationsActionSymbol(for gaps: [String]) -> String {
    if gaps.contains("handoff") { return "person.crop.circle.badge.checkmark" }
    if gaps.contains("order") { return "envelope.badge.fill" }
    if gaps.contains("receiving") { return "checkmark.seal.fill" }
    if gaps.contains("inventory") { return "shippingbox.and.arrow.backward.fill" }
    if gaps.contains("storage") { return "archivebox.fill" }
    if gaps.contains("custody") { return "person.2.badge.gearshape.fill" }
    if gaps.contains("label") { return "tag.square.fill" }
    if gaps.contains("manual check") { return "checklist.checked" }
    if gaps.contains("manifest") { return "paperplane.fill" }
    if gaps.contains("dispatch") { return "checkmark.rectangle.stack.fill" }
    return "scope"
  }

  private func runWishlistPurchaseOperationsHandoffAction(for entry: WishlistPurchaseOperationsHandoffEntry) {
    let gaps = entry.gaps
    if gaps.contains("handoff") {
      store.prepareWishlistPurchaseHandoff(entry.item)
    } else if gaps.contains("order") {
      if let email = store.suggestedWishlistOrderConfirmations(for: entry.item).first {
        store.confirmWishlistOrderFromIntake(entry.item, email: email)
      } else {
        store.markWishlistOrderConfirmationSeen(entry.item)
      }
    } else if gaps.contains("receiving") {
      store.createWishlistReceivingInspection(entry.item)
    } else if gaps.contains("inventory") {
      store.createWishlistInventoryReceipt(entry.item)
    } else if gaps.contains("storage") {
      store.createWishlistStorageLocation(entry.item)
    } else if gaps.contains("custody") {
      store.createWishlistCustodyRecord(entry.item)
    } else if gaps.contains("label") {
      store.createWishlistLabelReference(entry.item)
    } else if gaps.contains("manual check") {
      store.createWishlistScanSession(entry.item)
    } else if gaps.contains("manifest") {
      store.createWishlistShipmentManifest(entry.item)
    } else if gaps.contains("dispatch") {
      store.createWishlistDispatchReadinessChecklist(entry.item)
    } else {
      wishlistSearchText = entry.item.itemName
      selectedSource = nil
      selectedStatus = nil
    }
  }

  private var wishlistAgentHandoffPacketPanel: some View {
    let requests = store.wishlistResearchRequests
    let ready = requests.filter(\.isAgentBriefReady)
    let needsScope = requests.filter { !$0.isAgentBriefReady && !$0.requestStatus.localizedCaseInsensitiveContains("blocked") }
    let blocked = requests.filter { $0.requestStatus.localizedCaseInsensitiveContains("blocked") }
    let missingResearchItems = store.wishlistItems.filter { item in
      (item.comparisonOptions ?? []).isEmpty
        && !requests.contains { $0.wishlistItemID == item.id }
    }

    return SettingsPanel(title: "Future comparison agent packet", symbol: "sparkles.rectangle.stack.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("This is the local contract for a future shopping comparison agent. It defines what can be handed off later: product/source context, AU and overseas retailer scope, AUD landed cost, postage timing, seller trust evidence, and strict no-purchase boundaries.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Ready briefs", "\(ready.count)", ready.isEmpty ? .secondary : .green),
          ("Need scope", "\(needsScope.count)", needsScope.isEmpty ? .green : .orange),
          ("Blocked", "\(blocked.count)", blocked.isEmpty ? .green : .red),
          ("No brief", "\(missingResearchItems.count)", missingResearchItems.isEmpty ? .green : .blue)
        ])

        VStack(alignment: .leading, spacing: 6) {
          Label("Future agent output contract", systemImage: "doc.text.magnifyingglass")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Text("Required output: product URL, seller, listed price/currency, estimated AUD landed total, postage cost/time, seller region, returns/warranty notes, trust evidence, and recommendation.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Text("Boundaries: no checkout, no payment, no account login, no credential capture, no mailbox mutation, no carrier booking, and no background monitoring.")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))

        if requests.isEmpty {
          MVPEmptyState(
            title: "No agent research briefs staged",
            detail: "Use Compare on Wishlist items to stage local research briefs. Later, a real agent can consume these briefs without changing the operator workflow.",
            symbol: "list.bullet.clipboard.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 245 : 360), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(Array((ready + needsScope + blocked).prefix(6))) { request in
              WishlistAgentHandoffPacketRow(request: request) {
                store.markWishlistResearchRequestReviewed(request)
              } onTask: {
                store.createReviewTask(
                  linkedEntityType: .wishlistItem,
                  linkedEntityID: request.wishlistItemID?.uuidString ?? request.id.uuidString,
                  label: request.itemName,
                  summary: "Prepare future comparison-agent brief: confirm AUD budget, seller criteria, postage timing, trust evidence, and no-purchase boundaries before live research.",
                  priority: request.isAgentBriefReady ? .normal : .high,
                  assignee: "Wishlist review"
                )
              } onDraft: {
                store.createWishlistResearchBriefDraft(request)
              }
            }
          }
        }

        if !missingResearchItems.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Items without a research brief")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            ForEach(missingResearchItems.prefix(3)) { item in
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: "star.square.fill")
                  .foregroundStyle(.blue)
                  .frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                  Text(item.itemName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                  Text("Create a comparison plan before this can be handed to a future agent.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Create brief", systemImage: "list.bullet.clipboard") {
                  store.createWishlistComparisonPlan(item)
                  store.createWishlistResearchRequest(from: item)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
              }
              .padding(8)
              .background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }
      }
    }
  }

  private var wishlistAgentBatchBriefPanel: some View {
    let requests = store.wishlistResearchRequests
    let ready = requests.filter(\.isAgentBriefReady)
    let usable = ready.isEmpty ? requests.filter { !$0.requestStatus.localizedCaseInsensitiveContains("blocked") } : ready
    let scopeGaps = requests.reduce(0) { $0 + $1.agentBriefGaps.count }
    let lastBatchDraft = store.draftMessages.first { draft in
      draft.linkedEntityType == .wishlistItem
        && draft.linkedEntityID == "wishlist-research-batch"
    }

    return SettingsPanel(title: "Batch comparison brief", symbol: "doc.text.magnifyingglass") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Create one local draft packet for future comparison work across Wishlist items. The packet is designed for later agent or human research: compare AU and overseas sellers, estimate AUD landed totals, include postage timing, and reject low-trust sellers.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Requests", "\(requests.count)", requests.isEmpty ? .secondary : .blue),
          ("Ready", "\(ready.count)", ready.isEmpty ? .secondary : .green),
          ("Included now", "\(min(usable.count, 12))", usable.isEmpty ? .secondary : .teal),
          ("Scope gaps", "\(scopeGaps)", scopeGaps == 0 ? .green : .orange)
        ])

        HStack(alignment: .top, spacing: 10) {
          Image(systemName: usable.isEmpty ? "exclamationmark.triangle.fill" : "checklist.checked")
            .foregroundStyle(usable.isEmpty ? .orange : .green)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(usable.isEmpty ? "No batch-ready research requests" : "Batch packet can be drafted")
              .font(.subheadline.weight(.semibold))
            Text(usable.isEmpty ? "Create or review Wishlist research requests first. Blocked requests are intentionally excluded." : "The draft includes up to 12 \(ready.isEmpty ? "unblocked" : "agent-ready") requests, required output fields, seller trust rules, postage expectations, and no-purchase boundaries.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .padding(10)
        .background((usable.isEmpty ? Color.orange : Color.green).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        if let lastBatchDraft {
          VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
              Image(systemName: "star.square.on.square.fill")
                .foregroundStyle(lastBatchDraft.status.color)
                .frame(width: 24, height: 24)
              VStack(alignment: .leading, spacing: 4) {
                Text("Latest batch draft")
                  .font(.subheadline.weight(.semibold))
                Text(lastBatchDraft.subject)
                  .font(.caption.weight(.semibold))
                  .lineLimit(2)
                Text(wishlistBatchDraftNextAction(lastBatchDraft))
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
              Spacer(minLength: 8)
              Badge(lastBatchDraft.status.rawValue, color: lastBatchDraft.status.color)
            }

            CompactMetadataGrid(minimumWidth: 145) {
              Badge(lastBatchDraft.reviewState.rawValue, color: lastBatchDraft.reviewState.color)
              Label(lastBatchDraft.createdDate, systemImage: "calendar")
                .font(.caption)
                .foregroundStyle(.secondary)
              Label("Local draft only", systemImage: "lock.doc.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            CompactActionRow {
              Button("Ready", systemImage: "checkmark.seal.fill") {
                store.markDraftMessageReady(lastBatchDraft)
              }
              .disabled(lastBatchDraft.status == .ready)
              Button("Sent locally", systemImage: "paperplane.fill") {
                store.markDraftMessageSentLocally(lastBatchDraft)
              }
              .disabled(lastBatchDraft.status == .sentLocally)
              Button("Reopen", systemImage: "arrow.uturn.backward.circle.fill") {
                store.reopenDraftMessage(lastBatchDraft)
              }
              .disabled(lastBatchDraft.status == .reopened)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
          }
          .padding(10)
          .background(lastBatchDraft.status.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        if !usable.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Included examples")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            ForEach(usable.prefix(4)) { request in
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: request.isAgentBriefReady ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                  .foregroundStyle(request.isAgentBriefReady ? .green : .orange)
                  .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                  Text(request.itemName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                  Text(request.isAgentBriefReady ? "Ready packet: AUD, postage, trust, region, and output boundaries present." : request.agentBriefNextAction)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Badge(request.agentBriefStatus, color: request.isAgentBriefReady ? .green : .orange)
              }
              .padding(8)
              .background(.background, in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }

        CompactActionRow {
          Button("Create batch brief draft", systemImage: "doc.badge.plus") {
            store.createWishlistBatchResearchBriefDraft()
          }
          .disabled(usable.isEmpty)
          NavigationLink {
            CommunicationView(store: store)
          } label: {
            Label("Open Drafts", systemImage: "envelope.open.fill")
          }
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Audit trail", systemImage: "list.clipboard.fill")
          }
        }
        .buttonStyle(.bordered)

        Text("Still not active: live retailer search, exchange-rate lookup, postage APIs, seller trust services, browser automation, account login, checkout, payment, order monitoring, or external agents.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func wishlistBatchDraftNextAction(_ draft: DraftMessage) -> String {
    switch draft.status {
    case .draft:
      return "Review the packet before handing it to a future research agent or copying it into a manual comparison workflow."
    case .ready:
      return "Use the packet outside ParcelOps, then mark it sent locally once the handoff is complete."
    case .sentLocally:
      return "The packet is no longer active in Tasks. Reopen it only if the comparison research needs another pass."
    case .reopened:
      return "Update the batch brief or Wishlist request scope, then mark it ready again."
    }
  }

  private var wishlistCaptureCandidatesPanel: some View {
    SettingsPanel(title: "Capture candidate staging", symbol: "puzzlepiece.extension.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Review local product-page capture candidates before they become Wishlist items. This is the boundary a future browser extension or share flow can write into; this screen does not install an extension, scrape pages, or sync with a browser.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        CompactMetadataGrid(minimumWidth: 140) {
          Badge("\(store.wishlistCaptureCandidates.count) staged", color: store.wishlistCaptureCandidates.isEmpty ? .secondary : .blue)
          Badge("\(store.wishlistCaptureCandidates.filter { $0.reviewState == .needsReview }.count) needs review", color: store.wishlistCaptureCandidates.contains { $0.reviewState == .needsReview } ? .orange : .green)
          Badge("\(store.wishlistCaptureCandidates.filter { $0.source == .browserExtension }.count) extension path", color: .teal)
        }

        CompactActionRow {
          Button("Add browser capture placeholder", systemImage: "puzzlepiece.extension.fill") {
            store.addBrowserExtensionWishlistCapturePlaceholder()
          }
        }
        .buttonStyle(.bordered)

        if store.wishlistCaptureCandidates.isEmpty {
          MVPEmptyState(
            title: "No staged capture candidates",
            detail: "Use the browser capture placeholder to test the future extension handoff without reading any browser page or contacting external services.",
            symbol: "puzzlepiece.extension.fill",
            actionTitle: "Add placeholder",
            action: store.addBrowserExtensionWishlistCapturePlaceholder
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 230 : 320), spacing: 10)], spacing: 10) {
            ForEach(store.wishlistCaptureCandidates) { capture in
              WishlistCaptureCandidateRow(capture: capture) {
                store.promoteWishlistCaptureToItem(capture)
              } onDismiss: {
                store.dismissWishlistCapture(capture)
              }
            }
          }
        }
      }
    }
  }

  private var wishlistResearchRequestsPanel: some View {
    let openRequests = store.wishlistResearchRequests.filter { $0.reviewState != .accepted }
    let blockedRequests = store.wishlistResearchRequests.filter { $0.requestStatus.localizedCaseInsensitiveContains("blocked") }
    let readyRequests = store.wishlistResearchRequests.filter(\.isAgentBriefReady)
    let scopeGapRequests = store.wishlistResearchRequests.filter { !$0.isAgentBriefReady }

    return SettingsPanel(title: "Future agent research queue", symbol: "list.bullet.clipboard.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("These are local briefs for a future comparison agent. Each request defines what to compare across Australian and overseas retailers, which postage details to capture, what seller trust evidence is required, and what the agent must not do before buying.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Research briefs", "\(store.wishlistResearchRequests.count)", store.wishlistResearchRequests.isEmpty ? .secondary : .blue),
          ("Open", "\(openRequests.count)", openRequests.isEmpty ? .green : .orange),
          ("Agent-ready", "\(readyRequests.count)", readyRequests.isEmpty ? .secondary : .green),
          ("Scope gaps", "\(scopeGapRequests.count)", scopeGapRequests.isEmpty ? .green : .orange),
          ("Blocked", "\(blockedRequests.count)", blockedRequests.isEmpty ? .green : .red)
        ])

        if !scopeGapRequests.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Briefs needing scope")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            ForEach(scopeGapRequests.prefix(4)) { request in
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundStyle(.orange)
                  .frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                  Text(request.itemName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                  Text(request.agentBriefNextAction)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Badge(request.agentBriefStatus, color: request.isAgentBriefReady ? .green : .orange)
              }
              .padding(8)
              .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }

        if store.wishlistResearchRequests.isEmpty {
          MVPEmptyState(
            title: "No research briefs yet",
            detail: "Use Compare on a Wishlist item to create a local brief for future seller research. No live web search or external agent runs from this screen.",
            symbol: "list.bullet.clipboard.fill"
          )
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 240 : 340), spacing: 10)], spacing: 10) {
            ForEach(store.wishlistResearchRequests) { request in
              WishlistResearchRequestRow(request: request) {
                store.markWishlistResearchRequestReviewed(request)
              } onBlock: {
                store.blockWishlistResearchRequest(request)
              } onTask: {
                store.createReviewTask(
                  linkedEntityType: .wishlistItem,
                  linkedEntityID: request.wishlistItemID?.uuidString ?? request.id.uuidString,
                  label: request.itemName,
                  summary: "Prepare wishlist comparison research: \(request.itemName). Confirm seller criteria, AUD landed cost, postage timing, returns/warranty, and seller trust requirements before any purchase.",
                  priority: request.reviewState == .needsReview ? .high : .normal,
                  assignee: "Wishlist review"
                )
              } onDraft: {
                store.createWishlistResearchBriefDraft(request)
              } onRemove: {
                store.removeWishlistResearchRequest(request)
              }
            }
          }
        }

        Text("Not active yet: browsing retailer sites, exchange-rate lookup, postage quote APIs, seller trust services, browser automation, account login, checkout, payment, or background monitoring.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  @ViewBuilder
  private var gmailWishlistFocusPanel: some View {
    if !store.gmailMailboxConnections.isEmpty || !gmailWishlistCandidateEmails.isEmpty {
      SettingsPanel(title: "Gmail wishlist focus", symbol: "envelope.badge.shield.half.filled") {
        VStack(alignment: .leading, spacing: 12) {
          Text("Gmail messages sometimes contain purchase intent rather than active orders. Keep those out of Orders until a person confirms the item, storefront, owner, and whether it should become a wishlist item.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          MetricStrip(items: [
            ("Gmail candidates", "\(gmailWishlistCandidateEmails.count)", gmailWishlistCandidateEmails.isEmpty ? .secondary : .blue),
            ("Ready signals", "\(gmailWishlistReadyCount)", gmailWishlistReadyCount == 0 ? .secondary : .teal),
            ("Wishlist items", "\(store.wishlistItems.count)", store.wishlistItems.isEmpty ? .secondary : .green),
            ("Needs review", "\(store.wishlistItems.filter { $0.status.localizedCaseInsensitiveContains("review") }.count)", store.wishlistItems.contains { $0.status.localizedCaseInsensitiveContains("review") } ? .orange : .green)
          ])

          if gmailWishlistCandidateEmails.isEmpty {
            Label("No Gmail-origin purchase-intent candidates are visible. Use Mailbox Monitor for Gmail refresh and classifier review before adding wishlist items manually.", systemImage: "tray.and.arrow.down.fill")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
          } else {
            VStack(alignment: .leading, spacing: 8) {
              Text("Review Gmail purchase signals")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
              LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 190 : 260), spacing: 10)], spacing: 10) {
                ForEach(gmailWishlistCandidateEmails.prefix(4)) { email in
                  VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                      Label("Gmail intake", systemImage: "envelope.badge.shield.half.filled")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                      Spacer(minLength: 8)
                      Badge(gmailWishlistCandidateLabel(for: email), color: gmailWishlistCandidateScore(for: email) > 2 ? .orange : .teal)
                    }
                    Text(email.subject.isPlaceholderValidationValue ? email.detectedMerchant : email.subject)
                      .font(.caption.weight(.semibold))
                      .lineLimit(2)
                    Text(gmailWishlistCandidateDetail(for: email))
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                      .fixedSize(horizontal: false, vertical: true)
                  }
                  .padding(10)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
              }
            }
          }

          CompactActionRow {
            Button("Manual wishlist item", systemImage: "plus") {
              store.addManualWishlistItemPlaceholder()
            }
            NavigationLink {
              MailboxView(store: store)
            } label: {
              Label("Mailbox Monitor", systemImage: "server.rack")
            }
            NavigationLink {
              InboxView(store: store)
            } label: {
              Label("Inbox", systemImage: "tray.full.fill")
            }
          }
          .buttonStyle(.bordered)

          Text("This panel reads only local Gmail intake summaries. It does not fetch Gmail, create wishlist items automatically, open shopfronts automatically, store token values, or mutate mailbox messages.")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }

  private func gmailWishlistCandidateScore(for email: ForwardedEmailIntake) -> Int {
    let text = [email.subject, email.rawBodyPreview, email.detectedMerchant, email.detectedDestinationAddress]
      .joined(separator: " ")
      .localizedLowercase
    var score = 0
    if text.contains("wishlist") || text.contains("wish list") { score += 3 }
    if text.contains("want to buy") || text.contains("would like to buy") || text.contains("looking to buy") { score += 3 }
    if text.contains("purchase") || text.contains("quote") || text.contains("price") || text.contains("stock") { score += 2 }
    if text.contains("recommend") || text.contains("replacement") || text.contains("supplier") || text.contains("vendor") { score += 1 }
    if !email.detectedMerchant.isPlaceholderValidationValue { score += 1 }
    if !email.detectedOrderNumber.isPlaceholderValidationValue || !email.detectedTrackingNumber.isPlaceholderValidationValue { score -= 3 }
    return max(score, 0)
  }

  private func gmailWishlistCandidateLabel(for email: ForwardedEmailIntake) -> String {
    let score = gmailWishlistCandidateScore(for: email)
    if score >= 4 { return "Likely wishlist" }
    if score > 0 { return "Possible wishlist" }
    return "Review"
  }

  private func gmailWishlistCandidateDetail(for email: ForwardedEmailIntake) -> String {
    var parts: [String] = []
    if !email.detectedMerchant.isPlaceholderValidationValue { parts.append("merchant: \(email.detectedMerchant)") }
    if !email.detectedOrderNumber.isPlaceholderValidationValue { parts.append("order already detected") }
    if !email.detectedTrackingNumber.isPlaceholderValidationValue { parts.append("tracking already detected") }
    if parts.isEmpty { parts.append("confirm item, storefront, and purchase intent before adding a manual wishlist item") }
    return parts.joined(separator: "; ")
  }

  private func uniqueWishlistItems(_ items: [WishlistItem]) -> [WishlistItem] {
    var seen = Set<UUID>()
    return items.filter { item in
      if seen.contains(item.id) { return false }
      seen.insert(item.id)
      return true
    }
  }
}

private struct WishlistPurchaseReleaseGate: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var stage: String
  var detail: String
  var actionTitle: String
  var actionSymbol: String
  var checks: [(String, Bool)]
  var tone: Color
  var sortPriority: Int

  var isReadyForManualPurchase: Bool {
    stage == "Ready for manual purchase"
  }

  var isLinkedOrder: Bool {
    stage == "Linked order released"
  }
}

private struct WishlistPurchaseOperatorChecklist: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var stage: String
  var detail: String
  var selectedSeller: String
  var totalAUD: String
  var postage: String
  var trust: String
  var handoff: String
  var manualChecks: [(String, Bool)]
  var blockers: [String]
  var liveVerification: [String]
  var tone: Color
  var actionTitle: String
  var actionSymbol: String
  var sortPriority: Int
}

private struct WishlistPurchaseOperatorChecklistRow: View {
  var checklist: WishlistPurchaseOperatorChecklist
  var onAction: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "checklist.checked")
          .foregroundStyle(checklist.tone)
          .frame(width: 22, height: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(checklist.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(checklist.selectedSeller)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text(checklist.detail)
            .font(.caption.weight(.semibold))
            .foregroundStyle(checklist.tone)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(checklist.stage, color: checklist.tone)
      }

      CompactMetadataGrid(minimumWidth: 126) {
        WishlistMatrixMetric(title: "AUD", value: checklist.totalAUD, symbol: "dollarsign.circle.fill")
        WishlistMatrixMetric(title: "Postage", value: checklist.postage, symbol: "shippingbox.fill")
        WishlistMatrixMetric(title: "Trust", value: checklist.trust, symbol: "shield.checkered")
        WishlistMatrixMetric(title: "Handoff", value: checklist.handoff, symbol: "person.crop.circle.badge.checkmark")
      }

      VStack(alignment: .leading, spacing: 6) {
        Text("Local checklist")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        CompactMetadataGrid(minimumWidth: 118) {
          ForEach(checklist.manualChecks, id: \.0) { check in
            Label(check.0, systemImage: check.1 ? "checkmark.circle.fill" : "circle")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(check.1 ? Color.green : Color.secondary)
              .lineLimit(1)
          }
        }
      }

      if !checklist.blockers.isEmpty {
        Text("Before buying: \(checklist.blockers.prefix(4).joined(separator: ", ")).")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }

      VStack(alignment: .leading, spacing: 5) {
        Label("Manual live verification", systemImage: "hand.raised.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 6)], alignment: .leading, spacing: 6) {
          ForEach(checklist.liveVerification, id: \.self) { label in
            Badge(label, color: .orange)
          }
        }
      }

      CompactActionRow {
        Button(checklist.actionTitle, systemImage: checklist.actionSymbol, action: onAction)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .background(checklist.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPurchaseAccountLedgerEntry: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var handoff: WishlistPurchaseHandoff?
  var linkedOrder: TrackedOrder?
  var candidateCount: Int
  var stage: String
  var detail: String
  var tone: Color
  var actionTitle: String
  var actionSymbol: String
  var sortPriority: Int
}

private struct WishlistPurchaseAccountLedgerRow: View {
  var entry: WishlistPurchaseAccountLedgerEntry
  var onAction: () -> Void
  var onPurchased: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var seller: String {
    entry.handoff?.sellerName ?? entry.item.purchaseDecision?.selectedSellerName ?? entry.item.storefront
  }

  private var account: String {
    entry.handoff?.accountLabel ?? "\(entry.item.owner) account to confirm"
  }

  private var orderSummary: String {
    entry.linkedOrder?.orderNumber ?? "No linked order"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "person.crop.circle.badge.clock.fill")
          .foregroundStyle(entry.tone)
          .frame(width: 22, height: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("\(seller) • \(account)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text(entry.detail)
            .font(.caption.weight(.semibold))
            .foregroundStyle(entry.tone)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(entry.stage, color: entry.tone)
      }

      CompactMetadataGrid(minimumWidth: 126) {
        WishlistMatrixMetric(title: "Seller", value: seller, symbol: "storefront.fill")
        WishlistMatrixMetric(title: "Account", value: account, symbol: "person.crop.circle.badge.key.fill")
        WishlistMatrixMetric(title: "Order", value: orderSummary, symbol: "link")
        WishlistMatrixMetric(title: "Candidates", value: "\(entry.candidateCount) Inbox", symbol: "envelope.badge.fill")
      }

      if let handoff = entry.handoff {
        VStack(alignment: .leading, spacing: 5) {
          Label("Order-watch notes", systemImage: "eye.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Text(handoff.expectedOrderSignals)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(3)
          Text(handoff.orderWatchStatus)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(entry.tone)
            .fixedSize(horizontal: false, vertical: true)
        }
      } else {
        Text("No purchase handoff exists yet. Prepare one before buying externally so the account label and expected confirmation text are captured locally.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.purple)
          .fixedSize(horizontal: false, vertical: true)
      }

      Text("Local-only ledger: no account login, checkout, payment, mailbox mutation, carrier booking, or background monitoring occurs here.")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button(entry.actionTitle, systemImage: entry.actionSymbol, action: onAction)
        Button("Purchased", systemImage: "bag.fill", action: onPurchased)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPostPurchaseOrderWatchEntry: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var handoff: WishlistPurchaseHandoff
  var matches: [ForwardedEmailIntake]
  var stage: String
  var detail: String
  var tone: Color
  var sortPriority: Int
}

private struct WishlistPurchaseOperationsHandoffEntry: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var linkedOrder: TrackedOrder?
  var stage: String
  var detail: String
  var gaps: [String]
  var inspectionCount: Int
  var receiptCount: Int
  var storageCount: Int
  var custodyCount: Int
  var labelCount: Int
  var scanCount: Int
  var manifestCount: Int
  var dispatchCount: Int
  var tone: Color
  var actionTitle: String
  var actionSymbol: String
  var sortPriority: Int
}

private struct WishlistPurchaseOperationsHandoffRow: View {
  var entry: WishlistPurchaseOperationsHandoffEntry
  var onAction: () -> Void
  var onTask: () -> Void
  var onFocus: () -> Void

  private var orderValue: String {
    entry.linkedOrder?.orderNumber ?? "Not linked"
  }

  private var gapSummary: String {
    entry.gaps.isEmpty ? "No downstream setup gaps detected." : "Next gaps: \(entry.gaps.prefix(5).joined(separator: ", "))."
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "arrow.triangle.branch")
          .foregroundStyle(entry.tone)
          .frame(width: 22, height: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("\(entry.item.storefront) • \(entry.item.owner)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text(entry.detail)
            .font(.caption.weight(.semibold))
            .foregroundStyle(entry.tone)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(entry.stage, color: entry.tone)
      }

      CompactMetadataGrid(minimumWidth: 118) {
        WishlistMatrixMetric(title: "Order", value: orderValue, symbol: "link")
        WishlistMatrixMetric(title: "Receiving", value: "\(entry.inspectionCount)", symbol: "checkmark.seal.fill")
        WishlistMatrixMetric(title: "Inventory", value: "\(entry.receiptCount)", symbol: "shippingbox.and.arrow.backward.fill")
        WishlistMatrixMetric(title: "Storage", value: "\(entry.storageCount)", symbol: "archivebox.fill")
        WishlistMatrixMetric(title: "Custody", value: "\(entry.custodyCount)", symbol: "person.2.badge.gearshape.fill")
        WishlistMatrixMetric(title: "Label", value: "\(entry.labelCount)", symbol: "tag.square.fill")
        WishlistMatrixMetric(title: "Manual check", value: "\(entry.scanCount)", symbol: "checklist.checked")
        WishlistMatrixMetric(title: "Dispatch", value: "\(entry.manifestCount)/\(entry.dispatchCount)", symbol: "paperplane.fill")
      }

      Text(gapSummary)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(entry.gaps.isEmpty ? Color.green : entry.tone)
        .fixedSize(horizontal: false, vertical: true)

      Text("Local downstream planning only. Use this to stage records, not to receive stock, scan labels, book carriers, or change mailbox/order systems.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button(entry.actionTitle, systemImage: entry.actionSymbol, action: onAction)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPipelineItem: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var stage: String
  var detail: String
  var nextAction: String
  var symbol: String
  var tone: Color
  var sortPriority: Int
}

private struct WishlistPipelineRow: View {
  var pipelineItem: WishlistPipelineItem
  var onAction: () -> Void
  var onFocus: () -> Void

  private var blockerSummary: String {
    let blockers = pipelineItem.item.operatorPurchaseBlockers
    guard !blockers.isEmpty else { return "No local blocker promoted." }
    return blockers.prefix(3).joined(separator: " • ")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: pipelineItem.symbol)
          .foregroundStyle(pipelineItem.tone)
          .frame(width: 22, height: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(pipelineItem.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("\(pipelineItem.item.storefront) • \(pipelineItem.item.owner)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text(pipelineItem.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(pipelineItem.stage, color: pipelineItem.tone)
      }

      Text(blockerSummary)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(2)

      CompactActionRow {
        Button(pipelineItem.nextAction, systemImage: "arrow.forward.circle", action: onAction)
        Button("Focus", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
    }
    .padding(10)
    .background(pipelineItem.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPurchaseReleaseChecklistRow: View {
  var gate: WishlistPurchaseReleaseGate
  var onAction: () -> Void
  var onFocus: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "checkmark.seal.text.page.fill")
          .foregroundStyle(gate.tone)
          .frame(width: 22, height: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(gate.item.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text("\(gate.item.storefront) • \(gate.item.owner)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text(gate.detail)
            .font(.caption.weight(.semibold))
            .foregroundStyle(gate.tone)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(gate.stage, color: gate.tone)
      }

      CompactMetadataGrid(minimumWidth: 92) {
        ForEach(gate.checks, id: \.0) { check in
          Label(check.0, systemImage: check.1 ? "checkmark.circle.fill" : "circle")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(check.1 ? Color.green : Color.secondary)
            .lineLimit(1)
        }
      }

      CompactActionRow {
        Button(gate.actionTitle, systemImage: gate.actionSymbol, action: onAction)
        Button("Focus", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
    }
    .padding(10)
    .background(gate.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistReadinessRow: View {
  var item: WishlistItem

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: item.source.symbol)
        .foregroundStyle(.teal)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(item.itemName)
          .font(.caption.weight(.semibold))
        Text(readinessDetail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 8)
      Badge(item.status, color: item.status.localizedCaseInsensitiveContains("review") ? .orange : .blue)
    }
    .padding(8)
    .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
  }

  private var readinessDetail: String {
    if item.capturedDetail.localizedCaseInsensitiveContains("placeholder") {
      return "Placeholder capture. Confirm item, storefront, owner, and purchase intent before creating an order."
    }
    if item.storefront.isPlaceholderValidationValue {
      return "Storefront needs review before this becomes an order."
    }
    if item.estimatedCost.isPlaceholderValidationValue {
      return "Estimated cost needs review before handoff."
    }
    if item.status.localizedCaseInsensitiveContains("review") {
      return "Review status is still open. Confirm details before linking or converting."
    }
    return "Ready for local link or conversion when purchase intent is confirmed."
  }
}

private struct WishlistPurchaseBlockerQueueRow: View {
  var item: WishlistItem
  var actionTitle: String
  var actionSymbol: String
  var onFocus: () -> Void
  var onAction: () -> Void

  private var blockerSummary: String {
    item.operatorPurchaseBlockers.prefix(3).joined(separator: ", ")
  }

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "star.square.fill")
        .foregroundStyle(.orange)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 4) {
        Text(item.itemName)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text("\(item.storefront) • \(item.owner)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        Text("Blockers: \(blockerSummary)")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 8)
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(item.operatorPurchaseBlockers.count)", color: .orange)
        Button("Focus", systemImage: "scope", action: onFocus)
          .buttonStyle(.bordered)
          .labelStyle(.iconOnly)
          .help("Filter Wishlist to this item")
        Button(actionTitle, systemImage: actionSymbol, action: onAction)
          .buttonStyle(.borderedProminent)
          .labelStyle(.iconOnly)
          .help(actionTitle)
      }
    }
    .padding(8)
    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct CaptureChannelRow: View {
  var symbol: String
  var title: String
  var detail: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: symbol)
        .foregroundStyle(.teal)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(10)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistSellerOptionIssue: Identifiable {
  var id: String {
    "\(item.id.uuidString)-\(option.id.uuidString)-\(kind)"
  }

  var item: WishlistItem
  var option: WishlistComparisonOption
  var kind: String
  var title: String
  var detail: String
  var symbol: String
  var color: Color
}

private struct WishlistSellerSafetyRubricEntry: Identifiable {
  var id: String {
    "\(item.id.uuidString)-\(option.id.uuidString)-safety"
  }

  var item: WishlistItem
  var option: WishlistComparisonOption
  var isPreferred: Bool
  var decision: String
  var detail: String
  var gaps: [String]
  var tone: Color
  var sortPriority: Int
}

private struct WishlistSellerSafetyRubricRow: View {
  var entry: WishlistSellerSafetyRubricEntry
  var onAction: () -> Void
  var onFocus: () -> Void

  private var actionTitle: String {
    if entry.decision == "Acceptable local candidate" { return "Readiness" }
    if entry.decision == "Reject or manual review" { return "Evidence task" }
    return "Re-score"
  }

  private var actionSymbol: String {
    if entry.decision == "Acceptable local candidate" { return "checklist.checked" }
    if entry.decision == "Reject or manual review" { return "checklist" }
    return "chart.bar.doc.horizontal"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.decision == "Acceptable local candidate" ? "shield.checkered" : "exclamationmark.shield.fill")
          .foregroundStyle(entry.tone)
          .frame(width: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.option.sellerName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(entry.item.itemName)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Text(entry.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 6) {
          Badge(entry.decision, color: entry.tone)
          if entry.isPreferred {
            Badge("Preferred", color: .purple)
          }
        }
      }

      CompactMetadataGrid(minimumWidth: 120) {
        Label(entry.option.estimatedAUDTotal, systemImage: "dollarsign.circle.fill")
        Label("\(entry.option.postageCost), \(entry.option.postageTime)", systemImage: "shippingbox.fill")
        Label(entry.option.trustRating, systemImage: "shield.lefthalf.filled")
        Label("Score \(entry.option.operatorSellerMatrixScore)", systemImage: "gauge.with.dots.needle.50percent")
      }
      .font(.caption2)
      .foregroundStyle(.secondary)

      if !entry.gaps.isEmpty {
        Text("Missing: \(entry.gaps.joined(separator: ", "))")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      CompactActionRow {
        Button(actionTitle, systemImage: actionSymbol, action: onAction)
        Button("Focus", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistSellerOptionIssueRow: View {
  var issue: WishlistSellerOptionIssue

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: issue.symbol)
        .foregroundStyle(issue.color)
        .frame(width: 22)
      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(issue.title)
            .font(.caption.weight(.semibold))
          Badge(issue.kind, color: issue.color)
        }
        Text("\(issue.item.itemName) • \(issue.option.sellerName)")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        Text(issue.detail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        Text("AUD \(issue.option.estimatedAUDTotal) • postage \(issue.option.postageCost), \(issue.option.postageTime) • trust \(issue.option.trustRating)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(issue.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistCaptureCandidateRow: View {
  var capture: WishlistCaptureCandidate
  var onPromote: () -> Void
  var onDismiss: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: capture.source.symbol)
          .foregroundStyle(.teal)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(capture.pageTitle.isPlaceholderValidationValue ? "Captured product page" : capture.pageTitle)
            .font(.headline)
            .lineLimit(2)
          Text(capture.productSummary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(capture.reviewState.rawValue, color: capture.reviewState == .needsReview ? .orange : .blue)
      }

      CompactMetadataGrid(minimumWidth: 120) {
        Label(capture.source.rawValue, systemImage: capture.source.symbol)
        Label(capture.detectedStorefront, systemImage: "storefront.fill")
        Label(capture.detectedPrice, systemImage: "dollarsign.circle.fill")
        Label(capture.capturedDate, systemImage: "clock.fill")
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      if !capture.pageURL.isPlaceholderValidationValue {
        Text(capture.pageURL)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }

      Text(capture.notes)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button("Promote to Wishlist", systemImage: "star.square.fill", action: onPromote)
          .buttonStyle(.borderedProminent)
        Button("Dismiss", systemImage: "xmark.circle", action: onDismiss)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistResearchRequestRow: View {
  var request: WishlistResearchRequest
  var onReviewed: () -> Void
  var onBlock: () -> Void
  var onTask: () -> Void
  var onDraft: () -> Void
  var onRemove: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "list.bullet.clipboard.fill")
          .foregroundStyle(.teal)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(request.itemName)
            .font(.headline)
            .lineLimit(2)
          Text(request.requestStatus)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 6) {
          Badge(request.agentBriefStatus, color: request.isAgentBriefReady ? .green : (request.requestStatus.localizedCaseInsensitiveContains("blocked") ? .red : .orange))
          Badge(request.reviewState.rawValue, color: request.reviewState == .needsReview ? .orange : .green)
        }
      }

      CompactMetadataGrid(minimumWidth: 145) {
        Label(request.maxBudgetAUD, systemImage: "dollarsign.circle.fill")
        Label(request.createdDate, systemImage: "clock.fill")
        Label(request.lastReviewedDate, systemImage: "checkmark.seal.fill")
        Label(request.agentBriefGaps.isEmpty ? "No scope gaps" : "\(request.agentBriefGaps.count) scope gaps", systemImage: request.agentBriefGaps.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 6) {
        WishlistResearchLine(title: "Scope", detail: request.regionScope)
        WishlistResearchLine(title: "Seller criteria", detail: request.sellerCriteria)
        WishlistResearchLine(title: "Postage", detail: request.postageRequirements)
        WishlistResearchLine(title: "Trust", detail: request.trustRequirements)
      }

      if !request.sourceURL.isPlaceholderValidationValue {
        Text(request.sourceURL)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }

      VStack(alignment: .leading, spacing: 6) {
        Label("Agent packet preview", systemImage: "doc.text.magnifyingglass")
          .font(.caption.weight(.semibold))
          .foregroundStyle(request.isAgentBriefReady ? .green : .orange)
        Text(request.agentBriefNextAction)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(request.isAgentBriefReady ? .green : .orange)
          .fixedSize(horizontal: false, vertical: true)
        if !request.agentBriefGaps.isEmpty {
          Text("Missing: \(request.agentBriefGaps.joined(separator: ", "))")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Text("Output expected: seller/product link, listed currency, AUD landed total, postage cost/time, seller region, returns/warranty, trust evidence, safest recommendation.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(8)
      .background((request.isAgentBriefReady ? Color.green : Color.orange).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

      CompactActionRow {
        Button("Reviewed", systemImage: "checkmark.seal", action: onReviewed)
          .buttonStyle(.borderedProminent)
        Button("Block", systemImage: "exclamationmark.triangle", action: onBlock)
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist", action: onTask)
          .buttonStyle(.bordered)
        Button("Brief", systemImage: "doc.text", action: onDraft)
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", action: onRemove)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistAgentHandoffPacketRow: View {
  var request: WishlistResearchRequest
  var onReviewed: () -> Void
  var onTask: () -> Void
  var onDraft: () -> Void

  private var tone: Color {
    if request.requestStatus.localizedCaseInsensitiveContains("blocked") { return .red }
    return request.isAgentBriefReady ? .green : .orange
  }

  private var packetSummary: String {
    if request.isAgentBriefReady {
      return "Ready later for a live comparison agent once integration exists."
    }
    return request.agentBriefNextAction
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: request.isAgentBriefReady ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
          .foregroundStyle(tone)
          .frame(width: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(request.itemName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(packetSummary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(request.agentBriefStatus, color: tone)
      }

      CompactMetadataGrid(minimumWidth: 118) {
        Label(request.maxBudgetAUD, systemImage: "dollarsign.circle.fill")
        Label(request.reviewState.rawValue, systemImage: "checkmark.seal.fill")
        Label(request.agentBriefGaps.isEmpty ? "No gaps" : "\(request.agentBriefGaps.count) gaps", systemImage: request.agentBriefGaps.isEmpty ? "checkmark.circle.fill" : "circle")
      }
      .font(.caption2)
      .foregroundStyle(.secondary)

      Text("Scope: \(request.regionScope)")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(2)

      CompactActionRow {
        Button("Reviewed", systemImage: "checkmark.seal", action: onReviewed)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Brief draft", systemImage: "doc.text", action: onDraft)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistResearchLine: View {
  var title: String
  var detail: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.caption.weight(.semibold))
      Text(detail)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

private struct WishlistPlanningStep: View {
  var number: String
  var title: String
  var detail: String

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Text(number)
        .font(.caption.weight(.bold))
        .foregroundStyle(.white)
        .frame(width: 22, height: 22)
        .background(.teal, in: Circle())
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.caption.weight(.semibold))
        Text(detail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistComparisonMatrixEntry: Identifiable {
  var item: WishlistItem
  var option: WishlistComparisonOption
  var isPreferred: Bool

  var id: String {
    "\(item.id.uuidString)-\(option.id.uuidString)"
  }
}

private struct WishlistLandedCostReviewEntry: Identifiable {
  var item: WishlistItem
  var option: WishlistComparisonOption
  var badges: [String]
  var blockers: [String]
  var recommendation: String
  var tone: Color
  var sortPriority: Int

  var id: String {
    "\(item.id.uuidString)-\(option.id.uuidString)-landed-cost"
  }

  var isPreferred: Bool {
    badges.contains("Preferred")
  }

  var isCheapest: Bool {
    badges.contains("Cheapest")
  }

  var isSafest: Bool {
    badges.contains("Safest")
  }
}

private struct WishlistLandedCostReviewRow: View {
  var entry: WishlistLandedCostReviewEntry
  var onPrefer: () -> Void
  var onScore: () -> Void
  var onEvidenceTask: () -> Void
  var onFocus: () -> Void

  private var actionTitle: String {
    if entry.blockers.contains("seller trust") || entry.tone == .red { return "Evidence task" }
    if !entry.blockers.isEmpty { return "Re-score" }
    return entry.isPreferred ? "Preferred" : "Prefer"
  }

  private var actionSymbol: String {
    if entry.blockers.contains("seller trust") || entry.tone == .red { return "checklist" }
    if !entry.blockers.isEmpty { return "chart.bar.doc.horizontal" }
    return "checkmark.seal"
  }

  private func runPrimaryAction() {
    if entry.blockers.contains("seller trust") || entry.tone == .red {
      onEvidenceTask()
    } else if !entry.blockers.isEmpty {
      onScore()
    } else {
      onPrefer()
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.isCheapest ? "dollarsign.circle.fill" : "storefront.fill")
          .foregroundStyle(entry.tone)
          .frame(width: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.option.sellerName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
          Text(entry.item.itemName)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Text(entry.recommendation)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 6) {
          Badge(entry.option.recommendation, color: entry.tone)
          ForEach(entry.badges.prefix(2), id: \.self) { badge in
            Badge(badge, color: badge == "Preferred" ? .purple : .teal)
          }
        }
      }

      CompactMetadataGrid(minimumWidth: 125) {
        WishlistMatrixMetric(title: "AUD total", value: entry.option.estimatedAUDTotal, symbol: "dollarsign.circle.fill")
        WishlistMatrixMetric(title: "Postage", value: "\(entry.option.postageCost), \(entry.option.postageTime)", symbol: "shippingbox.fill")
        WishlistMatrixMetric(title: "Trust", value: entry.option.trustRating, symbol: "shield.checkered")
        WishlistMatrixMetric(title: "Score", value: "\(entry.option.operatorSellerMatrixScore)/100", symbol: "chart.bar.fill")
      }

      if !entry.blockers.isEmpty {
        VStack(alignment: .leading, spacing: 5) {
          Label("Blocks preference", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(entry.blockers.prefix(6), id: \.self) { blocker in
              Badge(blocker, color: .orange)
            }
          }
        }
      }

      if !entry.option.productURL.isPlaceholderValidationValue {
        Text(entry.option.productURL)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }

      Text(entry.option.trustNotes)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(3)

      CompactActionRow {
        Button(actionTitle, systemImage: actionSymbol, action: runPrimaryAction)
          .disabled(entry.isPreferred && entry.blockers.isEmpty)
        Button("Prefer", systemImage: "checkmark.seal", action: onPrefer)
          .disabled(entry.isPreferred)
        Button("Score", systemImage: "chart.bar.doc.horizontal", action: onScore)
        Button("Item", systemImage: "scope", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(entry.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistComparisonMatrixRow: View {
  var entry: WishlistComparisonMatrixEntry
  var onPreferred: () -> Void
  var onScore: () -> Void
  var onFocus: () -> Void

  private var scoreColor: Color {
    let score = entry.option.operatorSellerMatrixScore
    if score >= 75 { return .green }
    if score >= 55 { return .orange }
    return .red
  }

  private var evidenceSummary: String {
    let gaps = entry.option.operatorSellerEvidenceGaps
    if gaps.isEmpty {
      return entry.option.operatorSellerMatrixRecommendation
    }
    return "Needs \(gaps.prefix(3).joined(separator: ", "))"
  }

  private var evidenceColor: Color {
    entry.option.operatorSellerEvidenceGaps.isEmpty ? .secondary : .orange
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: entry.isPreferred ? "checkmark.seal.fill" : "storefront.fill")
          .foregroundStyle(entry.isPreferred ? .green : .teal)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 3) {
          Text(entry.option.sellerName)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
          Text(entry.item.itemName)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 4) {
          Badge("\(entry.option.operatorSellerMatrixScore)", color: scoreColor)
          if entry.isPreferred {
            Badge("Preferred", color: .green)
          }
        }
      }

      CompactMetadataGrid(minimumWidth: 120) {
        WishlistMatrixMetric(title: "AUD total", value: entry.option.estimatedAUDTotal, symbol: "dollarsign.circle.fill")
        WishlistMatrixMetric(title: "Postage", value: "\(entry.option.postageCost), \(entry.option.postageTime)", symbol: "shippingbox.fill")
        WishlistMatrixMetric(title: "Trust", value: entry.option.trustRating, symbol: "shield.lefthalf.filled")
        WishlistMatrixMetric(title: "Region", value: entry.option.sellerRegion, symbol: "globe.asia.australia.fill")
      }

      Text(evidenceSummary)
        .font(.caption)
        .foregroundStyle(evidenceColor)
        .fixedSize(horizontal: false, vertical: true)

      if let decisionReason = entry.option.decisionReason, !decisionReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Text(decisionReason)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(3)
      }

      CompactActionRow {
        Button(entry.isPreferred ? "Preferred" : "Prefer", systemImage: "checkmark.seal", action: onPreferred)
          .disabled(entry.isPreferred)
        Button("Score", systemImage: "chart.bar.doc.horizontal", action: onScore)
        Button("Item", systemImage: "line.3.horizontal.decrease.circle", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistMatrixMetric: View {
  var title: String
  var value: String
  var symbol: String

  var body: some View {
    HStack(alignment: .top, spacing: 6) {
      Image(systemName: symbol)
        .foregroundStyle(.teal)
        .frame(width: 16)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not recorded" : value)
          .font(.caption2)
          .lineLimit(2)
      }
    }
  }
}

private struct WishlistPurchaseDecisionSummary: Identifiable {
  var id: UUID { item.id }
  var item: WishlistItem
  var selectedSeller: String
  var totalAUD: String
  var postage: String
  var trust: String
  var rejectedOptions: String
  var verificationGaps: [String]
  var stage: String
  var detail: String
  var color: Color
  var actionTitle: String
  var actionSymbol: String
  var sortPriority: Int
}

private struct WishlistPurchaseDecisionSummaryRow: View {
  var summary: WishlistPurchaseDecisionSummary
  var onAction: () -> Void
  var onReviewTask: () -> Void
  var onNeedsReview: () -> Void
  var onFocus: () -> Void

  private var decision: WishlistPurchaseDecision? {
    summary.item.purchaseDecision
  }

  private var reviewLabel: String {
    decision?.reviewState.rawValue ?? "Not drafted"
  }

  private var notes: String {
    let raw = decision?.decisionNotes ?? summary.detail
    return raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? summary.detail : raw
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "checkmark.seal.fill")
          .foregroundStyle(summary.color)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 3) {
          Text(summary.item.itemName)
            .font(.caption.weight(.semibold))
            .lineLimit(2)
          Text(summary.selectedSeller)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Spacer(minLength: 8)
        Badge(summary.stage, color: summary.color)
      }

      Text(summary.detail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactMetadataGrid(minimumWidth: 126) {
        WishlistMatrixMetric(title: "AUD total", value: summary.totalAUD, symbol: "dollarsign.circle.fill")
        WishlistMatrixMetric(title: "Postage", value: summary.postage, symbol: "shippingbox.fill")
        WishlistMatrixMetric(title: "Trust", value: summary.trust, symbol: "shield.checkered")
        WishlistMatrixMetric(title: "Review", value: reviewLabel, symbol: "checkmark.seal")
      }

      if !summary.rejectedOptions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        VStack(alignment: .leading, spacing: 3) {
          Label("Alternates rejected or left behind", systemImage: "arrow.triangle.branch")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
          Text(summary.rejectedOptions)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(3)
        }
      }

      if !summary.verificationGaps.isEmpty {
        VStack(alignment: .leading, spacing: 5) {
          Label("Verify before buying", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(summary.verificationGaps.prefix(8), id: \.self) { gap in
              Badge(gap, color: .orange)
            }
          }
        }
      } else {
        Text("Local decision fields are complete. Still verify live price, stock, postage, account, payment, delivery address, returns, and warranty outside ParcelOps before buying.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.green)
          .fixedSize(horizontal: false, vertical: true)
      }

      Text(notes)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactActionRow {
        Button(summary.actionTitle, systemImage: summary.actionSymbol, action: onAction)
        Button("Task", systemImage: "checklist", action: onReviewTask)
        Button("Needs review", systemImage: "exclamationmark.triangle", action: onNeedsReview)
        Button("Item", systemImage: "line.3.horizontal.decrease.circle", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(summary.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPurchaseDecisionQueueRow: View {
  var item: WishlistItem
  var stageTitle: String
  var stageDetail: String
  var stageColor: Color
  var actionTitle: String
  var actionSymbol: String
  var onAction: () -> Void
  var onFocus: () -> Void

  private var preferredSeller: WishlistComparisonOption? {
    guard let preferredOptionID = item.preferredOptionID else { return nil }
    return item.comparisonOptions?.first { $0.id == preferredOptionID }
  }

  private var sellerSummary: String {
    if let preferredSeller {
      return "\(preferredSeller.sellerName) • \(preferredSeller.estimatedAUDTotal) • \(preferredSeller.postageTime)"
    }
    if let first = item.comparisonOptions?.first {
      return "\(first.sellerName) • preferred seller not selected"
    }
    return "No seller option selected"
  }

  private var reviewSummary: String {
    [
      item.purchaseReadiness,
      item.purchaseDecision?.decisionStatus,
      item.purchaseHandoff?.purchaseStatus
    ]
      .compactMap { value in
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
      }
      .prefix(2)
      .joined(separator: " • ")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "bag.badge.questionmark.fill")
          .foregroundStyle(stageColor)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 3) {
          Text(item.itemName)
            .font(.caption.weight(.semibold))
            .lineLimit(2)
          Text(sellerSummary)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        Spacer(minLength: 8)
        Badge(stageTitle, color: stageColor)
      }

      Text(stageDetail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if !reviewSummary.isEmpty {
        Text(reviewSummary)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(stageColor)
          .fixedSize(horizontal: false, vertical: true)
      }

      CompactActionRow {
        Button(actionTitle, systemImage: actionSymbol, action: onAction)
        Button("Item", systemImage: "line.3.horizontal.decrease.circle", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(stageColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPurchaseHandoffPackRow: View {
  var item: WishlistItem
  var linkedOrder: TrackedOrder?
  var gaps: [String]
  var accountCount: Int
  var costCount: Int
  var procurementCount: Int
  var receivingCount: Int
  var onNext: () -> Void
  var onTask: () -> Void
  var onOrderSeen: () -> Void
  var onFocus: () -> Void

  private var handoff: WishlistPurchaseHandoff? {
    item.purchaseHandoff
  }

  private var stageColor: Color {
    if gaps.isEmpty { return .green }
    if gaps.contains("order link") { return .teal }
    if gaps.contains("cost") || gaps.contains("procurement") || gaps.contains("receiving") { return .orange }
    return .purple
  }

  private var nextActionTitle: String {
    if gaps.contains("handoff") { return "Handoff" }
    if gaps.contains("cost") { return "Cost" }
    if gaps.contains("procurement") { return "Procurement" }
    if gaps.contains("receiving") { return "Receiving" }
    if gaps.contains("order link") { return "Order seen" }
    return "Task"
  }

  private var nextActionSymbol: String {
    if gaps.contains("handoff") { return "person.crop.circle.badge.checkmark" }
    if gaps.contains("cost") { return "dollarsign.circle.fill" }
    if gaps.contains("procurement") { return "cart.badge.plus" }
    if gaps.contains("receiving") { return "shippingbox.and.arrow.down.fill" }
    if gaps.contains("order link") { return "envelope.badge.fill" }
    return "checklist"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "shippingbox.and.arrow.backward.fill")
          .foregroundStyle(stageColor)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 3) {
          Text(item.itemName)
            .font(.caption.weight(.semibold))
            .lineLimit(2)
          Text(handoff?.sellerName ?? item.purchaseDecision?.selectedSellerName ?? item.storefront)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Spacer(minLength: 8)
        Badge(gaps.isEmpty ? "Pack ready" : "\(gaps.count) gaps", color: stageColor)
      }

      Text(handoff?.purchaseStatus ?? item.purchaseReadiness ?? "Purchase handoff not prepared")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactMetadataGrid(minimumWidth: 120) {
        WishlistMatrixMetric(title: "Account", value: accountCount == 0 ? handoff?.accountLabel ?? "To confirm" : "\(accountCount) matched", symbol: "person.crop.circle.badge.key.fill")
        WishlistMatrixMetric(title: "Cost", value: costCount == 0 ? "Missing" : "\(costCount) linked", symbol: "dollarsign.circle.fill")
        WishlistMatrixMetric(title: "Procurement", value: procurementCount == 0 ? "Missing" : "\(procurementCount) linked", symbol: "cart.badge.plus")
        WishlistMatrixMetric(title: "Receiving", value: receivingCount == 0 ? "Missing" : "\(receivingCount) linked", symbol: "shippingbox.and.arrow.down.fill")
        WishlistMatrixMetric(title: "Order", value: linkedOrder?.orderNumber ?? "Not linked", symbol: "link")
      }

      if !gaps.isEmpty {
        Text("Next setup: \(gaps.prefix(4).joined(separator: ", ")).")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(stageColor)
          .fixedSize(horizontal: false, vertical: true)
      }

      CompactActionRow {
        Button(nextActionTitle, systemImage: nextActionSymbol, action: onNext)
        Button("Task", systemImage: "checklist", action: onTask)
        Button("Order seen", systemImage: "envelope.badge.fill", action: onOrderSeen)
        Button("Item", systemImage: "line.3.horizontal.decrease.circle", action: onFocus)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(stageColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct WishlistItemRow: View {
  var item: WishlistItem
  var linkedOrder: TrackedOrder?
  var store: ParcelOpsStore?
  var confirmationMatches: [ForwardedEmailIntake] = []
  var suggestedAccounts: [AccountCredentialRecord] = []
  var suggestedCosts: [CostRecord] = []
  var suggestedProcurementRequests: [ProcurementRequest] = []
  var suggestedReceivingInspections: [ReceivingInspectionRecord] = []
  var suggestedInventoryReceipts: [InventoryReceiptRecord] = []
  var suggestedStorageLocations: [StorageLocationRecord] = []
  var suggestedCustodyRecords: [CustodyRecord] = []
  var suggestedLabelReferences: [LabelReferenceRecord] = []
  var suggestedScanSessions: [ScanSessionRecord] = []
  var suggestedShipmentManifests: [ShipmentManifestRecord] = []
  var suggestedDispatchChecklists: [DispatchReadinessChecklist] = []
  var isDeleted = false
  var onConvert: () -> Void
  var onLink: () -> Void
  var onCompare: () -> Void
  var onAddOption: () -> Void
  var onScore: () -> Void
  var onEvidenceTask: () -> Void
  var onCheck: () -> Void
  var onDecision: () -> Void
  var onDecisionReviewed: () -> Void
  var onDecisionNeedsReview: () -> Void
  var onDecisionTask: () -> Void
  var onHandoff: () -> Void
  var onHandoffTask: () -> Void
  var onPurchased: () -> Void
  var onOrderSeen: () -> Void
  var onUseConfirmation: (ForwardedEmailIntake) -> Void
  var onAddAccount: () -> Void
  var onAccountTask: (AccountCredentialRecord) -> Void
  var onAccountDraft: (AccountCredentialRecord) -> Void
  var onAddCost: () -> Void
  var onCostTask: (CostRecord) -> Void
  var onCostDraft: (CostRecord) -> Void
  var onAddProcurement: () -> Void
  var onProcurementTask: (ProcurementRequest) -> Void
  var onProcurementDraft: (ProcurementRequest) -> Void
  var onAddInspection: () -> Void
  var onInspectionTask: (ReceivingInspectionRecord) -> Void
  var onInspectionDraft: (ReceivingInspectionRecord) -> Void
  var onAddInventoryReceipt: () -> Void
  var onInventoryReceiptTask: (InventoryReceiptRecord) -> Void
  var onInventoryReceiptDraft: (InventoryReceiptRecord) -> Void
  var onAddStorageLocation: () -> Void
  var onStorageLocationTask: (StorageLocationRecord) -> Void
  var onStorageLocationDraft: (StorageLocationRecord) -> Void
  var onAddCustody: () -> Void
  var onCustodyTask: (CustodyRecord) -> Void
  var onCustodyDraft: (CustodyRecord) -> Void
  var onAddLabelReference: () -> Void
  var onLabelReferenceTask: (LabelReferenceRecord) -> Void
  var onLabelReferenceDraft: (LabelReferenceRecord) -> Void
  var onAddScanSession: () -> Void
  var onScanSessionTask: (ScanSessionRecord) -> Void
  var onScanSessionDraft: (ScanSessionRecord) -> Void
  var onAddShipmentManifest: () -> Void
  var onShipmentManifestTask: (ShipmentManifestRecord) -> Void
  var onShipmentManifestDraft: (ShipmentManifestRecord) -> Void
  var onAddDispatchChecklist: () -> Void
  var onDispatchChecklistTask: (DispatchReadinessChecklist) -> Void
  var onDispatchChecklistDraft: (DispatchReadinessChecklist) -> Void
  var onReady: () -> Void
  var onPreferredOption: (WishlistComparisonOption) -> Void
  var onDuplicateOption: (WishlistComparisonOption) -> Void
  var onUpdateOption: (WishlistComparisonOption) -> Void
  var onRemoveOption: (WishlistComparisonOption) -> Void
  var onTask: () -> Void
  var onDraft: () -> Void
  var onDelete: () -> Void
  @State private var feedbackMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: item.source.symbol)
          .foregroundStyle(.teal)
          .frame(width: 28)
        VStack(alignment: .leading, spacing: 4) {
          Text(item.itemName)
            .font(.headline)
          Text("\(item.storefront) • \(item.estimatedCost)")
            .foregroundStyle(.secondary)
          Text(item.storefrontURL)
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("\(item.owner) • \(item.pool)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Badge(item.status, color: .blue)
      }
      Text(item.capturedDetail)
        .font(.caption)
        .foregroundStyle(.secondary)

      wishlistPurchasePacketSummary
      wishlistComparisonSummary
      wishlistPurchaseChecksSummary
      wishlistPurchaseDecisionSummary
      wishlistPurchaseHandoffSummary
      if !isDeleted {
        wishlistOperatorNextStep
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], alignment: .leading, spacing: 8) {
        if isDeleted {
          Button("Restore", systemImage: "arrow.uturn.backward") {
            onConvert()
            feedbackMessage = "Wishlist item restored locally. Confirm details before linking or converting it to an order."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Restore")
          Button("Delete now", systemImage: "trash.fill") {
            onDelete()
            feedbackMessage = "Wishlist item deleted locally. No shopfront, mailbox, payment, or order system was contacted."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Delete permanently")
        } else {
          if let url = URL(string: item.storefrontURL) {
            Link(destination: url) {
              Label("Open shopfront", systemImage: "safari")
            }
            .buttonStyle(.borderedProminent)
            .labelStyle(.iconOnly)
            .help("Open shopfront")
            ShareLink(item: url) {
              Label("Share link", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Share link")
          }
          Button("Convert to order", systemImage: "shippingbox.fill") {
            onConvert()
            feedbackMessage = "Wishlist item converted locally. Check Orders before any dispatch or purchase follow-up."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Convert to order")
          Button("Link order", systemImage: "link") {
            onLink()
            feedbackMessage = "Wishlist item linked locally. Review the order context before closing this capture."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Link to existing order")
          Button("Compare sellers", systemImage: "magnifyingglass.circle") {
            onCompare()
            feedbackMessage = "Local comparison plan created. No web search, retailer scrape, currency lookup, postage quote, or trust service was contacted."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Create local seller comparison plan")
          Button("Add seller option", systemImage: "storefront") {
            onAddOption()
            feedbackMessage = "Manual seller option added locally. Fill in live price, AUD total, postage, trust, and product link before choosing where to buy."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Add seller option")
          Button("Score options", systemImage: "chart.bar.doc.horizontal") {
            onScore()
            feedbackMessage = "Seller options scored locally from existing comparison fields. Verify live price, postage, trust, returns, and account readiness before buying."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Score seller options locally")
          Button("Ready to buy", systemImage: "checkmark.seal") {
            onReady()
            feedbackMessage = "Wishlist item marked ready for purchase review locally. ParcelOps did not buy anything or store payment details."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Mark ready for purchase review")
          Button("Readiness", systemImage: "checklist.checked") {
            onCheck()
            feedbackMessage = "Purchase readiness checked locally. Fix blockers before buying externally."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Run local purchase readiness check")
          Button("Decision", systemImage: "doc.text.magnifyingglass") {
            onDecision()
            feedbackMessage = "Purchase decision drafted locally. Review why this seller is preferred before buying externally."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Draft purchase decision")
          Button("Handoff", systemImage: "person.crop.circle.badge.checkmark") {
            onHandoff()
            feedbackMessage = "Manual purchase handoff prepared locally. Confirm account and payment outside ParcelOps."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Prepare manual purchase handoff")
          Button("Purchased", systemImage: "bag.fill") {
            onPurchased()
            feedbackMessage = "External purchase recorded locally. ParcelOps did not buy anything or store payment details."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Record external purchase")
          Button("Order seen", systemImage: "envelope.badge.fill") {
            onOrderSeen()
            feedbackMessage = "Order confirmation marked seen locally. Link the real order if needed."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Mark order confirmation seen")
          Button("Task", systemImage: "checklist") {
            onTask()
            feedbackMessage = "Wishlist comparison review task created locally. Check Tasks for owner follow-up."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Create comparison review task")
          Button("Draft", systemImage: "envelope.open") {
            onDraft()
            feedbackMessage = "Wishlist purchase review draft created locally. No message was sent."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Create purchase review draft")
          Button("Delete", systemImage: "trash") {
            onDelete()
            feedbackMessage = "Wishlist item moved to deleted locally. No external shopfront, mailbox, or order system was changed."
          }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Move to deleted items")
        }
      }

      if let feedbackMessage {
        WishlistActionFeedbackPanel(message: feedbackMessage)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  @ViewBuilder
  private var wishlistPurchasePacketSummary: some View {
    let options = item.comparisonOptions ?? []
    let preferred = item.preferredOptionID.flatMap { id in options.first { $0.id == id } }
    let decision = item.purchaseDecision
    let handoff = item.purchaseHandoff
    let checks = item.purchaseChecks ?? []
    let failedChecks = checks.filter { $0.status != "Passed" }
    let blockers = wishlistPurchasePacketBlockers(
      options: options,
      preferred: preferred,
      decision: decision,
      handoff: handoff,
      failedChecks: failedChecks
    )

    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label("Purchase packet", systemImage: "doc.text.image.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.blue)
        Spacer(minLength: 8)
        Badge(blockers.isEmpty ? "Packet looks ready" : "\(blockers.count) blocker\(blockers.count == 1 ? "" : "s")", color: blockers.isEmpty ? .green : .orange)
      }

      CompactMetadataGrid(minimumWidth: 170) {
        PurchasePacketFact(title: "Preferred seller", value: preferred?.sellerName ?? decision?.selectedSellerName ?? "Seller not selected", symbol: "storefront.fill", color: preferred == nil ? .orange : .teal)
        PurchasePacketFact(title: "AUD total", value: decision?.totalAUDSummary ?? preferred?.estimatedAUDTotal ?? item.estimatedCost, symbol: "dollarsign.circle.fill", color: wishlistPacketValueNeedsReview(decision?.totalAUDSummary ?? preferred?.estimatedAUDTotal ?? item.estimatedCost) ? .orange : .green)
        PurchasePacketFact(title: "Postage", value: decision?.postageSummary ?? preferred.map { "\($0.postageCost), \($0.postageTime)" } ?? "Postage not reviewed", symbol: "shippingbox.fill", color: preferred == nil ? .orange : .purple)
        PurchasePacketFact(title: "Trust", value: decision?.trustSummary ?? preferred?.trustRating ?? "Trust not reviewed", symbol: "shield.checkered", color: wishlistPacketTrustColor(decision?.trustSummary ?? preferred?.trustRating ?? ""))
        PurchasePacketFact(title: "Decision", value: decision?.decisionStatus ?? "Decision not drafted", symbol: "doc.text.magnifyingglass", color: decision?.reviewState == .accepted ? .green : .orange)
        PurchasePacketFact(title: "Order link", value: linkedOrder?.orderNumber ?? (handoff?.linkedOrderID == nil ? "No linked order yet" : "Linked order missing"), symbol: "link", color: linkedOrder == nil ? .orange : .green)
      }

      if blockers.isEmpty {
        Label("Local packet is ready for manual live verification. Confirm current price, stock, postage, seller trust, account, delivery address, and payment details outside ParcelOps before buying.", systemImage: "checkmark.seal.fill")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.green)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        VStack(alignment: .leading, spacing: 4) {
          Text("Before purchase")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
          ForEach(blockers.prefix(5), id: \.self) { blocker in
            Label(blocker, systemImage: "exclamationmark.triangle.fill")
              .font(.caption2)
              .foregroundStyle(.orange)
              .fixedSize(horizontal: false, vertical: true)
          }
          let remaining = max(blockers.count - 5, 0)
          if remaining > 0 {
            Text("\(remaining) more blocker\(remaining == 1 ? "" : "s") shown in the detailed sections below.")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
      }

      CompactActionRow {
        Button("Packet draft", systemImage: "envelope.open") {
          onDraft()
          feedbackMessage = "Wishlist purchase packet draft created locally. No message was sent and no seller, browser, mailbox, checkout, or payment action occurred."
        }
        .buttonStyle(.bordered)
        Button("Handoff task", systemImage: "checklist") {
          onHandoffTask()
          feedbackMessage = "Wishlist purchase handoff task created or refreshed locally. Confirm account, payment, address, seller page, and order confirmation outside ParcelOps."
        }
        .buttonStyle(.bordered)
      }

      Text("This packet is a local buying checklist only. ParcelOps does not verify live retailer pages, convert currency live, quote postage, assess seller reputation externally, buy items, or store payment details.")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .background(.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
  }

  private func wishlistPurchasePacketBlockers(
    options: [WishlistComparisonOption],
    preferred: WishlistComparisonOption?,
    decision: WishlistPurchaseDecision?,
    handoff: WishlistPurchaseHandoff?,
    failedChecks: [WishlistPurchaseCheck]
  ) -> [String] {
    var blockers: [String] = []
    if options.isEmpty {
      blockers.append("Add or draft seller comparison options.")
    }
    if preferred == nil {
      blockers.append("Select a preferred seller option.")
    }
    if let preferred {
      let gaps = preferred.operatorSellerEvidenceGaps
      if !gaps.isEmpty {
        blockers.append("Complete preferred seller evidence: \(gaps.joined(separator: ", ")).")
      }
    }
    if failedChecks.isEmpty && item.purchaseChecks?.isEmpty != false {
      blockers.append("Run the local purchase readiness check.")
    } else if !failedChecks.isEmpty {
      blockers.append("Resolve \(failedChecks.count) readiness check item\(failedChecks.count == 1 ? "" : "s").")
    }
    if decision == nil {
      blockers.append("Draft the purchase decision.")
    } else if decision?.reviewState != .accepted {
      blockers.append("Review and accept the purchase decision locally.")
    }
    if handoff == nil {
      blockers.append("Prepare the manual purchase handoff.")
    } else if linkedOrder == nil {
      blockers.append("After external purchase, link or create the local order when confirmation arrives.")
    }
    return blockers
  }

  private func wishlistPacketValueNeedsReview(_ value: String) -> Bool {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    return normalized.isEmpty
      || normalized.contains("pending")
      || normalized.contains("confirm")
      || normalized.contains("review")
      || normalized.isPlaceholderValidationValue
  }

  private func wishlistPacketTrustColor(_ value: String) -> Color {
    if value.localizedCaseInsensitiveContains("trusted") || value.localizedCaseInsensitiveContains("high") || value.localizedCaseInsensitiveContains("accepted") {
      return .green
    }
    if value.localizedCaseInsensitiveContains("unknown") || value.localizedCaseInsensitiveContains("review") || value.localizedCaseInsensitiveContains("blocked") {
      return .orange
    }
    return .secondary
  }

  @ViewBuilder
  private var wishlistComparisonSummary: some View {
    let options = item.comparisonOptions ?? []
    let missingEvidence = missingSellerEvidenceLabels
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label("Comparison", systemImage: "magnifyingglass.circle.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.teal)
        Spacer(minLength: 8)
        Badge(item.comparisonStatus ?? "Not compared", color: options.isEmpty ? .secondary : .teal)
        if let readiness = item.purchaseReadiness {
          Badge(readiness, color: readiness.localizedCaseInsensitiveContains("ready") ? .green : .orange)
        }
      }

      if let notes = item.comparisonNotes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Text(notes)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      if options.isEmpty {
        Text("No seller options yet. Create a local comparison plan before converting this to an order or buying externally.")
          .font(.caption2)
          .foregroundStyle(.secondary)
      } else {
        if let preferred = options.first(where: { $0.id == item.preferredOptionID }) {
          WishlistPreferredOptionSummary(option: preferred)
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], alignment: .leading, spacing: 8) {
          ForEach(options) { option in
            WishlistComparisonOptionCard(
              option: option,
              isPreferred: item.preferredOptionID == option.id
            ) {
              onPreferredOption(option)
              feedbackMessage = "Preferred seller selected locally. Confirm trust, postage, returns, and total AUD cost before purchase."
            } onDuplicate: {
              onDuplicateOption(option)
              feedbackMessage = "Seller option copied locally. Adjust the copy with the alternate retailer, AUD total, postage, and trust notes."
            } onUpdate: { updatedOption in
              onUpdateOption(updatedOption)
              feedbackMessage = "Seller option saved locally. Re-run local scoring after confirming price, AUD total, postage, and trust details."
            } onRemove: {
              onRemoveOption(option)
              feedbackMessage = "Seller option removed locally. No retailer, browser, payment, or order state was changed."
            }
          }
        }

        if !missingEvidence.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Label("Seller evidence still needs review", systemImage: "checklist")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.orange)
            Text("Missing: \(missingEvidence.joined(separator: ", ")). Create one local task to confirm these before purchase.")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            CompactActionRow {
              Button("Evidence task", systemImage: "checklist") {
                onEvidenceTask()
                feedbackMessage = "Wishlist seller evidence task created locally. No web search, seller lookup, browser automation, purchase, payment, or external service ran."
              }
              .buttonStyle(.bordered)
            }
          }
          .padding(8)
          .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }
    }
    .padding(10)
    .background(.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
  }

  private var missingSellerEvidenceLabels: [String] {
    let labels = (item.comparisonOptions ?? []).flatMap(\.operatorSellerEvidenceGaps)
    return Array(Set(labels)).sorted()
  }

  @ViewBuilder
  private var wishlistOperatorNextStep: some View {
    let options = item.comparisonOptions ?? []
    let checks = item.purchaseChecks ?? []
    let failedChecks = checks.filter { $0.status != "Passed" }
    let missingEvidence = missingSellerEvidenceLabels

    if options.isEmpty {
      wishlistNextStepPanel(
        title: "Next: compare seller options",
        detail: "Add or draft seller options before deciding where to buy. This stays local until you explicitly open a seller page.",
        symbol: "magnifyingglass.circle.fill",
        color: .teal
      ) {
        Button("Compare sellers", systemImage: "magnifyingglass.circle") {
          onCompare()
          feedbackMessage = "Local comparison plan created. No web search, retailer scrape, currency lookup, postage quote, or trust service was contacted."
        }
        .buttonStyle(.borderedProminent)
        Button("Add option", systemImage: "storefront") {
          onAddOption()
          feedbackMessage = "Manual seller option added locally. Fill in live price, AUD total, postage, trust, and product link before choosing where to buy."
        }
        .buttonStyle(.bordered)
      }
    } else if !missingEvidence.isEmpty {
      wishlistNextStepPanel(
        title: "Next: fill seller evidence gaps",
        detail: "Confirm \(missingEvidence.joined(separator: ", ")) before purchase review. Create one task to track the missing evidence without duplicating work.",
        symbol: "checklist",
        color: .orange
      ) {
        Button("Evidence task", systemImage: "checklist") {
          onEvidenceTask()
          feedbackMessage = "Wishlist seller evidence task created locally. No web search, seller lookup, browser automation, purchase, payment, or external service ran."
        }
        .buttonStyle(.borderedProminent)
        Button("Score options", systemImage: "chart.bar.doc.horizontal") {
          onScore()
          feedbackMessage = "Seller options scored locally from existing comparison fields. Verify live price, postage, trust, returns, and account readiness before buying."
        }
        .buttonStyle(.bordered)
      }
    } else if checks.isEmpty || !failedChecks.isEmpty {
      wishlistNextStepPanel(
        title: checks.isEmpty ? "Next: run readiness check" : "Next: clear purchase blockers",
        detail: checks.isEmpty ? "Run the local checklist before drafting a purchase decision." : "\(failedChecks.count) readiness item\(failedChecks.count == 1 ? "" : "s") still need review before handoff.",
        symbol: "checklist.checked",
        color: .indigo
      ) {
        Button("Run readiness", systemImage: "checklist.checked") {
          onCheck()
          feedbackMessage = "Purchase readiness checked locally. Fix blockers before buying externally."
        }
        .buttonStyle(.borderedProminent)
        Button("Task", systemImage: "checklist") {
          onTask()
          feedbackMessage = "Wishlist comparison review task created locally. Check Tasks for owner follow-up."
        }
        .buttonStyle(.bordered)
      }
    } else if item.purchaseDecision == nil {
      wishlistNextStepPanel(
        title: "Next: draft purchase decision",
        detail: "Readiness checks are clear locally. Draft the seller decision so cost, trust, postage, and rejected options are recorded before purchase.",
        symbol: "doc.text.magnifyingglass",
        color: .brown
      ) {
        Button("Decision", systemImage: "doc.text.magnifyingglass") {
          onDecision()
          feedbackMessage = "Purchase decision drafted locally. Review why this seller is preferred before buying externally."
        }
        .buttonStyle(.borderedProminent)
      }
    } else if item.purchaseDecision?.reviewState != .accepted {
      wishlistNextStepPanel(
        title: "Next: review purchase decision",
        detail: "The decision exists but has not been accepted locally. Review it before preparing purchase handoff.",
        symbol: "checkmark.seal",
        color: .brown
      ) {
        Button("Reviewed", systemImage: "checkmark.seal") {
          onDecisionReviewed()
          feedbackMessage = "Purchase decision reviewed locally. Confirm live seller/account/payment details before buying externally."
        }
        .buttonStyle(.borderedProminent)
        Button("Decision task", systemImage: "checklist") {
          onDecisionTask()
          feedbackMessage = "Purchase decision review task created or refreshed locally. Check Tasks before buying externally."
        }
        .buttonStyle(.bordered)
      }
    } else if item.purchaseHandoff == nil {
      wishlistNextStepPanel(
        title: "Next: prepare manual purchase handoff",
        detail: "The decision is reviewed locally. Prepare the handoff so account, expected order signals, and order watch state are tracked.",
        symbol: "person.crop.circle.badge.checkmark",
        color: .purple
      ) {
        Button("Prepare handoff", systemImage: "person.crop.circle.badge.checkmark") {
          onHandoff()
          feedbackMessage = "Manual purchase handoff prepared locally. Confirm account and payment outside ParcelOps."
        }
        .buttonStyle(.borderedProminent)
      }
    } else if linkedOrder == nil {
      wishlistNextStepPanel(
        title: "Next: watch for order confirmation",
        detail: "Purchase handoff is staged. After buying outside ParcelOps, mark the confirmation seen or link the matching local order.",
        symbol: "envelope.badge.fill",
        color: .purple
      ) {
        Button("Order seen", systemImage: "envelope.badge.fill") {
          onOrderSeen()
          feedbackMessage = "Order confirmation marked seen locally. Link the real order if needed."
        }
        .buttonStyle(.borderedProminent)
        Button("Link order", systemImage: "link") {
          onLink()
          feedbackMessage = "Wishlist item linked locally. Review the order context before closing this capture."
        }
        .buttonStyle(.bordered)
      }
    } else {
      wishlistNextStepPanel(
        title: "Next: use the linked order as source of truth",
        detail: "Wishlist purchase context is linked to \(linkedOrder?.orderNumber ?? "a local order"). Continue tracking dispatch, receiving, evidence, and tasks from the order workflow.",
        symbol: "shippingbox.fill",
        color: .green
      ) {
        Button("Task", systemImage: "checklist") {
          onTask()
          feedbackMessage = "Wishlist comparison review task created locally. Check Tasks for owner follow-up."
        }
        .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open") {
          onDraft()
          feedbackMessage = "Wishlist follow-up draft created locally. No message was sent."
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private func wishlistNextStepPanel<Actions: View>(
    title: String,
    detail: String,
    symbol: String,
    color: Color,
    @ViewBuilder actions: () -> Actions
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(title, systemImage: symbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
      Text(detail)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      CompactActionRow {
        actions()
      }
    }
    .padding(10)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  @ViewBuilder
  private var wishlistPurchaseDecisionSummary: some View {
    if let decision = item.purchaseDecision {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Label("Purchase decision", systemImage: "doc.text.magnifyingglass")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.brown)
          Spacer(minLength: 8)
          Badge(decision.decisionStatus, color: decision.reviewState == .accepted ? .green : .orange)
        }

        CompactMetadataGrid(minimumWidth: 180) {
          PurchaseDecisionFact(title: "Seller", value: decision.selectedSellerName, symbol: "storefront.fill")
          PurchaseDecisionFact(title: "AUD total", value: decision.totalAUDSummary, symbol: "dollarsign.circle.fill")
          PurchaseDecisionFact(title: "Postage", value: decision.postageSummary, symbol: "shippingbox.fill")
          PurchaseDecisionFact(title: "Trust", value: decision.trustSummary, symbol: "shield.checkered")
        }

        if !decision.rejectedOptionsSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Text("Rejected/alternate options: \(decision.rejectedOptionsSummary)")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Text(decision.decisionNotes)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        CompactActionRow {
          Button("Reviewed", systemImage: "checkmark.seal") {
            onDecisionReviewed()
            feedbackMessage = "Purchase decision reviewed locally. Confirm live seller/account/payment details before buying externally."
          }
          .buttonStyle(.borderedProminent)
          Button("Needs review", systemImage: "exclamationmark.triangle") {
            onDecisionNeedsReview()
            feedbackMessage = "Purchase decision reopened locally for seller, trust, postage, account, or payment review."
          }
          .buttonStyle(.bordered)
          Button("Task", systemImage: "checklist") {
            onDecisionTask()
            feedbackMessage = "Purchase decision review task created or refreshed locally. Check Tasks before buying externally."
          }
          .buttonStyle(.bordered)
        }
      }
      .padding(10)
      .background(.brown.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }
  }

  @ViewBuilder
  private var wishlistPurchaseChecksSummary: some View {
    let checks = item.purchaseChecks ?? []
    if !checks.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Label("Purchase readiness", systemImage: "checklist.checked")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.indigo)
          Spacer(minLength: 8)
          Badge("\(checks.filter { $0.status == "Passed" }.count) passed", color: .green)
          let reviewCount = checks.filter { $0.status != "Passed" }.count
          Badge("\(reviewCount) review", color: reviewCount == 0 ? .green : .orange)
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 8)], alignment: .leading, spacing: 8) {
          ForEach(checks) { check in
            WishlistPurchaseCheckRow(check: check)
          }
        }
        Text("Readiness checks are local guidance only. Confirm live seller, price, account, payment, postage, returns, and delivery details outside ParcelOps before buying.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(10)
      .background(.indigo.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }
  }

  @ViewBuilder
  private var wishlistPurchaseHandoffSummary: some View {
    if let handoff = item.purchaseHandoff {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Label("Purchase handoff", systemImage: "person.crop.circle.badge.checkmark")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Spacer(minLength: 8)
          Badge(handoff.purchaseStatus, color: handoff.purchaseStatus.localizedCaseInsensitiveContains("linked") ? .green : .purple)
        }
        CompactMetadataGrid(minimumWidth: 190) {
          PurchaseHandoffFact(title: "Seller", value: handoff.sellerName, symbol: "storefront.fill")
          PurchaseHandoffFact(title: "Account", value: handoff.accountLabel, symbol: "person.crop.circle.fill")
          PurchaseHandoffFact(title: "Order watch", value: handoff.orderWatchStatus, symbol: "envelope.badge.fill")
          PurchaseHandoffFact(title: "Updated", value: handoff.updatedAt, symbol: "clock.fill")
        }
        Text("Expected order signals: \(handoff.expectedOrderSignals)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        Text(handoff.notes)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        CompactActionRow {
          Button("Handoff task", systemImage: "checklist") {
            onHandoffTask()
            feedbackMessage = "Wishlist purchase handoff task created or refreshed locally. Confirm account, payment, address, seller page, and order confirmation outside ParcelOps."
          }
          .buttonStyle(.bordered)
        }

        if let linkedOrder, let store {
          VStack(alignment: .leading, spacing: 6) {
            Label("Linked order", systemImage: "shippingbox.fill")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.green)
            Text("This Wishlist handoff is linked to \(linkedOrder.orderNumber). Use the order detail as the source of truth for tracking, dispatch setup, receiving, and evidence.")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            CompactActionRow {
              NavigationLink {
                OrderDetailView(order: linkedOrder, store: store)
              } label: {
                Label("Open linked order", systemImage: "arrow.up.right.square.fill")
              }
            }
            .buttonStyle(.bordered)
          }
          .padding(8)
          .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        } else if handoff.linkedOrderID != nil {
          Label("Linked order ID is stored, but the local order record was not found. Recreate or relink the order before staging downstream handoff records.", systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
            .padding(8)
            .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        VStack(alignment: .leading, spacing: 6) {
          Label("Account used for purchase", systemImage: "key.horizontal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Text("Track the retailer or supplier account reference here. ParcelOps stores only non-secret account placeholders; no passwords, tokens, payment details, or browser sessions are stored.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if suggestedAccounts.isEmpty {
            HStack(alignment: .center, spacing: 8) {
              Text("No matching local account placeholder yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer(minLength: 8)
              Button("Add account", systemImage: "key.badge.plus") {
                onAddAccount()
                feedbackMessage = "Account placeholder created from Wishlist handoff. No secrets, login, Keychain item, payment details, or retailer access were used."
              }
              .buttonStyle(.bordered)
            }
          } else {
            ForEach(suggestedAccounts.prefix(3)) { account in
              WishlistAccountContextRow(account: account) {
                onAccountTask(account)
                feedbackMessage = "Account review task created locally. No credentials or retailer account were accessed."
              } onDraft: {
                onAccountDraft(account)
                feedbackMessage = "Account follow-up draft created locally. No message was sent."
              }
            }
          }
        }
        .padding(8)
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 6) {
          Label("Cost and budget handoff", systemImage: "dollarsign.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Text("Create a local cost placeholder once a seller is preferred or purchase handoff is ready. This records expected AUD total, postage, trust context, owner, budget code, and account link without payment processing or accounting integration.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if suggestedCosts.isEmpty {
            HStack(alignment: .center, spacing: 8) {
              Text("No linked cost or budget placeholder yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer(minLength: 8)
              Button("Add cost", systemImage: "dollarsign.circle") {
                onAddCost()
                feedbackMessage = "Wishlist purchase cost placeholder created locally. Review Costs & Budgets before buying externally."
              }
              .buttonStyle(.bordered)
            }
          } else {
            ForEach(suggestedCosts.prefix(3)) { cost in
              WishlistCostContextRow(cost: cost) {
                onCostTask(cost)
                feedbackMessage = "Cost review task created locally. No payment, reimbursement, or accounting integration was used."
              } onDraft: {
                onCostDraft(cost)
                feedbackMessage = "Cost follow-up draft created locally. No message was sent."
              }
            }
          }
        }
        .padding(8)
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 6) {
          Label("Procurement request", systemImage: "cart.badge.plus")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Text("Use this when the item needs approval or buying coordination before an external purchase. It stays local and links back to the Wishlist item, account placeholder, and cost record.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if suggestedProcurementRequests.isEmpty {
            HStack(alignment: .center, spacing: 8) {
              Text("No linked procurement request yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer(minLength: 8)
              Button("Add request", systemImage: "cart.badge.plus") {
                onAddProcurement()
                feedbackMessage = "Wishlist procurement request created locally. Review approval, seller, account, budget, and delivery details before buying externally."
              }
              .buttonStyle(.bordered)
            }
          } else {
            ForEach(suggestedProcurementRequests.prefix(3)) { request in
              WishlistProcurementContextRow(request: request) {
                onProcurementTask(request)
                feedbackMessage = "Procurement review task created locally. No supplier, purchase order, or payment integration was used."
              } onDraft: {
                onProcurementDraft(request)
                feedbackMessage = "Procurement follow-up draft created locally. No message was sent."
              }
            }
          }
        }
        .padding(8)
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 6) {
          Label("Receiving check", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Text("Stage a local receiving inspection before the item arrives so the operator knows what to verify: item, quantity, condition, accessories, paperwork, and discrepancy follow-up.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if suggestedReceivingInspections.isEmpty {
            HStack(alignment: .center, spacing: 8) {
              Text("No receiving check staged yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer(minLength: 8)
              Button("Add check", systemImage: "checkmark.seal") {
                onAddInspection()
                feedbackMessage = "Wishlist receiving inspection staged locally. No carrier, supplier, scanner, OCR, or warehouse system was contacted."
              }
              .buttonStyle(.bordered)
            }
          } else {
            ForEach(suggestedReceivingInspections.prefix(3)) { inspection in
              WishlistReceivingInspectionRow(inspection: inspection) {
                onInspectionTask(inspection)
                feedbackMessage = "Receiving inspection task created locally. No carrier, warehouse, scanner, or OCR integration was used."
              } onDraft: {
                onInspectionDraft(inspection)
                feedbackMessage = "Receiving inspection follow-up draft created locally. No message was sent."
              }
            }
          }
        }
        .padding(8)
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 6) {
          Label("Inventory receipt", systemImage: "shippingbox.and.arrow.backward.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Text("Use this to plan where the received item goes after inspection: stocked, handed off, partially accepted, rejected, or still pending local review.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if suggestedInventoryReceipts.isEmpty {
            HStack(alignment: .center, spacing: 8) {
              Text("No stock or handoff receipt staged yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer(minLength: 8)
              Button("Add receipt", systemImage: "shippingbox.and.arrow.backward") {
                onAddInventoryReceipt()
                feedbackMessage = "Wishlist inventory receipt staged locally. No warehouse, inventory API, scanner, carrier, supplier, or mailbox action occurred."
              }
              .buttonStyle(.bordered)
            }
          } else {
            ForEach(suggestedInventoryReceipts.prefix(3)) { receipt in
              WishlistInventoryReceiptRow(receipt: receipt) {
                onInventoryReceiptTask(receipt)
                feedbackMessage = "Inventory receipt task created locally. No warehouse, inventory API, scanner, or carrier integration was used."
              } onDraft: {
                onInventoryReceiptDraft(receipt)
                feedbackMessage = "Inventory receipt follow-up draft created locally. No message was sent."
              }
            }
          }
        }
        .padding(8)
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 6) {
          Label("Storage or handoff location", systemImage: "archivebox.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Text("Reserve a local staging spot for the item after receipt. This can later become a real shelf, bin, desk, locker, or handoff area assignment.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if suggestedStorageLocations.isEmpty {
            HStack(alignment: .center, spacing: 8) {
              Text("No staging location reserved yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer(minLength: 8)
              Button("Add location", systemImage: "archivebox") {
                onAddStorageLocation()
                feedbackMessage = "Wishlist staging location created locally. No warehouse, map, access-control, scanner, carrier, supplier, or inventory system was contacted."
              }
              .buttonStyle(.bordered)
            }
          } else {
            ForEach(suggestedStorageLocations.prefix(3)) { location in
              WishlistStorageLocationRow(location: location) {
                onStorageLocationTask(location)
                feedbackMessage = "Storage location task created locally. No warehouse, access-control, scanner, map, or inventory integration was used."
              } onDraft: {
                onStorageLocationDraft(location)
                feedbackMessage = "Storage location follow-up draft created locally. No message was sent."
              }
            }
          }
        }
        .padding(8)
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 6) {
          Label("Custody and responsibility", systemImage: "person.2.badge.gearshape.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Text("Track who is responsible for the item as it moves from purchase confirmation to receiving, staging, storage, or handoff. This is a local chain-of-custody note, not a signature or scanner workflow.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if suggestedCustodyRecords.isEmpty {
            HStack(alignment: .center, spacing: 8) {
              Text("No custody record staged yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer(minLength: 8)
              Button("Add custody", systemImage: "person.2.badge.gearshape") {
                onAddCustody()
                feedbackMessage = "Wishlist custody record created locally. No signature capture, scanner, access-control, warehouse, carrier, supplier, or retailer system was contacted."
              }
              .buttonStyle(.bordered)
            }
          } else {
            ForEach(suggestedCustodyRecords.prefix(3)) { custody in
              WishlistCustodyRecordRow(custody: custody) {
                onCustodyTask(custody)
                feedbackMessage = "Custody review task created locally. No signature capture, scanner, access-control, or external system was used."
              } onDraft: {
                onCustodyDraft(custody)
                feedbackMessage = "Custody follow-up draft created locally. No message was sent."
              }
            }
          }
        }
        .padding(8)
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 6) {
          Label("Label reference", systemImage: "tag.square.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Text("Create a local label placeholder that ties the Wishlist item to receiving, storage, custody, or handoff notes. This does not generate a barcode, QR code, printable label, scan, or carrier label.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if suggestedLabelReferences.isEmpty {
            HStack(alignment: .center, spacing: 8) {
              Text("No label reference staged yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer(minLength: 8)
              Button("Add label", systemImage: "tag.square") {
                onAddLabelReference()
                feedbackMessage = "Wishlist label reference created locally. No barcode, QR, printer, scanner, camera, carrier, warehouse, or retailer system was contacted."
              }
              .buttonStyle(.bordered)
            }
          } else {
            ForEach(suggestedLabelReferences.prefix(3)) { label in
              WishlistLabelReferenceRow(label: label) {
                onLabelReferenceTask(label)
                feedbackMessage = "Label reference review task created locally. No scanner, printer, QR, barcode, carrier, or warehouse integration was used."
              } onDraft: {
                onLabelReferenceDraft(label)
                feedbackMessage = "Label reference follow-up draft created locally. No message was sent."
              }
            }
          }
        }
        .padding(8)
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 6) {
          Label("Manual verification", systemImage: "checklist.checked")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Text("Stage a local manual check that the received item, label reference, storage location, and custody record line up. This is not scanner hardware, camera access, barcode scanning, or QR generation.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if suggestedScanSessions.isEmpty {
            HStack(alignment: .center, spacing: 8) {
              Text("No manual verification session staged yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer(minLength: 8)
              Button("Add check", systemImage: "checklist.checked") {
                onAddScanSession()
                feedbackMessage = "Wishlist manual verification session created locally. No scanner, camera, barcode, QR, printer, carrier, warehouse, or retailer system was contacted."
              }
              .buttonStyle(.bordered)
            }
          } else {
            ForEach(suggestedScanSessions.prefix(3)) { scan in
              WishlistScanSessionRow(scan: scan) {
                onScanSessionTask(scan)
                feedbackMessage = "Manual verification review task created locally. No scanner, camera, barcode, QR, printer, or external integration was used."
              } onDraft: {
                onScanSessionDraft(scan)
                feedbackMessage = "Manual verification follow-up draft created locally. No message was sent."
              }
            }
          }
        }
        .padding(8)
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 6) {
          Label("Outbound handoff plan", systemImage: "paperplane.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Text("Create a local dispatch manifest only when the item needs an outbound transfer, courier handoff, internal delivery run, or final handoff after purchase and receipt. This does not book a carrier, print a label, or mark anything shipped.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if suggestedShipmentManifests.isEmpty {
            HStack(alignment: .center, spacing: 8) {
              Text("No outbound handoff plan staged yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer(minLength: 8)
              Button("Add manifest", systemImage: "paperplane") {
                onAddShipmentManifest()
                feedbackMessage = "Wishlist dispatch manifest created locally. No carrier booking, label printing, scanner, camera, warehouse, supplier, retailer, or mailbox action occurred."
              }
              .buttonStyle(.bordered)
            }
          } else {
            ForEach(suggestedShipmentManifests.prefix(3)) { manifest in
              WishlistShipmentManifestRow(manifest: manifest) {
                onShipmentManifestTask(manifest)
                feedbackMessage = "Dispatch manifest review task created locally. No carrier, label, scanner, or warehouse integration was used."
              } onDraft: {
                onShipmentManifestDraft(manifest)
                feedbackMessage = "Dispatch manifest follow-up draft created locally. No message was sent."
              }
            }
          }
        }
        .padding(8)
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 6) {
          Label("Dispatch readiness", systemImage: "checkmark.rectangle.stack.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
          Text("Use this as a final local readiness gate before any outbound handoff. It checks the order evidence, receipt, storage, custody, label reference, manual verification, and manifest context without booking or sending anything.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          if suggestedDispatchChecklists.isEmpty {
            HStack(alignment: .center, spacing: 8) {
              Text("No dispatch readiness checklist staged yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer(minLength: 8)
              Button("Add checklist", systemImage: "checkmark.rectangle.stack") {
                onAddDispatchChecklist()
                feedbackMessage = "Wishlist dispatch readiness checklist created locally. No carrier booking, label printing, scanner, camera, warehouse, notification, calendar, or external service was used."
              }
              .buttonStyle(.bordered)
            }
          } else {
            ForEach(suggestedDispatchChecklists.prefix(3)) { checklist in
              WishlistDispatchChecklistRow(checklist: checklist) {
                onDispatchChecklistTask(checklist)
                feedbackMessage = "Dispatch readiness review task created locally. No carrier, label, scanner, notification, calendar, or external integration was used."
              } onDraft: {
                onDispatchChecklistDraft(checklist)
                feedbackMessage = "Dispatch readiness follow-up draft created locally. No message was sent."
              }
            }
          }
        }
        .padding(8)
        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        if !confirmationMatches.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Label("Possible Inbox confirmations", systemImage: "envelope.badge.fill")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.purple)
            Text("These are stored Inbox intake rows that match this Wishlist handoff. Use one only after confirming it is the purchase confirmation.")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            ForEach(confirmationMatches.prefix(3)) { email in
              WishlistOrderConfirmationCandidateRow(email: email) {
                onUseConfirmation(email)
                feedbackMessage = "Wishlist handoff linked to an existing Inbox confirmation locally. Check Orders for the created or linked order."
              }
            }
          }
          .padding(8)
          .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }
      .padding(10)
      .background(.purple.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

private struct WishlistOrderConfirmationCandidateRow: View {
  var email: ForwardedEmailIntake
  var onUse: () -> Void

  private var detail: String {
    [
      email.sender,
      email.receivedDate,
      email.detectedOrderNumber.isPlaceholderValidationValue ? nil : "Order \(email.detectedOrderNumber)",
      email.detectedTrackingNumber.isPlaceholderValidationValue ? nil : "Tracking \(email.detectedTrackingNumber)"
    ]
      .compactMap { $0 }
      .joined(separator: " • ")
  }

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "envelope.open.fill")
        .foregroundStyle(.purple)
      VStack(alignment: .leading, spacing: 3) {
        Text(email.subject.isPlaceholderValidationValue ? "Inbox confirmation candidate" : email.subject)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text(detail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      Spacer(minLength: 8)
      Button("Use", systemImage: "link.badge.plus", action: onUse)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Use this Inbox email as the Wishlist order confirmation")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistAccountContextRow: View {
  var account: AccountCredentialRecord
  var onTask: () -> Void
  var onDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "key.horizontal.fill")
        .foregroundStyle(account.credentialStorageStatus.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(account.accountName)
          .font(.caption.weight(.semibold))
        Text("\(account.organisation) • \(account.usernameLabel)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        HStack(spacing: 6) {
          Badge(account.credentialStorageStatus.rawValue, color: account.credentialStorageStatus.color)
          Badge(account.mfaStatus.rawValue, color: account.mfaStatus.color)
          Badge(account.reviewState.rawValue, color: account.reviewState.color)
        }
      }
      Spacer(minLength: 8)
      Button("Task", systemImage: "checklist", action: onTask)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create account review task")
      Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create account follow-up draft")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistCostContextRow: View {
  var cost: CostRecord
  var onTask: () -> Void
  var onDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "dollarsign.circle.fill")
        .foregroundStyle(cost.reviewState.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(cost.title)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text("\(cost.amountText) \(cost.currency) • \(cost.budgetCode) • \(cost.costOwnerTeam)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        HStack(spacing: 6) {
          Badge(cost.approvalStatus.rawValue, color: cost.approvalStatus == .approved ? .green : .orange)
          Badge(cost.reimbursementStatus.rawValue, color: cost.reimbursementStatus == .reimbursed ? .green : .secondary)
          Badge(cost.reviewState.rawValue, color: cost.reviewState.color)
        }
      }
      Spacer(minLength: 8)
      Button("Task", systemImage: "checklist", action: onTask)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create cost review task")
      Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create cost follow-up draft")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistProcurementContextRow: View {
  var request: ProcurementRequest
  var onTask: () -> Void
  var onDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "cart.badge.plus")
        .foregroundStyle(request.reviewState.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(request.title)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text("\(request.estimatedCostText) \(request.currency) • \(request.budgetCode) • \(request.assignedBuyerTeam)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        HStack(spacing: 6) {
          Badge(request.approvalStatus.rawValue, color: request.approvalStatus == .approved ? .green : .orange)
          Badge(request.procurementStatus.rawValue, color: request.procurementStatus == .received ? .green : .blue)
          Badge(request.reviewState.rawValue, color: request.reviewState.color)
        }
      }
      Spacer(minLength: 8)
      Button("Task", systemImage: "checklist", action: onTask)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create procurement review task")
      Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create procurement follow-up draft")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistReceivingInspectionRow: View {
  var inspection: ReceivingInspectionRecord
  var onTask: () -> Void
  var onDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "checkmark.seal.fill")
        .foregroundStyle(inspection.reviewState.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(inspection.title)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text("\(inspection.inspectionType.rawValue) • \(inspection.assignedInspectorTeam) • \(inspection.dueDate)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        HStack(spacing: 6) {
          Badge(inspection.inspectionStatus.rawValue, color: inspection.inspectionStatus == .resolved ? .green : .blue)
          Badge(inspection.discrepancyType.rawValue, color: inspection.discrepancyType == .none ? .secondary : .orange)
          Badge(inspection.reviewState.rawValue, color: inspection.reviewState.color)
        }
      }
      Spacer(minLength: 8)
      Button("Task", systemImage: "checklist", action: onTask)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create receiving inspection task")
      Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create receiving inspection follow-up draft")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistInventoryReceiptRow: View {
  var receipt: InventoryReceiptRecord
  var onTask: () -> Void
  var onDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "shippingbox.and.arrow.backward.fill")
        .foregroundStyle(receipt.reviewState.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(receipt.title)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text("\(receipt.receiptType.rawValue) • \(receipt.assignedOwnerTeam) • \(receipt.storageLocationSummary)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        HStack(spacing: 6) {
          Badge(receipt.stockHandoffStatus.rawValue, color: receipt.stockHandoffStatus == .stocked || receipt.stockHandoffStatus == .handedOff ? .green : .blue)
          Badge("\(receipt.quantityAccepted)/\(receipt.quantityReceived) accepted", color: receipt.quantityRejected > 0 ? .orange : .secondary)
          Badge(receipt.reviewState.rawValue, color: receipt.reviewState.color)
        }
      }
      Spacer(minLength: 8)
      Button("Task", systemImage: "checklist", action: onTask)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create inventory receipt task")
      Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create inventory receipt follow-up draft")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistStorageLocationRow: View {
  var location: StorageLocationRecord
  var onTask: () -> Void
  var onDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "archivebox.fill")
        .foregroundStyle(location.reviewState.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(location.title)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text("\(location.locationType.rawValue) • \(location.locationCode) • \(location.areaZone)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        HStack(spacing: 6) {
          Badge(location.isEnabled ? "Enabled" : "Disabled", color: location.isEnabled ? .green : .secondary)
          Badge(location.assignedOwnerTeam, color: .blue)
          Badge(location.reviewState.rawValue, color: location.reviewState.color)
        }
      }
      Spacer(minLength: 8)
      Button("Task", systemImage: "checklist", action: onTask)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create storage location task")
      Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create storage location follow-up draft")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistCustodyRecordRow: View {
  var custody: CustodyRecord
  var onTask: () -> Void
  var onDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "person.2.badge.gearshape.fill")
        .foregroundStyle(custody.reviewState.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(custody.title)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text("\(custody.currentCustodianTeam) • \(custody.handoffMethod.rawValue) • \(custody.transferDate)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        HStack(spacing: 6) {
          Badge(custody.custodyStatus.rawValue, color: custody.custodyStatus == .received || custody.custodyStatus == .returnedClosed ? .green : .blue)
          Badge(custody.assignedOwnerTeam, color: .blue)
          Badge(custody.reviewState.rawValue, color: custody.reviewState.color)
        }
      }
      Spacer(minLength: 8)
      Button("Task", systemImage: "checklist", action: onTask)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create custody review task")
      Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create custody follow-up draft")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistLabelReferenceRow: View {
  var label: LabelReferenceRecord
  var onTask: () -> Void
  var onDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "tag.square.fill")
        .foregroundStyle(label.reviewState.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(label.title)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text("\(label.labelType.rawValue) • \(label.labelValuePlaceholder) • \(label.labelSource.rawValue)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        HStack(spacing: 6) {
          Badge(label.labelStatus.rawValue, color: label.labelStatus == .scannedVerified ? .green : label.labelStatus == .invalidNeedsReview ? .red : .blue)
          Badge(label.assignedOwnerTeam, color: .blue)
          Badge(label.reviewState.rawValue, color: label.reviewState.color)
        }
      }
      Spacer(minLength: 8)
      Button("Task", systemImage: "checklist", action: onTask)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create label reference review task")
      Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create label reference follow-up draft")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistScanSessionRow: View {
  var scan: ScanSessionRecord
  var onTask: () -> Void
  var onDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "checklist.checked")
        .foregroundStyle(scan.reviewState.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(scan.title)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text("\(scan.scanPurpose.rawValue) • \(scan.scanMethodPlaceholder.rawValue) • expected \(scan.expectedLabelReferenceValue)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        HStack(spacing: 6) {
          Badge(scan.scanStatus.rawValue, color: scan.scanStatus == .completed || scan.scanStatus == .matched ? .green : scan.scanStatus == .mismatchNeedsReview ? .red : .blue)
          Badge(scan.assignedOperatorTeam, color: .blue)
          Badge(scan.reviewState.rawValue, color: scan.reviewState.color)
        }
      }
      Spacer(minLength: 8)
      Button("Task", systemImage: "checklist", action: onTask)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create manual verification review task")
      Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create manual verification follow-up draft")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistShipmentManifestRow: View {
  var manifest: ShipmentManifestRecord
  var onTask: () -> Void
  var onDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "paperplane.fill")
        .foregroundStyle(manifest.reviewState.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(manifest.title)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text("\(manifest.manifestType.rawValue) • \(manifest.carrierCourier) • \(manifest.plannedDispatchDate)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        HStack(spacing: 6) {
          Badge(manifest.dispatchStatus.rawValue, color: manifest.dispatchStatus == .handedOff || manifest.dispatchStatus == .dispatched ? .green : manifest.dispatchStatus == .blockedNeedsReview ? .red : .blue)
          Badge(manifest.assignedOwnerTeam, color: .blue)
          Badge(manifest.reviewState.rawValue, color: manifest.reviewState.color)
        }
      }
      Spacer(minLength: 8)
      Button("Task", systemImage: "checklist", action: onTask)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create dispatch manifest review task")
      Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create dispatch manifest follow-up draft")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistDispatchChecklistRow: View {
  var checklist: DispatchReadinessChecklist
  var onTask: () -> Void
  var onDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "checkmark.rectangle.stack.fill")
        .foregroundStyle(checklist.reviewState.color)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(checklist.title)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Text("\(checklist.checklistType.rawValue) • \(checklist.plannedDispatchDate)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        HStack(spacing: 6) {
          Badge(checklist.checklistStatus.rawValue, color: checklist.checklistStatus == .ready || checklist.checklistStatus == .completed ? .green : checklist.checklistStatus == .blockedNeedsReview ? .red : .blue)
          Badge(checklist.assignedOwnerTeam, color: .blue)
          Badge(checklist.reviewState.rawValue, color: checklist.reviewState.color)
        }
      }
      Spacer(minLength: 8)
      Button("Task", systemImage: "checklist", action: onTask)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create dispatch readiness review task")
      Button("Draft", systemImage: "envelope.open.fill", action: onDraft)
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Create dispatch readiness follow-up draft")
    }
    .padding(8)
    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPreferredOptionSummary: View {
  var option: WishlistComparisonOption

  private var color: Color {
    guard let risk = option.riskLevel else { return .teal }
    if risk.localizedCaseInsensitiveContains("lower") { return .green }
    if risk.localizedCaseInsensitiveContains("high") { return .red }
    return .orange
  }

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "checkmark.seal.fill")
        .foregroundStyle(color)
      VStack(alignment: .leading, spacing: 3) {
        Text("Current best candidate: \(option.sellerName)")
          .font(.caption.weight(.semibold))
        Text("Local score \(option.localScore.map(String.init) ?? "not scored") • \(option.riskLevel ?? "risk not scored")")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(color)
        if let reason = option.decisionReason, !reason.isEmpty {
          Text(reason)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct PurchaseHandoffFact: View {
  var title: String
  var value: String
  var symbol: String

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: symbol)
        .foregroundStyle(.purple)
        .frame(width: 18)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(value)
          .font(.caption)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(.purple.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct PurchasePacketFact: View {
  var title: String
  var value: String
  var symbol: String
  var color: Color

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: symbol)
        .foregroundStyle(color)
        .frame(width: 18)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(value)
          .font(.caption)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct PurchaseDecisionFact: View {
  var title: String
  var value: String
  var symbol: String

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: symbol)
        .foregroundStyle(.brown)
        .frame(width: 18)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(value)
          .font(.caption)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(.brown.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistPurchaseCheckRow: View {
  var check: WishlistPurchaseCheck

  private var color: Color {
    if check.status == "Passed" { return .green }
    if check.severity == "High" { return .red }
    return .orange
  }

  private var symbol: String {
    if check.status == "Passed" { return "checkmark.circle.fill" }
    if check.severity == "High" { return "exclamationmark.triangle.fill" }
    return "exclamationmark.circle.fill"
  }

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: symbol)
        .foregroundStyle(color)
        .frame(width: 18)
      VStack(alignment: .leading, spacing: 3) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(check.title)
            .font(.caption.weight(.semibold))
          Badge(check.status, color: color)
        }
        Text(check.detail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistComparisonOptionCard: View {
  var option: WishlistComparisonOption
  var isPreferred: Bool
  var onPrefer: () -> Void
  var onDuplicate: () -> Void
  var onUpdate: (WishlistComparisonOption) -> Void
  var onRemove: () -> Void
  @State private var isEditing = false
  @State private var draft: WishlistComparisonOption

  init(
    option: WishlistComparisonOption,
    isPreferred: Bool,
    onPrefer: @escaping () -> Void,
    onDuplicate: @escaping () -> Void,
    onUpdate: @escaping (WishlistComparisonOption) -> Void,
    onRemove: @escaping () -> Void
  ) {
    self.option = option
    self.isPreferred = isPreferred
    self.onPrefer = onPrefer
    self.onDuplicate = onDuplicate
    self.onUpdate = onUpdate
    self.onRemove = onRemove
    _draft = State(initialValue: option)
  }

  private var trustColor: Color {
    if option.trustRating.localizedCaseInsensitiveContains("high") || option.trustRating.localizedCaseInsensitiveContains("trusted") { return .green }
    if option.trustRating.localizedCaseInsensitiveContains("review") || option.trustRating.localizedCaseInsensitiveContains("unknown") { return .orange }
    return .secondary
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(option.sellerName)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
        Spacer(minLength: 8)
        Badge(isPreferred ? "Preferred" : option.recommendation, color: isPreferred ? .green : .blue)
      }
      Text("\(option.estimatedAUDTotal) • postage \(option.postageCost) • \(option.postageTime)")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Text("\(option.sellerRegion) • trust: \(option.trustRating)")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(trustColor)
      if let score = option.localScore, let risk = option.riskLevel {
        Text("Local score \(score)/100 • \(risk)")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(risk.localizedCaseInsensitiveContains("high") ? .red : trustColor)
      }
      if let reason = option.decisionReason, !reason.isEmpty {
        Text(reason)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(3)
      }
      WishlistSellerEvidenceChecklist(option: option)
      Text(option.trustNotes)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(3)
      HStack {
        if let url = URL(string: option.productURL), !option.productURL.isPlaceholderValidationValue {
          Link(destination: url) {
            Label("Open seller", systemImage: "safari")
          }
          .buttonStyle(.bordered)
          .labelStyle(.iconOnly)
          .help("Open seller page")
        }
        Button(isPreferred ? "Preferred" : "Prefer", systemImage: isPreferred ? "checkmark.seal.fill" : "checkmark.seal") {
          onPrefer()
        }
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help(isPreferred ? "Preferred option" : "Select preferred option")
        Button("Edit option", systemImage: "pencil") {
          draft = option
          isEditing = true
        }
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Edit seller option")
        Button("Copy option", systemImage: "doc.on.doc") {
          onDuplicate()
        }
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Copy seller option")
        Button("Remove option", systemImage: "trash") {
          onRemove()
        }
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .help("Remove seller option")
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background((isPreferred ? Color.green : trustColor).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      WishlistComparisonOptionEditor(option: $draft) {
        isEditing = false
      } onSave: {
        onUpdate(draft)
        isEditing = false
      }
    }
  }
}

private struct WishlistSellerEvidenceChecklist: View {
  var option: WishlistComparisonOption

  private var evidenceItems: [(String, Bool, String)] {
    let searchable = [
      option.productURL,
      option.listedPrice,
      option.currency,
      option.estimatedAUDTotal,
      option.postageCost,
      option.postageTime,
      option.sellerRegion,
      option.trustRating,
      option.trustNotes,
      option.recommendation
    ]
      .joined(separator: " ")
      .localizedLowercase

    return [
      ("Product link", !option.productURL.isPlaceholderValidationValue && option.productURL.localizedCaseInsensitiveContains("http"), "Direct seller page"),
      ("AUD total", option.estimatedAUDTotal.localizedCaseInsensitiveContains("aud") && !option.estimatedAUDTotal.localizedCaseInsensitiveContains("pending"), "Landed AUD"),
      ("Postage cost", !option.postageCost.localizedCaseInsensitiveContains("pending") && !option.postageCost.isPlaceholderValidationValue, "Cost known"),
      ("Postage time", !option.postageTime.localizedCaseInsensitiveContains("pending") && !option.postageTime.isPlaceholderValidationValue, "ETA known"),
      ("Seller trust", !option.trustRating.localizedCaseInsensitiveContains("unknown") && !option.trustRating.localizedCaseInsensitiveContains("review"), "Trust noted"),
      ("Returns/warranty", searchable.contains("return") || searchable.contains("warranty"), "Policy noted")
    ]
  }

  private var missingItems: [String] {
    evidenceItems.filter { !$0.1 }.map(\.0)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        Label("Evidence", systemImage: "checklist")
          .font(.caption2.weight(.semibold))
        Badge(missingItems.isEmpty ? "Complete enough for review" : "\(missingItems.count) missing", color: missingItems.isEmpty ? .green : .orange)
      }
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], alignment: .leading, spacing: 6) {
        ForEach(evidenceItems, id: \.0) { title, passed, detail in
          HStack(spacing: 5) {
            Image(systemName: passed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
              .foregroundStyle(passed ? Color.green : Color.orange)
            VStack(alignment: .leading, spacing: 1) {
              Text(title)
                .font(.caption2.weight(.semibold))
              Text(passed ? detail : "Needs check")
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
          .padding(6)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background((passed ? Color.green : Color.orange).opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        }
      }
      if !missingItems.isEmpty {
        Text("Before purchase review, fill in: \(missingItems.joined(separator: ", ")).")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(8)
    .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct WishlistComparisonOptionEditor: View {
  @Binding var option: WishlistComparisonOption
  var onCancel: () -> Void
  var onSave: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Label("Seller option", systemImage: "storefront.fill")
          .font(.headline)
        Spacer()
        Button("Cancel", action: onCancel)
          .buttonStyle(.bordered)
        Button("Save", action: onSave)
          .buttonStyle(.borderedProminent)
      }

      Text("Record manual comparison details only. ParcelOps does not verify live prices, contact retailers, calculate postage, access accounts, or purchase anything from this editor.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          GroupBox("Retailer") {
            VStack(alignment: .leading, spacing: 10) {
              TextField("Seller name", text: $option.sellerName)
              TextField("Product URL", text: $option.productURL)
              TextField("Seller region", text: $option.sellerRegion)
              TextField("Recommendation", text: $option.recommendation)
            }
          }

          GroupBox("Price and postage") {
            VStack(alignment: .leading, spacing: 10) {
              TextField("Listed price", text: $option.listedPrice)
              TextField("Currency", text: $option.currency)
              TextField("Estimated AUD total", text: $option.estimatedAUDTotal)
              TextField("Postage cost", text: $option.postageCost)
              TextField("Postage time", text: $option.postageTime)
            }
          }

          GroupBox("Trust and decision notes") {
            VStack(alignment: .leading, spacing: 10) {
              TextField("Trust rating", text: $option.trustRating)
              TextField("Trust notes", text: $option.trustNotes, axis: .vertical)
                .lineLimit(3...6)
              TextField("Decision reason", text: Binding(
                get: { option.decisionReason ?? "" },
                set: { option.decisionReason = $0 }
              ), axis: .vertical)
                .lineLimit(2...5)
            }
          }
        }
      }
    }
    .padding(20)
    .frame(minWidth: 520, minHeight: 560)
  }
}

private struct WishlistActionFeedbackPanel: View {
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
