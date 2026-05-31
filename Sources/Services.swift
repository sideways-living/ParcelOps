import Foundation

protocol MailboxIngestionService {
  func ingest(from mailboxes: [TrackedMailbox]) async throws -> [MailEvent]
}

protocol OrderMatchingService {
  func reviewState(for event: MailEvent, existingOrders: [TrackedOrder]) -> ReviewState
}

protocol ShopifySyncService {
  func sync(connections: [ShopifyConnection]) async throws -> [TrackedOrder]
}

protocol CarrierTrackingService {
  func refresh(order: TrackedOrder) async throws -> TrackedOrder
}

protocol ParcelExportService {
  func export(order: TrackedOrder) async throws
}

protocol WorkflowTemplateEngine {
  func actions(for trigger: WorkflowTrigger) -> [WorkflowTemplateAction]
}

struct MockMailboxIngestionService: MailboxIngestionService {
  func ingest(from mailboxes: [TrackedMailbox]) async throws -> [MailEvent] {
    []
  }
}

struct MockOrderMatchingService: OrderMatchingService {
  func reviewState(for event: MailEvent, existingOrders: [TrackedOrder]) -> ReviewState {
    event.severity == .info ? .accepted : .needsReview
  }
}

struct MockShopifySyncService: ShopifySyncService {
  func sync(connections: [ShopifyConnection]) async throws -> [TrackedOrder] {
    []
  }
}

struct MockCarrierTrackingService: CarrierTrackingService {
  func refresh(order: TrackedOrder) async throws -> TrackedOrder {
    order
  }
}

struct MockParcelExportService: ParcelExportService {
  func export(order: TrackedOrder) async throws {}
}

struct RuleBasedWorkflowTemplateEngine: WorkflowTemplateEngine {
  private var rules: [WorkflowTemplateRule] = [
    WorkflowTemplateRule(trigger: .manualSync, actions: [.ingestMailboxes, .syncShopify, .scanFolders, .refreshCarriers, .appendContactHistory]),
    WorkflowTemplateRule(trigger: .mailboxEventSeverity(.critical), actions: [.routeToNeedsReview, .appendContactHistory]),
    WorkflowTemplateRule(trigger: .mailboxEventSeverity(.watch), actions: [.routeToNeedsReview, .appendContactHistory]),
    WorkflowTemplateRule(trigger: .mailboxEventSeverity(.info), actions: [.appendContactHistory]),
    WorkflowTemplateRule(trigger: .wishlistConverted, actions: [.routeToNeedsReview, .appendContactHistory])
  ]

  func actions(for trigger: WorkflowTrigger) -> [WorkflowTemplateAction] {
    rules.first { $0.trigger == trigger }?.actions ?? []
  }
}
