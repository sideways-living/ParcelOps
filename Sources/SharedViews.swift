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
    case .wishlistItem: "star.square.fill"
    case .reconciliationIssue: "arrow.triangle.2.circlepath.circle.fill"
    case .microsoft365MailboxConnection: "mail.stack.fill"
    case .spaceMailIMAPConnection: "server.rack"
    case .gmailMailboxConnection: "envelope.badge.shield.half.filled"
    case .trackedMailbox: "envelope.badge.fill"
    case .shopifyConnection: "cart.badge.plus"
    case .sourceConnection: "key.fill"
    case .watchedFolder: "folder.fill.badge.gearshape"
    case .settings: "gearshape.2.fill"
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
    case .gmailIntake: "envelope.badge.shield.half.filled"
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
    case .mailboxProviderGate: "checkmark.seal.fill"
    case .setupPlaceholder: "gearshape.2.fill"
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
      || source == .gmailIntake
      || source == .exceptionPlaybook
      || source == .tracking
      || prioritySeverity.localizedCaseInsensitiveContains("critical")
  }

  var supportsReviewAction: Bool {
    switch source {
    case .reviewTask, .handoffNote, .intakeEmail, .intakeParser, .spaceMailIntake, .gmailIntake, .reconciliation, .shipmentGroup, .tracking, .evidence, .slaPolicy, .exceptionPlaybook, .draftMessage, .contact, .customerProfile, .destinationAddress, .deliveryInstruction, .packageContent, .costRecord, .returnClaim, .procurementRequest, .receivingInspection, .inventoryReceipt, .storageLocation, .custodyRecord, .labelReference, .scanSession, .shipmentManifest, .dispatchChecklist, .account, .vendorProfile, .mailboxProviderGate, .setupPlaceholder:
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
  var store: ParcelOpsStore? = nil

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
              if let sourceContext = store?.acceptanceSourceContext(for: record) {
                Label(sourceContext.label, systemImage: sourceContext.symbol)
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(.teal)
                Text(sourceContext.detail)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
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
    case .wishlistItem: "star.square.fill"
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
    case .reviewTask, .handoffNote, .slaPolicy, .exceptionPlaybook, .draftMessage, .contact, .customerProfile, .destinationAddress, .deliveryInstruction, .packageContent, .costRecord, .returnClaim, .procurementRequest, .receivingInspection, .inventoryReceipt, .storageLocation, .custodyRecord, .labelReference, .scanSession, .shipmentManifest, .dispatchChecklist, .account, .vendorProfile, .integration, .automationRule, .savedFilter, .auditEvent, .shipmentGroup, .importQueueItem, .acceptanceRecord, .wishlistItem, .reconciliationIssue:
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

struct OrderMailboxSourceTrailPanel: View {
  var summaries: [OrderMailboxSourceSummary]
  var title: String = "Mailbox provider trail"
  var symbol: String = "envelope.badge.shield.half.filled"

  var body: some View {
    if !summaries.isEmpty {
      VStack(alignment: .leading, spacing: 7) {
        Label(title, systemImage: symbol)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.blue)
        CompactMetadataGrid(minimumWidth: 130) {
          ForEach(summaries) { summary in
            Badge(summary.badgeLabel, color: color(for: summary.providerName))
          }
        }
        ForEach(summaries) { summary in
          Text("\(summary.statusLabel): \(summary.detailText)")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(10)
      .background(Color.blue.opacity(0.08))
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
  }

  private func color(for providerName: String) -> Color {
    if providerName.localizedCaseInsensitiveContains("Gmail") { return .blue }
    if providerName.localizedCaseInsensitiveContains("SpaceMail") { return .teal }
    if providerName.localizedCaseInsensitiveContains("Mock") { return .purple }
    if providerName.localizedCaseInsensitiveContains("Microsoft") { return .blue }
    return .secondary
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

struct OperatorMVPReadinessCard: View {
  var store: ParcelOpsStore

  private var checks: [(title: String, detail: String, isComplete: Bool, tone: String, symbol: String)] {
    let hasSpaceMailSetup = !store.spaceMailIMAPConnections.isEmpty
    let hasGmailSetup = !store.gmailMailboxConnections.isEmpty
    let hasSpaceMailCredential = store.spaceMailIMAPConnections.contains {
      $0.credentialStorageStatus.localizedCaseInsensitiveContains("available")
        || $0.credentialStorageStatus.localizedCaseInsensitiveContains("ready")
    }
    let hasGmailConnectedAuth = store.hasGmailConnectedAuth
    let hasMicrosoft365Setup = !store.microsoft365MailboxConnections.isEmpty
    let hasMicrosoft365ConnectedAuth = store.microsoft365MailboxConnections.contains {
      store.microsoft365AuthSessionState(for: $0).status == .connected
    }
    let hasMailboxSetup = store.hasMailboxProviderSetup
    let hasMailboxCredentialOrAuth = store.hasMailboxCredentialOrAuthReadiness
    let hasMailboxRefresh = store.hasMailboxManualRefreshEvidence
    let mailboxProviderLabel: String = {
      let names = [
        hasSpaceMailSetup ? "SpaceMail" : nil,
        hasGmailSetup ? "Gmail" : nil,
        hasMicrosoft365Setup ? "Outlook" : nil
      ].compactMap { $0 }
      return names.isEmpty ? "No mailbox" : names.joined(separator: ", ")
    }()
    let mailboxCredentialDetail: String = {
      let readyNames = [
        hasSpaceMailCredential ? "SpaceMail Keychain credential" : nil,
        hasGmailConnectedAuth ? "Gmail Google sign-in" : nil,
        hasMicrosoft365ConnectedAuth ? "Outlook Microsoft sign-in" : nil
      ].compactMap { $0 }
      if readyNames.count > 1 {
        return "\(readyNames.joined(separator: ", ")) evidence is available."
      }
      if hasSpaceMailCredential {
        return "SpaceMail Keychain credential is available for manual read-only IMAP refresh."
      }
      if hasGmailConnectedAuth {
        return "Gmail Google sign-in evidence is available for manual read-only Gmail refresh."
      }
      if hasMicrosoft365ConnectedAuth {
        return "Outlook Microsoft sign-in evidence is available for manual read-only Graph refresh."
      }
      if hasMicrosoft365Setup && !hasGmailSetup && !hasSpaceMailSetup {
        return "Complete Microsoft sign-in from Mailbox Monitor or Settings before real Outlook refresh."
      }
      if hasGmailSetup || hasMicrosoft365Setup || hasSpaceMailSetup {
        return "Set/check SpaceMail credentials or complete the hosted-provider sign-in from Mailbox Monitor or Settings."
      }
      return "Set up a mailbox provider, then complete the matching credential or sign-in step."
    }()
    let mailboxRefreshDetail: String = {
      let spaceMailRefreshed = store.spaceMailIMAPConnections.contains { $0.lastManualRefreshDate != "Never" }
      let gmailRefreshed = store.gmailMailboxConnections.contains { $0.lastManualRefreshDate != "Never" }
      let outlookRefreshed = store.microsoft365MailboxConnections.contains { $0.lastManualRefreshDate != "Never" }
      let names = [
        spaceMailRefreshed ? "SpaceMail" : nil,
        gmailRefreshed ? "Gmail" : nil,
        outlookRefreshed ? "Outlook" : nil
      ].compactMap { $0 }
      return names.isEmpty ? "Run a manual mailbox refresh when credentials or sign-in are ready." : "\(names.joined(separator: ", ")) manual refresh result evidence exists."
    }()
    let hasInboxEvidence = !store.intakeEmails.isEmpty || !store.importQueueItems.isEmpty || !store.acceptanceRecords.isEmpty
    let hasInboxOrder = store.orders.contains { $0.source == .forwardedMailbox || $0.checkedMailbox == "manual-import" || $0.isInboxCreatedLocalOrder }
    let hasWishlistItems = !store.wishlistItems.isEmpty
    let hasWishlistPurchaseFlow = store.wishlistItems.contains { item in
      item.purchaseDecision != nil
        || item.purchaseHandoff != nil
        || !(item.comparisonOptions ?? []).isEmpty
        || item.status.localizedCaseInsensitiveContains("purchase")
    }
    let hasWishlistOrderHandoff = store.wishlistItems.contains { item in
      guard let linkedOrderID = item.purchaseHandoff?.linkedOrderID else { return false }
      return store.orders.contains { $0.id == linkedOrderID }
    }
    let hasDispatchContext = !store.shipmentManifestRecords.isEmpty && !store.dispatchReadinessChecklists.isEmpty
    let hasOpenWorkRouting = !store.openWorkbenchItems.isEmpty || !store.reviewTasks.isEmpty || !store.handoffNotes.isEmpty
    let hasAuditTrail = store.auditEvents.contains { event in
      [.spaceMailIMAPConnection, .gmailMailboxConnection, .intakeEmail, .order, .reviewTask, .handoffNote, .shipmentManifest, .dispatchChecklist, .wishlistItem].contains(event.entityType)
    }

    return [
      (
        "Mailbox setup",
        hasMailboxSetup
          ? "\(mailboxProviderLabel) configured for manual read-only intake."
          : "Add or review an active mailbox provider before expecting real intake.",
        hasMailboxSetup,
        hasMailboxSetup ? "success" : "warning",
        hasMicrosoft365Setup && !hasSpaceMailSetup && !hasGmailSetup ? "mail.stack.fill" : hasGmailSetup && !hasSpaceMailSetup ? "envelope.badge.shield.half.filled" : "server.rack"
      ),
      (
        "Credential or sign-in",
        mailboxCredentialDetail,
        hasMailboxCredentialOrAuth,
        hasMailboxCredentialOrAuth ? "success" : "attention",
        hasGmailSetup || hasMicrosoft365Setup ? "person.badge.key.fill" : "key.horizontal.fill"
      ),
      (
        "Manual refresh evidence",
        mailboxRefreshDetail,
        hasMailboxRefresh,
        hasMailboxRefresh ? "success" : "attention",
        "arrow.down.to.line.compact"
      ),
      (
        "Inbox evidence",
        hasInboxEvidence ? "Inbox/import/acceptance data exists for local triage." : "Import or seed intake before testing the daily operator queue.",
        hasInboxEvidence,
        hasInboxEvidence ? "success" : "warning",
        "tray.full.fill"
      ),
      (
        "Inbox to Orders handoff",
        hasInboxOrder ? "At least one order has Inbox/import source context." : "Create or link one order from confirmed intake to test the core handoff.",
        hasInboxOrder,
        hasInboxOrder ? "success" : "attention",
        "link.badge.plus"
      ),
      (
        "Wishlist capture",
        hasWishlistItems
          ? "Wishlist has local items available for manual comparison, purchase planning, and order-watch work."
          : "Add one Wishlist item manually before testing the purchase planning path.",
        hasWishlistItems,
        hasWishlistItems ? "success" : "attention",
        "star.square.fill"
      ),
      (
        "Wishlist purchase handoff",
        hasWishlistOrderHandoff
          ? "At least one Wishlist purchase handoff is linked to a local order."
          : hasWishlistPurchaseFlow
            ? "Wishlist purchase planning exists. Link or create an order after a real purchase confirmation arrives."
            : "Run the local Wishlist comparison and purchase handoff steps before expecting order follow-through.",
        hasWishlistPurchaseFlow,
        hasWishlistOrderHandoff ? "success" : hasWishlistPurchaseFlow ? "attention" : "attention",
        "cart.badge.plus"
      ),
      (
        "Dispatch context",
        hasDispatchContext ? "Manifest and readiness records are available for outbound testing." : "Use Dispatch setup after an order is confirmed.",
        hasDispatchContext,
        hasDispatchContext ? "success" : "attention",
        "paperplane.fill"
      ),
      (
        "Work routing",
        hasOpenWorkRouting ? "Workbench, Tasks, or Handoffs have local follow-up routes." : "Create a task or handoff from Inbox/Workbench/Audit when follow-up is needed.",
        hasOpenWorkRouting,
        hasOpenWorkRouting ? "success" : "attention",
        "checklist"
      ),
      (
        "Audit trail",
        hasAuditTrail ? "Audit has workflow evidence for intake, order, task, or dispatch actions." : "Perform one local action and confirm it appears in Audit.",
        hasAuditTrail,
        hasAuditTrail ? "success" : "warning",
        "list.clipboard.fill"
      )
    ]
  }

  private var completeCount: Int {
    checks.filter(\.isComplete).count
  }

  private var incompleteChecks: [(title: String, detail: String, isComplete: Bool, tone: String, symbol: String)] {
    checks.filter { !$0.isComplete }
  }

  private var warningBlockerCount: Int {
    incompleteChecks.filter { $0.tone == "warning" }.count
  }

  private var attentionBlockerCount: Int {
    incompleteChecks.filter { $0.tone == "attention" }.count
  }

  private var tone: String {
    if completeCount == checks.count { return "success" }
    if completeCount >= max(checks.count - 2, 1) { return "attention" }
    return "warning"
  }

  private var color: Color {
    color(for: tone)
  }

  private var title: String {
    if completeCount == checks.count {
      return "Operator MVP is ready for hands-on use"
    }
    if completeCount >= max(checks.count - 2, 1) {
      return "Operator MVP is close to usable"
    }
    return "Operator MVP still needs setup evidence"
  }

  private var nextAction: String {
    checks.first { !$0.isComplete }?.detail ?? "Run a short supervised pass through Dashboard, Inbox, Orders, Workbench, Dispatch, Tasks, Audit, and Settings."
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "gauge.with.dots.needle.67percent")
          .foregroundStyle(color)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.headline)
          Text("A local-only readiness check across the primary operator flow. It uses existing JSON-backed records and audit evidence only.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge("\(completeCount)/\(checks.count)", color: color)
      }

      Text("Next: \(nextAction)")
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .fixedSize(horizontal: false, vertical: true)

      MetricStrip(items: [
        ("Complete", "\(completeCount)", completeCount == checks.count ? .green : .teal),
        ("Remaining", "\(incompleteChecks.count)", incompleteChecks.isEmpty ? .green : .orange),
        ("Blockers", "\(warningBlockerCount)", warningBlockerCount == 0 ? .green : .red),
        ("Follow-up", "\(attentionBlockerCount)", attentionBlockerCount == 0 ? .green : .orange)
      ])

      if !incompleteChecks.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Label("Top readiness blockers", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(warningBlockerCount > 0 ? .red : .orange)

          ForEach(Array(incompleteChecks.prefix(3)), id: \.title) { check in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: check.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color(for: check.tone))
                .frame(width: 18)
              VStack(alignment: .leading, spacing: 2) {
                Text(check.title)
                  .font(.caption.weight(.semibold))
                Text(check.detail)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
          }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((warningBlockerCount > 0 ? Color.red : Color.orange).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 10)], alignment: .leading, spacing: 10) {
        ForEach(checks, id: \.title) { check in
          VStack(alignment: .leading, spacing: 6) {
            Label(check.title, systemImage: check.isComplete ? "checkmark.circle.fill" : check.symbol)
              .font(.caption.weight(.semibold))
              .foregroundStyle(color(for: check.tone))
              .lineLimit(2)
            Text(check.detail)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background(color(for: check.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }

      Text("Boundaries: this card does not run IMAP, read Keychain credentials, mutate mailbox messages, call Shopify/carrier APIs, start background jobs, or send notifications.")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
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
    return [
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
  var store: ParcelOpsStore?
  var usesMailboxReleaseTask = false
  @State private var feedbackMessage: String?

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

      if let store {
        CompactActionRow {
          Button(usesMailboxReleaseTask ? "Create mailbox release follow-up" : "Create release follow-up", systemImage: "checklist") {
            if usesMailboxReleaseTask {
              store.createReviewTaskFromMailboxReleaseReadinessSnapshot()
              feedbackMessage = "Mailbox release readiness follow-up task created. Check Tasks."
            } else {
              store.createReviewTaskFromSpaceMailReleaseSnapshot()
              feedbackMessage = "Release snapshot follow-up task created. Check Tasks."
            }
          }
          .buttonStyle(.bordered)

          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
          .buttonStyle(.bordered)

          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Open Audit", systemImage: "list.clipboard.fill")
          }
          .buttonStyle(.bordered)
        }
      }

      if let feedbackMessage {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
          VStack(alignment: .leading, spacing: 4) {
            Text(feedbackMessage)
              .font(.caption.weight(.semibold))
              .foregroundStyle(.green)
            Text("The report text was copied into a local JSON-backed task. No file export or external service ran.")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
      }

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

struct GmailReleaseSelfCheckSummaryCard: View {
  var summary: GmailReleaseSelfCheckSummary
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var color: Color {
    color(for: summary.tone)
  }

  private var visibleItems: [GmailReleaseSelfCheckItem] {
    let blockers = summary.items.filter { !$0.isComplete }
    return Array((blockers.isEmpty ? summary.items : blockers).prefix(horizontalSizeClass == .compact ? 3 : 4))
  }

  private var providerFitItem: GmailReleaseSelfCheckItem? {
    summary.items.first { $0.title == "Provider fit" }
  }

  private var providerFitNeedsReview: Bool {
    providerFitItem.map { !$0.isComplete } ?? false
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: summary.tone == "success" ? "checkmark.seal.fill" : "exclamationmark.shield.fill")
          .foregroundStyle(color)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(summary.verdict)
            .font(.headline)
          Text(summary.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Text(summary.nextAction)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge("\(summary.completedCount)/\(summary.totalCount)", color: color)
      }

      MetricStrip(items: [
        ("Checks", "\(summary.completedCount)/\(summary.totalCount)", color),
        ("Provider fit", providerFitNeedsReview ? "Review" : "OK", providerFitNeedsReview ? .teal : .green),
        ("Blocking", "\(summary.items.filter { !$0.isComplete && $0.tone == "warning" }.count)", summary.items.contains { !$0.isComplete && $0.tone == "warning" } ? .red : .green),
        ("Attention", "\(summary.items.filter { !$0.isComplete && $0.tone == "attention" }.count)", summary.items.contains { !$0.isComplete && $0.tone == "attention" } ? .orange : .green)
      ])

      if let providerFitItem, providerFitNeedsReview {
        VStack(alignment: .leading, spacing: 4) {
          Label("Confirm Gmail provider fit", systemImage: providerFitItem.symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.teal)
          Text(providerFitItem.detail)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Text(providerFitItem.nextAction)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.teal)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }

      if !visibleItems.isEmpty {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 190 : 220), spacing: 8)], alignment: .leading, spacing: 8) {
          ForEach(visibleItems) { item in
            VStack(alignment: .leading, spacing: 5) {
              Label(item.title, systemImage: item.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color(for: item.tone))
              Text(item.nextAction)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(color(for: item.tone).opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
          }
        }
      }

      Text("This card is computed from local setup, sign-in, refresh, classifier, Inbox handoff, and Audit state. It does not open Google sign-in, fetch Gmail, store token values, or mutate mailbox messages.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
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

struct GmailReleaseBoundaryPanel: View {
  var store: ParcelOpsStore
  var title: String
  var lead: String
  var sourceMetricTitle: String
  var sourceCount: Int
  var boundaryDetail: String
  var showTasksLink: Bool = true

  private var summaries: [GmailReleaseSelfCheckSummary] {
    store.gmailMailboxConnections.map { store.gmailReleaseSelfCheckSummary(for: $0) }
  }

  private var blockingCount: Int {
    summaries.reduce(0) { total, summary in
      total + summary.items.filter { !$0.isComplete && $0.tone == "warning" }.count
    }
  }

  private var attentionCount: Int {
    summaries.reduce(0) { total, summary in
      total + summary.items.filter { !$0.isComplete && $0.tone == "attention" }.count
    }
  }

  private var firstActionConnection: GmailMailboxConnection? {
    guard let summary = summaries.first(where: { $0.items.contains { !$0.isComplete } }),
          let connection = store.gmailMailboxConnections.first(where: { $0.id == summary.connectionID })
    else {
      return store.gmailMailboxConnections.first
    }
    return connection
  }

  private var topReleaseBlocker: MailboxReleaseBlockerItem? {
    store.gmailReleaseBlockerSummary.blockers.first { $0.tone == "warning" || $0.tone == "attention" }
  }

  private var color: Color {
    if blockingCount > 0 { return .red }
    if attentionCount > 0 { return .orange }
    return .green
  }

  var body: some View {
    if !summaries.isEmpty {
      SettingsPanel(title: title, symbol: "envelope.badge.shield.half.filled") {
        VStack(alignment: .leading, spacing: 10) {
          Label("Gmail provider readiness boundary", systemImage: blockingCount > 0 ? "exclamationmark.shield.fill" : "checkmark.seal.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
          Text(lead)
            .font(.caption)
            .foregroundStyle(.secondary)

          MetricStrip(items: [
            ("Release blockers", "\(blockingCount)", blockingCount == 0 ? .green : .red),
            ("Needs attention", "\(attentionCount)", attentionCount == 0 ? .green : .orange),
            (sourceMetricTitle, "\(sourceCount)", sourceCount == 0 ? .secondary : .blue),
            ("Connections", "\(summaries.count)", .teal)
          ])

          ForEach(summaries.prefix(2)) { summary in
            GmailReleaseSelfCheckSummaryCard(summary: summary)
          }

          if let topReleaseBlocker {
            MailboxTopReleaseBlockerCallout(blocker: topReleaseBlocker)
          }

          if blockingCount > 0 || attentionCount > 0 {
            CompactActionRow {
              if let connection = firstActionConnection {
                Button("Create Gmail release task", systemImage: "checkmark.seal.fill") {
                  store.createReviewTaskFromGmailReleaseSelfCheck(connection)
                }
                .buttonStyle(.bordered)
              }
              NavigationLink {
                MailboxView(store: store)
              } label: {
                Label("Open Mailbox Monitor", systemImage: "tray.and.arrow.down.fill")
              }
              .buttonStyle(.bordered)
              if showTasksLink {
                NavigationLink {
                  TasksView(store: store)
                } label: {
                  Label("Open Tasks", systemImage: "checklist")
                }
                .buttonStyle(.bordered)
              }
            }
          } else {
            Label("Gmail release checks do not currently block this local follow-up area.", systemImage: "checkmark.seal.fill")
              .font(.caption)
              .foregroundStyle(.green)
          }

          Text(boundaryDetail)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }
    }
  }
}

struct Microsoft365ReleaseSelfCheckCard: View {
  var summary: Microsoft365ReleaseSelfCheckSummary
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var blockingCount: Int {
    summary.items.filter { !$0.isComplete && $0.tone == "warning" }.count
  }

  private var attentionCount: Int {
    summary.items.filter { !$0.isComplete && $0.tone == "attention" }.count
  }

  private var color: Color {
    if blockingCount > 0 { return .red }
    if attentionCount > 0 || summary.graphBlockerCount > 0 { return .orange }
    return color(for: summary.tone)
  }

  private var visibleRows: [Microsoft365ReleaseSelfCheckItem] {
    let blockers = summary.items.filter { !$0.isComplete }
    return Array((blockers.isEmpty ? summary.items : blockers).prefix(horizontalSizeClass == .compact ? 3 : 4))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: blockingCount > 0 ? "exclamationmark.shield.fill" : "checkmark.seal.fill")
          .foregroundStyle(color)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(summary.verdict)
            .font(.headline)
          Text(summary.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Text(summary.nextAction)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge("\(summary.completedCount)/\(summary.totalCount)", color: color)
      }

      MetricStrip(items: [
        ("Checks", "\(summary.completedCount)/\(summary.totalCount)", color),
        ("Blocking", "\(blockingCount)", blockingCount == 0 ? .green : .red),
        ("Attention", "\(attentionCount)", attentionCount == 0 ? .green : .orange),
        ("Graph blockers", "\(summary.graphBlockerCount)", summary.graphBlockerCount == 0 ? .green : .orange)
      ])

      LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 190 : 220), spacing: 8)], alignment: .leading, spacing: 8) {
        ForEach(visibleRows) { row in
          VStack(alignment: .leading, spacing: 5) {
            Label(row.title, systemImage: row.symbolName)
              .font(.caption.weight(.semibold))
              .foregroundStyle(color(for: row.tone))
            Text(row.nextAction)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .lineLimit(3)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(8)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background(color(for: row.tone).opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        }
      }

      Text("This card is computed from local Microsoft setup, MSAL status, OAuth planning, read-only Graph refresh summaries, Inbox handoff, and Audit state. It does not open Microsoft sign-in, fetch Outlook messages, store token values, or mutate mailbox messages.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
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

struct Microsoft365ReleaseBoundaryPanel: View {
  var store: ParcelOpsStore
  var title: String
  var lead: String
  var sourceMetricTitle: String
  var sourceCount: Int
  var boundaryDetail: String
  var showTasksLink: Bool = true

  private var summaries: [Microsoft365ReleaseSelfCheckSummary] {
    store.microsoft365MailboxConnections.map { store.microsoft365ReleaseSelfCheckSummary(for: $0) }
  }

  private var blockingCount: Int {
    summaries.reduce(0) { total, summary in
      total + summary.items.filter { !$0.isComplete && $0.tone == "warning" }.count
    }
  }

  private var attentionCount: Int {
    summaries.reduce(0) { total, summary in
      total + summary.items.filter { !$0.isComplete && $0.tone == "attention" }.count
    }
  }

  private var graphBlockerCount: Int {
    summaries.reduce(0) { $0 + $1.graphBlockerCount }
  }

  private var firstActionConnection: Microsoft365MailboxConnection? {
    guard let summary = summaries.first(where: { $0.items.contains { !$0.isComplete } }),
          let connection = store.microsoft365MailboxConnections.first(where: { $0.id == summary.connectionID })
    else {
      return store.microsoft365MailboxConnections.first
    }
    return connection
  }

  private var color: Color {
    if blockingCount > 0 { return .red }
    if attentionCount > 0 || graphBlockerCount > 0 { return .orange }
    return .green
  }

  var body: some View {
    if !summaries.isEmpty {
      SettingsPanel(title: title, symbol: "mail.stack.fill") {
        VStack(alignment: .leading, spacing: 10) {
          Label("Outlook provider readiness boundary", systemImage: blockingCount > 0 ? "exclamationmark.shield.fill" : "checkmark.seal.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
          Text(lead)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          MetricStrip(items: [
            ("Release blockers", "\(blockingCount)", blockingCount == 0 ? .green : .red),
            ("Needs attention", "\(attentionCount)", attentionCount == 0 ? .green : .orange),
            ("Graph blockers", "\(graphBlockerCount)", graphBlockerCount == 0 ? .green : .orange),
            (sourceMetricTitle, "\(sourceCount)", sourceCount == 0 ? .secondary : .blue),
            ("Connections", "\(summaries.count)", .purple)
          ])

          ForEach(summaries.prefix(2)) { summary in
            Microsoft365ReleaseSelfCheckCard(summary: summary)
          }

          if blockingCount > 0 || attentionCount > 0 || graphBlockerCount > 0 {
            CompactActionRow {
              if let connection = firstActionConnection {
                Button("Create Outlook release task", systemImage: "checkmark.seal.fill") {
                  store.createReviewTaskFromMicrosoft365ReleaseSelfCheck(connection)
                }
                .buttonStyle(.bordered)
              }
              NavigationLink {
                MailboxView(store: store)
              } label: {
                Label("Open Mailbox Monitor", systemImage: "tray.and.arrow.down.fill")
              }
              .buttonStyle(.bordered)
              if showTasksLink {
                NavigationLink {
                  TasksView(store: store)
                } label: {
                  Label("Open Tasks", systemImage: "checklist")
                }
                .buttonStyle(.bordered)
              }
            }
          } else {
            Label("Outlook release checks do not currently block this local follow-up area.", systemImage: "checkmark.seal.fill")
              .font(.caption)
              .foregroundStyle(.green)
          }

          Text(boundaryDetail)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }
    }
  }
}

struct MailboxReleaseBlockerCard: View {
  var summary: MailboxReleaseBlockerSummary
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var color: Color {
    color(for: summary.tone)
  }

  private var columns: [GridItem] {
    [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 210 : 260), spacing: 10)]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: summary.tone == "success" ? "checkmark.seal.fill" : "exclamationmark.octagon.fill")
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
        Badge(summary.tone == "success" ? "Clear" : "Review", color: color)
      }

      MetricStrip(items: summary.metrics.map { metric in
        (metric.title, metric.value, color(for: metric.tone))
      })

      if summary.blockers.isEmpty {
        Label("No mailbox release blockers are currently promoted from provider QA, intake quality, or handoff checks.", systemImage: "checkmark.circle.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.green)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
          ForEach(summary.blockers) { blocker in
            VStack(alignment: .leading, spacing: 8) {
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: blocker.symbol)
                  .foregroundStyle(color(for: blocker.tone))
                  .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                  Text(blocker.title)
                    .font(.caption.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                  Text(blocker.source)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color(for: blocker.tone))
                }
              }

              Text(blocker.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

              Label(blocker.nextAction, systemImage: "arrow.forward.circle.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color(for: blocker.tone))
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(color(for: blocker.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }
      }

      Text("This queue is computed from existing local provider, intake, and handoff checks. It does not fetch mail, mutate mailboxes, or contact external services.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
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

struct MailboxTopReleaseBlockerCallout: View {
  var blocker: MailboxReleaseBlockerItem

  private var color: Color {
    switch blocker.tone {
    case "warning":
      return .red
    case "attention":
      return .orange
    case "success":
      return .green
    default:
      return .secondary
    }
  }

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: blocker.symbol)
        .foregroundStyle(color)
        .frame(width: 22)
      VStack(alignment: .leading, spacing: 4) {
        Text(blocker.title)
          .font(.caption.weight(.semibold))
        Text(blocker.detail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        Label(blocker.nextAction, systemImage: "arrow.forward.circle.fill")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(color)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct MailboxRunTimelineCard: View {
  var summary: MailboxRunTimelineSummary
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var color: Color {
    color(for: summary.tone)
  }

  private var columns: [GridItem] {
    [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 220 : 280), spacing: 10)]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "clock.arrow.circlepath")
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
        Badge("Runs", color: color)
      }

      MetricStrip(items: summary.metrics.map { metric in
        (metric.title, metric.value, color(for: metric.tone))
      })

      if summary.entries.isEmpty {
        Label("No refresh timeline exists yet. Run a manual mailbox refresh to create local evidence.", systemImage: "clock.badge.questionmark")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
          ForEach(summary.entries) { entry in
            VStack(alignment: .leading, spacing: 7) {
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: entry.symbol)
                  .foregroundStyle(color(for: entry.tone))
                  .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                  Text(entry.title)
                    .font(.caption.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                  Text("\(entry.provider) • \(entry.timestamp)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color(for: entry.tone))
                    .fixedSize(horizontal: false, vertical: true)
                }
              }

              Text(entry.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

              Badge(entry.outcome, color: color(for: entry.tone))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(color(for: entry.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }
      }

      Text("Timeline entries are derived from local refresh history and safe audit summaries. They do not include passwords, tokens, auth strings, or full message bodies.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
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

struct MailboxReleaseTestPlanCard: View {
  var summary: MailboxReleaseTestPlanSummary
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var color: Color {
    color(for: summary.tone)
  }

  private var columns: [GridItem] {
    [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 220 : 280), spacing: 10)]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "checkmark.rectangle.stack.fill")
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
        Badge("Test plan", color: color)
      }

      MetricStrip(items: summary.metrics.map { metric in
        (metric.title, metric.value, color(for: metric.tone))
      })

      LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
        ForEach(summary.steps) { step in
          VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: step.isComplete ? "checkmark.circle.fill" : step.symbol)
                .foregroundStyle(color(for: step.tone))
                .frame(width: 22)
              VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                  .font(.caption.weight(.semibold))
                  .fixedSize(horizontal: false, vertical: true)
                Text(step.isComplete ? "Evidence present" : "Needs action")
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(color(for: step.tone))
              }
            }

            Text(step.detail)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)

            Text(step.evidence)
              .font(.caption2.weight(.semibold))
              .foregroundStyle(color(for: step.tone))
              .fixedSize(horizontal: false, vertical: true)

            Label(step.nextAction, systemImage: "arrow.forward.circle.fill")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(color(for: step.tone))
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background(color(for: step.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }

      Text("This test plan reads existing local mailbox, Inbox, order, task, and Audit state. It does not run mailbox refresh, change credentials, mutate mailbox messages, call external services, or create background jobs.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
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

struct MailboxOperatorDecisionCard: View {
  var summary: MailboxOperatorDecisionSummary
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var color: Color {
    color(for: summary.tone)
  }

  private var columns: [GridItem] {
    [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 210 : 250), spacing: 10)]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "arrowshape.turn.up.right.circle.fill")
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
        Badge("Next", color: color)
      }

      Label(summary.primaryAction, systemImage: "arrow.forward.circle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .fixedSize(horizontal: false, vertical: true)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

      MetricStrip(items: summary.metrics.map { metric in
        (metric.title, metric.value, color(for: metric.tone))
      })

      LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
        ForEach(summary.decisions) { decision in
          HStack(alignment: .top, spacing: 8) {
            Image(systemName: decision.isActive ? decision.symbol : "checkmark.circle.fill")
              .foregroundStyle(color(for: decision.tone))
              .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
              Text(decision.title)
                .font(.caption.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
              Text(decision.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
              if decision.isActive {
                Text(decision.action)
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(color(for: decision.tone))
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background(color(for: decision.tone).opacity(decision.isActive ? 0.1 : 0.05), in: RoundedRectangle(cornerRadius: 8))
        }
      }

      Text("This decision summary is computed from local provider, Inbox, order, task, release blocker, and audit state. It does not run refreshes or mutate mailbox data.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
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

struct MailboxProviderTestQueueCard: View {
  var summary: MailboxProviderTestQueueSummary
  var store: ParcelOpsStore?
  var showMailboxLink: Bool = true
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var feedbackMessage: String?

  private var color: Color {
    color(for: summary.tone)
  }

  private var columns: [GridItem] {
    [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 220 : 300), spacing: 10)]
  }

  private var visibleItems: [MailboxProviderTestQueueItem] {
    Array(summary.items.prefix(horizontalSizeClass == .compact ? 5 : 8))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "checklist.checked")
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
        Badge(summary.currentProvider, color: color)
      }

      MetricStrip(items: summary.metrics.map { metric in
        (metric.title, metric.value, color(for: metric.tone))
      })

      if let store {
        CompactActionRow {
          Button("Create queue follow-up", systemImage: "checklist") {
            store.createReviewTaskFromMailboxProviderTestQueue()
            feedbackMessage = "Mailbox provider queue follow-up task created. Check Tasks."
          }
          .buttonStyle(.bordered)

          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
          .buttonStyle(.bordered)

          if showMailboxLink {
            NavigationLink {
              MailboxView(store: store)
            } label: {
              Label("Mailbox Monitor", systemImage: "server.rack")
            }
            .buttonStyle(.bordered)
          }

          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Inbox", systemImage: "tray.full.fill")
          }
          .buttonStyle(.bordered)

          NavigationLink {
            SettingsView(store: store)
          } label: {
            Label("Settings", systemImage: "gearshape.fill")
          }
          .buttonStyle(.bordered)
        }
      }

      if let feedbackMessage {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
          Text(feedbackMessage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.green)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }

      LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
        ForEach(visibleItems) { item in
          VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: item.isComplete ? "checkmark.circle.fill" : item.symbol)
                .foregroundStyle(color(for: item.tone))
                .frame(width: 22)
              VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                  .font(.caption.weight(.semibold))
                  .fixedSize(horizontal: false, vertical: true)
                Text("\(item.providerName) • \(item.phase)")
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(color(for: item.tone))
              }
              Spacer()
            }

            Text(item.detail)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)

            Label(item.nextAction, systemImage: "arrow.forward.circle.fill")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(color(for: item.tone))
              .fixedSize(horizontal: false, vertical: true)

            Text(item.evidence)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background(color(for: item.tone).opacity(item.isComplete ? 0.05 : 0.1), in: RoundedRectangle(cornerRadius: 8))
        }
      }

      if summary.items.count > visibleItems.count {
        Text("\(summary.items.count - visibleItems.count) additional completed or lower-priority provider check\(summary.items.count - visibleItems.count == 1 ? "" : "s") hidden from this compact view.")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      Text("This queue is computed from local setup, credential, sign-in, refresh, Inbox, parser, and order-handoff state. It does not connect to providers or mutate mailbox data.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
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

struct MailboxProviderHandoffPacketCard: View {
  var packet: MailboxProviderHandoffPacketSummary
  var store: ParcelOpsStore?
  var showTasksLink: Bool = true
  var showAuditLink: Bool = true
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var feedbackMessage: String?

  private var color: Color {
    color(for: packet.tone)
  }

  private var columns: [GridItem] {
    [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 220 : 300), spacing: 10)]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "doc.text.fill")
          .foregroundStyle(color)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(packet.title)
            .font(.headline)
          Text(packet.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Text("Generated \(packet.generatedDate)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
        }
        Spacer()
        Badge("Handoff", color: color)
      }

      MetricStrip(items: packet.metrics.map { metric in
        (metric.title, metric.value, color(for: metric.tone))
      })

      if let store {
        CompactActionRow {
          Button("Create handoff note", systemImage: "arrow.left.arrow.right.square.fill") {
            store.createHandoffNoteFromMailboxProviderHandoffPacket()
            feedbackMessage = "Mailbox provider handoff note created or refreshed. Check Handoff Notes."
          }
          .buttonStyle(.bordered)

          Button("Create handoff task", systemImage: "checklist") {
            store.createReviewTaskFromMailboxProviderHandoffPacket()
            feedbackMessage = "Mailbox provider handoff task created. Check Tasks."
          }
          .buttonStyle(.bordered)

          NavigationLink {
            HandoffNotesView(store: store)
          } label: {
            Label("Handoff Notes", systemImage: "arrow.left.arrow.right.square.fill")
          }
          .buttonStyle(.bordered)

          if showTasksLink {
            NavigationLink {
              TasksView(store: store)
            } label: {
              Label("Open Tasks", systemImage: "checklist")
            }
            .buttonStyle(.bordered)
          }

          if showAuditLink {
            NavigationLink {
              AuditView(store: store)
            } label: {
              Label("Open Audit", systemImage: "list.clipboard.fill")
            }
            .buttonStyle(.bordered)
          }
        }
      }

      if let feedbackMessage {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
          Text(feedbackMessage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.green)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }

      LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
        ForEach(packet.sections) { section in
          VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: section.symbol)
                .foregroundStyle(color(for: section.tone))
                .frame(width: 22)
              VStack(alignment: .leading, spacing: 3) {
                Text(section.title)
                  .font(.caption.weight(.semibold))
                Text(section.detail)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }

            VStack(alignment: .leading, spacing: 4) {
              ForEach(Array(section.lines.prefix(4).enumerated()), id: \.offset) { _, line in
                Text(line)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background(color(for: section.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }

      Text("This packet is generated from local JSON-backed state only. It does not refresh mailboxes, read credentials, send messages, call external services, or modify mailbox messages.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
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

struct MailboxProviderTroubleshootingCard: View {
  var summary: MailboxProviderTroubleshootingSummary
  var store: ParcelOpsStore?
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var feedbackMessage: String?

  private var color: Color {
    color(for: summary.tone)
  }

  private var columns: [GridItem] {
    [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 220 : 300), spacing: 10)]
  }

  private var visibleIssues: [MailboxProviderTroubleshootingIssue] {
    Array(summary.issues.prefix(horizontalSizeClass == .compact ? 4 : 6))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "stethoscope")
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
        Badge("Diagnostics", color: color)
      }

      MetricStrip(items: summary.metrics.map { metric in
        (metric.title, metric.value, color(for: metric.tone))
      })

      if let store {
        CompactActionRow {
          Button("Create diagnostic task", systemImage: "checklist") {
            store.createReviewTaskFromMailboxProviderTroubleshooting()
            feedbackMessage = "Mailbox provider diagnostic task created. Check Tasks."
          }
          .buttonStyle(.bordered)

          Button("Draft diagnostic packet", systemImage: "envelope.badge") {
            store.createDraftMessageFromMailboxProviderTroubleshooting()
            feedbackMessage = "Mailbox provider diagnostic draft created. Check Drafts."
          }
          .buttonStyle(.bordered)

          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
          .buttonStyle(.bordered)

          NavigationLink {
            CommunicationView(store: store)
          } label: {
            Label("Open Drafts", systemImage: "envelope.open.fill")
          }
          .buttonStyle(.bordered)
        }
      }

      if let feedbackMessage {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
          Text(feedbackMessage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.green)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }

      if visibleIssues.isEmpty {
        Label("No mailbox provider diagnostics are currently promoted.", systemImage: "checkmark.circle.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.green)
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      } else {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
          ForEach(visibleIssues) { issue in
            VStack(alignment: .leading, spacing: 8) {
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: issue.symbol)
                  .foregroundStyle(color(for: issue.tone))
                  .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                  Text(issue.title)
                    .font(.caption.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                  Text(issue.providerName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color(for: issue.tone))
                }
              }

              Text("Symptom: \(issue.symptom)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
              Text("Likely cause: \(issue.likelyCause)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
              Label(issue.nextAction, systemImage: "arrow.forward.circle.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color(for: issue.tone))
                .fixedSize(horizontal: false, vertical: true)
              Text(issue.evidence)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(color(for: issue.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }
      }

      if summary.issues.count > visibleIssues.count {
        Text("\(summary.issues.count - visibleIssues.count) additional diagnostic\(summary.issues.count - visibleIssues.count == 1 ? "" : "s") hidden from this compact view.")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      Text("Diagnostics are computed from local setup, auth/session status, refresh summaries, classifier results, parser diagnostics, Inbox state, and release blockers. They do not refresh mailboxes or read credentials.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
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

struct MailboxProviderAdvancedDiagnosticsDisclosure: View {
  var store: ParcelOpsStore
  var title: String = "Provider diagnostics"
  var detail: String = "Open this when you need release gates, handoff evidence, or troubleshooting detail. The daily queue only needs the quick status above."
  var showReleaseGate: Bool = true
  var showHandoffPacket: Bool = true
  var showTroubleshooting: Bool = true
  var showMailboxLink: Bool = true
  var showTasksLink: Bool = true
  var showAuditLink: Bool = true
  @State private var isExpanded = false

  private var collapsedStatus: String {
    if showReleaseGate {
      return store.mailboxProviderReleaseGateSummary.verdict
    }
    if showHandoffPacket {
      return store.mailboxProviderHandoffPacketSummary.title
    }
    if showTroubleshooting {
      return store.mailboxProviderTroubleshootingSummary.title
    }
    return "Details"
  }

  private var collapsedTone: Color {
    if showReleaseGate {
      return color(for: store.mailboxProviderReleaseGateSummary.tone)
    }
    if showHandoffPacket {
      return color(for: store.mailboxProviderHandoffPacketSummary.tone)
    }
    if showTroubleshooting {
      return color(for: store.mailboxProviderTroubleshootingSummary.tone)
    }
    return .secondary
  }

  var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
      VStack(alignment: .leading, spacing: 12) {
        if showReleaseGate {
          MailboxProviderReleaseGateCard(
            summary: store.mailboxProviderReleaseGateSummary,
            store: store,
            showMailboxLink: showMailboxLink,
            showTasksLink: showTasksLink,
            showAuditLink: showAuditLink
          )
        }
        if showHandoffPacket {
          MailboxProviderHandoffPacketCard(
            packet: store.mailboxProviderHandoffPacketSummary,
            store: store,
            showTasksLink: showTasksLink,
            showAuditLink: showAuditLink
          )
        }
        if showTroubleshooting {
          MailboxProviderTroubleshootingCard(summary: store.mailboxProviderTroubleshootingSummary, store: store)
        }
      }
      .padding(.top, 10)
    } label: {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
          .foregroundStyle(.secondary)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.headline)
          Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Badge(collapsedStatus, color: collapsedTone)
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
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

struct MailboxProviderReleaseGateCard: View {
  var summary: MailboxProviderReleaseGateSummary
  var store: ParcelOpsStore?
  var showMailboxLink: Bool = true
  var showTasksLink: Bool = true
  var showAuditLink: Bool = true
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var feedbackMessage: String?

  private var color: Color {
    color(for: summary.tone)
  }

  private var columns: [GridItem] {
    [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 220 : 300), spacing: 10)]
  }

  private var visibleGates: [MailboxProviderReleaseGateItem] {
    Array(prioritizedGates.prefix(horizontalSizeClass == .compact ? 5 : 8))
  }

  private var prioritizedGates: [MailboxProviderReleaseGateItem] {
    summary.gates.sorted { left, right in
      let leftRank = gatePriority(left)
      let rightRank = gatePriority(right)
      if leftRank != rightRank { return leftRank < rightRank }
      return left.title < right.title
    }
  }

  private var primaryOpenGate: MailboxProviderReleaseGateItem? {
    prioritizedGates.first { !$0.isPassed }
  }

  private func gatePriority(_ gate: MailboxProviderReleaseGateItem) -> Int {
    if !gate.isPassed && gate.tone == "warning" { return 0 }
    if !gate.isPassed && gate.tone == "attention" { return 1 }
    if !gate.isPassed { return 2 }
    if gate.tone == "attention" { return 3 }
    return 4
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "checkmark.seal.fill")
          .foregroundStyle(color)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(summary.title)
            .font(.headline)
          Text(summary.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Text("Generated \(summary.generatedDate)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
        }
        Spacer()
        Badge(summary.verdict, color: color)
      }

      MetricStrip(items: summary.metrics.map { metric in
        (metric.title, metric.value, color(for: metric.tone))
      })

      if let store {
        CompactActionRow {
          Button("Create gate task", systemImage: "checklist") {
            store.createReviewTaskFromMailboxProviderReleaseGate()
            feedbackMessage = "Mailbox provider release gate task created. Check Tasks."
          }
          .buttonStyle(.bordered)

          if showMailboxLink {
            NavigationLink {
              MailboxView(store: store)
            } label: {
              Label("Mailbox Monitor", systemImage: "server.rack")
            }
            .buttonStyle(.bordered)
          }

          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Inbox", systemImage: "tray.full.fill")
          }
          .buttonStyle(.bordered)

          NavigationLink {
            OperationsWorkbenchView(store: store)
          } label: {
            Label("Workbench", systemImage: "rectangle.stack.badge.person.crop.fill")
          }
          .buttonStyle(.bordered)

          NavigationLink {
            SettingsView(store: store)
          } label: {
            Label("Settings", systemImage: "gearshape.2.fill")
          }
          .buttonStyle(.bordered)

          if showTasksLink {
            NavigationLink {
              TasksView(store: store)
            } label: {
              Label("Open Tasks", systemImage: "checklist")
            }
            .buttonStyle(.bordered)
          }

          if showAuditLink {
            NavigationLink {
              AuditView(store: store)
            } label: {
              Label("Open Audit", systemImage: "list.clipboard.fill")
            }
            .buttonStyle(.bordered)
          }
        }
      }

      if let feedbackMessage {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
          Text(feedbackMessage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.green)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }

      if let primaryOpenGate {
        VStack(alignment: .leading, spacing: 6) {
          Label("Primary open gate", systemImage: primaryOpenGate.symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color(for: primaryOpenGate.tone))
          Text(primaryOpenGate.title)
            .font(.subheadline.weight(.semibold))
          Text(primaryOpenGate.nextAction)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color(for: primaryOpenGate.tone).opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
      }

      LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
        ForEach(visibleGates) { gate in
          VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: gate.isPassed ? "checkmark.circle.fill" : gate.symbol)
                .foregroundStyle(color(for: gate.tone))
                .frame(width: 22)
              VStack(alignment: .leading, spacing: 3) {
                Text(gate.title)
                  .font(.caption.weight(.semibold))
                  .fixedSize(horizontal: false, vertical: true)
                Text(gate.isPassed ? "Pass" : "Open")
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(color(for: gate.tone))
              }
            }

            Text("Requirement: \(gate.requirement)")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            Text("Evidence: \(gate.evidence)")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            if !gate.isPassed {
              Label(gate.nextAction, systemImage: "arrow.forward.circle.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color(for: gate.tone))
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background(color(for: gate.tone).opacity(gate.isPassed ? 0.05 : 0.1), in: RoundedRectangle(cornerRadius: 8))
        }
      }

      if summary.gates.count > visibleGates.count {
        Text("\(summary.gates.count - visibleGates.count) additional gate\(summary.gates.count - visibleGates.count == 1 ? "" : "s") hidden from this compact view.")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Label("Selectable gate handoff", systemImage: "doc.text.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
          Spacer()
          Badge(summary.verdict, color: color)
        }

        Text("Use this local report when handing off provider readiness, release blockers, Inbox/order evidence, and next actions. It is generated from persisted local state only.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        Text(summary.reportText)
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }

      Text("This release gate is computed from local JSON-backed provider, Inbox, task, audit, and release state. It does not run refreshes, read credentials, call external services, or mutate mailbox data.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
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
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool {
    horizontalSizeClass == .compact
  }

  private var color: Color {
    color(for: plan.tone)
  }

  private var sortedItems: [SpaceMailPostRefreshActionItem] {
    plan.items.sorted { left, right in
      if priority(for: left) != priority(for: right) {
        return priority(for: left) < priority(for: right)
      }
      if left.count != right.count {
        return left.count > right.count
      }
      return left.title < right.title
    }
  }

  private var visibleItems: [SpaceMailPostRefreshActionItem] {
    Array(sortedItems.prefix(isCompact ? 3 : 5))
  }

  private var hiddenItemCount: Int {
    max(0, sortedItems.count - visibleItems.count)
  }

  private var actionColumns: [GridItem] {
    [GridItem(.adaptive(minimum: isCompact ? 180 : 230), spacing: 10)]
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

      LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 10) {
        ForEach(visibleItems) { item in
          VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 8) {
              Label(item.title, systemImage: item.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color(for: item.tone))
                .fixedSize(horizontal: false, vertical: true)
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

      if hiddenItemCount > 0 {
        Text("\(hiddenItemCount) lower-priority post-refresh action\(hiddenItemCount == 1 ? "" : "s") hidden here. Open Mailbox Monitor for the full review list.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
  }

  private func priority(for item: SpaceMailPostRefreshActionItem) -> Int {
    if item.tone == "warning" { return 0 }
    if item.tone == "attention" { return 1 }
    if item.count > 0 { return 2 }
    if item.tone == "success" { return 4 }
    return 3
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

struct GmailPostRefreshActionCard: View {
  var plan: GmailPostRefreshActionPlan
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool {
    horizontalSizeClass == .compact
  }

  private var color: Color {
    color(for: plan.tone)
  }

  private var sortedItems: [GmailPostRefreshActionItem] {
    plan.items.sorted { left, right in
      if priority(for: left) != priority(for: right) {
        return priority(for: left) < priority(for: right)
      }
      if left.count != right.count {
        return left.count > right.count
      }
      return left.title < right.title
    }
  }

  private var visibleItems: [GmailPostRefreshActionItem] {
    Array(sortedItems.prefix(isCompact ? 3 : 5))
  }

  private var hiddenItemCount: Int {
    max(0, sortedItems.count - visibleItems.count)
  }

  private var actionColumns: [GridItem] {
    [GridItem(.adaptive(minimum: isCompact ? 180 : 230), spacing: 10)]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "envelope.badge.shield.half.filled")
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
        Badge("Gmail", color: color)
      }

      LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 10) {
        ForEach(visibleItems) { item in
          VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 8) {
              Label(item.title, systemImage: item.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color(for: item.tone))
                .fixedSize(horizontal: false, vertical: true)
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

      if hiddenItemCount > 0 {
        Text("\(hiddenItemCount) lower-priority Gmail action\(hiddenItemCount == 1 ? "" : "s") hidden here. Open Mailbox Monitor for the full review list.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Text("Gmail refresh remains explicit, manual, and read-only. Use Inbox for imported order mail and Mailbox Monitor for uncertain or filtered previews.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
  }

  private func priority(for item: GmailPostRefreshActionItem) -> Int {
    if item.tone == "warning" { return 0 }
    if item.tone == "attention" { return 1 }
    if item.count > 0 { return 2 }
    if item.tone == "success" { return 4 }
    return 3
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

struct MailboxProviderPostRefreshDisclosure<Content: View>: View {
  var title: String = "Provider post-refresh actions"
  var detail: String = "Open this when you need provider-specific refresh follow-up. Keep it collapsed when working the main queue."
  var symbol: String = "arrow.triangle.branch"
  var tone: Color = .secondary
  var statusLabel: String = "Optional"
  @ViewBuilder var content: Content
  @State private var isExpanded = false

  var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
      VStack(alignment: .leading, spacing: 12) {
        content
      }
      .padding(.top, 10)
    } label: {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: isExpanded ? "chevron.down.circle.fill" : symbol)
          .foregroundStyle(tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.headline)
          Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge(statusLabel, color: tone)
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(tone.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
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

struct GmailOperationsRunbook: View {
  private let normalSteps = [
    ("Confirm setup", "Check Gmail address, monitored labels, OAuth client ID placeholder, reversed URL scheme, and read-only Gmail scope notes."),
    ("Test Google sign-in", "Use the explicit sign-in test. ParcelOps should record only non-secret status, not tokens or callback URLs."),
    ("Run manual refresh", "Use real Gmail refresh only when a person is ready to review results. It must stay read-only."),
    ("Review outcomes", "Start with imported Inbox rows, then uncertain messages, then filtered examples if expected order mail is missing."),
    ("Create or link orders", "Use confirmed order or tracking details to create/link orders, then check Orders, Workbench, Tasks, and Audit.")
  ]

  private let recoverySteps = [
    ("Setup incomplete", "Add missing Gmail address, labels, OAuth client ID placeholder, redirect/scheme, or read-only scope notes."),
    ("Sign-in required", "Run Test real Google sign-in again and confirm the same mailbox account is used."),
    ("Consent/API issue", "Confirm Gmail API is enabled, the consent screen allows the account, and gmail.readonly or gmail.metadata is granted."),
    ("Label issue", "Use INBOX for the primary inbox or an existing Gmail label. Refresh remains read-only."),
    ("No imports", "Check mixed mailbox summary. Filtered non-order mail is expected for mixed-use Gmail mailboxes.")
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "envelope.badge.shield.half.filled")
          .foregroundStyle(.teal)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text("Gmail operations runbook")
            .font(.headline)
          Text("Use this when connecting or retesting a Gmail or Google Workspace mailbox. It describes operator actions only; it does not start sign-in or refresh.")
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

      Text("Boundaries: Gmail refresh is manual and read-only. ParcelOps must not delete, move, mark read, send, or modify Gmail messages. Google access tokens, refresh tokens, auth codes, callback URLs, and client secrets must not be written to JSON or Audit.")
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

struct Microsoft365OperationsRunbook: View {
  private let normalSteps = [
    ("Confirm setup", "Check mailbox address, monitored folders, tenant/client placeholders, redirect URI, User.Read, and Mail.Read notes."),
    ("Test Microsoft sign-in", "Use the explicit sign-in test. ParcelOps records only non-secret status, not tokens or callback URLs."),
    ("Run manual Graph refresh", "Use real Outlook refresh only when a person is ready to review results. It must stay read-only."),
    ("Review diagnostics", "If Graph returns 401 or a consent issue, use Audit for safe token metadata, /me probe, and Graph response labels."),
    ("Create or link orders", "Use confirmed order or tracking details from Inbox, then check Orders, Workbench, Tasks, and Audit.")
  ]

  private let recoverySteps = [
    ("Setup incomplete", "Add missing tenant ID, client ID, redirect URI, mailbox address, folders, or Mail.Read scope notes."),
    ("Sign-in required", "Run Test real Microsoft sign-in again and confirm the account matches the mailbox being refreshed."),
    ("Consent or Graph issue", "Confirm Entra app registration, public client redirect URI, delegated User.Read/Mail.Read consent, and tenant policy."),
    ("Mailbox blocked", "If /me works but mailbox endpoints fail, identity access works and mailbox Graph access is blocked or challenged."),
    ("No imports", "Check Inbox, duplicate refresh counts, and Audit. Duplicate Outlook messages update existing rows rather than creating new intake.")
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "mail.stack.fill")
          .foregroundStyle(.blue)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text("Outlook operations runbook")
            .font(.headline)
          Text("Use this when connecting or retesting a Microsoft 365 mailbox. It describes operator actions only; it does not start sign-in or refresh.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge("Manual", color: .blue)
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 10)], alignment: .leading, spacing: 10) {
        runbookColumn(title: "Normal path", symbol: "checkmark.seal.fill", items: normalSteps, color: .green)
        runbookColumn(title: "If something looks wrong", symbol: "wrench.and.screwdriver.fill", items: recoverySteps, color: .orange)
      }

      Text("Boundaries: Outlook refresh is manual and read-only. ParcelOps must not delete, move, mark read, send, or modify mailbox messages. Microsoft access tokens, refresh tokens, auth codes, callback URLs, authorization headers, and client secrets must not be written to JSON or Audit.")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
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

struct Microsoft365RecoveryCard: View {
  var summaries: [Microsoft365IntakeHealthSummary]
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool {
    horizontalSizeClass == .compact
  }

  private var latest: Microsoft365IntakeHealthSummary? {
    summaries.first
  }

  private var totalFetched: Int {
    summaries.reduce(0) { $0 + $1.fetchedCount }
  }

  private var totalImported: Int {
    summaries.reduce(0) { $0 + $1.importedCount }
  }

  private var totalDuplicates: Int {
    summaries.reduce(0) { $0 + $1.duplicateCount }
  }

  private var totalRefreshed: Int {
    summaries.reduce(0) { $0 + $1.duplicateRefreshedCount }
  }

  private var totalBlocked: Int {
    summaries.reduce(0) { $0 + $1.blockedCount }
  }

  private var color: Color {
    if totalBlocked > 0 || summaries.contains(where: { $0.tone == "warning" }) { return .orange }
    if totalImported > 0 || totalRefreshed > 0 || summaries.contains(where: { $0.tone == "success" }) { return .green }
    return .secondary
  }

  private var visibleSummaries: [Microsoft365IntakeHealthSummary] {
    Array(summaries.prefix(isCompact ? 2 : 4))
  }

  private var summaryColumns: [GridItem] {
    [GridItem(.adaptive(minimum: isCompact ? 190 : 240), spacing: 10)]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "mail.stack.fill")
          .foregroundStyle(color)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text("Outlook recovery context")
            .font(.headline)
          Text(latest?.detail ?? "No Microsoft 365 refresh summary exists yet. Add or review an Outlook setup placeholder, then run sign-in and manual Graph refresh when needed.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          if let latest {
            Text("Next: \(latest.nextAction)")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(color)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        Spacer()
        Badge(totalBlocked > 0 ? "\(totalBlocked) blocker" : "Outlook", color: color)
      }

      MetricStrip(items: [
        ("Fetched", "\(totalFetched)", totalFetched == 0 ? .secondary : .blue),
        ("Imported", "\(totalImported)", totalImported == 0 ? .secondary : .green),
        ("Duplicates", "\(totalDuplicates)", totalDuplicates == 0 ? .secondary : .teal),
        ("Refreshed", "\(totalRefreshed)", totalRefreshed == 0 ? .secondary : .green),
        ("Blocked", "\(totalBlocked)", totalBlocked == 0 ? .secondary : .orange)
      ])

      if summaries.isEmpty {
        MVPEmptyState(
          title: "No Outlook refresh evidence yet",
          detail: "Outlook setup, sign-in, token acquisition, and Graph refresh diagnostics will appear here after explicit local actions run.",
          symbol: "mail.stack"
        )
      } else {
        LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 10) {
          ForEach(visibleSummaries) { summary in
            VStack(alignment: .leading, spacing: 7) {
              HStack(alignment: .top, spacing: 8) {
                Label(summary.displayName, systemImage: "mail.stack.fill")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(color(for: summary.tone, blockedCount: summary.blockedCount))
                  .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Badge(summary.primaryOutcomeStatus, color: color(for: summary.tone, blockedCount: summary.blockedCount))
              }
              Text(summary.compactRefreshCountsText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
              Text(summary.lastRefreshSummary.isEmpty ? summary.nextAction : summary.lastRefreshSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(color(for: summary.tone, blockedCount: summary.blockedCount).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }
      }

      Text("Use Audit for detailed Microsoft sign-in, token metadata, /me probe, and Graph HTTP diagnostics. Tokens, auth headers, callback URLs, and raw message bodies stay out of JSON and Audit.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
  }

  private func color(for tone: String, blockedCount: Int) -> Color {
    if blockedCount > 0 { return .orange }
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

struct SpaceMailShiftHandoffCard: View {
  var summary: SpaceMailShiftHandoffSummary
  var onCreateDraft: (() -> Void)?

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

      if let onCreateDraft {
        CompactActionRow {
          Button(action: onCreateDraft) {
            Label("Draft handoff", systemImage: "envelope.badge")
          }
          .buttonStyle(.bordered)
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

struct GmailShiftHandoffCard: View {
  var summary: GmailShiftHandoffSummary
  var onCreateHandoffNote: (() -> Void)?
  var onCreateTask: (() -> Void)?
  var onCreateDraft: (() -> Void)?

  private var color: Color {
    color(for: summary.tone)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "envelope.badge.shield.half.filled")
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
        Badge("Gmail handoff", color: color)
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

      Text("Gmail remains explicit, manual, and read-only. Use this handoff to decide whether to fix setup, sign in, refresh, or review imported/uncertain messages.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if onCreateHandoffNote != nil || onCreateTask != nil || onCreateDraft != nil {
        CompactActionRow {
          if let onCreateHandoffNote {
            Button(action: onCreateHandoffNote) {
              Label("Handoff note", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.bordered)
          }
          if let onCreateTask {
            Button(action: onCreateTask) {
              Label("Review task", systemImage: "checklist")
            }
            .buttonStyle(.bordered)
          }
          if let onCreateDraft {
            Button(action: onCreateDraft) {
              Label("Draft handoff", systemImage: "envelope.badge")
            }
            .buttonStyle(.bordered)
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

struct SpaceMailRefreshTrendCard: View {
  var summary: SpaceMailRefreshTrendSummary
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool {
    horizontalSizeClass == .compact
  }

  private var color: Color {
    color(for: summary.tone)
  }

  private var visibleEntries: [SpaceMailRefreshTrendEntry] {
    Array(summary.entries.prefix(isCompact ? 3 : 6))
  }

  private var hiddenEntryCount: Int {
    max(0, summary.entries.count - visibleEntries.count)
  }

  private var entryColumns: [GridItem] {
    [GridItem(.adaptive(minimum: isCompact ? 180 : 230), spacing: 10)]
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
        LazyVGrid(columns: entryColumns, alignment: .leading, spacing: 10) {
          ForEach(visibleEntries) { entry in
            VStack(alignment: .leading, spacing: 6) {
              HStack(alignment: .top, spacing: 8) {
                Text(entry.timestamp)
                  .font(.caption.weight(.semibold))
                  .fixedSize(horizontal: false, vertical: true)
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

        if hiddenEntryCount > 0 {
          Text("\(hiddenEntryCount) older refresh event\(hiddenEntryCount == 1 ? "" : "s") hidden here. Open Mailbox Monitor or Audit for full refresh detail.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
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

struct GmailRefreshTrendCard: View {
  var summary: GmailRefreshTrendSummary
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool {
    horizontalSizeClass == .compact
  }

  private var color: Color {
    color(for: summary.tone)
  }

  private var visibleEntries: [GmailRefreshTrendEntry] {
    Array(summary.entries.prefix(isCompact ? 3 : 6))
  }

  private var hiddenEntryCount: Int {
    max(0, summary.entries.count - visibleEntries.count)
  }

  private var entryColumns: [GridItem] {
    [GridItem(.adaptive(minimum: isCompact ? 180 : 230), spacing: 10)]
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
        Badge("Gmail trend", color: color)
      }

      MetricStrip(items: summary.metrics.map { metric in
        (metric.title, metric.value, color(for: metric.tone))
      })

      if summary.entries.isEmpty {
        MVPEmptyState(
          title: "No Gmail refresh evidence yet",
          detail: "Gmail setup, sign-in, and refresh events will appear here after the explicit local actions run.",
          symbol: "clock.arrow.circlepath"
        )
      } else {
        LazyVGrid(columns: entryColumns, alignment: .leading, spacing: 10) {
          ForEach(visibleEntries) { entry in
            VStack(alignment: .leading, spacing: 6) {
              HStack(alignment: .top, spacing: 8) {
                Text(entry.timestamp)
                  .font(.caption.weight(.semibold))
                  .fixedSize(horizontal: false, vertical: true)
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

        if hiddenEntryCount > 0 {
          Text("\(hiddenEntryCount) older Gmail event\(hiddenEntryCount == 1 ? "" : "s") hidden here. Open Audit for full detail.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      Text("Trend entries use saved Gmail setup summaries plus safe Audit evidence. Gmail remains manual and read-only; token values, headers, and full message bodies are not shown here.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
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

struct MailboxProviderSetupChecklistCard: View {
  var summary: MailboxProviderSetupChecklistSummary
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var color: Color {
    color(for: summary.tone)
  }

  private var providerColumns: [GridItem] {
    [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 220 : 300), spacing: 10)]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "checklist.checked")
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
        Badge(summary.tone == "success" ? "Ready" : "Review", color: color)
      }

      MetricStrip(items: summary.metrics.map { metric in
        (metric.title, metric.value, color(for: metric.tone))
      })

      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "arrow.triangle.branch")
            .foregroundStyle(color)
            .frame(width: 22)
          VStack(alignment: .leading, spacing: 3) {
            Text(summary.primaryProviderTitle)
              .font(.subheadline.weight(.semibold))
            Text(summary.primaryProviderDetail)
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        Label(summary.primaryProviderNextAction, systemImage: "arrow.forward.circle.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(color)
          .fixedSize(horizontal: false, vertical: true)

        if !summary.topBlockers.isEmpty {
          VStack(alignment: .leading, spacing: 5) {
            Text("Top setup blockers")
              .font(.caption.weight(.semibold))
            ForEach(summary.topBlockers, id: \.self) { blocker in
              Label(blocker, systemImage: "exclamationmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

      LazyVGrid(columns: providerColumns, alignment: .leading, spacing: 10) {
        ForEach(summary.providers) { provider in
          VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: provider.symbol)
                .foregroundStyle(color(for: provider.tone))
                .frame(width: 22)
              VStack(alignment: .leading, spacing: 3) {
                Text(provider.providerName)
                  .font(.subheadline.weight(.semibold))
                Text(provider.status)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(color(for: provider.tone))
                  .fixedSize(horizontal: false, vertical: true)
              }
              Spacer()
            }

            Text(provider.detail)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
              ForEach(provider.checks) { check in
                HStack(alignment: .top, spacing: 8) {
                  Image(systemName: check.isComplete ? "checkmark.circle.fill" : check.symbol)
                    .foregroundStyle(color(for: check.tone))
                    .frame(width: 20)
                  VStack(alignment: .leading, spacing: 2) {
                    Text(check.title)
                      .font(.caption.weight(.semibold))
                    Text(check.detail)
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                      .fixedSize(horizontal: false, vertical: true)
                  }
                }
              }
            }

            Label(provider.nextAction, systemImage: "arrow.forward.circle.fill")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(color(for: provider.tone))
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background(color(for: provider.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }

      Text("Checklist status is computed from saved local provider setup, auth/credential state, and manual refresh evidence. It does not sign in, fetch mail, or change mailbox data.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
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

struct MailboxProviderQuickStatusCard: View {
  var summary: MailboxProviderComparisonSummary
  var store: ParcelOpsStore?
  var showMailboxLink = true
  var showInboxLink = true
  var showSetupLink = true
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var color: Color {
    color(for: summary.tone)
  }

  private var isCompact: Bool {
    horizontalSizeClass == .compact
  }

  private var configuredProviderCount: Int {
    summary.providers.filter { provider in
      provider.providerName != "No provider"
    }.count
  }

  private var totalFetchedCount: Int {
    summary.providers.reduce(0) { $0 + $1.fetchedCount }
  }

  private var totalImportedCount: Int {
    summary.providers.reduce(0) { $0 + $1.importedCount }
  }

  private var totalUncertainCount: Int {
    summary.providers.reduce(0) { $0 + $1.uncertainCount }
  }

  private var totalBlockerCount: Int {
    summary.providers.reduce(0) { $0 + $1.blockedCount }
  }

  private var nextActionTitle: String {
    summary.actionItems.first?.title ?? summary.providers.first?.nextAction ?? "Run or review the active mailbox provider"
  }

  private var nextActionDetail: String {
    summary.actionItems.first?.detail ?? summary.detail
  }

  private var providerColumns: [GridItem] {
    [GridItem(.adaptive(minimum: isCompact ? 190 : 230), spacing: 8)]
  }

  private var visibleProviders: [MailboxProviderComparisonItem] {
    Array(summary.providers.prefix(isCompact ? 2 : 3))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if isCompact {
        VStack(alignment: .leading, spacing: 8) {
          headerContent
          Badge(summary.recommendedProvider, color: color)
        }
      } else {
        HStack(alignment: .top, spacing: 10) {
          headerContent
          Spacer()
          Badge(summary.recommendedProvider, color: color)
        }
      }

      MetricStrip(items: [
        ("Providers", "\(configuredProviderCount)", configuredProviderCount > 0 ? .green : .orange),
        ("Fetched", "\(totalFetchedCount)", totalFetchedCount > 0 ? .blue : .secondary),
        ("Imported", "\(totalImportedCount)", totalImportedCount > 0 ? .green : .secondary),
        ("Uncertain", "\(totalUncertainCount)", totalUncertainCount > 0 ? .orange : .green),
        ("Blockers", "\(totalBlockerCount)", totalBlockerCount > 0 ? .red : .green)
      ])

      if !visibleProviders.isEmpty {
        LazyVGrid(columns: providerColumns, alignment: .leading, spacing: 8) {
          ForEach(visibleProviders) { provider in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: provider.symbol)
                .foregroundStyle(color(for: provider.tone))
                .frame(width: 20)
              VStack(alignment: .leading, spacing: 3) {
                Text(provider.providerName)
                  .font(.caption.weight(.semibold))
                Text(provider.statusTitle)
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(color(for: provider.tone))
                  .fixedSize(horizontal: false, vertical: true)
                Text(provider.nextAction)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(color(for: provider.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }
      }

      HStack(alignment: .top, spacing: 8) {
        Image(systemName: summary.actionItems.first?.symbol ?? (totalBlockerCount > 0 ? "wrench.and.screwdriver.fill" : "arrow.forward.circle.fill"))
          .foregroundStyle(color)
          .frame(width: 20)
        VStack(alignment: .leading, spacing: 3) {
          Text(nextActionTitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
          Text(nextActionDetail)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          }
      }

      if let store, showMailboxLink || showInboxLink || showSetupLink {
        CompactActionRow {
          if showMailboxLink {
            NavigationLink {
              MailboxView(store: store)
            } label: {
              Label("Mailbox Monitor", systemImage: "server.rack")
            }
          }
          if showInboxLink {
            NavigationLink {
              InboxView(store: store)
            } label: {
              Label("Inbox", systemImage: "tray.full.fill")
            }
          }
          if showSetupLink {
            NavigationLink {
              IntegrationsView(store: store)
            } label: {
              Label("Provider setup", systemImage: "gearshape.2.fill")
            }
          }
        }
        .buttonStyle(.bordered)
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private var headerContent: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "mail.stack.fill")
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
    }
    .frame(maxWidth: .infinity, alignment: .leading)
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

struct MailboxProviderComparisonCard: View {
  var summary: MailboxProviderComparisonSummary
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool {
    horizontalSizeClass == .compact
  }

  private var color: Color {
    color(for: summary.tone)
  }

  private var providerColumns: [GridItem] {
    [GridItem(.adaptive(minimum: isCompact ? 210 : 260), spacing: 10)]
  }

  private var actionColumns: [GridItem] {
    [GridItem(.adaptive(minimum: isCompact ? 190 : 240), spacing: 10)]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if isCompact {
        VStack(alignment: .leading, spacing: 8) {
          headerContent
          Badge(summary.recommendedProvider, color: color)
        }
      } else {
        HStack(alignment: .top, spacing: 10) {
          headerContent
          Spacer()
          Badge(summary.recommendedProvider, color: color)
        }
      }

      MetricStrip(items: summary.metrics.map { metric in
        (metric.title, metric.value, color(for: metric.tone))
      })

      if !summary.decisionRules.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Label("Provider decision guide", systemImage: "signpost.right.and.left.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
          LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 10) {
            ForEach(summary.decisionRules) { rule in
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: rule.symbol)
                  .foregroundStyle(color(for: rule.tone))
                  .frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                  Text(rule.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color(for: rule.tone))
                    .fixedSize(horizontal: false, vertical: true)
                  Text(rule.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
              }
              .padding(10)
              .frame(maxWidth: .infinity, alignment: .topLeading)
              .background(color(for: rule.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }
      }

      LazyVGrid(columns: providerColumns, alignment: .leading, spacing: 10) {
        ForEach(summary.providers) { provider in
          VStack(alignment: .leading, spacing: 8) {
            if isCompact {
              VStack(alignment: .leading, spacing: 8) {
                providerHeader(provider)
                Badge(provider.blockedCount > 0 ? "Needs setup" : "Available", color: color(for: provider.tone))
              }
            } else {
              HStack(alignment: .top, spacing: 8) {
                providerHeader(provider)
                Spacer()
                Badge(provider.blockedCount > 0 ? "Needs setup" : "Available", color: color(for: provider.tone))
              }
            }

            Text(provider.detail)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)

            MetricStrip(items: [
              ("Fetched", "\(provider.fetchedCount)", provider.fetchedCount > 0 ? .blue : .secondary),
              ("Imported", "\(provider.importedCount)", provider.importedCount > 0 ? .green : .secondary),
              ("Uncertain", "\(provider.uncertainCount)", provider.uncertainCount > 0 ? .orange : .secondary),
              ("Blockers", "\(provider.blockedCount)", provider.blockedCount > 0 ? .red : .green)
            ])

            Label(provider.nextAction, systemImage: provider.blockedCount > 0 ? "wrench.and.screwdriver.fill" : "arrow.forward.circle.fill")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(color(for: provider.tone))
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background(color(for: provider.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }

      if !summary.actionItems.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Label("Recommended next actions", systemImage: "checklist")
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)

          LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 10) {
            ForEach(summary.actionItems) { item in
              HStack(alignment: .top, spacing: 8) {
                Text(item.priority)
                  .font(.caption2.weight(.bold))
                  .foregroundStyle(.white)
                  .frame(width: 20, height: 20)
                  .background(color(for: item.tone), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                  Label(item.title, systemImage: item.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color(for: item.tone))
                    .fixedSize(horizontal: false, vertical: true)
                  Text(item.providerName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                  Text(item.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
              }
              .padding(10)
              .frame(maxWidth: .infinity, alignment: .topLeading)
              .background(color(for: item.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }
      }

      Text("Provider comparison is local operator guidance only. Mailbox refreshes remain explicit, manual, read-only actions.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
  }

  private var headerContent: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "arrow.left.arrow.right.circle.fill")
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
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func providerHeader(_ provider: MailboxProviderComparisonItem) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: provider.symbol)
        .foregroundStyle(color(for: provider.tone))
        .frame(width: 22)
      VStack(alignment: .leading, spacing: 3) {
        Text(provider.providerName)
          .font(.subheadline.weight(.semibold))
        Text(provider.statusTitle)
          .font(.caption.weight(.semibold))
          .foregroundStyle(color(for: provider.tone))
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
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
      return .teal
    }
  }
}

struct MailboxOperationsHandoffCard: View {
  var summary: MailboxOperationsHandoffSummary
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var color: Color {
    color(for: summary.tone)
  }

  private var columns: [GridItem] {
    [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 190 : 240), spacing: 10)]
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
        }
        Spacer()
        Badge(summary.lastEvidenceText, color: color)
      }

      MetricStrip(items: summary.metrics.map { metric in
        (metric.title, metric.value, color(for: metric.tone))
      })

      LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
        ForEach(summary.lines) { line in
          HStack(alignment: .top, spacing: 8) {
            Image(systemName: line.symbol)
              .foregroundStyle(color(for: line.tone))
              .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
              Text(line.title)
                .font(.caption.weight(.semibold))
              Text(line.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background(color(for: line.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }

      Text("This handoff brief is computed from local Inbox, parser, provider setup, and refresh evidence. It does not fetch, mutate, or send mailbox data.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
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

struct MailboxProviderChoiceGuideCard: View {
  private let providerRows: [(title: String, useWhen: String, setup: String, boundary: String, symbol: String, color: Color)] = [
    (
      "SpaceMail / IMAP",
      "Use for SpaceMail and other ordinary IMAP-hosted mailboxes.",
      "Confirm host, port, SSL/TLS, folder, mixed-mailbox mode, and Keychain password/app-password.",
      "Manual read-only IMAP refresh only. No mailbox mutation or background sync.",
      "server.rack",
      .green
    ),
    (
      "Gmail / Google Workspace",
      "Use only when the mailbox is hosted by Gmail or Google Workspace.",
      "Create Google Cloud iOS OAuth client, set bundle ID app.bitrig.parcelops, enable Gmail API, sign in, then run manual refresh.",
      "Manual read-only Gmail API refresh only. No token values in JSON and no mailbox mutation.",
      "envelope.badge.shield.half.filled",
      .teal
    ),
    (
      "Outlook / Microsoft 365",
      "Use only when the mailbox is hosted by Microsoft 365 or Outlook.",
      "Configure Entra app registration, redirect URI, read-only Graph scopes, Microsoft sign-in, then run manual Graph refresh.",
      "Manual read-only Graph refresh only. No background sync and no mailbox mutation.",
      "mail.stack.fill",
      .blue
    )
  ]

  var body: some View {
    SettingsPanel(title: "Choose the mailbox provider", symbol: "point.3.connected.trianglepath.dotted") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Pick the provider that actually hosts the mailbox. Custom domains can be misleading: a domain email address might still be hosted by SpaceMail/IMAP, Gmail/Google Workspace, or Microsoft 365.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        CompactMetadataGrid(minimumWidth: 230) {
          ForEach(providerRows, id: \.title) { row in
            VStack(alignment: .leading, spacing: 7) {
              Label(row.title, systemImage: row.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(row.color)
              Text(row.useWhen)
                .font(.caption2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
              Text(row.setup)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
              Text(row.boundary)
                .font(.caption2)
                .foregroundStyle(row.color)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(row.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }

        Text("All three providers feed the same local Inbox triage path. Use mock refresh for workflow testing; use real refresh only when the provider setup, credential/sign-in, and read-only scope are ready.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
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
      SpaceMailShiftHandoffCard(
        summary: store.spaceMailShiftHandoffSummary,
        onCreateDraft: { store.createSpaceMailShiftDraftMessage() }
      )

      DisclosureGroup {
        VStack(alignment: .leading, spacing: 12) {
          if showRunbook {
            SpaceMailOperationsRunbook()
          }
          SpaceMailQACheckCard(summary: store.spaceMailQACheckSummary)
          SpaceMailRefreshTrendCard(summary: store.spaceMailRefreshTrendSummary)
          if showReleaseSnapshot {
            SpaceMailReleaseSnapshotCard(snapshot: store.spaceMailReleaseSnapshot, store: store)
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
  var title: String = "Mailbox intake status"
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

  private var gmailHealthSummaries: [GmailIntakeHealthSummary] {
    store.gmailIntakeHealthSummaries
  }

  private var microsoft365HealthSummaries: [Microsoft365IntakeHealthSummary] {
    store.microsoft365IntakeHealthSummaries
  }

  private var fetchedCount: Int {
    store.totalMailboxFetchedCount
  }

  private var importedCount: Int {
    store.totalMailboxImportedCount
  }

  private var duplicateCount: Int {
    store.totalMailboxDuplicateCount
  }

  private var duplicateRefreshedCount: Int {
    store.totalMailboxDuplicateRefreshedCount
  }

  private var duplicateNoChangeCount: Int {
    store.totalMailboxDuplicateNoChangeCount
  }

  private var filteredCount: Int {
    store.totalMailboxFilteredSignalCount
  }

  private var uncertainCount: Int {
    store.totalMailboxUncertainSignalCount
  }

  private var gmailFetchedCount: Int {
    store.totalGmailFetchedCount
  }

  private var gmailImportedCount: Int {
    store.totalGmailImportedCount
  }

  private var gmailReviewCount: Int {
    store.totalGmailUncertainSignalCount + store.totalGmailFilteredSignalCount
  }

  private var gmailStatusTone: String {
    if gmailHealthSummaries.contains(where: { $0.tone == "warning" }) { return "warning" }
    if gmailHealthSummaries.contains(where: { $0.tone == "attention" || $0.pendingUncertainReviewCount > 0 }) { return "attention" }
    if gmailHealthSummaries.contains(where: { $0.importedCount > 0 || $0.tone == "success" }) { return "success" }
    return "default"
  }

  private var gmailStatusTitle: String {
    if gmailHealthSummaries.isEmpty { return "Gmail setup not started" }
    if gmailHealthSummaries.contains(where: { $0.tone == "warning" }) { return "Gmail setup needs attention" }
    if gmailReviewCount > 0 { return "Gmail review queue available" }
    if gmailImportedCount > 0 { return "Gmail order intake captured" }
    if gmailFetchedCount > 0 { return "Gmail filter evidence available" }
    return "Gmail ready for manual testing"
  }

  private var gmailStatusDetail: String {
    guard let latest = gmailHealthSummaries.first else {
      return "Add or review Gmail setup from Settings or Mailbox Monitor when a mailbox uses Gmail or Google Workspace."
    }
    return "\(latest.displayName): \(latest.detail)"
  }

  private var gmailStatusFooter: String {
    guard let latest = gmailHealthSummaries.first else {
      return "Next: add Gmail setup placeholder"
    }
    return "\(latest.compactRefreshCountsText). Next: \(latest.nextAction)"
  }

  private var hasSpaceMailProvider: Bool {
    !store.spaceMailIMAPConnections.isEmpty || !healthSummaries.isEmpty
  }

  private var hasGmailProvider: Bool {
    !store.gmailMailboxConnections.isEmpty || !gmailHealthSummaries.isEmpty
  }

  private var hasMicrosoft365Provider: Bool {
    !store.microsoft365MailboxConnections.isEmpty || !microsoft365HealthSummaries.isEmpty
  }

  private var microsoft365StatusTone: String {
    if microsoft365HealthSummaries.contains(where: { $0.tone == "warning" || $0.blockedCount > 0 }) { return "warning" }
    if microsoft365HealthSummaries.contains(where: { $0.tone == "attention" }) { return "attention" }
    if microsoft365HealthSummaries.contains(where: { $0.importedCount > 0 || $0.duplicateRefreshedCount > 0 || $0.tone == "success" }) { return "success" }
    return "default"
  }

  private var microsoft365StatusTitle: String {
    if microsoft365HealthSummaries.isEmpty { return "Outlook setup not started" }
    if microsoft365HealthSummaries.contains(where: { $0.tone == "warning" || $0.blockedCount > 0 }) { return "Outlook setup or Graph refresh needs attention" }
    if microsoft365HealthSummaries.contains(where: { $0.importedCount > 0 }) { return "Outlook order intake captured" }
    if microsoft365HealthSummaries.contains(where: { $0.duplicateRefreshedCount > 0 }) { return "Outlook duplicate refresh updated Inbox rows" }
    if microsoft365HealthSummaries.contains(where: { $0.fetchedCount > 0 || $0.duplicateCount > 0 }) { return "Outlook refresh evidence available" }
    return "Outlook ready for manual testing"
  }

  private var microsoft365StatusDetail: String {
    guard let latest = microsoft365HealthSummaries.first else {
      return "Add or review Outlook / Microsoft 365 setup from Settings or Mailbox Monitor when a mailbox is Microsoft-hosted."
    }
    return "\(latest.displayName): \(latest.detail)"
  }

  private var microsoft365StatusFooter: String {
    guard let latest = microsoft365HealthSummaries.first else {
      return "Next: add Outlook / Microsoft 365 setup placeholder"
    }
    return "\(latest.compactRefreshCountsText). Next: \(latest.nextAction)"
  }

  private var classifierImpactPreviews: [SpaceMailClassifierImpactPreview] {
    store.spaceMailIMAPConnections.flatMap { store.spaceMailClassifierImpactPreviews(for: $0) }
  }

  private var safestClassifierPreview: SpaceMailClassifierImpactPreview? {
    classifierImpactPreviews.sorted { lhs, rhs in
      let lhsPriority = classifierRiskPriority(lhs.riskLabel)
      let rhsPriority = classifierRiskPriority(rhs.riskLabel)
      if lhsPriority == rhsPriority {
        if lhs.importedCount == rhs.importedCount {
          return lhs.uncertainCount > rhs.uncertainCount
        }
        return lhs.importedCount < rhs.importedCount
      }
      return lhsPriority < rhsPriority
    }.first
  }

  private var color: Color {
    if hasSpaceMailProvider {
      return color(for: plan.tone)
    }
    if hasGmailProvider {
      return color(for: gmailStatusTone)
    }
    if hasMicrosoft365Provider {
      return color(for: microsoft365StatusTone)
    }
    return .orange
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if showTitle {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Label(title, systemImage: "mail.stack.fill")
            .font(.headline)
          Spacer()
          Badge("\(store.mailboxProviderSetupCount) providers", color: color)
        }
      }

      MetricStrip(items: [
        ("Fetched", "\(fetchedCount)", fetchedCount == 0 ? .secondary : .blue),
        ("Imported", "\(importedCount)", importedCount == 0 ? .secondary : .green),
        ("Duplicates", "\(duplicateCount)", duplicateCount == 0 ? .secondary : .teal),
        ("Refreshed", "\(duplicateRefreshedCount)", duplicateRefreshedCount == 0 ? .secondary : .green),
        ("Filtered", "\(filteredCount)", filteredCount == 0 ? .secondary : .teal),
        ("Uncertain", "\(uncertainCount)", uncertainCount == 0 ? .secondary : .orange)
      ])

      if duplicateRefreshedCount > 0 || duplicateNoChangeCount > 0 {
        Label("\(duplicateRefreshedCount) duplicate refresh update\(duplicateRefreshedCount == 1 ? "" : "s") and \(duplicateNoChangeCount) no-change result\(duplicateNoChangeCount == 1 ? "" : "s"). Existing Inbox rows were reused instead of duplicated.", systemImage: "arrow.triangle.2.circlepath")
          .font(.caption2)
          .foregroundStyle(duplicateRefreshedCount > 0 ? .green : .secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], alignment: .leading, spacing: 10) {
        if hasSpaceMailProvider {
          statusTile(
            title: "SpaceMail: \(plan.title)",
            detail: "IMAP: \(plan.detail)",
            footer: "Next: \(plan.primaryAction)",
            symbol: "arrow.triangle.branch",
            tone: plan.tone
          )
        }

        if hasGmailProvider {
          statusTile(
            title: gmailStatusTitle,
            detail: gmailStatusDetail,
            footer: gmailStatusFooter,
            symbol: "envelope.badge.shield.half.filled",
            tone: gmailStatusTone
          )
        }

        if hasMicrosoft365Provider {
          statusTile(
            title: microsoft365StatusTitle,
            detail: microsoft365StatusDetail,
            footer: microsoft365StatusFooter,
            symbol: "mail.stack.fill",
            tone: microsoft365StatusTone
          )
        }

        if !hasSpaceMailProvider && !hasGmailProvider && !hasMicrosoft365Provider {
          statusTile(
            title: "No mailbox provider configured",
            detail: "Add an active mailbox provider in Settings before testing live mailbox intake.",
            footer: "Next: open Settings or Mailbox Monitor",
            symbol: "mail.stack",
            tone: "warning"
          )
        }

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

        if let safestClassifierPreview {
          statusTile(
            title: "Classifier preset preview",
            detail: "\(presetTitle(safestClassifierPreview.preset)): \(safestClassifierPreview.detail)",
            footer: "\(safestClassifierPreview.importedCount) import, \(safestClassifierPreview.uncertainCount) uncertain, \(safestClassifierPreview.filteredCount) filtered",
            symbol: "line.3.horizontal.decrease.circle",
            tone: tone(forClassifierRisk: safestClassifierPreview.riskLabel)
          )
        }
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

  private func classifierRiskPriority(_ label: String) -> Int {
    if label.localizedCaseInsensitiveContains("stable") { return 0 }
    if label.localizedCaseInsensitiveContains("filter") { return 1 }
    if label.localizedCaseInsensitiveContains("review") { return 2 }
    if label.localizedCaseInsensitiveContains("import") { return 3 }
    return 4
  }

  private func tone(forClassifierRisk label: String) -> String {
    if label.localizedCaseInsensitiveContains("import") { return "attention" }
    if label.localizedCaseInsensitiveContains("review") { return "attention" }
    if label.localizedCaseInsensitiveContains("stable") { return "success" }
    if label.localizedCaseInsensitiveContains("filter") { return "default" }
    return "default"
  }

  private func presetTitle(_ preset: SpaceMailFilterPreset) -> String {
    switch preset {
    case .conservative:
      return "Conservative"
    case .balanced:
      return "Balanced"
    case .forwardedOrders:
      return "Forwarded orders"
    }
  }
}

struct MailboxProviderOperatorReadinessStack: View {
  var store: ParcelOpsStore
  var title: String = "Provider intake at a glance"
  var detail: String = "Use this as the operator-level mailbox provider summary. Detailed setup, QA, troubleshooting, and release evidence is still available below."
  var showAdvancedEvidence: Bool = true
  var showHandoffPacket: Bool = false
  var showMailboxLink: Bool = true

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      SettingsPanel(title: title, symbol: "point.3.connected.trianglepath.dotted") {
        VStack(alignment: .leading, spacing: 12) {
          Text(detail)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          MailboxProviderQuickStatusCard(summary: store.mailboxProviderComparisonSummary, store: store)
          MailboxProviderQAMatrixCard(store: store)
          SpaceMailPrimaryStatusStrip(store: store, title: "Combined provider intake")
          MailboxProviderReleaseGateCard(summary: store.mailboxProviderReleaseGateSummary, store: store, showMailboxLink: showMailboxLink)
          if !store.gmailMailboxConnections.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Label("Gmail provider checks", systemImage: "envelope.badge.shield.half.filled")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
              ForEach(store.gmailMailboxConnections) { connection in
                GmailReleaseSelfCheckSummaryCard(summary: store.gmailReleaseSelfCheckSummary(for: connection))
              }
            }
          }
          if !store.microsoft365MailboxConnections.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Label("Outlook provider checks", systemImage: "mail.stack.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
              ForEach(store.microsoft365MailboxConnections.prefix(2)) { connection in
                Microsoft365ReleaseSelfCheckCard(summary: store.microsoft365ReleaseSelfCheckSummary(for: connection))
              }
              if let connection = store.microsoft365MailboxConnections.first(where: {
                store.microsoft365ReleaseSelfCheckSummary(for: $0).tone != "success"
              }) {
                CompactActionRow {
                  Button("Create Outlook release task", systemImage: "checkmark.seal.fill") {
                    store.createReviewTaskFromMicrosoft365ReleaseSelfCheck(connection)
                  }
                  .buttonStyle(.bordered)
                  if showMailboxLink {
                    NavigationLink {
                      MailboxView(store: store)
                    } label: {
                      Label("Open Mailbox Monitor", systemImage: "tray.and.arrow.down.fill")
                    }
                    .buttonStyle(.bordered)
                  }
                }
              }
            }
          }
          if showHandoffPacket {
            MailboxProviderHandoffPacketCard(packet: store.mailboxProviderHandoffPacketSummary, store: store)
          }
          MailboxProviderComparisonCard(summary: store.mailboxProviderComparisonSummary)
          MailboxOperatorDecisionCard(summary: store.mailboxOperatorDecisionSummary)
          if !store.microsoft365MailboxConnections.isEmpty {
            Microsoft365RecoveryCard(summaries: store.microsoft365IntakeHealthSummaries)
          }

          CompactActionRow {
            if showMailboxLink {
              NavigationLink {
                MailboxView(store: store)
              } label: {
                Label("Mailbox Monitor", systemImage: "server.rack")
              }
            }
            NavigationLink {
              InboxView(store: store)
            } label: {
              Label("Inbox", systemImage: "tray.full.fill")
            }
            NavigationLink {
              TasksView(store: store)
            } label: {
              Label("Tasks", systemImage: "checklist")
            }
            NavigationLink {
              AuditView(store: store)
            } label: {
              Label("Audit", systemImage: "list.clipboard.fill")
            }
          }
          .buttonStyle(.bordered)
        }
      }

      if showAdvancedEvidence {
        DisclosureGroup {
          VStack(alignment: .leading, spacing: 12) {
            MailboxProviderSetupChecklistCard(summary: store.mailboxProviderSetupChecklistSummary)
            MailboxProviderTestQueueCard(summary: store.mailboxProviderTestQueueSummary, store: store, showMailboxLink: showMailboxLink)
            if !showHandoffPacket {
              MailboxProviderHandoffPacketCard(packet: store.mailboxProviderHandoffPacketSummary, store: store)
            }
            MailboxProviderTroubleshootingCard(summary: store.mailboxProviderTroubleshootingSummary, store: store)
            MailboxOperationsHandoffCard(summary: store.mailboxOperationsHandoffSummary)
            SpaceMailQACheckCard(summary: store.mailboxProviderQACheckSummary)
            SpaceMailQACheckCard(summary: store.mailboxIntakeQualitySummary)
            SpaceMailPostRefreshActionCard(plan: store.spaceMailPostRefreshActionPlan)
            SpaceMailShiftHandoffCard(
              summary: store.spaceMailShiftHandoffSummary,
              onCreateDraft: { store.createSpaceMailShiftDraftMessage() }
            )
            SpaceMailReleaseSnapshotCard(snapshot: store.mailboxReleaseReadinessSnapshot, store: store, usesMailboxReleaseTask: true)
            MailboxReleaseBlockerCard(summary: store.mailboxReleaseBlockerSummary)
            MailboxRunTimelineCard(summary: store.mailboxRunTimelineSummary)
            MailboxReleaseTestPlanCard(summary: store.mailboxReleaseTestPlanSummary)
            GmailPostRefreshActionCard(plan: store.gmailPostRefreshActionPlan)
            GmailShiftHandoffCard(
              summary: store.gmailShiftHandoffSummary,
              onCreateHandoffNote: { store.createGmailShiftHandoffNote() },
              onCreateTask: { store.createGmailShiftReviewTask() },
              onCreateDraft: { store.createGmailShiftDraftMessage() }
            )
            SpaceMailReleaseSnapshotCard(snapshot: store.gmailReleaseReadinessSnapshot, store: nil)
            MailboxReleaseBlockerCard(summary: store.gmailReleaseBlockerSummary)
            MailboxOperatorDecisionCard(summary: store.gmailOperatorDecisionSummary)
            GmailRefreshTrendCard(summary: store.gmailRefreshTrendSummary)
            GmailOperationsRunbook()
            if !store.microsoft365MailboxConnections.isEmpty {
              ForEach(store.microsoft365MailboxConnections.prefix(2)) { connection in
                Microsoft365ReleaseSelfCheckCard(summary: store.microsoft365ReleaseSelfCheckSummary(for: connection))
              }
              Microsoft365RecoveryCard(summaries: store.microsoft365IntakeHealthSummaries)
              Microsoft365OperationsRunbook()
            }
          }
          .padding(.top, 10)
        } label: {
          Label("Advanced provider evidence, QA, and runbooks", systemImage: "doc.text.magnifyingglass")
            .font(.headline)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
      }
    }
  }
}

struct MailboxProviderQAMatrixCard: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.latestSpaceMailIntakeHealthSummary
  }

  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.latestGmailIntakeHealthSummary
  }

  private var latestMicrosoft365Summary: Microsoft365IntakeHealthSummary? {
    store.latestMicrosoft365IntakeHealthSummary
  }

  private var hasSpaceMailSetup: Bool {
    !store.spaceMailIMAPConnections.isEmpty
  }

  private var hasGmailSetup: Bool {
    !store.gmailMailboxConnections.isEmpty
  }

  private var hasGmailAuth: Bool {
    store.hasGmailConnectedAuth
  }

  private var hasProviderSetup: Bool {
    store.hasMailboxProviderSetup
  }

  private var hasCredentialOrAuth: Bool {
    store.hasMailboxCredentialOrAuthReadiness
  }

  private var fetchedCount: Int {
    store.latestMailboxFetchedCount
  }

  private var importedCount: Int {
    store.latestMailboxImportedCount
  }

  private var duplicateCount: Int {
    store.latestMailboxDuplicateCount
  }

  private var duplicateRefreshedCount: Int {
    store.latestMailboxDuplicateRefreshedCount
  }

  private var filteredCount: Int {
    store.latestMailboxFilteredCount
  }

  private var uncertainCount: Int {
    store.latestMailboxUncertainCount
  }

  private var inboxOrderCount: Int {
    store.inboxCreatedOrderCount
  }

  private var providerAuditCount: Int {
    store.auditEvents.filter { event in
      event.entityType == .spaceMailIMAPConnection
        || event.entityType == .gmailMailboxConnection
        || event.entityType == .microsoft365MailboxConnection
        || event.summary.localizedCaseInsensitiveContains("SpaceMail")
        || event.summary.localizedCaseInsensitiveContains("Gmail")
        || event.summary.localizedCaseInsensitiveContains("Microsoft 365")
        || event.summary.localizedCaseInsensitiveContains("Outlook")
        || event.afterDetail?.localizedCaseInsensitiveContains("SpaceMail") == true
        || event.afterDetail?.localizedCaseInsensitiveContains("Gmail") == true
        || event.afterDetail?.localizedCaseInsensitiveContains("Microsoft 365") == true
        || event.afterDetail?.localizedCaseInsensitiveContains("Outlook") == true
    }.count
  }

  private var matrixRows: [QAMatrixRow] {
    [
      QAMatrixRow(
        title: "Provider setup",
        status: hasProviderSetup ? "Present" : "Missing",
        detail: hasProviderSetup ? "SpaceMail, Gmail, or Outlook setup records exist." : "Add SpaceMail for IMAP, Gmail for Google-hosted mailboxes, or Outlook for Microsoft-hosted mailboxes.",
        symbol: "server.rack",
        color: hasProviderSetup ? .green : .orange
      ),
      QAMatrixRow(
        title: "Credential or sign-in",
        status: hasCredentialOrAuth ? "Ready" : "Needed",
        detail: hasCredentialOrAuth ? "A SpaceMail Keychain reference, Gmail sign-in, or Microsoft sign-in state is available." : "Set/check SpaceMail credential, complete Gmail sign-in, or complete Microsoft sign-in before real refresh.",
        symbol: "key.horizontal.fill",
        color: hasCredentialOrAuth ? .green : .orange
      ),
      QAMatrixRow(
        title: "Manual refresh evidence",
        status: fetchedCount > 0 ? "\(fetchedCount) fetched" : "Not run",
        detail: fetchedCount > 0 ? "\(importedCount) imported, \(duplicateCount) duplicate, \(duplicateRefreshedCount) refreshed." : "Run one explicit manual read-only refresh for the active provider.",
        symbol: "arrow.clockwise.circle.fill",
        color: fetchedCount > 0 ? .green : .orange
      ),
      QAMatrixRow(
        title: "Mixed-mailbox filtering",
        status: filteredCount > 0 ? "\(filteredCount) filtered" : "Quiet",
        detail: filteredCount > 0 ? "Filtered non-order messages stayed out of Inbox." : "No filtered examples are recorded yet.",
        symbol: "line.3.horizontal.decrease.circle.fill",
        color: filteredCount > 0 ? .teal : .secondary
      ),
      QAMatrixRow(
        title: "Uncertain review",
        status: uncertainCount > 0 ? "\(uncertainCount) review" : "Clear",
        detail: uncertainCount > 0 ? "Review uncertain previews in Mailbox Monitor before importing." : "No uncertain provider messages are waiting for review.",
        symbol: "questionmark.folder.fill",
        color: uncertainCount > 0 ? .orange : .green
      ),
      QAMatrixRow(
        title: "Source-to-order handoff",
        status: inboxOrderCount > 0 ? "\(inboxOrderCount) order" : "Pending",
        detail: inboxOrderCount > 0 ? "Mailbox-created, forwarded-mailbox, or Wishlist-linked orders are visible across the operator flow." : "Create or link one order from a confirmed intake or Wishlist source.",
        symbol: "link.badge.plus",
        color: inboxOrderCount > 0 ? .green : .orange
      ),
      QAMatrixRow(
        title: "Provider audit trail",
        status: providerAuditCount > 0 ? "\(providerAuditCount) events" : "Missing",
        detail: providerAuditCount > 0 ? "Provider setup, refresh, classifier, and handoff actions are traceable." : "Run a provider action so Audit has a safe local history.",
        symbol: "list.clipboard.fill",
        color: providerAuditCount > 0 ? .purple : .orange
      )
    ]
  }

  private var columns: [GridItem] {
    [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 210 : 240), spacing: 10)]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "tablecells.badge.ellipsis")
          .foregroundStyle(hasProviderSetup && hasCredentialOrAuth && fetchedCount > 0 ? .green : .orange)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text("Provider QA matrix")
            .font(.headline)
          Text("Use this quick check before judging a mailbox test pass. It reads local setup, refresh summaries, Inbox handoff, and Audit evidence without signing in, fetching mail, reading credentials, or changing mailbox messages.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge(fetchedCount > 0 ? "Evidence" : "Needs run", color: fetchedCount > 0 ? .green : .orange)
      }

      MetricStrip(items: [
        ("Fetched", "\(fetchedCount)", fetchedCount > 0 ? .green : .secondary),
        ("Imported", "\(importedCount)", importedCount > 0 ? .green : .secondary),
        ("Refreshed", "\(duplicateRefreshedCount)", duplicateRefreshedCount > 0 ? .green : .secondary),
        ("Filtered", "\(filteredCount)", filteredCount > 0 ? .teal : .secondary),
        ("Uncertain", "\(uncertainCount)", uncertainCount > 0 ? .orange : .green),
        ("Orders", "\(inboxOrderCount)", inboxOrderCount > 0 ? .green : .orange)
      ])

      LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
        ForEach(matrixRows) { row in
          HStack(alignment: .top, spacing: 8) {
            Image(systemName: row.symbol)
              .foregroundStyle(row.color)
              .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
              HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(row.title)
                  .font(.caption.weight(.semibold))
                Spacer(minLength: 6)
                Text(row.status)
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(row.color)
              }
              Text(row.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background(row.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background, in: RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }

  private struct QAMatrixRow: Identifiable {
    let id = UUID()
    var title: String
    var status: String
    var detail: String
    var symbol: String
    var color: Color
  }
}

struct OperatorSupportSnapshotCard: View {
  var store: ParcelOpsStore
  var title: String = "Operator support snapshot"
  var detail: String = "Current local readiness and recovery context for hands-on testing."

  private var readiness: SpaceMailMVPReadinessSummary {
    store.spaceMailMVPReadinessSummary
  }

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.latestSpaceMailIntakeHealthSummary
  }

  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.latestGmailIntakeHealthSummary
  }

  private var latestMicrosoft365Summary: Microsoft365IntakeHealthSummary? {
    store.latestMicrosoft365IntakeHealthSummary
  }

  private var activeSpaceMailConnection: SpaceMailIMAPConnection? {
    store.spaceMailIMAPConnections.first
  }

  private var hasMailboxProviderSetup: Bool {
    store.hasMailboxProviderSetup
  }

  private var inboxLinkedOrderCount: Int {
    Set(store.intakeEmails.compactMap(\.linkedOrderID)).count
  }

  private var inboxCreatedOrderCount: Int {
    store.inboxCreatedOrderCount
  }

  private var activeWishlistItems: [WishlistItem] {
    store.activeWishlistItems
  }

  private var stagedWishlistCaptureCount: Int {
    store.stagedWishlistCaptureCandidateCount
  }

  private var agentReadyWishlistResearchCount: Int {
    store.agentReadyWishlistResearchRequestCount
  }

  private var openWishlistOrderWatchCount: Int {
    store.openWishlistOrderWatchRecordCount
  }

  private var linkedWishlistOrderCount: Int {
    store.wishlistLinkedOrderCount
  }

  private var openDailyWorkCount: Int {
    store.reviewIntakeEmails.count
      + store.importQueueItemsNeedingReview.count
      + store.acceptanceRecordsNeedingReview.count
      + store.reviewOrders.count
      + store.openWorkbenchItems.count
      + store.reviewTasksNeedingAttention.count
      + store.handoffNotesNeedingAttention.count
  }

  private var credentialReady: Bool {
    store.hasMailboxCredentialOrAuthReadiness
  }

  private var hasProviderRefreshEvidence: Bool {
    let hasSpaceMailRefresh = latestSpaceMailSummary.map {
      $0.fetchedCount > 0 || $0.importedCount > 0 || $0.duplicateCount > 0 || $0.filteredCount > 0 || $0.uncertainCount > 0 || $0.lastRefreshDate != "Never"
    } ?? false
    let hasGmailRefresh = latestGmailSummary.map {
      $0.fetchedCount > 0 || $0.importedCount > 0 || $0.duplicateCount > 0 || $0.filteredCount > 0 || $0.uncertainCount > 0 || $0.lastRefreshDate != "Never"
    } ?? false
    let hasMicrosoft365Refresh = latestMicrosoft365Summary.map {
      $0.fetchedCount > 0 || $0.importedCount > 0 || $0.duplicateCount > 0 || $0.duplicateRefreshedCount > 0 || $0.blockedCount > 0 || $0.lastRefreshDate != "Never"
    } ?? false
    return hasSpaceMailRefresh || hasGmailRefresh || hasMicrosoft365Refresh
  }

  private var supportTone: Color {
    if !hasMailboxProviderSetup { return .orange }
    if !credentialReady { return .orange }
    if latestSpaceMailSummary?.tone == "warning" || latestGmailSummary?.tone == "warning" || latestMicrosoft365Summary?.tone == "warning" { return .red }
    if !hasProviderRefreshEvidence { return .orange }
    return .green
  }

  private var supportBadge: String {
    if !hasMailboxProviderSetup { return "Setup needed" }
    if !credentialReady { return "Credential needed" }
    if latestSpaceMailSummary?.tone == "warning" || latestGmailSummary?.tone == "warning" || latestMicrosoft365Summary?.tone == "warning" { return "Check mailbox" }
    if !hasProviderRefreshEvidence { return "Refresh needed" }
    return "Ready"
  }

  private var mailboxModeText: String {
    activeSpaceMailConnection?.mailboxMode.rawValue ?? "Not configured"
  }

  private var latestRefreshText: String {
    store.latestMailboxCompactRefreshText
  }

  private var supportTiles: [(String, String, String, Color)] {
    [
      (
        "Mailbox readiness",
        "\(readiness.completedCount) of \(readiness.totalCount) SpaceMail checks complete; \(store.gmailMailboxConnections.count) Gmail provider\(store.gmailMailboxConnections.count == 1 ? "" : "s") and \(store.microsoft365MailboxConnections.count) Outlook provider\(store.microsoft365MailboxConnections.count == 1 ? "" : "s") configured. \(latestGmailSummary?.nextAction ?? latestMicrosoft365Summary?.nextAction ?? "Use whichever provider hosts the mailbox being tested today.")",
        "checklist.checked",
        hasProviderRefreshEvidence && latestGmailSummary?.tone != "warning" && latestSpaceMailSummary?.tone != "warning" && latestMicrosoft365Summary?.tone != "warning" ? .green : .orange
      ),
      (
        "Mixed mailbox mode",
        "\(mailboxModeText). Mixed mailbox mode keeps filtered non-order mail out of Inbox and holds uncertain mail for review.",
        "line.3.horizontal.decrease.circle",
        (store.latestMailboxFilteredCount) > 0 ? .teal : .secondary
      ),
      (
        "Source-to-order trail",
        "\(inboxLinkedOrderCount) intake source\(inboxLinkedOrderCount == 1 ? "" : "s") linked to order records; \(inboxCreatedOrderCount) mailbox-created order\(inboxCreatedOrderCount == 1 ? "" : "s") available for follow-up.",
        "link.badge.plus",
        inboxLinkedOrderCount > 0 ? .green : .orange
      ),
      (
        "Wishlist handoff",
        "\(store.activeWishlistItemCount) active item\(store.activeWishlistItemCount == 1 ? "" : "s"), \(stagedWishlistCaptureCount) staged capture\(stagedWishlistCaptureCount == 1 ? "" : "s"), \(agentReadyWishlistResearchCount) agent-ready brief\(agentReadyWishlistResearchCount == 1 ? "" : "s"), \(openWishlistOrderWatchCount) order watch record\(openWishlistOrderWatchCount == 1 ? "" : "s").",
        "star.square.fill",
        stagedWishlistCaptureCount == 0 && openWishlistOrderWatchCount == 0 ? (store.activeWishlistItemCount == 0 ? .secondary : .teal) : .purple
      ),
      (
        "Local audit",
        "\(store.auditEvents.count) audit event\(store.auditEvents.count == 1 ? "" : "s") recorded. Use Audit for exact action history and safe diagnostics.",
        "list.clipboard.fill",
        store.auditEvents.isEmpty ? .orange : .purple
      )
    ]
  }

  var body: some View {
    SettingsPanel(title: title, symbol: "lifepreserver.fill") {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "lifepreserver.fill")
          .font(.title3)
          .foregroundStyle(supportTone)
          .frame(width: 28)

        VStack(alignment: .leading, spacing: 4) {
          Text(detail)
            .font(.headline)
          Text(latestRefreshText)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()
        Badge(supportBadge, color: supportTone)
      }

      MetricStrip(items: [
        ("Readiness", "\(readiness.completedCount)/\(readiness.totalCount)", readiness.completedCount == readiness.totalCount ? .green : .orange),
        ("Daily work", "\(openDailyWorkCount)", openDailyWorkCount == 0 ? .green : .orange),
        ("Linked orders", "\(inboxLinkedOrderCount)", inboxLinkedOrderCount == 0 ? .orange : .green),
        ("Wishlist", "\(store.activeWishlistItemCount)", store.activeWishlistItemCount == 0 ? .secondary : .purple),
        ("Wish orders", "\(linkedWishlistOrderCount)", linkedWishlistOrderCount == 0 ? .secondary : .green),
        ("Fetched", "\(store.latestMailboxFetchedCount)", latestSpaceMailSummary == nil && latestGmailSummary == nil ? .secondary : .blue),
        ("Refreshed", "\(store.latestMailboxDuplicateRefreshedCount)", (store.latestMailboxDuplicateRefreshedCount) == 0 ? .secondary : .green),
        ("Filtered", "\(store.latestMailboxFilteredCount)", (store.latestMailboxFilteredCount) == 0 ? .secondary : .teal),
        ("Uncertain", "\(store.latestMailboxUncertainCount)", (store.latestMailboxUncertainCount) == 0 ? .secondary : .orange)
      ])

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], alignment: .leading, spacing: 10) {
        ForEach(Array(supportTiles.enumerated()), id: \.offset) { _, tile in
          VStack(alignment: .leading, spacing: 6) {
            Label(tile.0, systemImage: tile.2)
              .font(.caption.weight(.semibold))
              .foregroundStyle(tile.3)
            Text(tile.1)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background(tile.3.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }

      CompactActionRow {
        NavigationLink { MailboxView(store: store) } label: { Label("Mailbox Monitor", systemImage: "server.rack") }
          .buttonStyle(.bordered)
        NavigationLink { InboxView(store: store) } label: { Label("Inbox", systemImage: "tray.full.fill") }
          .buttonStyle(.bordered)
        NavigationLink { OrdersView(store: store) } label: { Label("Orders", systemImage: "shippingbox.fill") }
          .buttonStyle(.bordered)
        NavigationLink { AuditView(store: store) } label: { Label("Audit", systemImage: "list.clipboard.fill") }
          .buttonStyle(.bordered)
        NavigationLink { MVPSetupView(store: store) } label: { Label("MVP Setup", systemImage: "checklist.checked") }
          .buttonStyle(.bordered)
      }

      Text("Support boundary: this snapshot reads existing local records only. It does not run IMAP or Gmail refresh, change Keychain credentials, mutate mailbox messages, call external services, or alter JSON persistence.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

struct OperatorTestSessionChecklistCard: View {
  var store: ParcelOpsStore
  var title: String = "Operator test session"
  var detail: String = "A short evidence-led path for proving the MVP flow without guessing what to test next."
  @State private var feedbackMessage: String?

  private var qa: SpaceMailQACheckSummary {
    store.spaceMailQACheckSummary
  }

  private var readiness: SpaceMailMVPReadinessSummary {
    store.spaceMailMVPReadinessSummary
  }

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.latestSpaceMailIntakeHealthSummary
  }

  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.latestGmailIntakeHealthSummary
  }

  private var latestMicrosoft365Summary: Microsoft365IntakeHealthSummary? {
    store.latestMicrosoft365IntakeHealthSummary
  }

  private var inboxLinkedOrderCount: Int {
    Set(store.intakeEmails.compactMap(\.linkedOrderID)).count
  }

  private var openTasksCount: Int {
    store.reviewTasksNeedingAttention.count + store.handoffNotesNeedingAttention.count
  }

  private var activeWishlistItems: [WishlistItem] {
    store.activeWishlistItems
  }

  private var wishlistLinkedOrderCount: Int {
    store.wishlistLinkedOrderCount
  }

  private var wishlistEvidenceCount: Int {
    store.activeWishlistItemCount
      + store.stagedWishlistCaptureCandidateCount
      + store.activeWishlistResearchRequestCount
      + store.activeWishlistOrderWatchRecordCount
      + wishlistLinkedOrderCount
  }

  private var passCount: Int {
    sessionSteps.filter(\.isComplete).count
  }

  private var sessionTone: Color {
    if passCount == sessionSteps.count { return .green }
    if passCount >= max(sessionSteps.count - 2, 1) { return .orange }
    return .red
  }

  private var sessionStatus: String {
    if passCount == sessionSteps.count { return "Ready to test" }
    if passCount >= max(sessionSteps.count - 2, 1) { return "Nearly ready" }
    return "Needs setup"
  }

  private var sessionSteps: [(title: String, detail: String, evidence: String, symbol: String, isComplete: Bool, color: Color)] {
    let hasCredential = qa.checks.contains { $0.title == "Credential evidence" && $0.isComplete }
    let hasRefresh = qa.checks.contains { $0.title == "Read-only refresh evidence" && $0.isComplete }
    let hasFiltering = qa.checks.contains { $0.title == "Mixed-mailbox filter evidence" && $0.isComplete }
    let hasParserEvidence = qa.checks.contains { $0.title == "Parser evidence" && $0.isComplete }
    let hasOrderHandoff = qa.checks.contains { $0.title == "Order handoff evidence" && $0.isComplete }
    let hasAuditTrail = qa.checks.contains { $0.title == "Audit trail evidence" && $0.isComplete }
    let hasGmailRefresh = latestGmailSummary.map { $0.fetchedCount > 0 || $0.importedCount > 0 || $0.duplicateCount > 0 || $0.filteredCount > 0 || $0.uncertainCount > 0 || $0.lastRefreshDate != "Never" } ?? false
    let hasGmailFiltering = latestGmailSummary.map { $0.filteredCount > 0 || $0.pendingUncertainReviewCount > 0 || $0.uncertainCount > 0 } ?? false
    let hasGmailAuth = store.hasGmailConnectedAuth
    let hasMicrosoft365Refresh = latestMicrosoft365Summary.map { $0.fetchedCount > 0 || $0.importedCount > 0 || $0.duplicateCount > 0 || $0.duplicateRefreshedCount > 0 || $0.blockedCount > 0 || $0.lastRefreshDate != "Never" } ?? false
    let hasMicrosoft365Auth = store.microsoft365MailboxConnections.contains { store.microsoft365AuthSessionState(for: $0).status == .connected }
    let hasAnyProviderCredentialOrAuth = hasCredential || hasGmailAuth || hasMicrosoft365Auth
    let dispatchWorkCount = store.blockedShipmentManifests.count
      + store.undispatchedShipmentManifests.count
      + store.blockedDispatchChecklists.count
      + store.incompleteDispatchChecklists.count
    let hasActionQueue = openTasksCount > 0 || !store.openWorkbenchItems.isEmpty || dispatchWorkCount > 0

    return [
      (
        "1. Confirm setup",
        "The active mailbox provider has either a SpaceMail Keychain credential, Gmail sign-in, or Microsoft sign-in before a real refresh.",
        hasAnyProviderCredentialOrAuth ? "Credential or sign-in evidence exists." : "Set/check SpaceMail credentials, complete Gmail sign-in, or complete Microsoft sign-in first.",
        "key.horizontal.fill",
        hasAnyProviderCredentialOrAuth,
        hasAnyProviderCredentialOrAuth ? .green : .orange
      ),
      (
        "2. Run read-only refresh",
        "Manual mailbox refresh has completed or returned a clear safe result.",
        store.latestMailboxCompactRefreshText,
        "mail.stack.fill",
        hasRefresh || hasGmailRefresh || hasMicrosoft365Refresh,
        hasRefresh || hasGmailRefresh || hasMicrosoft365Refresh ? .green : .orange
      ),
      (
        "3. Review mixed mailbox decisions",
        "Filtered non-order mail stays out of Inbox, while uncertain mail is held in Mailbox Monitor.",
        [
          latestSpaceMailSummary.map { "SpaceMail \($0.filteredCount) filtered, \($0.totalUncertainCount) uncertain." } ?? "SpaceMail no classifier evidence.",
          latestGmailSummary.map { "Gmail \($0.filteredCount) filtered, \($0.totalUncertainCount) uncertain." } ?? "Gmail no classifier evidence."
        ].joined(separator: " "),
        "line.3.horizontal.decrease.circle",
        hasFiltering || hasGmailFiltering,
        hasFiltering || hasGmailFiltering ? .green : .orange
      ),
      (
        "4. Validate parser output",
        "Review detected merchant, order, tracking, destination, and parser diagnostics before creating records.",
        hasParserEvidence ? "\(store.intakeEmails.count) intake row\(store.intakeEmails.count == 1 ? "" : "s") available." : "No parser evidence yet.",
        "text.magnifyingglass",
        hasParserEvidence,
        hasParserEvidence ? .green : .orange
      ),
      (
        "5. Prove Source-to-order handoff",
        "Create or link one order from a confirmed intake row, then check Orders and order detail source trail.",
        hasOrderHandoff ? "\(inboxLinkedOrderCount) intake source\(inboxLinkedOrderCount == 1 ? "" : "s") linked to orders." : "No linked intake order evidence yet.",
        "shippingbox.fill",
        hasOrderHandoff,
        hasOrderHandoff ? .green : .orange
      ),
      (
        "6. Check follow-up queues",
        "Workbench, Dispatch, and Tasks should show the relevant local follow-up context for the order.",
        hasActionQueue ? "\(store.openWorkbenchItems.count) workbench item\(store.openWorkbenchItems.count == 1 ? "" : "s"), \(openTasksCount) task/handoff item\(openTasksCount == 1 ? "" : "s"), \(dispatchWorkCount) dispatch item\(dispatchWorkCount == 1 ? "" : "s")." : "No active local follow-up queue evidence yet.",
        "rectangle.stack.badge.person.crop.fill",
        hasActionQueue,
        hasActionQueue ? .green : .orange
      ),
      (
        "7. Check Wishlist path",
        "If the run includes a wanted item, confirm local capture, comparison scope, seller trust, purchase handoff, and order watch remain manual and auditable.",
        wishlistEvidenceCount > 0 ? "\(store.activeWishlistItemCount) active item\(store.activeWishlistItemCount == 1 ? "" : "s"), \(wishlistLinkedOrderCount) linked order\(wishlistLinkedOrderCount == 1 ? "" : "s"), \(wishlistEvidenceCount) local evidence signal\(wishlistEvidenceCount == 1 ? "" : "s")." : "No Wishlist evidence needed for this mailbox-only test pass.",
        "star.square.fill",
        true,
        wishlistEvidenceCount > 0 ? .purple : .secondary
      ),
      (
        "8. Confirm Audit",
        "Audit should show setup, refresh, parser, intake, order, task, and review actions as local activity.",
        hasAuditTrail ? "\(store.auditEvents.count) audit event\(store.auditEvents.count == 1 ? "" : "s") available." : "No intake/order audit evidence yet.",
        "list.clipboard.fill",
        hasAuditTrail,
        hasAuditTrail ? .green : .orange
      )
    ]
  }

  var body: some View {
    SettingsPanel(title: title, symbol: "checkmark.rectangle.stack.fill") {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "checkmark.rectangle.stack.fill")
          .font(.title3)
          .foregroundStyle(sessionTone)
          .frame(width: 28)

        VStack(alignment: .leading, spacing: 4) {
          Text(detail)
            .font(.headline)
          Text(readiness.nextAction)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()
        Badge(sessionStatus, color: sessionTone)
      }

      MetricStrip(items: [
        ("Session", "\(passCount)/\(sessionSteps.count)", sessionTone),
        ("RC evidence", "\(qa.completedCount)/\(qa.totalCount)", qa.completedCount == qa.totalCount ? .green : .orange),
        ("Inbox rows", "\(store.reviewIntakeEmails.count)", store.reviewIntakeEmails.isEmpty ? .secondary : .blue),
        ("Linked orders", "\(inboxLinkedOrderCount)", inboxLinkedOrderCount == 0 ? .orange : .green),
        ("Open work", "\(store.openWorkbenchItems.count)", store.openWorkbenchItems.isEmpty ? .secondary : .purple),
        ("Wishlist", "\(store.activeWishlistItemCount)", store.activeWishlistItemCount == 0 ? .secondary : .purple),
        ("Audit", "\(store.auditEvents.count)", store.auditEvents.isEmpty ? .orange : .green)
      ])

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 245), spacing: 10)], alignment: .leading, spacing: 10) {
        ForEach(Array(sessionSteps.enumerated()), id: \.offset) { _, step in
          VStack(alignment: .leading, spacing: 6) {
            Label(step.title, systemImage: step.isComplete ? "checkmark.circle.fill" : step.symbol)
              .font(.caption.weight(.semibold))
              .foregroundStyle(step.color)
            Text(step.detail)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            Text(step.evidence)
              .font(.caption2.weight(.semibold))
              .foregroundStyle(step.color)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background(step.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }

      CompactActionRow {
        Button("Seed demo workflow", systemImage: "wand.and.stars") {
          store.seedLocalInboxOrderDemoWorkflow()
          feedbackMessage = "Local demo workflow seeded. Check Inbox, Orders, Workbench, Tasks, and Audit."
        }
        .buttonStyle(.borderedProminent)

        Button("Create test follow-up", systemImage: "checklist") {
          store.createReviewTaskFromOperatorTestSession()
          feedbackMessage = "Operator test follow-up task created. Check Tasks."
        }
        .buttonStyle(.bordered)

        NavigationLink { MailboxView(store: store) } label: { Label("Mailbox Monitor", systemImage: "server.rack") }
          .buttonStyle(.bordered)
        NavigationLink { InboxView(store: store) } label: { Label("Inbox", systemImage: "tray.full.fill") }
          .buttonStyle(.bordered)
        NavigationLink { OrdersView(store: store) } label: { Label("Orders", systemImage: "shippingbox.fill") }
          .buttonStyle(.bordered)
        NavigationLink { AuditView(store: store) } label: { Label("Audit", systemImage: "list.clipboard.fill") }
          .buttonStyle(.bordered)
      }

      if let feedbackMessage {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
          VStack(alignment: .leading, spacing: 4) {
            Text(feedbackMessage)
              .font(.caption.weight(.semibold))
              .foregroundStyle(.green)
            Text("This action only creates local JSON-backed records and Audit history.")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
      }

      Text("Test-session boundary: this checklist reads existing local state and can seed local demo records. It does not run mailbox refresh, change credentials, mutate mailbox messages, call external services, or create background jobs.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

struct OperatorHandoffBriefCard: View {
  var store: ParcelOpsStore
  var title: String = "Operator handoff brief"
  var detail: String = "Use this before stopping work or handing the app to another operator."

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.latestSpaceMailIntakeHealthSummary
  }

  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.latestGmailIntakeHealthSummary
  }

  private var latestMicrosoft365Summary: Microsoft365IntakeHealthSummary? {
    store.latestMicrosoft365IntakeHealthSummary
  }

  private var inboxLinkedOrderCount: Int {
    Set(store.intakeEmails.compactMap(\.linkedOrderID)).count
  }

  private var taskFollowUpCount: Int {
    store.reviewTasksNeedingAttention.count + store.handoffNotesNeedingAttention.count + store.draftMessagesNeedingReview.count
  }

  private var dispatchFollowUpCount: Int {
    store.blockedShipmentManifests.count
      + store.undispatchedShipmentManifests.count
      + store.blockedDispatchChecklists.count
      + store.incompleteDispatchChecklists.count
      + store.dispatchChecklistsNeedingReview.count
      + store.shipmentManifestsNeedingReview.count
  }

  private var activeWishlistItems: [WishlistItem] {
    store.activeWishlistItems
  }

  private var wishlistCaptureReviewCount: Int {
    store.stagedWishlistCaptureCandidateCount
  }

  private var wishlistResearchReviewCount: Int {
    store.activeWishlistResearchReviewQueueCount
  }

  private var wishlistOrderWatchCount: Int {
    store.openWishlistOrderWatchRecordCount
  }

  private var linkedWishlistOrderCount: Int {
    store.wishlistLinkedOrderCount
  }

  private var wishlistFollowUpCount: Int {
    wishlistCaptureReviewCount + wishlistResearchReviewCount + wishlistOrderWatchCount
  }

  private var wishlistLine: String {
    "\(store.activeWishlistItemCount) active item\(store.activeWishlistItemCount == 1 ? "" : "s"); \(wishlistCaptureReviewCount) staged capture\(wishlistCaptureReviewCount == 1 ? "" : "s"); \(wishlistResearchReviewCount) research scope item\(wishlistResearchReviewCount == 1 ? "" : "s"); \(wishlistOrderWatchCount) order-watch record\(wishlistOrderWatchCount == 1 ? "" : "s"); \(linkedWishlistOrderCount) linked order\(linkedWishlistOrderCount == 1 ? "" : "s")."
  }

  private var mailboxLine: String {
    store.latestMailboxNamedRefreshDetail
  }

  private var handoffLines: [(String, String, String, Color)] {
    let hasAnyProviderSummary = latestSpaceMailSummary != nil || latestGmailSummary != nil || latestMicrosoft365Summary != nil
    let hasProviderWarning = latestSpaceMailSummary?.tone == "warning" || latestGmailSummary?.tone == "warning" || latestMicrosoft365Summary?.tone == "warning"

    return [
      (
        "Mailbox intake",
        mailboxLine,
        "mail.stack.fill",
        hasAnyProviderSummary ? (hasProviderWarning ? Color.red : Color.teal) : Color.orange
      ),
      (
        "Inbox and orders",
        "\(store.reviewIntakeEmails.count) intake row\(store.reviewIntakeEmails.count == 1 ? "" : "s") need review; \(inboxLinkedOrderCount) intake source\(inboxLinkedOrderCount == 1 ? "" : "s") linked to orders.",
        "tray.full.fill",
        store.reviewIntakeEmails.isEmpty && inboxLinkedOrderCount > 0 ? .green : .orange
      ),
      (
        "Workbench",
        "\(store.openWorkbenchItems.count) open item\(store.openWorkbenchItems.count == 1 ? "" : "s"); \(store.highPriorityWorkbenchItems.count) high-priority item\(store.highPriorityWorkbenchItems.count == 1 ? "" : "s").",
        "rectangle.stack.badge.person.crop.fill",
        store.highPriorityWorkbenchItems.isEmpty ? .teal : .orange
      ),
      (
        "Tasks and handoffs",
        "\(taskFollowUpCount) task, handoff, or draft follow-up item\(taskFollowUpCount == 1 ? "" : "s") needs attention.",
        "checklist",
        taskFollowUpCount == 0 ? .green : .orange
      ),
      (
        "Dispatch",
        "\(dispatchFollowUpCount) manifest or readiness item\(dispatchFollowUpCount == 1 ? "" : "s") needs review, preparation, completion, or unblock work.",
        "paperplane.fill",
        dispatchFollowUpCount == 0 ? .green : .blue
      ),
      (
        "Wishlist",
        "\(wishlistLine) Capture, comparison, trust review, purchase handoff, and order watch are local/manual until an operator acts outside ParcelOps.",
        "star.square.fill",
        wishlistFollowUpCount == 0 ? (store.activeWishlistItemCount == 0 ? .secondary : .teal) : .purple
      ),
      (
        "Audit",
        "\(store.auditEvents.count) audit event\(store.auditEvents.count == 1 ? "" : "s") available. Use Audit for exact local action history and technical diagnostics when needed.",
        "list.clipboard.fill",
        store.auditEvents.isEmpty ? .orange : .purple
      )
    ]
  }

  private var attentionCount: Int {
    store.reviewIntakeEmails.count
      + store.highPriorityWorkbenchItems.count
      + taskFollowUpCount
      + dispatchFollowUpCount
      + wishlistFollowUpCount
      + (latestSpaceMailSummary?.pendingUncertainReviewCount ?? 0)
      + (latestSpaceMailSummary?.parserIssueCount ?? 0)
      + (latestGmailSummary?.pendingUncertainReviewCount ?? 0)
  }

  private var tone: Color {
    if latestSpaceMailSummary == nil && latestGmailSummary == nil && latestMicrosoft365Summary == nil { return .orange }
    if attentionCount == 0 { return .green }
    if attentionCount <= 5 { return .orange }
    return .red
  }

  private var briefText: String {
    [
      "ParcelOps operator handoff",
      "Status: \(attentionCount == 0 ? "clear" : "\(attentionCount) attention item\(attentionCount == 1 ? "" : "s")")",
      mailboxLine,
      "Inbox: \(store.reviewIntakeEmails.count) review row\(store.reviewIntakeEmails.count == 1 ? "" : "s"), \(inboxLinkedOrderCount) linked intake order source\(inboxLinkedOrderCount == 1 ? "" : "s").",
      "Workbench: \(store.openWorkbenchItems.count) open, \(store.highPriorityWorkbenchItems.count) high priority.",
      "Tasks/handoffs/drafts: \(taskFollowUpCount) attention item\(taskFollowUpCount == 1 ? "" : "s").",
      "Dispatch: \(dispatchFollowUpCount) attention item\(dispatchFollowUpCount == 1 ? "" : "s").",
      "Wishlist: \(wishlistLine)",
      "Audit: \(store.auditEvents.count) local event\(store.auditEvents.count == 1 ? "" : "s").",
      "Boundary: mailbox refresh is manual/read-only. Do not commit xcuserdata, DerivedData, local signing/team changes, or generated project noise."
    ].joined(separator: "\n")
  }

  var body: some View {
    SettingsPanel(title: title, symbol: "person.2.wave.2.fill") {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "person.2.wave.2.fill")
          .font(.title3)
          .foregroundStyle(tone)
          .frame(width: 28)

        VStack(alignment: .leading, spacing: 4) {
          Text(detail)
            .font(.headline)
          Text(attentionCount == 0 ? "No promoted daily handoff items are open." : "\(attentionCount) promoted daily item\(attentionCount == 1 ? "" : "s") should be mentioned before handoff.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()
        Badge(attentionCount == 0 ? "Clear" : "Handoff", color: tone)
      }

      MetricStrip(items: [
        ("Inbox", "\(store.reviewIntakeEmails.count)", store.reviewIntakeEmails.isEmpty ? .green : .orange),
        ("Linked orders", "\(inboxLinkedOrderCount)", inboxLinkedOrderCount == 0 ? .secondary : .green),
        ("Workbench", "\(store.openWorkbenchItems.count)", store.openWorkbenchItems.isEmpty ? .green : .purple),
        ("Tasks", "\(taskFollowUpCount)", taskFollowUpCount == 0 ? .green : .orange),
        ("Dispatch", "\(dispatchFollowUpCount)", dispatchFollowUpCount == 0 ? .green : .blue),
        ("Wishlist", "\(wishlistFollowUpCount)", wishlistFollowUpCount == 0 ? .secondary : .purple),
        ("Audit", "\(store.auditEvents.count)", store.auditEvents.isEmpty ? .orange : .purple)
      ])

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 245), spacing: 10)], alignment: .leading, spacing: 10) {
        ForEach(Array(handoffLines.enumerated()), id: \.offset) { _, line in
          VStack(alignment: .leading, spacing: 6) {
            Label(line.0, systemImage: line.2)
              .font(.caption.weight(.semibold))
              .foregroundStyle(line.3)
            Text(line.1)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background(line.3.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }

      VStack(alignment: .leading, spacing: 6) {
        Text("Selectable handoff note")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(briefText)
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }

      CompactActionRow {
        NavigationLink { InboxView(store: store) } label: { Label("Inbox", systemImage: "tray.full.fill") }
          .buttonStyle(.bordered)
        NavigationLink { OperationsWorkbenchView(store: store) } label: { Label("Workbench", systemImage: "rectangle.stack.badge.person.crop.fill") }
          .buttonStyle(.bordered)
        NavigationLink { TasksView(store: store) } label: { Label("Tasks", systemImage: "checklist") }
          .buttonStyle(.bordered)
        NavigationLink { DispatchView(store: store) } label: { Label("Dispatch", systemImage: "paperplane.fill") }
          .buttonStyle(.bordered)
        NavigationLink { WishlistView(store: store) } label: { Label("Wishlist", systemImage: "star.square.fill") }
          .buttonStyle(.bordered)
        NavigationLink { AuditView(store: store) } label: { Label("Audit", systemImage: "list.clipboard.fill") }
          .buttonStyle(.bordered)
      }

      Text("Handoff boundary: this brief is computed from existing local records only. It does not send messages, create notifications, run mailbox refresh, mutate mailbox messages, or change credentials.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
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

  private var jsonStorePath: String {
    JSONParcelOpsRepository.defaultStoreDirectoryPath
  }

  private var jsonFileCount: Int {
    JSONParcelOpsRepository.persistedJSONFileNames.count
  }

  private var persistenceSnapshot: LocalPersistenceSnapshot {
    LocalPersistenceSnapshot(storePath: jsonStorePath, expectedFileNames: JSONParcelOpsRepository.persistedJSONFileNames)
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
        ("JSON files", "\(persistenceSnapshot.presentCount)/\(jsonFileCount)", persistenceSnapshot.missingCount == 0 ? .green : .orange),
        ("Local size", persistenceSnapshot.totalSizeText, .teal),
        ("Audit events", "\(store.auditEvents.count)", .purple),
        ("Review queue", "\(store.reviewQueueCount)", store.reviewQueueCount == 0 ? .green : .orange),
        ("Open work", "\(store.openWorkbenchItems.count)", store.openWorkbenchItems.isEmpty ? .green : .teal)
      ])

      localPersistenceSnapshot

      LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 180 : 220), spacing: 10)], alignment: .leading, spacing: 10) {
        safetyLine(
          title: "Default JSON location",
          detail: jsonStorePath,
          symbol: "folder.fill",
          color: .teal
        )
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
          title: "Corrupt JSON handling",
          detail: "If a JSON file cannot be decoded, ParcelOps archives it with an invalid timestamp suffix and restores default sample data for that file.",
          symbol: "archivebox.fill",
          color: .purple
        )
        safetyLine(
          title: "Manual backup boundary",
          detail: "To back up test data, copy the ParcelOps JSON folder outside the app. This screen does not run an export, file picker, cloud sync, or background backup.",
          symbol: "externaldrive.fill",
          color: .green
        )
        safetyLine(
          title: "Backup does not include secrets",
          detail: "JSON backups preserve local records and setup status only. SpaceMail passwords stay in Keychain and must be managed separately by macOS.",
          symbol: "key.horizontal.fill",
          color: .orange
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

  private var localPersistenceSnapshot: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label("Local JSON snapshot", systemImage: "doc.text.magnifyingglass")
          .font(.caption.weight(.semibold))
          .foregroundStyle(persistenceSnapshot.tone)
        Spacer()
        Badge(persistenceSnapshot.statusLabel, color: persistenceSnapshot.tone)
      }

      Text(persistenceSnapshot.detail)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      CompactMetadataGrid(minimumWidth: compact ? 92 : 118) {
        Badge("\(persistenceSnapshot.presentCount) present", color: persistenceSnapshot.presentCount == 0 ? .orange : .green)
        Badge("\(persistenceSnapshot.missingCount) sample-backed", color: persistenceSnapshot.missingCount == 0 ? .green : .orange)
        Badge("\(persistenceSnapshot.archivedInvalidCount) archived invalid", color: persistenceSnapshot.archivedInvalidCount == 0 ? .green : .purple)
        Badge(persistenceSnapshot.totalSizeText, color: .teal)
      }

      if !persistenceSnapshot.missingExamples.isEmpty {
        Text("Sample-backed files: \(persistenceSnapshot.missingExamples.joined(separator: ", "))")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)
      }

      if !persistenceSnapshot.archivedInvalidExamples.isEmpty {
        Text("Archived invalid JSON: \(persistenceSnapshot.archivedInvalidExamples.joined(separator: ", "))")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)
      }

      Text("This snapshot only reads local file metadata. It does not export files, open a file picker, sync to cloud, read passwords, or change JSON contents.")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(persistenceSnapshot.tone.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
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

struct LocalDataHygieneCard: View {
  var store: ParcelOpsStore
  var compact: Bool = false

  private var summary: LocalDataHygieneSummary {
    store.localDataHygieneSummary
  }

  private var tone: Color {
    color(for: summary.tone)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "stethoscope")
          .foregroundStyle(tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text("Local data hygiene")
            .font(.headline)
          Text(summary.verdict)
            .font(.subheadline.weight(.semibold))
          Text(summary.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge("\(summary.signalCount) signals", color: tone)
      }

      MetricStrip(items: summary.metrics.prefix(6).map { metric in
        (metric.title, metric.value, color(for: metric.tone))
      })

      LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 170 : 220), spacing: 10)], alignment: .leading, spacing: 10) {
        ForEach(summary.metrics.dropFirst(6)) { metric in
          hygieneMetric(metric)
        }
      }

      VStack(alignment: .leading, spacing: 6) {
        Label("Suggested next action", systemImage: "arrow.right.circle.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(tone)
        Text(summary.nextAction)
          .font(.callout.weight(.semibold))
          .foregroundStyle(tone)
          .fixedSize(horizontal: false, vertical: true)
        Text("This is guidance only. Use the existing workflow buttons on Inbox, Mailbox Monitor, Tasks, and Audit when you intentionally review, ignore, link, or complete records.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

      if !summary.examples.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Label("Example signals", systemImage: "text.magnifyingglass")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          ForEach(summary.examples, id: \.self) { example in
            Text(example)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .lineLimit(2)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }

      VStack(alignment: .leading, spacing: 6) {
        Label("Boundaries", systemImage: "lock.shield.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        ForEach(summary.boundaries, id: \.self) { boundary in
          Text(boundary)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))

      CompactActionRow {
        Button("Record snapshot", systemImage: "camera.metering.center.weighted") {
          store.recordLocalDataHygieneSnapshot()
        }
        .buttonStyle(.borderedProminent)
        Button("Create hygiene task", systemImage: "checklist") {
          store.createReviewTaskFromLocalDataHygiene()
        }
        .buttonStyle(.bordered)
        NavigationLink { InboxView(store: store) } label: { Label("Open Inbox", systemImage: "tray.full.fill") }
          .buttonStyle(.bordered)
        NavigationLink { MailboxView(store: store) } label: { Label("Mailbox Monitor", systemImage: "server.rack") }
          .buttonStyle(.bordered)
        NavigationLink { TasksView(store: store) } label: { Label("Tasks", systemImage: "checklist") }
          .buttonStyle(.bordered)
        NavigationLink { AuditView(store: store) } label: { Label("Audit", systemImage: "list.clipboard.fill") }
          .buttonStyle(.bordered)
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background, in: RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }

  private func hygieneMetric(_ metric: LocalDataHygieneMetric) -> some View {
    let metricColor = color(for: metric.tone)
    return VStack(alignment: .leading, spacing: 5) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(metric.title)
          .font(.caption.weight(.semibold))
        Spacer()
        Badge(metric.value, color: metricColor)
      }
      Text(metric.detail)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(metricColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private func color(for tone: String) -> Color {
    switch tone {
    case "success":
      return .green
    case "warning":
      return .orange
    case "attention":
      return .orange
    case "neutral":
      return .secondary
    default:
      return .blue
    }
  }
}

struct LocalDataHygieneSummaryCard: View {
  var store: ParcelOpsStore
  var title: String = "Local data hygiene"
  var detail: String = "A compact read-only check for test noise, parser leftovers, duplicate ingest, and partial Inbox order follow-up."
  var showExamples: Bool = true

  private var summary: LocalDataHygieneSummary {
    store.localDataHygieneSummary
  }

  private var tone: Color {
    color(for: summary.tone)
  }

  private var visibleMetrics: [LocalDataHygieneMetric] {
    let preferredTitles = ["Intake placeholders", "Needs review", "Parser diagnostics", "Uncertain SpaceMail", "Filtered review", "Partial order tasks"]
    return preferredTitles.compactMap { title in summary.metrics.first { $0.title == title } }
  }

  private var cleanupPlanRows: [CleanupPlanRow] {
    let metricLookup = Dictionary(uniqueKeysWithValues: summary.metrics.map { ($0.title, $0) })
    let needsReviewCount = Int(metricLookup["Needs review"]?.value ?? "") ?? 0
    let parserCount = Int(metricLookup["Parser diagnostics"]?.value ?? "") ?? 0
    let uncertainCount = Int(metricLookup["Uncertain SpaceMail"]?.value ?? "") ?? 0
    let filteredCount = Int(metricLookup["Filtered review"]?.value ?? "") ?? 0
    let placeholderCount = Int(metricLookup["Intake placeholders"]?.value ?? "") ?? 0
    let partialTaskCount = Int(metricLookup["Partial order tasks"]?.value ?? "") ?? 0

    var rows: [CleanupPlanRow] = []
    if needsReviewCount > 0 {
      rows.append(CleanupPlanRow(
        title: "Review current intake first",
        detail: "\(needsReviewCount) intake row\(needsReviewCount == 1 ? "" : "s") still need local review. Work clean order candidates before parser experiments or historical ignored rows.",
        symbol: "tray.full.fill",
        color: .orange
      ))
    }
    if uncertainCount > 0 {
      rows.append(CleanupPlanRow(
        title: "Resolve uncertain mailbox previews",
        detail: "\(uncertainCount) uncertain preview\(uncertainCount == 1 ? "" : "s") should be imported only if order-related, otherwise dismissed locally from Mailbox Monitor.",
        symbol: "questionmark.folder.fill",
        color: .orange
      ))
    }
    if parserCount > 0 || placeholderCount > 0 {
      rows.append(CleanupPlanRow(
        title: "Separate parser noise from real work",
        detail: "\(parserCount + placeholderCount) parser or placeholder signal\(parserCount + placeholderCount == 1 ? "" : "s") may be old test data. Reprocess only when tied to a current order email.",
        symbol: "text.magnifyingglass",
        color: .teal
      ))
    }
    if partialTaskCount > 0 {
      rows.append(CleanupPlanRow(
        title: "Close owned follow-up",
        detail: "\(partialTaskCount) task or handoff signal\(partialTaskCount == 1 ? "" : "s") should be completed, reopened, or assigned before calling the MVP flow clean.",
        symbol: "checklist",
        color: .purple
      ))
    }
    if filteredCount > 0 {
      rows.append(CleanupPlanRow(
        title: "Leave filtered mail out of Inbox",
        detail: "\(filteredCount) filtered preview\(filteredCount == 1 ? "" : "s") are low-priority review evidence. Import only if a real order was filtered too aggressively.",
        symbol: "line.3.horizontal.decrease.circle.fill",
        color: .secondary
      ))
    }
    if rows.isEmpty {
      rows.append(CleanupPlanRow(
        title: "No cleanup pressure",
        detail: "The active hygiene signals are quiet. Keep historical ignored, duplicate, and filtered records as audit context unless a specific row is misleading a tester.",
        symbol: "checkmark.seal.fill",
        color: .green
      ))
    }
    return rows
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: summary.signalCount == 0 ? "checkmark.seal.fill" : "stethoscope")
          .foregroundStyle(tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.headline)
          Text(summary.verdict)
            .font(.subheadline.weight(.semibold))
          Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge(summary.signalCount == 0 ? "Tidy" : "\(summary.signalCount) signals", color: tone)
      }

      MetricStrip(items: visibleMetrics.map { metric in
        (metric.title, metric.value, color(for: metric.tone))
      })

      Text(summary.nextAction)
        .font(.caption.weight(.semibold))
        .foregroundStyle(tone)
        .fixedSize(horizontal: false, vertical: true)

      VStack(alignment: .leading, spacing: 8) {
        Label("Cleanup plan", systemImage: "list.bullet.clipboard")
          .font(.caption.weight(.semibold))
          .foregroundStyle(tone)
        CompactMetadataGrid(minimumWidth: 190) {
          ForEach(cleanupPlanRows) { row in
            VStack(alignment: .leading, spacing: 6) {
              Label(row.title, systemImage: row.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(row.color)
              Text(row.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(row.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(tone.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

      if showExamples && !summary.examples.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(summary.examples.prefix(3), id: \.self) { example in
            Text(example)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .lineLimit(2)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }

      CompactActionRow {
        Button("Record snapshot", systemImage: "camera.metering.center.weighted") {
          store.recordLocalDataHygieneSnapshot()
        }
        .buttonStyle(.borderedProminent)
        Button("Create task", systemImage: "checklist") {
          store.createReviewTaskFromLocalDataHygiene()
        }
        .buttonStyle(.bordered)
        NavigationLink { SettingsView(store: store) } label: { Label("Full hygiene view", systemImage: "gearshape.2.fill") }
          .buttonStyle(.bordered)
        NavigationLink { InboxView(store: store) } label: { Label("Inbox", systemImage: "tray.full.fill") }
          .buttonStyle(.bordered)
        NavigationLink { MailboxView(store: store) } label: { Label("Mailbox", systemImage: "server.rack") }
          .buttonStyle(.bordered)
        NavigationLink { TasksView(store: store) } label: { Label("Tasks", systemImage: "checklist") }
          .buttonStyle(.bordered)
      }

      Text("Read-only boundary: this card does not delete, merge, rewrite, refresh mail, read Keychain, or mutate mailbox messages.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(tone.opacity(0.18)))
  }

  private func color(for tone: String) -> Color {
    switch tone {
    case "success":
      return .green
    case "warning":
      return .orange
    case "attention":
      return .orange
    case "neutral":
      return .secondary
    default:
      return .blue
    }
  }

  private struct CleanupPlanRow: Identifiable {
    let id = UUID()
    var title: String
    var detail: String
    var symbol: String
    var color: Color
  }
}

struct ActiveOperatorQueueFocusCard: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var activeIntakeCount: Int {
    store.reviewIntakeEmails.filter { email in
      email.reviewState == .needsReview
        && !email.subject.isPlaceholderValidationValue
        && !email.sender.isPlaceholderValidationValue
    }.count
  }

  private var placeholderIntakeCount: Int {
    store.reviewIntakeEmails.filter { email in
      email.subject.isPlaceholderValidationValue
        || email.sender.isPlaceholderValidationValue
        || email.detectedOrderNumber.isPlaceholderValidationValue
        || email.detectedTrackingNumber.isPlaceholderValidationValue
        || email.rawBodyPreview.localizedCaseInsensitiveContains("Content-Type:")
        || email.rawBodyPreview.localizedCaseInsensitiveContains("Return-Path:")
    }.count
  }

  private var uncertainProviderCount: Int {
    store.pendingMailboxUncertainReviewCount
  }

  private var filteredProviderCount: Int {
    store.pendingMailboxFilteredReviewCount
  }

  private var activeWorkbenchCount: Int {
    store.openWorkbenchItems.count
  }

  private var activeTaskCount: Int {
    store.reviewTasksNeedingAttention.count + store.handoffNotesNeedingAttention.count
  }

  private var blockedDispatchCount: Int {
    store.blockedShipmentManifests.count + store.blockedDispatchChecklists.count
  }

  private var activeQueueCount: Int {
    activeIntakeCount + uncertainProviderCount + activeWorkbenchCount + activeTaskCount + blockedDispatchCount
  }

  private var historicalNoiseCount: Int {
    placeholderIntakeCount
      + filteredProviderCount
      + store.intakeEmails.filter { $0.reviewState == .ignored }.count
      + store.mailboxIngestRecords.filter { $0.status == .duplicateSkipped }.count
  }

  private var tone: Color {
    if activeQueueCount == 0 { return .green }
    if activeQueueCount <= 8 { return .orange }
    return .red
  }

  private var statusTitle: String {
    if activeQueueCount == 0 { return "Active operator queue is clear" }
    if activeQueueCount <= 8 { return "Focus on active operator work first" }
    return "Active operator queue is noisy"
  }

  private var statusDetail: String {
    if activeQueueCount == 0 {
      return "Current Inbox, uncertain provider review, Workbench, Tasks, and blocked Dispatch work are quiet. Historical ignored, duplicate, and filtered rows can remain as audit evidence."
    }
    return "Work the active queue before judging the app by historical mailbox-test noise. Ignored rows, duplicate ingest, and filtered mixed-mailbox examples are deliberately lower priority."
  }

  private var focusRows: [FocusRow] {
    [
      FocusRow(
        title: "Inbox review",
        value: "\(activeIntakeCount)",
        detail: activeIntakeCount == 0 ? "No clean active intake rows need review." : "Review clean intake rows before old placeholder rows.",
        symbol: "tray.full.fill",
        color: activeIntakeCount == 0 ? .green : .orange
      ),
      FocusRow(
        title: "Uncertain providers",
        value: "\(uncertainProviderCount)",
        detail: uncertainProviderCount == 0 ? "No uncertain mailbox previews are waiting." : "Import true order messages or dismiss non-order previews.",
        symbol: "questionmark.folder.fill",
        color: uncertainProviderCount == 0 ? .green : .orange
      ),
      FocusRow(
        title: "Workbench",
        value: "\(activeWorkbenchCount)",
        detail: activeWorkbenchCount == 0 ? "No open Workbench exceptions." : "Handle exceptions, mismatches, or blocked work here.",
        symbol: "rectangle.stack.badge.person.crop.fill",
        color: activeWorkbenchCount == 0 ? .green : .orange
      ),
      FocusRow(
        title: "Tasks and handoffs",
        value: "\(activeTaskCount)",
        detail: activeTaskCount == 0 ? "No task or handoff attention needed." : "Complete, acknowledge, reopen, or assign follow-up work.",
        symbol: "checklist",
        color: activeTaskCount == 0 ? .green : .orange
      ),
      FocusRow(
        title: "Blocked dispatch",
        value: "\(blockedDispatchCount)",
        detail: blockedDispatchCount == 0 ? "No blocked dispatch items." : "Unblock manifests or readiness checklists before handoff.",
        symbol: "paperplane.fill",
        color: blockedDispatchCount == 0 ? .green : .red
      ),
      FocusRow(
        title: "Historical noise",
        value: "\(historicalNoiseCount)",
        detail: "Ignored, duplicate, filtered, or placeholder rows are useful context but should not drive daily work.",
        symbol: "archivebox.fill",
        color: historicalNoiseCount == 0 ? .green : .secondary
      )
    ]
  }

  private var columns: [GridItem] {
    [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 210 : 240), spacing: 10)]
  }

  var body: some View {
    SettingsPanel(title: "Active queue focus", symbol: "scope") {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "scope")
          .foregroundStyle(tone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(statusTitle)
            .font(.headline)
          Text(statusDetail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge(activeQueueCount == 0 ? "Clear" : "\(activeQueueCount) active", color: tone)
      }

      MetricStrip(items: [
        ("Active", "\(activeQueueCount)", tone),
        ("Inbox", "\(activeIntakeCount)", activeIntakeCount == 0 ? .green : .orange),
        ("Uncertain", "\(uncertainProviderCount)", uncertainProviderCount == 0 ? .green : .orange),
        ("Workbench", "\(activeWorkbenchCount)", activeWorkbenchCount == 0 ? .green : .orange),
        ("Tasks", "\(activeTaskCount)", activeTaskCount == 0 ? .green : .orange),
        ("Historical", "\(historicalNoiseCount)", .secondary)
      ])

      LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
        ForEach(focusRows) { row in
          HStack(alignment: .top, spacing: 8) {
            Image(systemName: row.symbol)
              .foregroundStyle(row.color)
              .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
              HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(row.title)
                  .font(.caption.weight(.semibold))
                Spacer(minLength: 6)
                Text(row.value)
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(row.color)
              }
              Text(row.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background(row.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }

      CompactActionRow {
        NavigationLink { InboxView(store: store) } label: { Label("Inbox", systemImage: "tray.full.fill") }
          .buttonStyle(.bordered)
        NavigationLink { MailboxView(store: store) } label: { Label("Mailbox", systemImage: "server.rack") }
          .buttonStyle(.bordered)
        NavigationLink { OperationsWorkbenchView(store: store) } label: { Label("Workbench", systemImage: "rectangle.stack.badge.person.crop.fill") }
          .buttonStyle(.bordered)
        NavigationLink { TasksView(store: store) } label: { Label("Tasks", systemImage: "checklist") }
          .buttonStyle(.bordered)
        NavigationLink { DispatchView(store: store) } label: { Label("Dispatch", systemImage: "paperplane.fill") }
          .buttonStyle(.bordered)
      }

      Text("Read-only boundary: this card only groups existing local state. It does not delete old test data, clear duplicate metadata, dismiss reviews, refresh mail, read Keychain, or mutate mailbox messages.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private struct FocusRow: Identifiable {
    let id = UUID()
    var title: String
    var value: String
    var detail: String
    var symbol: String
    var color: Color
  }
}

struct PrimaryRouteShortcutGuideCard: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var columns: [GridItem] {
    [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 145 : 165), spacing: 8)]
  }

  private let shortcutRows: [(key: String, title: String, detail: String, symbol: String, color: Color)] = [
    ("⌘1", "Dashboard", "Start-of-day summary", "rectangle.grid.2x2.fill", .blue),
    ("⌘2", "Inbox", "Mailbox triage", "tray.full.fill", .teal),
    ("⌘3", "Orders", "Active order work", "shippingbox.fill", .orange),
    ("⌘4", "Workbench", "Exceptions", "rectangle.stack.badge.person.crop.fill", .purple),
    ("⌘5", "Dispatch", "Outbound queue", "paperplane.fill", .green),
    ("⌘6", "Tasks", "Follow-up work", "checklist", .indigo),
    ("⌘7", "Audit", "Local history", "list.clipboard.fill", .cyan),
    ("⌘8", "Settings", "Setup and sources", "gearshape.fill", .secondary)
  ]

  var body: some View {
    SettingsPanel(title: "Primary route shortcuts", symbol: "keyboard") {
      Text("Use the Navigate menu or these keyboard shortcuts on macOS to move through the daily operator flow without hunting through the sidebar.")
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
        ForEach(shortcutRows, id: \.key) { row in
          HStack(alignment: .top, spacing: 8) {
            Text(row.key)
              .font(.caption.weight(.bold))
              .monospaced()
              .foregroundStyle(row.color)
              .frame(width: 34, alignment: .leading)
            Image(systemName: row.symbol)
              .foregroundStyle(row.color)
              .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
              Text(row.title)
                .font(.caption.weight(.semibold))
              Text(row.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .padding(9)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background(row.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }

      Text("Shortcut boundary: these commands only change the visible ParcelOps route. They do not refresh mail, modify records, touch credentials, or perform background work.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

struct RecentOperatorImprovementsCard: View {
  private let improvements: [(title: String, detail: String, symbol: String, color: Color)] = [
    (
      "Active queue focus",
      "Dashboard, Needs Review, Settings, and MVP Setup now separate current operator work from historical mailbox-test noise.",
      "scope",
      .teal
    ),
    (
      "Cleaner navigation",
      "The desktop sidebar keeps advanced routes collapsed, shows daily route counts first, and avoids the old floating footer overlap.",
      "sidebar.left",
      .blue
    ),
    (
      "Faster route switching",
      "The macOS Navigate menu and visible shortcut hints support Command-1 through Command-8 for the primary workflow.",
      "keyboard",
      .purple
    ),
    (
      "Mailbox QA clarity",
      "Mailbox provider status, duplicate refresh handling, parser diagnostics, and source trails remain visible without flooding Inbox.",
      "tray.full.fill",
      .orange
    )
  ]

  var body: some View {
    SettingsPanel(title: "Recent operator improvements", symbol: "sparkles") {
      Text("Use this as a short handoff note for what changed recently in the daily MVP experience.")
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      VStack(alignment: .leading, spacing: 8) {
        ForEach(improvements, id: \.title) { item in
          HStack(alignment: .top, spacing: 9) {
            Image(systemName: item.symbol)
              .foregroundStyle(item.color)
              .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
              Text(item.title)
                .font(.caption.weight(.semibold))
              Text(item.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .padding(9)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background(item.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }

      Text("This is static release context only. It does not read mail, modify local records, touch credentials, or start background work.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

private struct LocalPersistenceSnapshot {
  var storePath: String
  var expectedFileNames: [String]

  private var fileManager: FileManager { .default }

  private var storeURL: URL {
    URL(fileURLWithPath: storePath, isDirectory: true)
  }

  private var directoryContents: [URL] {
    (try? fileManager.contentsOfDirectory(
      at: storeURL,
      includingPropertiesForKeys: [.fileSizeKey],
      options: [.skipsHiddenFiles]
    )) ?? []
  }

  private var presentFileNames: Set<String> {
    Set(directoryContents.map(\.lastPathComponent))
  }

  var presentCount: Int {
    expectedFileNames.filter { presentFileNames.contains($0) }.count
  }

  var missingCount: Int {
    max(expectedFileNames.count - presentCount, 0)
  }

  var archivedInvalidCount: Int {
    directoryContents.filter { $0.lastPathComponent.contains(".invalid-") && $0.pathExtension == "json" }.count
  }

  var totalSizeText: String {
    let totalBytes = directoryContents.reduce(0) { total, url in
      let values = try? url.resourceValues(forKeys: [.fileSizeKey])
      return total + (values?.fileSize ?? 0)
    }
    return ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
  }

  var missingExamples: [String] {
    Array(expectedFileNames.filter { !presentFileNames.contains($0) }.prefix(4))
  }

  var archivedInvalidExamples: [String] {
    Array(directoryContents.map(\.lastPathComponent).filter { $0.contains(".invalid-") && $0.hasSuffix(".json") }.sorted().prefix(3))
  }

  var statusLabel: String {
    if !fileManager.fileExists(atPath: storePath) { return "Folder pending" }
    if archivedInvalidCount > 0 { return "Archived invalid JSON" }
    if missingCount > 0 { return "Sample-backed" }
    return "Persisted locally"
  }

  var detail: String {
    if !fileManager.fileExists(atPath: storePath) {
      return "The local JSON folder has not been created yet. It will be created automatically when ParcelOps saves or loads JSON-backed data."
    }
    if archivedInvalidCount > 0 {
      return "\(archivedInvalidCount) invalid JSON file\(archivedInvalidCount == 1 ? " was" : "s were") archived locally and defaults were restored for those records."
    }
    if missingCount > 0 {
      return "\(missingCount) expected JSON file\(missingCount == 1 ? " is" : "s are") still sample-backed or not written yet. This is normal before those local record types are edited."
    }
    return "All expected JSON files are present in the local ParcelOps store."
  }

  var tone: Color {
    if !fileManager.fileExists(atPath: storePath) { return .orange }
    if archivedInvalidCount > 0 { return .purple }
    if missingCount > 0 { return .orange }
    return .green
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
    let source = store.intakeSourceSummary(for: email)
    return IntakeSourceContext(
      providerLabel: source.label,
      providerColor: color(for: source.tone),
      statusLabel: source.status,
      statusColor: source.status == MailboxIngestStatus.imported.rawValue ? .green : email.reviewState.color,
      capturedLabel: source.captured,
      detail: source.label == "Manual/local" ? manualDetail : "\(source.detail) \(linkedDetailSuffix)"
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

  private func color(for tone: String) -> Color {
    switch tone {
    case "spacemail":
      return .teal
    case "gmail":
      return .green
    case "mock":
      return .purple
    case "microsoft", "mailbox":
      return .blue
    default:
      return .secondary
    }
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

struct LinkedOrderContextPanel: View {
  var order: TrackedOrder?
  var sourceLabel: String
  var emptyDetail: String
  var linkedDetail: String
  var store: ParcelOpsStore?

  init(
    order: TrackedOrder?,
    sourceLabel: String,
    emptyDetail: String,
    linkedDetail: String,
    store: ParcelOpsStore? = nil
  ) {
    self.order = order
    self.sourceLabel = sourceLabel
    self.emptyDetail = emptyDetail
    self.linkedDetail = linkedDetail
    self.store = store
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label(order == nil ? "No linked order" : "Linked order", systemImage: order == nil ? "link.badge.plus" : "link.circle.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(tone)
        Spacer()
        Badge(sourceLabel, color: tone)
      }

      if let order {
        CompactMetadataGrid(minimumWidth: 130) {
          Badge(order.orderNumber, color: .teal)
          Badge(order.status.rawValue, color: order.status.color)
          Badge(order.reviewState.rawValue, color: order.reviewState.color)
          Badge(order.trackingNumber.isPlaceholderValidationValue ? "Tracking needs review" : "Tracking present", color: order.trackingNumber.isPlaceholderValidationValue ? .orange : .green)
        }
        Text("\(order.store) • \(order.customer) • \(order.destination)")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        Text(linkedDetail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        if let store {
          NavigationLink {
            OrderDetailView(order: order, store: store)
          } label: {
            Label("Open linked order", systemImage: "arrow.up.right.square.fill")
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
        }
      } else {
        Text(emptyDetail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private var tone: Color {
    if let order {
      if order.reviewState != .accepted || order.trackingNumber.isPlaceholderValidationValue || order.destination.isPlaceholderValidationValue {
        return .orange
      }
      return .teal
    }
    return .secondary
  }
}

struct LinkedOrdersContextPanel: View {
  var title: String
  var linkedOrders: [TrackedOrder]
  var sourceLabel: String
  var emptyDetail: String
  var linkedDetail: String
  var tone: Color = .teal
  var store: ParcelOpsStore? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label(title, systemImage: linkedOrders.isEmpty ? "link.badge.plus" : "shippingbox.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(linkedOrders.isEmpty ? .orange : tone)
        Spacer()
        Badge(sourceLabel, color: linkedOrders.isEmpty ? .orange : tone)
      }

      Text(linkedOrders.isEmpty ? emptyDetail : linkedDetail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if linkedOrders.isEmpty {
        Badge("No linked order found", color: .orange)
      } else {
        CompactMetadataGrid(minimumWidth: 140) {
          ForEach(linkedOrders.prefix(4)) { order in
            Badge(order.orderNumber, color: order.reviewState == .accepted ? .green : .orange)
            Badge(order.trackingNumber.isPlaceholderValidationValue ? "Tracking needs review" : "Tracking present", color: order.trackingNumber.isPlaceholderValidationValue ? .orange : .green)
          }
        }

        if let store {
          let sourceSummaries = linkedOrders.prefix(3).compactMap { order in
            inboxSourceSummary(for: order, store: store)
          }

          if !sourceSummaries.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
              Label("Order source trail", systemImage: "tray.and.arrow.down.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tone)
              ForEach(sourceSummaries, id: \.id) { summary in
                CompactMetadataGrid(minimumWidth: 140) {
                  Badge(summary.orderNumber, color: summary.color)
                  Badge(summary.sourceLabel, color: summary.color)
                  Badge(summary.status, color: summary.status == MailboxIngestStatus.imported.rawValue ? .green : summary.color)
                }
                Text(summary.detail)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
            .padding(8)
            .background(tone.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
          }

          let mailboxSources = linkedOrders.prefix(3).flatMap { order in
            store.mailboxSourceSummaries(for: order).map { source in
              DispatchLinkedOrderMailboxSourceSummary(orderNumber: order.orderNumber, source: source)
            }
          }

          if !mailboxSources.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
              Label("Mailbox provider trail", systemImage: "envelope.badge.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tone)
              ForEach(mailboxSources.prefix(6)) { item in
                CompactMetadataGrid(minimumWidth: 140) {
                  Badge(item.orderNumber, color: mailboxSourceColor(item.source))
                  Badge(item.source.badgeLabel, color: mailboxSourceColor(item.source))
                  Badge(item.source.statusLabel, color: mailboxSourceColor(item.source))
                }
                Text(item.source.detailText)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
            .padding(8)
            .background(tone.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
          }

          CompactActionRow {
            ForEach(linkedOrders.prefix(3)) { order in
              NavigationLink {
                OrderDetailView(order: order, store: store)
              } label: {
                Label(order.orderNumber, systemImage: "arrow.up.right.square.fill")
              }
              .buttonStyle(.bordered)
              .controlSize(.small)
            }
          }
        }
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background((linkedOrders.isEmpty ? Color.orange : tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private func inboxSourceSummary(for order: TrackedOrder, store: ParcelOpsStore) -> DispatchLinkedOrderSourceSummary? {
    guard order.isInboxCreatedLocalOrder else { return nil }
    let linkedEmail = store.linkedIntakeEmails(for: order).first

    guard let linkedEmail else {
      return DispatchLinkedOrderSourceSummary(
        id: "missing-\(order.id.uuidString)",
        orderNumber: order.orderNumber,
        sourceLabel: "No intake match",
        status: "Check order",
        detail: "This dispatch row is linked to an Inbox-created order, but no intake email matched the current order number.",
        color: .orange
      )
    }

    let source = store.intakeSourceSummary(for: linkedEmail)
    return DispatchLinkedOrderSourceSummary(
      id: linkedEmail.id.uuidString,
      orderNumber: order.orderNumber,
      sourceLabel: source.label,
      status: source.status,
      detail: "\(source.detail) Captured \(source.captured).",
      color: color(for: source.tone)
    )
  }

  private func color(for tone: String) -> Color {
    switch tone {
    case "spacemail":
      return .teal
    case "mock":
      return .purple
    case "microsoft", "mailbox":
      return .blue
    default:
      return .secondary
    }
  }

  private func mailboxSourceColor(_ summary: OrderMailboxSourceSummary) -> Color {
    if summary.importedCount > 0 { return .green }
    if summary.duplicateRefreshedCount > 0 { return .teal }
    if summary.duplicateCount > 0 { return .orange }
    switch summary.providerName {
    case "Gmail": return .blue
    case "SpaceMail": return .teal
    case "Microsoft 365": return .purple
    default: return .secondary
    }
  }
}

private struct DispatchLinkedOrderSourceSummary {
  var id: String
  var orderNumber: String
  var sourceLabel: String
  var status: String
  var detail: String
  var color: Color
}

private struct DispatchLinkedOrderMailboxSourceSummary: Identifiable {
  var orderNumber: String
  var source: OrderMailboxSourceSummary

  var id: String {
    "\(orderNumber)-\(source.id)"
  }
}
