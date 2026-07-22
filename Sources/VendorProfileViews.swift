import SwiftUI

struct VendorProfilesView: View {
  var store: ParcelOpsStore

  @State private var selectedProfileType: VendorProfileType?
  @State private var selectedRiskLevel: VendorRiskLevel?
  @State private var selectedEnabledState: Bool?
  @State private var selectedChannel: CommunicationChannel?
  @State private var selectedReviewState: ReviewState?
  @State private var profileSearchText = ""
  @State private var showAllVendorProfiles = false
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var baseFilteredProfiles: [VendorProfile] {
    store.vendorProfiles.filter { profile in
      let matchesType = selectedProfileType == nil || profile.profileType == selectedProfileType
      let matchesRisk = selectedRiskLevel == nil || profile.riskLevel == selectedRiskLevel
      let matchesEnabled = selectedEnabledState == nil || profile.isEnabled == selectedEnabledState
      let matchesChannel = selectedChannel == nil || profile.preferredChannel == selectedChannel
      let matchesReview = selectedReviewState == nil || profile.reviewState == selectedReviewState
      return matchesType && matchesRisk && matchesEnabled && matchesChannel && matchesReview
    }
  }

  private var filteredProfiles: [VendorProfile] {
    let query = profileSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredProfiles }
    return baseFilteredProfiles.filter { profile in
      vendorProfileSearchParts(profile).joined(separator: " ").localizedLowercase.contains(query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedProfileType != nil
      || selectedRiskLevel != nil
      || selectedEnabledState != nil
      || selectedChannel != nil
      || selectedReviewState != nil
      || !profileSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var displayedProfiles: [VendorProfile] {
    showAllVendorProfiles ? filteredProfiles : Array(filteredProfiles.prefix(48))
  }

  private var hiddenDisplayedProfileCount: Int {
    max(filteredProfiles.count - displayedProfiles.count, 0)
  }

  private var gmailVendorSourceCount: Int {
    vendorProviderRows
      .filter { $0.label.localizedCaseInsensitiveContains("Gmail") }
      .reduce(0) { total, row in total + row.count }
  }

  private var microsoft365VendorSourceCount: Int {
    vendorProviderRows
      .filter { $0.label.localizedCaseInsensitiveContains("Microsoft 365") || $0.label.localizedCaseInsensitiveContains("Outlook") }
      .reduce(0) { total, row in total + row.count }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Vendor profiles")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Local vendor, supplier, carrier, Shopify, and team profiles that group operational records.")
            .foregroundStyle(.secondary)
        }

        filterBar
        inboxVendorCoverage
        gmailVendorReadinessPanel

        SettingsPanel(title: "Profiles", symbol: "building.2.crop.circle.fill") {
          HStack {
            Text("\(filteredProfiles.count) visible profiles")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredProfiles.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add profile", systemImage: "plus", action: store.addVendorProfilePlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredProfiles.isEmpty {
            MVPEmptyState(title: "No vendor profiles match this view", detail: hasActiveFilters ? "Clear search or filters to return to all local vendor profiles." : "Add a local profile to group vendor, carrier, store, supplier, and internal team context.", symbol: "building.2.crop.circle.fill", actionTitle: hasActiveFilters ? "Clear filters" : "Add profile", action: hasActiveFilters ? clearFilters : store.addVendorProfilePlaceholder)
          } else {
            if hiddenDisplayedProfileCount > 0 {
              CompactActionRow {
                Label("Showing first \(displayedProfiles.count) profiles", systemImage: "speedometer")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.secondary)
                Badge("\(hiddenDisplayedProfileCount) older hidden", color: .secondary)
                Button(showAllVendorProfiles ? "Show first 48" : "Show all \(filteredProfiles.count)", systemImage: showAllVendorProfiles ? "rectangle.compress.vertical" : "rectangle.expand.vertical") {
                  withAnimation(.snappy) {
                    showAllVendorProfiles.toggle()
                  }
                }
                .buttonStyle(.bordered)
              }
              Text("Search and filters still scan every local vendor profile. The default list is capped so Vendor Profiles opens quickly with accumulated test data.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(displayedProfiles) { profile in
              VendorProfileRow(profile: profile, store: store, inboxOrders: inboxOrders(for: profile), contacts: store.contactDirectoryEntries, accounts: store.accountCredentialRecords, destinationAddresses: store.suggestedDestinationAddresses(for: profile), deliveryInstructions: store.suggestedDeliveryInstructions(for: profile), packageContents: store.suggestedPackageContents(for: profile)) { updatedProfile in
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
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search profile, organisation, website, support, service notes, contact, or account", text: $profileSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Type", selection: $selectedProfileType) {
        Text("All types").tag(nil as VendorProfileType?)
        ForEach(VendorProfileType.allCases) { type in
          Text(type.rawValue).tag(type as VendorProfileType?)
        }
      }

      Picker("Risk", selection: $selectedRiskLevel) {
        Text("All risks").tag(nil as VendorRiskLevel?)
        ForEach(VendorRiskLevel.allCases) { risk in
          Text(risk.rawValue).tag(risk as VendorRiskLevel?)
        }
      }

      Picker("Enabled", selection: $selectedEnabledState) {
        Text("All states").tag(nil as Bool?)
        Text("Enabled").tag(true as Bool?)
        Text("Disabled").tag(false as Bool?)
      }

      Picker("Channel", selection: $selectedChannel) {
        Text("All channels").tag(nil as CommunicationChannel?)
        ForEach(CommunicationChannel.allCases) { channel in
          Text(channel.rawValue).tag(channel as CommunicationChannel?)
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
    selectedProfileType = nil
    selectedRiskLevel = nil
    selectedEnabledState = nil
    selectedChannel = nil
    selectedReviewState = nil
    profileSearchText = ""
  }

  @ViewBuilder
  private var gmailVendorReadinessPanel: some View {
    CollapsedProviderEvidencePanel(
      title: "Mailbox vendor evidence",
      detail: "Open provider release evidence only when vendor profile readiness depends on mailbox provider source trails."
    ) {
      VStack(alignment: .leading, spacing: 10) {
        GmailReleaseBoundaryPanel(
          store: store,
          title: "Gmail vendor readiness",
          lead: "Gmail-origin intake should affect vendor, carrier, store, or supplier profiles only after Gmail can fetch read-only messages and a person confirms the Inbox order context.",
          sourceMetricTitle: "Gmail vendor sources",
          sourceCount: gmailVendorSourceCount,
          boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store tokens, contact vendors, or change vendor profiles automatically."
        )
        Microsoft365ReleaseBoundaryPanel(
          store: store,
          title: "Outlook vendor readiness",
          lead: "Outlook-origin intake should affect vendor, carrier, store, or supplier profiles only after Microsoft setup, Graph diagnostics, and confirmed Inbox order context are clear.",
          sourceMetricTitle: "Outlook vendor sources",
          sourceCount: microsoft365VendorSourceCount,
          boundaryDetail: "Local-only boundary: this panel does not start Microsoft sign-in, request tokens, fetch Outlook messages, contact vendors, or change vendor profiles automatically."
        )
      }
    }
  }

  private var inboxVendorCoverage: some View {
    let sourceOrders = store.operatorSourceOrders
    let linkedProfiles = vendorProfilesLinkedToInboxOrders
    let actionProfiles = linkedProfiles.filter { profile in
      !profile.isEnabled
        || profile.reviewState != .accepted
        || profile.riskLevel == .high
        || profile.riskLevel == .critical
        || profile.defaultContactID == nil
        || profile.defaultAccountID == nil
    }
    let missingCount = inboxOrdersMissingVendor.count

    return SettingsPanel(title: "Inbox and Wishlist vendor readiness", symbol: "building.2.crop.circle.fill") {
      VStack(alignment: .leading, spacing: 10) {
        Text("Checks whether orders created from Inbox intake or Wishlist purchase handoff have local vendor, carrier, store, or supplier context for manual follow-up.")
          .font(.caption)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 150) {
          Badge("\(store.intakeLinkedOrderCount) Inbox orders", color: .blue)
          Badge("\(store.wishlistLinkedOrderCount) Wishlist orders", color: .pink)
          Badge("\(linkedProfiles.count) matched vendors", color: .teal)
          Badge("\(actionProfiles.count) need action", color: actionProfiles.isEmpty ? .green : .orange)
          Badge("\(missingCount) without vendor", color: missingCount == 0 ? .green : .orange)
        }

        if !vendorProviderRows.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Mailbox source for vendors")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
              ForEach(vendorProviderRows, id: \.label) { row in
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
          Text("No Inbox-created or Wishlist-linked orders are present yet. Create an order from Inbox or complete a Wishlist purchase handoff before checking vendor profile coverage.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if linkedProfiles.isEmpty {
          Text("No vendor profiles currently match Inbox-created or Wishlist-linked orders by store, carrier, default contact, or default account.")
            .font(.caption)
            .foregroundStyle(.orange)
        } else if actionProfiles.isEmpty {
          Text("Matched vendor profiles are enabled, reviewed, normal-risk, and have default contact/account context.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          ForEach(Array(actionProfiles.prefix(3))) { profile in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: profile.riskLevel == .high || profile.riskLevel == .critical ? "exclamationmark.triangle.fill" : profile.profileType.symbol)
                .foregroundStyle(profile.riskLevel == .high || profile.riskLevel == .critical ? .red : .orange)
              VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                  .font(.caption.bold())
                Text(profileActionSummary(for: profile))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Badge(profile.riskLevel.rawValue, color: profile.riskLevel.color)
            }
          }
        }
      }
    }
  }

  private var vendorProviderRows: [(label: String, count: Int, detail: String, symbol: String, color: Color)] {
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
        detail = "SpaceMail intake can suggest store, supplier, carrier, and portal vendor profiles for manual follow-up."
      case "gmail":
        detail = "Gmail intake can suggest store, supplier, carrier, and portal vendor profiles for manual follow-up."
      case "mock":
        detail = "Mock mailbox intake supports local vendor testing. Confirm live provider context before relying on vendor profiles."
      default:
        detail = "Local mailbox intake can suggest vendor profile context once linked to an order."
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




  private var vendorProfilesLinkedToInboxOrders: [VendorProfile] {
    store.vendorProfiles.filter { profile in
      store.operatorSourceOrders.contains { order in
        vendorProfile(profile, matches: order)
      }
    }
  }

  private var inboxOrdersMissingVendor: [TrackedOrder] {
    store.operatorSourceOrders.filter { order in
      !store.vendorProfiles.contains { profile in
        vendorProfile(profile, matches: order)
      }
    }
  }

  private func inboxOrders(for profile: VendorProfile) -> [TrackedOrder] {
    store.operatorSourceOrders.filter { vendorProfile(profile, matches: $0) }
  }

  private func vendorProfile(_ profile: VendorProfile, matches order: TrackedOrder) -> Bool {
    let organisation = profile.primaryOrganisation.trimmingCharacters(in: .whitespacesAndNewlines)
    let contactMatch = profile.defaultContactID.flatMap { contactID in
      store.contactDirectoryEntries.first { $0.id == contactID }
    }.map { contact in
      (!contact.email.isPlaceholderValidationValue && order.recipientEmail.localizedCaseInsensitiveContains(contact.email))
        || (!contact.organisation.isPlaceholderValidationValue && (order.store.localizedCaseInsensitiveContains(contact.organisation) || order.carrier.localizedCaseInsensitiveContains(contact.organisation)))
    } ?? false
    let accountMatch = profile.defaultAccountID.flatMap { accountID in
      store.accountCredentialRecords.first { $0.id == accountID }
    }.map { account in
      !account.organisation.isPlaceholderValidationValue && (order.store.localizedCaseInsensitiveContains(account.organisation) || order.carrier.localizedCaseInsensitiveContains(account.organisation))
    } ?? false
    return contactMatch
      || accountMatch
      || (!organisation.isEmpty && !organisation.isPlaceholderValidationValue && (order.store.localizedCaseInsensitiveContains(organisation) || order.carrier.localizedCaseInsensitiveContains(organisation) || order.customer.localizedCaseInsensitiveContains(organisation)))
  }

  private func profileActionSummary(for profile: VendorProfile) -> String {
    var parts: [String] = []
    if !profile.isEnabled { parts.append("enable or confirm disabled vendor") }
    if profile.reviewState != .accepted { parts.append("mark reviewed") }
    if profile.riskLevel == .high || profile.riskLevel == .critical { parts.append("review vendor risk") }
    if profile.defaultContactID == nil { parts.append("add default contact") }
    if profile.defaultAccountID == nil { parts.append("add default account placeholder") }
    return parts.isEmpty ? "Vendor profile is enabled, reviewed, and normal-risk." : parts.joined(separator: ", ")
  }


  private func vendorProfileSearchParts(_ profile: VendorProfile) -> [String] {
    let contact = profile.defaultContactID.flatMap { contactID in
      store.contactDirectoryEntries.first { $0.id == contactID }
    }
    let account = profile.defaultAccountID.flatMap { accountID in
      store.accountCredentialRecords.first { $0.id == accountID }
    }
    let mailboxSummaries = inboxOrders(for: profile).flatMap { store.mailboxSourceSummaries(for: $0) }
    var parts = [
      profile.id.uuidString,
      profile.name,
      profile.profileType.rawValue,
      profile.primaryOrganisation,
      profile.website,
      profile.supportURL,
      profile.defaultContactID?.uuidString ?? "",
      profile.defaultAccountID?.uuidString ?? "",
      profile.preferredChannel.rawValue,
      profile.serviceLevelNotes,
      profile.riskLevel.rawValue,
      profile.isEnabled ? "Enabled" : "Disabled",
      profile.createdDate,
      profile.lastReviewedDate,
      profile.reviewState.rawValue,
      contact?.name ?? "",
      contact?.email ?? "",
      contact?.phone ?? "",
      account?.accountName ?? "",
      account?.usernameLabel ?? ""
    ]
    parts.append(contentsOf: mailboxSummaries.map(\.providerName))
    parts.append(contentsOf: mailboxSummaries.map(\.mailboxLabel))
    parts.append(contentsOf: mailboxSummaries.map(\.statusLabel))
    parts.append(contentsOf: mailboxSummaries.map(\.detailText))
    return parts
  }
}

struct VendorProfileRow: View {
  var profile: VendorProfile
  var store: ParcelOpsStore? = nil
  var inboxOrders: [TrackedOrder] = []
  var contacts: [ContactDirectoryEntry] = []
  var accounts: [AccountCredentialRecord] = []
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var onSave: (VendorProfile) -> Void
  var onToggle: () -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false
  @State private var feedbackMessage: String?

  private var defaultContact: ContactDirectoryEntry? {
    guard let contactID = profile.defaultContactID else { return nil }
    return contacts.first { $0.id == contactID }
  }

  private var defaultAccount: AccountCredentialRecord? {
    guard let accountID = profile.defaultAccountID else { return nil }
    return accounts.first { $0.id == accountID }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: profile.profileType.symbol)
          .foregroundStyle(profile.riskLevel.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(profile.name)
                .font(.headline)
              Text("\(profile.primaryOrganisation) • \(profile.profileType.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(profile.isEnabled ? "Enabled" : "Disabled", color: profile.isEnabled ? .green : .gray)
          }

          Text(profile.serviceLevelNotes)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          HStack(spacing: 8) {
            Badge(profile.riskLevel.rawValue, color: profile.riskLevel.color)
            Badge(profile.reviewState.rawValue, color: profile.reviewState.color)
            Label(profile.preferredChannel.rawValue, systemImage: profile.preferredChannel.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          HStack(spacing: 8) {
            Text("Reviewed \(profile.lastReviewedDate)")
            if let defaultContact {
              Text(defaultContact.name)
            }
            if let defaultAccount {
              Text(defaultAccount.accountName)
            }
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }

      if let feedbackMessage {
        VendorProfileActionFeedbackPanel(message: feedbackMessage)
      }

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button(profile.isEnabled ? "Disable" : "Enable", systemImage: profile.isEnabled ? "pause.circle.fill" : "play.circle.fill") {
          onToggle()
          feedbackMessage = profile.isEnabled
            ? "Vendor profile disabled locally. Existing linked records remain unchanged."
            : "Vendor profile enabled locally. Confirm contact, account, and service notes before relying on it."
        }
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.circle.fill") {
          onReviewed()
          feedbackMessage = "Vendor profile marked reviewed locally. No supplier, account, or mailbox system was contacted."
        }
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Review task created from this vendor profile for local follow-up."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Draft message created from this vendor profile. It remains local until a person sends anything outside ParcelOps."
        }
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash") {
          onRemove()
          feedbackMessage = "Vendor profile removed locally. No supplier, account, credential, or mailbox system was changed."
        }
          .buttonStyle(.bordered)
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

      if !inboxOrders.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Label("Inbox/Wishlist vendor source", systemImage: "tray.and.arrow.down.fill")
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
          title: "Mailbox provider vendor trail",
          symbol: "building.2.crop.circle.fill"
        )
      }

      if !vendorWarnings.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Label("Vendor follow-up", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.bold())
            .foregroundStyle(.orange)
          ForEach(vendorWarnings, id: \.self) { warning in
            Text(warning)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      VendorProfileEditView(profile: profile, contacts: contacts, accounts: accounts) { updatedProfile in
        onSave(updatedProfile)
        feedbackMessage = "Vendor profile details saved locally. Recheck linked contacts, accounts, and service notes if values changed."
      }
    }
  }

  private var vendorWarnings: [String] {
    var warnings: [String] = []
    if !profile.isEnabled && !inboxOrders.isEmpty {
      warnings.append("This vendor profile matches an Inbox-created or Wishlist-linked order but is disabled.")
    }
    if profile.reviewState != .accepted && !inboxOrders.isEmpty {
      warnings.append("Vendor profile needs review before relying on it for local follow-up.")
    }
    if (profile.riskLevel == .high || profile.riskLevel == .critical) && !inboxOrders.isEmpty {
      warnings.append("Vendor risk is \(profile.riskLevel.rawValue.lowercased()); confirm manual follow-up path.")
    }
    if profile.defaultContactID == nil && !inboxOrders.isEmpty {
      warnings.append("Default contact is missing.")
    }
    if profile.defaultAccountID == nil && !inboxOrders.isEmpty {
      warnings.append("Default account placeholder is missing.")
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

private struct VendorProfileActionFeedbackPanel: View {
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

struct VendorProfileSuggestionRow: View {
  var profile: VendorProfile
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: profile.profileType.symbol)
        .foregroundStyle(profile.riskLevel.color)
        .frame(width: 24, height: 24)
      VStack(alignment: .leading, spacing: 3) {
        Text(profile.name)
          .font(.callout.weight(.semibold))
        Text("\(profile.primaryOrganisation) • \(profile.riskLevel.rawValue) risk")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(profile.serviceLevelNotes)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
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

struct VendorProfileEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: VendorProfile
  var contacts: [ContactDirectoryEntry]
  var accounts: [AccountCredentialRecord]
  var onSave: (VendorProfile) -> Void

  init(profile: VendorProfile, contacts: [ContactDirectoryEntry], accounts: [AccountCredentialRecord], onSave: @escaping (VendorProfile) -> Void) {
    self._draft = State(initialValue: profile)
    self.contacts = contacts
    self.accounts = accounts
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Profile") {
          TextField("Name", text: $draft.name)
          Picker("Profile type", selection: $draft.profileType) {
            ForEach(VendorProfileType.allCases) { type in
              Text(type.rawValue).tag(type)
            }
          }
          TextField("Primary organisation", text: $draft.primaryOrganisation)
          TextField("Website", text: $draft.website)
          TextField("Support URL", text: $draft.supportURL)
        }

        Section("Defaults") {
          Picker("Default contact", selection: $draft.defaultContactID) {
            Text("No default contact").tag(nil as UUID?)
            ForEach(Array(contacts.prefix(80))) { contact in
              Text("\(contact.name) • \(contact.organisation)").tag(contact.id as UUID?)
            }
            if contacts.count > 80 {
              Text("\(contacts.count - 80) more contacts available in Contacts")
                .tag(nil as UUID?)
                .disabled(true)
            }
          }
          Picker("Default account", selection: $draft.defaultAccountID) {
            Text("No default account").tag(nil as UUID?)
            ForEach(Array(accounts.prefix(80))) { account in
              Text("\(account.accountName) • \(account.organisation)").tag(account.id as UUID?)
            }
            if accounts.count > 80 {
              Text("\(accounts.count - 80) more accounts available in Accounts")
                .tag(nil as UUID?)
                .disabled(true)
            }
          }
          Picker("Preferred channel", selection: $draft.preferredChannel) {
            ForEach(CommunicationChannel.allCases) { channel in
              Text(channel.rawValue).tag(channel)
            }
          }
        }

        Section("Service") {
          TextField("Service level notes", text: $draft.serviceLevelNotes, axis: .vertical)
            .lineLimit(3...7)
          Picker("Risk level", selection: $draft.riskLevel) {
            ForEach(VendorRiskLevel.allCases) { risk in
              Text(risk.rawValue).tag(risk)
            }
          }
        }

        Section("State") {
          Toggle("Enabled", isOn: $draft.isEnabled)
          TextField("Created date", text: $draft.createdDate)
          TextField("Last reviewed", text: $draft.lastReviewedDate)
          Picker("Review state", selection: $draft.reviewState) {
            Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted)
            Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview)
            Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor)
          }
        }
      }
      .navigationTitle("Edit vendor profile")
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
