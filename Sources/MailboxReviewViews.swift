import SwiftUI

struct MailboxView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Forwarded email intake")
            .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
          Text("Local captures from the tracking mailbox are reviewed here before they become order records or supporting evidence.")
            .foregroundStyle(.secondary)
        }

        MVPWorkflowGuide(
          title: "What to do here",
          detail: "Treat each forwarded email as a draft signal until a person confirms the detected order details.",
          steps: [
            "Check merchant, order number, tracking number, and destination.",
            "Edit any wrong detected values before accepting.",
            "Link to an existing order or create a new order.",
            "Mark reviewed, ignore, or create a task when follow-up is needed."
          ],
          symbol: "envelope.open.fill"
        )

        SettingsPanel(title: "Detected order emails", symbol: "envelope.open.fill") {
          if store.intakeEmails.isEmpty {
            MVPEmptyState(title: "No forwarded emails yet", detail: "This MVP uses local sample records. Add or seed intake records before testing the mailbox review flow.", symbol: "envelope.badge")
          } else {
            ForEach(store.intakeEmails) { email in
              IntakeEmailRow(email: email, orders: store.orders, evidenceAttachments: store.evidence(for: .intakeEmail, linkedEntityID: email.id), suggestedContacts: store.suggestedContacts(for: email), suggestedAccounts: store.suggestedAccounts(for: email), suggestedProfiles: store.suggestedVendorProfiles(for: email), customerProfiles: store.suggestedCustomerProfiles(for: email), destinationAddresses: store.suggestedDestinationAddresses(for: email), deliveryInstructions: store.suggestedDeliveryInstructions(for: email), packageContents: store.suggestedPackageContents(for: email), shipmentGroups: store.suggestedShipmentGroups(for: email)) { updatedEmail in
                store.updateIntakeEmail(updatedEmail)
              } onLinkOrder: { order in
                store.linkIntakeEmail(email, to: order)
              } onCreateOrder: {
                store.createOrder(from: email)
              } onReviewed: {
                store.markIntakeEmailReviewed(email)
              } onIgnore: {
                store.ignoreIntakeEmail(email)
              } onAddEvidence: {
                store.addPlaceholderEvidence(to: .intakeEmail, linkedEntityID: email.id, label: email.detectedOrderNumber)
              } onReviewEvidence: { attachment in
                store.markEvidenceReviewed(attachment)
              } onRemoveEvidence: { attachment in
                store.removeEvidence(attachment)
              } onCreateTask: {
                store.createReviewTask(from: email)
              } onCreateDraft: {
                store.createDraftMessage(from: email)
              } onDraftFromContact: { contact in
                store.createDraftMessage(from: contact, linkedEntityType: .intakeEmail, linkedEntityID: email.id.uuidString, label: email.detectedOrderNumber)
              } onCreateAccount: {
                store.addAccountCredentialRecord(linkedEntityType: .intakeEmail, linkedEntityID: email.id.uuidString, organisation: email.detectedMerchant, label: email.detectedOrderNumber)
              } onTaskFromAccount: { account in
                store.createReviewTask(from: account)
              } onDraftFromAccount: { account in
                store.createDraftMessage(from: account)
              } onCreateProfile: {
                store.addVendorProfile(profileType: .supplier, organisation: email.detectedMerchant, label: email.detectedOrderNumber)
              } onTaskFromProfile: { profile in
                store.createReviewTask(from: profile)
              } onDraftFromProfile: { profile in
                store.createDraftMessage(from: profile)
              }
            }
          }
        }

        SettingsPanel(title: "Mailbox events", symbol: "envelope.badge.fill") {
          ForEach(store.mailEvents) { event in
            MailEventRow(event: event)
          }
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }
}

struct IntakeEmailRow: View {
  var email: ForwardedEmailIntake
  var orders: [TrackedOrder]
  var evidenceAttachments: [EvidenceAttachment]
  var suggestedContacts: [ContactDirectoryEntry] = []
  var suggestedAccounts: [AccountCredentialRecord] = []
  var suggestedProfiles: [VendorProfile] = []
  var customerProfiles: [CustomerRecipientProfile] = []
  var destinationAddresses: [DestinationAddressRecord] = []
  var deliveryInstructions: [DeliveryInstructionRecord] = []
  var packageContents: [PackageContentRecord] = []
  var shipmentGroups: [ShipmentGroup] = []
  var onSave: (ForwardedEmailIntake) -> Void
  var onLinkOrder: (TrackedOrder) -> Void
  var onCreateOrder: () -> Void
  var onReviewed: () -> Void
  var onIgnore: () -> Void
  var onAddEvidence: () -> Void
  var onReviewEvidence: (EvidenceAttachment) -> Void
  var onRemoveEvidence: (EvidenceAttachment) -> Void
  var onCreateTask: () -> Void = {}
  var onCreateDraft: () -> Void = {}
  var onDraftFromContact: (ContactDirectoryEntry) -> Void = { _ in }
  var onCreateAccount: () -> Void = {}
  var onTaskFromAccount: (AccountCredentialRecord) -> Void = { _ in }
  var onDraftFromAccount: (AccountCredentialRecord) -> Void = { _ in }
  var onCreateProfile: () -> Void = {}
  var onTaskFromProfile: (VendorProfile) -> Void = { _ in }
  var onDraftFromProfile: (VendorProfile) -> Void = { _ in }
  @State private var isEditing = false

  private var linkedOrder: TrackedOrder? {
    orders.first { $0.id == email.linkedOrderID }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "envelope.open.fill")
          .foregroundStyle(email.reviewState.color)
          .frame(width: 28, height: 28)
        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(email.subject)
                .font(.headline)
              Text("\(email.sender) • \(email.receivedDate)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(email.reviewState.rawValue, color: email.reviewState.color)
          }
          Text(email.rawBodyPreview)
            .foregroundStyle(.secondary)
            .lineLimit(3)
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
            IntakeFact(title: "Merchant", value: email.detectedMerchant, symbol: "storefront.fill")
            IntakeFact(title: "Order", value: email.detectedOrderNumber, symbol: "number")
            IntakeFact(title: "Tracking", value: email.detectedTrackingNumber, symbol: "barcode.viewfinder")
            IntakeFact(title: "Destination", value: email.detectedDestinationAddress, symbol: "mappin.and.ellipse")
          }
          if let linkedOrder {
            Text("Linked to \(linkedOrder.orderNumber) • \(linkedOrder.store)")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.green)
          }
          if !shipmentGroups.isEmpty {
            ShipmentGroupContextStrip(groups: shipmentGroups)
          }
        }
      }

      HStack {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)

        Menu {
          ForEach(orders) { order in
            Button("\(order.orderNumber) • \(order.store)") {
              onLinkOrder(order)
            }
          }
        } label: {
          Label("Link order", systemImage: "link")
        }
        .buttonStyle(.bordered)

        Button("Create order", systemImage: "plus.circle.fill", action: onCreateOrder)
          .buttonStyle(.borderedProminent)
        Button("Reviewed", systemImage: "checkmark.circle.fill", action: onReviewed)
          .buttonStyle(.bordered)
        Button("Ignore", systemImage: "trash", action: onIgnore)
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill", action: onCreateDraft)
          .buttonStyle(.bordered)
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Label("Evidence", systemImage: "paperclip")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Spacer()
          Button("Add", systemImage: "plus", action: onAddEvidence)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }

        if evidenceAttachments.isEmpty {
          Text("No evidence linked.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          ForEach(evidenceAttachments) { attachment in
            EvidenceAttachmentRow(attachment: attachment) {
              onReviewEvidence(attachment)
            } onRemove: {
              onRemoveEvidence(attachment)
            } onCreateDraft: {
              onCreateDraft()
            }
          }
        }
      }

      if !suggestedContacts.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Label("Suggested contacts", systemImage: "person.crop.circle.badge.checkmark")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          ForEach(suggestedContacts) { contact in
            ContactSuggestionRow(contact: contact) {
              onDraftFromContact(contact)
            }
          }
        }
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Label("Suggested accounts", systemImage: "key.horizontal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Spacer()
          Button("Add", systemImage: "key.badge.plus", action: onCreateAccount)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }

        if suggestedAccounts.isEmpty {
          Text("No local account placeholders matched.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          ForEach(suggestedAccounts) { account in
            AccountSuggestionRow(account: account) {
              onTaskFromAccount(account)
            } onCreateDraft: {
              onDraftFromAccount(account)
            }
          }
        }
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Label("Suggested profiles", systemImage: "building.2.crop.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Spacer()
          Button("Add", systemImage: "building.2.crop.circle", action: onCreateProfile)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }

        if suggestedProfiles.isEmpty {
          Text("No local vendor profiles matched.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          ForEach(suggestedProfiles) { profile in
            VendorProfileSuggestionRow(profile: profile) {
              onTaskFromProfile(profile)
            } onCreateDraft: {
              onDraftFromProfile(profile)
            }
          }
        }
      }

      if !customerProfiles.isEmpty {
        CustomerProfileStrip(profiles: customerProfiles)
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
      IntakeEmailEditView(email: email) { updatedEmail in
        onSave(updatedEmail)
      }
    }
  }
}

struct IntakeEmailEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: ForwardedEmailIntake
  var onSave: (ForwardedEmailIntake) -> Void

  init(email: ForwardedEmailIntake, onSave: @escaping (ForwardedEmailIntake) -> Void) {
    self._draft = State(initialValue: email)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Email") {
          TextField("Sender", text: $draft.sender)
          TextField("Subject", text: $draft.subject)
          TextField("Received", text: $draft.receivedDate)
          TextField("Body preview", text: $draft.rawBodyPreview, axis: .vertical)
            .lineLimit(3...6)
        }

        Section("Detected order details") {
          TextField("Merchant", text: $draft.detectedMerchant)
          TextField("Order number", text: $draft.detectedOrderNumber)
          TextField("Tracking number", text: $draft.detectedTrackingNumber)
          TextField("Destination address", text: $draft.detectedDestinationAddress, axis: .vertical)
            .lineLimit(2...4)
          Picker("Review state", selection: $draft.reviewState) {
            Text(IntakeEmailReviewState.needsReview.rawValue).tag(IntakeEmailReviewState.needsReview)
            Text(IntakeEmailReviewState.reviewed.rawValue).tag(IntakeEmailReviewState.reviewed)
            Text(IntakeEmailReviewState.ignored.rawValue).tag(IntakeEmailReviewState.ignored)
          }
        }
      }
      .navigationTitle("Edit intake email")
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
      .frame(minWidth: 520, minHeight: 520)
      #endif
    }
  }
}

struct IntakeFact: View {
  var title: String
  var value: String
  var symbol: String

  var body: some View {
    HStack(alignment: .top, spacing: 6) {
      Image(systemName: symbol)
        .foregroundStyle(.teal)
        .frame(width: 18)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption2)
          .foregroundStyle(.secondary)
        Text(value)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
      }
    }
  }
}

struct MailEventRow: View {
  var event: MailEvent

  var body: some View {
    HStack(alignment: .top) {
      Image(systemName: "envelope.badge.fill")
        .foregroundStyle(event.severity.color)
        .frame(width: 30, height: 30)
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(event.sender)
            .font(.headline)
          Badge(event.severity.rawValue, color: event.severity.color)
          Badge(event.reviewState.rawValue, color: event.reviewState.color)
          Spacer()
          Text(event.receivedTime)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Text(event.summary)
          .foregroundStyle(.secondary)
        Text("Matched order: \(event.matchedOrder)")
          .font(.caption.weight(.semibold))
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct NeedsReviewView: View {
  var store: ParcelOpsStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Needs review")
              .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
            Text("Exceptions, risky matches, and lower-confidence intake wait here until a user accepts or discards them.")
              .foregroundStyle(.secondary)
          }
          Spacer()
          Badge("\(store.reviewQueueCount)", color: .orange)
        }

        SettingsPanel(title: "Operations Workbench", symbol: "rectangle.stack.badge.person.crop.fill") {
          ForEach(Array(store.highPriorityWorkbenchItems.prefix(8))) { item in
            WorkbenchItemRow(item: item, customerProfiles: store.suggestedCustomerProfiles(for: item), destinationAddresses: store.suggestedDestinationAddresses(for: item), deliveryInstructions: store.suggestedDeliveryInstructions(for: item), packageContents: store.suggestedPackageContents(for: item), receivingInspections: store.suggestedReceivingInspections(for: item), inventoryReceipts: store.suggestedInventoryReceipts(for: item), storageLocations: store.suggestedStorageLocations(for: item), custodyRecords: store.suggestedCustodyRecords(for: item), labelReferences: store.suggestedLabelReferenceRecords(for: item), scanSessions: store.suggestedScanSessionRecords(for: item), shipmentManifests: store.suggestedShipmentManifestRecords(for: item), dispatchChecklists: store.suggestedDispatchReadinessChecklists(for: item)) {
              store.createReviewTask(from: item)
            } onCreateDraft: {
              store.createDraftMessage(from: item)
            } onReviewed: {
              store.markWorkbenchItemReviewed(item)
            }
          }
        }

        SettingsPanel(title: "Timeline watchlist", symbol: "clock.badge.exclamationmark.fill") {
          ForEach(Array(store.timelineWatchlist.prefix(8))) { activity in
            TimelineActivityRow(activity: activity, shipmentGroups: store.suggestedShipmentGroups(for: activity), importQueueItems: store.importQueueItems(for: activity), acceptanceRecords: store.acceptanceRecords(for: activity)) {
              store.createReviewTask(from: activity)
            } onCreateDraft: {
              store.createDraftMessage(from: activity)
            }
          }
        }

        SettingsPanel(title: "Validation issues", symbol: "checkmark.seal.fill") {
          ForEach(Array(store.highSeverityValidationIssues.prefix(8))) { issue in
            ValidationIssueRow(issue: issue, shipmentGroups: store.suggestedShipmentGroups(for: issue), importQueueItems: store.importQueueItems(for: issue), acceptanceRecords: store.acceptanceRecords(for: issue), playbooks: store.suggestedPlaybooks(for: issue), handoffNotes: store.handoffNotes(for: issue), customerProfiles: store.suggestedCustomerProfiles(for: issue), destinationAddresses: store.suggestedDestinationAddresses(for: issue), deliveryInstructions: store.suggestedDeliveryInstructions(for: issue), packageContents: store.suggestedPackageContents(for: issue)) {
              store.createReviewTask(from: issue)
            } onCreateDraft: {
              store.createDraftMessage(from: issue)
            }
          }
        }

        SettingsPanel(title: "Reconciliation", symbol: "arrow.triangle.2.circlepath.circle.fill") {
          ForEach(Array(store.highSeverityReconciliationIssues.prefix(8))) { issue in
            ReconciliationIssueRow(
              issue: issue,
              shipmentGroups: store.suggestedShipmentGroups(for: issue),
              importQueueItems: store.importQueueItems(for: issue),
              acceptanceRecords: store.acceptanceRecords(for: issue),
              validationIssues: store.relatedValidationIssues(for: issue),
              playbooks: store.suggestedPlaybooks(for: issue),
              handoffNotes: store.handoffNotes(for: issue),
              customerProfiles: store.suggestedCustomerProfiles(for: issue),
              destinationAddresses: store.suggestedDestinationAddresses(for: issue),
              deliveryInstructions: store.suggestedDeliveryInstructions(for: issue),
              packageContents: store.suggestedPackageContents(for: issue)
            ) {
              store.markReconciliationIssueReviewed(issue)
            } onCreateTask: {
              store.createReviewTask(from: issue)
            } onCreateDraft: {
              store.createDraftMessage(from: issue)
            }
          }
        }

        SettingsPanel(title: "Shipment groups", symbol: "shippingbox.and.arrow.backward.fill") {
          ForEach(Array(Set(store.shipmentGroupsNeedingReview + store.highRiskShipmentGroups)).sorted { lhs, rhs in
            lhs.riskLevel.riskRank > rhs.riskLevel.riskRank
          }) { group in
            ShipmentGroupRow(group: group, importQueueItems: store.importQueueItems(for: group), acceptanceRecords: store.acceptanceRecords(for: group), playbooks: store.suggestedPlaybooks(for: group), handoffNotes: store.handoffNotes(for: group), customerProfiles: store.suggestedCustomerProfiles(for: group), destinationAddresses: store.suggestedDestinationAddresses(for: group), deliveryInstructions: store.suggestedDeliveryInstructions(for: group), packageContents: store.suggestedPackageContents(for: group)) { updatedGroup in
              store.updateShipmentGroup(updatedGroup)
            } onReviewed: {
              store.markShipmentGroupReviewed(group)
            } onCreateTask: {
              store.createReviewTask(from: group)
            } onCreateDraft: {
              store.createDraftMessage(from: group)
            } onRemove: {
              store.removeShipmentGroup(group)
            }
          }
        }

        SettingsPanel(title: "Acceptance review", symbol: "checkmark.rectangle.stack.fill") {
          ForEach(Array(store.acceptanceCandidates.filter { candidate in
            candidate.reviewState == .needsReview || candidate.decision == .blocked || candidate.decision == .reopened
          }.prefix(8))) { candidate in
            AcceptanceCandidateRow(
              candidate: candidate,
              orders: store.orders,
              shipmentGroups: store.shipmentGroups,
              linkedOrderLabel: candidate.suggestedLinkedOrderID.flatMap { store.orderLabel(for: $0) },
              linkedShipmentGroupLabel: candidate.suggestedShipmentGroupID.flatMap { store.shipmentGroupLabel(for: $0) },
              history: store.acceptanceHistory(sourceType: candidate.sourceType, sourceID: candidate.sourceID),
              playbooks: store.suggestedPlaybooks(for: candidate),
              handoffNotes: store.handoffNotes(for: candidate),
              customerProfiles: store.suggestedCustomerProfiles(for: candidate),
              destinationAddresses: store.suggestedDestinationAddresses(for: candidate),
              deliveryInstructions: store.suggestedDeliveryInstructions(for: candidate),
              packageContents: store.suggestedPackageContents(for: candidate),
              onLinkOrder: { order in store.linkAcceptanceCandidate(candidate, to: order) },
              onLinkShipmentGroup: { group in store.linkAcceptanceCandidate(candidate, to: group) },
              onCreateOrder: { store.createOrder(from: candidate) },
              onCreateShipmentGroup: { store.createShipmentGroup(from: candidate) },
              onAccept: { store.acceptCandidate(candidate) },
              onIgnore: { store.ignoreCandidate(candidate) },
              onReopen: { store.reopenCandidate(candidate) },
              onTask: { store.createReviewTask(from: candidate) },
              onDraft: { store.createDraftMessage(from: candidate) }
            )
          }
        }

        SettingsPanel(title: "Import queue", symbol: "tray.and.arrow.down.fill") {
          ForEach(Array(Set(store.blockedImportQueueItems + store.lowConfidenceImportQueueItems + store.importQueueItemsNeedingReview)).prefix(8)) { item in
            ImportQueueItemRow(
              item: item,
              orders: store.orders,
              shipmentGroups: store.shipmentGroups,
              playbooks: store.suggestedPlaybooks(for: item),
              handoffNotes: store.handoffNotes(for: item),
              customerProfiles: store.suggestedCustomerProfiles(for: item),
              destinationAddresses: store.suggestedDestinationAddresses(for: item),
              deliveryInstructions: store.suggestedDeliveryInstructions(for: item),
              packageContents: store.suggestedPackageContents(for: item),
              onSave: store.updateImportQueueItem,
              onLinkOrder: { order in store.linkImportQueueItem(item, to: order) },
              onLinkShipmentGroup: { group in store.linkImportQueueItem(item, to: group) },
              onCreateOrder: { store.createOrder(from: item) },
              onCreateShipmentGroup: { store.createShipmentGroup(from: item) },
              onAccepted: { store.markImportQueueItemAccepted(item) },
              onIgnored: { store.ignoreImportQueueItem(item) },
              onReopen: { store.reopenImportQueueItem(item) },
              onRemove: { store.removeImportQueueItem(item) },
              onCreateTask: { store.createReviewTask(from: item) },
              onCreateDraft: { store.createDraftMessage(from: item) }
            )
          }
        }

        SettingsPanel(title: "Order matches", symbol: "shippingbox.fill") {
          ForEach(store.reviewOrders) { order in
            ReviewOrderRow(order: order) { updatedOrder in
              store.updateOrder(updatedOrder)
            } onClear: {
              store.clearIssue(for: order.orderNumber)
            } onDiscard: {
              store.discardSpam(for: order.orderNumber)
            } onCreateTask: {
              store.createReviewTask(from: order)
            } onCreateDraft: {
              store.createDraftMessage(from: order)
            }
          }
        }

        SettingsPanel(title: "Mailbox events", symbol: "envelope.badge.fill") {
          ForEach(store.reviewMailEvents) { event in
            ReviewMailEventRow(event: event) {
              store.clearIssue(for: event.matchedOrder)
            } onDiscard: {
              store.discardSpam(for: event.matchedOrder)
            } onCreateTask: {
              store.createReviewTask(
                linkedEntityType: .auditEvent,
                linkedEntityID: event.id.uuidString,
                label: event.matchedOrder,
                summary: "Follow up mailbox event from \(event.sender): \(event.summary)",
                priority: event.severity == .critical ? .urgent : .high
              )
            }
          }
        }

        SettingsPanel(title: "Forwarded emails", symbol: "envelope.open.fill") {
          ForEach(store.reviewIntakeEmails) { email in
            IntakeEmailRow(email: email, orders: store.orders, evidenceAttachments: store.evidence(for: .intakeEmail, linkedEntityID: email.id), suggestedContacts: store.suggestedContacts(for: email), suggestedAccounts: store.suggestedAccounts(for: email), suggestedProfiles: store.suggestedVendorProfiles(for: email), customerProfiles: store.suggestedCustomerProfiles(for: email), destinationAddresses: store.suggestedDestinationAddresses(for: email), deliveryInstructions: store.suggestedDeliveryInstructions(for: email), packageContents: store.suggestedPackageContents(for: email), shipmentGroups: store.suggestedShipmentGroups(for: email)) { updatedEmail in
              store.updateIntakeEmail(updatedEmail)
            } onLinkOrder: { order in
              store.linkIntakeEmail(email, to: order)
            } onCreateOrder: {
              store.createOrder(from: email)
            } onReviewed: {
              store.markIntakeEmailReviewed(email)
            } onIgnore: {
              store.ignoreIntakeEmail(email)
            } onAddEvidence: {
              store.addPlaceholderEvidence(to: .intakeEmail, linkedEntityID: email.id, label: email.detectedOrderNumber)
            } onReviewEvidence: { attachment in
              store.markEvidenceReviewed(attachment)
            } onRemoveEvidence: { attachment in
              store.removeEvidence(attachment)
            } onCreateTask: {
              store.createReviewTask(from: email)
            } onCreateDraft: {
              store.createDraftMessage(from: email)
            } onDraftFromContact: { contact in
              store.createDraftMessage(from: contact, linkedEntityType: .intakeEmail, linkedEntityID: email.id.uuidString, label: email.detectedOrderNumber)
            } onCreateAccount: {
              store.addAccountCredentialRecord(linkedEntityType: .intakeEmail, linkedEntityID: email.id.uuidString, organisation: email.detectedMerchant, label: email.detectedOrderNumber)
            } onTaskFromAccount: { account in
              store.createReviewTask(from: account)
            } onDraftFromAccount: { account in
              store.createDraftMessage(from: account)
            } onCreateProfile: {
              store.addVendorProfile(profileType: .supplier, organisation: email.detectedMerchant, label: email.detectedOrderNumber)
            } onTaskFromProfile: { profile in
              store.createReviewTask(from: profile)
            } onDraftFromProfile: { profile in
              store.createDraftMessage(from: profile)
            }
          }
        }

        SettingsPanel(title: "Evidence", symbol: "paperclip") {
          ForEach(store.reviewEvidenceAttachments) { attachment in
            EvidenceAttachmentRow(attachment: attachment, shipmentGroups: store.suggestedShipmentGroups(for: attachment), customerProfiles: store.suggestedCustomerProfiles(for: attachment), destinationAddresses: store.suggestedDestinationAddresses(for: attachment), deliveryInstructions: store.suggestedDeliveryInstructions(for: attachment), packageContents: store.suggestedPackageContents(for: attachment)) {
              store.markEvidenceReviewed(attachment)
            } onRemove: {
              store.removeEvidence(attachment)
            } onCreateTask: {
              store.createReviewTask(from: attachment)
            } onCreateDraft: {
              store.createDraftMessage(from: attachment)
            } onCreateContact: {
              store.addContactDirectoryEntry(linkedEntityType: .evidence, linkedEntityID: attachment.id.uuidString, label: attachment.fileName)
            }
          }
        }

        SettingsPanel(title: "Tracking events", symbol: "location.fill.viewfinder") {
          ForEach(store.reviewCarrierTrackingEvents) { event in
            TrackingEventRow(event: event, order: store.orders.first { $0.id == event.orderID }, suggestedContacts: store.suggestedContacts(for: event), suggestedProfiles: store.suggestedVendorProfiles(for: event), customerProfiles: store.suggestedCustomerProfiles(for: event), destinationAddresses: store.suggestedDestinationAddresses(for: event), deliveryInstructions: store.suggestedDeliveryInstructions(for: event), packageContents: store.suggestedPackageContents(for: event), shipmentGroups: store.suggestedShipmentGroups(for: event)) {
              store.markTrackingEventReviewed(event)
            } onRemove: {
              store.removeTrackingEvent(event)
            } onCreateTask: {
              store.createReviewTask(from: event)
            } onCreateDraft: {
              store.createDraftMessage(from: event)
            } onDraftFromContact: { contact in
              store.createDraftMessage(from: contact, linkedEntityType: .trackingEvent, linkedEntityID: event.id.uuidString, label: event.trackingNumber)
            } onCreateProfile: {
              store.addVendorProfile(profileType: .carrier, organisation: event.carrier, label: event.trackingNumber)
            } onTaskFromProfile: { profile in
              store.createReviewTask(from: profile)
            } onDraftFromProfile: { profile in
              store.createDraftMessage(from: profile)
            } relatedTasks: {
              store.tasks(for: .trackingEvent, linkedEntityID: event.id.uuidString)
            }
          }
        }

        SettingsPanel(title: "Task escalations", symbol: "checklist") {
          ForEach(store.reviewTasksNeedingAttention) { task in
            ReviewTaskRow(task: task, matchingPolicies: store.policies(for: task.linkedEntityType), shipmentGroups: store.suggestedShipmentGroups(for: task), handoffNotes: store.handoffNotes(for: task), customerProfiles: store.suggestedCustomerProfiles(for: task), destinationAddresses: store.suggestedDestinationAddresses(for: task), deliveryInstructions: store.suggestedDeliveryInstructions(for: task), packageContents: store.suggestedPackageContents(for: task)) { updatedTask in
              store.updateReviewTask(updatedTask)
            } onComplete: {
              store.completeReviewTask(task)
            } onReopen: {
              store.reopenReviewTask(task)
            } onReviewed: {
              store.markReviewTaskReviewed(task)
            } onCreateDraft: {
              store.createDraftMessage(from: task)
            } onCreateContact: {
              store.addContactDirectoryEntry(linkedEntityType: .reviewTask, linkedEntityID: task.id.uuidString, label: task.title)
            } onRemove: {
              store.removeReviewTask(task)
            }
          }
        }

        SettingsPanel(title: "Handoff notes", symbol: "arrow.left.arrow.right.square.fill") {
          ForEach(store.handoffNotesNeedingAttention) { note in
            HandoffNoteRow(note: note, customerProfiles: store.suggestedCustomerProfiles(for: note), destinationAddresses: store.suggestedDestinationAddresses(for: note), deliveryInstructions: store.suggestedDeliveryInstructions(for: note), packageContents: store.suggestedPackageContents(for: note)) { updatedNote in
              store.updateHandoffNote(updatedNote)
            } onAcknowledge: {
              store.acknowledgeHandoffNote(note)
            } onComplete: {
              store.completeHandoffNote(note)
            } onReopen: {
              store.reopenHandoffNote(note)
            } onReviewed: {
              store.markHandoffNoteReviewed(note)
            } onCreateTask: {
              store.createReviewTask(from: note)
            } onCreateDraft: {
              store.createDraftMessage(from: note)
            } onRemove: {
              store.removeHandoffNote(note)
            }
          }
        }

        SettingsPanel(title: "SLA policies", symbol: "timer") {
          ForEach(store.policiesNeedingReview) { policy in
            SLAPolicyRow(policy: policy, destinationAddresses: store.suggestedDestinationAddresses(for: policy), deliveryInstructions: store.suggestedDeliveryInstructions(for: policy), packageContents: store.suggestedPackageContents(for: policy)) { updatedPolicy in
              store.updateSLAPolicy(updatedPolicy)
            } onToggle: {
              store.toggleSLAPolicy(policy)
            } onReviewed: {
              store.markSLAPolicyReviewed(policy)
            } onEvaluate: {
              store.evaluateSLAPolicyPlaceholder(policy)
            } onCreateDraft: {
              store.createDraftMessage(from: policy)
            } onCreateContact: {
              store.addContactDirectoryEntry(linkedEntityType: .slaPolicy, linkedEntityID: policy.id.uuidString, label: policy.name)
            } onRemove: {
              store.removeSLAPolicy(policy)
            }
          }
        }

        SettingsPanel(title: "Exception playbooks", symbol: "book.closed.fill") {
          ForEach(Array(Set(store.playbooksNeedingReview + store.enabledHighPriorityPlaybooks)).sorted { lhs, rhs in
            lhs.priority.rawValue > rhs.priority.rawValue
          }) { playbook in
            ExceptionPlaybookRow(playbook: playbook, handoffNotes: store.handoffNotes(for: playbook), destinationAddresses: store.suggestedDestinationAddresses(for: playbook), deliveryInstructions: store.suggestedDeliveryInstructions(for: playbook), packageContents: store.suggestedPackageContents(for: playbook)) { updatedPlaybook in
              store.updateExceptionPlaybook(updatedPlaybook)
            } onToggle: {
              store.toggleExceptionPlaybook(playbook)
            } onReviewed: {
              store.markExceptionPlaybookReviewed(playbook)
            } onCreateTask: {
              store.createReviewTask(from: playbook)
            } onCreateDraft: {
              store.createDraftMessage(from: playbook)
            } onRemove: {
              store.removeExceptionPlaybook(playbook)
            }
          }
        }

        SettingsPanel(title: "Draft messages", symbol: "envelope.open.fill") {
          ForEach(store.draftMessagesNeedingReview) { draft in
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

        SettingsPanel(title: "Contacts", symbol: "person.crop.circle.badge.checkmark") {
          ForEach(store.contactsNeedingReview) { contact in
            ContactDirectoryRow(contact: contact, destinationAddresses: store.suggestedDestinationAddresses(for: contact), deliveryInstructions: store.suggestedDeliveryInstructions(for: contact), packageContents: store.suggestedPackageContents(for: contact)) { updatedContact in
              store.updateContactDirectoryEntry(updatedContact)
            } onToggle: {
              store.toggleContactDirectoryEntry(contact)
            } onReviewed: {
              store.markContactDirectoryEntryReviewed(contact)
            } onCreateDraft: {
              store.createDraftMessage(from: contact)
            } onRemove: {
              store.removeContactDirectoryEntry(contact)
            }
          }
        }

        SettingsPanel(title: "Customer profiles", symbol: "person.text.rectangle.fill") {
          ForEach(Array(Set(store.customerProfilesNeedingReview + store.customerRecipientProfiles.filter { !$0.isEnabled }))) { profile in
            CustomerProfileRow(profile: profile) { updatedProfile in
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

        SettingsPanel(title: "Destination addresses", symbol: "mappin.and.ellipse") {
          ForEach(Array(Set(store.destinationAddressesNeedingReview + store.highRiskDestinationAddresses + store.destinationAddresses.filter { !$0.isEnabled }))) { address in
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

        SettingsPanel(title: "Delivery instructions", symbol: "signpost.right.and.left.fill") {
          ForEach(Array(Set(store.deliveryInstructionsNeedingReview + store.highRiskDeliveryInstructions + store.deliveryInstructions.filter { !$0.isEnabled } + store.deliveryInstructionsWithAccessConstraints.filter { $0.reviewState != .accepted }))) { instruction in
            DeliveryInstructionRow(
              instruction: instruction,
              destinationAddress: store.destinationAddresses.first { $0.id == instruction.destinationAddressID },
              customerProfile: store.customerRecipientProfiles.first { $0.id == instruction.customerProfileID }
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

        SettingsPanel(title: "Package contents", symbol: "shippingbox.circle.fill") {
          ForEach(Array(Set(store.packageContentsNeedingReview + store.unverifiedPackageContents + store.packageContentDiscrepancies + store.highRiskPackageContents + store.highValuePackageContents))) { content in
            PackageContentRow(content: content, custodyRecords: store.suggestedCustodyRecords(for: content)) { updatedContent in
              store.updatePackageContent(updatedContent)
            } onVerified: {
              store.markPackageContentVerified(content)
            } onDiscrepancy: {
              store.markPackageContentDiscrepancy(content)
            } onReviewed: {
              store.markPackageContentReviewed(content)
            } onCreateTask: {
              store.createReviewTask(from: content)
            } onCreateDraft: {
              store.createDraftMessage(from: content)
            } onRemove: {
              store.removePackageContent(content)
            }
          }
        }

        SettingsPanel(title: "Costs & budgets", symbol: "creditcard.and.123") {
          ForEach(Array(Set(store.costRecordsNeedingReview + store.disputedCostRecords + store.unreimbursedCostRecords + store.unapprovedCostRecords + store.highRiskCostRecords + store.missingBudgetCodeCostRecords))) { cost in
            CostRecordRow(cost: cost) { updatedCost in
              store.updateCostRecord(updatedCost)
            } onApproved: {
              store.markCostRecordApproved(cost)
            } onReimbursed: {
              store.markCostRecordReimbursed(cost)
            } onDisputed: {
              store.markCostRecordDisputed(cost)
            } onReviewed: {
              store.markCostRecordReviewed(cost)
            } onCreateTask: {
              store.createReviewTask(from: cost)
            } onCreateDraft: {
              store.createDraftMessage(from: cost)
            } onRemove: {
              store.removeCostRecord(cost)
            }
          }
        }

        SettingsPanel(title: "Returns & claims", symbol: "arrow.uturn.backward.square.fill") {
          ForEach(Array(Set(store.returnClaimsNeedingReview + store.disputedReturnClaims + store.unresolvedReturnClaims + store.overdueReturnClaims + store.highRiskReturnClaims + store.returnClaimsMissingEvidence))) { claim in
            ReturnClaimRow(claim: claim, custodyRecords: store.suggestedCustodyRecords(for: claim), labelReferences: store.suggestedLabelReferenceRecords(for: claim), scanSessions: store.suggestedScanSessionRecords(for: claim)) { updatedClaim in
              store.updateReturnClaim(updatedClaim)
            } onSubmitted: {
              store.markReturnClaimSubmitted(claim)
            } onApproved: {
              store.markReturnClaimApproved(claim)
            } onResolved: {
              store.markReturnClaimResolved(claim)
            } onDisputed: {
              store.markReturnClaimDisputed(claim)
            } onReviewed: {
              store.markReturnClaimReviewed(claim)
            } onCreateTask: {
              store.createReviewTask(from: claim)
            } onCreateDraft: {
              store.createDraftMessage(from: claim)
            } onRemove: {
              store.removeReturnClaim(claim)
            }
          }
        }

        SettingsPanel(title: "Procurement", symbol: "cart.badge.plus") {
          ForEach(Array(Set(store.procurementRequestsNeedingReview + store.unapprovedProcurementRequests + store.rejectedProcurementRequests + store.notYetOrderedProcurementRequests + store.overdueProcurementRequests + store.highRiskProcurementRequests + store.missingBudgetCodeProcurementRequests))) { request in
            ProcurementRequestRow(request: request, custodyRecords: store.suggestedCustodyRecords(for: request), labelReferences: store.suggestedLabelReferenceRecords(for: request), scanSessions: store.suggestedScanSessionRecords(for: request)) { updatedRequest in
              store.updateProcurementRequest(updatedRequest)
            } onApproved: {
              store.markProcurementRequestApproved(request)
            } onOrdered: {
              store.markProcurementRequestOrdered(request)
            } onReceived: {
              store.markProcurementRequestReceived(request)
            } onRejected: {
              store.markProcurementRequestRejected(request)
            } onReviewed: {
              store.markProcurementRequestReviewed(request)
            } onCreateTask: {
              store.createReviewTask(from: request)
            } onCreateDraft: {
              store.createDraftMessage(from: request)
            } onRemove: {
              store.removeProcurementRequest(request)
            }
          }
        }

        SettingsPanel(title: "Receiving inspections", symbol: "checklist.checked") {
          ForEach(Array(Set(store.receivingInspectionsNeedingReview + store.blockedReceivingInspections + store.unresolvedInspectionDiscrepancies + store.highRiskReceivingInspections + store.overdueReceivingInspections + store.quantityMismatchReceivingInspections))) { inspection in
            ReceivingInspectionRow(inspection: inspection, custodyRecords: store.suggestedCustodyRecords(for: inspection)) { updatedInspection in
              store.updateReceivingInspection(updatedInspection)
            } onInspected: {
              store.markReceivingInspectionInspected(inspection)
            } onDiscrepancy: {
              store.markReceivingInspectionDiscrepancy(inspection)
            } onResolved: {
              store.markReceivingInspectionResolved(inspection)
            } onBlocked: {
              store.markReceivingInspectionBlocked(inspection)
            } onReviewed: {
              store.markReceivingInspectionReviewed(inspection)
            } onCreateTask: {
              store.createReviewTask(from: inspection)
            } onCreateDraft: {
              store.createDraftMessage(from: inspection)
            } onRemove: {
              store.removeReceivingInspection(inspection)
            }
          }
        }

        SettingsPanel(title: "Inventory receipts", symbol: "archivebox.fill") {
          ForEach(Array(Set(store.inventoryReceiptsNeedingReview + store.rejectedInventoryReceipts + store.partiallyAcceptedInventoryReceipts + store.highRiskInventoryReceipts + store.unassignedInventoryReceipts + store.inventoryReceiptsMissingStorage))) { receipt in
            InventoryReceiptRow(receipt: receipt, custodyRecords: store.suggestedCustodyRecords(for: receipt)) { updatedReceipt in
              store.updateInventoryReceipt(updatedReceipt)
            } onStocked: {
              store.markInventoryReceiptStocked(receipt)
            } onHandedOff: {
              store.markInventoryReceiptHandedOff(receipt)
            } onPartiallyAccepted: {
              store.markInventoryReceiptPartiallyAccepted(receipt)
            } onRejected: {
              store.markInventoryReceiptRejected(receipt)
            } onReviewed: {
              store.markInventoryReceiptReviewed(receipt)
            } onCreateTask: {
              store.createReviewTask(from: receipt)
            } onCreateDraft: {
              store.createDraftMessage(from: receipt)
            } onRemove: {
              store.removeInventoryReceipt(receipt)
            }
          }
        }

        SettingsPanel(title: "Storage locations", symbol: "cabinet.fill") {
          ForEach(Array(Set(store.storageLocationsNeedingReview + store.disabledStorageLocations + store.highRiskStorageLocations + store.storageLocationsMissingCodes + store.storageLocationsWithAccessNotes + store.storageLocationsWithCapacityWarnings))) { location in
            StorageLocationRow(location: location, custodyRecords: store.suggestedCustodyRecords(for: location)) { updatedLocation in
              store.updateStorageLocation(updatedLocation)
            } onToggle: {
              store.toggleStorageLocation(location)
            } onReviewed: {
              store.markStorageLocationReviewed(location)
            } onCreateTask: {
              store.createReviewTask(from: location)
            } onCreateDraft: {
              store.createDraftMessage(from: location)
            } onRemove: {
              store.removeStorageLocation(location)
            }
          }
        }

        SettingsPanel(title: "Custody chain", symbol: "person.badge.shield.checkmark.fill") {
          ForEach(Array(Set(store.custodyRecordsNeedingReview + store.disputedCustodyRecords + store.openCustodyTransfers + store.overdueCustodyRecords + store.highRiskCustodyRecords + store.custodyRecordsMissingCustodians + store.custodyRecordsMissingLocations))) { record in
            CustodyRecordRow(record: record, labelReferences: store.suggestedLabelReferenceRecords(for: record)) { updatedRecord in
              store.updateCustodyRecord(updatedRecord)
            } onTransferred: {
              store.markCustodyRecordTransferred(record)
            } onReceived: {
              store.markCustodyRecordReceived(record)
            } onReturnedClosed: {
              store.markCustodyRecordReturnedClosed(record)
            } onDisputed: {
              store.markCustodyRecordDisputed(record)
            } onReviewed: {
              store.markCustodyRecordReviewed(record)
            } onCreateTask: {
              store.createReviewTask(from: record)
            } onCreateDraft: {
              store.createDraftMessage(from: record)
            } onRemove: {
              store.removeCustodyRecord(record)
            }
          }
        }

        SettingsPanel(title: "Label references", symbol: "barcode.viewfinder") {
          ForEach(Array(Set(store.labelReferencesNeedingReview + store.invalidLabelReferences + store.unverifiedLabelReferences + store.highRiskLabelReferences + store.labelReferencesMissingValues + store.labelReferencesMissingLinkedRecords))) { record in
            LabelReferenceRow(record: record, scanSessions: store.suggestedScanSessionRecords(for: record)) { updatedRecord in
              store.updateLabelReferenceRecord(updatedRecord)
            } onPrinted: {
              store.markLabelReferencePrinted(record)
            } onVerified: {
              store.markLabelReferenceVerified(record)
            } onInvalid: {
              store.markLabelReferenceInvalid(record)
            } onReviewed: {
              store.markLabelReferenceReviewed(record)
            } onCreateTask: {
              store.createReviewTask(from: record)
            } onCreateDraft: {
              store.createDraftMessage(from: record)
            } onRemove: {
              store.removeLabelReferenceRecord(record)
            }
          }
        }

        SettingsPanel(title: "Scan sessions", symbol: "qrcode.viewfinder") {
          ForEach(Array(Set(store.scanSessionsNeedingReview + store.mismatchScanSessions + store.incompleteScanSessions + store.highRiskScanSessions + store.scanSessionsMissingCapturedValues + store.scanSessionsMissingLabelReferences))) { record in
            ScanSessionRow(record: record) { updatedRecord in
              store.updateScanSessionRecord(updatedRecord)
            } onMatched: {
              store.markScanSessionMatched(record)
            } onMismatch: {
              store.markScanSessionMismatch(record)
            } onCompleted: {
              store.markScanSessionCompleted(record)
            } onReopen: {
              store.reopenScanSession(record)
            } onReviewed: {
              store.markScanSessionReviewed(record)
            } onCreateTask: {
              store.createReviewTask(from: record)
            } onCreateDraft: {
              store.createDraftMessage(from: record)
            } onRemove: {
              store.removeScanSessionRecord(record)
            }
          }
        }

        SettingsPanel(title: "Shipment manifests", symbol: "list.bullet.clipboard.fill") {
          ForEach(Array(Set(store.shipmentManifestsNeedingReview + store.blockedShipmentManifests + store.undispatchedShipmentManifests + store.highRiskShipmentManifests + store.shipmentManifestsMissingIncludedOrders + store.shipmentManifestsMissingHandoffLocation + store.shipmentManifestsWithIncompleteScans))) { record in
            ShipmentManifestRow(record: record) { updatedRecord in
              store.updateShipmentManifestRecord(updatedRecord)
            } onPrepared: {
              store.markShipmentManifestPrepared(record)
            } onDispatched: {
              store.markShipmentManifestDispatched(record)
            } onHandedOff: {
              store.markShipmentManifestHandedOff(record)
            } onBlocked: {
              store.markShipmentManifestBlocked(record)
            } onReopen: {
              store.reopenShipmentManifest(record)
            } onReviewed: {
              store.markShipmentManifestReviewed(record)
            } onCreateTask: {
              store.createReviewTask(from: record)
            } onCreateDraft: {
              store.createDraftMessage(from: record)
            } onRemove: {
              store.removeShipmentManifestRecord(record)
            }
          }
        }

        SettingsPanel(title: "Dispatch readiness", symbol: "checkmark.rectangle.stack.fill") {
          ForEach(Array(Set(store.dispatchChecklistsNeedingReview + store.blockedDispatchChecklists + store.incompleteDispatchChecklists + store.highRiskDispatchChecklists + store.dispatchChecklistsMissingRequirements + store.dispatchChecklistsLinkedToBlockedManifests))) { checklist in
            DispatchReadinessRow(checklist: checklist) { updatedChecklist in
              store.updateDispatchReadinessChecklist(updatedChecklist)
            } onReady: {
              store.markDispatchChecklistReady(checklist)
            } onBlocked: {
              store.markDispatchChecklistBlocked(checklist)
            } onCompleted: {
              store.markDispatchChecklistCompleted(checklist)
            } onReopen: {
              store.reopenDispatchChecklist(checklist)
            } onReviewed: {
              store.markDispatchChecklistReviewed(checklist)
            } onCreateTask: {
              store.createReviewTask(from: checklist)
            } onCreateDraft: {
              store.createDraftMessage(from: checklist)
            } onRemove: {
              store.removeDispatchReadinessChecklist(checklist)
            }
          }
        }

        SettingsPanel(title: "Accounts", symbol: "key.horizontal.fill") {
          ForEach(store.accountRecordsNeedingReview) { account in
            AccountCredentialRow(account: account, contacts: store.contactDirectoryEntries, destinationAddresses: store.suggestedDestinationAddresses(for: account), deliveryInstructions: store.suggestedDeliveryInstructions(for: account), packageContents: store.suggestedPackageContents(for: account)) { updatedAccount in
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
            } onRemove: {
              store.removeAccountCredentialRecord(account)
            }
          }
        }

        SettingsPanel(title: "Vendor profiles", symbol: "building.2.crop.circle.fill") {
          ForEach(Array(Set(store.vendorProfilesNeedingReview + store.highRiskEnabledVendorProfiles)).sorted { lhs, rhs in
            lhs.riskLevel.riskRank > rhs.riskLevel.riskRank
          }) { profile in
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
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }
}

struct ReviewOrderRow: View {
  var order: TrackedOrder
  var onSave: (TrackedOrder) -> Void
  var onClear: () -> Void
  var onDiscard: () -> Void
  var onCreateTask: () -> Void = {}
  var onCreateDraft: () -> Void = {}
  @State private var isEditing = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text("\(order.orderNumber) • \(order.store)")
            .font(.headline)
          Text("Recipient \(order.recipientEmail), checked in \(order.checkedMailbox)")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(order.latestStatus)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Badge(order.reviewState.rawValue, color: order.reviewState.color)
      }
      HStack {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Add to orders", systemImage: "checkmark.circle.fill", action: onClear)
          .buttonStyle(.borderedProminent)
        Button("Discard spam", systemImage: "trash", action: onDiscard)
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
        Button("Draft", systemImage: "envelope.open.fill", action: onCreateDraft)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      OrderEditView(order: order) { updatedOrder in
        onSave(updatedOrder)
      }
    }
  }
}

struct ReviewMailEventRow: View {
  var event: MailEvent
  var onClear: () -> Void
  var onDiscard: () -> Void
  var onCreateTask: () -> Void = {}

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(event.sender)
            .font(.headline)
          Text(event.summary)
            .foregroundStyle(.secondary)
          Text("Suggested match: \(event.matchedOrder)")
            .font(.caption.weight(.semibold))
        }
        Spacer()
        Badge(event.severity.rawValue, color: event.severity.color)
      }
      HStack {
        Button("Add to order", systemImage: "checkmark.circle.fill", action: onClear)
          .buttonStyle(.borderedProminent)
        Button("Discard spam", systemImage: "trash", action: onDiscard)
          .buttonStyle(.bordered)
        Button("Task", systemImage: "checklist", action: onCreateTask)
          .buttonStyle(.bordered)
      }
    }
    .padding(12)
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
