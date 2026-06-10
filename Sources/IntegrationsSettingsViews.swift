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
            Button("Microsoft 365 setup", systemImage: "mail.stack.fill", action: store.addMicrosoft365MailboxConnectionPlaceholder)
            Button("Mailbox placeholder", systemImage: "envelope.badge.fill", action: store.addTrackedMailboxPlaceholder)
            Button("Shopify placeholder", systemImage: "cart.badge.plus", action: store.connectShopifyPlaceholder)
            Button("Folder placeholder", systemImage: "folder.badge.plus", action: store.addWatchedFolderPlaceholder)
            Button("Login placeholder", systemImage: "key.fill", action: store.addStoreLoginPlaceholder)
          }
        }

        SettingsPanel(title: "Microsoft 365 mailbox setup", symbol: "mail.stack.fill") {
          Text("Prepare the mailbox connection in local placeholder records, then test the mocked Graph refresh into Inbox. Nothing here opens browser sign-in, requests tokens, stores secrets, or contacts Microsoft Graph.")
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
            } onSimulatedRefresh: {
              store.importSimulatedFetchedMailboxMessages(for: connection)
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
  var onSimulatedRefresh: () -> Void
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

      Text("Local setup only. Mock Graph refresh uses deterministic sample messages; no OAuth, browser sign-in, token exchange, Keychain storage, network call, background sync, notification, or mailbox connection is used.")
        .font(.caption)
        .foregroundStyle(.secondary)

      Microsoft365AuthStateSection(authState: authState)

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
        ActionGroupHeader(title: "Future OAuth boundary", symbol: "person.badge.key.fill")
        CompactActionRow {
          Button("Connect Microsoft 365 mock", systemImage: "person.crop.circle.badge.checkmark", action: onMockAuthConnect)
            .buttonStyle(.borderedProminent)
          Button("Mock auth failure", systemImage: "xmark.octagon", action: onMockAuthFailure)
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

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Future Microsoft 365 auth state", systemImage: "person.badge.key.fill")
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
      }
      Text(authState.detailText)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Text("Mock auth only: no browser sign-in opens, no OAuth flow runs, no tokens are requested or stored, Keychain is not used, and Microsoft Graph network calls remain mocked.")
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

struct ActionGroupHeader: View {
  var title: String
  var symbol: String

  var body: some View {
    Label(title, systemImage: symbol)
      .font(.caption.weight(.semibold))
      .foregroundStyle(.secondary)
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
      .navigationTitle("Microsoft 365 mailbox")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { onSave(draft) }
        }
      }
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
