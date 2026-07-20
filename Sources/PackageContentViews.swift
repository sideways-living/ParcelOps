import SwiftUI

struct PackageContentsView: View {
  var store: ParcelOpsStore
  @State private var selectedCategory: PackageItemCategory?
  @State private var selectedValueBand: PackageValueBand?
  @State private var selectedVerificationStatus: PackageVerificationStatus?
  @State private var selectedRiskLevel: ShipmentRiskLevel?
  @State private var selectedLinkedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedReviewState: ReviewState?
  @State private var packageSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var baseFilteredContents: [PackageContentRecord] {
    store.filteredPackageContents(
      itemCategory: selectedCategory,
      valueBand: selectedValueBand,
      verificationStatus: selectedVerificationStatus,
      riskLevel: selectedRiskLevel,
      linkedEntityType: selectedLinkedEntityType,
      reviewState: selectedReviewState
    )
  }

  private var filteredContents: [PackageContentRecord] {
    let query = packageSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredContents }
    return baseFilteredContents.filter { content in
      packageContent(content, matches: query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedCategory != nil
      || selectedValueBand != nil
      || selectedVerificationStatus != nil
      || selectedRiskLevel != nil
      || selectedLinkedEntityType != nil
      || selectedReviewState != nil
      || !packageSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filterBar
        inboxPackageContentCoverage
        gmailPackageContentReadinessPanel

        SettingsPanel(title: "Content records", symbol: "shippingbox.circle.fill") {
          HStack {
            Text("\(filteredContents.count) visible content records")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredContents.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add content", systemImage: "plus", action: store.addPackageContentPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredContents.isEmpty {
            MVPEmptyState(title: "No package contents match this view", detail: hasActiveFilters ? "Clear search or filters to return to all local package content records." : "Add a package content record to track item verification, quantities, discrepancies, evidence, and receiving context.", symbol: "shippingbox.circle.fill", actionTitle: hasActiveFilters ? "Clear filters" : "Add content", action: hasActiveFilters ? clearFilters : store.addPackageContentPlaceholder)
          } else {
            ForEach(filteredContents) { content in
              PackageContentRow(content: content, store: store, linkedOrder: linkedOrder(for: content), costRecords: store.suggestedCostRecords(for: content), returnClaims: store.suggestedReturnClaims(for: content), procurementRequests: store.suggestedProcurementRequests(for: content), receivingInspections: store.suggestedReceivingInspections(for: content), inventoryReceipts: store.suggestedInventoryReceipts(for: content), storageLocations: store.suggestedStorageLocations(for: content), custodyRecords: store.suggestedCustodyRecords(for: content), labelReferences: store.suggestedLabelReferenceRecords(for: content), scanSessions: store.suggestedScanSessionRecords(for: content), shipmentManifests: store.suggestedShipmentManifestRecords(for: content), dispatchChecklists: store.suggestedDispatchReadinessChecklists(for: content)) { updatedContent in
                store.updatePackageContent(updatedContent)
              } onVerified: {
                store.markPackageContentVerified(content)
              } onDiscrepancy: {
                store.markPackageContentDiscrepancy(content)
              } onReviewed: {
                store.markPackageContentReviewed(content)
              } onCreateTask: {
                store.createReviewTask(from: content)
              } onCreateDraft: {
                store.createDraftMessage(from: content)
              } onRemove: {
                store.removePackageContent(content)
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
        Text("Package Contents")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Local item verification, quantity checks, evidence links, and discrepancy review for packages.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(store.unverifiedPackageContents.count) unverified", color: .orange)
        Badge("\(store.packageContentDiscrepancies.count) discrepancies", color: .red)
      }
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search item, order, shipment, destination, evidence, cost, claim, procurement, or storage", text: $packageSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Category", selection: $selectedCategory) {
        Text("All categories").tag(nil as PackageItemCategory?)
        ForEach(PackageItemCategory.allCases) { category in
          Text(category.rawValue).tag(category as PackageItemCategory?)
        }
      }

      Picker("Value", selection: $selectedValueBand) {
        Text("All value").tag(nil as PackageValueBand?)
        ForEach(PackageValueBand.allCases) { value in
          Text(value.rawValue).tag(value as PackageValueBand?)
        }
      }

      Picker("Verification", selection: $selectedVerificationStatus) {
        Text("All verification").tag(nil as PackageVerificationStatus?)
        ForEach(PackageVerificationStatus.allCases) { status in
          Text(status.rawValue).tag(status as PackageVerificationStatus?)
        }
      }

      Picker("Risk", selection: $selectedRiskLevel) {
        Text("All risk").tag(nil as ShipmentRiskLevel?)
        ForEach(ShipmentRiskLevel.allCases) { risk in
          Text(risk.rawValue).tag(risk as ShipmentRiskLevel?)
        }
      }

      Picker("Linked", selection: $selectedLinkedEntityType) {
        Text("All links").tag(nil as ReviewTaskLinkedEntityType?)
        ForEach(ReviewTaskLinkedEntityType.allCases) { type in
          Text(type.rawValue).tag(type as ReviewTaskLinkedEntityType?)
        }
      }

      Picker("Review", selection: $selectedReviewState) {
        Text("All review").tag(nil as ReviewState?)
        ForEach(reviewStates, id: \.self) { state in
          Text(state.rawValue).tag(state as ReviewState?)
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
    selectedCategory = nil
    selectedValueBand = nil
    selectedVerificationStatus = nil
    selectedRiskLevel = nil
    selectedLinkedEntityType = nil
    selectedReviewState = nil
    packageSearchText = ""
  }

  private var gmailPackageContentReadinessPanel: some View {
    CollapsedProviderEvidencePanel(
      title: "Mailbox content evidence",
      detail: "Open provider release evidence only when package content readiness depends on mailbox provider source trails."
    ) {
      VStack(alignment: .leading, spacing: 10) {
        GmailReleaseBoundaryPanel(
          store: store,
          title: "Gmail package content readiness",
          lead: "Gmail-origin intake should create package content work only after Gmail setup is ready and a person confirms the imported Inbox order and item details.",
          sourceMetricTitle: "Gmail content sources",
          sourceCount: gmailPackageContentSourceCount,
          boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store tokens, scan barcodes, run OCR, connect inventory, or change package content records automatically."
        )
        Microsoft365ReleaseBoundaryPanel(
          store: store,
          title: "Outlook package content readiness",
          lead: "Outlook-origin intake should create package content work only after Microsoft setup, Graph diagnostics, and confirmed Inbox order/item details are clear.",
          sourceMetricTitle: "Outlook content sources",
          sourceCount: microsoft365PackageContentSourceCount,
          boundaryDetail: "Local-only boundary: this panel does not start Microsoft sign-in, request tokens, fetch Outlook messages, scan barcodes, run OCR, connect inventory, or change package content records automatically."
        )
      }
    }
  }

  private var gmailPackageContentSourceCount: Int {
    packageContentProviderRows
      .filter { $0.label.localizedCaseInsensitiveContains("Gmail") }
      .reduce(0) { total, row in total + row.count }
  }

  private var microsoft365PackageContentSourceCount: Int {
    packageContentProviderRows
      .filter { $0.label.localizedCaseInsensitiveContains("Microsoft 365") || $0.label.localizedCaseInsensitiveContains("Outlook") }
      .reduce(0) { total, row in total + row.count }
  }

  private var inboxPackageContentCoverage: some View {
    let sourceOrders = store.operatorSourceOrders

    return SettingsPanel(title: "Inbox and Wishlist package content coverage", symbol: "shippingbox.circle.fill") {
      Text("Checks whether orders created from Inbox intake or Wishlist purchase handoff have local item verification records before cost, return, receiving, and dispatch work.")
        .font(.caption)
        .foregroundStyle(.secondary)

      CompactMetadataGrid(minimumWidth: 150) {
        Badge("\(store.intakeLinkedOrderCount) Inbox orders", color: .blue)
        Badge("\(store.wishlistLinkedOrderCount) Wishlist orders", color: .pink)
        Badge("\(contentsLinkedToInboxOrders.count) linked contents", color: .teal)
        Badge("\(unverifiedInboxContents.count) unverified", color: unverifiedInboxContents.isEmpty ? .green : .orange)
        Badge("\(inboxOrdersMissingContent.count) missing content", color: inboxOrdersMissingContent.isEmpty ? .green : .orange)
      }

      if !packageContentProviderRows.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Mailbox source for package contents")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
            ForEach(packageContentProviderRows, id: \.label) { row in
              HStack(alignment: .top, spacing: 10) {
                Image(systemName: row.symbol)
                  .foregroundStyle(row.color)
                  .frame(width: 22)
                VStack(alignment: .leading, spacing: 4) {
                  HStack(alignment: .firstTextBaseline) {
                    Text(row.label)
                      .font(.caption.weight(.semibold))
                    Spacer(minLength: 8)
                    Badge("\(row.count) intake", color: row.color)
                  }
                  Text(row.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
              }
              .padding(9)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(row.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }
      }

      if sourceOrders.isEmpty {
        Text("No Inbox-created or Wishlist-linked orders need package content checks yet.")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else if inboxOrdersMissingContent.isEmpty && unverifiedInboxContents.isEmpty {
        Label("Inbox-created and Wishlist-linked orders have verified package content coverage for this local workflow.", systemImage: "checkmark.seal.fill")
          .font(.caption)
          .foregroundStyle(.green)
      } else {
        VStack(alignment: .leading, spacing: 8) {
          if !inboxOrdersMissingContent.isEmpty {
            Text("Inbox orders needing item verification records")
              .font(.caption.weight(.semibold))
            CompactActionRow {
              ForEach(inboxOrdersMissingContent.prefix(4)) { order in
                NavigationLink {
                  OrderDetailView(order: order, store: store)
                } label: {
                  Label(order.orderNumber, systemImage: "arrow.up.right.square.fill")
                }
                .buttonStyle(.bordered)
              }
            }
          }

          if !unverifiedInboxContents.isEmpty {
            Text("Linked content still needing verification")
              .font(.caption.weight(.semibold))
            CompactMetadataGrid(minimumWidth: 170) {
              ForEach(unverifiedInboxContents.prefix(4)) { content in
                Badge(content.title, color: content.riskLevel.color)
              }
            }
          }
        }
      }
    }
  }




  private var contentsLinkedToInboxOrders: [PackageContentRecord] {
    store.packageContents.filter { content in
      guard let orderID = content.orderID ?? (content.linkedEntityType == .order ? UUID(uuidString: content.linkedEntityID) : nil) else {
        return false
      }
      return store.operatorSourceOrders.contains { $0.id == orderID }
    }
  }

  private var unverifiedInboxContents: [PackageContentRecord] {
    contentsLinkedToInboxOrders.filter { $0.verificationStatus != .verified }
  }

  private var inboxOrdersMissingContent: [TrackedOrder] {
    store.operatorSourceOrders.filter { order in
      !store.packageContents.contains { content in
        content.orderID == order.id || (content.linkedEntityType == .order && content.linkedEntityID == order.id.uuidString)
      }
    }
  }

  private var packageContentProviderRows: [(label: String, count: Int, detail: String, symbol: String, color: Color)] {
    var counts: [String: Int] = [:]
    var tones: [String: String] = [:]

    for order in store.operatorSourceOrders {
      for email in store.linkedIntakeEmails(for: order) {
        let summary = store.intakeSourceSummary(for: email)
        counts[summary.label, default: 0] += 1
        tones[summary.label] = summary.tone
      }
    }

    return counts
      .map { label, count in
        let tone = tones[label] ?? ""
        let detail: String
        switch tone {
        case "spacemail":
          detail = "SpaceMail intake can create item verification work when an order is created or linked from Inbox."
        case "gmail":
          detail = "Gmail intake can create item verification work when an order is created or linked from Inbox."
        case "mock":
          detail = "Mock mailbox intake supports local package-content testing. Confirm live provider context before operational handoff."
        default:
          detail = "Local mailbox intake can create package content checks once linked to an order."
        }
        return (label: label, count: count, detail: detail, symbol: providerSymbol(for: tone, label: label), color: sourceColor(for: tone))
      }
      .sorted { lhs, rhs in
        if lhs.count != rhs.count { return lhs.count > rhs.count }
        return lhs.label < rhs.label
      }
  }


  private func linkedOrder(for content: PackageContentRecord) -> TrackedOrder? {
    let orderID = content.orderID ?? (content.linkedEntityType == .order ? UUID(uuidString: content.linkedEntityID) : nil)
    guard let orderID else { return nil }
    return store.orders.first { $0.id == orderID }
  }

  private func sourceColor(for tone: String) -> Color {
    switch tone {
    case "spacemail": return .teal
    case "gmail": return .blue
    case "mock": return .purple
    case "microsoft", "mailbox": return .blue
    default: return .secondary
    }
  }

  private func providerSymbol(for tone: String, label: String) -> String {
    if tone == "gmail" || label.localizedCaseInsensitiveContains("Gmail") {
      return "envelope.badge.shield.half.filled"
    }
    if tone == "spacemail" || label.localizedCaseInsensitiveContains("SpaceMail") {
      return "server.rack"
    }
    if tone == "mock" {
      return "testtube.2"
    }
    return "envelope.open.fill"
  }

  private func packageContent(_ content: PackageContentRecord, matches query: String) -> Bool {
    let order = linkedOrder(for: content)
    let costRecords = store.suggestedCostRecords(for: content)
    let returnClaims = store.suggestedReturnClaims(for: content)
    let procurementRequests = store.suggestedProcurementRequests(for: content)
    let receivingInspections = store.suggestedReceivingInspections(for: content)
    let inventoryReceipts = store.suggestedInventoryReceipts(for: content)
    let storageLocations = store.suggestedStorageLocations(for: content)
    let custodyRecords = store.suggestedCustodyRecords(for: content)
    let labelReferences = store.suggestedLabelReferenceRecords(for: content)
    let scanSessions = store.suggestedScanSessionRecords(for: content)
    let shipmentManifests = store.suggestedShipmentManifestRecords(for: content)
    let dispatchChecklists = store.suggestedDispatchReadinessChecklists(for: content)
    let mailboxSummaries = order.map { store.mailboxSourceSummaries(for: $0) } ?? []
    var searchParts: [String] = [
      content.id.uuidString,
      content.title,
      content.linkedEntityType.rawValue,
      content.linkedEntityID,
      content.orderID?.uuidString ?? "",
      content.shipmentGroupID?.uuidString ?? "",
      content.destinationAddressID?.uuidString ?? "",
      content.deliveryInstructionID?.uuidString ?? "",
      content.customerProfileID?.uuidString ?? "",
      content.itemSummary,
      "\(content.expectedQuantity)",
      "\(content.verifiedQuantity)",
      content.itemCategory.rawValue,
      content.valueBand.rawValue,
      content.verificationStatus.rawValue,
      content.discrepancySummary,
      content.riskLevel.rawValue,
      content.createdDate,
      content.lastReviewedDate,
      content.reviewState.rawValue,
      order?.orderNumber ?? "",
      order?.store ?? "",
      order?.customer ?? "",
      order?.recipientEmail ?? "",
      order?.trackingNumber ?? "",
      order?.carrier ?? "",
      order?.destination ?? ""
    ]
    searchParts.append(contentsOf: content.evidenceAttachmentIDs.map(\.uuidString))
    searchParts.append(contentsOf: costRecords.map(\.title))
    searchParts.append(contentsOf: costRecords.map(\.budgetCode))
    searchParts.append(contentsOf: returnClaims.map(\.title))
    searchParts.append(contentsOf: procurementRequests.map(\.title))
    searchParts.append(contentsOf: receivingInspections.map(\.title))
    searchParts.append(contentsOf: inventoryReceipts.map(\.title))
    searchParts.append(contentsOf: storageLocations.map(\.title))
    searchParts.append(contentsOf: storageLocations.map(\.locationCode))
    searchParts.append(contentsOf: custodyRecords.map(\.title))
    searchParts.append(contentsOf: labelReferences.map(\.title))
    searchParts.append(contentsOf: scanSessions.map(\.title))
    searchParts.append(contentsOf: shipmentManifests.map(\.title))
    searchParts.append(contentsOf: dispatchChecklists.map(\.title))
    searchParts.append(contentsOf: mailboxSummaries.map(\.providerName))
    searchParts.append(contentsOf: mailboxSummaries.map(\.mailboxLabel))
    searchParts.append(contentsOf: mailboxSummaries.map(\.statusLabel))
    searchParts.append(contentsOf: mailboxSummaries.map(\.detailText))
    let searchableText = searchParts.joined(separator: " ")
    return searchableText.localizedLowercase.contains(query)
  }
}

struct PackageContentRow: View {
  var content: PackageContentRecord
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
  var costRecords: [CostRecord] = []
  var returnClaims: [ReturnClaimRecord] = []
  var procurementRequests: [ProcurementRequest] = []
  var receivingInspections: [ReceivingInspectionRecord] = []
  var inventoryReceipts: [InventoryReceiptRecord] = []
  var storageLocations: [StorageLocationRecord] = []
  var custodyRecords: [CustodyRecord] = []
  var labelReferences: [LabelReferenceRecord] = []
  var scanSessions: [ScanSessionRecord] = []
  var shipmentManifests: [ShipmentManifestRecord] = []
  var dispatchChecklists: [DispatchReadinessChecklist] = []
  var onSave: (PackageContentRecord) -> Void
  var onVerified: () -> Void
  var onDiscrepancy: () -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false
  @State private var feedbackMessage: String?

  private var linkedIntakeEmails: [ForwardedEmailIntake] {
    guard let store, let linkedOrder else { return [] }
    return store.linkedIntakeEmails(for: linkedOrder)
  }

  private var linkedWishlistItems: [WishlistItem] {
    guard let store, let linkedOrder else { return [] }
    return store.activeWishlistItemsLinked(to: linkedOrder)
  }

  private var needsInboxVerificationAttention: Bool {
    (!linkedIntakeEmails.isEmpty || !linkedWishlistItems.isEmpty) && content.verificationStatus != .verified
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: content.itemCategory.symbol)
          .foregroundStyle(content.riskLevel.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(content.title)
                .font(.headline)
              Text("\(content.itemCategory.rawValue) • \(content.valueBand.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(content.verificationStatus.rawValue, color: content.verificationStatus.color)
          }

          Text(content.itemSummary)
            .foregroundStyle(.secondary)
          Text(content.discrepancySummary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          HStack(spacing: 8) {
            Badge(content.riskLevel.rawValue, color: content.riskLevel.color)
            Badge(content.reviewState.rawValue, color: content.reviewState.color)
            Label("\(content.verifiedQuantity)/\(content.expectedQuantity)", systemImage: "number.circle.fill")
              .font(.caption)
              .foregroundStyle(.secondary)
            Label(content.linkedEntityType.rawValue, systemImage: content.linkedEntityType.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      if !linkedIntakeEmails.isEmpty || !linkedWishlistItems.isEmpty || needsInboxVerificationAttention {
        packageContentInboxSourceTrail
      }

      if let store {
        OrderMailboxSourceTrailPanel(
          summaries: mailboxSummaries(using: store),
          title: "Mailbox provider content trail",
          symbol: "shippingbox.circle.fill"
        )
      }

      CostRecordStrip(costs: costRecords)
      ReturnClaimStrip(claims: returnClaims)
      ProcurementRequestStrip(requests: procurementRequests)
      ReceivingInspectionStrip(inspections: receivingInspections)
      InventoryReceiptStrip(receipts: inventoryReceipts)
      StorageLocationStrip(locations: storageLocations)
      CustodyRecordStrip(records: custodyRecords)
      LabelReferenceStrip(records: labelReferences)
      ScanSessionStrip(records: scanSessions)

      if let feedbackMessage {
        PackageContentActionFeedbackPanel(message: feedbackMessage, store: store)
      }

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Verified", systemImage: "checkmark.seal.fill") {
          onVerified()
          feedbackMessage = "Package content marked verified locally."
        }
          .buttonStyle(.bordered)
        Button("Discrepancy", systemImage: "exclamationmark.triangle.fill") {
          onDiscrepancy()
          feedbackMessage = "Package content marked with a local discrepancy."
        }
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.circle.fill") {
          onReviewed()
          feedbackMessage = "Package content marked reviewed locally."
        }
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Follow-up task created from package content. Check Tasks."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Draft created from package content. Check Drafts."
        }
          .buttonStyle(.bordered)
        if let store, let linkedOrder {
          NavigationLink {
            OrderDetailView(order: linkedOrder, store: store)
          } label: {
            Label("Open order", systemImage: "arrow.up.right.square.fill")
          }
          .buttonStyle(.bordered)
        }
        Button("Remove", systemImage: "trash", role: .destructive) {
          onRemove()
          feedbackMessage = "Package content removed locally."
        }
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      PackageContentEditView(content: content) { updatedContent in
        onSave(updatedContent)
        feedbackMessage = "Package content saved locally."
      }
    }
  }

  private var packageContentInboxSourceTrail: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label("Inbox/Wishlist item verification context", systemImage: "envelope.open.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(sourceTrailDescription)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactMetadataGrid(minimumWidth: 140) {
        if needsInboxVerificationAttention {
          Badge("Verify before handoff", color: .orange)
        }
        if let linkedOrder {
          Badge(linkedOrder.orderNumber, color: .blue)
        }
        ForEach(linkedWishlistItems.prefix(2)) { item in
          Badge("Wishlist \(item.itemName)", color: .pink)
        }
        ForEach(linkedIntakeEmails.prefix(3)) { email in
          if let store {
            let source = store.intakeSourceSummary(for: email)
            Badge(source.label, color: sourceColor(for: source.tone))
          }
          Badge(email.detectedTrackingNumber, color: email.detectedTrackingNumber.isPlaceholderValidationValue ? .orange : .teal)
        }
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
  }

  private var sourceTrailDescription: String {
    if needsInboxVerificationAttention {
      return "This item record came from an Inbox-created or Wishlist-linked order and still needs local quantity/item verification before downstream work."
    }
    if !linkedWishlistItems.isEmpty && linkedIntakeEmails.isEmpty {
      return "Wishlist purchase context is linked to this package content record. Confirm item and quantity before downstream work."
    }
    return "Inbox intake or Wishlist context is linked to this package content record. Provider IDs stay in Audit/details."
  }

  private func mailboxSummaries(using store: ParcelOpsStore) -> [OrderMailboxSourceSummary] {
    guard let linkedOrder else { return [] }
    return store.mailboxSourceSummaries(for: linkedOrder)
  }

  private func sourceColor(for tone: String) -> Color {
    switch tone {
    case "spacemail":
      return .teal
    case "gmail":
      return .blue
    case "mock":
      return .purple
    case "microsoft", "mailbox":
      return .blue
    default:
      return .secondary
    }
  }
}

private struct PackageContentActionFeedbackPanel: View {
  var message: String
  var store: ParcelOpsStore?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(message, systemImage: "checkmark.circle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.green)
      Text("This is local package verification only. No inventory system, barcode scanner, OCR, carrier, supplier, or mailbox action was used.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      if let store {
        CompactActionRow {
          if message.localizedCaseInsensitiveContains("task") {
            NavigationLink { TasksView(store: store) } label: { Label("Open Tasks", systemImage: "checklist") }
          }
          if message.localizedCaseInsensitiveContains("draft") {
            NavigationLink { CommunicationView(store: store) } label: { Label("Open Drafts", systemImage: "envelope.open.fill") }
          }
          NavigationLink { AuditView(store: store) } label: { Label("Open Audit", systemImage: "list.clipboard.fill") }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.green.opacity(0.10))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct PackageContentEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: PackageContentRecord
  var onSave: (PackageContentRecord) -> Void

  init(content: PackageContentRecord, onSave: @escaping (PackageContentRecord) -> Void) {
    self._draft = State(initialValue: content)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Content") {
          TextField("Title", text: $draft.title)
          TextField("Item summary", text: $draft.itemSummary, axis: .vertical)
          Stepper("Expected quantity: \(draft.expectedQuantity)", value: $draft.expectedQuantity, in: 0...999)
          Stepper("Verified quantity: \(draft.verifiedQuantity)", value: $draft.verifiedQuantity, in: 0...999)
          Picker("Category", selection: $draft.itemCategory) {
            ForEach(PackageItemCategory.allCases) { category in
              Text(category.rawValue).tag(category)
            }
          }
          Picker("Value band", selection: $draft.valueBand) {
            ForEach(PackageValueBand.allCases) { band in
              Text(band.rawValue).tag(band)
            }
          }
        }

        Section("Verification") {
          Picker("Status", selection: $draft.verificationStatus) {
            ForEach(PackageVerificationStatus.allCases) { status in
              Text(status.rawValue).tag(status)
            }
          }
          TextField("Discrepancy summary", text: $draft.discrepancySummary, axis: .vertical)
          Picker("Risk", selection: $draft.riskLevel) {
            ForEach(ShipmentRiskLevel.allCases) { risk in
              Text(risk.rawValue).tag(risk)
            }
          }
          Picker("Review state", selection: $draft.reviewState) {
            ForEach([ReviewState.needsReview, .monitor, .accepted], id: \.self) { state in
              Text(state.rawValue).tag(state)
            }
          }
          TextField("Last reviewed", text: $draft.lastReviewedDate)
        }

        Section("Link") {
          Picker("Linked record type", selection: $draft.linkedEntityType) {
            ForEach(ReviewTaskLinkedEntityType.allCases) { type in
              Text(type.rawValue).tag(type)
            }
          }
          TextField("Linked record ID", text: $draft.linkedEntityID)
        }
      }
      .navigationTitle("Edit Content")
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
    .frame(minWidth: 560, minHeight: 560)
  }
}
