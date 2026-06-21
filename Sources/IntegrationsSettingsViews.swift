import SwiftUI

struct IntegrationsView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        VStack(alignment: .leading, spacing: 10) {
          Text("Local source setup")
            .font(isCompact ? .title2.bold() : .title.bold())
          Text("Placeholder records for future mailbox, Shopify, folder, and login workflows. Nothing here connects to live services yet.")
            .font(.callout)
            .foregroundStyle(.secondary)
          CompactActionRow {
            Button("SpaceMail IMAP setup", systemImage: "server.rack", action: store.addSpaceMailIMAPConnectionPlaceholder)
            Button("Microsoft 365 setup", systemImage: "mail.stack.fill", action: store.addMicrosoft365MailboxConnectionPlaceholder)
            Button("Mailbox placeholder", systemImage: "envelope.badge.fill", action: store.addTrackedMailboxPlaceholder)
            Button("Shopify placeholder", systemImage: "cart.badge.plus", action: store.connectShopifyPlaceholder)
            Button("Folder placeholder", systemImage: "folder.badge.plus", action: store.addWatchedFolderPlaceholder)
            Button("Login placeholder", systemImage: "key.fill", action: store.addStoreLoginPlaceholder)
          }
        }

        SettingsPanel(title: "SpaceMail IMAP setup", symbol: "server.rack") {
          Text("Use this as the current mailbox path for SpaceMail. This section stores non-secret IMAP setup fields, manages the password/app-password in Keychain, and keeps mock refresh separate from the real manual refresh boundary.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Text("Do not enter passwords here. No password, app password, auth string, or Keychain item is stored in JSON or audit logs.")
            .font(.caption)
            .foregroundStyle(.secondary)
          CompactActionRow {
            Button("Add SpaceMail placeholder", systemImage: "plus", action: store.addSpaceMailIMAPConnectionPlaceholder)
              .buttonStyle(.bordered)
            Badge("\(store.spaceMailIMAPConnections.count) placeholders", color: .blue)
          }
          if store.spaceMailIMAPConnections.isEmpty {
            MVPEmptyState(title: "No SpaceMail IMAP placeholders", detail: "Add a SpaceMail placeholder to capture host, port, folder, and credential-readiness notes before real IMAP is connected.", symbol: "server.rack")
          }
          ForEach(store.spaceMailIMAPConnections) { connection in
            SpaceMailIMAPConnectionRow(connection: connection) { updatedConnection in
              store.updateSpaceMailIMAPConnection(updatedConnection)
            } onReviewed: {
              store.markSpaceMailIMAPConnectionReviewed(connection)
            } onMockRefresh: {
              store.importMockSpaceMailIMAPMessages(for: connection)
            } onRealRefresh: {
              store.importRealSpaceMailIMAPMessages(for: connection)
            } onSaveCredential: { password in
              store.saveSpaceMailCredential(password, for: connection)
            } onCheckCredential: {
              store.checkSpaceMailCredential(connection)
            } onClearCredential: {
              store.clearSpaceMailCredential(connection)
            } onCredentialReady: {
              store.simulateSpaceMailCredentialReady(connection)
            } onCredentialMissing: {
              store.simulateSpaceMailCredentialMissing(connection)
            } onCredentialError: {
              store.simulateSpaceMailCredentialStorageError(connection)
            } onCredentialClear: {
              store.simulateSpaceMailCredentialClear(connection)
            } onRemove: {
              store.removeSpaceMailIMAPConnection(connection)
            }
          }
        }

        SettingsPanel(title: "Microsoft 365 mailbox setup", symbol: "mail.stack.fill") {
          Text("Microsoft 365 remains available as an advanced option, but SpaceMail IMAP is the current provider path for this project.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Microsoft365SetupFlowGuide()
          CompactActionRow {
            Button("Add mailbox placeholder", systemImage: "plus", action: store.addMicrosoft365MailboxConnectionPlaceholder)
              .buttonStyle(.bordered)
            Badge("\(store.microsoft365MailboxConnections.count) placeholders", color: .orange)
          }
          if store.microsoft365MailboxConnections.isEmpty {
            MVPEmptyState(title: "No Microsoft 365 mailbox placeholders", detail: "Add a placeholder to capture the mailbox address, OAuth planning notes, and mock refresh setup before real authentication is built.", symbol: "mail.stack")
          }
          ForEach(store.microsoft365MailboxConnections) { connection in
            Microsoft365MailboxConnectionRow(connection: connection, readiness: store.microsoft365OAuthReadinessSummary(for: connection), implementationPlan: store.microsoft365OAuthImplementationPlan(for: connection), authState: store.microsoft365AuthSessionState(for: connection)) { updatedConnection in
              store.updateMicrosoft365MailboxConnection(updatedConnection)
            } onReadyForReview: {
              store.markMicrosoft365MailboxConnectionReadyForReview(connection)
            } onMockAuthConnect: {
              store.connectMicrosoft365AuthMock(connection)
            } onMockAuthFailure: {
              store.simulateMicrosoft365AuthFailure(connection)
            } onRealAuthConnect: {
              store.connectMicrosoft365AuthReal(connection)
            } onTokenStoreReady: {
              store.simulateMicrosoft365TokenStoreReady(connection)
            } onTokenMissing: {
              store.simulateMicrosoft365TokenMissing(connection)
            } onTokenStorageError: {
              store.simulateMicrosoft365TokenStorageError(connection)
            } onTokenClear: {
              store.simulateMicrosoft365TokenClear(connection)
            } onSimulatedRefresh: {
              store.importSimulatedFetchedMailboxMessages(for: connection)
            } onRealGraphRefresh: {
              store.importRealMicrosoftGraphMailboxMessages(for: connection)
            } onReviewOAuth: {
              store.markMicrosoft365OAuthSetupReviewed(connection)
            } onResetOAuth: {
              store.resetMicrosoft365OAuthReadiness(connection)
            } onReviewImplementationPlan: {
              store.markMicrosoft365OAuthImplementationPlanReviewed(connection)
            } onCreatePlanTask: {
              store.createReviewTaskFromMicrosoft365OAuthPlan(connection)
            } onRemove: {
              store.removeMicrosoft365MailboxConnection(connection)
            }
          }
        }

        SettingsPanel(title: "Tracked mailboxes", symbol: "envelope.badge.fill") {
          ForEach(store.mailboxes) { mailbox in
            MailboxConnectionRow(mailbox: mailbox)
          }
        }
        SettingsPanel(title: "Shopify stores", symbol: "cart.badge.plus") {
          ForEach(store.shopifyConnections) { connection in
            ShopifyConnectionRow(connection: connection, suggestedAccounts: store.suggestedAccounts(for: connection), suggestedProfiles: store.suggestedVendorProfiles(for: connection)) {
              store.addAccountCredentialRecord(linkedEntityType: .shopifyStore, linkedEntityID: connection.id.uuidString, organisation: connection.storeName, label: connection.storeName)
            } onTaskFromAccount: { account in
              store.createReviewTask(from: account)
            } onDraftFromAccount: { account in
              store.createDraftMessage(from: account)
            } onCreateProfile: {
              store.addVendorProfile(profileType: .shopifyStore, organisation: connection.storeName, label: connection.storeName)
            } onTaskFromProfile: { profile in
              store.createReviewTask(from: profile)
            } onDraftFromProfile: { profile in
              store.createDraftMessage(from: profile)
            }
          }
        }
        SettingsPanel(title: "Watched folders", symbol: "folder.fill.badge.gearshape") {
          ForEach(store.watchedFolders) { folder in
            WatchedFolderRow(folder: folder)
          }
        }
        ForEach(store.connections) { connection in
          SourceConnectionRow(connection: connection, suggestedAccounts: store.suggestedAccounts(for: connection), suggestedProfiles: store.suggestedVendorProfiles(for: connection)) {
            store.addAccountCredentialRecord(linkedEntityType: .sourceConnection, linkedEntityID: connection.id.uuidString, organisation: connection.name, label: connection.name)
          } onTaskFromAccount: { account in
            store.createReviewTask(from: account)
          } onDraftFromAccount: { account in
            store.createDraftMessage(from: account)
          } onCreateProfile: {
            store.addVendorProfile(profileType: .supplier, organisation: connection.name, label: connection.name)
          } onTaskFromProfile: { profile in
            store.createReviewTask(from: profile)
          } onDraftFromProfile: { profile in
            store.createDraftMessage(from: profile)
          }
        }
      }
      .padding(isCompact ? 14 : 24)
    }
  }
}

struct Microsoft365SetupFlowGuide: View {
  private let steps: [(String, String, String)] = [
    ("1", "Setup mailbox placeholder", "Record the mailbox address, tenant hint, folders, and local setup notes."),
    ("2", "Prepare OAuth placeholders", "Capture non-secret tenant, client, redirect, scope, and consent planning details."),
    ("3", "Review implementation checklist", "Confirm the plan for app registration, consent, token storage, refresh, errors, and audit."),
    ("4", "Run Mock Graph refresh", "Import deterministic sample messages through the provider-neutral intake path."),
    ("5", "Review imported intake", "Open Inbox or Mailbox Monitor and accept, ignore, review, task, or draft from local records."),
    ("6", "Check Audit and Tasks", "Confirm local actions were logged and follow-up work was created where needed.")
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Local setup flow", systemImage: "list.number")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], alignment: .leading, spacing: 10) {
        ForEach(steps, id: \.0) { step in
          HStack(alignment: .top, spacing: 10) {
            Text(step.0)
              .font(.caption.weight(.bold))
              .foregroundStyle(.blue)
              .frame(width: 24, height: 24)
              .background(.blue.opacity(0.12))
              .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
              Text(step.1)
                .font(.caption.weight(.semibold))
              Text(step.2)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
      }
      Text("Local-only boundary: OAuth, browser sign-in, token exchange, Keychain, Microsoft Graph network calls, real mailbox access, background sync, and notifications are not active.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct Microsoft365MailboxConnectionRow: View {
  var connection: Microsoft365MailboxConnection
  var readiness: Microsoft365OAuthReadinessSummary
  var implementationPlan: Microsoft365OAuthImplementationPlan
  var authState: Microsoft365AuthSessionState
  var onSave: (Microsoft365MailboxConnection) -> Void
  var onReadyForReview: () -> Void
  var onMockAuthConnect: () -> Void
  var onMockAuthFailure: () -> Void
  var onRealAuthConnect: () -> Void
  var onTokenStoreReady: () -> Void
  var onTokenMissing: () -> Void
  var onTokenStorageError: () -> Void
  var onTokenClear: () -> Void
  var onSimulatedRefresh: () -> Void
  var onRealGraphRefresh: () -> Void
  var onReviewOAuth: () -> Void
  var onResetOAuth: () -> Void
  var onReviewImplementationPlan: () -> Void
  var onCreatePlanTask: () -> Void
  var onRemove: () -> Void
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var isEditing = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "mail.stack.fill")
          .foregroundStyle(.blue)
          .frame(width: 28)
        VStack(alignment: .leading, spacing: 4) {
          Text(connection.displayName)
            .font(.headline)
          Text(connection.mailboxAddress)
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("\(connection.tenantDomainHint) • \(connection.monitoredFolderNames)")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(connection.setupNotes)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Label(readiness.statusText, systemImage: readiness.isReady ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(readiness.isReady ? .green : .orange)
          if !readiness.missingFields.isEmpty {
            Text(readiness.detailText)
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          Label(implementationPlan.statusText, systemImage: "list.clipboard.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.blue)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 4) {
          Badge(connection.reviewState.rawValue, color: connection.reviewState.color)
          Text(connection.connectionStatus)
            .font(.caption.weight(.semibold))
            .multilineTextAlignment(.trailing)
          Text("Refresh: \(connection.lastManualRefreshDate)")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }

      Text("Mock Graph refresh remains available for local testing. Real Graph refresh is manual, read-only, and imports only message previews after Microsoft sign-in and Mail.Read consent.")
        .font(.caption)
        .foregroundStyle(.secondary)

      microsoftGraphRefreshSummary
      Microsoft365AuthStateSection(authState: authState)
      Microsoft365RealSignInChecklist(connection: connection, readiness: readiness)

      VStack(alignment: .leading, spacing: 6) {
        Label("OAuth readiness and implementation checklist", systemImage: "checklist")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Text("Use this as a planning review before real Microsoft authentication work starts.")
          .font(.caption2)
          .foregroundStyle(.secondary)
        ForEach(implementationPlan.items) { item in
          HStack(alignment: .top, spacing: 8) {
            Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
              .foregroundStyle(item.isComplete ? .green : .secondary)
              .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
              Text(item.title)
                .font(.caption.weight(.semibold))
              Text(item.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
        }
      }

      VStack(alignment: .leading, spacing: 8) {
        ActionGroupHeader(title: "Microsoft sign-in boundary", symbol: "person.badge.key.fill")
        Text("Use real sign-in only after the checklist is ready. If signing, consent, or Keychain cache setup blocks the test, use mock auth and Mock Graph refresh to keep testing intake.")
          .font(.caption2)
          .foregroundStyle(.secondary)
        CompactActionRow {
          Button("Test real Microsoft sign-in", systemImage: "person.crop.circle.badge.checkmark", action: onRealAuthConnect)
            .buttonStyle(.borderedProminent)
          Button("Connect Microsoft 365 mock", systemImage: "person.crop.circle.badge.checkmark", action: onMockAuthConnect)
            .buttonStyle(.bordered)
          Button("Mock auth failure", systemImage: "xmark.octagon", action: onMockAuthFailure)
            .buttonStyle(.bordered)
        }
        ActionGroupHeader(title: "Token storage planning", symbol: "key.fill")
        CompactActionRow {
          Button("Mock token ready", systemImage: "checkmark.seal", action: onTokenStoreReady)
            .buttonStyle(.bordered)
          Button("Token missing", systemImage: "exclamationmark.triangle", action: onTokenMissing)
            .buttonStyle(.bordered)
          Button("Storage error", systemImage: "xmark.octagon", action: onTokenStorageError)
            .buttonStyle(.bordered)
          Button("Clear token ref", systemImage: "trash", action: onTokenClear)
            .buttonStyle(.bordered)
        }
        ActionGroupHeader(title: "Setup and mock refresh", symbol: "mail.and.text.magnifyingglass")
        CompactActionRow {
          Button("Edit setup", systemImage: "pencil") {
            isEditing = true
          }
          .buttonStyle(.bordered)
          Button("Ready for review", systemImage: "checkmark.shield.fill", action: onReadyForReview)
            .buttonStyle(.bordered)
          Button("Run Mock Graph refresh", systemImage: "tray.and.arrow.down.fill", action: onSimulatedRefresh)
            .buttonStyle(.borderedProminent)
        }
        ActionGroupHeader(title: "Real mailbox read", symbol: "envelope.open.fill")
        Text("Manual read-only test: requests User.Read and Mail.Read, fetches at most 10 message previews from the configured folder, then imports through the existing duplicate-safe intake path.")
          .font(.caption2)
          .foregroundStyle(.secondary)
        CompactActionRow {
          Button("Run real Graph refresh", systemImage: "arrow.down.message.fill", action: onRealGraphRefresh)
            .buttonStyle(.bordered)
            .disabled(authState.status != .connected)
        }
        Text(realGraphActionHint)
          .font(.caption2)
          .foregroundStyle(realGraphActionHintColor)
        ActionGroupHeader(title: "OAuth planning", symbol: "list.clipboard.fill")
        CompactActionRow {
          Button("Review OAuth setup", systemImage: "checkmark.seal", action: onReviewOAuth)
            .buttonStyle(.bordered)
          Button("Review plan", systemImage: "list.clipboard.fill", action: onReviewImplementationPlan)
            .buttonStyle(.bordered)
          Button("Create plan task", systemImage: "checklist", action: onCreatePlanTask)
            .buttonStyle(.bordered)
        }
        ActionGroupHeader(title: "Maintenance", symbol: "wrench.and.screwdriver.fill")
        CompactActionRow {
          Button("Reset OAuth placeholders", systemImage: "arrow.counterclockwise", action: onResetOAuth)
            .buttonStyle(.bordered)
          Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
            .buttonStyle(.bordered)
        }
      }
    }
    .padding(10)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      Microsoft365MailboxConnectionEditor(connection: connection, implementationPlan: implementationPlan) { updatedConnection in
        onSave(updatedConnection)
        isEditing = false
      }
      .presentationDetents(horizontalSizeClass == .compact ? [.large] : [.medium, .large])
    }
  }

  private var microsoftGraphRefreshSummary: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label("Mailbox refresh status", systemImage: refreshStatusIcon)
        .font(.caption.weight(.semibold))
        .foregroundStyle(refreshStatusColor)
      Text(refreshStatusSummary)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(refreshStatusDetail)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(refreshStatusColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private var refreshStatusSummary: String {
    let status = connection.connectionStatus
    if status.localizedCaseInsensitiveContains("Real Graph: Success") {
      return "Real Graph refresh completed. New message previews, if any, were imported into Inbox through duplicate-safe intake."
    }
    if status.localizedCaseInsensitiveContains("Real Graph: Duplicate skipped") {
      return "Real Graph refresh completed and only found messages ParcelOps had already captured."
    }
    if status.localizedCaseInsensitiveContains("Mock Graph") {
      return "Last refresh used the local Mock Graph path, not Microsoft Graph."
    }
    if status.localizedCaseInsensitiveContains("Consent required") {
      return "Mail.Read consent or tenant policy needs attention before real Graph refresh can read message previews."
    }
    if status.localizedCaseInsensitiveContains("Folder not found") {
      return "The configured folder was not found. Check the first monitored folder name, or use Inbox."
    }
    if status.localizedCaseInsensitiveContains("Auth required") {
      return "Real Graph refresh needs a successful Microsoft sign-in before it can request Mail.Read."
    }
    if authState.status == .connected {
      return "Microsoft sign-in is connected. Real Graph refresh is ready for a manual read-only test."
    }
    return "Connect Microsoft 365 before running a real Graph refresh, or use Mock Graph refresh for local testing."
  }

  private var refreshStatusDetail: String {
    "Last refresh: \(connection.lastManualRefreshDate). Current status: \(connection.connectionStatus). Mock refresh and real Graph refresh are separate actions."
  }

  private var refreshStatusIcon: String {
    let status = connection.connectionStatus
    if status.localizedCaseInsensitiveContains("Success") { return "checkmark.seal.fill" }
    if status.localizedCaseInsensitiveContains("Duplicate skipped") { return "doc.on.doc.fill" }
    if status.localizedCaseInsensitiveContains("Consent required") || status.localizedCaseInsensitiveContains("Folder not found") || status.localizedCaseInsensitiveContains("Auth required") {
      return "exclamationmark.triangle.fill"
    }
    if status.localizedCaseInsensitiveContains("Mock Graph") { return "testtube.2" }
    return authState.status == .connected ? "envelope.open.fill" : "mail.stack.fill"
  }

  private var refreshStatusColor: Color {
    let status = connection.connectionStatus
    if status.localizedCaseInsensitiveContains("Success") { return .green }
    if status.localizedCaseInsensitiveContains("Duplicate skipped") { return .blue }
    if status.localizedCaseInsensitiveContains("Consent required") || status.localizedCaseInsensitiveContains("Folder not found") || status.localizedCaseInsensitiveContains("Auth required") {
      return .orange
    }
    if status.localizedCaseInsensitiveContains("Mock Graph") { return .purple }
    return authState.status == .connected ? .teal : .secondary
  }

  private var realGraphActionHint: String {
    authState.status == .connected
      ? "This reads message previews only. It will not delete, move, mark read, send, or change mailbox messages."
      : "Real Graph refresh is disabled until real Microsoft sign-in succeeds. Mock Graph refresh remains available."
  }

  private var realGraphActionHintColor: Color {
    authState.status == .connected ? .secondary : .orange
  }
}

struct Microsoft365AuthStateSection: View {
  var authState: Microsoft365AuthSessionState

  private var statusColor: Color {
    switch authState.status {
    case .notConfigured, .consentRequired, .tokenExpired: .orange
    case .notConnected, .connecting: .blue
    case .connected: .green
    case .authFailed: .red
    }
  }

  private var tokenStoreColor: Color {
    switch authState.tokenStoreStatus {
    case .keychainNotConfigured, .tokenMissing, .tokenClearSimulated: .orange
    case .mockTokenReferenceAvailable: .green
    case .storageErrorSimulated: .red
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Microsoft 365 sign-in state", systemImage: "person.badge.key.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      CompactMetadataGrid(minimumWidth: 140) {
        Badge(authState.status.rawValue, color: statusColor)
        Label(authState.signedInAccount, systemImage: "person.crop.circle")
          .font(.caption)
          .foregroundStyle(.secondary)
        Label("Attempt: \(authState.lastAuthAttemptDate)", systemImage: "clock")
          .font(.caption)
          .foregroundStyle(.secondary)
        Label("Success: \(authState.lastSuccessfulAuthDate)", systemImage: "checkmark.seal")
          .font(.caption)
          .foregroundStyle(.secondary)
        Label(authState.keychainStatus, systemImage: "key.slash")
          .font(.caption)
          .foregroundStyle(.secondary)
        Badge(authState.tokenStoreStatus.rawValue, color: tokenStoreColor)
      }
      Text(authState.detailText)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Text(authState.tokenStoreDetail)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Text(statusGuidance)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(statusColor)
        .fixedSize(horizontal: false, vertical: true)
      Text("Real sign-in is opt-in. ParcelOps does not store token values in JSON. Mock Graph remains available, and real Graph refresh is manual/read-only.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }

  private var statusGuidance: String {
    switch authState.status {
    case .notConfigured:
      "Missing setup: confirm tenant/domain, client ID, and redirect URI before trying real sign-in."
    case .notConnected:
      authState.detailText.localizedCaseInsensitiveContains("cancelled")
        ? "Cancelled: no account was connected. You can retry real sign-in or use mock auth."
        : "Not connected: use mock auth for local testing or complete setup before real sign-in."
    case .connecting:
      "Sign-in started: wait for Microsoft authentication to finish or return to ParcelOps."
    case .connected:
      "Connected: identity sign-in succeeded. Use Run real Graph refresh only when you want a manual read-only mailbox test."
    case .authFailed:
      "Failed: check Xcode signing, active app window, redirect URI, and MSAL runtime setup."
    case .consentRequired:
      "Consent/admin review: check Entra app registration, tenant policy, and User.Read permission consent."
    case .tokenExpired:
      "Token cache needs attention: retry sign-in. ParcelOps still does not store token values in JSON."
    }
  }
}

struct Microsoft365RealSignInChecklist: View {
  var connection: Microsoft365MailboxConnection
  var readiness: Microsoft365OAuthReadinessSummary

  private let expectedRedirectURI = MSALMicrosoft365AuthAdapter.redirectURI

  private var hasTenant: Bool {
    !connection.tenantIDPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !connection.tenantDomainHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var hasClientID: Bool {
    !connection.clientIDPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var hasRedirect: Bool {
    connection.redirectURIPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines) == expectedRedirectURI
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Before real sign-in", systemImage: "checklist.checked")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text("Required Entra setup: public client/native app registration, tenant or domain, application client ID, redirect URI \(expectedRedirectURI), delegated User.Read for sign-in, and delegated Mail.Read for manual real Graph refresh.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      CompactMetadataGrid(minimumWidth: 170) {
        ReadinessPill(title: "Tenant/domain", isReady: hasTenant)
        ReadinessPill(title: "Client ID", isReady: hasClientID)
        ReadinessPill(title: "Redirect URI", isReady: hasRedirect)
        ReadinessPill(title: "User.Read only", isReady: connection.requestedScopesSummary.localizedCaseInsensitiveContains("User.Read"))
        ReadinessPill(title: "Planning reviewed", isReady: readiness.isReady)
      }
      Text("Fallback: Connect Microsoft 365 mock tests auth state locally. Run Mock Graph refresh imports deterministic sample messages without contacting Microsoft Graph.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct ReadinessPill: View {
  var title: String
  var isReady: Bool

  var body: some View {
    Label(title, systemImage: isReady ? "checkmark.circle.fill" : "circle")
      .font(.caption)
      .foregroundStyle(isReady ? .green : .secondary)
  }
}

struct ActionGroupHeader: View {
  var title: String
  var symbol: String

  var body: some View {
    Label(title, systemImage: symbol)
      .font(.caption.weight(.semibold))
      .foregroundStyle(.secondary)
  }
}

struct SpaceMailIMAPConnectionRow: View {
  var connection: SpaceMailIMAPConnection
  var onSave: (SpaceMailIMAPConnection) -> Void
  var onReviewed: () -> Void
  var onMockRefresh: () -> Void
  var onRealRefresh: () -> Void
  var onSaveCredential: (String) -> Void
  var onCheckCredential: () -> Void
  var onClearCredential: () -> Void
  var onCredentialReady: () -> Void
  var onCredentialMissing: () -> Void
  var onCredentialError: () -> Void
  var onCredentialClear: () -> Void
  var onRemove: () -> Void

  @State private var isEditing = false
  @State private var isCredentialSheetPresented = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "server.rack")
          .foregroundStyle(.blue)
          .frame(width: 28)
        VStack(alignment: .leading, spacing: 5) {
          Text(connection.displayName)
            .font(.headline)
          Text(connection.emailAddressUsername)
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Text("\(connection.imapHost):\(connection.imapPort) • \(connection.securityMode) • \(connection.folderName)")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("Mailbox mode: \(connection.mailboxMode.rawValue)")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("Credential storage: \(connection.credentialStorageStatus)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Badge(connection.reviewState.rawValue, color: connection.reviewState == .accepted ? .green : .orange)
      }

      Text("Status: \(connection.connectionStatus) • Last refresh: \(connection.lastManualRefreshDate)")
        .font(.caption)
        .foregroundStyle(.secondary)

      if !connection.setupNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Text(connection.setupNotes)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Text("Manual real refresh uses read-only IMAP. Mixed mailbox mode filters likely non-order messages before they reach Inbox, while dedicated mode passes fetched messages straight to intake duplicate handling. No mailbox items are deleted, moved, marked read, flagged, sent, or modified.")
        .font(.caption)
        .foregroundStyle(.secondary)

      spaceMailRefreshSummary

      VStack(alignment: .leading, spacing: 6) {
        ActionGroupHeader(title: "Keychain credential", symbol: "key.horizontal")
        Text("Set, check, or clear the SpaceMail password/app-password in Keychain. ParcelOps stores only the non-secret status label in JSON and Audit.")
          .font(.caption)
          .foregroundStyle(.secondary)
        CompactActionRow {
          Button("Set/update password", systemImage: "key.fill") { isCredentialSheetPresented = true }
          Button("Check credential", systemImage: "checkmark.seal", action: onCheckCredential)
          Button("Clear credential", systemImage: "xmark.circle", role: .destructive, action: onClearCredential)
        }
      }

      VStack(alignment: .leading, spacing: 6) {
        ActionGroupHeader(title: "Credential state test actions", symbol: "wrench.and.screwdriver")
        Text("These mock actions only change non-secret status labels for testing error states. They do not create, read, write, delete, store, or log passwords or Keychain items.")
          .font(.caption)
          .foregroundStyle(.secondary)
        CompactActionRow {
          Button("Credential ready", systemImage: "key.radiowaves.forward", action: onCredentialReady)
          Button("Credential missing", systemImage: "key.slash", action: onCredentialMissing)
          Button("Storage error", systemImage: "exclamationmark.triangle", action: onCredentialError)
          Button("Clear reference", systemImage: "xmark.circle", action: onCredentialClear)
        }
      }

      CompactActionRow {
        Button("Edit setup", systemImage: "pencil") { isEditing = true }
        Button("Mark reviewed", systemImage: "checkmark.circle", action: onReviewed)
        Button("Run Mock SpaceMail refresh", systemImage: "tray.and.arrow.down", action: onMockRefresh)
        Button("Run real SpaceMail refresh", systemImage: "network", action: onRealRefresh)
        Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
      }
    }
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      SpaceMailIMAPConnectionEditor(connection: connection) { updatedConnection in
        onSave(updatedConnection)
      }
    }
    .sheet(isPresented: $isCredentialSheetPresented) {
      SpaceMailCredentialSheet(connection: connection) { password in
        onSaveCredential(password)
      }
    }
  }

  private var spaceMailRefreshSummary: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Latest SpaceMail refresh", systemImage: "tray.and.arrow.down.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(spaceMailRefreshColor)
      CompactMetadataGrid(minimumWidth: 120) {
        Badge("\(connection.lastRefreshFetchedCount) fetched", color: .blue)
        Badge("\(connection.lastRefreshImportedCount) imported", color: connection.lastRefreshImportedCount > 0 ? .green : .secondary)
        Badge("\(connection.lastRefreshDuplicateCount) duplicates", color: connection.lastRefreshDuplicateCount > 0 ? .orange : .secondary)
        Badge("\(connection.lastRefreshFilteredNonOrderCount) filtered", color: connection.lastRefreshFilteredNonOrderCount > 0 ? .teal : .secondary)
        Badge("\(connection.lastRefreshUncertainCount) uncertain", color: connection.lastRefreshUncertainCount > 0 ? .orange : .secondary)
      }
      Text(connection.lastRefreshSummary)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      if connection.mailboxMode == .mixedFiltered {
        Text("Mixed mailbox mode keeps filtered non-order messages out of Inbox. Open Audit only when you need the detailed reason labels.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.teal)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(spaceMailRefreshColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private var spaceMailRefreshColor: Color {
    let status = connection.connectionStatus
    if status.localizedCaseInsensitiveContains("success") { return .green }
    if status.localizedCaseInsensitiveContains("duplicate") { return .teal }
    if status.localizedCaseInsensitiveContains("failed") || status.localizedCaseInsensitiveContains("missing") { return .orange }
    return .secondary
  }
}

struct SpaceMailCredentialSheet: View {
  @Environment(\.dismiss) private var dismiss
  var connection: SpaceMailIMAPConnection
  var onSave: (String) -> Void

  @State private var password = ""

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text(connection.displayName)
            .font(.headline)
          Text(connection.emailAddressUsername)
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Text("The password/app-password is sent to Keychain only. It is not stored in ParcelOps JSON or Audit.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        SecureField("SpaceMail password or app password", text: $password)
          .textFieldStyle(.roundedBorder)

        Text("Use this only for the configured SpaceMail inbox. Clearing or checking credentials can be done from the setup row after saving.")
          .font(.caption)
          .foregroundStyle(.secondary)

        Spacer()
      }
      .padding()
      .frame(minWidth: 420, idealWidth: 520, maxWidth: 620, minHeight: 220, idealHeight: 280, maxHeight: 360)
      .navigationTitle("SpaceMail Credential")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save to Keychain") {
            onSave(password)
            password = ""
            dismiss()
          }
          .disabled(password.isEmpty)
        }
      }
    }
  }
}

struct SpaceMailIMAPConnectionEditor: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: SpaceMailIMAPConnection
  var onSave: (SpaceMailIMAPConnection) -> Void

  init(connection: SpaceMailIMAPConnection, onSave: @escaping (SpaceMailIMAPConnection) -> Void) {
    self._draft = State(initialValue: connection)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        Form {
          Section("1. SpaceMail mailbox") {
            TextField("Display name", text: $draft.displayName)
            TextField("Email address / username", text: $draft.emailAddressUsername)
            TextField("IMAP host", text: $draft.imapHost)
            TextField("IMAP port", text: $draft.imapPort)
            TextField("Security mode", text: $draft.securityMode)
            TextField("Folder name", text: $draft.folderName)
            Picker("Mailbox mode", selection: $draft.mailboxMode) {
              ForEach(SpaceMailMailboxMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
              }
            }
          }
          Section("2. Local status") {
            TextField("Connection status", text: $draft.connectionStatus)
            TextField("Last manual refresh", text: $draft.lastManualRefreshDate)
            TextField("Credential storage status", text: $draft.credentialStorageStatus)
            Picker("Review state", selection: $draft.reviewState) {
              Text("Accepted").tag(ReviewState.accepted)
              Text("Needs review").tag(ReviewState.needsReview)
              Text("Monitor").tag(ReviewState.monitor)
            }
          }
          Section("3. Setup notes") {
            TextField("Setup notes", text: $draft.setupNotes, axis: .vertical)
              .lineLimit(4...8)
            Text("Do not enter passwords, app passwords, OAuth codes, tokens, API keys, or client secrets here. Use the secure credential prompt on the setup row for SpaceMail passwords.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Section("Read-only plan") {
            Text("SpaceMail IMAP refresh selects the configured folder read-only, fetches a small page of message headers/previews, then imports likely order messages through the provider-neutral intake path. Mixed mailbox mode keeps obvious non-order messages out of the primary Inbox. It must not delete, move, mark read, send, or modify mailbox messages.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .formStyle(.grouped)

        Divider()
        HStack {
          Spacer()
          Button("Cancel") { dismiss() }
            .keyboardShortcut(.cancelAction)
          Button("Save") {
            onSave(draft)
            dismiss()
          }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
        }
        .padding()
        .background(.background)
      }
      .frame(minWidth: 460, idealWidth: 620, maxWidth: 740, minHeight: 380, idealHeight: 600, maxHeight: 700)
      .navigationTitle("SpaceMail IMAP")
    }
  }
}

struct Microsoft365MailboxConnectionEditor: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: Microsoft365MailboxConnection
  var implementationPlan: Microsoft365OAuthImplementationPlan
  var onSave: (Microsoft365MailboxConnection) -> Void

  init(connection: Microsoft365MailboxConnection, implementationPlan: Microsoft365OAuthImplementationPlan, onSave: @escaping (Microsoft365MailboxConnection) -> Void) {
    self._draft = State(initialValue: connection)
    self.implementationPlan = implementationPlan
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        Form {
          Section("1. Mailbox placeholder") {
            TextField("Display name", text: $draft.displayName)
            TextField("Tenant/domain hint", text: $draft.tenantDomainHint)
            TextField("Mailbox address", text: $draft.mailboxAddress)
            TextField("Monitored folders", text: $draft.monitoredFolderNames)
          }
          Section("2. Local status and notes") {
            TextField("Connection status", text: $draft.connectionStatus)
            TextField("Last manual refresh", text: $draft.lastManualRefreshDate)
            Picker("Review state", selection: $draft.reviewState) {
              Text("Accepted").tag(ReviewState.accepted)
              Text("Needs review").tag(ReviewState.needsReview)
              Text("Monitor").tag(ReviewState.monitor)
            }
            TextField("Setup notes", text: $draft.setupNotes, axis: .vertical)
              .lineLimit(3...6)
          }
          Section("3. OAuth readiness placeholders") {
            Text("Non-secret planning fields only. These prepare future OAuth work but do not start sign-in or store credentials.")
              .font(.caption)
              .foregroundStyle(.secondary)
            TextField("Tenant ID placeholder", text: $draft.tenantIDPlaceholder)
            TextField("Client ID placeholder", text: $draft.clientIDPlaceholder)
            TextField("Redirect URI placeholder", text: $draft.redirectURIPlaceholder)
            TextField("Requested scopes summary", text: $draft.requestedScopesSummary, axis: .vertical)
              .lineLimit(2...4)
            TextField("OAuth readiness status", text: $draft.oauthReadinessStatus)
            TextField("Consent/admin notes", text: $draft.consentAdminNotes, axis: .vertical)
              .lineLimit(3...6)
          }
          Section("4. Implementation checklist") {
            Text(implementationPlan.statusText)
              .font(.subheadline.weight(.semibold))
            Text("Review these planning items before adding a real OAuth flow in a later pass.")
              .font(.caption)
              .foregroundStyle(.secondary)
            ForEach(implementationPlan.items) { item in
              Label {
                VStack(alignment: .leading, spacing: 2) {
                  Text(item.title)
                  Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              } icon: {
                Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                  .foregroundStyle(item.isComplete ? .green : .secondary)
              }
            }
          }
          Section("Not connected") {
            Text("Use non-secret app registration notes only. Do not enter passwords, OAuth codes, client secrets, tokens, API keys, refresh tokens, or Keychain values. This placeholder does not run OAuth, open browser sign-in, request or store tokens, use Keychain, contact Microsoft Graph, or access any mailbox.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .formStyle(.grouped)

        Divider()
        HStack {
          Spacer()
          Button("Cancel") { dismiss() }
            .keyboardShortcut(.cancelAction)
          Button("Save") {
            onSave(draft)
            dismiss()
          }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
        }
        .padding()
        .background(.background)
      }
      .frame(minWidth: 480, idealWidth: 640, maxWidth: 760, minHeight: 420, idealHeight: 680, maxHeight: 720)
      .navigationTitle("Microsoft 365 mailbox")
    }
  }
}

struct MailboxConnectionRow: View {
  var mailbox: TrackedMailbox

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: mailbox.provider.symbol)
        .foregroundStyle(.blue)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 4) {
        Text(mailbox.address)
          .font(.headline)
        Text("\(mailbox.provider.rawValue) • \(mailbox.monitoredFolders)")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(mailbox.routingRule)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 4) {
        Text(mailbox.status)
          .font(.callout.weight(.semibold))
        Text(mailbox.lastChecked)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(10)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct ShopifyConnectionRow: View {
  var connection: ShopifyConnection
  var suggestedAccounts: [AccountCredentialRecord] = []
  var suggestedProfiles: [VendorProfile] = []
  var onCreateAccount: () -> Void = {}
  var onTaskFromAccount: (AccountCredentialRecord) -> Void = { _ in }
  var onDraftFromAccount: (AccountCredentialRecord) -> Void = { _ in }
  var onCreateProfile: () -> Void = {}
  var onTaskFromProfile: (VendorProfile) -> Void = { _ in }
  var onDraftFromProfile: (VendorProfile) -> Void = { _ in }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "cart.fill")
          .foregroundStyle(.green)
          .frame(width: 28)
        VStack(alignment: .leading, spacing: 4) {
          Text(connection.storeName)
            .font(.headline)
          Text(connection.storeDomain)
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("\(connection.mappedTeam) • \(connection.mappedMailbox)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 4) {
          Text(connection.isEnabled ? connection.status : "Disabled")
            .font(.callout.weight(.semibold))
          Text(connection.lastSync)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      HStack {
        Button("Account", systemImage: "key.badge.plus", action: onCreateAccount)
          .buttonStyle(.bordered)
        Button("Profile", systemImage: "building.2.crop.circle", action: onCreateProfile)
          .buttonStyle(.bordered)
      }

      ForEach(suggestedAccounts) { account in
        AccountSuggestionRow(account: account) {
          onTaskFromAccount(account)
        } onCreateDraft: {
          onDraftFromAccount(account)
        }
      }

      ForEach(suggestedProfiles) { profile in
        VendorProfileSuggestionRow(profile: profile) {
          onTaskFromProfile(profile)
        } onCreateDraft: {
          onDraftFromProfile(profile)
        }
      }
    }
    .padding(10)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct WatchedFolderRow: View {
  var folder: WatchedFolder

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "folder.fill.badge.gearshape")
        .foregroundStyle(.orange)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 4) {
        Text(folder.name)
          .font(.headline)
        Text(folder.location)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text("\(folder.platform) • \(folder.fileTypes) • \(folder.cadence)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 4) {
        Text(folder.status)
          .font(.callout.weight(.semibold))
        Text(folder.lastScan)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(10)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct SourceConnectionRow: View {
  var connection: SourceConnection
  var suggestedAccounts: [AccountCredentialRecord] = []
  var suggestedProfiles: [VendorProfile] = []
  var onCreateAccount: () -> Void = {}
  var onTaskFromAccount: (AccountCredentialRecord) -> Void = { _ in }
  var onDraftFromAccount: (AccountCredentialRecord) -> Void = { _ in }
  var onCreateProfile: () -> Void = {}
  var onTaskFromProfile: (VendorProfile) -> Void = { _ in }
  var onDraftFromProfile: (VendorProfile) -> Void = { _ in }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 14) {
        Image(systemName: connection.kind.symbol)
          .foregroundStyle(.teal)
          .frame(width: 34)
        VStack(alignment: .leading, spacing: 4) {
          Text(connection.name)
            .font(.headline)
          Text("\(connection.kind.rawValue) • \(connection.account)")
            .foregroundStyle(.secondary)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 4) {
          Text(connection.status)
            .font(.callout.weight(.semibold))
          Text(connection.lastSync)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      HStack {
        Button("Account", systemImage: "key.badge.plus", action: onCreateAccount)
          .buttonStyle(.bordered)
        Button("Profile", systemImage: "building.2.crop.circle", action: onCreateProfile)
          .buttonStyle(.bordered)
      }

      ForEach(suggestedAccounts) { account in
        AccountSuggestionRow(account: account) {
          onTaskFromAccount(account)
        } onCreateDraft: {
          onDraftFromAccount(account)
        }
      }

      ForEach(suggestedProfiles) { profile in
        VendorProfileSuggestionRow(profile: profile) {
          onTaskFromProfile(profile)
        } onCreateDraft: {
          onDraftFromProfile(profile)
        }
      }
    }
    .padding(14)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct SettingsView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }

  var body: some View {
    @Bindable var store = store

    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("Settings")
          .font(isCompact ? .title.bold() : .largeTitle.bold())

        MVPWorkflowGuide(
          title: "Before connecting live systems",
          detail: "These settings describe the intended workflow, but the current MVP remains local-only.",
          steps: [
            "Use sample and placeholder records to test the full flow.",
            "Do not enter real passwords, API keys, OAuth secrets, or mailbox credentials.",
            "Treat toggles as planning controls until integrations are explicitly added.",
            "Use Audit to confirm that local actions are being recorded."
          ],
          symbol: "gearshape.2.fill"
        )

        SettingsPanel(title: "MVP local-only status", symbol: "checklist") {
          Text("ParcelOps currently stores local JSON records and sample operational data. These controls describe intended workflows; they do not connect to live services yet.")
            .foregroundStyle(.secondary)

          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            IntegrationStatusRow(title: "Email mailbox", status: "Not connected", symbol: "envelope.badge.fill", color: .orange)
            IntegrationStatusRow(title: "Shopify", status: "Not connected", symbol: "cart.badge.plus", color: .orange)
            IntegrationStatusRow(title: "Carrier APIs", status: "Not connected", symbol: "location.fill.viewfinder", color: .orange)
            IntegrationStatusRow(title: "Store logins", status: "Placeholder only", symbol: "key.horizontal.fill", color: .orange)
            IntegrationStatusRow(title: "Credential storage", status: "Not enabled", symbol: "lock.shield.fill", color: .red)
            IntegrationStatusRow(title: "Background sync", status: "Not enabled", symbol: "bell.slash.fill", color: .red)
          }
        }

        SettingsPanel(title: "Mailbox intake", symbol: "envelope.open.fill") {
          Toggle("Plan forwarded mailbox monitoring", isOn: $store.settings.mailboxMonitoringEnabled)
          Toggle("Plan order creation from recognized emails", isOn: $store.settings.autoCreateOrdersFromEmail)
          Picker("Match confidence", selection: $store.settings.matchConfidencePolicy) {
            Text("Strict").tag("Strict")
            Text("Balanced").tag("Balanced")
            Text("Permissive").tag("Permissive")
          }
          .pickerStyle(.menu)
        }

        SettingsPanel(title: "Tracked mailboxes", symbol: "envelope.badge.fill") {
          ForEach(store.mailboxes) { mailbox in
            MailboxConnectionRow(mailbox: mailbox)
          }
          Button("Add mailbox placeholder", systemImage: "plus", action: store.addTrackedMailboxPlaceholder)
            .buttonStyle(.bordered)
        }

        SettingsPanel(title: "Shopify accounts", symbol: "cart.badge.plus") {
          ForEach(store.shopifyConnections) { connection in
            ShopifyConnectionRow(connection: connection)
          }
          Button("Add Shopify placeholder", systemImage: "plus", action: store.connectShopifyPlaceholder)
            .buttonStyle(.bordered)
        }

        SettingsPanel(title: "Watched folders", symbol: "folder.fill.badge.gearshape") {
          Toggle("Plan saved-folder scanning", isOn: $store.settings.folderWatchingEnabled)
          Picker("Scan cadence", selection: $store.settings.folderScanCadence) {
            Text("Every 5 minutes").tag("Every 5 minutes")
            Text("Every 15 minutes").tag("Every 15 minutes")
            Text("Hourly").tag("Hourly")
            Text("Manual only").tag("Manual only")
          }
          .pickerStyle(.menu)
          ForEach(store.watchedFolders) { folder in
            WatchedFolderRow(folder: folder)
          }
          Button("Add folder placeholder", systemImage: "folder.badge.plus", action: store.addWatchedFolderPlaceholder)
            .buttonStyle(.bordered)
        }

        SettingsPanel(title: "Review controls", symbol: "checkmark.shield.fill") {
          Toggle("Require review for risky email/order matches", isOn: $store.settings.requireReviewForRiskyMatches)
          Toggle("Plan delivery exception alerts", isOn: $store.settings.notifyOnDeliveryExceptions)
          Stepper("Exception alert threshold: \(store.settings.exceptionThreshold)", value: $store.settings.exceptionThreshold, in: 1...10)
        }

        SettingsPanel(title: "Future source planning", symbol: "link.badge.plus") {
          Toggle("Plan Shopify supplier sync", isOn: $store.settings.shopifySyncEnabled)
          Toggle("Plan password-vault login sync", isOn: $store.settings.storeLoginSyncEnabled)
          Toggle("Plan carrier tracking handoff", isOn: $store.settings.carrierTrackingEnabled)
          Picker("Future carrier tracking mode", selection: $store.settings.carrierTrackingMode) {
            Text("Parcel handoff placeholder").tag("Export to Parcel")
            Text("Carrier API placeholder").tag("Free carrier API")
            Text("Manual local updates").tag("Manual updates")
          }
          .pickerStyle(.menu)
          Button("Save settings", systemImage: "checkmark", action: store.saveSettings)
            .buttonStyle(.borderedProminent)
        }
      }
      .padding(isCompact ? 14 : 24)
    }
  }
}

struct IntegrationStatusRow: View {
  var title: String
  var status: String
  var symbol: String
  var color: Color

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: symbol)
        .foregroundStyle(color)
        .frame(width: 22)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption.weight(.semibold))
        Text(status)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .padding(10)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
