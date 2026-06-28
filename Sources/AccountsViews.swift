import SwiftUI

struct AccountsView: View {
  var store: ParcelOpsStore

  @State private var selectedOrganisation: String?
  @State private var selectedEntityType: AccountLinkedEntityType?
  @State private var selectedEnabledState: Bool?
  @State private var selectedCredentialStatus: CredentialStorageStatus?
  @State private var selectedMFAStatus: MFAStatus?
  @State private var selectedReviewState: ReviewState?
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var organisations: [String] {
    Array(Set(store.accountCredentialRecords.map(\.organisation))).sorted()
  }

  private var filteredAccounts: [AccountCredentialRecord] {
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

        SettingsPanel(title: "Account placeholders", symbol: "key.horizontal.fill") {
          HStack {
            Text("\(filteredAccounts.count) visible accounts")
              .font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            Button("Add account", systemImage: "plus", action: store.addAccountCredentialRecordPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredAccounts.isEmpty {
            Text("No account placeholders match the selected filters.")
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(12)
              .background(.quinary)
              .clipShape(RoundedRectangle(cornerRadius: 8))
          } else {
            ForEach(filteredAccounts) { account in
              AccountCredentialRow(account: account, store: store, linkedOrder: linkedOrder(for: account), contacts: store.contactDirectoryEntries, suggestedProfiles: store.suggestedVendorProfiles(for: account), destinationAddresses: store.suggestedDestinationAddresses(for: account), deliveryInstructions: store.suggestedDeliveryInstructions(for: account), packageContents: store.suggestedPackageContents(for: account)) { updatedAccount in
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
      Picker("Organisation", selection: $selectedOrganisation) {
        Text("All organisations").tag(nil as String?)
        ForEach(organisations, id: \.self) { organisation in
          Text(organisation).tag(organisation as String?)
        }
      }
      .pickerStyle(.menu)

      Picker("Record", selection: $selectedEntityType) {
        Text("All records").tag(nil as AccountLinkedEntityType?)
        ForEach(AccountLinkedEntityType.allCases) { entityType in
          Text(entityType.rawValue).tag(entityType as AccountLinkedEntityType?)
        }
      }
      .pickerStyle(.menu)

      Picker("Enabled", selection: $selectedEnabledState) {
        Text("All states").tag(nil as Bool?)
        Text("Enabled").tag(true as Bool?)
        Text("Disabled").tag(false as Bool?)
      }
      .pickerStyle(.menu)

      Picker("Credential", selection: $selectedCredentialStatus) {
        Text("All credential states").tag(nil as CredentialStorageStatus?)
        ForEach(CredentialStorageStatus.allCases) { status in
          Text(status.rawValue).tag(status as CredentialStorageStatus?)
        }
      }
      .pickerStyle(.menu)

      Picker("MFA", selection: $selectedMFAStatus) {
        Text("All MFA states").tag(nil as MFAStatus?)
        ForEach(MFAStatus.allCases) { status in
          Text(status.rawValue).tag(status as MFAStatus?)
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

      Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle") {
        selectedOrganisation = nil
        selectedEntityType = nil
        selectedEnabledState = nil
        selectedCredentialStatus = nil
        selectedMFAStatus = nil
        selectedReviewState = nil
      }
      .buttonStyle(.bordered)
    }
  }

  private func linkedOrder(for account: AccountCredentialRecord) -> TrackedOrder? {
    guard account.linkedEntityType == .order, let orderID = UUID(uuidString: account.linkedEntityID) else { return nil }
    return store.orders.first { $0.id == orderID }
  }
}

struct AccountCredentialRow: View {
  var account: AccountCredentialRecord
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
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

      HStack {
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
        Button(account.isEnabled ? "Disable" : "Enable", systemImage: account.isEnabled ? "pause.circle.fill" : "play.circle.fill", action: onToggle)
          .buttonStyle(.bordered)
        Button("Checked", systemImage: "checkmark.seal.fill", action: onChecked)
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.circle.fill", action: onReviewed)
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill", action: onCreateDraft)
          .buttonStyle(.bordered)
        Button("Profile", systemImage: "building.2.crop.circle", action: onCreateProfile)
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", action: onRemove)
          .buttonStyle(.bordered)
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
      }
    }
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
            ForEach(contacts) { contact in
              Text("\(contact.name) • \(contact.organisation)").tag(contact.id as UUID?)
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
