import SwiftUI

struct DestinationAddressesView: View {
  var store: ParcelOpsStore
  @State private var selectedOrganisationTeam: String?
  @State private var selectedPreferredCarrier: String?
  @State private var selectedRiskLevel: ShipmentRiskLevel?
  @State private var selectedEnabled: Bool?
  @State private var selectedReviewState: ReviewState?
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var teams: [String] {
    Array(Set(store.destinationAddresses.map(\.organisationTeam))).sorted()
  }

  private var carriers: [String] {
    Array(Set(store.destinationAddresses.map(\.preferredCarrier))).sorted()
  }

  private var filteredAddresses: [DestinationAddressRecord] {
    store.filteredDestinationAddresses(
      organisationTeam: selectedOrganisationTeam,
      preferredCarrier: selectedPreferredCarrier,
      riskLevel: selectedRiskLevel,
      isEnabled: selectedEnabled,
      reviewState: selectedReviewState
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filters

        SettingsPanel(title: "Addresses", symbol: "mappin.and.ellipse") {
          ForEach(filteredAddresses) { address in
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
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
    .background(.regularMaterial)
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Destination Addresses")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Reusable local delivery destinations, access notes, carrier preferences, and address-risk context.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 8) {
        Button("Add address", systemImage: "plus", action: store.addDestinationAddressPlaceholder)
          .buttonStyle(.borderedProminent)
        Badge("\(store.destinationAddressesNeedingReview.count) review", color: .orange)
      }
    }
  }

  private var filters: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Picker("Team", selection: $selectedOrganisationTeam) {
          Text("All teams").tag(String?.none)
          ForEach(teams, id: \.self) { team in Text(team).tag(Optional(team)) }
        }
        Picker("Carrier", selection: $selectedPreferredCarrier) {
          Text("All carriers").tag(String?.none)
          ForEach(carriers, id: \.self) { carrier in Text(carrier).tag(Optional(carrier)) }
        }
      }
      HStack {
        Picker("Risk", selection: $selectedRiskLevel) {
          Text("All risk").tag(ShipmentRiskLevel?.none)
          ForEach(ShipmentRiskLevel.allCases) { risk in Text(risk.rawValue).tag(Optional(risk)) }
        }
        Picker("Enabled", selection: $selectedEnabled) {
          Text("All states").tag(Bool?.none)
          Text("Enabled").tag(Optional(true))
          Text("Disabled").tag(Optional(false))
        }
        Picker("Review", selection: $selectedReviewState) {
          Text("All review").tag(ReviewState?.none)
          ForEach([ReviewState.needsReview, .monitor, .accepted], id: \.self) { state in
            Text(state.rawValue).tag(Optional(state))
          }
        }
      }
    }
    .pickerStyle(.menu)
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
  }
}

struct DestinationAddressRow: View {
  var address: DestinationAddressRecord
  var customerProfiles: [CustomerRecipientProfile] = []
  var onSave: (DestinationAddressRecord) -> Void
  var onToggle: () -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false

  private var linkedProfile: CustomerRecipientProfile? {
    guard let id = address.customerProfileID else { return nil }
    return customerProfiles.first { $0.id == id }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "mappin.and.ellipse")
          .foregroundStyle(address.riskLevel.color)
          .frame(width: 28, height: 28)
        VStack(alignment: .leading, spacing: 5) {
          Text(address.label)
            .font(.headline)
          Text("\(address.addressLineSummary), \(address.cityRegion), \(address.country)")
            .foregroundStyle(.secondary)
          Text("\(address.deliveryInstructions) \(address.accessNotes)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 6) {
          Badge(address.riskLevel.rawValue, color: address.riskLevel.color)
          Badge(address.isEnabled ? "Enabled" : "Disabled", color: address.isEnabled ? .green : .gray)
          Badge(address.reviewState.rawValue, color: address.reviewState.color)
        }
      }

      HStack(spacing: 8) {
        Label(address.organisationTeam, systemImage: "person.2.fill")
        Label(address.preferredCarrier, systemImage: "truck.box.fill")
        if let linkedProfile {
          Label(linkedProfile.displayName, systemImage: "person.text.rectangle.fill")
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      HStack {
        Button("Edit", systemImage: "pencil") { isEditing = true }
          .buttonStyle(.bordered)
        Button(address.isEnabled ? "Disable" : "Enable", systemImage: address.isEnabled ? "pause.circle" : "play.circle", action: onToggle)
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
      DestinationAddressEditView(address: address, customerProfiles: customerProfiles) { updatedAddress in
        onSave(updatedAddress)
        isEditing = false
      }
    }
  }
}

struct DestinationAddressEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: DestinationAddressRecord
  var customerProfiles: [CustomerRecipientProfile]
  var onSave: (DestinationAddressRecord) -> Void

  init(address: DestinationAddressRecord, customerProfiles: [CustomerRecipientProfile], onSave: @escaping (DestinationAddressRecord) -> Void) {
    _draft = State(initialValue: address)
    self.customerProfiles = customerProfiles
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        TextField("Label", text: $draft.label)
        Picker("Customer profile", selection: $draft.customerProfileID) {
          Text("No linked profile").tag(UUID?.none)
          ForEach(customerProfiles) { profile in
            Text(profile.displayName).tag(Optional(profile.id))
          }
        }
        TextField("Organisation/team", text: $draft.organisationTeam)
        TextField("Address line summary", text: $draft.addressLineSummary, axis: .vertical)
        TextField("City/region", text: $draft.cityRegion)
        TextField("Country", text: $draft.country)
        TextField("Preferred carrier", text: $draft.preferredCarrier)
        Picker("Risk", selection: $draft.riskLevel) {
          ForEach(ShipmentRiskLevel.allCases) { risk in Text(risk.rawValue).tag(risk) }
        }
        Toggle("Enabled", isOn: $draft.isEnabled)
        Picker("Review state", selection: $draft.reviewState) {
          ForEach([ReviewState.needsReview, .monitor, .accepted], id: \.self) { state in
            Text(state.rawValue).tag(state)
          }
        }
        TextField("Delivery instructions", text: $draft.deliveryInstructions, axis: .vertical)
        TextField("Access notes", text: $draft.accessNotes, axis: .vertical)
      }
      .navigationTitle("Edit Destination")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(draft) } }
      }
      .frame(minWidth: 500, minHeight: 560)
    }
  }
}
