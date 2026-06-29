import SwiftUI

struct VendorProfilesView: View {
  var store: ParcelOpsStore

  @State private var selectedProfileType: VendorProfileType?
  @State private var selectedRiskLevel: VendorRiskLevel?
  @State private var selectedEnabledState: Bool?
  @State private var selectedChannel: CommunicationChannel?
  @State private var selectedReviewState: ReviewState?
  @State private var profileSearchText = ""
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
            ForEach(filteredProfiles) { profile in
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

  private func vendorProfileSearchParts(_ profile: VendorProfile) -> [String] {
    let contact = profile.defaultContactID.flatMap { contactID in
      store.contactDirectoryEntries.first { $0.id == contactID }
    }
    let account = profile.defaultAccountID.flatMap { accountID in
      store.accountCredentialRecords.first { $0.id == accountID }
    }
    return [
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
  }
}

struct VendorProfileRow: View {
  var profile: VendorProfile
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

      CompactActionRow {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button(profile.isEnabled ? "Disable" : "Enable", systemImage: profile.isEnabled ? "pause.circle.fill" : "play.circle.fill", action: onToggle)
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.circle.fill", action: onReviewed)
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill", action: onCreateDraft)
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", action: onRemove)
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
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      VendorProfileEditView(profile: profile, contacts: contacts, accounts: accounts) { updatedProfile in
        onSave(updatedProfile)
      }
    }
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
            ForEach(contacts) { contact in
              Text("\(contact.name) • \(contact.organisation)").tag(contact.id as UUID?)
            }
          }
          Picker("Default account", selection: $draft.defaultAccountID) {
            Text("No default account").tag(nil as UUID?)
            ForEach(accounts) { account in
              Text("\(account.accountName) • \(account.organisation)").tag(account.id as UUID?)
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
