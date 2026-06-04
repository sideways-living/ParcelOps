import SwiftUI

extension String {
  var normalizedValidationKey: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
      .replacingOccurrences(of: " ", with: "")
  }

  var isPlaceholderValidationValue: Bool {
    let normalized = trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized.isEmpty
      || normalized == "pending"
      || normalized == "unknown"
      || normalized == "unassigned"
      || normalized == "choose folder"
      || normalized == "needs setup"
      || normalized == "never"
  }
}

extension OrderStatus {
  var color: Color {
    switch self {
    case .intake: .gray
    case .ordered: .blue
    case .shipped: .cyan
    case .inTransit: .indigo
    case .exception: .red
    case .delivered: .green
    }
  }
}

extension ReviewState {
  var color: Color {
    switch self {
    case .accepted: .green
    case .needsReview: .orange
    case .monitor: .blue
    }
  }
}

extension Severity {
  var color: Color {
    switch self {
    case .info: .blue
    case .watch: .orange
    case .critical: .red
    }
  }

  var riskRank: Int {
    switch self {
    case .info: 0
    case .watch: 1
    case .critical: 2
    }
  }

  var timelineRisk: TimelineRiskLevel {
    switch self {
    case .info: .normal
    case .watch: .high
    case .critical: .critical
    }
  }
}

extension IntakeEmailReviewState {
  var color: Color {
    switch self {
    case .needsReview: .orange
    case .reviewed: .green
    case .ignored: .gray
    }
  }
}

extension AuditAction {
  var color: Color {
    switch self {
    case .created: .green
    case .edited: .blue
    case .enabled: .green
    case .disabled: .gray
    case .linked: .teal
    case .reviewed: .indigo
    case .ignored: .gray
    case .cleared: .orange
    case .pinned: .purple
    case .unpinned: .gray
    case .acknowledged: .blue
    case .completed: .green
    case .reopened: .orange
    case .evaluated: .blue
    case .removed: .red
    }
  }
}

extension AuditEntityType {
  var symbol: String {
    switch self {
    case .order: "shippingbox.fill"
    case .intakeEmail: "envelope.open.fill"
    case .mailEvent: "envelope.badge.fill"
    case .evidence: "paperclip"
    case .trackingEvent: "location.fill.viewfinder"
    case .automationRule: "arrow.triangle.branch"
    case .savedFilter: "line.3.horizontal.decrease.circle.fill"
    case .auditEvent: "list.clipboard.fill"
    case .reviewTask: "checklist"
    case .handoffNote: "arrow.left.arrow.right.square.fill"
    case .slaPolicy: "timer"
    case .exceptionPlaybook: "book.closed.fill"
    case .communicationTemplate: "text.badge.checkmark"
    case .draftMessage: "envelope.open.fill"
    case .contactDirectoryEntry: "person.crop.circle.badge.checkmark"
    case .customerRecipientProfile: "person.text.rectangle.fill"
    case .destinationAddress: "mappin.and.ellipse"
    case .deliveryInstruction: "signpost.right.and.left.fill"
    case .packageContent: "shippingbox.circle.fill"
    case .costRecord: "creditcard.and.123"
    case .returnClaim: "arrow.uturn.backward.square.fill"
    case .procurementRequest: "cart.badge.plus"
    case .receivingInspection: "checklist.checked"
    case .accountCredentialRecord: "key.horizontal.fill"
    case .vendorProfile: "building.2.crop.circle.fill"
    case .shipmentGroup: "shippingbox.and.arrow.backward.fill"
    case .importQueueItem: "tray.and.arrow.down.fill"
    case .acceptanceRecord: "checkmark.rectangle.stack.fill"
    case .reconciliationIssue: "arrow.triangle.2.circlepath.circle.fill"
    }
  }
}

extension TimelineEntityType {
  var symbol: String {
    switch self {
    case .order: "shippingbox.fill"
    case .intakeEmail: "envelope.open.fill"
    case .trackingEvent: "location.fill.viewfinder"
    case .evidence: "paperclip"
    case .reviewTask: "checklist"
    case .handoffNote: "arrow.left.arrow.right.square.fill"
    case .slaPolicy: "timer"
    case .communicationTemplate: "text.badge.checkmark"
    case .draftMessage: "envelope.open.fill"
    case .contact: "person.crop.circle.badge.checkmark"
    case .customerProfile: "person.text.rectangle.fill"
    case .destinationAddress: "mappin.and.ellipse"
    case .deliveryInstruction: "signpost.right.and.left.fill"
    case .packageContent: "shippingbox.circle.fill"
    case .costRecord: "creditcard.and.123"
    case .returnClaim: "arrow.uturn.backward.square.fill"
    case .procurementRequest: "cart.badge.plus"
    case .receivingInspection: "checklist.checked"
    case .account: "key.horizontal.fill"
    case .vendorProfile: "building.2.crop.circle.fill"
    case .shipmentGroup: "shippingbox.and.arrow.backward.fill"
    case .importQueueItem: "tray.and.arrow.down.fill"
    case .acceptanceRecord: "checkmark.rectangle.stack.fill"
    case .automationRule: "arrow.triangle.branch"
    case .savedFilter: "line.3.horizontal.decrease.circle.fill"
    case .auditEvent: "list.clipboard.fill"
    }
  }
}

extension TimelineRiskLevel {
  var color: Color {
    switch self {
    case .normal: .blue
    case .watch: .orange
    case .high: .red
    case .critical: .red
    }
  }

  var rank: Int {
    switch self {
    case .normal: 0
    case .watch: 1
    case .high: 2
    case .critical: 3
    }
  }
}

extension TimelineActivitySource {
  var symbol: String {
    switch self {
    case .order: "shippingbox.fill"
    case .mailbox: "envelope.badge.fill"
    case .carrier: "truck.box.fill"
    case .evidence: "paperclip"
    case .task: "checklist"
    case .sla: "timer"
    case .communication: "bubble.left.and.text.bubble.right.fill"
    case .directory: "person.crop.circle.badge.checkmark"
    case .account: "key.horizontal.fill"
    case .vendorProfile: "building.2.crop.circle.fill"
    case .shipmentGroup: "shippingbox.and.arrow.backward.fill"
    case .importQueue: "tray.and.arrow.down.fill"
    case .acceptance: "checkmark.rectangle.stack.fill"
    case .automation: "arrow.triangle.branch"
    case .search: "magnifyingglass"
    case .audit: "list.clipboard.fill"
    }
  }
}

extension WorkbenchSource {
  var symbol: String {
    switch self {
    case .reviewTask: "checklist"
    case .handoffNote: "arrow.left.arrow.right.square.fill"
    case .intakeEmail: "envelope.open.fill"
    case .importQueue: "tray.and.arrow.down.fill"
    case .acceptanceReview: "checkmark.rectangle.stack.fill"
    case .reconciliation: "arrow.triangle.2.circlepath.circle.fill"
    case .validation: "checkmark.seal.fill"
    case .shipmentGroup: "shippingbox.and.arrow.backward.fill"
    case .tracking: "location.fill.viewfinder"
    case .evidence: "paperclip"
    case .slaPolicy: "timer"
    case .exceptionPlaybook: "book.closed.fill"
    case .draftMessage: "envelope.open.fill"
    case .contact: "person.crop.circle.badge.checkmark"
    case .customerProfile: "person.text.rectangle.fill"
    case .destinationAddress: "mappin.and.ellipse"
    case .deliveryInstruction: "signpost.right.and.left.fill"
    case .packageContent: "shippingbox.circle.fill"
    case .costRecord: "creditcard.and.123"
    case .returnClaim: "arrow.uturn.backward.square.fill"
    case .procurementRequest: "cart.badge.plus"
    case .receivingInspection: "checklist.checked"
    case .account: "key.horizontal.fill"
    case .vendorProfile: "building.2.crop.circle.fill"
    }
  }
}

extension WorkbenchItem {
  var color: Color {
    let value = prioritySeverity.lowercased()
    if value.contains("critical") || value.contains("urgent") { return .red }
    if value.contains("high") || value.contains("blocked") { return .orange }
    if reviewState == .needsReview { return .orange }
    if status.localizedCaseInsensitiveContains("complete") || status.localizedCaseInsensitiveContains("sent") { return .green }
    return .blue
  }

  var rank: Int {
    let value = prioritySeverity.lowercased()
    if value.contains("critical") || value.contains("urgent") { return 4 }
    if value.contains("high") { return 3 }
    if value.contains("medium") || value.contains("normal") { return 2 }
    return 1
  }

  var isBlocked: Bool {
    status.localizedCaseInsensitiveContains("blocked")
  }

  var isAwaitingAcceptance: Bool {
    source == .acceptanceReview || source == .importQueue || status.localizedCaseInsensitiveContains("ready")
  }

  var isDueOrOverdue: Bool {
    let due = dueDateText.lowercased()
    return due.contains("today") || due.contains("overdue")
  }

  var isException: Bool {
    source == .reconciliation
      || source == .validation
      || source == .exceptionPlaybook
      || source == .tracking
      || prioritySeverity.localizedCaseInsensitiveContains("critical")
  }

  var supportsReviewAction: Bool {
    switch source {
    case .reviewTask, .handoffNote, .intakeEmail, .reconciliation, .shipmentGroup, .tracking, .evidence, .slaPolicy, .exceptionPlaybook, .draftMessage, .contact, .customerProfile, .destinationAddress, .deliveryInstruction, .packageContent, .costRecord, .returnClaim, .procurementRequest, .receivingInspection, .account, .vendorProfile:
      true
    case .importQueue, .acceptanceReview, .validation:
      false
    }
  }
}

extension ValidationEntityType {
  var symbol: String {
    switch self {
    case .order: "shippingbox.fill"
    case .intakeEmail: "envelope.open.fill"
    case .trackingNumber: "number.circle.fill"
    case .destinationAddress: "mappin.and.ellipse"
    case .vendorProfileMatch: "building.2.crop.circle.fill"
    case .accountPlaceholder: "key.horizontal.fill"
    case .contactSuggestion: "person.crop.circle.badge.questionmark"
    }
  }
}

extension ValidationSeverity {
  var color: Color {
    switch self {
    case .info: .blue
    case .warning: .orange
    case .high: .red
    case .critical: .red
    }
  }

  var rank: Int {
    switch self {
    case .info: 0
    case .warning: 1
    case .high: 2
    case .critical: 3
    }
  }

  var taskPriority: TaskPriority {
    switch self {
    case .info: .low
    case .warning: .normal
    case .high: .high
    case .critical: .urgent
    }
  }
}

extension ValidationStatus {
  var color: Color {
    switch self {
    case .valid: .green
    case .incomplete: .orange
    case .conflict: .red
    case .lowConfidence: .orange
    case .duplicate: .purple
    case .staleReview: .blue
    case .needsCorrection: .red
    }
  }
}

extension ReconciliationIssueType {
  var symbol: String {
    switch self {
    case .missingLink: "link.badge.plus"
    case .orderNumberConflict: "number.circle.fill"
    case .trackingNumberConflict: "location.fill.viewfinder"
    case .destinationConflict: "mappin.and.ellipse"
    case .duplicateStagedRecord: "doc.on.doc.fill"
    case .acceptedWithoutOrder: "checkmark.rectangle.stack.fill"
    case .shipmentGroupMissingPrimary: "shippingbox.and.arrow.backward.fill"
    }
  }
}

extension ReconciliationEntityType {
  var symbol: String {
    switch self {
    case .intakeEmail: "envelope.open.fill"
    case .importQueueItem: "tray.and.arrow.down.fill"
    case .acceptanceRecord: "checkmark.rectangle.stack.fill"
    case .order: "shippingbox.fill"
    case .shipmentGroup: "shippingbox.and.arrow.backward.fill"
    case .trackingEvent: "location.fill.viewfinder"
    case .evidence: "paperclip"
    case .validationIssue: "checkmark.seal.fill"
    }
  }

  var reviewTaskLinkedEntityType: ReviewTaskLinkedEntityType? {
    switch self {
    case .intakeEmail: .intakeEmail
    case .importQueueItem: .importQueueItem
    case .acceptanceRecord: .acceptanceRecord
    case .order: .order
    case .shipmentGroup: .shipmentGroup
    case .trackingEvent: .trackingEvent
    case .evidence: .evidence
    case .validationIssue: nil
    }
  }
}

extension VendorProfileType {
  var symbol: String {
    switch self {
    case .store: "storefront.fill"
    case .supplier: "building.2.fill"
    case .carrier: "truck.box.fill"
    case .shopifyStore: "cart.fill"
    case .internalTeam: "person.2.fill"
    case .marketplace: "bag.fill"
    }
  }
}

extension CustomerProfileType {
  var symbol: String {
    switch self {
    case .customer: "person.fill"
    case .recipient: "person.crop.square.fill"
    case .internalTeam: "person.2.fill"
    case .department: "building.columns.fill"
    case .site: "mappin.and.ellipse"
    }
  }
}

extension DeliveryPreference {
  var symbol: String {
    switch self {
    case .delivery: "truck.box.fill"
    case .clickAndCollect: "bag.fill"
    case .pickup: "shippingbox.and.arrow.backward.fill"
    case .internalHandoff: "arrow.left.arrow.right.square.fill"
    case .noPreference: "questionmark.circle.fill"
    }
  }
}

extension VendorRiskLevel {
  var color: Color {
    switch self {
    case .low: .green
    case .medium: .blue
    case .high: .orange
    case .critical: .red
    }
  }

  var riskRank: Int {
    switch self {
    case .low: 0
    case .medium: 1
    case .high: 2
    case .critical: 3
    }
  }

  var timelineRisk: TimelineRiskLevel {
    switch self {
    case .low: .normal
    case .medium: .watch
    case .high: .high
    case .critical: .critical
    }
  }
}

extension ShipmentRiskLevel {
  var color: Color {
    switch self {
    case .low: .green
    case .medium: .blue
    case .high: .orange
    case .critical: .red
    }
  }

  var riskRank: Int {
    switch self {
    case .low: 0
    case .medium: 1
    case .high: 2
    case .critical: 3
    }
  }

  var timelineRisk: TimelineRiskLevel {
    switch self {
    case .low: .normal
    case .medium: .watch
    case .high: .high
    case .critical: .critical
    }
  }
}

extension ImportSourceType {
  var symbol: String {
    switch self {
    case .forwardedEmail: "envelope.open.fill"
    case .manualEntry: "square.and.pencil"
    case .pdf: "doc.richtext.fill"
    case .screenshot: "photo.fill"
    case .watchedFolder: "folder.fill"
    case .supplierPortal: "person.crop.circle.badge.checkmark"
    case .shopify: "cart.fill"
    }
  }
}

extension ImportStatus {
  var color: Color {
    switch self {
    case .staged: .orange
    case .linked: .blue
    case .accepted: .green
    case .ignored: .gray
    case .blocked: .red
    case .reopened: .purple
    }
  }
}

extension ImportConfidenceRange {
  func contains(_ score: Int) -> Bool {
    switch self {
    case .all: true
    case .low: score < 50
    case .medium: score >= 50 && score < 75
    case .high: score >= 75
    }
  }
}

extension AcceptanceSourceType {
  var symbol: String {
    switch self {
    case .importQueueItem: "tray.and.arrow.down.fill"
    case .intakeEmail: "envelope.open.fill"
    }
  }
}

extension AcceptanceDecision {
  var color: Color {
    switch self {
    case .ready: .blue
    case .accepted: .green
    case .ignored: .gray
    case .reopened: .purple
    case .blocked: .red
    }
  }
}

extension AcceptanceCandidate {
  var reviewTaskLinkedEntityType: ReviewTaskLinkedEntityType {
    switch sourceType {
    case .importQueueItem: .importQueueItem
    case .intakeEmail: .intakeEmail
    }
  }
}

struct AcceptanceHistoryStrip: View {
  var records: [AcceptanceRecord]

  var body: some View {
    if !records.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Label("Acceptance history", systemImage: "checkmark.rectangle.stack.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        ForEach(records.prefix(3)) { record in
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: record.sourceType.symbol)
              .foregroundStyle(record.decision.color)
              .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
              Text(record.sourceLabel)
                .font(.caption.weight(.semibold))
              Text("\(record.decision.rawValue) • \(record.decidedDate)")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Text(record.summary)
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge("\(record.confidenceScore)%", color: record.confidenceScore < 50 ? .red : record.confidenceScore < 75 ? .orange : .green)
          }
        }
      }
      .padding(10)
      .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

struct ExceptionPlaybookStrip: View {
  var playbooks: [ExceptionPlaybook]

  var body: some View {
    if !playbooks.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Label("Suggested playbooks", systemImage: "book.closed.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        ForEach(playbooks.prefix(3)) { playbook in
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: playbook.issueType.symbol)
              .foregroundStyle(playbook.priority.color)
              .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
              Text(playbook.name)
                .font(.caption.weight(.semibold))
              Text("\(playbook.issueType.rawValue) • \(playbook.escalationContact)")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Text(playbook.recommendedSteps)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer()
            Badge(playbook.priority.rawValue, color: playbook.priority.color)
          }
        }
      }
      .padding(10)
      .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

struct HandoffNoteStrip: View {
  var notes: [HandoffNote]

  var body: some View {
    if !notes.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Label("Handoff notes", systemImage: "arrow.left.arrow.right.square.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        ForEach(notes.prefix(3)) { note in
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: note.linkedEntityType.symbol)
              .foregroundStyle(note.priority.color)
              .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
              Text(note.title)
                .font(.caption.weight(.semibold))
              Text("\(note.assignee) • due \(note.dueDate)")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Text(note.summary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer()
            Badge(note.status.rawValue, color: note.status.color)
          }
        }
      }
      .padding(10)
      .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

struct CustomerProfileStrip: View {
  var profiles: [CustomerRecipientProfile]

  var body: some View {
    if !profiles.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Label("Customer profiles", systemImage: "person.text.rectangle.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        ForEach(profiles.prefix(3)) { profile in
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: profile.profileType.symbol)
              .foregroundStyle(profile.isEnabled ? .blue : .orange)
              .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
              Text(profile.displayName)
                .font(.caption.weight(.semibold))
              Text("\(profile.organisationTeam) • \(profile.deliveryPreference.rawValue)")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Text(profile.defaultDestinationAddress)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer()
            Badge(profile.reviewState.rawValue, color: profile.reviewState.color)
          }
        }
      }
      .padding(10)
      .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

struct DestinationAddressStrip: View {
  var addresses: [DestinationAddressRecord]

  var body: some View {
    if !addresses.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Label("Destination addresses", systemImage: "mappin.and.ellipse")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        ForEach(addresses.prefix(3)) { address in
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
              .foregroundStyle(address.riskLevel.color)
              .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
              Text(address.label)
                .font(.caption.weight(.semibold))
              Text("\(address.addressLineSummary), \(address.cityRegion)")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Text("\(address.preferredCarrier) • \(address.deliveryInstructions)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer()
            Badge(address.riskLevel.rawValue, color: address.riskLevel.color)
          }
        }
      }
      .padding(10)
      .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

struct DeliveryInstructionStrip: View {
  var instructions: [DeliveryInstructionRecord]

  var body: some View {
    if !instructions.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Label("Delivery instructions", systemImage: "signpost.right.and.left.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        ForEach(instructions.prefix(3)) { instruction in
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: instruction.instructionType.symbol)
              .foregroundStyle(instruction.riskLevel.color)
              .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
              Text(instruction.title)
                .font(.caption.weight(.semibold))
              Text("\(instruction.instructionType.rawValue) • \(instruction.preferredDeliveryWindow)")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Text(instruction.accessConstraintSummary.isEmpty ? instruction.instructionSummary : instruction.accessConstraintSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer()
            Badge(instruction.riskLevel.rawValue, color: instruction.riskLevel.color)
          }
        }
      }
      .padding(10)
      .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

struct PackageContentStrip: View {
  var contents: [PackageContentRecord]

  var body: some View {
    if !contents.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Label("Package contents", systemImage: "shippingbox.circle.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        ForEach(contents.prefix(3)) { content in
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: content.itemCategory.symbol)
              .foregroundStyle(content.riskLevel.color)
              .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
              Text(content.title)
                .font(.caption.weight(.semibold))
              Text("\(content.itemCategory.rawValue) • \(content.verifiedQuantity)/\(content.expectedQuantity) verified")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Text(content.verificationStatus == .discrepancy ? content.discrepancySummary : content.itemSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer()
            Badge(content.verificationStatus.rawValue, color: content.verificationStatus.color)
          }
        }
      }
      .padding(10)
      .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

struct CostRecordStrip: View {
  var costs: [CostRecord]

  var body: some View {
    if !costs.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Label("Costs & budgets", systemImage: "creditcard.and.123")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        ForEach(costs.prefix(3)) { cost in
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: cost.costCategory.symbol)
              .foregroundStyle(cost.riskLevel.color)
              .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
              Text(cost.title)
                .font(.caption.weight(.semibold))
              Text("\(cost.amountText) \(cost.currency) • \(cost.costCategory.rawValue)")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Text("\(cost.budgetCode) • \(cost.costOwnerTeam)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer()
            Badge(cost.approvalStatus.rawValue, color: cost.approvalStatus.color)
          }
        }
      }
      .padding(10)
      .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

struct ReturnClaimStrip: View {
  var claims: [ReturnClaimRecord]

  var body: some View {
    if !claims.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Label("Returns & claims", systemImage: "arrow.uturn.backward.square.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        ForEach(claims.prefix(3)) { claim in
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: claim.claimType.symbol)
              .foregroundStyle(claim.riskLevel.color)
              .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
              Text(claim.title)
                .font(.caption.weight(.semibold))
              Text("\(claim.claimType.rawValue) • \(claim.requestedOutcome.rawValue)")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Text("\(claim.refundReplacementAmountText) \(claim.currency) • \(claim.assignedOwnerTeam)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer()
            Badge(claim.claimStatus.rawValue, color: claim.claimStatus.color)
          }
        }
      }
      .padding(10)
      .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

struct ProcurementRequestStrip: View {
  var requests: [ProcurementRequest]

  var body: some View {
    if !requests.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Label("Procurement", systemImage: "cart.badge.plus")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        ForEach(requests.prefix(3)) { request in
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: request.procurementStatus.symbol)
              .foregroundStyle(request.riskLevel.color)
              .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
              Text(request.title)
                .font(.caption.weight(.semibold))
              Text("\(request.estimatedCostText) \(request.currency) • \(request.budgetCode)")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Text("\(request.assignedBuyerTeam) • needed \(request.neededByDate)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer()
            Badge(request.approvalStatus.rawValue, color: request.approvalStatus.color)
          }
        }
      }
      .padding(10)
      .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

struct ReceivingInspectionStrip: View {
  var inspections: [ReceivingInspectionRecord]

  var body: some View {
    if !inspections.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Label("Receiving inspections", systemImage: "checklist.checked")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        ForEach(inspections.prefix(3)) { inspection in
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: inspection.inspectionType.symbol)
              .foregroundStyle(inspection.riskLevel.color)
              .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
              Text(inspection.title)
                .font(.caption.weight(.semibold))
              Text("\(inspection.inspectionType.rawValue) • \(inspection.quantityReceived)/\(inspection.quantityExpected) received")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Text(inspection.discrepancyType == .none ? inspection.conditionSummary : inspection.discrepancySummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer()
            Badge(inspection.inspectionStatus.rawValue, color: inspection.inspectionStatus.color)
          }
        }
      }
      .padding(10)
      .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

extension ReceivingInspectionType {
  var symbol: String {
    switch self {
    case .inbound: "tray.and.arrow.down.fill"
    case .packageCondition: "shippingbox.fill"
    case .quantityCheck: "number.circle.fill"
    case .returnInspection: "arrow.uturn.backward.square.fill"
    case .procurementReceipt: "cart.badge.plus"
    case .exceptionReview: "exclamationmark.triangle.fill"
    }
  }
}

extension ReceivingInspectionStatus {
  var color: Color {
    switch self {
    case .pending: .orange
    case .inspected, .resolved: .green
    case .discrepancy: .red
    case .blocked: .purple
    }
  }
}

extension ReceivingDiscrepancyType {
  var color: Color {
    switch self {
    case .none: .green
    case .quantityMismatch, .damaged, .wrongItem, .missingItem, .documentationMissing: .red
    case .other: .orange
    }
  }
}

extension ProcurementApprovalStatus {
  var color: Color {
    switch self {
    case .approved: .green
    case .draft, .pendingApproval: .orange
    case .rejected, .needsReview: .red
    }
  }
}

extension ProcurementStatus {
  var color: Color {
    switch self {
    case .received: .green
    case .ordered, .approvedToOrder: .blue
    case .requested: .orange
    case .blocked, .cancelled: .red
    }
  }

  var symbol: String {
    switch self {
    case .requested: "cart.badge.plus"
    case .approvedToOrder: "checkmark.seal.fill"
    case .ordered: "cart.fill"
    case .received: "shippingbox.fill"
    case .blocked: "hand.raised.fill"
    case .cancelled: "xmark.circle.fill"
    }
  }
}

extension ReturnClaimType {
  var symbol: String {
    switch self {
    case .returnRequest: "arrow.uturn.backward.square.fill"
    case .exchange: "arrow.left.arrow.right.square.fill"
    case .refund: "creditcard.trianglebadge.exclamationmark"
    case .damageClaim: "exclamationmark.triangle.fill"
    case .missingItemClaim: "shippingbox.and.arrow.backward.fill"
    case .carrierClaim: "truck.box.fill"
    }
  }
}

extension ReturnClaimStatus {
  var color: Color {
    switch self {
    case .draft, .readyToSubmit: .orange
    case .submitted: .blue
    case .approved, .resolved: .green
    case .disputed, .blocked: .red
    }
  }
}

extension CostCategory {
  var symbol: String {
    switch self {
    case .orderCost: "cart.fill"
    case .shipping: "truck.box.fill"
    case .taxGST: "percent"
    case .reimbursement: "arrow.uturn.backward.circle.fill"
    case .adjustment: "plusminus.circle.fill"
    case .serviceFee: "creditcard.fill"
    case .other: "creditcard.and.123"
    }
  }
}

extension CostApprovalStatus {
  var color: Color {
    switch self {
    case .approved: .green
    case .draft, .pendingApproval: .orange
    case .rejected, .needsReview: .red
    }
  }
}

extension ReimbursementStatus {
  var color: Color {
    switch self {
    case .notRequired, .reimbursed: .green
    case .notSubmitted, .pending: .orange
    case .disputed: .red
    }
  }
}

extension PackageItemCategory {
  var symbol: String {
    switch self {
    case .officeSupplies: "folder.fill"
    case .electronics: "desktopcomputer"
    case .furniture: "chair.fill"
    case .samples: "testtube.2"
    case .documents: "doc.text.fill"
    case .apparel: "tshirt.fill"
    case .other: "shippingbox.fill"
    }
  }
}

extension PackageVerificationStatus {
  var color: Color {
    switch self {
    case .verified: .green
    case .partiallyVerified: .orange
    case .notVerified: .gray
    case .discrepancy: .red
    case .blocked: .purple
    }
  }
}

extension DeliveryInstructionType {
  var symbol: String {
    switch self {
    case .deliveryWindow: "clock.badge.checkmark.fill"
    case .accessConstraint: "lock.shield.fill"
    case .carrierNote: "truck.box.fill"
    case .handling: "shippingbox.circle.fill"
    case .security: "shield.lefthalf.filled"
    case .contactRequired: "phone.badge.checkmark.fill"
    }
  }
}

extension ContactLinkedEntityType {
  var symbol: String {
    switch self {
    case .store: "storefront.fill"
    case .supplier: "building.2.fill"
    case .carrier: "truck.box.fill"
    case .shopifyStore: "cart.fill"
    case .internalTeam: "person.2.fill"
    case .customerProfile: "person.text.rectangle.fill"
    case .destinationAddress: "mappin.and.ellipse"
    case .deliveryInstruction: "signpost.right.and.left.fill"
    case .packageContent: "shippingbox.circle.fill"
    case .costRecord: "creditcard.and.123"
    case .returnClaim: "arrow.uturn.backward.square.fill"
    case .procurementRequest: "cart.badge.plus"
    case .receivingInspection: "checklist.checked"
    case .order: "shippingbox.fill"
    case .intakeEmail: "envelope.open.fill"
    case .trackingEvent: "location.fill.viewfinder"
    case .evidence: "paperclip"
    case .reviewTask: "checklist"
    case .slaPolicy: "timer"
    case .exceptionPlaybook: "book.closed.fill"
    case .draftMessage: "envelope.open.fill"
    }
  }

  var vendorProfileType: VendorProfileType {
    switch self {
    case .store: .store
    case .supplier: .supplier
    case .carrier: .carrier
    case .shopifyStore: .shopifyStore
    case .internalTeam: .internalTeam
    default: .supplier
    }
  }
}

extension AccountLinkedEntityType {
  var symbol: String {
    switch self {
    case .store: "storefront.fill"
    case .supplier: "building.2.fill"
    case .carrier: "truck.box.fill"
    case .shopifyStore: "cart.fill"
    case .internalTeam: "person.2.fill"
    case .contact: "person.crop.circle.badge.checkmark"
    case .customerProfile: "person.text.rectangle.fill"
    case .destinationAddress: "mappin.and.ellipse"
    case .deliveryInstruction: "signpost.right.and.left.fill"
    case .packageContent: "shippingbox.circle.fill"
    case .costRecord: "creditcard.and.123"
    case .returnClaim: "arrow.uturn.backward.square.fill"
    case .procurementRequest: "cart.badge.plus"
    case .receivingInspection: "checklist.checked"
    case .order: "shippingbox.fill"
    case .intakeEmail: "envelope.open.fill"
    case .integration: "point.3.connected.trianglepath.dotted"
    case .sourceConnection: "link.badge.plus"
    }
  }

  var vendorProfileType: VendorProfileType {
    switch self {
    case .store: .store
    case .supplier: .supplier
    case .carrier: .carrier
    case .shopifyStore: .shopifyStore
    case .internalTeam: .internalTeam
    default: .supplier
    }
  }
}

extension ReviewTaskLinkedEntityType {
  var symbol: String {
    switch self {
    case .order: "shippingbox.fill"
    case .intakeEmail: "envelope.open.fill"
    case .trackingEvent: "location.fill.viewfinder"
    case .evidence: "paperclip"
    case .automationRule: "arrow.triangle.branch"
    case .savedFilter: "line.3.horizontal.decrease.circle.fill"
    case .auditEvent: "list.clipboard.fill"
    case .reviewTask: "checklist"
    case .handoffNote: "arrow.left.arrow.right.square.fill"
    case .slaPolicy: "timer"
    case .exceptionPlaybook: "book.closed.fill"
    case .draftMessage: "envelope.open.fill"
    case .contact: "person.crop.circle.badge.checkmark"
    case .customerProfile: "person.text.rectangle.fill"
    case .destinationAddress: "mappin.and.ellipse"
    case .deliveryInstruction: "signpost.right.and.left.fill"
    case .packageContent: "shippingbox.circle.fill"
    case .costRecord: "creditcard.and.123"
    case .returnClaim: "arrow.uturn.backward.square.fill"
    case .procurementRequest: "cart.badge.plus"
    case .receivingInspection: "checklist.checked"
    case .account: "key.horizontal.fill"
    case .vendorProfile: "building.2.crop.circle.fill"
    case .shipmentGroup: "shippingbox.and.arrow.backward.fill"
    case .importQueueItem: "tray.and.arrow.down.fill"
    case .acceptanceRecord: "checkmark.rectangle.stack.fill"
    case .reconciliationIssue: "arrow.triangle.2.circlepath.circle.fill"
    }
  }
}

extension TaskPriority {
  var color: Color {
    switch self {
    case .low: .gray
    case .normal: .blue
    case .high: .orange
    case .urgent: .red
    }
  }
}

extension TaskStatus {
  var color: Color {
    switch self {
    case .open: .orange
    case .inProgress: .blue
    case .blocked: .red
    case .completed: .green
    }
  }
}

extension CommunicationChannel {
  var symbol: String {
    switch self {
    case .email: "envelope.fill"
    case .phoneScript: "phone.fill"
    case .internalNote: "note.text"
    case .supplierPortal: "person.crop.circle.badge.checkmark"
    }
  }
}

extension DraftMessageStatus {
  var color: Color {
    switch self {
    case .draft: .orange
    case .ready: .blue
    case .sentLocally: .green
    case .reopened: .purple
    }
  }
}

extension CredentialStorageStatus {
  var color: Color {
    switch self {
    case .notStored: .gray
    case .externalVaultReference: .green
    case .needsSetup: .orange
    case .accessPending: .blue
    case .rotatedExternally: .purple
    }
  }
}

extension MFAStatus {
  var color: Color {
    switch self {
    case .notConfigured: .orange
    case .enabled: .green
    case .needsReview: .red
    case .sharedDevice: .blue
    case .unknown: .gray
    }
  }
}

extension ReviewTask {
  var isLocallyOverdue: Bool {
    let normalizedDueDate = dueDate.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard status != .completed else { return false }
    return normalizedDueDate.contains("yesterday")
      || normalizedDueDate.contains("overdue")
      || normalizedDueDate.contains("past due")
  }
}

extension HandoffNote {
  var isLocallyOverdue: Bool {
    let normalizedDueDate = dueDate.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard status != .completed else { return false }
    return normalizedDueDate.contains("yesterday")
      || normalizedDueDate.contains("overdue")
      || normalizedDueDate.contains("past due")
  }
}

extension ShipmentGroup {
  func matches(linkedEntityType: ReviewTaskLinkedEntityType, linkedEntityID: String) -> Bool {
    switch linkedEntityType {
    case .order:
      guard let id = UUID(uuidString: linkedEntityID) else { return false }
      return primaryOrderID == id || relatedOrderIDs.contains(id)
    case .intakeEmail:
      guard let id = UUID(uuidString: linkedEntityID) else { return false }
      return relatedIntakeEmailIDs.contains(id)
    case .trackingEvent:
      guard let id = UUID(uuidString: linkedEntityID) else { return false }
      return relatedTrackingEventIDs.contains(id)
    case .evidence:
      guard let id = UUID(uuidString: linkedEntityID) else { return false }
      return relatedEvidenceIDs.contains(id)
    case .reviewTask, .handoffNote, .slaPolicy, .exceptionPlaybook, .draftMessage, .contact, .customerProfile, .destinationAddress, .deliveryInstruction, .packageContent, .costRecord, .returnClaim, .procurementRequest, .receivingInspection, .account, .vendorProfile, .automationRule, .savedFilter, .auditEvent, .shipmentGroup, .importQueueItem, .acceptanceRecord, .reconciliationIssue:
      return id.uuidString == linkedEntityID
    }
  }
}

extension ImportQueueItem {
  func matches(linkedEntityType: ReviewTaskLinkedEntityType, linkedEntityID: String) -> Bool {
    switch linkedEntityType {
    case .order:
      guard let id = UUID(uuidString: linkedEntityID) else { return false }
      return suggestedLinkedOrderID == id
    case .shipmentGroup:
      guard let id = UUID(uuidString: linkedEntityID) else { return false }
      return suggestedShipmentGroupID == id
    case .importQueueItem:
      return id.uuidString == linkedEntityID
    case .acceptanceRecord:
      return false
    case .reconciliationIssue:
      return false
    default:
      return false
    }
  }
}

extension AcceptanceRecord {
  func matches(linkedEntityType: ReviewTaskLinkedEntityType, linkedEntityID: String) -> Bool {
    switch linkedEntityType {
    case .order:
      guard let id = UUID(uuidString: linkedEntityID) else { return false }
      return linkedOrderID == id
    case .shipmentGroup:
      guard let id = UUID(uuidString: linkedEntityID) else { return false }
      return linkedShipmentGroupID == id
    case .importQueueItem:
      guard sourceType == .importQueueItem else { return false }
      return sourceID.uuidString == linkedEntityID
    case .intakeEmail:
      guard sourceType == .intakeEmail else { return false }
      return sourceID.uuidString == linkedEntityID
    case .acceptanceRecord:
      return id.uuidString == linkedEntityID
    case .reconciliationIssue:
      return false
    default:
      return false
    }
  }
}

extension TimelineActivity {
  var reviewTaskLinkedEntityType: ReviewTaskLinkedEntityType? {
    switch entityType {
    case .order: .order
    case .intakeEmail: .intakeEmail
    case .trackingEvent: .trackingEvent
    case .evidence: .evidence
    case .reviewTask: .reviewTask
    case .handoffNote: .handoffNote
    case .slaPolicy: .slaPolicy
    case .communicationTemplate: nil
    case .draftMessage: .draftMessage
    case .contact: .contact
    case .customerProfile: .customerProfile
    case .destinationAddress: .destinationAddress
    case .deliveryInstruction: .deliveryInstruction
    case .packageContent: .packageContent
    case .costRecord: .costRecord
    case .returnClaim: .returnClaim
    case .procurementRequest: .procurementRequest
    case .receivingInspection: .receivingInspection
    case .account: .account
    case .vendorProfile: .vendorProfile
    case .shipmentGroup: .shipmentGroup
    case .importQueueItem: .importQueueItem
    case .acceptanceRecord: .acceptanceRecord
    case .automationRule: .automationRule
    case .savedFilter: .savedFilter
    case .auditEvent: .auditEvent
    }
  }

  var supportsReviewTask: Bool {
    reviewTaskLinkedEntityType != nil
  }

  var supportsDraftMessage: Bool {
    reviewTaskLinkedEntityType != nil
  }
}

extension ValidationIssue {
  var supportsReviewTask: Bool {
    linkedEntityType != nil
  }

  var supportsDraftMessage: Bool {
    linkedEntityType != nil
  }
}

extension ReconciliationIssue {
  func matches(entityType: ReconciliationEntityType, entityID: String) -> Bool {
    (sourceEntityType == entityType && sourceEntityID == entityID)
      || (targetEntityType == entityType && targetEntityID == entityID)
  }
}

extension SearchEntityType {
  var symbol: String {
    switch self {
    case .order: "shippingbox.fill"
    case .intakeEmail: "envelope.open.fill"
    case .trackingEvent: "location.fill.viewfinder"
    case .evidence: "paperclip"
    case .auditEvent: "list.clipboard.fill"
    case .automationRule: "arrow.triangle.branch"
    }
  }

  var color: Color {
    switch self {
    case .order: .teal
    case .intakeEmail: .orange
    case .trackingEvent: .indigo
    case .evidence: .purple
    case .auditEvent: .blue
    case .automationRule: .green
    }
  }
}

extension EvidenceLinkedEntityType {
  var symbol: String {
    switch self {
    case .order: "shippingbox.fill"
    case .intakeEmail: "envelope.open.fill"
    }
  }
}

extension EvidenceSource {
  var symbol: String {
    switch self {
    case .forwardedEmail: "envelope.open.fill"
    case .manualUpload: "paperclip"
    case .watchedFolder: "folder.fill"
    case .screenshot: "photo.fill"
    case .supplierPortal: "person.crop.circle.badge.checkmark"
    }
  }
}

extension TrackingEventSource {
  var symbol: String {
    switch self {
    case .manual: "square.and.pencil"
    case .forwardedEmail: "envelope.open.fill"
    case .carrierMock: "location.fill.viewfinder"
    case .shopifyMock: "cart.fill"
    }
  }
}

extension AutomationTriggerType {
  var symbol: String {
    switch self {
    case .forwardedEmailCaptured: "envelope.open.fill"
    case .orderNeedsReview: "checkmark.shield.fill"
    case .trackingWarning: "location.fill.viewfinder"
    case .evidenceAdded: "paperclip"
    case .manualReview: "square.and.pencil"
    }
  }
}

struct Badge: View {
  var text: String
  var color: Color

  init(_ text: String, color: Color) {
    self.text = text
    self.color = color
  }

  var body: some View {
    Text(text)
      .font(.caption.weight(.semibold))
      .foregroundStyle(color)
      .padding(.horizontal, 9)
      .padding(.vertical, 5)
      .background(color.opacity(0.12))
      .clipShape(Capsule())
  }
}

struct Panel<Content: View>: View {
  var title: String
  var symbol: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label(title, systemImage: symbol)
        .font(.title3.bold())
      content
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct SettingsPanel<Content: View>: View {
  var title: String
  var symbol: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label(title, systemImage: symbol)
        .font(.headline)
      VStack(alignment: .leading, spacing: 12) {
        content
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct DetailCell: View {
  var title: String
  var value: String
  var symbol: String

  init(_ title: String, _ value: String, symbol: String) {
    self.title = title
    self.value = value
    self.symbol = symbol
  }

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: symbol)
        .foregroundStyle(.teal)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(value)
          .font(.callout.weight(.medium))
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
