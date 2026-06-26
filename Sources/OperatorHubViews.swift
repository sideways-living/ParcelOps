import SwiftUI

struct InboxView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }
  private var triageItems: [InboxTriageItem] {
    let acceptanceItems = store.acceptanceRecordsNeedingReview.compactMap { record in
      store.acceptanceCandidates.first { $0.sourceType == record.sourceType && $0.sourceID == record.sourceID }
    }
    let acceptanceKeys = Set(acceptanceItems.map { InboxTriageItem.sourceKey(sourceType: $0.sourceType, sourceID: $0.sourceID) })

    let emailItems = store.reviewIntakeEmails
      .filter { !acceptanceKeys.contains(InboxTriageItem.sourceKey(sourceType: .intakeEmail, sourceID: $0.id)) }
      .map(InboxTriageItem.email)

    let importItems = uniqueImportItems(store.blockedImportQueueItems + store.lowConfidenceImportQueueItems + store.importQueueItemsNeedingReview)
      .filter { !acceptanceKeys.contains(InboxTriageItem.sourceKey(sourceType: .importQueueItem, sourceID: $0.id)) }
      .map(InboxTriageItem.importQueue)

    let parserItems = store.intakeParserDiagnostics.map(InboxTriageItem.parserDiagnostic)

    return (acceptanceItems.map(InboxTriageItem.acceptance) + parserItems + emailItems + importItems)
      .sorted { lhs, rhs in
        if lhs.sortPriority == rhs.sortPriority {
          return lhs.capturedDate > rhs.capturedDate
        }
        return lhs.sortPriority > rhs.sortPriority
      }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: isCompact ? 14 : 18) {
        header
        mailboxHealthPanel
        triagePanel
        detailRoutes
      }
      .padding(isCompact ? 14 : 24)
    }
    .background(.regularMaterial)
  }

  private var triagePanel: some View {
    SettingsPanel(title: "Unified triage queue", symbol: "tray.full.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Work the highest-risk incoming order signals here, then open a detailed view when a record needs correction or linking.")
          .font(.callout)
          .foregroundStyle(.secondary)

        if triageItems.isEmpty {
          MVPEmptyState(
            title: "Inbox triage is clear",
            detail: "Forwarded emails, staged imports, and acceptance decisions that need action will appear here.",
            symbol: "checkmark.seal.fill"
          )
        } else {
          ForEach(triageItems.prefix(12)) { item in
            InboxTriageRow(item: item, store: store)
          }
        }
      }
    }
  }

  private var mailboxHealthPanel: some View {
    SettingsPanel(title: "Mailbox intake health", symbol: "server.rack") {
      VStack(alignment: .leading, spacing: 12) {
        Text("SpaceMail is a mixed-use mailbox, so ParcelOps filters likely non-order messages before they reach triage. Use this panel to see whether the latest refresh produced actionable intake or simply filtered normal mail.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        if store.spaceMailIntakeHealthSummaries.isEmpty {
          MVPEmptyState(
            title: "No SpaceMail mailbox configured",
            detail: "Add a SpaceMail setup in Mailbox Monitor or Settings when you are ready to use real IMAP intake.",
            symbol: "server.rack"
          )
        } else {
          ForEach(store.spaceMailIntakeHealthSummaries) { summary in
            InboxMailboxHealthRow(summary: summary)
          }
        }
      }
    }
  }

  private var detailRoutes: some View {
    SettingsPanel(title: "Detailed inbox views", symbol: "rectangle.stack.fill") {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 220 : 260), spacing: 12)], alignment: .leading, spacing: 12) {
        OperatorRouteCard(title: "Mailbox Monitor", detail: "Review forwarded order emails and detected fields.", symbol: "envelope.badge.fill", badge: "\(store.intakeEmails.count) emails") {
          MailboxView(store: store)
        }

        OperatorRouteCard(title: "Import Queue", detail: "Review manually staged order records before accepting them.", symbol: "tray.and.arrow.down.fill", badge: "\(store.importQueueItems.count) imports") {
          ImportQueueView(store: store)
        }

        OperatorRouteCard(title: "Acceptance Review", detail: "Link intake to existing orders or create new local records.", symbol: "checkmark.rectangle.stack.fill", badge: "\(store.acceptanceRecordsNeedingReview.count) to review") {
          AcceptanceReviewView(store: store)
        }
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Inbox")
        .font(isCompact ? .title.bold() : .largeTitle.bold())
      Text("Triage incoming order signals, staged imports, and acceptance decisions before they become operational records.")
        .foregroundStyle(.secondary)

      MetricStrip(items: [
        ("Triage", "\(triageItems.count)", .red),
        ("Emails", "\(store.reviewIntakeEmails.count)", .blue),
        ("Parser", "\(store.intakeParserDiagnostics.count)", .orange),
        ("Mailbox", "\(store.spaceMailIntakeHealthSummaries.filter { $0.tone == "warning" || $0.pendingUncertainReviewCount > 0 || $0.parserIssueCount > 0 || $0.importedCount > 0 }.count)", .purple),
        ("Imports", "\(store.importQueueItemsNeedingReview.count)", .teal),
        ("Acceptance", "\(store.acceptanceRecordsNeedingReview.count)", .orange),
        ("All records", "\(store.intakeEmails.count + store.importQueueItems.count)", .gray)
      ])
    }
  }

  private func uniqueImportItems(_ items: [ImportQueueItem]) -> [ImportQueueItem] {
    var seen: Set<UUID> = []
    var unique: [ImportQueueItem] = []
    for item in items where !seen.contains(item.id) {
      seen.insert(item.id)
      unique.append(item)
    }
    return unique
  }
}

private struct InboxMailboxHealthRow: View {
  var summary: SpaceMailIntakeHealthSummary

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label(summary.displayName, systemImage: "server.rack")
          .font(.subheadline.weight(.semibold))
        Spacer()
        Badge(summary.verdict, color: color)
      }
      Text(summary.detail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      CompactMetadataGrid(minimumWidth: 110) {
        Badge("\(summary.fetchedCount) fetched", color: .blue)
        Badge("\(summary.importedCount) imported", color: summary.importedCount > 0 ? .green : .secondary)
        Badge("\(summary.filteredCount) filtered", color: summary.filteredCount > 0 ? .teal : .secondary)
        Badge("\(summary.duplicateCount) duplicates", color: summary.duplicateCount > 0 ? .orange : .secondary)
        Badge("\(summary.uncertainCount) uncertain", color: summary.uncertainCount > 0 ? .orange : .secondary)
        Badge("\(summary.parserIssueCount) parser checks", color: summary.parserIssueCount > 0 ? .orange : .secondary)
      }
      Text(summary.nextAction)
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .fixedSize(horizontal: false, vertical: true)
      if !summary.topReasonLabels.isEmpty {
        Text("Latest reasons: \(summary.topReasonLabels.joined(separator: "; "))")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(3)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private var color: Color {
    switch summary.tone {
    case "success":
      return .green
    case "attention":
      return .orange
    case "warning":
      return .red
    default:
      return .blue
    }
  }
}

private struct InboxTriageItem: Identifiable {
  var id: String
  var source: InboxTriageSource
  var sourceLabel: String
  var title: String
  var subtitle: String
  var detail: String
  var capturedDate: String
  var confidenceScore: Int?
  var reviewLabel: String
  var linkedOrderID: UUID?
  var linkedShipmentGroupID: UUID?
  var nextAction: String
  var readinessLabel: String
  var readinessDetail: String
  var readinessTone: InboxTriageTone
  var sortPriority: Int

  static func email(_ email: ForwardedEmailIntake) -> InboxTriageItem {
    let readiness = emailReadiness(email)
    return InboxTriageItem(
      id: "email-\(email.id.uuidString)",
      source: .email(email),
      sourceLabel: "Mailbox",
      title: "\(email.detectedMerchant) • \(email.detectedOrderNumber)",
      subtitle: email.subject,
      detail: "Tracking \(email.detectedTrackingNumber) • \(email.detectedDestinationAddress)",
      capturedDate: email.receivedDate,
      confidenceScore: email.localInboxConfidence,
      reviewLabel: email.reviewState.rawValue,
      linkedOrderID: email.linkedOrderID,
      linkedShipmentGroupID: nil,
      nextAction: email.linkedOrderID == nil ? "Link or create order" : "Review detected fields",
      readinessLabel: readiness.label,
      readinessDetail: readiness.detail,
      readinessTone: readiness.tone,
      sortPriority: email.reviewState == .needsReview ? 80 : 35
    )
  }

  static func importQueue(_ item: ImportQueueItem) -> InboxTriageItem {
    let readiness = importReadiness(item)
    return InboxTriageItem(
      id: "import-\(item.id.uuidString)",
      source: .importQueue(item),
      sourceLabel: "Import",
      title: "\(item.detectedMerchant) • \(item.detectedOrderNumber)",
      subtitle: item.sourceLabel,
      detail: "Tracking \(item.detectedTrackingNumber) • \(item.detectedDestinationAddress)",
      capturedDate: item.capturedDate,
      confidenceScore: item.confidenceScore,
      reviewLabel: item.importStatus.rawValue,
      linkedOrderID: item.suggestedLinkedOrderID,
      linkedShipmentGroupID: item.suggestedShipmentGroupID,
      nextAction: item.importStatus == .blocked ? "Resolve blocked import" : item.confidenceScore < 70 ? "Check low-confidence fields" : "Accept or link import",
      readinessLabel: readiness.label,
      readinessDetail: readiness.detail,
      readinessTone: readiness.tone,
      sortPriority: item.importStatus == .blocked ? 95 : item.confidenceScore < 70 ? 85 : 65
    )
  }

  static func acceptance(_ candidate: AcceptanceCandidate) -> InboxTriageItem {
    let readiness = acceptanceReadiness(candidate)
    return InboxTriageItem(
      id: "acceptance-\(candidate.id)",
      source: .acceptance(candidate),
      sourceLabel: "Acceptance",
      title: "\(candidate.detectedMerchant) • \(candidate.detectedOrderNumber)",
      subtitle: candidate.sourceLabel,
      detail: "Tracking \(candidate.detectedTrackingNumber) • \(candidate.detectedDestinationAddress)",
      capturedDate: candidate.capturedDate,
      confidenceScore: candidate.confidenceScore,
      reviewLabel: candidate.decision.rawValue,
      linkedOrderID: candidate.suggestedLinkedOrderID,
      linkedShipmentGroupID: candidate.suggestedShipmentGroupID,
      nextAction: candidate.suggestedLinkedOrderID == nil ? "Choose order or create one" : "Accept into operations",
      readinessLabel: readiness.label,
      readinessDetail: readiness.detail,
      readinessTone: readiness.tone,
      sortPriority: candidate.decision == .blocked ? 100 : candidate.reviewState == .needsReview ? 90 : 70
    )
  }

  static func parserDiagnostic(_ diagnostic: IntakeParserDiagnostic) -> InboxTriageItem {
    let readiness = parserReadiness(diagnostic)
    return InboxTriageItem(
      id: "parser-\(diagnostic.id)",
      source: .parserDiagnostic(diagnostic),
      sourceLabel: "Parser",
      title: diagnostic.title,
      subtitle: diagnostic.subjectPreview,
      detail: diagnostic.summary,
      capturedDate: diagnostic.capturedDate,
      confidenceScore: nil,
      reviewLabel: diagnostic.severity.rawValue,
      linkedOrderID: nil,
      linkedShipmentGroupID: nil,
      nextAction: diagnostic.recommendedAction,
      readinessLabel: readiness.label,
      readinessDetail: readiness.detail,
      readinessTone: readiness.tone,
      sortPriority: diagnostic.severity == .critical ? 98 : diagnostic.severity == .high ? 92 : 72
    )
  }

  static func sourceKey(sourceType: AcceptanceSourceType, sourceID: UUID) -> String {
    "\(sourceType.rawValue)-\(sourceID.uuidString)"
  }

  private static func emailReadiness(_ email: ForwardedEmailIntake) -> (label: String, detail: String, tone: InboxTriageTone) {
    if email.reviewState == .ignored {
      return ("Ignored locally", "This email is not active unless reopened from the detailed mailbox view.", .muted)
    }

    let missingFields = missingDetectedFields(
      merchant: email.detectedMerchant,
      order: email.detectedOrderNumber,
      tracking: email.detectedTrackingNumber,
      destination: email.detectedDestinationAddress
    )
    if !missingFields.isEmpty {
      return ("Needs correction", "Check \(missingFields.joined(separator: ", ")) before creating or linking an order.", .warning)
    }
    if email.linkedOrderID == nil {
      return ("Ready to link", "Detected order details look usable; link to an existing order or create a new one.", .attention)
    }
    return ("Ready to review", "Linked order context exists; review once and move it forward.", .success)
  }

  private static func importReadiness(_ item: ImportQueueItem) -> (label: String, detail: String, tone: InboxTriageTone) {
    if item.importStatus == .blocked {
      return ("Blocked", "Resolve the blocked import before accepting it into operations.", .warning)
    }
    if item.confidenceScore < 70 {
      return ("Low confidence", "Check detected fields before accepting this staged import.", .attention)
    }
    if item.suggestedLinkedOrderID == nil {
      return ("Ready to link", "Choose an existing order or create a new local order from this import.", .attention)
    }
    return ("Ready to accept", "Suggested order context exists; accept when the fields look right.", .success)
  }

  private static func acceptanceReadiness(_ candidate: AcceptanceCandidate) -> (label: String, detail: String, tone: InboxTriageTone) {
    if candidate.decision == .blocked {
      return ("Blocked", "Resolve the acceptance blocker before moving this record forward.", .warning)
    }
    if candidate.confidenceScore < 70 {
      return ("Check fields", "Compare detected fields before accepting this source record.", .attention)
    }
    if candidate.suggestedLinkedOrderID == nil {
      return ("Choose order", "Select an existing order or create one during acceptance.", .attention)
    }
    return ("Ready to accept", "Linked order context is present; accept when the comparison looks right.", .success)
  }

  private static func parserReadiness(_ diagnostic: IntakeParserDiagnostic) -> (label: String, detail: String, tone: InboxTriageTone) {
    let hints = (diagnostic.issueLabels + diagnostic.parserHintLabels + diagnostic.nextStepLabels)
      .prefix(3)
      .joined(separator: ", ")
    let detail = hints.isEmpty ? diagnostic.summary : hints
    return ("Parser check", detail, diagnostic.severity == .critical || diagnostic.severity == .high ? .warning : .attention)
  }

  private static func missingDetectedFields(merchant: String, order: String, tracking: String, destination: String) -> [String] {
    [
      merchant.isPlaceholderValidationValue ? "merchant" : nil,
      order.isPlaceholderValidationValue ? "order number" : nil,
      tracking.isPlaceholderValidationValue ? "tracking number" : nil,
      destination.isPlaceholderValidationValue ? "destination" : nil
    ].compactMap { $0 }
  }
}

private enum InboxTriageTone {
  case success
  case attention
  case warning
  case muted

  var color: Color {
    switch self {
    case .success:
      return .green
    case .attention:
      return .orange
    case .warning:
      return .red
    case .muted:
      return .secondary
    }
  }
}

private enum InboxTriageSource {
  case email(ForwardedEmailIntake)
  case importQueue(ImportQueueItem)
  case acceptance(AcceptanceCandidate)
  case parserDiagnostic(IntakeParserDiagnostic)

  var symbol: String {
    switch self {
    case .email: "envelope.open.fill"
    case .importQueue: "tray.and.arrow.down.fill"
    case .acceptance: "checkmark.rectangle.stack.fill"
    case .parserDiagnostic: "text.magnifyingglass"
    }
  }

  var color: Color {
    switch self {
    case .email(let email):
      email.reviewState.color
    case .importQueue(let item):
      item.importStatus.color
    case .acceptance(let candidate):
      candidate.decision.color
    case .parserDiagnostic(let diagnostic):
      diagnostic.severity.color
    }
  }
}

private struct InboxTriageRow: View {
  var item: InboxTriageItem
  var store: ParcelOpsStore
  @State private var feedbackMessage: String?

  private var linkedOrderLabel: String? {
    item.linkedOrderID.flatMap { store.orderLabel(for: $0) }
  }

  private var linkedShipmentGroupLabel: String? {
    item.linkedShipmentGroupID.flatMap { store.shipmentGroupLabel(for: $0) }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: item.source.symbol)
          .foregroundStyle(item.source.color)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: 5) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
              Text(item.title)
                .font(.headline)
              Text(item.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer(minLength: 8)
            Badge(item.sourceLabel, color: item.source.color)
          }

          Text(item.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)

          CompactMetadataGrid {
            if let confidenceScore = item.confidenceScore {
              Badge("\(confidenceScore)% confidence", color: confidenceColor(confidenceScore))
            }
            Badge(item.reviewLabel, color: item.source.color)
            Badge(item.readinessLabel, color: item.readinessTone.color)
            if let linkedOrderLabel {
              Label(linkedOrderLabel, systemImage: "shippingbox.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            if let linkedShipmentGroupLabel {
              Label(linkedShipmentGroupLabel, systemImage: "shippingbox.and.arrow.backward.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          Text(item.readinessDetail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          Label(item.nextAction, systemImage: "arrow.forward.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(item.readinessTone.color)
        }
      }

      CompactActionRow {
        NavigationLink {
          detailDestination
        } label: {
          Label("Open", systemImage: "arrow.up.right.square.fill")
        }
        .buttonStyle(.bordered)

        switch item.source {
        case .email(let email):
          Button("Create order", systemImage: "plus.circle.fill") {
            store.createOrder(from: email)
            feedbackMessage = "Order created and linked locally. Check Orders."
          }
          .buttonStyle(.borderedProminent)
          .disabled(email.linkedOrderID != nil)
          Button("Reviewed", systemImage: "checkmark.circle.fill") {
            store.markIntakeEmailReviewed(email)
            feedbackMessage = "Email marked reviewed locally."
          }
          .buttonStyle(.bordered)
          Button("Ignore", systemImage: "eye.slash.fill") {
            store.ignoreIntakeEmail(email)
            feedbackMessage = "Email ignored locally."
          }
          .buttonStyle(.bordered)
          Button("Reprocess", systemImage: "arrow.triangle.2.circlepath") {
            store.reprocessIntakeEmail(email)
            feedbackMessage = "Email reprocessed from stored preview."
          }
          .buttonStyle(.bordered)
          Button("Create task", systemImage: "checklist") {
            store.createReviewTask(from: email)
            feedbackMessage = "Follow-up task created. Check Tasks."
          }
          .buttonStyle(.bordered)
          Button("Create draft", systemImage: "envelope.open.fill") {
            store.createDraftMessage(from: email)
            feedbackMessage = "Draft message created locally."
          }
          .buttonStyle(.bordered)

        case .importQueue(let importItem):
          Button("Create order", systemImage: "plus.circle.fill") {
            store.createOrder(from: importItem)
            feedbackMessage = "Order created from import. Check Orders."
          }
          .buttonStyle(.borderedProminent)
          .disabled(importItem.suggestedLinkedOrderID != nil)
          Button("Accept import", systemImage: "checkmark.seal.fill") {
            store.markImportQueueItemAccepted(importItem)
            feedbackMessage = "Import accepted locally."
          }
          .buttonStyle(.borderedProminent)
          Button("Ignore", systemImage: "eye.slash.fill") {
            store.ignoreImportQueueItem(importItem)
            feedbackMessage = "Import ignored locally."
          }
          .buttonStyle(.bordered)
          Button("Reopen", systemImage: "arrow.uturn.backward.circle.fill") {
            store.reopenImportQueueItem(importItem)
            feedbackMessage = "Import reopened for review."
          }
          .buttonStyle(.bordered)
          Button("Create task", systemImage: "checklist") {
            store.createReviewTask(from: importItem)
            feedbackMessage = "Follow-up task created. Check Tasks."
          }
          .buttonStyle(.bordered)
          Button("Create draft", systemImage: "square.and.pencil") {
            store.createDraftMessage(from: importItem)
            feedbackMessage = "Draft message created locally."
          }
          .buttonStyle(.bordered)

        case .acceptance(let candidate):
          Button("Create order", systemImage: "plus.circle.fill") {
            store.createOrder(from: candidate)
            feedbackMessage = "Order created from acceptance. Check Orders."
          }
          .buttonStyle(.borderedProminent)
          .disabled(candidate.suggestedLinkedOrderID != nil)
          Button("Accept record", systemImage: "checkmark.circle.fill") {
            store.acceptCandidate(candidate)
            feedbackMessage = "Acceptance record accepted locally."
          }
          .buttonStyle(.borderedProminent)
          Button("Ignore", systemImage: "eye.slash.fill") {
            store.ignoreCandidate(candidate)
            feedbackMessage = "Acceptance record ignored locally."
          }
          .buttonStyle(.bordered)
          Button("Reopen", systemImage: "arrow.counterclockwise") {
            store.reopenCandidate(candidate)
            feedbackMessage = "Acceptance record reopened for review."
          }
          .buttonStyle(.bordered)
          Button("Create task", systemImage: "checklist") {
            store.createReviewTask(from: candidate)
            feedbackMessage = "Follow-up task created. Check Tasks."
          }
          .buttonStyle(.bordered)
          Button("Create draft", systemImage: "envelope.open.fill") {
            store.createDraftMessage(from: candidate)
            feedbackMessage = "Draft message created locally."
          }
          .buttonStyle(.bordered)

        case .parserDiagnostic(let diagnostic):
          Button("Reprocess", systemImage: "arrow.triangle.2.circlepath") {
            if let email = store.intakeEmails.first(where: { $0.id == diagnostic.intakeEmailID }) {
              store.reprocessIntakeEmail(email)
              feedbackMessage = "Email reprocessed from stored preview."
            }
          }
          .buttonStyle(.borderedProminent)
          Button("Create task", systemImage: "checklist") {
            if let email = store.intakeEmails.first(where: { $0.id == diagnostic.intakeEmailID }) {
              store.createReviewTask(from: email)
              feedbackMessage = "Parser follow-up task created. Check Tasks."
            }
          }
          .buttonStyle(.bordered)
        }
      }

      if let feedbackMessage {
        Label(feedbackMessage, systemImage: "checkmark.circle.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.green)
          .padding(.horizontal, 10)
          .padding(.vertical, 7)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.green.opacity(0.12))
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }

  @ViewBuilder
  private var detailDestination: some View {
    switch item.source {
    case .email:
      MailboxView(store: store)
    case .importQueue:
      ImportQueueView(store: store)
    case .acceptance:
      AcceptanceReviewView(store: store)
    case .parserDiagnostic:
      MailboxView(store: store)
    }
  }

  private func confidenceColor(_ score: Int) -> Color {
    if score < 50 {
      return .red
    }
    if score < 75 {
      return .orange
    }
    return .green
  }
}

private extension ForwardedEmailIntake {
  var localInboxConfidence: Int {
    var score = 90
    if detectedMerchant.isPlaceholderValidationValue { score -= 18 }
    if detectedOrderNumber.isPlaceholderValidationValue { score -= 18 }
    if detectedTrackingNumber.isPlaceholderValidationValue { score -= 12 }
    if detectedDestinationAddress.isPlaceholderValidationValue { score -= 16 }
    if linkedOrderID == nil { score -= 8 }
    if reviewState == .needsReview { score -= 6 }
    return max(10, min(100, score))
  }
}

struct DispatchView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }
  private var dispatchItems: [DispatchQueueItem] {
    let manifestItems = uniqueManifests(
      store.blockedShipmentManifests
        + store.highRiskShipmentManifests
        + store.undispatchedShipmentManifests
        + store.shipmentManifestsNeedingReview
        + store.shipmentManifestsMissingIncludedOrders
        + store.shipmentManifestsMissingHandoffLocation
        + store.shipmentManifestsWithIncompleteScans
    ).map(DispatchQueueItem.manifest)

    let checklistItems = uniqueChecklists(
      store.blockedDispatchChecklists
        + store.highRiskDispatchChecklists
        + store.incompleteDispatchChecklists
        + store.dispatchChecklistsNeedingReview
        + store.dispatchChecklistsMissingRequirements
        + store.dispatchChecklistsLinkedToBlockedManifests
    ).map(DispatchQueueItem.checklist)

    return (manifestItems + checklistItems)
      .sorted { lhs, rhs in
        if lhs.sortPriority == rhs.sortPriority {
          return lhs.plannedDate > rhs.plannedDate
        }
        return lhs.sortPriority > rhs.sortPriority
      }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: isCompact ? 14 : 18) {
        header
        dispatchQueuePanel
        detailRoutes
      }
      .padding(isCompact ? 14 : 24)
    }
    .background(.regularMaterial)
  }

  private var dispatchQueuePanel: some View {
    SettingsPanel(title: "Unified dispatch queue", symbol: "shippingbox.and.arrow.backward.fill") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Work blocked, high-risk, incomplete, and upcoming outbound records here before opening a detailed dispatch view.")
          .font(.callout)
          .foregroundStyle(.secondary)

        if dispatchItems.isEmpty {
          MVPEmptyState(
            title: "Dispatch queue is clear",
            detail: "Shipment manifests and readiness checklists that need outbound action will appear here.",
            symbol: "checkmark.seal.fill"
          )
        } else {
          ForEach(dispatchItems.prefix(12)) { item in
            DispatchQueueRow(item: item, store: store)
          }
        }
      }
    }
  }

  private var detailRoutes: some View {
    SettingsPanel(title: "Detailed dispatch views", symbol: "rectangle.stack.fill") {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 220 : 260), spacing: 12)], alignment: .leading, spacing: 12) {
        OperatorRouteCard(title: "Shipment Manifests", detail: "Prepare outbound batches and courier handoff groups.", symbol: "list.bullet.clipboard.fill", badge: "\(store.shipmentManifestRecords.count) manifests") {
          ShipmentManifestsView(store: store)
        }

        OperatorRouteCard(title: "Dispatch Readiness", detail: "Confirm scans, labels, custody, and handoff readiness.", symbol: "checkmark.rectangle.stack.fill", badge: "\(store.incompleteDispatchChecklists.count) incomplete") {
          DispatchReadinessView(store: store)
        }
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Dispatch")
        .font(isCompact ? .title.bold() : .largeTitle.bold())
      Text("Triage outbound batches and readiness checks before dispatch, courier handoff, or internal transfer.")
        .foregroundStyle(.secondary)

      MetricStrip(items: [
        ("Queue", "\(dispatchItems.count)", .red),
        ("Undispatched", "\(store.undispatchedShipmentManifests.count)", .purple),
        ("Blocked", "\(store.blockedShipmentManifests.count)", .red),
        ("Incomplete", "\(store.incompleteDispatchChecklists.count)", .orange),
        ("High risk", "\(store.highRiskShipmentManifests.count + store.highRiskDispatchChecklists.count)", .pink)
      ])
    }
  }

  private func uniqueManifests(_ records: [ShipmentManifestRecord]) -> [ShipmentManifestRecord] {
    var seen: Set<UUID> = []
    var unique: [ShipmentManifestRecord] = []
    for record in records where !seen.contains(record.id) {
      seen.insert(record.id)
      unique.append(record)
    }
    return unique
  }

  private func uniqueChecklists(_ checklists: [DispatchReadinessChecklist]) -> [DispatchReadinessChecklist] {
    var seen: Set<UUID> = []
    var unique: [DispatchReadinessChecklist] = []
    for checklist in checklists where !seen.contains(checklist.id) {
      seen.insert(checklist.id)
      unique.append(checklist)
    }
    return unique
  }
}

private struct DispatchQueueItem: Identifiable {
  var id: String
  var source: DispatchQueueSource
  var sourceLabel: String
  var title: String
  var subtitle: String
  var detail: String
  var plannedDate: String
  var statusLabel: String
  var riskLevel: ShipmentRiskLevel
  var reviewState: ReviewState
  var orderCount: Int
  var shipmentGroupCount: Int
  var scanCount: Int
  var nextAction: String
  var sortPriority: Int

  static func manifest(_ record: ShipmentManifestRecord) -> DispatchQueueItem {
    DispatchQueueItem(
      id: "manifest-\(record.id.uuidString)",
      source: .manifest(record),
      sourceLabel: "Manifest",
      title: "\(record.carrierCourier) • \(record.manifestType.rawValue)",
      subtitle: record.title,
      detail: record.destinationSummary,
      plannedDate: record.plannedDispatchDate,
      statusLabel: record.dispatchStatus.rawValue,
      riskLevel: record.riskLevel,
      reviewState: record.reviewState,
      orderCount: record.includedOrderIDs.count,
      shipmentGroupCount: record.shipmentGroupIDs.count,
      scanCount: record.scanSessionIDs.count,
      nextAction: manifestNextAction(record),
      sortPriority: manifestSortPriority(record)
    )
  }

  static func checklist(_ checklist: DispatchReadinessChecklist) -> DispatchQueueItem {
    DispatchQueueItem(
      id: "checklist-\(checklist.id.uuidString)",
      source: .checklist(checklist),
      sourceLabel: "Readiness",
      title: "\(checklist.checklistType.rawValue) • \(checklist.assignedOwnerTeam)",
      subtitle: checklist.title,
      detail: checklist.missingRequirementsSummary.isPlaceholderValidationValue ? checklist.requiredChecksSummary : "Missing: \(checklist.missingRequirementsSummary)",
      plannedDate: checklist.plannedDispatchDate,
      statusLabel: checklist.checklistStatus.rawValue,
      riskLevel: checklist.riskLevel,
      reviewState: checklist.reviewState,
      orderCount: checklist.orderIDs.count,
      shipmentGroupCount: checklist.shipmentGroupIDs.count,
      scanCount: checklist.scanSessionIDs.count,
      nextAction: checklistNextAction(checklist),
      sortPriority: checklistSortPriority(checklist)
    )
  }

  private static func manifestNextAction(_ record: ShipmentManifestRecord) -> String {
    switch record.dispatchStatus {
    case .blockedNeedsReview:
      return "Resolve blocked manifest"
    case .draft, .reopened:
      return "Prepare manifest"
    case .prepared:
      return "Dispatch or block"
    case .dispatched:
      return "Confirm handoff"
    case .handedOff:
      return record.reviewState == .accepted ? "Handoff complete" : "Mark reviewed"
    }
  }

  private static func checklistNextAction(_ checklist: DispatchReadinessChecklist) -> String {
    switch checklist.checklistStatus {
    case .blockedNeedsReview:
      return "Resolve blocked checklist"
    case .draft, .reopened:
      return "Mark ready or block"
    case .ready:
      return "Complete readiness checks"
    case .completed:
      return checklist.reviewState == .accepted ? "Checklist complete" : "Mark reviewed"
    }
  }

  private static func manifestSortPriority(_ record: ShipmentManifestRecord) -> Int {
    if record.dispatchStatus == .blockedNeedsReview { return 100 }
    if record.riskLevel == .critical { return 95 }
    if record.riskLevel == .high { return 90 }
    if record.dispatchStatus == .prepared { return 82 }
    if record.dispatchStatus == .draft || record.dispatchStatus == .reopened { return 75 }
    if record.reviewState != .accepted { return 65 }
    return 35
  }

  private static func checklistSortPriority(_ checklist: DispatchReadinessChecklist) -> Int {
    if checklist.checklistStatus == .blockedNeedsReview { return 100 }
    if checklist.riskLevel == .critical { return 95 }
    if checklist.riskLevel == .high { return 90 }
    if checklist.checklistStatus == .ready { return 82 }
    if checklist.checklistStatus == .draft || checklist.checklistStatus == .reopened { return 75 }
    if checklist.reviewState != .accepted { return 65 }
    return 35
  }
}

private enum DispatchQueueSource {
  case manifest(ShipmentManifestRecord)
  case checklist(DispatchReadinessChecklist)

  var symbol: String {
    switch self {
    case .manifest: "list.bullet.clipboard.fill"
    case .checklist: "checkmark.rectangle.stack.fill"
    }
  }
}

private struct DispatchQueueRow: View {
  var item: DispatchQueueItem
  var store: ParcelOpsStore

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: item.source.symbol)
          .foregroundStyle(item.riskLevel.color)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: 5) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
              Text(item.title)
                .font(.headline)
              Text(item.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer(minLength: 8)
            Badge(item.sourceLabel, color: item.riskLevel.color)
          }

          Text(item.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)

          CompactMetadataGrid {
            Badge(item.statusLabel, color: item.riskLevel.color)
            Badge(item.riskLevel.rawValue, color: item.riskLevel.color)
            Badge(item.reviewState.rawValue, color: item.reviewState.color)
            Label(item.plannedDate, systemImage: "calendar")
              .font(.caption)
              .foregroundStyle(.secondary)
            Label("\(item.orderCount) orders", systemImage: "shippingbox.fill")
              .font(.caption)
              .foregroundStyle(.secondary)
            Label("\(item.shipmentGroupCount) groups", systemImage: "shippingbox.and.arrow.backward.fill")
              .font(.caption)
              .foregroundStyle(.secondary)
            Label("\(item.scanCount) scans", systemImage: "qrcode.viewfinder")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Label(item.nextAction, systemImage: "arrow.forward.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(item.riskLevel.color)
        }
      }

      CompactActionRow {
        NavigationLink {
          detailDestination
        } label: {
          Label("Open", systemImage: "arrow.up.right.square.fill")
        }
        .buttonStyle(.bordered)

        switch item.source {
        case .manifest(let record):
          Button("Prepared", systemImage: "checkmark.circle.fill") {
            store.markShipmentManifestPrepared(record)
          }
          .buttonStyle(.bordered)
          Button("Dispatched", systemImage: "paperplane.fill") {
            store.markShipmentManifestDispatched(record)
          }
          .buttonStyle(.bordered)
          Button("Handed off", systemImage: "person.badge.shield.checkmark.fill") {
            store.markShipmentManifestHandedOff(record)
          }
          .buttonStyle(.borderedProminent)
          Button("Blocked", systemImage: "exclamationmark.triangle.fill") {
            store.markShipmentManifestBlocked(record)
          }
          .buttonStyle(.bordered)
          Button("Reopen", systemImage: "arrow.counterclockwise") {
            store.reopenShipmentManifest(record)
          }
          .buttonStyle(.bordered)
          Button("Reviewed", systemImage: "checkmark.shield.fill") {
            store.markShipmentManifestReviewed(record)
          }
          .buttonStyle(.bordered)
          Button("Task", systemImage: "checklist") {
            store.createReviewTask(from: record)
          }
          .buttonStyle(.bordered)
          Button("Draft", systemImage: "envelope.open.fill") {
            store.createDraftMessage(from: record)
          }
          .buttonStyle(.bordered)

        case .checklist(let checklist):
          Button("Ready", systemImage: "checkmark.circle.fill") {
            store.markDispatchChecklistReady(checklist)
          }
          .buttonStyle(.bordered)
          Button("Complete", systemImage: "checkmark.seal.fill") {
            store.markDispatchChecklistCompleted(checklist)
          }
          .buttonStyle(.borderedProminent)
          Button("Blocked", systemImage: "exclamationmark.triangle.fill") {
            store.markDispatchChecklistBlocked(checklist)
          }
          .buttonStyle(.bordered)
          Button("Reopen", systemImage: "arrow.counterclockwise") {
            store.reopenDispatchChecklist(checklist)
          }
          .buttonStyle(.bordered)
          Button("Reviewed", systemImage: "checkmark.shield.fill") {
            store.markDispatchChecklistReviewed(checklist)
          }
          .buttonStyle(.bordered)
          Button("Task", systemImage: "checklist") {
            store.createReviewTask(from: checklist)
          }
          .buttonStyle(.bordered)
          Button("Draft", systemImage: "envelope.open.fill") {
            store.createDraftMessage(from: checklist)
          }
          .buttonStyle(.bordered)
        }
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }

  @ViewBuilder
  private var detailDestination: some View {
    switch item.source {
    case .manifest:
      ShipmentManifestsView(store: store)
    case .checklist:
      DispatchReadinessView(store: store)
    }
  }
}

private struct OperatorRouteCard<Destination: View>: View {
  var title: String
  var detail: String
  var symbol: String
  var badge: String
  @ViewBuilder var destination: Destination
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }

  var body: some View {
    NavigationLink {
      destination
    } label: {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: symbol)
          .foregroundStyle(.teal)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 5) {
          if isCompact {
            VStack(alignment: .leading, spacing: 6) {
              Text(title)
                .font(.headline)
              Badge(badge, color: .teal)
            }
          } else {
            Text(title)
              .font(.headline)
          }
          Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        if !isCompact {
          Spacer(minLength: 8)
          Badge(badge, color: .teal)
        }
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.background)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }
    .buttonStyle(.plain)
  }
}
