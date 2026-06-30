import SwiftUI

struct IntegrationsView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var setupSearchText = ""

  private var isCompact: Bool { horizontalSizeClass == .compact }
  private var hasSpaceMailSetup: Bool { !store.spaceMailIMAPConnections.isEmpty }
  private var hasSpaceMailCredentialReference: Bool {
    store.spaceMailIMAPConnections.contains {
      $0.credentialStorageStatus.localizedCaseInsensitiveContains("available")
        || $0.credentialStorageStatus.localizedCaseInsensitiveContains("ready")
    }
  }
  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.spaceMailIntakeHealthSummaries.first
  }

  private var recommendedSetupTitle: String {
    if !hasSpaceMailSetup {
      return "Start with SpaceMail setup"
    }
    if !hasSpaceMailCredentialReference {
      return "Add the SpaceMail Keychain credential"
    }
    if let latestSpaceMailSummary, latestSpaceMailSummary.pendingUncertainReviewCount > 0 || latestSpaceMailSummary.uncertainCount > 0 {
      return "Review uncertain mixed-mailbox messages"
    }
    return "Run SpaceMail manual refresh when needed"
  }

  private var recommendedSetupDetail: String {
    if !hasSpaceMailSetup {
      return "SpaceMail IMAP is the only live mailbox path currently intended for this project. Add or edit that setup before using planning-only integrations."
    }
    if !hasSpaceMailCredentialReference {
      return "Use the secure password prompt on the SpaceMail row. Passwords and app passwords must not be typed into setup notes or JSON-backed fields."
    }
    if let latestSpaceMailSummary, latestSpaceMailSummary.pendingUncertainReviewCount > 0 || latestSpaceMailSummary.uncertainCount > 0 {
      return "Uncertain mixed-mailbox messages stay out of Inbox until an operator imports or dismisses them locally."
    }
    return "Use the explicit read-only SpaceMail refresh action. Microsoft 365, Shopify, watched folders, and login placeholders remain secondary planning surfaces."
  }

  private var recommendedSetupTone: Color {
    if !hasSpaceMailSetup || !hasSpaceMailCredentialReference { return .orange }
    if let latestSpaceMailSummary, latestSpaceMailSummary.pendingUncertainReviewCount > 0 || latestSpaceMailSummary.uncertainCount > 0 { return .orange }
    return .green
  }

  private var normalizedSetupSearch: String {
    setupSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  private func matchesSetupSection(_ terms: String...) -> Bool {
    let query = normalizedSetupSearch
    guard !query.isEmpty else { return true }
    return terms.joined(separator: " ").lowercased().contains(query)
  }

  private var showsRecommendedSetup: Bool {
    matchesSetupSection("recommended", "setup", "path", "current", "next", "SpaceMail", "credential", "uncertain", "manual refresh")
  }

  private var showsSpaceMailSetup: Bool {
    matchesSetupSection("SpaceMail", "IMAP", "Keychain", "credential", "mixed mailbox", "classifier", "uncertain", "filtered", "real refresh", "mock refresh")
  }

  private var showsMicrosoftSetup: Bool {
    matchesSetupSection("Microsoft", "365", "Graph", "OAuth", "MSAL", "mock", "sign in", "mailbox")
  }

  private var showsTrackedMailboxes: Bool {
    matchesSetupSection("tracked", "mailboxes", "mailbox", "email", "placeholder")
  }

  private var showsShopifySetup: Bool {
    matchesSetupSection("Shopify", "store", "commerce", "placeholder")
  }

  private var showsFolderSetup: Bool {
    matchesSetupSection("watched", "folders", "folder", "local", "placeholder")
  }

  private var showsSourceConnections: Bool {
    matchesSetupSection("source", "connections", "accounts", "vendor", "credentials", "reference")
  }

  private var visibleSetupSectionCount: Int {
    [
      showsRecommendedSetup,
      showsSpaceMailSetup,
      showsMicrosoftSetup,
      showsTrackedMailboxes,
      showsShopifySetup,
      showsFolderSetup,
      showsSourceConnections
    ].filter(\.self).count
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        VStack(alignment: .leading, spacing: 10) {
          Text("Local source setup")
            .font(isCompact ? .title2.bold() : .title.bold())
          Text("SpaceMail IMAP is the current manual read-only mailbox path. Shopify, folders, logins, and Microsoft 365 remain setup or planning surfaces unless explicitly tested.")
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

        SettingsPanel(title: "Find setup section", symbol: "magnifyingglass") {
          VStack(alignment: .leading, spacing: 10) {
            FilterControlGrid {
              TextField("Search setup, SpaceMail, Microsoft 365, Shopify, folders, credentials", text: $setupSearchText)
                .textFieldStyle(.roundedBorder)

              Button("Clear", systemImage: "xmark.circle") {
                setupSearchText = ""
              }
              .buttonStyle(.bordered)
              .disabled(normalizedSetupSearch.isEmpty)

              Badge("\(visibleSetupSectionCount) sections", color: visibleSetupSectionCount == 0 ? .orange : .blue)
            }

            Text("Use this to narrow the setup page while testing. It only changes which local setup sections are visible.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        if visibleSetupSectionCount == 0 {
          MVPEmptyState(title: "No setup sections match", detail: "Clear the setup search or try SpaceMail, Microsoft 365, Shopify, folder, mailbox, credential, or classifier.", symbol: "magnifyingglass")
        }

        if showsRecommendedSetup {
          SettingsPanel(title: "Recommended setup path", symbol: "arrow.forward.circle.fill") {
          VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
              Image(systemName: hasSpaceMailSetup ? "server.rack" : "server.rack.fill")
                .foregroundStyle(recommendedSetupTone)
                .frame(width: 24)
              VStack(alignment: .leading, spacing: 4) {
                Text(recommendedSetupTitle)
                  .font(.headline)
                Text(recommendedSetupDetail)
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
              Spacer()
              Badge(hasSpaceMailSetup ? "SpaceMail" : "Setup needed", color: recommendedSetupTone)
            }

            MetricStrip(items: [
              ("SpaceMail", hasSpaceMailSetup ? "Configured" : "Not set", hasSpaceMailSetup ? .green : .orange),
              ("Credential", hasSpaceMailCredentialReference ? "Keychain" : "Needed", hasSpaceMailCredentialReference ? .green : .orange),
              ("Fetched", "\(latestSpaceMailSummary?.fetchedCount ?? 0)", .blue),
              ("Imported", "\(latestSpaceMailSummary?.importedCount ?? 0)", (latestSpaceMailSummary?.importedCount ?? 0) > 0 ? .green : .secondary),
              ("Uncertain", "\(latestSpaceMailSummary?.pendingUncertainReviewCount ?? latestSpaceMailSummary?.uncertainCount ?? 0)", ((latestSpaceMailSummary?.pendingUncertainReviewCount ?? latestSpaceMailSummary?.uncertainCount ?? 0) > 0) ? .orange : .secondary)
            ])

            Text("Advanced providers stay available below, but they should not be treated as the daily mailbox path unless the project explicitly switches away from SpaceMail.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)

            SettingsReleaseCandidateCard(store: store)
          }
        }
        }

        if showsSpaceMailSetup {
          SettingsPanel(title: "SpaceMail IMAP setup", symbol: "server.rack") {
          Text("Use this as the current mailbox path for SpaceMail. This section stores non-secret IMAP setup fields, manages the password/app-password in Keychain, and keeps mock refresh separate from the real manual refresh boundary.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Text("Do not enter passwords here. No password, app password, auth string, or Keychain item is stored in JSON or audit logs.")
            .font(.caption)
            .foregroundStyle(.secondary)
          SpaceMailOperatorGuidanceStack(store: store)
          CompactActionRow {
            Button("Add SpaceMail placeholder", systemImage: "plus", action: store.addSpaceMailIMAPConnectionPlaceholder)
              .buttonStyle(.bordered)
            Badge("\(store.spaceMailIMAPConnections.count) placeholders", color: .blue)
          }
          if store.spaceMailIMAPConnections.isEmpty {
            MVPEmptyState(title: "No SpaceMail IMAP setup", detail: "Add a SpaceMail setup to capture host, port, folder, mixed-mailbox mode, and Keychain credential status before manual refresh.", symbol: "server.rack")
          }
          ForEach(store.spaceMailIMAPConnections) { connection in
            SpaceMailIMAPConnectionRow(connection: connection, healthSummary: store.spaceMailIntakeHealthSummary(for: connection)) { updatedConnection in
              store.updateSpaceMailIMAPConnection(updatedConnection)
            } onReviewed: {
              store.markSpaceMailIMAPConnectionReviewed(connection)
            } onMockRefresh: {
              store.importMockSpaceMailIMAPMessages(for: connection)
            } onRealRefresh: {
              store.importRealSpaceMailIMAPMessages(for: connection)
            } onImportUncertain: { uncertainMessage in
              store.importUncertainSpaceMailMessage(uncertainMessage, for: connection)
            } onDismissUncertain: { uncertainMessage in
              store.dismissUncertainSpaceMailMessage(uncertainMessage, for: connection)
            } onImportFiltered: { filteredMessage in
              store.importFilteredSpaceMailMessage(filteredMessage, for: connection)
            } onDismissFiltered: { filteredMessage in
              store.dismissFilteredSpaceMailMessage(filteredMessage, for: connection)
            } onPromoteFiltered: { filteredMessage in
              store.promoteFilteredSpaceMailMessageToUncertain(filteredMessage, for: connection)
            } onDismissAllUncertain: {
              store.dismissAllUncertainSpaceMailMessages(for: connection)
            } onDismissAllFiltered: {
              store.dismissAllFilteredSpaceMailMessages(for: connection)
            } onTaskFromUncertain: { uncertainMessage in
              store.createReviewTask(from: uncertainMessage, connection: connection)
            } onDraftFromUncertain: { uncertainMessage in
              store.createDraftMessage(from: uncertainMessage, connection: connection)
            } onTaskFromFiltered: { filteredMessage in
              store.createReviewTask(from: filteredMessage, connection: connection)
            } onDraftFromFiltered: { filteredMessage in
              store.createDraftMessage(from: filteredMessage, connection: connection)
            } onAddUncertainHint: { uncertainMessage, target in
              store.addSpaceMailHintFromUncertain(uncertainMessage, target: target, for: connection)
            } onAddFilteredHint: { filteredMessage, target in
              store.addSpaceMailHintFromFiltered(filteredMessage, target: target, for: connection)
            } onTestClassifier: {
              store.testSpaceMailAmbiguousClassifier(for: connection)
            } onTestCustomClassifier: { sender, subject, preview in
              store.testSpaceMailCustomClassifier(for: connection, sender: sender, subject: subject, preview: preview)
            } onRunClassifierSuite: {
              store.runSpaceMailClassifierTestSuite(for: connection)
            } onApplyFilterPreset: { preset in
              store.applySpaceMailFilterPreset(preset, to: connection)
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
        }

        if showsMicrosoftSetup {
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
        }

        if showsTrackedMailboxes {
          SettingsPanel(title: "Tracked mailboxes", symbol: "envelope.badge.fill") {
          ForEach(store.mailboxes) { mailbox in
            MailboxConnectionRow(mailbox: mailbox)
          }
        }
        }
        if showsShopifySetup {
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
        }
        if showsFolderSetup {
          SettingsPanel(title: "Watched folders", symbol: "folder.fill.badge.gearshape") {
          ForEach(store.watchedFolders) { folder in
            WatchedFolderRow(folder: folder)
          }
        }
        }
        if showsSourceConnections {
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
    ("4", "Run mock Graph test", "Import deterministic sample messages through the provider-neutral intake path."),
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
          Button("Use mock Microsoft auth", systemImage: "person.crop.circle.badge.checkmark", action: onMockAuthConnect)
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
        ActionGroupHeader(title: "Setup and mock test refresh", symbol: "mail.and.text.magnifyingglass")
        CompactActionRow {
          Button("Edit setup", systemImage: "pencil") {
            isEditing = true
          }
          .buttonStyle(.bordered)
          Button("Ready for review", systemImage: "checkmark.shield.fill", action: onReadyForReview)
            .buttonStyle(.bordered)
          Button("Run mock Graph test", systemImage: "tray.and.arrow.down.fill", action: onSimulatedRefresh)
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
      Text("Fallback: mock Microsoft auth tests auth state locally. Mock Graph test imports deterministic sample messages without contacting Microsoft Graph.")
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
  var healthSummary: SpaceMailIntakeHealthSummary
  var onSave: (SpaceMailIMAPConnection) -> Void
  var onReviewed: () -> Void
  var onMockRefresh: () -> Void
  var onRealRefresh: () -> Void
  var onImportUncertain: (SpaceMailUncertainMessage) -> Void
  var onDismissUncertain: (SpaceMailUncertainMessage) -> Void
  var onImportFiltered: (SpaceMailFilteredMessage) -> Void
  var onDismissFiltered: (SpaceMailFilteredMessage) -> Void
  var onPromoteFiltered: (SpaceMailFilteredMessage) -> Void
  var onDismissAllUncertain: () -> Void
  var onDismissAllFiltered: () -> Void
  var onTaskFromUncertain: (SpaceMailUncertainMessage) -> Void
  var onDraftFromUncertain: (SpaceMailUncertainMessage) -> Void
  var onTaskFromFiltered: (SpaceMailFilteredMessage) -> Void
  var onDraftFromFiltered: (SpaceMailFilteredMessage) -> Void
  var onAddUncertainHint: (SpaceMailUncertainMessage, SpaceMailHintTarget) -> Void
  var onAddFilteredHint: (SpaceMailFilteredMessage, SpaceMailHintTarget) -> Void
  var onTestClassifier: () -> Void
  var onTestCustomClassifier: (String, String, String) -> Void
  var onRunClassifierSuite: () -> Void
  var onApplyFilterPreset: (SpaceMailFilterPreset) -> Void
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
  @State private var classifierSender = "customer@example.com"
  @State private var classifierSubject = "Delivery question"
  @State private var classifierPreview = "Can you check whether this relates to an order? I do not have the tracking number yet."

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

      spaceMailSetupFlow

      setupActions

      keychainCredentialSection

      SpaceMailIntakeHealthCard(summary: healthSummary)

      spaceMailRefreshSummary
      spaceMailNextSteps
      spaceMailReviewQueueSummary

      if !connection.uncertainMessages.isEmpty {
        uncertainMessagesReview
      }

      if !connection.filteredMessages.isEmpty {
        filteredMessagesReview
      }

      if connection.mailboxMode == .mixedFiltered {
        spaceMailFilterTuningSummary
      }

      if connection.mailboxMode == .mixedFiltered {
        spaceMailClassifierTest
      }

      if !connection.refreshHistory.isEmpty {
        spaceMailRefreshHistory
      }

      credentialStateTestSection

      maintenanceActions
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

  private var spaceMailSetupFlow: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("SpaceMail operator flow", systemImage: "list.number")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.blue)
      Text("Use this row from top to bottom: confirm setup, set the Keychain password, choose the mailbox mode, run a manual refresh, review the results, then tune the classifier only if the result looks wrong.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      CompactMetadataGrid(minimumWidth: 170) {
        Badge("1 Confirm setup", color: .blue)
        Badge("2 Keychain password", color: .purple)
        Badge("3 Mailbox mode", color: .teal)
        Badge("4 Manual refresh", color: .green)
        Badge("5 Review results", color: .orange)
        Badge("6 Tune classifier", color: .secondary)
      }
      Text("Real refresh is read-only IMAP. ParcelOps must not delete, move, mark read, flag, send, or modify mailbox items.")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
  }

  private var setupActions: some View {
    VStack(alignment: .leading, spacing: 6) {
      ActionGroupHeader(title: "1. Confirm mailbox settings", symbol: "server.rack")
      Text("Check email address, host, port, SSL/TLS mode, folder, and mixed-mailbox mode before running a real refresh.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      CompactActionRow {
        Button("Edit setup", systemImage: "pencil") { isEditing = true }
        Button("Mark reviewed", systemImage: "checkmark.circle", action: onReviewed)
      }
    }
  }

  private var keychainCredentialSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      ActionGroupHeader(title: "2. Set Keychain credential", symbol: "key.horizontal")
      Text("Set, check, or clear the SpaceMail password/app-password in Keychain. ParcelOps stores only the non-secret status label in JSON and Audit.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      CompactActionRow {
        Button("Set/update password", systemImage: "key.fill") { isCredentialSheetPresented = true }
        Button("Check credential", systemImage: "checkmark.seal", action: onCheckCredential)
        Button("Clear credential", systemImage: "xmark.circle", role: .destructive, action: onClearCredential)
      }
    }
  }

  private var credentialStateTestSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      ActionGroupHeader(title: "Advanced local test controls", symbol: "wrench.and.screwdriver")
      Text("Use these only to simulate credential status labels while testing UI states. They do not create, read, write, delete, store, or log passwords or Keychain items.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      CompactActionRow {
        Button("Credential ready", systemImage: "key.radiowaves.forward", action: onCredentialReady)
        Button("Credential missing", systemImage: "key.slash", action: onCredentialMissing)
        Button("Storage error", systemImage: "exclamationmark.triangle", action: onCredentialError)
        Button("Clear reference", systemImage: "xmark.circle", action: onCredentialClear)
        Button("Run mock refresh", systemImage: "tray.and.arrow.down", action: onMockRefresh)
      }
    }
  }

  private var maintenanceActions: some View {
    VStack(alignment: .leading, spacing: 6) {
      ActionGroupHeader(title: "Maintenance", symbol: "gearshape")
      CompactActionRow {
        Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
      }
    }
  }

  private var spaceMailRefreshSummary: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("4. Run manual refresh", systemImage: "tray.and.arrow.down.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(spaceMailRefreshColor)
      CompactActionRow {
        Button("Run real SpaceMail refresh", systemImage: "network", action: onRealRefresh)
      }
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
        Text("Mixed mailbox mode keeps filtered non-order messages out of Inbox. Uncertain previews stay here for review; Audit remains available for detailed reason labels.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.teal)
          .fixedSize(horizontal: false, vertical: true)
      }
      if !connection.lastRefreshFilteredExamples.isEmpty {
        Text("Filtered examples: \(connection.lastRefreshFilteredExamples.joined(separator: "; "))")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      if !connection.lastRefreshUncertainExamples.isEmpty {
        Text("Uncertain examples: \(connection.lastRefreshUncertainExamples.joined(separator: "; "))")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      if !connection.lastRefreshReasonBreakdown.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Text("Classifier reasons")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
          ForEach(Array(connection.lastRefreshReasonBreakdown.prefix(6))) { item in
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Badge(item.decision, color: classifierReasonColor(item.decision))
              Text("\(item.count)x \(item.reason)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
              Spacer(minLength: 0)
            }
          }
        }
        .padding(8)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(spaceMailRefreshColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private var spaceMailNextSteps: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("5. What to do after refresh", systemImage: "arrow.turn.down.right")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.blue)

      ForEach(Array(spaceMailNextStepItems.enumerated()), id: \.offset) { _, item in
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: item.symbol)
            .foregroundStyle(item.color)
            .frame(width: 18)
          VStack(alignment: .leading, spacing: 2) {
            Text(item.title)
              .font(.caption.weight(.semibold))
            Text(item.detail)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
  }

  private var spaceMailReviewQueueSummary: some View {
    let uncertainCount = connection.uncertainMessages.count
    let filteredCount = connection.filteredMessages.count

    return VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label("5. Review queued examples", systemImage: "tray.full.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(uncertainCount > 0 ? .orange : (filteredCount > 0 ? .teal : .secondary))
        Spacer()
        Badge("\(uncertainCount) uncertain", color: uncertainCount > 0 ? .orange : .secondary)
        Badge("\(filteredCount) filtered", color: filteredCount > 0 ? .teal : .secondary)
      }
      Text(reviewQueueSummaryText(uncertainCount: uncertainCount, filteredCount: filteredCount))
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      if uncertainCount > 0 || filteredCount > 0 {
        CompactActionRow {
          if uncertainCount > 0 {
            Button("Dismiss all uncertain", systemImage: "xmark.circle", role: .destructive, action: onDismissAllUncertain)
          }
          if filteredCount > 0 {
            Button("Dismiss all filtered", systemImage: "line.3.horizontal.decrease.circle", role: .destructive, action: onDismissAllFiltered)
          }
        }
        Text("Bulk dismiss only clears local review queues. It does not delete intake, reset duplicate metadata, or modify mailbox messages.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
  }

  private func reviewQueueSummaryText(uncertainCount: Int, filteredCount: Int) -> String {
    if uncertainCount == 0 && filteredCount == 0 {
      return "No mixed-mailbox examples are waiting for local review. Imported order mail should be handled in Inbox."
    }
    if uncertainCount > 0 && filteredCount > 0 {
      return "Review uncertain previews first. Filtered examples are lower priority and should only be imported or promoted when a real order was filtered too aggressively."
    }
    if uncertainCount > 0 {
      return "Uncertain previews are order-adjacent but missing strong IDs. Import only true order updates, or dismiss locally after review."
    }
    return "Filtered examples stayed out of Inbox. Move one to uncertain review if it may be relevant, or dismiss after spot-checking."
  }

  private var spaceMailNextStepItems: [(title: String, detail: String, symbol: String, color: Color)] {
    if connection.lastManualRefreshDate == "Never" {
      return [
        ("Run a manual refresh", "After setup and Keychain credential checks pass, run the real read-only refresh from this row.", "tray.and.arrow.down.fill", .blue),
        ("Then review results here", "Imported messages go to Inbox; uncertain and filtered examples stay in this Mailbox Monitor section.", "list.bullet.clipboard.fill", .teal)
      ]
    }

    var items: [(title: String, detail: String, symbol: String, color: Color)] = []

    if connection.lastRefreshImportedCount > 0 {
      items.append((
        "Review imported Inbox rows",
        "\(connection.lastRefreshImportedCount) likely order message\(connection.lastRefreshImportedCount == 1 ? "" : "s") reached Inbox. Confirm fields, then link or create orders.",
        "tray.full.fill",
        .green
      ))
    }

    if !connection.uncertainMessages.isEmpty || connection.lastRefreshUncertainCount > 0 {
      let count = max(connection.uncertainMessages.count, connection.lastRefreshUncertainCount)
      items.append((
        "Review uncertain previews",
        "\(count) message\(count == 1 ? "" : "s") looked order-adjacent but lacked strong identifiers. Import only true order updates.",
        "questionmark.folder.fill",
        .orange
      ))
    }

    if connection.lastRefreshFilteredNonOrderCount > 0 {
      items.append((
        "Filtered mail stayed out of Inbox",
        "\(connection.lastRefreshFilteredNonOrderCount) message\(connection.lastRefreshFilteredNonOrderCount == 1 ? "" : "s") were treated as non-order mail. Check filtered examples only if expected order mail is missing.",
        "line.3.horizontal.decrease.circle.fill",
        .teal
      ))
    }

    if connection.lastRefreshImportedCount == 0 && connection.lastRefreshUncertainCount == 0 && connection.lastRefreshFilteredNonOrderCount == 0 {
      items.append((
        "No operator action from latest refresh",
        "The latest refresh did not produce imported, uncertain, or filtered messages. Check host/folder only if this is unexpected.",
        "checkmark.seal.fill",
        .green
      ))
    }

    if connection.lastRefreshDuplicateCount > 0 {
      items.append((
        "Duplicates were not re-added",
        "\(connection.lastRefreshDuplicateCount) already-seen message\(connection.lastRefreshDuplicateCount == 1 ? "" : "s") were skipped or refreshed in place, so Inbox should not be duplicated.",
        "doc.on.doc.fill",
        .secondary
      ))
    }

    return Array(items.prefix(4))
  }

  private func classifierReasonColor(_ decision: String) -> Color {
    if decision.localizedCaseInsensitiveContains("import") { return .green }
    if decision.localizedCaseInsensitiveContains("uncertain") { return .orange }
    if decision.localizedCaseInsensitiveContains("filter") { return .teal }
    return .secondary
  }

  private func classifierCautionColor(_ label: String) -> Color {
    if label.localizedCaseInsensitiveContains("score") { return .secondary }
    if label.localizedCaseInsensitiveContains("no order") || label.localizedCaseInsensitiveContains("no strong") { return .orange }
    return .teal
  }

  private func parserStatusColor(_ status: String) -> Color {
    if status.localizedCaseInsensitiveContains("needs review") { return .orange }
    if status.localizedCaseInsensitiveContains("passed") { return .green }
    return .secondary
  }

  private var spaceMailFilterTuningSummary: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("6. Tune mixed-mailbox classifier", systemImage: "line.3.horizontal.decrease.circle")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.purple)
      Text("Use this after reviewing refresh results. Presets and hints tune the built-in classifier before messages reach Inbox. They do not call external AI and do not change mailbox messages.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      CompactMetadataGrid(minimumWidth: 130) {
        Badge("\(connection.trustedSenderHints.count) trusted senders", color: connection.trustedSenderHints.isEmpty ? .secondary : .purple)
        Badge("\(connection.importKeywordHints.count) import hints", color: connection.importKeywordHints.isEmpty ? .secondary : .green)
        Badge("\(connection.uncertainKeywordHints.count) uncertain hints", color: connection.uncertainKeywordHints.isEmpty ? .secondary : .orange)
        Badge("\(connection.filterKeywordHints.count) filter hints", color: connection.filterKeywordHints.isEmpty ? .secondary : .teal)
      }
      if !connection.trustedSenderHints.isEmpty {
        Text("Trusted senders: \(connection.trustedSenderHints.joined(separator: ", "))")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      if !connection.importKeywordHints.isEmpty {
        Text("Import hints: \(connection.importKeywordHints.joined(separator: ", "))")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      if !connection.uncertainKeywordHints.isEmpty {
        Text("Uncertain hints: \(connection.uncertainKeywordHints.joined(separator: ", "))")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      if !connection.filterKeywordHints.isEmpty {
        Text("Filter hints: \(connection.filterKeywordHints.joined(separator: ", "))")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      CompactActionRow {
        ForEach(SpaceMailFilterPreset.allCases) { preset in
          Button(presetButtonTitle(preset), systemImage: presetSymbol(preset)) {
            onApplyFilterPreset(preset)
          }
        }
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.purple.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
  }

  private func presetButtonTitle(_ preset: SpaceMailFilterPreset) -> String {
    switch preset {
    case .conservative: "Conservative"
    case .balanced: "Balanced"
    case .forwardedOrders: "Forwarded orders"
    }
  }

  private func presetSymbol(_ preset: SpaceMailFilterPreset) -> String {
    switch preset {
    case .conservative: "line.3.horizontal.decrease.circle"
    case .balanced: "slider.horizontal.3"
    case .forwardedOrders: "envelope.badge.fill"
    }
  }

  private var spaceMailRefreshHistory: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        Label("Recent SpaceMail activity", systemImage: "clock.arrow.circlepath")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.blue)
        Spacer()
        Badge("\(connection.refreshHistory.count) saved", color: .blue)
      }
      Text("Local history keeps the latest refresh and review outcomes here, so Audit can stay for deeper investigation.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      ForEach(Array(connection.refreshHistory.prefix(6))) { entry in
        VStack(alignment: .leading, spacing: 5) {
          HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
              Text(entry.eventType)
                .font(.caption.weight(.semibold))
              Text(entry.timestamp)
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(entry.status, color: historyColor(for: entry.status))
          }
          CompactMetadataGrid(minimumWidth: 96) {
            Badge("\(entry.fetchedCount) fetched", color: .blue)
            Badge("\(entry.importedCount) imported", color: entry.importedCount > 0 ? .green : .secondary)
            Badge("\(entry.duplicateCount) dupes", color: entry.duplicateCount > 0 ? .orange : .secondary)
            Badge("\(entry.filteredNonOrderCount) filtered", color: entry.filteredNonOrderCount > 0 ? .teal : .secondary)
            Badge("\(entry.uncertainCount) uncertain", color: entry.uncertainCount > 0 ? .orange : .secondary)
          }
          Text(entry.summary)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
  }

  private func historyColor(for status: String) -> Color {
    if status.localizedCaseInsensitiveContains("success") || status.localizedCaseInsensitiveContains("imported") { return .green }
    if status.localizedCaseInsensitiveContains("duplicate") || status.localizedCaseInsensitiveContains("filtered") { return .teal }
    if status.localizedCaseInsensitiveContains("uncertain") || status.localizedCaseInsensitiveContains("dismissed") { return .orange }
    if status.localizedCaseInsensitiveContains("failed") || status.localizedCaseInsensitiveContains("missing") { return .red }
    return .secondary
  }

  private var spaceMailClassifierTest: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        Label("6. Test classifier decisions", systemImage: "questionmark.diamond.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
        Spacer()
        classifierTestBadge
      }
      Text("Built-in sample: Delivery question / Can you check whether this relates to an order? I do not have the tracking number yet.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Text("Result includes the local filter decision plus the intake fields ParcelOps would detect from the same sample.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      spaceMailClassifierRuleGuide
      Text(connection.classifierTestSummary)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(classifierTestColor)
        .fixedSize(horizontal: false, vertical: true)
      VStack(alignment: .leading, spacing: 6) {
        TextField("Sender", text: $classifierSender)
          .textFieldStyle(.roundedBorder)
        TextField("Subject", text: $classifierSubject)
          .textFieldStyle(.roundedBorder)
        TextField("Body preview", text: $classifierPreview, axis: .vertical)
          .lineLimit(2...4)
          .textFieldStyle(.roundedBorder)
      }
      CompactActionRow {
        Button("Run built-in test", systemImage: "play.circle", action: onTestClassifier)
        Button("Run custom test", systemImage: "text.magnifyingglass") {
          onTestCustomClassifier(classifierSender, classifierSubject, classifierPreview)
        }
        .disabled(classifierSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && classifierPreview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        Button("Run test suite", systemImage: "checklist") {
          onRunClassifierSuite()
        }
      }
      if !connection.classifierTestResults.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Text("Classifier test results")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
          ForEach(connection.classifierTestResults) { result in
            VStack(alignment: .leading, spacing: 4) {
              HStack(alignment: .firstTextBaseline) {
                Text(result.sampleName)
                  .font(.caption.weight(.semibold))
                Spacer()
                Badge(result.decision, color: classifierReasonColor(result.decision))
              }
              Text("\(result.reason) • score \(result.score)")
                .font(.caption2)
                .foregroundStyle(.secondary)
              if !result.positiveEvidenceLabels.isEmpty {
                CompactMetadataGrid(minimumWidth: 150) {
                  ForEach(result.positiveEvidenceLabels, id: \.self) { label in
                    Badge(label, color: .green)
                  }
                }
              }
              if !result.cautionLabels.isEmpty {
                CompactMetadataGrid(minimumWidth: 150) {
                  ForEach(result.cautionLabels, id: \.self) { label in
                    Badge(label, color: classifierCautionColor(label))
                  }
                }
              }
              Text(result.nextActionText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(classifierReasonColor(result.decision))
                .fixedSize(horizontal: false, vertical: true)
              Text(result.parserStatus)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(parserStatusColor(result.parserStatus))
                .fixedSize(horizontal: false, vertical: true)
              CompactMetadataGrid(minimumWidth: 120) {
                Badge(result.detectedOrderNumber, color: result.detectedOrderNumber.isPlaceholderValidationValue ? .secondary : .blue)
                Badge(result.detectedTrackingNumber, color: result.detectedTrackingNumber.isPlaceholderValidationValue ? .secondary : .purple)
                Badge(result.detectedMerchant, color: .secondary)
                if result.expectedOrderNumber != "No expected order" {
                  Badge("Expected \(result.expectedOrderNumber)", color: .blue)
                }
                if result.expectedTrackingNumber != "No expected tracking" {
                  Badge("Expected \(result.expectedTrackingNumber)", color: .purple)
                }
              }
            }
            .padding(8)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
          }
        }
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private var spaceMailClassifierRuleGuide: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Decision guide")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
      CompactMetadataGrid(minimumWidth: 180) {
        Badge("Import: signal + order/tracking ID", color: .green)
        Badge("Uncertain: order-ish, missing ID", color: .orange)
        Badge("Filter: marketing/security/social", color: .teal)
        Badge("Manual review: safe previews only", color: .secondary)
      }
      Text("Use the built-in suite after changing presets or hints. It should import clear order/refund samples, keep delivery questions uncertain, and filter obvious marketing or security messages.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(8)
    .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
  }

  @ViewBuilder
  private var classifierTestBadge: some View {
    if connection.classifierTestSummary.localizedCaseInsensitiveContains("Uncertain") {
      Badge("Uncertain", color: .orange)
    } else if connection.classifierTestSummary.localizedCaseInsensitiveContains("Imported") {
      Badge("Imported", color: .green)
    } else if connection.classifierTestSummary.localizedCaseInsensitiveContains("Filtered") {
      Badge("Filtered", color: .teal)
    } else {
      Badge("Not run", color: .secondary)
    }
  }

  private var classifierTestColor: Color {
    if connection.classifierTestSummary.localizedCaseInsensitiveContains("Uncertain") { return .orange }
    if connection.classifierTestSummary.localizedCaseInsensitiveContains("Imported") { return .green }
    if connection.classifierTestSummary.localizedCaseInsensitiveContains("Filtered") { return .teal }
    return .secondary
  }

  private var spaceMailRefreshColor: Color {
    let status = connection.connectionStatus
    if status.localizedCaseInsensitiveContains("success") { return .green }
    if status.localizedCaseInsensitiveContains("duplicate") { return .teal }
    if status.localizedCaseInsensitiveContains("failed") || status.localizedCaseInsensitiveContains("missing") { return .orange }
    return .secondary
  }

  private var uncertainMessagesReview: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("5. Review uncertain SpaceMail messages", systemImage: "questionmark.folder.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.orange)
      Text("These previews looked possibly order-related, but not strong enough for automatic Inbox import. Import only if the preview is relevant, or dismiss it locally.")
        .font(.caption2)
        .foregroundStyle(.secondary)
      CompactActionRow {
        Button("Dismiss all uncertain", systemImage: "xmark.circle", role: .destructive, action: onDismissAllUncertain)
      }
      ForEach(connection.uncertainMessages) { message in
        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
              Text(message.subject)
                .font(.caption.weight(.semibold))
              Text("\(message.sender) • \(message.receivedDate)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge("Uncertain", color: .orange)
          }
          Text(message.bodyPreview)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(3)
          Text("Reason: \(message.reason)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.orange)
          CompactActionRow {
            Button("Import to Inbox", systemImage: "tray.and.arrow.down.fill") {
              onImportUncertain(message)
            }
            Button("Task", systemImage: "checklist") {
              onTaskFromUncertain(message)
            }
            Button("Draft", systemImage: "envelope.open.fill") {
              onDraftFromUncertain(message)
            }
            Button("Trust sender", systemImage: "person.badge.shield.checkmark") {
              onAddUncertainHint(message, .trustedSender)
            }
            Button("Uncertain hint", systemImage: "questionmark.diamond") {
              onAddUncertainHint(message, .uncertainKeyword)
            }
            Button("Import hint", systemImage: "plus.circle") {
              onAddUncertainHint(message, .importKeyword)
            }
            Button("Dismiss", systemImage: "xmark.circle", role: .destructive) {
              onDismissUncertain(message)
            }
          }
        }
        .padding(8)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private var filteredMessagesReview: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("5. Review filtered SpaceMail examples", systemImage: "line.3.horizontal.decrease.circle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.teal)
      Text("These previews were filtered out of Inbox. Import one only if the classifier was too strict, or dismiss it locally to clear the review list.")
        .font(.caption2)
        .foregroundStyle(.secondary)
      CompactActionRow {
        Button("Dismiss all filtered", systemImage: "xmark.circle", role: .destructive, action: onDismissAllFiltered)
      }
      ForEach(connection.filteredMessages) { message in
        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
              Text(message.subject)
                .font(.caption.weight(.semibold))
              Text("\(message.sender) • \(message.receivedDate)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge("Filtered", color: .teal)
          }
          Text(message.bodyPreview)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text("Reason: \(message.reason)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.teal)
          CompactActionRow {
            Button("Import anyway", systemImage: "tray.and.arrow.down.fill") {
              onImportFiltered(message)
            }
            Button("Move to uncertain", systemImage: "questionmark.folder") {
              onPromoteFiltered(message)
            }
            Button("Task", systemImage: "checklist") {
              onTaskFromFiltered(message)
            }
            Button("Draft", systemImage: "envelope.open.fill") {
              onDraftFromFiltered(message)
            }
            Button("Trust sender", systemImage: "person.badge.shield.checkmark") {
              onAddFilteredHint(message, .trustedSender)
            }
            Button("Import hint", systemImage: "plus.circle") {
              onAddFilteredHint(message, .importKeyword)
            }
            Button("Filter hint", systemImage: "line.3.horizontal.decrease.circle") {
              onAddFilteredHint(message, .filterKeyword)
            }
            Button("Dismiss", systemImage: "xmark.circle", role: .destructive) {
              onDismissFiltered(message)
            }
          }
        }
        .padding(8)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct SpaceMailIntakeHealthCard: View {
  var summary: SpaceMailIntakeHealthSummary

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label("Intake health", systemImage: symbol)
          .font(.caption.weight(.semibold))
          .foregroundStyle(toneColor)
        Spacer()
        Badge(summary.verdict, color: toneColor)
      }
      Text(summary.detail)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Text(summary.nextAction)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(toneColor)
        .fixedSize(horizontal: false, vertical: true)
      CompactMetadataGrid(minimumWidth: 112) {
        Badge("\(summary.fetchedCount) fetched", color: .blue)
        Badge("\(summary.importedCount) imported", color: summary.importedCount > 0 ? .green : .secondary)
        Badge("\(summary.duplicateCount) duplicates", color: summary.duplicateCount > 0 ? .orange : .secondary)
        Badge("\(summary.filteredCount) filtered", color: summary.filteredCount > 0 ? .teal : .secondary)
        Badge("\(summary.uncertainCount) uncertain", color: summary.uncertainCount > 0 ? .orange : .secondary)
        Badge("\(summary.parserIssueCount) parser checks", color: summary.parserIssueCount > 0 ? .orange : .secondary)
        Badge("\(summary.linkedIntakeCount) linked intake", color: summary.linkedIntakeCount > 0 ? .blue : .secondary)
      }
      if summary.pendingUncertainReviewCount > 0 || summary.pendingFilteredReviewCount > 0 {
        Text("Pending local review: \(summary.pendingUncertainReviewCount) uncertain, \(summary.pendingFilteredReviewCount) filtered examples.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.orange)
      }
      if !summary.topReasonLabels.isEmpty {
        VStack(alignment: .leading, spacing: 5) {
          Text("Latest reason labels")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
          ForEach(summary.topReasonLabels, id: \.self) { reason in
            Text(reason)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .padding(8)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
      }
      Text("Last refresh: \(summary.lastRefreshDate)")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(toneColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private var toneColor: Color {
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

  private var symbol: String {
    switch summary.tone {
    case "success":
      return "checkmark.seal.fill"
    case "attention":
      return "exclamationmark.triangle.fill"
    case "warning":
      return "xmark.octagon.fill"
    default:
      return "waveform.path.ecg"
    }
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
          Section("4. Mixed mailbox filter hints") {
            TextField("Trusted sender hints", text: listBinding(\.trustedSenderHints), axis: .vertical)
              .lineLimit(1...3)
            TextField("Import keyword hints", text: listBinding(\.importKeywordHints), axis: .vertical)
              .lineLimit(1...3)
            TextField("Uncertain keyword hints", text: listBinding(\.uncertainKeywordHints), axis: .vertical)
              .lineLimit(1...3)
            TextField("Filter keyword hints", text: listBinding(\.filterKeywordHints), axis: .vertical)
              .lineLimit(1...3)
            Text("Separate hints with commas. Import hints only help messages that already look order-related; uncertain hints keep ambiguous order/delivery questions out of Inbox but available for review; filter hints suppress obvious non-order mail.")
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

  private func listBinding(_ keyPath: WritableKeyPath<SpaceMailIMAPConnection, [String]>) -> Binding<String> {
    Binding(
      get: { draft[keyPath: keyPath].joined(separator: ", ") },
      set: { draft[keyPath: keyPath] = Self.parseHintList($0) }
    )
  }

  private static func parseHintList(_ value: String) -> [String] {
    value
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
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

struct SettingsReleaseCandidateCard: View {
  var store: ParcelOpsStore

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.spaceMailIntakeHealthSummaries.first
  }

  private var inboxCreatedOrdersCount: Int {
    store.orders.filter { order in
      order.source == .forwardedMailbox || order.checkedMailbox == "manual-import"
    }.count
  }

  private var manualRefreshCount: Int {
    store.spaceMailIMAPConnections.filter { $0.lastManualRefreshDate != "Never" }.count
  }

  private var unresolvedOperatorCount: Int {
    store.reviewIntakeEmails.count
      + store.intakeParserDiagnostics.count
      + store.openWorkbenchItems.count
      + store.reviewTasksNeedingAttention.count
      + store.blockedShipmentManifests.count
      + store.blockedDispatchChecklists.count
  }

  private var tone: Color {
    if manualRefreshCount == 0 { return .orange }
    if inboxCreatedOrdersCount == 0 { return .orange }
    if unresolvedOperatorCount > 0 { return .teal }
    return .green
  }

  private var title: String {
    if manualRefreshCount == 0 { return "Release test needs a SpaceMail refresh" }
    if inboxCreatedOrdersCount == 0 { return "Release test needs one Inbox-created order" }
    if unresolvedOperatorCount > 0 { return "Release test has open operator work" }
    return "Release test path is clean"
  }

  private var detail: String {
    if manualRefreshCount == 0 {
      return "Run a manual SpaceMail refresh from Mailbox Monitor before judging the daily operator flow."
    }
    if inboxCreatedOrdersCount == 0 {
      return "Create or link one order from Inbox so Orders, Workbench, Tasks, Dashboard, and Audit can show the handoff."
    }
    if unresolvedOperatorCount > 0 {
      return "Open work is expected during testing. Use Inbox, Workbench, Dispatch, Tasks, and Audit to verify the path is understandable."
    }
    return "Core local workflow has refresh evidence, Inbox-to-order handoff, and audit history. Keep integrations local/manual until the next approved implementation slice."
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: tone == .green ? "checkmark.seal.fill" : "checklist")
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
        Badge(tone == .green ? "Ready" : "Review", color: tone)
      }

      MetricStrip(items: [
        ("Refreshes", "\(manualRefreshCount)", manualRefreshCount == 0 ? .orange : .green),
        ("Fetched", "\(latestSpaceMailSummary?.fetchedCount ?? 0)", .blue),
        ("Imported", "\(latestSpaceMailSummary?.importedCount ?? 0)", (latestSpaceMailSummary?.importedCount ?? 0) > 0 ? .green : .secondary),
        ("Inbox orders", "\(inboxCreatedOrdersCount)", inboxCreatedOrdersCount == 0 ? .orange : .green),
        ("Open work", "\(unresolvedOperatorCount)", unresolvedOperatorCount == 0 ? .green : .teal)
      ])

      Text("Release boundary: manual read-only intake, local JSON records, SpaceMail credential in Keychain, no mailbox mutation, no Shopify/carrier APIs, no background sync, no notifications, no OCR/scanner/calendar/file-picker workflows.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct SettingsView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var settingsSearchText = ""

  private var isCompact: Bool { horizontalSizeClass == .compact }
  private var hasSpaceMailSetup: Bool { !store.spaceMailIMAPConnections.isEmpty }
  private var hasSpaceMailCredentialReference: Bool {
    store.spaceMailIMAPConnections.contains {
      $0.credentialStorageStatus.localizedCaseInsensitiveContains("available")
        || $0.credentialStorageStatus.localizedCaseInsensitiveContains("ready")
    }
  }

  private var mailboxStatus: (String, Color) {
    hasSpaceMailSetup ? ("SpaceMail manual", .green) : ("Not connected", .orange)
  }

  private var credentialStatus: (String, Color) {
    hasSpaceMailCredentialReference ? ("SpaceMail Keychain", .green) : ("SpaceMail Keychain ready", .orange)
  }

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.spaceMailIntakeHealthSummaries.first
  }

  private var activeSetupTitle: String {
    if let latestSpaceMailSummary {
      if latestSpaceMailSummary.importedCount > 0 {
        return "SpaceMail imported order mail"
      }
      if latestSpaceMailSummary.pendingUncertainReviewCount > 0 || latestSpaceMailSummary.uncertainCount > 0 {
        return "SpaceMail has uncertain mail to review"
      }
      if latestSpaceMailSummary.filteredCount > 0 {
        return "SpaceMail filtered mixed mailbox mail"
      }
      return "SpaceMail is ready for manual intake"
    }
    return "Set up SpaceMail to start real intake"
  }

  private var activeSetupDetail: String {
    guard let latestSpaceMailSummary else {
      return "No SpaceMail mailbox is configured yet. Add a setup in Integrations or Mailbox Monitor, then save the password/app-password through the secure Keychain prompt."
    }
    return "\(latestSpaceMailSummary.displayName): \(latestSpaceMailSummary.detail) \(latestSpaceMailSummary.nextAction)"
  }

  private var activeSetupTone: Color {
    guard let latestSpaceMailSummary else { return .orange }
    switch latestSpaceMailSummary.tone {
    case "success": return .green
    case "attention": return .orange
    case "warning": return .red
    default: return .teal
    }
  }

  private var normalizedSettingsSearch: String {
    settingsSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  private func matchesSettingsSection(_ terms: String...) -> Bool {
    let query = normalizedSettingsSearch
    guard !query.isEmpty else { return true }
    return terms.joined(separator: " ").lowercased().contains(query)
  }

  private var showsActiveSetup: Bool {
    matchesSettingsSection("active", "setup", "SpaceMail", "mailbox", "credential", "Keychain", "manual", "refresh")
  }

  private var showsLocalOnlyStatus: Bool {
    matchesSettingsSection("MVP", "local-only", "status", "JSON", "Shopify", "carrier", "credential", "background sync", "notifications")
  }

  private var showsMailboxIntake: Bool {
    matchesSettingsSection("mailbox", "intake", "forwarded", "email", "order creation", "confidence", "review")
  }

  private var showsTrackedMailboxes: Bool {
    matchesSettingsSection("tracked", "mailboxes", "email", "placeholder")
  }

  private var showsShopifyAccounts: Bool {
    matchesSettingsSection("Shopify", "accounts", "store", "placeholder")
  }

  private var showsWatchedFolders: Bool {
    matchesSettingsSection("watched", "folders", "folder", "scan", "cadence", "manual")
  }

  private var showsReviewControls: Bool {
    matchesSettingsSection("review", "risky", "matches", "delivery", "exception", "alerts", "threshold")
  }

  private var showsFuturePlanning: Bool {
    matchesSettingsSection("future", "source", "planning", "Shopify", "password", "vault", "carrier", "tracking", "settings")
  }

  private var visibleSettingsSectionCount: Int {
    [
      showsActiveSetup,
      showsLocalOnlyStatus,
      showsMailboxIntake,
      showsTrackedMailboxes,
      showsShopifyAccounts,
      showsWatchedFolders,
      showsReviewControls,
      showsFuturePlanning
    ].filter(\.self).count
  }

  var body: some View {
    @Bindable var store = store

    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("Settings")
          .font(isCompact ? .title.bold() : .largeTitle.bold())

        SettingsPanel(title: "Find setting", symbol: "magnifyingglass") {
          VStack(alignment: .leading, spacing: 10) {
            FilterControlGrid {
              TextField("Search settings, mailbox, SpaceMail, Shopify, folders, review, carrier", text: $settingsSearchText)
                .textFieldStyle(.roundedBorder)

              Button("Clear", systemImage: "xmark.circle") {
                settingsSearchText = ""
              }
              .buttonStyle(.bordered)
              .disabled(normalizedSettingsSearch.isEmpty)

              Badge("\(visibleSettingsSectionCount) sections", color: visibleSettingsSectionCount == 0 ? .orange : .blue)
            }

            Text("This only narrows visible local settings sections. It does not enable live integrations or background behavior.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        if visibleSettingsSectionCount == 0 {
          MVPEmptyState(title: "No settings sections match", detail: "Clear the settings search or try mailbox, SpaceMail, Shopify, folders, review, carrier, credential, or local-only.", symbol: "magnifyingglass")
        }

        if showsActiveSetup {
          SettingsPanel(title: "Active setup now", symbol: "checkmark.seal.fill") {
          VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
              Image(systemName: hasSpaceMailSetup ? "server.rack" : "server.rack.fill")
                .font(.title3)
                .foregroundStyle(activeSetupTone)
                .frame(width: 28)

              VStack(alignment: .leading, spacing: 4) {
                Text(activeSetupTitle)
                  .font(.headline)
                Text(activeSetupDetail)
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }

            MetricStrip(items: [
              ("SpaceMail", hasSpaceMailSetup ? "Configured" : "Not set", hasSpaceMailSetup ? .green : .orange),
              ("Credential", hasSpaceMailCredentialReference ? "Keychain" : "Needed", hasSpaceMailCredentialReference ? .green : .orange),
              ("Last fetched", "\(latestSpaceMailSummary?.fetchedCount ?? 0)", .blue),
              ("Imported", "\(latestSpaceMailSummary?.importedCount ?? 0)", (latestSpaceMailSummary?.importedCount ?? 0) > 0 ? .green : .secondary),
              ("Filtered", "\(latestSpaceMailSummary?.filteredCount ?? 0)", (latestSpaceMailSummary?.filteredCount ?? 0) > 0 ? .teal : .secondary)
            ])

            Text("Current live path: SpaceMail manual read-only IMAP refresh. Microsoft 365, Shopify, carriers, folders, notifications, scanners, calendars, and background sync remain planning or advanced setup surfaces.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        }

        if showsLocalOnlyStatus {
          MVPWorkflowGuide(
            title: "Before connecting live systems",
            detail: "Most integrations remain local planning surfaces. SpaceMail is the exception: it can run a manual, read-only IMAP refresh when a Keychain password is configured.",
            steps: [
              "Use SpaceMail only through the explicit manual refresh action.",
              "Enter a SpaceMail password only in the secure Keychain prompt, not in setup notes or JSON fields.",
              "Treat Shopify, carrier, notification, scanner, calendar, and background-sync toggles as planning controls.",
              "Use Audit to confirm that local actions are being recorded."
            ],
            symbol: "gearshape.2.fill"
          )

          SettingsPanel(title: "MVP local-only status", symbol: "checklist") {
          Text("ParcelOps stores operational records in local JSON. SpaceMail password/app-password values use Keychain and manual read-only refresh; the rest of the integration surface remains placeholder or planning-only.")
            .foregroundStyle(.secondary)

          LocalDataSafetyCard(store: store, compact: isCompact)

          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            IntegrationStatusRow(title: "Email mailbox", status: mailboxStatus.0, symbol: "envelope.badge.fill", color: mailboxStatus.1)
            IntegrationStatusRow(title: "Shopify", status: "Not connected", symbol: "cart.badge.plus", color: .orange)
            IntegrationStatusRow(title: "Carrier APIs", status: "Not connected", symbol: "location.fill.viewfinder", color: .orange)
            IntegrationStatusRow(title: "Store logins", status: "Placeholder only", symbol: "key.horizontal.fill", color: .orange)
            IntegrationStatusRow(title: "Credential storage", status: credentialStatus.0, symbol: "lock.shield.fill", color: credentialStatus.1)
            IntegrationStatusRow(title: "Background sync", status: "Not enabled", symbol: "bell.slash.fill", color: .red)
          }
        }

          SettingsReleaseCandidateCard(store: store)
        }

        if showsMailboxIntake {
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
        }

        if showsTrackedMailboxes {
          SettingsPanel(title: "Tracked mailboxes", symbol: "envelope.badge.fill") {
          ForEach(store.mailboxes) { mailbox in
            MailboxConnectionRow(mailbox: mailbox)
          }
          Button("Add mailbox placeholder", systemImage: "plus", action: store.addTrackedMailboxPlaceholder)
            .buttonStyle(.bordered)
        }
        }

        if showsShopifyAccounts {
          SettingsPanel(title: "Shopify accounts", symbol: "cart.badge.plus") {
          ForEach(store.shopifyConnections) { connection in
            ShopifyConnectionRow(connection: connection)
          }
          Button("Add Shopify placeholder", systemImage: "plus", action: store.connectShopifyPlaceholder)
            .buttonStyle(.bordered)
        }
        }

        if showsWatchedFolders {
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
        }

        if showsReviewControls {
          SettingsPanel(title: "Review controls", symbol: "checkmark.shield.fill") {
          Toggle("Require review for risky email/order matches", isOn: $store.settings.requireReviewForRiskyMatches)
          Toggle("Plan delivery exception alerts", isOn: $store.settings.notifyOnDeliveryExceptions)
          Stepper("Exception alert threshold: \(store.settings.exceptionThreshold)", value: $store.settings.exceptionThreshold, in: 1...10)
        }
        }

        if showsFuturePlanning {
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
