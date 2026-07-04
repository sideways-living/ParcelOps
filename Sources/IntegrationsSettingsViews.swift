import SwiftUI

struct IntegrationsView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var setupSearchText = ""
  @State private var setupFeedbackMessage: String?

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
  private var hasGmailSetup: Bool { !store.gmailMailboxConnections.isEmpty }
  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.gmailIntakeHealthSummaries.first
  }
  private var hasGmailConnectedAuth: Bool {
    store.gmailMailboxConnections.contains { connection in
      store.gmailAuthSessionState(for: connection).status == .connected
    }
  }
  private var hasGmailCoreSetup: Bool {
    store.gmailMailboxConnections.contains { connection in
      !connection.emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !connection.monitoredLabelNames.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !(connection.oauthClientIDPlaceholder ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !(connection.redirectURIPlaceholder ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && connection.requestedScopesSummary.localizedCaseInsensitiveContains("gmail.")
    }
  }

  private var microsoftSetupCount: Int {
    store.microsoft365MailboxConnections.count
  }

  private var microsoftConnectedCount: Int {
    store.microsoft365MailboxConnections.filter {
      $0.connectionStatus.localizedCaseInsensitiveContains("connected")
        || $0.connectionStatus.localizedCaseInsensitiveContains("real graph")
    }.count
  }

  private var spaceMailLivePathDetail: String {
    if hasGmailSetup && !hasSpaceMailSetup {
      if let latestGmailSummary {
        return "\(latestGmailSummary.displayName): \(latestGmailSummary.fetchedCount) fetched, \(latestGmailSummary.importedCount) imported, \(latestGmailSummary.filteredCount) filtered, \(latestGmailSummary.uncertainCount + latestGmailSummary.pendingUncertainReviewCount) uncertain. \(latestGmailSummary.nextAction)"
      }
      return "Gmail setup exists for Google-hosted mailboxes. Finish setup/sign-in, then use manual read-only Gmail refresh when needed."
    }
    if !hasSpaceMailSetup {
      return "No live mailbox setup exists yet. Add SpaceMail for IMAP mailboxes or Gmail for Google-hosted mailboxes before treating planning-only providers as daily intake paths."
    }
    if !hasSpaceMailCredentialReference {
      return "SpaceMail setup exists, but the Keychain credential is not ready. Add or check the credential before running the real manual refresh."
    }
    if let latestSpaceMailSummary {
      return "\(latestSpaceMailSummary.displayName): \(latestSpaceMailSummary.fetchedCount) fetched, \(latestSpaceMailSummary.importedCount) imported, \(latestSpaceMailSummary.filteredCount) filtered, \(latestSpaceMailSummary.uncertainCount + latestSpaceMailSummary.pendingUncertainReviewCount) uncertain. \(latestSpaceMailSummary.nextAction)"
    }
    return "SpaceMail is configured and ready for an explicit manual refresh. No refresh history is recorded yet."
  }

  private var providerPriorityTone: Color {
    if hasGmailSetup && !hasGmailCoreSetup { return .orange }
    if hasGmailSetup && !hasGmailConnectedAuth { return .orange }
    if !hasSpaceMailSetup && !hasGmailSetup { return .orange }
    if hasSpaceMailSetup && !hasSpaceMailCredentialReference { return .orange }
    if let latestSpaceMailSummary, latestSpaceMailSummary.pendingUncertainReviewCount > 0 || latestSpaceMailSummary.uncertainCount > 0 { return .orange }
    if let latestGmailSummary, latestGmailSummary.pendingUncertainReviewCount > 0 || latestGmailSummary.uncertainCount > 0 { return .orange }
    return .green
  }

  private var recommendedSetupTitle: String {
    if !hasSpaceMailSetup && !hasGmailSetup {
      return "Start with mailbox setup"
    }
    if hasSpaceMailSetup && !hasSpaceMailCredentialReference {
      return "Add the SpaceMail Keychain credential"
    }
    if hasGmailSetup && !hasGmailCoreSetup {
      return "Finish Gmail setup details"
    }
    if hasGmailSetup && !hasGmailConnectedAuth {
      return "Test Google sign-in"
    }
    if let latestSpaceMailSummary, latestSpaceMailSummary.pendingUncertainReviewCount > 0 || latestSpaceMailSummary.uncertainCount > 0 {
      return "Review uncertain mixed-mailbox messages"
    }
    if let latestGmailSummary, latestGmailSummary.pendingUncertainReviewCount > 0 || latestGmailSummary.uncertainCount > 0 {
      return "Review uncertain Gmail messages"
    }
    return "Run manual mailbox refresh when needed"
  }

  private var recommendedSetupDetail: String {
    if !hasSpaceMailSetup && !hasGmailSetup {
      return "Use SpaceMail for IMAP mailboxes or Gmail for Google-hosted mailboxes. Both feed the same local Inbox intake path."
    }
    if hasSpaceMailSetup && !hasSpaceMailCredentialReference {
      return "Use the secure password prompt on the SpaceMail row. Passwords and app passwords must not be typed into setup notes or JSON-backed fields."
    }
    if hasGmailSetup && !hasGmailCoreSetup {
      return "Add Gmail address, labels, OAuth client placeholder, redirect/scheme, and read-only Gmail scope notes. Do not enter client secrets or token values."
    }
    if hasGmailSetup && !hasGmailConnectedAuth {
      return "Use the explicit Google sign-in test before real Gmail refresh. ParcelOps keeps token values out of JSON and Audit."
    }
    if let latestSpaceMailSummary, latestSpaceMailSummary.pendingUncertainReviewCount > 0 || latestSpaceMailSummary.uncertainCount > 0 {
      return "Uncertain mixed-mailbox messages stay out of Inbox until an operator imports or dismisses them locally."
    }
    if let latestGmailSummary, latestGmailSummary.pendingUncertainReviewCount > 0 || latestGmailSummary.uncertainCount > 0 {
      return "Uncertain Gmail previews stay out of Inbox until an operator imports or dismisses them locally."
    }
    return "Use explicit manual read-only refresh for the active mailbox provider. Microsoft 365, Shopify, watched folders, and login placeholders remain secondary planning surfaces."
  }

  private var recommendedSetupTone: Color {
    if !hasSpaceMailSetup && !hasGmailSetup { return .orange }
    if hasSpaceMailSetup && !hasSpaceMailCredentialReference { return .orange }
    if hasGmailSetup && (!hasGmailCoreSetup || !hasGmailConnectedAuth) { return .orange }
    if let latestSpaceMailSummary, latestSpaceMailSummary.pendingUncertainReviewCount > 0 || latestSpaceMailSummary.uncertainCount > 0 { return .orange }
    if let latestGmailSummary, latestGmailSummary.pendingUncertainReviewCount > 0 || latestGmailSummary.uncertainCount > 0 { return .orange }
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
    matchesSetupSection("recommended", "setup", "path", "current", "next", "SpaceMail", "Gmail", "Google", "credential", "uncertain", "manual refresh")
  }

  private var showsEditorSafety: Bool {
    matchesSetupSection("editor", "save", "cancel", "short window", "credential", "password", "secret", "safe setup")
  }

  private var showsLocalDataSafety: Bool {
    matchesSetupSection("local", "data", "JSON", "persistence", "backup", "storage", "credentials", "Keychain", "privacy")
  }

  private var showsSpaceMailSetup: Bool {
    matchesSetupSection("SpaceMail", "IMAP", "Keychain", "credential", "mixed mailbox", "classifier", "uncertain", "filtered", "real refresh", "mock refresh")
  }

  private var showsMicrosoftSetup: Bool {
    matchesSetupSection("Microsoft", "365", "Graph", "OAuth", "MSAL", "mock", "sign in", "mailbox")
  }

  private var showsGmailSetup: Bool {
    matchesSetupSection("Gmail", "Google", "Workspace", "OAuth", "labels", "mock", "mailbox")
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
      showsEditorSafety,
      showsLocalDataSafety,
      showsSpaceMailSetup,
      showsMicrosoftSetup,
      showsGmailSetup,
      showsTrackedMailboxes,
      showsShopifySetup,
      showsFolderSetup,
      showsSourceConnections
    ].filter(\.self).count
  }

  private var providerPriorityPanel: some View {
    SettingsPanel(title: "Mailbox provider status", symbol: "point.3.connected.trianglepath.dotted") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: hasGmailSetup && !hasSpaceMailSetup ? "envelope.badge.shield.half.filled" : "server.rack")
            .font(.title3)
            .foregroundStyle(providerPriorityTone)
            .frame(width: 28)
          VStack(alignment: .leading, spacing: 4) {
            Text("Use SpaceMail or Gmail as the live mailbox path")
              .font(.headline)
            Text(spaceMailLivePathDetail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        MetricStrip(items: [
          ("SpaceMail", hasSpaceMailSetup ? "Configured" : "Not set", hasSpaceMailSetup ? .green : .secondary),
          ("SpaceMail credential", hasSpaceMailCredentialReference ? "Keychain" : hasSpaceMailSetup ? "Needed" : "N/A", hasSpaceMailCredentialReference ? .green : hasSpaceMailSetup ? .orange : .secondary),
          ("Gmail", hasGmailSetup ? "Configured" : "Not set", hasGmailSetup ? .green : .secondary),
          ("Google sign-in", hasGmailConnectedAuth ? "Connected" : hasGmailSetup ? "Needed" : "N/A", hasGmailConnectedAuth ? .green : hasGmailSetup ? .orange : .secondary),
          ("M365 records", "\(microsoftSetupCount)", microsoftSetupCount == 0 ? .secondary : .teal),
          ("M365 ready", "\(microsoftConnectedCount)", microsoftConnectedCount == 0 ? .secondary : .orange)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 180 : 230), spacing: 10)], alignment: .leading, spacing: 10) {
          ProviderPriorityStep(
            title: "IMAP path",
            detail: "SpaceMail supports manual read-only IMAP refresh with a Keychain password and mixed-mailbox filtering.",
            symbol: "server.rack",
            color: hasSpaceMailSetup ? (hasSpaceMailCredentialReference ? .green : .orange) : .secondary
          )
          ProviderPriorityStep(
            title: "Gmail path",
            detail: "Gmail/Google Workspace supports manual read-only refresh after Google sign-in and Gmail setup are ready.",
            symbol: "envelope.badge.shield.half.filled",
            color: hasGmailSetup ? (hasGmailConnectedAuth ? .green : .orange) : .secondary
          )
          ProviderPriorityStep(
            title: "Advanced testing",
            detail: "Microsoft 365 remains available for OAuth/Graph experiments, but it should not block SpaceMail or Gmail intake.",
            symbol: "mail.stack.fill",
            color: microsoftSetupCount == 0 ? .secondary : .teal
          )
          ProviderPriorityStep(
            title: "Planning only",
            detail: "Shopify, folders, carrier, scanner, OCR, notifications, calendars, and background sync are still not live paths.",
            symbol: "lock.shield.fill",
            color: .secondary
          )
        }

        Text("Operational rule: run the relevant mailbox provider manually, review imported/uncertain/filtered outcomes, then move real order work through Inbox, Orders, Workbench, Dispatch, Tasks, and Audit. Treat non-mailbox providers as optional setup unless deliberately reactivated.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(providerPriorityTone)
          .fixedSize(horizontal: false, vertical: true)

        CompactActionRow {
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Open Mailbox Monitor", systemImage: "server.rack")
          }
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Open Inbox", systemImage: "tray.full.fill")
          }
          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Open Audit", systemImage: "list.clipboard.fill")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        VStack(alignment: .leading, spacing: 10) {
          Text("Local source setup")
            .font(isCompact ? .title2.bold() : .title.bold())
          Text("SpaceMail IMAP and Gmail are the current manual read-only mailbox paths. Shopify, folders, logins, and Microsoft 365 remain setup or planning surfaces unless explicitly enabled.")
            .font(.callout)
            .foregroundStyle(.secondary)
          CompactActionRow {
            Button("SpaceMail IMAP setup", systemImage: "server.rack") {
              store.addSpaceMailIMAPConnectionPlaceholder()
              setupFeedbackMessage = "SpaceMail IMAP setup placeholder added locally. Add the Keychain credential before running real manual refresh."
            }
            Button("Microsoft 365 setup", systemImage: "mail.stack.fill") {
              store.addMicrosoft365MailboxConnectionPlaceholder()
              setupFeedbackMessage = "Microsoft 365 setup placeholder added locally. Graph remains optional; no mailbox fetch starts here."
            }
            Button("Gmail setup", systemImage: "envelope.badge.shield.half.filled") {
              store.addGmailMailboxConnectionPlaceholder()
              setupFeedbackMessage = "Gmail setup added locally. Save non-secret app details, test Google sign-in, then run manual read-only refresh."
            }
            Button("Mailbox setup", systemImage: "envelope.badge.fill") {
              store.addTrackedMailboxPlaceholder()
              setupFeedbackMessage = "Mailbox setup placeholder added locally for planning and review."
            }
            Button("Shopify planning", systemImage: "cart.badge.plus") {
              store.connectShopifyPlaceholder()
              setupFeedbackMessage = "Shopify planning placeholder added locally. No Shopify API or store login was contacted."
            }
            Button("Folder setup", systemImage: "folder.badge.plus") {
              store.addWatchedFolderPlaceholder()
              setupFeedbackMessage = "Folder setup placeholder added locally. No file picker, folder scan, or background watcher was started."
            }
            Button("Login planning", systemImage: "key.fill") {
              store.addStoreLoginPlaceholder()
              setupFeedbackMessage = "Login planning placeholder added locally. No credential, password vault, or Keychain item was created."
            }
          }
          if let setupFeedbackMessage {
            SettingsActionFeedbackPanel(message: setupFeedbackMessage)
          }
        }

        SettingsPanel(title: "Find setup section", symbol: "magnifyingglass") {
          VStack(alignment: .leading, spacing: 10) {
            FilterControlGrid {
              TextField("Search setup, SpaceMail, JSON, credentials, Microsoft 365, Shopify", text: $setupSearchText)
                .textFieldStyle(.roundedBorder)

              Button("Clear", systemImage: "xmark.circle") {
                setupSearchText = ""
              }
              .buttonStyle(.bordered)
              .disabled(normalizedSetupSearch.isEmpty)

              Badge("\(visibleSetupSectionCount) sections", color: visibleSetupSectionCount == 0 ? .orange : .blue)
            }

            Text("Use this to narrow the setup page. It only changes which local setup sections are visible.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        if visibleSetupSectionCount == 0 {
          MVPEmptyState(title: "No setup sections match", detail: "Clear the setup search or try SpaceMail, JSON, persistence, Microsoft 365, Shopify, folder, mailbox, credential, or classifier.", symbol: "magnifyingglass")
        }

        if showsRecommendedSetup {
          SettingsPanel(title: "Recommended setup path", symbol: "arrow.forward.circle.fill") {
          VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
              Image(systemName: hasSpaceMailSetup ? "server.rack" : hasGmailSetup ? "envelope.badge.shield.half.filled" : "envelope.badge.fill")
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
              Badge(hasSpaceMailSetup ? "SpaceMail" : hasGmailSetup ? "Gmail" : "Setup needed", color: recommendedSetupTone)
            }

            MetricStrip(items: [
              ("SpaceMail", hasSpaceMailSetup ? "Configured" : "Not set", hasSpaceMailSetup ? .green : hasGmailSetup ? .secondary : .orange),
              ("Credential", hasSpaceMailCredentialReference ? "Keychain" : hasSpaceMailSetup ? "Needed" : "N/A", hasSpaceMailCredentialReference ? .green : hasSpaceMailSetup ? .orange : .secondary),
              ("Gmail", hasGmailSetup ? "Configured" : "Not set", hasGmailSetup ? .green : .secondary),
              ("Google sign-in", hasGmailConnectedAuth ? "Connected" : hasGmailSetup ? "Needed" : "N/A", hasGmailConnectedAuth ? .green : hasGmailSetup ? .orange : .secondary),
              ("Fetched", "\((latestSpaceMailSummary?.fetchedCount ?? 0) + (latestGmailSummary?.fetchedCount ?? 0))", .blue),
              ("Imported", "\((latestSpaceMailSummary?.importedCount ?? 0) + (latestGmailSummary?.importedCount ?? 0))", ((latestSpaceMailSummary?.importedCount ?? 0) + (latestGmailSummary?.importedCount ?? 0)) > 0 ? .green : .secondary),
              ("Uncertain", "\((latestSpaceMailSummary?.pendingUncertainReviewCount ?? latestSpaceMailSummary?.uncertainCount ?? 0) + (latestGmailSummary?.pendingUncertainReviewCount ?? latestGmailSummary?.uncertainCount ?? 0))", (((latestSpaceMailSummary?.pendingUncertainReviewCount ?? latestSpaceMailSummary?.uncertainCount ?? 0) + (latestGmailSummary?.pendingUncertainReviewCount ?? latestGmailSummary?.uncertainCount ?? 0)) > 0) ? .orange : .secondary)
            ])

            SpaceMailPrimaryStatusStrip(store: store, title: "Current SpaceMail intake", showTitle: true)

            SpaceMailMVPReadinessCard(summary: store.spaceMailMVPReadinessSummary, showChecklist: false)

            Text("Advanced providers stay available below, but they should not be treated as the daily mailbox path unless the project explicitly switches away from SpaceMail/Gmail mailbox intake.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)

            SpaceMailRefreshTrendCard(summary: store.spaceMailRefreshTrendSummary)

            Text("Recent manual refresh history is shown here so setup decisions can be based on imported, filtered, duplicate, and uncertain counts instead of Audit detail alone.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)

            CompactActionRow {
              NavigationLink {
                MailboxView(store: store)
              } label: {
                Label("Open Mailbox Monitor", systemImage: "server.rack")
              }
              NavigationLink {
                InboxView(store: store)
              } label: {
                Label("Open Inbox", systemImage: "tray.full.fill")
              }
              NavigationLink {
                AuditView(store: store)
              } label: {
                Label("Open Audit", systemImage: "list.clipboard.fill")
              }
            }
            .buttonStyle(.bordered)

            SettingsReleaseCandidateCard(store: store)
          }
        }
          providerPriorityPanel
        }

        if showsLocalDataSafety {
          SettingsPanel(title: "Local data and privacy", symbol: "internaldrive.fill") {
            Text("Use this section when checking where the MVP stores local records, what is deliberately excluded from JSON, and how to reason about manual test backups.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)

            LocalDataSafetyCard(store: store, compact: isCompact)

            Text("This is a read-only support view. It does not export files, open a file picker, sync to cloud, read Keychain passwords, change JSON contents, or mutate mailbox messages.")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        if showsEditorSafety {
          SettingsPanel(title: "Setup editor safety", symbol: "rectangle.and.pencil.and.ellipsis") {
            VStack(alignment: .leading, spacing: 12) {
              Text("SpaceMail and Microsoft setup editors are for non-secret configuration only. Their forms scroll, and Save/Cancel stay pinned at the bottom of the sheet so they remain reachable on shorter windows.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

              LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], alignment: .leading, spacing: 10) {
                SetupEditorSafetyItem(
                  title: "Non-secret setup",
                  detail: "Use setup editors for mailbox address, host, folder, mode, planning notes, and classifier hints.",
                  symbol: "doc.text.magnifyingglass",
                  color: .blue
                )
                SetupEditorSafetyItem(
                  title: "Credential prompts only",
                  detail: "SpaceMail passwords or app passwords belong in the secure credential action, not setup notes or JSON-backed fields.",
                  symbol: "lock.shield.fill",
                  color: .green
                )
                SetupEditorSafetyItem(
                  title: "Pinned actions",
                  detail: "If the sheet is taller than the screen, scroll the form; Save and Cancel should remain visible at the bottom.",
                  symbol: "arrow.down.to.line.compact",
                  color: .teal
                )
                SetupEditorSafetyItem(
                  title: "No mailbox mutation",
                  detail: "Editing setup does not fetch mail, start background sync, mark read, delete, move, send, or modify mailbox items.",
                  symbol: "envelope.badge.shield.half.filled",
                  color: .orange
                )
              }

              Text("If Save is not visible after opening a setup editor, that is a layout bug. The intended behavior is a scrollable form with a fixed bottom action bar.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
            Button("Add SpaceMail setup", systemImage: "plus") {
              store.addSpaceMailIMAPConnectionPlaceholder()
              setupFeedbackMessage = "SpaceMail IMAP setup placeholder added locally. Configure host, folder, mode, and Keychain credential before real refresh."
            }
              .buttonStyle(.bordered)
            Badge("\(store.spaceMailIMAPConnections.count) setup records", color: .blue)
          }
          if store.spaceMailIMAPConnections.isEmpty {
            MVPEmptyState(title: "No SpaceMail IMAP setup", detail: "Add a SpaceMail setup to capture host, port, folder, mixed-mailbox mode, and Keychain credential status before manual refresh.", symbol: "server.rack")
          }
          ForEach(store.spaceMailIMAPConnections) { connection in
            SpaceMailIMAPConnectionRow(
              connection: connection,
              healthSummary: store.spaceMailIntakeHealthSummary(for: connection),
              assignedFollowUpSummaries: store.spaceMailAssignedFollowUpSummaries(for: connection),
              classifierImpactPreviews: store.spaceMailClassifierImpactPreviews(for: connection)
            ) { updatedConnection in
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
            } onCreateTasksForAllUncertain: {
              store.createReviewTasksForAllUncertainSpaceMailMessages(for: connection)
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
            } onAddDemoUncertain: {
              store.addSpaceMailDemoUncertainMessage(for: connection)
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
            } onCreateShiftHandoff: {
              store.createSpaceMailShiftHandoffNote(for: connection)
            } onCreateShiftTask: {
              store.createSpaceMailShiftReviewTask(for: connection)
            } onCreateParserQATask: {
              store.createSpaceMailParserQAReviewTask(for: connection)
            } onRemove: {
              store.removeSpaceMailIMAPConnection(connection)
            }
          }
        }
        }

        if showsGmailSetup {
          SettingsPanel(title: "Gmail mailbox setup", symbol: "envelope.badge.shield.half.filled") {
          Text("Use this for Gmail or Google Workspace mailboxes that feed the same Inbox intake path. Mock refresh remains available; real Gmail refresh is manual, read-only, and separate from sign-in.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          CompactActionRow {
            Button("Add Gmail setup", systemImage: "plus") {
              store.addGmailMailboxConnectionPlaceholder()
              setupFeedbackMessage = "Gmail setup added locally. Use mock refresh for local testing or real refresh after Google sign-in."
            }
              .buttonStyle(.bordered)
            Badge("\(store.gmailMailboxConnections.count) setup records", color: .teal)
          }
          if store.gmailMailboxConnections.isEmpty {
            MVPEmptyState(title: "No Gmail setup", detail: "Add a Gmail setup record to capture email address, labels, mixed-mailbox mode, OAuth app notes, and real/manual refresh readiness.", symbol: "envelope.badge.shield.half.filled")
          }
          ForEach(store.gmailMailboxConnections) { connection in
            GmailMailboxConnectionRow(
              connection: connection,
              readiness: store.gmailOAuthReadinessSummary(for: connection),
              implementationPlan: store.gmailOAuthImplementationPlan(for: connection),
              setupTestChecklist: store.gmailSetupTestChecklist(for: connection),
              authState: store.gmailAuthSessionState(for: connection)
            ) { updatedConnection in
              store.updateGmailMailboxConnection(updatedConnection)
            } onReviewed: {
              store.markGmailMailboxConnectionReviewed(connection)
            } onMockRefresh: {
              store.importMockGmailMessages(for: connection)
            } onRealReadinessCheck: {
              store.checkRealGmailReadiness(for: connection)
            } onRealRefresh: {
              store.importRealGmailMessages(for: connection)
            } onRealAuthReadinessCheck: {
              store.testRealGmailSignIn(connection)
            } onMockAuthConnect: {
              store.connectGmailAuthMock(connection)
            } onMockAuthFailure: {
              store.simulateGmailAuthFailure(connection)
            } onTokenStoreReady: {
              store.simulateGmailTokenStoreReady(connection)
            } onTokenMissing: {
              store.simulateGmailTokenMissing(connection)
            } onTokenStorageError: {
              store.simulateGmailTokenStorageError(connection)
            } onTokenClear: {
              store.simulateGmailTokenClear(connection)
            } onReviewPlan: {
              store.markGmailOAuthImplementationPlanReviewed(connection)
            } onCreatePlanTask: {
              store.createReviewTaskFromGmailOAuthPlan(connection)
            } onImportUncertain: { message in
              store.importUncertainGmailMessage(message, for: connection)
            } onDismissUncertain: { message in
              store.dismissUncertainGmailMessage(message, for: connection)
            } onImportFiltered: { message in
              store.importFilteredGmailMessage(message, for: connection)
            } onDismissFiltered: { message in
              store.dismissFilteredGmailMessage(message, for: connection)
            } onTestClassifier: {
              store.testGmailAmbiguousClassifier(for: connection)
            } onTestCustomClassifier: { sender, subject, preview in
              store.testGmailCustomClassifier(for: connection, sender: sender, subject: subject, preview: preview)
            } onRunClassifierSuite: {
              store.runGmailClassifierTestSuite(for: connection)
            } onRemove: {
              store.removeGmailMailboxConnection(connection)
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
            Button("Add mailbox setup", systemImage: "plus") {
              store.addMicrosoft365MailboxConnectionPlaceholder()
              setupFeedbackMessage = "Microsoft 365 mailbox setup placeholder added locally. Real Graph refresh remains manual and explicit."
            }
              .buttonStyle(.bordered)
            Badge("\(store.microsoft365MailboxConnections.count) setup records", color: .orange)
          }
          if store.microsoft365MailboxConnections.isEmpty {
            MVPEmptyState(title: "No Microsoft 365 mailbox setup", detail: "Add a setup record to capture the mailbox address, OAuth planning notes, and mock refresh setup before real authentication is used.", symbol: "mail.stack")
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
            MailboxConnectionRow(mailbox: mailbox) {
              store.markTrackedMailboxPlaceholderReviewed(mailbox)
            } onRemove: {
              store.removeTrackedMailboxPlaceholder(mailbox)
            }
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
            } onReviewed: {
              store.markShopifyPlaceholderReviewed(connection)
            } onRemove: {
              store.removeShopifyPlaceholder(connection)
            }
          }
        }
        }
        if showsFolderSetup {
          SettingsPanel(title: "Watched folders", symbol: "folder.fill.badge.gearshape") {
          ForEach(store.watchedFolders) { folder in
            WatchedFolderRow(folder: folder) {
              store.markWatchedFolderPlaceholderReviewed(folder)
            } onRemove: {
              store.removeWatchedFolderPlaceholder(folder)
            }
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
            } onReviewed: {
              store.markStoreLoginPlaceholderReviewed(connection)
            } onRemove: {
              store.removeStoreLoginPlaceholder(connection)
            }
          }
        }
      }
      .padding(isCompact ? 14 : 24)
    }
  }
}

struct SetupEditorSafetyItem: View {
  var title: String
  var detail: String
  var symbol: String
  var color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Label(title, systemImage: symbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
      Text(detail)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct ProviderPriorityStep: View {
  var title: String
  var detail: String
  var symbol: String
  var color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Label(title, systemImage: symbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
      Text(detail)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct Microsoft365SetupFlowGuide: View {
  private let steps: [(String, String, String)] = [
    ("1", "Set up mailbox record", "Record the mailbox address, tenant hint, folders, and local setup notes."),
    ("2", "Prepare OAuth planning fields", "Capture non-secret tenant, client, redirect, scope, and consent planning details."),
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

      Text("Mock Graph refresh remains available for local checks. Real Graph refresh is manual, read-only, and imports only message previews after Microsoft sign-in and Mail.Read consent.")
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
        Text("Use real sign-in only after the checklist is ready. If signing, consent, or Keychain cache setup blocks the flow, use mock auth and Mock Graph refresh to keep intake review moving.")
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
        ActionGroupHeader(title: "Setup and mock refresh", symbol: "mail.and.text.magnifyingglass")
        CompactActionRow {
          Button("Edit setup", systemImage: "pencil") {
            isEditing = true
          }
          .buttonStyle(.bordered)
          Button("Ready for review", systemImage: "checkmark.shield.fill", action: onReadyForReview)
            .buttonStyle(.bordered)
          Button("Run mock Graph refresh", systemImage: "tray.and.arrow.down.fill", action: onSimulatedRefresh)
            .buttonStyle(.borderedProminent)
        }
        ActionGroupHeader(title: "Real mailbox read", symbol: "envelope.open.fill")
        Text("Manual read-only refresh: requests User.Read and Mail.Read, fetches at most 10 message previews from the configured folder, then imports through the existing duplicate-safe intake path.")
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
      return "Microsoft sign-in is connected. Real Graph refresh is ready for a manual read-only check."
    }
    return "Connect Microsoft 365 before running a real Graph refresh, or use Mock Graph refresh for local review."
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
        : "Not connected: use mock auth for local review or complete setup before real sign-in."
    case .connecting:
      "Sign-in started: wait for Microsoft authentication to finish or return to ParcelOps."
    case .connected:
      "Connected: identity sign-in succeeded. Use Run real Graph refresh only when you want a manual read-only mailbox check."
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
      Text("Fallback: mock Microsoft auth checks auth state locally. Mock Graph refresh imports deterministic sample messages without contacting Microsoft Graph.")
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

struct GmailMailboxConnectionRow: View {
  var connection: GmailMailboxConnection
  var readiness: GmailOAuthReadinessSummary
  var implementationPlan: GmailOAuthImplementationPlan
  var setupTestChecklist: GmailSetupTestChecklist
  var authState: GmailAuthSessionState
  var onSave: (GmailMailboxConnection) -> Void
  var onReviewed: () -> Void
  var onMockRefresh: () -> Void
  var onRealReadinessCheck: () -> Void
  var onRealRefresh: () -> Void
  var onRealAuthReadinessCheck: () -> Void
  var onMockAuthConnect: () -> Void
  var onMockAuthFailure: () -> Void
  var onTokenStoreReady: () -> Void
  var onTokenMissing: () -> Void
  var onTokenStorageError: () -> Void
  var onTokenClear: () -> Void
  var onReviewPlan: () -> Void
  var onCreatePlanTask: () -> Void
  var onImportUncertain: (GmailReviewMessage) -> Void
  var onDismissUncertain: (GmailReviewMessage) -> Void
  var onImportFiltered: (GmailReviewMessage) -> Void
  var onDismissFiltered: (GmailReviewMessage) -> Void
  var onTestClassifier: () -> Void
  var onTestCustomClassifier: (String, String, String) -> Void
  var onRunClassifierSuite: () -> Void
  var onRemove: () -> Void

  @State private var draft: GmailMailboxConnection
  @State private var isEditing = false
  @State private var classifierSender = ""
  @State private var classifierSubject = "Delivery question"
  @State private var classifierPreview = "Can you check whether this relates to an order? I do not have the tracking number yet."

  init(
    connection: GmailMailboxConnection,
    readiness: GmailOAuthReadinessSummary,
    implementationPlan: GmailOAuthImplementationPlan,
    setupTestChecklist: GmailSetupTestChecklist,
    authState: GmailAuthSessionState,
    onSave: @escaping (GmailMailboxConnection) -> Void,
    onReviewed: @escaping () -> Void,
    onMockRefresh: @escaping () -> Void,
    onRealReadinessCheck: @escaping () -> Void,
    onRealRefresh: @escaping () -> Void,
    onRealAuthReadinessCheck: @escaping () -> Void,
    onMockAuthConnect: @escaping () -> Void,
    onMockAuthFailure: @escaping () -> Void,
    onTokenStoreReady: @escaping () -> Void,
    onTokenMissing: @escaping () -> Void,
    onTokenStorageError: @escaping () -> Void,
    onTokenClear: @escaping () -> Void,
    onReviewPlan: @escaping () -> Void,
    onCreatePlanTask: @escaping () -> Void,
    onImportUncertain: @escaping (GmailReviewMessage) -> Void,
    onDismissUncertain: @escaping (GmailReviewMessage) -> Void,
    onImportFiltered: @escaping (GmailReviewMessage) -> Void,
    onDismissFiltered: @escaping (GmailReviewMessage) -> Void,
    onTestClassifier: @escaping () -> Void,
    onTestCustomClassifier: @escaping (String, String, String) -> Void,
    onRunClassifierSuite: @escaping () -> Void,
    onRemove: @escaping () -> Void
  ) {
    self.connection = connection
    self.readiness = readiness
    self.implementationPlan = implementationPlan
    self.setupTestChecklist = setupTestChecklist
    self.authState = authState
    self.onSave = onSave
    self.onReviewed = onReviewed
    self.onMockRefresh = onMockRefresh
    self.onRealReadinessCheck = onRealReadinessCheck
    self.onRealRefresh = onRealRefresh
    self.onRealAuthReadinessCheck = onRealAuthReadinessCheck
    self.onMockAuthConnect = onMockAuthConnect
    self.onMockAuthFailure = onMockAuthFailure
    self.onTokenStoreReady = onTokenStoreReady
    self.onTokenMissing = onTokenMissing
    self.onTokenStorageError = onTokenStorageError
    self.onTokenClear = onTokenClear
    self.onReviewPlan = onReviewPlan
    self.onCreatePlanTask = onCreatePlanTask
    self.onImportUncertain = onImportUncertain
    self.onDismissUncertain = onDismissUncertain
    self.onImportFiltered = onImportFiltered
    self.onDismissFiltered = onDismissFiltered
    self.onTestClassifier = onTestClassifier
    self.onTestCustomClassifier = onTestCustomClassifier
    self.onRunClassifierSuite = onRunClassifierSuite
    self.onRemove = onRemove
    _draft = State(initialValue: connection)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "envelope.badge.shield.half.filled")
          .foregroundStyle(.teal)
          .frame(width: 28)
        VStack(alignment: .leading, spacing: 5) {
          Text(connection.displayName)
            .font(.headline)
          Text(connection.emailAddress)
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Text("Labels: \(connection.monitoredLabelNames)")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("Mailbox mode: \(connection.mailboxMode.rawValue)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Badge(connection.reviewState.rawValue, color: connection.reviewState == .accepted ? .green : .orange)
      }

      Text("Status: \(connection.connectionStatus) • Last refresh: \(connection.lastManualRefreshDate)")
        .font(.caption)
        .foregroundStyle(.secondary)
      Text("OAuth readiness: \(connection.oauthReadinessStatus)")
        .font(.caption)
        .foregroundStyle(.secondary)
      Text("Credential storage: \(connection.credentialStorageStatus)")
        .font(.caption)
        .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: gmailOperatorNextSymbol)
            .foregroundStyle(gmailOperatorNextColor)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(gmailOperatorNextTitle)
              .font(.subheadline.weight(.semibold))
            Text(gmailOperatorNextDetail)
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        MetricStrip(items: [
          ("Setup", readiness.isReady ? "Ready" : "Missing", readiness.isReady ? .green : .orange),
          ("Sign-in", authState.status.rawValue, authState.status == .connected ? .green : .orange),
          ("Refresh", gmailRefreshModeLabel, gmailRefreshGuidanceColor),
          ("Inbox", connection.lastRefreshImportedCount > 0 ? "\(connection.lastRefreshImportedCount)" : "0", connection.lastRefreshImportedCount > 0 ? .green : .secondary)
        ])
        CompactActionRow {
          if hasMissingCoreGmailSetup {
            Button("Edit setup", systemImage: "pencil") {
              draft = connection
              isEditing = true
            }
          } else if authState.status != .connected {
            Button("Test real Google sign-in", systemImage: "person.badge.key", action: onRealAuthReadinessCheck)
          } else if connection.lastRefreshUncertainCount ?? 0 > 0 || !(connection.uncertainMessages ?? []).isEmpty {
            Label("Review uncertain section below", systemImage: "arrow.down.circle")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.orange)
          } else {
            Button("Run real Gmail refresh", systemImage: "envelope.badge.shield.half.filled", action: onRealRefresh)
          }
          Button("Run mock refresh", systemImage: "envelope.badge", action: onMockRefresh)
          Button("Run classifier suite", systemImage: "checklist", action: onRunClassifierSuite)
        }
        .buttonStyle(.bordered)
        Text("This card is the operator path. The detailed setup, OAuth, token, and classifier sections below remain available for diagnostics.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(gmailOperatorNextColor)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(10)
      .background(gmailOperatorNextColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

      VStack(alignment: .leading, spacing: 8) {
        Label("Latest Gmail refresh", systemImage: "tray.and.arrow.down")
          .font(.caption.weight(.semibold))
          .foregroundStyle(connection.lastRefreshImportedCount > 0 ? .green : connection.lastRefreshFilteredNonOrderCount > 0 ? .teal : .secondary)
        MetricStrip(items: [
          ("Fetched", "\(connection.lastRefreshFetchedCount)", .blue),
          ("Imported", "\(connection.lastRefreshImportedCount)", connection.lastRefreshImportedCount > 0 ? .green : .secondary),
          ("Duplicates", "\(connection.lastRefreshDuplicateCount)", connection.lastRefreshDuplicateCount > 0 ? .orange : .secondary),
          ("Filtered", "\(connection.lastRefreshFilteredNonOrderCount)", connection.lastRefreshFilteredNonOrderCount > 0 ? .teal : .secondary),
          ("Uncertain", "\(connection.lastRefreshUncertainCount ?? 0)", (connection.lastRefreshUncertainCount ?? 0) > 0 ? .orange : .secondary)
        ])
        Text(connection.lastRefreshSummary)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        if connection.lastRefreshDuplicateCount > 0 {
          Label("Duplicate Gmail messages were not imported again. Existing linked Inbox rows can still be refreshed locally when newly parsed fields change.", systemImage: "arrow.triangle.2.circlepath")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.teal)
            .fixedSize(horizontal: false, vertical: true)
        }
        VStack(alignment: .leading, spacing: 6) {
          Label(gmailRefreshGuidanceTitle, systemImage: gmailRefreshGuidanceSymbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(gmailRefreshGuidanceColor)
          Text(gmailRefreshGuidanceDetail)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          CompactMetadataGrid(minimumWidth: 135) {
            Badge(gmailRefreshModeLabel, color: gmailRefreshGuidanceColor)
            Badge(connection.mailboxMode == .mixedFiltered ? "Mixed filtering" : "Dedicated mailbox", color: .teal)
            Badge("Read-only", color: .blue)
            Badge("Manual", color: .secondary)
          }
        }
        .padding(8)
        .background(gmailRefreshGuidanceColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        if connection.mailboxMode == .mixedFiltered {
          Text("Mixed Gmail mode keeps filtered non-order messages out of Inbox. Use real refresh only after Google sign-in and read-only Gmail consent are ready.")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.teal)
            .fixedSize(horizontal: false, vertical: true)
        } else {
          Text("Dedicated Gmail mode passes fetched messages straight to intake duplicate/import handling.")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        if let examples = connection.lastRefreshFilteredExamples, !examples.isEmpty {
          Text("Filtered examples: \(examples.joined(separator: "; "))")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        if let examples = connection.lastRefreshUncertainExamples, !examples.isEmpty {
          Text("Uncertain examples: \(examples.joined(separator: "; "))")
            .font(.caption2)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(10)
      .background((connection.lastRefreshUncertainCount ?? 0) > 0 ? Color.orange.opacity(0.10) : connection.lastRefreshFilteredNonOrderCount > 0 ? Color.teal.opacity(0.10) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

      if let messages = connection.uncertainMessages, !messages.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Label("Review uncertain Gmail messages", systemImage: "questionmark.folder.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
          Text("These previews looked order-related but were missing a strong order or tracking ID. They stay out of Inbox until imported locally.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          ForEach(messages) { message in
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
                .buttonStyle(.bordered)
                Button("Dismiss", systemImage: "xmark.circle", role: .destructive) {
                  onDismissUncertain(message)
                }
                .buttonStyle(.bordered)
              }
            }
            .padding(8)
            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }
        .padding(10)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }

      if let messages = connection.filteredMessages, !messages.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Label("Review filtered Gmail examples", systemImage: "line.3.horizontal.decrease.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.teal)
          Text("These previews were treated as non-order Gmail. Import one only when the classifier was too strict; otherwise dismiss it locally to keep review focused.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          ForEach(messages) { message in
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
                .lineLimit(3)
              Text("Reason: \(message.reason)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.teal)
              CompactActionRow {
                Button("Import to Inbox", systemImage: "tray.and.arrow.down.fill") {
                  onImportFiltered(message)
                }
                .buttonStyle(.bordered)
                Button("Dismiss", systemImage: "xmark.circle", role: .destructive) {
                  onDismissFiltered(message)
                }
                .buttonStyle(.bordered)
              }
            }
            .padding(8)
            .background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }
        .padding(10)
        .background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }

      VStack(alignment: .leading, spacing: 8) {
        Label("Gmail classifier test", systemImage: "text.magnifyingglass")
          .font(.caption.weight(.semibold))
          .foregroundStyle(gmailClassifierColor)
        Text("Local tests only. Use this to check how mixed Gmail messages would be imported, held as uncertain, or filtered before running a real refresh.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        CompactMetadataGrid(minimumWidth: 170) {
          Badge("Import: signal + ID", color: .green)
          Badge("Uncertain: order-ish, no ID", color: .orange)
          Badge("Filter: marketing/security", color: .teal)
          Badge("No mailbox fetch", color: .secondary)
        }
        Text(connection.classifierTestSummary ?? "No Gmail classifier test has run yet.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(gmailClassifierColor)
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
          Button("Test ambiguous sample", systemImage: "play.circle", action: onTestClassifier)
          Button("Run custom test", systemImage: "text.magnifyingglass") {
            onTestCustomClassifier(classifierSender, classifierSubject, classifierPreview)
          }
          .disabled(classifierSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && classifierPreview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          Button("Run Gmail suite", systemImage: "checklist", action: onRunClassifierSuite)
        }
        if let results = connection.classifierTestResults, !results.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            ForEach(results) { result in
              VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                  Text(result.sampleName)
                    .font(.caption.weight(.semibold))
                  Spacer()
                  Badge(result.decision, color: gmailClassifierDecisionColor(result.decision))
                }
                Text("\(result.reason) • score \(result.score)")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                Text(result.decisionStatus)
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(result.decisionStatus.localizedCaseInsensitiveContains("needs review") ? .orange : .green)
                CompactMetadataGrid(minimumWidth: 120) {
                  Badge(result.detectedOrderNumber, color: result.detectedOrderNumber.isPlaceholderValidationValue ? .secondary : .blue)
                  Badge(result.detectedTrackingNumber, color: result.detectedTrackingNumber.isPlaceholderValidationValue ? .secondary : .purple)
                  if result.expectedDecision != "No expected decision" {
                    Badge("Expected \(result.expectedDecision)", color: gmailClassifierDecisionColor(result.expectedDecision))
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
      .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

      HStack(alignment: .top, spacing: 10) {
        Image(systemName: authState.status.symbol)
          .foregroundStyle(authState.status == .connected ? .green : authState.status == .authFailed ? .red : .orange)
          .frame(width: 20)
        VStack(alignment: .leading, spacing: 3) {
          Text("Gmail auth state: \(authState.status.rawValue)")
            .font(.caption.weight(.semibold))
          Text("Account: \(authState.signedInAccount) • Last attempt: \(authState.lastAuthAttemptDate)")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(authState.detailText)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(10)
      .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))

      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "key.slash")
          .foregroundStyle(authState.tokenStoreStatus.localizedCaseInsensitiveContains("available") ? .green : .orange)
          .frame(width: 20)
        VStack(alignment: .leading, spacing: 3) {
          Text("Gmail token storage: \(authState.tokenStoreStatus)")
            .font(.caption.weight(.semibold))
          Text(authState.tokenStoreDetail)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Text("Planning only. No Google token value or Keychain item is created, read, written, deleted, stored in JSON, or logged.")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(10)
      .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))

      VStack(alignment: .leading, spacing: 8) {
        Label("Google app setup placeholders", systemImage: "gearshape.2.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(readiness.isReady ? .green : .orange)
        Text("Non-secret planning fields only. Do not enter client secrets, auth codes, access tokens, refresh tokens, API keys, passwords, or Keychain values.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        CompactMetadataGrid(minimumWidth: 160) {
          Badge((connection.googleCloudProjectHint ?? "").isEmpty ? "Project missing" : "Project noted", color: (connection.googleCloudProjectHint ?? "").isEmpty ? .orange : .green)
          Badge((connection.oauthClientIDPlaceholder ?? "").isEmpty ? "Client ID missing" : "Client ID noted", color: (connection.oauthClientIDPlaceholder ?? "").isEmpty ? .orange : .green)
          Badge((connection.redirectURIPlaceholder ?? "").isEmpty ? "Redirect missing" : "Redirect noted", color: (connection.redirectURIPlaceholder ?? "").isEmpty ? .orange : .green)
          Badge((connection.consentScreenNotes ?? "").isEmpty ? "Consent notes missing" : "Consent noted", color: (connection.consentScreenNotes ?? "").isEmpty ? .orange : .green)
        }
        if let project = connection.googleCloudProjectHint, !project.isEmpty {
          Text("Project: \(project)")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        if let redirect = connection.redirectURIPlaceholder, !redirect.isEmpty {
          Text("Redirect/scheme: \(redirect)")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(10)
      .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))

      VStack(alignment: .leading, spacing: 8) {
        Label("Gmail OAuth planning", systemImage: "checklist")
          .font(.caption.weight(.semibold))
          .foregroundStyle(readiness.isReady ? .green : .orange)
        Text(readiness.detailText)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        MetricStrip(items: [
          ("Plan", "\(implementationPlan.completedCount)/\(implementationPlan.totalCount)", implementationPlan.completedCount == implementationPlan.totalCount ? .green : .orange),
          ("Readiness", readiness.isReady ? "Ready" : "Missing", readiness.isReady ? .green : .orange),
          ("Mode", connection.mailboxMode == .mixedFiltered ? "Mixed" : "Dedicated", .teal),
          ("Real Gmail", "Manual only", .teal)
        ])
        ForEach(implementationPlan.items) { item in
          HStack(alignment: .top, spacing: 8) {
            Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
              .foregroundStyle(item.isComplete ? .green : .secondary)
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
        Text("This checklist is local planning only. It does not store tokens or change mailbox messages. Real refresh remains manual and read-only.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(10)
      .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))

      Text("Recommended order: save setup, test real Google sign-in, then run real Gmail refresh. Mock Gmail refresh is still available for local intake testing.")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.teal)
        .fixedSize(horizontal: false, vertical: true)

      Text("Real Gmail sign-in is opt-in. Real refresh may use the current GoogleSignIn session in memory; no token values are stored in ParcelOps JSON.")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      Text(GoogleGmailAuthAdapter().setupReadinessDetail(for: connection))
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      VStack(alignment: .leading, spacing: 8) {
        Label("Gmail setup test checklist", systemImage: "checklist.checked")
          .font(.caption.weight(.semibold))
          .foregroundStyle(setupTestChecklist.completedCount == setupTestChecklist.totalCount ? .green : .orange)
        Text("Follow these steps in order when connecting or retesting a Gmail mailbox. This checklist is computed from local setup, sign-in, refresh, and audit state.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        MetricStrip(items: [
          ("Steps", "\(setupTestChecklist.completedCount)/\(setupTestChecklist.totalCount)", setupTestChecklist.completedCount == setupTestChecklist.totalCount ? .green : .orange),
          ("Auth", authState.status.rawValue, authState.status == .connected ? .green : .orange),
          ("Refresh", gmailRefreshModeLabel, gmailRefreshGuidanceColor),
          ("Inbox", connection.lastRefreshImportedCount > 0 ? "Has intake" : "No intake", connection.lastRefreshImportedCount > 0 ? .green : .secondary)
        ])
        ForEach(Array(setupTestChecklist.items.enumerated()), id: \.element.id) { index, item in
          GmailSetupChecklistStepRow(index: index + 1, item: item)
        }
        Text("Real Gmail refresh remains manual and read-only. ParcelOps does not delete, move, mark read, send, or modify Gmail messages.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(10)
      .background(Color.teal.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

      if isEditing {
        VStack(alignment: .leading, spacing: 8) {
          TextField("Display name", text: $draft.displayName)
          TextField("Email address", text: $draft.emailAddress)
          TextField("Label names", text: $draft.monitoredLabelNames)
          Picker("Mailbox mode", selection: $draft.mailboxMode) {
            ForEach(SpaceMailMailboxMode.allCases) { mode in
              Text(mode.rawValue).tag(mode)
            }
          }
          TextField("Connection status", text: $draft.connectionStatus)
          TextField("OAuth readiness", text: $draft.oauthReadinessStatus)
          TextField("Google Cloud project hint", text: optionalTextBinding(\.googleCloudProjectHint))
          TextField("OAuth client ID placeholder", text: optionalTextBinding(\.oauthClientIDPlaceholder))
          TextField("Redirect URI or URL scheme placeholder", text: optionalTextBinding(\.redirectURIPlaceholder))
          TextField("Requested scopes", text: $draft.requestedScopesSummary)
          TextField("Consent screen notes", text: optionalTextBinding(\.consentScreenNotes), axis: .vertical)
            .lineLimit(2...5)
          TextField("Credential storage", text: $draft.credentialStorageStatus)
          TextField("Setup notes", text: $draft.setupNotes, axis: .vertical)
            .lineLimit(2...5)
          CompactActionRow {
            Button("Save Gmail setup", systemImage: "checkmark.circle.fill") {
              onSave(draft)
              isEditing = false
            }
            .buttonStyle(.borderedProminent)
            Button("Cancel", systemImage: "xmark.circle") {
              draft = connection
              isEditing = false
            }
            .buttonStyle(.bordered)
          }
        }
        .textFieldStyle(.roundedBorder)
      }

      VStack(alignment: .leading, spacing: 10) {
        Label("Gmail actions", systemImage: "slider.horizontal.3")
          .font(.caption.weight(.semibold))
        Text("Primary actions are first. Mock and token-state actions are kept separate so they do not look like the normal operator path.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        VStack(alignment: .leading, spacing: 6) {
          Text("Primary")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
          CompactActionRow {
            Button(isEditing ? "Close editor" : "Edit setup", systemImage: "pencil") {
              draft = connection
              isEditing.toggle()
            }
            Button("Mark reviewed", systemImage: "checkmark.circle", action: onReviewed)
            Button("Test real Google sign-in", systemImage: "person.badge.key", action: onRealAuthReadinessCheck)
            Button("Check readiness", systemImage: "network.badge.shield.half.filled", action: onRealReadinessCheck)
            Button("Run real Gmail refresh", systemImage: "envelope.badge.shield.half.filled", action: onRealRefresh)
          }
        }
        VStack(alignment: .leading, spacing: 6) {
          Text("Local testing and planning")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
          CompactActionRow {
            Button("Run mock refresh", systemImage: "envelope.badge", action: onMockRefresh)
            Button("Mock Gmail auth", systemImage: "person.crop.circle.badge.checkmark", action: onMockAuthConnect)
            Button("Mock auth failure", systemImage: "xmark.octagon", action: onMockAuthFailure)
            Button("Review Gmail plan", systemImage: "list.clipboard.fill", action: onReviewPlan)
            Button("Create plan task", systemImage: "checklist", action: onCreatePlanTask)
          }
        }
        VStack(alignment: .leading, spacing: 6) {
          Text("Token simulation and maintenance")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
          CompactActionRow {
            Button("Token ready", systemImage: "key.fill", action: onTokenStoreReady)
            Button("Token missing", systemImage: "key.slash", action: onTokenMissing)
            Button("Token error", systemImage: "exclamationmark.triangle", action: onTokenStorageError)
            Button("Clear token ref", systemImage: "trash.circle", action: onTokenClear)
            Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
          }
        }
      }
      .buttonStyle(.bordered)
      .padding(10)
      .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
    }
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
  }

  private var hasMissingCoreGmailSetup: Bool {
    connection.emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || connection.monitoredLabelNames.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || (connection.oauthClientIDPlaceholder ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || (connection.redirectURIPlaceholder ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !connection.requestedScopesSummary.localizedCaseInsensitiveContains("gmail.")
  }

  private var gmailOperatorNextTitle: String {
    if hasMissingCoreGmailSetup { return "Finish Gmail setup details" }
    if authState.status != .connected { return "Test Google sign-in before real refresh" }
    if connection.connectionStatus.localizedCaseInsensitiveContains("Auth required") { return "Gmail auth needs a fresh sign-in" }
    if connection.connectionStatus.localizedCaseInsensitiveContains("Consent required") { return "Gmail consent needs review" }
    if connection.connectionStatus.localizedCaseInsensitiveContains("Label not found") { return "Fix the Gmail label before refreshing" }
    if (connection.uncertainMessages ?? []).isEmpty == false { return "Review uncertain Gmail messages" }
    if connection.lastRefreshImportedCount > 0 { return "Review imported Gmail intake in Inbox" }
    if connection.lastRefreshFilteredNonOrderCount > 0 { return "Gmail filter is holding non-order mail out of Inbox" }
    if connection.lastManualRefreshDate == "Never" { return "Run the first manual Gmail refresh" }
    return "Gmail is ready for the next manual check"
  }

  private var gmailOperatorNextDetail: String {
    if hasMissingCoreGmailSetup {
      return "Add the mailbox address, label, OAuth client placeholder, redirect/scheme, and a read-only Gmail scope note. Do not enter client secrets or token values."
    }
    if authState.status != .connected {
      return "Use the explicit sign-in test. ParcelOps should only keep non-secret session status in JSON; token values remain outside app persistence."
    }
    if connection.connectionStatus.localizedCaseInsensitiveContains("Auth required") {
      return "The latest real refresh could not use the current Google session. Sign in again, then retry the manual read-only refresh."
    }
    if connection.connectionStatus.localizedCaseInsensitiveContains("Consent required") {
      return "Confirm Gmail API is enabled and that the signed-in account has consent for the read-only Gmail scope before retrying."
    }
    if connection.connectionStatus.localizedCaseInsensitiveContains("Label not found") {
      return "Use INBOX or an existing Gmail label. The refresh will stay read-only and will not mark, move, or delete mail."
    }
    if (connection.uncertainMessages ?? []).isEmpty == false {
      return "Uncertain previews are deliberately held out of Inbox. Import only genuine order mail or dismiss non-order messages locally."
    }
    if connection.lastRefreshImportedCount > 0 {
      return "\(connection.lastRefreshImportedCount) likely order message\(connection.lastRefreshImportedCount == 1 ? "" : "s") reached Inbox. Review, create, or link orders from Inbox."
    }
    if connection.lastRefreshFilteredNonOrderCount > 0 {
      return "\(connection.lastRefreshFilteredNonOrderCount) mixed-mailbox message\(connection.lastRefreshFilteredNonOrderCount == 1 ? "" : "s") were filtered and not imported. Check examples only if an order email was missed."
    }
    if connection.lastManualRefreshDate == "Never" {
      return "Run real Gmail refresh when sign-in is ready, or use mock refresh to test the local intake path without Google access."
    }
    return "Run manual refresh when you want to check Gmail again. Background sync and mailbox mutation are still not enabled."
  }

  private var gmailOperatorNextSymbol: String {
    if hasMissingCoreGmailSetup { return "gearshape.2.fill" }
    if authState.status != .connected ||
      connection.connectionStatus.localizedCaseInsensitiveContains("Auth required") ||
      connection.connectionStatus.localizedCaseInsensitiveContains("Consent required") {
      return "person.badge.key"
    }
    if connection.connectionStatus.localizedCaseInsensitiveContains("Label not found") { return "tag.slash" }
    if (connection.uncertainMessages ?? []).isEmpty == false { return "questionmark.folder.fill" }
    if connection.lastRefreshImportedCount > 0 { return "tray.and.arrow.down.fill" }
    if connection.lastRefreshFilteredNonOrderCount > 0 { return "line.3.horizontal.decrease.circle" }
    return "envelope.badge.shield.half.filled"
  }

  private var gmailOperatorNextColor: Color {
    if hasMissingCoreGmailSetup ||
      authState.status != .connected ||
      connection.connectionStatus.localizedCaseInsensitiveContains("Auth required") ||
      connection.connectionStatus.localizedCaseInsensitiveContains("Consent required") ||
      connection.connectionStatus.localizedCaseInsensitiveContains("Label not found") ||
      (connection.uncertainMessages ?? []).isEmpty == false {
      return .orange
    }
    if connection.lastRefreshImportedCount > 0 { return .green }
    if connection.lastRefreshFilteredNonOrderCount > 0 { return .teal }
    return .secondary
  }

  private var gmailClassifierColor: Color {
    guard let summary = connection.classifierTestSummary else { return .secondary }
    if summary.localizedCaseInsensitiveContains("needs review") { return .orange }
    if summary.localizedCaseInsensitiveContains("Uncertain") { return .orange }
    if summary.localizedCaseInsensitiveContains("Imported") { return .green }
    if summary.localizedCaseInsensitiveContains("Filtered") { return .teal }
    if summary.localizedCaseInsensitiveContains("passed") { return .green }
    return .secondary
  }

  private var gmailRefreshGuidanceTitle: String {
    if connection.connectionStatus.localizedCaseInsensitiveContains("Auth required") {
      return "Sign in again before refresh"
    }
    if connection.connectionStatus.localizedCaseInsensitiveContains("Consent required") {
      return "Gmail consent needs attention"
    }
    if connection.connectionStatus.localizedCaseInsensitiveContains("Label not found") {
      return "Check Gmail label setup"
    }
    if connection.connectionStatus.localizedCaseInsensitiveContains("Gmail API rejected") ||
        connection.connectionStatus.localizedCaseInsensitiveContains("Network failed") {
      return "Gmail API returned a diagnostic"
    }
    if connection.lastRefreshImportedCount > 0 {
      return "Refresh imported Inbox items"
    }
    if connection.lastRefreshFilteredNonOrderCount > 0 || (connection.lastRefreshUncertainCount ?? 0) > 0 {
      return "Refresh completed with filtering"
    }
    if connection.connectionStatus.localizedCaseInsensitiveContains("No messages") {
      return "No Gmail messages matched"
    }
    if connection.connectionStatus.localizedCaseInsensitiveContains("Ready") {
      return "Ready for manual real refresh"
    }
    return "Gmail refresh status"
  }

  private var gmailRefreshGuidanceDetail: String {
    if connection.connectionStatus.localizedCaseInsensitiveContains("Auth required") {
      return "Use Test real Google sign-in, confirm the same mailbox account, then retry Run real Gmail refresh. ParcelOps does not store token values in JSON."
    }
    if connection.connectionStatus.localizedCaseInsensitiveContains("Consent required") {
      return "The signed-in Google session is missing read-only Gmail consent or the Google Cloud consent screen/API access needs review. Re-run sign-in and confirm gmail.readonly or gmail.metadata is granted."
    }
    if connection.connectionStatus.localizedCaseInsensitiveContains("Label not found") {
      return "Check the label field. Use INBOX for the primary inbox, or an existing custom Gmail label name. Refresh stays read-only."
    }
    if connection.connectionStatus.localizedCaseInsensitiveContains("Gmail API rejected") ||
        connection.connectionStatus.localizedCaseInsensitiveContains("Network failed") {
      return "Open Audit for the safe Gmail HTTP status, error code/message, response size, and non-secret response preview. No tokens, auth headers, full URLs, or raw bodies are logged."
    }
    if connection.lastRefreshImportedCount > 0 {
      return "\(connection.lastRefreshImportedCount) message\(connection.lastRefreshImportedCount == 1 ? "" : "s") entered Inbox intake. Review Inbox triage before creating or linking orders."
    }
    if connection.lastRefreshFilteredNonOrderCount > 0 || (connection.lastRefreshUncertainCount ?? 0) > 0 {
      let uncertainCount = connection.lastRefreshUncertainCount ?? 0
      return "\(connection.lastRefreshFilteredNonOrderCount) non-order message\(connection.lastRefreshFilteredNonOrderCount == 1 ? "" : "s") stayed out of Inbox; \(uncertainCount) uncertain preview\(uncertainCount == 1 ? "" : "s") can be reviewed locally."
    }
    if connection.connectionStatus.localizedCaseInsensitiveContains("No messages") {
      return "The read-only Gmail request succeeded but returned no messages for the configured label/filter. Check the label or try again after new mail arrives."
    }
    if connection.connectionStatus.localizedCaseInsensitiveContains("Ready") {
      return "Setup fields are present. Run Test real Google sign-in first, then Run real Gmail refresh when you are ready to fetch up to 10 read-only message previews."
    }
    return "Use mock refresh for local testing, or complete Google setup and sign-in before real refresh. Gmail refresh remains manual and read-only."
  }

  private var gmailRefreshGuidanceSymbol: String {
    if connection.connectionStatus.localizedCaseInsensitiveContains("Auth required") ||
        connection.connectionStatus.localizedCaseInsensitiveContains("Consent required") {
      return "person.badge.key"
    }
    if connection.connectionStatus.localizedCaseInsensitiveContains("Label not found") {
      return "tag.slash"
    }
    if connection.connectionStatus.localizedCaseInsensitiveContains("Gmail API rejected") ||
        connection.connectionStatus.localizedCaseInsensitiveContains("Network failed") {
      return "exclamationmark.triangle"
    }
    if connection.lastRefreshImportedCount > 0 { return "tray.and.arrow.down.fill" }
    if connection.lastRefreshFilteredNonOrderCount > 0 || (connection.lastRefreshUncertainCount ?? 0) > 0 {
      return "line.3.horizontal.decrease.circle"
    }
    return "info.circle"
  }

  private var gmailRefreshGuidanceColor: Color {
    if connection.connectionStatus.localizedCaseInsensitiveContains("Auth required") ||
        connection.connectionStatus.localizedCaseInsensitiveContains("Consent required") ||
        connection.connectionStatus.localizedCaseInsensitiveContains("Label not found") ||
        connection.connectionStatus.localizedCaseInsensitiveContains("Gmail API rejected") ||
        connection.connectionStatus.localizedCaseInsensitiveContains("Network failed") {
      return .orange
    }
    if connection.lastRefreshImportedCount > 0 { return .green }
    if connection.lastRefreshFilteredNonOrderCount > 0 { return .teal }
    if (connection.lastRefreshUncertainCount ?? 0) > 0 { return .orange }
    return .secondary
  }

  private var gmailRefreshModeLabel: String {
    if connection.connectionStatus.localizedCaseInsensitiveContains("Real Gmail") { return "Real Gmail" }
    if connection.connectionStatus.localizedCaseInsensitiveContains("Mock Gmail") { return "Mock Gmail" }
    if connection.connectionStatus.localizedCaseInsensitiveContains("readiness") { return "Readiness" }
    return "No refresh"
  }

  private func gmailClassifierDecisionColor(_ decision: String) -> Color {
    if decision.localizedCaseInsensitiveContains("Imported") { return .green }
    if decision.localizedCaseInsensitiveContains("Uncertain") { return .orange }
    if decision.localizedCaseInsensitiveContains("Filtered") { return .teal }
    return .secondary
  }

  private func optionalTextBinding(_ keyPath: WritableKeyPath<GmailMailboxConnection, String?>) -> Binding<String> {
    Binding(
      get: { draft[keyPath: keyPath] ?? "" },
      set: { draft[keyPath: keyPath] = $0 }
    )
  }
}

private struct GmailSetupChecklistStepRow: View {
  var index: Int
  var item: GmailSetupTestChecklistItem

  private var accentColor: Color {
    item.isComplete ? .green : .orange
  }

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      ZStack {
        Circle()
          .fill(accentColor.opacity(item.isComplete ? 0.20 : 0.16))
          .frame(width: 24, height: 24)
        Text("\(index)")
          .font(.caption2.weight(.bold))
          .foregroundStyle(accentColor)
      }
      VStack(alignment: .leading, spacing: 3) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Image(systemName: item.symbolName)
            .foregroundStyle(accentColor)
            .frame(width: 16)
          Text(item.title)
            .font(.caption.weight(.semibold))
          Spacer()
          Badge(item.isComplete ? "Done" : "Next", color: accentColor)
        }
        Text(item.detail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        Text(item.nextAction)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(item.isComplete ? Color.secondary : Color.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(8)
    .background(accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct SpaceMailIMAPConnectionRow: View {
  var connection: SpaceMailIMAPConnection
  var healthSummary: SpaceMailIntakeHealthSummary
  var assignedFollowUpSummaries: [String]
  var classifierImpactPreviews: [SpaceMailClassifierImpactPreview]
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
  var onCreateTasksForAllUncertain: () -> Void
  var onTaskFromUncertain: (SpaceMailUncertainMessage) -> Void
  var onDraftFromUncertain: (SpaceMailUncertainMessage) -> Void
  var onTaskFromFiltered: (SpaceMailFilteredMessage) -> Void
  var onDraftFromFiltered: (SpaceMailFilteredMessage) -> Void
  var onAddUncertainHint: (SpaceMailUncertainMessage, SpaceMailHintTarget) -> Void
  var onAddFilteredHint: (SpaceMailFilteredMessage, SpaceMailHintTarget) -> Void
  var onTestClassifier: () -> Void
  var onAddDemoUncertain: () -> Void
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
  var onCreateShiftHandoff: () -> Void
  var onCreateShiftTask: () -> Void
  var onCreateParserQATask: () -> Void
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
      spaceMailCurrentHandoffTrail
      spaceMailShiftHandoffActions
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
        spaceMailTestMessageTemplates
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

  private var spaceMailTestMessageTemplates: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        Label("Classifier test message templates", systemImage: "doc.text.magnifyingglass")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.indigo)
        Spacer()
        Badge("Local guide", color: .indigo)
      }
      Text("Use these as known-good manual samples when testing a mixed-use mailbox. They are examples only; this panel does not fetch mail, send mail, store secrets, or change mailbox messages.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], alignment: .leading, spacing: 8) {
        spaceMailTestTemplateCard(
          title: "Should import",
          badge: "Imported",
          color: .green,
          subject: "Order TEST-123 shipped tracking ABC123",
          body: "Order TEST-123 shipped tracking ABC123 to Melbourne.",
          note: "Strong order/shipping signal plus order and tracking IDs."
        )
        spaceMailTestTemplateCard(
          title: "Should be uncertain",
          badge: "Uncertain",
          color: .orange,
          subject: "Delivery question",
          body: "Can you check whether this relates to an order? I do not have the tracking number yet.",
          note: "Order-adjacent language without a reliable order or tracking ID."
        )
        spaceMailTestTemplateCard(
          title: "Should filter",
          badge: "Filtered",
          color: .teal,
          subject: "Final days for free delivery",
          body: "Final days to get free delivery on your next purchase. View this email or unsubscribe.",
          note: "Marketing/newsletter wording even though it contains weak delivery language."
        )
      }
      Text("After sending a real sample to the mailbox, run manual refresh. Imported examples appear in Inbox, uncertain examples stay in this row for review, and filtered examples stay out of Inbox.")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private func spaceMailTestTemplateCard(title: String, badge: String, color: Color, subject: String, body: String, note: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline) {
        Text(title)
          .font(.caption.weight(.semibold))
        Spacer()
        Badge(badge, color: color)
      }
      VStack(alignment: .leading, spacing: 3) {
        Text("Subject")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(subject)
          .font(.caption2.monospaced())
          .textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)
      }
      VStack(alignment: .leading, spacing: 3) {
        Text("Body")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(body)
          .font(.caption2.monospaced())
          .textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)
      }
      Text(note)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
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

  private var spaceMailCurrentHandoffTrail: some View {
    let recentHistory = Array(connection.refreshHistory.prefix(3))
    return VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label("Current handoff trail", systemImage: "point.3.connected.trianglepath.dotted")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.teal)
        Spacer()
        Badge("\(assignedFollowUpSummaries.count) assigned", color: assignedFollowUpSummaries.isEmpty ? .secondary : .purple)
      }

      Text("This is the quick shift view: latest refresh outcomes plus open SpaceMail follow-up created from this mailbox. Use Audit only when you need the full event detail.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if recentHistory.isEmpty && assignedFollowUpSummaries.isEmpty {
        Text("No refresh or SpaceMail follow-up has been recorded for this setup yet.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
      } else {
        if !recentHistory.isEmpty {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(recentHistory) { entry in
              VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                  Text(entry.eventType)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                  Spacer()
                  Badge(entry.status, color: historyColor(for: entry.status))
                }
                Text("\(entry.importedCount) imported, \(entry.filteredNonOrderCount) filtered, \(entry.uncertainCount) uncertain")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                Text(entry.summary)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .lineLimit(2)
                  .fixedSize(horizontal: false, vertical: true)
              }
              .padding(8)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }

        if !assignedFollowUpSummaries.isEmpty {
          VStack(alignment: .leading, spacing: 5) {
            Text("Assigned follow-up")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.purple)
            ForEach(Array(assignedFollowUpSummaries.prefix(4)), id: \.self) { summary in
              Label(summary, systemImage: "checklist")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .padding(8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }

      Text("This panel reads local JSON state only. It does not fetch mail, read credentials, import messages, change classifier hints, or modify mailbox items.")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
  }

  private var spaceMailShiftHandoffActions: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label("6. Shift handoff", systemImage: "person.2.wave.2.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.purple)
        Spacer()
        Badge("Local only", color: .purple)
      }
      Text("Capture the current SpaceMail state as a handoff note or review task so the next operator can continue without opening Audit first.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      CompactActionRow {
        Button("Create handoff note", systemImage: "arrow.left.arrow.right.square.fill", action: onCreateShiftHandoff)
        Button("Create review task", systemImage: "checklist", action: onCreateShiftTask)
      }
      Text("Uses current local refresh counts, parser diagnostics, mixed-mailbox review queues, and Inbox/order handoff state. It does not fetch mail, read passwords, change classifier rules, or modify mailbox messages.")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.purple.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
  }

  private var spaceMailReviewQueueSummary: some View {
    let uncertainCount = connection.uncertainMessages.count
    let filteredCount = connection.filteredMessages.count

    return VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label("7. Review queued examples", systemImage: "tray.full.fill")
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
            Button("Task all uncertain", systemImage: "checklist") {
              onCreateTasksForAllUncertain()
            }
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

  private func classifierStatusColor(_ status: String) -> Color {
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
      if !classifierImpactPreviews.isEmpty {
        spaceMailClassifierImpactPreview
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

  private var spaceMailClassifierImpactPreview: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        Label("Preset impact preview", systemImage: "chart.bar.doc.horizontal")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.teal)
        Spacer()
        Badge("Local samples only", color: .teal)
      }
      Text("Preview uses built-in samples plus stored uncertain and filtered previews. It does not fetch mail, import messages, change classifier hints, or modify mailbox items.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 8)], alignment: .leading, spacing: 8) {
        ForEach(classifierImpactPreviews) { preview in
          VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
              Text(presetButtonTitle(preview.preset))
                .font(.caption.weight(.semibold))
              Spacer()
              Badge(preview.riskLabel, color: impactColor(preview.riskLabel))
            }
            CompactMetadataGrid(minimumWidth: 74) {
              Badge("\(preview.sampleCount) samples", color: .secondary)
              Badge("\(preview.importedCount) import", color: preview.importedCount > 0 ? .green : .secondary)
              Badge("\(preview.uncertainCount) uncertain", color: preview.uncertainCount > 0 ? .orange : .secondary)
              Badge("\(preview.filteredCount) filtered", color: preview.filteredCount > 0 ? .teal : .secondary)
              Badge("\(preview.changedCount) changed", color: preview.changedCount > 0 ? .purple : .secondary)
            }
            Text(preview.detail)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            ForEach(preview.examples, id: \.self) { example in
              Label(example, systemImage: "arrow.triangle.branch")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .padding(8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(impactColor(preview.riskLabel).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }
    }
    .padding(8)
    .background(Color.teal.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
  }

  private func impactColor(_ label: String) -> Color {
    if label.localizedCaseInsensitiveContains("import") { return .orange }
    if label.localizedCaseInsensitiveContains("review") { return .purple }
    if label.localizedCaseInsensitiveContains("stable") { return .green }
    if label.localizedCaseInsensitiveContains("filter") { return .teal }
    return .secondary
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
        Label("6. Test classifier and parser", systemImage: "text.magnifyingglass")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.orange)
        Spacer()
        classifierTestBadge
      }
      Text("Built-in sample: Delivery question / Can you check whether this relates to an order? I do not have the tracking number yet.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Text("Results show two separate checks: whether the mixed-mailbox classifier would import/filter/hold the message, and whether the intake parser would extract order and tracking values correctly.")
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
        Button("Test ambiguous sample", systemImage: "play.circle", action: onTestClassifier)
        Button("Add demo uncertain", systemImage: "questionmark.diamond") {
          onAddDemoUncertain()
        }
        Button("Run custom test", systemImage: "text.magnifyingglass") {
          onTestCustomClassifier(classifierSender, classifierSubject, classifierPreview)
        }
        .disabled(classifierSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && classifierPreview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        Button("Run parser/classifier suite", systemImage: "checklist") {
          onRunClassifierSuite()
        }
      }
      parserQASummary
      if !connection.classifierTestResults.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Text("Sample results")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
          classifierSuiteSummary
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
              Text(result.decisionStatus)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(classifierStatusColor(result.decisionStatus))
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
                if result.expectedDecision != "No expected decision" {
                  Badge("Expected \(result.expectedDecision)", color: classifierReasonColor(result.expectedDecision))
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

  private var classifierSuiteSummary: some View {
    let decisionChecks = connection.classifierTestResults.filter { !$0.decisionStatus.localizedCaseInsensitiveContains("No classifier expectation") }
    let decisionPasses = decisionChecks.filter { $0.decisionStatus.localizedCaseInsensitiveContains("passed") }
    let decisionFailures = decisionChecks.filter { $0.decisionStatus.localizedCaseInsensitiveContains("needs review") }
    let parserChecks = connection.classifierTestResults.filter { !$0.parserStatus.localizedCaseInsensitiveContains("No parser expectation") }
    let parserPasses = parserChecks.filter { $0.parserStatus.localizedCaseInsensitiveContains("passed") }
    let parserFailures = parserChecks.filter { $0.parserStatus.localizedCaseInsensitiveContains("needs review") }
    let hasFailures = !decisionFailures.isEmpty || !parserFailures.isEmpty

    return VStack(alignment: .leading, spacing: 6) {
      CompactMetadataGrid(minimumWidth: 130) {
        Badge("\(decisionPasses.count)/\(decisionChecks.count) decisions", color: decisionFailures.isEmpty ? .green : .orange)
        Badge("\(parserPasses.count)/\(parserChecks.count) parser", color: parserFailures.isEmpty ? .green : .orange)
        Badge(hasFailures ? "Needs review" : "Suite passed", color: hasFailures ? .orange : .green)
      }
      Text(hasFailures ? classifierSuiteFailureSummary(decisionFailures: decisionFailures, parserFailures: parserFailures) : "Built-in classifier expectations passed. Clear order/tracking samples import, ambiguous delivery questions stay uncertain, and obvious non-order mail filters out.")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(hasFailures ? .orange : .green)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(8)
    .background((hasFailures ? Color.orange : Color.green).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private var parserQASummary: some View {
    let parserChecks = connection.classifierTestResults.filter { !$0.parserStatus.localizedCaseInsensitiveContains("No parser expectation") }
    let parserPasses = parserChecks.filter { $0.parserStatus.localizedCaseInsensitiveContains("passed") }
    let parserFailures = parserChecks.filter { $0.parserStatus.localizedCaseInsensitiveContains("needs review") }
    let clearOrderSamples = connection.classifierTestResults.filter {
      !$0.detectedOrderNumber.isPlaceholderValidationValue || !$0.detectedTrackingNumber.isPlaceholderValidationValue
    }

    return VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label("Parser QA", systemImage: "number.square.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(parserFailures.isEmpty && !parserChecks.isEmpty ? .green : .orange)
        Spacer()
        if parserChecks.isEmpty {
          Badge("Not run", color: .secondary)
        } else {
          Badge("\(parserPasses.count)/\(parserChecks.count) passed", color: parserFailures.isEmpty ? .green : .orange)
        }
      }

      if parserChecks.isEmpty {
        Text("Run the parser/classifier suite before trusting live order extraction. It includes samples for clear order shipped tracking text, refund/order text, tracking-only updates, ambiguous delivery questions, and non-order marketing/security mail.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        Button("Create parser QA task", systemImage: "checklist", action: onCreateParserQATask)
          .buttonStyle(.bordered)
      } else {
        CompactMetadataGrid(minimumWidth: 140) {
          Badge("\(parserPasses.count) parser passes", color: parserFailures.isEmpty ? .green : .orange)
          Badge("\(parserFailures.count) parser checks", color: parserFailures.isEmpty ? .green : .orange)
          Badge("\(clearOrderSamples.count) extracted IDs", color: clearOrderSamples.isEmpty ? .secondary : .blue)
        }
        Text(parserFailures.isEmpty ? "Parser expectations passed for the built-in samples with explicit order/tracking values." : "Review parser failures before relying on live SpaceMail extraction.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(parserFailures.isEmpty ? .green : .orange)
          .fixedSize(horizontal: false, vertical: true)
        ForEach(parserFailures.prefix(3)) { result in
          Text("\(result.sampleName): \(result.parserStatus)")
            .font(.caption2)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
        }
        if !parserFailures.isEmpty {
          Button("Create parser QA task", systemImage: "checklist", action: onCreateParserQATask)
            .buttonStyle(.bordered)
        }
      }
    }
    .padding(8)
    .background((parserFailures.isEmpty && !parserChecks.isEmpty ? Color.green : Color.orange).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private func classifierSuiteFailureSummary(decisionFailures: [SpaceMailClassifierTestResult], parserFailures: [SpaceMailClassifierTestResult]) -> String {
    let decisionText = decisionFailures.prefix(3).map { "\($0.sampleName): \($0.decisionStatus)" }
    let parserText = parserFailures.prefix(3).map { "\($0.sampleName): \($0.parserStatus)" }
    let combined = (decisionText + parserText).joined(separator: "; ")
    return combined.isEmpty ? "Review classifier and parser expectations before trusting mixed-mailbox filtering." : combined
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
    let decisionFailures = connection.classifierTestResults.filter { $0.decisionStatus.localizedCaseInsensitiveContains("needs review") }
    let parserFailures = connection.classifierTestResults.filter { $0.parserStatus.localizedCaseInsensitiveContains("needs review") }
    if !decisionFailures.isEmpty || !parserFailures.isEmpty {
      Badge("Needs review", color: .orange)
    } else if !connection.classifierTestResults.isEmpty {
      Badge("Suite passed", color: .green)
    } else if connection.classifierTestSummary.localizedCaseInsensitiveContains("Uncertain") {
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
    if connection.classifierTestResults.contains(where: { $0.decisionStatus.localizedCaseInsensitiveContains("needs review") || $0.parserStatus.localizedCaseInsensitiveContains("needs review") }) { return .orange }
    if !connection.classifierTestResults.isEmpty { return .green }
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

      HStack(alignment: .top, spacing: 8) {
        Image(systemName: queueSymbol)
          .foregroundStyle(queueColor)
          .frame(width: 18)
        VStack(alignment: .leading, spacing: 3) {
          Text(queueTitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(queueColor)
          Text(queueDetail)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(queueColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

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

  private var queueTitle: String {
    if summary.parserIssueCount > 0 {
      return "Active queue: parser review"
    }
    if summary.pendingUncertainReviewCount > 0 {
      return "Active queue: uncertain SpaceMail review"
    }
    if summary.linkedIntakeCount > 0 && summary.importedCount > 0 {
      return "Active queue: Inbox triage"
    }
    if summary.pendingFilteredReviewCount > 0 {
      return "Optional queue: filtered examples"
    }
    if summary.filteredCount > 0 && summary.importedCount == 0 && summary.uncertainCount == 0 {
      return "No primary queue: mixed-mailbox filter handled this refresh"
    }
    if summary.duplicateCount > 0 && summary.importedCount == 0 {
      return "No primary queue: duplicate refresh"
    }
    return "No primary queue waiting"
  }

  private var queueDetail: String {
    if summary.parserIssueCount > 0 {
      return "Review parser diagnostics before creating orders so weak order, tracking, sender, or destination fields do not flow downstream."
    }
    if summary.pendingUncertainReviewCount > 0 {
      return "Uncertain previews stayed out of Inbox. Import only true order mail, or dismiss/filter non-order messages locally."
    }
    if summary.linkedIntakeCount > 0 && summary.importedCount > 0 {
      return "Imported SpaceMail rows are ready for human confirmation in Inbox before order creation or linking."
    }
    if summary.pendingFilteredReviewCount > 0 {
      return "Filtered examples are not work items by default. Spot-check them only when an expected order email is missing."
    }
    if summary.filteredCount > 0 && summary.importedCount == 0 && summary.uncertainCount == 0 {
      return "This is expected for a mixed-use mailbox when recent mail does not contain strong order or tracking evidence."
    }
    if summary.duplicateCount > 0 && summary.importedCount == 0 {
      return "ParcelOps already saw these provider message IDs, so no duplicate Inbox rows were created."
    }
    return "Run a manual refresh when new order mail is expected, or wait for the next forwarded update."
  }

  private var queueColor: Color {
    if summary.parserIssueCount > 0 { return .orange }
    if summary.pendingUncertainReviewCount > 0 { return .orange }
    if summary.linkedIntakeCount > 0 && summary.importedCount > 0 { return .green }
    if summary.pendingFilteredReviewCount > 0 { return .teal }
    if summary.filteredCount > 0 && summary.importedCount == 0 && summary.uncertainCount == 0 { return .teal }
    return .secondary
  }

  private var queueSymbol: String {
    if summary.parserIssueCount > 0 { return "text.magnifyingglass" }
    if summary.pendingUncertainReviewCount > 0 { return "questionmark.folder.fill" }
    if summary.linkedIntakeCount > 0 && summary.importedCount > 0 { return "tray.full.fill" }
    if summary.pendingFilteredReviewCount > 0 { return "line.3.horizontal.decrease.circle.fill" }
    if summary.filteredCount > 0 && summary.importedCount == 0 && summary.uncertainCount == 0 { return "line.3.horizontal.decrease.circle" }
    return "clock.arrow.circlepath"
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
      .safeAreaInset(edge: .bottom) {
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
        .overlay(Divider(), alignment: .top)
      }
      .frame(minWidth: 460, idealWidth: 620, maxWidth: 740, minHeight: 320, idealHeight: 600)
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
      .safeAreaInset(edge: .bottom) {
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
        .overlay(Divider(), alignment: .top)
      }
      .frame(minWidth: 480, idealWidth: 640, maxWidth: 760, minHeight: 320, idealHeight: 680)
      .navigationTitle("Microsoft 365 mailbox")
    }
  }
}

struct MailboxConnectionRow: View {
  var mailbox: TrackedMailbox
  var onReviewed: () -> Void = {}
  var onRemove: () -> Void = {}

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
        Button("Reviewed", systemImage: "checkmark.circle", action: onReviewed)
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
          .buttonStyle(.bordered)
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
  var onReviewed: () -> Void = {}
  var onRemove: () -> Void = {}

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
        Button("Reviewed", systemImage: "checkmark.circle", action: onReviewed)
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
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
  var onReviewed: () -> Void = {}
  var onRemove: () -> Void = {}

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
        Button("Reviewed", systemImage: "checkmark.circle", action: onReviewed)
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
          .buttonStyle(.bordered)
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
  var onReviewed: () -> Void = {}
  var onRemove: () -> Void = {}

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
        Button("Reviewed", systemImage: "checkmark.circle", action: onReviewed)
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
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

  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.gmailIntakeHealthSummaries.first
  }

  private var hasMailboxSetup: Bool {
    !store.spaceMailIMAPConnections.isEmpty || !store.gmailMailboxConnections.isEmpty
  }

  private var latestManualFetchedCount: Int {
    max(latestSpaceMailSummary?.fetchedCount ?? 0, latestGmailSummary?.fetchedCount ?? 0)
  }

  private var latestManualImportedCount: Int {
    (latestSpaceMailSummary?.importedCount ?? 0) + (latestGmailSummary?.importedCount ?? 0)
  }

  private var inboxCreatedOrdersCount: Int {
    store.orders.filter { order in
      order.source == .forwardedMailbox || order.checkedMailbox == "manual-import"
    }.count
  }

  private var manualRefreshCount: Int {
    store.spaceMailIMAPConnections.filter { $0.lastManualRefreshDate != "Never" }.count
      + store.gmailMailboxConnections.filter { $0.lastManualRefreshDate != "Never" }.count
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
    if !hasMailboxSetup || manualRefreshCount == 0 { return .orange }
    if inboxCreatedOrdersCount == 0 { return .orange }
    if unresolvedOperatorCount > 0 { return .teal }
    return .green
  }

  private var title: String {
    if !hasMailboxSetup { return "Mailbox setup needed" }
    if manualRefreshCount == 0 { return "Manual mailbox refresh needed" }
    if inboxCreatedOrdersCount == 0 { return "Inbox-created order needed" }
    if unresolvedOperatorCount > 0 { return "Open operator work remains" }
    return "Daily workflow is clean"
  }

  private var detail: String {
    if !hasMailboxSetup {
      return "Add SpaceMail for IMAP mailboxes or Gmail for Google-hosted mailboxes before judging the daily operator flow."
    }
    if manualRefreshCount == 0 {
      return "Run one explicit manual mailbox refresh from Mailbox Monitor. SpaceMail and Gmail both feed the same local Inbox intake path."
    }
    if inboxCreatedOrdersCount == 0 {
      return "Create or link one order from Inbox so Orders, Workbench, Tasks, Dashboard, and Audit can show the handoff."
    }
    if unresolvedOperatorCount > 0 {
      return "Use Inbox, Workbench, Dispatch, Tasks, and Audit to clear or deliberately leave assigned follow-up work."
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
        ("Fetched", "\(latestManualFetchedCount)", .blue),
        ("Imported", "\(latestManualImportedCount)", latestManualImportedCount > 0 ? .green : .secondary),
        ("Inbox orders", "\(inboxCreatedOrdersCount)", inboxCreatedOrdersCount == 0 ? .orange : .green),
        ("Open work", "\(unresolvedOperatorCount)", unresolvedOperatorCount == 0 ? .green : .teal)
      ])

      Text("Local boundary: manual read-only mailbox intake, local JSON records, provider credentials kept out of JSON, no mailbox mutation, no Shopify/carrier APIs, no background sync, no notifications, no OCR/scanner/calendar/file-picker workflows.")
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
  @State private var settingsFeedbackMessage: String?

  private var isCompact: Bool { horizontalSizeClass == .compact }
  private var hasSpaceMailSetup: Bool { !store.spaceMailIMAPConnections.isEmpty }
  private var hasSpaceMailCredentialReference: Bool {
    store.spaceMailIMAPConnections.contains {
      $0.credentialStorageStatus.localizedCaseInsensitiveContains("available")
        || $0.credentialStorageStatus.localizedCaseInsensitiveContains("ready")
    }
  }
  private var hasGmailSetup: Bool { !store.gmailMailboxConnections.isEmpty }
  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.gmailIntakeHealthSummaries.first
  }
  private var hasGmailConnectedAuth: Bool {
    store.gmailMailboxConnections.contains { connection in
      store.gmailAuthSessionState(for: connection).status == .connected
    }
  }
  private var hasGmailCoreSetup: Bool {
    store.gmailMailboxConnections.contains { connection in
      !connection.emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !connection.monitoredLabelNames.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !(connection.oauthClientIDPlaceholder ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !(connection.redirectURIPlaceholder ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && connection.requestedScopesSummary.localizedCaseInsensitiveContains("gmail.")
    }
  }
  private var hasLiveMailboxSetup: Bool {
    hasSpaceMailSetup || hasGmailSetup
  }
  private var hasLiveMailboxCredentialOrAuth: Bool {
    hasSpaceMailCredentialReference || hasGmailConnectedAuth
  }

  private var mailboxStatus: (String, Color) {
    if hasSpaceMailSetup && hasGmailSetup { return ("SpaceMail + Gmail", .green) }
    if hasSpaceMailSetup { return ("SpaceMail manual", .green) }
    if hasGmailSetup { return ("Gmail manual", hasGmailConnectedAuth ? .green : .orange) }
    return ("Not connected", .orange)
  }

  private var credentialStatus: (String, Color) {
    if hasSpaceMailCredentialReference && hasGmailConnectedAuth { return ("Keychain + Google", .green) }
    if hasSpaceMailCredentialReference { return ("SpaceMail Keychain", .green) }
    if hasGmailConnectedAuth { return ("Google signed in", .green) }
    if hasGmailSetup { return ("Google sign-in needed", .orange) }
    return ("Credential needed", .orange)
  }

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.spaceMailIntakeHealthSummaries.first
  }

  private var settingsManualRefreshCount: Int {
    store.spaceMailIMAPConnections.filter { $0.lastManualRefreshDate != "Never" }.count
      + store.gmailMailboxConnections.filter { $0.lastManualRefreshDate != "Never" }.count
  }

  private var latestManualMailboxFetchedCount: Int {
    max(latestSpaceMailSummary?.fetchedCount ?? 0, latestGmailSummary?.fetchedCount ?? 0)
  }

  private var latestManualMailboxImportedCount: Int {
    (latestSpaceMailSummary?.importedCount ?? 0) + (latestGmailSummary?.importedCount ?? 0)
  }

  private var latestManualMailboxFilteredCount: Int {
    (latestSpaceMailSummary?.filteredCount ?? 0) + (latestGmailSummary?.filteredCount ?? 0)
  }

  private var latestManualMailboxUncertainCount: Int {
    (latestSpaceMailSummary?.pendingUncertainReviewCount ?? 0)
      + (latestSpaceMailSummary?.uncertainCount ?? 0)
      + (latestGmailSummary?.pendingUncertainReviewCount ?? 0)
      + (latestGmailSummary?.uncertainCount ?? 0)
  }

  private var settingsInboxCreatedOrdersCount: Int {
    store.orders.filter(\.isInboxCreatedLocalOrder).count
  }

  private var settingsOpenOperatorWorkCount: Int {
    store.reviewIntakeEmails.count
      + store.intakeParserDiagnostics.count
      + store.openWorkbenchItems.count
      + store.reviewTasksNeedingAttention.count
      + store.handoffNotesNeedingAttention.count
      + store.blockedShipmentManifests.count
      + store.blockedDispatchChecklists.count
  }

  private var setupPlanningPlaceholderCount: Int {
    store.mailboxes.count
      + store.shopifyConnections.count
      + store.watchedFolders.count
  }

  private var setupUncertainReviewCount: Int {
    store.spaceMailIMAPConnections.reduce(0) { total, connection in
      total + connection.uncertainMessages.count
    }
      + store.gmailMailboxConnections.reduce(0) { total, connection in
        total + (connection.uncertainMessages?.count ?? 0) + (connection.lastRefreshUncertainCount ?? 0)
      }
  }

  private var setupCompletionItems: [(title: String, detail: String, blockers: Int, destination: String, symbol: String, color: Color)] {
    [
      (
        "Mailbox provider setup",
        "Add SpaceMail for IMAP mailboxes or Gmail for Google-hosted mailboxes before treating live intake as the primary path.",
        hasLiveMailboxSetup ? 0 : 1,
        "Mailbox Monitor",
        "envelope.badge.fill",
        hasLiveMailboxSetup ? .green : .orange
      ),
      (
        "Credential or sign-in",
        "SpaceMail uses the secure Keychain action; Gmail uses explicit Google sign-in. Do not put credentials or tokens into setup notes or JSON.",
        hasLiveMailboxCredentialOrAuth ? 0 : 1,
        "Mailbox provider row",
        "lock.shield.fill",
        hasLiveMailboxCredentialOrAuth ? .green : .orange
      ),
      (
        "Gmail setup details",
        "When Gmail is configured, confirm address, labels, OAuth app placeholders, redirect/scheme, and read-only Gmail scope notes before real refresh.",
        hasGmailSetup && !hasGmailCoreSetup ? 1 : 0,
        "Gmail row",
        "envelope.badge.shield.half.filled",
        hasGmailSetup && !hasGmailCoreSetup ? .orange : .green
      ),
      (
        "Manual refresh proof",
        "Run at least one explicit read-only mailbox refresh so setup has fetched/imported/filtered evidence.",
        settingsManualRefreshCount == 0 ? 1 : 0,
        "Mailbox Monitor",
        "tray.and.arrow.down.fill",
        settingsManualRefreshCount == 0 ? .orange : .green
      ),
      (
        "Mixed-mailbox review",
        "Uncertain messages and parser diagnostics should be reviewed without flooding the primary Inbox.",
        setupUncertainReviewCount + store.intakeParserDiagnostics.count,
        "Mailbox Monitor",
        "text.magnifyingglass",
        setupUncertainReviewCount + store.intakeParserDiagnostics.count == 0 ? .green : .orange
      ),
      (
        "Inbox to order handoff",
        "At least one Inbox-created order confirms the operator path from live intake into Orders, Workbench, Tasks, and Audit.",
        settingsInboxCreatedOrdersCount == 0 ? 1 : 0,
        "Inbox or Orders",
        "shippingbox.fill",
        settingsInboxCreatedOrdersCount == 0 ? .teal : .green
      ),
      (
        "Open operator work",
        "Outstanding review, Workbench, task, handoff, and blocked dispatch work should be assigned or deliberately left open.",
        settingsOpenOperatorWorkCount,
        "Dashboard or Tasks",
        "checklist",
        settingsOpenOperatorWorkCount == 0 ? .green : .blue
      ),
      (
        "Planning-only records",
        "Tracked mailbox, Shopify, folder, and account placeholders are allowed, but should not be mistaken for live integrations.",
        setupPlanningPlaceholderCount,
        "Settings",
        "lock.shield.fill",
        setupPlanningPlaceholderCount == 0 ? .secondary : .teal
      )
    ]
  }

  private var setupCompletionBlockerCount: Int {
    setupCompletionItems.reduce(0) { total, item in
      item.title == "Planning-only records" ? total : total + item.blockers
    }
  }

  private var setupCompletionCompleteCount: Int {
    setupCompletionItems.filter { item in
      item.blockers == 0 || item.title == "Planning-only records"
    }.count
  }

  private var settingsReadinessTone: Color {
    if !hasLiveMailboxSetup || !hasLiveMailboxCredentialOrAuth { return .orange }
    if hasGmailSetup && !hasGmailCoreSetup { return .orange }
    if settingsManualRefreshCount == 0 { return .orange }
    if settingsInboxCreatedOrdersCount == 0 { return .teal }
    if settingsOpenOperatorWorkCount > 0 { return .blue }
    return .green
  }

  private var settingsReadinessTitle: String {
    if !hasLiveMailboxSetup { return "Set up a mailbox provider before live intake testing" }
    if !hasLiveMailboxCredentialOrAuth { return "Add SpaceMail credential or complete Gmail sign-in" }
    if hasGmailSetup && !hasGmailCoreSetup { return "Finish Gmail setup details" }
    if settingsManualRefreshCount == 0 { return "Run one manual mailbox refresh" }
    if settingsInboxCreatedOrdersCount == 0 { return "Create or link one Inbox order" }
    if settingsOpenOperatorWorkCount > 0 { return "Operator workflow has open follow-up" }
    return "Daily operator setup is ready"
  }

  private var settingsReadinessDetail: String {
    if !hasLiveMailboxSetup {
      return "Use Mailbox Monitor or Integrations to add SpaceMail for IMAP mailboxes or Gmail for Google-hosted mailboxes. Keep secrets out of setup notes and JSON fields."
    }
    if !hasLiveMailboxCredentialOrAuth {
      return "Use the secure SpaceMail credential action or the explicit Google sign-in test for Gmail. Passwords, tokens, and app secrets must stay out of JSON."
    }
    if hasGmailSetup && !hasGmailCoreSetup {
      return "Complete the Gmail address, labels, OAuth client placeholder, redirect/scheme, and read-only Gmail scope notes before real Gmail refresh."
    }
    if settingsManualRefreshCount == 0 {
      return "Run an explicit read-only SpaceMail or Gmail refresh so the app has a real refresh result before hands-on testing."
    }
    if settingsInboxCreatedOrdersCount == 0 {
      return "Review imported intake in Inbox, then create or link one order so Orders, Workbench, Tasks, Dashboard, and Audit show the handoff."
    }
    if settingsOpenOperatorWorkCount > 0 {
      return "Use Inbox, Workbench, Dispatch, Tasks, and Audit to clear or deliberately leave assigned follow-up work."
    }
    return "Mailbox setup, manual refresh, Inbox-to-order handoff, local tasks, and audit trace are in place for hands-on MVP use."
  }

  private var activeSetupTitle: String {
    if let latestGmailSummary, !hasSpaceMailSetup {
      if latestGmailSummary.importedCount > 0 {
        return "Gmail imported order mail"
      }
      if latestGmailSummary.pendingUncertainReviewCount > 0 || latestGmailSummary.uncertainCount > 0 {
        return "Gmail has uncertain mail to review"
      }
      if latestGmailSummary.filteredCount > 0 {
        return "Gmail filtered mixed mailbox mail"
      }
      return "Gmail is ready for manual intake"
    }
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
    if hasGmailSetup {
      return "Finish Gmail setup to start real intake"
    }
    return "Set up a mailbox provider to start real intake"
  }

  private var activeSetupDetail: String {
    if let latestGmailSummary, !hasSpaceMailSetup {
      return "\(latestGmailSummary.displayName): \(latestGmailSummary.detail) \(latestGmailSummary.nextAction)"
    }
    guard let latestSpaceMailSummary else {
      if hasGmailSetup {
        return "Gmail setup exists. Finish required setup values, test Google sign-in, then use the explicit manual read-only Gmail refresh."
      }
      return "No live mailbox provider is configured yet. Add SpaceMail for IMAP mailboxes or Gmail for Google-hosted mailboxes."
    }
    return "\(latestSpaceMailSummary.displayName): \(latestSpaceMailSummary.detail) \(latestSpaceMailSummary.nextAction)"
  }

  private var activeSetupTone: Color {
    if let latestGmailSummary, !hasSpaceMailSetup {
      switch latestGmailSummary.tone {
      case "success": return .green
      case "attention": return .orange
      case "warning": return .red
      default: return .teal
      }
    }
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
    matchesSettingsSection("active", "setup", "SpaceMail", "Gmail", "Google", "mailbox", "credential", "Keychain", "manual", "refresh")
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

  private var settingsReadinessPanel: some View {
    SettingsPanel(title: "Daily operator readiness", symbol: "checkmark.seal.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: settingsReadinessTone == .green ? "checkmark.seal.fill" : "arrow.forward.circle.fill")
            .font(.title3)
            .foregroundStyle(settingsReadinessTone)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text(settingsReadinessTitle)
              .font(.headline)
            Text(settingsReadinessDetail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer(minLength: 8)
          Badge(settingsReadinessTone == .green ? "Ready" : "Next step", color: settingsReadinessTone)
        }

        MetricStrip(items: [
          ("Mailbox", mailboxStatus.0, mailboxStatus.1),
          ("Credential", credentialStatus.0, credentialStatus.1),
          ("Refreshes", "\(settingsManualRefreshCount)", settingsManualRefreshCount == 0 ? .orange : .green),
          ("Inbox orders", "\(settingsInboxCreatedOrdersCount)", settingsInboxCreatedOrdersCount == 0 ? .teal : .green),
          ("Open work", "\(settingsOpenOperatorWorkCount)", settingsOpenOperatorWorkCount == 0 ? .green : .blue)
        ])

        Text("Local boundary: SpaceMail and Gmail refreshes are manual and read-only; credentials and tokens stay out of JSON; Shopify, carriers, scanners, OCR, calendars, notifications, outbound email, and background sync are not live.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        CompactActionRow {
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Mailbox Monitor", systemImage: "server.rack")
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
  }

  private var setupCompletionLadderPanel: some View {
    SettingsPanel(title: "Setup completion ladder", symbol: "checklist.checked") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: setupCompletionBlockerCount == 0 ? "checkmark.seal.fill" : "list.bullet.clipboard.fill")
            .font(.title3)
            .foregroundStyle(setupCompletionBlockerCount == 0 ? .green : .orange)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text(setupCompletionBlockerCount == 0 ? "Setup path is ready for hands-on use" : "Clear setup blockers before relying on daily intake")
              .font(.headline)
            Text("This breaks Settings into the daily operator sequence: configure SpaceMail or Gmail, protect the credential or sign-in, run a manual refresh, review mixed-mailbox results, create/link an order, then close visible follow-up.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer(minLength: 8)
          Badge("\(setupCompletionCompleteCount)/\(setupCompletionItems.count)", color: setupCompletionBlockerCount == 0 ? .green : .orange)
        }

        LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 160 : 215), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(setupCompletionItems, id: \.title) { item in
            VStack(alignment: .leading, spacing: 8) {
              HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(item.title, systemImage: item.symbol)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(item.color)
                Spacer()
                Badge(item.title == "Planning-only records" ? "\(item.blockers)" : (item.blockers == 0 ? "Clear" : "\(item.blockers)"), color: item.color)
              }

              Text(item.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

              Text("Check \(item.destination)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(item.color)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(item.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }

        Text("Local boundary: this panel reads existing local setup, JSON-backed records, Keychain status labels, and auditable workflow counts only. It does not fetch mail, save passwords, contact Shopify/carriers, start background sync, send notifications, or mutate mailbox messages.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  var body: some View {
    @Bindable var store = store

    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("Settings")
          .font(isCompact ? .title.bold() : .largeTitle.bold())

        settingsReadinessPanel
        setupCompletionLadderPanel

        SettingsPanel(title: "Find setting", symbol: "magnifyingglass") {
          VStack(alignment: .leading, spacing: 10) {
            FilterControlGrid {
              TextField("Search settings, mailbox, SpaceMail, Gmail, Shopify, folders, review, carrier", text: $settingsSearchText)
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
          MVPEmptyState(title: "No settings sections match", detail: "Clear the settings search or try mailbox, SpaceMail, Gmail, Shopify, folders, review, carrier, credential, or local-only.", symbol: "magnifyingglass")
        }

        if showsActiveSetup {
          SettingsPanel(title: "Active setup now", symbol: "checkmark.seal.fill") {
          VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
              Image(systemName: hasSpaceMailSetup ? "server.rack" : hasGmailSetup ? "envelope.badge.shield.half.filled" : "server.rack.fill")
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
              ("Mailbox", mailboxStatus.0, mailboxStatus.1),
              ("Credential", credentialStatus.0, credentialStatus.1),
              ("Last fetched", "\(latestManualMailboxFetchedCount)", .blue),
              ("Imported", "\(latestManualMailboxImportedCount)", latestManualMailboxImportedCount > 0 ? .green : .secondary),
              ("Filtered", "\(latestManualMailboxFilteredCount)", latestManualMailboxFilteredCount > 0 ? .teal : .secondary)
            ])

            Text("Current live paths: SpaceMail manual read-only IMAP refresh and Gmail manual read-only API refresh. Microsoft 365, Shopify, carriers, folders, notifications, scanners, calendars, and background sync remain planning or advanced setup surfaces.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)

            ActionGroupHeader(title: "Continue setup", symbol: "arrow.right.circle.fill")
            CompactActionRow {
              NavigationLink {
                MailboxView(store: store)
              } label: {
                Label("Open Mailbox Monitor", systemImage: "server.rack")
              }
              .buttonStyle(.bordered)

              NavigationLink {
                InboxView(store: store)
              } label: {
                Label("Open Inbox", systemImage: "tray.full.fill")
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
        }

          OperatorSupportSnapshotCard(store: store, title: "Setup support snapshot", detail: "Current mailbox, credential, source trail, and audit readiness.")
        }

        if showsLocalOnlyStatus {
          MVPWorkflowGuide(
            title: "Before connecting live systems",
            detail: "Most integrations remain local planning surfaces. SpaceMail and Gmail are the current manual, read-only mailbox intake paths when their credential/sign-in setup is ready.",
            steps: [
              "Use SpaceMail and Gmail only through explicit manual refresh actions.",
              "Enter SpaceMail passwords only in the secure Keychain prompt; use Google sign-in for Gmail. Do not put secrets in setup notes or JSON fields.",
              "Treat Shopify, carrier, notification, scanner, calendar, and background-sync toggles as planning controls.",
              "Use Audit to confirm that local actions are being recorded."
            ],
            symbol: "gearshape.2.fill"
          )

          SettingsPanel(title: "Local-only status", symbol: "checklist") {
          Text("ParcelOps stores operational records in local JSON. SpaceMail uses Keychain for password/app-password values; Gmail uses explicit Google sign-in. Mailbox refresh remains manual and read-only; the rest of the integration surface remains planning-only.")
            .foregroundStyle(.secondary)

          LocalDataSafetyCard(store: store, compact: isCompact)

          LocalDataHygieneCard(store: store, compact: isCompact)

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
            MailboxConnectionRow(mailbox: mailbox) {
              store.markTrackedMailboxPlaceholderReviewed(mailbox)
              settingsFeedbackMessage = "Tracked mailbox placeholder marked reviewed locally."
            } onRemove: {
              store.removeTrackedMailboxPlaceholder(mailbox)
              settingsFeedbackMessage = "Tracked mailbox placeholder removed locally. No mailbox connection was changed."
            }
          }
          Button("Add mailbox placeholder", systemImage: "plus") {
            store.addTrackedMailboxPlaceholder()
            settingsFeedbackMessage = "Mailbox placeholder added locally for setup planning."
          }
            .buttonStyle(.bordered)
          if let settingsFeedbackMessage {
            SettingsActionFeedbackPanel(message: settingsFeedbackMessage)
          }
        }
        }

        if showsShopifyAccounts {
          SettingsPanel(title: "Shopify accounts", symbol: "cart.badge.plus") {
          ForEach(store.shopifyConnections) { connection in
            ShopifyConnectionRow(connection: connection, onReviewed: {
              store.markShopifyPlaceholderReviewed(connection)
              settingsFeedbackMessage = "Shopify placeholder marked reviewed locally."
            }, onRemove: {
              store.removeShopifyPlaceholder(connection)
              settingsFeedbackMessage = "Shopify placeholder removed locally. No Shopify API or store login was contacted."
            })
          }
          Button("Add Shopify placeholder", systemImage: "plus") {
            store.connectShopifyPlaceholder()
            settingsFeedbackMessage = "Shopify placeholder added locally. No Shopify API or store login was contacted."
          }
            .buttonStyle(.bordered)
          if let settingsFeedbackMessage {
            SettingsActionFeedbackPanel(message: settingsFeedbackMessage)
          }
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
            WatchedFolderRow(folder: folder) {
              store.markWatchedFolderPlaceholderReviewed(folder)
              settingsFeedbackMessage = "Watched folder placeholder marked reviewed locally."
            } onRemove: {
              store.removeWatchedFolderPlaceholder(folder)
              settingsFeedbackMessage = "Watched folder placeholder removed locally. No file watcher or background job was changed."
            }
          }
          Button("Add folder placeholder", systemImage: "folder.badge.plus") {
            store.addWatchedFolderPlaceholder()
            settingsFeedbackMessage = "Folder placeholder added locally. No file picker, folder scan, or background watcher was started."
          }
            .buttonStyle(.bordered)
          if let settingsFeedbackMessage {
            SettingsActionFeedbackPanel(message: settingsFeedbackMessage)
          }
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
          Button("Save settings", systemImage: "checkmark") {
            store.saveSettings()
            settingsFeedbackMessage = "Settings saved locally. Planning toggles do not start integrations, notifications, or background sync."
          }
            .buttonStyle(.borderedProminent)
          if let settingsFeedbackMessage {
            SettingsActionFeedbackPanel(message: settingsFeedbackMessage)
          }
        }
        }
      }
      .padding(isCompact ? 14 : 24)
    }
  }
}

private struct SettingsActionFeedbackPanel: View {
  var message: String

  var body: some View {
    Label {
      Text(message)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    } icon: {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
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
