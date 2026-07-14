import SwiftUI

struct ContactsView: View {
  var store: ParcelOpsStore

  @State private var selectedOrganisation: String?
  @State private var selectedEntityType: ContactLinkedEntityType?
  @State private var selectedEnabledState: Bool?
  @State private var selectedChannel: CommunicationChannel?
  @State private var selectedReviewState: ReviewState?
  @State private var contactSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var organisations: [String] {
    Array(Set(store.contactDirectoryEntries.map(\.organisation))).sorted()
  }

  private var baseFilteredContacts: [ContactDirectoryEntry] {
    store.contactDirectoryEntries.filter { contact in
      let matchesOrganisation = selectedOrganisation == nil || contact.organisation == selectedOrganisation
      let matchesEntity = selectedEntityType == nil || contact.linkedEntityType == selectedEntityType
      let matchesEnabled = selectedEnabledState == nil || contact.isEnabled == selectedEnabledState
      let matchesChannel = selectedChannel == nil || contact.channelPreference == selectedChannel
      let matchesReview = selectedReviewState == nil || contact.reviewState == selectedReviewState
      return matchesOrganisation && matchesEntity && matchesEnabled && matchesChannel && matchesReview
    }
  }

  private var filteredContacts: [ContactDirectoryEntry] {
    let query = contactSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredContacts }
    return baseFilteredContacts.filter { contact in
      contactSearchParts(contact).joined(separator: " ").localizedLowercase.contains(query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedOrganisation != nil
      || selectedEntityType != nil
      || selectedEnabledState != nil
      || selectedChannel != nil
      || selectedReviewState != nil
      || !contactSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Contacts")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Local supplier, store, carrier, Shopify, and internal team contacts for manual follow-up.")
            .foregroundStyle(.secondary)
        }

        filterBar
        inboxContactCoverage
        gmailContactReadinessPanel

        SettingsPanel(title: "Contact directory", symbol: "person.crop.circle.badge.checkmark") {
          HStack {
            Text("\(filteredContacts.count) visible contacts")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredContacts.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add contact", systemImage: "plus", action: store.addContactDirectoryEntryPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredContacts.isEmpty {
            MVPEmptyState(title: "No contacts match this view", detail: hasActiveFilters ? "Clear search or filters to return to all local contacts." : "Add a local contact to keep supplier, carrier, store, and internal follow-up details close to operational records.", symbol: "person.crop.circle.badge.checkmark", actionTitle: hasActiveFilters ? "Clear filters" : "Add contact", action: hasActiveFilters ? clearFilters : store.addContactDirectoryEntryPlaceholder)
          } else {
            ForEach(filteredContacts) { contact in
              ContactDirectoryRow(contact: contact, store: store, linkedOrder: linkedOrder(for: contact), inboxOrders: inboxOrders(for: contact), suggestedAccounts: store.suggestedAccounts(for: contact), suggestedProfiles: store.suggestedVendorProfiles(for: contact), destinationAddresses: store.suggestedDestinationAddresses(for: contact), deliveryInstructions: store.suggestedDeliveryInstructions(for: contact), packageContents: store.suggestedPackageContents(for: contact)) { updatedContact in
                store.updateContactDirectoryEntry(updatedContact)
              } onToggle: {
                store.toggleContactDirectoryEntry(contact)
              } onReviewed: {
                store.markContactDirectoryEntryReviewed(contact)
              } onCreateDraft: {
                store.createDraftMessage(from: contact)
              } onCreateAccount: {
                store.addAccountCredentialRecord(linkedEntityType: .contact, linkedEntityID: contact.id.uuidString, organisation: contact.organisation, label: contact.name, linkedContactID: contact.id)
              } onTaskFromAccount: { account in
                store.createReviewTask(from: account)
              } onDraftFromAccount: { account in
                store.createDraftMessage(from: account)
              } onCreateProfile: {
                store.addVendorProfile(profileType: contact.linkedEntityType.vendorProfileType, organisation: contact.organisation, label: contact.name, defaultContactID: contact.id)
              } onTaskFromProfile: { profile in
                store.createReviewTask(from: profile)
              } onDraftFromProfile: { profile in
                store.createDraftMessage(from: profile)
              } onRemove: {
                store.removeContactDirectoryEntry(contact)
              }
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  @ViewBuilder
  private var gmailContactReadinessPanel: some View {
    GmailReleaseBoundaryPanel(
      store: store,
      title: "Gmail contact readiness",
      lead: "Gmail-origin intake can create customer, supplier, carrier, or internal follow-up contacts after a confirmed Inbox order. Use this before treating Gmail contact coverage as routine.",
      sourceMetricTitle: "Gmail contacts",
      sourceCount: gmailContactSourceCount,
      boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store token values, create contacts automatically, or mutate mailbox messages."
    )
  }

  private var gmailContactSourceCount: Int {
    contactProviderRows
      .filter { $0.label.localizedCaseInsensitiveContains("Gmail") }
      .reduce(0) { total, row in total + row.count }
  }

  private var filterBar: some View {
    FilterControlGrid {
      TextField("Search name, organisation, role, email, phone, notes, linked record, or order", text: $contactSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Organisation", selection: $selectedOrganisation) {
        Text("All organisations").tag(nil as String?)
        ForEach(organisations, id: \.self) { organisation in
          Text(organisation).tag(organisation as String?)
        }
      }

      Picker("Record", selection: $selectedEntityType) {
        Text("All records").tag(nil as ContactLinkedEntityType?)
        ForEach(ContactLinkedEntityType.allCases) { entityType in
          Text(entityType.rawValue).tag(entityType as ContactLinkedEntityType?)
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
    selectedOrganisation = nil
    selectedEntityType = nil
    selectedEnabledState = nil
    selectedChannel = nil
    selectedReviewState = nil
    contactSearchText = ""
  }

  private var inboxContactCoverage: some View {
    let inboxOrders = inboxCreatedOrders
    let wishlistOrders = wishlistLinkedOrders
    let linkedContacts = contactsLinkedToInboxOrders
    let actionContacts = linkedContacts.filter { !$0.isEnabled || $0.reviewState != .accepted || $0.email.isPlaceholderValidationValue }
    let missingCount = inboxOrdersMissingContact.count

    return SettingsPanel(title: "Inbox and Wishlist contact readiness", symbol: "person.crop.circle.badge.checkmark") {
      VStack(alignment: .leading, spacing: 10) {
        Text("Checks whether orders created from Inbox intake or Wishlist purchase handoff have usable local contact context for store, carrier, customer, or internal follow-up.")
          .font(.caption)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 150) {
          Badge("\(inboxOrders.count) Inbox orders", color: .blue)
          Badge("\(wishlistOrders.count) Wishlist orders", color: .pink)
          Badge("\(linkedContacts.count) matched contacts", color: .teal)
          Badge("\(actionContacts.count) need action", color: actionContacts.isEmpty ? .green : .orange)
          Badge("\(missingCount) without contact", color: missingCount == 0 ? .green : .orange)
        }

        if !contactProviderRows.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Mailbox source for contacts")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
              ForEach(contactProviderRows, id: \.label) { row in
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

        if inboxOrders.isEmpty && wishlistOrders.isEmpty {
          Text("No Inbox-created or Wishlist-linked orders are present yet. Create an order from Inbox or complete a Wishlist purchase handoff before checking contact coverage.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if linkedContacts.isEmpty {
          Text("No contacts currently match Inbox-created or Wishlist-linked orders by store, carrier, customer/team, or recipient email.")
            .font(.caption)
            .foregroundStyle(.orange)
        } else if actionContacts.isEmpty {
          Text("Matched contacts are enabled, reviewed, and have contact details for current Inbox-created and Wishlist-linked orders.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          ForEach(Array(actionContacts.prefix(3))) { contact in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: contact.isEnabled ? "person.crop.circle.badge.exclamationmark" : "pause.circle.fill")
                .foregroundStyle(contact.isEnabled ? .orange : .red)
              VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                  .font(.caption.bold())
                Text(contactActionSummary(for: contact))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Badge(contact.reviewState.rawValue, color: contact.reviewState.color)
            }
          }
        }
      }
    }
  }

  private var contactProviderRows: [(label: String, count: Int, detail: String, symbol: String, color: Color)] {
    var counts: [String: Int] = [:]
    var tones: [String: String] = [:]
    for order in inboxCreatedOrders {
      for email in linkedIntakeEmails(for: order) {
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
        detail = "SpaceMail intake can suggest store, carrier, customer, and internal contacts for local follow-up."
      case "gmail":
        detail = "Gmail intake can suggest store, carrier, customer, and internal contacts for local follow-up."
      case "mock":
        detail = "Mock mailbox intake supports local contact testing. Confirm live provider context before relying on follow-up contacts."
      default:
        detail = "Local mailbox intake can suggest contact context once linked to an order."
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

  private func linkedOrder(for contact: ContactDirectoryEntry) -> TrackedOrder? {
    guard contact.linkedEntityType == .order, let orderID = UUID(uuidString: contact.linkedEntityID) else { return nil }
    return store.orders.first { $0.id == orderID }
  }

  private var inboxCreatedOrders: [TrackedOrder] {
    store.orders.filter { !linkedIntakeEmails(for: $0).isEmpty }
  }

  private var wishlistLinkedOrders: [TrackedOrder] {
    store.orders.filter { !store.activeWishlistItemsLinked(to: $0).isEmpty }
  }

  private var contactSourceOrders: [TrackedOrder] {
    uniqueOrders(inboxCreatedOrders + wishlistLinkedOrders)
  }

  private var contactsLinkedToInboxOrders: [ContactDirectoryEntry] {
    store.contactDirectoryEntries.filter { contact in
      contactSourceOrders.contains { order in
        contactMatches(contact, order: order)
      }
    }
  }

  private var inboxOrdersMissingContact: [TrackedOrder] {
    contactSourceOrders.filter { order in
      !store.contactDirectoryEntries.contains { contact in
        contactMatches(contact, order: order)
      }
    }
  }

  private func inboxOrders(for contact: ContactDirectoryEntry) -> [TrackedOrder] {
    contactSourceOrders.filter { contactMatches(contact, order: $0) }
  }

  private func uniqueOrders(_ orders: [TrackedOrder]) -> [TrackedOrder] {
    var seen: Set<UUID> = []
    var unique: [TrackedOrder] = []
    for order in orders where seen.contains(order.id) == false {
      seen.insert(order.id)
      unique.append(order)
    }
    return unique
  }

  private func contactMatches(_ contact: ContactDirectoryEntry, order: TrackedOrder) -> Bool {
    if contact.linkedEntityType == .order, let linkedID = UUID(uuidString: contact.linkedEntityID), linkedID == order.id {
      return true
    }
    let organisation = contact.organisation.trimmingCharacters(in: .whitespacesAndNewlines)
    let name = contact.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let email = contact.email.trimmingCharacters(in: .whitespacesAndNewlines)
    return (!organisation.isEmpty && !organisation.isPlaceholderValidationValue && (order.store.localizedCaseInsensitiveContains(organisation) || order.carrier.localizedCaseInsensitiveContains(organisation) || order.customer.localizedCaseInsensitiveContains(organisation)))
      || (!name.isEmpty && !name.isPlaceholderValidationValue && order.customer.localizedCaseInsensitiveContains(name))
      || (!email.isEmpty && !email.isPlaceholderValidationValue && order.recipientEmail.localizedCaseInsensitiveContains(email))
  }

  private func contactActionSummary(for contact: ContactDirectoryEntry) -> String {
    var parts: [String] = []
    if !contact.isEnabled { parts.append("enable or confirm disabled contact") }
    if contact.reviewState != .accepted { parts.append("mark reviewed") }
    if contact.email.isPlaceholderValidationValue && contact.phone.isPlaceholderValidationValue { parts.append("add contact method") }
    return parts.isEmpty ? "Contact is enabled and reviewed." : parts.joined(separator: ", ")
  }

  private func linkedIntakeEmails(for order: TrackedOrder) -> [ForwardedEmailIntake] {
    store.linkedIntakeEmails(for: order)
  }

  private func contactSearchParts(_ contact: ContactDirectoryEntry) -> [String] {
    let order = linkedOrder(for: contact)
    return [
      contact.id.uuidString,
      contact.name,
      contact.organisation,
      contact.role,
      contact.email,
      contact.phone,
      contact.channelPreference.rawValue,
      contact.linkedEntityType.rawValue,
      contact.linkedEntityID,
      contact.notes,
      contact.isEnabled ? "Enabled" : "Disabled",
      contact.createdDate,
      contact.lastContactedDate,
      contact.reviewState.rawValue,
      order?.orderNumber ?? "",
      order?.store ?? "",
      order?.customer ?? "",
      order?.recipientEmail ?? "",
      order?.trackingNumber ?? "",
      order?.carrier ?? "",
      order?.destination ?? ""
    ]
  }
}

struct ContactDirectoryRow: View {
  var contact: ContactDirectoryEntry
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
  var inboxOrders: [TrackedOrder] = []
  var suggestedAccounts: [AccountCredentialRecord] = []
  var suggestedProfiles: [VendorProfile] = []
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var onSave: (ContactDirectoryEntry) -> Void
  var onToggle: () -> Void
  var onReviewed: () -> Void
  var onCreateDraft: () -> Void
  var onCreateAccount: () -> Void = {}
  var onTaskFromAccount: (AccountCredentialRecord) -> Void = { _ in }
  var onDraftFromAccount: (AccountCredentialRecord) -> Void = { _ in }
  var onCreateProfile: () -> Void = {}
  var onTaskFromProfile: (VendorProfile) -> Void = { _ in }
  var onDraftFromProfile: (VendorProfile) -> Void = { _ in }
  var onRemove: () -> Void
  @State private var isEditing = false
  @State private var feedbackMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: contact.linkedEntityType.symbol)
          .foregroundStyle(contact.isEnabled ? .green : .secondary)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(contact.name)
                .font(.headline)
              Text("\(contact.organisation) • \(contact.role)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(contact.isEnabled ? "Enabled" : "Disabled", color: contact.isEnabled ? .green : .gray)
          }

          Text(contact.notes)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          HStack(spacing: 8) {
            Badge(contact.reviewState.rawValue, color: contact.reviewState.color)
            Label(contact.channelPreference.rawValue, systemImage: contact.channelPreference.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
            Label(contact.linkedEntityType.rawValue, systemImage: contact.linkedEntityType.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(contact.lastContactedDate)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      if let feedbackMessage {
        ContactActionFeedbackPanel(message: feedbackMessage, store: store)
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
        Button(contact.isEnabled ? "Disable" : "Enable", systemImage: contact.isEnabled ? "pause.circle.fill" : "play.circle.fill") {
          onToggle()
          feedbackMessage = contact.isEnabled ? "Contact disabled locally." : "Contact enabled locally."
        }
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.circle.fill") {
          onReviewed()
          feedbackMessage = "Contact marked reviewed locally."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Draft created from contact. Check Drafts."
        }
          .buttonStyle(.bordered)
        Button("Account", systemImage: "key.badge.plus") {
          onCreateAccount()
          feedbackMessage = "Account placeholder created from contact. Check Accounts."
        }
          .buttonStyle(.bordered)
        Button("Profile", systemImage: "building.2.crop.circle") {
          onCreateProfile()
          feedbackMessage = "Vendor profile created from contact. Check Vendor Profiles."
        }
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash") {
          onRemove()
          feedbackMessage = "Contact removed locally."
        }
          .buttonStyle(.bordered)
      }

      if !inboxOrders.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Label("Inbox/Wishlist contact source", systemImage: "tray.and.arrow.down.fill")
            .font(.caption.bold())
            .foregroundStyle(.teal)
          ForEach(inboxOrders.prefix(2)) { order in
            HStack(spacing: 6) {
              Badge(order.orderNumber, color: order.orderNumber.isPlaceholderValidationValue ? .orange : .blue)
              Badge(order.store, color: .teal)
              Text(order.customer)
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

      if !contactWarnings.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Label("Contact follow-up", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.bold())
            .foregroundStyle(.orange)
          ForEach(contactWarnings, id: \.self) { warning in
            Text(warning)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      if !suggestedAccounts.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Label("Linked accounts", systemImage: "key.horizontal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          ForEach(suggestedAccounts) { account in
            AccountSuggestionRow(account: account) {
              onTaskFromAccount(account)
              feedbackMessage = "Follow-up task created from linked account. Check Tasks."
            } onCreateDraft: {
              onDraftFromAccount(account)
              feedbackMessage = "Draft created from linked account. Check Drafts."
            }
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
      ContactDirectoryEditView(contact: contact) { updatedContact in
        onSave(updatedContact)
        feedbackMessage = "Contact saved locally."
      }
    }
  }

  private var contactWarnings: [String] {
    var warnings: [String] = []
    if !contact.isEnabled && !inboxOrders.isEmpty {
      warnings.append("This contact matches an Inbox-created or Wishlist-linked order but is disabled.")
    }
    if contact.reviewState != .accepted && !inboxOrders.isEmpty {
      warnings.append("Contact needs review before relying on it for local follow-up.")
    }
    if contact.email.isPlaceholderValidationValue && contact.phone.isPlaceholderValidationValue && !inboxOrders.isEmpty {
      warnings.append("Contact method is missing or placeholder.")
    }
    return warnings
  }

  private func sourceEmails(using store: ParcelOpsStore) -> [ForwardedEmailIntake] {
    var seen = Set<UUID>()
    return inboxOrders.flatMap { order -> [ForwardedEmailIntake] in
      return store.linkedIntakeEmails(for: order)
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

private struct ContactActionFeedbackPanel: View {
  var message: String
  var store: ParcelOpsStore?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(message, systemImage: "checkmark.circle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.green)
      Text("This is local reference follow-up. No contact sync, account login, outbound email, or external service was used.")
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
          if message.localizedCaseInsensitiveContains("account") {
            NavigationLink {
              AccountsView(store: store)
            } label: {
              Label("Open Accounts", systemImage: "key.horizontal.fill")
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

struct ContactSuggestionRow: View {
  var contact: ContactDirectoryEntry
  var onCreateDraft: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: contact.linkedEntityType.symbol)
        .foregroundStyle(contact.reviewState.color)
        .frame(width: 24, height: 24)
      VStack(alignment: .leading, spacing: 3) {
        Text(contact.name)
          .font(.callout.weight(.semibold))
        Text("\(contact.organisation) • \(contact.role)")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(contact.channelPreference == .phoneScript ? contact.phone : contact.email)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button("Draft", systemImage: "envelope.open.fill", action: onCreateDraft)
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
    .padding(10)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct ContactDirectoryEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: ContactDirectoryEntry
  var onSave: (ContactDirectoryEntry) -> Void

  init(contact: ContactDirectoryEntry, onSave: @escaping (ContactDirectoryEntry) -> Void) {
    self._draft = State(initialValue: contact)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Contact") {
          TextField("Name", text: $draft.name)
          TextField("Organisation", text: $draft.organisation)
          TextField("Role", text: $draft.role)
          TextField("Email", text: $draft.email)
          TextField("Phone", text: $draft.phone)
          Picker("Channel preference", selection: $draft.channelPreference) {
            ForEach(CommunicationChannel.allCases) { channel in
              Text(channel.rawValue).tag(channel)
            }
          }
        }

        Section("Linked record") {
          Picker("Linked type", selection: $draft.linkedEntityType) {
            ForEach(ContactLinkedEntityType.allCases) { entityType in
              Text(entityType.rawValue).tag(entityType)
            }
          }
          TextField("Linked ID", text: $draft.linkedEntityID)
        }

        Section("Notes") {
          TextField("Notes", text: $draft.notes, axis: .vertical)
            .lineLimit(3...7)
        }

        Section("State") {
          Toggle("Enabled", isOn: $draft.isEnabled)
          TextField("Created date", text: $draft.createdDate)
          TextField("Last contacted", text: $draft.lastContactedDate)
          Picker("Review state", selection: $draft.reviewState) {
            Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted)
            Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview)
            Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor)
          }
        }
      }
      .navigationTitle("Edit contact")
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
      .frame(minWidth: 560, minHeight: 620)
      #endif
    }
  }
}
