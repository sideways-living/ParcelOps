import SwiftUI

struct ScanSessionsView: View {
  var store: ParcelOpsStore
  @State private var selectedPurpose: ScanPurpose?
  @State private var selectedMethod: ScanMethodPlaceholder?
  @State private var selectedStatus: ScanSessionStatus?
  @State private var operatorTeam = ""
  @State private var selectedRiskLevel: ShipmentRiskLevel?
  @State private var selectedLinkedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedReviewState: ReviewState?
  @State private var scanSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var baseFilteredRecords: [ScanSessionRecord] {
    store.filteredScanSessionRecords(scanPurpose: selectedPurpose, scanMethod: selectedMethod, scanStatus: selectedStatus, operatorTeam: operatorTeam, riskLevel: selectedRiskLevel, linkedEntityType: selectedLinkedEntityType, reviewState: selectedReviewState)
  }

  private var filteredRecords: [ScanSessionRecord] {
    let query = scanSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredRecords }
    return baseFilteredRecords.filter { scanSession($0, matches: query) }
  }

  private var hasActiveFilters: Bool {
    selectedPurpose != nil
      || selectedMethod != nil
      || selectedStatus != nil
      || !operatorTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || selectedRiskLevel != nil
      || selectedLinkedEntityType != nil
      || selectedReviewState != nil
      || !scanSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filterBar
        inboxScanCoverage
        gmailScanReadinessPanel

        SettingsPanel(title: "Scan session records", symbol: "qrcode.viewfinder") {
          HStack {
            Text("\(filteredRecords.count) visible scan sessions")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredRecords.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add scan", systemImage: "plus", action: store.addScanSessionPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredRecords.isEmpty {
            MVPEmptyState(title: "No scan sessions match this view", detail: hasActiveFilters ? "Clear search or filters to return to all local scan sessions." : "Add a local scan session placeholder to track expected and captured label values without scanner hardware.", symbol: "qrcode.viewfinder", actionTitle: hasActiveFilters ? "Clear filters" : "Add scan", action: hasActiveFilters ? clearFilters : store.addScanSessionPlaceholder)
          } else {
            ForEach(filteredRecords) { record in
              ScanSessionRow(record: record, store: store, linkedOrder: linkedOrder(for: record), shipmentManifests: store.suggestedShipmentManifestRecords(for: record), dispatchChecklists: store.suggestedDispatchReadinessChecklists(for: record)) { updatedRecord in
                store.updateScanSessionRecord(updatedRecord)
              } onMatched: {
                store.markScanSessionMatched(record)
              } onMismatch: {
                store.markScanSessionMismatch(record)
              } onCompleted: {
                store.markScanSessionCompleted(record)
              } onReopen: {
                store.reopenScanSession(record)
              } onReviewed: {
                store.markScanSessionReviewed(record)
              } onCreateTask: {
                store.createReviewTask(from: record)
              } onCreateDraft: {
                store.createDraftMessage(from: record)
              } onRemove: {
                store.removeScanSessionRecord(record)
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
        Text("Scan Sessions")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Local manual verification sessions for barcode, QR, label, order, custody, receiving, and inventory checks.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(store.mismatchScanSessions.count) mismatch", color: .red)
        Badge("\(store.incompleteScanSessions.count) incomplete", color: .orange)
      }
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search scan, label value, operator, mismatch, location, custody, manifest, order, or evidence", text: $scanSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Purpose", selection: $selectedPurpose) {
        Text("All purposes").tag(nil as ScanPurpose?)
        ForEach(ScanPurpose.allCases) { purpose in Text(purpose.rawValue).tag(purpose as ScanPurpose?) }
      }

      Picker("Method", selection: $selectedMethod) {
        Text("All methods").tag(nil as ScanMethodPlaceholder?)
        ForEach(ScanMethodPlaceholder.allCases) { method in Text(method.rawValue).tag(method as ScanMethodPlaceholder?) }
      }

      Picker("Status", selection: $selectedStatus) {
        Text("All status").tag(nil as ScanSessionStatus?)
        ForEach(ScanSessionStatus.allCases) { status in Text(status.rawValue).tag(status as ScanSessionStatus?) }
      }

      TextField("Operator/team", text: $operatorTeam)
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

  private var inboxScanCoverage: some View {
    let inboxOrders = inboxCreatedOrders
    let wishlistOrders = wishlistLinkedOrders
    let linkedScans = scansLinkedToInboxOrders
    let actionScans = scansNeedingAction
    let missingScanCount = inboxOrdersMissingScan.count

    return SettingsPanel(title: "Inbox and Wishlist scan readiness", symbol: "qrcode.viewfinder") {
      VStack(alignment: .leading, spacing: 10) {
        Text("Checks whether orders created from Inbox intake or Wishlist purchase handoff have local manual label or order verification sessions before dispatch.")
          .font(.caption)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 150) {
          Badge("\(inboxOrders.count) Inbox orders", color: .blue)
          Badge("\(wishlistOrders.count) Wishlist orders", color: .pink)
          Badge("\(linkedScans.count) linked scans", color: .teal)
          Badge("\(actionScans.count) need action", color: actionScans.isEmpty ? .green : .orange)
          Badge("\(missingScanCount) missing scans", color: missingScanCount == 0 ? .green : .orange)
        }

        if !scanProviderRows.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Mailbox source for scans")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
              ForEach(scanProviderRows, id: \.label) { row in
                HStack(alignment: .top, spacing: 10) {
                  Image(systemName: row.symbol)
                    .foregroundStyle(row.color)
                    .frame(width: 22, height: 22)
                  VStack(alignment: .leading, spacing: 4) {
                    HStack {
                      Text(row.label)
                        .font(.caption.weight(.semibold))
                      Spacer()
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

        if inboxOrders.isEmpty && wishlistOrders.isEmpty {
          Text("No Inbox-created or Wishlist-linked orders are present yet. Create an order from Inbox or complete a Wishlist purchase handoff before checking scan readiness.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if linkedScans.isEmpty {
          Text("Inbox-created or Wishlist-linked orders do not have scan sessions yet. Add a session when label, order, custody, or inventory verification is needed.")
            .font(.caption)
            .foregroundStyle(.orange)
        } else {
          ForEach(Array(actionScans.prefix(3))) { record in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: record.scanStatus == .mismatchNeedsReview ? "exclamationmark.triangle.fill" : "qrcode.viewfinder")
                .foregroundStyle(record.scanStatus == .mismatchNeedsReview ? .red : .orange)
              VStack(alignment: .leading, spacing: 2) {
                Text(record.title)
                  .font(.caption.bold())
                Text(scanActionSummary(for: record))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Badge(record.scanStatus.rawValue, color: record.scanStatus.color)
            }
          }

          if actionScans.isEmpty {
            Text("Linked scan sessions look matched, completed, assigned, and reviewed for current Inbox-created and Wishlist-linked orders.")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else if actionScans.count > 3 {
            Text("\(actionScans.count - 3) more linked scan sessions need captured values, label links, completion, or review.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private var scanProviderRows: [(label: String, count: Int, detail: String, symbol: String, color: Color)] {
    var counts: [String: Int] = [:]
    var tones: [String: String] = [:]
    for order in inboxCreatedOrders {
      for email in linkedIntakeEmails(for: order) {
        let summary = store.intakeSourceSummary(for: email)
        counts[summary.label, default: 0] += 1
        tones[summary.label] = summary.tone
      }
    }
    return counts.map { label, count in
      let tone = tones[label] ?? ""
      let detail: String
      switch tone {
      case "spacemail":
        detail = "SpaceMail intake can drive scan verification after an Inbox order is linked, labeled, stored, or prepared for dispatch."
      case "gmail":
        detail = "Gmail intake can drive scan verification after an Inbox order is linked, labeled, stored, or prepared for dispatch."
      case "mock":
        detail = "Mock mailbox intake supports local scan testing. Confirm live provider context before dispatch readiness."
      default:
        detail = "Local mailbox intake can drive scan verification once linked to an order."
      }
      return (
        label: label,
        count: count,
        detail: detail,
        symbol: providerSymbol(for: tone, label: label),
        color: sourceColor(for: tone)
      )
    }
    .sorted { lhs, rhs in
      if lhs.count == rhs.count {
        return lhs.label < rhs.label
      }
      return lhs.count > rhs.count
    }
  }

  private var gmailScanReadinessPanel: some View {
    GmailReleaseBoundaryPanel(
      store: store,
      title: "Gmail scan readiness",
      lead: "Gmail-origin intake should create scan verification work only after Gmail setup is ready and the imported Inbox order has confirmed label, tracking, custody, or dispatch context.",
      sourceMetricTitle: "Gmail scan sources",
      sourceCount: gmailScanSourceCount,
      boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store tokens, access camera/scanner hardware, generate QR codes, or change scan session records automatically."
    )
  }

  private var gmailScanSourceCount: Int {
    scanProviderRows
      .filter { $0.label.localizedCaseInsensitiveContains("Gmail") }
      .reduce(0) { total, row in total + row.count }
  }

  private func clearFilters() {
    selectedPurpose = nil
    selectedMethod = nil
    selectedStatus = nil
    operatorTeam = ""
    selectedRiskLevel = nil
    selectedLinkedEntityType = nil
    selectedReviewState = nil
    scanSearchText = ""
  }

  private func linkedOrder(for record: ScanSessionRecord) -> TrackedOrder? {
    let orderID = record.orderID ?? (record.linkedEntityType == .order ? UUID(uuidString: record.linkedEntityID) : nil)
    guard let orderID else { return nil }
    return store.orders.first { $0.id == orderID }
  }

  private var inboxCreatedOrders: [TrackedOrder] {
    store.orders.filter { !linkedIntakeEmails(for: $0).isEmpty }
  }

  private var wishlistLinkedOrders: [TrackedOrder] {
    store.wishlistLinkedOrders
  }

  private var scanSourceOrders: [TrackedOrder] {
    store.operatorSourceOrders
  }

  private var scansLinkedToInboxOrders: [ScanSessionRecord] {
    let orderIDs = Set(scanSourceOrders.map(\.id))
    let receiptIDs = Set(store.inventoryReceipts.filter { receipt in
      if let orderID = receipt.orderID, orderIDs.contains(orderID) {
        return true
      }
      if receipt.linkedEntityType == .order, let linkedID = UUID(uuidString: receipt.linkedEntityID), orderIDs.contains(linkedID) {
        return true
      }
      return false
    }.map(\.id))
    let locationIDs = Set(store.storageLocations.filter { location in
      !Set(location.orderIDs).isDisjoint(with: orderIDs) || !Set(location.inventoryReceiptIDs).isDisjoint(with: receiptIDs)
    }.map(\.id))
    let custodyIDs = Set(store.custodyRecords.filter { record in
      (record.orderID.map { orderIDs.contains($0) } ?? false)
        || (record.inventoryReceiptID.map { receiptIDs.contains($0) } ?? false)
        || (record.storageLocationID.map { locationIDs.contains($0) } ?? false)
    }.map(\.id))
    let labelIDs = Set(store.labelReferenceRecords.filter { record in
      (record.orderID.map { orderIDs.contains($0) } ?? false)
        || (record.inventoryReceiptID.map { receiptIDs.contains($0) } ?? false)
        || (record.storageLocationID.map { locationIDs.contains($0) } ?? false)
        || (record.custodyRecordID.map { custodyIDs.contains($0) } ?? false)
    }.map(\.id))

    return store.scanSessionRecords.filter { record in
      (record.orderID.map { orderIDs.contains($0) } ?? false)
        || (record.inventoryReceiptID.map { receiptIDs.contains($0) } ?? false)
        || (record.scanLocationStorageLocationID.map { locationIDs.contains($0) } ?? false)
        || (record.custodyRecordID.map { custodyIDs.contains($0) } ?? false)
        || (record.linkedLabelReferenceID.map { labelIDs.contains($0) } ?? false)
        || (record.linkedEntityType == .order && UUID(uuidString: record.linkedEntityID).map { orderIDs.contains($0) } == true)
    }
  }

  private var inboxOrdersMissingScan: [TrackedOrder] {
    let scanOrderIDs = Set(scansLinkedToInboxOrders.compactMap { record -> UUID? in
      record.orderID ?? (record.linkedEntityType == .order ? UUID(uuidString: record.linkedEntityID) : nil)
    })
    return scanSourceOrders.filter { !scanOrderIDs.contains($0.id) }
  }

  private func uniqueOrders(_ orders: [TrackedOrder]) -> [TrackedOrder] {
    var seen: Set<UUID> = []
    var unique: [TrackedOrder] = []
    for order in orders where seen.contains(order.id) == false {
      seen.insert(order.id)
      unique.append(order)
    }
    return unique
  }

  private var scansNeedingAction: [ScanSessionRecord] {
    scansLinkedToInboxOrders.filter { record in
      record.scanStatus == .planned
        || record.scanStatus == .mismatchNeedsReview
        || record.scanStatus == .reopened
        || record.scanStatus == .blocked
        || record.reviewState != .accepted
        || record.riskLevel == .high
        || record.riskLevel == .critical
        || record.capturedValuePlaceholder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || record.linkedLabelReferenceID == nil
        || record.assignedOperatorTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
  }

  private func scanActionSummary(for record: ScanSessionRecord) -> String {
    var parts: [String] = []
    if record.scanStatus == .planned || record.scanStatus == .reopened || record.scanStatus == .blocked { parts.append("complete scan") }
    if record.scanStatus == .mismatchNeedsReview { parts.append("resolve mismatch") }
    if record.capturedValuePlaceholder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { parts.append("capture value") }
    if record.linkedLabelReferenceID == nil { parts.append("link label") }
    if record.assignedOperatorTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { parts.append("assign operator") }
    if record.riskLevel == .high || record.riskLevel == .critical { parts.append("review risk") }
    if record.reviewState != .accepted { parts.append("mark reviewed") }
    return parts.isEmpty ? "Scan session is matched, completed, assigned, and reviewed." : parts.joined(separator: ", ")
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

  private func linkedIntakeEmails(for order: TrackedOrder) -> [ForwardedEmailIntake] {
    store.linkedIntakeEmails(for: order)
  }

  private func scanSession(_ record: ScanSessionRecord, matches query: String) -> Bool {
    let order = linkedOrder(for: record)
    let shipmentManifests = store.suggestedShipmentManifestRecords(for: record)
    let dispatchChecklists = store.suggestedDispatchReadinessChecklists(for: record)
    var searchParts: [String] = [
      record.id.uuidString,
      record.title,
      record.linkedEntityType.rawValue,
      record.linkedEntityID,
      record.scanPurpose.rawValue,
      record.scanMethodPlaceholder.rawValue,
      record.expectedLabelReferenceValue,
      record.capturedValuePlaceholder,
      record.scanStatus.rawValue,
      record.mismatchSummary,
      record.assignedOperatorTeam,
      record.createdDate,
      record.completedDate,
      record.notes,
      record.riskLevel.rawValue,
      record.reviewState.rawValue,
      order?.orderNumber ?? "",
      order?.store ?? "",
      order?.customer ?? "",
      order?.recipientEmail ?? "",
      order?.trackingNumber ?? "",
      order?.carrier ?? "",
      order?.destination ?? ""
    ]
    searchParts.append(contentsOf: [
      record.linkedLabelReferenceID?.uuidString ?? "",
      record.scanLocationStorageLocationID?.uuidString ?? "",
      record.custodyRecordID?.uuidString ?? "",
      record.inventoryReceiptID?.uuidString ?? "",
      record.orderID?.uuidString ?? "",
      record.shipmentGroupID?.uuidString ?? "",
      record.packageContentID?.uuidString ?? ""
    ])
    searchParts.append(contentsOf: record.evidenceAttachmentIDs.map(\.uuidString))
    searchParts.append(contentsOf: shipmentManifests.flatMap { [$0.title, $0.manifestReferencePlaceholder, $0.carrierCourier, $0.destinationSummary] })
    searchParts.append(contentsOf: dispatchChecklists.flatMap { [$0.title, $0.checklistType.rawValue, $0.checklistStatus.rawValue, $0.assignedOwnerTeam] })
    return searchParts.joined(separator: " ").localizedLowercase.contains(query)
  }
}

struct ScanSessionRow: View {
  var record: ScanSessionRecord
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
  var shipmentManifests: [ShipmentManifestRecord] = []
  var dispatchChecklists: [DispatchReadinessChecklist] = []
  var onSave: (ScanSessionRecord) -> Void
  var onMatched: () -> Void
  var onMismatch: () -> Void
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
        Image(systemName: record.scanPurpose.symbol)
          .foregroundStyle(record.riskLevel.color)
          .frame(width: 28, height: 28)
        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(record.title)
                .font(.headline)
              Text("\(record.scanPurpose.rawValue) • \(record.scanMethodPlaceholder.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(record.scanStatus.rawValue, color: record.scanStatus.color)
          }
          Text("Expected \(record.expectedLabelReferenceValue) • captured \(record.capturedValuePlaceholder.isEmpty ? "missing" : record.capturedValuePlaceholder)")
            .foregroundStyle(.secondary)
          Text("\(record.mismatchSummary) • Operator \(record.assignedOperatorTeam)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)
          HStack(spacing: 8) {
            Badge(record.riskLevel.rawValue, color: record.riskLevel.color)
            Badge(record.reviewState.rawValue, color: record.reviewState.color)
            Label(record.linkedEntityType.rawValue, systemImage: record.linkedEntityType.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
            Label(record.completedDate, systemImage: "calendar")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      if !scanWarnings.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Label("Scan follow-up", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.bold())
            .foregroundStyle(.orange)
          ForEach(scanWarnings, id: \.self) { warning in
            Text(warning)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      if let store, let linkedOrder {
        let linkedEmails = linkedIntakeEmails(for: linkedOrder, store: store)
        let linkedWishlistItems = store.activeWishlistItemsLinked(to: linkedOrder)
        if !linkedEmails.isEmpty || !linkedWishlistItems.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Label("Inbox/Wishlist scan source", systemImage: "tray.and.arrow.down.fill")
              .font(.caption.bold())
              .foregroundStyle(.teal)
            ForEach(linkedWishlistItems.prefix(2)) { item in
              HStack(spacing: 6) {
                Badge("Wishlist", color: .pink)
                if let handoff = item.purchaseHandoff {
                  Badge(handoff.purchaseStatus, color: .secondary)
                }
                Text(item.itemName)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
            }
            ForEach(linkedEmails.prefix(2)) { email in
              HStack(spacing: 6) {
                let sourceSummary = store.intakeSourceSummary(for: email)
                Badge(sourceSummary.label, color: sourceColor(for: sourceSummary.tone))
                if !email.detectedTrackingNumber.isPlaceholderValidationValue {
                  Badge("Tracking \(email.detectedTrackingNumber)", color: .teal)
                }
                if !email.detectedOrderNumber.isPlaceholderValidationValue {
                  Badge("Order \(email.detectedOrderNumber)", color: .blue)
                }
                Text(email.subject)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
            }
          }
        }
      }

      if let feedbackMessage {
        ScanSessionActionFeedbackPanel(message: feedbackMessage)
      }

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Matched", systemImage: "checkmark.circle.fill") {
          onMatched()
          feedbackMessage = "Scan marked matched locally. No camera, scanner hardware, or barcode service was used."
        }
          .buttonStyle(.bordered)
        Button("Mismatch", systemImage: "exclamationmark.triangle.fill") {
          onMismatch()
          feedbackMessage = "Scan marked mismatch locally. Review linked label, custody, and dispatch readiness before handoff."
        }
          .buttonStyle(.bordered)
        Button("Complete", systemImage: "checkmark.seal.fill") {
          onCompleted()
          feedbackMessage = "Scan session completed locally. Confirm label and dispatch context before closing related work."
        }
          .buttonStyle(.bordered)
        Button("Reopen", systemImage: "arrow.counterclockwise") {
          onReopen()
          feedbackMessage = "Scan session reopened locally for another manual verification pass."
        }
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.shield.fill") {
          onReviewed()
          feedbackMessage = "Scan session marked reviewed locally. No scanner, camera, or warehouse system was contacted."
        }
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Review task created from this scan session for local follow-up."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Draft message created from this scan session. It remains local until a person sends anything outside ParcelOps."
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
          feedbackMessage = "Scan session removed locally. No mailbox, scanner, camera, or warehouse system was changed."
        }
          .buttonStyle(.bordered)
      }

      if !shipmentManifests.isEmpty {
        ShipmentManifestStrip(records: shipmentManifests)
      }
      if !dispatchChecklists.isEmpty {
        DispatchReadinessStrip(checklists: dispatchChecklists)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      ScanSessionEditView(record: record) { updatedRecord in
        onSave(updatedRecord)
        feedbackMessage = "Scan session details saved locally. Recheck expected and captured values if dispatch readiness depends on this scan."
      }
    }
  }

  private var scanWarnings: [String] {
    var warnings: [String] = []
    if record.scanStatus == .planned || record.scanStatus == .reopened || record.scanStatus == .blocked {
      warnings.append("Scan is not complete yet.")
    }
    if record.scanStatus == .mismatchNeedsReview {
      warnings.append("Scan mismatch needs review before dispatch or handoff.")
    }
    if record.capturedValuePlaceholder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      warnings.append("Captured value is missing.")
    }
    if record.linkedLabelReferenceID == nil {
      warnings.append("No label reference is linked.")
    }
    if record.assignedOperatorTeam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      warnings.append("Operator/team is missing.")
    }
    if record.riskLevel == .high || record.riskLevel == .critical {
      warnings.append("Risk is \(record.riskLevel.rawValue.lowercased()); confirm scan handling.")
    }
    if record.reviewState != .accepted {
      warnings.append("Review state is \(record.reviewState.rawValue.lowercased()); mark reviewed after local checks are complete.")
    }
    return warnings
  }

  private func linkedIntakeEmails(for order: TrackedOrder, store: ParcelOpsStore) -> [ForwardedEmailIntake] {
    store.linkedIntakeEmails(for: order)
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
}

private struct ScanSessionActionFeedbackPanel: View {
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

struct ScanSessionEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: ScanSessionRecord
  var onSave: (ScanSessionRecord) -> Void

  init(record: ScanSessionRecord, onSave: @escaping (ScanSessionRecord) -> Void) {
    self._draft = State(initialValue: record)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Scan") {
          TextField("Title", text: $draft.title)
          Picker("Purpose", selection: $draft.scanPurpose) {
            ForEach(ScanPurpose.allCases) { purpose in Text(purpose.rawValue).tag(purpose) }
          }
          Picker("Method", selection: $draft.scanMethodPlaceholder) {
            ForEach(ScanMethodPlaceholder.allCases) { method in Text(method.rawValue).tag(method) }
          }
          Picker("Status", selection: $draft.scanStatus) {
            ForEach(ScanSessionStatus.allCases) { status in Text(status.rawValue).tag(status) }
          }
          TextField("Expected value", text: $draft.expectedLabelReferenceValue)
          TextField("Captured value", text: $draft.capturedValuePlaceholder)
          TextField("Mismatch summary", text: $draft.mismatchSummary, axis: .vertical)
        }

        Section("Ownership") {
          TextField("Operator/team", text: $draft.assignedOperatorTeam)
          TextField("Created date", text: $draft.createdDate)
          TextField("Completed date", text: $draft.completedDate)
          TextField("Notes", text: $draft.notes, axis: .vertical)
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
      .navigationTitle("Edit Scan")
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
    .frame(minWidth: 640, minHeight: 680)
  }
}
