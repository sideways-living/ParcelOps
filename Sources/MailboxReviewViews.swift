import SwiftUI

struct MailboxView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var intakeSearchText = ""
  @State private var showResolvedIntakeEmails = false

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
    store.spaceMailIntakeHealthSummaries.first
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

        MailboxReviewStartPanel(store: store)

        SpaceMailOperatorGuidanceStack(store: store)

        SettingsPanel(title: "SpaceMail IMAP setup", symbol: "server.rack") {
          Text("SpaceMail is the current mailbox provider path. Capture non-secret IMAP settings here, manage the password/app-password in Keychain, and keep mock refresh separate from the real manual refresh boundary.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Text("Do not enter passwords here. No password, app password, auth string, or Keychain item is stored in JSON or audit logs.")
            .font(.caption)
            .foregroundStyle(.secondary)
          CompactActionRow {
            Button("Add SpaceMail setup", systemImage: "plus", action: store.addSpaceMailIMAPConnectionPlaceholder)
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
            } onCreateShiftHandoff: {
              store.createSpaceMailShiftHandoffNote(for: connection)
            } onCreateShiftTask: {
              store.createSpaceMailShiftReviewTask(for: connection)
            } onRemove: {
              store.removeSpaceMailIMAPConnection(connection)
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
              ("Fetched", "\(latestSpaceMailSummary?.fetchedCount ?? 0)", .blue),
              ("Imported", "\(latestSpaceMailSummary?.importedCount ?? 0)", (latestSpaceMailSummary?.importedCount ?? 0) > 0 ? .green : .secondary),
              ("Duplicates", "\(latestSpaceMailSummary?.duplicateCount ?? 0)", (latestSpaceMailSummary?.duplicateCount ?? 0) > 0 ? .orange : .secondary),
              ("Filtered", "\(latestSpaceMailSummary?.filteredCount ?? 0)", (latestSpaceMailSummary?.filteredCount ?? 0) > 0 ? .teal : .secondary),
              ("Uncertain", "\(latestSpaceMailSummary?.pendingUncertainReviewCount ?? latestSpaceMailSummary?.uncertainCount ?? 0)", ((latestSpaceMailSummary?.pendingUncertainReviewCount ?? latestSpaceMailSummary?.uncertainCount ?? 0) > 0) ? .orange : .secondary)
            ])

            SpaceMailRefreshTrendCard(summary: store.spaceMailRefreshTrendSummary)

            Text("Trend rows summarize recent manual refreshes. Filtered mixed-mailbox messages are counted here but stay out of Inbox unless you explicitly promote or import them.")
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
            }
          }
        }

        SettingsPanel(title: "Microsoft 365 setup planning", symbol: "mail.stack.fill") {
          Text("Microsoft 365 remains available as an advanced option, but SpaceMail IMAP is the current provider path for this project.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Microsoft365SetupFlowGuide()
          CompactActionRow {
            Button("Add mailbox setup", systemImage: "plus", action: store.addMicrosoft365MailboxConnectionPlaceholder)
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
          Text("Import sample fetched mailbox messages through the same provider-neutral intake path. No mailbox is contacted.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          CompactActionRow {
            Button("Import sample messages", systemImage: "envelope.badge.fill") {
              store.importSimulatedFetchedMailboxMessages()
            }
            .buttonStyle(.borderedProminent)
            Badge("\(store.mailboxIngestRecords.count) ingest records", color: .blue)
          }
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
            MVPEmptyState(title: "No forwarded emails yet", detail: "Run a SpaceMail refresh or import sample messages to populate the mailbox review flow.", symbol: "envelope.badge")
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

private struct MailboxReviewStartPanel: View {
  var store: ParcelOpsStore

  private var latestSummary: SpaceMailIntakeHealthSummary? {
    store.spaceMailIntakeHealthSummaries.first
  }

  private var reviewEmailCount: Int {
    store.reviewIntakeEmails.count
  }

  private var parserIssueCount: Int {
    store.intakeParserDiagnostics.count
  }

  private var uncertainCount: Int {
    store.spaceMailIMAPConnections.reduce(0) { $0 + $1.uncertainMessages.count }
  }

  private var tone: Color {
    if parserIssueCount > 0 || uncertainCount > 0 { return .orange }
    if reviewEmailCount > 0 { return .teal }
    if latestSummary == nil { return .orange }
    return .green
  }

  private var title: String {
    if parserIssueCount > 0 { return "Start with parser checks" }
    if uncertainCount > 0 { return "Review uncertain SpaceMail messages" }
    if reviewEmailCount > 0 { return "Review imported order emails" }
    if latestSummary == nil { return "Set up SpaceMail before real intake" }
    return "Mailbox review is clear"
  }

  private var detail: String {
    if parserIssueCount > 0 {
      return "Parser checks mean a captured message still has weak order, tracking, merchant, or destination evidence. Reprocess or edit before creating orders."
    }
    if uncertainCount > 0 {
      return "Uncertain messages are held out of Inbox. Import only if the subject and preview look order-related; otherwise dismiss or add classifier hints."
    }
    if reviewEmailCount > 0 {
      return "Work the detected order emails below. Confirm fields, then create/link orders, mark reviewed, ignore, task, or draft."
    }
    if latestSummary == nil {
      return "Add SpaceMail setup, confirm host/folder, save the Keychain credential, then run one manual read-only refresh."
    }
    return "Latest mailbox activity has no immediate review rows. Use setup details only when tuning SpaceMail or investigating Audit evidence."
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
        ("Fetched", "\(latestSummary?.fetchedCount ?? 0)", .blue),
        ("Imported", "\(latestSummary?.importedCount ?? 0)", (latestSummary?.importedCount ?? 0) > 0 ? .green : .secondary),
        ("Filtered", "\(latestSummary?.filteredCount ?? 0)", (latestSummary?.filteredCount ?? 0) > 0 ? .teal : .secondary),
        ("Uncertain", "\(uncertainCount)", uncertainCount == 0 ? .green : .orange),
        ("Parser", "\(parserIssueCount)", parserIssueCount == 0 ? .green : .orange),
        ("Review rows", "\(reviewEmailCount)", reviewEmailCount == 0 ? .green : .teal)
      ])

      Text("Filtered mixed-mailbox messages are not imported into Inbox. Setup controls below are for configuration and diagnostics; the review queue is the operational work.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
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
  private var showsMixedMailboxReview: Bool { matchesReviewSection("spacemail", "mixed", "mailbox", "uncertain", "filtered") }
  private var showsForwardedEmails: Bool { matchesReviewSection("forwarded", "emails", "intake", "mailbox", "order") }
  private var showsEvidence: Bool { matchesReviewSection("evidence", "attachments", "paperclip") }
  private var showsTrackingEvents: Bool { matchesReviewSection("tracking", "carrier", "events", "shipment") }
  private var showsTaskEscalations: Bool { matchesReviewSection("task", "escalations", "review tasks", "follow-up") }
  private var showsHandoffNotes: Bool { matchesReviewSection("handoff", "notes", "shift", "assigned") }

  private var visiblePrimaryReviewSectionCount: Int {
    [
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
      + store.spaceMailIMAPConnections.reduce(0) { $0 + $1.uncertainMessages.count }
      + store.reviewIntakeEmails.count
      + store.reviewEvidenceAttachments.count
      + store.reviewCarrierTrackingEvents.count
      + store.reviewTasksNeedingAttention.count
      + store.handoffNotesNeedingAttention.count
      + store.draftMessagesNeedingReview.count
      + store.blockedShipmentManifests.count
      + store.blockedDispatchChecklists.count
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
          MVPEmptyState(title: "No review sections match", detail: "Clear the review search or try Inbox, Workbench, validation, tracking, tasks, handoff, SpaceMail, import, acceptance, evidence, or dispatch.", symbol: "magnifyingglass")
        }

        NeedsReviewSectionHeader(
          title: "Primary daily review",
          detail: "Use these sections for intake, order handoff, dispatch blockers, task follow-up, and the highest-priority operational exceptions.",
          count: dailyAttentionCount,
          symbol: "tray.full.fill",
          color: dailyAttentionCount == 0 ? .green : .orange
        )

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
          SettingsPanel(title: "SpaceMail mixed-mailbox review", symbol: "questionmark.folder.fill") {
            Text("These previews were held out of the primary Inbox by the mixed-mailbox filter. Import only true order/order-update messages; dismiss local false positives without changing the mailbox.")
              .font(.caption)
              .foregroundStyle(.secondary)

            if store.spaceMailIMAPConnections.isEmpty {
              MVPEmptyState(
                title: "No SpaceMail setup exists",
                detail: "Add a SpaceMail IMAP setup before mixed-mailbox review can show uncertain or filtered examples.",
                symbol: "server.rack"
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
            }
          }
        }

        if showsForwardedEmails {
          SettingsPanel(title: "Forwarded emails", symbol: "envelope.open.fill") {
            if store.reviewIntakeEmails.isEmpty {
              MVPEmptyState(title: "No forwarded emails need review", detail: "Order-related messages imported from SpaceMail or simulated intake will appear here until reviewed, linked, ignored, or converted into an order.", symbol: "envelope.open.fill")
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
