import SwiftUI

struct DeliveryInstructionsView: View {
  var store: ParcelOpsStore
  @State private var selectedType: DeliveryInstructionType?
  @State private var selectedProfileID: UUID?
  @State private var selectedCarrierContext: String?
  @State private var selectedRiskLevel: ShipmentRiskLevel?
  @State private var selectedEnabledState: Bool?
  @State private var selectedReviewState: ReviewState?
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var carrierContexts: [String] {
    Array(Set(store.deliveryInstructions.map(\.carrierNotes).filter { !$0.isEmpty })).sorted()
  }

  private var filteredInstructions: [DeliveryInstructionRecord] {
    store.filteredDeliveryInstructions(
      instructionType: selectedType,
      profileID: selectedProfileID,
      carrierContext: selectedCarrierContext,
      riskLevel: selectedRiskLevel,
      isEnabled: selectedEnabledState,
      reviewState: selectedReviewState
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filterBar

        SettingsPanel(title: "Reusable instructions", symbol: "signpost.right.and.left.fill") {
          HStack {
            Text("\(filteredInstructions.count) visible instructions")
              .font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            Button("Add instruction", systemImage: "plus", action: store.addDeliveryInstructionPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredInstructions.isEmpty {
            Text("No delivery instructions match the selected filters.")
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(12)
              .background(.quinary)
              .clipShape(RoundedRectangle(cornerRadius: 8))
          } else {
            ForEach(filteredInstructions) { instruction in
              DeliveryInstructionRow(
                instruction: instruction,
                store: store,
                linkedOrder: linkedOrder(for: instruction),
                destinationAddress: store.destinationAddresses.first { $0.id == instruction.destinationAddressID },
                customerProfile: store.customerRecipientProfiles.first { $0.id == instruction.customerProfileID },
                packageContents: store.suggestedPackageContents(for: instruction)
              ) { updatedInstruction in
                store.updateDeliveryInstruction(updatedInstruction)
              } onToggle: {
                store.toggleDeliveryInstruction(instruction)
              } onReviewed: {
                store.markDeliveryInstructionReviewed(instruction)
              } onCreateTask: {
                store.createReviewTask(from: instruction)
              } onCreateDraft: {
                store.createDraftMessage(from: instruction)
              } onRemove: {
                store.removeDeliveryInstruction(instruction)
              }
            }
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Delivery Instructions")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Reusable local delivery windows, access constraints, and carrier notes linked to destinations and operational records.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(store.deliveryInstructionsNeedingReview.count) review", color: .orange)
        Badge("\(store.highRiskDeliveryInstructions.count) high risk", color: .red)
      }
    }
  }

  private var filterBar: some View {
    FilterControlGrid {
      Picker("Type", selection: $selectedType) {
        Text("All types").tag(nil as DeliveryInstructionType?)
        ForEach(DeliveryInstructionType.allCases) { type in
          Text(type.rawValue).tag(type as DeliveryInstructionType?)
        }
      }
      .pickerStyle(.menu)

      Picker("Profile", selection: $selectedProfileID) {
        Text("All profiles").tag(nil as UUID?)
        ForEach(store.customerRecipientProfiles) { profile in
          Text(profile.displayName).tag(profile.id as UUID?)
        }
      }
      .pickerStyle(.menu)

      Picker("Carrier/context", selection: $selectedCarrierContext) {
        Text("All contexts").tag(nil as String?)
        ForEach(carrierContexts, id: \.self) { context in
          Text(context).tag(context as String?)
        }
      }
      .pickerStyle(.menu)

      Picker("Risk", selection: $selectedRiskLevel) {
        Text("All risk").tag(nil as ShipmentRiskLevel?)
        ForEach(ShipmentRiskLevel.allCases) { risk in
          Text(risk.rawValue).tag(risk as ShipmentRiskLevel?)
        }
      }
      .pickerStyle(.menu)

      Picker("Enabled", selection: $selectedEnabledState) {
        Text("All states").tag(nil as Bool?)
        Text("Enabled").tag(true as Bool?)
        Text("Disabled").tag(false as Bool?)
      }
      .pickerStyle(.menu)

      Picker("Review", selection: $selectedReviewState) {
        Text("All review").tag(nil as ReviewState?)
        ForEach(reviewStates, id: \.self) { state in
          Text(state.rawValue).tag(state as ReviewState?)
        }
      }
      .pickerStyle(.menu)

      Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle") {
        selectedType = nil
        selectedProfileID = nil
        selectedCarrierContext = nil
        selectedRiskLevel = nil
        selectedEnabledState = nil
        selectedReviewState = nil
      }
      .buttonStyle(.bordered)
    }
  }

  private func linkedOrder(for instruction: DeliveryInstructionRecord) -> TrackedOrder? {
    guard instruction.linkedEntityType == .order, let orderID = UUID(uuidString: instruction.linkedEntityID) else { return nil }
    return store.orders.first { $0.id == orderID }
  }
}

struct DeliveryInstructionRow: View {
  var instruction: DeliveryInstructionRecord
  var store: ParcelOpsStore? = nil
  var linkedOrder: TrackedOrder? = nil
  var destinationAddress: DestinationAddressRecord?
  var customerProfile: CustomerRecipientProfile?
  var packageContents: [PackageContentRecord] = []
  var onSave: (DeliveryInstructionRecord) -> Void
  var onToggle: () -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: instruction.instructionType.symbol)
          .foregroundStyle(instruction.riskLevel.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(instruction.title)
                .font(.headline)
              Text("\(instruction.instructionType.rawValue) • \(destinationAddress?.label ?? instruction.linkedEntityType.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(instruction.isEnabled ? "Enabled" : "Disabled", color: instruction.isEnabled ? .green : .gray)
          }

          Text(instruction.instructionSummary)
            .foregroundStyle(.secondary)
          Text(instruction.accessConstraintSummary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          HStack(spacing: 8) {
            Badge(instruction.riskLevel.rawValue, color: instruction.riskLevel.color)
            Badge(instruction.reviewState.rawValue, color: instruction.reviewState.color)
            Label(instruction.linkedEntityType.rawValue, systemImage: instruction.linkedEntityType.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          HStack(spacing: 8) {
            Text("Preferred \(instruction.preferredDeliveryWindow)")
            Text("Restricted \(instruction.restrictedDeliveryWindow)")
            if let customerProfile {
              Text(customerProfile.displayName)
            }
          }
          .font(.caption)
          .foregroundStyle(.secondary)

          Text(instruction.carrierNotes)
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
        Button(instruction.isEnabled ? "Disable" : "Enable", systemImage: instruction.isEnabled ? "pause.circle.fill" : "play.circle.fill", action: onToggle)
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

      if !packageContents.isEmpty {
        PackageContentStrip(contents: packageContents)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      DeliveryInstructionEditView(
        instruction: instruction,
        destinationAddresses: [],
        customerProfiles: []
      ) { updatedInstruction in
        onSave(updatedInstruction)
      }
    }
  }
}

struct DeliveryInstructionEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: DeliveryInstructionRecord
  var destinationAddresses: [DestinationAddressRecord]
  var customerProfiles: [CustomerRecipientProfile]
  var onSave: (DeliveryInstructionRecord) -> Void

  init(instruction: DeliveryInstructionRecord, destinationAddresses: [DestinationAddressRecord], customerProfiles: [CustomerRecipientProfile], onSave: @escaping (DeliveryInstructionRecord) -> Void) {
    self._draft = State(initialValue: instruction)
    self.destinationAddresses = destinationAddresses
    self.customerProfiles = customerProfiles
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Instruction") {
          TextField("Title", text: $draft.title)
          Picker("Instruction type", selection: $draft.instructionType) {
            ForEach(DeliveryInstructionType.allCases) { type in
              Text(type.rawValue).tag(type)
            }
          }
          TextField("Instruction summary", text: $draft.instructionSummary, axis: .vertical)
          TextField("Access constraint summary", text: $draft.accessConstraintSummary, axis: .vertical)
          TextField("Carrier notes", text: $draft.carrierNotes, axis: .vertical)
        }

        Section("Links") {
          Picker("Linked record type", selection: $draft.linkedEntityType) {
            ForEach(ReviewTaskLinkedEntityType.allCases) { entityType in
              Text(entityType.rawValue).tag(entityType)
            }
          }
          TextField("Linked record ID", text: $draft.linkedEntityID)
        }

        Section("Timing") {
          TextField("Preferred delivery window", text: $draft.preferredDeliveryWindow)
          TextField("Restricted delivery window", text: $draft.restrictedDeliveryWindow)
        }

        Section("State") {
          Picker("Risk", selection: $draft.riskLevel) {
            ForEach(ShipmentRiskLevel.allCases) { risk in
              Text(risk.rawValue).tag(risk)
            }
          }
          Picker("Review state", selection: $draft.reviewState) {
            ForEach([ReviewState.needsReview, .monitor, .accepted], id: \.self) { state in
              Text(state.rawValue).tag(state)
            }
          }
          Toggle("Enabled", isOn: $draft.isEnabled)
          TextField("Last reviewed", text: $draft.lastReviewedDate)
        }
      }
      .navigationTitle("Edit Instruction")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: { dismiss() })
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            onSave(draft)
            dismiss()
          }
        }
      }
    }
    .frame(minWidth: 560, minHeight: 560)
  }
}
