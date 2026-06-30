import SwiftUI

extension String {
  var normalizedValidationKey: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
      .replacingOccurrences(of: " ", with: "")
  }

  var isPlaceholderValidationValue: Bool {
    let normalized = trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let compact = normalized.replacingOccurrences(of: " ", with: "")
    return normalized.isEmpty
      || normalized == "pending"
      || normalized == "unknown"
      || normalized == "unassigned"
      || normalized == "choose folder"
      || normalized == "needs setup"
      || normalized == "never"
      || compact.contains("needsreview")
      || compact.contains("unknownsender")
      || compact.contains("unknowndate")
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
    case .inventoryReceipt: "archivebox.fill"
    case .storageLocation: "cabinet.fill"
    case .custodyRecord: "person.badge.shield.checkmark.fill"
    case .labelReference: "barcode.viewfinder"
    case .scanSession: "qrcode.viewfinder"
    case .shipmentManifest: "list.bullet.clipboard.fill"
    case .dispatchChecklist: "checkmark.rectangle.stack.fill"
    case .accountCredentialRecord: "key.horizontal.fill"
    case .vendorProfile: "building.2.crop.circle.fill"
    case .shipmentGroup: "shippingbox.and.arrow.backward.fill"
    case .importQueueItem: "tray.and.arrow.down.fill"
    case .acceptanceRecord: "checkmark.rectangle.stack.fill"
    case .reconciliationIssue: "arrow.triangle.2.circlepath.circle.fill"
    case .microsoft365MailboxConnection: "mail.stack.fill"
    case .spaceMailIMAPConnection: "server.rack"
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
    case .inventoryReceipt: "archivebox.fill"
    case .storageLocation: "cabinet.fill"
    case .custodyRecord: "person.badge.shield.checkmark.fill"
    case .labelReference: "barcode.viewfinder"
    case .scanSession: "qrcode.viewfinder"
    case .shipmentManifest: "list.bullet.clipboard.fill"
    case .dispatchChecklist: "checkmark.rectangle.stack.fill"
    case .account: "key.horizontal.fill"
    case .vendorProfile: "building.2.crop.circle.fill"
    case .integration: "point.3.connected.trianglepath.dotted"
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
    case .intakeParser: "text.magnifyingglass"
    case .spaceMailIntake: "server.rack"
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
    case .inventoryReceipt: "archivebox.fill"
    case .storageLocation: "cabinet.fill"
    case .custodyRecord: "person.badge.shield.checkmark.fill"
    case .labelReference: "barcode.viewfinder"
    case .scanSession: "qrcode.viewfinder"
    case .shipmentManifest: "list.bullet.clipboard.fill"
    case .dispatchChecklist: "checkmark.rectangle.stack.fill"
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
      || source == .intakeParser
      || source == .spaceMailIntake
      || source == .exceptionPlaybook
      || source == .tracking
      || prioritySeverity.localizedCaseInsensitiveContains("critical")
  }

  var supportsReviewAction: Bool {
    switch source {
    case .reviewTask, .handoffNote, .intakeEmail, .intakeParser, .spaceMailIntake, .reconciliation, .shipmentGroup, .tracking, .evidence, .slaPolicy, .exceptionPlaybook, .draftMessage, .contact, .customerProfile, .destinationAddress, .deliveryInstruction, .packageContent, .costRecord, .returnClaim, .procurementRequest, .receivingInspection, .inventoryReceipt, .storageLocation, .custodyRecord, .labelReference, .scanSession, .shipmentManifest, .dispatchChecklist, .account, .vendorProfile:
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

struct InventoryReceiptStrip: View {
  var receipts: [InventoryReceiptRecord]

  var body: some View {
    if !receipts.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Label("Inventory receipts", systemImage: "archivebox.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        ForEach(receipts.prefix(3)) { receipt in
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: receipt.receiptType.symbol)
              .foregroundStyle(receipt.riskLevel.color)
              .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
              Text(receipt.title)
                .font(.caption.weight(.semibold))
              Text("\(receipt.receiptType.rawValue) • \(receipt.quantityAccepted)/\(receipt.quantityReceived) accepted")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Text(receipt.storageLocationSummary.isEmpty ? receipt.discrepancySummary : receipt.storageLocationSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer()
            Badge(receipt.stockHandoffStatus.rawValue, color: receipt.stockHandoffStatus.color)
          }
        }
      }
      .padding(10)
      .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

struct StorageLocationStrip: View {
  var locations: [StorageLocationRecord]

  var body: some View {
    if !locations.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Label("Storage locations", systemImage: "cabinet.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        ForEach(locations.prefix(3)) { location in
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: location.locationType.symbol)
              .foregroundStyle(location.riskLevel.color)
              .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
              Text(location.title)
                .font(.caption.weight(.semibold))
              Text("\(location.locationCode) • \(location.areaZone)")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Text(location.currentUsageSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer()
            Badge(location.isEnabled ? "Enabled" : "Disabled", color: location.isEnabled ? .green : .gray)
          }
        }
      }
      .padding(10)
      .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

struct CustodyRecordStrip: View {
  var records: [CustodyRecord]

  var body: some View {
    if !records.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Label("Custody chain", systemImage: "person.badge.shield.checkmark.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        ForEach(records.prefix(3)) { record in
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: record.handoffMethod.symbol)
              .foregroundStyle(record.riskLevel.color)
              .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
              Text(record.title)
                .font(.caption.weight(.semibold))
              Text("\(record.currentCustodianTeam) • \(record.assignedOwnerTeam)")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Text(record.custodyReason)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer()
            Badge(record.custodyStatus.rawValue, color: record.custodyStatus.color)
          }
        }
      }
      .padding(10)
      .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

struct LabelReferenceStrip: View {
  var records: [LabelReferenceRecord]

  var body: some View {
    if !records.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Label("Label references", systemImage: "barcode.viewfinder")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        ForEach(records.prefix(3)) { record in
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: record.labelType.symbol)
              .foregroundStyle(record.riskLevel.color)
              .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
              Text(record.title)
                .font(.caption.weight(.semibold))
              Text("\(record.labelValuePlaceholder) • \(record.associatedCarrier)")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Text(record.notes)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer()
            Badge(record.labelStatus.rawValue, color: record.labelStatus.color)
          }
        }
      }
      .padding(10)
      .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

struct ScanSessionStrip: View {
  var records: [ScanSessionRecord]

  var body: some View {
    if !records.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Label("Scan sessions", systemImage: "qrcode.viewfinder")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        ForEach(records.prefix(3)) { record in
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: record.scanPurpose.symbol)
              .foregroundStyle(record.riskLevel.color)
              .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
              Text(record.title)
                .font(.caption.weight(.semibold))
              Text("\(record.expectedLabelReferenceValue) • captured \(record.capturedValuePlaceholder.isEmpty ? "missing" : record.capturedValuePlaceholder)")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Text(record.mismatchSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer()
            Badge(record.scanStatus.rawValue, color: record.scanStatus.color)
          }
        }
      }
      .padding(10)
      .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

struct ShipmentManifestStrip: View {
  var records: [ShipmentManifestRecord]

  var body: some View {
    if !records.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Label("Shipment manifests", systemImage: "list.bullet.clipboard.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        ForEach(records.prefix(3)) { record in
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: record.manifestType.symbol)
              .foregroundStyle(record.dispatchStatus.color)
              .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
              Text(record.title)
                .font(.caption.weight(.semibold))
              Text("\(record.carrierCourier) • \(record.destinationSummary)")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Text(record.notes)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer()
            Badge(record.dispatchStatus.rawValue, color: record.dispatchStatus.color)
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

extension InventoryReceiptType {
  var symbol: String {
    switch self {
    case .stockReceipt: "archivebox.fill"
    case .teamHandoff: "arrow.left.arrow.right.square.fill"
    case .returnReceipt: "arrow.uturn.backward.square.fill"
    case .replacementReceipt: "shippingbox.circle.fill"
    case .sampleReceipt: "testtube.2"
    case .exceptionReceipt: "exclamationmark.triangle.fill"
    }
  }
}

extension StorageLocationType {
  var symbol: String {
    switch self {
    case .shelf: "cabinet.fill"
    case .bin: "archivebox.fill"
    case .cage: "lock.square.fill"
    case .desk: "table.furniture.fill"
    case .locker: "lock.rectangle.stack.fill"
    case .handoffArea: "arrow.left.arrow.right.square.fill"
    case .stagingArea: "tray.and.arrow.down.fill"
    }
  }
}

extension InventoryStockHandoffStatus {
  var color: Color {
    switch self {
    case .stocked, .handedOff: .green
    case .pending, .partiallyAccepted: .orange
    case .rejected, .needsReview: .red
    }
  }
}

extension CustodyStatus {
  var color: Color {
    switch self {
    case .pendingTransfer, .transferred: .blue
    case .received, .returnedClosed: .green
    case .disputed, .needsReview: .red
    }
  }
}

extension CustodyHandoffMethod {
  var symbol: String {
    switch self {
    case .directHandoff: "person.2.fill"
    case .storageMove: "cabinet.fill"
    case .courierHandoff: "truck.box.fill"
    case .internalCollection: "arrow.left.arrow.right.square.fill"
    case .evidenceReview: "paperclip"
    case .manualUpdate: "square.and.pencil"
    }
  }
}

struct DispatchReadinessStrip: View {
  var checklists: [DispatchReadinessChecklist]

  var body: some View {
    if !checklists.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Label("Dispatch readiness", systemImage: "checkmark.rectangle.stack.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        ForEach(checklists.prefix(3)) { checklist in
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: checklist.checklistType.symbol)
              .foregroundStyle(checklist.checklistStatus.color)
              .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
              Text(checklist.title)
                .font(.caption.weight(.semibold))
              Text("\(checklist.checklistType.rawValue) • \(checklist.plannedDispatchDate)")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Text(checklist.missingRequirementsSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer()
            Badge(checklist.checklistStatus.rawValue, color: checklist.checklistStatus.color)
          }
        }
      }
      .padding(10)
      .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

extension LabelReferenceType {
  var symbol: String {
    switch self {
    case .barcode: "barcode.viewfinder"
    case .qrCode: "qrcode.viewfinder"
    case .trackingLabel: "tag.fill"
    case .shelfBinLabel: "cabinet.fill"
    case .returnLabel: "arrow.uturn.backward.square.fill"
    case .procurementLabel: "cart.badge.plus"
    case .receivingLabel: "checklist.checked"
    case .inventoryLabel: "archivebox.fill"
    case .custodyLabel: "person.badge.shield.checkmark.fill"
    case .evidenceLabel: "paperclip"
    }
  }
}

extension LabelReferenceStatus {
  var color: Color {
    switch self {
    case .scannedVerified: .green
    case .printedLocally: .blue
    case .draft: .orange
    case .invalidNeedsReview, .missingValue: .red
    case .archived: .gray
    }
  }
}

extension ScanPurpose {
  var symbol: String {
    switch self {
    case .labelVerification: "barcode.viewfinder"
    case .orderCheck: "shippingbox.fill"
    case .receivingCheck: "checklist.checked"
    case .inventoryHandoff: "archivebox.fill"
    case .custodyTransfer: "person.badge.shield.checkmark.fill"
    case .returnClaimCheck: "arrow.uturn.backward.square.fill"
    case .evidenceCheck: "paperclip"
    }
  }
}

extension ScanSessionStatus {
  var color: Color {
    switch self {
    case .matched, .completed: .green
    case .planned, .reopened: .orange
    case .mismatchNeedsReview, .blocked: .red
    }
  }
}

extension ShipmentManifestType {
  var symbol: String {
    switch self {
    case .shipmentManifest: "list.bullet.clipboard.fill"
    case .dispatchChecklist: "checkmark.rectangle.stack.fill"
    case .dispatchBatch: "shippingbox.and.arrow.backward.fill"
    case .courierHandoff: "person.badge.shield.checkmark.fill"
    case .internalDeliveryRun: "arrow.triangle.swap"
    case .outboundTransferGroup: "tray.and.arrow.up.fill"
    }
  }
}

extension ShipmentManifestDispatchStatus {
  var color: Color {
    switch self {
    case .draft: .gray
    case .prepared: .blue
    case .dispatched: .purple
    case .handedOff: .green
    case .blockedNeedsReview: .red
    case .reopened: .orange
    }
  }
}

extension DispatchChecklistType {
  var symbol: String {
    switch self {
    case .manifestReadiness: "list.bullet.clipboard.fill"
    case .labelAndScan: "qrcode.viewfinder"
    case .custodyHandoff: "person.badge.shield.checkmark.fill"
    case .destinationReview: "mappin.and.ellipse"
    case .exceptionClearance: "checkmark.shield.fill"
    case .outboundTransfer: "tray.and.arrow.up.fill"
    }
  }
}

extension DispatchChecklistStatus {
  var color: Color {
    switch self {
    case .draft: .gray
    case .ready: .blue
    case .blockedNeedsReview: .red
    case .completed: .green
    case .reopened: .orange
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
    case .inventoryReceipt: "archivebox.fill"
    case .storageLocation: "cabinet.fill"
    case .custodyRecord: "person.badge.shield.checkmark.fill"
    case .labelReference: "barcode.viewfinder"
    case .scanSession: "qrcode.viewfinder"
    case .shipmentManifest: "list.bullet.clipboard.fill"
    case .dispatchChecklist: "checkmark.rectangle.stack.fill"
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
    case .inventoryReceipt: "archivebox.fill"
    case .storageLocation: "cabinet.fill"
    case .custodyRecord: "person.badge.shield.checkmark.fill"
    case .labelReference: "barcode.viewfinder"
    case .scanSession: "qrcode.viewfinder"
    case .shipmentManifest: "list.bullet.clipboard.fill"
    case .dispatchChecklist: "checkmark.rectangle.stack.fill"
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
    case .inventoryReceipt: "archivebox.fill"
    case .storageLocation: "cabinet.fill"
    case .custodyRecord: "person.badge.shield.checkmark.fill"
    case .labelReference: "barcode.viewfinder"
    case .scanSession: "qrcode.viewfinder"
    case .shipmentManifest: "list.bullet.clipboard.fill"
    case .dispatchChecklist: "checkmark.rectangle.stack.fill"
    case .account: "key.horizontal.fill"
    case .vendorProfile: "building.2.crop.circle.fill"
    case .integration: "point.3.connected.trianglepath.dotted"
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
    case .reviewTask, .handoffNote, .slaPolicy, .exceptionPlaybook, .draftMessage, .contact, .customerProfile, .destinationAddress, .deliveryInstruction, .packageContent, .costRecord, .returnClaim, .procurementRequest, .receivingInspection, .inventoryReceipt, .storageLocation, .custodyRecord, .labelReference, .scanSession, .shipmentManifest, .dispatchChecklist, .account, .vendorProfile, .integration, .automationRule, .savedFilter, .auditEvent, .shipmentGroup, .importQueueItem, .acceptanceRecord, .reconciliationIssue:
      guard let id = UUID(uuidString: linkedEntityID) else { return false }
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
    case .inventoryReceipt: .inventoryReceipt
    case .storageLocation: .storageLocation
    case .custodyRecord: .custodyRecord
    case .labelReference: .labelReference
    case .scanSession: .scanSession
    case .shipmentManifest: .shipmentManifest
    case .dispatchChecklist: .dispatchChecklist
    case .account: .account
    case .vendorProfile: .vendorProfile
    case .integration: .integration
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
      .lineLimit(1)
      .truncationMode(.tail)
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

struct FilterControlGrid<Content: View>: View {
  @ViewBuilder var content: Content

  private var columns: [GridItem] {
    [GridItem(.adaptive(minimum: 150), spacing: 10)]
  }

  var body: some View {
    LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
      content
    }
    .pickerStyle(.menu)
    .textFieldStyle(.roundedBorder)
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct CompactActionRow<Content: View>: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @ViewBuilder var content: Content

  private var isCompact: Bool { horizontalSizeClass == .compact }

  var body: some View {
    if isCompact {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 8)], alignment: .leading, spacing: 8) {
        content
      }
      .font(.caption)
      .controlSize(.small)
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      HStack(spacing: 8) {
        content
      }
    }
  }
}

struct CompactMetadataGrid<Content: View>: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  var minimumWidth: CGFloat = 110
  @ViewBuilder var content: Content

  private var isCompact: Bool { horizontalSizeClass == .compact }

  var body: some View {
    if isCompact {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumWidth), spacing: 8)], alignment: .leading, spacing: 8) {
        content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      HStack(spacing: 8) {
        content
      }
    }
  }
}

struct IntakeReadinessStrip: View {
  var email: ForwardedEmailIntake
  var hasLinkedOrder: Bool = false

  private var missingFields: [String] {
    [
      email.detectedMerchant.isPlaceholderValidationValue ? "merchant" : nil,
      email.detectedOrderNumber.isPlaceholderValidationValue ? "order" : nil,
      email.detectedTrackingNumber.isPlaceholderValidationValue ? "tracking" : nil,
      email.detectedDestinationAddress.isPlaceholderValidationValue ? "destination" : nil
    ].compactMap { $0 }
  }

  private var confidence: Int {
    var score = 90
    if email.detectedMerchant.isPlaceholderValidationValue { score -= 18 }
    if email.detectedOrderNumber.isPlaceholderValidationValue { score -= 22 }
    if email.detectedTrackingNumber.isPlaceholderValidationValue { score -= 16 }
    if email.detectedDestinationAddress.isPlaceholderValidationValue { score -= 14 }
    if !hasLinkedOrder { score -= 8 }
    if email.reviewState == .needsReview { score -= 6 }
    return max(10, min(100, score))
  }

  private var tone: Color {
    if confidence < 55 || missingFields.contains("order") || missingFields.contains("tracking") {
      return .orange
    }
    if confidence < 75 || !missingFields.isEmpty {
      return .yellow
    }
    return .green
  }

  private var statusLabel: String {
    if missingFields.contains("order") || missingFields.contains("tracking") {
      return "Check before order"
    }
    if !missingFields.isEmpty {
      return "Needs field check"
    }
    if hasLinkedOrder {
      return "Linked intake"
    }
    return "Ready to create/link"
  }

  private var detail: String {
    if missingFields.isEmpty {
      return hasLinkedOrder
        ? "Detected fields look usable and this email is already linked to an order."
        : "Detected fields look usable. Create an order or link this email to an existing order."
    }
    return "Missing or weak: \(missingFields.joined(separator: ", ")). Reprocess or edit before creating an order."
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      CompactMetadataGrid(minimumWidth: 130) {
        Badge("\(confidence)% confidence", color: confidence < 55 ? .red : confidence < 75 ? .orange : .green)
        Badge(statusLabel, color: tone)
        ForEach(missingFields, id: \.self) { field in
          Badge("Check \(field)", color: .orange)
        }
      }
      Text(detail)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct SpaceMailMVPReadinessCard: View {
  var summary: SpaceMailMVPReadinessSummary
  var showChecklist: Bool = true

  private var color: Color {
    switch summary.tone {
    case "success":
      return .green
    case "attention":
      return .orange
    case "warning":
      return .red
    default:
      return .secondary
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "checklist.checked")
          .foregroundStyle(color)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(summary.verdict)
            .font(.subheadline.weight(.semibold))
          Text(summary.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge("\(summary.completedCount)/\(summary.totalCount)", color: color)
      }

      Text(summary.nextAction)
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .fixedSize(horizontal: false, vertical: true)

      if showChecklist {
        CompactMetadataGrid(minimumWidth: 180) {
          ForEach(summary.items) { item in
            Label(item.title, systemImage: item.isComplete ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
              .font(.caption)
              .foregroundStyle(color(for: item))
              .lineLimit(2)
          }
        }
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private func color(for item: SpaceMailMVPReadinessItem) -> Color {
    switch item.tone {
    case "success":
      return .green
    case "attention":
      return .orange
    case "warning":
      return .red
    default:
      return .secondary
    }
  }
}

struct SpaceMailTestRunGuide: View {
  var summary: SpaceMailMVPReadinessSummary

  private var color: Color {
    switch summary.tone {
    case "success":
      return .green
    case "attention":
      return .orange
    case "warning":
      return .red
    default:
      return .secondary
    }
  }

  private var steps: [String] {
    [
      "Confirm the SpaceMail row shows host, folder, SSL/TLS, mixed mailbox mode, and a Keychain password reference.",
      "Run real SpaceMail refresh manually. It must stay read-only and should show fetched, imported, duplicate, filtered, and uncertain counts.",
      "Review imported Inbox rows. Check the readiness strip before creating or linking an order.",
      "Review uncertain or filtered examples if a genuine order email did not import automatically.",
      "Create or link one order from Inbox, then confirm the order appears in Orders, Dashboard, Workbench, Tasks, and Audit.",
      "Quit and reopen the app to confirm local JSON state still shows the same intake, order, and audit trail."
    ]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "checklist.checked")
          .foregroundStyle(color)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text("SpaceMail supervised test run")
            .font(.headline)
          Text("Use this short path to decide whether the current SpaceMail local MVP is usable without adding background sync or mailbox mutation.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge("\(summary.completedCount)/\(summary.totalCount) ready", color: color)
      }

      VStack(alignment: .leading, spacing: 8) {
        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
          HStack(alignment: .top, spacing: 8) {
            Text("\(index + 1)")
              .font(.caption.bold())
              .foregroundStyle(.white)
              .frame(width: 22, height: 22)
              .background(color, in: Circle())
            Text(step)
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }

      Text("Current gate: \(summary.verdict). \(summary.nextAction)")
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct SpaceMailQACheckCard: View {
  var summary: SpaceMailQACheckSummary

  private var color: Color {
    switch summary.tone {
    case "success":
      return .green
    case "attention":
      return .orange
    case "warning":
      return .red
    default:
      return .secondary
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "doc.text.magnifyingglass")
          .foregroundStyle(color)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(summary.verdict)
            .font(.headline)
          Text(summary.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Badge("\(summary.completedCount)/\(summary.totalCount)", color: color)
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], alignment: .leading, spacing: 10) {
        ForEach(summary.checks) { check in
          VStack(alignment: .leading, spacing: 6) {
            Label(check.title, systemImage: check.isComplete ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
              .font(.caption.weight(.semibold))
              .foregroundStyle(color(for: check))
            Text(check.detail)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            Text(check.evidence)
              .font(.caption2.weight(.semibold))
              .foregroundStyle(color(for: check))
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(color(for: check).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
  }

  private func color(for check: SpaceMailQACheck) -> Color {
    switch check.tone {
    case "success":
      return .green
    case "attention":
      return .orange
    case "warning":
      return .red
    default:
      return .secondary
    }
  }
}

struct SpaceMailReleaseSnapshotCard: View {
  var snapshot: SpaceMailReleaseSnapshot

  private var color: Color {
    color(for: snapshot.tone)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "doc.plaintext.fill")
          .foregroundStyle(color)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(snapshot.verdict)
            .font(.headline)
          Text(snapshot.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Text("Generated \(snapshot.generatedDate)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
        }
        Spacer()
        Badge("Snapshot", color: color)
      }

      MetricStrip(items: snapshot.metrics.map { metric in
        (metric.title, metric.value, color(for: metric.tone))
      })

      VStack(alignment: .leading, spacing: 6) {
        Text("Selectable release notes")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(snapshot.reportText)
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
  }

  private func color(for tone: String) -> Color {
    switch tone {
    case "success":
      return .green
    case "attention":
      return .orange
    case "warning":
      return .red
    default:
      return .secondary
    }
  }
}

struct SpaceMailPostRefreshActionCard: View {
  var plan: SpaceMailPostRefreshActionPlan

  private var color: Color {
    color(for: plan.tone)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "arrow.triangle.branch")
          .foregroundStyle(color)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(plan.title)
            .font(.headline)
          Text(plan.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Text("Next: \(plan.primaryAction)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
        }
        Spacer()
        Badge("Post-refresh", color: color)
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], alignment: .leading, spacing: 10) {
        ForEach(plan.items) { item in
          VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Label(item.title, systemImage: item.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color(for: item.tone))
              Spacer()
              Badge("\(item.count)", color: color(for: item.tone))
            }
            Text(item.detail)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            Text(item.actionLabel)
              .font(.caption2.weight(.semibold))
              .foregroundStyle(color(for: item.tone))
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background(color(for: item.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
  }

  private func color(for tone: String) -> Color {
    switch tone {
    case "success":
      return .green
    case "attention":
      return .orange
    case "warning":
      return .red
    default:
      return .secondary
    }
  }
}

struct SpaceMailOperationsRunbook: View {
  private let normalSteps = [
    ("Confirm setup", "Check host, port, SSL/TLS, folder, mixed mailbox mode, and Keychain credential status before refreshing."),
    ("Run manual refresh", "Use real SpaceMail refresh only when a person is ready to review results. It must stay read-only."),
    ("Review outcomes", "Start with imported Inbox rows, then uncertain messages, then filtered examples if expected order mail is missing."),
    ("Create or link orders", "Use confirmed order or tracking details to create/link orders, then check Orders, Workbench, Tasks, and Audit."),
    ("Close the loop", "Mark reviewed, create a task, or draft a follow-up message so the next operator sees the current state.")
  ]

  private let recoverySteps = [
    ("Credential missing", "Set or check the SpaceMail Keychain password/app-password, then retry manual refresh."),
    ("Connection failed", "Confirm SpaceMail host, port 993, SSL/TLS, and folder name before retrying."),
    ("No imports", "Check mixed mailbox summary. Filtered non-order mail is expected for a mixed mailbox."),
    ("Expected order missing", "Review uncertain and filtered examples, then add local hints only if the reason label is clear."),
    ("Parser weak", "Use Reprocess or Edit on the intake row. Do not fetch mail again just to fix local parser fields.")
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "list.bullet.clipboard.fill")
          .foregroundStyle(.teal)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text("SpaceMail operations runbook")
            .font(.headline)
          Text("Use this when running the mixed mailbox intake manually. It describes operator actions only; it does not start refreshes or change mailbox behavior.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge("Manual", color: .teal)
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 10)], alignment: .leading, spacing: 10) {
        runbookColumn(title: "Normal path", symbol: "checkmark.seal.fill", items: normalSteps, color: .green)
        runbookColumn(title: "If something looks wrong", symbol: "wrench.and.screwdriver.fill", items: recoverySteps, color: .orange)
      }

      Text("Boundaries: SpaceMail refresh is manual and read-only. ParcelOps must not delete, move, mark read, flag, send, or modify mailbox messages. Passwords and app passwords must not be written to JSON or Audit.")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
  }

  private func runbookColumn(title: String, symbol: String, items: [(String, String)], color: Color) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(title, systemImage: symbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
      ForEach(Array(items.enumerated()), id: \.offset) { index, item in
        HStack(alignment: .top, spacing: 8) {
          Text("\(index + 1)")
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(color, in: Circle())
          VStack(alignment: .leading, spacing: 2) {
            Text(item.0)
              .font(.caption.weight(.semibold))
            Text(item.1)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct SpaceMailShiftHandoffCard: View {
  var summary: SpaceMailShiftHandoffSummary

  private var color: Color {
    color(for: summary.tone)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "person.2.wave.2.fill")
          .foregroundStyle(color)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(summary.title)
            .font(.headline)
          Text(summary.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Text(summary.lastRefreshText)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge("Handoff", color: color)
      }

      MetricStrip(items: summary.keyCounts.map { metric in
        (metric.title, metric.value, color(for: metric.tone))
      })

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], alignment: .leading, spacing: 10) {
        ForEach(summary.handoffLines) { line in
          VStack(alignment: .leading, spacing: 6) {
            Label(line.title, systemImage: line.symbol)
              .font(.caption.weight(.semibold))
              .foregroundStyle(color(for: line.tone))
            Text(line.detail)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background(color(for: line.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
  }

  private func color(for tone: String) -> Color {
    switch tone {
    case "success":
      return .green
    case "attention":
      return .orange
    case "warning":
      return .red
    default:
      return .secondary
    }
  }
}

struct SpaceMailRefreshTrendCard: View {
  var summary: SpaceMailRefreshTrendSummary

  private var color: Color {
    color(for: summary.tone)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "chart.line.uptrend.xyaxis")
          .foregroundStyle(color)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(summary.title)
            .font(.headline)
          Text(summary.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge("Trend", color: color)
      }

      MetricStrip(items: summary.metrics.map { metric in
        (metric.title, metric.value, color(for: metric.tone))
      })

      if summary.entries.isEmpty {
        MVPEmptyState(
          title: "No refresh history yet",
          detail: "Manual SpaceMail refresh results will appear here after real or mock refresh runs.",
          symbol: "clock.arrow.circlepath"
        )
      } else {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(summary.entries) { entry in
            VStack(alignment: .leading, spacing: 6) {
              HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.timestamp)
                  .font(.caption.weight(.semibold))
                Spacer()
                Badge(entry.status, color: color(for: entry.tone))
              }
              Text(entry.displayName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
              Text(entry.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(color(for: entry.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
  }

  private func color(for tone: String) -> Color {
    switch tone {
    case "success":
      return .green
    case "attention":
      return .orange
    case "warning":
      return .red
    default:
      return .secondary
    }
  }
}

struct SpaceMailOperatorGuidanceStack: View {
  var store: ParcelOpsStore
  var showTestRun: Bool = true
  var showRunbook: Bool = true
  var showReleaseSnapshot: Bool = true

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if showTestRun {
        SpaceMailTestRunGuide(summary: store.spaceMailMVPReadinessSummary)
      }

      SpaceMailPostRefreshActionCard(plan: store.spaceMailPostRefreshActionPlan)
      SpaceMailShiftHandoffCard(summary: store.spaceMailShiftHandoffSummary)

      DisclosureGroup {
        VStack(alignment: .leading, spacing: 12) {
          if showRunbook {
            SpaceMailOperationsRunbook()
          }
          SpaceMailQACheckCard(summary: store.spaceMailQACheckSummary)
          SpaceMailRefreshTrendCard(summary: store.spaceMailRefreshTrendSummary)
          if showReleaseSnapshot {
            SpaceMailReleaseSnapshotCard(snapshot: store.spaceMailReleaseSnapshot)
          }
        }
        .padding(.top, 10)
      } label: {
        Label("SpaceMail evidence, runbook, and diagnostics", systemImage: "doc.text.magnifyingglass")
          .font(.headline)
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.background, in: RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }
  }
}

struct SpaceMailPrimaryStatusStrip: View {
  var store: ParcelOpsStore
  var title: String = "SpaceMail intake status"
  var showTitle: Bool = true

  private var plan: SpaceMailPostRefreshActionPlan {
    store.spaceMailPostRefreshActionPlan
  }

  private var handoff: SpaceMailShiftHandoffSummary {
    store.spaceMailShiftHandoffSummary
  }

  private var trend: SpaceMailRefreshTrendSummary {
    store.spaceMailRefreshTrendSummary
  }

  private var healthSummaries: [SpaceMailIntakeHealthSummary] {
    store.spaceMailIntakeHealthSummaries
  }

  private var fetchedCount: Int {
    healthSummaries.reduce(0) { $0 + $1.fetchedCount }
  }

  private var importedCount: Int {
    healthSummaries.reduce(0) { $0 + $1.importedCount }
  }

  private var filteredCount: Int {
    healthSummaries.reduce(0) { $0 + $1.filteredCount }
  }

  private var uncertainCount: Int {
    healthSummaries.reduce(0) { $0 + $1.uncertainCount + $1.pendingUncertainReviewCount }
  }

  private var color: Color {
    color(for: plan.tone)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if showTitle {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Label(title, systemImage: "server.rack")
            .font(.headline)
          Spacer()
          Badge(plan.primaryAction, color: color)
        }
      }

      MetricStrip(items: [
        ("Fetched", "\(fetchedCount)", fetchedCount == 0 ? .secondary : .blue),
        ("Imported", "\(importedCount)", importedCount == 0 ? .secondary : .green),
        ("Filtered", "\(filteredCount)", filteredCount == 0 ? .secondary : .teal),
        ("Uncertain", "\(uncertainCount)", uncertainCount == 0 ? .secondary : .orange)
      ])

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], alignment: .leading, spacing: 10) {
        statusTile(
          title: plan.title,
          detail: plan.detail,
          footer: "Next: \(plan.primaryAction)",
          symbol: "arrow.triangle.branch",
          tone: plan.tone
        )

        statusTile(
          title: handoff.title,
          detail: handoff.detail,
          footer: handoff.lastRefreshText,
          symbol: "arrow.left.arrow.right.square.fill",
          tone: handoff.tone
        )

        statusTile(
          title: trend.title,
          detail: trend.detail,
          footer: trend.entries.first.map { "Latest: \($0.status)" } ?? "No refresh history yet",
          symbol: "chart.line.uptrend.xyaxis",
          tone: trend.tone
        )
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.18)))
  }

  private func statusTile(title: String, detail: String, footer: String, symbol: String, tone: String) -> some View {
    let tileColor = color(for: tone)
    return VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Image(systemName: symbol)
          .foregroundStyle(tileColor)
          .frame(width: 18)
        Text(title)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
      }
      Text(detail)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Text(footer)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tileColor)
        .lineLimit(3)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(tileColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private func color(for tone: String) -> Color {
    switch tone {
    case "success":
      return .green
    case "attention":
      return .orange
    case "warning":
      return .red
    default:
      return .secondary
    }
  }
}

struct LocalDataSafetyCard: View {
  var store: ParcelOpsStore
  var compact: Bool = false

  private var localRecordCount: Int {
    store.orders.count
      + store.intakeEmails.count
      + store.importQueueItems.count
      + store.acceptanceRecords.count
      + store.reviewTasks.count
      + store.handoffNotes.count
      + store.shipmentManifestRecords.count
      + store.dispatchReadinessChecklists.count
      + store.auditEvents.count
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "internaldrive.fill")
          .foregroundStyle(.green)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text("Local data safety")
            .font(.headline)
          Text("ParcelOps keeps the MVP usable without a live service by saving operational records as local JSON and keeping sensitive mailbox credentials out of those JSON files.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge("Local", color: .green)
      }

      MetricStrip(items: [
        ("Tracked local records", "\(localRecordCount)", .blue),
        ("Audit events", "\(store.auditEvents.count)", .purple),
        ("Review queue", "\(store.reviewQueueCount)", store.reviewQueueCount == 0 ? .green : .orange),
        ("Open work", "\(store.openWorkbenchItems.count)", store.openWorkbenchItems.isEmpty ? .green : .teal)
      ])

      LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 180 : 220), spacing: 10)], alignment: .leading, spacing: 10) {
        safetyLine(
          title: "Stored in local JSON",
          detail: "Orders, intake rows, import/acceptance records, tasks, handoffs, dispatch records, settings, and audit events.",
          symbol: "doc.text.fill",
          color: .blue
        )
        safetyLine(
          title: "Not stored in JSON",
          detail: "SpaceMail passwords, app passwords, auth strings, access tokens, refresh tokens, client secrets, and raw callback URLs.",
          symbol: "lock.shield.fill",
          color: .green
        )
        safetyLine(
          title: "No mailbox mutation",
          detail: "Real SpaceMail refresh remains manual and read-only. ParcelOps does not delete, move, flag, send, or mark mailbox messages read.",
          symbol: "envelope.badge.shield.half.filled",
          color: .teal
        )
        safetyLine(
          title: "Still disconnected",
          detail: "Shopify, carrier APIs, background sync, notifications, OCR, scanners, calendars, file pickers, and outbound email remain inactive.",
          symbol: "network.slash",
          color: .orange
        )
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background, in: RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }

  private func safetyLine(title: String, detail: String, symbol: String, color: Color) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: symbol)
        .foregroundStyle(color)
        .frame(width: 18)
      VStack(alignment: .leading, spacing: 3) {
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
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct OperatorDailyWorkloadSummary: View {
  var dailyAttentionCount: Int
  var advancedBacklogCount: Int
  var reviewQueueCount: Int
  var titleWhenClear: String = "Primary workflow is clear"
  var titleWhenBusy: String = "Daily operator work needs attention"
  var detailWhenClear: String = "The main Inbox, Orders, Workbench, Dispatch, and Tasks flow has no immediate workload. Advanced records can be reviewed when needed."
  var detailWhenBusy: String = "Start with the primary workflow. The advanced backlog is still available, but it is not the first daily operating queue."

  private var tone: Color {
    dailyAttentionCount == 0 ? .green : .orange
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: dailyAttentionCount == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
          .foregroundStyle(tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(dailyAttentionCount == 0 ? titleWhenClear : titleWhenBusy)
            .font(.headline)
          Text(dailyAttentionCount == 0 ? detailWhenClear : detailWhenBusy)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge(dailyAttentionCount == 0 ? "Clear" : "Action needed", color: tone)
      }

      MetricStrip(items: [
        ("Daily attention", "\(dailyAttentionCount)", tone),
        ("Advanced backlog", "\(advancedBacklogCount)", advancedBacklogCount == 0 ? .green : .secondary),
        ("Total review signals", "\(reviewQueueCount)", reviewQueueCount == 0 ? .green : .orange)
      ])
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(tone.opacity(0.18)))
  }
}

struct MVPWorkflowGuide: View {
  var title: String
  var detail: String
  var steps: [String]
  var symbol: String = "point.3.connected.trianglepath.dotted"

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: symbol)
          .foregroundStyle(.teal)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.headline)
          Text(detail)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 10)], alignment: .leading, spacing: 10) {
        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
          HStack(alignment: .top, spacing: 8) {
            Text("\(index + 1)")
              .font(.caption.weight(.bold))
              .foregroundStyle(.white)
              .frame(width: 20, height: 20)
              .background(.teal)
              .clipShape(Circle())
            Text(step)
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .padding(10)
          .background(.quinary)
          .clipShape(RoundedRectangle(cornerRadius: 8))
        }
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct MVPEmptyState: View {
  var title: String
  var detail: String
  var symbol: String
  var actionTitle: String?
  var action: (() -> Void)?

  init(title: String, detail: String, symbol: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
    self.title = title
    self.detail = detail
    self.symbol = symbol
    self.actionTitle = actionTitle
    self.action = action
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Image(systemName: symbol)
        .font(.title3)
        .foregroundStyle(.teal)
      Text(title)
        .font(.headline)
      Text(detail)
        .font(.callout)
        .foregroundStyle(.secondary)
      if let actionTitle, let action {
        Button(actionTitle, systemImage: "plus", action: action)
          .buttonStyle(.borderedProminent)
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
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

struct IntakeSourceContextPanel: View {
  var email: ForwardedEmailIntake
  var store: ParcelOpsStore
  var manualDetail: String
  var linkedDetailSuffix: String
  var compact: Bool

  init(
    email: ForwardedEmailIntake,
    store: ParcelOpsStore,
    manualDetail: String,
    linkedDetailSuffix: String,
    compact: Bool = false
  ) {
    self.email = email
    self.store = store
    self.manualDetail = manualDetail
    self.linkedDetailSuffix = linkedDetailSuffix
    self.compact = compact
  }

  private var sourceContext: IntakeSourceContext {
    guard let ingestRecord = store.mailboxIngestRecords.first(where: { $0.intakeEmailID == email.id }) else {
      return IntakeSourceContext(
        providerLabel: "Manual/local",
        providerColor: .secondary,
        statusLabel: email.reviewState.rawValue,
        statusColor: email.reviewState.color,
        capturedLabel: email.receivedDate.isEmpty ? "Date unknown" : email.receivedDate,
        detail: manualDetail
      )
    }

    let provider = mailboxProviderContext(for: ingestRecord.sourceMailboxID, providerMessageID: ingestRecord.providerMessageID)
    return IntakeSourceContext(
      providerLabel: provider.label,
      providerColor: provider.color,
      statusLabel: ingestRecord.status.rawValue,
      statusColor: ingestRecord.status == .imported ? .green : .orange,
      capturedLabel: ingestRecord.capturedDate,
      detail: "\(provider.detail) \(linkedDetailSuffix)"
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      CompactMetadataGrid(minimumWidth: 120) {
        Badge(sourceContext.providerLabel, color: sourceContext.providerColor)
        Badge(sourceContext.statusLabel, color: sourceContext.statusColor)
        Badge(sourceContext.capturedLabel, color: .secondary)
      }
      Text(sourceContext.detail)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(compact ? 0 : 8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      if !compact {
        RoundedRectangle(cornerRadius: 8)
          .fill(sourceContext.providerColor.opacity(0.07))
      }
    }
  }

  private func mailboxProviderContext(for sourceMailboxID: UUID, providerMessageID: String) -> (label: String, detail: String, color: Color) {
    if let connection = store.spaceMailIMAPConnections.first(where: { $0.id == sourceMailboxID }) {
      return (
        "SpaceMail IMAP",
        "Captured from \(connection.displayName) using manual read-only IMAP refresh.",
        .teal
      )
    }

    if let connection = store.microsoft365MailboxConnections.first(where: { $0.id == sourceMailboxID }) {
      let isMock = providerMessageID.localizedCaseInsensitiveContains("mock")
      return (
        isMock ? "Mock Graph" : "Microsoft Graph",
        isMock
          ? "Captured from \(connection.displayName) using deterministic mock Graph refresh."
          : "Captured from \(connection.displayName) using manual read-only Microsoft Graph refresh.",
        isMock ? .purple : .blue
      )
    }

    if let mailbox = store.mailboxes.first(where: { $0.id == sourceMailboxID }) {
      return (
        "\(mailbox.provider.rawValue) mailbox",
        "Captured from tracked mailbox \(mailbox.address) through the provider-neutral intake path.",
        .blue
      )
    }

    if providerMessageID.localizedCaseInsensitiveContains("spacemail") {
      return ("SpaceMail intake", "Captured through SpaceMail intake; the source mailbox setup is no longer present locally.", .teal)
    }

    if providerMessageID.localizedCaseInsensitiveContains("mock") || providerMessageID.localizedCaseInsensitiveContains("simulated") {
      return ("Local test mail", "Captured through a local simulated mailbox import.", .purple)
    }

    return ("Mailbox intake", "Captured through the provider-neutral mailbox ingestion path.", .blue)
  }
}

private struct IntakeSourceContext {
  var providerLabel: String
  var providerColor: Color
  var statusLabel: String
  var statusColor: Color
  var capturedLabel: String
  var detail: String
}
