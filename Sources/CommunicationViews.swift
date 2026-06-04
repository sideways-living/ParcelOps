import SwiftUI

struct CommunicationView: View {
  var store: ParcelOpsStore

  @State private var selectedMode: CommunicationMode = .templates
  @State private var selectedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedReviewState: ReviewState?
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var filteredTemplates: [CommunicationTemplate] {
    store.communicationTemplates.filter { template in
      let matchesEntity = selectedEntityType == nil || template.linkedEntityType == selectedEntityType
      let matchesReview = selectedReviewState == nil || template.reviewState == selectedReviewState
      return matchesEntity && matchesReview
    }
  }

  private var filteredDrafts: [DraftMessage] {
    store.draftMessages.filter { draft in
      let matchesEntity = selectedEntityType == nil || draft.linkedEntityType == selectedEntityType
      let matchesReview = selectedReviewState == nil || draft.reviewState == selectedReviewState
      return matchesEntity && matchesReview
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Communication")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Local templates and draft outbound messages. Nothing is sent from ParcelOps yet.")
            .foregroundStyle(.secondary)
        }

        filterBar

        Picker("Communication mode", selection: $selectedMode) {
          ForEach(CommunicationMode.allCases) { mode in
            Text(mode.rawValue).tag(mode)
          }
        }
        .pickerStyle(.segmented)

        if selectedMode == .templates {
          SettingsPanel(title: "Templates", symbol: "text.badge.checkmark") {
            HStack {
              Text("\(filteredTemplates.count) visible templates")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer()
              Button("Add template", systemImage: "plus", action: store.addCommunicationTemplatePlaceholder)
                .buttonStyle(.borderedProminent)
            }

            ForEach(filteredTemplates) { template in
              CommunicationTemplateRow(template: template) { updatedTemplate in
                store.updateCommunicationTemplate(updatedTemplate)
              } onToggle: {
                store.toggleCommunicationTemplate(template)
              } onReviewed: {
                store.markCommunicationTemplateReviewed(template)
              } onCreateDraft: {
                store.createDraftMessage(
                  linkedEntityType: template.linkedEntityType,
                  linkedEntityID: "Template preview",
                  label: template.name,
                  recipient: "operations@parcelops.example",
                  template: template
                )
              } onRemove: {
                store.removeCommunicationTemplate(template)
              }
            }
          }
        } else {
          SettingsPanel(title: "Draft messages", symbol: "envelope.open.fill") {
            HStack {
              Text("\(filteredDrafts.count) visible drafts")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer()
              Button("Add draft", systemImage: "plus", action: store.addDraftMessagePlaceholder)
                .buttonStyle(.borderedProminent)
            }

            ForEach(filteredDrafts) { draft in
              DraftMessageRow(draft: draft, destinationAddresses: store.suggestedDestinationAddresses(for: draft), deliveryInstructions: store.suggestedDeliveryInstructions(for: draft), packageContents: store.suggestedPackageContents(for: draft)) { updatedDraft in
                store.updateDraftMessage(updatedDraft)
              } onReady: {
                store.markDraftMessageReady(draft)
              } onSent: {
                store.markDraftMessageSentLocally(draft)
              } onReopen: {
                store.reopenDraftMessage(draft)
              } onCreateContact: {
                store.addContactDirectoryEntry(linkedEntityType: .draftMessage, linkedEntityID: draft.id.uuidString, label: draft.recipient)
              } onRemove: {
                store.removeDraftMessage(draft)
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
      Picker("Record", selection: $selectedEntityType) {
        Text("All records").tag(nil as ReviewTaskLinkedEntityType?)
        ForEach(ReviewTaskLinkedEntityType.allCases) { entityType in
          Text(entityType.rawValue).tag(entityType as ReviewTaskLinkedEntityType?)
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
        selectedEntityType = nil
        selectedReviewState = nil
      }
      .buttonStyle(.bordered)
    }
  }
}

enum CommunicationMode: String, CaseIterable, Identifiable {
  case templates = "Templates"
  case drafts = "Drafts"

  var id: String { rawValue }
}

struct CommunicationTemplateRow: View {
  var template: CommunicationTemplate
  var onSave: (CommunicationTemplate) -> Void
  var onToggle: () -> Void
  var onReviewed: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: template.channel.symbol)
          .foregroundStyle(template.isEnabled ? .green : .secondary)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(template.name)
                .font(.headline)
              Text("\(template.linkedEntityType.rawValue) • \(template.channel.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(template.isEnabled ? "Enabled" : "Disabled", color: template.isEnabled ? .green : .gray)
          }

          Text(template.subjectTemplate)
            .font(.subheadline.weight(.semibold))
          Text(template.bodyTemplate)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          HStack(spacing: 8) {
            Badge(template.reviewState.rawValue, color: template.reviewState.color)
            Text("\(template.usageCount) uses")
              .font(.caption)
              .foregroundStyle(.secondary)
            Text("Last used \(template.lastUsedDate)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      HStack {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button(template.isEnabled ? "Disable" : "Enable", systemImage: template.isEnabled ? "pause.circle.fill" : "play.circle.fill", action: onToggle)
          .buttonStyle(.bordered)
        Button("Reviewed", systemImage: "checkmark.circle.fill", action: onReviewed)
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill", action: onCreateDraft)
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", action: onRemove)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      CommunicationTemplateEditView(template: template) { updatedTemplate in
        onSave(updatedTemplate)
      }
    }
  }
}

struct DraftMessageRow: View {
  var draft: DraftMessage
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var onSave: (DraftMessage) -> Void
  var onReady: () -> Void
  var onSent: () -> Void
  var onReopen: () -> Void
  var onCreateContact: () -> Void = {}
  var onRemove: () -> Void
  @State private var isEditing = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: draft.channel.symbol)
          .foregroundStyle(draft.status.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(draft.subject)
                .font(.headline)
              Text("\(draft.recipient) • \(draft.channel.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(draft.status.rawValue, color: draft.status.color)
          }

          Text(draft.body)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(4)

          HStack(spacing: 8) {
            Badge(draft.reviewState.rawValue, color: draft.reviewState.color)
            Label(draft.linkedEntityType.rawValue, systemImage: draft.linkedEntityType.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(draft.linkedEntityID)
              .font(.caption2.monospaced())
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
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
      }

      HStack {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Ready", systemImage: "checkmark.circle.fill", action: onReady)
          .buttonStyle(.bordered)
        Button("Sent locally", systemImage: "paperplane.fill", action: onSent)
          .buttonStyle(.borderedProminent)
        Button("Reopen", systemImage: "arrow.uturn.backward.circle.fill", action: onReopen)
          .buttonStyle(.bordered)
        Button("Contact", systemImage: "person.crop.circle.badge.plus", action: onCreateContact)
          .buttonStyle(.bordered)
        Button("Remove", systemImage: "trash", action: onRemove)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      DraftMessageEditView(draft: draft) { updatedDraft in
        onSave(updatedDraft)
      }
    }
  }
}

struct CommunicationTemplateEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: CommunicationTemplate
  var onSave: (CommunicationTemplate) -> Void

  init(template: CommunicationTemplate, onSave: @escaping (CommunicationTemplate) -> Void) {
    self._draft = State(initialValue: template)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Template") {
          TextField("Name", text: $draft.name)
          Picker("Linked record type", selection: $draft.linkedEntityType) {
            ForEach(ReviewTaskLinkedEntityType.allCases) { entityType in
              Text(entityType.rawValue).tag(entityType)
            }
          }
          TextField("Subject template", text: $draft.subjectTemplate)
          TextField("Body template", text: $draft.bodyTemplate, axis: .vertical)
            .lineLimit(4...8)
          Picker("Channel", selection: $draft.channel) {
            ForEach(CommunicationChannel.allCases) { channel in
              Text(channel.rawValue).tag(channel)
            }
          }
        }

        Section("State") {
          Toggle("Enabled", isOn: $draft.isEnabled)
          TextField("Created date", text: $draft.createdDate)
          TextField("Last used", text: $draft.lastUsedDate)
          Stepper("Usage count: \(draft.usageCount)", value: $draft.usageCount, in: 0...999)
          Picker("Review state", selection: $draft.reviewState) {
            Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted)
            Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview)
            Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor)
          }
        }
      }
      .navigationTitle("Edit template")
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

struct DraftMessageEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: DraftMessage
  var onSave: (DraftMessage) -> Void

  init(draft: DraftMessage, onSave: @escaping (DraftMessage) -> Void) {
    self._draft = State(initialValue: draft)
    self.onSave = onSave
  }

  private var templateIDBinding: Binding<String> {
    Binding(
      get: { draft.templateID?.uuidString ?? "" },
      set: { value in
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.templateID = trimmed.isEmpty ? nil : UUID(uuidString: trimmed)
      }
    )
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Linked record") {
          Picker("Record type", selection: $draft.linkedEntityType) {
            ForEach(ReviewTaskLinkedEntityType.allCases) { entityType in
              Text(entityType.rawValue).tag(entityType)
            }
          }
          TextField("Linked record ID", text: $draft.linkedEntityID)
          TextField("Template ID", text: templateIDBinding)
        }

        Section("Message") {
          TextField("Recipient", text: $draft.recipient)
          TextField("Subject", text: $draft.subject)
          TextField("Body", text: $draft.body, axis: .vertical)
            .lineLimit(5...10)
          Picker("Channel", selection: $draft.channel) {
            ForEach(CommunicationChannel.allCases) { channel in
              Text(channel.rawValue).tag(channel)
            }
          }
        }

        Section("State") {
          TextField("Created date", text: $draft.createdDate)
          Picker("Status", selection: $draft.status) {
            ForEach(DraftMessageStatus.allCases) { status in
              Text(status.rawValue).tag(status)
            }
          }
          Picker("Review state", selection: $draft.reviewState) {
            Text(ReviewState.accepted.rawValue).tag(ReviewState.accepted)
            Text(ReviewState.needsReview.rawValue).tag(ReviewState.needsReview)
            Text(ReviewState.monitor.rawValue).tag(ReviewState.monitor)
          }
        }
      }
      .navigationTitle("Edit draft")
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
