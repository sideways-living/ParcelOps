import Foundation
import Network
import Security

protocol MailboxIngestionService {
  func fetchMessages(from mailboxes: [TrackedMailbox]) async throws -> [FetchedMailboxMessage]
}

protocol MicrosoftGraphMailboxClient {
  func fetchMessages(for connection: Microsoft365MailboxConnection, accessToken: String?) async -> MicrosoftGraphMailboxFetchResult
}

protocol SpaceMailIMAPClient {
  func fetchMessages(for connection: SpaceMailIMAPConnection, sourceMailboxID: UUID, password: String?) async -> SpaceMailIMAPFetchResult
}

protocol SpaceMailCredentialStore {
  func savePassword(_ password: String, for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialStoreResult
  func loadPassword(for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialLoadResult
  func checkPassword(for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialStoreResult
  func clearPassword(for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialStoreResult
  func simulateReady(for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialStoreResult
  func simulateMissing(for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialStoreResult
  func simulateStorageError(for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialStoreResult
  func simulateClear(for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialStoreResult
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

struct MockSpaceMailIMAPClient: SpaceMailIMAPClient {
  func fetchMessages(for connection: SpaceMailIMAPConnection, sourceMailboxID: UUID, password: String? = nil) async -> SpaceMailIMAPFetchResult {
    if connection.emailAddressUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        connection.imapHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        connection.imapPort.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        connection.folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return SpaceMailIMAPFetchResult(
        status: .notConfigured,
        messages: [],
        detail: "SpaceMail IMAP setup is missing mailbox, host, port, or folder. No real IMAP connection was made."
      )
    }

    if connection.credentialStorageStatus.localizedCaseInsensitiveContains("missing") ||
        connection.credentialStorageStatus.localizedCaseInsensitiveContains("required") {
      return SpaceMailIMAPFetchResult(
        status: .credentialMissing,
        messages: [],
        detail: "Mock SpaceMail IMAP client reports credentials are missing. No password was requested or stored, and no real Keychain item was read by the mock refresh."
      )
    }

    if connection.connectionStatus.localizedCaseInsensitiveContains("connection failed") {
      return SpaceMailIMAPFetchResult(
        status: .connectionFailedSimulated,
        messages: [],
        detail: "Mock SpaceMail IMAP client simulated a connection failure. No network request was made."
      )
    }

    if connection.folderName.localizedCaseInsensitiveContains("missing") ||
        connection.folderName.localizedCaseInsensitiveContains("not found") {
      return SpaceMailIMAPFetchResult(
        status: .folderNotFoundSimulated,
        messages: [],
        detail: "Mock SpaceMail IMAP client simulated a missing folder for '\(connection.folderName)'. No mailbox was contacted."
      )
    }

    if connection.connectionStatus.localizedCaseInsensitiveContains("parse failed") {
      return SpaceMailIMAPFetchResult(
        status: .parseFailedSimulated,
        messages: [],
        detail: "Mock SpaceMail IMAP client simulated a message parse failure. No mailbox data was read."
      )
    }

    if connection.folderName.localizedCaseInsensitiveContains("empty") {
      return SpaceMailIMAPFetchResult(
        status: .noMessages,
        messages: [],
        detail: "Mock SpaceMail IMAP client returned no local sample messages for folder '\(connection.folderName)'."
      )
    }

    let messages = [
      FetchedMailboxMessage(
        providerMessageID: "spacemail-imap-\(connection.id.uuidString)-uid-1001",
        sender: "orders@northline.example",
        subject: "Fwd: Northline Outfitters order NO-44918 shipped",
        receivedDate: "Today 9:15 AM",
        plainTextBodyPreview: "Mock SpaceMail IMAP message from \(connection.folderName). Forwarded order confirmation from Northline Outfitters. Order NO-44918 has shipped with tracking NL4491800123 to 12 Market Street, Melbourne VIC. Original recipient: \(connection.emailAddressUsername).",
        sourceMailboxID: sourceMailboxID
      ),
      FetchedMailboxMessage(
        providerMessageID: "spacemail-imap-\(connection.id.uuidString)-uid-1002",
        sender: "dispatch@urbancrate.example",
        subject: "Fwd: Urban Crate order UC-7812 tracking update",
        receivedDate: "Today 10:05 AM",
        plainTextBodyPreview: "Mock SpaceMail IMAP message from \(connection.folderName). Urban Crate order UC-7812 is now in transit. Tracking number UC7812AUS is headed to Level 2, 41 Collins Street, Melbourne VIC. Please review destination details.",
        sourceMailboxID: sourceMailboxID
      )
    ]

    return SpaceMailIMAPFetchResult(
      status: .success,
      messages: messages,
      detail: "Mock SpaceMail IMAP client returned deterministic local messages through the provider-neutral intake model. No real IMAP connection was made, no password was requested or stored, Keychain was not used by the mock refresh, and no mailbox items were deleted, moved, marked read, sent, or modified."
    )
  }
}

struct RealSpaceMailIMAPClient: SpaceMailIMAPClient {
  func fetchMessages(for connection: SpaceMailIMAPConnection, sourceMailboxID: UUID, password: String? = nil) async -> SpaceMailIMAPFetchResult {
    let emailAddress = connection.emailAddressUsername.trimmingCharacters(in: .whitespacesAndNewlines)
    let host = connection.imapHost.trimmingCharacters(in: .whitespacesAndNewlines)
    let portText = connection.imapPort.trimmingCharacters(in: .whitespacesAndNewlines)
    let securityMode = connection.securityMode.trimmingCharacters(in: .whitespacesAndNewlines)
    let folderName = connection.folderName.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !emailAddress.isEmpty, !host.isEmpty, !portText.isEmpty, !folderName.isEmpty else {
      return SpaceMailIMAPFetchResult(
        status: .notConfigured,
        messages: [],
        detail: "Real SpaceMail IMAP refresh needs email/username, IMAP host, port, and folder before any connection can be attempted. No network request was made."
      )
    }

    guard let port = Int(portText), (1...65535).contains(port) else {
      return SpaceMailIMAPFetchResult(
        status: .notConfigured,
        messages: [],
        detail: "Real SpaceMail IMAP refresh needs a valid numeric IMAP port. Use 993 for SpaceMail SSL/TLS. No network request was made."
      )
    }

    guard securityMode.localizedCaseInsensitiveContains("ssl") ||
        securityMode.localizedCaseInsensitiveContains("tls") else {
      return SpaceMailIMAPFetchResult(
        status: .connectionFailed,
        messages: [],
        detail: "Real SpaceMail IMAP refresh currently requires SSL/TLS. Update the connection security mode before retrying. No mailbox login was attempted."
      )
    }

    guard connection.credentialStorageStatus == SpaceMailCredentialStoreStatus.passwordReferenceAvailable.rawValue ||
        connection.credentialStorageStatus.localizedCaseInsensitiveContains("reference available") else {
      return SpaceMailIMAPFetchResult(
        status: .credentialMissing,
        messages: [],
        detail: "Real SpaceMail IMAP refresh stopped before login because no password or app-password reference is available. ParcelOps did not prompt for, store, read, or log a password, and no mailbox item was touched."
      )
    }

    guard let password, !password.isEmpty else {
      return SpaceMailIMAPFetchResult(
        status: .credentialMissing,
        messages: [],
        detail: "Real SpaceMail IMAP refresh found a credential reference label but no in-memory password was available from Keychain. No mailbox login was attempted."
      )
    }

    do {
      let session = SpaceMailIMAPSession(host: host, port: port)
      let messages = try await session.fetchRecentMessages(
        username: emailAddress,
        password: password,
        folderName: folderName,
        sourceMailboxID: sourceMailboxID,
        connectionID: connection.id,
        limit: 10
      )
      return SpaceMailIMAPFetchResult(
        status: messages.isEmpty ? .noMessages : .success,
        messages: messages,
        detail: "Real SpaceMail IMAP refresh connected over SSL/TLS, authenticated, selected folder '\(folderName)' read-only with EXAMINE, and fetched \(messages.count) recent message previews using BODY.PEEK. No password, auth string, server challenge, or full message body was logged or stored. No mailbox item was deleted, moved, marked read, flagged, sent, or modified."
      )
    } catch SpaceMailIMAPSessionError.authFailed {
      return SpaceMailIMAPFetchResult(
        status: .authFailed,
        messages: [],
        detail: "Real SpaceMail IMAP login failed. Check the SpaceMail username and app password. The password and server authentication details were not logged or stored."
      )
    } catch SpaceMailIMAPSessionError.folderNotFound {
      return SpaceMailIMAPFetchResult(
        status: .folderNotFound,
        messages: [],
        detail: "Real SpaceMail IMAP connected and authenticated, but the configured folder '\(folderName)' could not be selected read-only. No mailbox messages were fetched or modified."
      )
    } catch SpaceMailIMAPSessionError.timedOut(let phase) {
      return SpaceMailIMAPFetchResult(
        status: .connectionFailed,
        messages: [],
        detail: "Real SpaceMail IMAP refresh timed out during \(phase). No password, auth string, server challenge, full message body, or mailbox mutation was logged or stored."
      )
    } catch SpaceMailIMAPSessionError.parseFailed(let detail) {
      return SpaceMailIMAPFetchResult(
        status: .parseFailed,
        messages: [],
        detail: "Real SpaceMail IMAP fetched a response but could not safely parse message previews. \(detail) No credentials or full message bodies were logged."
      )
    } catch {
      return SpaceMailIMAPFetchResult(
        status: .connectionFailed,
        messages: [],
        detail: "Real SpaceMail IMAP connection or fetch failed before import. \(SpaceMailIMAPSession.safeErrorSummary(error)) No password, auth string, server challenge, or mailbox mutation was logged or stored."
      )
    }
  }
}

private enum SpaceMailIMAPSessionError: Error {
  case connectionFailed(String)
  case authFailed
  case folderNotFound
  case timedOut(String)
  case parseFailed(String)
}

private final class SpaceMailIMAPSession: @unchecked Sendable {
  private let host: String
  private let port: Int
  private let queue = DispatchQueue(label: "ParcelOps.SpaceMailIMAPSession")
  private var connection: NWConnection?
  private var commandIndex = 0

  private final class ResumeState {
    var didResume = false
  }

  init(host: String, port: Int) {
    self.host = host
    self.port = port
  }

  func fetchRecentMessages(
    username: String,
    password: String,
    folderName: String,
    sourceMailboxID: UUID,
    connectionID: UUID,
    limit: Int
  ) async throws -> [FetchedMailboxMessage] {
    defer { close() }
    try await withTimeout("TLS connect") {
      try await self.connect()
    }
    _ = try await withTimeout("greeting read") {
      try await self.readUntilLinePrefix("*")
    }
    _ = try await withTimeout("login") {
      try await self.sendCommand("LOGIN \(self.quote(username)) \(self.quote(password))", failure: .authFailed)
    }
    _ = try await withTimeout("folder EXAMINE") {
      try await self.sendCommand("EXAMINE \(self.quote(folderName))", failure: .folderNotFound)
    }
    let searchResponse = try await withTimeout("UID SEARCH") {
      try await self.sendCommand("UID SEARCH ALL", failure: .parseFailed("UID SEARCH did not complete."))
    }
    let uids = parseUIDSearch(searchResponse).suffix(limit)
    guard !uids.isEmpty else {
      _ = try? await withTimeout("logout", seconds: 8) {
        try await self.sendCommand("LOGOUT", failure: .connectionFailed("Logout failed."))
      }
      return []
    }

    let uidList = uids.joined(separator: ",")
    let fetchResponse = try await withTimeout("UID FETCH") {
      try await self.sendCommand("UID FETCH \(uidList) (UID BODY.PEEK[]<0.4096>)", failure: .parseFailed("UID FETCH did not complete."))
    }
    _ = try? await withTimeout("logout", seconds: 8) {
      try await self.sendCommand("LOGOUT", failure: .connectionFailed("Logout failed."))
    }
    return parseFetchedMessages(fetchResponse, folderName: folderName, sourceMailboxID: sourceMailboxID, connectionID: connectionID)
  }

  static func safeErrorSummary(_ error: Error) -> String {
    if let imapError = error as? SpaceMailIMAPSessionError {
      switch imapError {
      case .connectionFailed(let detail): return detail
      case .authFailed: return "Authentication failed."
      case .folderNotFound: return "Folder not found."
      case .timedOut(let phase): return "Timed out during \(phase)."
      case .parseFailed(let detail): return detail
      }
    }
    return "The IMAP session ended unexpectedly."
  }

  private func connect() async throws {
    let tls = NWProtocolTLS.Options()
    let parameters = NWParameters(tls: tls)
    let endpointHost = NWEndpoint.Host(host)
    guard let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
      throw SpaceMailIMAPSessionError.connectionFailed("Invalid IMAP port.")
    }
    let connection = NWConnection(host: endpointHost, port: endpointPort, using: parameters)
    self.connection = connection

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      let lock = NSLock()
      let resumeState = ResumeState()
      connection.stateUpdateHandler = { state in
        lock.lock()
        defer { lock.unlock() }
        guard !resumeState.didResume else { return }
        switch state {
        case .ready:
          resumeState.didResume = true
          continuation.resume()
        case .failed:
          resumeState.didResume = true
          continuation.resume(throwing: SpaceMailIMAPSessionError.connectionFailed("TLS connection failed."))
        case .waiting:
          break
        default:
          break
        }
      }
      connection.start(queue: queue)
    }
  }

  private func withTimeout<T>(
    _ phase: String,
    seconds: UInt64 = 20,
    operation: @escaping @Sendable () async throws -> T
  ) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
      group.addTask {
        try await operation()
      }
      group.addTask {
        try await Task.sleep(for: .seconds(seconds))
        throw SpaceMailIMAPSessionError.timedOut(phase)
      }
      guard let result = try await group.next() else {
        throw SpaceMailIMAPSessionError.timedOut(phase)
      }
      group.cancelAll()
      return result
    }
  }

  private func sendCommand(_ command: String, failure: SpaceMailIMAPSessionError) async throws -> String {
    commandIndex += 1
    let tag = "A\(String(format: "%03d", commandIndex))"
    guard let data = "\(tag) \(command)\r\n".data(using: .utf8), let connection else {
      throw SpaceMailIMAPSessionError.connectionFailed("IMAP command could not be encoded.")
    }

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      connection.send(content: data, completion: .contentProcessed { error in
        if error != nil {
          continuation.resume(throwing: SpaceMailIMAPSessionError.connectionFailed("IMAP command send failed."))
        } else {
          continuation.resume()
        }
      })
    }

    let response = try await readUntilTagged(tag)
    guard let taggedLine = response
      .components(separatedBy: .newlines)
      .last(where: { $0.hasPrefix("\(tag) ") }) else {
      throw failure
    }
    if taggedLine.localizedCaseInsensitiveContains("\(tag) OK") {
      return response
    }
    throw failure
  }

  private func readUntilLinePrefix(_ prefix: String) async throws -> String {
    var response = ""
    while !response.components(separatedBy: .newlines).contains(where: { $0.hasPrefix(prefix) }) {
      response += try await receiveChunk()
    }
    return response
  }

  private func readUntilTagged(_ tag: String) async throws -> String {
    var response = ""
    while !response.components(separatedBy: .newlines).contains(where: { $0.hasPrefix("\(tag) ") }) {
      response += try await receiveChunk()
    }
    return response
  }

  private func receiveChunk() async throws -> String {
    guard let connection else {
      throw SpaceMailIMAPSessionError.connectionFailed("IMAP connection was not open.")
    }
    return try await withCheckedThrowingContinuation { continuation in
      connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
        if error != nil {
          continuation.resume(throwing: SpaceMailIMAPSessionError.connectionFailed("IMAP receive failed."))
        } else if let data, !data.isEmpty {
          continuation.resume(returning: String(decoding: data, as: UTF8.self))
        } else if isComplete {
          continuation.resume(throwing: SpaceMailIMAPSessionError.connectionFailed("IMAP connection closed."))
        } else {
          continuation.resume(returning: "")
        }
      }
    }
  }

  private func close() {
    connection?.cancel()
    connection = nil
  }

  private func quote(_ value: String) -> String {
    "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
  }

  private func parseUIDSearch(_ response: String) -> [String] {
    response
      .components(separatedBy: .newlines)
      .first(where: { $0.localizedCaseInsensitiveContains("* SEARCH") })?
      .components(separatedBy: .whitespaces)
      .filter { !$0.isEmpty && Int($0) != nil } ?? []
  }

  private func parseFetchedMessages(_ response: String, folderName: String, sourceMailboxID: UUID, connectionID: UUID) -> [FetchedMailboxMessage] {
    response
      .components(separatedBy: "\r\n* ")
      .compactMap { rawPart -> FetchedMailboxMessage? in
        let part = rawPart.hasPrefix("* ") ? rawPart : "* \(rawPart)"
        guard part.localizedCaseInsensitiveContains("FETCH") else { return nil }
        guard let uid = firstMatch(in: part, pattern: #"UID\s+([0-9]+)"#) else { return nil }
        let messageID = headerValue("Message-ID", in: part)
        let providerID = providerMessageID(messageID: messageID, uid: uid, folderName: folderName, connectionID: connectionID)
        return FetchedMailboxMessage(
          providerMessageID: providerID,
          sender: headerValue("From", in: part) ?? "Unknown sender",
          subject: headerValue("Subject", in: part) ?? "No subject",
          receivedDate: headerValue("Date", in: part) ?? "Unknown date",
          plainTextBodyPreview: bodyPreview(from: part),
          sourceMailboxID: sourceMailboxID
        )
      }
  }

  private func headerValue(_ name: String, in text: String) -> String? {
    let unfolded = text.replacingOccurrences(of: "\r\n\t", with: " ").replacingOccurrences(of: "\r\n ", with: " ")
    let escaped = NSRegularExpression.escapedPattern(for: name)
    guard let match = firstMatch(in: unfolded, pattern: #"(?im)^\#(escaped):\s*(.+)$"#) else { return nil }
    return sanitizeHeader(match)
  }

  private func bodyPreview(from text: String) -> String {
    let split = text.components(separatedBy: "\r\n\r\n")
    let body = split.count > 1 ? split.dropFirst().joined(separator: "\n") : text
    let cleaned = body
      .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return String(cleaned.prefix(700))
  }

  private func providerMessageID(messageID: String?, uid: String, folderName: String, connectionID: UUID) -> String {
    let stableID = messageID?
      .trimmingCharacters(in: CharacterSet(charactersIn: "<> "))
      .replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
    if let stableID, !stableID.isEmpty {
      return "spacemail-imap-\(connectionID.uuidString)-message-\(stableID)"
    }
    let safeFolder = folderName.replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression).lowercased()
    return "spacemail-imap-\(connectionID.uuidString)-\(safeFolder)-uid-\(uid)"
  }

  private func firstMatch(in text: String, pattern: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else { return nil }
    guard let swiftRange = Range(match.range(at: 1), in: text) else { return nil }
    return String(text[swiftRange])
  }

  private func sanitizeHeader(_ value: String) -> String {
    value
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

struct MockSpaceMailCredentialStore: SpaceMailCredentialStore {
  func savePassword(_ password: String, for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialStoreResult {
    SpaceMailCredentialStoreResult(
      status: password.isEmpty ? .passwordMissing : .passwordReferenceAvailable,
      detailText: password.isEmpty
        ? "Mock credential save received an empty password for \(connection.displayName). No secret value was stored."
        : "Mock credential save recorded a non-secret password-reference status for \(connection.displayName). No password value was stored or logged."
    )
  }

  func loadPassword(for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialLoadResult {
    SpaceMailCredentialLoadResult(
      status: .passwordMissing,
      password: nil,
      detailText: "Mock credential load has no password for \(connection.displayName). No secret value was read."
    )
  }

  func checkPassword(for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialStoreResult {
    SpaceMailCredentialStoreResult(
      status: .passwordMissing,
      detailText: "Mock credential check found no password reference for \(connection.displayName). No secret value was read."
    )
  }

  func clearPassword(for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialStoreResult {
    SpaceMailCredentialStoreResult(
      status: .passwordClearSimulated,
      detailText: "Mock credential clear recorded a clear status for \(connection.displayName). No secret value was deleted."
    )
  }

  func simulateReady(for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialStoreResult {
    SpaceMailCredentialStoreResult(
      status: .passwordReferenceAvailable,
      detailText: "Mock password reference available for \(connection.displayName). No password, app password, auth string, server credential, or Keychain item was created, read, written, deleted, stored in JSON, or logged."
    )
  }

  func simulateMissing(for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialStoreResult {
    SpaceMailCredentialStoreResult(
      status: .passwordMissing,
      detailText: "Mock credential lookup reports no password reference for \(connection.displayName). No password prompt opened, no Keychain API was called, and no secret value was handled."
    )
  }

  func simulateStorageError(for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialStoreResult {
    SpaceMailCredentialStoreResult(
      status: .storageErrorSimulated,
      detailText: "Mock credential storage error for \(connection.displayName). This is a local error-state simulation only; no Keychain item or password value was touched."
    )
  }

  func simulateClear(for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialStoreResult {
    SpaceMailCredentialStoreResult(
      status: .passwordClearSimulated,
      detailText: "Mock password reference clear simulated for \(connection.displayName). No Keychain item, IMAP password, app password, or auth string was deleted."
    )
  }
}

struct KeychainSpaceMailCredentialStore: SpaceMailCredentialStore {
  private let service = "app.bitrig.parcelops.spacemail.imap"

  func savePassword(_ password: String, for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialStoreResult {
    let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedPassword.isEmpty else {
      return SpaceMailCredentialStoreResult(
        status: .passwordMissing,
        detailText: "No SpaceMail password was saved because the secure password field was empty. No Keychain item was created or updated."
      )
    }

    guard let passwordData = password.data(using: .utf8) else {
      return SpaceMailCredentialStoreResult(
        status: .storageErrorSimulated,
        detailText: "SpaceMail password could not be prepared for Keychain storage. The password value was not logged or stored in JSON."
      )
    }

    let query = baseQuery(for: connection)
    SecItemDelete(query as CFDictionary)

    var attributes = query
    attributes[kSecValueData as String] = passwordData
    #if os(iOS)
    attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    #endif

    let status = SecItemAdd(attributes as CFDictionary, nil)
    guard status == errSecSuccess else {
      return SpaceMailCredentialStoreResult(
        status: .storageErrorSimulated,
        detailText: "SpaceMail password reference could not be saved to Keychain. Keychain status: \(status). No password value was stored in JSON or logged."
      )
    }

    return SpaceMailCredentialStoreResult(
      status: .passwordReferenceAvailable,
      detailText: "SpaceMail password reference saved in Keychain for \(safeAccountLabel(for: connection)). ParcelOps stored only this non-secret status in JSON and audit logs."
    )
  }

  func loadPassword(for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialLoadResult {
    var query = baseQuery(for: connection)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound {
      return SpaceMailCredentialLoadResult(
        status: .passwordMissing,
        password: nil,
        detailText: "No SpaceMail password reference exists in Keychain for \(safeAccountLabel(for: connection))."
      )
    }
    guard status == errSecSuccess, let data = item as? Data, let password = String(data: data, encoding: .utf8) else {
      return SpaceMailCredentialLoadResult(
        status: .storageErrorSimulated,
        password: nil,
        detailText: "SpaceMail password reference could not be loaded from Keychain. Keychain status: \(status). No password value was logged or stored in JSON."
      )
    }

    return SpaceMailCredentialLoadResult(
      status: .passwordReferenceAvailable,
      password: password,
      detailText: "SpaceMail password reference is available in Keychain for \(safeAccountLabel(for: connection)). The password value was loaded only into memory for this manual operation and was not logged or stored in JSON."
    )
  }

  func checkPassword(for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialStoreResult {
    var query = baseQuery(for: connection)
    query[kSecReturnData as String] = false
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    let status = SecItemCopyMatching(query as CFDictionary, nil)
    if status == errSecSuccess {
      return SpaceMailCredentialStoreResult(
        status: .passwordReferenceAvailable,
        detailText: "SpaceMail password reference exists in Keychain for \(safeAccountLabel(for: connection)). No password value was read, logged, or stored in JSON."
      )
    }
    if status == errSecItemNotFound {
      return SpaceMailCredentialStoreResult(
        status: .passwordMissing,
        detailText: "No SpaceMail password reference exists in Keychain for \(safeAccountLabel(for: connection))."
      )
    }
    return SpaceMailCredentialStoreResult(
      status: .storageErrorSimulated,
      detailText: "SpaceMail Keychain credential check failed. Keychain status: \(status). No password value was read, logged, or stored in JSON."
    )
  }

  func clearPassword(for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialStoreResult {
    let status = SecItemDelete(baseQuery(for: connection) as CFDictionary)
    if status == errSecSuccess || status == errSecItemNotFound {
      return SpaceMailCredentialStoreResult(
        status: .passwordCleared,
        detailText: "SpaceMail password reference cleared from Keychain for \(safeAccountLabel(for: connection)). No password value was logged or stored in JSON."
      )
    }
    return SpaceMailCredentialStoreResult(
      status: .storageErrorSimulated,
      detailText: "SpaceMail password reference could not be cleared from Keychain. Keychain status: \(status). No password value was logged or stored in JSON."
    )
  }

  func simulateReady(for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialStoreResult {
    SpaceMailCredentialStoreResult(
      status: .passwordReferenceAvailable,
      detailText: "Mock password reference available for \(connection.displayName). No password, app password, auth string, server credential, or Keychain item was created, read, written, deleted, stored in JSON, or logged."
    )
  }

  func simulateMissing(for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialStoreResult {
    SpaceMailCredentialStoreResult(
      status: .passwordMissing,
      detailText: "Mock credential lookup reports no password reference for \(connection.displayName). No password prompt opened, no Keychain API was called, and no secret value was handled."
    )
  }

  func simulateStorageError(for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialStoreResult {
    SpaceMailCredentialStoreResult(
      status: .storageErrorSimulated,
      detailText: "Mock credential storage error for \(connection.displayName). This is a local error-state simulation only; no Keychain item or password value was touched."
    )
  }

  func simulateClear(for connection: SpaceMailIMAPConnection) async -> SpaceMailCredentialStoreResult {
    SpaceMailCredentialStoreResult(
      status: .passwordClearSimulated,
      detailText: "Mock password reference clear simulated for \(connection.displayName). No Keychain item, IMAP password, app password, or auth string was deleted."
    )
  }

  private func baseQuery(for connection: SpaceMailIMAPConnection) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: accountKey(for: connection)
    ]
  }

  private func accountKey(for connection: SpaceMailIMAPConnection) -> String {
    "\(connection.id.uuidString)|\(connection.emailAddressUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
  }

  private func safeAccountLabel(for connection: SpaceMailIMAPConnection) -> String {
    connection.emailAddressUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? connection.displayName
      : connection.emailAddressUsername
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

    let identityProbeDetail: String
    do {
      let identityProbe = try await executeIdentityProbe(accessToken: accessToken, connection: connection)
      switch identityProbe {
      case .success(let detail):
        identityProbeDetail = detail
      case .failure(let status, let detail):
        return MicrosoftGraphMailboxFetchResult(
          status: status,
          messages: [],
          detail: "\(detail)\nIdentity Graph access did not succeed, so mailbox message fetch was not attempted. If this is HTTP 401, the token/request is being rejected generally by Microsoft Graph despite valid-looking token metadata."
        )
      }
    } catch is DecodingError {
      return MicrosoftGraphMailboxFetchResult(status: .parseFailed, messages: [], detail: "Could not parse Microsoft Graph /me probe response. No mailbox fetch was attempted.")
    } catch {
      return MicrosoftGraphMailboxFetchResult(status: .networkFailed, messages: [], detail: "Microsoft Graph /me probe failed: \(safeNetworkError(error)). No mailbox fetch was attempted.")
    }

    let folderName = firstConfiguredFolderName(from: connection.monitoredFolderNames)
    guard let folderID = await resolveFolderID(named: folderName, accessToken: accessToken) else {
      return MicrosoftGraphMailboxFetchResult(
        status: .folderNotFound,
        messages: [],
        detail: "\(identityProbeDetail)\nCould not resolve mailbox folder '\(folderName)'. Identity Graph access works, but mailbox folder access is blocked or unavailable. No messages were imported and no mailbox items were changed."
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
        resultDetail = "\(identityProbeDetail)\nReal Microsoft Graph refresh used /me/mailFolders/{folder}/messages for '\(folderName)'."
      case .failure(let status, let detail) where status == .authRequired:
        guard let fallbackURL = messagesURL(path: "https://graph.microsoft.com/v1.0/me/messages") else {
          return MicrosoftGraphMailboxFetchResult(
            status: .graphRejected,
            messages: [],
            detail: "\(identityProbeDetail)\n\(detail)\nCould not create the Microsoft Graph /me/messages fallback URL. Identity Graph access works, but mailbox Graph access is blocked. No mailbox items were changed."
          )
        }
        let fallbackResult = try await executeMessagesRequest(url: fallbackURL, accessToken: accessToken, folderName: folderName, pathLabel: "fallback /me/messages")
        switch fallbackResult {
        case .success(let response):
          graphResponse = response
          resultDetail = "\(identityProbeDetail)\n\(detail)\nFallback result: /me/messages succeeded as a read-only diagnostic path after the folder messages endpoint returned 401."
        case .failure(let fallbackStatus, let fallbackDetail):
          return MicrosoftGraphMailboxFetchResult(
            status: fallbackStatus,
            messages: [],
            detail: "\(identityProbeDetail)\n\(detail)\nFallback result: /me/messages also failed.\n\(fallbackDetail)\nIdentity Graph access works, but mailbox Graph access is blocked or challenged."
          )
        }
      case .failure(let status, let detail):
        return MicrosoftGraphMailboxFetchResult(
          status: status,
          messages: [],
          detail: "\(identityProbeDetail)\n\(detail)\nIdentity Graph access works, but mailbox Graph access is blocked or challenged."
        )
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

  private func meProbeURL() -> URL? {
    var components = URLComponents(string: "https://graph.microsoft.com/v1.0/me")
    components?.queryItems = [
      URLQueryItem(name: "$select", value: "id,displayName,userPrincipalName,mail")
    ]
    return components?.url
  }

  private func executeIdentityProbe(accessToken: String, connection: Microsoft365MailboxConnection) async throws -> GraphIdentityProbeResult {
    guard let url = meProbeURL() else {
      return .failure(.graphRejected, "Could not create the Microsoft Graph /me probe URL. No mailbox fetch was attempted.")
    }

    let (data, response) = try await URLSession.shared.data(for: authorizedRequest(url: url, accessToken: accessToken))
    guard let httpResponse = response as? HTTPURLResponse else {
      return .failure(.networkFailed, "Microsoft Graph /me probe response was not an HTTP response. No mailbox fetch was attempted.")
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      let status = graphStatus(for: httpResponse.statusCode)
      return .failure(
        status,
        "\(identityProbeFailureDetail(status: status, statusCode: httpResponse.statusCode))\n\(graphErrorDetail(from: data, response: httpResponse))"
      )
    }

    let profile = try JSONDecoder().decode(GraphMeResponse.self, from: data)
    return .success(identityProbeSuccessDetail(for: profile, connection: connection))
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

  private func identityProbeFailureDetail(status: MicrosoftGraphMailboxFetchStatus, statusCode: Int) -> String {
    switch status {
    case .authRequired:
      return "Microsoft Graph /me probe returned HTTP \(statusCode). The token/request is being rejected generally by Microsoft Graph despite valid-looking token metadata. No mailbox fetch was attempted."
    case .consentRequired:
      return "Microsoft Graph /me probe returned HTTP \(statusCode). Identity Graph access needs consent or tenant policy review before mailbox access can be tested. No mailbox fetch was attempted."
    default:
      return "Microsoft Graph /me probe returned HTTP \(statusCode). Identity Graph access did not succeed, so mailbox access was not tested."
    }
  }

  private func identityProbeSuccessDetail(for profile: GraphMeResponse, connection: Microsoft365MailboxConnection) -> String {
    let mailboxPlaceholder = connection.mailboxAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    let profileValues = [profile.userPrincipalName, profile.mail]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    let matchText: String
    if mailboxPlaceholder.isEmpty || profileValues.isEmpty {
      matchText = "unavailable"
    } else {
      matchText = profileValues.contains { $0.caseInsensitiveCompare(mailboxPlaceholder) == .orderedSame } ? "yes" : "no"
    }

    return [
      "Microsoft Graph /me probe:",
      "Probe result: succeeded",
      "Returned id: \(profile.id?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? "present" : "missing")",
      "Returned displayName: \(profile.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? "present" : "missing")",
      "Returned userPrincipalName: \(profile.userPrincipalName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? "present" : "missing")",
      "Returned mail: \(profile.mail?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? "present" : "missing")",
      "Mailbox placeholder match: \(matchText)",
      "Identity Graph access works. If mailbox endpoints fail, mailbox Graph access is blocked or challenged."
    ].joined(separator: "\n")
  }

  private func graphErrorDetail(from data: Data, response: HTTPURLResponse) -> String {
    let decodedError = (try? JSONDecoder().decode(GraphErrorResponse.self, from: data))?.error
    let code = sanitizedGraphErrorValue(decodedError?.code, fallback: "missing")
    let message = sanitizedGraphErrorValue(decodedError?.message, fallback: "missing")
    let requestID = sanitizedGraphErrorValue(headerValue("request-id", in: response) ?? decodedError?.innerError?.requestID, fallback: "missing")
    let clientRequestID = sanitizedGraphErrorValue(headerValue("client-request-id", in: response) ?? decodedError?.innerError?.clientRequestID, fallback: "missing")
    let responseDate = sanitizedGraphErrorValue(headerValue("date", in: response) ?? decodedError?.innerError?.date, fallback: "missing")
    let contentType = sanitizedGraphErrorValue(headerValue("content-type", in: response), fallback: "missing")
    let bodyPreview = sanitizedResponseBodyPreview(from: data)

    return [
      "Microsoft Graph error detail:",
      "Graph error code: \(code)",
      "Graph error message: \(message)",
      "Graph request-id: \(requestID)",
      "Graph client-request-id: \(clientRequestID)",
      "Graph response date: \(responseDate)",
      "Graph response content type: \(contentType)",
      "Graph response body length: \(data.count)",
      "Graph response body preview: \(bodyPreview)",
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

  private func sanitizedResponseBodyPreview(from data: Data) -> String {
    guard !data.isEmpty else { return "empty" }
    guard var text = String(data: data, encoding: .utf8) else {
      return "non-UTF8 response body"
    }
    text = text
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "\r", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    text = redactingSensitiveFragments(in: text)
    guard !text.isEmpty else { return "empty" }
    return String(text.prefix(600))
  }

  private func redactingSensitiveFragments(in text: String) -> String {
    let redactions: [(String, String)] = [
      (#"(?i)bearer\s+[A-Za-z0-9\-._~+/]+=*"#, "Bearer [redacted]"),
      (#"(?i)"(access_token|refresh_token|id_token|client_secret|code)"\s*:\s*"[^"]*""#, #""$1":"[redacted]""#),
      (#"(?i)(access_token|refresh_token|id_token|client_secret|code)=([^&\s]+)"#, "$1=[redacted]")
    ]
    return redactions.reduce(text) { current, redaction in
      guard let regex = try? NSRegularExpression(pattern: redaction.0) else { return current }
      let range = NSRange(current.startIndex..<current.endIndex, in: current)
      return regex.stringByReplacingMatches(in: current, range: range, withTemplate: redaction.1)
    }
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

  private enum GraphIdentityProbeResult {
    case success(String)
    case failure(MicrosoftGraphMailboxFetchStatus, String)
  }

  private struct GraphMeResponse: Decodable {
    var id: String?
    var displayName: String?
    var userPrincipalName: String?
    var mail: String?
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
