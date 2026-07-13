import XCTest
@testable import ParcelOps

final class ParcelOpsModelRegressionTests: XCTestCase {
  func testInboxCreatedOrderDetectionAndMissingFields() {
    let forwarded = makeOrder(
      orderNumber: "Pending",
      trackingNumber: "Pending review",
      destination: "Destination needs review",
      checkedMailbox: "tracking@example.com",
      source: .forwardedMailbox,
      latestStatus: "Created from forwarded email"
    )

    XCTAssertTrue(forwarded.isInboxCreatedLocalOrder)
    XCTAssertEqual(forwarded.missingInboxOrderFieldCount, 3)

    let manualImport = makeOrder(
      orderNumber: "PO-123",
      trackingNumber: "TRK123",
      destination: "Melbourne VIC",
      checkedMailbox: "manual-import",
      source: .manual,
      latestStatus: "Imported from local review"
    )

    XCTAssertTrue(manualImport.isInboxCreatedLocalOrder)
    XCTAssertEqual(manualImport.missingInboxOrderFieldCount, 0)
  }

  func testWishlistSellerEvidenceGapsAndScore() {
    let weakOption = WishlistComparisonOption(
      sellerName: "Unknown marketplace seller",
      productURL: "Pending",
      listedPrice: "49.00",
      currency: "USD",
      estimatedAUDTotal: "Pending AUD total",
      postageCost: "Pending",
      postageTime: "Pending",
      sellerRegion: "Overseas",
      trustRating: "Unknown",
      trustNotes: "No returns or warranty evidence recorded.",
      recommendation: "Needs review",
      lastChecked: "Never",
      localScore: nil,
      riskLevel: nil,
      decisionReason: nil
    )

    XCTAssertTrue(weakOption.operatorSellerEvidenceGaps.contains("product link"))
    XCTAssertTrue(weakOption.operatorSellerEvidenceGaps.contains("AUD total"))
    XCTAssertTrue(weakOption.operatorSellerEvidenceGaps.contains("postage cost"))
    XCTAssertTrue(weakOption.operatorSellerEvidenceGaps.contains("postage time"))
    XCTAssertTrue(weakOption.operatorSellerEvidenceGaps.contains("seller trust"))
    XCTAssertEqual(weakOption.operatorSellerMatrixRisk, "High risk")

    let strongOption = WishlistComparisonOption(
      sellerName: "Known Australian retailer",
      productURL: "https://example.com/product",
      listedPrice: "99.00",
      currency: "AUD",
      estimatedAUDTotal: "AUD 109 delivered",
      postageCost: "AUD 10",
      postageTime: "3-5 business days",
      sellerRegion: "Australia",
      trustRating: "Trusted",
      trustNotes: "Returns and warranty visible.",
      recommendation: "Shortlist",
      lastChecked: "Today",
      localScore: nil,
      riskLevel: nil,
      decisionReason: nil
    )

    XCTAssertTrue(strongOption.operatorSellerEvidenceGaps.isEmpty)
    XCTAssertGreaterThanOrEqual(strongOption.operatorSellerMatrixScore, 75)
    XCTAssertEqual(strongOption.operatorSellerMatrixRisk, "Lower risk")
  }

  func testWishlistPurchaseBlockerProgression() {
    let optionID = UUID()
    let option = WishlistComparisonOption(
      id: optionID,
      sellerName: "Known Australian retailer",
      productURL: "https://example.com/product",
      listedPrice: "99.00",
      currency: "AUD",
      estimatedAUDTotal: "AUD 109 delivered",
      postageCost: "AUD 10",
      postageTime: "3-5 business days",
      sellerRegion: "Australia",
      trustRating: "Trusted",
      trustNotes: "Returns and warranty visible.",
      recommendation: "Shortlist",
      lastChecked: "Today",
      localScore: 90,
      riskLevel: "Lower risk",
      decisionReason: "Best landed cost and trust evidence."
    )

    let baseItem = WishlistItem(
      itemName: "Replacement scanner",
      storefront: "Known Australian retailer",
      storefrontURL: "https://example.com/product",
      estimatedCost: "AUD 109",
      owner: "Receiving desk",
      pool: "Operations",
      source: .manual,
      status: "Comparing",
      capturedDetail: "Needed for receiving desk",
      comparisonStatus: "Options captured",
      comparisonNotes: "One strong seller option",
      purchaseReadiness: nil,
      preferredOptionID: optionID,
      comparisonOptions: [option],
      purchaseChecks: [WishlistPurchaseCheck(title: "Readiness", status: "Passed", detail: "Checked locally", severity: "Low")],
      purchaseDecision: nil,
      purchaseHandoff: nil
    )

    XCTAssertTrue(baseItem.operatorPurchaseBlockers.contains("draft purchase decision"))
    XCTAssertTrue(baseItem.operatorPurchaseBlockers.contains("prepare handoff"))

    let decidedItem = WishlistItem(
      itemName: baseItem.itemName,
      storefront: baseItem.storefront,
      storefrontURL: baseItem.storefrontURL,
      estimatedCost: baseItem.estimatedCost,
      owner: baseItem.owner,
      pool: baseItem.pool,
      source: baseItem.source,
      status: "Ready for handoff",
      capturedDetail: baseItem.capturedDetail,
      comparisonStatus: baseItem.comparisonStatus,
      comparisonNotes: baseItem.comparisonNotes,
      purchaseReadiness: "Ready for purchase review",
      preferredOptionID: optionID,
      comparisonOptions: [option],
      purchaseChecks: baseItem.purchaseChecks,
      purchaseDecision: WishlistPurchaseDecision(
        selectedOptionID: optionID,
        selectedSellerName: option.sellerName,
        decisionStatus: "Approved locally",
        totalAUDSummary: option.estimatedAUDTotal,
        postageSummary: "\(option.postageCost), \(option.postageTime)",
        trustSummary: option.trustRating,
        rejectedOptionsSummary: "None",
        decisionNotes: "Proceed outside ParcelOps.",
        decidedBy: "Operator",
        decidedDate: "Today",
        reviewState: .accepted
      ),
      purchaseHandoff: WishlistPurchaseHandoff(
        sellerName: option.sellerName,
        accountLabel: "Operations account",
        purchaseStatus: "Ready to buy externally",
        expectedOrderSignals: "Order confirmation email",
        orderWatchStatus: "Watch Inbox",
        linkedOrderID: nil,
        notes: "No purchase in ParcelOps.",
        updatedAt: "Today"
      )
    )

    XCTAssertEqual(decidedItem.operatorPurchaseBlockers, ["link order after confirmation"])
  }

  func testWishlistAgentReadinessSummaryHandlesNoActiveItems() {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    resetWishlistState(store)

    let summary = store.wishlistAgentReadinessSummary

    XCTAssertEqual(summary.title, "Wishlist agent path not started")
    XCTAssertEqual(summary.tone, "neutral")
    XCTAssertEqual(summary.readyBriefCount, 0)
    XCTAssertEqual(summary.sellerOptionGapCount, 0)
    XCTAssertEqual(summary.trustReviewCount, 0)
    XCTAssertEqual(summary.orderWatchGapCount, 0)
  }

  func testWishlistAgentReadinessSummaryFlagsSellerEvidenceBlockers() {
    let weakOption = WishlistComparisonOption(
      sellerName: "Unknown overseas seller",
      productURL: "Pending",
      listedPrice: "49.00",
      currency: "USD",
      estimatedAUDTotal: "Pending AUD total",
      postageCost: "Pending",
      postageTime: "Pending",
      sellerRegion: "Overseas",
      trustRating: "Unknown",
      trustNotes: "No delivery evidence.",
      recommendation: "Needs review",
      lastChecked: "Never",
      localScore: nil,
      riskLevel: "High risk",
      decisionReason: nil
    )
    let item = WishlistItem(
      itemName: "Replacement scanner",
      storefront: "Unknown overseas seller",
      storefrontURL: "Pending",
      estimatedCost: "Pending",
      owner: "Receiving desk",
      pool: "Operations",
      source: .manual,
      status: "Comparing",
      capturedDetail: "Needed for receiving desk",
      comparisonStatus: "Options need review",
      comparisonNotes: "Weak seller evidence",
      purchaseReadiness: "Waiting for seller evidence",
      preferredOptionID: weakOption.id,
      comparisonOptions: [weakOption],
      purchaseChecks: [],
      purchaseDecision: nil,
      purchaseHandoff: nil
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    resetWishlistState(store)
    store.wishlistItems = [item]

    let summary = store.wishlistAgentReadinessSummary
    let evidenceItem = summary.items.first { $0.title == "Seller comparison evidence" }
    let trustItem = summary.items.first { $0.title == "Seller trust gate" }

    XCTAssertEqual(summary.title, "Wishlist agent path has blockers")
    XCTAssertEqual(summary.tone, "warning")
    XCTAssertGreaterThan(summary.sellerOptionGapCount, 0)
    XCTAssertEqual(summary.trustReviewCount, 1)
    XCTAssertEqual(evidenceItem?.tone, "warning")
    XCTAssertEqual(trustItem?.tone, "warning")
    XCTAssertTrue(summary.verdict.contains("blocker area"))
  }

  func testWishlistAgentReadinessSummaryFlagsOrderWatchGap() {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    resetWishlistState(store)
    store.wishlistItems = [item]

    let summary = store.wishlistAgentReadinessSummary
    let orderWatchItem = summary.items.first { $0.title == "Post-purchase order watch" }

    XCTAssertEqual(summary.title, "Wishlist agent path needs operator review")
    XCTAssertEqual(summary.tone, "attention")
    XCTAssertEqual(summary.orderWatchGapCount, 1)
    XCTAssertEqual(orderWatchItem?.status, "1 open")
    XCTAssertEqual(orderWatchItem?.tone, "attention")
    XCTAssertTrue(orderWatchItem?.detail.contains("order confirmation") == true)
  }

  func testWishlistAgentReadinessSummaryClearsLinkedOrderWatchGap() {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: UUID()
    )
    resetWishlistState(store)
    store.wishlistItems = [item]

    let summary = store.wishlistAgentReadinessSummary
    let orderWatchItem = summary.items.first { $0.title == "Post-purchase order watch" }

    XCTAssertEqual(summary.orderWatchGapCount, 0)
    XCTAssertEqual(orderWatchItem?.status, "No open watch gaps")
    XCTAssertEqual(orderWatchItem?.tone, "success")
    XCTAssertTrue(orderWatchItem?.detail.contains("No current Wishlist handoff") == true)
  }

  func testWishlistOrderWatchMatchesExistingLocalOrder() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    let order = makeOrder(
      orderNumber: "ORDER-123",
      trackingNumber: "TRACK-123",
      destination: "Brisbane QLD",
      checkedMailbox: "caught@droctopus.net",
      source: .forwardedMailbox,
      latestStatus: "Known Australian retailer Replacement scanner shipped with tracking."
    )
    resetWishlistState(store)
    store.orders = [order]
    store.wishlistItems = [item]

    store.addWishlistOrderWatchRecord(item)
    let stagedRecord = try XCTUnwrap(store.wishlistOrderWatchRecords.first)
    store.checkWishlistOrderWatchRecord(stagedRecord)

    let checkedRecord = try XCTUnwrap(store.wishlistOrderWatchRecords.first)
    let checkedItem = try XCTUnwrap(store.wishlistItems.first)

    XCTAssertEqual(checkedRecord.linkedOrderID, order.id)
    XCTAssertEqual(checkedRecord.watchStatus, "Matched local order")
    XCTAssertEqual(checkedRecord.reviewState, .accepted)
    XCTAssertTrue(checkedRecord.matchedOrderSummary.contains(order.orderNumber))
    XCTAssertEqual(checkedItem.purchaseHandoff?.linkedOrderID, order.id)
    XCTAssertEqual(checkedItem.purchaseReadiness, "Order watch matched local order")
  }

  func testWishlistOrderWatchBatchMatchesOpenRecordsOnly() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let matchedItem = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    let waitingItem = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Packing bench scale",
      sellerName: "Warehouse Supplies",
      linkedOrderID: nil
    )
    let order = makeOrder(
      orderNumber: "ORDER-456",
      trackingNumber: "TRACK-456",
      destination: "Melbourne VIC",
      checkedMailbox: "caught@droctopus.net",
      source: .forwardedMailbox,
      latestStatus: "Known Australian retailer Replacement scanner dispatched."
    )
    resetWishlistState(store)
    store.orders = [order]
    store.intakeEmails = []
    store.wishlistItems = [matchedItem, waitingItem]
    store.addWishlistOrderWatchRecord(matchedItem)
    store.addWishlistOrderWatchRecord(waitingItem)

    store.checkOpenWishlistOrderWatchRecords()

    let matchedRecord = try XCTUnwrap(store.wishlistOrderWatchRecords.first { $0.wishlistItemID == matchedItem.id })
    let waitingRecord = try XCTUnwrap(store.wishlistOrderWatchRecords.first { $0.wishlistItemID == waitingItem.id })

    XCTAssertEqual(matchedRecord.linkedOrderID, order.id)
    XCTAssertEqual(matchedRecord.watchStatus, "Matched local order")
    XCTAssertNil(waitingRecord.linkedOrderID)
    XCTAssertEqual(waitingRecord.watchStatus, "No confirmation found yet")
    XCTAssertEqual(waitingRecord.reviewState, .needsReview)
  }

  func testWishlistOrderWatchReviewedAndBlockedStates() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let unlinkedItem = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    let linkedItem = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Packing bench scale",
      sellerName: "Warehouse Supplies",
      linkedOrderID: UUID()
    )
    resetWishlistState(store)
    store.wishlistItems = [unlinkedItem, linkedItem]
    store.addWishlistOrderWatchRecord(unlinkedItem)
    store.addWishlistOrderWatchRecord(linkedItem)

    let unlinkedRecord = try XCTUnwrap(store.wishlistOrderWatchRecords.first { $0.wishlistItemID == unlinkedItem.id })
    let linkedRecord = try XCTUnwrap(store.wishlistOrderWatchRecords.first { $0.wishlistItemID == linkedItem.id })

    store.markWishlistOrderWatchRecordReviewed(unlinkedRecord)
    store.markWishlistOrderWatchRecordReviewed(linkedRecord)

    var reviewedUnlinked = try XCTUnwrap(store.wishlistOrderWatchRecords.first { $0.wishlistItemID == unlinkedItem.id })
    let reviewedLinked = try XCTUnwrap(store.wishlistOrderWatchRecords.first { $0.wishlistItemID == linkedItem.id })

    XCTAssertEqual(reviewedUnlinked.watchStatus, "Reviewed; still awaiting order")
    XCTAssertEqual(reviewedUnlinked.reviewState, .accepted)
    XCTAssertEqual(reviewedLinked.watchStatus, "Reviewed and linked")
    XCTAssertEqual(reviewedLinked.reviewState, .accepted)

    store.blockWishlistOrderWatchRecord(reviewedUnlinked)

    reviewedUnlinked = try XCTUnwrap(store.wishlistOrderWatchRecords.first { $0.wishlistItemID == unlinkedItem.id })
    XCTAssertEqual(reviewedUnlinked.watchStatus, "Blocked locally")
    XCTAssertEqual(reviewedUnlinked.reviewState, .needsReview)
  }

  func testWishlistOrderWatchRemovalLogsWithoutDeletingItem() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    resetWishlistState(store)
    store.wishlistItems = [item]
    store.auditEvents = []
    store.addWishlistOrderWatchRecord(item)
    let record = try XCTUnwrap(store.wishlistOrderWatchRecords.first)

    store.removeWishlistOrderWatchRecord(record)

    XCTAssertTrue(store.wishlistOrderWatchRecords.isEmpty)
    XCTAssertEqual(store.wishlistItems.map(\.id), [item.id])
    XCTAssertTrue(store.auditEvents.contains { $0.summary == "Wishlist order watch record removed locally." })
  }

  func testWishlistOrderWatchReviewTaskCreatesAndRefreshesCandidateTask() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    let intake = ForwardedEmailIntake(
      sender: "orders@known-retailer.example",
      subject: "Order TEST-123 shipped tracking ABC123",
      receivedDate: "Today",
      rawBodyPreview: "Known Australian retailer confirmed Replacement scanner order TEST-123 shipped with tracking ABC123.",
      detectedMerchant: "Known Australian retailer",
      detectedOrderNumber: "TEST-123",
      detectedTrackingNumber: "ABC123",
      detectedDestinationAddress: "Brisbane QLD",
      linkedOrderID: nil,
      reviewState: .needsReview
    )
    resetWishlistState(store)
    store.wishlistItems = [item]
    store.intakeEmails = [intake]
    store.reviewTasks = []
    store.addWishlistOrderWatchRecord(item)
    let record = try XCTUnwrap(store.wishlistOrderWatchRecords.first)

    store.createWishlistOrderWatchRecordReviewTask(record)
    store.createWishlistOrderWatchRecordReviewTask(record)

    let task = try XCTUnwrap(store.reviewTasks.first)

    XCTAssertEqual(store.reviewTasks.count, 1)
    XCTAssertEqual(task.title, "Review Wishlist Inbox confirmation candidates: Replacement scanner")
    XCTAssertEqual(task.linkedEntityType, .wishlistItem)
    XCTAssertEqual(task.linkedEntityID, item.id.uuidString)
    XCTAssertEqual(task.priority, .urgent)
    XCTAssertTrue(task.summary.contains("Inbox candidates: 1"))
    XCTAssertTrue(task.summary.contains("TEST-123"))
  }

  func testWishlistClosureBlockedByMissingOperationsTrail() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: UUID()
    )
    resetWishlistState(store)
    resetWishlistOperationsTrail(store)
    store.reviewTasks = []
    store.wishlistItems = [item]

    store.closeWishlistItemLocally(item)

    let updatedItem = try XCTUnwrap(store.wishlistItems.first)
    let closureTask = try XCTUnwrap(store.reviewTasks.first)

    XCTAssertNotEqual(updatedItem.status, "Closed locally")
    XCTAssertEqual(updatedItem.purchaseReadiness, "Purchased externally; watch for confirmation")
    XCTAssertEqual(closureTask.linkedEntityType, .wishlistItem)
    XCTAssertEqual(closureTask.linkedEntityID, item.id.uuidString)
    XCTAssertTrue(closureTask.title.contains("Close Wishlist item"))
    XCTAssertTrue(closureTask.summary.contains("receiving"))
    XCTAssertTrue(closureTask.summary.contains("dispatch"))
  }

  func testWishlistClosureReadinessBatchCreatesTaskForGaps() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: UUID()
    )
    resetWishlistState(store)
    resetWishlistOperationsTrail(store)
    store.reviewTasks = []
    store.wishlistItems = [item]

    store.checkWishlistOperationsClosureReadinessBatch()

    let closureTask = try XCTUnwrap(store.reviewTasks.first)

    XCTAssertEqual(closureTask.linkedEntityType, .wishlistItem)
    XCTAssertEqual(closureTask.linkedEntityID, "wishlist-closure-readiness-batch")
    XCTAssertEqual(closureTask.title, "Follow up Wishlist closure readiness")
    XCTAssertTrue(closureTask.summary.contains("closure gaps"))
    XCTAssertTrue(closureTask.summary.contains("local only"))
    XCTAssertEqual(closureTask.status, .open)
  }

  func testWishlistOperationsTrailCarriesLinkedOrderContext() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let linkedOrderID = UUID()
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: linkedOrderID
    )
    resetWishlistState(store)
    resetWishlistOperationsTrail(store)
    store.wishlistItems = [item]

    stageWishlistOperationsTrail(store, for: item)

    let inspection = try XCTUnwrap(store.receivingInspections.first)
    let receipt = try XCTUnwrap(store.inventoryReceipts.first)
    let location = try XCTUnwrap(store.storageLocations.first)
    let custody = try XCTUnwrap(store.custodyRecords.first)
    let label = try XCTUnwrap(store.labelReferenceRecords.first)
    let scan = try XCTUnwrap(store.scanSessionRecords.first)
    let manifest = try XCTUnwrap(store.shipmentManifestRecords.first)
    let checklist = try XCTUnwrap(store.dispatchReadinessChecklists.first)

    XCTAssertEqual(inspection.orderID, linkedOrderID)
    XCTAssertEqual(receipt.orderID, linkedOrderID)
    XCTAssertEqual(Set(location.orderIDs), [linkedOrderID])
    XCTAssertEqual(custody.orderID, linkedOrderID)
    XCTAssertEqual(label.orderID, linkedOrderID)
    XCTAssertEqual(scan.orderID, linkedOrderID)
    XCTAssertEqual(manifest.includedOrderIDs, [linkedOrderID])
    XCTAssertEqual(checklist.orderIDs, [linkedOrderID])
    XCTAssertEqual(receipt.receivingInspectionID, inspection.id)
    XCTAssertEqual(custody.inventoryReceiptID, receipt.id)
    XCTAssertEqual(custody.storageLocationID, location.id)
    XCTAssertEqual(label.inventoryReceiptID, receipt.id)
    XCTAssertEqual(label.custodyRecordID, custody.id)
    XCTAssertEqual(scan.linkedLabelReferenceID, label.id)
    XCTAssertEqual(scan.inventoryReceiptID, receipt.id)
    XCTAssertEqual(manifest.inventoryReceiptIDs, [receipt.id])
    XCTAssertEqual(manifest.custodyRecordIDs, [custody.id])
    XCTAssertEqual(manifest.labelReferenceIDs, [label.id])
    XCTAssertEqual(manifest.scanSessionIDs, [scan.id])
    XCTAssertEqual(checklist.shipmentManifestID, manifest.id)
    XCTAssertEqual(checklist.inventoryReceiptIDs, [receipt.id])
    XCTAssertEqual(checklist.custodyRecordIDs, [custody.id])
    XCTAssertEqual(checklist.labelReferenceIDs, [label.id])
    XCTAssertEqual(checklist.scanSessionIDs, [scan.id])
  }

  func testWishlistSuggestionsReturnStagedOperationsTrail() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: UUID()
    )
    resetWishlistState(store)
    resetWishlistOperationsTrail(store)
    store.wishlistItems = [item]
    stageWishlistOperationsTrail(store, for: item)

    XCTAssertEqual(store.suggestedReceivingInspections(for: item).map(\.id), store.receivingInspections.map(\.id))
    XCTAssertEqual(store.suggestedInventoryReceipts(for: item).map(\.id), store.inventoryReceipts.map(\.id))
    XCTAssertEqual(store.suggestedStorageLocations(for: item).map(\.id), store.storageLocations.map(\.id))
    XCTAssertEqual(store.suggestedCustodyRecords(for: item).map(\.id), store.custodyRecords.map(\.id))
    XCTAssertEqual(store.suggestedLabelReferenceRecords(for: item).map(\.id), store.labelReferenceRecords.map(\.id))
    XCTAssertEqual(store.suggestedScanSessionRecords(for: item).map(\.id), store.scanSessionRecords.map(\.id))
    XCTAssertEqual(store.suggestedShipmentManifestRecords(for: item).map(\.id), store.shipmentManifestRecords.map(\.id))
    XCTAssertEqual(store.suggestedDispatchReadinessChecklists(for: item).map(\.id), store.dispatchReadinessChecklists.map(\.id))
  }

  func testWishlistCloseSucceedsWithCompleteLocalOperationsTrail() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: UUID()
    )
    resetWishlistState(store)
    resetWishlistOperationsTrail(store)
    store.reviewTasks = []
    store.wishlistItems = [item]
    stageWishlistOperationsTrail(store, for: item)

    store.closeWishlistItemLocally(item)

    let closed = try XCTUnwrap(store.wishlistItems.first)

    XCTAssertEqual(closed.status, "Closed locally")
    XCTAssertEqual(closed.purchaseReadiness, "Wishlist operations closed locally")
    XCTAssertEqual(closed.purchaseHandoff?.purchaseStatus, "Closed locally after operations handoff")
    XCTAssertEqual(closed.purchaseHandoff?.orderWatchStatus, "Closed against local order and operations trail")
    XCTAssertTrue(store.reviewTasks.isEmpty)
  }

  func testWishlistCloseReadyBatchClosesOnlyCompleteItems() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let readyItem = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: UUID()
    )
    let blockedItem = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Packing bench scale",
      sellerName: "Warehouse Supplies",
      linkedOrderID: UUID()
    )
    resetWishlistState(store)
    resetWishlistOperationsTrail(store)
    store.reviewTasks = []
    store.wishlistItems = [readyItem, blockedItem]
    stageWishlistOperationsTrail(store, for: readyItem)
    store.createReviewTask(
      linkedEntityType: .wishlistItem,
      linkedEntityID: blockedItem.id.uuidString,
      label: "Resolve Wishlist closure gap",
      summary: "Open follow-up blocks local closure until completed."
    )

    store.closeReadyWishlistItemsLocally()

    let closed = try XCTUnwrap(store.wishlistItems.first { $0.id == readyItem.id })
    let stillOpen = try XCTUnwrap(store.wishlistItems.first { $0.id == blockedItem.id })

    XCTAssertEqual(closed.status, "Closed locally")
    XCTAssertNotEqual(stillOpen.status, "Closed locally")
    XCTAssertEqual(stillOpen.purchaseReadiness, "Purchased externally; watch for confirmation")
  }

  func testWishlistPriceWatchRuleMatchesSavedSellerQuote() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    let rule = makeWishlistPriceWatchRule(
      item: item,
      targetAUDTotal: "AUD 120",
      maxPostageCost: "AUD 15",
      requiredTrustLevel: "Trusted",
      allowedRegions: "Australia"
    )
    let quote = makeWishlistSellerQuote(
      item: item,
      sellerName: "Known Australian retailer",
      estimatedAUDTotal: "AUD 109 delivered",
      postageCost: "AUD 10",
      sellerRegion: "Australia",
      trustSummary: "Trusted seller with returns"
    )
    resetWishlistState(store)
    store.wishlistItems = [item]
    store.wishlistPriceWatchRules = [rule]
    store.wishlistSellerQuotes = [quote]

    store.evaluateWishlistPriceWatchRule(rule)

    let evaluatedRule = try XCTUnwrap(store.wishlistPriceWatchRules.first)
    let updatedItem = try XCTUnwrap(store.wishlistItems.first)

    XCTAssertEqual(evaluatedRule.ruleStatus, "Matched locally: Known Australian retailer")
    XCTAssertEqual(evaluatedRule.reviewState, .needsReview)
    XCTAssertNotEqual(evaluatedRule.lastEvaluatedDate, "Not evaluated")
    XCTAssertEqual(updatedItem.purchaseReadiness, "Price watch rule matched locally; review before purchase")
  }

  func testWishlistPriceWatchRuleMonitorsWhenSavedQuotesDoNotMatch() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    let rule = makeWishlistPriceWatchRule(
      item: item,
      targetAUDTotal: "AUD 100",
      maxPostageCost: "AUD 10",
      requiredTrustLevel: "Trusted",
      allowedRegions: "Australia"
    )
    let quote = makeWishlistSellerQuote(
      item: item,
      sellerName: "Known Australian retailer",
      estimatedAUDTotal: "AUD 149 delivered",
      postageCost: "AUD 18",
      sellerRegion: "Australia",
      trustSummary: "Trusted seller with returns"
    )
    resetWishlistState(store)
    store.wishlistItems = [item]
    store.wishlistPriceWatchRules = [rule]
    store.wishlistSellerQuotes = [quote]

    store.evaluateWishlistPriceWatchRule(rule)

    let evaluatedRule = try XCTUnwrap(store.wishlistPriceWatchRules.first)
    let updatedItem = try XCTUnwrap(store.wishlistItems.first)

    XCTAssertEqual(evaluatedRule.ruleStatus, "Watching locally; no match")
    XCTAssertEqual(evaluatedRule.reviewState, .monitor)
    XCTAssertEqual(updatedItem.purchaseReadiness, "Purchased externally; watch for confirmation")
  }

  func testWishlistPriceWatchRuleFlagsMissingLocalCandidates() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    let rule = makeWishlistPriceWatchRule(
      item: item,
      targetAUDTotal: "AUD 120",
      maxPostageCost: "AUD 15",
      requiredTrustLevel: "Trusted",
      allowedRegions: "Australia"
    )
    resetWishlistState(store)
    store.wishlistItems = [item]
    store.wishlistPriceWatchRules = [rule]
    store.wishlistSellerQuotes = []
    store.wishlistPriceSnapshots = []

    store.evaluateWishlistPriceWatchRule(rule)

    let evaluatedRule = try XCTUnwrap(store.wishlistPriceWatchRules.first)

    XCTAssertEqual(evaluatedRule.ruleStatus, "No local quotes or snapshots")
    XCTAssertEqual(evaluatedRule.reviewState, .needsReview)
    XCTAssertNotEqual(evaluatedRule.lastEvaluatedDate, "Not evaluated")
  }

  func testWishlistPurchaseDecisionUsesPreferredSellerOption() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let preferredOptionID = UUID()
    var item = makeReadyWishlistItem(
      optionID: preferredOptionID,
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    let alternateOption = WishlistComparisonOption(
      sellerName: "Unknown overseas seller",
      productURL: "https://example.net/replacement-scanner",
      listedPrice: "59.00",
      currency: "USD",
      estimatedAUDTotal: "AUD 145 delivered",
      postageCost: "AUD 40",
      postageTime: "14-21 business days",
      sellerRegion: "Overseas",
      trustRating: "Unknown",
      trustNotes: "No warranty evidence.",
      recommendation: "Backup only",
      lastChecked: "Today",
      localScore: 45,
      riskLevel: "High risk",
      decisionReason: "Higher risk and slower postage."
    )
    item.comparisonOptions?.append(alternateOption)
    item.purchaseDecision = nil
    resetWishlistState(store)
    store.wishlistItems = [item]

    store.createWishlistPurchaseDecision(item)

    let updatedItem = try XCTUnwrap(store.wishlistItems.first)
    let decision = try XCTUnwrap(updatedItem.purchaseDecision)

    XCTAssertEqual(decision.selectedOptionID, preferredOptionID)
    XCTAssertEqual(decision.selectedSellerName, "Known Australian retailer")
    XCTAssertEqual(decision.decisionStatus, "Draft decision")
    XCTAssertEqual(decision.reviewState, .needsReview)
    XCTAssertTrue(decision.rejectedOptionsSummary.contains("Unknown overseas seller"))
    XCTAssertEqual(updatedItem.status, "Purchase decision drafted")
    XCTAssertEqual(updatedItem.purchaseReadiness, "Decision needs review before purchase")
  }

  func testWishlistPurchaseDecisionReviewProgressesToManualHandoffReadiness() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    resetWishlistState(store)
    store.wishlistItems = [item]

    store.markWishlistPurchaseDecisionReviewed(item)

    let updatedItem = try XCTUnwrap(store.wishlistItems.first)
    let decision = try XCTUnwrap(updatedItem.purchaseDecision)

    XCTAssertEqual(decision.decisionStatus, "Decision reviewed")
    XCTAssertEqual(decision.reviewState, .accepted)
    XCTAssertEqual(updatedItem.status, "Purchase decision reviewed")
    XCTAssertEqual(updatedItem.purchaseReadiness, "Ready for manual purchase handoff")
  }

  func testWishlistPurchaseHandoffStagesSingleOrderWatchRecord() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    resetWishlistState(store)
    store.wishlistItems = [item]
    store.wishlistOrderWatchRecords = []

    store.prepareWishlistPurchaseHandoff(item)
    let preparedItem = try XCTUnwrap(store.wishlistItems.first)
    store.recordWishlistPurchasedExternally(preparedItem)
    let purchasedItem = try XCTUnwrap(store.wishlistItems.first)
    store.recordWishlistPurchasedExternally(purchasedItem)

    let updatedItem = try XCTUnwrap(store.wishlistItems.first)
    let watchRecord = try XCTUnwrap(store.wishlistOrderWatchRecords.first)

    XCTAssertEqual(store.wishlistOrderWatchRecords.count, 1)
    XCTAssertEqual(watchRecord.wishlistItemID, item.id)
    XCTAssertTrue(watchRecord.expectedOrderSignals.contains("Known Australian retailer"))
    XCTAssertTrue(watchRecord.expectedOrderSignals.contains("Replacement scanner"))
    XCTAssertEqual(updatedItem.status, "Awaiting order confirmation")
    XCTAssertEqual(updatedItem.purchaseReadiness, "Order watch rule refreshed locally")
    XCTAssertEqual(updatedItem.purchaseHandoff?.purchaseStatus, "Purchased externally, awaiting order confirmation")
  }

  func testWishlistPurchasePacketDraftCreatesLocalOperatorPacket() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    var item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    item.purchaseDecision = nil
    resetWishlistState(store)
    store.wishlistItems = [item]
    store.draftMessages = []

    store.createWishlistPurchasePacketDraft(item)

    let draft = try XCTUnwrap(store.draftMessages.first)
    let updatedItem = try XCTUnwrap(store.wishlistItems.first)

    XCTAssertEqual(draft.linkedEntityType, .wishlistItem)
    XCTAssertEqual(draft.linkedEntityID, item.id.uuidString)
    XCTAssertEqual(draft.subject, "Wishlist purchase packet: Replacement scanner")
    XCTAssertEqual(draft.recipient, "Wishlist review")
    XCTAssertEqual(draft.status, .draft)
    XCTAssertEqual(draft.reviewState, .needsReview)
    XCTAssertTrue(draft.body.contains("Manual purchase checklist"))
    XCTAssertTrue(draft.body.contains("Known Australian retailer"))
    XCTAssertTrue(draft.body.contains("ParcelOps did not open retailer pages"))
    XCTAssertNotNil(updatedItem.purchaseDecision)
  }

  func testWishlistPurchasePacketDraftReopensExistingPacketInsteadOfDuplicating() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    let existingDraft = DraftMessage(
      linkedEntityType: .wishlistItem,
      linkedEntityID: item.id.uuidString,
      templateID: nil,
      recipient: "Wishlist review",
      subject: "Wishlist purchase packet: Replacement scanner",
      body: "Existing packet body",
      channel: .email,
      createdDate: "Yesterday",
      status: .ready,
      reviewState: .accepted
    )
    resetWishlistState(store)
    store.wishlistItems = [item]
    store.draftMessages = [existingDraft]

    store.createWishlistPurchasePacketDraft(item)

    let draft = try XCTUnwrap(store.draftMessages.first)

    XCTAssertEqual(store.draftMessages.count, 1)
    XCTAssertEqual(draft.id, existingDraft.id)
    XCTAssertEqual(draft.status, .reopened)
    XCTAssertEqual(draft.reviewState, .needsReview)
    XCTAssertEqual(draft.body, "Existing packet body")
  }

  func testWishlistPurchaseDecisionReviewTaskRefreshesExistingOpenTask() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    var item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    item.purchaseDecision?.reviewState = .accepted
    let existingTask = ReviewTask(
      title: "Review Wishlist purchase decision: Old title",
      summary: "Old summary",
      linkedEntityType: .wishlistItem,
      linkedEntityID: item.id.uuidString,
      priority: .high,
      dueDate: "Yesterday",
      assignee: "Old owner",
      status: .open,
      createdDate: "Yesterday",
      completedDate: nil,
      reviewState: .accepted
    )
    resetWishlistState(store)
    store.wishlistItems = [item]
    store.reviewTasks = [existingTask]

    store.createWishlistPurchaseDecisionReviewTask(item)

    let refreshedTask = try XCTUnwrap(store.reviewTasks.first)

    XCTAssertEqual(store.reviewTasks.count, 1)
    XCTAssertEqual(refreshedTask.id, existingTask.id)
    XCTAssertEqual(refreshedTask.title, "Review Wishlist purchase decision: Replacement scanner")
    XCTAssertTrue(refreshedTask.summary.contains("Known Australian retailer"))
    XCTAssertEqual(refreshedTask.priority, .normal)
    XCTAssertEqual(refreshedTask.dueDate, "Today")
    XCTAssertEqual(refreshedTask.assignee, item.owner)
    XCTAssertEqual(refreshedTask.reviewState, .needsReview)
  }

  func testWishlistPurchaseHandoffReviewTaskReflectsOrderLinkState() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let unlinkedItem = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    let linkedItem = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Packing bench scale",
      sellerName: "Warehouse Supplies",
      linkedOrderID: UUID()
    )
    resetWishlistState(store)
    store.wishlistItems = [unlinkedItem, linkedItem]
    store.reviewTasks = []

    store.createWishlistPurchaseHandoffReviewTask(unlinkedItem)
    store.createWishlistPurchaseHandoffReviewTask(linkedItem)

    let unlinkedTask = try XCTUnwrap(store.reviewTasks.first { $0.linkedEntityID == unlinkedItem.id.uuidString })
    let linkedTask = try XCTUnwrap(store.reviewTasks.first { $0.linkedEntityID == linkedItem.id.uuidString })

    XCTAssertEqual(unlinkedTask.title, "Prepare Wishlist purchase handoff: Replacement scanner")
    XCTAssertEqual(unlinkedTask.priority, .high)
    XCTAssertEqual(unlinkedTask.reviewState, .accepted)
    XCTAssertTrue(unlinkedTask.summary.contains("Expected order signals"))
    XCTAssertEqual(linkedTask.priority, .normal)
    XCTAssertEqual(linkedTask.reviewState, .accepted)
    XCTAssertTrue(linkedTask.summary.contains("Warehouse Supplies"))
  }

  func testWishlistPurchaseHandoffReviewTaskRefreshesExistingOpenTask() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    let existingTask = ReviewTask(
      title: "Prepare Wishlist purchase handoff: Old title",
      summary: "Old handoff summary",
      linkedEntityType: .wishlistItem,
      linkedEntityID: item.id.uuidString,
      priority: .normal,
      dueDate: "Yesterday",
      assignee: "Old owner",
      status: .open,
      createdDate: "Yesterday",
      completedDate: nil,
      reviewState: .accepted
    )
    resetWishlistState(store)
    store.wishlistItems = [item]
    store.reviewTasks = [existingTask]

    store.createWishlistPurchaseHandoffReviewTask(item)

    let refreshedTask = try XCTUnwrap(store.reviewTasks.first)

    XCTAssertEqual(store.reviewTasks.count, 1)
    XCTAssertEqual(refreshedTask.id, existingTask.id)
    XCTAssertEqual(refreshedTask.title, "Prepare Wishlist purchase handoff: Replacement scanner")
    XCTAssertEqual(refreshedTask.priority, .high)
    XCTAssertEqual(refreshedTask.dueDate, "Today")
    XCTAssertEqual(refreshedTask.assignee, item.owner)
    XCTAssertTrue(refreshedTask.summary.contains("No purchase should be marked complete"))
  }

  func testWishlistPurchaseLinkRecordUsesPreferredOption() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    resetWishlistState(store)
    store.wishlistItems = [item]
    store.auditEvents = []

    store.addWishlistPurchaseLinkRecord(item)

    let record = try XCTUnwrap(store.wishlistPurchaseLinkRecords.first)

    XCTAssertEqual(store.wishlistPurchaseLinkRecords.count, 1)
    XCTAssertEqual(record.wishlistItemID, item.id)
    XCTAssertEqual(record.itemName, "Replacement scanner")
    XCTAssertEqual(record.sellerName, "Known Australian retailer")
    XCTAssertEqual(record.productURL, "https://example.com/replacement-scanner")
    XCTAssertEqual(record.linkType, "Preferred purchase link")
    XCTAssertEqual(record.estimatedAUDTotal, "AUD 109 delivered")
    XCTAssertEqual(record.postageSummary, "AUD 10, 3-5 business days")
    XCTAssertEqual(record.trustSummary, "Trusted")
    XCTAssertEqual(record.accountContext, "Operations account")
    XCTAssertTrue(record.selectedForPurchase)
    XCTAssertEqual(record.reviewState, .needsReview)
    XCTAssertTrue(store.auditEvents.contains { $0.summary == "Wishlist purchase link record added locally." })
  }

  func testWishlistPurchaseLinkSelectionKeepsOnlyOneSelected() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    let firstRecord = WishlistPurchaseLinkRecord(
      wishlistItemID: item.id,
      itemName: item.itemName,
      sellerName: "Known Australian retailer",
      productURL: "https://example.com/replacement-scanner",
      linkType: "Preferred purchase link",
      estimatedAUDTotal: "AUD 109 delivered",
      postageSummary: "AUD 10, 3-5 business days",
      trustSummary: "Trusted",
      readinessStatus: "Needs operator review",
      accountContext: "Operations account",
      selectedForPurchase: true,
      createdDate: "Today",
      lastCheckedDate: "Today",
      reviewState: .needsReview,
      notes: "Local test record."
    )
    let secondRecord = WishlistPurchaseLinkRecord(
      wishlistItemID: item.id,
      itemName: item.itemName,
      sellerName: "Backup retailer",
      productURL: "https://example.com/backup-scanner",
      linkType: "Candidate seller link",
      estimatedAUDTotal: "AUD 119 delivered",
      postageSummary: "AUD 12, 4-6 business days",
      trustSummary: "Trusted",
      readinessStatus: "Needs operator review",
      accountContext: "Operations account",
      selectedForPurchase: false,
      createdDate: "Today",
      lastCheckedDate: "Today",
      reviewState: .needsReview,
      notes: "Local test record."
    )
    resetWishlistState(store)
    store.wishlistItems = [item]
    store.wishlistPurchaseLinkRecords = [firstRecord, secondRecord]

    store.markWishlistPurchaseLinkSelected(secondRecord)

    let selected = try XCTUnwrap(store.wishlistPurchaseLinkRecords.first { $0.id == secondRecord.id })
    let deselected = try XCTUnwrap(store.wishlistPurchaseLinkRecords.first { $0.id == firstRecord.id })
    let refreshedItem = try XCTUnwrap(store.wishlistItems.first)

    XCTAssertTrue(selected.selectedForPurchase)
    XCTAssertEqual(selected.readinessStatus, "Selected for manual purchase review")
    XCTAssertEqual(selected.reviewState, .needsReview)
    XCTAssertFalse(deselected.selectedForPurchase)
    XCTAssertEqual(refreshedItem.purchaseReadiness, "Purchase link selected locally")
  }

  func testWishlistPurchaseLinkReadyAndBlockedUpdateItemReadiness() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    resetWishlistState(store)
    store.wishlistItems = [item]
    store.addWishlistPurchaseLinkRecord(item)
    var record = try XCTUnwrap(store.wishlistPurchaseLinkRecords.first)

    store.markWishlistPurchaseLinkReady(record)

    record = try XCTUnwrap(store.wishlistPurchaseLinkRecords.first)
    var refreshedItem = try XCTUnwrap(store.wishlistItems.first)
    XCTAssertEqual(record.readinessStatus, "Ready to open externally")
    XCTAssertEqual(record.reviewState, .accepted)
    XCTAssertEqual(refreshedItem.purchaseReadiness, "Purchase link ready for external manual buying")

    store.blockWishlistPurchaseLinkRecord(record)

    record = try XCTUnwrap(store.wishlistPurchaseLinkRecords.first)
    refreshedItem = try XCTUnwrap(store.wishlistItems.first)
    XCTAssertEqual(record.readinessStatus, "Blocked locally")
    XCTAssertEqual(record.reviewState, .needsReview)
    XCTAssertFalse(record.selectedForPurchase)
    XCTAssertEqual(refreshedItem.purchaseReadiness, "Blocked by purchase link review")
  }

  func testWishlistReopenClosedItemWithLinkedOrderRestoresFollowUpState() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    var item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: UUID()
    )
    item.status = "Closed locally"
    item.purchaseReadiness = "Wishlist operations closed locally"
    resetWishlistState(store)
    store.wishlistItems = [item]

    store.reopenClosedWishlistItem(item)

    let reopened = try XCTUnwrap(store.wishlistItems.first)

    XCTAssertEqual(reopened.status, "Order confirmation linked")
    XCTAssertEqual(reopened.purchaseReadiness, "Reopened locally after closure")
    XCTAssertEqual(reopened.purchaseHandoff?.purchaseStatus, "Reopened locally for follow-up")
    XCTAssertEqual(reopened.purchaseHandoff?.orderWatchStatus, "Reopened with linked local order")
  }

  func testWishlistReopenClosedItemWithoutLinkedOrderRestoresLinkingState() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    var item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    item.status = "Closed locally"
    item.purchaseReadiness = "Wishlist operations closed locally"
    resetWishlistState(store)
    store.wishlistItems = [item]

    store.reopenClosedWishlistItem(item)

    let reopened = try XCTUnwrap(store.wishlistItems.first)

    XCTAssertEqual(reopened.status, "Order confirmation needs linking")
    XCTAssertEqual(reopened.purchaseReadiness, "Reopened locally after closure")
    XCTAssertEqual(reopened.purchaseHandoff?.purchaseStatus, "Reopened locally for follow-up")
    XCTAssertEqual(reopened.purchaseHandoff?.orderWatchStatus, "Reopened; order link needs review")
  }

  func testWishlistInboxConfirmationCreatesAndLinksOrder() throws {
    let repository = InMemoryParcelOpsRepository()
    let store = ParcelOpsStore(repository: repository)
    let optionID = UUID()
    let item = makeReadyWishlistItem(
      optionID: optionID,
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    let intake = ForwardedEmailIntake(
      sender: "orders@known-retailer.example",
      subject: "Order TEST-123 shipped tracking ABC123",
      receivedDate: "Today",
      rawBodyPreview: "Known Australian retailer confirmed Replacement scanner order TEST-123 shipped with tracking ABC123.",
      detectedMerchant: "Known Australian retailer",
      detectedOrderNumber: "TEST-123",
      detectedTrackingNumber: "ABC123",
      detectedDestinationAddress: "Brisbane QLD",
      linkedOrderID: nil,
      reviewState: .needsReview
    )
    store.orders = []
    store.intakeEmails = [intake]
    store.wishlistItems = [item]
    store.reviewTasks = []
    store.auditEvents = []

    XCTAssertEqual(store.suggestedWishlistOrderConfirmations(for: item).map(\.id), [intake.id])

    store.confirmWishlistOrderFromIntake(item, email: intake)

    let createdOrder = try XCTUnwrap(store.orders.first)
    let updatedIntake = try XCTUnwrap(store.intakeEmails.first)
    let updatedItem = try XCTUnwrap(store.wishlistItems.first)
    XCTAssertEqual(createdOrder.orderNumber, "TEST-123")
    XCTAssertEqual(createdOrder.trackingNumber, "ABC123")
    XCTAssertEqual(updatedIntake.reviewState, .reviewed)
    XCTAssertEqual(updatedIntake.linkedOrderID, createdOrder.id)
    XCTAssertEqual(updatedItem.purchaseHandoff?.linkedOrderID, createdOrder.id)
    XCTAssertEqual(updatedItem.status, "Order confirmation linked")
    XCTAssertTrue(updatedItem.operatorPurchaseBlockers.isEmpty)
    XCTAssertEqual(store.activeWishlistItemsLinked(to: createdOrder).map(\.id), [item.id])
  }

  func testWishlistConversionCreatesLocalOrderDraftAndLinksHandoff() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    var item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    item.purchaseHandoff = nil
    resetWishlistState(store)
    store.orders = []
    store.wishlistItems = [item]
    store.auditEvents = []

    store.convertWishlistToOrder(item)

    let createdOrder = try XCTUnwrap(store.orders.first)
    let updatedItem = try XCTUnwrap(store.wishlistItems.first)

    XCTAssertTrue(createdOrder.orderNumber.hasPrefix("WISH-"))
    XCTAssertEqual(createdOrder.store, item.storefront)
    XCTAssertEqual(createdOrder.source, .manual)
    XCTAssertEqual(createdOrder.latestStatus, "Converted from wishlist and awaiting purchase confirmation")
    XCTAssertEqual(updatedItem.purchaseHandoff?.linkedOrderID, createdOrder.id)
    XCTAssertEqual(updatedItem.status, "Linked to order draft")
    XCTAssertEqual(updatedItem.purchaseReadiness, "Local order draft created from Wishlist")
    XCTAssertEqual(store.activeWishlistItemsLinked(to: createdOrder).map(\.id), [item.id])
    XCTAssertTrue(store.auditEvents.contains { $0.summary == "Order draft created from wishlist item." })
  }

  func testWishlistManualOrderLinkMatchesExistingOrder() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    let order = makeOrder(
      orderNumber: "ORDER-789",
      trackingNumber: "TRACK-789",
      destination: "Brisbane QLD",
      checkedMailbox: "caught@droctopus.net",
      source: .forwardedMailbox,
      latestStatus: "Known Australian retailer Replacement scanner order confirmation."
    )
    resetWishlistState(store)
    store.orders = [order]
    store.wishlistItems = [item]

    store.linkWishlistItemToOrder(item)

    let linkedItem = try XCTUnwrap(store.wishlistItems.first)

    XCTAssertEqual(linkedItem.purchaseHandoff?.linkedOrderID, order.id)
    XCTAssertEqual(linkedItem.purchaseHandoff?.purchaseStatus, "Linked to existing local order")
    XCTAssertEqual(linkedItem.status, "Linked to existing order")
    XCTAssertEqual(linkedItem.purchaseReadiness, "Existing local order linked")
    XCTAssertEqual(store.activeWishlistItemsLinked(to: order).map(\.id), [item.id])
  }

  func testWishlistManualOrderLinkWithoutMatchFlagsReview() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    var item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    item.purchaseHandoff = nil
    let unrelatedOrder = makeOrder(
      orderNumber: "ORDER-000",
      trackingNumber: "TRACK-000",
      destination: "Perth WA",
      checkedMailbox: "caught@droctopus.net",
      source: .forwardedMailbox,
      latestStatus: "Warehouse Supplies packing tape order."
    )
    resetWishlistState(store)
    store.orders = [unrelatedOrder]
    store.wishlistItems = [item]

    store.linkWishlistItemToOrder(item)

    let updatedItem = try XCTUnwrap(store.wishlistItems.first)

    XCTAssertNil(updatedItem.purchaseHandoff?.linkedOrderID)
    XCTAssertEqual(updatedItem.purchaseHandoff?.purchaseStatus, "Order link needs manual selection")
    XCTAssertEqual(updatedItem.status, "Order link needs review")
    XCTAssertEqual(updatedItem.purchaseReadiness, "Choose or create local order before downstream handoff")
    XCTAssertTrue(store.activeWishlistItemsLinked(to: unrelatedOrder).isEmpty)
  }

  func testWishlistPurchaseHandoffPersistsAcrossRepositoryReload() throws {
    let repository = InMemoryParcelOpsRepository()
    let store = ParcelOpsStore(repository: repository)
    let linkedOrderID = UUID()
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: linkedOrderID
    )
    resetWishlistState(store)
    store.wishlistItems = [item]

    store.addWishlistPurchaseLinkRecord(item)
    let link = try XCTUnwrap(store.wishlistPurchaseLinkRecords.first)
    store.markWishlistPurchaseLinkReady(link)
    store.addWishlistOrderWatchRecord(item)

    let reloadedStore = ParcelOpsStore(repository: repository)
    let reloadedItem = try XCTUnwrap(reloadedStore.wishlistItems.first { $0.id == item.id })
    let reloadedLink = try XCTUnwrap(reloadedStore.wishlistPurchaseLinkRecords.first { $0.wishlistItemID == item.id })
    let reloadedWatch = try XCTUnwrap(reloadedStore.wishlistOrderWatchRecords.first { $0.wishlistItemID == item.id })

    XCTAssertEqual(reloadedItem.purchaseHandoff?.linkedOrderID, linkedOrderID)
    XCTAssertEqual(reloadedItem.purchaseHandoff?.sellerName, "Known Australian retailer")
    XCTAssertEqual(reloadedLink.productURL, item.storefrontURL)
    XCTAssertEqual(reloadedLink.readinessStatus, "Ready to open externally")
    XCTAssertEqual(reloadedLink.reviewState, .accepted)
    XCTAssertEqual(reloadedWatch.linkedOrderID, linkedOrderID)
    XCTAssertEqual(reloadedWatch.watchStatus, "Linked to local order")
    XCTAssertEqual(reloadedWatch.expectedMailboxOrSource, "Inbox triage after manual mailbox refresh")
  }

  func testWishlistPurchaseHandoffModelsRoundTripJSON() throws {
    let linkedOrderID = UUID()
    let optionID = UUID()
    let item = makeReadyWishlistItem(
      optionID: optionID,
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: linkedOrderID
    )
    let link = WishlistPurchaseLinkRecord(
      wishlistItemID: item.id,
      itemName: item.itemName,
      sellerName: "Known Australian retailer",
      productURL: "https://example.com/replacement-scanner",
      linkType: "Preferred purchase link",
      estimatedAUDTotal: "AUD 109 delivered",
      postageSummary: "AUD 10, 3-5 business days",
      trustSummary: "Trusted",
      readinessStatus: "Ready to open externally",
      accountContext: "Operations account",
      selectedForPurchase: true,
      createdDate: "Today",
      lastCheckedDate: "Today",
      reviewState: .accepted,
      notes: "Local link only."
    )
    let watch = WishlistOrderWatchRecord(
      wishlistItemID: item.id,
      linkedOrderID: linkedOrderID,
      itemName: item.itemName,
      sellerName: "Known Australian retailer",
      accountLabel: "Operations account",
      expectedOrderSignals: "Known Australian retailer | Replacement scanner | shipped | tracking",
      expectedMailboxOrSource: "Inbox triage after manual mailbox refresh",
      watchStatus: "Linked to local order",
      matchedOrderSummary: "TEST-123",
      nextCheckSummary: "Review linked order and dispatch handoff.",
      createdDate: "Today",
      lastCheckedDate: "Today",
      reviewState: .accepted,
      notes: "Local watch only."
    )

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let decodedItem = try decoder.decode(WishlistItem.self, from: encoder.encode(item))
    let decodedLink = try decoder.decode(WishlistPurchaseLinkRecord.self, from: encoder.encode(link))
    let decodedWatch = try decoder.decode(WishlistOrderWatchRecord.self, from: encoder.encode(watch))

    XCTAssertEqual(decodedItem.id, item.id)
    XCTAssertEqual(decodedItem.preferredOptionID, optionID)
    XCTAssertEqual(decodedItem.purchaseHandoff?.linkedOrderID, linkedOrderID)
    XCTAssertEqual(decodedItem.purchaseDecision?.reviewState, .accepted)
    XCTAssertEqual(decodedItem.comparisonOptions?.first?.sellerName, "Known Australian retailer")
    XCTAssertEqual(decodedLink.wishlistItemID, item.id)
    XCTAssertTrue(decodedLink.selectedForPurchase)
    XCTAssertEqual(decodedLink.reviewState, .accepted)
    XCTAssertEqual(decodedWatch.wishlistItemID, item.id)
    XCTAssertEqual(decodedWatch.linkedOrderID, linkedOrderID)
    XCTAssertEqual(decodedWatch.reviewState, .accepted)
  }

  func testSpaceMailConnectionDecodesOldJSONDefaults() throws {
    let json = """
    {
      "displayName": "SpaceMail tracking inbox",
      "emailAddressUsername": "caught@example.test",
      "imapHost": "mail.spacemail.com",
      "imapPort": "993",
      "securityMode": "SSL/TLS",
      "folderName": "INBOX",
      "connectionStatus": "Ready for IMAP",
      "lastManualRefreshDate": "Never",
      "setupNotes": "Local setup notes only",
      "credentialStorageStatus": "Password not stored",
      "reviewState": "Needs review"
    }
    """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(SpaceMailIMAPConnection.self, from: json)

    XCTAssertEqual(decoded.mailboxMode, .mixedFiltered)
    XCTAssertEqual(decoded.lastRefreshSummary, "No refresh has run yet.")
    XCTAssertTrue(decoded.uncertainMessages.isEmpty)
    XCTAssertTrue(decoded.filteredMessages.isEmpty)
    XCTAssertTrue(decoded.refreshHistory.isEmpty)
  }

  func testGmailConnectionDecodesOldJSONDefaults() throws {
    let json = """
    {
      "displayName": "Gmail tracking inbox",
      "emailAddress": "orders@example.test",
      "monitoredLabelNames": "INBOX, Orders",
      "connectionStatus": "Placeholder configured",
      "lastManualRefreshDate": "Never",
      "setupNotes": "Local setup notes only",
      "reviewState": "Needs review"
    }
    """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(GmailMailboxConnection.self, from: json)

    XCTAssertEqual(decoded.mailboxMode, .mixedFiltered)
    XCTAssertEqual(decoded.oauthReadinessStatus, "Needs review")
    XCTAssertEqual(decoded.requestedScopesSummary, "openid email profile https://www.googleapis.com/auth/gmail.readonly")
    XCTAssertEqual(decoded.credentialStorageStatus, "GoogleSignIn cache pending")
    XCTAssertEqual(decoded.lastRefreshFetchedCount, 0)
    XCTAssertEqual(decoded.lastRefreshImportedCount, 0)
    XCTAssertEqual(decoded.lastRefreshDuplicateCount, 0)
    XCTAssertEqual(decoded.lastRefreshFilteredNonOrderCount, 0)
    XCTAssertNil(decoded.lastRefreshUncertainCount)
    XCTAssertEqual(decoded.lastRefreshSummary, "No Gmail refresh has run yet.")
    XCTAssertNil(decoded.uncertainMessages)
    XCTAssertNil(decoded.filteredMessages)
    XCTAssertNil(decoded.refreshHistory)
  }

  func testGmailConnectionPreservesRefreshMetadata() throws {
    let messageID = UUID()
    let historyID = UUID()
    let json = """
    {
      "displayName": "Gmail tracking inbox",
      "emailAddress": "orders@example.test",
      "monitoredLabelNames": "INBOX, Orders",
      "connectionStatus": "Real Gmail: Fetch success",
      "lastManualRefreshDate": "Today",
      "setupNotes": "Local setup notes only",
      "oauthReadinessStatus": "Ready",
      "requestedScopesSummary": "openid email profile https://www.googleapis.com/auth/gmail.readonly",
      "credentialStorageStatus": "GoogleSignIn cache available",
      "mailboxMode": "Mixed mailbox, filter likely order emails only",
      "lastRefreshFetchedCount": 10,
      "lastRefreshImportedCount": 2,
      "lastRefreshDuplicateCount": 3,
      "lastRefreshFilteredNonOrderCount": 4,
      "lastRefreshUncertainCount": 1,
      "lastRefreshSummary": "2 imported, 4 filtered, 1 uncertain",
      "lastRefreshFilteredExamples": ["Newsletter"],
      "lastRefreshUncertainExamples": ["Delivery question"],
      "uncertainMessages": [
        {
          "id": "\(messageID.uuidString)",
          "providerMessageID": "gmail-msg-1",
          "sourceMailboxID": "\(UUID().uuidString)",
          "sender": "sender@example.test",
          "subject": "Delivery question",
          "receivedDate": "Today",
          "bodyPreview": "Can you check whether this relates to an order?",
          "reason": "delivery-ish no id",
          "capturedDate": "Today"
        }
      ],
      "refreshHistory": [
        {
          "id": "\(historyID.uuidString)",
          "timestamp": "Today",
          "eventType": "Real refresh",
          "status": "Fetch success",
          "fetchedCount": 10,
          "importedCount": 2,
          "duplicateCount": 3,
          "filteredNonOrderCount": 4,
          "uncertainCount": 1,
          "summary": "Manual Gmail refresh completed."
        }
      ],
      "reviewState": "Needs review"
    }
    """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(GmailMailboxConnection.self, from: json)

    XCTAssertEqual(decoded.mailboxMode, .mixedFiltered)
    XCTAssertEqual(decoded.lastRefreshFetchedCount, 10)
    XCTAssertEqual(decoded.lastRefreshImportedCount, 2)
    XCTAssertEqual(decoded.lastRefreshDuplicateCount, 3)
    XCTAssertEqual(decoded.lastRefreshFilteredNonOrderCount, 4)
    XCTAssertEqual(decoded.lastRefreshUncertainCount, 1)
    XCTAssertEqual(decoded.lastRefreshSummary, "2 imported, 4 filtered, 1 uncertain")
    XCTAssertEqual(decoded.lastRefreshFilteredExamples, ["Newsletter"])
    XCTAssertEqual(decoded.lastRefreshUncertainExamples, ["Delivery question"])
    XCTAssertEqual(decoded.uncertainMessages?.first?.subject, "Delivery question")
    XCTAssertEqual(decoded.uncertainMessages?.first?.reason, "delivery-ish no id")
    XCTAssertEqual(decoded.refreshHistory?.first?.uncertainCount, 1)
  }

  func testGmailConnectionPersistsAcrossRepositoryReload() throws {
    let repository = InMemoryParcelOpsRepository()
    let mailboxID = UUID()
    let uncertain = GmailReviewMessage(
      providerMessageID: "gmail-ambiguous-1",
      sourceMailboxID: mailboxID,
      sender: "person@example.test",
      subject: "Delivery question",
      receivedDate: "Today",
      bodyPreview: "Can you check whether this relates to an order?",
      reason: "order-ish no tracking id",
      capturedDate: "Today"
    )
    let connection = GmailMailboxConnection(
      id: mailboxID,
      displayName: "Gmail tracking inbox",
      emailAddress: "orders@example.test",
      monitoredLabelNames: "INBOX, Orders",
      connectionStatus: "Real Gmail: Fetch success",
      lastManualRefreshDate: "Today",
      setupNotes: "Local Gmail setup.",
      oauthReadinessStatus: "Ready",
      googleCloudProjectHint: "ParcelOps Gmail intake",
      oauthClientIDPlaceholder: "client-id-placeholder",
      redirectURIPlaceholder: "app.bitrig.parcelops:/oauth2redirect/google",
      requestedScopesSummary: "openid email profile https://www.googleapis.com/auth/gmail.readonly",
      consentScreenNotes: "Internal testing only.",
      credentialStorageStatus: "GoogleSignIn cache available",
      mailboxMode: .mixedFiltered,
      lastRefreshFetchedCount: 10,
      lastRefreshImportedCount: 2,
      lastRefreshDuplicateCount: 1,
      lastRefreshFilteredNonOrderCount: 6,
      lastRefreshUncertainCount: 1,
      lastRefreshSummary: "2 imported, 6 filtered, 1 uncertain",
      lastRefreshFilteredExamples: ["Newsletter"],
      lastRefreshUncertainExamples: ["Delivery question"],
      lastRefreshReasonBreakdown: [
        SpaceMailClassifierReasonCount(decision: "Imported", reason: "strong order evidence", count: 2),
        SpaceMailClassifierReasonCount(decision: "Filtered", reason: "filtered marketing", count: 6)
      ],
      uncertainMessages: [uncertain],
      filteredMessages: [],
      refreshHistory: [
        GmailRefreshHistoryEntry(
          timestamp: "Today",
          eventType: "Real refresh",
          status: "Fetch success",
          fetchedCount: 10,
          importedCount: 2,
          duplicateCount: 1,
          filteredNonOrderCount: 6,
          uncertainCount: 1,
          summary: "Manual Gmail refresh completed."
        )
      ],
      reviewState: .accepted
    )

    repository.saveGmailMailboxConnections([connection])

    let reloadedStore = ParcelOpsStore(repository: repository)
    let reloaded = try XCTUnwrap(reloadedStore.gmailMailboxConnections.first { $0.id == mailboxID })

    XCTAssertEqual(reloaded.emailAddress, "orders@example.test")
    XCTAssertEqual(reloaded.oauthReadinessStatus, "Ready")
    XCTAssertEqual(reloaded.credentialStorageStatus, "GoogleSignIn cache available")
    XCTAssertEqual(reloaded.lastRefreshFetchedCount, 10)
    XCTAssertEqual(reloaded.lastRefreshImportedCount, 2)
    XCTAssertEqual(reloaded.lastRefreshFilteredNonOrderCount, 6)
    XCTAssertEqual(reloaded.lastRefreshUncertainCount, 1)
    XCTAssertEqual(reloaded.uncertainMessages?.first?.subject, "Delivery question")
    XCTAssertEqual(reloaded.refreshHistory?.first?.summary, "Manual Gmail refresh completed.")
    XCTAssertEqual(reloaded.lastRefreshReasonBreakdown?.first?.reason, "strong order evidence")
  }

  func testGmailPreviewTaskRefreshesExistingOpenProviderMessageTask() {
    let mailboxID = UUID()
    let message = GmailReviewMessage(
      providerMessageID: "gmail-preview-task-1",
      sourceMailboxID: mailboxID,
      sender: "person@example.test",
      subject: "Delivery question",
      receivedDate: "Today",
      bodyPreview: "Can you check whether this relates to an order?",
      reason: "order-ish no tracking id",
      capturedDate: "Today"
    )
    let connection = makeGmailConnection(
      id: mailboxID,
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 10,
      imported: 0,
      filtered: 9,
      uncertain: 1
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = [connection]
    store.reviewTasks = []
    store.auditEvents = []

    store.createReviewTask(from: message, connection: connection, reviewQueue: "uncertain")
    store.createReviewTask(from: message, connection: connection, reviewQueue: "uncertain")

    let tasks = store.reviewTasks.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == mailboxID.uuidString
        && $0.summary.contains(message.providerMessageID)
    }
    XCTAssertEqual(tasks.count, 1)
    XCTAssertEqual(tasks.first?.assignee, "Mailbox team")
    XCTAssertEqual(tasks.first?.priority, .normal)
    XCTAssertEqual(tasks.first?.reviewState, .needsReview)
    XCTAssertTrue(tasks.first?.summary.contains("Review uncertain Gmail preview") == true)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Existing Gmail preview review task refreshed."
        && (event.afterDetail?.contains("No duplicate task was created.") ?? false)
    })
  }

  func testGmailPreviewTaskCreatesNewTaskAfterCompletedTask() {
    let mailboxID = UUID()
    let message = GmailReviewMessage(
      providerMessageID: "gmail-preview-task-completed",
      sourceMailboxID: mailboxID,
      sender: "offers@example.test",
      subject: "Possible order update",
      receivedDate: "Today",
      bodyPreview: "This may relate to an order.",
      reason: "filtered review requested",
      capturedDate: "Today"
    )
    let connection = makeGmailConnection(
      id: mailboxID,
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 10,
      imported: 0,
      filtered: 10,
      uncertain: 0
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = [connection]
    store.reviewTasks = []
    store.auditEvents = []

    store.createReviewTask(from: message, connection: connection, reviewQueue: "filtered")
    guard let firstTask = store.reviewTasks.first else {
      XCTFail("Expected Gmail preview task.")
      return
    }
    store.completeReviewTask(firstTask)
    store.createReviewTask(from: message, connection: connection, reviewQueue: "filtered")

    let tasks = store.reviewTasks.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == mailboxID.uuidString
        && $0.summary.contains(message.providerMessageID)
    }
    XCTAssertEqual(tasks.count, 2)
    XCTAssertEqual(tasks.filter { $0.status == .completed }.count, 1)
    XCTAssertEqual(tasks.filter { $0.status == .open }.count, 1)
    XCTAssertEqual(tasks.filter { $0.priority == .low }.count, 2)
    XCTAssertTrue(store.auditEvents.contains { $0.summary == "Review task completed." })
    XCTAssertTrue(store.auditEvents.contains { $0.summary == "Review task created from filtered Gmail preview." })
  }

  func testGmailPreviewDraftRefreshesExistingUnsentProviderMessageDraft() {
    let mailboxID = UUID()
    let message = GmailReviewMessage(
      providerMessageID: "gmail-preview-draft-1",
      sourceMailboxID: mailboxID,
      sender: "person@example.test",
      subject: "Delivery question",
      receivedDate: "Today",
      bodyPreview: "Can you check whether this relates to an order?",
      reason: "order-ish no tracking id",
      capturedDate: "Today"
    )
    let connection = makeGmailConnection(
      id: mailboxID,
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 10,
      imported: 0,
      filtered: 9,
      uncertain: 1
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = [connection]
    store.draftMessages = []
    store.auditEvents = []

    store.createDraftMessage(from: message, connection: connection, reviewQueue: "uncertain")
    store.draftMessages[0].status = .ready
    store.createDraftMessage(from: message, connection: connection, reviewQueue: "uncertain")

    let drafts = store.draftMessages.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == mailboxID.uuidString
        && $0.body.contains(message.providerMessageID)
    }
    XCTAssertEqual(drafts.count, 1)
    XCTAssertEqual(drafts.first?.recipient, "person@example.test")
    XCTAssertEqual(drafts.first?.status, .reopened)
    XCTAssertTrue(drafts.first?.body.contains("Gmail preview: uncertain") == true)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Existing Gmail preview draft refreshed."
        && (event.afterDetail?.contains("No duplicate draft was created.") ?? false)
    })
  }

  func testGmailPreviewDraftCreatesNewDraftAfterSentLocally() {
    let mailboxID = UUID()
    let message = GmailReviewMessage(
      providerMessageID: "gmail-filtered-draft-sent",
      sourceMailboxID: mailboxID,
      sender: "offers@example.test",
      subject: "Final days",
      receivedDate: "Today",
      bodyPreview: "Marketing promotion that was filtered from mixed mailbox intake.",
      reason: "marketing",
      capturedDate: "Today"
    )
    let connection = makeGmailConnection(
      id: mailboxID,
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 10,
      imported: 0,
      filtered: 10,
      uncertain: 0
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = [connection]
    store.draftMessages = []
    store.auditEvents = []

    store.createDraftMessage(from: message, connection: connection, reviewQueue: "filtered")
    store.draftMessages[0].status = .sentLocally
    store.createDraftMessage(from: message, connection: connection, reviewQueue: "filtered")

    let drafts = store.draftMessages.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == mailboxID.uuidString
        && $0.body.contains(message.providerMessageID)
    }
    XCTAssertEqual(drafts.count, 2)
    XCTAssertEqual(drafts.filter { $0.status == .sentLocally }.count, 1)
    XCTAssertEqual(drafts.filter { $0.status == .draft }.count, 1)
    XCTAssertTrue(drafts.allSatisfy { $0.body.contains("Gmail preview: filtered") })
    XCTAssertEqual(store.auditEvents.filter { $0.summary == "Draft message created from filtered Gmail preview." }.count, 2)
  }

  func testGmailPostRefreshActionPlanHandlesNoProvider() {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = []
    store.gmailAuthSessionStates = [:]

    let plan = store.gmailPostRefreshActionPlan

    XCTAssertEqual(plan.title, "Gmail post-refresh actions unavailable")
    XCTAssertEqual(plan.tone, "neutral")
    XCTAssertEqual(plan.primaryAction, "Add Gmail setup")
    XCTAssertEqual(plan.items.first { $0.title == "Finish setup and sign-in" }?.tone, "warning")
  }

  func testGmailPostRefreshActionPlanPrioritizesSetupBlockers() {
    let connection = makeGmailConnection(
      oauthReadinessStatus: "Needs review",
      credentialStorageStatus: "GoogleSignIn cache pending",
      fetched: 10,
      imported: 0,
      filtered: 10,
      uncertain: 0
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = [connection]
    store.gmailAuthSessionStates = [
      connection.id: GmailAuthSessionState(
        connectionID: connection.id,
        status: .notConnected,
        signedInAccount: "Not signed in",
        lastAuthAttemptDate: "Never",
        lastSuccessfulAuthDate: "Never",
        tokenStoreStatus: "GoogleSignIn cache pending",
        tokenStoreDetail: "No token values stored in JSON.",
        detailText: "Test setup is intentionally blocked."
      )
    ]
    store.mailboxIngestRecords = []
    store.intakeEmails = []

    let plan = store.gmailPostRefreshActionPlan
    let setupItem = plan.items.first { $0.title == "Finish setup and sign-in" }

    XCTAssertEqual(plan.title, "Gmail setup blockers need review")
    XCTAssertEqual(plan.tone, "warning")
    XCTAssertEqual(plan.primaryAction, "Review Gmail setup")
    XCTAssertEqual(setupItem?.tone, "warning")
    XCTAssertEqual(setupItem?.actionLabel, "Review Gmail setup")
  }

  func testGmailHealthSummaryFlagsSetupBlockers() {
    let connection = makeGmailConnection(
      oauthReadinessStatus: "Needs review",
      credentialStorageStatus: "GoogleSignIn cache pending",
      fetched: 0,
      imported: 0,
      filtered: 0,
      uncertain: nil
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = [connection]
    store.gmailAuthSessionStates = [:]
    store.mailboxIngestRecords = []
    store.intakeEmails = []

    let summary = store.gmailIntakeHealthSummary(for: connection)

    XCTAssertEqual(summary.verdict, "Gmail setup blocked")
    XCTAssertEqual(summary.tone, "warning")
    XCTAssertEqual(summary.fetchedCount, 0)
    XCTAssertEqual(summary.importedCount, 0)
    XCTAssertEqual(summary.nextAction, "Open Mailbox Monitor or Settings, fix the Gmail setup blockers, then run Check readiness before sign-in.")
  }

  func testGmailHealthSummaryPreservesDuplicateRefreshCounts() {
    let mailboxID = UUID()
    let intake = ForwardedEmailIntake(
      sender: "orders@example.test",
      subject: "Order TEST-123 shipped",
      receivedDate: "Today",
      rawBodyPreview: "Order TEST-123 shipped tracking ABC123",
      detectedMerchant: "Example Store",
      detectedOrderNumber: "TEST-123",
      detectedTrackingNumber: "ABC123",
      detectedDestinationAddress: "Destination needs review",
      linkedOrderID: nil,
      reviewState: .needsReview
    )
    let connection = makeGmailConnection(
      id: mailboxID,
      oauthReadinessStatus: "Needs review",
      credentialStorageStatus: "GoogleSignIn cache pending",
      fetched: 10,
      imported: 1,
      filtered: 7,
      uncertain: 0
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = [connection]
    store.gmailAuthSessionStates = [:]
    store.intakeEmails = [intake]
    store.mailboxIngestRecords = [
      MailboxIngestRecord(
        providerMessageID: "gmail-updated-1",
        sourceMailboxID: mailboxID,
        intakeEmailID: intake.id,
        capturedDate: "Today",
        status: .duplicateRefreshed,
        summary: "Duplicate refreshed existing Gmail intake"
      ),
      MailboxIngestRecord(
        providerMessageID: "gmail-no-change-1",
        sourceMailboxID: mailboxID,
        intakeEmailID: intake.id,
        capturedDate: "Today",
        status: .duplicateNoChange,
        summary: "Duplicate did not change Gmail intake"
      )
    ]

    let summary = store.gmailIntakeHealthSummary(for: connection)

    XCTAssertEqual(summary.verdict, "Gmail setup blocked")
    XCTAssertEqual(summary.fetchedCount, 10)
    XCTAssertEqual(summary.importedCount, 1)
    XCTAssertEqual(summary.filteredCount, 7)
    XCTAssertEqual(summary.linkedIntakeCount, 1)
    XCTAssertEqual(summary.duplicateRefreshedCount, 1)
    XCTAssertEqual(summary.duplicateNoChangeCount, 1)
  }

  func testGmailConnectedRefreshStillSurfacesCompiledSetupBlockers() {
    let mailboxID = UUID()
    let connection = makeGmailConnection(
      id: mailboxID,
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 10,
      imported: 1,
      filtered: 8,
      uncertain: 1
    )
    let uncertain = GmailReviewMessage(
      providerMessageID: "gmail-ambiguous-1",
      sourceMailboxID: mailboxID,
      sender: "person@example.test",
      subject: "Delivery question",
      receivedDate: "Today",
      bodyPreview: "Can you check whether this relates to an order?",
      reason: "order-ish no tracking id",
      capturedDate: "Today"
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    var refreshedConnection = connection
    refreshedConnection.connectionStatus = "Real Gmail: Fetch success"
    refreshedConnection.lastManualRefreshDate = "Today"
    refreshedConnection.lastRefreshSummary = "1 imported, 8 filtered, 1 uncertain"
    refreshedConnection.uncertainMessages = [uncertain]
    store.gmailMailboxConnections = [refreshedConnection]
    store.gmailAuthSessionStates = [
      mailboxID: GmailAuthSessionState(
        connectionID: mailboxID,
        status: .connected,
        signedInAccount: "orders@example.test",
        lastAuthAttemptDate: "Today",
        lastSuccessfulAuthDate: "Today",
        tokenStoreStatus: "GoogleSignIn cache available",
        tokenStoreDetail: "No token values stored in JSON.",
        detailText: "Identity sign-in available for manual read-only refresh."
      )
    ]
    store.mailboxIngestRecords = []
    store.intakeEmails = []

    let health = store.gmailIntakeHealthSummary(for: refreshedConnection)
    let plan = store.gmailPostRefreshActionPlan

    XCTAssertEqual(health.verdict, "Gmail setup blocked")
    XCTAssertEqual(health.tone, "warning")
    XCTAssertEqual(health.pendingUncertainReviewCount, 1)
    XCTAssertEqual(health.importedCount, 1)
    XCTAssertEqual(plan.title, "Gmail setup blockers need review")
    XCTAssertEqual(plan.primaryAction, "Review Gmail setup")
    XCTAssertEqual(plan.items.first { $0.title == "Finish setup and sign-in" }?.tone, "warning")
    XCTAssertEqual(plan.items.first { $0.title == "Review uncertain messages" }?.count, 1)
  }

  func testGmailLabelReadinessDefaultsMissingLabelsToSetupWarning() {
    var connection = makeGmailConnection(
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 0,
      imported: 0,
      filtered: 0,
      uncertain: nil
    )
    connection.monitoredLabelNames = "   "
    let store = ParcelOpsStore()

    let summary = store.gmailLabelReadinessSummary(for: connection)

    XCTAssertEqual(summary.status, "Label missing")
    XCTAssertEqual(summary.primaryLabel, "INBOX")
    XCTAssertEqual(summary.labelCount, 0)
    XCTAssertEqual(summary.refreshMode, "Default would be INBOX")
    XCTAssertEqual(summary.tone, "warning")
    XCTAssertEqual(summary.nextAction, "Edit setup and add the exact Gmail label to check.")
  }

  func testGmailLabelReadinessTreatsInboxAsSystemLabel() {
    var connection = makeGmailConnection(
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 0,
      imported: 0,
      filtered: 0,
      uncertain: nil
    )
    connection.monitoredLabelNames = " inbox "
    let store = ParcelOpsStore()

    let summary = store.gmailLabelReadinessSummary(for: connection)

    XCTAssertEqual(summary.status, "Label ready")
    XCTAssertEqual(summary.primaryLabel, "inbox")
    XCTAssertEqual(summary.labelCount, 1)
    XCTAssertEqual(summary.refreshMode, "System label INBOX")
    XCTAssertEqual(summary.tone, "success")
    XCTAssertTrue(summary.detail.contains("read-only message list request"))
  }

  func testGmailLabelReadinessWarnsWhenMultipleLabelsAreConfigured() {
    var connection = makeGmailConnection(
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 0,
      imported: 0,
      filtered: 0,
      uncertain: nil
    )
    connection.monitoredLabelNames = "Order Updates, INBOX"
    let store = ParcelOpsStore()

    let summary = store.gmailLabelReadinessSummary(for: connection)

    XCTAssertEqual(summary.status, "Primary label selected")
    XCTAssertEqual(summary.primaryLabel, "Order Updates")
    XCTAssertEqual(summary.labelCount, 2)
    XCTAssertEqual(summary.refreshMode, "Custom label search")
    XCTAssertEqual(summary.tone, "attention")
    XCTAssertEqual(summary.nextAction, "Put the label you want fetched first, or run separate setup records for separate labels.")
  }

  func testMailboxProviderComparisonRequiresAProviderWhenNoneConfigured() {
    let store = ParcelOpsStore()
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = []
    store.gmailAuthSessionStates = [:]

    let summary = store.mailboxProviderComparisonSummary

    XCTAssertEqual(summary.title, "Choose a mailbox provider")
    XCTAssertEqual(summary.recommendedProvider, "Add provider")
    XCTAssertEqual(summary.tone, "warning")
    XCTAssertEqual(summary.providers.count, 2)
    XCTAssertTrue(summary.actionItems.contains { $0.title == "Choose SpaceMail or Gmail" })
    XCTAssertEqual(summary.metrics.first { $0.title == "Providers" }?.value, "0")
    XCTAssertEqual(summary.metrics.first { $0.title == "Blockers" }?.value, "1")
  }

  func testMailboxProviderComparisonTreatsQuietSpaceMailRefreshAsReady() {
    let store = ParcelOpsStore()
    store.spaceMailIMAPConnections = [
      makeSpaceMailConnection(
        credentialStorageStatus: "Password reference available",
        fetched: 10,
        imported: 0,
        filtered: 8,
        uncertain: 0
      )
    ]
    store.gmailMailboxConnections = []
    store.gmailAuthSessionStates = [:]

    let summary = store.mailboxProviderComparisonSummary
    let spaceMail = summary.providers.first { $0.providerName == "SpaceMail" }

    XCTAssertEqual(summary.title, "Mailbox intake is quiet")
    XCTAssertEqual(summary.recommendedProvider, "SpaceMail")
    XCTAssertEqual(summary.tone, "success")
    XCTAssertEqual(spaceMail?.statusTitle, "SpaceMail filtering is active")
    XCTAssertEqual(spaceMail?.fetchedCount, 10)
    XCTAssertEqual(spaceMail?.blockedCount, 0)
    XCTAssertTrue(summary.actionItems.contains { $0.providerName == "SpaceMail" && $0.title == "Monitor SpaceMail refreshes" })
    XCTAssertEqual(summary.metrics.first { $0.title == "Filtered" }?.value, "8")
    XCTAssertEqual(summary.metrics.first { $0.title == "Blockers" }?.value, "0")
  }

  func testMailboxProviderComparisonFlagsGmailSetupBlockers() {
    let store = ParcelOpsStore()
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = [
      makeGmailConnection(
        oauthReadinessStatus: "Needs review",
        credentialStorageStatus: "GoogleSignIn cache pending",
        fetched: 0,
        imported: 0,
        filtered: 0,
        uncertain: nil
      )
    ]
    store.gmailAuthSessionStates = [:]

    let summary = store.mailboxProviderComparisonSummary
    let gmail = summary.providers.first { $0.providerName == "Gmail" }

    XCTAssertEqual(summary.title, "Mailbox setup has blockers")
    XCTAssertEqual(summary.recommendedProvider, "Gmail")
    XCTAssertEqual(summary.tone, "warning")
    XCTAssertEqual(gmail?.statusTitle, "Gmail setup or sign-in blocked")
    XCTAssertEqual(gmail?.blockedCount, 2)
    XCTAssertTrue(summary.actionItems.contains { $0.providerName == "Gmail" && $0.title == "Finish Gmail setup" })
    XCTAssertEqual(summary.metrics.first { $0.title == "Providers" }?.value, "1")
    XCTAssertEqual(summary.metrics.first { $0.title == "Blockers" }?.value, "3")
  }

  func testMailboxProviderComparisonKeepsGmailSetupBlockedEvenWithQuietRefreshEvidence() {
    let mailboxID = UUID()
    let connection = makeGmailConnection(
      id: mailboxID,
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 10,
      imported: 0,
      filtered: 10,
      uncertain: 0
    )
    let store = ParcelOpsStore()
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = [connection]
    store.gmailAuthSessionStates = [
      mailboxID: GmailAuthSessionState(
        connectionID: mailboxID,
        status: .connected,
        signedInAccount: "orders@example.test",
        lastAuthAttemptDate: "Today",
        lastSuccessfulAuthDate: "Today",
        tokenStoreStatus: "GoogleSignIn cache available",
        tokenStoreDetail: "No token values stored in JSON.",
        detailText: "Identity sign-in available."
      )
    ]

    let summary = store.mailboxProviderComparisonSummary
    let gmail = summary.providers.first { $0.providerName == "Gmail" }

    XCTAssertEqual(summary.title, "Mailbox setup has blockers")
    XCTAssertEqual(summary.recommendedProvider, "Gmail")
    XCTAssertEqual(summary.tone, "warning")
    XCTAssertEqual(gmail?.statusTitle, "Gmail setup or sign-in blocked")
    XCTAssertEqual(gmail?.fetchedCount, 10)
    XCTAssertEqual(gmail?.blockedCount, 1)
    XCTAssertEqual(summary.metrics.first { $0.title == "Fetched" }?.value, "10")
    XCTAssertEqual(summary.metrics.first { $0.title == "Filtered" }?.value, "10")
    XCTAssertEqual(summary.metrics.first { $0.title == "Blockers" }?.value, "2")
    XCTAssertTrue(summary.actionItems.contains { $0.providerName == "Gmail" && $0.title == "Finish Gmail setup" })
  }

  func testMailboxProviderComparisonSummarizesSpaceMailAndGmailSideBySide() {
    let mailboxID = UUID()
    let store = ParcelOpsStore()
    store.spaceMailIMAPConnections = [
      makeSpaceMailConnection(
        credentialStorageStatus: "Password reference available",
        fetched: 10,
        imported: 0,
        filtered: 8,
        uncertain: 0
      )
    ]
    store.gmailMailboxConnections = [
      makeGmailConnection(
        id: mailboxID,
        oauthReadinessStatus: "Needs review",
        credentialStorageStatus: "GoogleSignIn cache pending",
        fetched: 0,
        imported: 0,
        filtered: 0,
        uncertain: nil
      )
    ]
    store.gmailAuthSessionStates = [:]

    let summary = store.mailboxProviderComparisonSummary
    let spaceMail = summary.providers.first { $0.providerName == "SpaceMail" }
    let gmail = summary.providers.first { $0.providerName == "Gmail" }

    XCTAssertEqual(summary.title, "Mailbox setup has blockers")
    XCTAssertEqual(summary.recommendedProvider, "SpaceMail + Gmail")
    XCTAssertEqual(summary.tone, "warning")
    XCTAssertEqual(spaceMail?.statusTitle, "SpaceMail filtering is active")
    XCTAssertEqual(gmail?.statusTitle, "Gmail setup or sign-in blocked")
    XCTAssertTrue(summary.decisionRules.contains { $0.title == "Both providers can run side by side" })
    XCTAssertEqual(summary.metrics.first { $0.title == "Providers" }?.value, "2")
    XCTAssertEqual(summary.metrics.first { $0.title == "Fetched" }?.value, "10")
    XCTAssertEqual(summary.metrics.first { $0.title == "Filtered" }?.value, "8")
    XCTAssertEqual(summary.metrics.first { $0.title == "Blockers" }?.value, "2")
  }

  func testMailboxProviderComparisonPrioritizesOperatorWorkOverSetupBlockers() {
    let uncertainMessage = SpaceMailUncertainMessage(
      providerMessageID: "spacemail-uncertain-mixed",
      sourceMailboxID: UUID(),
      sender: "sender@example.test",
      subject: "Delivery question",
      receivedDate: "Today",
      bodyPreview: "Can you check whether this relates to an order?",
      reason: "delivery-ish no id",
      capturedDate: "Today"
    )
    let store = ParcelOpsStore()
    store.spaceMailIMAPConnections = [
      makeSpaceMailConnection(
        credentialStorageStatus: "Password reference available",
        fetched: 10,
        imported: 1,
        filtered: 8,
        uncertain: 1,
        uncertainMessages: [uncertainMessage]
      )
    ]
    store.gmailMailboxConnections = [
      makeGmailConnection(
        oauthReadinessStatus: "Needs review",
        credentialStorageStatus: "GoogleSignIn cache pending",
        fetched: 0,
        imported: 0,
        filtered: 0,
        uncertain: nil
      )
    ]
    store.gmailAuthSessionStates = [:]
    store.mailboxIngestRecords = []
    store.intakeEmails = []

    let summary = store.mailboxProviderComparisonSummary
    let spaceMail = summary.providers.first { $0.providerName == "SpaceMail" }
    let gmail = summary.providers.first { $0.providerName == "Gmail" }

    XCTAssertEqual(summary.title, "Mailbox intake needs operator review")
    XCTAssertEqual(summary.recommendedProvider, "SpaceMail + Gmail")
    XCTAssertEqual(summary.tone, "attention")
    XCTAssertEqual(spaceMail?.statusTitle, "SpaceMail has operator work")
    XCTAssertEqual(gmail?.statusTitle, "Gmail setup or sign-in blocked")
    XCTAssertTrue(summary.actionItems.contains { $0.providerName == "SpaceMail" && $0.title == "Review SpaceMail intake" })
    XCTAssertTrue(summary.actionItems.contains { $0.providerName == "Gmail" && $0.title == "Finish Gmail setup" })
    XCTAssertEqual(summary.metrics.first { $0.title == "Imported" }?.value, "1")
    XCTAssertEqual(summary.metrics.first { $0.title == "Uncertain" }?.value, "2")
  }

  func testMailboxOperationsHandoffFlagsProviderSetupBlockers() {
    let store = ParcelOpsStore()
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = [
      makeGmailConnection(
        oauthReadinessStatus: "Needs review",
        credentialStorageStatus: "GoogleSignIn cache pending",
        fetched: 0,
        imported: 0,
        filtered: 0,
        uncertain: nil
      )
    ]
    store.gmailAuthSessionStates = [:]
    store.intakeEmails = []

    let summary = store.mailboxOperationsHandoffSummary

    XCTAssertEqual(summary.title, "Mailbox handoff has setup blockers")
    XCTAssertEqual(summary.tone, "warning")
    XCTAssertEqual(summary.metrics.first { $0.title == "Blockers" }?.value, "3")
    XCTAssertEqual(summary.lines.first?.title, "Provider setup blockers")
    XCTAssertEqual(summary.lines.first?.tone, "warning")
    XCTAssertEqual(summary.lastEvidenceText, "No real mailbox refresh evidence yet")
  }

  func testMailboxOperationsHandoffPromotesImportedAndUncertainWork() {
    let mailboxID = UUID()
    let intake = ForwardedEmailIntake(
      sender: "orders@example.test",
      subject: "Order TEST-123 shipped",
      receivedDate: "Today",
      rawBodyPreview: "Order TEST-123 shipped tracking ABC123",
      detectedMerchant: "Example Store",
      detectedOrderNumber: "TEST-123",
      detectedTrackingNumber: "ABC123",
      detectedDestinationAddress: "Destination needs review",
      linkedOrderID: nil,
      reviewState: .needsReview
    )
    let uncertainMessage = SpaceMailUncertainMessage(
      providerMessageID: "spacemail-uncertain-handoff",
      sourceMailboxID: mailboxID,
      sender: "sender@example.test",
      subject: "Delivery question",
      receivedDate: "Today",
      bodyPreview: "Can you check whether this relates to an order?",
      reason: "delivery-ish no id",
      capturedDate: "Today"
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = [
      makeSpaceMailConnection(
        id: mailboxID,
        credentialStorageStatus: "Password reference available",
        fetched: 10,
        imported: 1,
        filtered: 8,
        uncertain: 1,
        uncertainMessages: [uncertainMessage]
      )
    ]
    store.gmailMailboxConnections = []
    store.intakeEmails = [intake]
    store.mailboxIngestRecords = [
      MailboxIngestRecord(
        providerMessageID: "spacemail-imported-handoff",
        sourceMailboxID: mailboxID,
        intakeEmailID: intake.id,
        capturedDate: "Today",
        status: .imported,
        summary: "Imported order update"
      )
    ]

    let summary = store.mailboxOperationsHandoffSummary

    XCTAssertEqual(summary.title, "Mailbox handoff has operator work")
    XCTAssertEqual(summary.tone, "attention")
    XCTAssertEqual(summary.metrics.first { $0.title == "Imported" }?.value, "1")
    XCTAssertEqual(summary.metrics.first { $0.title == "Open intake" }?.value, "1")
    XCTAssertEqual(summary.metrics.first { $0.title == "Uncertain" }?.value, "2")
    XCTAssertTrue(summary.lines.contains { $0.title == "Imported intake ready" })
    XCTAssertTrue(summary.lines.contains { $0.title == "Uncertain mailbox previews" })
    XCTAssertTrue(summary.lines.contains { $0.title == "Inbox triage still open" })
  }

  func testMailboxOperationsHandoffTreatsFilteredOnlyRefreshAsStable() {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = [
      makeSpaceMailConnection(
        credentialStorageStatus: "Password reference available",
        fetched: 10,
        imported: 0,
        filtered: 10,
        uncertain: 0
      )
    ]
    store.gmailMailboxConnections = []
    store.intakeEmails = []
    store.mailboxIngestRecords = []

    let summary = store.mailboxOperationsHandoffSummary

    XCTAssertEqual(summary.title, "Mailbox handoff is stable")
    XCTAssertEqual(summary.tone, "success")
    XCTAssertEqual(summary.metrics.first { $0.title == "Filtered" }?.value, "10")
    XCTAssertEqual(summary.metrics.first { $0.title == "Open intake" }?.value, "0")
    XCTAssertEqual(summary.metrics.first { $0.title == "Blockers" }?.value, "0")
    XCTAssertEqual(summary.lines.first?.title, "Mailbox noise controlled")
    XCTAssertEqual(summary.lines.first?.tone, "success")
  }

  func testMailboxProviderTestQueueFlagsGmailCompileConfigBlocker() {
    let mailboxID = UUID()
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = [
      makeGmailConnection(
        id: mailboxID,
        oauthReadinessStatus: "Ready",
        credentialStorageStatus: "GoogleSignIn cache available",
        fetched: 10,
        imported: 0,
        filtered: 10,
        uncertain: 0
      )
    ]
    store.gmailAuthSessionStates = [
      mailboxID: GmailAuthSessionState(
        connectionID: mailboxID,
        status: .connected,
        signedInAccount: "orders@example.test",
        lastAuthAttemptDate: "Today",
        lastSuccessfulAuthDate: "Today",
        tokenStoreStatus: "GoogleSignIn cache available",
        tokenStoreDetail: "No token values stored in JSON.",
        detailText: "Identity sign-in available."
      )
    ]
    store.intakeEmails = []
    store.mailboxIngestRecords = []
    store.orders = []

    let summary = store.mailboxProviderTestQueueSummary

    XCTAssertEqual(summary.title, "Mailbox provider test queue has blockers")
    XCTAssertEqual(summary.tone, "warning")
    XCTAssertEqual(summary.currentProvider, "Gmail")
    XCTAssertTrue(summary.items.contains { item in
      item.providerName == "Gmail"
        && item.phase == "Compile config"
        && item.title == "Rebuild app with Gmail OAuth values"
        && item.tone == "warning"
        && !item.isComplete
    })
    XCTAssertTrue(summary.items.contains { item in
      item.providerName == "Gmail"
        && item.phase == "Refresh"
        && item.title == "Gmail refresh evidence exists"
        && item.isComplete
    })
    XCTAssertEqual(summary.metrics.first { $0.title == "Evidence" }?.value, "10")
    XCTAssertEqual(summary.metrics.first { $0.title == "Warnings" }?.tone, "warning")
  }

  func testMailboxProviderTestQueuePromotesOpenInboxTriage() {
    let mailboxID = UUID()
    let intake = ForwardedEmailIntake(
      sender: "orders@example.test",
      subject: "Order TEST-123 shipped",
      receivedDate: "Today",
      rawBodyPreview: "Order TEST-123 shipped tracking ABC123",
      detectedMerchant: "Example Store",
      detectedOrderNumber: "TEST-123",
      detectedTrackingNumber: "ABC123",
      detectedDestinationAddress: "123 Test Street",
      linkedOrderID: nil,
      reviewState: .needsReview
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = [
      makeSpaceMailConnection(
        id: mailboxID,
        credentialStorageStatus: "Password reference available",
        fetched: 10,
        imported: 1,
        filtered: 9,
        uncertain: 0
      )
    ]
    store.gmailMailboxConnections = []
    store.intakeEmails = [intake]
    store.orders = []
    store.mailboxIngestRecords = [
      MailboxIngestRecord(
        providerMessageID: "spacemail-imported-queue",
        sourceMailboxID: mailboxID,
        intakeEmailID: intake.id,
        capturedDate: "Today",
        status: .imported,
        summary: "Imported order update"
      )
    ]

    let summary = store.mailboxProviderTestQueueSummary

    XCTAssertTrue(summary.tone == "attention" || summary.tone == "warning")
    XCTAssertTrue(summary.items.contains { item in
      item.providerName == "Inbox"
        && item.phase == "Triage"
        && item.title == "Review mailbox-created intake"
        && item.tone == "attention"
        && !item.isComplete
    })
    XCTAssertTrue(summary.items.contains { item in
      item.providerName == "SpaceMail"
        && item.phase == "Refresh"
        && item.title == "SpaceMail refresh evidence exists"
        && item.evidence == "10 fetched, 1 imported, 0 uncertain."
        && item.isComplete
    })
    XCTAssertEqual(summary.metrics.first { $0.title == "Inbox" }?.value, "1")
    XCTAssertEqual(summary.metrics.first { $0.title == "Handoff" }?.value, "Review")
  }

  func testMailboxProviderTestQueueTreatsFilteredOnlyRefreshAsClearEvidence() {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = [
      makeSpaceMailConnection(
        credentialStorageStatus: "Password reference available",
        fetched: 10,
        imported: 0,
        filtered: 10,
        uncertain: 0
      )
    ]
    store.gmailMailboxConnections = []
    store.intakeEmails = []
    store.mailboxIngestRecords = []
    store.orders = []

    let summary = store.mailboxProviderTestQueueSummary

    XCTAssertTrue(summary.items.contains { item in
      item.providerName == "SpaceMail"
        && item.phase == "Refresh"
        && item.title == "SpaceMail refresh evidence exists"
        && item.tone == "success"
        && item.isComplete
    })
    XCTAssertTrue(summary.items.contains { item in
      item.providerName == "Inbox"
        && item.phase == "Triage"
        && item.title == "Inbox triage is clear"
        && item.tone == "success"
        && item.isComplete
    })
    XCTAssertEqual(summary.metrics.first { $0.title == "Inbox" }?.value, "0")
    XCTAssertEqual(summary.metrics.first { $0.title == "Evidence" }?.value, "10")
  }

  func testMailboxProviderHandoffPacketPromotesQueueAndBoundaries() {
    let mailboxID = UUID()
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = [
      makeGmailConnection(
        id: mailboxID,
        oauthReadinessStatus: "Ready",
        credentialStorageStatus: "GoogleSignIn cache available",
        fetched: 10,
        imported: 0,
        filtered: 10,
        uncertain: 0
      )
    ]
    store.gmailAuthSessionStates = [
      mailboxID: GmailAuthSessionState(
        connectionID: mailboxID,
        status: .connected,
        signedInAccount: "orders@example.test",
        lastAuthAttemptDate: "Today",
        lastSuccessfulAuthDate: "Today",
        tokenStoreStatus: "GoogleSignIn cache available",
        tokenStoreDetail: "No token values stored in JSON.",
        detailText: "Identity sign-in available."
      )
    ]
    store.intakeEmails = []
    store.mailboxIngestRecords = []
    store.orders = []

    let packet = store.mailboxProviderHandoffPacketSummary
    let queueSection = packet.sections.first { $0.title == "Next test queue" }
    let setupSection = packet.sections.first { $0.title == "Setup readiness" }

    XCTAssertEqual(packet.title, "Mailbox provider handoff has blockers")
    XCTAssertEqual(packet.tone, "warning")
    XCTAssertTrue(packet.reportText.contains("Boundaries:"))
    XCTAssertTrue(packet.reportText.contains("It does not run mailbox refreshes"))
    XCTAssertTrue(queueSection?.lines.contains { $0.contains("Gmail / Compile config: Rebuild app with Gmail OAuth values") } == true)
    XCTAssertTrue(setupSection?.lines.contains { $0.contains("Gmail") } == true)
    XCTAssertEqual(packet.metrics.first { $0.title == "Warnings" }?.tone, "warning")
  }

  func testMailboxProviderReleaseGateBlocksWhenNoProviderConfigured() {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = []
    store.gmailAuthSessionStates = [:]
    store.intakeEmails = []
    store.mailboxIngestRecords = []
    store.orders = []

    let gate = store.mailboxProviderReleaseGateSummary
    let providerGate = gate.gates.first { $0.title == "Provider configured" }
    let refreshGate = gate.gates.first { $0.title == "Manual refresh evidence exists" }

    XCTAssertEqual(gate.verdict, "Blocked")
    XCTAssertEqual(gate.tone, "warning")
    XCTAssertEqual(providerGate?.isPassed, false)
    XCTAssertEqual(providerGate?.tone, "warning")
    XCTAssertEqual(refreshGate?.isPassed, false)
    XCTAssertTrue(gate.reportText.contains("Local-only release gate computed from JSON-backed app state."))
    XCTAssertTrue(gate.reportText.contains("No mailbox refresh, credential read, external service call"))
    XCTAssertEqual(gate.metrics.first { $0.title == "Verdict" }?.value, "Blocked")
    XCTAssertEqual(gate.metrics.first { $0.title == "Warnings" }?.tone, "warning")
  }

  func testMailboxProviderReleaseGateTracksImportedInboxHandoffGap() {
    let mailboxID = UUID()
    let intake = ForwardedEmailIntake(
      sender: "orders@example.test",
      subject: "Order TEST-123 shipped",
      receivedDate: "Today",
      rawBodyPreview: "Order TEST-123 shipped tracking ABC123",
      detectedMerchant: "Example Store",
      detectedOrderNumber: "TEST-123",
      detectedTrackingNumber: "ABC123",
      detectedDestinationAddress: "123 Test Street",
      linkedOrderID: nil,
      reviewState: .needsReview
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = [
      makeSpaceMailConnection(
        id: mailboxID,
        credentialStorageStatus: "Password reference available",
        fetched: 10,
        imported: 1,
        filtered: 9,
        uncertain: 0
      )
    ]
    store.gmailMailboxConnections = []
    store.intakeEmails = [intake]
    store.mailboxIngestRecords = [
      MailboxIngestRecord(
        providerMessageID: "spacemail-imported-release-gate",
        sourceMailboxID: mailboxID,
        intakeEmailID: intake.id,
        capturedDate: "Today",
        status: .imported,
        summary: "Imported order update"
      )
    ]
    store.orders = []

    let gate = store.mailboxProviderReleaseGateSummary
    let triageGate = gate.gates.first { $0.title == "Inbox triage is actionable" }
    let handoffGate = gate.gates.first { $0.title == "Order handoff is visible" }

    XCTAssertEqual(triageGate?.isPassed, false)
    XCTAssertEqual(triageGate?.tone, "attention")
    XCTAssertEqual(handoffGate?.isPassed, false)
    XCTAssertEqual(handoffGate?.tone, "attention")
    XCTAssertTrue(gate.reportText.contains("Inbox triage is actionable"))
    XCTAssertTrue(gate.reportText.contains("Order handoff is visible"))
    XCTAssertEqual(gate.metrics.first { $0.title == "Orders" }?.value, "0")
  }

  func testMailboxProviderHandoffPacketTaskRefreshesExistingOpenTask() {
    let mailboxID = UUID()
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = [
      makeGmailConnection(
        id: mailboxID,
        oauthReadinessStatus: "Ready",
        credentialStorageStatus: "GoogleSignIn cache available",
        fetched: 10,
        imported: 0,
        filtered: 10,
        uncertain: 0
      )
    ]
    store.gmailAuthSessionStates = [
      mailboxID: GmailAuthSessionState(
        connectionID: mailboxID,
        status: .connected,
        signedInAccount: "orders@example.test",
        lastAuthAttemptDate: "Today",
        lastSuccessfulAuthDate: "Today",
        tokenStoreStatus: "GoogleSignIn cache available",
        tokenStoreDetail: "No token values stored in JSON.",
        detailText: "Identity sign-in available."
      )
    ]
    store.reviewTasks = []

    store.createReviewTaskFromMailboxProviderHandoffPacket()
    store.createReviewTaskFromMailboxProviderHandoffPacket()

    let tasks = store.reviewTasks.filter {
      $0.linkedEntityType == .integration && $0.linkedEntityID == "mailbox-provider-handoff-packet"
    }
    XCTAssertEqual(tasks.count, 1)
    XCTAssertEqual(tasks.first?.priority, .high)
    XCTAssertEqual(tasks.first?.dueDate, "Today")
    XCTAssertEqual(tasks.first?.assignee, "ParcelOps Operations")
    XCTAssertTrue(tasks.first?.summary.contains("Mailbox provider handoff has blockers") == true)
    XCTAssertTrue(store.auditEvents.contains { $0.summary == "Existing mailbox provider handoff packet task refreshed." })
  }

  func testMailboxProviderHandoffNoteRefreshesExistingOpenNote() {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = [
      makeSpaceMailConnection(
        credentialStorageStatus: "Password reference available",
        fetched: 10,
        imported: 0,
        filtered: 10,
        uncertain: 0
      )
    ]
    store.gmailMailboxConnections = []
    store.intakeEmails = []
    store.mailboxIngestRecords = []
    store.orders = []
    store.handoffNotes = []

    store.createHandoffNoteFromMailboxProviderHandoffPacket()
    store.createHandoffNoteFromMailboxProviderHandoffPacket()

    let notes = store.handoffNotes.filter {
      $0.linkedEntityType == .integration && $0.linkedEntityID == "mailbox-provider-handoff-packet"
    }
    XCTAssertEqual(notes.count, 1)
    XCTAssertEqual(notes.first?.assignee, "Mailbox team")
    XCTAssertTrue(notes.first?.notes.contains("Shift handoff boundary:") == true)
    XCTAssertTrue(notes.first?.notes.contains("It does not run Gmail, SpaceMail, Microsoft 365, IMAP, or Graph refreshes.") == true)
    XCTAssertTrue(store.auditEvents.contains { $0.summary == "Existing mailbox provider handoff note refreshed." })
  }

  func testMailboxProviderTroubleshootingDraftRefreshesExistingUnsentDraft() {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = []
    store.draftMessages = []
    store.auditEvents = []

    store.createDraftMessageFromMailboxProviderTroubleshooting()
    store.createDraftMessageFromMailboxProviderTroubleshooting()

    let drafts = store.draftMessages.filter {
      $0.linkedEntityType == .integration && $0.linkedEntityID == "mailbox-provider-troubleshooting"
    }
    XCTAssertEqual(drafts.count, 1)
    XCTAssertEqual(drafts.first?.recipient, "operations@parcelops.example")
    XCTAssertEqual(drafts.first?.status, .draft)
    XCTAssertEqual(drafts.first?.reviewState, .needsReview)
    XCTAssertTrue(drafts.first?.subject.contains("Mailbox provider diagnostics") == true)
    XCTAssertTrue(drafts.first?.body.contains("Mailbox provider diagnostic packet") == true)
    XCTAssertTrue(drafts.first?.body.contains("ParcelOps did not run Gmail, SpaceMail, Microsoft 365, IMAP, Graph") == true)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Existing mailbox provider troubleshooting draft refreshed."
        && (event.afterDetail?.contains("No duplicate draft was created.") ?? false)
    })
  }

  func testMailboxProviderTroubleshootingDraftCreatesNewDraftAfterSentLocally() {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = []
    store.draftMessages = []
    store.auditEvents = []

    store.createDraftMessageFromMailboxProviderTroubleshooting()
    store.draftMessages[0].status = .sentLocally
    store.createDraftMessageFromMailboxProviderTroubleshooting()

    let drafts = store.draftMessages.filter {
      $0.linkedEntityType == .integration && $0.linkedEntityID == "mailbox-provider-troubleshooting"
    }
    XCTAssertEqual(drafts.count, 2)
    XCTAssertEqual(drafts.filter { $0.status == .sentLocally }.count, 1)
    XCTAssertEqual(drafts.filter { $0.status == .draft }.count, 1)
    XCTAssertEqual(store.auditEvents.filter { $0.summary == "Mailbox provider troubleshooting draft created locally." }.count, 2)
  }

  func testMailboxProviderTroubleshootingDraftAppearsInReviewQueue() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = []
    store.draftMessages = []

    store.createDraftMessageFromMailboxProviderTroubleshooting()

    let draft = try XCTUnwrap(store.draftMessages.first)
    XCTAssertEqual(draft.linkedEntityType, .integration)
    XCTAssertEqual(draft.linkedEntityID, "mailbox-provider-troubleshooting")
    XCTAssertTrue(store.isMailboxProviderDraft(draft))
    XCTAssertEqual(store.draftMessagesNeedingReview.map(\.id), [draft.id])
  }

  func testMailboxProviderTroubleshootingSentAcceptedDraftStaysClosed() {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = []
    store.draftMessages = []

    store.createDraftMessageFromMailboxProviderTroubleshooting()
    store.draftMessages[0].status = .sentLocally
    store.draftMessages[0].reviewState = .accepted

    XCTAssertTrue(store.isMailboxProviderDraft(store.draftMessages[0]))
    XCTAssertTrue(store.draftMessagesNeedingReview.isEmpty)
  }

  func testMailboxProviderReleaseGateTaskPromotesPrimaryOpenGate() {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = []
    store.gmailAuthSessionStates = [:]
    store.intakeEmails = []
    store.mailboxIngestRecords = []
    store.orders = []
    store.reviewTasks = []

    store.createReviewTaskFromMailboxProviderReleaseGate()
    store.createReviewTaskFromMailboxProviderReleaseGate()

    let tasks = store.reviewTasks.filter {
      $0.linkedEntityType == .integration && $0.linkedEntityID == "mailbox-provider-release-gate"
    }
    XCTAssertEqual(tasks.count, 1)
    XCTAssertEqual(tasks.first?.priority, .high)
    XCTAssertEqual(tasks.first?.dueDate, "Today")
    XCTAssertTrue(tasks.first?.title.hasPrefix("Resolve mailbox provider gate:") == true)
    XCTAssertTrue(tasks.first?.summary.contains("Primary open gate:") == true)
    XCTAssertTrue(tasks.first?.summary.contains("Next action:") == true)
    XCTAssertTrue(tasks.first?.summary.contains("Verdict: Blocked") == true)
    XCTAssertTrue(store.auditEvents.contains { $0.summary == "Existing mailbox provider release gate task refreshed." })
  }

  func testWorkbenchPromotesMailboxProviderReleaseGateItem() {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = []
    store.gmailAuthSessionStates = [:]
    store.intakeEmails = []
    store.mailboxIngestRecords = []
    store.orders = []

    let item = store.workbenchItems.first { $0.source == .mailboxProviderGate }

    XCTAssertNotNil(item)
    XCTAssertEqual(item?.id, "mailbox-provider-release-gate")
    XCTAssertEqual(item?.linkedEntityType, .integration)
    XCTAssertEqual(item?.linkedEntityID, "mailbox-provider-release-gate")
    XCTAssertEqual(item?.prioritySeverity, "High")
    XCTAssertEqual(item?.status, "Blocked")
    XCTAssertEqual(item?.reviewState, .needsReview)
    XCTAssertTrue(item?.title.contains("Mailbox provider release gate") == true)
    XCTAssertTrue(item?.summary.contains("Open gates:") == true)
    XCTAssertFalse(item?.suggestedNextAction.isEmpty ?? true)
  }

  func testWorkbenchMailboxProviderReleaseGateReviewLogsWithoutMutatingProviders() {
    let mailboxID = UUID()
    let connection = makeSpaceMailConnection(
      id: mailboxID,
      credentialStorageStatus: "Password reference available",
      fetched: 10,
      imported: 1,
      filtered: 9,
      uncertain: 0
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = [connection]
    store.gmailMailboxConnections = []
    store.intakeEmails = []
    store.mailboxIngestRecords = []
    store.orders = []
    store.auditEvents = []

    guard let item = store.workbenchItems.first(where: { $0.source == .mailboxProviderGate }) else {
      XCTFail("Expected mailbox provider release gate Workbench item.")
      return
    }

    store.markWorkbenchItemReviewed(item)

    XCTAssertEqual(store.spaceMailIMAPConnections, [connection])
    XCTAssertTrue(store.gmailMailboxConnections.isEmpty)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Mailbox provider release gate workbench item reviewed locally."
        && (event.afterDetail?.contains("No mailbox was fetched, no credential was changed, and no provider configuration was modified.") ?? false)
    })
  }

  func testWorkbenchMailboxProviderReleaseGateTaskKeepsIntegrationContext() {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = []
    store.intakeEmails = []
    store.mailboxIngestRecords = []
    store.orders = []
    store.reviewTasks = []
    store.auditEvents = []

    guard let item = store.workbenchItems.first(where: { $0.source == .mailboxProviderGate }) else {
      XCTFail("Expected mailbox provider release gate Workbench item.")
      return
    }

    store.createReviewTask(from: item)

    XCTAssertEqual(store.reviewTasks.count, 1)
    let task = store.reviewTasks[0]
    XCTAssertEqual(task.linkedEntityType, .integration)
    XCTAssertEqual(task.linkedEntityID, "mailbox-provider-release-gate")
    XCTAssertEqual(task.priority, .high)
    XCTAssertEqual(task.status, .open)
    XCTAssertEqual(task.assignee, "ParcelOps Operations")
    XCTAssertTrue(task.title.contains("Mailbox provider release gate"))
    XCTAssertTrue(task.summary.contains("Next action:"))
    XCTAssertTrue(store.auditEvents.contains { event in
      event.entityType == .reviewTask
        && event.summary == "Review task created from integration."
        && event.entityID == task.id.uuidString
    })
  }

  func testWorkbenchMailboxProviderReleaseGateDraftKeepsIntegrationContext() {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = []
    store.intakeEmails = []
    store.mailboxIngestRecords = []
    store.orders = []
    store.draftMessages = []
    store.auditEvents = []

    guard let item = store.workbenchItems.first(where: { $0.source == .mailboxProviderGate }) else {
      XCTFail("Expected mailbox provider release gate Workbench item.")
      return
    }

    store.createDraftMessage(from: item)

    XCTAssertEqual(store.draftMessages.count, 1)
    let draft = store.draftMessages[0]
    XCTAssertEqual(draft.linkedEntityType, .integration)
    XCTAssertEqual(draft.linkedEntityID, "mailbox-provider-release-gate")
    XCTAssertEqual(draft.recipient, "operations@parcelops.example")
    XCTAssertEqual(draft.status, .draft)
    XCTAssertEqual(draft.reviewState, .needsReview)
    XCTAssertTrue(draft.subject.contains("Mailbox provider release gate"))
    XCTAssertTrue(store.auditEvents.contains { event in
      event.entityType == .draftMessage
        && event.summary == "Draft message created locally."
        && event.entityID == draft.id.uuidString
    })
  }

  func testGmailReleaseSelfCheckFlagsSetupBlockersBeforeSignIn() {
    let connection = makeGmailConnection(
      oauthReadinessStatus: "Needs review",
      credentialStorageStatus: "GoogleSignIn cache pending",
      fetched: 0,
      imported: 0,
      filtered: 0,
      uncertain: nil
    )
    let store = ParcelOpsStore()
    store.gmailMailboxConnections = [connection]
    store.gmailAuthSessionStates = [:]
    store.auditEvents = []

    let summary = store.gmailReleaseSelfCheckSummary(for: connection)
    let setupItem = summary.items.first { $0.title == "Setup and callback" }
    let signInItem = summary.items.first { $0.title == "Google sign-in" }
    let refreshItem = summary.items.first { $0.title == "Manual read-only refresh" }

    XCTAssertEqual(summary.verdict, "Gmail release blocked")
    XCTAssertEqual(summary.tone, "warning")
    XCTAssertEqual(summary.completedCount, 0)
    XCTAssertEqual(summary.totalCount, 6)
    XCTAssertEqual(setupItem?.tone, "warning")
    XCTAssertEqual(signInItem?.tone, "attention")
    XCTAssertEqual(refreshItem?.tone, "neutral")
    XCTAssertEqual(summary.nextAction, "Use Edit setup and update compiled plist/project values before live testing.")
  }

  func testGmailReleaseSelfCheckShowsSignInEvidenceWhileSetupRemainsBlocked() {
    let mailboxID = UUID()
    let connection = makeGmailConnection(
      id: mailboxID,
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 0,
      imported: 0,
      filtered: 0,
      uncertain: nil
    )
    let store = ParcelOpsStore()
    store.gmailMailboxConnections = [connection]
    store.gmailAuthSessionStates = [
      mailboxID: GmailAuthSessionState(
        connectionID: mailboxID,
        status: .connected,
        signedInAccount: "orders@example.test",
        lastAuthAttemptDate: "Today",
        lastSuccessfulAuthDate: "Today",
        tokenStoreStatus: "GoogleSignIn cache available",
        tokenStoreDetail: "No token values stored in JSON.",
        detailText: "Identity sign-in available."
      )
    ]
    store.auditEvents = [
      AuditEvent(
        timestamp: "Today",
        actor: "Local user",
        action: .reviewed,
        entityType: .gmailMailboxConnection,
        entityID: mailboxID.uuidString,
        entityLabel: connection.displayName,
        summary: "Gmail setup reviewed locally.",
        beforeDetail: nil,
        afterDetail: "Gmail sign-in evidence recorded."
      )
    ]

    let summary = store.gmailReleaseSelfCheckSummary(for: connection)
    let signInItem = summary.items.first { $0.title == "Google sign-in" }
    let refreshItem = summary.items.first { $0.title == "Manual read-only refresh" }
    let auditItem = summary.items.first { $0.title == "Audit evidence" }

    XCTAssertEqual(summary.verdict, "Gmail release blocked")
    XCTAssertEqual(summary.tone, "warning")
    XCTAssertEqual(signInItem?.isComplete, true)
    XCTAssertEqual(refreshItem?.isComplete, false)
    XCTAssertEqual(refreshItem?.tone, "neutral")
    XCTAssertEqual(auditItem?.isComplete, true)
    XCTAssertEqual(summary.nextAction, "Use Edit setup and update compiled plist/project values before live testing.")
  }

  func testGmailReleaseSelfCheckShowsUncertainReviewWhileSetupRemainsBlocked() {
    let mailboxID = UUID()
    let uncertain = GmailReviewMessage(
      providerMessageID: "gmail-uncertain-release",
      sourceMailboxID: mailboxID,
      sender: "sender@example.test",
      subject: "Delivery question",
      receivedDate: "Today",
      bodyPreview: "Can you check whether this relates to an order?",
      reason: "delivery-ish no id",
      capturedDate: "Today"
    )
    var connection = makeGmailConnection(
      id: mailboxID,
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 10,
      imported: 0,
      filtered: 9,
      uncertain: 1
    )
    connection.connectionStatus = "Real Gmail: Fetch success"
    connection.lastManualRefreshDate = "Today"
    connection.uncertainMessages = [uncertain]
    connection.classifierTestResults = [
      GmailClassifierTestResult(
        sampleName: "Ambiguous delivery sample",
        decision: "Uncertain",
        reason: "delivery-ish no id",
        score: 2,
        subjectPreview: "Delivery question",
        detectedOrderNumber: "Order number needs review",
        detectedTrackingNumber: "Tracking number needs review",
        expectedDecision: "Uncertain",
        decisionStatus: "Matched expected decision"
      )
    ]
    let store = ParcelOpsStore()
    store.gmailMailboxConnections = [connection]
    store.gmailAuthSessionStates = [
      mailboxID: GmailAuthSessionState(
        connectionID: mailboxID,
        status: .connected,
        signedInAccount: "orders@example.test",
        lastAuthAttemptDate: "Today",
        lastSuccessfulAuthDate: "Today",
        tokenStoreStatus: "GoogleSignIn cache available",
        tokenStoreDetail: "No token values stored in JSON.",
        detailText: "Identity sign-in available."
      )
    ]
    store.auditEvents = [
      AuditEvent(
        timestamp: "Today",
        actor: "Local user",
        action: .reviewed,
        entityType: .gmailMailboxConnection,
        entityID: mailboxID.uuidString,
        entityLabel: connection.displayName,
        summary: "Real Gmail refresh completed.",
        beforeDetail: nil,
        afterDetail: "Manual read-only refresh evidence."
      )
    ]

    let summary = store.gmailReleaseSelfCheckSummary(for: connection)
    let filterItem = summary.items.first { $0.title == "Mixed-mailbox filtering" }
    let refreshItem = summary.items.first { $0.title == "Manual read-only refresh" }

    XCTAssertEqual(summary.verdict, "Gmail release blocked")
    XCTAssertEqual(summary.tone, "warning")
    XCTAssertEqual(refreshItem?.isComplete, true)
    XCTAssertEqual(filterItem?.isComplete, false)
    XCTAssertEqual(filterItem?.tone, "attention")
    XCTAssertEqual(summary.nextAction, "Use Edit setup and update compiled plist/project values before live testing.")
  }

  func testGmailSetupHandoffTaskRefreshesExistingOpenTask() {
    let mailboxID = UUID()
    var connection = makeGmailConnection(
      id: mailboxID,
      oauthReadinessStatus: "Needs review",
      credentialStorageStatus: "GoogleSignIn cache pending",
      fetched: 0,
      imported: 0,
      filtered: 0,
      uncertain: nil
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = [connection]
    store.reviewTasks = []
    store.auditEvents = []

    store.createReviewTaskFromGmailOAuthPlan(connection)
    connection.oauthReadinessStatus = "Ready"
    connection.credentialStorageStatus = "GoogleSignIn cache available"
    store.createReviewTaskFromGmailOAuthPlan(connection)

    let tasks = store.reviewTasks.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == mailboxID.uuidString
        && $0.title.localizedCaseInsensitiveContains("Gmail config handoff")
    }
    XCTAssertEqual(tasks.count, 1)
    XCTAssertEqual(tasks.first?.assignee, "Operations")
    XCTAssertEqual(tasks.first?.reviewState, .needsReview)
    XCTAssertTrue(tasks.first?.summary.contains("Review Gmail setup before real sign-in.") == true)
    XCTAssertTrue(tasks.first?.summary.contains("Compiled client:") == true)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Existing Gmail setup handoff review task refreshed."
        && (event.afterDetail?.contains("No duplicate task was created.") ?? false)
    })
  }

  func testGmailSetupHandoffTaskCreatesNewTaskAfterCompletedTask() {
    let mailboxID = UUID()
    let connection = makeGmailConnection(
      id: mailboxID,
      oauthReadinessStatus: "Needs review",
      credentialStorageStatus: "GoogleSignIn cache pending",
      fetched: 0,
      imported: 0,
      filtered: 0,
      uncertain: nil
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = [connection]
    store.reviewTasks = []
    store.auditEvents = []

    store.createReviewTaskFromGmailOAuthPlan(connection)
    guard let firstTask = store.reviewTasks.first else {
      XCTFail("Expected Gmail setup handoff task.")
      return
    }
    store.completeReviewTask(firstTask)
    store.createReviewTaskFromGmailOAuthPlan(connection)

    let tasks = store.reviewTasks.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == mailboxID.uuidString
        && $0.title.localizedCaseInsensitiveContains("Gmail config handoff")
    }
    XCTAssertEqual(tasks.count, 2)
    XCTAssertEqual(tasks.filter { $0.status == .completed }.count, 1)
    XCTAssertEqual(tasks.filter { $0.status == .open }.count, 1)
    XCTAssertTrue(store.auditEvents.contains { $0.summary == "Review task completed." })
    XCTAssertTrue(store.auditEvents.contains { $0.summary == "Review task created from Gmail setup handoff." })
  }

  func testGmailReleaseSelfCheckTaskRefreshesExistingOpenTask() {
    let mailboxID = UUID()
    var connection = makeGmailConnection(
      id: mailboxID,
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 0,
      imported: 0,
      filtered: 0,
      uncertain: nil
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = [connection]
    store.gmailAuthSessionStates = [:]
    store.reviewTasks = []
    store.auditEvents = []

    store.createReviewTaskFromGmailReleaseSelfCheck(connection)
    connection.connectionStatus = "Real Gmail: Fetch success"
    connection.lastManualRefreshDate = "Today"
    connection.lastRefreshFetchedCount = 10
    connection.lastRefreshFilteredNonOrderCount = 10
    store.createReviewTaskFromGmailReleaseSelfCheck(connection)

    let tasks = store.reviewTasks.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == mailboxID.uuidString
        && $0.title.localizedCaseInsensitiveContains("Gmail release self-check")
    }
    XCTAssertEqual(tasks.count, 1)
    XCTAssertEqual(tasks.first?.assignee, "Mailbox team")
    XCTAssertEqual(tasks.first?.priority, .high)
    XCTAssertEqual(tasks.first?.reviewState, .needsReview)
    XCTAssertTrue(tasks.first?.summary.contains("Gmail release blocked") == true)
    XCTAssertTrue(tasks.first?.summary.contains("Next action:") == true)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Existing Gmail release self-check review task refreshed."
        && (event.afterDetail?.contains("No duplicate task was created.") ?? false)
    })
  }

  func testGmailReleaseSelfCheckTaskCreatesNewTaskAfterCompletedTask() {
    let mailboxID = UUID()
    let connection = makeGmailConnection(
      id: mailboxID,
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 0,
      imported: 0,
      filtered: 0,
      uncertain: nil
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = [connection]
    store.gmailAuthSessionStates = [:]
    store.reviewTasks = []
    store.auditEvents = []

    store.createReviewTaskFromGmailReleaseSelfCheck(connection)
    guard let firstTask = store.reviewTasks.first else {
      XCTFail("Expected Gmail release self-check task.")
      return
    }
    store.completeReviewTask(firstTask)
    store.createReviewTaskFromGmailReleaseSelfCheck(connection)

    let tasks = store.reviewTasks.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == mailboxID.uuidString
        && $0.title.localizedCaseInsensitiveContains("Gmail release self-check")
    }
    XCTAssertEqual(tasks.count, 2)
    XCTAssertEqual(tasks.filter { $0.status == .completed }.count, 1)
    XCTAssertEqual(tasks.filter { $0.status == .open }.count, 1)
    XCTAssertTrue(store.auditEvents.contains { $0.summary == "Review task completed." })
    XCTAssertTrue(store.auditEvents.contains { $0.summary == "Review task created from Gmail release self-check." })
  }

  func testGmailShiftHandoffNoteRefreshesExistingOpenNote() {
    let connection = makeGmailConnection(
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 10,
      imported: 2,
      filtered: 6,
      uncertain: 1
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = [connection]
    store.handoffNotes = []
    store.auditEvents = []

    store.createGmailShiftHandoffNote()
    store.createGmailShiftHandoffNote()

    let notes = store.handoffNotes.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == "gmail-shift-handoff"
    }
    XCTAssertEqual(notes.count, 1)
    XCTAssertEqual(notes.first?.title, "Gmail shift handoff")
    XCTAssertEqual(notes.first?.assignee, "Mailbox team")
    XCTAssertEqual(notes.first?.dueDate, "Next shift")
    XCTAssertEqual(notes.first?.status, .open)
    XCTAssertEqual(notes.first?.reviewState, .needsReview)
    XCTAssertTrue(notes.first?.notes.contains("Gmail remains explicit, manual, and read-only") == true)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Existing Gmail shift handoff note refreshed."
        && (event.afterDetail?.contains("No duplicate handoff note was created.") ?? false)
    })
  }

  func testGmailShiftReviewTaskRefreshesExistingOpenTask() {
    let connection = makeGmailConnection(
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 10,
      imported: 2,
      filtered: 6,
      uncertain: 1
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = [connection]
    store.reviewTasks = []
    store.auditEvents = []

    store.createGmailShiftReviewTask()
    store.createGmailShiftReviewTask()

    let tasks = store.reviewTasks.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == "gmail-shift-handoff"
    }
    XCTAssertEqual(tasks.count, 1)
    XCTAssertEqual(tasks.first?.title, "Follow up Gmail shift handoff")
    XCTAssertEqual(tasks.first?.assignee, "Mailbox team")
    XCTAssertEqual(tasks.first?.status, .open)
    XCTAssertEqual(tasks.first?.reviewState, .needsReview)
    XCTAssertTrue(tasks.first?.summary.contains("Gmail remains explicit, manual, and read-only") == true)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Existing Gmail shift review task refreshed."
        && (event.afterDetail?.contains("No duplicate task was created.") ?? false)
    })
  }

  func testGmailShiftDraftRefreshesExistingUnsentDraft() {
    let connection = makeGmailConnection(
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 10,
      imported: 2,
      filtered: 6,
      uncertain: 1
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = [connection]
    store.draftMessages = []
    store.auditEvents = []

    store.createGmailShiftDraftMessage()
    store.createGmailShiftDraftMessage()

    let drafts = store.draftMessages.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == "gmail-shift-handoff"
    }
    XCTAssertEqual(drafts.count, 1)
    XCTAssertEqual(drafts.first?.recipient, "operations@parcelops.example")
    XCTAssertEqual(drafts.first?.status, .draft)
    XCTAssertEqual(drafts.first?.reviewState, .needsReview)
    XCTAssertTrue(drafts.first?.body.contains("Gmail remains explicit, manual, and read-only") == true)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Existing Gmail shift draft refreshed."
        && (event.afterDetail?.contains("No duplicate draft was created.") ?? false)
    })
  }

  func testGmailShiftDraftCreatesNewDraftAfterSentLocally() {
    let connection = makeGmailConnection(
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 10,
      imported: 2,
      filtered: 6,
      uncertain: 1
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = [connection]
    store.draftMessages = []
    store.auditEvents = []

    store.createGmailShiftDraftMessage()
    store.draftMessages[0].status = .sentLocally
    store.createGmailShiftDraftMessage()

    let drafts = store.draftMessages.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == "gmail-shift-handoff"
    }
    XCTAssertEqual(drafts.count, 2)
    XCTAssertEqual(drafts.filter { $0.status == .sentLocally }.count, 1)
    XCTAssertEqual(drafts.filter { $0.status == .draft }.count, 1)
    XCTAssertEqual(store.auditEvents.filter { $0.summary == "Gmail shift draft created locally." }.count, 2)
  }

  func testSpaceMailShiftHandoffNoteRefreshesExistingOpenNote() {
    let mailboxID = UUID()
    let connection = makeSpaceMailConnection(
      id: mailboxID,
      credentialStorageStatus: "Password reference available",
      fetched: 10,
      imported: 1,
      filtered: 8,
      uncertain: 1
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = [connection]
    store.handoffNotes = []
    store.auditEvents = []

    store.createSpaceMailShiftHandoffNote(for: connection)
    store.createSpaceMailShiftHandoffNote(for: connection)

    let notes = store.handoffNotes.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == mailboxID.uuidString
        && $0.title.localizedCaseInsensitiveContains("SpaceMail shift handoff")
    }
    XCTAssertEqual(notes.count, 1)
    XCTAssertEqual(notes.first?.assignee, "Mailbox team")
    XCTAssertEqual(notes.first?.dueDate, "Next shift")
    XCTAssertEqual(notes.first?.status, .open)
    XCTAssertEqual(notes.first?.reviewState, .needsReview)
    XCTAssertTrue(notes.first?.notes.contains("Connection: SpaceMail tracking inbox") == true)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Existing SpaceMail shift handoff note refreshed."
        && (event.afterDetail?.contains("No duplicate handoff note was created.") ?? false)
    })
  }

  func testSpaceMailShiftReviewTaskRefreshesExistingOpenTask() {
    let mailboxID = UUID()
    let connection = makeSpaceMailConnection(
      id: mailboxID,
      credentialStorageStatus: "Password reference available",
      fetched: 10,
      imported: 1,
      filtered: 8,
      uncertain: 1
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = [connection]
    store.reviewTasks = []
    store.auditEvents = []

    store.createSpaceMailShiftReviewTask(for: connection)
    store.createSpaceMailShiftReviewTask(for: connection)

    let tasks = store.reviewTasks.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == mailboxID.uuidString
        && $0.title.localizedCaseInsensitiveContains("SpaceMail shift summary")
    }
    XCTAssertEqual(tasks.count, 1)
    XCTAssertEqual(tasks.first?.title, "Follow up SpaceMail shift summary")
    XCTAssertEqual(tasks.first?.assignee, "Mailbox team")
    XCTAssertEqual(tasks.first?.status, .open)
    XCTAssertEqual(tasks.first?.reviewState, .needsReview)
    XCTAssertTrue(tasks.first?.summary.contains("Connection: SpaceMail tracking inbox") == true)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Existing SpaceMail shift review task refreshed."
        && (event.afterDetail?.contains("No duplicate task was created.") ?? false)
    })
  }

  func testSpaceMailShiftDraftRefreshesExistingUnsentDraft() {
    let mailboxID = UUID()
    let connection = makeSpaceMailConnection(
      id: mailboxID,
      credentialStorageStatus: "Password reference available",
      fetched: 10,
      imported: 1,
      filtered: 8,
      uncertain: 1
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = [connection]
    store.draftMessages = []
    store.auditEvents = []

    store.createSpaceMailShiftDraftMessage(for: connection)
    store.createSpaceMailShiftDraftMessage(for: connection)

    let drafts = store.draftMessages.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == "spacemail-shift-handoff-\(mailboxID.uuidString)"
    }
    XCTAssertEqual(drafts.count, 1)
    XCTAssertEqual(drafts.first?.recipient, "operations@parcelops.example")
    XCTAssertEqual(drafts.first?.status, .draft)
    XCTAssertEqual(drafts.first?.reviewState, .needsReview)
    XCTAssertTrue(drafts.first?.body.contains("Connection: SpaceMail tracking inbox") == true)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Existing SpaceMail shift draft refreshed."
        && (event.afterDetail?.contains("No duplicate draft was created.") ?? false)
    })
  }

  func testSpaceMailShiftDraftCreatesNewDraftAfterSentLocally() {
    let mailboxID = UUID()
    let connection = makeSpaceMailConnection(
      id: mailboxID,
      credentialStorageStatus: "Password reference available",
      fetched: 10,
      imported: 1,
      filtered: 8,
      uncertain: 1
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = [connection]
    store.draftMessages = []
    store.auditEvents = []

    store.createSpaceMailShiftDraftMessage(for: connection)
    store.draftMessages[0].status = .sentLocally
    store.createSpaceMailShiftDraftMessage(for: connection)

    let drafts = store.draftMessages.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == "spacemail-shift-handoff-\(mailboxID.uuidString)"
    }
    XCTAssertEqual(drafts.count, 2)
    XCTAssertEqual(drafts.filter { $0.status == .sentLocally }.count, 1)
    XCTAssertEqual(drafts.filter { $0.status == .draft }.count, 1)
    XCTAssertEqual(store.auditEvents.filter { $0.summary == "SpaceMail shift draft created locally." }.count, 2)
  }

  func testSpaceMailHealthSummaryFlagsUncertainReview() {
    let uncertainMessage = SpaceMailUncertainMessage(
      providerMessageID: "spacemail-uncertain-1",
      sourceMailboxID: UUID(),
      sender: "sender@example.test",
      subject: "Delivery question",
      receivedDate: "Today",
      bodyPreview: "Can you check whether this relates to an order?",
      reason: "delivery-ish no id",
      capturedDate: "Today"
    )
    let connection = makeSpaceMailConnection(
      credentialStorageStatus: "Password reference available",
      fetched: 10,
      imported: 0,
      filtered: 8,
      uncertain: 1,
      uncertainMessages: [uncertainMessage],
      reasonBreakdown: [
        SpaceMailClassifierReasonCount(decision: "Uncertain", reason: "delivery-ish no id", count: 1),
        SpaceMailClassifierReasonCount(decision: "Filtered", reason: "marketing", count: 8)
      ]
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = [connection]
    store.mailboxIngestRecords = []
    store.intakeEmails = []

    let summary = store.spaceMailIntakeHealthSummary(for: connection)

    XCTAssertEqual(summary.verdict, "Uncertain messages need review")
    XCTAssertEqual(summary.tone, "attention")
    XCTAssertEqual(summary.fetchedCount, 10)
    XCTAssertEqual(summary.filteredCount, 8)
    XCTAssertEqual(summary.uncertainCount, 1)
    XCTAssertEqual(summary.pendingUncertainReviewCount, 1)
    XCTAssertEqual(summary.topReasonLabels.first, "Uncertain: delivery-ish no id x1")
  }

  func testSpaceMailHealthSummaryFlagsParserIssuesForLinkedIntake() {
    let mailboxID = UUID()
    let intake = ForwardedEmailIntake(
      sender: "orders@example.test",
      subject: "Order update",
      receivedDate: "Today",
      rawBodyPreview: "Order shipped but parser could not determine order or tracking fields.",
      detectedMerchant: "Example Store",
      detectedOrderNumber: "Order number needs review",
      detectedTrackingNumber: "Tracking number needs review",
      detectedDestinationAddress: "Destination needs review",
      linkedOrderID: nil,
      reviewState: .needsReview
    )
    let connection = makeSpaceMailConnection(
      id: mailboxID,
      credentialStorageStatus: "Password reference available",
      fetched: 1,
      imported: 1,
      filtered: 0,
      uncertain: 0
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = [connection]
    store.intakeEmails = [intake]
    store.mailboxIngestRecords = [
      MailboxIngestRecord(
        providerMessageID: "spacemail-parser-1",
        sourceMailboxID: mailboxID,
        intakeEmailID: intake.id,
        capturedDate: "Today",
        status: .imported,
        summary: "Imported parser test message"
      )
    ]

    let summary = store.spaceMailIntakeHealthSummary(for: connection)

    XCTAssertEqual(summary.verdict, "Parser review needed")
    XCTAssertEqual(summary.tone, "attention")
    XCTAssertEqual(summary.importedCount, 1)
    XCTAssertEqual(summary.linkedIntakeCount, 1)
    XCTAssertGreaterThan(summary.parserIssueCount, 0)
    XCTAssertEqual(summary.nextAction, "Open the parser review queue, reprocess if needed, or create a follow-up task.")
  }

  func testSpaceMailPostRefreshActionPlanTreatsFilteredOnlyRefreshAsClear() {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = [
      makeSpaceMailConnection(
        credentialStorageStatus: "Password reference available",
        fetched: 10,
        imported: 0,
        filtered: 10,
        uncertain: 0
      )
    ]
    store.mailboxIngestRecords = []
    store.intakeEmails = []

    let plan = store.spaceMailPostRefreshActionPlan

    XCTAssertEqual(plan.title, "SpaceMail post-refresh queue is clear")
    XCTAssertEqual(plan.tone, "success")
    XCTAssertEqual(plan.primaryAction, "Wait for new order mail or run another manual refresh")
    XCTAssertEqual(plan.items.first { $0.title == "Review imported Inbox rows" }?.tone, "success")
    XCTAssertEqual(plan.items.first { $0.title == "Check filtered examples" }?.count, 0)
  }

  func testSpaceMailPostRefreshActionPlanPrioritizesUncertainReview() {
    let uncertainMessage = SpaceMailUncertainMessage(
      providerMessageID: "spacemail-uncertain-2",
      sourceMailboxID: UUID(),
      sender: "sender@example.test",
      subject: "Delivery question",
      receivedDate: "Today",
      bodyPreview: "Can you check whether this relates to an order?",
      reason: "delivery-ish no id",
      capturedDate: "Today"
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = [
      makeSpaceMailConnection(
        credentialStorageStatus: "Password reference available",
        fetched: 10,
        imported: 0,
        filtered: 8,
        uncertain: 1,
        uncertainMessages: [uncertainMessage]
      )
    ]
    store.mailboxIngestRecords = []
    store.intakeEmails = []

    let plan = store.spaceMailPostRefreshActionPlan
    let uncertainItem = plan.items.first { $0.title == "Review uncertain messages" }

    XCTAssertEqual(plan.title, "SpaceMail post-refresh actions need review")
    XCTAssertEqual(plan.tone, "attention")
    XCTAssertEqual(plan.primaryAction, "Review uncertain previews")
    XCTAssertEqual(uncertainItem?.count, 1)
    XCTAssertEqual(uncertainItem?.tone, "attention")
    XCTAssertEqual(uncertainItem?.actionLabel, "Review uncertain previews")
  }

  func testSpaceMailUncertainPreviewTaskRefreshesExistingOpenProviderMessageTask() {
    let mailboxID = UUID()
    let message = SpaceMailUncertainMessage(
      providerMessageID: "spacemail-preview-task-1",
      sourceMailboxID: mailboxID,
      sender: "sender@example.test",
      subject: "Delivery question",
      receivedDate: "Today",
      bodyPreview: "Can you check whether this relates to an order?",
      reason: "delivery-ish no id",
      capturedDate: "Today"
    )
    let connection = makeSpaceMailConnection(
      id: mailboxID,
      credentialStorageStatus: "Password reference available",
      fetched: 10,
      imported: 0,
      filtered: 9,
      uncertain: 1,
      uncertainMessages: [message]
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = [connection]
    store.reviewTasks = []
    store.auditEvents = []

    store.createReviewTask(from: message, connection: connection)
    store.createReviewTask(from: message, connection: connection)

    let tasks = store.reviewTasks.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == mailboxID.uuidString
        && $0.summary.contains(message.providerMessageID)
    }
    XCTAssertEqual(tasks.count, 1)
    XCTAssertEqual(tasks.first?.assignee, "Mailbox team")
    XCTAssertEqual(tasks.first?.priority, .normal)
    XCTAssertEqual(tasks.first?.reviewState, .needsReview)
    XCTAssertTrue(tasks.first?.summary.contains("Review uncertain SpaceMail preview") == true)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Existing uncertain SpaceMail preview review task refreshed."
        && (event.afterDetail?.contains("No duplicate task was created.") ?? false)
    })
  }

  func testSpaceMailFilteredPreviewTaskRefreshesExistingOpenProviderMessageTask() {
    let mailboxID = UUID()
    let message = SpaceMailFilteredMessage(
      providerMessageID: "spacemail-filtered-task-1",
      sourceMailboxID: mailboxID,
      sender: "offers@example.test",
      subject: "Final days",
      receivedDate: "Today",
      bodyPreview: "Marketing promotion that was filtered from mixed mailbox intake.",
      reason: "marketing",
      capturedDate: "Today"
    )
    let connection = makeSpaceMailConnection(
      id: mailboxID,
      credentialStorageStatus: "Password reference available",
      fetched: 10,
      imported: 0,
      filtered: 10,
      uncertain: 0
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = [connection]
    store.reviewTasks = []
    store.auditEvents = []

    store.createReviewTask(from: message, connection: connection)
    store.createReviewTask(from: message, connection: connection)

    let tasks = store.reviewTasks.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == mailboxID.uuidString
        && $0.summary.contains(message.providerMessageID)
    }
    XCTAssertEqual(tasks.count, 1)
    XCTAssertEqual(tasks.first?.assignee, "Mailbox team")
    XCTAssertEqual(tasks.first?.priority, .low)
    XCTAssertEqual(tasks.first?.reviewState, .needsReview)
    XCTAssertTrue(tasks.first?.summary.contains("Review filtered SpaceMail preview") == true)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Existing filtered SpaceMail preview review task refreshed."
        && (event.afterDetail?.contains("No duplicate task was created.") ?? false)
    })
  }

  func testSpaceMailPreviewTaskCreatesNewTaskAfterCompletedTask() {
    let mailboxID = UUID()
    let message = SpaceMailUncertainMessage(
      providerMessageID: "spacemail-preview-task-completed",
      sourceMailboxID: mailboxID,
      sender: "person@example.test",
      subject: "Possible delivery update",
      receivedDate: "Today",
      bodyPreview: "This may relate to a delivery but has no tracking number yet.",
      reason: "delivery-ish no id",
      capturedDate: "Today"
    )
    let connection = makeSpaceMailConnection(
      id: mailboxID,
      credentialStorageStatus: "Password reference available",
      fetched: 10,
      imported: 0,
      filtered: 9,
      uncertain: 1,
      uncertainMessages: [message]
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = [connection]
    store.reviewTasks = []
    store.auditEvents = []

    store.createReviewTask(from: message, connection: connection)
    guard let firstTask = store.reviewTasks.first else {
      XCTFail("Expected SpaceMail preview task.")
      return
    }
    store.completeReviewTask(firstTask)
    store.createReviewTask(from: message, connection: connection)

    let tasks = store.reviewTasks.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == mailboxID.uuidString
        && $0.summary.contains(message.providerMessageID)
    }
    XCTAssertEqual(tasks.count, 2)
    XCTAssertEqual(tasks.filter { $0.status == .completed }.count, 1)
    XCTAssertEqual(tasks.filter { $0.status == .open }.count, 1)
    XCTAssertEqual(tasks.filter { $0.priority == .normal }.count, 2)
    XCTAssertTrue(store.auditEvents.contains { $0.summary == "Review task completed." })
    XCTAssertTrue(store.auditEvents.contains { $0.summary == "Review task created from integration." })
  }

  func testSpaceMailUncertainPreviewDraftRefreshesExistingUnsentProviderMessageDraft() {
    let mailboxID = UUID()
    let message = SpaceMailUncertainMessage(
      providerMessageID: "spacemail-preview-draft-1",
      sourceMailboxID: mailboxID,
      sender: "sender@example.test",
      subject: "Delivery question",
      receivedDate: "Today",
      bodyPreview: "Can you check whether this relates to an order?",
      reason: "delivery-ish no id",
      capturedDate: "Today"
    )
    let connection = makeSpaceMailConnection(
      id: mailboxID,
      credentialStorageStatus: "Password reference available",
      fetched: 10,
      imported: 0,
      filtered: 9,
      uncertain: 1,
      uncertainMessages: [message]
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = [connection]
    store.draftMessages = []
    store.auditEvents = []

    store.createDraftMessage(from: message, connection: connection)
    store.draftMessages[0].status = .ready
    store.createDraftMessage(from: message, connection: connection)

    let drafts = store.draftMessages.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == mailboxID.uuidString
        && $0.body.contains(message.providerMessageID)
    }
    XCTAssertEqual(drafts.count, 1)
    XCTAssertEqual(drafts.first?.recipient, "sender@example.test")
    XCTAssertEqual(drafts.first?.status, .reopened)
    XCTAssertTrue(drafts.first?.body.contains("SpaceMail preview: uncertain") == true)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Existing SpaceMail preview draft refreshed."
        && (event.afterDetail?.contains("No duplicate draft was created.") ?? false)
    })
  }

  func testSpaceMailFilteredPreviewDraftCreatesNewDraftAfterSentLocally() {
    let mailboxID = UUID()
    let message = SpaceMailFilteredMessage(
      providerMessageID: "spacemail-filtered-draft-sent",
      sourceMailboxID: mailboxID,
      sender: "offers@example.test",
      subject: "Final days",
      receivedDate: "Today",
      bodyPreview: "Marketing promotion that was filtered from mixed mailbox intake.",
      reason: "marketing",
      capturedDate: "Today"
    )
    let connection = makeSpaceMailConnection(
      id: mailboxID,
      credentialStorageStatus: "Password reference available",
      fetched: 10,
      imported: 0,
      filtered: 10,
      uncertain: 0
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = [connection]
    store.draftMessages = []
    store.auditEvents = []

    store.createDraftMessage(from: message, connection: connection)
    store.draftMessages[0].status = .sentLocally
    store.createDraftMessage(from: message, connection: connection)

    let drafts = store.draftMessages.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == mailboxID.uuidString
        && $0.body.contains(message.providerMessageID)
    }
    XCTAssertEqual(drafts.count, 2)
    XCTAssertEqual(drafts.filter { $0.status == .sentLocally }.count, 1)
    XCTAssertEqual(drafts.filter { $0.status == .draft }.count, 1)
    XCTAssertTrue(drafts.allSatisfy { $0.body.contains("SpaceMail preview: filtered") })
    XCTAssertEqual(store.auditEvents.filter { $0.summary == "Draft message created from SpaceMail preview." }.count, 2)
  }

  private func makeOrder(
    orderNumber: String,
    trackingNumber: String,
    destination: String,
    checkedMailbox: String,
    source: IntakeSource,
    latestStatus: String
  ) -> TrackedOrder {
    TrackedOrder(
      orderNumber: orderNumber,
      store: "Test Store",
      recipientEmail: "recipient@example.com",
      checkedMailbox: checkedMailbox,
      customer: "Test Customer",
      fulfillment: .delivery,
      carrier: "Test Carrier",
      trackingNumber: trackingNumber,
      destination: destination,
      eta: "Tomorrow",
      source: source,
      status: .intake,
      reviewState: .needsReview,
      latestStatus: latestStatus,
      timeline: [],
      contactHistory: []
    )
  }

  private func makeReadyWishlistItem(
    optionID: UUID,
    itemName: String,
    sellerName: String,
    linkedOrderID: UUID?
  ) -> WishlistItem {
    let option = WishlistComparisonOption(
      id: optionID,
      sellerName: sellerName,
      productURL: "https://example.com/replacement-scanner",
      listedPrice: "99.00",
      currency: "AUD",
      estimatedAUDTotal: "AUD 109 delivered",
      postageCost: "AUD 10",
      postageTime: "3-5 business days",
      sellerRegion: "Australia",
      trustRating: "Trusted",
      trustNotes: "Returns and warranty visible.",
      recommendation: "Preferred seller",
      lastChecked: "Today",
      localScore: 90,
      riskLevel: "Lower risk",
      decisionReason: "Best landed cost and trust evidence."
    )

    return WishlistItem(
      itemName: itemName,
      storefront: sellerName,
      storefrontURL: option.productURL,
      estimatedCost: option.estimatedAUDTotal,
      owner: "Receiving desk",
      pool: "Operations",
      source: .manual,
      status: linkedOrderID == nil ? "Awaiting order confirmation" : "Order confirmation linked",
      capturedDetail: "Needed for receiving desk",
      comparisonStatus: "Options captured",
      comparisonNotes: "One strong seller option",
      purchaseReadiness: "Purchased externally; watch for confirmation",
      preferredOptionID: optionID,
      comparisonOptions: [option],
      purchaseChecks: [
        WishlistPurchaseCheck(title: "Readiness", status: "Passed", detail: "Checked locally", severity: "Low")
      ],
      purchaseDecision: WishlistPurchaseDecision(
        selectedOptionID: optionID,
        selectedSellerName: sellerName,
        decisionStatus: "Approved locally",
        totalAUDSummary: option.estimatedAUDTotal,
        postageSummary: "\(option.postageCost), \(option.postageTime)",
        trustSummary: option.trustRating,
        rejectedOptionsSummary: "None",
        decisionNotes: "Proceed outside ParcelOps.",
        decidedBy: "Operator",
        decidedDate: "Today",
        reviewState: .accepted
      ),
      purchaseHandoff: WishlistPurchaseHandoff(
        sellerName: sellerName,
        accountLabel: "Operations account",
        purchaseStatus: linkedOrderID == nil ? "Purchased externally, awaiting order confirmation" : "Inbox confirmation linked locally",
        expectedOrderSignals: "\(sellerName) | \(itemName) | order confirmation | order number | shipped | tracking",
        orderWatchStatus: "Watch Inbox and Orders for local confirmation email or order record.",
        linkedOrderID: linkedOrderID,
        notes: "No purchase in ParcelOps.",
        updatedAt: "Today"
      )
    )
  }

  private func resetWishlistState(_ store: ParcelOpsStore) {
    store.wishlistItems = []
    store.wishlistCaptureCandidates = []
    store.wishlistResearchRequests = []
    store.wishlistPriceSnapshots = []
    store.wishlistSellerQuotes = []
    store.wishlistPriceWatchRules = []
    store.wishlistSellerTrustRecords = []
    store.wishlistPurchaseAccountRecords = []
    store.wishlistPurchaseApprovalRecords = []
    store.wishlistPurchaseLinkRecords = []
    store.wishlistOrderWatchRecords = []
    store.deletedWishlistItems = []
  }

  private func resetWishlistOperationsTrail(_ store: ParcelOpsStore) {
    store.receivingInspections = []
    store.inventoryReceipts = []
    store.storageLocations = []
    store.custodyRecords = []
    store.labelReferenceRecords = []
    store.scanSessionRecords = []
    store.shipmentManifestRecords = []
    store.dispatchReadinessChecklists = []
  }

  private func stageWishlistOperationsTrail(_ store: ParcelOpsStore, for item: WishlistItem) {
    store.createWishlistReceivingInspection(item)
    store.createWishlistInventoryReceipt(item)
    store.createWishlistStorageLocation(item)
    store.createWishlistCustodyRecord(item)
    store.createWishlistLabelReference(item)
    store.createWishlistScanSession(item)
    store.createWishlistShipmentManifest(item)
    store.createWishlistDispatchReadinessChecklist(item)
  }

  private func makeWishlistPriceWatchRule(
    item: WishlistItem,
    targetAUDTotal: String,
    maxPostageCost: String,
    requiredTrustLevel: String,
    allowedRegions: String
  ) -> WishlistPriceWatchRule {
    WishlistPriceWatchRule(
      wishlistItemID: item.id,
      itemName: item.itemName,
      targetAUDTotal: targetAUDTotal,
      maxPostageCost: maxPostageCost,
      maximumDeliveryTime: "7 days",
      requiredTrustLevel: requiredTrustLevel,
      allowedRegions: allowedRegions,
      ruleStatus: "Watching locally",
      createdDate: "Today",
      lastEvaluatedDate: "Not evaluated",
      reviewState: .needsReview,
      notes: "Local test rule."
    )
  }

  private func makeWishlistSellerQuote(
    item: WishlistItem,
    sellerName: String,
    estimatedAUDTotal: String,
    postageCost: String,
    sellerRegion: String,
    trustSummary: String
  ) -> WishlistSellerQuote {
    WishlistSellerQuote(
      wishlistItemID: item.id,
      itemName: item.itemName,
      sellerName: sellerName,
      productURL: "https://example.com/replacement-scanner",
      listedPrice: "99.00",
      currency: "AUD",
      estimatedAUDTotal: estimatedAUDTotal,
      postageCost: postageCost,
      postageTime: "3-5 business days",
      sellerRegion: sellerRegion,
      trustSummary: trustSummary,
      returnsWarrantySummary: "Returns visible",
      quoteSource: "Manual",
      quoteStatus: "Captured locally",
      capturedDate: "Today",
      reviewState: .accepted,
      notes: "Local saved quote."
    )
  }

  private func makeSpaceMailConnection(
    id: UUID = UUID(),
    credentialStorageStatus: String,
    fetched: Int,
    imported: Int,
    filtered: Int,
    uncertain: Int,
    uncertainMessages: [SpaceMailUncertainMessage] = [],
    reasonBreakdown: [SpaceMailClassifierReasonCount] = []
  ) -> SpaceMailIMAPConnection {
    SpaceMailIMAPConnection(
      id: id,
      displayName: "SpaceMail tracking inbox",
      emailAddressUsername: "orders@example.test",
      imapHost: "mail.spacemail.com",
      imapPort: "993",
      securityMode: "SSL/TLS",
      folderName: "INBOX",
      connectionStatus: "Real IMAP: Fetch success",
      lastManualRefreshDate: "Today",
      setupNotes: "Local setup only",
      credentialStorageStatus: credentialStorageStatus,
      lastRefreshFetchedCount: fetched,
      lastRefreshImportedCount: imported,
      lastRefreshFilteredNonOrderCount: filtered,
      lastRefreshUncertainCount: uncertain,
      uncertainMessages: uncertainMessages,
      lastRefreshReasonBreakdown: reasonBreakdown,
      reviewState: .accepted
    )
  }

  private func makeGmailConnection(
    id: UUID = UUID(),
    oauthReadinessStatus: String,
    credentialStorageStatus: String,
    fetched: Int,
    imported: Int,
    filtered: Int,
    uncertain: Int?
  ) -> GmailMailboxConnection {
    GmailMailboxConnection(
      id: id,
      displayName: "Gmail tracking inbox",
      emailAddress: "orders@example.test",
      monitoredLabelNames: "INBOX",
      connectionStatus: "Placeholder configured",
      lastManualRefreshDate: "Never",
      setupNotes: "Local setup only",
      oauthReadinessStatus: oauthReadinessStatus,
      oauthClientIDPlaceholder: "placeholder-client-id",
      redirectURIPlaceholder: "placeholder-callback-scheme",
      requestedScopesSummary: "openid email profile https://www.googleapis.com/auth/gmail.readonly",
      credentialStorageStatus: credentialStorageStatus,
      lastRefreshFetchedCount: fetched,
      lastRefreshImportedCount: imported,
      lastRefreshFilteredNonOrderCount: filtered,
      lastRefreshUncertainCount: uncertain,
      reviewState: .needsReview
    )
  }
}
