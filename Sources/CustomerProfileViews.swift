import SwiftUI

struct CustomerProfilesView: View {
  var store: ParcelOpsStore
  @State private var selectedProfileType: CustomerProfileType?
  @State private var selectedOrganisationTeam: String?
  @State private var selectedEnabled: Bool?
  @State private var selectedDeliveryPreference: DeliveryPreference?
  @State private var selectedReviewState: ReviewState?
  @State private var profileSearchText = ""
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var organisationTeams: [String] {
    Array(Set(store.customerRecipientProfiles.map(\.organisationTeam))).sorted()
  }

  private var baseFilteredProfiles: [CustomerRecipientProfile] {
    store.filteredCustomerRecipientProfiles(
      profileType: selectedProfileType,
      organisationTeam: selectedOrganisationTeam,
      isEnabled: selectedEnabled,
      deliveryPreference: selectedDeliveryPreference,
      reviewState: selectedReviewState
    )
  }

  private var filteredProfiles: [CustomerRecipientProfile] {
    let query = profileSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    guard !query.isEmpty else { return baseFilteredProfiles }
    return baseFilteredProfiles.filter { profile in
      customerProfileSearchParts(profile).joined(separator: " ").localizedLowercase.contains(query)
    }
  }

  private var hasActiveFilters: Bool {
    selectedProfileType != nil
      || selectedOrganisationTeam != nil
      || selectedEnabled != nil
      || selectedDeliveryPreference != nil
      || selectedReviewState != nil
      || !profileSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var gmailProfileSourceCount: Int {
    profileProviderRows
      .filter { $0.label.localizedCaseInsensitiveContains("Gmail") }
      .reduce(0) { total, row in total + row.count }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filters
        inboxProfileCoverage
        gmailProfileReadinessPanel

        SettingsPanel(title: "Profiles", symbol: "person.text.rectangle.fill") {
          HStack {
            Text("\(filteredProfiles.count) visible profiles")
              .font(.caption)
              .foregroundStyle(.secondary)
            if hasActiveFilters {
              Badge("\(baseFilteredProfiles.count) after filters", color: .blue)
            }
            Spacer()
            Button("Add profile", systemImage: "plus", action: store.addCustomerRecipientProfilePlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredProfiles.isEmpty {
            MVPEmptyState(title: "No customer profiles match this view", detail: hasActiveFilters ? "Clear search or filters to return to all local customer and recipient profiles." : "Add a local customer or recipient profile to reuse email, destination, team, and delivery preference details.", symbol: "person.text.rectangle.fill", actionTitle: hasActiveFilters ? "Clear filters" : "Add profile", action: hasActiveFilters ? clearFilters : store.addCustomerRecipientProfilePlaceholder)
          } else {
            ForEach(filteredProfiles) { profile in
              CustomerProfileRow(profile: profile, store: store, inboxOrders: inboxOrders(for: profile), destinationAddresses: store.suggestedDestinationAddresses(for: profile), deliveryInstructions: store.suggestedDeliveryInstructions(for: profile), packageContents: store.suggestedPackageContents(for: profile)) { updatedProfile in
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
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
    .background(.regularMaterial)
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Customer Profiles")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Reusable local customer, team, recipient, and destination records for operational matching.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 8) {
        Button("Add profile", systemImage: "plus", action: store.addCustomerRecipientProfilePlaceholder)
          .buttonStyle(.borderedProminent)
        Badge("\(store.customerProfilesNeedingReview.count) review", color: .orange)
      }
    }
  }

  private var filters: some View {
    FilterControlGrid {
      TextField("Search name, team, email, phone, address, delivery preference, or notes", text: $profileSearchText)
        .textFieldStyle(.roundedBorder)

      Picker("Type", selection: $selectedProfileType) {
        Text("All types").tag(CustomerProfileType?.none)
        ForEach(CustomerProfileType.allCases) { type in
          Label(type.rawValue, systemImage: type.symbol).tag(Optional(type))
        }
      }
      Picker("Team", selection: $selectedOrganisationTeam) {
        Text("All teams").tag(String?.none)
        ForEach(organisationTeams, id: \.self) { team in
          Text(team).tag(Optional(team))
        }
      }
      Picker("Enabled", selection: $selectedEnabled) {
        Text("All states").tag(Bool?.none)
        Text("Enabled").tag(Optional(true))
        Text("Disabled").tag(Optional(false))
      }
      Picker("Delivery", selection: $selectedDeliveryPreference) {
        Text("All delivery").tag(DeliveryPreference?.none)
        ForEach(DeliveryPreference.allCases) { preference in
          Label(preference.rawValue, systemImage: preference.symbol).tag(Optional(preference))
        }
      }
      Picker("Review", selection: $selectedReviewState) {
        Text("All review").tag(ReviewState?.none)
        ForEach([ReviewState.needsReview, .monitor, .accepted], id: \.self) { state in
          Text(state.rawValue).tag(Optional(state))
        }
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
    selectedOrganisationTeam = nil
    selectedEnabled = nil
    selectedDeliveryPreference = nil
    selectedReviewState = nil
    profileSearchText = ""
  }

  @ViewBuilder
  private var gmailProfileReadinessPanel: some View {
    GmailReleaseBoundaryPanel(
      store: store,
      title: "Gmail customer profile readiness",
      lead: "Gmail-origin intake should update customer, recipient, team, and destination context only after Gmail setup is ready and a person confirms the imported Inbox order.",
      sourceMetricTitle: "Gmail profile sources",
      sourceCount: gmailProfileSourceCount,
      boundaryDetail: "Local-only boundary: this panel does not start Google sign-in, fetch Gmail, store tokens, sync contacts, or change customer profiles automatically."
    )
  }

  private var inboxProfileCoverage: some View {
    let inboxOrders = inboxCreatedOrders
    let wishlistOrders = wishlistLinkedOrders
    let linkedProfiles = customerProfilesLinkedToInboxOrders
    let actionProfiles = linkedProfiles.filter { !$0.isEnabled || $0.reviewState != .accepted }
    let missingCount = inboxOrdersMissingProfile.count

    return SettingsPanel(title: "Inbox and Wishlist customer profile readiness", symbol: "person.text.rectangle.fill") {
      VStack(alignment: .leading, spacing: 10) {
        Text("Checks whether orders created from Inbox intake or Wishlist purchase handoff have reusable customer, recipient, or team context before downstream handoff.")
          .font(.caption)
          .foregroundStyle(.secondary)

        CompactMetadataGrid(minimumWidth: 150) {
          Badge("\(inboxOrders.count) Inbox orders", color: .blue)
          Badge("\(wishlistOrders.count) Wishlist orders", color: .pink)
          Badge("\(linkedProfiles.count) matched profiles", color: .teal)
          Badge("\(actionProfiles.count) need action", color: actionProfiles.isEmpty ? .green : .orange)
          Badge("\(missingCount) without profile", color: missingCount == 0 ? .green : .orange)
        }

        if !profileProviderRows.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Mailbox source for profiles")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
              ForEach(profileProviderRows, id: \.label) { row in
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
          Text("No Inbox-created or Wishlist-linked orders are present yet. Create an order from Inbox or complete a Wishlist purchase handoff before using profile coverage checks.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if linkedProfiles.isEmpty {
          Text("No customer profiles currently match Inbox-created or Wishlist-linked orders by email, customer/team, or destination text.")
            .font(.caption)
            .foregroundStyle(.orange)
        } else if actionProfiles.isEmpty {
          Text("Matched customer profiles are enabled and reviewed for current Inbox-created and Wishlist-linked orders.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          ForEach(Array(actionProfiles.prefix(3))) { profile in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: profile.isEnabled ? "checkmark.shield.fill" : "pause.circle.fill")
                .foregroundStyle(profile.isEnabled ? .orange : .red)
              VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                  .font(.caption.bold())
                Text(profileActionSummary(for: profile))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Badge(profile.reviewState.rawValue, color: profile.reviewState.color)
            }
          }
        }
      }
    }
  }

  private var profileProviderRows: [(label: String, count: Int, detail: String, symbol: String, color: Color)] {
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
        detail = "SpaceMail intake can suggest customer, recipient, team, and destination profile context for local review."
      case "gmail":
        detail = "Gmail intake can suggest customer, recipient, team, and destination profile context for local review."
      case "mock":
        detail = "Mock mailbox intake supports local profile testing. Confirm live provider context before relying on reusable profiles."
      default:
        detail = "Local mailbox intake can suggest reusable profile context once linked to an order."
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

  private var inboxCreatedOrders: [TrackedOrder] {
    store.orders.filter { !linkedIntakeEmails(for: $0).isEmpty }
  }

  private var wishlistLinkedOrders: [TrackedOrder] {
    store.orders.filter { !store.wishlistItemsLinked(to: $0).isEmpty }
  }

  private var profileSourceOrders: [TrackedOrder] {
    uniqueOrders(inboxCreatedOrders + wishlistLinkedOrders)
  }

  private var customerProfilesLinkedToInboxOrders: [CustomerRecipientProfile] {
    store.customerRecipientProfiles.filter { profile in
      profileSourceOrders.contains { order in
        customerProfile(profile, matches: order)
      }
    }
  }

  private var inboxOrdersMissingProfile: [TrackedOrder] {
    profileSourceOrders.filter { order in
      !store.customerRecipientProfiles.contains { profile in
        customerProfile(profile, matches: order)
      }
    }
  }

  private func inboxOrders(for profile: CustomerRecipientProfile) -> [TrackedOrder] {
    profileSourceOrders.filter { customerProfile(profile, matches: $0) }
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

  private func customerProfile(_ profile: CustomerRecipientProfile, matches order: TrackedOrder) -> Bool {
    let email = profile.primaryEmail.trimmingCharacters(in: .whitespacesAndNewlines)
    let profileName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    let team = profile.organisationTeam.trimmingCharacters(in: .whitespacesAndNewlines)
    let address = profile.defaultDestinationAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    return (!email.isEmpty && !email.isPlaceholderValidationValue && order.recipientEmail.localizedCaseInsensitiveContains(email))
      || (!profileName.isEmpty && !profileName.isPlaceholderValidationValue && order.customer.localizedCaseInsensitiveContains(profileName))
      || (!team.isEmpty && !team.isPlaceholderValidationValue && order.customer.localizedCaseInsensitiveContains(team))
      || (!address.isEmpty && !address.isPlaceholderValidationValue && (order.destination.localizedCaseInsensitiveContains(address) || address.localizedCaseInsensitiveContains(order.destination)))
  }

  private func profileActionSummary(for profile: CustomerRecipientProfile) -> String {
    var parts: [String] = []
    if !profile.isEnabled { parts.append("enable or confirm disabled profile") }
    if profile.reviewState != .accepted { parts.append("mark reviewed") }
    return parts.isEmpty ? "Profile is enabled and reviewed." : parts.joined(separator: ", ")
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

  private func linkedIntakeEmails(for order: TrackedOrder) -> [ForwardedEmailIntake] {
    let orderNumber = order.orderNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    return store.intakeEmails.filter { email in
      email.linkedOrderID == order.id
        || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.detectedOrderNumber.localizedCaseInsensitiveContains(orderNumber))
        || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.subject.localizedCaseInsensitiveContains(orderNumber))
        || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.rawBodyPreview.localizedCaseInsensitiveContains(orderNumber))
    }
  }

  private func customerProfileSearchParts(_ profile: CustomerRecipientProfile) -> [String] {
    let addresses = store.suggestedDestinationAddresses(for: profile)
    let instructions = store.suggestedDeliveryInstructions(for: profile)
    let packageContents = store.suggestedPackageContents(for: profile)
    var parts = [
      profile.id.uuidString,
      profile.displayName,
      profile.profileType.rawValue,
      profile.organisationTeam,
      profile.primaryEmail,
      profile.phone,
      profile.defaultDestinationAddress,
      profile.deliveryPreference.rawValue,
      profile.notes,
      profile.isEnabled ? "Enabled" : "Disabled",
      profile.createdDate,
      profile.lastReviewedDate,
      profile.reviewState.rawValue
    ]
    parts.append(contentsOf: addresses.flatMap { [$0.label, $0.addressLineSummary, $0.cityRegion, $0.country, $0.preferredCarrier] })
    parts.append(contentsOf: instructions.flatMap { [$0.title, $0.instructionSummary, $0.accessConstraintSummary, $0.carrierNotes] })
    parts.append(contentsOf: packageContents.flatMap { [$0.title, $0.itemSummary, $0.discrepancySummary] })
    return parts
  }
}

struct CustomerProfileRow: View {
  var profile: CustomerRecipientProfile
  var store: ParcelOpsStore? = nil
  var inboxOrders: [TrackedOrder] = []
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var onSave: (CustomerRecipientProfile) -> Void
  var onToggle: () -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false
  @State private var feedbackMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: profile.profileType.symbol)
          .foregroundStyle(profile.isEnabled ? .blue : .orange)
          .frame(width: 22)
        VStack(alignment: .leading, spacing: 4) {
          Text(profile.displayName)
            .font(.headline)
          Text("\(profile.organisationTeam) • \(profile.primaryEmail)")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(profile.defaultDestinationAddress)
            .foregroundStyle(.secondary)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 6) {
          Badge(profile.profileType.rawValue, color: .blue)
          Badge(profile.deliveryPreference.rawValue, color: .teal)
          Badge(profile.isEnabled ? "Enabled" : "Disabled", color: profile.isEnabled ? .green : .gray)
          Badge(profile.reviewState.rawValue, color: profile.reviewState.color)
        }
      }

      Text(profile.notes)
        .font(.callout)
        .foregroundStyle(.secondary)

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
          Label("Inbox/Wishlist profile source", systemImage: "tray.and.arrow.down.fill")
            .font(.caption.bold())
            .foregroundStyle(.teal)
          ForEach(inboxOrders.prefix(2)) { order in
            HStack(spacing: 6) {
              Badge(order.orderNumber, color: order.orderNumber.isPlaceholderValidationValue ? .orange : .blue)
              Badge(order.trackingNumber.isPlaceholderValidationValue ? "Tracking needs review" : "Tracking present", color: order.trackingNumber.isPlaceholderValidationValue ? .orange : .green)
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

      if !profileWarnings.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Label("Profile follow-up", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.bold())
            .foregroundStyle(.orange)
          ForEach(profileWarnings, id: \.self) { warning in
            Text(warning)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      if let feedbackMessage {
        CustomerProfileActionFeedbackPanel(message: feedbackMessage, store: store)
      }

      CompactActionRow {
        Button("Edit", systemImage: "pencil") { isEditing = true }
          .buttonStyle(.bordered)
        Button(profile.isEnabled ? "Disable" : "Enable", systemImage: profile.isEnabled ? "pause.circle" : "play.circle") {
          onToggle()
          feedbackMessage = profile.isEnabled ? "Customer profile disabled locally." : "Customer profile enabled locally."
        }
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.circle.fill") {
          onReviewed()
          feedbackMessage = "Customer profile marked reviewed locally."
        }
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist") {
          onCreateTask()
          feedbackMessage = "Follow-up task created from customer profile. Check Tasks."
        }
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill") {
          onCreateDraft()
          feedbackMessage = "Draft created from customer profile. Check Drafts."
        }
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", role: .destructive) {
          onRemove()
          feedbackMessage = "Customer profile removed locally."
        }
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    .sheet(isPresented: $isEditing) {
      CustomerProfileEditView(profile: profile) { updatedProfile in
        onSave(updatedProfile)
        feedbackMessage = "Customer profile saved locally."
        isEditing = false
      }
    }
  }

  private var profileWarnings: [String] {
    var warnings: [String] = []
    if !profile.isEnabled && !inboxOrders.isEmpty {
      warnings.append("This profile matches an Inbox-created or Wishlist-linked order but is disabled.")
    }
    if profile.reviewState != .accepted && !inboxOrders.isEmpty {
      warnings.append("Profile needs review before relying on it for Inbox-created or Wishlist-linked order handoff.")
    }
    if profile.primaryEmail.isPlaceholderValidationValue && !inboxOrders.isEmpty {
      warnings.append("Primary email is missing or placeholder.")
    }
    if profile.defaultDestinationAddress.isPlaceholderValidationValue && !inboxOrders.isEmpty {
      warnings.append("Default destination address needs confirmation.")
    }
    return warnings
  }

  private func sourceEmails(using store: ParcelOpsStore) -> [ForwardedEmailIntake] {
    var seen = Set<UUID>()
    return inboxOrders.flatMap { order -> [ForwardedEmailIntake] in
      let orderNumber = order.orderNumber.trimmingCharacters(in: .whitespacesAndNewlines)
      return store.intakeEmails.filter { email in
        email.linkedOrderID == order.id
          || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.detectedOrderNumber.localizedCaseInsensitiveContains(orderNumber))
          || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.subject.localizedCaseInsensitiveContains(orderNumber))
          || (!orderNumber.isEmpty && !orderNumber.isPlaceholderValidationValue && email.rawBodyPreview.localizedCaseInsensitiveContains(orderNumber))
      }
    }.filter { seen.insert($0.id).inserted }
  }

  private func sourceColor(for tone: String) -> Color {
    switch tone {
    case "spacemail": return .teal
    case "gmail": return .blue
    case "mock": return .purple
    case "microsoft", "mailbox": return .blue
    default: return .secondary
    }
  }
}

private struct CustomerProfileActionFeedbackPanel: View {
  var message: String
  var store: ParcelOpsStore?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(message, systemImage: "checkmark.circle.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.green)
      Text("This is local customer/recipient profile tracking only. No identity sync, contact sync, email send, address validation, or external service was used.")
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

struct CustomerProfileEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: CustomerRecipientProfile
  var onSave: (CustomerRecipientProfile) -> Void

  init(profile: CustomerRecipientProfile, onSave: @escaping (CustomerRecipientProfile) -> Void) {
    _draft = State(initialValue: profile)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        TextField("Display name", text: $draft.displayName)
        Picker("Profile type", selection: $draft.profileType) {
          ForEach(CustomerProfileType.allCases) { type in
            Text(type.rawValue).tag(type)
          }
        }
        TextField("Organisation/team", text: $draft.organisationTeam)
        TextField("Primary email", text: $draft.primaryEmail)
        TextField("Phone", text: $draft.phone)
        TextField("Default destination address", text: $draft.defaultDestinationAddress, axis: .vertical)
        Picker("Delivery preference", selection: $draft.deliveryPreference) {
          ForEach(DeliveryPreference.allCases) { preference in
            Text(preference.rawValue).tag(preference)
          }
        }
        Toggle("Enabled", isOn: $draft.isEnabled)
        Picker("Review state", selection: $draft.reviewState) {
          ForEach([ReviewState.needsReview, .monitor, .accepted], id: \.self) { state in
            Text(state.rawValue).tag(state)
          }
        }
        TextField("Notes", text: $draft.notes, axis: .vertical)
      }
      .navigationTitle("Edit Customer Profile")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { onSave(draft) }
        }
      }
      .frame(minWidth: 460, minHeight: 520)
    }
  }
}
