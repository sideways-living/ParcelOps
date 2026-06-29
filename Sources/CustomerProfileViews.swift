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

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filters

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
              CustomerProfileRow(profile: profile, destinationAddresses: store.suggestedDestinationAddresses(for: profile), deliveryInstructions: store.suggestedDeliveryInstructions(for: profile), packageContents: store.suggestedPackageContents(for: profile)) { updatedProfile in
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

      CompactActionRow {
        Button("Edit", systemImage: "pencil") { isEditing = true }
          .buttonStyle(.bordered)
        Button(profile.isEnabled ? "Disable" : "Enable", systemImage: profile.isEnabled ? "pause.circle" : "play.circle", action: onToggle)
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.circle.fill", action: onReviewed)
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill", action: onCreateDraft)
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
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
        isEditing = false
      }
    }
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
