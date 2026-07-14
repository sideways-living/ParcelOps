import SwiftUI

struct MailboxView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var intakeSearchText = ""
  @State private var showResolvedIntakeEmails = false
  @State private var providerSetupFeedbackMessage: String?

  private var normalizedIntakeSearch: String {
    intakeSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  private var visibleIntakeEmails: [ForwardedEmailIntake] {
    store.intakeEmails.filter { email in
      let matchesSearch = intakeEmailMatchesSearch(email)
      let isActionable = email.reviewState != .reviewed && email.reviewState != .ignored
      return matchesSearch && (showResolvedIntakeEmails || !normalizedIntakeSearch.isEmpty || isActionable)
    }
  }

  private var visibleReviewIntakeCount: Int {
    visibleIntakeEmails.filter { $0.reviewState != .reviewed && $0.reviewState != .ignored }.count
  }

  private var hiddenResolvedIntakeCount: Int {
    guard normalizedIntakeSearch.isEmpty && !showResolvedIntakeEmails else { return 0 }
    return store.intakeEmails.filter { $0.reviewState == .reviewed || $0.reviewState == .ignored }.count
  }

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.latestSpaceMailIntakeHealthSummary
  }

  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.latestGmailIntakeHealthSummary
  }

  private var latestMailboxFetchedCount: Int {
    store.latestMailboxFetchedCount
  }

  private var latestMailboxImportedCount: Int {
    store.latestMailboxImportedCount
  }

  private var latestMailboxDuplicateCount: Int {
    store.latestMailboxDuplicateCount
  }

  private var latestMailboxDuplicateRefreshedCount: Int {
    store.latestMailboxDuplicateRefreshedCount
  }

  private var latestMailboxFilteredCount: Int {
    store.latestMailboxFilteredCount
  }

  private var latestMailboxUncertainCount: Int {
    store.latestMailboxUncertainCount
  }

  private var mailboxProviderDecision: (title: String, detail: String, color: Color) {
    let hasSpaceMailSetup = !store.spaceMailIMAPConnections.isEmpty
    let hasGmailSetup = !store.gmailMailboxConnections.isEmpty
    let hasSpaceMailRefresh = latestSpaceMailSummary.map {
      $0.fetchedCount > 0 || $0.importedCount > 0 || $0.duplicateCount > 0 || $0.filteredCount > 0 || $0.uncertainCount > 0
    } ?? false
    let hasGmailRefresh = latestGmailSummary.map {
      $0.fetchedCount > 0 || $0.importedCount > 0 || $0.duplicateCount > 0 || $0.filteredCount > 0 || $0.uncertainCount > 0
    } ?? false

    if latestMailboxImportedCount > 0 {
      return (
        "Start in Inbox",
        "\(latestMailboxImportedCount) likely order message\(latestMailboxImportedCount == 1 ? "" : "s") reached Inbox. Review, edit, then create or link orders.",
        .green
      )
    }
    if latestMailboxUncertainCount > 0 {
      return (
        "Review uncertain mail first",
        "\(latestMailboxUncertainCount) uncertain preview\(latestMailboxUncertainCount == 1 ? "" : "s") stayed out of Inbox. Import only the true order messages.",
        .orange
      )
    }
    if latestMailboxFilteredCount > 0 {
      return (
        "Filtered mail looks quiet",
        "\(latestMailboxFilteredCount) mixed-mailbox message\(latestMailboxFilteredCount == 1 ? "" : "s") were kept out of Inbox. Check examples only if an expected order is missing.",
        .teal
      )
    }
    if hasSpaceMailRefresh || hasGmailRefresh {
      return (
        "Refresh ran with no order candidates",
        "The latest manual refresh fetched mail but did not create order intake. Send a known test order or check filtered examples if something is missing.",
        .secondary
      )
    }
    if hasSpaceMailSetup || hasGmailSetup {
      return (
        "Run the active provider refresh",
        "Choose SpaceMail for IMAP-hosted mailboxes or Gmail for Google-hosted mailboxes, then run the explicit manual read-only refresh.",
        .blue
      )
    }
    return (
      "Set up a mailbox provider",
      "Add SpaceMail for IMAP-hosted mailboxes or Gmail for Google-hosted mailboxes before testing live intake.",
      .orange
    )
  }

  private var mailboxProviderRows: [(name: String, status: String, detail: String, symbol: String, color: Color)] {
    let spaceMailCredentialReady = store.spaceMailIMAPConnections.contains {
      $0.credentialStorageStatus.localizedCaseInsensitiveContains("available")
        || $0.credentialStorageStatus.localizedCaseInsensitiveContains("ready")
    }
    let gmailSignedIn = store.gmailMailboxConnections.contains {
      store.gmailAuthSessionState(for: $0).status == .connected
    }
    let gmailSetupReady = store.gmailMailboxConnections.contains {
      store.gmailOAuthReadinessSummary(for: $0).isReady
    }

    return [
      (
        "SpaceMail / IMAP",
        store.spaceMailIMAPConnections.isEmpty ? "Not set" : spaceMailCredentialReady ? "Ready" : "Credential needed",
        latestSpaceMailSummary.map { "\($0.fetchedCount) fetched, \($0.importedCount) imported, \($0.filteredCount) filtered, \($0.pendingUncertainReviewCount) uncertain. \($0.nextAction)" }
          ?? "Use for SpaceMail or other IMAP-hosted mailboxes. Requires host, SSL/TLS, folder, username, and Keychain password reference.",
        "server.rack",
        store.spaceMailIMAPConnections.isEmpty ? .secondary : spaceMailCredentialReady ? .green : .orange
      ),
      (
        "Gmail / Google Workspace",
        store.gmailMailboxConnections.isEmpty ? "Not set" : gmailSignedIn ? "Signed in" : gmailSetupReady ? "Sign-in needed" : "Setup needed",
        latestGmailSummary.map { "\($0.fetchedCount) fetched, \($0.importedCount) imported, \($0.filteredCount) filtered, \($0.pendingUncertainReviewCount) uncertain. \($0.nextAction)" }
          ?? "Use only for Gmail or Google Workspace mailboxes. Requires matching Google client setup, explicit sign-in, and manual read-only refresh.",
        "envelope.badge.shield.half.filled",
        store.gmailMailboxConnections.isEmpty ? .secondary : gmailSignedIn ? .green : .orange
      )
    ]
  }

  private var wishlistOrderWatchItems: [WishlistItem] {
    store.wishlistItems
      .filter { item in
        store.isActiveWishlistItem(item)
          && item.purchaseHandoff != nil
          && item.purchaseHandoff?.linkedOrderID == nil
      }
      .sorted { first, second in
        let firstMatches = store.suggestedWishlistOrderConfirmations(for: first).count
        let secondMatches = store.suggestedWishlistOrderConfirmations(for: second).count
        if firstMatches == secondMatches {
          return first.itemName.localizedCaseInsensitiveCompare(second.itemName) == .orderedAscending
        }
        return firstMatches > secondMatches
      }
  }

  private var wishlistOrderWatchMatchCount: Int {
    wishlistOrderWatchItems.reduce(0) { partial, item in
      partial + store.suggestedWishlistOrderConfirmations(for: item).count
    }
  }

  @ViewBuilder
  private var wishlistOrderWatchPanel: some View {
    if !wishlistOrderWatchItems.isEmpty {
      SettingsPanel(title: "Wishlist order watch", symbol: "star.square.on.square.fill") {
        Text("Use this after manual mailbox refreshes to connect Wishlist purchase handoffs to imported order confirmations. This is local matching only; ParcelOps does not watch retailer accounts, run checkout, or poll mail in the background.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        MetricStrip(items: [
          ("Watching", "\(wishlistOrderWatchItems.count)", .orange),
          ("Inbox matches", "\(wishlistOrderWatchMatchCount)", wishlistOrderWatchMatchCount > 0 ? .green : .secondary),
          ("Action", wishlistOrderWatchMatchCount > 0 ? "link match" : "refresh mail", wishlistOrderWatchMatchCount > 0 ? .green : .blue)
        ])

        ForEach(wishlistOrderWatchItems.prefix(5)) { item in
          WishlistOrderWatchMatchRow(
            item: item,
            matches: Array(store.suggestedWishlistOrderConfirmations(for: item).prefix(3)),
            onUseConfirmation: { email in
              store.confirmWishlistOrderFromIntake(item, email: email)
            },
            onMarkSeen: {
              store.markWishlistOrderConfirmationSeen(item)
            }
          )
        }

        CompactActionRow {
          NavigationLink {
            WishlistView(store: store)
          } label: {
            Label("Open Wishlist", systemImage: "star.square.fill")
          }
          .buttonStyle(.bordered)
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Open Inbox", systemImage: "tray.full.fill")
          }
          .buttonStyle(.bordered)
        }
      }
    }
  }

  private func addOrFocusSpaceMailSetup() {
    if store.spaceMailIMAPConnections.isEmpty {
      store.addSpaceMailIMAPConnectionPlaceholder()
      providerSetupFeedbackMessage = "SpaceMail setup added locally. Confirm host/folder details and set the Keychain credential before real refresh."
    } else {
      providerSetupFeedbackMessage = "Use the existing SpaceMail setup row below. Add another setup only when there is a second IMAP mailbox to manage."
    }
  }

  private func addOrFocusGmailSetup() {
    if store.gmailMailboxConnections.isEmpty {
      store.addGmailMailboxConnectionPlaceholder()
      providerSetupFeedbackMessage = "Gmail setup added locally. Complete non-secret Google app details before sign-in or real refresh."
    } else {
      providerSetupFeedbackMessage = "Use the existing Gmail setup row below. Add another setup only when there is a second Gmail or Google Workspace mailbox."
    }
  }

  private func addOrFocusMicrosoft365Setup() {
    if store.microsoft365MailboxConnections.isEmpty {
      store.addMicrosoft365MailboxConnectionPlaceholder()
      providerSetupFeedbackMessage = "Microsoft 365 setup added locally. Keep this path advanced unless the mailbox is Microsoft-hosted."
    } else {
      providerSetupFeedbackMessage = "Use the existing Microsoft 365 setup row below. Keep it secondary unless this mailbox is actually Microsoft-hosted."
    }
  }

  private var activeMailboxProviderPanel: some View {
    SettingsPanel(title: "Active mailbox path", symbol: "arrow.triangle.branch") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: mailboxProviderDecision.color == .green ? "checkmark.circle.fill" : "arrow.right.circle.fill")
            .foregroundStyle(mailboxProviderDecision.color)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(mailboxProviderDecision.title)
              .font(.headline)
            Text(mailboxProviderDecision.detail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Badge(mailboxProviderDecision.color == .green ? "Ready" : "Next", color: mailboxProviderDecision.color)
        }

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(mailboxProviderRows, id: \.name) { row in
            VStack(alignment: .leading, spacing: 8) {
              HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(row.name, systemImage: row.symbol)
                  .font(.subheadline.weight(.semibold))
                Spacer()
                Badge(row.status, color: row.color)
              }
              Text(row.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(row.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(row.color.opacity(0.22)))
          }
        }

        Text("Boundary: this panel only summarizes local provider state. It does not sign in, fetch mail, store credentials, classify new messages, or change mailbox messages.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        CompactActionRow {
          if latestMailboxImportedCount > 0 {
            NavigationLink {
              InboxView(store: store)
            } label: {
              Label("Review Inbox intake", systemImage: "tray.full.fill")
            }
            .buttonStyle(.borderedProminent)
          } else {
            NavigationLink {
              InboxView(store: store)
            } label: {
              Label("Open Inbox", systemImage: "tray.full.fill")
            }
            .buttonStyle(.bordered)
          }

          NavigationLink {
            IntegrationsView(store: store)
          } label: {
            Label("Provider setup", systemImage: "gearshape.2.fill")
          }
          .buttonStyle(.bordered)

          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Audit evidence", systemImage: "list.clipboard.fill")
          }
          .buttonStyle(.bordered)
        }

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 10)], alignment: .leading, spacing: 10) {
          MailboxProviderStepCard(number: "1", title: "Confirm provider", detail: "Use SpaceMail for IMAP mailboxes and Gmail only for Google-hosted mailboxes.")
          MailboxProviderStepCard(number: "2", title: "Run manual refresh", detail: "Refresh is explicit and read-only. No background mailbox watching starts here.")
          MailboxProviderStepCard(number: "3", title: "Review results", detail: "Imported rows go to Inbox; uncertain and filtered previews stay out until reviewed.")
          MailboxProviderStepCard(number: "4", title: "Create or link order", detail: "Only confirmed Inbox rows should become Orders or linked source evidence.")
        }
      }
    }
  }

  private func intakeEmailMatchesSearch(_ email: ForwardedEmailIntake) -> Bool {
    let query = normalizedIntakeSearch
    guard !query.isEmpty else { return true }
    let searchableText = [
      email.sender,
      email.subject,
      email.receivedDate,
      email.rawBodyPreview,
      email.detectedMerchant,
      email.detectedOrderNumber,
      email.detectedTrackingNumber,
      email.detectedDestinationAddress,
      email.linkedOrderID?.uuidString ?? "",
      email.reviewState.rawValue
    ].joined(separator: " ").lowercased()

    return searchableText.contains(query)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Forwarded email intake")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Local captures from the tracking mailbox are reviewed here before they become order records or supporting evidence.")
            .foregroundStyle(.secondary)
        }

        MVPWorkflowGuide(
          title: "What to do here",
          detail: "Treat each forwarded email as a draft signal until a person confirms the detected order details.",
          steps: [
            "Check merchant, order number, tracking number, and destination.",
            "Edit any wrong detected values before accepting.",
            "Link to an existing order or create a new order.",
            "Mark reviewed, ignore, or create a task when follow-up is needed."
          ],
          symbol: "envelope.open.fill"
        )

        activeMailboxProviderPanel

        MailboxReviewStartPanel(store: store)

        MailboxProviderOperatorReadinessStack(
          store: store,
          title: "Provider intake at a glance",
          detail: "Start here to decide which mailbox provider is the active manual intake path today. Open advanced evidence only when troubleshooting setup, parser, release, or provider readiness.",
          showHandoffPacket: true,
          showMailboxLink: false
        )

        MailboxProviderSetupChecklistCard(summary: store.mailboxProviderSetupChecklistSummary)

        wishlistOrderWatchPanel

        MailboxSpaceMailReadinessPanel(store: store)

        MailboxSpaceMailRunbookPanel(store: store)

        MailboxGmailReadinessPanel(store: store)

        MailboxGmailRunbookPanel(store: store)

        SpaceMailOperatorGuidanceStack(store: store)

        if let providerSetupFeedbackMessage {
          Label(providerSetupFeedbackMessage, systemImage: "checkmark.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.teal)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        SettingsPanel(title: "SpaceMail IMAP setup", symbol: "server.rack") {
          Text("Use SpaceMail for IMAP mailboxes. Gmail setup below covers Google-hosted mailboxes; both feed the same local Inbox intake path.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Text("Do not enter passwords here. No password, app password, auth string, or Keychain item is stored in JSON or audit logs.")
            .font(.caption)
            .foregroundStyle(.secondary)
          CompactActionRow {
            Button(store.spaceMailIMAPConnections.isEmpty ? "Add SpaceMail setup" : "Show existing SpaceMail setup", systemImage: store.spaceMailIMAPConnections.isEmpty ? "plus" : "arrow.down.circle.fill") {
              addOrFocusSpaceMailSetup()
            }
              .buttonStyle(.bordered)
            Badge("\(store.spaceMailIMAPConnections.count) setup records", color: .blue)
          }
          if store.spaceMailIMAPConnections.isEmpty {
            MVPEmptyState(title: "No SpaceMail IMAP setup", detail: "Add a SpaceMail setup, confirm host/folder details, set the Keychain password, then use either Mock SpaceMail refresh or the manual real read-only refresh.", symbol: "server.rack")
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
            } onCreateLatestRefreshTask: {
              store.createSpaceMailLatestRefreshReviewTask(for: connection)
            } onCreateParserQATask: {
              store.createSpaceMailParserQAReviewTask(for: connection)
            } onRemove: {
              store.removeSpaceMailIMAPConnection(connection)
            }
          }
        }

        SettingsPanel(title: "Gmail mailbox setup", symbol: "envelope.badge.shield.half.filled") {
          Text("Use this for Gmail or Google Workspace mailboxes that feed Inbox through the same intake path. Mock refresh remains available; real Gmail refresh is manual, read-only, and separate from sign-in.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          GmailGoogleCloudSetupGuide()
          CompactActionRow {
            Button(store.gmailMailboxConnections.isEmpty ? "Add Gmail setup" : "Show existing Gmail setup", systemImage: store.gmailMailboxConnections.isEmpty ? "plus" : "arrow.down.circle.fill") {
              addOrFocusGmailSetup()
            }
              .buttonStyle(.bordered)
            Badge("\(store.gmailMailboxConnections.count) setup records", color: .teal)
          }
          if store.gmailMailboxConnections.isEmpty {
            MVPEmptyState(title: "No Gmail setup", detail: "Add a Gmail setup record to capture address, labels, mixed-mailbox mode, OAuth app notes, and manual read-only refresh readiness.", symbol: "envelope.badge.shield.half.filled")
          }
          if !store.gmailMailboxConnections.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Label("Gmail release readiness", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
              ForEach(store.gmailMailboxConnections) { connection in
                GmailReleaseSelfCheckSummaryCard(summary: store.gmailReleaseSelfCheckSummary(for: connection))
              }
            }
          }
          ForEach(store.gmailMailboxConnections) { connection in
            GmailMailboxConnectionRow(
              connection: connection,
              readiness: store.gmailOAuthReadinessSummary(for: connection),
              implementationPlan: store.gmailOAuthImplementationPlan(for: connection),
              setupTestChecklist: store.gmailSetupTestChecklist(for: connection),
              releaseSelfCheck: store.gmailReleaseSelfCheckSummary(for: connection),
              labelReadiness: store.gmailLabelReadinessSummary(for: connection),
              authState: store.gmailAuthSessionState(for: connection),
              activeRefreshTask: store.activeGmailLatestRefreshTask(for: connection)
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
            } onCreateReleaseTask: {
              store.createReviewTaskFromGmailReleaseSelfCheck(connection)
            } onCreateRefreshTask: {
              store.createReviewTaskFromGmailLatestRefresh(connection)
            } onImportUncertain: { message in
              store.importUncertainGmailMessage(message, for: connection)
            } onDismissUncertain: { message in
              store.dismissUncertainGmailMessage(message, for: connection)
            } onCreateUncertainTask: { message in
              store.createReviewTask(from: message, connection: connection, reviewQueue: "uncertain")
            } onCreateUncertainDraft: { message in
              store.createDraftMessage(from: message, connection: connection, reviewQueue: "uncertain")
            } onTrustUncertainSender: { message in
              store.addGmailHintFromUncertain(message, target: .trustedSender, for: connection)
            } onImportUncertainHint: { message in
              store.addGmailHintFromUncertain(message, target: .importKeyword, for: connection)
            } onFilterUncertainHint: { message in
              store.addGmailHintFromUncertain(message, target: .filterKeyword, for: connection)
            } onImportFiltered: { message in
              store.importFilteredGmailMessage(message, for: connection)
            } onDismissFiltered: { message in
              store.dismissFilteredGmailMessage(message, for: connection)
            } onCreateFilteredTask: { message in
              store.createReviewTask(from: message, connection: connection, reviewQueue: "filtered")
            } onCreateFilteredDraft: { message in
              store.createDraftMessage(from: message, connection: connection, reviewQueue: "filtered")
            } onTrustFilteredSender: { message in
              store.addGmailHintFromFiltered(message, target: .trustedSender, for: connection)
            } onImportFilteredHint: { message in
              store.addGmailHintFromFiltered(message, target: .importKeyword, for: connection)
            } onFilterFilteredHint: { message in
              store.addGmailHintFromFiltered(message, target: .filterKeyword, for: connection)
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

        SettingsPanel(title: "After mailbox refresh", symbol: "arrow.right.circle.fill") {
          VStack(alignment: .leading, spacing: 12) {
            Text("Use these shortcuts after a real or mock refresh. Imported order emails go to Inbox; detailed refresh and action history stays in Audit.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)

            MetricStrip(items: [
              ("Fetched", "\(latestMailboxFetchedCount)", .blue),
              ("Imported", "\(latestMailboxImportedCount)", latestMailboxImportedCount > 0 ? .green : .secondary),
              ("Duplicates", "\(latestMailboxDuplicateCount)", latestMailboxDuplicateCount > 0 ? .orange : .secondary),
              ("Refreshed", "\(latestMailboxDuplicateRefreshedCount)", latestMailboxDuplicateRefreshedCount > 0 ? .green : .secondary),
              ("Filtered", "\(latestMailboxFilteredCount)", latestMailboxFilteredCount > 0 ? .teal : .secondary),
              ("Uncertain", "\(latestMailboxUncertainCount)", latestMailboxUncertainCount > 0 ? .orange : .secondary)
            ])

            MailboxProviderRefreshSummaryGrid(
              spaceMailSummary: latestSpaceMailSummary,
              gmailSummary: latestGmailSummary
            )

            SpaceMailRefreshTrendCard(summary: store.spaceMailRefreshTrendSummary)
            SpaceMailShiftHandoffCard(
              summary: store.spaceMailShiftHandoffSummary,
              onCreateDraft: { store.createSpaceMailShiftDraftMessage() }
            )
            GmailPostRefreshActionCard(plan: store.gmailPostRefreshActionPlan)
            GmailShiftHandoffCard(
              summary: store.gmailShiftHandoffSummary,
              onCreateHandoffNote: { store.createGmailShiftHandoffNote() },
              onCreateTask: { store.createGmailShiftReviewTask() },
              onCreateDraft: { store.createGmailShiftDraftMessage() }
            )
            SpaceMailReleaseSnapshotCard(snapshot: store.mailboxReleaseReadinessSnapshot, store: store, usesMailboxReleaseTask: true)
            MailboxReleaseBlockerCard(summary: store.mailboxReleaseBlockerSummary)
            MailboxOperatorDecisionCard(summary: store.mailboxOperatorDecisionSummary)
            GmailRefreshTrendCard(summary: store.gmailRefreshTrendSummary)

            Text("Provider rows summarize the latest active mailbox outcomes, trend history, handoff status, and refresh status so operators do not need to open Audit for the basic refresh decision. Filtered mixed-mailbox messages stay out of Inbox unless explicitly promoted or imported.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)

            CompactActionRow {
              NavigationLink {
                InboxView(store: store)
              } label: {
                Label("Open Inbox", systemImage: "tray.full.fill")
              }
              .buttonStyle(.borderedProminent)

              NavigationLink {
                AuditView(store: store)
              } label: {
                Label("Open Audit", systemImage: "list.clipboard.fill")
              }
              .buttonStyle(.bordered)

              if !store.gmailMailboxConnections.isEmpty {
                Button {
                  store.recordGmailReleaseReadinessSnapshot()
                } label: {
                  Label("Record Gmail snapshot", systemImage: "camera.metering.center.weighted")
                }
                .buttonStyle(.bordered)
              }
            }
          }
        }

        MailboxMissedOrderInvestigationPanel(
          store: store,
          latestSpaceMailSummary: latestSpaceMailSummary,
          latestGmailSummary: latestGmailSummary
        )

        SettingsPanel(title: "Microsoft 365 setup planning", symbol: "mail.stack.fill") {
          Text("Microsoft 365 remains available as an advanced option. The active mailbox provider rows above are the current manual intake paths for this project.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Microsoft365SetupFlowGuide()
          CompactActionRow {
            Button(store.microsoft365MailboxConnections.isEmpty ? "Add mailbox setup" : "Show Microsoft 365 setup", systemImage: store.microsoft365MailboxConnections.isEmpty ? "plus" : "arrow.down.circle.fill") {
              addOrFocusMicrosoft365Setup()
            }
              .buttonStyle(.bordered)
            Badge("\(store.microsoft365MailboxConnections.count) setup records", color: .orange)
          }
          if store.microsoft365MailboxConnections.isEmpty {
            MVPEmptyState(title: "No Microsoft 365 mailbox setup", detail: "Add a setup record in Mailbox Monitor or Settings, then run Mock Graph refresh to test the local intake path.", symbol: "mail.stack")
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

        SettingsPanel(title: "Local sample mailbox import", symbol: "tray.and.arrow.down.fill") {
          Text("Import local sample fetched mailbox messages through the same provider-neutral intake path. No mailbox is contacted.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          CompactActionRow {
            Button("Import clear order test email", systemImage: "checklist.checked") {
              store.importClearOrderIntakeTestMessage()
            }
            .buttonStyle(.borderedProminent)
            Button("Import sample messages", systemImage: "envelope.badge.fill") {
              store.importSimulatedFetchedMailboxMessages()
            }
            .buttonStyle(.bordered)
            Badge("\(store.mailboxIngestRecords.count) ingest records", color: .blue)
          }
          Text("Use the clear order test when you need one obvious Inbox row with an order number and tracking number before testing Create order, link order, and review actions.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        if !store.intakeParserDiagnostics.isEmpty {
          SettingsPanel(title: "Parser review queue", symbol: "text.magnifyingglass") {
            Text("Local diagnostics for already-captured intake emails. These checks do not fetch mail or change duplicate metadata.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
            CompactActionRow {
              Button("Reprocess all needing review", systemImage: "arrow.triangle.2.circlepath") {
                store.reprocessReviewIntakeEmails()
              }
              .buttonStyle(.bordered)
              Badge("\(store.intakeParserDiagnostics.count) diagnostics", color: .orange)
            }
            ForEach(store.intakeParserDiagnostics.prefix(8)) { diagnostic in
              IntakeParserDiagnosticRow(diagnostic: diagnostic) {
                if let email = store.intakeEmails.first(where: { $0.id == diagnostic.intakeEmailID }) {
                  store.reprocessIntakeEmail(email)
                }
              } onCreateTask: {
                if let email = store.intakeEmails.first(where: { $0.id == diagnostic.intakeEmailID }) {
                  store.createReviewTask(from: email)
                }
              }
            }
          }
        }

        SettingsPanel(title: "Detected order emails", symbol: "envelope.open.fill") {
          if store.intakeEmails.isEmpty {
            MVPEmptyState(title: "No forwarded emails yet", detail: "Run an active mailbox provider refresh, or import sample messages, to populate the mailbox review flow.", symbol: "envelope.badge")
          } else {
            Text("Default view shows actionable intake only. Reviewed and ignored rows are preserved locally, but hidden unless you search or show resolved rows.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)

            FilterControlGrid {
              TextField("Search subject, sender, order, tracking, merchant, destination, or linked order", text: $intakeSearchText)
                .textFieldStyle(.roundedBorder)

              Toggle("Show resolved", isOn: $showResolvedIntakeEmails)
                .font(.caption.weight(.semibold))
                .toggleStyle(.switch)

              Button("Clear", systemImage: "xmark.circle") {
                intakeSearchText = ""
              }
              .buttonStyle(.bordered)
              .disabled(normalizedIntakeSearch.isEmpty)

              Badge("\(visibleIntakeEmails.count) shown", color: visibleIntakeEmails.isEmpty ? .orange : .blue)
              Badge("\(visibleReviewIntakeCount) need review", color: visibleReviewIntakeCount == 0 ? .green : .orange)
              if hiddenResolvedIntakeCount > 0 {
                Badge("\(hiddenResolvedIntakeCount) resolved hidden", color: .secondary)
              }
            }

            CompactActionRow {
              Button("Reprocess all needing review", systemImage: "arrow.triangle.2.circlepath") {
                store.reprocessReviewIntakeEmails()
              }
              .buttonStyle(.bordered)
              Badge("\(store.reviewIntakeEmails.count) need review", color: .orange)
            }

            if visibleIntakeEmails.isEmpty {
              MVPEmptyState(title: showResolvedIntakeEmails ? "No detected emails match" : "No actionable intake emails match", detail: hiddenResolvedIntakeCount > 0 ? "Reviewed and ignored rows are hidden from the default queue. Search for a known subject or turn on Show resolved to inspect them." : "Clear the intake search or try a broader term such as order, tracking, sender, merchant, destination, or review state.", symbol: "magnifyingglass")
            }

            ForEach(visibleIntakeEmails) { email in
              IntakeEmailRow(email: email, store: store, orders: store.orders, evidenceAttachments: store.evidence(for: .intakeEmail, linkedEntityID: email.id), suggestedContacts: store.suggestedContacts(for: email), suggestedAccounts: store.suggestedAccounts(for: email), suggestedProfiles: store.suggestedVendorProfiles(for: email), customerProfiles: store.suggestedCustomerProfiles(for: email), destinationAddresses: store.suggestedDestinationAddresses(for: email), deliveryInstructions: store.suggestedDeliveryInstructions(for: email), packageContents: store.suggestedPackageContents(for: email), shipmentGroups: store.suggestedShipmentGroups(for: email)) { updatedEmail in
                store.updateIntakeEmail(updatedEmail)
              } onLinkOrder: { order in
                store.linkIntakeEmail(email, to: order)
              } onCreateOrder: {
                store.createOrder(from: email)
              } onReviewed: {
                store.markIntakeEmailReviewed(email)
              } onIgnore: {
                store.ignoreIntakeEmail(email)
              } onReprocess: {
                store.reprocessIntakeEmail(email)
              } onAddEvidence: {
                store.addPlaceholderEvidence(to: .intakeEmail, linkedEntityID: email.id, label: email.detectedOrderNumber)
              } onReviewEvidence: { attachment in
                store.markEvidenceReviewed(attachment)
              } onRemoveEvidence: { attachment in
                store.removeEvidence(attachment)
              } onCreateTask: {
                store.createReviewTask(from: email)
              } onCreateDraft: {
                store.createDraftMessage(from: email)
              } onDraftFromContact: { contact in
                store.createDraftMessage(from: contact, linkedEntityType: .intakeEmail, linkedEntityID: email.id.uuidString, label: email.detectedOrderNumber)
              } onCreateAccount: {
                store.addAccountCredentialRecord(linkedEntityType: .intakeEmail, linkedEntityID: email.id.uuidString, organisation: email.detectedMerchant, label: email.detectedOrderNumber)
              } onTaskFromAccount: { account in
                store.createReviewTask(from: account)
              } onDraftFromAccount: { account in
                store.createDraftMessage(from: account)
              } onCreateProfile: {
                store.addVendorProfile(profileType: .supplier, organisation: email.detectedMerchant, label: email.detectedOrderNumber)
              } onTaskFromProfile: { profile in
                store.createReviewTask(from: profile)
              } onDraftFromProfile: { profile in
                store.createDraftMessage(from: profile)
              }
            }
          }
        }

        SettingsPanel(title: "Mailbox events", symbol: "envelope.badge.fill") {
          ForEach(store.mailEvents) { event in
            MailEventRow(event: event)
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }
}

struct WishlistOrderWatchMatchRow: View {
  var item: WishlistItem
  var matches: [ForwardedEmailIntake]
  var onUseConfirmation: (ForwardedEmailIntake) -> Void
  var onMarkSeen: () -> Void

  private var handoff: WishlistPurchaseHandoff? {
    item.purchaseHandoff
  }

  private var expectedSignals: String {
    let value = handoff?.expectedOrderSignals.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return value.isEmpty ? "\(item.storefront) | \(item.itemName)" : value
  }

  private var sellerLabel: String {
    let seller = handoff?.sellerName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return seller.isEmpty || seller.isPlaceholderValidationValue ? item.storefront : seller
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: matches.isEmpty ? "clock.badge.exclamationmark" : "link.badge.plus")
          .foregroundStyle(matches.isEmpty ? Color.orange : Color.green)
          .frame(width: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(item.itemName)
            .font(.subheadline.weight(.semibold))
          Text("\(sellerLabel) • \(handoff?.purchaseStatus ?? "Purchase handoff active")")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("Expected signal: \(expectedSignals)")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        Spacer()
        Badge(matches.isEmpty ? "No match yet" : "\(matches.count) match\(matches.count == 1 ? "" : "es")", color: matches.isEmpty ? .orange : .green)
      }

      if matches.isEmpty {
        Text("No imported Inbox confirmation currently matches this Wishlist handoff. Run a manual mailbox refresh, or use Mark seen if the purchase was checked outside ParcelOps.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(matches) { email in
            let matchDetail = wishlistOrderWatchMatchDetail(email)
            HStack(alignment: .top, spacing: 10) {
              VStack(alignment: .leading, spacing: 3) {
                Text(email.subject.isPlaceholderValidationValue ? "Imported confirmation" : email.subject)
                  .font(.caption.weight(.semibold))
                  .lineLimit(2)
                Text(email.sender)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
                Text(wishlistOrderWatchEmailSummary(email))
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .lineLimit(2)
                Text("\(matchDetail.confidence) confidence • \(matchDetail.reasons.joined(separator: ", "))")
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(matchDetail.color)
                  .lineLimit(2)
              }
              Spacer()
              Button("Use confirmation", systemImage: "link.badge.plus") {
                onUseConfirmation(email)
              }
              .buttonStyle(.borderedProminent)
              .controlSize(.small)
            }
            .padding(8)
            .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }
      }

      CompactActionRow {
        Button("Mark seen", systemImage: "envelope.badge.fill", action: onMarkSeen)
          .buttonStyle(.bordered)
        if let linkedOrderID = handoff?.linkedOrderID {
          Badge("Linked order \(linkedOrderID.uuidString.prefix(8))", color: .green)
        } else {
          Badge("Order link pending", color: .orange)
        }
      }
    }
    .padding(12)
    .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
  }

  private func wishlistOrderWatchEmailSummary(_ email: ForwardedEmailIntake) -> String {
    var parts: [String] = []
    if !email.detectedOrderNumber.isPlaceholderValidationValue {
      parts.append("Order \(email.detectedOrderNumber)")
    }
    if !email.detectedTrackingNumber.isPlaceholderValidationValue {
      parts.append("Tracking \(email.detectedTrackingNumber)")
    }
    if !email.detectedMerchant.isPlaceholderValidationValue {
      parts.append("Merchant \(email.detectedMerchant)")
    }
    if parts.isEmpty {
      parts.append("Imported \(email.receivedDate)")
    }
    return parts.joined(separator: " • ")
  }

  private func wishlistOrderWatchMatchDetail(_ email: ForwardedEmailIntake) -> (score: Int, confidence: String, reasons: [String], color: Color) {
    let searchable = [
      email.sender,
      email.subject,
      email.rawBodyPreview,
      email.detectedMerchant,
      email.detectedOrderNumber,
      email.detectedTrackingNumber
    ]
      .joined(separator: " ")
      .localizedLowercase
    let itemName = item.itemName.localizedLowercase
    let seller = sellerLabel.localizedLowercase
    let signals = expectedSignals
      .components(separatedBy: CharacterSet(charactersIn: "|,"))
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase }
      .filter { $0.count >= 4 && !$0.isPlaceholderValidationValue }

    var score = 0
    var reasons: [String] = []
    if !seller.isEmpty && searchable.contains(seller) {
      score += 3
      reasons.append("seller")
    }
    if !itemName.isEmpty && searchable.contains(itemName) {
      score += 3
      reasons.append("item")
    }
    if signals.contains(where: { searchable.contains($0) }) {
      score += 2
      reasons.append("expected signal")
    }
    if !email.detectedOrderNumber.isPlaceholderValidationValue {
      score += 3
      reasons.append("order number")
    }
    if !email.detectedTrackingNumber.isPlaceholderValidationValue {
      score += 3
      reasons.append("tracking")
    }
    if searchable.contains("order") {
      score += 1
      reasons.append("order wording")
    }
    if searchable.contains("confirmation") || searchable.contains("confirmed") {
      score += 2
      reasons.append("confirmation")
    }
    if searchable.contains("shipped") || searchable.contains("tracking") || searchable.contains("dispatch") || searchable.contains("delivery") {
      score += 2
      reasons.append("shipping")
    }
    if searchable.contains("invoice") || searchable.contains("receipt") {
      score += 1
      reasons.append("receipt")
    }
    if email.linkedOrderID != nil {
      score += 2
      reasons.append("linked order")
    }
    if searchable.contains("newsletter") || searchable.contains("unsubscribe") || searchable.contains("promotion") {
      score -= 3
      reasons.append("marketing signal")
    }

    if score >= 10 {
      return (score, "High", Array(reasons.prefix(5)), .green)
    }
    if score >= 7 {
      return (score, "Medium", Array(reasons.prefix(5)), .teal)
    }
    if score >= 4 {
      return (score, "Low", Array(reasons.prefix(5)), .orange)
    }
    return (score, "Weak", reasons.isEmpty ? ["no clear signal"] : Array(reasons.prefix(5)), .secondary)
  }
}

private struct MailboxProviderStepCard: View {
  var number: String
  var title: String
  var detail: String

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Text(number)
        .font(.caption.bold())
        .foregroundStyle(.white)
        .frame(width: 24, height: 24)
        .background(.teal, in: Circle())
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
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct MailboxMissedOrderInvestigationPanel: View {
  var store: ParcelOpsStore
  var latestSpaceMailSummary: SpaceMailIntakeHealthSummary?
  var latestGmailSummary: GmailIntakeHealthSummary?

  private struct ReviewPreview: Identifiable {
    var id: String
    var provider: String
    var queue: String
    var subject: String
    var sender: String
    var reason: String
    var preview: String
    var tone: Color
  }

  private var latestFetchedCount: Int {
    store.latestMailboxFetchedCount
  }

  private var latestImportedCount: Int {
    store.latestMailboxImportedCount
  }

  private var latestDuplicateCount: Int {
    store.latestMailboxDuplicateCount
  }

  private var latestDuplicateRefreshedCount: Int {
    store.latestMailboxDuplicateRefreshedCount
  }

  private var latestFilteredCount: Int {
    store.latestMailboxFilteredCount
  }

  private var latestUncertainCount: Int {
    store.latestMailboxUncertainCount
  }

  private var parserDiagnosticCount: Int {
    store.intakeParserDiagnostics.count
  }

  private var hasProviderSetup: Bool {
    !store.spaceMailIMAPConnections.isEmpty || !store.gmailMailboxConnections.isEmpty
  }

  private var reviewPreviews: [ReviewPreview] {
    let spaceMailUncertain = store.spaceMailIMAPConnections.flatMap { connection in
      connection.uncertainMessages.prefix(3).map { message in
        ReviewPreview(
          id: "spacemail-uncertain-\(connection.id)-\(message.id)",
          provider: "SpaceMail",
          queue: "Uncertain",
          subject: message.subject,
          sender: message.sender,
          reason: message.reason,
          preview: message.bodyPreview,
          tone: .orange
        )
      }
    }
    let gmailUncertain = store.gmailMailboxConnections.flatMap { connection in
      (connection.uncertainMessages ?? []).prefix(3).map { message in
        ReviewPreview(
          id: "gmail-uncertain-\(connection.id)-\(message.id)",
          provider: "Gmail",
          queue: "Uncertain",
          subject: message.subject,
          sender: message.sender,
          reason: message.reason,
          preview: message.bodyPreview,
          tone: .orange
        )
      }
    }
    let spaceMailFiltered = store.spaceMailIMAPConnections.flatMap { connection in
      connection.filteredMessages.prefix(2).map { message in
        ReviewPreview(
          id: "spacemail-filtered-\(connection.id)-\(message.id)",
          provider: "SpaceMail",
          queue: "Filtered",
          subject: message.subject,
          sender: message.sender,
          reason: message.reason,
          preview: message.bodyPreview,
          tone: .teal
        )
      }
    }
    let gmailFiltered = store.gmailMailboxConnections.flatMap { connection in
      (connection.filteredMessages ?? []).prefix(2).map { message in
        ReviewPreview(
          id: "gmail-filtered-\(connection.id)-\(message.id)",
          provider: "Gmail",
          queue: "Filtered",
          subject: message.subject,
          sender: message.sender,
          reason: message.reason,
          preview: message.bodyPreview,
          tone: .teal
        )
      }
    }

    return Array((spaceMailUncertain + gmailUncertain + spaceMailFiltered + gmailFiltered).prefix(8))
  }

  private var latestFilteredExamples: [String] {
    let spaceMailExamples = store.spaceMailIMAPConnections.flatMap { $0.lastRefreshFilteredExamples }
    let gmailExamples = store.gmailMailboxConnections.flatMap { $0.lastRefreshFilteredExamples ?? [] }
    return Array((spaceMailExamples + gmailExamples).prefix(5))
  }

  private var latestUncertainExamples: [String] {
    let spaceMailExamples = store.spaceMailIMAPConnections.flatMap { $0.lastRefreshUncertainExamples }
    let gmailExamples = store.gmailMailboxConnections.flatMap { $0.lastRefreshUncertainExamples ?? [] }
    return Array((spaceMailExamples + gmailExamples).prefix(5))
  }

  private var title: String {
    if !hasProviderSetup { return "Set up a mailbox provider first" }
    if latestImportedCount > 0 { return "Latest refresh imported order candidates" }
    if latestUncertainCount > 0 { return "Review uncertain mailbox previews" }
    if latestDuplicateRefreshedCount > 0 { return "Existing Inbox rows were refreshed" }
    if latestFilteredCount > 0 { return "Check filtered examples if an order is missing" }
    if parserDiagnosticCount > 0 { return "Parser diagnostics need review" }
    if latestFetchedCount > 0 { return "Latest refresh found no order candidates" }
    return "Run a mailbox refresh to investigate missing orders"
  }

  private var detail: String {
    if !hasProviderSetup {
      return "Add SpaceMail for IMAP mailboxes or Gmail for Google-hosted mailboxes, then run a manual read-only refresh."
    }
    if latestImportedCount > 0 {
      return "\(latestImportedCount) likely order message\(latestImportedCount == 1 ? "" : "s") reached Inbox. Start in Inbox, then create or link orders."
    }
    if latestUncertainCount > 0 {
      return "\(latestUncertainCount) uncertain preview\(latestUncertainCount == 1 ? "" : "s") stayed out of Inbox. Import true order mail or dismiss non-order mail locally."
    }
    if latestDuplicateRefreshedCount > 0 {
      return "\(latestDuplicateRefreshedCount) duplicate message\(latestDuplicateRefreshedCount == 1 ? "" : "s") refreshed existing Inbox rows. Open Inbox to confirm whether the refreshed row is ready to create or link as an order."
    }
    if latestFilteredCount > 0 {
      return "\(latestFilteredCount) fetched message\(latestFilteredCount == 1 ? "" : "s") were filtered as non-order. Use the examples below only when an expected order email is missing."
    }
    if parserDiagnosticCount > 0 {
      return "Captured intake exists, but parser diagnostics still need review before creating clean orders."
    }
    if latestFetchedCount > 0 {
      return "The latest provider refresh fetched mail but did not create order intake. Send or forward a known test order, then refresh again."
    }
    return "No recent provider refresh evidence is available. Use an active mailbox provider setup row to run a manual refresh."
  }

  private var tone: Color {
    if !hasProviderSetup { return .orange }
    if latestImportedCount > 0 { return .green }
    if latestUncertainCount > 0 || parserDiagnosticCount > 0 { return .orange }
    if latestDuplicateRefreshedCount > 0 { return .green }
    if latestFilteredCount > 0 { return .teal }
    return .secondary
  }

  var body: some View {
    SettingsPanel(title: "Missing order investigation", symbol: "magnifyingglass.circle.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: latestImportedCount > 0 ? "tray.and.arrow.down.fill" : "magnifyingglass.circle.fill")
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
          Badge(latestImportedCount > 0 ? "Inbox" : latestUncertainCount > 0 ? "Review" : latestFilteredCount > 0 ? "Filtered" : "Check", color: tone)
        }

        MetricStrip(items: [
          ("Fetched", "\(latestFetchedCount)", latestFetchedCount > 0 ? .blue : .secondary),
          ("Imported", "\(latestImportedCount)", latestImportedCount > 0 ? .green : .secondary),
          ("Duplicates", "\(latestDuplicateCount)", latestDuplicateCount > 0 ? .orange : .secondary),
          ("Refreshed", "\(latestDuplicateRefreshedCount)", latestDuplicateRefreshedCount > 0 ? .green : .secondary),
          ("Filtered", "\(latestFilteredCount)", latestFilteredCount > 0 ? .teal : .secondary),
          ("Uncertain", "\(latestUncertainCount)", latestUncertainCount > 0 ? .orange : .secondary),
          ("Parser", "\(parserDiagnosticCount)", parserDiagnosticCount > 0 ? .orange : .green)
        ])

        CompactMetadataGrid(minimumWidth: 190) {
          investigationStep(
            index: 1,
            title: "Check Inbox",
            detail: latestImportedCount > 0 ? "Imported candidates are actionable there." : "No imported candidates from the latest refresh.",
            isActive: latestImportedCount > 0
          )
          investigationStep(
            index: 2,
            title: "Review uncertain",
            detail: latestUncertainCount > 0 ? "Import true order mail or dismiss locally." : "No uncertain previews are pending.",
            isActive: latestUncertainCount > 0
          )
          investigationStep(
            index: 3,
            title: "Inspect filtered",
            detail: latestFilteredCount > 0 ? "Use examples only when an expected order is missing." : "No filtered examples from the latest refresh.",
            isActive: latestFilteredCount > 0
          )
          investigationStep(
            index: 4,
            title: "Reprocess parser",
            detail: parserDiagnosticCount > 0 ? "Reprocess or task parser diagnostics." : "Parser queue is clear.",
            isActive: parserDiagnosticCount > 0
          )
        }

        if !reviewPreviews.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Label("Reviewable previews", systemImage: "line.3.horizontal.decrease.circle.fill")
              .font(.caption.weight(.semibold))
              .foregroundStyle(tone)
            ForEach(reviewPreviews) { preview in
              VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                  Text(preview.subject.isEmpty ? "No subject" : preview.subject)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                  Spacer()
                  Badge(preview.provider, color: preview.provider == "Gmail" ? .teal : .blue)
                  Badge(preview.queue, color: preview.tone)
                }
                Text(preview.sender)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
                Text(preview.reason)
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(preview.tone)
                Text(preview.preview)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .lineLimit(2)
              }
              .padding(8)
              .background(preview.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        } else if !latestFilteredExamples.isEmpty || !latestUncertainExamples.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Label("Latest safe examples", systemImage: "doc.text.magnifyingglass")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.teal)
            if !latestUncertainExamples.isEmpty {
              Text("Uncertain: \(latestUncertainExamples.joined(separator: "; "))")
                .font(.caption2)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            }
            if !latestFilteredExamples.isEmpty {
              Text("Filtered: \(latestFilteredExamples.joined(separator: "; "))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .padding(10)
          .background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        if !store.intakeParserDiagnostics.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Label("Top parser checks", systemImage: "text.magnifyingglass")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.orange)
            ForEach(store.intakeParserDiagnostics.prefix(3)) { diagnostic in
              VStack(alignment: .leading, spacing: 3) {
                Text(diagnostic.title)
                  .font(.caption.weight(.semibold))
                Text("\(diagnostic.subjectPreview) • \(diagnostic.recommendedAction)")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .lineLimit(2)
              }
              .padding(8)
              .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }

        Text("This panel reads local summaries only. It does not fetch mail, change duplicate metadata, mutate mailbox messages, or store full message bodies.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        CompactActionRow {
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
          Button("Reprocess intake", systemImage: "arrow.triangle.2.circlepath") {
            store.reprocessReviewIntakeEmails()
          }
          .disabled(store.reviewIntakeEmails.isEmpty)
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private func investigationStep(index: Int, title: String, detail: String, isActive: Bool) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Text("\(index)")
        .font(.caption2.weight(.bold))
        .foregroundStyle(.white)
        .frame(width: 22, height: 22)
        .background(isActive ? tone : Color.secondary, in: Circle())
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption.weight(.semibold))
        Text(detail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background((isActive ? tone : Color.secondary).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct MailboxProviderRefreshSummaryGrid: View {
  var spaceMailSummary: SpaceMailIntakeHealthSummary?
  var gmailSummary: GmailIntakeHealthSummary?

  var body: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 10)], alignment: .leading, spacing: 10) {
      providerCard(
        title: "SpaceMail IMAP",
        symbol: "server.rack",
        summary: spaceMailSummary.map {
          ProviderSummary(
            name: $0.displayName,
            verdict: $0.verdict,
            detail: $0.detail,
            nextAction: $0.nextAction,
            tone: $0.tone,
            fetched: $0.fetchedCount,
            imported: $0.importedCount,
            duplicate: $0.duplicateCount,
            duplicateRefreshed: $0.duplicateRefreshedCount,
            duplicateNoChange: $0.duplicateNoChangeCount,
            filtered: $0.filteredCount,
            uncertain: $0.pendingUncertainReviewCount + $0.uncertainCount,
            lastRefresh: $0.lastRefreshDate
          )
        },
        emptyDetail: "Use SpaceMail for IMAP mailboxes such as SpaceMail. Add setup and Keychain credential before real refresh."
      )

      providerCard(
        title: "Gmail / Google Workspace",
        symbol: "envelope.badge.shield.half.filled",
        summary: gmailSummary.map {
          ProviderSummary(
            name: $0.displayName,
            verdict: $0.verdict,
            detail: $0.detail,
            nextAction: $0.nextAction,
            tone: $0.tone,
            fetched: $0.fetchedCount,
            imported: $0.importedCount,
            duplicate: $0.duplicateCount,
            duplicateRefreshed: $0.duplicateRefreshedCount,
            duplicateNoChange: $0.duplicateNoChangeCount,
            filtered: $0.filteredCount,
            uncertain: $0.pendingUncertainReviewCount + $0.uncertainCount,
            lastRefresh: $0.lastRefreshDate
          )
        },
        emptyDetail: "Use Gmail setup only for Google-hosted mailboxes. Real refresh remains explicit, manual, and read-only."
      )
    }
  }

  private func providerCard(title: String, symbol: String, summary: ProviderSummary?, emptyDetail: String) -> some View {
    let tone = color(for: summary?.tone ?? "neutral")
    return VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label(title, systemImage: symbol)
          .font(.caption.weight(.semibold))
          .foregroundStyle(tone)
        Spacer()
        Badge(summary?.lastRefresh ?? "No refresh", color: tone)
      }

      if let summary {
        Text(summary.verdict)
          .font(.subheadline.weight(.semibold))
        Text("\(summary.name): \(summary.detail)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        MetricStrip(items: [
          ("Fetched", "\(summary.fetched)", summary.fetched > 0 ? .blue : .secondary),
          ("Imported", "\(summary.imported)", summary.imported > 0 ? .green : .secondary),
          ("Duplicates", "\(summary.duplicate)", summary.duplicate > 0 ? .teal : .secondary),
          ("Refreshed", "\(summary.duplicateRefreshed)", summary.duplicateRefreshed > 0 ? .green : .secondary),
          ("Filtered", "\(summary.filtered)", summary.filtered > 0 ? .teal : .secondary),
          ("Uncertain", "\(summary.uncertain)", summary.uncertain > 0 ? .orange : .secondary)
        ])
        if summary.duplicateRefreshed > 0 || summary.duplicateNoChange > 0 {
          Label("\(summary.duplicateRefreshed) duplicate refresh update\(summary.duplicateRefreshed == 1 ? "" : "s"), \(summary.duplicateNoChange) duplicate no-change result\(summary.duplicateNoChange == 1 ? "" : "s"). Existing Inbox rows were reused instead of duplicated.", systemImage: "arrow.triangle.2.circlepath")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(summary.duplicateRefreshed > 0 ? .green : .secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Text("Next: \(summary.nextAction)")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(tone)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        Text("Not configured")
          .font(.subheadline.weight(.semibold))
        Text(emptyDetail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(tone.opacity(0.16)))
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

  private struct ProviderSummary {
    var name: String
    var verdict: String
    var detail: String
    var nextAction: String
    var tone: String
    var fetched: Int
    var imported: Int
    var duplicate: Int
    var duplicateRefreshed: Int
    var duplicateNoChange: Int
    var filtered: Int
    var uncertain: Int
    var lastRefresh: String
  }
}

private struct MailboxReviewStartPanel: View {
  var store: ParcelOpsStore

  private var latestSummary: SpaceMailIntakeHealthSummary? {
    store.latestSpaceMailIntakeHealthSummary
  }

  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.latestGmailIntakeHealthSummary
  }

  private var reviewEmailCount: Int {
    store.reviewIntakeEmails.count
  }

  private var parserIssueCount: Int {
    store.intakeParserDiagnostics.count
  }

  private var uncertainCount: Int {
    store.pendingSpaceMailUncertainReviewCount
  }

  private var gmailUncertainCount: Int {
    store.gmailMailboxConnections.reduce(0) { $0 + ($1.uncertainMessages?.count ?? 0) + ($1.lastRefreshUncertainCount ?? 0) }
  }

  private var gmailWarningCount: Int {
    store.gmailIntakeHealthSummaries.filter { $0.tone == "warning" || $0.tone == "attention" }.count
  }

  private var providerReviewCount: Int {
    uncertainCount + gmailUncertainCount + gmailWarningCount
  }

  private var tone: Color {
    if parserIssueCount > 0 || providerReviewCount > 0 { return .orange }
    if reviewEmailCount > 0 { return .teal }
    if latestSummary == nil && latestGmailSummary == nil { return .orange }
    return .green
  }

  private var title: String {
    if parserIssueCount > 0 { return "Start with parser checks" }
    if uncertainCount > 0 { return "Review uncertain SpaceMail messages" }
    if gmailUncertainCount > 0 { return "Review uncertain Gmail messages" }
    if gmailWarningCount > 0 { return "Review Gmail setup or refresh state" }
    if reviewEmailCount > 0 { return "Review imported order emails" }
    if latestSummary == nil && latestGmailSummary == nil { return "Set up a mailbox before real intake" }
    return "Mailbox review is clear"
  }

  private var detail: String {
    if parserIssueCount > 0 {
      return "Parser checks mean a captured message still has weak order, tracking, merchant, or destination evidence. Reprocess or edit before creating orders."
    }
    if uncertainCount > 0 {
      return "Uncertain messages are held out of Inbox. Import only if the subject and preview look order-related; otherwise dismiss or add classifier hints."
    }
    if gmailUncertainCount > 0 {
      return "Gmail uncertain previews are also held out of Inbox. Review them in the Gmail setup row before importing any mixed-mailbox message."
    }
    if gmailWarningCount > 0 {
      return "At least one Gmail setup has a sign-in, consent, label, API, or readiness state that needs review before it should create Inbox work."
    }
    if reviewEmailCount > 0 {
      return "Work the detected order emails below. Confirm fields, then create/link orders, mark reviewed, ignore, task, or draft."
    }
    if latestSummary == nil && latestGmailSummary == nil {
      return "Add SpaceMail for IMAP mailboxes or Gmail for Google-hosted mailboxes. Both paths feed the same local Inbox intake queue."
    }
    return "Latest mailbox activity has no immediate review rows. Use setup details only when tuning the active mailbox provider or investigating Audit evidence."
  }

  var body: some View {
    SettingsPanel(title: "Mailbox review first", symbol: "arrow.forward.circle.fill") {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: tone == .green ? "checkmark.seal.fill" : "tray.full.fill")
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
        Badge(tone == .green ? "Clear" : "Review", color: tone)
      }

      MetricStrip(items: [
        ("Fetched", "\((latestSummary?.fetchedCount ?? 0) + (latestGmailSummary?.fetchedCount ?? 0))", .blue),
        ("Imported", "\((latestSummary?.importedCount ?? 0) + (latestGmailSummary?.importedCount ?? 0))", ((latestSummary?.importedCount ?? 0) + (latestGmailSummary?.importedCount ?? 0)) > 0 ? .green : .secondary),
        ("Filtered", "\((latestSummary?.filteredCount ?? 0) + (latestGmailSummary?.filteredCount ?? 0))", ((latestSummary?.filteredCount ?? 0) + (latestGmailSummary?.filteredCount ?? 0)) > 0 ? .teal : .secondary),
        ("Uncertain", "\(uncertainCount + gmailUncertainCount)", uncertainCount + gmailUncertainCount == 0 ? .green : .orange),
        ("Parser", "\(parserIssueCount)", parserIssueCount == 0 ? .green : .orange),
        ("Review rows", "\(reviewEmailCount)", reviewEmailCount == 0 ? .green : .teal)
      ])

      Text("Filtered mixed-mailbox messages are not imported into Inbox. Mailbox provider setup controls below are for configuration and diagnostics; the review queue is the operational work.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

private struct MailboxSpaceMailReadinessPanel: View {
  var store: ParcelOpsStore

  private var latestSummary: SpaceMailIntakeHealthSummary? {
    store.latestSpaceMailIntakeHealthSummary
  }

  private var hasSetup: Bool {
    !store.spaceMailIMAPConnections.isEmpty
  }

  private var hasCredentialReference: Bool {
    store.spaceMailIMAPConnections.contains {
      $0.credentialStorageStatus.localizedCaseInsensitiveContains("available")
        || $0.credentialStorageStatus.localizedCaseInsensitiveContains("ready")
    }
  }

  private var hasManualRefresh: Bool {
    store.spaceMailIMAPConnections.contains { $0.lastManualRefreshDate != "Never" }
  }

  private var parserSuiteResults: [SpaceMailClassifierTestResult] {
    store.spaceMailIMAPConnections.flatMap(\.classifierTestResults)
  }

  private var parserChecks: [SpaceMailClassifierTestResult] {
    parserSuiteResults.filter { !$0.parserStatus.localizedCaseInsensitiveContains("No parser expectation") }
  }

  private var parserPasses: [SpaceMailClassifierTestResult] {
    parserChecks.filter { $0.parserStatus.localizedCaseInsensitiveContains("passed") }
  }

  private var parserFailures: [SpaceMailClassifierTestResult] {
    parserChecks.filter { $0.parserStatus.localizedCaseInsensitiveContains("needs review") }
  }

  private var readinessTone: Color {
    if !hasSetup || !hasCredentialReference || !hasManualRefresh || parserChecks.isEmpty || !parserFailures.isEmpty { return .orange }
    if (latestSummary?.pendingUncertainReviewCount ?? 0) > 0 { return .orange }
    return .green
  }

  private var readinessTitle: String {
    if !hasSetup { return "SpaceMail setup is needed" }
    if !hasCredentialReference { return "SpaceMail credential is needed" }
    if parserChecks.isEmpty { return "Run parser QA before live order extraction" }
    if !parserFailures.isEmpty { return "Review parser QA failures" }
    if !hasManualRefresh { return "Run a manual SpaceMail refresh" }
    if (latestSummary?.pendingUncertainReviewCount ?? 0) > 0 { return "Review uncertain SpaceMail previews" }
    return "SpaceMail intake path is ready"
  }

  private var readinessDetail: String {
    if !hasSetup {
      return "Add one SpaceMail setup record with non-secret host, port, folder, and mixed-mailbox mode before using live intake."
    }
    if !hasCredentialReference {
      return "Set or check the Keychain password/app-password reference. Do not put passwords in setup notes or JSON-backed fields."
    }
    if parserChecks.isEmpty {
      return "Run the parser/classifier suite so the app proves it can distinguish filtered mail from order mail and extract order/tracking values from built-in samples."
    }
    if !parserFailures.isEmpty {
      return "\(parserFailures.count) parser expectation failed. Create a parser QA task or review the sample results before trusting similar live messages."
    }
    if !hasManualRefresh {
      return "Run the explicit manual read-only refresh. It uses EXAMINE/BODY.PEEK and must not delete, move, mark read, flag, send, or modify mailbox items."
    }
    if (latestSummary?.pendingUncertainReviewCount ?? 0) > 0 {
      return "Uncertain previews are held out of Inbox. Import only true order updates; dismiss or tune hints for non-order mail."
    }
    return "Setup, credential, parser QA, and latest refresh evidence are present. Continue reviewing imported order emails and Audit as needed."
  }

  var body: some View {
    SettingsPanel(title: "SpaceMail readiness", symbol: "checklist.checked") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: readinessTone == .green ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
            .foregroundStyle(readinessTone)
            .frame(width: 24)

          VStack(alignment: .leading, spacing: 4) {
            Text(readinessTitle)
              .font(.headline)
            Text(readinessDetail)
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer()
          Badge(readinessTone == .green ? "Ready" : "Action", color: readinessTone)
        }

        MetricStrip(items: [
          ("Setup", hasSetup ? "Set" : "Needed", hasSetup ? .green : .orange),
          ("Credential", hasCredentialReference ? "Keychain" : "Needed", hasCredentialReference ? .green : .orange),
          ("Parser QA", parserChecks.isEmpty ? "Not run" : "\(parserPasses.count)/\(parserChecks.count)", parserFailures.isEmpty && !parserChecks.isEmpty ? .green : .orange),
          ("Refresh", hasManualRefresh ? "Seen" : "Needed", hasManualRefresh ? .green : .orange),
          ("Imported", "\(latestSummary?.importedCount ?? 0)", (latestSummary?.importedCount ?? 0) > 0 ? .green : .secondary),
          ("Uncertain", "\(latestSummary?.pendingUncertainReviewCount ?? latestSummary?.uncertainCount ?? 0)", ((latestSummary?.pendingUncertainReviewCount ?? latestSummary?.uncertainCount ?? 0) > 0) ? .orange : .secondary),
          ("Filtered", "\(latestSummary?.filteredCount ?? 0)", (latestSummary?.filteredCount ?? 0) > 0 ? .teal : .secondary)
        ])

        CompactActionRow {
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Open Inbox", systemImage: "tray.full.fill")
          }
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
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
}

private struct MailboxSpaceMailRunbookPanel: View {
  var store: ParcelOpsStore

  private var latestSummary: SpaceMailIntakeHealthSummary? {
    store.latestSpaceMailIntakeHealthSummary
  }

  private var primaryConnection: SpaceMailIMAPConnection? {
    store.spaceMailIMAPConnections.first
  }

  private var hasSetup: Bool {
    primaryConnection != nil
  }

  private var hasCredentialReference: Bool {
    store.spaceMailIMAPConnections.contains {
      $0.credentialStorageStatus.localizedCaseInsensitiveContains("available")
        || $0.credentialStorageStatus.localizedCaseInsensitiveContains("ready")
    }
  }

  private var hasRefreshEvidence: Bool {
    store.spaceMailIMAPConnections.contains { $0.lastManualRefreshDate != "Never" }
  }

  private var actionableIntakeCount: Int {
    store.intakeEmails.filter { $0.reviewState != .reviewed && $0.reviewState != .ignored }.count
  }

  private var linkedIntakeCount: Int {
    store.intakeEmails.filter { $0.linkedOrderID != nil }.count
  }

  private var parserDiagnosticCount: Int {
    store.intakeParserDiagnostics.count
  }

  private var pendingUncertainCount: Int {
    latestSummary?.pendingUncertainReviewCount ?? latestSummary?.uncertainCount ?? 0
  }

  private var pendingFilteredReviewCount: Int {
    latestSummary?.pendingFilteredReviewCount ?? 0
  }

  private var runbookItems: [(title: String, detail: String, status: String, symbol: String, color: Color)] {
    [
      (
        "1. Confirm setup",
        hasSetup ? "SpaceMail host, port, folder, and mailbox mode are present." : "Add the SpaceMail setup record before testing live intake.",
        hasSetup ? "Ready" : "Needed",
        "server.rack",
        hasSetup ? .green : .orange
      ),
      (
        "2. Check credential",
        hasCredentialReference ? "A Keychain password/app-password reference is available for manual refresh." : "Set or check the Keychain credential before real refresh.",
        hasCredentialReference ? "Ready" : "Needed",
        "key.fill",
        hasCredentialReference ? .green : .orange
      ),
      (
        "3. Run refresh",
        hasRefreshEvidence ? "A manual read-only refresh has run. Latest refresh: \(latestSummary?.lastRefreshDate ?? primaryConnection?.lastManualRefreshDate ?? "unknown")." : "Run one manual read-only refresh after setup and credentials are ready.",
        hasRefreshEvidence ? "Seen" : "Needed",
        "arrow.triangle.2.circlepath",
        hasRefreshEvidence ? .green : .orange
      ),
      (
        "4. Review results",
        "Fetched \(latestSummary?.fetchedCount ?? 0), imported \(latestSummary?.importedCount ?? 0), duplicates \(latestSummary?.duplicateCount ?? 0), filtered \(latestSummary?.filteredCount ?? 0), uncertain \(pendingUncertainCount).",
        hasRefreshEvidence ? "Current" : "Waiting",
        "chart.bar.doc.horizontal",
        hasRefreshEvidence ? .blue : .secondary
      ),
      (
        "5. Triage Inbox",
        actionableIntakeCount > 0 ? "\(actionableIntakeCount) actionable intake rows need review. \(linkedIntakeCount) intake rows already have linked-order context." : "No actionable intake rows are waiting in the primary Inbox.",
        actionableIntakeCount > 0 ? "Action" : "Clear",
        "tray.full.fill",
        actionableIntakeCount > 0 ? .orange : .green
      ),
      (
        "6. Handle edge cases",
        pendingUncertainCount > 0 || pendingFilteredReviewCount > 0 || parserDiagnosticCount > 0
          ? "\(pendingUncertainCount) uncertain, \(pendingFilteredReviewCount) filtered-review, and \(parserDiagnosticCount) parser diagnostic rows need optional review."
          : "No uncertain, filtered-review, or parser diagnostic rows are currently blocking intake.",
        pendingUncertainCount > 0 || pendingFilteredReviewCount > 0 || parserDiagnosticCount > 0 ? "Review" : "Clear",
        "questionmark.folder.fill",
        pendingUncertainCount > 0 || pendingFilteredReviewCount > 0 || parserDiagnosticCount > 0 ? .orange : .green
      )
    ]
  }

  private var headline: String {
    if !hasSetup { return "Start by adding SpaceMail setup" }
    if !hasCredentialReference { return "Set the SpaceMail credential next" }
    if !hasRefreshEvidence { return "Run the first manual SpaceMail refresh" }
    if actionableIntakeCount > 0 { return "Review imported order emails" }
    if pendingUncertainCount > 0 { return "Review uncertain SpaceMail messages" }
    return "SpaceMail intake runbook is clear"
  }

  private var headlineColor: Color {
    if !hasSetup || !hasCredentialReference || !hasRefreshEvidence || actionableIntakeCount > 0 || pendingUncertainCount > 0 { return .orange }
    return .green
  }

  var body: some View {
    SettingsPanel(title: "SpaceMail refresh runbook", symbol: "list.bullet.rectangle.portrait.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: headlineColor == .green ? "checkmark.circle.fill" : "arrow.right.circle.fill")
            .foregroundStyle(headlineColor)
            .frame(width: 24)

          VStack(alignment: .leading, spacing: 4) {
            Text(headline)
              .font(.headline)
            Text("This is the operator path after opening Mailbox Monitor. It uses existing local state only and does not fetch, mutate, or reclassify messages.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer()
          Badge(headlineColor == .green ? "Clear" : "Next action", color: headlineColor)
        }

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(runbookItems, id: \.title) { item in
            VStack(alignment: .leading, spacing: 8) {
              HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(item.title, systemImage: item.symbol)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(item.color)
                Spacer()
                Badge(item.status, color: item.color)
              }
              Text(item.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(item.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }

        CompactActionRow {
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Open Inbox", systemImage: "tray.full.fill")
          }
          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Open Audit evidence", systemImage: "list.clipboard.fill")
          }
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open follow-up tasks", systemImage: "checklist")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }
}

private struct MailboxGmailRunbookPanel: View {
  var store: ParcelOpsStore

  private var latestSummary: GmailIntakeHealthSummary? {
    store.latestGmailIntakeHealthSummary
  }

  private var primaryConnection: GmailMailboxConnection? {
    store.gmailMailboxConnections.first
  }

  private var primaryReadiness: GmailOAuthReadinessSummary? {
    primaryConnection.map { store.gmailOAuthReadinessSummary(for: $0) }
  }

  private var primaryAuthState: GmailAuthSessionState? {
    primaryConnection.map { store.gmailAuthSessionState(for: $0) }
  }

  private var hasSetup: Bool {
    primaryConnection != nil
  }

  private var hasMailboxBasics: Bool {
    guard let connection = primaryConnection else { return false }
    return !connection.emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !connection.monitoredLabelNames.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var hasOAuthValues: Bool {
    guard let connection = primaryConnection else { return false }
    return !(connection.oauthClientIDPlaceholder ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !(connection.redirectURIPlaceholder ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && (connection.requestedScopesSummary.localizedCaseInsensitiveContains("gmail.readonly")
        || connection.requestedScopesSummary.localizedCaseInsensitiveContains("gmail.metadata"))
  }

  private var hasCompiledReadiness: Bool {
    primaryReadiness?.isReady == true
  }

  private var hasConnectedAuth: Bool {
    primaryAuthState?.status == .connected
  }

  private var hasRefreshEvidence: Bool {
    store.gmailMailboxConnections.contains { $0.lastManualRefreshDate != "Never" }
  }

  private var pendingUncertainCount: Int {
    store.pendingGmailUncertainReviewCount
  }

  private var filteredReviewCount: Int {
    store.pendingGmailFilteredReviewCount
  }

  private var latestCountsText: String {
    guard let latestSummary else {
      return "No Gmail refresh summary exists yet."
    }
    return "Fetched \(latestSummary.fetchedCount), imported \(latestSummary.importedCount), duplicate \(latestSummary.duplicateCount), refreshed \(latestSummary.duplicateRefreshedCount), filtered \(latestSummary.filteredCount), uncertain \(latestSummary.pendingUncertainReviewCount)."
  }

  private var runbookItems: [(title: String, detail: String, status: String, symbol: String, color: Color)] {
    [
      (
        "1. Confirm Gmail setup",
        hasSetup ? "Gmail setup record exists for \(primaryConnection?.emailAddress ?? "saved mailbox")." : "Add a Gmail setup record only for Gmail or Google Workspace mailboxes.",
        hasSetup ? "Ready" : "Needed",
        "envelope.badge.shield.half.filled",
        hasSetup ? .green : .orange
      ),
      (
        "2. Check labels",
        hasMailboxBasics ? "Mailbox and monitored label names are saved: \(primaryConnection?.monitoredLabelNames ?? "INBOX")." : "Save the Gmail address and label names, usually INBOX.",
        hasMailboxBasics ? "Ready" : "Needed",
        "tag.fill",
        hasMailboxBasics ? .green : .orange
      ),
      (
        "3. Check OAuth values",
        hasOAuthValues ? "Non-secret client ID, callback scheme, and read-only Gmail scope are present." : "Save Google iOS client ID, reversed callback scheme, and gmail.readonly or gmail.metadata scope.",
        hasOAuthValues ? "Ready" : "Needed",
        "key.fill",
        hasOAuthValues ? .green : .orange
      ),
      (
        "4. Match compiled app",
        hasCompiledReadiness ? "Saved Google values match the compiled app callback configuration." : "Run readiness and make saved values match App/Info.plist before sign-in.",
        hasCompiledReadiness ? "Ready" : "Blocked",
        "app.badge.checkmark",
        hasCompiledReadiness ? .green : .orange
      ),
      (
        "5. Test sign-in",
        hasConnectedAuth ? "Google sign-in is connected for the current app session." : "Use the explicit real Google sign-in test before real Gmail refresh.",
        hasConnectedAuth ? "Connected" : "Needed",
        "person.crop.circle.badge.checkmark",
        hasConnectedAuth ? .green : .orange
      ),
      (
        "6. Run manual refresh",
        hasRefreshEvidence ? "A manual read-only Gmail refresh has run. \(latestCountsText)" : "Run real Gmail refresh only after setup, callback, and sign-in are ready. Use mock refresh for local workflow testing.",
        hasRefreshEvidence ? "Seen" : "Waiting",
        "arrow.triangle.2.circlepath",
        hasRefreshEvidence ? .blue : .secondary
      ),
      (
        "7. Review results",
        pendingUncertainCount > 0 || filteredReviewCount > 0
          ? "\(pendingUncertainCount) uncertain and \(filteredReviewCount) filtered Gmail previews are available for optional local review."
          : "No Gmail uncertain or filtered review rows are currently waiting.",
        pendingUncertainCount > 0 || filteredReviewCount > 0 ? "Review" : "Clear",
        "questionmark.folder.fill",
        pendingUncertainCount > 0 || filteredReviewCount > 0 ? .orange : .green
      )
    ]
  }

  private var headline: String {
    if !hasSetup { return "Add Gmail setup only if this mailbox is Google-hosted" }
    if !hasMailboxBasics { return "Confirm Gmail address and label names" }
    if !hasOAuthValues { return "Fill non-secret Google OAuth values" }
    if !hasCompiledReadiness { return "Match saved values to compiled app config" }
    if !hasConnectedAuth { return "Test Google sign-in next" }
    if !hasRefreshEvidence { return "Run the first manual Gmail refresh" }
    if pendingUncertainCount > 0 { return "Review uncertain Gmail previews" }
    return "Gmail runbook is clear"
  }

  private var headlineColor: Color {
    if !hasSetup || !hasMailboxBasics || !hasOAuthValues || !hasCompiledReadiness || !hasConnectedAuth || pendingUncertainCount > 0 { return .orange }
    return hasRefreshEvidence ? .green : .teal
  }

  var body: some View {
    SettingsPanel(title: "Gmail manual refresh runbook", symbol: "list.bullet.rectangle.portrait.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: headlineColor == .green ? "checkmark.circle.fill" : "arrow.right.circle.fill")
            .foregroundStyle(headlineColor)
            .frame(width: 24)

          VStack(alignment: .leading, spacing: 4) {
            Text(headline)
              .font(.headline)
            Text("Use this sequence for Gmail or Google Workspace mailboxes. It reads current local setup state only and does not sign in, fetch, classify, or mutate mailbox messages by itself.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer()
          Badge(headlineColor == .green ? "Clear" : "Next action", color: headlineColor)
        }

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 215), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(runbookItems, id: \.title) { item in
            VStack(alignment: .leading, spacing: 8) {
              HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(item.title, systemImage: item.symbol)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(item.color)
                Spacer()
                Badge(item.status, color: item.color)
              }
              Text(item.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(item.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }

        Text("Gmail remains opt-in, manual, and read-only. This runbook does not add background sync, mailbox mutation, token logging, password storage, outbound mail, or external classification.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)

        CompactActionRow {
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Open Inbox", systemImage: "tray.full.fill")
          }
          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Open Audit evidence", systemImage: "list.clipboard.fill")
          }
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open follow-up tasks", systemImage: "checklist")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }
}

struct MailboxGmailReadinessPanel: View {
  var store: ParcelOpsStore

  private var latestSummary: GmailIntakeHealthSummary? {
    store.latestGmailIntakeHealthSummary
  }

  private var primaryConnection: GmailMailboxConnection? {
    store.gmailMailboxConnections.first
  }

  private var latestReasonBreakdown: [SpaceMailClassifierReasonCount] {
    primaryConnection?.lastRefreshReasonBreakdown ?? []
  }

  private var primaryAuthState: GmailAuthSessionState? {
    guard let connection = primaryConnection else { return nil }
    return store.gmailAuthSessionState(for: connection)
  }

  private var primaryReadiness: GmailOAuthReadinessSummary? {
    guard let connection = primaryConnection else { return nil }
    return store.gmailOAuthReadinessSummary(for: connection)
  }

  private var hasSetup: Bool {
    primaryConnection != nil
  }

  private var hasCoreSetup: Bool {
    guard let connection = primaryConnection else { return false }
    return hasMailboxBasics(connection)
      && hasOAuthPlaceholders(connection)
      && hasReadOnlyScope(connection)
  }

  private var hasCompiledCallbackReadiness: Bool {
    primaryReadiness?.isReady == true
  }

  private var compiledCallbackBlockerText: String {
    guard let readiness = primaryReadiness else {
      return "No Gmail setup record is available."
    }
    if readiness.isReady {
      return "Compiled app callback values match the saved Gmail setup."
    }
    let blockers = readiness.missingFields.prefix(4).joined(separator: ", ")
    return blockers.isEmpty ? readiness.detailText : blockers
  }

  private var hasConnectedAuth: Bool {
    primaryAuthState?.status == .connected
  }

  private var hasManualRefresh: Bool {
    store.gmailMailboxConnections.contains { $0.lastManualRefreshDate != "Never" }
  }

  private var pendingUncertainCount: Int {
    store.gmailMailboxConnections.reduce(0) { $0 + ($1.uncertainMessages?.count ?? 0) + ($1.lastRefreshUncertainCount ?? 0) }
  }

  private var warningCount: Int {
    store.gmailIntakeHealthSummaries.filter { $0.tone == "warning" || $0.tone == "attention" }.count
  }

  private var importedCount: Int {
    store.totalGmailImportedCount
  }

  private var filteredCount: Int {
    store.totalGmailFilteredSignalCount
  }

  private var fetchedCount: Int {
    store.totalGmailFetchedCount
  }

  private var hasReviewOutcome: Bool {
    importedCount > 0 || filteredCount > 0 || pendingUncertainCount > 0 || fetchedCount > 0
  }

  private var hasGmailAuditEvidence: Bool {
    store.recentAuditEvents.contains { event in
      event.summary.localizedCaseInsensitiveContains("Gmail")
        || event.entityLabel.localizedCaseInsensitiveContains("Gmail")
        || event.afterDetail?.localizedCaseInsensitiveContains("Gmail") == true
    }
  }

  private var checklistItems: [GmailReadinessChecklistItem] {
    guard let connection = primaryConnection else {
      return [
        GmailReadinessChecklistItem(
          title: "Add Gmail setup",
          detail: "Create a setup record only for mailboxes hosted by Gmail or Google Workspace.",
          symbol: "plus.circle",
          isComplete: false
        )
      ]
    }

    let mailboxBasicsReady = hasMailboxBasics(connection)
    let savedOAuthFieldsReady = hasOAuthPlaceholders(connection) && hasReadOnlyScope(connection)
    let latestResultText = "\(fetchedCount) fetched, \(importedCount) imported, \(filteredCount) filtered, \(pendingUncertainCount) uncertain."
    return [
      GmailReadinessChecklistItem(
        title: "Mailbox and label",
        detail: mailboxBasicsReady ? "\(connection.emailAddress) using labels \(connection.monitoredLabelNames)." : "Add the Gmail address and monitored labels, usually INBOX.",
        symbol: "envelope.fill",
        isComplete: mailboxBasicsReady
      ),
      GmailReadinessChecklistItem(
        title: "OAuth app values",
        detail: savedOAuthFieldsReady ? "Google iOS client ID, reversed URL scheme, and read-only Gmail scope are saved." : "Add Google Cloud iOS OAuth client ID, reversed URL scheme, and gmail.readonly or gmail.metadata.",
        symbol: "key.fill",
        isComplete: savedOAuthFieldsReady
      ),
      GmailReadinessChecklistItem(
        title: "Compiled callback",
        detail: compiledCallbackBlockerText,
        symbol: "app.badge.checkmark",
        isComplete: hasCompiledCallbackReadiness
      ),
      GmailReadinessChecklistItem(
        title: "Google sign-in",
        detail: hasConnectedAuth ? "Real Google sign-in status is connected for this app session." : "Run Check readiness, then use Test real Google sign-in before running a real Gmail refresh.",
        symbol: "person.crop.circle.badge.checkmark",
        isComplete: hasConnectedAuth
      ),
      GmailReadinessChecklistItem(
        title: "Manual refresh",
        detail: hasManualRefresh ? "A manual Gmail refresh result exists. Refresh remains read-only and user-initiated." : "Run real Gmail refresh only after setup readiness, compiled callback readiness, Google sign-in, and read-only scope consent are clear. Use mock refresh for local workflow testing.",
        symbol: "arrow.triangle.2.circlepath",
        isComplete: hasManualRefresh
      ),
      GmailReadinessChecklistItem(
        title: "Review result",
        detail: hasReviewOutcome ? latestResultText : "No Gmail refresh result has produced a reviewable outcome yet.",
        symbol: "tray.full.fill",
        isComplete: hasReviewOutcome
      ),
      GmailReadinessChecklistItem(
        title: "Audit trail",
        detail: hasGmailAuditEvidence ? "Audit has Gmail setup, sign-in, refresh, or review evidence." : "Audit will show Gmail actions after setup, auth, refresh, or review work runs.",
        symbol: "list.clipboard.fill",
        isComplete: hasGmailAuditEvidence
      )
    ]
  }

  private var readinessTone: Color {
    if !hasSetup || !hasCoreSetup || !hasCompiledCallbackReadiness || !hasConnectedAuth || warningCount > 0 || pendingUncertainCount > 0 { return .orange }
    if importedCount > 0 { return .green }
    if filteredCount > 0 { return .teal }
    return .secondary
  }

  private var readinessTitle: String {
    if !hasSetup { return "Gmail setup is optional" }
    if !hasCoreSetup { return "Finish Gmail setup details" }
    if !hasCompiledCallbackReadiness { return "Fix Gmail callback readiness before sign-in" }
    if !hasConnectedAuth { return "Test Google sign-in before Gmail refresh" }
    if warningCount > 0 { return "Gmail setup or refresh needs review" }
    if pendingUncertainCount > 0 { return "Review uncertain Gmail previews" }
    if importedCount > 0 { return "Gmail imported order intake" }
    if filteredCount > 0 { return "Gmail mixed-mailbox filtering is working" }
    if !hasManualRefresh { return "Run the first Gmail refresh when needed" }
    return "Gmail intake path is quiet"
  }

  private var readinessDetail: String {
    if !hasSetup {
      return "Add Gmail setup only for mailboxes hosted by Gmail or Google Workspace. Use the provider that hosts the active mailbox."
    }
    if !hasCoreSetup {
      return "Add mailbox address, label, OAuth client placeholder, redirect/scheme, and a read-only Gmail scope note. Do not add secrets or token values."
    }
    if !hasCompiledCallbackReadiness {
      return "Saved Gmail fields must match the compiled App Info.plist client ID and callback scheme before real sign-in and refresh will be reliable."
    }
    if !hasConnectedAuth {
      return "Use the explicit Google sign-in test in the Gmail setup row. ParcelOps records only non-secret status and keeps refresh manual."
    }
    if warningCount > 0 {
      return "Check the Gmail setup row for auth, consent, label, API, or readiness diagnostics before relying on live Gmail intake."
    }
    if pendingUncertainCount > 0 {
      return "\(pendingUncertainCount) uncertain Gmail preview\(pendingUncertainCount == 1 ? "" : "s") are held out of Inbox. Import true order mail or dismiss non-order mail locally."
    }
    if importedCount > 0 {
      return "\(importedCount) Gmail message\(importedCount == 1 ? "" : "s") reached Inbox intake. Review or create/link orders from Inbox."
    }
    if filteredCount > 0 {
      return "\(filteredCount) mixed-mailbox Gmail message\(filteredCount == 1 ? "" : "s") were filtered out of Inbox. Check examples only when an expected order email is missing."
    }
    if !hasManualRefresh {
      return "Gmail setup is present but no manual refresh has run. Use mock refresh for local tests or real refresh after sign-in."
    }
    return "The latest Gmail state has no imported or uncertain order work. Run manual refresh again only when you want to check for new mail."
  }

  var body: some View {
    SettingsPanel(title: "Gmail readiness", symbol: "envelope.badge.shield.half.filled") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: readinessTone == .green || readinessTone == .teal ? "checkmark.seal.fill" : "person.badge.key")
            .foregroundStyle(readinessTone)
            .frame(width: 24)

          VStack(alignment: .leading, spacing: 4) {
            Text(readinessTitle)
              .font(.headline)
            Text(readinessDetail)
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer()
          Badge(readinessTone == .green || readinessTone == .teal ? "Ready" : "Action", color: readinessTone)
        }

        MetricStrip(items: [
          ("Setup", hasCoreSetup ? "Ready" : hasSetup ? "Missing" : "Optional", hasCoreSetup ? .green : hasSetup ? .orange : .secondary),
          ("Callback", hasCompiledCallbackReadiness ? "Ready" : hasSetup ? "Blocked" : "N/A", hasCompiledCallbackReadiness ? .green : hasSetup ? .orange : .secondary),
          ("Sign-in", primaryAuthState?.status.rawValue ?? "Not configured", hasConnectedAuth ? .green : .orange),
          ("Fetched", "\(fetchedCount)", fetchedCount > 0 ? .blue : .secondary),
          ("Imported", "\(importedCount)", importedCount > 0 ? .green : .secondary),
          ("Filtered", "\(filteredCount)", filteredCount > 0 ? .teal : .secondary),
          ("Uncertain", "\(pendingUncertainCount)", pendingUncertainCount == 0 ? .green : .orange)
        ])

        CompactMetadataGrid(minimumWidth: 190) {
          ForEach(Array(checklistItems.enumerated()), id: \.offset) { index, item in
            GmailReadinessChecklistCard(index: index + 1, item: item)
          }
        }

        if let summary = latestSummary {
          VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
              Text(summary.displayName)
                .font(.caption.weight(.semibold))
              Spacer()
              Badge(summary.verdict, color: toneColor(summary.tone))
            }
            Text(summary.nextAction)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            Text("Latest refresh: \(summary.lastRefreshDate). \(summary.lastRefreshSummary)")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .lineLimit(3)
          }
          .padding(10)
          .background(toneColor(summary.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        if !latestReasonBreakdown.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Label("Latest Gmail classifier reasons", systemImage: "line.3.horizontal.decrease.circle.fill")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.teal)
            Text("Safe labels from the last Gmail refresh. Use these to check why messages were imported, filtered, or held for uncertain review without opening Audit.")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(latestReasonBreakdown.prefix(6))) { item in
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
          .padding(10)
          .background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        Text("Gmail remains manual and read-only. No background sync, mailbox mutation, token logging, or external classification is added by this readiness panel.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(readinessTone)
          .fixedSize(horizontal: false, vertical: true)

        CompactActionRow {
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
          NavigationLink {
            TasksView(store: store)
          } label: {
            Label("Open Tasks", systemImage: "checklist")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private func toneColor(_ tone: String) -> Color {
    switch tone {
    case "success":
      return .green
    case "warning":
      return .orange
    case "attention":
      return .teal
    default:
      return .secondary
    }
  }

  private func classifierReasonColor(_ decision: String) -> Color {
    if decision.localizedCaseInsensitiveContains("import") { return .green }
    if decision.localizedCaseInsensitiveContains("uncertain") { return .orange }
    if decision.localizedCaseInsensitiveContains("filter") { return .teal }
    return .secondary
  }

  private func hasMailboxBasics(_ connection: GmailMailboxConnection) -> Bool {
    !connection.emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !connection.monitoredLabelNames.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func hasOAuthPlaceholders(_ connection: GmailMailboxConnection) -> Bool {
    !(connection.oauthClientIDPlaceholder ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !(connection.redirectURIPlaceholder ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func hasReadOnlyScope(_ connection: GmailMailboxConnection) -> Bool {
    connection.requestedScopesSummary.localizedCaseInsensitiveContains("gmail.readonly")
      || connection.requestedScopesSummary.localizedCaseInsensitiveContains("gmail.metadata")
  }
}

private struct GmailReadinessChecklistItem {
  var title: String
  var detail: String
  var symbol: String
  var isComplete: Bool
}

private struct GmailReadinessChecklistCard: View {
  var index: Int
  var item: GmailReadinessChecklistItem

  private var tone: Color {
    item.isComplete ? .green : .orange
  }

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      ZStack {
        Circle()
          .fill(tone.opacity(0.16))
          .frame(width: 28, height: 28)
        Image(systemName: item.isComplete ? "checkmark" : item.symbol)
          .font(.caption.weight(.semibold))
          .foregroundStyle(tone)
      }

      VStack(alignment: .leading, spacing: 3) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text("\(index). \(item.title)")
            .font(.caption.weight(.semibold))
          Spacer(minLength: 4)
          Badge(item.isComplete ? "Done" : "Next", color: tone)
        }
        Text(item.detail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct IntakeParserDiagnosticRow: View {
  var diagnostic: IntakeParserDiagnostic
  var onReprocess: () -> Void
  var onCreateTask: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Label(diagnostic.title, systemImage: "text.magnifyingglass")
          .font(.subheadline.weight(.semibold))
        Spacer()
        Badge(diagnostic.severity.rawValue, color: severityColor)
      }
      Text(diagnostic.summary)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      if !diagnostic.issueLabels.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("Missing or weak fields")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
          CompactMetadataGrid(minimumWidth: 140) {
            ForEach(diagnostic.issueLabels, id: \.self) { label in
              Badge(label, color: .orange)
            }
          }
        }
      }
      if !diagnostic.parserHintLabels.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("Parser can help")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
          CompactMetadataGrid(minimumWidth: 150) {
            ForEach(diagnostic.parserHintLabels, id: \.self) { label in
              Badge(label, color: .blue)
            }
          }
        }
      }
      CompactMetadataGrid(minimumWidth: 130) {
        Badge(diagnostic.detectedMerchant, color: diagnostic.detectedMerchant.isPlaceholderValidationValue ? .secondary : .green)
        Badge(diagnostic.detectedOrderNumber, color: diagnostic.detectedOrderNumber.isPlaceholderValidationValue ? .orange : .blue)
        Badge(diagnostic.detectedTrackingNumber, color: diagnostic.detectedTrackingNumber.isPlaceholderValidationValue ? .orange : .purple)
        Badge(diagnostic.detectedDestination, color: diagnostic.detectedDestination.isPlaceholderValidationValue ? .secondary : .teal)
      }
      Text("Subject: \(diagnostic.subjectPreview)")
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text("Sender: \(diagnostic.senderPreview)")
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(diagnostic.recommendedAction)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(severityColor)
      if !diagnostic.nextStepLabels.isEmpty {
        CompactMetadataGrid(minimumWidth: 130) {
          ForEach(diagnostic.nextStepLabels, id: \.self) { label in
            Badge(label, color: severityColor)
          }
        }
      }
      CompactActionRow {
        Button("Reprocess", systemImage: "arrow.triangle.2.circlepath", action: onReprocess)
        Button("Task", systemImage: "checklist", action: onCreateTask)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(severityColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

  private var severityColor: Color {
    switch diagnostic.severity {
    case .critical:
      return .red
    case .high:
      return .orange
    case .warning:
      return .yellow
    case .info:
      return .secondary
    }
  }
}

struct SpaceMailNeedsReviewPreviewRow: View {
  var title: String
  var sender: String
  var receivedDate: String
  var bodyPreview: String
  var reason: String
  var badge: String
  var color: Color
  var onImport: () -> Void
  var onDismiss: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onTrustSender: () -> Void
  var onImportHint: () -> Void
  var onFilterHint: () -> Void

  private var displayTitle: String {
    title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No subject" : title
  }

  private var displaySender: String {
    sender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown sender" : sender
  }

  private var isFiltered: Bool {
    badge.localizedCaseInsensitiveContains("filtered")
  }

  private var recommendationTitle: String {
    isFiltered ? "Optional review: likely non-order mail" : "Review needed: possibly order-related"
  }

  private var recommendationDetail: String {
    if isFiltered {
      return "This preview stayed out of Inbox. Import only if it is a real order or order update; otherwise dismiss it or add a filter hint."
    }
    return "This preview stayed out of Inbox because the classifier was not confident. Import true order mail, or dismiss/filter it locally."
  }

  private var recommendationSymbol: String {
    isFiltered ? "line.3.horizontal.decrease.circle.fill" : "questionmark.folder.fill"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        VStack(alignment: .leading, spacing: 3) {
          Label(displayTitle, systemImage: recommendationSymbol)
            .font(.subheadline.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
          Text("\(displaySender) • \(receivedDate)")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Badge(badge, color: color)
      }

      HStack(alignment: .top, spacing: 8) {
        Image(systemName: recommendationSymbol)
          .foregroundStyle(color)
          .frame(width: 18)
        VStack(alignment: .leading, spacing: 2) {
          Text(recommendationTitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
          Text(recommendationDetail)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(8)
      .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

      Text(bodyPreview)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
      Text("Reason: \(reason)")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(color)
      CompactActionRow {
        Button("Import to Inbox", systemImage: "tray.and.arrow.down.fill", action: onImport)
        Button("Dismiss", systemImage: "xmark.circle", role: .destructive, action: onDismiss)
        Button("Task", systemImage: "checklist", action: onCreateTask)
        Button("Draft", systemImage: "envelope.open.fill", action: onCreateDraft)
      }
      ActionGroupHeader(title: "Classifier tuning", symbol: "slider.horizontal.3")
      CompactActionRow {
        Button("Trust sender", systemImage: "person.badge.shield.checkmark", action: onTrustSender)
        Button("Import hint", systemImage: "plus.circle", action: onImportHint)
        Button("Filter hint", systemImage: "line.3.horizontal.decrease.circle", action: onFilterHint)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct GmailNeedsReviewPreviewRow: View {
  var title: String
  var sender: String
  var receivedDate: String
  var bodyPreview: String
  var reason: String
  var badge: String = "Uncertain"
  var color: Color = .orange
  var recommendationTitle: String = "Review needed: possibly order-related"
  var recommendationDetail: String = "This Gmail preview stayed out of Inbox because the classifier was not confident. Import only true order mail; dismiss local false positives."
  var symbol: String = "questionmark.folder.fill"
  var onImport: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void = {}
  var onDismiss: () -> Void
  var onTrustSender: () -> Void = {}
  var onImportHint: () -> Void = {}
  var onFilterHint: () -> Void = {}

  private var displayTitle: String {
    title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No subject" : title
  }

  private var displaySender: String {
    sender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown sender" : sender
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        VStack(alignment: .leading, spacing: 3) {
          Label(displayTitle, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
          Text("\(displaySender) • \(receivedDate)")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Badge(badge, color: color)
      }

      HStack(alignment: .top, spacing: 8) {
        Image(systemName: symbol)
          .foregroundStyle(color)
          .frame(width: 18)
        VStack(alignment: .leading, spacing: 2) {
          Text(recommendationTitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
          Text(recommendationDetail)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(8)
      .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

      Text(bodyPreview)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
      Text("Reason: \(reason)")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(color)
      CompactActionRow {
        Button("Import to Inbox", systemImage: "tray.and.arrow.down.fill", action: onImport)
        Button("Task", systemImage: "checklist", action: onCreateTask)
        Button("Draft", systemImage: "envelope.open.fill", action: onCreateDraft)
        Button("Dismiss", systemImage: "xmark.circle", role: .destructive, action: onDismiss)
      }
      ActionGroupHeader(title: "Classifier tuning", symbol: "slider.horizontal.3")
      CompactActionRow {
        Button("Trust sender", systemImage: "person.badge.shield.checkmark", action: onTrustSender)
        Button("Import hint", systemImage: "plus.circle", action: onImportHint)
        Button("Filter hint", systemImage: "line.3.horizontal.decrease.circle", action: onFilterHint)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct IntakeEmailRow: View {
  var email: ForwardedEmailIntake
  var store: ParcelOpsStore
  var orders: [TrackedOrder]
  var evidenceAttachments: [EvidenceAttachment]
  var suggestedContacts: [ContactDirectoryEntry] = []
  var suggestedAccounts: [AccountCredentialRecord] = []
  var suggestedProfiles: [VendorProfile] = []
  var customerProfiles: [CustomerRecipientProfile] = []
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var shipmentGroups: [ShipmentGroup] = []
  var onSave: (ForwardedEmailIntake) -> Void
  var onLinkOrder: (TrackedOrder) -> Void
  var onCreateOrder: () -> Void
  var onReviewed: () -> Void
  var onIgnore: () -> Void
  var onReprocess: () -> Void = {}
  var onAddEvidence: () -> Void
  var onReviewEvidence: (EvidenceAttachment) -> Void
  var onRemoveEvidence: (EvidenceAttachment) -> Void
  var onCreateTask: () -> Void = {}
  var onCreateDraft: () -> Void = {}
  var onDraftFromContact: (ContactDirectoryEntry) -> Void = { _ in }
  var onCreateAccount: () -> Void = {}
  var onTaskFromAccount: (AccountCredentialRecord) -> Void = { _ in }
  var onDraftFromAccount: (AccountCredentialRecord) -> Void = { _ in }
  var onCreateProfile: () -> Void = {}
  var onTaskFromProfile: (VendorProfile) -> Void = { _ in }
  var onDraftFromProfile: (VendorProfile) -> Void = { _ in }
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var isEditing = false
  @State private var feedbackMessage: String?

  private var linkedOrder: TrackedOrder? {
    orders.first { $0.id == email.linkedOrderID }
  }

  private var missingDetectedFields: [String] {
    [
      email.detectedMerchant.isPlaceholderValidationValue ? "merchant" : nil,
      email.detectedOrderNumber.isPlaceholderValidationValue ? "order number" : nil,
      email.detectedTrackingNumber.isPlaceholderValidationValue ? "tracking number" : nil,
      email.detectedDestinationAddress.isPlaceholderValidationValue ? "destination" : nil
    ].compactMap { $0 }
  }

  private var hasCriticalMissingFields: Bool {
    email.detectedOrderNumber.isPlaceholderValidationValue || email.detectedTrackingNumber.isPlaceholderValidationValue
  }

  private var recommendedActionTitle: String {
    if email.reviewState == .ignored { return "Ignored locally" }
    if let linkedOrder { return "Linked to \(linkedOrder.orderNumber)" }
    if hasCriticalMissingFields { return "Fix parser fields before creating an order" }
    if !missingDetectedFields.isEmpty { return "Check remaining fields, then create or link" }
    return "Ready to create or link order"
  }

  private var recommendedActionDetail: String {
    if email.reviewState == .ignored {
      return "This row is hidden from the default queue unless resolved rows are shown. Reprocess or edit only if it was ignored by mistake."
    }
    if linkedOrder != nil {
      return "Open the linked order to continue dispatch setup or mark the intake email reviewed once the source trail looks right."
    }
    if hasCriticalMissingFields {
      return "Missing or weak \(missingDetectedFields.joined(separator: ", ")). Use Reprocess or Edit first. Create order remains available for manual fallback."
    }
    if !missingDetectedFields.isEmpty {
      return "Detected order and tracking look usable, but \(missingDetectedFields.joined(separator: ", ")) still needs a human check."
    }
    return "Detected merchant, order, tracking, and destination look usable. Create a new local order or link an existing one."
  }

  private var recommendedActionColor: Color {
    if email.reviewState == .ignored { return .secondary }
    if linkedOrder != nil { return .green }
    if hasCriticalMissingFields { return .orange }
    if !missingDetectedFields.isEmpty { return .yellow }
    return .green
  }

  private var factColumns: [GridItem] {
    Array(repeating: GridItem(.flexible()), count: horizontalSizeClass == .compact ? 1 : 2)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "envelope.open.fill")
          .foregroundStyle(email.reviewState.color)
          .frame(width: 28, height: 28)
        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(email.subject)
                .font(.headline)
              Text("\(email.sender) • \(email.receivedDate)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(email.reviewState.rawValue, color: email.reviewState.color)
          }
          Text(email.rawBodyPreview)
            .foregroundStyle(.secondary)
            .lineLimit(3)
          IntakeSourceContextPanel(
            email: email,
            store: store,
            manualDetail: "No mailbox ingest record is linked to this intake row. Treat it as local/manual until a source record is linked.",
            linkedDetailSuffix: "Duplicate-safe source metadata is linked; provider message IDs stay in Audit/details rather than the primary operator row."
          )
          LazyVGrid(columns: factColumns, alignment: .leading, spacing: 8) {
            IntakeFact(title: "Merchant", value: email.detectedMerchant, symbol: "storefront.fill")
            IntakeFact(title: "Order", value: email.detectedOrderNumber, symbol: "number")
            IntakeFact(title: "Tracking", value: email.detectedTrackingNumber, symbol: "barcode.viewfinder")
            IntakeFact(title: "Destination", value: email.detectedDestinationAddress, symbol: "mappin.and.ellipse")
          }
          IntakeReadinessStrip(email: email, hasLinkedOrder: linkedOrder != nil)
          LinkedOrderContextPanel(
            order: linkedOrder,
            sourceLabel: "Mailbox intake",
            emptyDetail: "No order is linked yet. Link to an existing order when this message matches known work, or create a new local order when it is genuinely new.",
            linkedDetail: "This forwarded email already has linked order context. Open the order before marking the intake reviewed if tracking, destination, or dispatch setup still needs confirmation.",
            store: store
          )
          intakeRecommendedActionPanel
          if !shipmentGroups.isEmpty {
            ShipmentGroupContextStrip(groups: shipmentGroups)
          }
        }
      }

      if hasCriticalMissingFields && linkedOrder == nil && email.reviewState != .ignored {
        CompactActionRow {
          Button("Reprocess first", systemImage: "arrow.triangle.2.circlepath", action: onReprocess)
            .buttonStyle(.borderedProminent)
          Button("Edit detected fields", systemImage: "pencil", action: { isEditing = true })
            .buttonStyle(.bordered)
          Button("Create task", systemImage: "checklist", action: onCreateTask)
            .buttonStyle(.bordered)
        }
      }

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)

        Menu {
          ForEach(orders) { order in
            Button("\(order.orderNumber) • \(order.store)") {
              onLinkOrder(order)
              feedbackMessage = "Intake linked to \(order.orderNumber). Check Orders."
            }
          }
        } label: {
          Label("Link order", systemImage: "link")
        }
        .buttonStyle(.bordered)

        if hasCriticalMissingFields {
          Button("Create partial order", systemImage: "plus.circle.fill") {
            onCreateOrder()
            feedbackMessage = "Partial order created and linked locally. Check Orders."
          }
            .buttonStyle(.bordered)
        } else {
          Button("Create order", systemImage: "plus.circle.fill") {
            onCreateOrder()
            feedbackMessage = "Order created and linked locally. Check Orders."
          }
            .buttonStyle(.borderedProminent)
        }
        Button("Mark reviewed", systemImage: "checkmark.circle.fill") {
          onReviewed()
          feedbackMessage = "Intake marked reviewed locally."
        }
          .buttonStyle(.bordered)
        Button("Ignore", systemImage: "trash") {
          onIgnore()
          feedbackMessage = "Intake ignored locally."
        }
          .buttonStyle(.bordered)
        Button("Reprocess", systemImage: "arrow.triangle.2.circlepath") {
          onReprocess()
          feedbackMessage = "Intake reprocessed from stored preview."
        }
          .buttonStyle(.bordered)
        Button("Create task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Follow-up task created. Check Tasks."
        }
          .buttonStyle(.bordered)
        Button("Create draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Draft message created locally."
        }
          .buttonStyle(.bordered)
      }

      if let feedbackMessage {
        VStack(alignment: .leading, spacing: 8) {
          Label(feedbackMessage, systemImage: "checkmark.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)

          if feedbackMessage.localizedCaseInsensitiveContains("order") {
            NavigationLink {
              OrdersView(store: store)
            } label: {
              Label("Open Orders", systemImage: "shippingbox.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
          }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.green.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Label("Evidence", systemImage: "paperclip")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Spacer()
          Button("Add evidence", systemImage: "plus", action: onAddEvidence)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }

        if evidenceAttachments.isEmpty {
          Text("No evidence linked.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          ForEach(evidenceAttachments) { attachment in
            EvidenceAttachmentRow(attachment: attachment) {
              onReviewEvidence(attachment)
            } onRemove: {
              onRemoveEvidence(attachment)
            } onCreateDraft: {
              onCreateDraft()
            }
          }
        }
      }

      if !suggestedContacts.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Label("Suggested contacts", systemImage: "person.crop.circle.badge.checkmark")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          ForEach(suggestedContacts) { contact in
            ContactSuggestionRow(contact: contact) {
              onDraftFromContact(contact)
            }
          }
        }
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Label("Suggested accounts", systemImage: "key.horizontal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Spacer()
          Button("Add account", systemImage: "key.badge.plus", action: onCreateAccount)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }

        if suggestedAccounts.isEmpty {
          Text("No local accounts matched.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          ForEach(suggestedAccounts) { account in
            AccountSuggestionRow(account: account) {
              onTaskFromAccount(account)
            } onCreateDraft: {
              onDraftFromAccount(account)
            }
          }
        }
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Label("Suggested profiles", systemImage: "building.2.crop.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Spacer()
          Button("Add profile", systemImage: "building.2.crop.circle", action: onCreateProfile)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }

        if suggestedProfiles.isEmpty {
          Text("No local vendor profiles matched.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          ForEach(suggestedProfiles) { profile in
            VendorProfileSuggestionRow(profile: profile) {
              onTaskFromProfile(profile)
            } onCreateDraft: {
              onDraftFromProfile(profile)
            }
          }
        }
      }

      if !customerProfiles.isEmpty {
        CustomerProfileStrip(profiles: customerProfiles)
      }
      if !destinationAddresses.isEmpty {
        DestinationAddressStrip(addresses: destinationAddresses)
      }
      if !deliveryInstructions.isEmpty {
        DeliveryInstructionStrip(instructions: deliveryInstructions)
      }
      if !packageContents.isEmpty {
        PackageContentStrip(contents: packageContents)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      IntakeEmailEditView(email: email) { updatedEmail in
        onSave(updatedEmail)
      }
    }
  }

  private var intakeRecommendedActionPanel: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label(recommendedActionTitle, systemImage: linkedOrder == nil ? "arrow.forward.circle.fill" : "link.circle.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(recommendedActionColor)
        Spacer()
        if !missingDetectedFields.isEmpty {
          Badge("\(missingDetectedFields.count) checks", color: recommendedActionColor)
        }
      }
      Text(recommendedActionDetail)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(recommendedActionColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }

}

struct IntakeEmailEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: ForwardedEmailIntake
  var onSave: (ForwardedEmailIntake) -> Void

  init(email: ForwardedEmailIntake, onSave: @escaping (ForwardedEmailIntake) -> Void) {
    self._draft = State(initialValue: email)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Email") {
          TextField("Sender", text: $draft.sender)
          TextField("Subject", text: $draft.subject)
          TextField("Received", text: $draft.receivedDate)
          TextField("Body preview", text: $draft.rawBodyPreview, axis: .vertical)
            .lineLimit(3...6)
        }

        Section("Detected order details") {
          TextField("Merchant", text: $draft.detectedMerchant)
          TextField("Order number", text: $draft.detectedOrderNumber)
          TextField("Tracking number", text: $draft.detectedTrackingNumber)
          TextField("Destination address", text: $draft.detectedDestinationAddress, axis: .vertical)
            .lineLimit(2...4)
          Picker("Review state", selection: $draft.reviewState) {
            Text(IntakeEmailReviewState.needsReview.rawValue).tag(IntakeEmailReviewState.needsReview)
            Text(IntakeEmailReviewState.reviewed.rawValue).tag(IntakeEmailReviewState.reviewed)
            Text(IntakeEmailReviewState.ignored.rawValue).tag(IntakeEmailReviewState.ignored)
          }
        }
      }
      .navigationTitle("Edit intake email")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            onSave(draft)
            dismiss()
          }
        }
      }
      #if os(macOS)
      .frame(minWidth: 520, minHeight: 520)
      #endif
    }
  }
}

struct IntakeFact: View {
  var title: String
  var value: String
  var symbol: String

  var body: some View {
    HStack(alignment: .top, spacing: 6) {
      Image(systemName: symbol)
        .foregroundStyle(.teal)
        .frame(width: 18)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption2)
          .foregroundStyle(.secondary)
        Text(value)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
      }
    }
  }
}

struct MailEventRow: View {
  var event: MailEvent

  var body: some View {
    HStack(alignment: .top) {
      Image(systemName: "envelope.badge.fill")
        .foregroundStyle(event.severity.color)
        .frame(width: 30, height: 30)
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(event.sender)
            .font(.headline)
          Badge(event.severity.rawValue, color: event.severity.color)
          Badge(event.reviewState.rawValue, color: event.reviewState.color)
          Spacer()
          Text(event.receivedTime)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Text(event.summary)
          .foregroundStyle(.secondary)
        Text("Matched order: \(event.matchedOrder)")
          .font(.caption.weight(.semibold))
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct NeedsReviewView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var showAdvancedBacklog = false
  @State private var reviewSearchText = ""

  private var normalizedReviewSearch: String {
    reviewSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  private func matchesReviewSection(_ terms: String...) -> Bool {
    let query = normalizedReviewSearch
    guard !query.isEmpty else { return true }
    return terms.joined(separator: " ").lowercased().contains(query)
  }

  private var showsInboxOrderHandoff: Bool { matchesReviewSection("inbox", "created", "order", "handoff", "import queue", "acceptance") }
  private var showsDraftMessageFollowUp: Bool { matchesReviewSection("draft", "message", "communication", "follow-up", "outbound") }
  private var showsOperationsWorkbench: Bool { matchesReviewSection("operations", "workbench", "exceptions", "blocked", "priority") }
  private var showsTimelineWatchlist: Bool { matchesReviewSection("timeline", "watchlist", "activity", "history") }
  private var showsValidationIssues: Bool { matchesReviewSection("validation", "issues", "missing", "invalid") }
  private var showsReconciliation: Bool { matchesReviewSection("reconciliation", "mismatch", "difference", "duplicate") }
  private var showsShipmentGroups: Bool { matchesReviewSection("shipment", "groups", "risk", "group") }
  private var showsAcceptanceReview: Bool { matchesReviewSection("acceptance", "review", "candidate", "blocked", "reopened") }
  private var showsImportQueue: Bool { matchesReviewSection("import", "queue", "blocked", "low confidence", "staged") }
  private var showsOrderMatches: Bool { matchesReviewSection("order", "matches", "orders", "tracking") }
  private var showsMailboxEvents: Bool { matchesReviewSection("mailbox", "events", "mail", "email") }
  private var showsParserChecks: Bool { matchesReviewSection("parser", "intake", "diagnostics", "merchant", "tracking", "order number") }
  private var showsParserChecksInPrimary: Bool { !normalizedReviewSearch.isEmpty && showsParserChecks }
  private var showsMixedMailboxReview: Bool { matchesReviewSection("spacemail", "gmail", "mixed", "mailbox", "uncertain", "filtered") }
  private var showsForwardedEmails: Bool { matchesReviewSection("forwarded", "emails", "intake", "mailbox", "order") }
  private var showsEvidence: Bool { matchesReviewSection("evidence", "attachments", "paperclip") }
  private var showsTrackingEvents: Bool { matchesReviewSection("tracking", "carrier", "events", "shipment") }
  private var showsTaskEscalations: Bool { matchesReviewSection("task", "escalations", "review tasks", "follow-up") }
  private var showsHandoffNotes: Bool { matchesReviewSection("handoff", "notes", "shift", "assigned") }
  private var showsMailboxProviderHandoff: Bool { matchesReviewSection("mailbox", "provider", "handoff", "release", "gate", "spacemail", "gmail") }
  private var gmailReleaseSelfChecks: [GmailReleaseSelfCheckSummary] {
    store.gmailMailboxConnections.map { store.gmailReleaseSelfCheckSummary(for: $0) }
  }
  private var gmailReleaseBlockingCount: Int {
    gmailReleaseSelfChecks.reduce(0) { total, summary in
      total + summary.items.filter { !$0.isComplete && $0.tone == "warning" }.count
    }
  }
  private var gmailReleaseAttentionCount: Int {
    gmailReleaseSelfChecks.reduce(0) { total, summary in
      total + summary.items.filter { !$0.isComplete && $0.tone == "attention" }.count
    }
  }
  private var gmailReleaseNeedsReview: Bool {
    gmailReleaseBlockingCount > 0 || gmailReleaseAttentionCount > 0
  }
  private var mailboxProviderTroubleshootingNeedsReview: Bool {
    let tone = store.mailboxProviderTroubleshootingSummary.tone
    return tone == "warning" || tone == "attention"
  }
  private var mailboxProviderNeedsReview: Bool {
    store.mailboxProviderReleaseGateSummary.tone != "success"
      || store.mailboxProviderHandoffPacketSummary.tone != "success"
      || mailboxProviderTroubleshootingNeedsReview
      || gmailReleaseNeedsReview
  }

  private var visiblePrimaryReviewSectionCount: Int {
    [
      mailboxProviderNeedsReview && showsMailboxProviderHandoff,
      showsInboxOrderHandoff,
      showsDraftMessageFollowUp,
      showsOperationsWorkbench,
      showsTimelineWatchlist,
      showsValidationIssues,
      showsReconciliation,
      showsShipmentGroups,
      showsAcceptanceReview,
      showsImportQueue,
      showsOrderMatches,
      showsMailboxEvents,
      showsParserChecksInPrimary,
      showsMixedMailboxReview,
      showsForwardedEmails,
      showsEvidence,
      showsTrackingEvents,
      showsTaskEscalations,
      showsHandoffNotes
    ].filter(\.self).count
  }

  private var inboxCreatedOrders: [TrackedOrder] {
    Array(
      store.orders
        .filter { $0.isInboxCreatedLocalOrder && $0.reviewState != .accepted }
        .prefix(8)
    )
  }

  private var operatorWorkbenchItems: [WorkbenchItem] {
    store.openWorkbenchItems.filter { $0.source != .intakeParser }
  }

  private var highPriorityOperatorWorkbenchItems: [WorkbenchItem] {
    operatorWorkbenchItems.filter { $0.rank >= 3 }
  }

  private var dailyAttentionCount: Int {
    inboxCreatedOrders.count
      + highPriorityOperatorWorkbenchItems.count
      + store.highSeverityValidationIssues.count
      + store.highSeverityReconciliationIssues.count
      + store.shipmentGroupsNeedingReview.count
      + store.highRiskShipmentGroups.count
      + store.acceptanceRecordsNeedingReview.count
      + store.importQueueItemsNeedingReview.count
      + store.blockedImportQueueItems.count
      + store.reviewOrders.count
      + store.reviewMailEvents.count
      + store.pendingSpaceMailUncertainReviewCount
      + store.gmailMailboxConnections.reduce(0) { $0 + ($1.uncertainMessages?.count ?? 0) }
      + store.reviewIntakeEmails.count
      + store.reviewEvidenceAttachments.count
      + store.reviewCarrierTrackingEvents.count
      + store.reviewTasksNeedingAttention.count
      + store.handoffNotesNeedingAttention.count
      + store.draftMessagesNeedingReview.count
      + store.blockedShipmentManifests.count
      + store.blockedDispatchChecklists.count
      + (mailboxProviderNeedsReview ? 1 : 0)
      + gmailReleaseBlockingCount
      + gmailReleaseAttentionCount
  }

  private var advancedBacklogCount: Int {
    max(store.reviewQueueCount - dailyAttentionCount, 0)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Needs review")
              .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
            Text("Daily operator review starts with Inbox, Orders, Workbench, Dispatch, and Tasks. Advanced record checks are grouped separately.")
              .foregroundStyle(.secondary)
          }
          Spacer()
          Badge("\(store.reviewQueueCount)", color: .orange)
        }

        OperatorDailyWorkloadSummary(
          dailyAttentionCount: dailyAttentionCount,
          advancedBacklogCount: advancedBacklogCount,
          reviewQueueCount: store.reviewQueueCount,
          titleWhenClear: "Primary review flow is clear",
          titleWhenBusy: "Primary review flow needs attention",
          detailWhenClear: "There is no immediate Inbox, Orders, Workbench, Dispatch, or Tasks review work. Advanced record checks remain available below.",
          detailWhenBusy: "Work through the primary review sections first. The advanced backlog is collapsed so it does not dominate daily triage."
        )

        ActiveOperatorQueueFocusCard(store: store)

        SettingsPanel(title: "Find review work", symbol: "magnifyingglass") {
          VStack(alignment: .leading, spacing: 10) {
            FilterControlGrid {
              TextField("Search review areas: Inbox, Workbench, validation, tracking, tasks, handoff", text: $reviewSearchText)
                .textFieldStyle(.roundedBorder)

              Button("Clear", systemImage: "xmark.circle") {
                reviewSearchText = ""
              }
              .buttonStyle(.bordered)
              .disabled(normalizedReviewSearch.isEmpty)

              Badge("\(visiblePrimaryReviewSectionCount) sections", color: visiblePrimaryReviewSectionCount == 0 ? .orange : .blue)
            }

            Text("This narrows the primary Needs Review sections only. Advanced backlog records remain under the disclosure below.")
              .font(.caption)
              .foregroundStyle(.secondary)
            if !store.intakeParserDiagnostics.isEmpty && normalizedReviewSearch.isEmpty {
              Label("\(store.intakeParserDiagnostics.count) parser diagnostics are hidden from the default Needs Review flow. Search parser when investigating intake detection issues.", systemImage: "text.magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }

        if visiblePrimaryReviewSectionCount == 0 {
          MVPEmptyState(title: "No review sections match", detail: "Clear the review search or try Inbox, Workbench, validation, tracking, tasks, handoff, SpaceMail, Gmail, import, acceptance, evidence, or dispatch.", symbol: "magnifyingglass")
        }

        NeedsReviewSectionHeader(
          title: "Primary daily review",
          detail: "Use these sections for intake, order handoff, dispatch blockers, task follow-up, and the highest-priority operational exceptions.",
          count: dailyAttentionCount,
          symbol: "tray.full.fill",
          color: dailyAttentionCount == 0 ? .green : .orange
        )

        if showsMailboxProviderHandoff && mailboxProviderNeedsReview {
          SettingsPanel(title: "Mailbox provider release and handoff", symbol: "checkmark.seal.fill") {
            VStack(alignment: .leading, spacing: 12) {
              Text("Use this before treating a mailbox provider as a clean daily intake path. It summarizes provider release gates, handoff readiness, and follow-up actions without running mailbox refresh or changing credentials.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

              MailboxProviderReleaseGateCard(summary: store.mailboxProviderReleaseGateSummary, store: store)
              MailboxProviderHandoffPacketCard(packet: store.mailboxProviderHandoffPacketSummary, store: store)
              MailboxProviderTroubleshootingCard(summary: store.mailboxProviderTroubleshootingSummary, store: store)
              GmailReleaseBoundaryPanel(
                store: store,
                title: "Gmail Needs Review boundary",
                lead: "These are provider-readiness checks, not Inbox or Dispatch records. Create a task only when a missing Gmail setup, sign-in, labels, classifier review, Inbox handoff, or audit evidence item needs an owner.",
                sourceMetricTitle: "Needs Review signals",
                sourceCount: gmailReleaseBlockingCount + gmailReleaseAttentionCount,
                boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store token values, create Needs Review records automatically, or mutate mailbox messages."
              )
            }
          }
        }

        if showsInboxOrderHandoff && !inboxCreatedOrders.isEmpty {
          SettingsPanel(title: "Inbox-created order handoff", symbol: "tray.and.arrow.down.fill") {
            Text("Orders created from Inbox, Import Queue, or Acceptance Review stay in Needs Review until tracking, destination, ownership, and dispatch setup are confirmed.")
              .font(.callout)
              .foregroundStyle(.secondary)
            ForEach(inboxCreatedOrders) { order in
              NeedsReviewInboxOrderRow(order: order, store: store)
            }
          }
        }

        if showsDraftMessageFollowUp && !store.draftMessagesNeedingReview.isEmpty {
          SettingsPanel(title: "Draft message follow-up", symbol: "envelope.open.fill") {
            Text("Drafts created from Inbox, Orders, Tasks, Workbench, and Dispatch stay in primary review until they are ready, sent locally, or reopened for editing. ParcelOps does not send outbound email.")
              .font(.callout)
              .foregroundStyle(.secondary)
            ForEach(store.draftMessagesNeedingReview.prefix(8)) { draft in
              DraftMessageRow(
                draft: draft,
                store: store,
                linkedOrder: linkedOrder(for: draft),
                destinationAddresses: store.suggestedDestinationAddresses(for: draft),
                deliveryInstructions: store.suggestedDeliveryInstructions(for: draft),
                packageContents: store.suggestedPackageContents(for: draft)
              ) { updatedDraft in
                store.updateDraftMessage(updatedDraft)
              } onReady: {
                store.markDraftMessageReady(draft)
              } onSent: {
                store.markDraftMessageSentLocally(draft)
              } onReopen: {
                store.reopenDraftMessage(draft)
              } onCreateContact: {
                store.addContactDirectoryEntry(linkedEntityType: .draftMessage, linkedEntityID: draft.id.uuidString, label: draft.recipient)
              } onRemove: {
                store.removeDraftMessage(draft)
              }
            }
          }
        }

        if showsOperationsWorkbench {
          SettingsPanel(title: "Operations Workbench", symbol: "rectangle.stack.badge.person.crop.fill") {
            if highPriorityOperatorWorkbenchItems.isEmpty {
              MVPEmptyState(title: "No urgent workbench review", detail: "Blocked intake, exception, validation, reconciliation, and high-risk operational items will appear here.", symbol: "rectangle.stack.badge.person.crop.fill")
            } else {
              ForEach(Array(highPriorityOperatorWorkbenchItems.prefix(8))) { item in
                WorkbenchItemRow(item: item, customerProfiles: store.suggestedCustomerProfiles(for: item), destinationAddresses: store.suggestedDestinationAddresses(for: item), deliveryInstructions: store.suggestedDeliveryInstructions(for: item), packageContents: store.suggestedPackageContents(for: item), receivingInspections: store.suggestedReceivingInspections(for: item), inventoryReceipts: store.suggestedInventoryReceipts(for: item), storageLocations: store.suggestedStorageLocations(for: item), custodyRecords: store.suggestedCustodyRecords(for: item), labelReferences: store.suggestedLabelReferenceRecords(for: item), scanSessions: store.suggestedScanSessionRecords(for: item), shipmentManifests: store.suggestedShipmentManifestRecords(for: item), dispatchChecklists: store.suggestedDispatchReadinessChecklists(for: item)) {
                  store.createReviewTask(from: item)
                } onCreateDraft: {
                  store.createDraftMessage(from: item)
                } onReviewed: {
                  store.markWorkbenchItemReviewed(item)
                }
              }
            }
          }
        }

        if showsTimelineWatchlist {
          SettingsPanel(title: "Timeline watchlist", symbol: "clock.badge.exclamationmark.fill") {
            if store.timelineWatchlist.isEmpty {
              MVPEmptyState(title: "No timeline watchlist items", detail: "Critical local activity and watchlist events will appear here when they need operator review.", symbol: "clock.badge.exclamationmark.fill")
            } else {
              ForEach(Array(store.timelineWatchlist.prefix(8))) { activity in
                TimelineActivityRow(activity: activity, store: store, linkedOrder: linkedOrder(for: activity), shipmentGroups: store.suggestedShipmentGroups(for: activity), importQueueItems: store.importQueueItems(for: activity), acceptanceRecords: store.acceptanceRecords(for: activity)) {
                  store.createReviewTask(from: activity)
                } onCreateDraft: {
                  store.createDraftMessage(from: activity)
                }
              }
            }
          }
        }

        if showsValidationIssues {
          SettingsPanel(title: "Validation issues", symbol: "checkmark.seal.fill") {
            if store.highSeverityValidationIssues.isEmpty {
              MVPEmptyState(title: "No high-severity validation issues", detail: "Missing links, invalid fields, and blocked validation records will appear here when they affect daily work.", symbol: "checkmark.seal.fill")
            } else {
              ForEach(Array(store.highSeverityValidationIssues.prefix(8))) { issue in
                ValidationIssueRow(issue: issue, store: store, linkedOrder: linkedOrder(for: issue), shipmentGroups: store.suggestedShipmentGroups(for: issue), importQueueItems: store.importQueueItems(for: issue), acceptanceRecords: store.acceptanceRecords(for: issue), playbooks: store.suggestedPlaybooks(for: issue), handoffNotes: store.handoffNotes(for: issue), customerProfiles: store.suggestedCustomerProfiles(for: issue), destinationAddresses: store.suggestedDestinationAddresses(for: issue), deliveryInstructions: store.suggestedDeliveryInstructions(for: issue), packageContents: store.suggestedPackageContents(for: issue)) {
                  store.createReviewTask(from: issue)
                } onCreateDraft: {
                  store.createDraftMessage(from: issue)
                }
              }
            }
          }
        }

        if showsReconciliation {
          SettingsPanel(title: "Reconciliation", symbol: "arrow.triangle.2.circlepath.circle.fill") {
            if store.highSeverityReconciliationIssues.isEmpty {
              MVPEmptyState(title: "No high-severity reconciliation issues", detail: "Duplicate, mismatch, and blocked reconciliation problems will appear here when they need operator action.", symbol: "arrow.triangle.2.circlepath.circle.fill")
            } else {
              ForEach(Array(store.highSeverityReconciliationIssues.prefix(8))) { issue in
                ReconciliationIssueRow(
                  issue: issue,
                  store: store,
                  linkedOrder: linkedOrder(for: issue),
                  shipmentGroups: store.suggestedShipmentGroups(for: issue),
                  importQueueItems: store.importQueueItems(for: issue),
                  acceptanceRecords: store.acceptanceRecords(for: issue),
                  validationIssues: store.relatedValidationIssues(for: issue),
                  playbooks: store.suggestedPlaybooks(for: issue),
                  handoffNotes: store.handoffNotes(for: issue),
                  customerProfiles: store.suggestedCustomerProfiles(for: issue),
                  destinationAddresses: store.suggestedDestinationAddresses(for: issue),
                  deliveryInstructions: store.suggestedDeliveryInstructions(for: issue),
                  packageContents: store.suggestedPackageContents(for: issue)
                ) {
                  store.markReconciliationIssueReviewed(issue)
                } onCreateTask: {
                  store.createReviewTask(from: issue)
                } onCreateDraft: {
                  store.createDraftMessage(from: issue)
                }
              }
            }
          }
        }

        if showsShipmentGroups {
          SettingsPanel(title: "Shipment groups", symbol: "shippingbox.and.arrow.backward.fill") {
            let groups = Array(Set(store.shipmentGroupsNeedingReview + store.highRiskShipmentGroups)).sorted { lhs, rhs in
              lhs.riskLevel.riskRank > rhs.riskLevel.riskRank
            }
            if groups.isEmpty {
              MVPEmptyState(title: "No shipment groups need review", detail: "High-risk or review-needed shipment groups will appear here when they affect the daily queue.", symbol: "shippingbox.and.arrow.backward.fill")
            } else {
              ForEach(groups) { group in
                ShipmentGroupRow(group: group, importQueueItems: store.importQueueItems(for: group), acceptanceRecords: store.acceptanceRecords(for: group), playbooks: store.suggestedPlaybooks(for: group), handoffNotes: store.handoffNotes(for: group), customerProfiles: store.suggestedCustomerProfiles(for: group), destinationAddresses: store.suggestedDestinationAddresses(for: group), deliveryInstructions: store.suggestedDeliveryInstructions(for: group), packageContents: store.suggestedPackageContents(for: group)) { updatedGroup in
                  store.updateShipmentGroup(updatedGroup)
                } onReviewed: {
                  store.markShipmentGroupReviewed(group)
                } onCreateTask: {
                  store.createReviewTask(from: group)
                } onCreateDraft: {
                  store.createDraftMessage(from: group)
                } onRemove: {
                  store.removeShipmentGroup(group)
                }
              }
            }
          }
        }

        if showsAcceptanceReview {
          SettingsPanel(title: "Acceptance review", symbol: "checkmark.rectangle.stack.fill") {
            let candidates = Array(store.acceptanceCandidates.filter { candidate in
              candidate.reviewState == .needsReview || candidate.decision == .blocked || candidate.decision == .reopened
            }.prefix(8))
            if candidates.isEmpty {
              MVPEmptyState(title: "No acceptance records need review", detail: "Blocked, reopened, or review-needed acceptance candidates will appear here.", symbol: "checkmark.rectangle.stack.fill")
            } else {
              ForEach(candidates) { candidate in
                AcceptanceCandidateRow(
                  candidate: candidate,
                  store: store,
                  orders: store.orders,
                  shipmentGroups: store.shipmentGroups,
                  linkedOrderLabel: candidate.suggestedLinkedOrderID.flatMap { store.orderLabel(for: $0) },
                  linkedShipmentGroupLabel: candidate.suggestedShipmentGroupID.flatMap { store.shipmentGroupLabel(for: $0) },
                  history: store.acceptanceHistory(sourceType: candidate.sourceType, sourceID: candidate.sourceID),
                  playbooks: store.suggestedPlaybooks(for: candidate),
                  handoffNotes: store.handoffNotes(for: candidate),
                  customerProfiles: store.suggestedCustomerProfiles(for: candidate),
                  destinationAddresses: store.suggestedDestinationAddresses(for: candidate),
                  deliveryInstructions: store.suggestedDeliveryInstructions(for: candidate),
                  packageContents: store.suggestedPackageContents(for: candidate),
                  onLinkOrder: { order in store.linkAcceptanceCandidate(candidate, to: order) },
                  onLinkShipmentGroup: { group in store.linkAcceptanceCandidate(candidate, to: group) },
                  onCreateOrder: { store.createOrder(from: candidate) },
                  onCreateShipmentGroup: { store.createShipmentGroup(from: candidate) },
                  onAccept: { store.acceptCandidate(candidate) },
                  onIgnore: { store.ignoreCandidate(candidate) },
                  onReopen: { store.reopenCandidate(candidate) },
                  onTask: { store.createReviewTask(from: candidate) },
                  onDraft: { store.createDraftMessage(from: candidate) }
                )
              }
            }
          }
        }

        if showsImportQueue {
          SettingsPanel(title: "Import queue", symbol: "tray.and.arrow.down.fill") {
            let importItems = Array(Set(store.blockedImportQueueItems + store.lowConfidenceImportQueueItems + store.importQueueItemsNeedingReview)).prefix(8)
            if importItems.isEmpty {
              MVPEmptyState(title: "No import queue items need review", detail: "Blocked, low-confidence, or review-needed staged imports will appear here.", symbol: "tray.and.arrow.down.fill")
            } else {
              ForEach(Array(importItems)) { item in
                ImportQueueItemRow(
                  item: item,
                  store: store,
                  orders: store.orders,
                  shipmentGroups: store.shipmentGroups,
                  playbooks: store.suggestedPlaybooks(for: item),
                  handoffNotes: store.handoffNotes(for: item),
                  customerProfiles: store.suggestedCustomerProfiles(for: item),
                  destinationAddresses: store.suggestedDestinationAddresses(for: item),
                  deliveryInstructions: store.suggestedDeliveryInstructions(for: item),
                  packageContents: store.suggestedPackageContents(for: item),
                  onSave: store.updateImportQueueItem,
                  onLinkOrder: { order in store.linkImportQueueItem(item, to: order) },
                  onLinkShipmentGroup: { group in store.linkImportQueueItem(item, to: group) },
                  onCreateOrder: { store.createOrder(from: item) },
                  onCreateShipmentGroup: { store.createShipmentGroup(from: item) },
                  onAccepted: { store.markImportQueueItemAccepted(item) },
                  onIgnored: { store.ignoreImportQueueItem(item) },
                  onReopen: { store.reopenImportQueueItem(item) },
                  onRemove: { store.removeImportQueueItem(item) },
                  onCreateTask: { store.createReviewTask(from: item) },
                  onCreateDraft: { store.createDraftMessage(from: item) }
                )
              }
            }
          }
        }

        if showsOrderMatches {
          SettingsPanel(title: "Order matches", symbol: "shippingbox.fill") {
            if store.reviewOrders.isEmpty {
              MVPEmptyState(title: "No orders need review", detail: "Review-needed orders, exceptions, and tracking issue matches will appear here.", symbol: "shippingbox.fill")
            } else {
              ForEach(store.reviewOrders) { order in
                ReviewOrderRow(order: order) { updatedOrder in
                  store.updateOrder(updatedOrder)
                } onClear: {
                  store.clearIssue(for: order.orderNumber)
                } onDiscard: {
                  store.discardSpam(for: order.orderNumber)
                } onCreateTask: {
                  store.createReviewTask(from: order)
                } onCreateDraft: {
                  store.createDraftMessage(from: order)
                }
              }
            }
          }
        }

        if showsMailboxEvents {
          SettingsPanel(title: "Mailbox events", symbol: "envelope.badge.fill") {
            if store.reviewMailEvents.isEmpty {
              MVPEmptyState(title: "No mailbox events need review", detail: "Mailbox events that match orders or require local follow-up will appear here.", symbol: "envelope.badge.fill")
            } else {
              ForEach(store.reviewMailEvents) { event in
                ReviewMailEventRow(event: event) {
                  store.clearIssue(for: event.matchedOrder)
                } onDiscard: {
                  store.discardSpam(for: event.matchedOrder)
                } onCreateTask: {
                  store.createReviewTask(
                    linkedEntityType: .auditEvent,
                    linkedEntityID: event.id.uuidString,
                    label: event.matchedOrder,
                    summary: "Follow up mailbox event from \(event.sender): \(event.summary)",
                    priority: event.severity == .critical ? .urgent : .high
                  )
                }
              }
            }
          }
        }

        if showsParserChecksInPrimary && !store.intakeParserDiagnostics.isEmpty {
          SettingsPanel(title: "Intake parser checks", symbol: "text.magnifyingglass") {
            Text("These forwarded emails reached intake, but the local parser still needs a person to confirm order, tracking, merchant, or destination details. This section appears only when you search for parser diagnostics.")
              .font(.caption)
              .foregroundStyle(.secondary)
            ForEach(Array(store.intakeParserDiagnostics.prefix(8))) { diagnostic in
              IntakeParserDiagnosticRow(diagnostic: diagnostic) {
                if let email = store.intakeEmails.first(where: { $0.id == diagnostic.intakeEmailID }) {
                  store.reprocessIntakeEmail(email)
                }
              } onCreateTask: {
                if let email = store.intakeEmails.first(where: { $0.id == diagnostic.intakeEmailID }) {
                  store.createReviewTask(from: email)
                }
              }
            }
          }
        }

        if showsMixedMailboxReview {
          SettingsPanel(title: "Mixed-mailbox review", symbol: "questionmark.folder.fill") {
            Text("These previews were held out of the primary Inbox by mixed-mailbox filtering. Import only true order/order-update messages; dismiss local false positives without changing the mailbox.")
              .font(.caption)
              .foregroundStyle(.secondary)

            if store.spaceMailIMAPConnections.isEmpty && store.gmailMailboxConnections.isEmpty {
              MVPEmptyState(
                title: "No mailbox setup exists",
                detail: "Add a SpaceMail IMAP or Gmail setup before mixed-mailbox review can show uncertain or filtered examples.",
                symbol: "envelope.badge.fill"
              )
            } else {
              ForEach(store.spaceMailIMAPConnections) { connection in
                VStack(alignment: .leading, spacing: 12) {
                  HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Label(connection.displayName, systemImage: "server.rack")
                      .font(.subheadline.weight(.semibold))
                    Spacer()
                    Badge("\(connection.uncertainMessages.count) uncertain", color: connection.uncertainMessages.isEmpty ? .secondary : .orange)
                    Badge("\(connection.filteredMessages.count) filtered", color: connection.filteredMessages.isEmpty ? .secondary : .teal)
                  }

                  Text("Latest refresh: \(connection.lastRefreshSummary)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                  VStack(alignment: .leading, spacing: 8) {
                    Label("Uncertain SpaceMail messages", systemImage: "questionmark.diamond.fill")
                      .font(.caption.weight(.semibold))
                      .foregroundStyle(.orange)

                    if connection.uncertainMessages.isEmpty {
                      MVPEmptyState(
                        title: "No uncertain messages waiting",
                        detail: "Order-ish messages without enough evidence will appear here. A zero count means the classifier either imported likely order mail or filtered likely non-order mail.",
                        symbol: "checkmark.seal.fill"
                      )
                    } else {
                      ForEach(connection.uncertainMessages.prefix(5)) { message in
                        SpaceMailNeedsReviewPreviewRow(
                          title: message.subject,
                          sender: message.sender,
                          receivedDate: message.receivedDate,
                          bodyPreview: message.bodyPreview,
                          reason: message.reason,
                          badge: "Uncertain",
                          color: .orange
                        ) {
                          store.importUncertainSpaceMailMessage(message, for: connection)
                        } onDismiss: {
                          store.dismissUncertainSpaceMailMessage(message, for: connection)
                        } onCreateTask: {
                          store.createReviewTask(from: message, connection: connection)
                        } onCreateDraft: {
                          store.createDraftMessage(from: message, connection: connection)
                        } onTrustSender: {
                          store.addSpaceMailHintFromUncertain(message, target: .trustedSender, for: connection)
                        } onImportHint: {
                          store.addSpaceMailHintFromUncertain(message, target: .importKeyword, for: connection)
                        } onFilterHint: {
                          store.addSpaceMailHintFromUncertain(message, target: .filterKeyword, for: connection)
                        }
                      }
                    }
                  }

                  VStack(alignment: .leading, spacing: 8) {
                    Label("Filtered SpaceMail examples", systemImage: "line.3.horizontal.decrease.circle.fill")
                      .font(.caption.weight(.semibold))
                      .foregroundStyle(.teal)

                    if connection.filteredMessages.isEmpty {
                      MVPEmptyState(
                        title: "No filtered examples saved",
                        detail: "Filtered non-order previews are counted locally. Saved examples appear here only when the classifier keeps recent safe subject/sender previews for spot review.",
                        symbol: "line.3.horizontal.decrease.circle.fill"
                      )
                    } else {
                      ForEach(connection.filteredMessages.prefix(3)) { message in
                        SpaceMailNeedsReviewPreviewRow(
                          title: message.subject,
                          sender: message.sender,
                          receivedDate: message.receivedDate,
                          bodyPreview: message.bodyPreview,
                          reason: message.reason,
                          badge: "Filtered",
                          color: .teal
                        ) {
                          store.importFilteredSpaceMailMessage(message, for: connection)
                        } onDismiss: {
                          store.dismissFilteredSpaceMailMessage(message, for: connection)
                        } onCreateTask: {
                          store.createReviewTask(from: message, connection: connection)
                        } onCreateDraft: {
                          store.createDraftMessage(from: message, connection: connection)
                        } onTrustSender: {
                          store.addSpaceMailHintFromFiltered(message, target: .trustedSender, for: connection)
                        } onImportHint: {
                          store.addSpaceMailHintFromFiltered(message, target: .importKeyword, for: connection)
                        } onFilterHint: {
                          store.addSpaceMailHintFromFiltered(message, target: .filterKeyword, for: connection)
                        }
                      }
                    }
                  }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
              }
              ForEach(store.gmailMailboxConnections) { connection in
                VStack(alignment: .leading, spacing: 12) {
                  HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Label(connection.displayName, systemImage: "envelope.badge.shield.half.filled")
                      .font(.subheadline.weight(.semibold))
                    Spacer()
                    Badge("\((connection.uncertainMessages ?? []).count) uncertain", color: (connection.uncertainMessages ?? []).isEmpty ? .secondary : .orange)
                    Badge("\(connection.lastRefreshFilteredNonOrderCount) filtered", color: connection.lastRefreshFilteredNonOrderCount == 0 ? .secondary : .teal)
                  }

                  Text("Latest refresh: \(connection.lastRefreshSummary)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                  VStack(alignment: .leading, spacing: 8) {
                    Label("Uncertain Gmail messages", systemImage: "questionmark.diamond.fill")
                      .font(.caption.weight(.semibold))
                      .foregroundStyle(.orange)

                    let messages = connection.uncertainMessages ?? []
                    if messages.isEmpty {
                      MVPEmptyState(
                        title: "No uncertain Gmail messages waiting",
                        detail: "Order-ish Gmail previews without enough evidence will appear here. A zero count means Gmail imported likely order mail or filtered likely non-order mail.",
                        symbol: "checkmark.seal.fill"
                      )
                    } else {
                      ForEach(Array(messages.prefix(5))) { message in
                        GmailNeedsReviewPreviewRow(
                          title: message.subject,
                          sender: message.sender,
                          receivedDate: message.receivedDate,
                          bodyPreview: message.bodyPreview,
                          reason: message.reason
                        ) {
                          store.importUncertainGmailMessage(message, for: connection)
                        } onCreateTask: {
                          store.createReviewTask(from: message, connection: connection, reviewQueue: "uncertain")
                        } onCreateDraft: {
                          store.createDraftMessage(from: message, connection: connection, reviewQueue: "uncertain")
                        } onDismiss: {
                          store.dismissUncertainGmailMessage(message, for: connection)
                        } onTrustSender: {
                          store.addGmailHintFromUncertain(message, target: .trustedSender, for: connection)
                        } onImportHint: {
                          store.addGmailHintFromUncertain(message, target: .importKeyword, for: connection)
                        } onFilterHint: {
                          store.addGmailHintFromUncertain(message, target: .filterKeyword, for: connection)
                        }
                      }
                    }
                  }

                  let filteredMessages = connection.filteredMessages ?? []
                  if !filteredMessages.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                      Label("Filtered Gmail examples", systemImage: "line.3.horizontal.decrease.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.teal)

                      ForEach(Array(filteredMessages.prefix(5))) { message in
                        GmailNeedsReviewPreviewRow(
                          title: message.subject,
                          sender: message.sender,
                          receivedDate: message.receivedDate,
                          bodyPreview: message.bodyPreview,
                          reason: message.reason,
                          badge: "Filtered",
                          color: .teal,
                          recommendationTitle: "Optional review: likely non-order Gmail",
                          recommendationDetail: "This Gmail preview was filtered out of Inbox. Import it only if it is a real order or order update; otherwise dismiss the local preview.",
                          symbol: "line.3.horizontal.decrease.circle.fill"
                        ) {
                          store.importFilteredGmailMessage(message, for: connection)
                        } onCreateTask: {
                          store.createReviewTask(from: message, connection: connection, reviewQueue: "filtered")
                        } onCreateDraft: {
                          store.createDraftMessage(from: message, connection: connection, reviewQueue: "filtered")
                        } onDismiss: {
                          store.dismissFilteredGmailMessage(message, for: connection)
                        } onTrustSender: {
                          store.addGmailHintFromFiltered(message, target: .trustedSender, for: connection)
                        } onImportHint: {
                          store.addGmailHintFromFiltered(message, target: .importKeyword, for: connection)
                        } onFilterHint: {
                          store.addGmailHintFromFiltered(message, target: .filterKeyword, for: connection)
                        }
                      }
                    }
                  }

                  if filteredMessages.isEmpty, let examples = connection.lastRefreshFilteredExamples, !examples.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                      Label("Filtered Gmail examples", systemImage: "line.3.horizontal.decrease.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.teal)
                      Text(examples.prefix(5).joined(separator: "; "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                  }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
              }
            }
          }
        }

        if showsForwardedEmails {
          SettingsPanel(title: "Forwarded emails", symbol: "envelope.open.fill") {
            if store.reviewIntakeEmails.isEmpty {
              MVPEmptyState(title: "No forwarded emails need review", detail: "Order-related messages imported from SpaceMail, Gmail, or simulated intake will appear here until reviewed, linked, ignored, or converted into an order.", symbol: "envelope.open.fill")
            } else {
              ForEach(store.reviewIntakeEmails) { email in
                IntakeEmailRow(email: email, store: store, orders: store.orders, evidenceAttachments: store.evidence(for: .intakeEmail, linkedEntityID: email.id), suggestedContacts: store.suggestedContacts(for: email), suggestedAccounts: store.suggestedAccounts(for: email), suggestedProfiles: store.suggestedVendorProfiles(for: email), customerProfiles: store.suggestedCustomerProfiles(for: email), destinationAddresses: store.suggestedDestinationAddresses(for: email), deliveryInstructions: store.suggestedDeliveryInstructions(for: email), packageContents: store.suggestedPackageContents(for: email), shipmentGroups: store.suggestedShipmentGroups(for: email)) { updatedEmail in
                  store.updateIntakeEmail(updatedEmail)
                } onLinkOrder: { order in
                  store.linkIntakeEmail(email, to: order)
                } onCreateOrder: {
                  store.createOrder(from: email)
                } onReviewed: {
                  store.markIntakeEmailReviewed(email)
                } onIgnore: {
                  store.ignoreIntakeEmail(email)
                } onReprocess: {
                  store.reprocessIntakeEmail(email)
                } onAddEvidence: {
                  store.addPlaceholderEvidence(to: .intakeEmail, linkedEntityID: email.id, label: email.detectedOrderNumber)
                } onReviewEvidence: { attachment in
                  store.markEvidenceReviewed(attachment)
                } onRemoveEvidence: { attachment in
                  store.removeEvidence(attachment)
                } onCreateTask: {
                  store.createReviewTask(from: email)
                } onCreateDraft: {
                  store.createDraftMessage(from: email)
                } onDraftFromContact: { contact in
                  store.createDraftMessage(from: contact, linkedEntityType: .intakeEmail, linkedEntityID: email.id.uuidString, label: email.detectedOrderNumber)
                } onCreateAccount: {
                  store.addAccountCredentialRecord(linkedEntityType: .intakeEmail, linkedEntityID: email.id.uuidString, organisation: email.detectedMerchant, label: email.detectedOrderNumber)
                } onTaskFromAccount: { account in
                  store.createReviewTask(from: account)
                } onDraftFromAccount: { account in
                  store.createDraftMessage(from: account)
                } onCreateProfile: {
                  store.addVendorProfile(profileType: .supplier, organisation: email.detectedMerchant, label: email.detectedOrderNumber)
                } onTaskFromProfile: { profile in
                  store.createReviewTask(from: profile)
                } onDraftFromProfile: { profile in
                  store.createDraftMessage(from: profile)
                }
              }
            }
          }
        }

        if showsEvidence {
          SettingsPanel(title: "Evidence", symbol: "paperclip") {
            if store.reviewEvidenceAttachments.isEmpty {
              MVPEmptyState(title: "No evidence needs review", detail: "Local evidence placeholders linked to intake, orders, tracking, or claims will appear here when review is required.", symbol: "paperclip")
            } else {
              ForEach(store.reviewEvidenceAttachments) { attachment in
                EvidenceAttachmentRow(attachment: attachment, shipmentGroups: store.suggestedShipmentGroups(for: attachment), customerProfiles: store.suggestedCustomerProfiles(for: attachment), destinationAddresses: store.suggestedDestinationAddresses(for: attachment), deliveryInstructions: store.suggestedDeliveryInstructions(for: attachment), packageContents: store.suggestedPackageContents(for: attachment)) {
                  store.markEvidenceReviewed(attachment)
                } onRemove: {
                  store.removeEvidence(attachment)
                } onCreateTask: {
                  store.createReviewTask(from: attachment)
                } onCreateDraft: {
                  store.createDraftMessage(from: attachment)
                } onCreateContact: {
                  store.addContactDirectoryEntry(linkedEntityType: .evidence, linkedEntityID: attachment.id.uuidString, label: attachment.fileName)
                }
              }
            }
          }
        }

        if showsTrackingEvents {
          SettingsPanel(title: "Tracking events", symbol: "location.fill.viewfinder") {
            if store.reviewCarrierTrackingEvents.isEmpty {
              MVPEmptyState(title: "No tracking events need review", detail: "Critical or watch-level local tracking events will appear here when they require follow-up.", symbol: "location.fill.viewfinder")
            } else {
              ForEach(store.reviewCarrierTrackingEvents) { event in
                TrackingEventRow(event: event, store: store, order: store.orders.first { $0.id == event.orderID }, suggestedContacts: store.suggestedContacts(for: event), suggestedProfiles: store.suggestedVendorProfiles(for: event), customerProfiles: store.suggestedCustomerProfiles(for: event), destinationAddresses: store.suggestedDestinationAddresses(for: event), deliveryInstructions: store.suggestedDeliveryInstructions(for: event), packageContents: store.suggestedPackageContents(for: event), shipmentGroups: store.suggestedShipmentGroups(for: event)) {
                  store.markTrackingEventReviewed(event)
                } onRemove: {
                  store.removeTrackingEvent(event)
                } onCreateTask: {
                  store.createReviewTask(from: event)
                } onCreateDraft: {
                  store.createDraftMessage(from: event)
                } onDraftFromContact: { contact in
                  store.createDraftMessage(from: contact, linkedEntityType: .trackingEvent, linkedEntityID: event.id.uuidString, label: event.trackingNumber)
                } onCreateProfile: {
                  store.addVendorProfile(profileType: .carrier, organisation: event.carrier, label: event.trackingNumber)
                } onTaskFromProfile: { profile in
                  store.createReviewTask(from: profile)
                } onDraftFromProfile: { profile in
                  store.createDraftMessage(from: profile)
                } relatedTasks: {
                  store.tasks(for: .trackingEvent, linkedEntityID: event.id.uuidString)
                }
              }
            }
          }
        }

        if showsTaskEscalations {
          SettingsPanel(title: "Task escalations", symbol: "checklist") {
            if store.reviewTasksNeedingAttention.isEmpty {
              MVPEmptyState(title: "No task escalations need review", detail: "Open, overdue, blocked, or review-needed follow-up tasks will appear here.", symbol: "checklist")
            } else {
              ForEach(store.reviewTasksNeedingAttention) { task in
                ReviewTaskRow(task: task, matchingPolicies: store.policies(for: task.linkedEntityType), shipmentGroups: store.suggestedShipmentGroups(for: task), handoffNotes: store.handoffNotes(for: task), customerProfiles: store.suggestedCustomerProfiles(for: task), destinationAddresses: store.suggestedDestinationAddresses(for: task), deliveryInstructions: store.suggestedDeliveryInstructions(for: task), packageContents: store.suggestedPackageContents(for: task)) { updatedTask in
                  store.updateReviewTask(updatedTask)
                } onComplete: {
                  store.completeReviewTask(task)
                } onReopen: {
                  store.reopenReviewTask(task)
                } onReviewed: {
                  store.markReviewTaskReviewed(task)
                } onCreateDraft: {
                  store.createDraftMessage(from: task)
                } onCreateContact: {
                  store.addContactDirectoryEntry(linkedEntityType: .reviewTask, linkedEntityID: task.id.uuidString, label: task.title)
                } onRemove: {
                  store.removeReviewTask(task)
                }
              }
            }
          }
        }

        if showsHandoffNotes {
          SettingsPanel(title: "Handoff notes", symbol: "arrow.left.arrow.right.square.fill") {
            if store.handoffNotesNeedingAttention.isEmpty {
              MVPEmptyState(title: "No handoff notes need attention", detail: "Open, overdue, blocked, or review-needed shift handoff notes will appear here.", symbol: "arrow.left.arrow.right.square.fill")
            } else {
              ForEach(store.handoffNotesNeedingAttention) { note in
                HandoffNoteRow(note: note, customerProfiles: store.suggestedCustomerProfiles(for: note), destinationAddresses: store.suggestedDestinationAddresses(for: note), deliveryInstructions: store.suggestedDeliveryInstructions(for: note), packageContents: store.suggestedPackageContents(for: note)) { updatedNote in
                  store.updateHandoffNote(updatedNote)
                } onAcknowledge: {
                  store.acknowledgeHandoffNote(note)
                } onComplete: {
                  store.completeHandoffNote(note)
                } onReopen: {
                  store.reopenHandoffNote(note)
                } onReviewed: {
                  store.markHandoffNoteReviewed(note)
                } onCreateTask: {
                  store.createReviewTask(from: note)
                } onCreateDraft: {
                  store.createDraftMessage(from: note)
                } onRemove: {
                  store.removeHandoffNote(note)
                }
              }
            }
          }
        }

        DisclosureGroup(isExpanded: $showAdvancedBacklog) {
          VStack(alignment: .leading, spacing: 14) {
            SettingsPanel(title: "SLA policies", symbol: "timer") {
              ForEach(store.policiesNeedingReview) { policy in
                SLAPolicyRow(policy: policy, destinationAddresses: store.suggestedDestinationAddresses(for: policy), deliveryInstructions: store.suggestedDeliveryInstructions(for: policy), packageContents: store.suggestedPackageContents(for: policy)) { updatedPolicy in
                  store.updateSLAPolicy(updatedPolicy)
                } onToggle: {
                  store.toggleSLAPolicy(policy)
                } onReviewed: {
                  store.markSLAPolicyReviewed(policy)
                } onEvaluate: {
                  store.evaluateSLAPolicyPlaceholder(policy)
                } onCreateDraft: {
                  store.createDraftMessage(from: policy)
                } onCreateContact: {
                  store.addContactDirectoryEntry(linkedEntityType: .slaPolicy, linkedEntityID: policy.id.uuidString, label: policy.name)
                } onRemove: {
                  store.removeSLAPolicy(policy)
                }
              }
            }

            SettingsPanel(title: "Exception playbooks", symbol: "book.closed.fill") {
              ForEach(Array(Set(store.playbooksNeedingReview + store.enabledHighPriorityPlaybooks)).sorted { lhs, rhs in
                lhs.priority.rawValue > rhs.priority.rawValue
              }) { playbook in
                ExceptionPlaybookRow(playbook: playbook, handoffNotes: store.handoffNotes(for: playbook), destinationAddresses: store.suggestedDestinationAddresses(for: playbook), deliveryInstructions: store.suggestedDeliveryInstructions(for: playbook), packageContents: store.suggestedPackageContents(for: playbook)) { updatedPlaybook in
                  store.updateExceptionPlaybook(updatedPlaybook)
                } onToggle: {
                  store.toggleExceptionPlaybook(playbook)
                } onReviewed: {
                  store.markExceptionPlaybookReviewed(playbook)
                } onCreateTask: {
                  store.createReviewTask(from: playbook)
                } onCreateDraft: {
                  store.createDraftMessage(from: playbook)
                } onRemove: {
                  store.removeExceptionPlaybook(playbook)
                }
              }
            }

            SettingsPanel(title: "Contacts", symbol: "person.crop.circle.badge.checkmark") {
              ForEach(store.contactsNeedingReview) { contact in
                ContactDirectoryRow(contact: contact, destinationAddresses: store.suggestedDestinationAddresses(for: contact), deliveryInstructions: store.suggestedDeliveryInstructions(for: contact), packageContents: store.suggestedPackageContents(for: contact)) { updatedContact in
                  store.updateContactDirectoryEntry(updatedContact)
                } onToggle: {
                  store.toggleContactDirectoryEntry(contact)
                } onReviewed: {
                  store.markContactDirectoryEntryReviewed(contact)
                } onCreateDraft: {
                  store.createDraftMessage(from: contact)
                } onRemove: {
                  store.removeContactDirectoryEntry(contact)
                }
              }
            }

        SettingsPanel(title: "Customer profiles", symbol: "person.text.rectangle.fill") {
          ForEach(Array(Set(store.customerProfilesNeedingReview + store.customerRecipientProfiles.filter { !$0.isEnabled }))) { profile in
            CustomerProfileRow(profile: profile) { updatedProfile in
              store.updateCustomerRecipientProfile(updatedProfile)
            } onToggle: {
              store.toggleCustomerRecipientProfile(profile)
            } onReviewed: {
              store.markCustomerRecipientProfileReviewed(profile)
            } onCreateTask: {
              store.createReviewTask(from: profile)
            } onCreateDraft: {
              store.createDraftMessage(from: profile)
            } onRemove: {
              store.removeCustomerRecipientProfile(profile)
            }
          }
        }

        SettingsPanel(title: "Destination addresses", symbol: "mappin.and.ellipse") {
          ForEach(Array(Set(store.destinationAddressesNeedingReview + store.highRiskDestinationAddresses + store.destinationAddresses.filter { !$0.isEnabled }))) { address in
            DestinationAddressRow(address: address, customerProfiles: store.customerRecipientProfiles) { updatedAddress in
              store.updateDestinationAddress(updatedAddress)
            } onToggle: {
              store.toggleDestinationAddress(address)
            } onReviewed: {
              store.markDestinationAddressReviewed(address)
            } onCreateTask: {
              store.createReviewTask(from: address)
            } onCreateDraft: {
              store.createDraftMessage(from: address)
            } onRemove: {
              store.removeDestinationAddress(address)
            }
          }
        }

        SettingsPanel(title: "Delivery instructions", symbol: "signpost.right.and.left.fill") {
          ForEach(Array(Set(store.deliveryInstructionsNeedingReview + store.highRiskDeliveryInstructions + store.deliveryInstructions.filter { !$0.isEnabled } + store.deliveryInstructionsWithAccessConstraints.filter { $0.reviewState != .accepted }))) { instruction in
            DeliveryInstructionRow(
              instruction: instruction,
              destinationAddress: store.destinationAddresses.first { $0.id == instruction.destinationAddressID },
              customerProfile: store.customerRecipientProfiles.first { $0.id == instruction.customerProfileID }
            ) { updatedInstruction in
              store.updateDeliveryInstruction(updatedInstruction)
            } onToggle: {
              store.toggleDeliveryInstruction(instruction)
            } onReviewed: {
              store.markDeliveryInstructionReviewed(instruction)
            } onCreateTask: {
              store.createReviewTask(from: instruction)
            } onCreateDraft: {
              store.createDraftMessage(from: instruction)
            } onRemove: {
              store.removeDeliveryInstruction(instruction)
            }
          }
        }

        SettingsPanel(title: "Package contents", symbol: "shippingbox.circle.fill") {
          ForEach(Array(Set(store.packageContentsNeedingReview + store.unverifiedPackageContents + store.packageContentDiscrepancies + store.highRiskPackageContents + store.highValuePackageContents))) { content in
            PackageContentRow(content: content, custodyRecords: store.suggestedCustodyRecords(for: content)) { updatedContent in
              store.updatePackageContent(updatedContent)
            } onVerified: {
              store.markPackageContentVerified(content)
            } onDiscrepancy: {
              store.markPackageContentDiscrepancy(content)
            } onReviewed: {
              store.markPackageContentReviewed(content)
            } onCreateTask: {
              store.createReviewTask(from: content)
            } onCreateDraft: {
              store.createDraftMessage(from: content)
            } onRemove: {
              store.removePackageContent(content)
            }
          }
        }

        SettingsPanel(title: "Costs & budgets", symbol: "creditcard.and.123") {
          ForEach(Array(Set(store.costRecordsNeedingReview + store.disputedCostRecords + store.unreimbursedCostRecords + store.unapprovedCostRecords + store.highRiskCostRecords + store.missingBudgetCodeCostRecords))) { cost in
            CostRecordRow(cost: cost) { updatedCost in
              store.updateCostRecord(updatedCost)
            } onApproved: {
              store.markCostRecordApproved(cost)
            } onReimbursed: {
              store.markCostRecordReimbursed(cost)
            } onDisputed: {
              store.markCostRecordDisputed(cost)
            } onReviewed: {
              store.markCostRecordReviewed(cost)
            } onCreateTask: {
              store.createReviewTask(from: cost)
            } onCreateDraft: {
              store.createDraftMessage(from: cost)
            } onRemove: {
              store.removeCostRecord(cost)
            }
          }
        }

        SettingsPanel(title: "Returns & claims", symbol: "arrow.uturn.backward.square.fill") {
          ForEach(Array(Set(store.returnClaimsNeedingReview + store.disputedReturnClaims + store.unresolvedReturnClaims + store.overdueReturnClaims + store.highRiskReturnClaims + store.returnClaimsMissingEvidence))) { claim in
            ReturnClaimRow(claim: claim, custodyRecords: store.suggestedCustodyRecords(for: claim), labelReferences: store.suggestedLabelReferenceRecords(for: claim), scanSessions: store.suggestedScanSessionRecords(for: claim)) { updatedClaim in
              store.updateReturnClaim(updatedClaim)
            } onSubmitted: {
              store.markReturnClaimSubmitted(claim)
            } onApproved: {
              store.markReturnClaimApproved(claim)
            } onResolved: {
              store.markReturnClaimResolved(claim)
            } onDisputed: {
              store.markReturnClaimDisputed(claim)
            } onReviewed: {
              store.markReturnClaimReviewed(claim)
            } onCreateTask: {
              store.createReviewTask(from: claim)
            } onCreateDraft: {
              store.createDraftMessage(from: claim)
            } onRemove: {
              store.removeReturnClaim(claim)
            }
          }
        }

        SettingsPanel(title: "Procurement", symbol: "cart.badge.plus") {
          ForEach(Array(Set(store.procurementRequestsNeedingReview + store.unapprovedProcurementRequests + store.rejectedProcurementRequests + store.notYetOrderedProcurementRequests + store.overdueProcurementRequests + store.highRiskProcurementRequests + store.missingBudgetCodeProcurementRequests))) { request in
            ProcurementRequestRow(request: request, custodyRecords: store.suggestedCustodyRecords(for: request), labelReferences: store.suggestedLabelReferenceRecords(for: request), scanSessions: store.suggestedScanSessionRecords(for: request)) { updatedRequest in
              store.updateProcurementRequest(updatedRequest)
            } onApproved: {
              store.markProcurementRequestApproved(request)
            } onOrdered: {
              store.markProcurementRequestOrdered(request)
            } onReceived: {
              store.markProcurementRequestReceived(request)
            } onRejected: {
              store.markProcurementRequestRejected(request)
            } onReviewed: {
              store.markProcurementRequestReviewed(request)
            } onCreateTask: {
              store.createReviewTask(from: request)
            } onCreateDraft: {
              store.createDraftMessage(from: request)
            } onRemove: {
              store.removeProcurementRequest(request)
            }
          }
        }

        SettingsPanel(title: "Receiving inspections", symbol: "checklist.checked") {
          ForEach(Array(Set(store.receivingInspectionsNeedingReview + store.blockedReceivingInspections + store.unresolvedInspectionDiscrepancies + store.highRiskReceivingInspections + store.overdueReceivingInspections + store.quantityMismatchReceivingInspections))) { inspection in
            ReceivingInspectionRow(inspection: inspection, custodyRecords: store.suggestedCustodyRecords(for: inspection)) { updatedInspection in
              store.updateReceivingInspection(updatedInspection)
            } onInspected: {
              store.markReceivingInspectionInspected(inspection)
            } onDiscrepancy: {
              store.markReceivingInspectionDiscrepancy(inspection)
            } onResolved: {
              store.markReceivingInspectionResolved(inspection)
            } onBlocked: {
              store.markReceivingInspectionBlocked(inspection)
            } onReviewed: {
              store.markReceivingInspectionReviewed(inspection)
            } onCreateTask: {
              store.createReviewTask(from: inspection)
            } onCreateDraft: {
              store.createDraftMessage(from: inspection)
            } onRemove: {
              store.removeReceivingInspection(inspection)
            }
          }
        }

        SettingsPanel(title: "Inventory receipts", symbol: "archivebox.fill") {
          ForEach(Array(Set(store.inventoryReceiptsNeedingReview + store.rejectedInventoryReceipts + store.partiallyAcceptedInventoryReceipts + store.highRiskInventoryReceipts + store.unassignedInventoryReceipts + store.inventoryReceiptsMissingStorage))) { receipt in
            InventoryReceiptRow(receipt: receipt, custodyRecords: store.suggestedCustodyRecords(for: receipt)) { updatedReceipt in
              store.updateInventoryReceipt(updatedReceipt)
            } onStocked: {
              store.markInventoryReceiptStocked(receipt)
            } onHandedOff: {
              store.markInventoryReceiptHandedOff(receipt)
            } onPartiallyAccepted: {
              store.markInventoryReceiptPartiallyAccepted(receipt)
            } onRejected: {
              store.markInventoryReceiptRejected(receipt)
            } onReviewed: {
              store.markInventoryReceiptReviewed(receipt)
            } onCreateTask: {
              store.createReviewTask(from: receipt)
            } onCreateDraft: {
              store.createDraftMessage(from: receipt)
            } onRemove: {
              store.removeInventoryReceipt(receipt)
            }
          }
        }

        SettingsPanel(title: "Storage locations", symbol: "cabinet.fill") {
          ForEach(Array(Set(store.storageLocationsNeedingReview + store.disabledStorageLocations + store.highRiskStorageLocations + store.storageLocationsMissingCodes + store.storageLocationsWithAccessNotes + store.storageLocationsWithCapacityWarnings))) { location in
            StorageLocationRow(location: location, custodyRecords: store.suggestedCustodyRecords(for: location)) { updatedLocation in
              store.updateStorageLocation(updatedLocation)
            } onToggle: {
              store.toggleStorageLocation(location)
            } onReviewed: {
              store.markStorageLocationReviewed(location)
            } onCreateTask: {
              store.createReviewTask(from: location)
            } onCreateDraft: {
              store.createDraftMessage(from: location)
            } onRemove: {
              store.removeStorageLocation(location)
            }
          }
        }

        SettingsPanel(title: "Custody chain", symbol: "person.badge.shield.checkmark.fill") {
          ForEach(Array(Set(store.custodyRecordsNeedingReview + store.disputedCustodyRecords + store.openCustodyTransfers + store.overdueCustodyRecords + store.highRiskCustodyRecords + store.custodyRecordsMissingCustodians + store.custodyRecordsMissingLocations))) { record in
            CustodyRecordRow(record: record, labelReferences: store.suggestedLabelReferenceRecords(for: record)) { updatedRecord in
              store.updateCustodyRecord(updatedRecord)
            } onTransferred: {
              store.markCustodyRecordTransferred(record)
            } onReceived: {
              store.markCustodyRecordReceived(record)
            } onReturnedClosed: {
              store.markCustodyRecordReturnedClosed(record)
            } onDisputed: {
              store.markCustodyRecordDisputed(record)
            } onReviewed: {
              store.markCustodyRecordReviewed(record)
            } onCreateTask: {
              store.createReviewTask(from: record)
            } onCreateDraft: {
              store.createDraftMessage(from: record)
            } onRemove: {
              store.removeCustodyRecord(record)
            }
          }
        }

        SettingsPanel(title: "Label references", symbol: "barcode.viewfinder") {
          ForEach(Array(Set(store.labelReferencesNeedingReview + store.invalidLabelReferences + store.unverifiedLabelReferences + store.highRiskLabelReferences + store.labelReferencesMissingValues + store.labelReferencesMissingLinkedRecords))) { record in
            LabelReferenceRow(record: record, scanSessions: store.suggestedScanSessionRecords(for: record)) { updatedRecord in
              store.updateLabelReferenceRecord(updatedRecord)
            } onPrinted: {
              store.markLabelReferencePrinted(record)
            } onVerified: {
              store.markLabelReferenceVerified(record)
            } onInvalid: {
              store.markLabelReferenceInvalid(record)
            } onReviewed: {
              store.markLabelReferenceReviewed(record)
            } onCreateTask: {
              store.createReviewTask(from: record)
            } onCreateDraft: {
              store.createDraftMessage(from: record)
            } onRemove: {
              store.removeLabelReferenceRecord(record)
            }
          }
        }

        SettingsPanel(title: "Scan sessions", symbol: "qrcode.viewfinder") {
          ForEach(Array(Set(store.scanSessionsNeedingReview + store.mismatchScanSessions + store.incompleteScanSessions + store.highRiskScanSessions + store.scanSessionsMissingCapturedValues + store.scanSessionsMissingLabelReferences))) { record in
            ScanSessionRow(record: record) { updatedRecord in
              store.updateScanSessionRecord(updatedRecord)
            } onMatched: {
              store.markScanSessionMatched(record)
            } onMismatch: {
              store.markScanSessionMismatch(record)
            } onCompleted: {
              store.markScanSessionCompleted(record)
            } onReopen: {
              store.reopenScanSession(record)
            } onReviewed: {
              store.markScanSessionReviewed(record)
            } onCreateTask: {
              store.createReviewTask(from: record)
            } onCreateDraft: {
              store.createDraftMessage(from: record)
            } onRemove: {
              store.removeScanSessionRecord(record)
            }
          }
        }

        SettingsPanel(title: "Shipment manifests", symbol: "list.bullet.clipboard.fill") {
          ForEach(Array(Set(store.shipmentManifestsNeedingReview + store.blockedShipmentManifests + store.undispatchedShipmentManifests + store.highRiskShipmentManifests + store.shipmentManifestsMissingIncludedOrders + store.shipmentManifestsMissingHandoffLocation + store.shipmentManifestsWithIncompleteScans))) { record in
            ShipmentManifestRow(record: record, store: store, linkedOrders: linkedOrders(for: record)) { updatedRecord in
              store.updateShipmentManifestRecord(updatedRecord)
            } onPrepared: {
              store.markShipmentManifestPrepared(record)
            } onDispatched: {
              store.markShipmentManifestDispatched(record)
            } onHandedOff: {
              store.markShipmentManifestHandedOff(record)
            } onBlocked: {
              store.markShipmentManifestBlocked(record)
            } onReopen: {
              store.reopenShipmentManifest(record)
            } onReviewed: {
              store.markShipmentManifestReviewed(record)
            } onCreateTask: {
              store.createReviewTask(from: record)
            } onCreateDraft: {
              store.createDraftMessage(from: record)
            } onRemove: {
              store.removeShipmentManifestRecord(record)
            }
          }
        }

        SettingsPanel(title: "Dispatch readiness", symbol: "checkmark.rectangle.stack.fill") {
          ForEach(Array(Set(store.dispatchChecklistsNeedingReview + store.blockedDispatchChecklists + store.incompleteDispatchChecklists + store.highRiskDispatchChecklists + store.dispatchChecklistsMissingRequirements + store.dispatchChecklistsLinkedToBlockedManifests))) { checklist in
            DispatchReadinessRow(checklist: checklist, store: store, linkedOrders: linkedOrders(for: checklist)) { updatedChecklist in
              store.updateDispatchReadinessChecklist(updatedChecklist)
            } onReady: {
              store.markDispatchChecklistReady(checklist)
            } onBlocked: {
              store.markDispatchChecklistBlocked(checklist)
            } onCompleted: {
              store.markDispatchChecklistCompleted(checklist)
            } onReopen: {
              store.reopenDispatchChecklist(checklist)
            } onReviewed: {
              store.markDispatchChecklistReviewed(checklist)
            } onCreateTask: {
              store.createReviewTask(from: checklist)
            } onCreateDraft: {
              store.createDraftMessage(from: checklist)
            } onRemove: {
              store.removeDispatchReadinessChecklist(checklist)
            }
          }
        }

        SettingsPanel(title: "Accounts", symbol: "key.horizontal.fill") {
          ForEach(store.accountRecordsNeedingReview) { account in
            AccountCredentialRow(account: account, contacts: store.contactDirectoryEntries, destinationAddresses: store.suggestedDestinationAddresses(for: account), deliveryInstructions: store.suggestedDeliveryInstructions(for: account), packageContents: store.suggestedPackageContents(for: account)) { updatedAccount in
              store.updateAccountCredentialRecord(updatedAccount)
            } onToggle: {
              store.toggleAccountCredentialRecord(account)
            } onReviewed: {
              store.markAccountCredentialRecordReviewed(account)
            } onChecked: {
              store.markAccountCredentialRecordChecked(account)
            } onCreateTask: {
              store.createReviewTask(from: account)
            } onCreateDraft: {
              store.createDraftMessage(from: account)
            } onRemove: {
              store.removeAccountCredentialRecord(account)
            }
          }
        }

        SettingsPanel(title: "Vendor profiles", symbol: "building.2.crop.circle.fill") {
          ForEach(Array(Set(store.vendorProfilesNeedingReview + store.highRiskEnabledVendorProfiles)).sorted { lhs, rhs in
            lhs.riskLevel.riskRank > rhs.riskLevel.riskRank
          }) { profile in
            VendorProfileRow(profile: profile, contacts: store.contactDirectoryEntries, accounts: store.accountCredentialRecords, destinationAddresses: store.suggestedDestinationAddresses(for: profile), deliveryInstructions: store.suggestedDeliveryInstructions(for: profile), packageContents: store.suggestedPackageContents(for: profile)) { updatedProfile in
              store.updateVendorProfile(updatedProfile)
            } onToggle: {
              store.toggleVendorProfile(profile)
            } onReviewed: {
              store.markVendorProfileReviewed(profile)
            } onCreateTask: {
              store.createReviewTask(from: profile)
            } onCreateDraft: {
              store.createDraftMessage(from: profile)
            } onRemove: {
              store.removeVendorProfile(profile)
            }
          }
        }
          }
          .padding(.top, 8)
        } label: {
          NeedsReviewSectionHeader(
            title: "Advanced and reference backlog",
            detail: "Open this when you are deliberately reviewing support records such as profiles, costs, custody, labels, storage, and other admin/reference data.",
            count: advancedBacklogCount,
            symbol: "archivebox.fill",
            color: advancedBacklogCount == 0 ? .green : .secondary
          )
        }
        .tint(.primary)
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private func linkedOrder(for activity: TimelineActivity) -> TrackedOrder? {
    guard activity.entityType == .order, let id = UUID(uuidString: activity.entityID) else { return nil }
    return store.orders.first { $0.id == id }
  }

  private func linkedOrder(for draft: DraftMessage) -> TrackedOrder? {
    guard draft.linkedEntityType == .order, let id = UUID(uuidString: draft.linkedEntityID) else { return nil }
    return store.orders.first { $0.id == id }
  }

  private func linkedOrder(for issue: ValidationIssue) -> TrackedOrder? {
    guard issue.entityType == .order || issue.linkedEntityType == .order,
          let id = UUID(uuidString: issue.entityID) else { return nil }
    return store.orders.first { $0.id == id }
  }

  private func linkedOrder(for issue: ReconciliationIssue) -> TrackedOrder? {
    let orderID: String?
    if issue.sourceEntityType == .order {
      orderID = issue.sourceEntityID
    } else if issue.targetEntityType == .order {
      orderID = issue.targetEntityID
    } else {
      orderID = nil
    }
    guard let orderID, let id = UUID(uuidString: orderID) else { return nil }
    return store.orders.first { $0.id == id }
  }

  private func linkedOrders(for record: ShipmentManifestRecord) -> [TrackedOrder] {
    var ids = record.includedOrderIDs
    if record.linkedEntityType == .order, let id = UUID(uuidString: record.linkedEntityID) {
      ids.append(id)
    }
    let uniqueIDs = ids.reduce(into: [UUID]()) { result, id in
      if !result.contains(id) { result.append(id) }
    }
    return uniqueIDs.compactMap { id in
      store.orders.first { $0.id == id }
    }
  }

  private func linkedOrders(for checklist: DispatchReadinessChecklist) -> [TrackedOrder] {
    var ids = checklist.orderIDs
    if checklist.linkedEntityType == .order, let id = UUID(uuidString: checklist.linkedEntityID) {
      ids.append(id)
    }
    let uniqueIDs = ids.reduce(into: [UUID]()) { result, id in
      if !result.contains(id) { result.append(id) }
    }
    return uniqueIDs.compactMap { id in
      store.orders.first { $0.id == id }
    }
  }
}

private struct NeedsReviewSectionHeader: View {
  var title: String
  var detail: String
  var count: Int
  var symbol: String
  var color: Color

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: symbol)
        .foregroundStyle(color)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)
        Text(detail)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer()
      Badge("\(count)", color: color)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.16)))
  }
}

private struct NeedsReviewInboxOrderRow: View {
  var order: TrackedOrder
  var store: ParcelOpsStore
  @State private var isEditing = false
  @State private var feedbackMessage: String?

  private var linkedTasks: [ReviewTask] {
    store.tasks(for: .order, linkedEntityID: order.id.uuidString)
  }

  private var linkedManifests: [ShipmentManifestRecord] {
    store.suggestedShipmentManifestRecords(for: order)
  }

  private var linkedChecklists: [DispatchReadinessChecklist] {
    store.suggestedDispatchReadinessChecklists(for: order)
  }

  private var warningTrackingEvents: [CarrierTrackingEvent] {
    store.trackingEvents(for: order.id).filter { event in
      event.severity == .watch || event.severity == .critical
    }
  }

  private var missingTracking: Bool {
    order.trackingNumber == "Pending" || order.trackingNumber.isPlaceholderValidationValue
  }

  private var missingDestination: Bool {
    order.destination == "Pending review" || order.destination.isPlaceholderValidationValue
  }

  private var missingFieldCount: Int {
    [order.orderNumber, order.trackingNumber, order.destination]
      .filter { value in
        value == "Pending" || value == "Pending review" || value.isPlaceholderValidationValue
      }
      .count
  }

  private var inboxDispatchContextCount: Int {
    linkedManifests.filter(\.needsReviewInboxHandoffSetup).count
      + linkedChecklists.filter(\.needsReviewInboxHandoffSetup).count
  }

  private var reopenedInboxDispatchCount: Int {
    linkedManifests.filter { $0.needsReviewInboxHandoffSetup && $0.dispatchStatus == .reopened }.count
      + linkedChecklists.filter { $0.needsReviewInboxHandoffSetup && $0.checklistStatus == .reopened }.count
  }

  private var operationalTimelineSignalCount: Int {
    1
      + 1
      + linkedTasks.count
      + linkedManifests.count
      + linkedChecklists.count
      + warningTrackingEvents.count
  }

  private var nextActionText: String {
    if reopenedInboxDispatchCount > 0 {
      return "Next: review reopened dispatch handoff before closing this order."
    }
    if missingFieldCount > 0 {
      return "Next: confirm missing order, tracking, or destination details."
    }
    if inboxDispatchContextCount == 0 && [.shipped, .inTransit, .exception].contains(order.status) {
      return "Next: add or link dispatch setup before treating this order as ready."
    }
    if !linkedTasks.isEmpty {
      return "Next: finish linked task follow-up, then mark the order reviewed."
    }
    return "Next: confirm linked context, then mark reviewed or create follow-up."
  }

  private var timelineDetail: String {
    if reopenedInboxDispatchCount > 0 {
      return "Timeline includes reopened dispatch handoff context."
    }
    if missingFieldCount > 0 {
      return "Timeline includes Inbox handoff and missing-detail review."
    }
    if inboxDispatchContextCount > 0 {
      return "Timeline links Inbox handoff, order detail, and dispatch setup."
    }
    if !linkedTasks.isEmpty {
      return "Timeline includes \(linkedTasks.count) linked task signal."
    }
    if !warningTrackingEvents.isEmpty {
      return "Timeline includes \(warningTrackingEvents.count) tracking warning signal."
    }
    return "Timeline links the Inbox source trail to this order."
  }

  private var rowTint: Color {
    if reopenedInboxDispatchCount > 0 { return .purple }
    if missingFieldCount > 0 { return .orange }
    if !warningTrackingEvents.isEmpty { return .red }
    return .teal
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "shippingbox.fill")
          .foregroundStyle(rowTint)
          .frame(width: 22)

        VStack(alignment: .leading, spacing: 4) {
          Text("\(order.store) \(order.orderNumber)")
            .font(.headline)
          Text("\(order.customer) • \(order.destination)")
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Text(nextActionText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(rowTint)
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 6) {
          Badge(order.status.rawValue, color: order.status.color)
          Badge(order.reviewState.rawValue, color: order.reviewState.color)
          if operationalTimelineSignalCount > 1 {
            Badge("\(operationalTimelineSignalCount) timeline", color: rowTint)
          }
          if reopenedInboxDispatchCount > 0 {
            Badge("Reopened", color: .purple)
          }
        }
      }

      CompactMetadataGrid {
        Label(missingTracking ? "Tracking needs check" : order.trackingNumber, systemImage: "barcode.viewfinder")
        Label(missingDestination ? "Destination needs check" : order.destination, systemImage: "mappin.and.ellipse")
        Label(order.carrier, systemImage: "truck.box.fill")
        Label(order.latestStatus, systemImage: "waveform.path.ecg")
        if inboxDispatchContextCount > 0 {
          Label("\(inboxDispatchContextCount) dispatch setup", systemImage: "shippingbox.and.arrow.backward.fill")
        }
        if !linkedTasks.isEmpty {
          Label("\(linkedTasks.count) linked task", systemImage: "checklist")
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      if operationalTimelineSignalCount > 1 {
        Label(timelineDetail, systemImage: "calendar.badge.clock")
          .font(.caption)
          .foregroundStyle(rowTint)
          .fixedSize(horizontal: false, vertical: true)
      }

      CompactActionRow {
        NavigationLink {
          OrderDetailView(order: order, store: store)
        } label: {
          Label("Open order", systemImage: "arrow.up.right.square.fill")
        }
        .buttonStyle(.bordered)

        Button("Edit", systemImage: "pencil") {
          isEditing = true
        }
        .buttonStyle(.bordered)

        Button("Task", systemImage: "checklist") {
          store.createReviewTask(from: order)
          feedbackMessage = "Review task created."
        }
        .buttonStyle(.bordered)

        Button("Draft", systemImage: "envelope.open.fill") {
          store.createDraftMessage(from: order)
          feedbackMessage = "Draft created."
        }
        .buttonStyle(.bordered)

        Button("Reviewed", systemImage: "checkmark.circle.fill") {
          var reviewedOrder = order
          reviewedOrder.reviewState = .accepted
          store.updateOrder(reviewedOrder)
          feedbackMessage = "Order marked reviewed."
        }
        .buttonStyle(.bordered)
      }

      if let feedbackMessage {
        Text(feedbackMessage)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
    }
    .padding(12)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      OrderEditView(order: order) { updatedOrder in
        store.updateOrder(updatedOrder)
      }
    }
  }
}

private extension ShipmentManifestRecord {
  var needsReviewInboxHandoffSetup: Bool {
    linkedEntityType == .order
      && (
        title.localizedCaseInsensitiveContains("Dispatch setup for")
          || manifestReferencePlaceholder.localizedCaseInsensitiveContains("INBOX-")
          || notes.localizedCaseInsensitiveContains("Inbox handoff")
      )
  }
}

private extension DispatchReadinessChecklist {
  var needsReviewInboxHandoffSetup: Bool {
    linkedEntityType == .order
      && (
        title.localizedCaseInsensitiveContains("Readiness for")
          || completedChecksSummary.localizedCaseInsensitiveContains("Inbox handoff")
          || missingRequirementsSummary.localizedCaseInsensitiveContains("handoff location")
      )
  }
}

struct ReviewOrderRow: View {
  var order: TrackedOrder
  var onSave: (TrackedOrder) -> Void
  var onClear: () -> Void
  var onDiscard: () -> Void
  var onCreateTask: () -> Void = {}
  var onCreateDraft: () -> Void = {}
  @State private var isEditing = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text("\(order.orderNumber) • \(order.store)")
            .font(.headline)
          Text("Recipient \(order.recipientEmail), checked in \(order.checkedMailbox)")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(order.latestStatus)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Badge(order.reviewState.rawValue, color: order.reviewState.color)
      }
      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Add to orders", systemImage: "checkmark.circle.fill", action: onClear)
          .buttonStyle(.borderedProminent)
        Button("Discard spam", systemImage: "trash", action: onDiscard)
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill", action: onCreateDraft)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      OrderEditView(order: order) { updatedOrder in
        onSave(updatedOrder)
      }
    }
  }
}

struct ReviewMailEventRow: View {
  var event: MailEvent
  var onClear: () -> Void
  var onDiscard: () -> Void
  var onCreateTask: () -> Void = {}

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(event.sender)
            .font(.headline)
          Text(event.summary)
            .foregroundStyle(.secondary)
          Text("Suggested match: \(event.matchedOrder)")
            .font(.caption.weight(.semibold))
        }
        Spacer()
        Badge(event.severity.rawValue, color: event.severity.color)
      }
      CompactActionRow {
        Button("Add to order", systemImage: "checkmark.circle.fill", action: onClear)
          .buttonStyle(.borderedProminent)
        Button("Discard spam", systemImage: "trash", action: onDiscard)
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
