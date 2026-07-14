import SwiftUI

struct MVPSetupView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isCompact: Bool { horizontalSizeClass == .compact }
  private var statusColumns: [GridItem] {
    Array(repeating: GridItem(.flexible(), spacing: 12), count: isCompact ? 1 : 2)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        MVPUsableVersionPanel(store: store)
        MVPDevelopmentProgressPanel(store: store)
        MVPRemainingWorkPanel(store: store)
        MVPCompletionRoadmapPanel(store: store)
        MVPDevelopmentStatusPanel(store: store)
        MVPMailboxProviderStatusPanel(store: store)
        if !store.gmailMailboxConnections.isEmpty {
          GmailReleaseBoundaryPanel(
            store: store,
            title: "Gmail MVP readiness",
            lead: "Use this when a mailbox is hosted by Gmail or Google Workspace. It checks saved setup, callback values, sign-in state, manual refresh evidence, classifier review, Inbox handoff, and Audit evidence before Gmail becomes a daily intake path.",
            sourceMetricTitle: "Gmail summaries",
            sourceCount: store.gmailIntakeHealthSummaries.count,
            boundaryDetail: "MVP boundary: this panel reads local Gmail readiness only. It does not start Google sign-in, fetch Gmail, store token values, mutate mailbox messages, or create hidden workflow actions.",
            showTasksLink: false
          )
        }
        MVPMailboxProviderReleasePanel(store: store)
        MVPNextDevelopmentPrioritiesPanel(store: store)
        MVPWishlistWorkflowReadinessPanel(store: store)
        OperatorMVPReadinessCard(store: store)
        OperatorSupportSnapshotCard(store: store, detail: "Use this snapshot to confirm setup, mailbox intake, source trails, and audit state before deeper QA.")
        OperatorTestSessionChecklistCard(store: store, detail: "Use this evidence checklist for one complete hands-on MVP validation pass.")
        OperatorHandoffBriefCard(store: store, detail: "Use this before handing testing or operation to another person.")

        MVPWorkflowGuide(
          title: "First usable workflow",
          detail: "Use this path to test the current manual mailbox operator workflow end to end. Active mailbox providers are the manual intake paths; Microsoft 365 remains available as an advanced provider path.",
          steps: [
            "Confirm the relevant mailbox setup: SpaceMail IMAP with Keychain credential, or Gmail sign-in and labels.",
            "Run one explicit manual read-only refresh for the selected provider.",
            "Use Inbox or Mailbox Monitor to review imported, uncertain, filtered, duplicate, and parser results.",
            "Create or link one order from a confirmed intake row.",
            "Use Orders and Workbench to verify the source trail, tracking, destination, and follow-up.",
            "Use Dispatch, Tasks, and Audit to confirm handoff readiness and traceability."
          ]
        )

        MVPHandsOnReleaseChecklist(store: store)
        MVPReleaseCandidateQACard(store: store)
        MVPReleaseEvidenceReport(store: store)
        MVPReleaseRunbook(store: store)
        MVPHandsOnTroubleshootingGuide(store: store)

        SpaceMailOperatorGuidanceStack(store: store)

        LocalDataHygieneSummaryCard(
          store: store,
          title: "Pre-test data hygiene",
          detail: "Check whether old mailbox/parser experiments are adding noise before running a new hands-on MVP pass."
        )
        ActiveOperatorQueueFocusCard(store: store)
        PrimaryRouteShortcutGuideCard()
        RecentOperatorImprovementsCard()
        LocalDataSafetyCard(store: store, compact: isCompact)

        LazyVGrid(columns: statusColumns, spacing: 12) {
          MVPStatusCard(title: "Local data store", detail: "Orders, intake, review work, manifests, tasks, and audit events are persisted as local JSON.", status: "Available", symbol: "internaldrive.fill", color: .green)
          MVPStatusCard(title: "Manual operations", detail: "You can create, edit, review, link, and remove local operational records.", status: "Available", symbol: "hand.tap.fill", color: .green)
          MVPStatusCard(title: "SpaceMail intake", detail: "SpaceMail IMAP can run a manual read-only refresh, filter mixed mailbox mail, and import likely order messages into local Inbox review.", status: "Manual", symbol: "envelope.badge.fill", color: .green)
          MVPStatusCard(title: "Gmail intake", detail: "Gmail can use readiness checks, explicit sign-in, and manual read-only refresh for Google-hosted mailboxes, with mock refresh still available for local testing.", status: "Manual", symbol: "envelope.open.fill", color: .green)
          MVPStatusCard(title: "Microsoft 365", detail: "Microsoft 365 setup, sign-in, and Graph diagnostics remain available, but it is no longer the primary mailbox path for this MVP.", status: "Advanced", symbol: "building.2.crop.circle", color: .teal)
          MVPStatusCard(title: "Wishlist", detail: "Wishlist supports local manual capture, comparison planning, seller trust notes, purchase handoff, and order-watch records. Agent research and browser extension capture remain planning/local handoff work.", status: "Local", symbol: "star.square.fill", color: .purple)
          MVPStatusCard(title: "Shopify", detail: "Shopify records and account placeholders exist, but no Shopify API or OAuth flow is connected.", status: "Placeholder", symbol: "cart.badge.plus", color: .orange)
          MVPStatusCard(title: "Carrier tracking", detail: "Tracking events are local records only. Carrier APIs and live refresh are not connected.", status: "Placeholder", symbol: "location.fill.viewfinder", color: .orange)
          MVPStatusCard(title: "Store logins", detail: "Account records are placeholders only. No browser automation or credential sync is active.", status: "Placeholder", symbol: "key.horizontal.fill", color: .orange)
          MVPStatusCard(title: "Credential storage", detail: "SpaceMail passwords use Keychain and OAuth providers use their platform caches. Tokens, API keys, OAuth secrets, and mailbox credentials are not stored in JSON.", status: "Scoped", symbol: "lock.shield.fill", color: .green)
          MVPStatusCard(title: "Background work", detail: "No background sync, notifications, reminders, calendars, OCR, scanners, or file pickers are active.", status: "Not connected", symbol: "bell.slash.fill", color: .red)
        }

        SettingsPanel(title: "MVP health snapshot", symbol: "gauge.with.dots.needle.67percent") {
          MetricStrip(items: [
            ("Orders", "\(store.orders.count)", .blue),
            ("Review queue", "\(store.reviewQueueCount)", .orange),
            ("Open work", "\(store.openWorkbenchItems.count)", .teal),
            ("Audit events", "\(store.auditEvents.count)", .purple)
          ])

          Text("Use this pass to judge whether the workflow is understandable before connecting real systems. The best next product work is simplifying confusing screens, then connecting one real intake source.")
            .foregroundStyle(.secondary)
        }
      }
      .padding(isCompact ? 14 : 24)
    }
    .background(.background)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("MVP Setup")
        .font(isCompact ? .title.bold() : .largeTitle.bold())
      Text("ParcelOps is currently a local-first operations prototype. Use these screens to test the order intake, review, dispatch, task, and audit workflow before connecting live systems.")
        .foregroundStyle(.secondary)
    }
  }
}

struct MVPRemainingWorkPanel: View {
  var store: ParcelOpsStore

  private var hasManualMailboxRefreshEvidence: Bool {
    store.spaceMailIntakeHealthSummaries.contains { $0.fetchedCount > 0 || $0.importedCount > 0 || $0.filteredCount > 0 }
      || store.gmailIntakeHealthSummaries.contains { $0.fetchedCount > 0 || $0.importedCount > 0 || $0.filteredCount > 0 }
  }

  private var hasInboxToOrderHandoff: Bool {
    let linkedOrderIDs = Set(store.intakeEmails.compactMap(\.linkedOrderID))
    return store.orders.contains { order in
      linkedOrderIDs.contains(order.id)
        || order.source == .forwardedMailbox
        || order.checkedMailbox == "manual-import"
    }
  }

  private var hasWishlistWorkflow: Bool {
    store.wishlistItems.contains(where: store.isActiveWishlistItem)
      || !store.wishlistCaptureCandidates.isEmpty
      || !store.wishlistResearchRequests.isEmpty
  }

  private var wishlistNeedsHumanReviewCount: Int {
    let activeItems = store.wishlistItems.filter(store.isActiveWishlistItem)
    let stagedCaptureCount = store.wishlistCaptureCandidates.filter { $0.reviewState != .accepted }.count
    let researchScopeCount = store.wishlistResearchRequests.filter { store.isActiveWishlistResearchRequest($0) && !$0.agentBriefGaps.isEmpty }.count
    let orderWatchCount = store.wishlistOrderWatchRecords.filter(store.isActiveWishlistOrderWatchRecord).count
    let purchaseReadyCount = activeItems.filter {
      $0.status.localizedCaseInsensitiveContains("ready")
        || ($0.purchaseReadiness ?? "").localizedCaseInsensitiveContains("ready")
    }.count
    return stagedCaptureCount + researchScopeCount + orderWatchCount + purchaseReadyCount
  }

  private var localFlowTone: Color {
    hasManualMailboxRefreshEvidence && hasInboxToOrderHandoff ? .green : .orange
  }

  private var localFlowStatus: String {
    hasManualMailboxRefreshEvidence && hasInboxToOrderHandoff ? "Usable" : "Prove once"
  }

  private var mailboxStatus: String {
    if hasManualMailboxRefreshEvidence { return "Manual path active" }
    if !store.spaceMailIMAPConnections.isEmpty || !store.gmailMailboxConnections.isEmpty { return "Setup exists" }
    return "Setup needed"
  }

  private var mailboxTone: Color {
    if hasManualMailboxRefreshEvidence { return .green }
    if !store.spaceMailIMAPConnections.isEmpty || !store.gmailMailboxConnections.isEmpty { return .orange }
    return .secondary
  }

  private var wishlistStatus: String {
    if !hasWishlistWorkflow { return "Optional" }
    if wishlistNeedsHumanReviewCount > 0 { return "Review \(wishlistNeedsHumanReviewCount)" }
    return "Ready"
  }

  private var wishlistTone: Color {
    if !hasWishlistWorkflow { return .secondary }
    return wishlistNeedsHumanReviewCount > 0 ? .purple : .green
  }

  private var nextBestAction: String {
    if !hasManualMailboxRefreshEvidence {
      return "Run one manual read-only SpaceMail or Gmail refresh, then check the summary before adding more integrations."
    }
    if !hasInboxToOrderHandoff {
      return "Create or link one order from a confirmed Inbox row and verify its source trail."
    }
    if wishlistNeedsHumanReviewCount > 0 {
      return "Review the active Wishlist capture, research, purchase, or order-watch items before treating Wishlist as routine."
    }
    return "Run a focused hands-on QA pass and record only issues that block normal operator use."
  }

  var body: some View {
    SettingsPanel(title: "Remaining work by area", symbol: "map.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: localFlowStatus == "Usable" ? "checkmark.seal.fill" : "checklist")
            .foregroundStyle(localFlowTone)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(localFlowStatus == "Usable" ? "Core workflow is usable; hardening remains" : "Prove the live intake-to-order path once")
              .font(.headline)
            Text("This panel is the short answer to where development stands: the local app is largely built, but each real provider and Wishlist path still needs focused QA before it should be treated as routine.")
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Badge(localFlowStatus, color: localFlowTone)
        }

        MetricStrip(items: [
          ("Core flow", localFlowStatus, localFlowTone),
          ("Mailbox", mailboxStatus, mailboxTone),
          ("Inbox orders", hasInboxToOrderHandoff ? "Linked" : "Needed", hasInboxToOrderHandoff ? .green : .orange),
          ("Wishlist", wishlistStatus, wishlistTone),
          ("External APIs", "Later", .secondary)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], alignment: .leading, spacing: 10) {
          remainingWorkBlock(
            title: "Daily operator MVP",
            detail: hasInboxToOrderHandoff
              ? "Dashboard, Inbox, Orders, Workbench, Dispatch, Tasks, Audit, and Settings have a usable local path. Remaining work is QA, copy/layout polish, and clearing old test noise."
              : "The UI and records exist. The next proof point is one confirmed Inbox row becoming a linked order with a visible source trail.",
            status: hasInboxToOrderHandoff ? "Mostly built" : "Needs proof",
            symbol: "square.grid.2x2.fill",
            color: hasInboxToOrderHandoff ? .green : .orange
          )
          remainingWorkBlock(
            title: "Mailbox intake",
            detail: hasManualMailboxRefreshEvidence
              ? "Manual read-only intake has evidence. Keep hardening parser/classifier edge cases before adding background sync or more mailbox automation."
              : "Provider setup exists only when SpaceMail or Gmail is configured. Prove one manual read-only refresh before relying on live intake.",
            status: mailboxStatus,
            symbol: "tray.and.arrow.down.fill",
            color: mailboxTone
          )
          remainingWorkBlock(
            title: "Wishlist purchasing",
            detail: hasWishlistWorkflow
              ? "Manual capture, staged browser-extension candidates, comparison planning, purchase handoff, and order-watch records exist locally. Agent research, live retailer comparison, browser extension sync, checkout, and account monitoring are still not connected."
              : "Wishlist is available, but no active planning data is present yet. Start with manual capture or staged browser-extension candidates.",
            status: wishlistStatus,
            symbol: "star.square.fill",
            color: wishlistTone
          )
          remainingWorkBlock(
            title: "Post-MVP integrations",
            detail: "Shopify, carrier tracking APIs, outbound email, live price monitoring, trust-rating services, notifications, calendars, OCR, scanners, and background jobs should wait until the manual workflows are stable.",
            status: "Not next",
            symbol: "network.slash",
            color: .secondary
          )
        }

        Label(nextBestAction, systemImage: "arrow.forward.circle.fill")
          .font(.callout.weight(.semibold))
          .foregroundStyle(localFlowTone)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func remainingWorkBlock(title: String, detail: String, status: String, symbol: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        Label(title, systemImage: symbol)
          .font(.caption.weight(.semibold))
          .foregroundStyle(color)
        Spacer(minLength: 8)
        Badge(status, color: color)
      }
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

struct MVPMailboxProviderReleasePanel: View {
  var store: ParcelOpsStore

  private var releaseGate: MailboxProviderReleaseGateSummary {
    store.mailboxProviderReleaseGateSummary
  }

  private var handoffPacket: MailboxProviderHandoffPacketSummary {
    store.mailboxProviderHandoffPacketSummary
  }

  private var panelTone: Color {
    releaseGate.tone == "success" && handoffPacket.tone == "success" ? .green : .orange
  }

  private var panelStatus: String {
    releaseGate.tone == "success" && handoffPacket.tone == "success" ? "Ready" : "Review"
  }

  var body: some View {
    SettingsPanel(title: "Provider release and handoff", symbol: "checkmark.seal.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: panelStatus == "Ready" ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
            .foregroundStyle(panelTone)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(panelStatus == "Ready" ? "Mailbox provider handoff is ready" : "Review mailbox provider handoff before live testing")
              .font(.headline)
            Text("Use this setup checkpoint before relying on a mailbox provider as daily intake. It shows release gates, handoff notes, and follow-up actions without running mailbox refresh, reading credentials, or changing mailbox state.")
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Badge(panelStatus, color: panelTone)
        }

        MailboxProviderReleaseGateCard(summary: releaseGate, store: store)
        MailboxProviderHandoffPacketCard(packet: handoffPacket, store: store)
      }
    }
  }
}

struct MVPMailboxProviderStatusPanel: View {
  var store: ParcelOpsStore

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.spaceMailIntakeHealthSummaries.first
  }

  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.gmailIntakeHealthSummaries.first
  }

  private var hasSpaceMailSetup: Bool {
    !store.spaceMailIMAPConnections.isEmpty
  }

  private var hasSpaceMailCredential: Bool {
    store.spaceMailIMAPConnections.contains {
      $0.credentialStorageStatus.localizedCaseInsensitiveContains("available")
        || $0.credentialStorageStatus.localizedCaseInsensitiveContains("ready")
    }
  }

  private var hasGmailSetup: Bool {
    !store.gmailMailboxConnections.isEmpty
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

  private var hasGmailConnectedAuth: Bool {
    store.gmailMailboxConnections.contains { connection in
      store.gmailAuthSessionState(for: connection).status == .connected
    }
  }

  private var manualProviderReadyCount: Int {
    [hasSpaceMailSetup && hasSpaceMailCredential, hasGmailCoreSetup && hasGmailConnectedAuth].filter { $0 }.count
  }

  private var latestManualFetchCount: Int {
    max(latestSpaceMailSummary?.fetchedCount ?? 0, latestGmailSummary?.fetchedCount ?? 0)
  }

  private var statusTitle: String {
    if manualProviderReadyCount > 0 { return "Manual mailbox intake is ready for hands-on testing" }
    if hasSpaceMailSetup || hasGmailSetup { return "Mailbox setup exists; finish credentials or sign-in" }
    return "Add one manual mailbox provider before live intake testing"
  }

  private var statusDetail: String {
    if manualProviderReadyCount > 0 {
      return "Use SpaceMail for IMAP mailboxes and Gmail for Google-hosted mailboxes. Both paths are explicit, manual, read-only, mixed-mailbox aware, and route into the same Inbox triage flow."
    }
    if hasGmailSetup && !hasGmailConnectedAuth {
      return "Gmail setup exists, but real refresh needs readiness checks and the explicit Gmail sign-in test to succeed. Mock refresh remains available for local testing."
    }
    if hasSpaceMailSetup && !hasSpaceMailCredential {
      return "SpaceMail setup exists, but real refresh needs a Keychain password or app-password reference."
    }
    return "Start with SpaceMail if the mailbox is IMAP-based, or Gmail if the mailbox is Google-hosted. Microsoft 365 can stay in the advanced provider section."
  }

  private var statusTone: Color {
    manualProviderReadyCount > 0 ? .green : .orange
  }

  var body: some View {
    SettingsPanel(title: "Mailbox provider status", symbol: "tray.full.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: manualProviderReadyCount > 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
            .foregroundStyle(statusTone)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(statusTitle)
              .font(.headline)
            Text(statusDetail)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Badge(manualProviderReadyCount > 0 ? "Manual ready" : "Setup needed", color: statusTone)
        }

        MetricStrip(items: [
          ("SpaceMail", hasSpaceMailSetup ? (hasSpaceMailCredential ? "Ready" : "Credential") : "Not set", hasSpaceMailSetup && hasSpaceMailCredential ? .green : .orange),
          ("Gmail", hasGmailSetup ? (hasGmailConnectedAuth ? "Connected" : "Sign in") : "Not set", hasGmailSetup && hasGmailConnectedAuth ? .green : .orange),
          ("Last fetched", "\(latestManualFetchCount)", latestManualFetchCount > 0 ? .blue : .secondary),
          ("SpaceMail filtered", "\(latestSpaceMailSummary?.filteredCount ?? 0)", (latestSpaceMailSummary?.filteredCount ?? 0) > 0 ? .teal : .secondary),
          ("Gmail filtered", "\(latestGmailSummary?.filteredCount ?? 0)", (latestGmailSummary?.filteredCount ?? 0) > 0 ? .teal : .secondary),
          ("Microsoft 365", store.microsoft365MailboxConnections.isEmpty ? "Optional" : "Advanced", .teal)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], alignment: .leading, spacing: 10) {
          providerBlock(
            title: "SpaceMail IMAP",
            detail: latestSpaceMailSummary.map { "\($0.fetchedCount) fetched, \($0.importedCount) imported, \($0.duplicateRefreshedCount) refreshed, \($0.filteredCount) filtered, \($0.pendingUncertainReviewCount + $0.uncertainCount) uncertain. \($0.nextAction)" } ?? "Use for IMAP mailboxes. Real refresh is manual, read-only, and uses Keychain-backed credential status.",
            symbol: "server.rack",
            color: hasSpaceMailSetup && hasSpaceMailCredential ? .green : .orange
          )
          providerBlock(
            title: "Gmail",
            detail: latestGmailSummary.map { "\($0.fetchedCount) fetched, \($0.importedCount) imported, \($0.duplicateRefreshedCount) refreshed, \($0.filteredCount) filtered, \($0.pendingUncertainReviewCount + $0.uncertainCount) uncertain. \($0.nextAction)" } ?? "Use for Google-hosted mailboxes. Real refresh is manual and read-only after readiness checks and explicit sign-in; mock refresh remains available.",
            symbol: "envelope.open.fill",
            color: hasGmailSetup && hasGmailConnectedAuth ? .green : .orange
          )
          providerBlock(
            title: "Microsoft 365",
            detail: "Keep as an advanced provider path for tenants that use Microsoft mailboxes. It should not block the current mailbox-provider MVP test path.",
            symbol: "building.2.crop.circle",
            color: .teal
          )
        }

        CompactActionRow {
          NavigationLink {
            MailboxView(store: store)
          } label: {
            Label("Mailbox Monitor", systemImage: "server.rack")
          }
          NavigationLink {
            IntegrationsView(store: store)
          } label: {
            Label("Settings", systemImage: "gearshape.fill")
          }
          NavigationLink {
            InboxView(store: store)
          } label: {
            Label("Inbox", systemImage: "tray.full.fill")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private func providerBlock(title: String, detail: String, symbol: String, color: Color) -> some View {
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

struct MVPNextDevelopmentPrioritiesPanel: View {
  var store: ParcelOpsStore

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.spaceMailIntakeHealthSummaries.first
  }

  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.gmailIntakeHealthSummaries.first
  }

  private var hasSpaceMailSetup: Bool {
    !store.spaceMailIMAPConnections.isEmpty
  }

  private var hasSpaceMailCredential: Bool {
    store.spaceMailIMAPConnections.contains {
      $0.credentialStorageStatus.localizedCaseInsensitiveContains("available")
        || $0.credentialStorageStatus.localizedCaseInsensitiveContains("ready")
      }
  }

  private var hasGmailSetup: Bool {
    !store.gmailMailboxConnections.isEmpty
  }

  private var hasGmailConnectedAuth: Bool {
    store.gmailMailboxConnections.contains { connection in
      store.gmailAuthSessionState(for: connection).status == .connected
    }
  }

  private var hasManualMailboxSetup: Bool {
    hasSpaceMailSetup || hasGmailSetup
  }

  private var hasManualMailboxReady: Bool {
    (hasSpaceMailSetup && hasSpaceMailCredential) || (hasGmailSetup && hasGmailConnectedAuth)
  }

  private var hasLiveRefreshEvidence: Bool {
    (latestSpaceMailSummary?.fetchedCount ?? 0) > 0
      || (latestGmailSummary?.fetchedCount ?? 0) > 0
  }

  private var hasInboxOrderHandoff: Bool {
    let linkedOrderIDs = Set(store.intakeEmails.compactMap(\.linkedOrderID))
    return store.orders.contains { order in
      linkedOrderIDs.contains(order.id)
        || order.source == .forwardedMailbox
        || order.checkedMailbox == "manual-import"
    }
  }

  private var qaEvidenceReady: Bool {
    hasManualMailboxSetup && hasManualMailboxReady && hasLiveRefreshEvidence && hasInboxOrderHandoff && !store.auditEvents.isEmpty
  }

  private var currentPriorityTitle: String {
    if !hasManualMailboxSetup { return "Priority: choose the active mailbox provider" }
    if !hasManualMailboxReady { return "Priority: finish mailbox credential or sign-in" }
    if !hasLiveRefreshEvidence { return "Priority: capture one refresh result" }
    if !hasInboxOrderHandoff { return "Priority: prove Inbox-to-order handoff" }
    if !qaEvidenceReady { return "Priority: complete QA evidence" }
    return "Priority: simplify and harden the operator loop"
  }

  private var currentPriorityDetail: String {
    if !hasManualMailboxSetup {
      return "Add SpaceMail for IMAP mailboxes or Gmail for Google-hosted mailboxes. Keep Microsoft 365 as an advanced provider option unless a licensed Microsoft mailbox is available."
    }
    if !hasManualMailboxReady {
      return "Use Keychain-backed SpaceMail credential storage or the explicit Gmail sign-in test. Do not place passwords, tokens, client secrets, or auth details in JSON fields or setup notes."
    }
    if !hasLiveRefreshEvidence {
      return "Run one manual read-only refresh from the active provider so the app has real fetched/imported/filtered/uncertain evidence."
    }
    if !hasInboxOrderHandoff {
      return "Create or link one order from a confirmed Inbox row so Orders, Workbench, Dispatch, Tasks, and Audit have real context."
    }
    if !qaEvidenceReady {
      return "Complete one repeatable test pass and confirm the result survives quit/reopen through local JSON persistence."
    }
    return "The next highest-value work is reducing noisy screens, tightening parser/classifier edge cases, and documenting a repeatable QA baseline before adding more integrations."
  }

  private var priorityTone: Color {
    qaEvidenceReady ? .green : .orange
  }

  var body: some View {
    SettingsPanel(title: "Next development priorities", symbol: "list.bullet.rectangle.portrait.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: qaEvidenceReady ? "checkmark.seal.fill" : "arrow.forward.circle.fill")
            .foregroundStyle(priorityTone)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(currentPriorityTitle)
              .font(.headline)
            Text(currentPriorityDetail)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Badge(qaEvidenceReady ? "Post-MVP" : "MVP QA", color: priorityTone)
        }

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], alignment: .leading, spacing: 10) {
          priorityBlock(
            title: "1. Prove repeatability",
            detail: "Run the same local flow several times: SpaceMail or Gmail refresh, triage, create/link order, Workbench follow-up, Dispatch setup, task, Audit, quit/reopen.",
            symbol: "repeat.circle.fill",
            color: qaEvidenceReady ? .green : .orange
          )
          priorityBlock(
            title: "2. Reduce operator noise",
            detail: "Keep improving primary screens so operators see Dashboard, Inbox, Orders, Workbench, Dispatch, Tasks, Audit, and Settings rather than internal record tables.",
            symbol: "sidebar.left",
            color: .teal
          )
          priorityBlock(
            title: "3. Harden intake parsing",
            detail: "Use saved diagnostics, classifier tests, uncertain examples, and local hints to improve real mixed-mailbox intake for SpaceMail and Gmail without external AI or mailbox mutation.",
            symbol: "text.magnifyingglass",
            color: .purple
          )
          priorityBlock(
            title: "4. Defer broad integrations",
            detail: "Do not add Shopify, carrier APIs, notifications, OCR, scanners, calendars, outbound email, or background sync until the manual operator loop is boringly reliable.",
            symbol: "network.slash",
            color: .secondary
          )
        }

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

  private func priorityBlock(title: String, detail: String, symbol: String, color: Color) -> some View {
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

struct MVPWishlistWorkflowReadinessPanel: View {
  var store: ParcelOpsStore

  private var activeItems: [WishlistItem] {
    store.wishlistItems.filter(store.isActiveWishlistItem)
  }

  private var stagedCaptures: [WishlistCaptureCandidate] {
    store.wishlistCaptureCandidates.filter { $0.reviewState != .accepted }
  }

  private var activeResearchRequests: [WishlistResearchRequest] {
    store.wishlistResearchRequests.filter(store.isActiveWishlistResearchRequest)
  }

  private var agentReadyResearchRequests: [WishlistResearchRequest] {
    activeResearchRequests.filter(\.isAgentBriefReady)
  }

  private var blockedResearchRequests: [WishlistResearchRequest] {
    activeResearchRequests.filter { !$0.agentBriefGaps.isEmpty }
  }

  private var comparisonReadyItems: [WishlistItem] {
    activeItems.filter { item in
      (item.comparisonOptions ?? []).contains { option in
        option.productURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
          && option.estimatedAUDTotal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
          && option.postageTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
          && option.trustRating.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
      }
    }
  }

  private var readyForPurchaseItems: [WishlistItem] {
    activeItems.filter { item in
      item.status.localizedCaseInsensitiveContains("ready to purchase")
        || (item.purchaseReadiness ?? "").localizedCaseInsensitiveContains("ready")
    }
  }

  private var openOrderWatchRecords: [WishlistOrderWatchRecord] {
    store.wishlistOrderWatchRecords.filter {
      store.isActiveWishlistOrderWatchRecord($0)
        && !$0.watchStatus.localizedCaseInsensitiveContains("closed")
        && !$0.watchStatus.localizedCaseInsensitiveContains("matched")
    }
  }

  private var linkedWishlistOrderCount: Int {
    store.wishlistLinkedOrders.count
  }

  private var readinessTone: Color {
    if !stagedCaptures.isEmpty || !blockedResearchRequests.isEmpty { return .orange }
    if !readyForPurchaseItems.isEmpty || !agentReadyResearchRequests.isEmpty || !openOrderWatchRecords.isEmpty { return .purple }
    if !activeItems.isEmpty { return .teal }
    return .secondary
  }

  private var readinessTitle: String {
    if activeItems.isEmpty && stagedCaptures.isEmpty { return "Wishlist workflow is ready for first local capture" }
    if !stagedCaptures.isEmpty { return "Wishlist has staged captures to review" }
    if !blockedResearchRequests.isEmpty { return "Wishlist research scope needs cleanup" }
    if !agentReadyResearchRequests.isEmpty { return "Wishlist research briefs are agent-ready" }
    if !readyForPurchaseItems.isEmpty { return "Wishlist has purchase-ready items" }
    if !openOrderWatchRecords.isEmpty { return "Wishlist order watch is active" }
    return "Wishlist is ready for local comparison planning"
  }

  private var readinessDetail: String {
    if activeItems.isEmpty && stagedCaptures.isEmpty {
      return "Add a manual Wishlist item or stage a browser-extension placeholder, then prepare comparison criteria before any external research."
    }
    if !stagedCaptures.isEmpty {
      return "\(stagedCaptures.count) staged capture\(stagedCaptures.count == 1 ? "" : "s") need promotion or dismissal before they become purchase planning records."
    }
    if !blockedResearchRequests.isEmpty {
      return "\(blockedResearchRequests.count) research request\(blockedResearchRequests.count == 1 ? "" : "s") need item, source URL, budget, postage, or seller trust detail before agent research."
    }
    if !agentReadyResearchRequests.isEmpty {
      return "\(agentReadyResearchRequests.count) research brief\(agentReadyResearchRequests.count == 1 ? "" : "s") have enough local scope for an external comparison pass. ParcelOps still does not browse or buy automatically."
    }
    if !readyForPurchaseItems.isEmpty {
      return "\(readyForPurchaseItems.count) item\(readyForPurchaseItems.count == 1 ? "" : "s") look ready for manual purchase handoff. Confirm account, seller trust, postage timing, and order-watch expectations."
    }
    if !openOrderWatchRecords.isEmpty {
      return "\(openOrderWatchRecords.count) order-watch record\(openOrderWatchRecords.count == 1 ? "" : "s") should be checked against Inbox and Orders after purchase confirmation arrives."
    }
    return "\(activeItems.count) active Wishlist item\(activeItems.count == 1 ? "" : "s") can be scoped for comparison, seller trust review, purchase handoff, or order watch."
  }

  var body: some View {
    SettingsPanel(title: "Wishlist workflow readiness", symbol: "star.square.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: "star.square.fill")
            .foregroundStyle(readinessTone)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(readinessTitle)
              .font(.headline)
            Text(readinessDetail)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Badge(activeItems.isEmpty ? "Capture" : "Local workflow", color: readinessTone)
        }

        MetricStrip(items: [
          ("Active items", "\(activeItems.count)", activeItems.isEmpty ? .secondary : .purple),
          ("Staged", "\(stagedCaptures.count)", stagedCaptures.isEmpty ? .green : .orange),
          ("Agent-ready", "\(agentReadyResearchRequests.count)", agentReadyResearchRequests.isEmpty ? .secondary : .blue),
          ("Blocked scope", "\(blockedResearchRequests.count)", blockedResearchRequests.isEmpty ? .green : .orange),
          ("Compared", "\(comparisonReadyItems.count)", comparisonReadyItems.isEmpty ? .secondary : .teal),
          ("Order watch", "\(openOrderWatchRecords.count)", openOrderWatchRecords.isEmpty ? .secondary : .purple),
          ("Linked orders", "\(linkedWishlistOrderCount)", linkedWishlistOrderCount == 0 ? .secondary : .green)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 10)], alignment: .leading, spacing: 10) {
          wishlistBlock(
            title: "Capture stays local",
            detail: "Manual entry and browser-extension placeholders create local records only. No product page scraping, file picking, OCR, checkout, or retailer login runs from this MVP panel.",
            symbol: "hand.tap.fill",
            color: .teal
          )
          wishlistBlock(
            title: "Comparison needs evidence",
            detail: "Before purchase, confirm AUD total, postage cost/time, seller region, trust rating, and why weaker sellers were rejected.",
            symbol: "list.bullet.clipboard.fill",
            color: .purple
          )
          wishlistBlock(
            title: "Purchase handoff is manual",
            detail: "Ready means the operator can open the selected link outside ParcelOps, buy manually, then let Inbox/Orders watch for confirmation. ParcelOps does not purchase automatically.",
            symbol: "cart.badge.plus",
            color: .orange
          )
        }

        CompactActionRow {
          NavigationLink {
            WishlistView(store: store)
          } label: {
            Label("Wishlist", systemImage: "star.square.fill")
          }
          NavigationLink {
            OrdersView(store: store)
          } label: {
            Label("Orders", systemImage: "shippingbox.fill")
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

  private func wishlistBlock(title: String, detail: String, symbol: String, color: Color) -> some View {
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

struct MVPDevelopmentStatusPanel: View {
  var store: ParcelOpsStore

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.spaceMailIntakeHealthSummaries.first
  }

  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.gmailIntakeHealthSummaries.first
  }

  private var hasSpaceMailSetup: Bool {
    !store.spaceMailIMAPConnections.isEmpty
  }

  private var hasSpaceMailCredential: Bool {
    store.spaceMailIMAPConnections.contains {
      $0.credentialStorageStatus.localizedCaseInsensitiveContains("available")
        || $0.credentialStorageStatus.localizedCaseInsensitiveContains("ready")
    }
  }

  private var hasGmailSetup: Bool {
    !store.gmailMailboxConnections.isEmpty
  }

  private var hasGmailConnectedAuth: Bool {
    store.gmailMailboxConnections.contains { connection in
      store.gmailAuthSessionState(for: connection).status == .connected
    }
  }

  private var hasManualMailboxSetup: Bool {
    hasSpaceMailSetup || hasGmailSetup
  }

  private var hasManualMailboxReady: Bool {
    (hasSpaceMailSetup && hasSpaceMailCredential) || (hasGmailSetup && hasGmailConnectedAuth)
  }

  private var hasRealRefreshEvidence: Bool {
    (latestSpaceMailSummary?.fetchedCount ?? 0) > 0
      || (latestGmailSummary?.fetchedCount ?? 0) > 0
  }

  private var latestManualFetchedCount: Int {
    max(latestSpaceMailSummary?.fetchedCount ?? 0, latestGmailSummary?.fetchedCount ?? 0)
  }

  private var latestManualImportedCount: Int {
    (latestSpaceMailSummary?.importedCount ?? 0) + (latestGmailSummary?.importedCount ?? 0)
  }

  private var hasInboxOrderHandoff: Bool {
    let linkedOrderIDs = Set(store.intakeEmails.compactMap(\.linkedOrderID))
    return store.orders.contains { order in
      linkedOrderIDs.contains(order.id)
        || order.source == .forwardedMailbox
        || order.checkedMailbox == "manual-import"
    }
  }

  private var liveCapabilityCount: Int {
    [
      true,
      hasManualMailboxSetup,
      hasManualMailboxReady,
      hasRealRefreshEvidence,
      hasInboxOrderHandoff,
      !store.auditEvents.isEmpty
    ].filter { $0 }.count
  }

  private var maturityTitle: String {
    if liveCapabilityCount >= 5 { return "MVP is usable for supervised daily-flow testing" }
    if liveCapabilityCount >= 3 { return "MVP is usable, but needs a complete hands-on pass" }
    return "MVP shell is usable, live intake setup still needs work"
  }

  private var maturityDetail: String {
    if liveCapabilityCount >= 5 {
      return "The app now has local persistence, manual mailbox-provider intake, mixed-mailbox filtering, Inbox triage, order handoff, Tasks, Dispatch context, Audit, and Settings. The next work should be QA, simplification, and specific gaps found during use."
    }
    if liveCapabilityCount >= 3 {
      return "The main local workflow is present. Run one complete mailbox-to-Inbox-to-Order-to-Audit pass before treating it as operator-ready."
    }
    return "Navigation, local records, and persistence are in place. Finish either SpaceMail credential setup or Gmail sign-in, then run one manual refresh before judging the live intake workflow."
  }

  private var maturityColor: Color {
    if liveCapabilityCount >= 5 { return .green }
    if liveCapabilityCount >= 3 { return .teal }
    return .orange
  }

  var body: some View {
    SettingsPanel(title: "Development status", symbol: "chart.line.uptrend.xyaxis") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: liveCapabilityCount >= 5 ? "checkmark.seal.fill" : "hammer.fill")
            .foregroundStyle(maturityColor)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(maturityTitle)
              .font(.headline)
            Text(maturityDetail)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Badge("\(liveCapabilityCount)/6 signals", color: maturityColor)
        }

        MetricStrip(items: [
          ("Mailbox setup", hasManualMailboxSetup ? "Set" : "Needed", hasManualMailboxSetup ? .green : .orange),
          ("Manual auth", hasManualMailboxReady ? "Ready" : "Needed", hasManualMailboxReady ? .green : .orange),
          ("Fetched", "\(latestManualFetchedCount)", hasRealRefreshEvidence ? .blue : .secondary),
          ("Imported", "\(latestManualImportedCount)", latestManualImportedCount > 0 ? .green : .secondary),
          ("Inbox orders", hasInboxOrderHandoff ? "Seen" : "Needed", hasInboxOrderHandoff ? .green : .orange),
          ("Audit", "\(store.auditEvents.count)", store.auditEvents.isEmpty ? .orange : .purple)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 10)], alignment: .leading, spacing: 10) {
          statusBlock(
            title: "Usable now",
            detail: "Local JSON persistence, primary navigation, manual mailbox refresh boundaries, mixed-mailbox filtering, Inbox triage, local order handoff, Tasks, Dispatch context, Audit, and Settings.",
            symbol: "checkmark.circle.fill",
            color: .green
          )
          statusBlock(
            title: "Needs QA evidence",
            detail: "One repeatable pass through a manual mailbox refresh, uncertain/filtered review, create or link order, Workbench follow-up, Dispatch setup, Task completion, Audit, quit and reopen.",
            symbol: "checklist.checked",
            color: .orange
          )
          statusBlock(
            title: "Later integrations",
            detail: "Shopify, carrier APIs, outbound email, background sync, notifications, OCR, scanners, calendars, and file pickers remain intentionally disconnected.",
            symbol: "network.slash",
            color: .secondary
          )
        }

        CompactActionRow {
          NavigationLink {
            DashboardView(store: store)
          } label: {
            Label("Dashboard", systemImage: "square.grid.2x2.fill")
          }
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
            OrdersView(store: store)
          } label: {
            Label("Orders", systemImage: "shippingbox.fill")
          }
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private func statusBlock(title: String, detail: String, symbol: String, color: Color) -> some View {
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

struct MVPUsableVersionPanel: View {
  var store: ParcelOpsStore

  private var hasSpaceMailSetup: Bool {
    !store.spaceMailIMAPConnections.isEmpty
  }

  private var hasSpaceMailCredential: Bool {
    store.spaceMailIMAPConnections.contains {
      $0.credentialStorageStatus.localizedCaseInsensitiveContains("available")
        || $0.credentialStorageStatus.localizedCaseInsensitiveContains("ready")
    }
  }

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.spaceMailIntakeHealthSummaries.first
  }

  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.gmailIntakeHealthSummaries.first
  }

  private var hasGmailSetup: Bool {
    !store.gmailMailboxConnections.isEmpty
  }

  private var hasGmailConnectedAuth: Bool {
    store.gmailMailboxConnections.contains { connection in
      store.gmailAuthSessionState(for: connection).status == .connected
    }
  }

  private var hasManualMailboxSetup: Bool {
    hasSpaceMailSetup || hasGmailSetup
  }

  private var hasManualMailboxReady: Bool {
    (hasSpaceMailSetup && hasSpaceMailCredential) || (hasGmailSetup && hasGmailConnectedAuth)
  }

  private var latestManualFetchedCount: Int {
    max(latestSpaceMailSummary?.fetchedCount ?? 0, latestGmailSummary?.fetchedCount ?? 0)
  }

  private var latestManualImportedCount: Int {
    (latestSpaceMailSummary?.importedCount ?? 0) + (latestGmailSummary?.importedCount ?? 0)
  }

  private var inboxOrderCount: Int {
    let linkedOrderIDs = Set(store.intakeEmails.compactMap(\.linkedOrderID))
    return store.orders.filter { order in
      linkedOrderIDs.contains(order.id)
        || order.source == .forwardedMailbox
        || order.checkedMailbox == "manual-import"
    }.count
  }

  private var operatorWorkCount: Int {
    store.reviewQueueCount + store.openWorkbenchItems.count + store.reviewTasksNeedingAttention.count
  }

  private var readinessTitle: String {
    if !hasManualMailboxSetup { return "Usable locally, mailbox setup still needed" }
    if !hasManualMailboxReady { return "Usable locally, mailbox credential or sign-in needed" }
    if inboxOrderCount == 0 { return "Ready for a supervised Inbox-to-order test" }
    if operatorWorkCount > 0 { return "Usable for hands-on operator testing" }
    return "Primary MVP path is usable"
  }

  private var readinessDetail: String {
    if !hasManualMailboxSetup {
      return "The local records, navigation, Tasks, Audit, and Settings flows are usable. Add SpaceMail for IMAP mailboxes or Gmail for Google-hosted mailboxes before relying on live mailbox intake."
    }
    if !hasManualMailboxReady {
      return "The mailbox setup exists, but real manual refresh still needs either a SpaceMail Keychain credential or a connected Gmail sign-in."
    }
    if inboxOrderCount == 0 {
      return "Run a manual mailbox refresh, review one imported intake row, then create or link an order to prove the daily flow."
    }
    return "The main daily flow now covers mailbox intake, Inbox triage, order handoff, Workbench follow-up, Tasks, Dispatch context, Audit, and local Settings."
  }

  private var readinessColor: Color {
    if !hasManualMailboxSetup || !hasManualMailboxReady { return .orange }
    if inboxOrderCount == 0 { return .teal }
    return .green
  }

  var body: some View {
    SettingsPanel(title: "Usable version status", symbol: "checkmark.seal.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: "checkmark.seal.fill")
            .foregroundStyle(readinessColor)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(readinessTitle)
              .font(.headline)
            Text(readinessDetail)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Badge(inboxOrderCount > 0 ? "Hands-on" : "Setup", color: readinessColor)
        }

        MetricStrip(items: [
          ("Mailbox", hasManualMailboxSetup ? "Set" : "Needed", hasManualMailboxSetup ? .green : .orange),
          ("Auth", hasManualMailboxReady ? "Ready" : "Needed", hasManualMailboxReady ? .green : .orange),
          ("Last fetched", "\(latestManualFetchedCount)", latestManualFetchedCount > 0 ? .blue : .secondary),
          ("Imported", "\(latestManualImportedCount)", latestManualImportedCount > 0 ? .green : .secondary),
          ("Inbox orders", "\(inboxOrderCount)", inboxOrderCount > 0 ? .green : .orange),
          ("Open review", "\(operatorWorkCount)", operatorWorkCount == 0 ? .green : .orange)
        ])

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], alignment: .leading, spacing: 10) {
          statusLine(
            title: "Usable today",
            detail: "Manual mailbox-provider intake, mixed-mailbox filtering, Inbox triage, local order creation/linking, Tasks, Dispatch context, Audit, and JSON persistence.",
            symbol: "hand.thumbsup.fill",
            color: .green
          )
          statusLine(
            title: "Needs operator judgement",
            detail: "Uncertain messages, parser misses, filtered examples, duplicate refreshes, and order fields still need local review before accepting records.",
            symbol: "person.crop.circle.badge.exclamationmark",
            color: .orange
          )
          statusLine(
            title: "Still not connected",
            detail: "No background sync, mailbox mutation, Shopify API, carrier API, outbound email, OCR, scanner, calendar, notification, or file-picker workflow is active.",
            symbol: "network.slash",
            color: .secondary
          )
        }
      }
    }
  }

  private func statusLine(title: String, detail: String, symbol: String, color: Color) -> some View {
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

struct MVPCompletionRoadmapPanel: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.spaceMailIntakeHealthSummaries.first
  }

  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.gmailIntakeHealthSummaries.first
  }

  private var hasSpaceMailCredential: Bool {
    store.spaceMailIMAPConnections.contains {
      $0.credentialStorageStatus.localizedCaseInsensitiveContains("available")
        || $0.credentialStorageStatus.localizedCaseInsensitiveContains("ready")
    }
  }

  private var hasGmailConnectedAuth: Bool {
    store.gmailMailboxConnections.contains { connection in
      store.gmailAuthSessionState(for: connection).status == .connected
    }
  }

  private var hasActiveMailboxProvider: Bool {
    hasSpaceMailCredential || hasGmailConnectedAuth
  }

  private var fetchedCount: Int {
    (latestSpaceMailSummary?.fetchedCount ?? 0) + (latestGmailSummary?.fetchedCount ?? 0)
  }

  private var importedCount: Int {
    (latestSpaceMailSummary?.importedCount ?? 0) + (latestGmailSummary?.importedCount ?? 0)
  }

  private var filteredCount: Int {
    (latestSpaceMailSummary?.filteredCount ?? 0) + (latestGmailSummary?.filteredCount ?? 0)
  }

  private var uncertainCount: Int {
    (latestSpaceMailSummary.map { $0.pendingUncertainReviewCount + $0.uncertainCount } ?? 0)
      + (latestGmailSummary.map { $0.pendingUncertainReviewCount + $0.uncertainCount } ?? 0)
  }

  private var inboxOrderCount: Int {
    let linkedOrderIDs = Set(store.intakeEmails.compactMap(\.linkedOrderID))
    return store.orders.filter { order in
      linkedOrderIDs.contains(order.id)
        || order.source == .forwardedMailbox
        || order.checkedMailbox == "manual-import"
        || order.isInboxCreatedLocalOrder
    }.count
  }

  private var openOperatorWorkCount: Int {
    store.reviewIntakeEmails.count
      + store.openWorkbenchItems.count
      + store.reviewTasksNeedingAttention.count
      + store.handoffNotesNeedingAttention.count
      + store.blockedShipmentManifests.count
      + store.blockedDispatchChecklists.count
  }

  private var hasAuditTrail: Bool {
    !store.auditEvents.isEmpty
  }

  private var roadmapItems: [RoadmapItem] {
    [
      RoadmapItem(
        title: "1. Daily local MVP",
        status: "Mostly built",
        detail: "Dashboard, Inbox, Orders, Workbench, Dispatch, Tasks, Audit, Settings, local JSON persistence, and local audit logging are in place.",
        evidence: "Primary workflow screens exist and local actions are auditable.",
        nextAction: "Keep using the simplified operator flow for hands-on testing.",
        symbol: "checkmark.seal.fill",
        color: .green
      ),
      RoadmapItem(
        title: "2. Live mailbox intake",
        status: hasActiveMailboxProvider && fetchedCount > 0 ? "Testable" : "Needs proof",
        detail: "SpaceMail IMAP and Gmail both use explicit manual read-only refresh boundaries and feed the same provider-neutral Inbox intake path.",
        evidence: "\(fetchedCount) fetched, \(importedCount) imported, \(filteredCount) filtered, \(uncertainCount) uncertain.",
        nextAction: hasActiveMailboxProvider && fetchedCount > 0 ? "Repeat one provider refresh and verify imported/filtered/uncertain outcomes." : "Finish one provider credential/sign-in and run one manual refresh.",
        symbol: "tray.and.arrow.down.fill",
        color: hasActiveMailboxProvider && fetchedCount > 0 ? .green : .orange
      ),
      RoadmapItem(
        title: "3. Inbox-to-order handoff",
        status: inboxOrderCount > 0 ? "Proven" : "Needs sample",
        detail: "The operator should be able to create or link an order from an imported intake row, then see the source trail in Orders, Dashboard, Workbench, Tasks, Dispatch, and Audit.",
        evidence: "\(inboxOrderCount) Inbox-linked or forwarded-mailbox order\(inboxOrderCount == 1 ? "" : "s") found.",
        nextAction: inboxOrderCount > 0 ? "Use one linked order for the next QA pass." : "Create or link one order from a confirmed Inbox row.",
        symbol: "link.badge.plus",
        color: inboxOrderCount > 0 ? .green : .orange
      ),
      RoadmapItem(
        title: "4. Operator hardening",
        status: openOperatorWorkCount > 0 ? "Active cleanup" : "Quiet",
        detail: "The remaining MVP work is mostly QA, parser/classifier tuning, noisy-state cleanup, clearer labels, and compact-layout polish found during real use.",
        evidence: "\(openOperatorWorkCount) open review, Workbench, Task, handoff, or blocked dispatch item\(openOperatorWorkCount == 1 ? "" : "s").",
        nextAction: "Use hands-on testing to close confusing rows and keep adding small polish commits.",
        symbol: "wrench.and.screwdriver.fill",
        color: openOperatorWorkCount > 0 ? .orange : .green
      ),
      RoadmapItem(
        title: "5. External integrations",
        status: "Later",
        detail: "Shopify, carrier APIs, outbound email, background sync, notifications, OCR, scanners, calendars, and file pickers remain out of scope until the manual operator workflow is stable.",
        evidence: "Mailbox intake is the only live integration area currently being developed.",
        nextAction: "Do not add more integrations until the mailbox-to-order workflow is repeatable.",
        symbol: "network.slash",
        color: .secondary
      )
    ]
  }

  private var completedCoreCount: Int {
    roadmapItems.filter { $0.color == .green }.count
  }

  private var columns: [GridItem] {
    [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 230 : 280), spacing: 10)]
  }

  var body: some View {
    SettingsPanel(title: "Completion roadmap", symbol: "map.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: "map.fill")
            .foregroundStyle(completedCoreCount >= 3 ? .green : .orange)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            Text(completedCoreCount >= 3 ? "Usable version is close; continue QA and cleanup" : "Usable shell exists; prove the live intake path")
              .font(.headline)
            Text("This roadmap is intentionally practical: it separates what is ready for supervised use, what still needs repeatable evidence, and what should wait until the core workflow is stable.")
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Badge("\(completedCoreCount)/4 core", color: completedCoreCount >= 3 ? .green : .orange)
        }

        MetricStrip(items: [
          ("Fetched", "\(fetchedCount)", fetchedCount > 0 ? .green : .secondary),
          ("Imported", "\(importedCount)", importedCount > 0 ? .green : .secondary),
          ("Inbox orders", "\(inboxOrderCount)", inboxOrderCount > 0 ? .green : .orange),
          ("Open work", "\(openOperatorWorkCount)", openOperatorWorkCount == 0 ? .green : .orange),
          ("Audit", hasAuditTrail ? "Present" : "Missing", hasAuditTrail ? .purple : .orange)
        ])

        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
          ForEach(roadmapItems) { item in
            VStack(alignment: .leading, spacing: 8) {
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: item.symbol)
                  .foregroundStyle(item.color)
                  .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                  Text(item.title)
                    .font(.caption.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                  Text(item.status)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(item.color)
                }
              }

              Text(item.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
              Text(item.evidence)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(item.color)
                .fixedSize(horizontal: false, vertical: true)
              Label(item.nextAction, systemImage: "arrow.forward.circle.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(item.color)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(item.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
        }

        Text("Roadmap boundary: this panel reads local app state only. It does not fetch mail, sign in, read credentials, mutate mailbox messages, call Shopify/carriers, send mail, schedule background work, or write new records.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private struct RoadmapItem: Identifiable {
    let id = UUID()
    var title: String
    var status: String
    var detail: String
    var evidence: String
    var nextAction: String
    var symbol: String
    var color: Color
  }
}

struct MVPDevelopmentProgressPanel: View {
  var store: ParcelOpsStore

  private var hasSpaceMailSetup: Bool {
    !store.spaceMailIMAPConnections.isEmpty
  }

  private var hasSpaceMailCredential: Bool {
    store.spaceMailIMAPConnections.contains {
      $0.credentialStorageStatus.localizedCaseInsensitiveContains("available")
        || $0.credentialStorageStatus.localizedCaseInsensitiveContains("ready")
    }
  }

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.spaceMailIntakeHealthSummaries.first
  }

  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.gmailIntakeHealthSummaries.first
  }

  private var hasGmailSetup: Bool {
    !store.gmailMailboxConnections.isEmpty
  }

  private var hasGmailConnectedAuth: Bool {
    store.gmailMailboxConnections.contains { connection in
      store.gmailAuthSessionState(for: connection).status == .connected
    }
  }

  private var hasManualMailboxSetup: Bool {
    hasSpaceMailSetup || hasGmailSetup
  }

  private var hasManualMailboxReady: Bool {
    (hasSpaceMailSetup && hasSpaceMailCredential) || (hasGmailSetup && hasGmailConnectedAuth)
  }

  private var hasRefreshEvidence: Bool {
    (latestSpaceMailSummary?.fetchedCount ?? 0) > 0
      || store.spaceMailIMAPConnections.contains { $0.lastManualRefreshDate != "Never" }
      || (latestGmailSummary?.fetchedCount ?? 0) > 0
      || store.gmailMailboxConnections.contains { $0.lastManualRefreshDate != "Never" }
  }

  private var latestManualFetchedCount: Int {
    max(latestSpaceMailSummary?.fetchedCount ?? 0, latestGmailSummary?.fetchedCount ?? 0)
  }

  private var latestManualImportedCount: Int {
    (latestSpaceMailSummary?.importedCount ?? 0) + (latestGmailSummary?.importedCount ?? 0)
  }

  private var hasInboxOrderHandoff: Bool {
    let linkedOrderIDs = Set(store.intakeEmails.compactMap(\.linkedOrderID))
    return store.orders.contains { order in
      linkedOrderIDs.contains(order.id)
        || order.source == .forwardedMailbox
        || order.checkedMailbox == "manual-import"
    }
  }

  private var hasDispatchContext: Bool {
    !store.shipmentManifestRecords.isEmpty || !store.dispatchReadinessChecklists.isEmpty
  }

  private var hasTaskContext: Bool {
    !store.reviewTasks.isEmpty || !store.handoffNotes.isEmpty || !store.draftMessages.isEmpty
  }

  private var hasAuditEvidence: Bool {
    !store.auditEvents.isEmpty
  }

  private var openOperationalNoiseCount: Int {
    store.reviewIntakeEmails.count
      + store.intakeParserDiagnostics.count
      + store.pendingSpaceMailUncertainReviewCount
      + store.gmailMailboxConnections.reduce(0) { $0 + ($1.uncertainMessages?.count ?? 0) + ($1.lastRefreshUncertainCount ?? 0) }
      + store.openWorkbenchItems.count
      + store.reviewTasksNeedingAttention.count
      + store.handoffNotesNeedingAttention.count
      + store.blockedShipmentManifests.count
      + store.blockedDispatchChecklists.count
  }

  private var completedFoundationCount: Int {
    progressItems.filter(\.isComplete).count
  }

  private var progressPercent: Int {
    guard !progressItems.isEmpty else { return 0 }
    return Int((Double(completedFoundationCount) / Double(progressItems.count) * 100).rounded())
  }

  private var progressTone: Color {
    if completedFoundationCount >= progressItems.count - 1 { return .green }
    if completedFoundationCount >= 5 { return .teal }
    return .orange
  }

  private var progressTitle: String {
    if completedFoundationCount >= progressItems.count - 1 {
      return "MVP is close to a usable supervised version"
    }
    if completedFoundationCount >= 5 {
      return "Core app is usable; remaining work is QA and cleanup"
    }
    return "Core screens exist; finish the live intake proof"
  }

  private var progressDetail: String {
    if completedFoundationCount >= progressItems.count - 1 {
      return "The remaining work should be hands-on QA, data cleanup, parser/classifier tuning, and simplifying any screens that still feel too technical. Additional integrations should wait."
    }
    if completedFoundationCount >= 5 {
      return "Dashboard, primary navigation, local records, manual mailbox setup, and order handoff are mostly in place. Finish repeatable QA evidence before expanding integrations."
    }
    return "Keep focusing on the local daily flow: setup, manual refresh, Inbox triage, order handoff, dispatch context, tasks, and audit trace."
  }

  private var currentStageTitle: String {
    if completedFoundationCount >= progressItems.count - 1 && openOperationalNoiseCount < 25 {
      return "Supervised MVP test candidate"
    }
    if hasManualMailboxReady && hasRefreshEvidence && hasInboxOrderHandoff {
      return "Usable local workflow with cleanup remaining"
    }
    if hasManualMailboxReady && hasRefreshEvidence {
      return "Live intake proven; order handoff next"
    }
    if hasManualMailboxSetup {
      return "Mailbox setup exists; prove refresh and handoff"
    }
    return "Local app shell ready; mailbox setup next"
  }

  private var currentStageDetail: String {
    if completedFoundationCount >= progressItems.count - 1 && openOperationalNoiseCount < 25 {
      return "The app can be used for a supervised hands-on pass. Focus on clearing noisy review data, verifying one real intake-to-order path, and recording any operator confusion."
    }
    if hasManualMailboxReady && hasRefreshEvidence && hasInboxOrderHandoff {
      return "Core daily flow is present. The remaining work is mostly QA, classifier/parser tuning, compact UI polish, and cleanup of old test artifacts."
    }
    if hasManualMailboxReady && hasRefreshEvidence {
      return "A mailbox provider has produced local refresh evidence. Create or link one order from Inbox to prove the operational handoff."
    }
    if hasManualMailboxSetup {
      return "Confirm credential/sign-in readiness, run one manual read-only refresh, then use the latest refresh summary to decide whether Inbox should receive work."
    }
    return "Use SpaceMail for IMAP mailboxes or Gmail for Google-hosted mailboxes. Keep Microsoft 365 advanced until a licensed mailbox is available."
  }

  private var activeMailboxEvidence: String {
    if let latestGmailSummary, latestGmailSummary.fetchedCount > 0 || latestGmailSummary.importedCount > 0 || latestGmailSummary.filteredCount > 0 {
      return "Gmail: \(latestGmailSummary.fetchedCount) fetched, \(latestGmailSummary.importedCount) imported, \(latestGmailSummary.filteredCount) filtered, \(latestGmailSummary.pendingUncertainReviewCount + latestGmailSummary.uncertainCount) uncertain."
    }
    if let latestSpaceMailSummary, latestSpaceMailSummary.fetchedCount > 0 || latestSpaceMailSummary.importedCount > 0 || latestSpaceMailSummary.filteredCount > 0 {
      return "SpaceMail: \(latestSpaceMailSummary.fetchedCount) fetched, \(latestSpaceMailSummary.importedCount) imported, \(latestSpaceMailSummary.filteredCount) filtered, \(latestSpaceMailSummary.pendingUncertainReviewCount + latestSpaceMailSummary.uncertainCount) uncertain."
    }
    if hasGmailSetup || hasSpaceMailSetup {
      return "Mailbox setup exists, but no useful manual refresh evidence is available yet."
    }
    return "No active mailbox provider is configured for live intake yet."
  }

  private var remainingBlockers: [(title: String, detail: String, symbol: String, color: Color)] {
    var items: [(title: String, detail: String, symbol: String, color: Color)] = []
    if !hasManualMailboxSetup {
      items.append(("Choose provider", "Add SpaceMail for IMAP mailboxes or Gmail for Google-hosted mailboxes.", "server.rack", .orange))
    } else if !hasManualMailboxReady {
      items.append(("Finish auth", "Set the SpaceMail Keychain credential or complete Gmail sign-in before relying on real refresh.", "key.fill", .orange))
    }
    if !hasRefreshEvidence {
      items.append(("Run manual refresh", "Run one explicit read-only provider refresh to prove local intake without background sync.", "arrow.triangle.2.circlepath", .orange))
    }
    if !hasInboxOrderHandoff {
      items.append(("Prove Inbox-to-order", "Create or link one order from a confirmed intake row and verify the source trail.", "shippingbox.fill", .orange))
    }
    if openOperationalNoiseCount >= 25 {
      items.append(("Reduce test noise", "Clear, review, or ignore old parser and mailbox test rows before judging the operator experience.", "line.3.horizontal.decrease.circle.fill", .teal))
    }
    if items.isEmpty {
      items.append(("No major blocker", "Continue hands-on QA and capture issues that prevent a normal operator from completing the daily flow.", "checkmark.seal.fill", .green))
    }
    return items
  }

  private var nextPragmaticActions: [(title: String, detail: String, symbol: String)] {
    [
      ("Run one focused QA pass", "Dashboard -> Mailbox Monitor -> Inbox -> Orders -> Workbench -> Dispatch -> Tasks -> Audit.", "checklist.checked"),
      ("Use one known test order", "Keep a single clean intake email as the baseline for parser, order creation, and dispatch handoff checks.", "envelope.open.fill"),
      ("Clear old noise after testing", "Review or ignore obsolete intake/parser rows so progress counts reflect current behaviour.", "trash.slash.fill"),
      ("Delay new integrations", "Do Gmail/SpaceMail hardening before Shopify, carrier APIs, outbound email, OCR, notifications, or background work.", "pause.circle.fill")
    ]
  }

  private var progressItems: [(title: String, detail: String, isComplete: Bool, symbol: String, color: Color)] {
    [
      (
        "Primary UI",
        "Dashboard, Inbox, Orders, Workbench, Dispatch, Tasks, Audit, and Settings are the daily operator path.",
        true,
        "square.grid.2x2.fill",
        .green
      ),
      (
        "Local persistence",
        "JSON-backed local records and audit history exist for hands-on testing.",
        !store.orders.isEmpty && !store.auditEvents.isEmpty,
        "internaldrive.fill",
        !store.orders.isEmpty && !store.auditEvents.isEmpty ? .green : .orange
      ),
      (
        "Manual mailbox setup",
        "The current live intake paths support SpaceMail IMAP and Gmail with explicit manual refresh.",
        hasManualMailboxSetup && hasManualMailboxReady,
        "server.rack",
        hasManualMailboxSetup && hasManualMailboxReady ? .green : .orange
      ),
      (
        "Manual refresh proof",
        "At least one manual read-only mailbox refresh has produced a local result.",
        hasRefreshEvidence,
        "tray.and.arrow.down.fill",
        hasRefreshEvidence ? .green : .orange
      ),
      (
        "Inbox-to-order handoff",
        "At least one intake row has become or linked to a tracked order.",
        hasInboxOrderHandoff,
        "shippingbox.fill",
        hasInboxOrderHandoff ? .green : .orange
      ),
      (
        "Dispatch context",
        "Local manifest or readiness context exists for outbound handoff testing.",
        hasDispatchContext,
        "paperplane.fill",
        hasDispatchContext ? .green : .teal
      ),
      (
        "Tasks and handoffs",
        "Review tasks, handoff notes, or draft follow-up exist so ownership can be tested.",
        hasTaskContext,
        "checklist",
        hasTaskContext ? .green : .teal
      ),
      (
        "Audit trace",
        "Actions are visible in Audit so a tester can verify what changed locally.",
        hasAuditEvidence,
        "list.clipboard.fill",
        hasAuditEvidence ? .green : .orange
      )
    ]
  }

  var body: some View {
    SettingsPanel(title: "Development progress estimate", symbol: "chart.bar.doc.horizontal.fill") {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: completedFoundationCount >= progressItems.count - 1 ? "checkmark.seal.fill" : "chart.line.uptrend.xyaxis")
            .font(.title3)
            .foregroundStyle(progressTone)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 4) {
            Text(progressTitle)
              .font(.headline)
            Text(progressDetail)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer(minLength: 8)
          Badge("\(progressPercent)%", color: progressTone)
        }

        MetricStrip(items: [
          ("Foundations", "\(completedFoundationCount)/\(progressItems.count)", progressTone),
          ("Open noise", "\(openOperationalNoiseCount)", openOperationalNoiseCount == 0 ? .green : .orange),
          ("Fetched", "\(latestManualFetchedCount)", latestManualFetchedCount > 0 ? .blue : .secondary),
          ("Imported", "\(latestManualImportedCount)", latestManualImportedCount > 0 ? .green : .secondary),
          ("Audit", "\(store.auditEvents.count)", store.auditEvents.isEmpty ? .orange : .purple)
        ])

        VStack(alignment: .leading, spacing: 10) {
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: progressTone == .green ? "checkmark.seal.fill" : "target")
              .foregroundStyle(progressTone)
              .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
              Text(currentStageTitle)
                .font(.subheadline.weight(.semibold))
              Text(currentStageDetail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
              Text(activeMailboxEvidence)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(progressTone)
                .fixedSize(horizontal: false, vertical: true)
            }
          }

          CompactMetadataGrid(minimumWidth: 180) {
            ForEach(remainingBlockers, id: \.title) { item in
              VStack(alignment: .leading, spacing: 6) {
                Label(item.title, systemImage: item.symbol)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(item.color)
                Text(item.detail)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
              .padding(8)
              .frame(maxWidth: .infinity, alignment: .topLeading)
              .background(item.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }
        .padding(10)
        .background(progressTone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(progressItems, id: \.title) { item in
            VStack(alignment: .leading, spacing: 7) {
              HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(item.title, systemImage: item.symbol)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(item.color)
                Spacer()
                Badge(item.isComplete ? "Ready" : "Needed", color: item.color)
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

        VStack(alignment: .leading, spacing: 8) {
          Label("Next practical development actions", systemImage: "arrow.forward.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.teal)
          CompactMetadataGrid(minimumWidth: 190) {
            ForEach(nextPragmaticActions, id: \.title) { item in
              VStack(alignment: .leading, spacing: 6) {
                Label(item.title, systemImage: item.symbol)
                  .font(.caption.weight(.semibold))
                Text(item.detail)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
              .padding(8)
              .frame(maxWidth: .infinity, alignment: .topLeading)
              .background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
          }
        }

        Text("Estimate boundary: this is a local readiness guide, not a release guarantee. It does not run tests, fetch mail, mutate mailbox messages, store secrets, call Shopify/carriers, send notifications, or start background work.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

struct MVPHandsOnReleaseChecklist: View {
  var store: ParcelOpsStore

  private var hasSpaceMailSetup: Bool {
    !store.spaceMailIMAPConnections.isEmpty
  }

  private var hasSpaceMailCredential: Bool {
    store.spaceMailIMAPConnections.contains {
      $0.credentialStorageStatus.localizedCaseInsensitiveContains("available")
        || $0.credentialStorageStatus.localizedCaseInsensitiveContains("ready")
    }
  }

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.spaceMailIntakeHealthSummaries.first
  }

  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.gmailIntakeHealthSummaries.first
  }

  private var hasGmailSetup: Bool {
    !store.gmailMailboxConnections.isEmpty
  }

  private var hasGmailConnectedAuth: Bool {
    store.gmailMailboxConnections.contains { connection in
      store.gmailAuthSessionState(for: connection).status == .connected
    }
  }

  private var hasManualMailboxSetup: Bool {
    hasSpaceMailSetup || hasGmailSetup
  }

  private var hasManualMailboxReady: Bool {
    (hasSpaceMailSetup && hasSpaceMailCredential) || (hasGmailSetup && hasGmailConnectedAuth)
  }

  private var latestManualFetchedCount: Int {
    max(latestSpaceMailSummary?.fetchedCount ?? 0, latestGmailSummary?.fetchedCount ?? 0)
  }

  private var intakeReadyCount: Int {
    store.intakeEmails.filter { email in
      email.reviewState == .needsReview || email.linkedOrderID != nil
    }.count
  }

  private var inboxCreatedOrderCount: Int {
    let linkedOrderIDs = Set(store.intakeEmails.compactMap(\.linkedOrderID))
    return store.orders.filter { order in
      linkedOrderIDs.contains(order.id)
        || order.source == .forwardedMailbox
        || order.checkedMailbox == "manual-import"
    }.count
  }

  private var dispatchContextCount: Int {
    store.shipmentManifestRecords.count + store.dispatchReadinessChecklists.count
  }

  private var openPrimaryWorkCount: Int {
    store.openWorkbenchItems.count + store.reviewTasksNeedingAttention.count
  }

  private var completedChecklistCount: Int {
    checklistItems.filter { $0.4 }.count
  }

  private var nextTestTitle: String {
    if !hasManualMailboxSetup { return "Next: add an active mailbox provider" }
    if !hasManualMailboxReady { return "Next: finish mailbox credential or sign-in" }
    if latestManualFetchedCount == 0 { return "Next: run one manual mailbox refresh" }
    if intakeReadyCount == 0 { return "Next: review Mailbox Monitor results" }
    if inboxCreatedOrderCount == 0 { return "Next: create or link one order from Inbox" }
    if dispatchContextCount == 0 { return "Next: create dispatch setup for one order" }
    if store.auditEvents.isEmpty { return "Next: create one local action and confirm Audit" }
    return "Next: run the hands-on loop end to end"
  }

  private var nextTestDetail: String {
    if !hasManualMailboxSetup {
      return "Create a non-secret SpaceMail setup for IMAP mailboxes or Gmail setup for Google-hosted mailboxes."
    }
    if !hasManualMailboxReady {
      return "Use the secure SpaceMail credential prompt or explicit Gmail sign-in. Do not put passwords, tokens, or auth details in notes or JSON."
    }
    if latestManualFetchedCount == 0 {
      return "Run an explicit real mailbox refresh. It is manual, read-only, and must not mutate the mailbox."
    }
    if intakeReadyCount == 0 {
      return "Check whether messages were filtered, uncertain, duplicate, or imported. Import only genuine order mail."
    }
    if inboxCreatedOrderCount == 0 {
      return "Use Inbox to verify detected fields and create or link one order so downstream screens have real context."
    }
    if dispatchContextCount == 0 {
      return "Open the order and create local manifest/readiness setup so Dispatch can show the outbound handoff."
    }
    if store.auditEvents.isEmpty {
      return "Create a task, draft, review action, or dispatch action, then confirm the event appears in Audit."
    }
    return "Use Dashboard, Inbox, Orders, Workbench, Dispatch, Tasks, and Audit to verify the workflow feels coherent."
  }

  private var nextTestColor: Color {
    if completedChecklistCount >= checklistItems.count { return .green }
    if !hasManualMailboxSetup || !hasManualMailboxReady { return .orange }
    return .teal
  }

  private var checklistItems: [(String, String, String, Color, Bool)] {
    [
      (
        "1. Refresh intake",
        "Run a mailbox provider manually, then confirm fetched, imported, duplicate, refreshed, filtered, and uncertain counts are understandable.",
        "server.rack",
        hasManualMailboxReady && latestManualFetchedCount > 0 ? .green : .orange,
        hasManualMailboxReady && latestManualFetchedCount > 0
      ),
      (
        "2. Triage Inbox",
        "Review imported intake, reprocess if needed, then create or link an order only when detected fields look credible.",
        "tray.full.fill",
        intakeReadyCount == 0 ? .orange : .blue,
        intakeReadyCount > 0
      ),
      (
        "3. Confirm Orders",
        "Open the created or linked order and verify the Inbox source trail, status, customer/destination, and tracking context.",
        "shippingbox.fill",
        inboxCreatedOrderCount == 0 ? .orange : .green,
        inboxCreatedOrderCount > 0
      ),
      (
        "4. Clear exceptions",
        "Use Workbench and Needs Review for validation, reconciliation, high-risk, and handoff follow-up before dispatch work.",
        "exclamationmark.triangle.fill",
        store.openWorkbenchItems.isEmpty ? .green : .orange,
        store.openWorkbenchItems.isEmpty
      ),
      (
        "5. Prepare dispatch",
        "Check Dispatch for manifests and readiness items so outbound work has an obvious next local action.",
        "paperplane.fill",
        dispatchContextCount == 0 ? .orange : .purple,
        dispatchContextCount > 0
      ),
      (
        "6. Verify traceability",
        "Check Tasks and Audit, then quit and reopen to confirm local JSON persistence keeps the same workflow state.",
        "list.clipboard.fill",
        store.auditEvents.isEmpty ? .orange : .teal,
        !store.auditEvents.isEmpty
      )
    ]
  }

  var body: some View {
    SettingsPanel(title: "Hands-on release checklist", symbol: "checklist.checked") {
      MetricStrip(items: [
        ("Checks", "\(completedChecklistCount)/\(checklistItems.count)", completedChecklistCount == checklistItems.count ? .green : .orange),
        ("Intake records", "\(store.intakeEmails.count)", .blue),
        ("Orders", "\(store.orders.count)", .green),
        ("Open work", "\(openPrimaryWorkCount)", .orange),
        ("Audit events", "\(store.auditEvents.count)", .purple)
      ])

      Text("Use this checklist when judging whether ParcelOps is ready for normal hands-on testing in Xcode. It is still a manual, local-first workflow: no background sync, notifications, mailbox mutation, Shopify, carrier APIs, OCR, scanners, or outbound email are active.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: completedChecklistCount == checklistItems.count ? "checkmark.seal.fill" : "arrow.forward.circle.fill")
            .foregroundStyle(nextTestColor)
            .frame(width: 22)
          VStack(alignment: .leading, spacing: 4) {
            Text(nextTestTitle)
              .font(.headline)
            Text(nextTestDetail)
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Badge(completedChecklistCount == checklistItems.count ? "Ready loop" : "Next test", color: nextTestColor)
        }

        CompactActionRow {
          Button("Seed local demo workflow", systemImage: "wand.and.stars") {
            store.seedLocalInboxOrderDemoWorkflow()
          }
          .buttonStyle(.borderedProminent)

          Button("Import clear order test email", systemImage: "checklist.checked") {
            store.importClearOrderIntakeTestMessage()
          }
          .buttonStyle(.bordered)

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
            OrdersView(store: store)
          } label: {
            Label("Orders", systemImage: "shippingbox.fill")
          }
          NavigationLink {
            OperationsWorkbenchView(store: store)
          } label: {
            Label("Workbench", systemImage: "rectangle.stack.badge.person.crop.fill")
          }
          NavigationLink {
            DispatchView(store: store)
          } label: {
            Label("Dispatch", systemImage: "paperplane.fill")
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
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(nextTestColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], alignment: .leading, spacing: 10) {
        ForEach(Array(checklistItems.enumerated()), id: \.offset) { _, item in
          MVPHandsOnReleaseChecklistRow(title: item.0, detail: item.1, symbol: item.2, color: item.3, isComplete: item.4)
        }
      }
    }
  }
}

struct MVPHandsOnReleaseChecklistRow: View {
  var title: String
  var detail: String
  var symbol: String
  var color: Color
  var isComplete: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label(title, systemImage: symbol)
          .font(.caption.weight(.semibold))
          .foregroundStyle(color)
        Spacer(minLength: 0)
        Badge(isComplete ? "Done" : "Check", color: isComplete ? .green : color)
      }
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

struct MVPReleaseCandidateQACard: View {
  var store: ParcelOpsStore
  @State private var feedbackMessage: String?

  private var latestDemoOrder: TrackedOrder? {
    store.orders.first { order in
      order.source == .forwardedMailbox
        && order.orderNumber.range(of: "TEST-", options: [.caseInsensitive, .anchored]) != nil
    }
  }

  private var linkedDemoIntakeCount: Int {
    guard let order = latestDemoOrder else { return 0 }
    return store.intakeEmails.filter { $0.linkedOrderID == order.id }.count
  }

  private var demoManifestCount: Int {
    latestDemoOrder.map { store.suggestedShipmentManifestRecords(for: $0).count } ?? 0
  }

  private var demoChecklistCount: Int {
    latestDemoOrder.map { store.suggestedDispatchReadinessChecklists(for: $0).count } ?? 0
  }

  private var completedDemoDispatchCount: Int {
    guard let order = latestDemoOrder else { return 0 }
    let manifests = store.suggestedShipmentManifestRecords(for: order).filter { $0.dispatchStatus == .handedOff }.count
    let checklists = store.suggestedDispatchReadinessChecklists(for: order).filter { $0.checklistStatus == .completed }.count
    return manifests + checklists
  }

  private var demoAuditCount: Int {
    guard let order = latestDemoOrder else { return 0 }
    return store.auditEvents.filter {
      $0.entityID == order.id.uuidString
        || $0.entityLabel.localizedCaseInsensitiveContains(order.orderNumber)
        || $0.afterDetail?.localizedCaseInsensitiveContains(order.orderNumber) == true
    }.count
  }

  private var hasLiveMailboxEvidence: Bool {
    store.spaceMailIntakeHealthSummaries.contains { summary in
      summary.fetchedCount > 0 || summary.importedCount > 0 || summary.filteredCount > 0 || summary.duplicateCount > 0 || summary.uncertainCount > 0
    } || store.gmailIntakeHealthSummaries.contains { summary in
      summary.fetchedCount > 0 || summary.importedCount > 0 || summary.filteredCount > 0 || summary.duplicateCount > 0 || summary.uncertainCount > 0
    }
  }

  private var hasPersistenceEvidence: Bool {
    store.auditEvents.count > 0 && store.orders.count > 0 && store.intakeEmails.count > 0
  }

  private var qaItems: [(title: String, detail: String, symbol: String, color: Color, isComplete: Bool)] {
    [
      (
        "Local demo seed",
        latestDemoOrder == nil ? "Seed the local demo workflow to create a known-good order path without mailbox access." : "Latest demo order \(latestDemoOrder?.orderNumber ?? "") exists.",
        "wand.and.stars",
        latestDemoOrder == nil ? .orange : .green,
        latestDemoOrder != nil
      ),
      (
        "Inbox source trail",
        linkedDemoIntakeCount == 0 ? "The demo order needs a linked intake email." : "\(linkedDemoIntakeCount) linked intake row exists for the demo order.",
        "link.badge.plus",
        linkedDemoIntakeCount == 0 ? .orange : .green,
        linkedDemoIntakeCount > 0
      ),
      (
        "Dispatch handoff",
        demoManifestCount + demoChecklistCount == 0 ? "Create or seed dispatch setup for the demo order." : "\(demoManifestCount) manifest and \(demoChecklistCount) readiness checklist records are linked.",
        "paperplane.fill",
        demoManifestCount + demoChecklistCount == 0 ? .orange : .purple,
        demoManifestCount > 0 && demoChecklistCount > 0
      ),
      (
        "Handoff completion",
        completedDemoDispatchCount == 0 ? "Complete the demo dispatch handoff once setup exists." : "\(completedDemoDispatchCount) demo dispatch records are completed locally.",
        "checkmark.rectangle.stack.fill",
        completedDemoDispatchCount == 0 ? .teal : .green,
        completedDemoDispatchCount > 0
      ),
      (
        "Audit trace",
        demoAuditCount == 0 ? "Perform the demo actions and confirm Audit shows the order trail." : "\(demoAuditCount) audit entries reference the latest demo order.",
        "list.clipboard.fill",
        demoAuditCount == 0 ? .orange : .purple,
        demoAuditCount > 0
      ),
      (
        "Live mailbox evidence",
        hasLiveMailboxEvidence ? "A live mailbox provider has at least one manual refresh result." : "Optional for demo readiness: run real mailbox refresh only when credentials, sign-in, and mailbox state are available.",
        "server.rack",
        hasLiveMailboxEvidence ? .green : .secondary,
        hasLiveMailboxEvidence
      ),
      (
        "Persistence evidence",
        hasPersistenceEvidence ? "Local JSON-backed records exist across intake, orders, and audit." : "Create local workflow evidence, quit, reopen, and confirm it remains visible.",
        "internaldrive.fill",
        hasPersistenceEvidence ? .green : .orange,
        hasPersistenceEvidence
      )
    ]
  }

  private var requiredItems: [(title: String, detail: String, symbol: String, color: Color, isComplete: Bool)] {
    Array(qaItems.prefix(5)) + Array(qaItems.suffix(1))
  }

  private var completedRequiredCount: Int {
    requiredItems.filter(\.isComplete).count
  }

  private var tone: Color {
    completedRequiredCount == requiredItems.count ? .green : completedRequiredCount >= 4 ? .teal : .orange
  }

  private var title: String {
    if completedRequiredCount == requiredItems.count { return "Release-candidate demo path is ready" }
    if latestDemoOrder == nil { return "Release-candidate QA needs a seeded demo" }
    return "Release-candidate QA is partly ready"
  }

  private var detail: String {
    if completedRequiredCount == requiredItems.count {
      return "The local demo path has enough evidence for Inbox, Orders, Dispatch, Tasks, Audit, and persistence-oriented hands-on testing."
    }
    return "Use the local demo path as the stable QA baseline. Live mailbox evidence remains useful, but it should not block app usability checks."
  }

  private var canCompleteHandoff: Bool {
    latestDemoOrder != nil
      && demoManifestCount > 0
      && demoChecklistCount > 0
      && completedDemoDispatchCount == 0
  }

  private var canReopenHandoff: Bool {
    latestDemoOrder != nil && completedDemoDispatchCount > 0
  }

  private var snapshot: SpaceMailReleaseSnapshot {
    store.spaceMailReleaseSnapshot
  }

  private var snapshotPreviewLines: [String] {
    snapshot.reportText
      .split(separator: "\n", omittingEmptySubsequences: false)
      .prefix(12)
      .map(String.init)
  }

  private var snapshotTone: Color {
    switch snapshot.tone {
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

  var body: some View {
    SettingsPanel(title: "Release-candidate QA", symbol: "checkmark.seal.fill") {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: completedRequiredCount == requiredItems.count ? "checkmark.seal.fill" : "checklist")
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
        Badge("\(completedRequiredCount)/\(requiredItems.count)", color: tone)
      }

      MetricStrip(items: [
        ("Demo order", latestDemoOrder == nil ? "No" : "Yes", latestDemoOrder == nil ? .orange : .green),
        ("Inbox links", "\(linkedDemoIntakeCount)", linkedDemoIntakeCount == 0 ? .orange : .green),
        ("Dispatch", "\(demoManifestCount + demoChecklistCount)", demoManifestCount + demoChecklistCount == 0 ? .orange : .purple),
        ("Completed", "\(completedDemoDispatchCount)", completedDemoDispatchCount == 0 ? .secondary : .green),
        ("Audit", "\(demoAuditCount)", demoAuditCount == 0 ? .orange : .purple)
      ])

      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .top, spacing: 8) {
          Label("Current release snapshot", systemImage: "doc.plaintext.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(snapshotTone)
          Spacer()
          Badge(snapshot.tone.capitalized, color: snapshotTone)
        }

        Text(snapshotPreviewLines.joined(separator: "\n"))
          .font(.caption2.monospaced())
          .foregroundStyle(.secondary)
          .lineLimit(14)
          .textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)

        Text("This preview is generated from local state only. Create a QA task to preserve the full snapshot for the next tester.")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(snapshotTone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

      CompactActionRow {
        Button(latestDemoOrder == nil ? "Seed demo workflow" : "Seed another demo", systemImage: "wand.and.stars") {
          store.seedLocalInboxOrderDemoWorkflow()
          feedbackMessage = "Local demo workflow seeded. Review the updated snapshot and Audit trail."
        }
        .buttonStyle(.borderedProminent)

        Button("Create QA task", systemImage: "checklist") {
          store.createReviewTaskFromSpaceMailReleaseSnapshot()
          feedbackMessage = "QA task created from the current release snapshot. Open Tasks to assign or complete it."
        }
        .buttonStyle(.bordered)

        NavigationLink {
          TasksView(store: store)
        } label: {
          Label("Tasks", systemImage: "checklist")
        }
        .buttonStyle(.bordered)

        if let order = latestDemoOrder {
          Button("Complete handoff", systemImage: "checkmark.rectangle.stack.fill") {
            store.completeInboxDispatchHandoff(for: order)
            feedbackMessage = "Dispatch handoff completed locally. Confirm the resulting Audit event."
          }
          .buttonStyle(.bordered)
          .disabled(!canCompleteHandoff)

          Button("Reopen handoff", systemImage: "arrow.counterclockwise.circle.fill") {
            store.reopenInboxDispatchHandoff(for: order)
            feedbackMessage = "Dispatch handoff reopened locally. Review the follow-up task before retesting."
          }
          .buttonStyle(.bordered)
          .disabled(!canReopenHandoff)
        }

        NavigationLink {
          DashboardView(store: store)
        } label: {
          Label("Dashboard", systemImage: "square.grid.2x2.fill")
        }
        .buttonStyle(.bordered)

        NavigationLink {
          AuditView(store: store)
        } label: {
          Label("Audit", systemImage: "list.clipboard.fill")
        }
        .buttonStyle(.bordered)
      }

      if let feedbackMessage {
        Label(feedbackMessage, systemImage: "checkmark.circle.fill")
          .font(.caption)
          .foregroundStyle(.green)
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], alignment: .leading, spacing: 10) {
        ForEach(Array(qaItems.enumerated()), id: \.offset) { _, item in
          MVPHandsOnReleaseChecklistRow(title: item.title, detail: item.detail, symbol: item.symbol, color: item.color, isComplete: item.isComplete)
        }
      }

      Text("QA boundaries: this card only reads and creates local JSON-backed workflow records through existing local actions. It does not run IMAP, mutate mailboxes, call Shopify/carrier APIs, send messages, create notifications, or schedule background work.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

struct MVPReleaseEvidenceReport: View {
  var store: ParcelOpsStore

  private var latestDemoOrder: TrackedOrder? {
    store.orders.first { order in
      order.source == .forwardedMailbox
        && order.orderNumber.range(of: "TEST-", options: [.caseInsensitive, .anchored]) != nil
    }
  }

  private var linkedIntakeCount: Int {
    guard let order = latestDemoOrder else { return 0 }
    return store.intakeEmails.filter { $0.linkedOrderID == order.id }.count
  }

  private var dispatchSetupCount: Int {
    guard let order = latestDemoOrder else { return 0 }
    return store.suggestedShipmentManifestRecords(for: order).count
      + store.suggestedDispatchReadinessChecklists(for: order).count
  }

  private var completedDispatchCount: Int {
    guard let order = latestDemoOrder else { return 0 }
    return store.suggestedShipmentManifestRecords(for: order).filter { $0.dispatchStatus == .handedOff }.count
      + store.suggestedDispatchReadinessChecklists(for: order).filter { $0.checklistStatus == .completed }.count
  }

  private var openDemoTaskCount: Int {
    guard let order = latestDemoOrder else { return 0 }
    return store.reviewTasks.filter {
      $0.linkedEntityType == .order
        && $0.linkedEntityID == order.id.uuidString
        && $0.status != .completed
    }.count
  }

  private var demoAuditCount: Int {
    guard let order = latestDemoOrder else { return 0 }
    return store.auditEvents.filter {
      $0.entityID == order.id.uuidString
        || $0.entityLabel.localizedCaseInsensitiveContains(order.orderNumber)
        || $0.afterDetail?.localizedCaseInsensitiveContains(order.orderNumber) == true
    }.count
  }

  private var persistenceEvidenceReady: Bool {
    !store.orders.isEmpty && !store.intakeEmails.isEmpty && !store.auditEvents.isEmpty
  }

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.spaceMailIntakeHealthSummaries.first
  }

  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.gmailIntakeHealthSummaries.first
  }

  private var liveMailboxEvidenceReady: Bool {
    let hasSpaceMailEvidence = latestSpaceMailSummary.map {
      $0.fetchedCount > 0 || $0.importedCount > 0 || $0.filteredCount > 0 || $0.duplicateCount > 0 || $0.uncertainCount > 0
    } ?? false
    let hasGmailEvidence = latestGmailSummary.map {
      $0.fetchedCount > 0 || $0.importedCount > 0 || $0.filteredCount > 0 || $0.duplicateCount > 0 || $0.uncertainCount > 0
    } ?? false
    return hasSpaceMailEvidence || hasGmailEvidence
  }

  private var requiredBlockers: [String] {
    var blockers: [String] = []
    if latestDemoOrder == nil { blockers.append("Seed local demo workflow") }
    if linkedIntakeCount == 0 { blockers.append("Link Inbox source to order") }
    if dispatchSetupCount == 0 { blockers.append("Create dispatch setup") }
    if completedDispatchCount == 0 { blockers.append("Complete demo handoff") }
    if demoAuditCount == 0 { blockers.append("Confirm Audit trail") }
    if !persistenceEvidenceReady { blockers.append("Confirm local JSON evidence") }
    return blockers
  }

  private var readyCount: Int {
    [
      latestDemoOrder != nil,
      linkedIntakeCount > 0,
      dispatchSetupCount > 0,
      completedDispatchCount > 0,
      demoAuditCount > 0,
      persistenceEvidenceReady
    ].filter { $0 }.count
  }

  private var tone: Color {
    if requiredBlockers.isEmpty { return .green }
    if readyCount >= 4 { return .teal }
    return .orange
  }

  private var verdictTitle: String {
    if requiredBlockers.isEmpty { return "QA evidence supports a hands-on release-candidate pass" }
    if latestDemoOrder == nil { return "QA evidence needs a stable local demo path" }
    return "QA evidence is incomplete"
  }

  private var verdictDetail: String {
    if requiredBlockers.isEmpty {
      return "The local path has enough traceable evidence for Dashboard, Inbox, Orders, Dispatch, Tasks, Audit, and persistence checks. Live mailbox evidence remains optional."
    }
    return "Finish the required blockers below before treating this as a release-candidate baseline. This report avoids live integrations and uses local records only."
  }

  private var canCompleteHandoff: Bool {
    latestDemoOrder != nil && dispatchSetupCount > 0 && completedDispatchCount == 0
  }

  private var canReopenHandoff: Bool {
    latestDemoOrder != nil && completedDispatchCount > 0
  }

  var body: some View {
    SettingsPanel(title: "QA evidence report", symbol: "doc.text.magnifyingglass") {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: requiredBlockers.isEmpty ? "checkmark.seal.fill" : "doc.text.magnifyingglass")
          .foregroundStyle(tone)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: 4) {
          Text(verdictTitle)
            .font(.headline)
          Text(verdictDetail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()
        Badge("\(readyCount)/6", color: tone)
      }

      MetricStrip(items: [
        ("Demo order", latestDemoOrder == nil ? "Missing" : "Present", latestDemoOrder == nil ? .orange : .green),
        ("Source links", "\(linkedIntakeCount)", linkedIntakeCount == 0 ? .orange : .green),
        ("Dispatch setup", "\(dispatchSetupCount)", dispatchSetupCount == 0 ? .orange : .purple),
        ("Closed handoff", "\(completedDispatchCount)", completedDispatchCount == 0 ? .secondary : .green),
        ("Open tasks", "\(openDemoTaskCount)", openDemoTaskCount == 0 ? .green : .orange),
        ("Audit trail", "\(demoAuditCount)", demoAuditCount == 0 ? .orange : .purple),
        ("Persistence", persistenceEvidenceReady ? "Seen" : "Check", persistenceEvidenceReady ? .green : .orange),
        ("Live mail", liveMailboxEvidenceReady ? "Seen" : "Optional", liveMailboxEvidenceReady ? .green : .secondary)
      ])

      if requiredBlockers.isEmpty {
        evidenceLine(
          title: "Required local evidence is complete",
          detail: "Run the hands-on pass from Dashboard, then quit and reopen the app to confirm the same local JSON-backed records remain visible.",
          symbol: "checkmark.circle.fill",
          color: .green
        )
      } else {
        VStack(alignment: .leading, spacing: 8) {
          Label("Required blockers", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
          ForEach(requiredBlockers, id: \.self) { blocker in
            Label(blocker, systemImage: "circle")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], alignment: .leading, spacing: 10) {
        evidenceLine(
          title: "Stable local baseline",
          detail: latestDemoOrder.map { "\($0.orderNumber) links Inbox, Orders, Dispatch, Tasks, and Audit." } ?? "Seed the demo workflow to create a stable non-mailbox baseline.",
          symbol: "wand.and.stars",
          color: latestDemoOrder == nil ? .orange : .green
        )
        evidenceLine(
          title: "Live mailbox is not a blocker",
          detail: liveMailboxEvidenceReady ? "An active mailbox provider has refresh evidence for mixed-mailbox testing." : "Live mailbox evidence is useful, but release-candidate QA can continue with local demo data.",
          symbol: "server.rack",
          color: liveMailboxEvidenceReady ? .green : .secondary
        )
        evidenceLine(
          title: "No external automation required",
          detail: "The QA path does not require Shopify, carrier APIs, outbound email, notifications, scanners, OCR, calendars, or background sync.",
          symbol: "network.slash",
          color: .secondary
        )
      }

      CompactActionRow {
        Button(latestDemoOrder == nil ? "Seed demo workflow" : "Seed another demo", systemImage: "wand.and.stars") {
          store.seedLocalInboxOrderDemoWorkflow()
        }
        .buttonStyle(.borderedProminent)

        if let order = latestDemoOrder {
          Button("Complete handoff", systemImage: "checkmark.rectangle.stack.fill") {
            store.completeInboxDispatchHandoff(for: order)
          }
          .buttonStyle(.bordered)
          .disabled(!canCompleteHandoff)

          Button("Reopen handoff", systemImage: "arrow.counterclockwise.circle.fill") {
            store.reopenInboxDispatchHandoff(for: order)
          }
          .buttonStyle(.bordered)
          .disabled(!canReopenHandoff)
        }

        NavigationLink { DashboardView(store: store) } label: { Label("Dashboard", systemImage: "square.grid.2x2.fill") }
          .buttonStyle(.bordered)
        NavigationLink { AuditView(store: store) } label: { Label("Audit", systemImage: "list.clipboard.fill") }
          .buttonStyle(.bordered)
      }
    }
  }

  private func evidenceLine(title: String, detail: String, symbol: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 6) {
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

struct MVPReleaseRunbook: View {
  var store: ParcelOpsStore

  private var hasDemoOrder: Bool {
    store.orders.contains { order in
      order.source == .forwardedMailbox
        && order.orderNumber.range(of: "TEST-", options: [.caseInsensitive, .anchored]) != nil
    }
  }

  private var hasSpaceMailResult: Bool {
    store.spaceMailIntakeHealthSummaries.contains { summary in
      summary.fetchedCount > 0 || summary.importedCount > 0 || summary.filteredCount > 0 || summary.duplicateCount > 0 || summary.uncertainCount > 0
    }
  }

  private var hasGmailResult: Bool {
    store.gmailIntakeHealthSummaries.contains { summary in
      summary.fetchedCount > 0 || summary.importedCount > 0 || summary.filteredCount > 0 || summary.duplicateCount > 0 || summary.uncertainCount > 0
    }
  }

  private var hasLiveMailboxResult: Bool {
    hasSpaceMailResult || hasGmailResult
  }

  private var hasAuditEvidence: Bool {
    store.auditEvents.contains { event in
      [.spaceMailIMAPConnection, .intakeEmail, .order, .reviewTask, .shipmentManifest, .dispatchChecklist].contains(event.entityType)
    }
  }

  private var hasOpenPrimaryWork: Bool {
    !store.reviewIntakeEmails.isEmpty
      || !store.openWorkbenchItems.isEmpty
      || !store.reviewTasksNeedingAttention.isEmpty
      || !store.incompleteDispatchChecklists.isEmpty
  }

  private var runbookTone: Color {
    if hasDemoOrder && hasAuditEvidence { return .green }
    if hasDemoOrder || hasLiveMailboxResult { return .teal }
    return .orange
  }

  private var runbookTitle: String {
    if hasDemoOrder && hasAuditEvidence { return "Runbook is ready for a supervised MVP pass" }
    if hasDemoOrder { return "Runbook has demo data; confirm Audit next" }
    return "Runbook needs a stable local demo seed"
  }

  private var runbookDetail: String {
    if hasDemoOrder && hasAuditEvidence {
      return "Use this sequence to run a short release-candidate pass. It is deliberately local-first and does not require live mailbox success."
    }
    if hasDemoOrder {
      return "The local demo order exists. Complete or reopen the dispatch handoff, then confirm the trail in Audit."
    }
    return "Seed the local demo workflow first so testing does not depend on live mailbox contents or classifier results."
  }

  private var normalSteps: [(String, String, String, Color)] {
    [
      ("1. Start at Dashboard", "Use Start here, Hands-on status, and Release-candidate checkpoint to decide where work should begin.", "square.grid.2x2.fill", .teal),
      ("2. Prove intake", "Use Inbox or Mailbox Monitor. A local demo email is enough; a real mailbox refresh is useful but optional for release-candidate QA.", "tray.full.fill", .blue),
      ("3. Create/link order", "Confirm merchant, order number, tracking, destination, and source trail before treating the order as operational.", "shippingbox.fill", .green),
      ("4. Close dispatch handoff", "Confirm manifest and readiness setup, then complete or reopen the local handoff as needed.", "paperplane.fill", .purple),
      ("5. Resolve owned work", "Open Workbench and Tasks. Complete only assigned local follow-up; filtered non-order mailbox results should not flood task work.", "checklist", .orange),
      ("6. Confirm Audit", "Audit should show the local source trail and handoff actions without secrets, full mailbox bodies, or mailbox mutation.", "list.clipboard.fill", .purple)
    ]
  }

  private var passCriteria: [(String, String, String, Color, Bool)] {
    [
      ("Dashboard gives a next action", "A tester can identify whether to open Inbox, Orders, Workbench, Dispatch, Tasks, or Audit.", "arrow.forward.circle.fill", .teal, true),
      ("Inbox creates or links an order", "A clear local/demo intake can become an order without relying on external services.", "link.badge.plus", .green, hasDemoOrder || !store.orders.isEmpty),
      ("Order keeps source trail", "The order detail can explain where the order came from and what still needs review.", "tray.and.arrow.down.fill", .blue, hasDemoOrder),
      ("Dispatch has a handoff path", "The tester can see manifest/readiness context and complete or reopen local handoff records.", "checkmark.rectangle.stack.fill", .purple, hasDemoOrder),
      ("Audit explains the trail", "Recent local actions appear in Audit with safe non-secret details.", "list.clipboard.fill", .purple, hasAuditEvidence),
      ("Settings explains boundaries", "Local JSON storage, mailbox credentials or auth state, and disconnected integrations are clear from Settings/MVP Setup.", "lock.shield.fill", .green, true)
    ]
  }

  private var knownLimitations: [(String, String, String, Color)] {
    [
      ("Mailbox refresh is manual", "Real mailbox refreshes are explicit, read-only, and mixed-mailbox filtered. There is no background sync or mailbox mutation.", "server.rack", .teal),
      ("Shopify is not connected", "Shopify records remain placeholders. No Shopify API, OAuth, store login, or order sync is active.", "cart.badge.plus", .orange),
      ("Carrier tracking is local", "Carrier events are local records only. No carrier APIs, label printing, booking, scanner, or tracking refresh is active.", "location.fill.viewfinder", .orange),
      ("Outbound communication is draft-only", "Draft messages and templates are local planning records. ParcelOps does not send email or notifications.", "paperplane.slash.fill", .secondary),
      ("Secrets stay out of JSON", "SpaceMail passwords are handled through Keychain status/actions and Gmail uses platform auth state, while JSON stores only non-secret operational records.", "key.horizontal.fill", .green),
      ("Advanced records are supporting context", "Costs, claims, procurement, receiving, custody, labels, and scans exist locally but are not the primary daily path.", "archivebox.fill", .secondary)
    ]
  }

  private var completedPassCriteriaCount: Int {
    passCriteria.filter(\.4).count
  }

  var body: some View {
    SettingsPanel(title: "MVP release runbook", symbol: "book.closed.fill") {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "book.closed.fill")
          .foregroundStyle(runbookTone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(runbookTitle)
            .font(.headline)
          Text(runbookDetail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge("\(completedPassCriteriaCount)/\(passCriteria.count)", color: runbookTone)
      }

      MetricStrip(items: [
        ("Demo order", hasDemoOrder ? "Ready" : "Needed", hasDemoOrder ? .green : .orange),
        ("Mailbox", hasLiveMailboxResult ? "Seen" : "Optional", hasLiveMailboxResult ? .green : .secondary),
        ("Open work", "\(store.openWorkbenchItems.count + store.reviewTasksNeedingAttention.count)", hasOpenPrimaryWork ? .orange : .green),
        ("Audit", hasAuditEvidence ? "Ready" : "Needed", hasAuditEvidence ? .green : .orange),
        ("Records", "\(store.orders.count + store.intakeEmails.count + store.auditEvents.count)", .blue)
      ])

      CompactActionRow {
        Button(hasDemoOrder ? "Seed another demo" : "Seed demo workflow", systemImage: "wand.and.stars") {
          store.seedLocalInboxOrderDemoWorkflow()
        }
        .buttonStyle(.borderedProminent)

        NavigationLink { DashboardView(store: store) } label: { Label("Dashboard", systemImage: "square.grid.2x2.fill") }
          .buttonStyle(.bordered)
        NavigationLink { InboxView(store: store) } label: { Label("Inbox", systemImage: "tray.full.fill") }
          .buttonStyle(.bordered)
        NavigationLink { OrdersView(store: store) } label: { Label("Orders", systemImage: "shippingbox.fill") }
          .buttonStyle(.bordered)
        NavigationLink { DispatchView(store: store) } label: { Label("Dispatch", systemImage: "paperplane.fill") }
          .buttonStyle(.bordered)
        NavigationLink { AuditView(store: store) } label: { Label("Audit", systemImage: "list.clipboard.fill") }
          .buttonStyle(.bordered)
      }

      runbookSection(title: "Test sequence", symbol: "list.number", items: normalSteps)

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], alignment: .leading, spacing: 10) {
        ForEach(Array(passCriteria.enumerated()), id: \.offset) { _, item in
          MVPHandsOnReleaseChecklistRow(title: item.0, detail: item.1, symbol: item.2, color: item.3, isComplete: item.4)
        }
      }

      runbookSection(title: "Known limitations", symbol: "exclamationmark.triangle.fill", items: knownLimitations)

      Text("Pass/fail rule: this MVP is ready for hands-on testing when a tester can complete the local demo path, understand filtered/uncertain mailbox results, and confirm Audit/Settings boundaries without expecting live Shopify, carrier, notification, scanner, OCR, calendar, file-picker, outbound email, or background automation behavior.")
        .font(.caption.weight(.semibold))
        .foregroundStyle(runbookTone)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func runbookSection(title: String, symbol: String, items: [(String, String, String, Color)]) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(title, systemImage: symbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], alignment: .leading, spacing: 10) {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
          VStack(alignment: .leading, spacing: 6) {
            Label(item.0, systemImage: item.2)
              .font(.caption.weight(.semibold))
              .foregroundStyle(item.3)
            Text(item.1)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background(item.3.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
      }
    }
  }
}

struct MVPHandsOnTroubleshootingGuide: View {
  var store: ParcelOpsStore

  private var hasSpaceMailSetup: Bool {
    !store.spaceMailIMAPConnections.isEmpty
  }

  private var hasSpaceMailCredential: Bool {
    store.spaceMailIMAPConnections.contains {
      $0.credentialStorageStatus.localizedCaseInsensitiveContains("available")
        || $0.credentialStorageStatus.localizedCaseInsensitiveContains("ready")
    }
  }

  private var latestSpaceMailSummary: SpaceMailIntakeHealthSummary? {
    store.spaceMailIntakeHealthSummaries.first
  }

  private var hasGmailSetup: Bool {
    !store.gmailMailboxConnections.isEmpty
  }

  private var hasGmailConnectedAuth: Bool {
    store.gmailMailboxConnections.contains { connection in
      store.gmailAuthSessionState(for: connection).status == .connected
    }
  }

  private var latestGmailSummary: GmailIntakeHealthSummary? {
    store.gmailIntakeHealthSummaries.first
  }

  private var hasMailboxSetup: Bool {
    hasSpaceMailSetup || hasGmailSetup
  }

  private var hasMailboxCredentialOrAuth: Bool {
    (hasSpaceMailSetup && hasSpaceMailCredential) || (hasGmailSetup && hasGmailConnectedAuth)
  }

  private var fetchedCount: Int {
    (latestSpaceMailSummary?.fetchedCount ?? 0) + (latestGmailSummary?.fetchedCount ?? 0)
  }

  private var filteredCount: Int {
    (latestSpaceMailSummary?.filteredCount ?? 0) + (latestGmailSummary?.filteredCount ?? 0)
  }

  private var uncertainCount: Int {
    (latestSpaceMailSummary?.pendingUncertainReviewCount ?? latestSpaceMailSummary?.uncertainCount ?? 0)
      + (latestGmailSummary?.pendingUncertainReviewCount ?? latestGmailSummary?.uncertainCount ?? 0)
  }

  private var latestMailboxDetail: String {
    let summaries: [String] = [
      latestSpaceMailSummary.map { "SpaceMail: \($0.fetchedCount) fetched, \($0.importedCount) imported, \($0.duplicateCount) duplicate, \($0.duplicateRefreshedCount) refreshed, \($0.filteredCount) filtered, \($0.pendingUncertainReviewCount + $0.uncertainCount) uncertain. \($0.nextAction)" },
      latestGmailSummary.map { "Gmail: \($0.fetchedCount) fetched, \($0.importedCount) imported, \($0.duplicateCount) duplicate, \($0.duplicateRefreshedCount) refreshed, \($0.filteredCount) filtered, \($0.pendingUncertainReviewCount + $0.uncertainCount) uncertain. \($0.nextAction)" }
    ].compactMap { $0 }
    guard !summaries.isEmpty else {
      return "No refresh summary yet. Start with the local demo workflow, then run the active mailbox provider only when credentials or sign-in are ready."
    }
    return summaries.joined(separator: " ")
  }

  private var issueTone: Color {
    if !hasMailboxSetup || !hasMailboxCredentialOrAuth { return .orange }
    if uncertainCount > 0 { return .orange }
    return .teal
  }

  private var issueTitle: String {
    if !hasMailboxSetup { return "Most issues can be tested with the local demo first" }
    if !hasMailboxCredentialOrAuth { return "Mailbox setup exists; credential or sign-in needs attention" }
    if uncertainCount > 0 { return "Mailbox provider has uncertain messages to review" }
    return "Use this guide when Xcode, setup, or mailbox testing stalls"
  }

  private var quickChecks: [(String, String, String, Color)] {
    [
      (
        "Xcode signing error",
        "If Xcode says a development team is required, open the ParcelOps target, choose Signing & Capabilities, select your team, then run again. This is local Xcode state and should not be committed unless deliberately shared.",
        "person.badge.key.fill",
        .orange
      ),
      (
        "LLDB already attached",
        "If Xcode says it cannot attach to a process more than once, stop the running app, quit any duplicate ParcelOps windows if needed, then run again. A clean Xcode restart is acceptable.",
        "ladybug.fill",
        .purple
      ),
      (
        "Settings sheet too tall",
        "Setup editors are intended to scroll with Save and Cancel reachable at the bottom. If actions are hidden, use the Settings setup search to narrow the page and reopen the editor.",
        "rectangle.and.pencil.and.ellipsis",
        .teal
      ),
      (
        "SwiftPM build database error",
        "A command-line build can compile/link successfully and still report a generated .build/build.db disk I/O error. Clean generated build data before treating it as a source failure.",
        "hammer.fill",
        .secondary
      ),
      (
        "Mailbox imports nothing",
        "Mixed mailbox mode is conservative. Filtered non-order mail stays out of Inbox; uncertain messages stay in Mailbox Monitor; only strong order/tracking evidence imports automatically.",
        "line.3.horizontal.decrease.circle",
        .blue
      ),
      (
        "Duplicate mailbox rows",
        "Duplicate provider message IDs should not create duplicate intake. Use refresh summaries, reprocess, or duplicate-refresh audit entries to confirm existing rows were updated or skipped.",
        "doc.on.doc.fill",
        .green
      )
    ]
  }

  private var recoverySteps: [(String, String, String, Color)] {
    [
      ("1. Prove local flow", "Seed the demo workflow from Dashboard or MVP Setup. This avoids relying on live mailbox content while testing UI and persistence.", "wand.and.stars", .green),
      ("2. Check source trail", "Open Inbox, Orders, and order detail. Confirm the source trail points back to intake/import/acceptance context.", "link.badge.plus", .blue),
      ("3. Use Mailbox Monitor", "For the active provider, review latest refresh counts, uncertain examples, filtered examples, classifier tests, and credential or sign-in status before changing parser rules.", "server.rack", .teal),
      ("4. Confirm Audit", "Use Audit to verify local actions. Technical provider diagnostics can stay hidden unless you are debugging parser/provider internals.", "list.clipboard.fill", .purple),
      ("5. Keep generated noise out", "Do not commit xcuserdata, DerivedData, local signing/team changes, or accidental generated project folders unless the change is intentionally shared.", "xmark.bin.fill", .orange)
    ]
  }

  var body: some View {
    SettingsPanel(title: "Hands-on troubleshooting", symbol: "wrench.and.screwdriver.fill") {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "wrench.and.screwdriver.fill")
          .foregroundStyle(issueTone)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 4) {
          Text(issueTitle)
            .font(.headline)
          Text(latestMailboxDetail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Badge(hasMailboxCredentialOrAuth ? "Ready" : "Setup", color: issueTone)
      }

      MetricStrip(items: [
        ("Providers", hasMailboxSetup ? "Set" : "Needed", hasMailboxSetup ? .green : .orange),
        ("Access", hasMailboxCredentialOrAuth ? "Ready" : "Needed", hasMailboxCredentialOrAuth ? .green : .orange),
        ("Fetched", "\(fetchedCount)", .blue),
        ("Filtered", "\(filteredCount)", filteredCount > 0 ? .teal : .secondary),
        ("Uncertain", "\(uncertainCount)", uncertainCount > 0 ? .orange : .secondary),
        ("Audit", "\(store.auditEvents.count)", store.auditEvents.isEmpty ? .orange : .purple)
      ])

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], alignment: .leading, spacing: 10) {
        ForEach(Array(quickChecks.enumerated()), id: \.offset) { _, item in
          troubleshootingTile(title: item.0, detail: item.1, symbol: item.2, color: item.3)
        }
      }

      VStack(alignment: .leading, spacing: 10) {
        Label("Recovery order", systemImage: "arrow.triangle.2.circlepath.circle.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], alignment: .leading, spacing: 10) {
          ForEach(Array(recoverySteps.enumerated()), id: \.offset) { _, item in
            troubleshootingTile(title: item.0, detail: item.1, symbol: item.2, color: item.3)
          }
        }
      }

      CompactActionRow {
        Button("Seed demo workflow", systemImage: "wand.and.stars") {
          store.seedLocalInboxOrderDemoWorkflow()
        }
        .buttonStyle(.borderedProminent)

        NavigationLink { MailboxView(store: store) } label: { Label("Mailbox Monitor", systemImage: "server.rack") }
          .buttonStyle(.bordered)
        NavigationLink { InboxView(store: store) } label: { Label("Inbox", systemImage: "tray.full.fill") }
          .buttonStyle(.bordered)
        NavigationLink { AuditView(store: store) } label: { Label("Audit", systemImage: "list.clipboard.fill") }
          .buttonStyle(.bordered)
        NavigationLink { IntegrationsView(store: store) } label: { Label("Settings", systemImage: "gearshape.fill") }
          .buttonStyle(.bordered)
      }

      Text("Troubleshooting boundary: this guide only explains local recovery steps and can seed local demo records. It does not run mailbox refresh, change credentials, mutate mailbox messages, clean build folders, edit signing, or touch external services.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func troubleshootingTile(title: String, detail: String, symbol: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 6) {
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

struct MVPStatusCard: View {
  var title: String
  var detail: String
  var status: String
  var symbol: String
  var color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top) {
        Image(systemName: symbol)
          .foregroundStyle(color)
          .frame(width: 24)
        Spacer()
        Badge(status, color: color)
      }
      Text(title)
        .font(.headline)
      Text(detail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}
