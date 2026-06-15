import Foundation

protocol MailboxIngestionService {
  func fetchMessages(from mailboxes: [TrackedMailbox]) async throws -> [FetchedMailboxMessage]
}

protocol MicrosoftGraphMailboxClient {
  func fetchMessages(for connection: Microsoft365MailboxConnection, accessToken: String?) async -> MicrosoftGraphMailboxFetchResult
}

protocol Microsoft365GraphTokenProvider {
  func acquireMailReadToken(for connection: Microsoft365MailboxConnection) async -> Microsoft365GraphTokenResult
}

protocol Microsoft365AuthClient {
  func connect(connection: Microsoft365MailboxConnection) async -> Microsoft365AuthResult
  func simulateFailure(connection: Microsoft365MailboxConnection) async -> Microsoft365AuthResult
}

protocol Microsoft365TokenStore {
  func simulateReady(for connection: Microsoft365MailboxConnection) async -> Microsoft365TokenStoreResult
  func simulateMissing(for connection: Microsoft365MailboxConnection) async -> Microsoft365TokenStoreResult
  func simulateStorageError(for connection: Microsoft365MailboxConnection) async -> Microsoft365TokenStoreResult
  func simulateClear(for connection: Microsoft365MailboxConnection) async -> Microsoft365TokenStoreResult
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
  func fetchMessages(for connection: Microsoft365MailboxConnection, accessToken: String? = nil) async -> MicrosoftGraphMailboxFetchResult {
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

struct RealMicrosoftGraphMailboxClient: MicrosoftGraphMailboxClient {
  func fetchMessages(for connection: Microsoft365MailboxConnection, accessToken: String?) async -> MicrosoftGraphMailboxFetchResult {
    guard let accessToken, !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return MicrosoftGraphMailboxFetchResult(
        status: .authRequired,
        messages: [],
        detail: "Real Graph refresh needs an in-memory Mail.Read token. No mailbox request was made."
      )
    }

    let folderName = firstConfiguredFolderName(from: connection.monitoredFolderNames)
    guard let folderID = await resolveFolderID(named: folderName, accessToken: accessToken) else {
      return MicrosoftGraphMailboxFetchResult(
        status: .folderNotFound,
        messages: [],
        detail: "Could not resolve mailbox folder '\(folderName)'. No messages were imported and no mailbox items were changed."
      )
    }

    guard let url = messagesURL(path: "https://graph.microsoft.com/v1.0/me/mailFolders/\(folderID)/messages") else {
      return MicrosoftGraphMailboxFetchResult(
        status: .graphRejected,
        messages: [],
        detail: "Could not create the Microsoft Graph messages URL. No mailbox request was made."
      )
    }

    do {
      let primaryResult = try await executeMessagesRequest(url: url, accessToken: accessToken, folderName: folderName, pathLabel: "folder messages")
      let graphResponse: GraphMessagesResponse
      let resultDetail: String
      switch primaryResult {
      case .success(let response):
        graphResponse = response
        resultDetail = "Real Microsoft Graph refresh used /me/mailFolders/{folder}/messages for '\(folderName)'."
      case .failure(let status, let detail) where status == .authRequired:
        guard let fallbackURL = messagesURL(path: "https://graph.microsoft.com/v1.0/me/messages") else {
          return MicrosoftGraphMailboxFetchResult(
            status: .graphRejected,
            messages: [],
            detail: "\(detail)\nCould not create the Microsoft Graph /me/messages fallback URL. No mailbox items were changed."
          )
        }
        let fallbackResult = try await executeMessagesRequest(url: fallbackURL, accessToken: accessToken, folderName: folderName, pathLabel: "fallback /me/messages")
        switch fallbackResult {
        case .success(let response):
          graphResponse = response
          resultDetail = "\(detail)\nFallback result: /me/messages succeeded as a read-only diagnostic path after the folder messages endpoint returned 401."
        case .failure(let fallbackStatus, let fallbackDetail):
          return MicrosoftGraphMailboxFetchResult(
            status: fallbackStatus,
            messages: [],
            detail: "\(detail)\nFallback result: /me/messages also failed.\n\(fallbackDetail)"
          )
        }
      case .failure(let status, let detail):
        return MicrosoftGraphMailboxFetchResult(status: status, messages: [], detail: detail)
      }

      let messages = graphResponse.value.map { message in
        MicrosoftGraphFetchedMessage(
          graphMessageID: message.id,
          sender: message.from?.emailAddress.address ?? message.from?.emailAddress.name ?? "Unknown sender",
          subject: message.subject ?? "(No subject)",
          receivedDate: message.receivedDateTime ?? "Unknown received date",
          plainTextBodyPreview: message.bodyPreview ?? ""
        )
      }

      if messages.isEmpty {
        return MicrosoftGraphMailboxFetchResult(
          status: .noMessages,
          messages: [],
          detail: "\(resultDetail)\nReal Microsoft Graph refresh found no messages. No mailbox items were changed."
        )
      }

      return MicrosoftGraphMailboxFetchResult(
        status: .success,
        messages: messages,
        detail: "\(resultDetail)\nReal Microsoft Graph refresh fetched \(messages.count) message preview\(messages.count == 1 ? "" : "s") using read-only fields. No mailbox items were deleted, moved, marked read, or modified."
      )
    } catch is DecodingError {
      return MicrosoftGraphMailboxFetchResult(status: .parseFailed, messages: [], detail: "Could not parse Microsoft Graph message response. No messages were imported.")
    } catch {
      return MicrosoftGraphMailboxFetchResult(status: .networkFailed, messages: [], detail: "Microsoft Graph message fetch failed: \(safeNetworkError(error)).")
    }
  }

  private func firstConfiguredFolderName(from folderText: String) -> String {
    folderText
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .first { !$0.isEmpty } ?? "Inbox"
  }

  private func resolveFolderID(named folderName: String, accessToken: String) async -> String? {
    if folderName.caseInsensitiveCompare("Inbox") == .orderedSame {
      return "Inbox"
    }

    var components = URLComponents(string: "https://graph.microsoft.com/v1.0/me/mailFolders")
    components?.queryItems = [URLQueryItem(name: "$select", value: "id,displayName")]
    guard let url = components?.url else { return nil }

    do {
      let (data, response) = try await URLSession.shared.data(for: authorizedRequest(url: url, accessToken: accessToken))
      guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else { return nil }
      let folderResponse = try JSONDecoder().decode(GraphFoldersResponse.self, from: data)
      return folderResponse.value.first { $0.displayName.caseInsensitiveCompare(folderName) == .orderedSame }?.id
    } catch {
      return nil
    }
  }

  private func authorizedRequest(url: URL, accessToken: String) -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return request
  }

  private func messagesURL(path: String) -> URL? {
    var components = URLComponents(string: path)
    components?.queryItems = [
      URLQueryItem(name: "$top", value: "10"),
      URLQueryItem(name: "$select", value: "id,subject,receivedDateTime,from,bodyPreview"),
      URLQueryItem(name: "$orderby", value: "receivedDateTime desc")
    ]
    return components?.url
  }

  private func executeMessagesRequest(
    url: URL,
    accessToken: String,
    folderName: String,
    pathLabel: String
  ) async throws -> GraphRequestResult {
    let (data, response) = try await URLSession.shared.data(for: authorizedRequest(url: url, accessToken: accessToken))
    guard let httpResponse = response as? HTTPURLResponse else {
      return .failure(.networkFailed, "Graph \(pathLabel) response was not an HTTP response.")
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      let status = graphStatus(for: httpResponse.statusCode)
      let safeErrorDetail = graphErrorDetail(from: data, response: httpResponse)
      return .failure(
        status,
        "\(graphFailureDetail(status: status, statusCode: httpResponse.statusCode, folderName: folderName, pathLabel: pathLabel))\n\(safeErrorDetail)"
      )
    }
    let graphResponse = try JSONDecoder().decode(GraphMessagesResponse.self, from: data)
    return .success(graphResponse)
  }

  private func graphStatus(for statusCode: Int) -> MicrosoftGraphMailboxFetchStatus {
    switch statusCode {
    case 401: .authRequired
    case 403: .consentRequired
    case 404: .folderNotFound
    default: .graphRejected
    }
  }

  private func graphFailureDetail(status: MicrosoftGraphMailboxFetchStatus, statusCode: Int, folderName: String, pathLabel: String) -> String {
    switch status {
    case .authRequired:
      return "Microsoft Graph \(pathLabel) returned HTTP \(statusCode). Token metadata may look valid, so use the Graph error code/message and 401 challenge metadata below as the source of truth. No mailbox items were changed."
    case .consentRequired:
      return "Microsoft Graph \(pathLabel) returned HTTP \(statusCode). Mail.Read may need user or admin consent in Microsoft Entra, or tenant policy may block mailbox reads. No messages were imported and no mailbox items were changed."
    case .folderNotFound:
      return "Microsoft Graph \(pathLabel) returned HTTP \(statusCode). Folder '\(folderName)' was not found or is not accessible. Use Inbox or check the first monitored folder name. No mailbox items were changed."
    default:
      return "Microsoft Graph \(pathLabel) returned HTTP \(statusCode). Check Graph permissions, selected fields, tenant policy, and mailbox access. No messages were imported and no mailbox items were changed."
    }
  }

  private func graphErrorDetail(from data: Data, response: HTTPURLResponse) -> String {
    let decodedError = (try? JSONDecoder().decode(GraphErrorResponse.self, from: data))?.error
    let code = sanitizedGraphErrorValue(decodedError?.code, fallback: "missing")
    let message = sanitizedGraphErrorValue(decodedError?.message, fallback: "missing")
    let requestID = sanitizedGraphErrorValue(headerValue("request-id", in: response) ?? decodedError?.innerError?.requestID, fallback: "missing")
    let clientRequestID = sanitizedGraphErrorValue(headerValue("client-request-id", in: response) ?? decodedError?.innerError?.clientRequestID, fallback: "missing")
    let responseDate = sanitizedGraphErrorValue(headerValue("date", in: response) ?? decodedError?.innerError?.date, fallback: "missing")

    return [
      "Microsoft Graph error detail:",
      "Graph error code: \(code)",
      "Graph error message: \(message)",
      "Graph request-id: \(requestID)",
      "Graph client-request-id: \(clientRequestID)",
      "Graph response date: \(responseDate)",
      graphChallengeDetail(from: response),
      "Authorization headers, request headers, raw tokens, and full request URLs are not logged."
    ].joined(separator: "\n")
  }

  private func graphChallengeDetail(from response: HTTPURLResponse) -> String {
    guard let header = headerValue("WWW-Authenticate", in: response) else {
      return "WWW-Authenticate challenge: missing"
    }
    let values = parsedAuthenticateValues(from: header)
    let error = sanitizedGraphErrorValue(values["error"], fallback: "missing")
    let description = sanitizedGraphErrorValue(values["error_description"], fallback: "missing")
    let authorizationURI = sanitizedGraphErrorValue(values["authorization_uri"], fallback: "missing")
    let realm = sanitizedGraphErrorValue(values["realm"], fallback: "missing")
    let hasClaims = values["claims"]?.isEmpty == false || header.localizedCaseInsensitiveContains("claims=")
    let lowerHeader = header.lowercased()
    return [
      "WWW-Authenticate challenge:",
      "Challenge error: \(error)",
      "Challenge description: \(description)",
      "Challenge authorization URI: \(authorizationURI)",
      "Challenge realm: \(realm)",
      "Challenge has claims: \(hasClaims ? "yes" : "no")",
      "Challenge indicates invalid_token: \(lowerHeader.contains("invalid_token") ? "yes" : "no")",
      "Challenge indicates insufficient_claims: \(lowerHeader.contains("insufficient_claims") ? "yes" : "no")",
      "Challenge indicates conditional access: \(lowerHeader.contains("conditional") || lowerHeader.contains("claims=") ? "yes" : "no")",
      "Challenge indicates tenant mismatch: \(lowerHeader.contains("tenant") || lowerHeader.contains("realm") ? "yes" : "no")",
      "Challenge indicates audience/scope issue: \(lowerHeader.contains("audience") || lowerHeader.contains("scope") ? "yes" : "no")"
    ].joined(separator: "\n")
  }

  private func parsedAuthenticateValues(from header: String) -> [String: String] {
    let pattern = #"([A-Za-z0-9_\-]+)="([^"]*)""#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [:] }
    let range = NSRange(header.startIndex..<header.endIndex, in: header)
    var values: [String: String] = [:]
    regex.enumerateMatches(in: header, range: range) { match, _, _ in
      guard let match,
            match.numberOfRanges >= 3,
            let keyRange = Range(match.range(at: 1), in: header),
            let valueRange = Range(match.range(at: 2), in: header) else { return }
      values[String(header[keyRange]).lowercased()] = String(header[valueRange])
    }
    return values
  }

  private func headerValue(_ key: String, in response: HTTPURLResponse) -> String? {
    response.allHeaderFields.first { header, _ in
      String(describing: header).caseInsensitiveCompare(key) == .orderedSame
    }.map { String(describing: $0.value) }
  }

  private func sanitizedGraphErrorValue(_ value: String?, fallback: String) -> String {
    let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return fallback }
    return String(trimmed.prefix(600))
  }

  private func safeNetworkError(_ error: Error) -> String {
    let description = error.localizedDescription
    return description.isEmpty ? "network request failed" : description
  }

  private struct GraphMessagesResponse: Decodable {
    var value: [GraphMessage]
  }

  private enum GraphRequestResult {
    case success(GraphMessagesResponse)
    case failure(MicrosoftGraphMailboxFetchStatus, String)
  }

  private struct GraphMessage: Decodable {
    var id: String
    var subject: String?
    var receivedDateTime: String?
    var from: GraphRecipient?
    var bodyPreview: String?
  }

  private struct GraphRecipient: Decodable {
    var emailAddress: GraphEmailAddress
  }

  private struct GraphEmailAddress: Decodable {
    var name: String?
    var address: String?
  }

  private struct GraphFoldersResponse: Decodable {
    var value: [GraphFolder]
  }

  private struct GraphFolder: Decodable {
    var id: String
    var displayName: String
  }

  private struct GraphErrorResponse: Decodable {
    var error: GraphError
  }

  private struct GraphError: Decodable {
    var code: String?
    var message: String?
    var innerError: GraphInnerError?

    enum CodingKeys: String, CodingKey {
      case code
      case message
      case innerError = "innerError"
    }
  }

  private struct GraphInnerError: Decodable {
    var date: String?
    var requestID: String?
    var clientRequestID: String?

    enum CodingKeys: String, CodingKey {
      case date
      case requestID = "request-id"
      case clientRequestID = "client-request-id"
    }
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

struct MockMicrosoft365TokenStore: Microsoft365TokenStore {
  func simulateReady(for connection: Microsoft365MailboxConnection) async -> Microsoft365TokenStoreResult {
    Microsoft365TokenStoreResult(
      status: .mockTokenReferenceAvailable,
      detailText: "Mock token reference available for \(connection.displayName). No access token, refresh token, auth code, client secret, password, or Keychain item was created, read, written, or deleted."
    )
  }

  func simulateMissing(for connection: Microsoft365MailboxConnection) async -> Microsoft365TokenStoreResult {
    Microsoft365TokenStoreResult(
      status: .tokenMissing,
      detailText: "Mock token lookup reports no token reference for \(connection.displayName). This is local status only; Keychain was not read."
    )
  }

  func simulateStorageError(for connection: Microsoft365MailboxConnection) async -> Microsoft365TokenStoreResult {
    Microsoft365TokenStoreResult(
      status: .storageErrorSimulated,
      detailText: "Mock token storage error for \(connection.displayName). No Keychain API was called and no secret value was handled."
    )
  }

  func simulateClear(for connection: Microsoft365MailboxConnection) async -> Microsoft365TokenStoreResult {
    Microsoft365TokenStoreResult(
      status: .tokenClearSimulated,
      detailText: "Mock token reference clear simulated for \(connection.displayName). No Keychain item, access token, or refresh token was deleted."
    )
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
