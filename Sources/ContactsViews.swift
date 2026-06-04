import SwiftUI

struct ContactsView: View {
  var store: ParcelOpsStore

  @State private var selectedOrganisation: String?
  @State private var selectedEntityType: ContactLinkedEntityType?
  @State private var selectedEnabledState: Bool?
  @State private var selectedChannel: CommunicationChannel?
  @State private var selectedReviewState: ReviewState?
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var organisations: [String] {
    Array(Set(store.contactDirectoryEntries.map(\.organisation))).sorted()
  }

  private var filteredContacts: [ContactDirectoryEntry] {
    store.contactDirectoryEntries.filter { contact in
      let matchesOrganisation = selectedOrganisation == nil || contact.organisation == selectedOrganisation
      let matchesEntity = selectedEntityType == nil || contact.linkedEntityType == selectedEntityType
      let matchesEnabled = selectedEnabledState == nil || contact.isEnabled == selectedEnabledState
      let matchesChannel = selectedChannel == nil || contact.channelPreference == selectedChannel
      let matchesReview = selectedReviewState == nil || contact.reviewState == selectedReviewState
      return matchesOrganisation && matchesEntity && matchesEnabled && matchesChannel && matchesReview
    }
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

        SettingsPanel(title: "Contact directory", symbol: "person.crop.circle.badge.checkmark") {
          HStack {
            Text("\(filteredContacts.count) visible contacts")
              .font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            Button("Add contact", systemImage: "plus", action: store.addContactDirectoryEntryPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredContacts.isEmpty {
            Text("No contacts match the selected filters.")
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(12)
              .background(.quinary)
              .clipShape(RoundedRectangle(cornerRadius: 8))
          } else {
            ForEach(filteredContacts) { contact in
              ContactDirectoryRow(contact: contact, suggestedAccounts: store.suggestedAccounts(for: contact), suggestedProfiles: store.suggestedVendorProfiles(for: contact), destinationAddresses: store.suggestedDestinationAddresses(for: contact), deliveryInstructions: store.suggestedDeliveryInstructions(for: contact)) { updatedContact in
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

  private var filterBar: some View {
    HStack {
      Picker("Organisation", selection: $selectedOrganisation) {
        Text("All organisations").tag(nil as String?)
        ForEach(organisations, id: \.self) { organisation in
          Text(organisation).tag(organisation as String?)
        }
      }
      .pickerStyle(.menu)

      Picker("Record", selection: $selectedEntityType) {
        Text("All records").tag(nil as ContactLinkedEntityType?)
        ForEach(ContactLinkedEntityType.allCases) { entityType in
          Text(entityType.rawValue).tag(entityType as ContactLinkedEntityType?)
        }
      }
      .pickerStyle(.menu)

      Picker("Enabled", selection: $selectedEnabledState) {
        Text("All states").tag(nil as Bool?)
        Text("Enabled").tag(true as Bool?)
        Text("Disabled").tag(false as Bool?)
      }
      .pickerStyle(.menu)

      Picker("Channel", selection: $selectedChannel) {
        Text("All channels").tag(nil as CommunicationChannel?)
        ForEach(CommunicationChannel.allCases) { channel in
          Text(channel.rawValue).tag(channel as CommunicationChannel?)
        }
      }
      .pickerStyle(.menu)

      Picker("Review", selection: $selectedReviewState) {
        Text("All review states").tag(nil as ReviewState?)
        Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted as ReviewState?)
        Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview as ReviewState?)
        Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor as ReviewState?)
      }
      .pickerStyle(.menu)

      Spacer()

      Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle") {
        selectedOrganisation = nil
        selectedEntityType = nil
        selectedEnabledState = nil
        selectedChannel = nil
        selectedReviewState = nil
      }
      .buttonStyle(.bordered)
    }
  }
}

struct ContactDirectoryRow: View {
  var contact: ContactDirectoryEntry
  var suggestedAccounts: [AccountCredentialRecord] = []
  var suggestedProfiles: [VendorProfile] = []
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
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

      HStack {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button(contact.isEnabled ? "Disable" : "Enable", systemImage: contact.isEnabled ? "pause.circle.fill" : "play.circle.fill", action: onToggle)
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.circle.fill", action: onReviewed)
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill", action: onCreateDraft)
          .buttonStyle(.bordered)
        Button("Account", systemImage: "key.badge.plus", action: onCreateAccount)
          .buttonStyle(.bordered)
        Button("Profile", systemImage: "building.2.crop.circle", action: onCreateProfile)
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", action: onRemove)
          .buttonStyle(.bordered)
      }

      if !suggestedAccounts.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Label("Linked accounts", systemImage: "key.horizontal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          ForEach(suggestedAccounts) { account in
            AccountSuggestionRow(account: account) {
              onTaskFromAccount(account)
            } onCreateDraft: {
              onDraftFromAccount(account)
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
            } onCreateDraft: {
              onDraftFromProfile(profile)
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
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      ContactDirectoryEditView(contact: contact) { updatedContact in
        onSave(updatedContact)
      }
    }
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
