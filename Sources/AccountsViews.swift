import SwiftUI

struct AccountsView: View {
  var store: ParcelOpsStore

  @State private var selectedOrganisation: String?
  @State private var selectedEntityType: AccountLinkedEntityType?
  @State private var selectedEnabledState: Bool?
  @State private var selectedCredentialStatus: CredentialStorageStatus?
  @State private var selectedMFAStatus: MFAStatus?
  @State private var selectedReviewState: ReviewState?
  @State private var accountSearchText = ""
  @State private var showAllAccounts = false
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var organisations: [String] {
    Array(Set(store.accountCredentialRecords.map(\.organisation))).sorted()
  }

  private var baseFilteredAccounts: [AccountCredentialRecord] {
    store.accountCredentialRecords.filter { account in
      let matchesOrganisation = selectedOrganisation == nil || account.organisation == selectedOrganisation
      let matchesEntity = selectedEntityType == nil || account.linkedEntityType == selectedEntityType
      let matchesEnabled = selectedEnabledState == nil || account.isEnabled == selectedEnabledState
      let matchesCredential = selectedCredentialStatus == nil || account.credentialStorageStatus == selectedCredentialStatus
      let matchesMFA = selectedMFAStatus == nil || account.mfaStatus == selectedMFAStatus
      let matchesReview = selectedReviewState == nil || account.reviewState == selectedReviewState
      return matchesOrganisation && matchesEntity && matchesEnabled && matchesCredential && matchesMFA && matchesReview
    }
  }

  private var filteredAccounts: [AccountCredentialRecord] {
    let query = accountSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredAccounts }
    return baseFilteredAccounts.filter { account in
      accountSearchParts(account).joined(separator: " ").localizedLowercase.contains(query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedOrganisation != nil
      || selectedEntityType != nil
      || selectedEnabledState != nil
      || selectedCredentialStatus != nil
      || selectedMFAStatus != nil
      || selectedReviewState != nil
      || !accountSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var displayedAccounts: [AccountCredentialRecord] {
    showAllAccounts ? filteredAccounts : Array(filteredAccounts.prefix(48))
  }

  private var hiddenDisplayedAccountCount: Int {
    max(filteredAccounts.count - displayedAccounts.count, 0)
  }

  private var gmailAccountSourceCount: Int {
    accountProviderRows
      .filter { $0.label.localizedCaseInsensitiveContains("Gmail") }
      .reduce(0) { total, row in total + row.count }
  }

  private var microsoft365AccountSourceCount: Int {
    accountProviderRows
      .filter { $0.label.localizedCaseInsensitiveContains("Microsoft 365") || $0.label.localizedCaseInsensitiveContains("Outlook") }
      .reduce(0) { total, row in total + row.count }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Accounts")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Local credential placeholders for supplier, store, carrier, Shopify, and internal accounts. Secrets are not stored here.")
            .foregroundStyle(.secondary)
        }

        filterBar
        inboxAccountCoverage
        gmailAccountReadinessPanel

        SettingsPanel(title: "Account placeholders", symbol: "key.horizontal.fill") {
          HStack {
            Text("\(filteredAccounts.count) visible accounts")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredAccounts.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add account", systemImage: "plus", action: store.addAccountCredentialRecordPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredAccounts.isEmpty {
            MVPEmptyState(title: "No account placeholders match this view", detail: hasActiveFilters ? "Clear search or filters to return to all local account placeholders." : "Add a local account placeholder to track review status and setup notes without storing secrets.", symbol: "key.horizontal.fill", actionTitle: hasActiveFilters ? "Clear filters" : "Add account", action: hasActiveFilters ? clearFilters : store.addAccountCredentialRecordPlaceholder)
          } else {
            if hiddenDisplayedAccountCount > 0 {
              CompactActionRow {
                Label("Showing first \(displayedAccounts.count) accounts", systemImage: "speedometer")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.secondary)
                Badge("\(hiddenDisplayedAccountCount) older hidden", color: .secondary)
                Button(showAllAccounts ? "Show first 48" : "Show all \(filteredAccounts.count)", systemImage: showAllAccounts ? "rectangle.compress.vertical" : "rectangle.expand.vertical") {
                  withAnimation(.snappy) {
                    showAllAccounts.toggle()
                  }
                }
                .buttonStyle(.bordered)
              }
              Text("Search and filters still scan every local account placeholder. The default list is capped so Accounts opens quickly with accumulated test data.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(displayedAccounts) { account in
              AccountCredentialRow(account: account, store: store, linkedOrder: linkedOrder(for: account), inboxOrders: inboxOrders(for: account), contacts: store.contactDirectoryEntries, suggestedProfiles: store.suggestedVendorProfiles(for: account), destinationAddresses: store.suggestedDestinationAddresses(for: account), deliveryInstructions: store.suggestedDeliveryInstructions(for: account), packageContents: store.suggestedPackageContents(for: account)) { updatedAccount in
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
              } onCreateProfile: {
                store.addVendorProfile(profileType: account.linkedEntityType.vendorProfileType, organisation: account.organisation, label: account.accountName, defaultAccountID: account.id)
              } onTaskFromProfile: { profile in
                store.createReviewTask(from: profile)
              } onDraftFromProfile: { profile in
                store.createDraftMessage(from: profile)
              } onRemove: {
                store.removeAccountCredentialRecord(account)
              }
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search account, organisation, username label, login URL, notes, linked record, or order", text: $accountSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Organisation", selection: $selectedOrganisation) {
        Text("All organisations").tag(nil as String?)
        ForEach(organisations, id: \.self) { organisation in
          Text(organisation).tag(organisation as String?)
        }
      }

      Picker("Record", selection: $selectedEntityType) {
        Text("All records").tag(nil as AccountLinkedEntityType?)
        ForEach(AccountLinkedEntityType.allCases) { entityType in
          Text(entityType.rawValue).tag(entityType as AccountLinkedEntityType?)
        }
      }

      Picker("Enabled", selection: $selectedEnabledState) {
        Text("All states").tag(nil as Bool?)
        Text("Enabled").tag(true as Bool?)
        Text("Disabled").tag(false as Bool?)
      }

      Picker("Credential", selection: $selectedCredentialStatus) {
        Text("All credential states").tag(nil as CredentialStorageStatus?)
        ForEach(CredentialStorageStatus.allCases) { status in
          Text(status.rawValue).tag(status as CredentialStorageStatus?)
        }
      }

      Picker("MFA", selection: $selectedMFAStatus) {
        Text("All MFA states").tag(nil as MFAStatus?)
        ForEach(MFAStatus.allCases) { status in
          Text(status.rawValue).tag(status as MFAStatus?)
        }
      }

      Picker("Review", selection: $selectedReviewState) {
        Text("All review states").tag(nil as ReviewState?)
        Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted as ReviewState?)
        Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview as ReviewState?)
        Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor as ReviewState?)
      }

      if hasActiveFilters {
        Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle") {
          clearFilters()
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private func clearFilters() {
    selectedOrganisation = nil
    selectedEntityType = nil
    selectedEnabledState = nil
    selectedCredentialStatus = nil
    selectedMFAStatus = nil
    selectedReviewState = nil
    accountSearchText = ""
  }

  @ViewBuilder
  private var gmailAccountReadinessPanel: some View {
    CollapsedProviderEvidencePanel(
      title: "Mailbox account evidence",
      detail: "Open provider release evidence only when account placeholder coverage depends on mailbox provider source trails."
    ) {
      VStack(alignment: .leading, spacing: 10) {
        GmailReleaseBoundaryPanel(
          store: store,
          title: "Gmail account readiness",
          lead: "Gmail-origin intake should create account follow-up only after the Gmail setup can sign in, fetch read-only messages, classify likely order mail, and hand confirmed Inbox rows into Orders.",
          sourceMetricTitle: "Gmail account sources",
          sourceCount: gmailAccountSourceCount,
          boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store tokens, create credentials, or change account placeholders automatically."
        )
        Microsoft365ReleaseBoundaryPanel(
          store: store,
          title: "Outlook account readiness",
          lead: "Outlook-origin intake should create account follow-up only after Microsoft setup, sign-in, Graph diagnostics, and confirmed Inbox rows are clear.",
          sourceMetricTitle: "Outlook account sources",
          sourceCount: microsoft365AccountSourceCount,
          boundaryDetail: "Local-only boundary: this panel does not start Microsoft sign-in, request tokens, fetch Outlook messages, create credentials, or change account placeholders automatically."
        )
      }
    }
  }

  private var inboxAccountCoverage: some View {
    let sourceOrders = store.operatorSourceOrders
    let linkedAccounts = accountsLinkedToInboxOrders
    let actionAccounts = linkedAccounts.filter { account in
      !account.isEnabled
        || account.reviewState != .accepted
        || account.credentialStorageStatus == .needsSetup
        || account.credentialStorageStatus == .accessPending
        || account.mfaStatus == .needsReview
        || account.mfaStatus == .unknown
    }
    let missingCount = inboxOrdersMissingAccount.count

    return SettingsPanel(title: "Inbox and Wishlist account readiness", symbol: "key.horizontal.fill") {
      VStack(alignment: .leading, spacing: 10) {
        Text("Checks whether orders created from Inbox intake or Wishlist purchase handoff have local account placeholders when manual supplier, store, carrier, or portal follow-up may be needed. No secrets are stored here.")
          .font(.caption)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 150) {
          Badge("\(store.intakeLinkedOrderCount) Inbox orders", color: .blue)
          Badge("\(store.wishlistLinkedOrderCount) Wishlist orders", color: .pink)
          Badge("\(linkedAccounts.count) matched accounts", color: .teal)
          Badge("\(actionAccounts.count) need action", color: actionAccounts.isEmpty ? .green : .orange)
          Badge("\(missingCount) without account", color: missingCount == 0 ? .green : .orange)
        }

        if !accountProviderRows.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Mailbox source for accounts")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
              ForEach(accountProviderRows, id: \.label) { row in
                HStack(alignment: .top, spacing: 10) {
                  Image(systemName: row.symbol)
                    .foregroundStyle(row.color)
                    .frame(width: 22, height: 22)
                  VStack(alignment: .leading, spacing: 4) {
                    HStack {
                      Text(row.label)
                        .font(.caption.weight(.semibold))
                      Spacer()
                      Badge("\(row.count) intake", color: row.color)
                    }
                    Text(row.detail)
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                      .fixedSize(horizontal: false, vertical: true)
                  }
                }
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(row.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
              }
            }
          }
        }

        if sourceOrders.isEmpty {
          Text("No Inbox-created or Wishlist-linked orders are present yet. Create an order from Inbox or complete a Wishlist purchase handoff before checking account placeholder coverage.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if linkedAccounts.isEmpty {
          Text("No account placeholders currently match Inbox-created or Wishlist-linked orders by store, carrier, linked contact, or linked order.")
            .font(.caption)
            .foregroundStyle(.orange)
        } else if actionAccounts.isEmpty {
          Text("Matched account placeholders are enabled, reviewed, checked, and ready as non-secret local references.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          ForEach(Array(actionAccounts.prefix(3))) { account in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: account.isEnabled ? "key.horizontal.fill" : "pause.circle.fill")
                .foregroundStyle(account.isEnabled ? .orange : .red)
              VStack(alignment: .leading, spacing: 2) {
                Text(account.accountName)
                  .font(.caption.bold())
                Text(accountActionSummary(for: account))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Badge(account.credentialStorageStatus.rawValue, color: account.credentialStorageStatus.color)
            }
          }
        }
      }
    }
  }

  private var accountProviderRows: [(label: String, count: Int, detail: String, symbol: String, color: Color)] {
    var counts: [String: Int] = [:]
    var tones: [String: String] = [:]
    for order in store.operatorSourceOrders {
      for email in store.linkedIntakeEmails(for: order) {
        let summary = store.intakeSourceSummary(for: email)
        counts[summary.label, default: 0] += 1
        tones[summary.label] = summary.tone
      }
    }
    return counts.map { label, count in
      let tone = tones[label] ?? ""
      let detail: String
      switch tone {
      case "spacemail":
        detail = "SpaceMail intake can suggest supplier, store, carrier, and portal account placeholders for manual follow-up."
      case "gmail":
        detail = "Gmail intake can suggest supplier, store, carrier, and portal account placeholders for manual follow-up."
      case "mock":
        detail = "Mock mailbox intake supports local account testing. Confirm live provider context before relying on account placeholders."
      default:
        detail = "Local mailbox intake can suggest account placeholder context once linked to an order."
      }
      return (
        label: label,
        count: count,
        detail: detail,
        symbol: providerSymbol(for: tone, label: label),
        color: sourceColor(for: tone)
      )
    }
    .sorted { lhs, rhs in
      if lhs.count == rhs.count {
        return lhs.label < rhs.label
      }
      return lhs.count > rhs.count
    }
  }

  private func sourceColor(for tone: String) -> Color {
    switch tone {
    case "spacemail":
      return .teal
    case "gmail":
      return .blue
    case "mock":
      return .purple
    case "microsoft", "mailbox":
      return .blue
    default:
      return .secondary
    }
  }

  private func providerSymbol(for tone: String, label: String) -> String {
    if tone == "gmail" || label.localizedCaseInsensitiveContains("Gmail") {
      return "envelope.badge.shield.half.filled"
    }
    if tone == "spacemail" || label.localizedCaseInsensitiveContains("SpaceMail") {
      return "server.rack"
    }
    if tone == "mock" {
      return "testtube.2"
    }
    return "envelope.open.fill"
  }

  private func linkedOrder(for account: AccountCredentialRecord) -> TrackedOrder? {
    guard account.linkedEntityType == .order, let orderID = UUID(uuidString: account.linkedEntityID) else { return nil }
    return store.orders.first { $0.id == orderID }
  }




  private var accountsLinkedToInboxOrders: [AccountCredentialRecord] {
    store.accountCredentialRecords.filter { account in
      store.operatorSourceOrders.contains { order in
        accountMatches(account, order: order)
      }
    }
  }

  private var inboxOrdersMissingAccount: [TrackedOrder] {
    store.operatorSourceOrders.filter { order in
      !store.accountCredentialRecords.contains { account in
        accountMatches(account, order: order)
      }
    }
  }

  private func inboxOrders(for account: AccountCredentialRecord) -> [TrackedOrder] {
    store.operatorSourceOrders.filter { accountMatches(account, order: $0) }
  }

  private func accountMatches(_ account: AccountCredentialRecord, order: TrackedOrder) -> Bool {
    if account.linkedEntityType == .order, let linkedID = UUID(uuidString: account.linkedEntityID), linkedID == order.id {
      return true
    }
    let organisation = account.organisation.trimmingCharacters(in: .whitespacesAndNewlines)
    let contactMatch = account.linkedContactID.flatMap { contactID in
      store.contactDirectoryEntries.first { $0.id == contactID }
    }.map { contact in
      !contact.email.isPlaceholderValidationValue && order.recipientEmail.localizedCaseInsensitiveContains(contact.email)
    } ?? false
    return contactMatch
      || (!organisation.isEmpty && !organisation.isPlaceholderValidationValue && (order.store.localizedCaseInsensitiveContains(organisation) || order.carrier.localizedCaseInsensitiveContains(organisation) || order.customer.localizedCaseInsensitiveContains(organisation)))
  }

  private func accountActionSummary(for account: AccountCredentialRecord) -> String {
    var parts: [String] = []
    if !account.isEnabled { parts.append("enable or confirm disabled placeholder") }
    if account.reviewState != .accepted { parts.append("mark reviewed") }
    if account.credentialStorageStatus == .needsSetup || account.credentialStorageStatus == .accessPending { parts.append("confirm credential readiness") }
    if account.mfaStatus == .needsReview || account.mfaStatus == .unknown { parts.append("review MFA status") }
    return parts.isEmpty ? "Account placeholder is enabled, reviewed, and checked." : parts.joined(separator: ", ")
  }


  private func accountSearchParts(_ account: AccountCredentialRecord) -> [String] {
    let order = linkedOrder(for: account)
    let mailboxSummaries = order.map { store.mailboxSourceSummaries(for: $0) } ?? []
    var parts = [
      account.id.uuidString,
      account.accountName,
      account.organisation,
      account.linkedContactID?.uuidString ?? "",
      account.linkedEntityType.rawValue,
      account.linkedEntityID,
      account.loginURL,
      account.usernameLabel,
      account.credentialStorageStatus.rawValue,
      account.mfaStatus.rawValue,
      account.renewalReviewDate,
      account.isEnabled ? "Enabled" : "Disabled",
      account.notes,
      account.createdDate,
      account.lastCheckedDate,
      account.reviewState.rawValue,
      order?.orderNumber ?? "",
      order?.store ?? "",
      order?.customer ?? "",
      order?.recipientEmail ?? "",
      order?.trackingNumber ?? "",
      order?.carrier ?? "",
      order?.destination ?? ""
    ]
    parts.append(contentsOf: mailboxSummaries.map(\.providerName))
    parts.append(contentsOf: mailboxSummaries.map(\.mailboxLabel))
    parts.append(contentsOf: mailboxSummaries.map(\.statusLabel))
    parts.append(contentsOf: mailboxSummaries.map(\.detailText))
    return parts
  }
}

struct AccountCredentialRow: View {
  var account: AccountCredentialRecord
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
  var inboxOrders: [TrackedOrder] = []
  var contacts: [ContactDirectoryEntry] = []
  var suggestedProfiles: [VendorProfile] = []
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var onSave: (AccountCredentialRecord) -> Void
  var onToggle: () -> Void
  var onReviewed: () -> Void
  var onChecked: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onCreateProfile: () -> Void = {}
  var onTaskFromProfile: (VendorProfile) -> Void = { _ in }
  var onDraftFromProfile: (VendorProfile) -> Void = { _ in }
  var onRemove: () -> Void
  @State private var isEditing = false
  @State private var feedbackMessage: String?

  private var linkedContact: ContactDirectoryEntry? {
    guard let contactID = account.linkedContactID else { return nil }
    return contacts.first { $0.id == contactID }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: account.linkedEntityType.symbol)
          .foregroundStyle(account.isEnabled ? .green : .secondary)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(account.accountName)
                .font(.headline)
              Text("\(account.organisation) • \(account.usernameLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(account.isEnabled ? "Enabled" : "Disabled", color: account.isEnabled ? .green : .gray)
          }

          Text(account.notes)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          HStack(spacing: 8) {
            Badge(account.credentialStorageStatus.rawValue, color: account.credentialStorageStatus.color)
            Badge(account.mfaStatus.rawValue, color: account.mfaStatus.color)
            Badge(account.reviewState.rawValue, color: account.reviewState.color)
          }

          HStack(spacing: 8) {
            Label(account.linkedEntityType.rawValue, systemImage: account.linkedEntityType.symbol)
            Text("Review \(account.renewalReviewDate)")
            Text("Checked \(account.lastCheckedDate)")
            if let linkedContact {
              Text(linkedContact.name)
            }
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }

      if let feedbackMessage {
        AccountActionFeedbackPanel(message: feedbackMessage, store: store)
      }

      CompactActionRow {
        if let store, let linkedOrder {
          NavigationLink {
            OrderDetailView(order: linkedOrder, store: store)
          } label: {
            Label("Open order", systemImage: "arrow.up.right.square.fill")
          }
          .buttonStyle(.bordered)
        }
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button(account.isEnabled ? "Disable" : "Enable", systemImage: account.isEnabled ? "pause.circle.fill" : "play.circle.fill") {
          onToggle()
          feedbackMessage = account.isEnabled ? "Account placeholder disabled locally." : "Account placeholder enabled locally."
        }
          .buttonStyle(.bordered)
        Button("Checked", systemImage: "checkmark.seal.fill") {
          onChecked()
          feedbackMessage = "Account placeholder checked locally."
        }
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.circle.fill") {
          onReviewed()
          feedbackMessage = "Account placeholder marked reviewed locally."
        }
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Follow-up task created from account. Check Tasks."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Draft created from account. Check Drafts."
        }
          .buttonStyle(.bordered)
        Button("Profile", systemImage: "building.2.crop.circle") {
          onCreateProfile()
          feedbackMessage = "Vendor profile created from account. Check Vendor Profiles."
        }
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash") {
          onRemove()
          feedbackMessage = "Account placeholder removed locally."
        }
          .buttonStyle(.bordered)
      }

      if !inboxOrders.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Label("Inbox/Wishlist account source", systemImage: "tray.and.arrow.down.fill")
            .font(.caption.bold())
            .foregroundStyle(.teal)
          ForEach(inboxOrders.prefix(2)) { order in
            HStack(spacing: 6) {
              Badge(order.orderNumber, color: order.orderNumber.isPlaceholderValidationValue ? .orange : .blue)
              Badge(order.store, color: .teal)
              Text(order.carrier)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
          }
          if let store {
            ForEach(sourceEmails(using: store).prefix(2)) { email in
              HStack(spacing: 6) {
                let source = store.intakeSourceSummary(for: email)
                Badge(source.label, color: sourceColor(for: source.tone))
                Text(email.subject)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
            }
          }
        }
      }

      if let store {
        OrderMailboxSourceTrailPanel(
          summaries: mailboxSummaries(using: store),
          title: "Mailbox provider account trail",
          symbol: "key.horizontal.fill"
        )
      }

      if !accountWarnings.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Label("Account follow-up", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.bold())
            .foregroundStyle(.orange)
          ForEach(accountWarnings, id: \.self) { warning in
            Text(warning)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      if !suggestedProfiles.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Label("Linked profiles", systemImage: "building.2.crop.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          ForEach(suggestedProfiles) { profile in
            VendorProfileSuggestionRow(profile: profile) {
              onTaskFromProfile(profile)
              feedbackMessage = "Follow-up task created from linked profile. Check Tasks."
            } onCreateDraft: {
              onDraftFromProfile(profile)
              feedbackMessage = "Draft created from linked profile. Check Drafts."
            }
          }
        }
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
      AccountCredentialEditView(account: account, contacts: contacts) { updatedAccount in
        onSave(updatedAccount)
        feedbackMessage = "Account placeholder saved locally."
      }
    }
  }

  private var accountWarnings: [String] {
    var warnings: [String] = []
    if !account.isEnabled && !inboxOrders.isEmpty {
      warnings.append("This account placeholder matches an Inbox-created or Wishlist-linked order but is disabled.")
    }
    if account.reviewState != .accepted && !inboxOrders.isEmpty {
      warnings.append("Account placeholder needs review before relying on it for local follow-up.")
    }
    if (account.credentialStorageStatus == .needsSetup || account.credentialStorageStatus == .accessPending) && !inboxOrders.isEmpty {
      warnings.append("Credential readiness is \(account.credentialStorageStatus.rawValue.lowercased()); no secret is stored here.")
    }
    if (account.mfaStatus == .needsReview || account.mfaStatus == .unknown) && !inboxOrders.isEmpty {
      warnings.append("MFA status needs confirmation before using this account for manual follow-up.")
    }
    return warnings
  }

  private func sourceEmails(using store: ParcelOpsStore) -> [ForwardedEmailIntake] {
    var seen = Set<UUID>()
    return inboxOrders.flatMap { order -> [ForwardedEmailIntake] in
      return store.linkedIntakeEmails(for: order)
    }.filter { seen.insert($0.id).inserted }
  }

  private func mailboxSummaries(using store: ParcelOpsStore) -> [OrderMailboxSourceSummary] {
    var seen = Set<String>()
    return inboxOrders.flatMap { order in
      store.mailboxSourceSummaries(for: order)
    }.filter { seen.insert($0.id).inserted }
  }

  private func sourceColor(for tone: String) -> Color {
    switch tone {
    case "spacemail":
      return .teal
    case "gmail":
      return .blue
    case "mock":
      return .purple
    case "microsoft", "mailbox":
      return .blue
    default:
      return .secondary
    }
  }
}

private struct AccountActionFeedbackPanel: View {
  var message: String
  var store: ParcelOpsStore?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(message, systemImage: "checkmark.circle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.green)
      Text("This is local account/reference tracking only. No login, credential sync, Keychain change, outbound email, or external service was used.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if let store {
        CompactActionRow {
          if message.localizedCaseInsensitiveContains("task") {
            NavigationLink {
              TasksView(store: store)
            } label: {
              Label("Open Tasks", systemImage: "checklist")
            }
          }
          if message.localizedCaseInsensitiveContains("draft") {
            NavigationLink {
              CommunicationView(store: store)
            } label: {
              Label("Open Drafts", systemImage: "envelope.open.fill")
            }
          }
          if message.localizedCaseInsensitiveContains("profile") {
            NavigationLink {
              VendorProfilesView(store: store)
            } label: {
              Label("Open Vendor Profiles", systemImage: "building.2.crop.circle.fill")
            }
          }
          NavigationLink {
            AuditView(store: store)
          } label: {
            Label("Open Audit", systemImage: "list.clipboard.fill")
          }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.green.opacity(0.10))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct AccountSuggestionRow: View {
  var account: AccountCredentialRecord
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: account.linkedEntityType.symbol)
        .foregroundStyle(account.credentialStorageStatus.color)
        .frame(width: 24, height: 24)
      VStack(alignment: .leading, spacing: 3) {
        Text(account.accountName)
          .font(.callout.weight(.semibold))
        Text("\(account.organisation) • \(account.credentialStorageStatus.rawValue)")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(account.usernameLabel)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button("Task", systemImage: "checklist", action: onCreateTask)
        .buttonStyle(.bordered)
        .controlSize(.small)
      Button("Draft", systemImage: "envelope.open.fill", action: onCreateDraft)
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
    .padding(10)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct AccountCredentialEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: AccountCredentialRecord
  var contacts: [ContactDirectoryEntry]
  var onSave: (AccountCredentialRecord) -> Void

  init(account: AccountCredentialRecord, contacts: [ContactDirectoryEntry], onSave: @escaping (AccountCredentialRecord) -> Void) {
    self._draft = State(initialValue: account)
    self.contacts = contacts
    self.onSave = onSave
  }

  private var linkedContactBinding: Binding<UUID?> {
    Binding(
      get: { draft.linkedContactID },
      set: { draft.linkedContactID = $0 }
    )
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Account") {
          TextField("Account name", text: $draft.accountName)
          TextField("Organisation", text: $draft.organisation)
          Picker("Linked contact", selection: linkedContactBinding) {
            Text("No linked contact").tag(nil as UUID?)
            ForEach(Array(contacts.prefix(80))) { contact in
              Text("\(contact.name) • \(contact.organisation)").tag(contact.id as UUID?)
            }
            if contacts.count > 80 {
              Text("\(contacts.count - 80) more contacts available in Contacts")
                .tag(nil as UUID?)
                .disabled(true)
            }
          }
          TextField("Login URL", text: $draft.loginURL)
          TextField("Username label", text: $draft.usernameLabel)
        }

        Section("Linked record") {
          Picker("Linked type", selection: $draft.linkedEntityType) {
            ForEach(AccountLinkedEntityType.allCases) { entityType in
              Text(entityType.rawValue).tag(entityType)
            }
          }
          TextField("Linked ID", text: $draft.linkedEntityID)
        }

        Section("Credential status") {
          Picker("Storage status", selection: $draft.credentialStorageStatus) {
            ForEach(CredentialStorageStatus.allCases) { status in
              Text(status.rawValue).tag(status)
            }
          }
          Picker("MFA status", selection: $draft.mfaStatus) {
            ForEach(MFAStatus.allCases) { status in
              Text(status.rawValue).tag(status)
            }
          }
          TextField("Renewal/review date", text: $draft.renewalReviewDate)
        }

        Section("Notes") {
          TextField("Notes", text: $draft.notes, axis: .vertical)
            .lineLimit(3...7)
        }

        Section("State") {
          Toggle("Enabled", isOn: $draft.isEnabled)
          TextField("Created date", text: $draft.createdDate)
          TextField("Last checked", text: $draft.lastCheckedDate)
          Picker("Review state", selection: $draft.reviewState) {
            Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted)
            Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview)
            Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor)
          }
        }
      }
      .navigationTitle("Edit account")
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
      .frame(minWidth: 580, minHeight: 660)
      #endif
    }
  }
}
