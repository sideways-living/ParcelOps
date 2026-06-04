import SwiftUI

struct PackageContentsView: View {
  var store: ParcelOpsStore
  @State private var selectedCategory: PackageItemCategory?
  @State private var selectedValueBand: PackageValueBand?
  @State private var selectedVerificationStatus: PackageVerificationStatus?
  @State private var selectedRiskLevel: ShipmentRiskLevel?
  @State private var selectedLinkedEntityType: ReviewTaskLinkedEntityType?
  @State private var selectedReviewState: ReviewState?
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let reviewStates: [ReviewState] = [.needsReview, .monitor, .accepted]

  private var filteredContents: [PackageContentRecord] {
    store.filteredPackageContents(
      itemCategory: selectedCategory,
      valueBand: selectedValueBand,
      verificationStatus: selectedVerificationStatus,
      riskLevel: selectedRiskLevel,
      linkedEntityType: selectedLinkedEntityType,
      reviewState: selectedReviewState
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        filterBar

        SettingsPanel(title: "Content records", symbol: "shippingbox.circle.fill") {
          HStack {
            Text("\(filteredContents.count) visible content records")
              .font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            Button("Add content", systemImage: "plus", action: store.addPackageContentPlaceholder)
              .buttonStyle(.borderedProminent)
          }

          if filteredContents.isEmpty {
            Text("No package contents match the selected filters.")
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(12)
              .background(.quinary)
              .clipShape(RoundedRectangle(cornerRadius: 8))
          } else {
            ForEach(filteredContents) { content in
              PackageContentRow(content: content, costRecords: store.suggestedCostRecords(for: content), returnClaims: store.suggestedReturnClaims(for: content), procurementRequests: store.suggestedProcurementRequests(for: content), receivingInspections: store.suggestedReceivingInspections(for: content), inventoryReceipts: store.suggestedInventoryReceipts(for: content)) { updatedContent in
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
        }
      }
      .padding(horizontalSizeClass == .compact ? 14 : 24)
    }
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Package Contents")
          .font(horizontalSizeClass == .compact ? .title.bold() : .largeTitle.bold())
        Text("Local item verification, quantity checks, evidence links, and discrepancy review for packages.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 6) {
        Badge("\(store.unverifiedPackageContents.count) unverified", color: .orange)
        Badge("\(store.packageContentDiscrepancies.count) discrepancies", color: .red)
      }
    }
  }

  private var filterBar: some View {
    HStack {
      Picker("Category", selection: $selectedCategory) {
        Text("All categories").tag(nil as PackageItemCategory?)
        ForEach(PackageItemCategory.allCases) { category in
          Text(category.rawValue).tag(category as PackageItemCategory?)
        }
      }
      .pickerStyle(.menu)

      Picker("Value", selection: $selectedValueBand) {
        Text("All value").tag(nil as PackageValueBand?)
        ForEach(PackageValueBand.allCases) { value in
          Text(value.rawValue).tag(value as PackageValueBand?)
        }
      }
      .pickerStyle(.menu)

      Picker("Verification", selection: $selectedVerificationStatus) {
        Text("All verification").tag(nil as PackageVerificationStatus?)
        ForEach(PackageVerificationStatus.allCases) { status in
          Text(status.rawValue).tag(status as PackageVerificationStatus?)
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

      Picker("Linked", selection: $selectedLinkedEntityType) {
        Text("All links").tag(nil as ReviewTaskLinkedEntityType?)
        ForEach(ReviewTaskLinkedEntityType.allCases) { type in
          Text(type.rawValue).tag(type as ReviewTaskLinkedEntityType?)
        }
      }
      .pickerStyle(.menu)

      Picker("Review", selection: $selectedReviewState) {
        Text("All review").tag(nil as ReviewState?)
        ForEach(reviewStates, id: \.self) { state in
          Text(state.rawValue).tag(state as ReviewState?)
        }
      }
      .pickerStyle(.menu)

      Spacer()

      Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle") {
        selectedCategory = nil
        selectedValueBand = nil
        selectedVerificationStatus = nil
        selectedRiskLevel = nil
        selectedLinkedEntityType = nil
        selectedReviewState = nil
      }
      .buttonStyle(.bordered)
    }
  }
}

struct PackageContentRow: View {
  var content: PackageContentRecord
  var costRecords: [CostRecord] = []
  var returnClaims: [ReturnClaimRecord] = []
  var procurementRequests: [ProcurementRequest] = []
  var receivingInspections: [ReceivingInspectionRecord] = []
  var inventoryReceipts: [InventoryReceiptRecord] = []
  var onSave: (PackageContentRecord) -> Void
  var onVerified: () -> Void
  var onDiscrepancy: () -> Void
  var onReviewed: () -> Void
  var onCreateTask: () -> Void
  var onCreateDraft: () -> Void
  var onRemove: () -> Void
  @State private var isEditing = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: content.itemCategory.symbol)
          .foregroundStyle(content.riskLevel.color)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(content.title)
                .font(.headline)
              Text("\(content.itemCategory.rawValue) • \(content.valueBand.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Badge(content.verificationStatus.rawValue, color: content.verificationStatus.color)
          }

          Text(content.itemSummary)
            .foregroundStyle(.secondary)
          Text(content.discrepancySummary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)

          HStack(spacing: 8) {
            Badge(content.riskLevel.rawValue, color: content.riskLevel.color)
            Badge(content.reviewState.rawValue, color: content.reviewState.color)
            Label("\(content.verifiedQuantity)/\(content.expectedQuantity)", systemImage: "number.circle.fill")
              .font(.caption)
              .foregroundStyle(.secondary)
            Label(content.linkedEntityType.rawValue, systemImage: content.linkedEntityType.symbol)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      CostRecordStrip(costs: costRecords)
      ReturnClaimStrip(claims: returnClaims)
      ProcurementRequestStrip(requests: procurementRequests)
      ReceivingInspectionStrip(inspections: receivingInspections)
      InventoryReceiptStrip(receipts: inventoryReceipts)

      HStack {
        Button("Edit", systemImage: "pencil", action: { isEditing = true })
          .buttonStyle(.bordered)
        Button("Verified", systemImage: "checkmark.seal.fill", action: onVerified)
          .buttonStyle(.bordered)
        Button("Discrepancy", systemImage: "exclamationmark.triangle.fill", action: onDiscrepancy)
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
    .background(.quinary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .sheet(isPresented: $isEditing) {
      PackageContentEditView(content: content) { updatedContent in
        onSave(updatedContent)
      }
    }
  }
}

struct PackageContentEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: PackageContentRecord
  var onSave: (PackageContentRecord) -> Void

  init(content: PackageContentRecord, onSave: @escaping (PackageContentRecord) -> Void) {
    self._draft = State(initialValue: content)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Content") {
          TextField("Title", text: $draft.title)
          TextField("Item summary", text: $draft.itemSummary, axis: .vertical)
          Stepper("Expected quantity: \(draft.expectedQuantity)", value: $draft.expectedQuantity, in: 0...999)
          Stepper("Verified quantity: \(draft.verifiedQuantity)", value: $draft.verifiedQuantity, in: 0...999)
          Picker("Category", selection: $draft.itemCategory) {
            ForEach(PackageItemCategory.allCases) { category in
              Text(category.rawValue).tag(category)
            }
          }
          Picker("Value band", selection: $draft.valueBand) {
            ForEach(PackageValueBand.allCases) { band in
              Text(band.rawValue).tag(band)
            }
          }
        }

        Section("Verification") {
          Picker("Status", selection: $draft.verificationStatus) {
            ForEach(PackageVerificationStatus.allCases) { status in
              Text(status.rawValue).tag(status)
            }
          }
          TextField("Discrepancy summary", text: $draft.discrepancySummary, axis: .vertical)
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
          TextField("Last reviewed", text: $draft.lastReviewedDate)
        }

        Section("Link") {
          Picker("Linked record type", selection: $draft.linkedEntityType) {
            ForEach(ReviewTaskLinkedEntityType.allCases) { type in
              Text(type.rawValue).tag(type)
            }
          }
          TextField("Linked record ID", text: $draft.linkedEntityID)
        }
      }
      .navigationTitle("Edit Content")
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
