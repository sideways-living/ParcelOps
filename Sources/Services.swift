import Foundation

protocol MailboxIngestionService {
  func fetchMessages(from mailboxes: [TrackedMailbox]) async throws -> [FetchedMailboxMessage]
}

protocol MicrosoftGraphMailboxClient {
  func fetchMessages(for connection: Microsoft365MailboxConnection) async -> MicrosoftGraphMailboxFetchResult
}

protocol Microsoft365AuthClient {
  func connect(connection: Microsoft365MailboxConnection) async -> Microsoft365AuthResult
  func simulateFailure(connection: Microsoft365MailboxConnection) async -> Microsoft365AuthResult
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
  func fetchMessages(from mailboxes: [TrackedMailbox]) async throws -> [FetchedMailboxMessage] {
    let mailbox = mailboxes.first
    let mailboxID = mailbox?.id ?? UUID()
    let mailboxAddress = mailbox?.address ?? "tracking-intake@parcelops.example"
    return [
      FetchedMailboxMessage(
        providerMessageID: "simulated-\(mailboxID.uuidString)-1001",
        sender: "orders@northline.example",
        subject: "Fwd: Northline Outfitters order NO-44918 shipped",
        receivedDate: "Today 9:15 AM",
        plainTextBodyPreview: "Forwarded order confirmation from Northline Outfitters. Order NO-44918 has shipped with tracking NL4491800123 to 12 Market Street, Melbourne VIC. Original recipient: \(mailboxAddress).",
        sourceMailboxID: mailboxID
      ),
      FetchedMailboxMessage(
        providerMessageID: "simulated-\(mailboxID.uuidString)-1002",
        sender: "dispatch@urbancrate.example",
        subject: "Fwd: Urban Crate order UC-7812 tracking update",
        receivedDate: "Today 10:05 AM",
        plainTextBodyPreview: "Urban Crate order UC-7812 is now in transit. Tracking number UC7812AUS is headed to Level 2, 41 Collins Street, Melbourne VIC. Please review destination details.",
        sourceMailboxID: mailboxID
      )
    ]
  }
}

struct MockMicrosoftGraphMailboxClient: MicrosoftGraphMailboxClient {
  func fetchMessages(for connection: Microsoft365MailboxConnection) async -> MicrosoftGraphMailboxFetchResult {
    if connection.mailboxAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return MicrosoftGraphMailboxFetchResult(
        status: .notConnected,
        messages: [],
        detail: "Mailbox address is missing. This is still a local setup placeholder."
      )
    }

    if connection.connectionStatus.localizedCaseInsensitiveContains("auth") {
      return MicrosoftGraphMailboxFetchResult(
        status: .simulatedAuthPlaceholder,
        messages: [],
        detail: "OAuth is not connected yet. No Microsoft Graph request was made."
      )
    }

    if connection.monitoredFolderNames.localizedCaseInsensitiveContains("empty") {
      return MicrosoftGraphMailboxFetchResult(
        status: .noMessages,
        messages: [],
        detail: "Mock Microsoft Graph client returned no local sample messages for these folders."
      )
    }

    return MicrosoftGraphMailboxFetchResult(
      status: .success,
      messages: [
        MicrosoftGraphFetchedMessage(
          graphMessageID: "mock-graph-\(connection.id.uuidString)-1001",
          sender: "orders@northline.example",
          subject: "Fwd: Northline Outfitters order NO-44918 shipped",
          receivedDate: "Today 9:15 AM",
          plainTextBodyPreview: "Forwarded order confirmation from Northline Outfitters. Order NO-44918 has shipped with tracking NL4491800123 to 12 Market Street, Melbourne VIC. Original recipient: \(connection.mailboxAddress)."
        ),
        MicrosoftGraphFetchedMessage(
          graphMessageID: "mock-graph-\(connection.id.uuidString)-1002",
          sender: "dispatch@urbancrate.example",
          subject: "Fwd: Urban Crate order UC-7812 tracking update",
          receivedDate: "Today 10:05 AM",
          plainTextBodyPreview: "Urban Crate order UC-7812 is now in transit. Tracking number UC7812AUS is headed to Level 2, 41 Collins Street, Melbourne VIC. Please review destination details."
        )
      ],
      detail: "Mock Microsoft Graph client returned deterministic local messages. No network request was made."
    )
  }
}

struct MockMicrosoft365AuthClient: Microsoft365AuthClient {
  func connect(connection: Microsoft365MailboxConnection) async -> Microsoft365AuthResult {
    let missingFields = missingReadinessFields(for: connection)
    if !missingFields.isEmpty {
      return Microsoft365AuthResult(
        status: .notConfigured,
        signedInAccount: "Not signed in",
        detailText: "Mock auth did not start because setup placeholders are missing: \(missingFields.joined(separator: ", ")). No browser sign-in opened and no tokens were requested."
      )
    }

    return Microsoft365AuthResult(
      status: .connected,
      signedInAccount: connection.mailboxAddress,
      detailText: "Mock Microsoft 365 auth succeeded for local UI testing. No OAuth flow ran, no token exchange occurred, Keychain is unused, and Microsoft Graph remains mocked."
    )
  }

  func simulateFailure(connection: Microsoft365MailboxConnection) async -> Microsoft365AuthResult {
    Microsoft365AuthResult(
      status: .authFailed,
      signedInAccount: "Not signed in",
      detailText: "Mock Microsoft 365 auth failed locally for error-state testing. No browser sign-in opened, no tokens were requested or stored, and no network call was made."
    )
  }

  private func missingReadinessFields(for connection: Microsoft365MailboxConnection) -> [String] {
    var missingFields: [String] = []
    if connection.tenantIDPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      missingFields.append("Tenant ID placeholder")
    }
    if connection.clientIDPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      missingFields.append("Client ID placeholder")
    }
    if connection.redirectURIPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      missingFields.append("Redirect URI placeholder")
    }
    if connection.requestedScopesSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      missingFields.append("Requested scopes summary")
    }
    return missingFields
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
