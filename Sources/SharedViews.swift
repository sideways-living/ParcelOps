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
    case .reviewTask: "checklist"
    case .slaPolicy: "timer"
    case .communicationTemplate: "text.badge.checkmark"
    case .draftMessage: "envelope.open.fill"
    case .contactDirectoryEntry: "person.crop.circle.badge.checkmark"
    case .accountCredentialRecord: "key.horizontal.fill"
    case .vendorProfile: "building.2.crop.circle.fill"
    case .shipmentGroup: "shippingbox.and.arrow.backward.fill"
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
    case .slaPolicy: "timer"
    case .communicationTemplate: "text.badge.checkmark"
    case .draftMessage: "envelope.open.fill"
    case .contact: "person.crop.circle.badge.checkmark"
    case .account: "key.horizontal.fill"
    case .vendorProfile: "building.2.crop.circle.fill"
    case .shipmentGroup: "shippingbox.and.arrow.backward.fill"
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
    case .automation: "arrow.triangle.branch"
    case .search: "magnifyingglass"
    case .audit: "list.clipboard.fill"
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

extension ContactLinkedEntityType {
  var symbol: String {
    switch self {
    case .store: "storefront.fill"
    case .supplier: "building.2.fill"
    case .carrier: "truck.box.fill"
    case .shopifyStore: "cart.fill"
    case .internalTeam: "person.2.fill"
    case .order: "shippingbox.fill"
    case .intakeEmail: "envelope.open.fill"
    case .trackingEvent: "location.fill.viewfinder"
    case .evidence: "paperclip"
    case .reviewTask: "checklist"
    case .slaPolicy: "timer"
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
    case .slaPolicy: "timer"
    case .draftMessage: "envelope.open.fill"
    case .contact: "person.crop.circle.badge.checkmark"
    case .account: "key.horizontal.fill"
    case .vendorProfile: "building.2.crop.circle.fill"
    case .shipmentGroup: "shippingbox.and.arrow.backward.fill"
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
    case .reviewTask, .slaPolicy, .draftMessage, .contact, .account, .vendorProfile, .automationRule, .savedFilter, .auditEvent, .shipmentGroup:
      return id.uuidString == linkedEntityID
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
    case .slaPolicy: .slaPolicy
    case .communicationTemplate: nil
    case .draftMessage: .draftMessage
    case .contact: .contact
    case .account: .account
    case .vendorProfile: .vendorProfile
    case .shipmentGroup: .shipmentGroup
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
