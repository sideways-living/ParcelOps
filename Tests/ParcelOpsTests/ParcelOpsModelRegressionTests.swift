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

  func testInboxDispatchSetupDoesNotCreateDuplicateRecords() {
    let order = makeOrder(
      orderNumber: "TEST-123",
      trackingNumber: "ABC123",
      destination: "Brisbane QLD",
      checkedMailbox: "caught@droctopus.net",
      source: .forwardedMailbox,
      latestStatus: "Created from verified Inbox intake"
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.orders = [order]
    store.shipmentManifestRecords = []
    store.dispatchReadinessChecklists = []
    store.auditEvents = []

    store.createDispatchSetup(for: order)
    store.createDispatchSetup(for: order)

    let manifests = store.suggestedShipmentManifestRecords(for: order).filter(\.isInboxHandoffSetup)
    let checklists = store.suggestedDispatchReadinessChecklists(for: order).filter(\.isInboxHandoffSetup)

    XCTAssertEqual(manifests.count, 1)
    XCTAssertEqual(checklists.count, 1)
    XCTAssertEqual(manifests.first?.includedOrderIDs, [order.id])
    XCTAssertEqual(checklists.first?.orderIDs, [order.id])
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Dispatch setup already exists for Inbox-created order."
        && (event.afterDetail?.contains("No duplicate dispatch records were created.") ?? false)
    })
  }

  func testInboxDispatchReopenCreatesSingleFollowUpTaskAndCompletionResolvesIt() throws {
    let order = makeOrder(
      orderNumber: "TEST-456",
      trackingNumber: "TRACK-456",
      destination: "Melbourne VIC",
      checkedMailbox: "caught@droctopus.net",
      source: .forwardedMailbox,
      latestStatus: "Created from verified Inbox intake"
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.orders = [order]
    store.shipmentManifestRecords = []
    store.dispatchReadinessChecklists = []
    store.reviewTasks = []
    store.auditEvents = []

    store.createDispatchSetup(for: order)
    store.completeInboxDispatchHandoff(for: order)
    store.reopenInboxDispatchHandoff(for: order)
    store.reopenInboxDispatchHandoff(for: order)

    let reopenTasks = store.reviewTasks.filter {
      $0.linkedEntityType == .order
        && $0.linkedEntityID == order.id.uuidString
        && $0.summary.localizedCaseInsensitiveContains("Reopened Inbox dispatch handoff")
    }
    XCTAssertEqual(reopenTasks.count, 1)
    XCTAssertEqual(reopenTasks.first?.status, .open)
    XCTAssertEqual(store.shipmentManifestRecords.first?.dispatchStatus, .reopened)
    XCTAssertEqual(store.dispatchReadinessChecklists.first?.checklistStatus, .reopened)

    store.completeInboxDispatchHandoff(for: order)

    let completedTask = try XCTUnwrap(store.reviewTasks.first {
      $0.linkedEntityID == order.id.uuidString
        && $0.summary.localizedCaseInsensitiveContains("Reopened Inbox dispatch handoff")
    })
    XCTAssertEqual(completedTask.status, .completed)
    XCTAssertEqual(store.shipmentManifestRecords.first?.dispatchStatus, .handedOff)
    XCTAssertEqual(store.dispatchReadinessChecklists.first?.checklistStatus, .completed)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Reopened Inbox dispatch handoff task resolved."
    })
  }

  func testInboxDispatchCompletionStopsWhenLinkedDispatchRecordsAreBlocked() throws {
    let order = makeOrder(
      orderNumber: "TEST-789",
      trackingNumber: "TRACK-789",
      destination: "Sydney NSW",
      checkedMailbox: "caught@droctopus.net",
      source: .forwardedMailbox,
      latestStatus: "Created from verified Inbox intake"
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.orders = [order]
    store.shipmentManifestRecords = []
    store.dispatchReadinessChecklists = []
    store.auditEvents = []

    store.createDispatchSetup(for: order)
    store.shipmentManifestRecords[0].dispatchStatus = .blockedNeedsReview
    store.dispatchReadinessChecklists[0].checklistStatus = .blockedNeedsReview
    let latestStatusBeforeCompletion = try XCTUnwrap(store.orders.first).latestStatus

    store.completeInboxDispatchHandoff(for: order)

    let updatedOrder = try XCTUnwrap(store.orders.first)
    XCTAssertEqual(updatedOrder.latestStatus, latestStatusBeforeCompletion)
    XCTAssertEqual(updatedOrder.status, .intake)
    XCTAssertEqual(updatedOrder.reviewState, .needsReview)
    XCTAssertEqual(store.shipmentManifestRecords.first?.dispatchStatus, .blockedNeedsReview)
    XCTAssertEqual(store.dispatchReadinessChecklists.first?.checklistStatus, .blockedNeedsReview)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Inbox dispatch handoff completion blocked."
        && (event.afterDetail?.contains("Resolve blocked dispatch records before completing handoff.") ?? false)
    })
  }

  func testInboxDispatchCompleteAndReopenSkipBeforeSetupExists() throws {
    let order = makeOrder(
      orderNumber: "TEST-000",
      trackingNumber: "TRACK-000",
      destination: "Perth WA",
      checkedMailbox: "caught@droctopus.net",
      source: .forwardedMailbox,
      latestStatus: "Created from verified Inbox intake"
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.orders = [order]
    store.shipmentManifestRecords = []
    store.dispatchReadinessChecklists = []
    store.reviewTasks = []
    store.auditEvents = []

    store.completeInboxDispatchHandoff(for: order)
    store.reopenInboxDispatchHandoff(for: order)

    let updatedOrder = try XCTUnwrap(store.orders.first)
    XCTAssertEqual(updatedOrder.latestStatus, "Created from verified Inbox intake")
    XCTAssertEqual(updatedOrder.status, .intake)
    XCTAssertTrue(store.shipmentManifestRecords.isEmpty)
    XCTAssertTrue(store.dispatchReadinessChecklists.isEmpty)
    XCTAssertTrue(store.reviewTasks.isEmpty)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Inbox dispatch handoff completion skipped."
        && (event.afterDetail?.contains("No linked Inbox dispatch manifest or readiness checklist was found.") ?? false)
    })
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Inbox dispatch handoff reopen skipped."
        && (event.afterDetail?.contains("No linked Inbox dispatch manifest or readiness checklist was found.") ?? false)
    })
  }

  func testInboxDispatchSetupStopsWhenInboxOrderFieldsAreMissing() throws {
    let order = makeOrder(
      orderNumber: "Pending",
      trackingNumber: "Pending",
      destination: "Destination needs review",
      checkedMailbox: "caught@droctopus.net",
      source: .forwardedMailbox,
      latestStatus: "Created from partial Inbox intake"
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.orders = [order]
    store.shipmentManifestRecords = []
    store.dispatchReadinessChecklists = []
    store.auditEvents = []

    store.createDispatchSetup(for: order)

    let updatedOrder = try XCTUnwrap(store.orders.first)
    XCTAssertEqual(updatedOrder.latestStatus, "Created from partial Inbox intake")
    XCTAssertEqual(updatedOrder.status, .intake)
    XCTAssertTrue(store.shipmentManifestRecords.isEmpty)
    XCTAssertTrue(store.dispatchReadinessChecklists.isEmpty)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Dispatch setup blocked by missing Inbox handoff fields."
        && (event.afterDetail?.contains("Missing fields: order number, tracking number, destination") ?? false)
        && (event.afterDetail?.contains("No dispatch records were created.") ?? false)
    })
  }

  func testIntakeParserRegressionSamplesStayGreen() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let results = store.intakeParserRegressionResults

    XCTAssertFalse(results.isEmpty)
    XCTAssertTrue(results.allSatisfy(\.passed), results.map(\.detail).joined(separator: "\n"))

    let clearOrder = try XCTUnwrap(results.first { $0.id == "clear-order-shipped" })
    XCTAssertEqual(clearOrder.detectedOrderNumber, "TEST-123")
    XCTAssertEqual(clearOrder.detectedTrackingNumber, "ABC123")

    let trackingOnly = try XCTUnwrap(results.first { $0.id == "tracking-only-update" })
    XCTAssertTrue(trackingOnly.detectedOrderNumber.isPlaceholderValidationValue)
    XCTAssertEqual(trackingOnly.detectedTrackingNumber, "ZXCV123456789")

    let marketing = try XCTUnwrap(results.first { $0.id == "encoded-subject" })
    XCTAssertTrue(marketing.detectedOrderNumber.isPlaceholderValidationValue)
    XCTAssertTrue(marketing.detectedTrackingNumber.isPlaceholderValidationValue)
  }

  func testFetchedMailboxMessageImportsClearOrderAndTrackingSignals() throws {
    let sourceMailboxID = UUID()
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.intakeEmails = []
    store.mailboxIngestRecords = []
    store.auditEvents = []

    let result = store.importFetchedMailboxMessages([
      FetchedMailboxMessage(
        providerMessageID: "provider-clear-order-001",
        sender: "orders@example-shop.test",
        subject: "Order TEST-123 shipped tracking ABC123",
        receivedDate: "Today",
        plainTextBodyPreview: "Order TEST-123 shipped tracking ABC123",
        sourceMailboxID: sourceMailboxID
      )
    ])

    XCTAssertEqual(result.imported, 1)
    XCTAssertEqual(result.duplicates, 0)

    let email = try XCTUnwrap(store.intakeEmails.first)
    XCTAssertEqual(email.sender, "orders@example-shop.test")
    XCTAssertEqual(email.subject, "Order TEST-123 shipped tracking ABC123")
    XCTAssertEqual(email.detectedOrderNumber, "TEST-123")
    XCTAssertEqual(email.detectedTrackingNumber, "ABC123")
    XCTAssertEqual(email.reviewState, .needsReview)

    let ingestRecord = try XCTUnwrap(store.mailboxIngestRecords.first)
    XCTAssertEqual(ingestRecord.providerMessageID, "provider-clear-order-001")
    XCTAssertEqual(ingestRecord.sourceMailboxID, sourceMailboxID)
    XCTAssertEqual(ingestRecord.intakeEmailID, email.id)
    XCTAssertEqual(ingestRecord.status, .imported)
  }

  func testDuplicateFetchedMailboxRefreshUpdatesMessyExistingIntakeWithoutDuplicating() throws {
    let sourceMailboxID = UUID()
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let staleIntakeID = UUID()
    store.intakeEmails = [
      ForwardedEmailIntake(
        id: staleIntakeID,
        sender: "Unknown Sender",
        subject: "No subject",
        receivedDate: "Unknown date",
        rawBodyPreview: "* 39763 FETCH (UID 39763 BODY[] {4096} Return-Path: <orders@example-shop.test> Dovecot internal routing text",
        detectedMerchant: "Unknown Sender",
        detectedOrderNumber: "Order number needs review",
        detectedTrackingNumber: "Tracking number needs review",
        detectedDestinationAddress: "Destination needs review",
        linkedOrderID: nil,
        reviewState: .needsReview
      )
    ]
    store.mailboxIngestRecords = [
      MailboxIngestRecord(
        providerMessageID: "provider-clear-order-duplicate",
        sourceMailboxID: sourceMailboxID,
        intakeEmailID: staleIntakeID,
        capturedDate: "Earlier",
        status: .imported,
        summary: "Imported fetched mailbox message: No subject"
      )
    ]
    store.auditEvents = []

    let result = store.importFetchedMailboxMessages([
      FetchedMailboxMessage(
        providerMessageID: "provider-clear-order-duplicate",
        sender: "orders@example-shop.test",
        subject: "Order TEST-123 shipped tracking ABC123",
        receivedDate: "Today",
        plainTextBodyPreview: "Order TEST-123 shipped tracking ABC123",
        sourceMailboxID: sourceMailboxID
      )
    ])

    XCTAssertEqual(result.imported, 0)
    XCTAssertEqual(result.duplicates, 1)
    XCTAssertEqual(store.intakeEmails.count, 1)

    let refreshed = try XCTUnwrap(store.intakeEmails.first)
    XCTAssertEqual(refreshed.id, staleIntakeID)
    XCTAssertEqual(refreshed.sender, "orders@example-shop.test")
    XCTAssertEqual(refreshed.subject, "Order TEST-123 shipped tracking ABC123")
    XCTAssertEqual(refreshed.detectedOrderNumber, "TEST-123")
    XCTAssertEqual(refreshed.detectedTrackingNumber, "ABC123")
    XCTAssertEqual(refreshed.reviewState, .needsReview)

    let latestIngestRecord = try XCTUnwrap(store.mailboxIngestRecords.first)
    XCTAssertEqual(latestIngestRecord.status, .duplicateRefreshed)
    XCTAssertEqual(latestIngestRecord.intakeEmailID, staleIntakeID)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Duplicate fetched mailbox message refreshed existing intake email."
        && (event.afterDetail?.contains("No duplicate intake email was created") ?? false)
    })
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
    XCTAssertEqual(summary.operationsClosureGapCount, 0)
  }

  func testWishlistSharedCountsMatchSourceCollections() {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    resetWishlistState(store)
    store.wishlistItems = [item]
    store.wishlistResearchRequests = [
      WishlistResearchRequest(
        wishlistItemID: item.id,
        itemName: item.itemName,
        sourceURL: "",
        regionScope: "",
        sellerCriteria: "",
        maxBudgetAUD: "",
        postageRequirements: "",
        trustRequirements: "",
        requestStatus: "Needs scope review",
        createdDate: "Today",
        lastReviewedDate: "Never",
        reviewState: .needsReview,
        notes: "Local regression fixture."
      )
    ]
    store.reviewTasks = [
      ReviewTask(
        title: "Review Wishlist handoff",
        summary: "Confirm local purchase handoff context.",
        linkedEntityType: .wishlistItem,
        linkedEntityID: item.id.uuidString,
        priority: .normal,
        dueDate: "Today",
        assignee: "Operations",
        status: .open,
        createdDate: "Today",
        completedDate: nil,
        reviewState: .needsReview
      )
    ]
    store.handoffNotes = [
      HandoffNote(
        title: "Wishlist handoff note",
        summary: "Follow local handoff before purchase.",
        linkedEntityType: .wishlistItem,
        linkedEntityID: item.id.uuidString,
        priority: .normal,
        assignee: "Operations",
        createdDate: "Today",
        dueDate: "Today",
        status: .open,
        reviewState: .needsReview,
        notes: "Local regression fixture."
      )
    ]
    store.draftMessages = [
      DraftMessage(
        linkedEntityType: .wishlistItem,
        linkedEntityID: item.id.uuidString,
        templateID: nil,
        recipient: "ops@example.test",
        subject: "Wishlist purchase packet ready",
        body: "Local packet draft.",
        channel: .email,
        createdDate: "Today",
        status: .draft,
        reviewState: .needsReview
      ),
      DraftMessage(
        linkedEntityType: .wishlistItem,
        linkedEntityID: "wishlist-research-batch",
        templateID: nil,
        recipient: "ops@example.test",
        subject: "Wishlist batch research brief",
        body: "Local batch draft.",
        channel: .email,
        createdDate: "Today",
        status: .draft,
        reviewState: .needsReview
      )
    ]

    XCTAssertEqual(store.wishlistTaskContextItemCount, 1)
    XCTAssertEqual(store.wishlistTaskContextItemCount, store.wishlistTaskContextItems.count)
    XCTAssertEqual(store.wishlistResearchAttentionRequestCount, store.wishlistResearchAttentionRequests.count)
    XCTAssertEqual(store.wishlistBatchResearchDraftCount, store.wishlistBatchResearchDrafts.count)
    XCTAssertEqual(store.wishlistPurchasePacketDraftCount, store.wishlistPurchasePacketDrafts.count)
    XCTAssertEqual(store.activeWishlistReviewTaskCount, store.activeWishlistReviewTasks.count)
    XCTAssertEqual(store.activeWishlistHandoffNoteCount, store.activeWishlistHandoffNotes.count)
    XCTAssertEqual(store.activeWishlistDraftMessageCount, store.activeWishlistDraftMessages.count)
    XCTAssertEqual(store.wishlistAwaitingOrderItemCount, 1)
    XCTAssertEqual(store.wishlistAwaitingOrderItemCount, store.wishlistAwaitingOrderItems.count)
    XCTAssertEqual(store.wishlistDashboardAttentionItemCount, store.wishlistDashboardAttentionItems.count)
    XCTAssertGreaterThan(store.wishlistTaskActionCount, 0)
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
    XCTAssertEqual(summary.operationsClosureGapCount, 0)
    XCTAssertEqual(orderWatchItem?.status, "1 open")
    XCTAssertEqual(orderWatchItem?.tone, "attention")
    XCTAssertTrue(orderWatchItem?.detail.contains("order confirmation") == true)
  }

  func testWishlistDailyAttentionCountMatchesComponentCounts() {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    resetWishlistState(store)
    store.wishlistItems = [item]

    let expected =
      store.wishlistUniqueAttentionItemCount
      + store.wishlistResearchAttentionRequestCount
      + (store.wishlistBatchBriefNeeded ? 1 : 0)

    XCTAssertEqual(store.wishlistDailyAttentionCount, expected)
    XCTAssertGreaterThan(store.wishlistDailyAttentionCount, 0)
  }

  func testWishlistDashboardSummaryHighlightsPurchasePacketBlocker() {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    resetWishlistState(store)
    store.wishlistItems = [item]

    XCTAssertEqual(store.wishlistAttentionBlockerSummary, "purchase packet needed (1)")
    XCTAssertEqual(store.wishlistDashboardNextAction, "Clear: purchase packet needed (1)")
    XCTAssertTrue(store.wishlistDashboardAttentionInsight?.contains("need a local purchase packet draft") == true)
    XCTAssertTrue(store.wishlistDashboardCardDetail.contains("Top blockers: purchase packet needed (1)"))
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
    XCTAssertEqual(summary.operationsClosureGapCount, 0)
    XCTAssertEqual(orderWatchItem?.status, "No open watch gaps")
    XCTAssertEqual(orderWatchItem?.tone, "success")
    XCTAssertTrue(orderWatchItem?.detail.contains("No current Wishlist handoff") == true)
  }

  func testWishlistAgentReadinessSummaryFlagsLinkedOrderClosureGaps() {
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

    let summary = store.wishlistAgentReadinessSummary
    let operationsItem = summary.items.first { $0.title == "Operations closure trail" }

    XCTAssertEqual(summary.title, "Wishlist agent path needs operator review")
    XCTAssertEqual(summary.tone, "attention")
    XCTAssertEqual(summary.operationsClosureGapCount, 1)
    XCTAssertEqual(operationsItem?.status, "1 gap")
    XCTAssertEqual(operationsItem?.tone, "attention")
    XCTAssertTrue(operationsItem?.detail.contains("Linked Wishlist orders still need local operations evidence") == true)
    XCTAssertTrue(operationsItem?.nextAction.contains("receiving, inventory") == true)
  }

  func testWishlistAgentReadinessSummaryClearsCompleteOperationsTrail() {
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

    let summary = store.wishlistAgentReadinessSummary
    let operationsItem = summary.items.first { $0.title == "Operations closure trail" }

    XCTAssertEqual(summary.operationsClosureGapCount, 0)
    XCTAssertEqual(operationsItem?.status, "Closure trail clear")
    XCTAssertEqual(operationsItem?.tone, "success")
    XCTAssertTrue(operationsItem?.detail.contains("receiving, inventory, storage") == true)
    XCTAssertTrue(operationsItem?.nextAction.contains("Close the Wishlist item locally") == true)
  }

  func testWishlistAgentReadinessSnapshotLogsWithoutCreatingWork() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    resetWishlistState(store)
    store.wishlistItems = [item]
    store.reviewTasks = []
    store.draftMessages = []
    store.auditEvents = []

    let beforeItemIDs = store.wishlistItems.map(\.id)

    store.recordWishlistAgentReadinessSnapshot()

    XCTAssertEqual(store.wishlistItems.map(\.id), beforeItemIDs)
    XCTAssertTrue(store.reviewTasks.isEmpty)
    XCTAssertTrue(store.draftMessages.isEmpty)
    let event = try XCTUnwrap(store.auditEvents.first)
    XCTAssertEqual(store.auditEvents.count, 1)
    XCTAssertEqual(event.action, .evaluated)
    XCTAssertEqual(event.entityType, .wishlistItem)
    XCTAssertEqual(event.entityID, "wishlist-agent-readiness")
    XCTAssertEqual(event.summary, "Wishlist agent readiness snapshot recorded for operator review.")
    XCTAssertTrue(event.afterDetail?.contains("Order watch gaps: 1") == true)
    XCTAssertTrue(event.afterDetail?.contains("Post-purchase order watch: 1 open") == true)
    XCTAssertTrue(event.afterDetail?.contains("No web search, browser automation, retailer comparison") == true)
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
    XCTAssertEqual(store.activeWishlistOrderWatchRecordCount, 2)
    XCTAssertEqual(store.openWishlistOrderWatchRecordCount, 1)
  }

  func testWishlistOrderWatchBatchSkipsBlockedRecords() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
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
    store.wishlistItems = [item]
    store.addWishlistOrderWatchRecord(item)
    let record = try XCTUnwrap(store.wishlistOrderWatchRecords.first)
    store.blockWishlistOrderWatchRecord(record)
    store.auditEvents = []

    store.checkOpenWishlistOrderWatchRecords()

    let blockedRecord = try XCTUnwrap(store.wishlistOrderWatchRecords.first)
    let blockedItem = try XCTUnwrap(store.wishlistItems.first)

    XCTAssertNil(blockedRecord.linkedOrderID)
    XCTAssertEqual(blockedRecord.watchStatus, "Blocked locally")
    XCTAssertEqual(blockedRecord.reviewState, .needsReview)
    XCTAssertNil(blockedItem.purchaseHandoff?.linkedOrderID)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Wishlist order watch batch check found no open records."
        && event.afterDetail?.contains("Open watch rules checked: 0") == true
    })
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
    XCTAssertEqual(store.activeWishlistOrderWatchRecordCount, 2)
    XCTAssertEqual(store.openWishlistOrderWatchRecordCount, 2)

    store.blockWishlistOrderWatchRecord(reviewedUnlinked)

    reviewedUnlinked = try XCTUnwrap(store.wishlistOrderWatchRecords.first { $0.wishlistItemID == unlinkedItem.id })
    XCTAssertEqual(reviewedUnlinked.watchStatus, "Blocked locally")
    XCTAssertEqual(reviewedUnlinked.reviewState, .needsReview)
    XCTAssertEqual(store.activeWishlistOrderWatchRecordCount, 2)
    XCTAssertEqual(store.openWishlistOrderWatchRecordCount, 2)
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
    XCTAssertEqual(store.activeWishlistOrderWatchRecordCount, 1)
    XCTAssertEqual(store.openWishlistOrderWatchRecordCount, 1)

    store.removeWishlistOrderWatchRecord(record)

    XCTAssertTrue(store.wishlistOrderWatchRecords.isEmpty)
    XCTAssertEqual(store.activeWishlistOrderWatchRecordCount, 0)
    XCTAssertEqual(store.openWishlistOrderWatchRecordCount, 0)
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
    XCTAssertEqual(task.status, .open)
    XCTAssertEqual(task.priority, .urgent)
    XCTAssertTrue(task.summary.contains("Inbox candidates: 1"))
    XCTAssertTrue(task.summary.contains("TEST-123"))
    XCTAssertTrue(store.auditEvents.contains { $0.summary == "Wishlist order confirmation follow-up task refreshed locally." })
  }

  func testWishlistOrderWatchCompletesCandidateTaskAfterOrderMatch() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    let candidate = ForwardedEmailIntake(
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
    let order = makeOrder(
      orderNumber: "TEST-123",
      trackingNumber: "ABC123",
      destination: "Brisbane QLD",
      checkedMailbox: "caught@droctopus.net",
      source: .forwardedMailbox,
      latestStatus: "Known Australian retailer Replacement scanner shipped with tracking ABC123."
    )
    resetWishlistState(store)
    store.wishlistItems = [item]
    store.orders = []
    store.intakeEmails = [candidate]
    store.reviewTasks = []
    store.auditEvents = []

    store.addWishlistOrderWatchRecord(item)
    let pendingRecord = try XCTUnwrap(store.wishlistOrderWatchRecords.first)
    store.checkWishlistOrderWatchRecord(pendingRecord)

    var task = try XCTUnwrap(store.reviewTasks.first)
    XCTAssertEqual(task.status, .open)
    XCTAssertEqual(task.priority, .urgent)
    XCTAssertTrue(task.summary.contains("Inbox candidates: 1"))

    store.orders = [order]
    let openRecord = try XCTUnwrap(store.wishlistOrderWatchRecords.first)
    store.checkWishlistOrderWatchRecord(openRecord)

    let matchedRecord = try XCTUnwrap(store.wishlistOrderWatchRecords.first)
    let matchedItem = try XCTUnwrap(store.wishlistItems.first)
    task = try XCTUnwrap(store.reviewTasks.first)

    XCTAssertEqual(matchedRecord.linkedOrderID, order.id)
    XCTAssertEqual(matchedRecord.watchStatus, "Matched local order")
    XCTAssertEqual(matchedRecord.reviewState, .accepted)
    XCTAssertEqual(matchedItem.purchaseHandoff?.linkedOrderID, order.id)
    XCTAssertEqual(task.status, .completed)
    XCTAssertEqual(task.reviewState, .accepted)
    XCTAssertTrue(task.summary.contains("matched order \(order.orderNumber)"))
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Wishlist order confirmation follow-up task completed after local order match."
        && event.afterDetail?.contains(order.orderNumber) == true
    })
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

  func testWishlistClosureReadinessBatchRefreshesExistingTaskForGaps() throws {
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
    store.checkWishlistOperationsClosureReadinessBatch()

    let closureTask = try XCTUnwrap(store.reviewTasks.first)

    XCTAssertEqual(store.reviewTasks.count, 1)
    XCTAssertEqual(closureTask.linkedEntityType, .wishlistItem)
    XCTAssertEqual(closureTask.linkedEntityID, "wishlist-closure-readiness-batch")
    XCTAssertEqual(closureTask.title, "Follow up Wishlist closure readiness")
    XCTAssertTrue(closureTask.summary.contains("closure gaps"))
    XCTAssertTrue(closureTask.summary.contains("local only"))
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Wishlist closure readiness follow-up task refreshed locally."
        && event.afterDetail?.contains("updated instead of duplicated") == true
    })
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

  func testWishlistPriceQuoteAndWatchRecordsFallbackToBestScoredSellerWhenNoPreferenceIsSet() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let (item, trustedOption) = try makeWishlistItemWithRiskyFirstOption()
    resetWishlistState(store)
    store.wishlistItems = [item]

    store.addWishlistPriceSnapshot(item)
    store.addWishlistSellerQuotePlaceholder(item)
    store.addWishlistPriceWatchRule(item)

    let snapshot = try XCTUnwrap(store.wishlistPriceSnapshots.first)
    let quote = try XCTUnwrap(store.wishlistSellerQuotes.first)
    let rule = try XCTUnwrap(store.wishlistPriceWatchRules.first)

    XCTAssertEqual(snapshot.sellerName, "Known Australian retailer")
    XCTAssertEqual(snapshot.productURL, trustedOption.productURL)
    XCTAssertEqual(snapshot.estimatedAUDTotal, "AUD 109 delivered")
    XCTAssertEqual(snapshot.trustSignal, "Trusted")
    XCTAssertEqual(quote.sellerName, "Known Australian retailer")
    XCTAssertEqual(quote.productURL, trustedOption.productURL)
    XCTAssertEqual(quote.trustSummary, "Trusted")
    XCTAssertEqual(rule.targetAUDTotal, "AUD 109 delivered")
    XCTAssertEqual(rule.maxPostageCost, "AUD 10")
    XCTAssertEqual(rule.requiredTrustLevel, "Trusted")
    XCTAssertEqual(rule.allowedRegions, "Australia")
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

  func testWishlistPurchaseDecisionDoesNotPreferCheapRiskySellerOverExplicitTrustedChoice() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    let trustedOptionID = UUID()
    var item = makeReadyWishlistItem(
      optionID: trustedOptionID,
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    let riskyCheapOption = WishlistComparisonOption(
      sellerName: "Too-cheap overseas marketplace",
      productURL: "https://example-risk.test/replacement-scanner",
      listedPrice: "18.00",
      currency: "USD",
      estimatedAUDTotal: "AUD 39 delivered",
      postageCost: "AUD 0",
      postageTime: "21-45 business days",
      sellerRegion: "Overseas",
      trustRating: "Unknown",
      trustNotes: "No returns, warranty, delivery history, or seller identity evidence.",
      recommendation: "Reject unless verified manually",
      lastChecked: "Today",
      localScore: 22,
      riskLevel: "High risk",
      decisionReason: "Cheap but unsafe delivery and trust profile."
    )
    item.comparisonOptions?.insert(riskyCheapOption, at: 0)
    item.preferredOptionID = trustedOptionID
    item.purchaseDecision = nil
    resetWishlistState(store)
    store.wishlistItems = [item]

    store.createWishlistPurchaseDecision(item)

    let decision = try XCTUnwrap(store.wishlistItems.first?.purchaseDecision)

    XCTAssertEqual(decision.selectedOptionID, trustedOptionID)
    XCTAssertEqual(decision.selectedSellerName, "Known Australian retailer")
    XCTAssertTrue(decision.rejectedOptionsSummary.contains("Too-cheap overseas marketplace"))
    XCTAssertTrue(decision.rejectedOptionsSummary.contains("trust Unknown"))
    XCTAssertFalse(decision.selectedSellerName.localizedCaseInsensitiveContains("Too-cheap"))
  }

  func testWishlistPurchaseDecisionFallsBackToBestScoredSellerWhenNoPreferenceIsSet() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    var item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    let riskyFirstOption = WishlistComparisonOption(
      sellerName: "First cheap risky seller",
      productURL: "https://risk-first.example/scanner",
      listedPrice: "18.00",
      currency: "USD",
      estimatedAUDTotal: "AUD 39 delivered",
      postageCost: "AUD 0",
      postageTime: "21-45 business days",
      sellerRegion: "Overseas",
      trustRating: "Unknown",
      trustNotes: "No returns or warranty evidence.",
      recommendation: "Do not prefer without review",
      lastChecked: "Today",
      localScore: 20,
      riskLevel: "High risk",
      decisionReason: "Cheap but poor trust evidence."
    )
    let trustedOption = try XCTUnwrap(item.comparisonOptions?.first)
    item.comparisonOptions = [riskyFirstOption, trustedOption]
    item.preferredOptionID = nil
    item.purchaseDecision = nil
    resetWishlistState(store)
    store.wishlistItems = [item]

    store.createWishlistPurchaseDecision(item)

    let decision = try XCTUnwrap(store.wishlistItems.first?.purchaseDecision)

    XCTAssertEqual(decision.selectedSellerName, "Known Australian retailer")
    XCTAssertEqual(decision.selectedOptionID, trustedOption.id)
    XCTAssertTrue(decision.rejectedOptionsSummary.contains("First cheap risky seller"))
    XCTAssertFalse(decision.selectedSellerName.localizedCaseInsensitiveContains("cheap risky"))
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
    XCTAssertEqual(store.activeWishlistOrderWatchRecordCount, 1)
    XCTAssertEqual(store.openWishlistOrderWatchRecordCount, 1)
    XCTAssertEqual(watchRecord.wishlistItemID, item.id)
    XCTAssertTrue(watchRecord.expectedOrderSignals.contains("Known Australian retailer"))
    XCTAssertTrue(watchRecord.expectedOrderSignals.contains("Replacement scanner"))
    XCTAssertEqual(updatedItem.status, "Awaiting order confirmation")
    XCTAssertEqual(updatedItem.purchaseReadiness, "Order watch rule refreshed locally")
    XCTAssertEqual(updatedItem.purchaseHandoff?.purchaseStatus, "Purchased externally, awaiting order confirmation")
  }

  func testWishlistPurchaseHandoffFallsBackToBestScoredSellerWhenNoPreferenceIsSet() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    var item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    let riskyFirstOption = WishlistComparisonOption(
      sellerName: "First cheap risky seller",
      productURL: "https://risk-first.example/scanner",
      listedPrice: "18.00",
      currency: "USD",
      estimatedAUDTotal: "AUD 39 delivered",
      postageCost: "AUD 0",
      postageTime: "21-45 business days",
      sellerRegion: "Overseas",
      trustRating: "Unknown",
      trustNotes: "No returns or warranty evidence.",
      recommendation: "Do not prefer without review",
      lastChecked: "Today",
      localScore: 20,
      riskLevel: "High risk",
      decisionReason: "Cheap but poor trust evidence."
    )
    let trustedOption = try XCTUnwrap(item.comparisonOptions?.first)
    item.comparisonOptions = [riskyFirstOption, trustedOption]
    item.preferredOptionID = nil
    item.purchaseHandoff = nil
    resetWishlistState(store)
    store.wishlistItems = [item]
    store.wishlistOrderWatchRecords = []

    store.prepareWishlistPurchaseHandoff(item)

    let handoff = try XCTUnwrap(store.wishlistItems.first?.purchaseHandoff)
    let watchRecord = try XCTUnwrap(store.wishlistOrderWatchRecords.first)

    XCTAssertEqual(handoff.sellerName, "Known Australian retailer")
    XCTAssertTrue(handoff.expectedOrderSignals.contains(trustedOption.productURL))
    XCTAssertFalse(handoff.expectedOrderSignals.localizedCaseInsensitiveContains("risk-first"))
    XCTAssertTrue(watchRecord.expectedOrderSignals.contains("Known Australian retailer"))
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

  func testWishlistPurchasePacketDraftFallsBackToBestScoredSellerWhenNoPreferenceIsSet() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    var item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    let riskyFirstOption = WishlistComparisonOption(
      sellerName: "First cheap risky seller",
      productURL: "https://risk-first.example/scanner",
      listedPrice: "18.00",
      currency: "USD",
      estimatedAUDTotal: "AUD 39 delivered",
      postageCost: "AUD 0",
      postageTime: "21-45 business days",
      sellerRegion: "Overseas",
      trustRating: "Unknown",
      trustNotes: "No returns or warranty evidence.",
      recommendation: "Do not prefer without review",
      lastChecked: "Today",
      localScore: 20,
      riskLevel: "High risk",
      decisionReason: "Cheap but poor trust evidence."
    )
    let trustedOption = try XCTUnwrap(item.comparisonOptions?.first)
    item.comparisonOptions = [riskyFirstOption, trustedOption]
    item.preferredOptionID = nil
    item.purchaseDecision = nil
    resetWishlistState(store)
    store.wishlistItems = [item]
    store.draftMessages = []

    store.createWishlistPurchasePacketDraft(item)

    let draft = try XCTUnwrap(store.draftMessages.first)
    let decision = try XCTUnwrap(store.wishlistItems.first?.purchaseDecision)

    XCTAssertEqual(decision.selectedSellerName, "Known Australian retailer")
    XCTAssertTrue(draft.body.contains("Selected seller:\nKnown Australian retailer"))
    XCTAssertTrue(draft.body.contains(trustedOption.productURL))
    XCTAssertTrue(draft.body.contains("First cheap risky seller"))
    XCTAssertFalse(draft.body.contains("Selected seller:\nFirst cheap risky seller"))
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

  func testWishlistPurchaseLinkRecordFallsBackToBestScoredSellerWhenNoPreferenceIsSet() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    var item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    let riskyFirstOption = WishlistComparisonOption(
      sellerName: "First cheap risky seller",
      productURL: "https://risk-first.example/scanner",
      listedPrice: "18.00",
      currency: "USD",
      estimatedAUDTotal: "AUD 39 delivered",
      postageCost: "AUD 0",
      postageTime: "21-45 business days",
      sellerRegion: "Overseas",
      trustRating: "Unknown",
      trustNotes: "No returns or warranty evidence.",
      recommendation: "Do not prefer without review",
      lastChecked: "Today",
      localScore: 20,
      riskLevel: "High risk",
      decisionReason: "Cheap but poor trust evidence."
    )
    let trustedOption = try XCTUnwrap(item.comparisonOptions?.first)
    item.comparisonOptions = [riskyFirstOption, trustedOption]
    item.preferredOptionID = nil
    item.purchaseDecision = nil
    resetWishlistState(store)
    store.wishlistItems = [item]

    store.addWishlistPurchaseLinkRecord(item)

    let record = try XCTUnwrap(store.wishlistPurchaseLinkRecords.first)

    XCTAssertEqual(record.sellerName, "Known Australian retailer")
    XCTAssertEqual(record.productURL, trustedOption.productURL)
    XCTAssertEqual(record.estimatedAUDTotal, "AUD 109 delivered")
    XCTAssertEqual(record.trustSummary, "Trusted")
    XCTAssertFalse(record.selectedForPurchase)
  }

  func testWishlistAccountApprovalAndDraftFallbackToBestScoredSellerWhenNoPreferenceIsSet() throws {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    var (item, trustedOption) = try makeWishlistItemWithRiskyFirstOption()
    item.purchaseDecision = nil
    item.purchaseHandoff = nil
    resetWishlistState(store)
    store.wishlistItems = [item]
    store.draftMessages = []

    store.addWishlistPurchaseAccountRecord(item)
    store.addWishlistPurchaseApprovalRecord(item)
    store.createDraftMessage(from: item)

    let account = try XCTUnwrap(store.wishlistPurchaseAccountRecords.first)
    let approval = try XCTUnwrap(store.wishlistPurchaseApprovalRecords.first)
    let draft = try XCTUnwrap(store.draftMessages.first)

    XCTAssertEqual(account.sellerName, "Known Australian retailer")
    XCTAssertTrue(account.expectedOrderEmailSignals.contains("Known Australian retailer"))
    XCTAssertEqual(approval.sellerName, "Known Australian retailer")
    XCTAssertEqual(approval.approvedAUDLimit, "AUD 109 delivered")
    XCTAssertTrue(draft.body.contains("Preferred seller: Known Australian retailer"))
    XCTAssertTrue(draft.body.contains("Best scored fallback - Known Australian retailer"))
    XCTAssertTrue(draft.body.contains(trustedOption.estimatedAUDTotal))
    XCTAssertFalse(draft.body.contains("Preferred seller: First cheap risky seller"))
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
    XCTAssertEqual(store.wishlistLinkedOrderCount, 1)
    XCTAssertEqual(store.wishlistLinkedOrders.map(\.id), [createdOrder.id])
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
    XCTAssertEqual(store.wishlistLinkedOrderCount, 1)
    XCTAssertEqual(store.wishlistLinkedOrders.map(\.id), [createdOrder.id])
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
    XCTAssertEqual(store.wishlistLinkedOrderCount, 1)
    XCTAssertEqual(store.wishlistLinkedOrders.map(\.id), [order.id])
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
    XCTAssertEqual(store.wishlistLinkedOrderCount, 0)
    XCTAssertTrue(store.wishlistLinkedOrders.isEmpty)
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

  func testGmailPostRefreshActionPlanTreatsFilteredOnlyRefreshAsNoOperatorWork() {
    let connection = makeGmailConnection(
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
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
        status: .connected,
        signedInAccount: "orders@example.test",
        lastAuthAttemptDate: "Today",
        lastSuccessfulAuthDate: "Today",
        tokenStoreStatus: "GoogleSignIn cache available",
        tokenStoreDetail: "No token values stored in JSON.",
        detailText: "Connected for test."
      )
    ]
    store.mailboxIngestRecords = []
    store.intakeEmails = []

    let plan = store.gmailPostRefreshActionPlan

    XCTAssertEqual(plan.items.first { $0.title == "Review imported Inbox rows" }?.count, 0)
    XCTAssertEqual(plan.items.first { $0.title == "Review imported Inbox rows" }?.tone, "success")
    XCTAssertEqual(plan.items.first { $0.title == "Fix parser diagnostics" }?.count, 0)
    XCTAssertEqual(plan.items.first { $0.title == "Create or link orders" }?.count, 0)
    XCTAssertEqual(plan.items.first { $0.title == "Review uncertain messages" }?.count, 0)
    XCTAssertEqual(plan.items.first { $0.title == "Check filtered examples" }?.count, 0)
  }

  func testGmailClassifierSuiteKeepsMixedMailboxDecisionsConservative() throws {
    var connection = makeGmailConnection(
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 0,
      imported: 0,
      filtered: 0,
      uncertain: 0
    )
    connection.mailboxMode = .mixedFiltered
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = [connection]
    store.auditEvents = []

    store.runGmailClassifierTestSuite(for: connection)

    let updatedConnection = try XCTUnwrap(store.gmailMailboxConnections.first)
    let results = try XCTUnwrap(updatedConnection.classifierTestResults)
    XCTAssertEqual(results.count, 4)
    XCTAssertEqual(results.first { $0.sampleName == "Clear shipped order" }?.decision, "Imported")
    XCTAssertEqual(results.first { $0.sampleName == "Ambiguous delivery question" }?.decision, "Uncertain")
    XCTAssertEqual(results.first { $0.sampleName == "Marketing offer" }?.decision, "Filtered")
    XCTAssertEqual(results.first { $0.sampleName == "Security notification" }?.decision, "Filtered")
    XCTAssertTrue(results.allSatisfy { $0.decisionStatus.localizedCaseInsensitiveContains("passed") })
    XCTAssertEqual(updatedConnection.classifierTestSummary, "Gmail classifier suite: 4/4 local decision expectations passed. Parser expectations: 1/1 passed. No Gmail API call, OAuth flow, token request, mailbox fetch, or Inbox import occurred.")
    XCTAssertTrue(store.auditEvents.contains { $0.summary == "Gmail classifier test suite ran locally." })
  }

  func testGmailAmbiguousClassifierAddsUncertainPreviewWithoutInboxImport() throws {
    var connection = makeGmailConnection(
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 0,
      imported: 0,
      filtered: 0,
      uncertain: 0
    )
    connection.mailboxMode = .mixedFiltered
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = [connection]
    store.intakeEmails = []
    store.mailboxIngestRecords = []
    store.auditEvents = []

    store.testGmailAmbiguousClassifier(for: connection)

    let updatedConnection = try XCTUnwrap(store.gmailMailboxConnections.first)
    let uncertainMessages = try XCTUnwrap(updatedConnection.uncertainMessages)
    XCTAssertEqual(uncertainMessages.count, 1)
    XCTAssertEqual(uncertainMessages.first?.subject, "Delivery question")
    XCTAssertTrue(uncertainMessages.first?.reason.localizedCaseInsensitiveContains("order") == true)
    XCTAssertEqual(updatedConnection.lastRefreshUncertainCount, 1)
    XCTAssertTrue(store.intakeEmails.isEmpty)
    XCTAssertTrue(store.mailboxIngestRecords.isEmpty)
    XCTAssertTrue(store.auditEvents.contains { $0.summary == "Gmail classifier sample tested locally." })
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

  func testMicrosoft365HealthSummaryPreservesImportedAndDuplicateEvidence() throws {
    let mailboxID = UUID()
    let intake = ForwardedEmailIntake(
      sender: "orders@example.test",
      subject: "Order OUTLOOK-123 shipped",
      receivedDate: "Today",
      rawBodyPreview: "Order OUTLOOK-123 shipped tracking MSFT123",
      detectedMerchant: "Example Store",
      detectedOrderNumber: "OUTLOOK-123",
      detectedTrackingNumber: "MSFT123",
      detectedDestinationAddress: "Destination needs review",
      linkedOrderID: nil,
      reviewState: .needsReview
    )
    let connection = makeMicrosoft365Connection(
      id: mailboxID,
      connectionStatus: "Real Graph: Fetch success",
      lastManualRefreshDate: "Today"
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = []
    store.microsoft365MailboxConnections = [connection]
    store.intakeEmails = [intake]
    store.mailboxIngestRecords = [
      MailboxIngestRecord(
        providerMessageID: "outlook-imported-1",
        sourceMailboxID: mailboxID,
        intakeEmailID: intake.id,
        capturedDate: "Today",
        status: .imported,
        summary: "Imported Outlook intake"
      ),
      MailboxIngestRecord(
        providerMessageID: "outlook-refreshed-1",
        sourceMailboxID: mailboxID,
        intakeEmailID: intake.id,
        capturedDate: "Today",
        status: .duplicateRefreshed,
        summary: "Duplicate refreshed Outlook intake"
      )
    ]
    store.microsoft365AuthSessionStates = [
      mailboxID: Microsoft365AuthSessionState(
        connectionID: mailboxID,
        status: .connected,
        signedInAccount: "orders@example.test",
        lastAuthAttemptDate: "Today",
        lastSuccessfulAuthDate: "Today",
        keychainStatus: "MSAL token cache managed by MSAL",
        tokenStoreStatus: .mockTokenReferenceAvailable,
        tokenStoreDetail: "No token values stored in JSON.",
        detailText: "Identity sign-in available."
      )
    ]

    let summary = store.microsoft365IntakeHealthSummary(for: connection)

    XCTAssertEqual(summary.verdict, "Outlook order intake captured")
    XCTAssertEqual(summary.tone, "success")
    XCTAssertEqual(summary.fetchedCount, 2)
    XCTAssertEqual(summary.importedCount, 1)
    XCTAssertEqual(summary.duplicateCount, 1)
    XCTAssertEqual(summary.duplicateRefreshedCount, 1)
    XCTAssertEqual(summary.linkedIntakeCount, 1)
    XCTAssertEqual(summary.blockedCount, 0)
    XCTAssertEqual(store.latestMicrosoft365IntakeHealthSummary?.importedCount, 1)
    XCTAssertEqual(store.latestMailboxFetchedCount, 2)
    XCTAssertEqual(store.latestMailboxImportedCount, 1)
    XCTAssertEqual(store.latestMailboxDuplicateCount, 1)
    XCTAssertTrue(store.latestMailboxCompactRefreshText.contains("Outlook 2 fetched"))
    XCTAssertTrue(store.latestMailboxCompactRefreshText.contains("1 imported"))
    XCTAssertTrue(store.latestMailboxCompactRefreshText.contains("1 duplicate"))
    XCTAssertTrue(store.latestMailboxCompactRefreshText.contains("1 refreshed"))
    XCTAssertTrue(store.latestActiveMailboxEvidenceText.contains("Outlook latest: 2 fetched, 1 imported"))
  }

  func testMicrosoft365ReleaseSelfCheckBlocksMissingOAuthReadiness() throws {
    var connection = makeMicrosoft365Connection(
      connectionStatus: "Not connected",
      lastManualRefreshDate: "Never"
    )
    connection.clientIDPlaceholder = ""
    connection.requestedScopesSummary = ""
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = []
    store.microsoft365MailboxConnections = [connection]
    store.microsoft365AuthSessionStates = [:]
    store.auditEvents = []

    let summary = store.microsoft365ReleaseSelfCheckSummary(for: connection)

    XCTAssertEqual(summary.verdict, "Outlook release blocked")
    XCTAssertEqual(summary.tone, "warning")
    XCTAssertEqual(summary.totalCount, 9)
    XCTAssertTrue(summary.items.contains { $0.title == "OAuth readiness" && !$0.isComplete && $0.tone == "warning" })
    XCTAssertTrue(summary.items.contains { $0.title == "Mail.Read consent" && !$0.isComplete && $0.tone == "warning" })
    XCTAssertTrue(summary.items.contains { $0.title == "Release task assigned" && !$0.isComplete && $0.tone == "attention" })
    XCTAssertEqual(summary.graphBlockerCount, 0)
  }

  func testMicrosoft365ReleaseSelfCheckSurfacesConnectedImportEvidence() throws {
    let mailboxID = UUID()
    let connection = makeMicrosoft365Connection(
      id: mailboxID,
      connectionStatus: "Real Graph: Fetch success",
      lastManualRefreshDate: "Today"
    )
    let intake = ForwardedEmailIntake(
      sender: "orders@example.test",
      subject: "Order OUTLOOK-456 shipped",
      receivedDate: "Today",
      rawBodyPreview: "Order OUTLOOK-456 shipped tracking MSFT456",
      detectedMerchant: "Example Store",
      detectedOrderNumber: "OUTLOOK-456",
      detectedTrackingNumber: "MSFT456",
      detectedDestinationAddress: "Destination needs review",
      linkedOrderID: nil,
      reviewState: .needsReview
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = []
    store.microsoft365MailboxConnections = [connection]
    store.intakeEmails = [intake]
    store.mailboxIngestRecords = [
      MailboxIngestRecord(
        providerMessageID: "outlook-release-import",
        sourceMailboxID: mailboxID,
        intakeEmailID: intake.id,
        capturedDate: "Today",
        status: .imported,
        summary: "Imported Outlook message"
      )
    ]
    store.microsoft365AuthSessionStates = [
      mailboxID: Microsoft365AuthSessionState(
        connectionID: mailboxID,
        status: .connected,
        signedInAccount: "orders@example.test",
        lastAuthAttemptDate: "Today",
        lastSuccessfulAuthDate: "Today",
        keychainStatus: "MSAL token cache managed by MSAL",
        tokenStoreStatus: .mockTokenReferenceAvailable,
        tokenStoreDetail: "No token values stored in JSON.",
        detailText: "Identity sign-in available."
      )
    ]
    store.auditEvents = [
      AuditEvent(
        timestamp: "Today",
        actor: "Local user",
        action: .evaluated,
        entityType: .microsoft365MailboxConnection,
        entityID: mailboxID.uuidString,
        entityLabel: connection.displayName,
        summary: "Real Microsoft Graph mailbox fetch completed.",
        afterDetail: "Imported 1 message."
      )
    ]

    let summary = store.microsoft365ReleaseSelfCheckSummary(for: connection)

    XCTAssertEqual(summary.graphBlockerCount, 0)
    XCTAssertTrue(summary.items.contains { $0.title == "Microsoft sign-in" && $0.isComplete })
    XCTAssertTrue(summary.items.contains { $0.title == "Manual Graph refresh" && $0.isComplete })
    XCTAssertTrue(summary.items.contains { $0.title == "Audit evidence" && $0.isComplete })
    XCTAssertTrue(summary.detail.contains("Latest health: Outlook order intake captured"))
  }

  func testMicrosoft365ReleaseSelfCheckTaskRefreshesExistingOpenTask() throws {
    let mailboxID = UUID()
    var connection = makeMicrosoft365Connection(
      id: mailboxID,
      connectionStatus: "Not connected",
      lastManualRefreshDate: "Never"
    )
    connection.clientIDPlaceholder = ""
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.microsoft365MailboxConnections = [connection]
    store.reviewTasks = []
    store.auditEvents = []

    store.createReviewTaskFromMicrosoft365ReleaseSelfCheck(connection)
    connection.connectionStatus = "Real Graph: Auth required"
    connection.lastManualRefreshDate = "Today"
    store.createReviewTaskFromMicrosoft365ReleaseSelfCheck(connection)

    let tasks = store.reviewTasks.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == mailboxID.uuidString
        && $0.title.localizedCaseInsensitiveContains("Outlook release self-check")
    }
    XCTAssertEqual(tasks.count, 1)
    XCTAssertEqual(tasks.first?.assignee, "Mailbox team")
    XCTAssertEqual(tasks.first?.priority, .high)
    XCTAssertEqual(tasks.first?.reviewState, .needsReview)
    XCTAssertTrue(tasks.first?.summary.contains("Outlook release blocked") == true)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Existing Outlook release self-check review task refreshed."
        && (event.afterDetail?.contains("No duplicate task was created.") ?? false)
    })

    let refreshedSummary = store.microsoft365ReleaseSelfCheckSummary(for: connection)
    let releaseTaskItem = refreshedSummary.items.first { $0.title == "Release task assigned" }
    XCTAssertEqual(releaseTaskItem?.isComplete, true)
    XCTAssertEqual(releaseTaskItem?.tone, "success")
  }

  func testMicrosoft365ReleaseSelfCheckTaskCreatesNewTaskAfterCompletedTask() throws {
    let mailboxID = UUID()
    let connection = makeMicrosoft365Connection(
      id: mailboxID,
      connectionStatus: "Real Graph: Fetch success",
      lastManualRefreshDate: "Today"
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.microsoft365MailboxConnections = [connection]
    store.reviewTasks = []
    store.auditEvents = []

    store.createReviewTaskFromMicrosoft365ReleaseSelfCheck(connection)
    guard let firstTask = store.reviewTasks.first else {
      XCTFail("Expected Outlook release self-check task.")
      return
    }
    store.completeReviewTask(firstTask)
    store.createReviewTaskFromMicrosoft365ReleaseSelfCheck(connection)

    let tasks = store.reviewTasks.filter {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == mailboxID.uuidString
        && $0.title.localizedCaseInsensitiveContains("Outlook release self-check")
    }
    XCTAssertEqual(tasks.count, 2)
    XCTAssertEqual(tasks.filter { $0.status == .completed }.count, 1)
    XCTAssertEqual(tasks.filter { $0.status == .open }.count, 1)
    XCTAssertTrue(store.auditEvents.contains { $0.summary == "Review task completed." })
    XCTAssertTrue(store.auditEvents.contains { $0.summary == "Review task created from Outlook release self-check." })
  }

  func testTotalMailboxCountsIncludeMicrosoft365Evidence() {
    let outlookID = UUID()
    let connection = makeMicrosoft365Connection(
      id: outlookID,
      connectionStatus: "Real Graph: Fetch success",
      lastManualRefreshDate: "Today"
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = []
    store.microsoft365MailboxConnections = [connection]
    store.mailboxIngestRecords = [
      MailboxIngestRecord(
        providerMessageID: "outlook-import-total",
        sourceMailboxID: outlookID,
        intakeEmailID: UUID(),
        capturedDate: "Today",
        status: .imported,
        summary: "Imported Outlook message"
      ),
      MailboxIngestRecord(
        providerMessageID: "outlook-refreshed-total",
        sourceMailboxID: outlookID,
        intakeEmailID: UUID(),
        capturedDate: "Today",
        status: .duplicateRefreshed,
        summary: "Refreshed Outlook duplicate"
      ),
      MailboxIngestRecord(
        providerMessageID: "outlook-nochange-total",
        sourceMailboxID: outlookID,
        intakeEmailID: UUID(),
        capturedDate: "Today",
        status: .duplicateNoChange,
        summary: "No-change Outlook duplicate"
      )
    ]
    store.microsoft365AuthSessionStates = [
      outlookID: Microsoft365AuthSessionState(
        connectionID: outlookID,
        status: .connected,
        signedInAccount: "orders@example.test",
        lastAuthAttemptDate: "Today",
        lastSuccessfulAuthDate: "Today",
        keychainStatus: "MSAL token cache managed by MSAL",
        tokenStoreStatus: .mockTokenReferenceAvailable,
        tokenStoreDetail: "No token values stored in JSON.",
        detailText: "Identity sign-in available."
      )
    ]

    XCTAssertEqual(store.totalMicrosoft365FetchedCount, 3)
    XCTAssertEqual(store.totalMicrosoft365ImportedCount, 1)
    XCTAssertEqual(store.totalMicrosoft365DuplicateCount, 2)
    XCTAssertEqual(store.totalMicrosoft365DuplicateRefreshedCount, 1)
    XCTAssertEqual(store.totalMicrosoft365DuplicateNoChangeCount, 1)
    XCTAssertEqual(store.totalMailboxFetchedCount, 3)
    XCTAssertEqual(store.totalMailboxImportedCount, 1)
    XCTAssertEqual(store.totalMailboxDuplicateCount, 2)
    XCTAssertEqual(store.totalMailboxDuplicateRefreshedCount, 1)
    XCTAssertEqual(store.totalMailboxDuplicateNoChangeCount, 1)
  }

  func testDuplicateGmailFetchRefreshesExistingStaleIntakeWithoutCreatingDuplicate() throws {
    let mailboxID = UUID()
    let intakeID = UUID()
    let staleIntake = ForwardedEmailIntake(
      id: intakeID,
      sender: "Unknown Sender",
      subject: "No subject",
      receivedDate: "Earlier",
      rawBodyPreview: "Raw Gmail API placeholder before parser cleanup.",
      detectedMerchant: "Unknown Sender",
      detectedOrderNumber: "Order number needs review",
      detectedTrackingNumber: "Tracking number needs review",
      detectedDestinationAddress: "Destination needs review",
      linkedOrderID: nil,
      reviewState: .needsReview
    )
    let fetchedMessage = FetchedMailboxMessage(
      providerMessageID: "gmail-clean-duplicate-1",
      sender: "orders@example-store.test",
      subject: "Example Store order TEST-123 shipped",
      receivedDate: "Today",
      plainTextBodyPreview: "Order TEST-123 shipped tracking ABC123 to 10 Market Street, Melbourne VIC.",
      sourceMailboxID: mailboxID
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.intakeEmails = [staleIntake]
    store.mailboxIngestRecords = [
      MailboxIngestRecord(
        providerMessageID: fetchedMessage.providerMessageID,
        sourceMailboxID: mailboxID,
        intakeEmailID: intakeID,
        capturedDate: "Earlier",
        status: .imported,
        summary: "Original Gmail import"
      )
    ]
    store.auditEvents = []

    let result = store.importFetchedMailboxMessages([fetchedMessage])

    XCTAssertEqual(result.imported, 0)
    XCTAssertEqual(result.duplicates, 1)
    XCTAssertEqual(store.intakeEmails.count, 1)
    let refreshed = try XCTUnwrap(store.intakeEmails.first)
    XCTAssertEqual(refreshed.id, intakeID)
    XCTAssertEqual(refreshed.sender, "orders@example-store.test")
    XCTAssertEqual(refreshed.subject, "Example Store order TEST-123 shipped")
    XCTAssertEqual(refreshed.detectedMerchant, "Example Store")
    XCTAssertEqual(refreshed.detectedOrderNumber, "TEST-123")
    XCTAssertEqual(refreshed.detectedTrackingNumber, "ABC123")
    XCTAssertTrue(refreshed.detectedDestinationAddress.localizedCaseInsensitiveContains("10 Market Street"))
    XCTAssertEqual(refreshed.reviewState, .needsReview)
    XCTAssertEqual(store.mailboxIngestRecords.first?.status, .duplicateRefreshed)
    XCTAssertEqual(store.mailboxIngestRecords.first?.intakeEmailID, intakeID)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Duplicate fetched mailbox message refreshed existing intake email."
        && event.afterDetail?.contains("Changed fields:") == true
        && event.afterDetail?.contains("No duplicate intake email was created") == true
    })
  }

  func testGmailCreatedOrderKeepsActualSourceMailboxTrail() throws {
    let mailboxID = UUID()
    let intake = ForwardedEmailIntake(
      sender: "orders@example-store.test",
      subject: "Example Store order TEST-123 shipped",
      receivedDate: "Today",
      rawBodyPreview: "Order TEST-123 shipped tracking ABC123 to 10 Market Street, Melbourne VIC.",
      detectedMerchant: "Example Store",
      detectedOrderNumber: "TEST-123",
      detectedTrackingNumber: "ABC123",
      detectedDestinationAddress: "10 Market Street, Melbourne VIC",
      linkedOrderID: nil,
      reviewState: .needsReview
    )
    let connection = makeGmailConnection(
      id: mailboxID,
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 1,
      imported: 1,
      filtered: 0,
      uncertain: 0
    )
    var gmailConnection = connection
    gmailConnection.emailAddress = "gmail-orders@example.test"
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = [gmailConnection]
    store.intakeEmails = [intake]
    store.mailboxIngestRecords = [
      MailboxIngestRecord(
        providerMessageID: "gmail-order-source-1",
        sourceMailboxID: mailboxID,
        intakeEmailID: intake.id,
        capturedDate: "Today",
        status: .imported,
        summary: "Imported from Gmail"
      )
    ]
    store.auditEvents = []

    store.createOrder(from: intake)

    let createdOrder = try XCTUnwrap(store.orders.first)
    let updatedIntake = try XCTUnwrap(store.intakeEmails.first)
    XCTAssertEqual(createdOrder.checkedMailbox, "gmail-orders@example.test")
    XCTAssertEqual(createdOrder.contactHistory.first?.contactPoint, "gmail-orders@example.test")
    XCTAssertEqual(updatedIntake.linkedOrderID, createdOrder.id)
    XCTAssertEqual(updatedIntake.reviewState, .reviewed)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Tracked order created from forwarded intake email."
        && event.afterDetail?.contains("Source mailbox: gmail-orders@example.test") == true
    })
  }

  func testLinkingGmailIntakeToExistingOrderKeepsActualSourceMailboxTrail() throws {
    let mailboxID = UUID()
    let order = makeOrder(
      orderNumber: "TEST-123",
      trackingNumber: "ABC123",
      destination: "10 Market Street, Melbourne VIC",
      checkedMailbox: "manual-import",
      source: .manual,
      latestStatus: "Manual order"
    )
    let intake = ForwardedEmailIntake(
      sender: "orders@example-store.test",
      subject: "Example Store order TEST-123 shipped",
      receivedDate: "Today",
      rawBodyPreview: "Order TEST-123 shipped tracking ABC123 to 10 Market Street, Melbourne VIC.",
      detectedMerchant: "Example Store",
      detectedOrderNumber: "TEST-123",
      detectedTrackingNumber: "ABC123",
      detectedDestinationAddress: "10 Market Street, Melbourne VIC",
      linkedOrderID: nil,
      reviewState: .needsReview
    )
    var gmailConnection = makeGmailConnection(
      id: mailboxID,
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 1,
      imported: 1,
      filtered: 0,
      uncertain: 0
    )
    gmailConnection.emailAddress = "gmail-orders@example.test"
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.orders = [order]
    store.gmailMailboxConnections = [gmailConnection]
    store.intakeEmails = [intake]
    store.mailboxIngestRecords = [
      MailboxIngestRecord(
        providerMessageID: "gmail-order-link-1",
        sourceMailboxID: mailboxID,
        intakeEmailID: intake.id,
        capturedDate: "Today",
        status: .imported,
        summary: "Imported from Gmail"
      )
    ]

    store.linkIntakeEmail(intake, to: order)

    let updatedOrder = try XCTUnwrap(store.orders.first)
    let updatedIntake = try XCTUnwrap(store.intakeEmails.first)
    XCTAssertEqual(updatedOrder.contactHistory.first?.contactPoint, "gmail-orders@example.test")
    XCTAssertEqual(updatedOrder.latestStatus, "Forwarded email evidence linked")
    XCTAssertEqual(updatedIntake.linkedOrderID, order.id)
    XCTAssertEqual(updatedIntake.reviewState, .reviewed)
  }

  func testAcceptanceReviewCreatedOrderKeepsGmailSourceMailboxTrail() throws {
    let mailboxID = UUID()
    let intake = ForwardedEmailIntake(
      sender: "orders@example-store.test",
      subject: "Example Store order TEST-123 shipped",
      receivedDate: "Today",
      rawBodyPreview: "Order TEST-123 shipped tracking ABC123 to 10 Market Street, Melbourne VIC.",
      detectedMerchant: "Example Store",
      detectedOrderNumber: "TEST-123",
      detectedTrackingNumber: "ABC123",
      detectedDestinationAddress: "10 Market Street, Melbourne VIC",
      linkedOrderID: nil,
      reviewState: .needsReview
    )
    var gmailConnection = makeGmailConnection(
      id: mailboxID,
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 1,
      imported: 1,
      filtered: 0,
      uncertain: 0
    )
    gmailConnection.emailAddress = "gmail-orders@example.test"
    let candidate = AcceptanceCandidate(
      id: "intake-\(intake.id.uuidString)",
      sourceType: .intakeEmail,
      sourceID: intake.id,
      sourceLabel: intake.subject,
      capturedDate: intake.receivedDate,
      rawSummary: intake.rawBodyPreview,
      detectedMerchant: intake.detectedMerchant,
      detectedOrderNumber: intake.detectedOrderNumber,
      detectedTrackingNumber: intake.detectedTrackingNumber,
      detectedDestinationAddress: intake.detectedDestinationAddress,
      suggestedLinkedOrderID: nil,
      suggestedShipmentGroupID: nil,
      confidenceScore: 92,
      decision: .ready,
      reviewState: .needsReview,
      notes: "Forwarded intake email awaiting local acceptance review."
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = [gmailConnection]
    store.intakeEmails = [intake]
    store.mailboxIngestRecords = [
      MailboxIngestRecord(
        providerMessageID: "gmail-acceptance-source-1",
        sourceMailboxID: mailboxID,
        intakeEmailID: intake.id,
        capturedDate: "Today",
        status: .imported,
        summary: "Imported from Gmail"
      )
    ]
    store.auditEvents = []

    store.createOrder(from: candidate)

    let createdOrder = try XCTUnwrap(store.orders.first)
    XCTAssertEqual(createdOrder.checkedMailbox, "gmail-orders@example.test")
    XCTAssertTrue(createdOrder.contactHistory.contains { $0.contactPoint == "gmail-orders@example.test" })
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Order created from acceptance review."
        && event.afterDetail?.contains("Source mailbox: gmail-orders@example.test") == true
    })
  }

  func testAcceptanceCandidateSourceContextShowsGmailMailbox() {
    let mailboxID = UUID()
    let intake = ForwardedEmailIntake(
      sender: "orders@example-store.test",
      subject: "Example Store order TEST-123 shipped",
      receivedDate: "Today",
      rawBodyPreview: "Order TEST-123 shipped tracking ABC123 to 10 Market Street, Melbourne VIC.",
      detectedMerchant: "Example Store",
      detectedOrderNumber: "TEST-123",
      detectedTrackingNumber: "ABC123",
      detectedDestinationAddress: "10 Market Street, Melbourne VIC",
      linkedOrderID: nil,
      reviewState: .needsReview
    )
    var gmailConnection = makeGmailConnection(
      id: mailboxID,
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 1,
      imported: 1,
      filtered: 0,
      uncertain: 0
    )
    gmailConnection.emailAddress = "gmail-orders@example.test"
    let candidate = AcceptanceCandidate(
      id: "intake-\(intake.id.uuidString)",
      sourceType: .intakeEmail,
      sourceID: intake.id,
      sourceLabel: intake.subject,
      capturedDate: intake.receivedDate,
      rawSummary: intake.rawBodyPreview,
      detectedMerchant: intake.detectedMerchant,
      detectedOrderNumber: intake.detectedOrderNumber,
      detectedTrackingNumber: intake.detectedTrackingNumber,
      detectedDestinationAddress: intake.detectedDestinationAddress,
      suggestedLinkedOrderID: nil,
      suggestedShipmentGroupID: nil,
      confidenceScore: 92,
      decision: .ready,
      reviewState: .needsReview,
      notes: "Forwarded intake email awaiting local acceptance review."
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = [gmailConnection]
    store.intakeEmails = [intake]
    store.mailboxIngestRecords = [
      MailboxIngestRecord(
        providerMessageID: "gmail-acceptance-source-context-1",
        sourceMailboxID: mailboxID,
        intakeEmailID: intake.id,
        capturedDate: "Today",
        status: .imported,
        summary: "Imported from Gmail"
      )
    ]

    let context = store.acceptanceSourceContext(for: candidate)

    XCTAssertEqual(context.label, "gmail-orders@example.test")
    XCTAssertTrue(context.detail.contains("Gmail intake"))
    XCTAssertTrue(context.detail.contains("preserves gmail-orders@example.test"))
  }

  func testAcceptanceCandidateSourceContextShowsImportFallback() {
    let item = ImportQueueItem(
      sourceType: .manualEntry,
      sourceLabel: "Manual test import",
      capturedDate: "Today",
      rawSummary: "Imported order TEST-456",
      detectedMerchant: "Example Store",
      detectedOrderNumber: "TEST-456",
      detectedTrackingNumber: "XYZ789",
      detectedDestinationAddress: "20 Market Street, Melbourne VIC",
      suggestedLinkedOrderID: nil,
      suggestedShipmentGroupID: nil,
      confidenceScore: 88,
      importStatus: .staged,
      reviewState: .needsReview,
      notes: "Review before acceptance."
    )
    let candidate = AcceptanceCandidate(
      id: "import-\(item.id.uuidString)",
      sourceType: .importQueueItem,
      sourceID: item.id,
      sourceLabel: item.sourceLabel,
      capturedDate: item.capturedDate,
      rawSummary: item.rawSummary,
      detectedMerchant: item.detectedMerchant,
      detectedOrderNumber: item.detectedOrderNumber,
      detectedTrackingNumber: item.detectedTrackingNumber,
      detectedDestinationAddress: item.detectedDestinationAddress,
      suggestedLinkedOrderID: nil,
      suggestedShipmentGroupID: nil,
      confidenceScore: item.confidenceScore,
      decision: .ready,
      reviewState: item.reviewState,
      notes: item.notes
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.importQueueItems = [item]

    let context = store.acceptanceSourceContext(for: candidate)

    XCTAssertEqual(context.label, "Manual test import")
    XCTAssertTrue(context.detail.contains("Manual entry import"))
    XCTAssertTrue(context.detail.contains("manual import"))
  }

  func testAcceptanceRecordSourceContextShowsGmailMailbox() {
    let mailboxID = UUID()
    let orderID = UUID()
    let intake = ForwardedEmailIntake(
      sender: "orders@example-store.test",
      subject: "Example Store order TEST-123 shipped",
      receivedDate: "Today",
      rawBodyPreview: "Order TEST-123 shipped tracking ABC123 to 10 Market Street, Melbourne VIC.",
      detectedMerchant: "Example Store",
      detectedOrderNumber: "TEST-123",
      detectedTrackingNumber: "ABC123",
      detectedDestinationAddress: "10 Market Street, Melbourne VIC",
      linkedOrderID: orderID,
      reviewState: .reviewed
    )
    var gmailConnection = makeGmailConnection(
      id: mailboxID,
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 1,
      imported: 1,
      filtered: 0,
      uncertain: 0
    )
    gmailConnection.emailAddress = "gmail-orders@example.test"
    let order = TrackedOrder(
      id: orderID,
      orderNumber: "TEST-123",
      store: "Example Store",
      recipientEmail: "ops@example.test",
      checkedMailbox: "gmail-orders@example.test",
      customer: "Operations",
      fulfillment: .delivery,
      carrier: "Carrier pending",
      trackingNumber: "ABC123",
      destination: "10 Market Street, Melbourne VIC",
      eta: "Pending",
      source: .forwardedMailbox,
      status: .shipped,
      reviewState: .needsReview,
      latestStatus: "Created from local acceptance review.",
      timeline: [],
      contactHistory: []
    )
    let record = AcceptanceRecord(
      sourceType: .intakeEmail,
      sourceID: intake.id,
      sourceLabel: intake.subject,
      decidedDate: "Today",
      confidenceScore: 92,
      linkedOrderID: orderID,
      linkedShipmentGroupID: nil,
      decision: .accepted,
      reviewState: .accepted,
      summary: "Accepted into tracked order.",
      notes: "Preserved source history."
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.orders = [order]
    store.gmailMailboxConnections = [gmailConnection]
    store.intakeEmails = [intake]
    store.mailboxIngestRecords = [
      MailboxIngestRecord(
        providerMessageID: "gmail-acceptance-record-source-context-1",
        sourceMailboxID: mailboxID,
        intakeEmailID: intake.id,
        capturedDate: "Today",
        status: .imported,
        summary: "Imported from Gmail"
      )
    ]

    let context = store.acceptanceSourceContext(for: record)

    XCTAssertEqual(context.label, "gmail-orders@example.test")
    XCTAssertTrue(context.detail.contains("Gmail intake"))
    XCTAssertTrue(context.detail.contains("Decision: Accepted"))
    XCTAssertTrue(context.detail.contains("Linked order: Example Store TEST-123"))
  }

  func testOrderSourceTrailSummaryCountsIntakeImportAcceptanceAndWishlist() {
    let order = makeOrder(
      orderNumber: "TEST-789",
      trackingNumber: "TRACK-789",
      destination: "Sydney NSW",
      checkedMailbox: "caught@droctopus.net",
      source: .forwardedMailbox,
      latestStatus: "Created from verified Inbox intake"
    )
    let intake = ForwardedEmailIntake(
      sender: "orders@example.test",
      subject: "Order TEST-789 shipped",
      receivedDate: "Today",
      rawBodyPreview: "Order TEST-789 shipped tracking TRACK-789.",
      detectedMerchant: "Example Store",
      detectedOrderNumber: "Order number needs review",
      detectedTrackingNumber: "TRACK-789",
      detectedDestinationAddress: "Sydney NSW",
      linkedOrderID: nil,
      reviewState: .needsReview
    )
    let importItem = ImportQueueItem(
      sourceType: .manualEntry,
      sourceLabel: "Manual TEST-789 import",
      capturedDate: "Today",
      rawSummary: "Manual import for TEST-789",
      detectedMerchant: "Example Store",
      detectedOrderNumber: "TEST-789",
      detectedTrackingNumber: "TRACK-789",
      detectedDestinationAddress: "Sydney NSW",
      suggestedLinkedOrderID: order.id,
      suggestedShipmentGroupID: nil,
      confidenceScore: 88,
      importStatus: .linked,
      reviewState: .accepted,
      notes: "Linked locally."
    )
    let acceptance = AcceptanceRecord(
      sourceType: .intakeEmail,
      sourceID: intake.id,
      sourceLabel: intake.subject,
      decidedDate: "Today",
      confidenceScore: 92,
      linkedOrderID: order.id,
      linkedShipmentGroupID: nil,
      decision: .accepted,
      reviewState: .accepted,
      summary: "Accepted into tracked order.",
      notes: "Preserved source history."
    )
    let wishlist = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: order.id
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.orders = [order]
    store.intakeEmails = [intake]
    store.importQueueItems = [importItem]
    store.acceptanceRecords = [acceptance]
    store.wishlistItems = [wishlist]

    let inboxSummary = store.sourceTrailSummary(for: order)
    let operatorSummary = store.sourceTrailSummary(for: order, includeWishlist: true)

    XCTAssertEqual(store.linkedIntakeEmails(for: order).map(\.id), [intake.id])
    XCTAssertEqual(inboxSummary.intakeCount, 1)
    XCTAssertEqual(inboxSummary.importCount, 1)
    XCTAssertEqual(inboxSummary.acceptanceCount, 1)
    XCTAssertEqual(inboxSummary.wishlistCount, 0)
    XCTAssertEqual(inboxSummary.totalCount, 3)
    XCTAssertEqual(inboxSummary.compactLabel, "3 sources")
    XCTAssertTrue(inboxSummary.auditDetail.contains("1 intake"))
    XCTAssertEqual(operatorSummary.totalCount, 4)
    XCTAssertEqual(operatorSummary.wishlistCount, 1)
    XCTAssertTrue(operatorSummary.auditDetail.contains("1 wishlist"))
  }

  func testOperatorSourceOrdersDeduplicateInboxAndWishlistOrders() {
    let inboxOrder = makeOrder(
      orderNumber: "TEST-902",
      trackingNumber: "TRACK-902",
      destination: "Brisbane QLD",
      checkedMailbox: "manual-import",
      source: .forwardedMailbox,
      latestStatus: "Created from Inbox"
    )
    let wishlistOnlyOrder = makeOrder(
      orderNumber: "TEST-903",
      trackingNumber: "TRACK-903",
      destination: "Melbourne VIC",
      checkedMailbox: "Wishlist",
      source: .manual,
      latestStatus: "Wishlist order confirmed"
    )
    let inboxWishlist = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: inboxOrder.id
    )
    let wishlistOnly = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Packing labels",
      sellerName: "Label supplier",
      linkedOrderID: wishlistOnlyOrder.id
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.orders = [inboxOrder, wishlistOnlyOrder]
    store.wishlistItems = [inboxWishlist, wishlistOnly]

    XCTAssertEqual(store.inboxCreatedOrders.map(\.id), [inboxOrder.id])
    XCTAssertEqual(Set(store.wishlistLinkedOrders.map(\.id)), Set([inboxOrder.id, wishlistOnlyOrder.id]))
    XCTAssertEqual(Set(store.operatorSourceOrders.map(\.id)), Set([inboxOrder.id, wishlistOnlyOrder.id]))
    XCTAssertEqual(store.operatorSourceOrders.count, 2)
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

  func testGmailOAuthReadinessRequiresCompiledClientAndCallbackConfiguration() {
    var connection = makeGmailConnection(
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 0,
      imported: 0,
      filtered: 0,
      uncertain: nil
    )
    connection.googleCloudProjectHint = "ParcelOps Gmail intake"
    connection.oauthClientIDPlaceholder = "1234567890-abcdef.apps.googleusercontent.com"
    connection.redirectURIPlaceholder = "com.googleusercontent.apps.1234567890-abcdef"
    connection.consentScreenNotes = "Internal test consent screen prepared."
    let store = ParcelOpsStore()

    let readiness = store.gmailOAuthReadinessSummary(for: connection)
    let checklist = store.gmailSetupTestChecklist(for: connection)
    let compiledStep = checklist.items.first { $0.title == "Confirm Google app and compiled callback" }

    XCTAssertFalse(readiness.isReady)
    XCTAssertTrue(readiness.missingFields.contains { $0.localizedCaseInsensitiveContains("Compiled App Info.plist GIDClientID") })
    XCTAssertTrue(readiness.missingFields.contains { $0.localizedCaseInsensitiveContains("compiled") && $0.localizedCaseInsensitiveContains("callback") })
    XCTAssertTrue(readiness.compiledClientIDStatus.localizedCaseInsensitiveContains("compiled"))
    XCTAssertTrue(readiness.compiledCallbackSchemeStatus.localizedCaseInsensitiveContains("compiled"))
    XCTAssertEqual(readiness.expectedCallbackScheme, "com.googleusercontent.apps.1234567890-abcdef")
    XCTAssertEqual(checklist.statusText, "1/6 Gmail setup test steps complete")
    XCTAssertEqual(compiledStep?.isComplete, false)
    XCTAssertTrue(compiledStep?.detail.localizedCaseInsensitiveContains("Compiled App Info.plist") == true)
    XCTAssertTrue(compiledStep?.nextAction.localizedCaseInsensitiveContains("compiled App Info.plist") == true)
  }

  func testRealGmailRefreshStopsBeforeClientWhenCompiledReadinessIsBlocked() async throws {
    let realClient = RecordingGmailMailboxClient()
    var connection = makeGmailConnection(
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 0,
      imported: 0,
      filtered: 0,
      uncertain: nil
    )
    connection.googleCloudProjectHint = "ParcelOps Gmail intake"
    connection.oauthClientIDPlaceholder = "1234567890-abcdef.apps.googleusercontent.com"
    connection.redirectURIPlaceholder = "com.googleusercontent.apps.1234567890-abcdef"
    connection.consentScreenNotes = "Internal test consent screen prepared."
    connection.lastRefreshFilteredExamples = ["Old filtered Gmail example"]
    connection.lastRefreshUncertainExamples = ["Old uncertain Gmail example"]
    connection.lastRefreshReasonBreakdown = [
      SpaceMailClassifierReasonCount(decision: "filtered", reason: "old stale reason", count: 3)
    ]
    connection.refreshHistory = [
      GmailRefreshHistoryEntry(
        timestamp: "Earlier",
        eventType: "Mock refresh",
        status: "Fetch success",
        fetchedCount: 5,
        importedCount: 1,
        duplicateCount: 1,
        filteredNonOrderCount: 3,
        uncertainCount: 0,
        summary: "Previous refresh"
      )
    ]
    let store = ParcelOpsStore(
      repository: InMemoryParcelOpsRepository(),
      realGmailMailboxClient: realClient
    )
    store.gmailMailboxConnections = [connection]
    store.auditEvents = []

    store.importRealGmailMessages(for: connection)
    try await Task.sleep(nanoseconds: 200_000_000)

    let updatedConnection = try XCTUnwrap(store.gmailMailboxConnections.first)
    let realClientCallCount = await realClient.callCount()
    XCTAssertEqual(realClientCallCount, 0)
    XCTAssertEqual(updatedConnection.connectionStatus, "Real Gmail: Not configured")
    XCTAssertEqual(updatedConnection.lastRefreshFetchedCount, 0)
    XCTAssertEqual(updatedConnection.lastRefreshImportedCount, 0)
    XCTAssertEqual(updatedConnection.lastRefreshDuplicateCount, 0)
    XCTAssertEqual(updatedConnection.lastRefreshFilteredNonOrderCount, 0)
    XCTAssertEqual(updatedConnection.lastRefreshUncertainCount, 0)
    XCTAssertEqual(updatedConnection.lastRefreshFilteredExamples, [])
    XCTAssertEqual(updatedConnection.lastRefreshUncertainExamples, [])
    XCTAssertEqual(updatedConnection.lastRefreshReasonBreakdown, [])
    XCTAssertTrue(updatedConnection.lastRefreshSummary.localizedCaseInsensitiveContains("stopped before token or API access"))
    let latestHistory = try XCTUnwrap(updatedConnection.refreshHistory?.first)
    XCTAssertEqual(latestHistory.eventType, "Real refresh preflight")
    XCTAssertEqual(latestHistory.status, GmailMailboxFetchStatus.notConfigured.rawValue)
    XCTAssertEqual(latestHistory.fetchedCount, 0)
    XCTAssertEqual(latestHistory.importedCount, 0)
    XCTAssertEqual(latestHistory.duplicateCount, 0)
    XCTAssertEqual(latestHistory.filteredNonOrderCount, 0)
    XCTAssertEqual(latestHistory.uncertainCount, 0)
    XCTAssertTrue(latestHistory.summary.localizedCaseInsensitiveContains("preflight stopped"))
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Real Gmail refresh stopped before API access."
        && event.afterDetail?.contains("Compiled client ID status") == true
        && event.afterDetail?.contains("No Google sign-in, token request, Gmail API call") == true
    })
  }

  func testGmailReadinessCheckClearsStaleRefreshStateWhenBlocked() async throws {
    var connection = makeGmailConnection(
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 8,
      imported: 2,
      filtered: 5,
      uncertain: 1
    )
    connection.googleCloudProjectHint = "ParcelOps Gmail intake"
    connection.oauthClientIDPlaceholder = "1234567890-abcdef.apps.googleusercontent.com"
    connection.redirectURIPlaceholder = "com.googleusercontent.apps.1234567890-abcdef"
    connection.consentScreenNotes = "Internal test consent screen prepared."
    connection.lastRefreshFilteredExamples = ["Old filtered Gmail example"]
    connection.lastRefreshUncertainExamples = ["Old uncertain Gmail example"]
    connection.lastRefreshReasonBreakdown = [
      SpaceMailClassifierReasonCount(decision: "filtered", reason: "old stale reason", count: 5)
    ]
    connection.refreshHistory = [
      GmailRefreshHistoryEntry(
        timestamp: "Earlier",
        eventType: "Real refresh",
        status: "Fetch success",
        fetchedCount: 8,
        importedCount: 2,
        duplicateCount: 1,
        filteredNonOrderCount: 5,
        uncertainCount: 1,
        summary: "Previous real refresh"
      )
    ]
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = [connection]
    store.auditEvents = []

    store.checkRealGmailReadiness(for: connection)
    try await Task.sleep(nanoseconds: 200_000_000)

    let updatedConnection = try XCTUnwrap(store.gmailMailboxConnections.first)
    XCTAssertEqual(updatedConnection.connectionStatus, "Real Gmail readiness: Not configured")
    XCTAssertEqual(updatedConnection.lastRefreshFetchedCount, 0)
    XCTAssertEqual(updatedConnection.lastRefreshImportedCount, 0)
    XCTAssertEqual(updatedConnection.lastRefreshDuplicateCount, 0)
    XCTAssertEqual(updatedConnection.lastRefreshFilteredNonOrderCount, 0)
    XCTAssertEqual(updatedConnection.lastRefreshUncertainCount, 0)
    XCTAssertEqual(updatedConnection.lastRefreshFilteredExamples, [])
    XCTAssertEqual(updatedConnection.lastRefreshUncertainExamples, [])
    XCTAssertEqual(updatedConnection.lastRefreshReasonBreakdown, [])
    XCTAssertTrue(updatedConnection.lastRefreshSummary.localizedCaseInsensitiveContains("did not request a token"))
    let latestHistory = try XCTUnwrap(updatedConnection.refreshHistory?.first)
    XCTAssertEqual(latestHistory.eventType, "Readiness check")
    XCTAssertEqual(latestHistory.status, GmailMailboxFetchStatus.notConfigured.rawValue)
    XCTAssertEqual(latestHistory.fetchedCount, 0)
    XCTAssertEqual(latestHistory.importedCount, 0)
    XCTAssertEqual(latestHistory.duplicateCount, 0)
    XCTAssertEqual(latestHistory.filteredNonOrderCount, 0)
    XCTAssertEqual(latestHistory.uncertainCount, 0)
    XCTAssertTrue(store.auditEvents.contains { event in
      event.summary == "Real Gmail readiness check completed."
        && event.afterDetail?.contains("Fetched: 0") == true
        && event.afterDetail?.contains("No Google OAuth flow, token request, Gmail API call") == true
    })
  }

  func testGmailReleaseSelfCheckStaysBlockedWhenCompiledOAuthConfigurationIsMissing() {
    let mailboxID = UUID()
    var connection = makeGmailConnection(
      id: mailboxID,
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 8,
      imported: 1,
      filtered: 6,
      uncertain: 0
    )
    connection.googleCloudProjectHint = "ParcelOps Gmail intake"
    connection.oauthClientIDPlaceholder = "1234567890-abcdef.apps.googleusercontent.com"
    connection.redirectURIPlaceholder = "com.googleusercontent.apps.1234567890-abcdef"
    connection.consentScreenNotes = "Internal test consent screen prepared."
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

    let summary = store.gmailReleaseSelfCheckSummary(for: connection)
    let setupItem = summary.items.first { $0.title == "Setup and callback" }

    XCTAssertEqual(summary.verdict, "Gmail release blocked")
    XCTAssertEqual(summary.tone, "warning")
    XCTAssertEqual(setupItem?.isComplete, false)
    XCTAssertEqual(setupItem?.tone, "warning")
    XCTAssertTrue(setupItem?.detail.localizedCaseInsensitiveContains("Compiled App Info.plist") == true)
  }

  func testMailboxProviderComparisonRequiresAProviderWhenNoneConfigured() {
    let store = ParcelOpsStore()
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = []
    store.microsoft365MailboxConnections = []
    store.gmailAuthSessionStates = [:]
    store.microsoft365AuthSessionStates = [:]

    let summary = store.mailboxProviderComparisonSummary

    XCTAssertEqual(summary.title, "Choose a mailbox provider")
    XCTAssertEqual(summary.recommendedProvider, "Add provider")
    XCTAssertEqual(summary.tone, "warning")
    XCTAssertEqual(summary.providers.count, 3)
    XCTAssertTrue(summary.actionItems.contains { $0.title == "Choose a mailbox provider" })
    XCTAssertEqual(summary.metrics.first { $0.title == "Providers" }?.value, "0")
    XCTAssertEqual(summary.metrics.first { $0.title == "Blockers" }?.value, "1")
  }

  func testMailboxProviderSetupChecklistFlagsMissingProvider() {
    let store = ParcelOpsStore()
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = []
    store.microsoft365MailboxConnections = []
    store.gmailAuthSessionStates = [:]
    store.microsoft365AuthSessionStates = [:]

    let summary = store.mailboxProviderSetupChecklistSummary
    let spaceMail = summary.providers.first { $0.providerName == "SpaceMail IMAP" }
    let gmail = summary.providers.first { $0.providerName == "Gmail" }
    let outlook = summary.providers.first { $0.providerName == "Outlook" }

    XCTAssertEqual(summary.title, "Provider setup checklist needs review")
    XCTAssertEqual(summary.tone, "warning")
    XCTAssertEqual(summary.metrics.first { $0.title == "Configured" }?.value, "0")
    XCTAssertEqual(summary.metrics.first { $0.title == "Checks" }?.value, "0/5")
    XCTAssertEqual(summary.metrics.first { $0.title == "Warnings" }?.value, "2")
    XCTAssertEqual(spaceMail?.status, "Setup needs attention")
    XCTAssertEqual(spaceMail?.tone, "warning")
    XCTAssertEqual(gmail?.status, "Optional, not configured")
    XCTAssertEqual(gmail?.tone, "neutral")
    XCTAssertEqual(outlook?.status, "Optional, not configured")
    XCTAssertEqual(outlook?.tone, "neutral")
  }

  func testMailboxProviderSetupChecklistTreatsSpaceMailRefreshAsUsable() {
    let store = ParcelOpsStore()
    store.spaceMailIMAPConnections = [
      makeSpaceMailConnection(
        credentialStorageStatus: "Password reference available",
        fetched: 10,
        imported: 1,
        filtered: 7,
        uncertain: 0
      )
    ]
    store.gmailMailboxConnections = []
    store.microsoft365MailboxConnections = []
    store.gmailAuthSessionStates = [:]
    store.microsoft365AuthSessionStates = [:]

    let summary = store.mailboxProviderSetupChecklistSummary
    let spaceMail = summary.providers.first { $0.providerName == "SpaceMail IMAP" }
    let gmail = summary.providers.first { $0.providerName == "Gmail" }
    let outlook = summary.providers.first { $0.providerName == "Outlook" }

    XCTAssertEqual(summary.title, "Provider setup checklist is usable")
    XCTAssertEqual(summary.tone, "success")
    XCTAssertEqual(summary.metrics.first { $0.title == "Configured" }?.value, "1")
    XCTAssertEqual(summary.metrics.first { $0.title == "Checks" }?.value, "5/5")
    XCTAssertEqual(summary.metrics.first { $0.title == "Warnings" }?.value, "0")
    XCTAssertEqual(summary.metrics.first { $0.title == "Refresh evidence" }?.value, "Yes")
    XCTAssertEqual(spaceMail?.status, "Ready for manual read-only refresh")
    XCTAssertEqual(spaceMail?.tone, "success")
    XCTAssertTrue(spaceMail?.checks.allSatisfy(\.isComplete) == true)
    XCTAssertEqual(gmail?.status, "Optional, not configured")
    XCTAssertEqual(gmail?.tone, "neutral")
    XCTAssertEqual(outlook?.status, "Optional, not configured")
    XCTAssertEqual(outlook?.tone, "neutral")
  }

  func testMailboxProviderSetupChecklistDoesNotRequireSpaceMailWhenGmailIsConfigured() {
    let gmailID = UUID()
    let store = ParcelOpsStore()
    store.spaceMailIMAPConnections = []
    store.microsoft365MailboxConnections = []
    store.gmailMailboxConnections = [
      makeGmailConnection(
        id: gmailID,
        oauthReadinessStatus: "Ready",
        credentialStorageStatus: "GoogleSignIn cache available",
        fetched: 8,
        imported: 1,
        filtered: 6,
        uncertain: 0
      )
    ]
    store.gmailAuthSessionStates = [
      gmailID: GmailAuthSessionState(
        connectionID: gmailID,
        status: .connected,
        signedInAccount: "orders@example.test",
        lastAuthAttemptDate: "Today",
        lastSuccessfulAuthDate: "Today",
        tokenStoreStatus: "GoogleSignIn cache available",
        tokenStoreDetail: "No token values stored in JSON.",
        detailText: "Identity sign-in available."
      )
    ]
    store.microsoft365AuthSessionStates = [:]

    let summary = store.mailboxProviderSetupChecklistSummary
    let gmail = summary.providers.first { $0.providerName == "Gmail" }
    let spaceMail = summary.providers.first { $0.providerName == "SpaceMail IMAP" }

    XCTAssertEqual(summary.title, "Provider setup checklist needs review")
    XCTAssertEqual(summary.tone, "warning")
    XCTAssertEqual(summary.metrics.first { $0.title == "Configured" }?.value, "1")
    XCTAssertEqual(summary.metrics.first { $0.title == "Checks" }?.value, "3/5")
    XCTAssertEqual(summary.metrics.first { $0.title == "Warnings" }?.value, "1")
    XCTAssertEqual(summary.metrics.first { $0.title == "Refresh evidence" }?.value, "No")
    XCTAssertEqual(spaceMail?.status, "Optional, not configured")
    XCTAssertEqual(spaceMail?.tone, "neutral")
    XCTAssertEqual(gmail?.status, "Gmail setup needs attention")
    XCTAssertEqual(gmail?.tone, "warning")
    XCTAssertEqual(gmail?.checks.count, 5)
  }

  func testMailboxProviderSetupChecklistTreatsMicrosoft365AsOptionalWhenNotConfigured() {
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
    store.microsoft365MailboxConnections = []
    store.gmailAuthSessionStates = [:]
    store.microsoft365AuthSessionStates = [:]

    let summary = store.mailboxProviderSetupChecklistSummary
    let outlook = summary.providers.first { $0.providerName == "Outlook" }

    XCTAssertEqual(summary.providers.map(\.providerName), ["SpaceMail IMAP", "Gmail", "Outlook"])
    XCTAssertEqual(outlook?.status, "Optional, not configured")
    XCTAssertEqual(outlook?.tone, "neutral")
    XCTAssertTrue(outlook?.checks.allSatisfy { $0.tone == "neutral" || !$0.isComplete } == true)
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
    store.microsoft365MailboxConnections = []
    store.gmailAuthSessionStates = [:]
    store.microsoft365AuthSessionStates = [:]

    let summary = store.mailboxProviderComparisonSummary
    let spaceMail = summary.providers.first { $0.providerName == "SpaceMail" }
    let outlook = summary.providers.first { $0.providerName == "Outlook" }

    XCTAssertEqual(summary.title, "Mailbox intake is quiet")
    XCTAssertEqual(summary.recommendedProvider, "SpaceMail")
    XCTAssertEqual(summary.tone, "success")
    XCTAssertEqual(spaceMail?.statusTitle, "SpaceMail filtering is active")
    XCTAssertEqual(spaceMail?.fetchedCount, 10)
    XCTAssertEqual(spaceMail?.blockedCount, 0)
    XCTAssertEqual(outlook?.statusTitle, "Microsoft 365 optional")
    XCTAssertEqual(outlook?.tone, "neutral")
    XCTAssertTrue(summary.actionItems.contains { $0.providerName == "SpaceMail" && $0.title == "Monitor SpaceMail refreshes" })
    XCTAssertEqual(summary.metrics.first { $0.title == "Filtered" }?.value, "8")
    XCTAssertEqual(summary.metrics.first { $0.title == "Blockers" }?.value, "0")
  }

  func testMailboxProviderComparisonFlagsMicrosoft365Diagnostics() {
    let outlookID = UUID()
    let store = ParcelOpsStore()
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = []
    store.microsoft365MailboxConnections = [
      makeMicrosoft365Connection(
        id: outlookID,
        connectionStatus: "Real Graph: Auth required",
        lastManualRefreshDate: "Today"
      )
    ]
    store.gmailAuthSessionStates = [:]
    store.microsoft365AuthSessionStates = [
      outlookID: Microsoft365AuthSessionState(
        connectionID: outlookID,
        status: .consentRequired,
        signedInAccount: "orders@example.test",
        lastAuthAttemptDate: "Today",
        lastSuccessfulAuthDate: "Never",
        keychainStatus: "MSAL cache entitlement ready",
        tokenStoreStatus: .keychainNotConfigured,
        tokenStoreDetail: "No token values stored in JSON.",
        detailText: "Consent or Graph diagnostics need review."
      )
    ]

    let summary = store.mailboxProviderComparisonSummary
    let outlook = summary.providers.first { $0.providerName == "Outlook" }

    XCTAssertEqual(summary.title, "Mailbox setup has blockers")
    XCTAssertEqual(summary.recommendedProvider, "Outlook")
    XCTAssertEqual(summary.tone, "warning")
    XCTAssertEqual(outlook?.statusTitle, "Microsoft 365 needs review")
    XCTAssertEqual(outlook?.fetchedCount, 1)
    XCTAssertEqual(outlook?.blockedCount, 1)
    XCTAssertTrue(summary.actionItems.contains { $0.providerName == "Outlook" && $0.title == "Review Microsoft 365 diagnostics" })
    XCTAssertEqual(summary.metrics.first { $0.title == "Fetched" }?.value, "1")
    XCTAssertEqual(summary.metrics.first { $0.title == "Blockers" }?.value, "2")
  }

  func testMailboxProviderComparisonPromotesMicrosoft365ImportedWork() {
    let outlookID = UUID()
    let intake = ForwardedEmailIntake(
      sender: "orders@example.test",
      subject: "Order OUTLOOK-456 shipped",
      receivedDate: "Today",
      rawBodyPreview: "Order OUTLOOK-456 shipped tracking MSFT456",
      detectedMerchant: "Example Store",
      detectedOrderNumber: "OUTLOOK-456",
      detectedTrackingNumber: "MSFT456",
      detectedDestinationAddress: "Destination needs review",
      linkedOrderID: nil,
      reviewState: .needsReview
    )
    let store = ParcelOpsStore()
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = []
    store.microsoft365MailboxConnections = [
      makeMicrosoft365Connection(
        id: outlookID,
        connectionStatus: "Real Graph: Fetch success",
        lastManualRefreshDate: "Today"
      )
    ]
    store.intakeEmails = [intake]
    store.mailboxIngestRecords = [
      MailboxIngestRecord(
        providerMessageID: "outlook-imported-2",
        sourceMailboxID: outlookID,
        intakeEmailID: intake.id,
        capturedDate: "Today",
        status: .imported,
        summary: "Imported Outlook intake"
      )
    ]
    store.gmailAuthSessionStates = [:]
    store.microsoft365AuthSessionStates = [
      outlookID: Microsoft365AuthSessionState(
        connectionID: outlookID,
        status: .connected,
        signedInAccount: "orders@example.test",
        lastAuthAttemptDate: "Today",
        lastSuccessfulAuthDate: "Today",
        keychainStatus: "MSAL token cache managed by MSAL",
        tokenStoreStatus: .mockTokenReferenceAvailable,
        tokenStoreDetail: "No token values stored in JSON.",
        detailText: "Identity sign-in available."
      )
    ]

    let summary = store.mailboxProviderComparisonSummary
    let outlook = summary.providers.first { $0.providerName == "Outlook" }

    XCTAssertEqual(summary.title, "Mailbox intake needs operator review")
    XCTAssertEqual(summary.recommendedProvider, "Outlook")
    XCTAssertEqual(summary.tone, "attention")
    XCTAssertEqual(outlook?.statusTitle, "Outlook / Microsoft 365 has operator work")
    XCTAssertEqual(outlook?.importedCount, 1)
    XCTAssertEqual(outlook?.blockedCount, 0)
    XCTAssertEqual(summary.metrics.first { $0.title == "Imported" }?.value, "1")
    XCTAssertEqual(summary.metrics.first { $0.title == "Fetched" }?.value, "1")
    XCTAssertTrue(summary.actionItems.contains { $0.providerName == "Outlook" && $0.title == "Review Outlook intake" })
  }

  func testMailboxProviderComparisonFlagsGmailSetupBlockers() {
    let store = ParcelOpsStore()
    store.spaceMailIMAPConnections = []
    store.microsoft365MailboxConnections = []
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
    store.microsoft365AuthSessionStates = [:]

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
    store.microsoft365MailboxConnections = []
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
    store.microsoft365AuthSessionStates = [:]

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
    store.microsoft365MailboxConnections = []
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
    store.microsoft365AuthSessionStates = [:]

    let summary = store.mailboxProviderComparisonSummary
    let spaceMail = summary.providers.first { $0.providerName == "SpaceMail" }
    let gmail = summary.providers.first { $0.providerName == "Gmail" }

    XCTAssertEqual(summary.title, "Mailbox setup has blockers")
    XCTAssertEqual(summary.recommendedProvider, "SpaceMail + Gmail")
    XCTAssertEqual(summary.tone, "warning")
    XCTAssertEqual(spaceMail?.statusTitle, "SpaceMail filtering is active")
    XCTAssertEqual(gmail?.statusTitle, "Gmail setup or sign-in blocked")
    XCTAssertTrue(summary.decisionRules.contains { $0.title == "Provider paths can run side by side" })
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
    store.microsoft365MailboxConnections = []
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
    store.microsoft365AuthSessionStates = [:]
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
    XCTAssertEqual(summary.metrics.first { $0.title == "Uncertain" }?.value, "1")
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
    XCTAssertEqual(summary.metrics.first { $0.title == "Uncertain" }?.value, "1")
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
    store.microsoft365MailboxConnections = []
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
    store.microsoft365AuthSessionStates = [:]
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
    store.microsoft365MailboxConnections = []
    store.gmailAuthSessionStates = [:]
    store.microsoft365AuthSessionStates = [:]
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

  func testMailboxProviderReleaseGateIgnoresOptionalMissingProviderChecks() {
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
    store.microsoft365MailboxConnections = []
    store.gmailAuthSessionStates = [:]
    store.microsoft365AuthSessionStates = [:]
    store.intakeEmails = []
    store.mailboxIngestRecords = []
    store.orders = []

    let queue = store.mailboxProviderTestQueueSummary
    let gate = store.mailboxProviderReleaseGateSummary
    let setupGate = gate.gates.first { $0.title == "Setup checklist complete enough" }

    XCTAssertFalse(queue.items.contains { $0.providerName == "Gmail" && $0.phase == "Setup" })
    XCTAssertEqual(setupGate?.isPassed, true)
    XCTAssertEqual(setupGate?.tone, "success")
    XCTAssertTrue(setupGate?.evidence.contains("0 incomplete required setup checks") == true)
    XCTAssertTrue(setupGate?.evidence.contains("Optional providers not configured: Gmail, Outlook") == true)
    XCTAssertEqual(setupGate?.nextAction, "Keep the active provider path current; configure optional providers only when needed.")
    XCTAssertTrue(gate.reportText.contains("Optional providers not configured: Gmail, Outlook"))
  }

  func testMailboxProviderReleaseGateRequiresLocalCheckpointTask() {
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
    store.reviewTasks = []

    let initialGate = store.mailboxProviderReleaseGateSummary
    let checkpointGate = initialGate.gates.first { $0.title == "Release validation checkpoint recorded" }

    XCTAssertEqual(checkpointGate?.isPassed, false)
    XCTAssertEqual(checkpointGate?.tone, "attention")
    XCTAssertEqual(initialGate.metrics.first { $0.title == "Checkpoint" }?.value, "Needed")
    XCTAssertTrue(initialGate.reportText.contains("Release validation checkpoint recorded"))

    store.createReviewTaskFromMailboxProviderReleaseGate()

    let refreshedGate = store.mailboxProviderReleaseGateSummary
    let refreshedCheckpointGate = refreshedGate.gates.first { $0.title == "Release validation checkpoint recorded" }

    XCTAssertEqual(refreshedCheckpointGate?.isPassed, true)
    XCTAssertEqual(refreshedCheckpointGate?.tone, "success")
    XCTAssertEqual(refreshedGate.metrics.first { $0.title == "Checkpoint" }?.value, "Open")
    XCTAssertTrue(store.reviewTasks.contains {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == "mailbox-provider-release-gate"
    })

    if let checkpointTask = store.reviewTasks.first(where: {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == "mailbox-provider-release-gate"
    }) {
      store.completeReviewTask(checkpointTask)
    }

    let completedGate = store.mailboxProviderReleaseGateSummary
    let completedCheckpointGate = completedGate.gates.first { $0.title == "Release validation checkpoint recorded" }

    XCTAssertEqual(completedCheckpointGate?.isPassed, false)
    XCTAssertEqual(completedCheckpointGate?.tone, "attention")
    XCTAssertEqual(completedGate.metrics.first { $0.title == "Checkpoint" }?.value, "Needed")
  }

  func testSpaceMailReleaseSnapshotRequiresOpenReleaseTask() {
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
    store.reviewTasks = []

    let initialSnapshot = store.spaceMailReleaseSnapshot
    XCTAssertTrue(initialSnapshot.reportText.contains("Release task gate: open task needed"))
    XCTAssertTrue(initialSnapshot.reportText.contains("Open SpaceMail release snapshot tasks: 0"))
    XCTAssertEqual(initialSnapshot.metrics.first { $0.title == "Release task" }?.value, "0")
    XCTAssertEqual(initialSnapshot.metrics.first { $0.title == "Release task" }?.tone, "attention")

    store.createReviewTaskFromSpaceMailReleaseSnapshot()

    let openTaskSnapshot = store.spaceMailReleaseSnapshot
    XCTAssertTrue(openTaskSnapshot.reportText.contains("Release task gate: open task present"))
    XCTAssertTrue(openTaskSnapshot.reportText.contains("Open SpaceMail release snapshot tasks: 1"))
    XCTAssertEqual(openTaskSnapshot.metrics.first { $0.title == "Release task" }?.value, "1")
    XCTAssertEqual(openTaskSnapshot.metrics.first { $0.title == "Release task" }?.tone, "success")

    if let task = store.reviewTasks.first(where: {
      $0.linkedEntityType == .integration &&
        $0.linkedEntityID == "spacemail-release-snapshot"
    }) {
      store.completeReviewTask(task)
    }

    let completedTaskSnapshot = store.spaceMailReleaseSnapshot
    XCTAssertTrue(completedTaskSnapshot.reportText.contains("Release task gate: open task needed"))
    XCTAssertTrue(completedTaskSnapshot.reportText.contains("Completed SpaceMail release snapshot tasks: 1"))
    XCTAssertEqual(completedTaskSnapshot.metrics.first { $0.title == "Release task" }?.value, "0")
    XCTAssertEqual(completedTaskSnapshot.metrics.first { $0.title == "Release task" }?.tone, "attention")
  }

  func testMailboxReleaseReadinessSnapshotRequiresOpenReleaseTask() {
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
    store.reviewTasks = []

    let initialSnapshot = store.mailboxReleaseReadinessSnapshot
    XCTAssertTrue(initialSnapshot.reportText.contains("Release task gate: open task needed"))
    XCTAssertTrue(initialSnapshot.reportText.contains("Open mailbox release readiness tasks: 0"))
    XCTAssertEqual(initialSnapshot.metrics.first { $0.title == "Release task" }?.value, "0")
    XCTAssertEqual(initialSnapshot.metrics.first { $0.title == "Release task" }?.tone, "attention")

    store.createReviewTaskFromMailboxReleaseReadinessSnapshot()

    let openTaskSnapshot = store.mailboxReleaseReadinessSnapshot
    XCTAssertTrue(openTaskSnapshot.reportText.contains("Release task gate: open task present"))
    XCTAssertTrue(openTaskSnapshot.reportText.contains("Open mailbox release readiness tasks: 1"))
    XCTAssertEqual(openTaskSnapshot.metrics.first { $0.title == "Release task" }?.value, "1")
    XCTAssertEqual(openTaskSnapshot.metrics.first { $0.title == "Release task" }?.tone, "success")

    if let task = store.reviewTasks.first(where: {
      $0.linkedEntityType == .integration &&
        $0.linkedEntityID == "mailbox-release-readiness"
    }) {
      store.completeReviewTask(task)
    }

    let completedTaskSnapshot = store.mailboxReleaseReadinessSnapshot
    XCTAssertTrue(completedTaskSnapshot.reportText.contains("Release task gate: open task needed"))
    XCTAssertTrue(completedTaskSnapshot.reportText.contains("Completed mailbox release readiness tasks: 1"))
    XCTAssertEqual(completedTaskSnapshot.metrics.first { $0.title == "Release task" }?.value, "0")
    XCTAssertEqual(completedTaskSnapshot.metrics.first { $0.title == "Release task" }?.tone, "attention")
  }

  func testLocalDataHygieneSnapshotLogsWithoutMutatingOperationalRecords() {
    let mailboxID = UUID()
    let intake = ForwardedEmailIntake(
      sender: "Unknown sender",
      subject: "No subject",
      receivedDate: "Today",
      rawBodyPreview: "Content-Type: text/plain\nOrder details need review.",
      detectedMerchant: "Unknown Sender",
      detectedOrderNumber: "Order number needs review",
      detectedTrackingNumber: "Tracking number needs review",
      detectedDestinationAddress: "Destination needs review",
      linkedOrderID: nil,
      reviewState: .needsReview
    )
    let ingest = MailboxIngestRecord(
      providerMessageID: "provider-message-1",
      sourceMailboxID: mailboxID,
      intakeEmailID: intake.id,
      capturedDate: "Today",
      status: .imported,
      summary: "Imported test intake."
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.intakeEmails = [intake]
    store.mailboxIngestRecords = [ingest]
    store.orders = []
    store.reviewTasks = []
    store.auditEvents = []

    let beforeIntake = store.intakeEmails
    let beforeIngest = store.mailboxIngestRecords

    store.recordLocalDataHygieneSnapshot()

    XCTAssertEqual(store.intakeEmails, beforeIntake)
    XCTAssertEqual(store.mailboxIngestRecords, beforeIngest)
    XCTAssertTrue(store.orders.isEmpty)
    XCTAssertTrue(store.reviewTasks.isEmpty)
    XCTAssertEqual(store.auditEvents.count, 1)
    XCTAssertEqual(store.auditEvents.first?.action, .evaluated)
    XCTAssertEqual(store.auditEvents.first?.entityType, .settings)
    XCTAssertEqual(store.auditEvents.first?.entityID, "local-data-hygiene")
    XCTAssertEqual(store.auditEvents.first?.summary, "Local data hygiene snapshot recorded for operator review.")
    XCTAssertTrue(store.auditEvents.first?.afterDetail?.contains("Signal count:") == true)
    XCTAssertTrue(store.auditEvents.first?.afterDetail?.contains("Intake placeholders: 1") == true)
    XCTAssertTrue(store.auditEvents.first?.afterDetail?.contains("No mailbox refresh, Keychain read, network call, or mailbox mutation runs from this card.") == true)
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
    store.microsoft365MailboxConnections = []
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

  func testMailboxProviderReleaseGateBlocksGmailWhenCompiledCallbackMissing() {
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
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
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
        tokenStoreDetail: "GoogleSignIn cache only; no token values in JSON.",
        detailText: "Connected for local readiness test."
      )
    ]
    store.intakeEmails = []
    store.mailboxIngestRecords = []
    store.orders = []

    let gate = store.mailboxProviderReleaseGateSummary
    let gmailGate = gate.gates.first { $0.title == "Gmail compiled callback readiness" }

    XCTAssertEqual(gate.verdict, "Blocked")
    XCTAssertEqual(gate.tone, "warning")
    XCTAssertEqual(gmailGate?.isPassed, false)
    XCTAssertEqual(gmailGate?.tone, "warning")
    XCTAssertTrue(gmailGate?.evidence.contains("OAuth/client/callback blockers") == true)
    XCTAssertTrue(gmailGate?.nextAction.contains("compiled app Info.plist/project callback configuration") == true)
    XCTAssertTrue(gate.reportText.contains("Gmail compiled callback readiness"))
    XCTAssertTrue(gate.reportText.contains("compiled app Info.plist/project callback configuration"))
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

  func testMailboxProviderDraftQueueOnlyIncludesOpenProviderDrafts() {
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = []
    store.gmailMailboxConnections = []
    store.draftMessages = []

    store.createDraftMessageFromMailboxProviderTroubleshooting()
    let providerDraftID = store.draftMessages[0].id

    let closedProviderDraft = DraftMessage(
      linkedEntityType: .integration,
      linkedEntityID: "mailbox-provider-closed",
      templateID: nil,
      recipient: "ops@example.com",
      subject: "Mailbox provider diagnostics closed",
      body: "Mailbox provider diagnostic packet already sent.",
      channel: .email,
      createdDate: "1 Jul 2026",
      status: .sentLocally,
      reviewState: .accepted
    )
    let unrelatedDraft = DraftMessage(
      linkedEntityType: .order,
      linkedEntityID: UUID().uuidString,
      templateID: nil,
      recipient: "customer@example.com",
      subject: "General order note",
      body: "Follow up with customer.",
      channel: .email,
      createdDate: "1 Jul 2026",
      status: .draft,
      reviewState: .needsReview
    )
    store.draftMessages.append(contentsOf: [closedProviderDraft, unrelatedDraft])

    XCTAssertEqual(store.mailboxProviderDraftMessagesNeedingReview.map(\.id), [providerDraftID])
    XCTAssertTrue(store.draftMessagesNeedingReview.contains { $0.id == providerDraftID })
    XCTAssertFalse(store.mailboxProviderDraftMessagesNeedingReview.contains { $0.id == closedProviderDraft.id })
    XCTAssertFalse(store.mailboxProviderDraftMessagesNeedingReview.contains { $0.id == unrelatedDraft.id })
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
    let releaseTaskItem = summary.items.first { $0.title == "Release task assigned" }

    XCTAssertEqual(summary.verdict, "Gmail release blocked")
    XCTAssertEqual(summary.tone, "warning")
    XCTAssertEqual(summary.completedCount, 1)
    XCTAssertEqual(summary.totalCount, 8)
    XCTAssertEqual(setupItem?.tone, "warning")
    XCTAssertEqual(signInItem?.tone, "attention")
    XCTAssertEqual(refreshItem?.tone, "neutral")
    XCTAssertEqual(releaseTaskItem?.isComplete, false)
    XCTAssertEqual(releaseTaskItem?.tone, "attention")
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

    let refreshedSummary = store.gmailReleaseSelfCheckSummary(for: connection)
    let releaseTaskItem = refreshedSummary.items.first { $0.title == "Release task assigned" }
    XCTAssertEqual(releaseTaskItem?.isComplete, true)
    XCTAssertEqual(releaseTaskItem?.tone, "success")
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

  func testGmailReleaseSelfCheckRequiresOpenTaskNotCompletedHistory() {
    let mailboxID = UUID()
    let connection = makeGmailConnection(
      id: mailboxID,
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 10,
      imported: 0,
      filtered: 10,
      uncertain: nil
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = [connection]
    store.gmailAuthSessionStates = [:]
    store.reviewTasks = []

    let initialItem = store.gmailReleaseSelfCheckSummary(for: connection).items.first { $0.title == "Release task assigned" }
    XCTAssertEqual(initialItem?.isComplete, false)
    XCTAssertEqual(initialItem?.tone, "attention")

    store.createReviewTaskFromGmailReleaseSelfCheck(connection)

    let openItem = store.gmailReleaseSelfCheckSummary(for: connection).items.first { $0.title == "Release task assigned" }
    XCTAssertEqual(openItem?.isComplete, true)
    XCTAssertEqual(openItem?.tone, "success")

    if let task = store.reviewTasks.first(where: {
      $0.linkedEntityType == .integration
        && $0.linkedEntityID == mailboxID.uuidString
        && $0.title.localizedCaseInsensitiveContains("Gmail release self-check")
    }) {
      store.completeReviewTask(task)
    }

    let completedItem = store.gmailReleaseSelfCheckSummary(for: connection).items.first { $0.title == "Release task assigned" }
    XCTAssertEqual(completedItem?.isComplete, false)
    XCTAssertEqual(completedItem?.tone, "attention")
  }

  func testGmailReleaseReadinessSnapshotLogsWithoutExternalWork() {
    let connection = makeGmailConnection(
      oauthReadinessStatus: "Ready",
      credentialStorageStatus: "GoogleSignIn cache available",
      fetched: 10,
      imported: 1,
      filtered: 8,
      uncertain: 1
    )
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.gmailMailboxConnections = [connection]
    store.auditEvents = []

    store.recordGmailReleaseReadinessSnapshot()

    XCTAssertEqual(store.auditEvents.count, 1)
    let event = store.auditEvents[0]
    XCTAssertEqual(event.entityType, .gmailMailboxConnection)
    XCTAssertEqual(event.entityID, connection.id.uuidString)
    XCTAssertTrue(event.summary.contains("Gmail release snapshot"))
    XCTAssertTrue(event.afterDetail?.contains("ParcelOps Gmail local release snapshot") == true)
    XCTAssertTrue(event.afterDetail?.contains("No Google sign-in, Gmail API request, token access, mailbox fetch") == true)
  }

  func testGmailReleaseReadinessSnapshotRequiresOpenReleaseTask() {
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
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
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
        afterDetail: "Local audit evidence only."
      )
    ]

    store.recordGmailReleaseReadinessSnapshot()

    let missingTaskEvent = store.auditEvents.first
    XCTAssertTrue(missingTaskEvent?.summary.contains("Gmail release snapshot") == true)
    XCTAssertTrue(missingTaskEvent?.afterDetail?.contains("Release task gate: open task needed") == true)
    XCTAssertTrue(missingTaskEvent?.afterDetail?.contains("Open Gmail release self-check tasks: 0") == true)

    store.createReviewTaskFromGmailReleaseSelfCheck(connection)
    store.auditEvents = []
    store.recordGmailReleaseReadinessSnapshot()

    let openTaskEvent = store.auditEvents.first
    XCTAssertTrue(openTaskEvent?.summary.contains("Gmail release snapshot") == true)
    XCTAssertTrue(openTaskEvent?.summary != "Gmail release snapshot: release task needed")
    XCTAssertTrue(openTaskEvent?.afterDetail?.contains("Release task gate: open task present") == true)
    XCTAssertTrue(openTaskEvent?.afterDetail?.contains("Open Gmail release self-check tasks: 1") == true)

    if let task = store.reviewTasks.first {
      store.completeReviewTask(task)
    }
    store.auditEvents = []
    store.recordGmailReleaseReadinessSnapshot()

    let completedTaskEvent = store.auditEvents.first
    XCTAssertTrue(completedTaskEvent?.summary.contains("Gmail release snapshot") == true)
    XCTAssertTrue(completedTaskEvent?.afterDetail?.contains("Release task gate: open task needed") == true)
    XCTAssertTrue(completedTaskEvent?.afterDetail?.contains("Completed Gmail release self-check tasks: 1") == true)
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

  func testSpaceMailClassifierSuiteKeepsMixedMailboxDecisionsConservative() throws {
    var connection = makeSpaceMailConnection(
      credentialStorageStatus: "Password reference available",
      fetched: 0,
      imported: 0,
      filtered: 0,
      uncertain: 0
    )
    connection.mailboxMode = .mixedFiltered
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = [connection]
    store.intakeEmails = []
    store.mailboxIngestRecords = []
    store.auditEvents = []

    store.runSpaceMailClassifierTestSuite(for: connection)

    let updatedConnection = try XCTUnwrap(store.spaceMailIMAPConnections.first)
    let results = updatedConnection.classifierTestResults
    XCTAssertEqual(results.count, 9)
    XCTAssertEqual(results.first { $0.sampleName == "Expected import: clear order shipped" }?.decision, "Imported")
    XCTAssertEqual(results.first { $0.sampleName == "Expected import: clear order shipped" }?.detectedOrderNumber, "TEST-123")
    XCTAssertEqual(results.first { $0.sampleName == "Expected import: clear order shipped" }?.detectedTrackingNumber, "ABC123")
    XCTAssertEqual(results.first { $0.sampleName == "Expected uncertain: delivery question" }?.decision, "Uncertain")
    XCTAssertEqual(results.first { $0.sampleName == "Expected uncertain: order follow-up missing IDs" }?.decision, "Uncertain")
    XCTAssertEqual(results.first { $0.sampleName == "Expected filter: marketing final days" }?.decision, "Filtered")
    XCTAssertEqual(results.first { $0.sampleName == "Expected filter: free delivery marketing" }?.decision, "Filtered")
    XCTAssertEqual(results.first { $0.sampleName == "Expected filter: security alert" }?.decision, "Filtered")
    XCTAssertEqual(results.first { $0.sampleName == "Expected filter: generic receipt" }?.decision, "Filtered")
    XCTAssertEqual(results.first { $0.sampleName == "Expected import: refund with order" }?.decision, "Imported")
    XCTAssertEqual(results.first { $0.sampleName == "Expected import: tracking update" }?.decision, "Imported")
    XCTAssertTrue(results.allSatisfy { $0.decisionStatus.localizedCaseInsensitiveContains("passed") })
    XCTAssertTrue(results.filter { !$0.parserStatus.localizedCaseInsensitiveContains("No parser expectation") }.allSatisfy { $0.parserStatus.localizedCaseInsensitiveContains("passed") })
    XCTAssertTrue(updatedConnection.classifierTestSummary.contains("3 imported, 2 uncertain, 4 filtered"))
    XCTAssertTrue(store.intakeEmails.isEmpty)
    XCTAssertTrue(store.mailboxIngestRecords.isEmpty)
    XCTAssertTrue(store.auditEvents.contains { $0.summary == "SpaceMail classifier test suite ran locally." })
  }

  func testSpaceMailAmbiguousClassifierAddsUncertainPreviewWithoutInboxImport() throws {
    var connection = makeSpaceMailConnection(
      credentialStorageStatus: "Password reference available",
      fetched: 0,
      imported: 0,
      filtered: 0,
      uncertain: 0
    )
    connection.mailboxMode = .mixedFiltered
    let store = ParcelOpsStore(repository: InMemoryParcelOpsRepository())
    store.spaceMailIMAPConnections = [connection]
    store.intakeEmails = []
    store.mailboxIngestRecords = []
    store.auditEvents = []

    store.testSpaceMailAmbiguousClassifier(for: connection)

    let updatedConnection = try XCTUnwrap(store.spaceMailIMAPConnections.first)
    XCTAssertEqual(updatedConnection.uncertainMessages.count, 1)
    XCTAssertEqual(updatedConnection.uncertainMessages.first?.subject, "Delivery question")
    XCTAssertEqual(updatedConnection.uncertainMessages.first?.reason, "order/delivery question without detected id")
    XCTAssertEqual(updatedConnection.lastRefreshUncertainCount, 1)
    XCTAssertTrue(updatedConnection.lastRefreshSummary.contains("uncertain sample preview"))
    XCTAssertTrue(store.intakeEmails.isEmpty)
    XCTAssertTrue(store.mailboxIngestRecords.isEmpty)
    XCTAssertTrue(store.auditEvents.contains { $0.summary == "SpaceMail mixed-mailbox classifier sample tested locally." })
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

  private func makeWishlistItemWithRiskyFirstOption() throws -> (WishlistItem, WishlistComparisonOption) {
    var item = makeReadyWishlistItem(
      optionID: UUID(),
      itemName: "Replacement scanner",
      sellerName: "Known Australian retailer",
      linkedOrderID: nil
    )
    let riskyFirstOption = WishlistComparisonOption(
      sellerName: "First cheap risky seller",
      productURL: "https://risk-first.example/scanner",
      listedPrice: "18.00",
      currency: "USD",
      estimatedAUDTotal: "AUD 39 delivered",
      postageCost: "AUD 0",
      postageTime: "21-45 business days",
      sellerRegion: "Overseas",
      trustRating: "Unknown",
      trustNotes: "No returns or warranty evidence.",
      recommendation: "Do not prefer without review",
      lastChecked: "Today",
      localScore: 20,
      riskLevel: "High risk",
      decisionReason: "Cheap but poor trust evidence."
    )
    let trustedOption = try XCTUnwrap(item.comparisonOptions?.first)
    item.comparisonOptions = [riskyFirstOption, trustedOption]
    item.preferredOptionID = nil
    return (item, trustedOption)
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

  private func makeMicrosoft365Connection(
    id: UUID = UUID(),
    connectionStatus: String,
    lastManualRefreshDate: String
  ) -> Microsoft365MailboxConnection {
    Microsoft365MailboxConnection(
      id: id,
      displayName: "Outlook tracking inbox",
      tenantDomainHint: "example.test",
      mailboxAddress: "orders@example.test",
      monitoredFolderNames: "Inbox",
      connectionStatus: connectionStatus,
      lastManualRefreshDate: lastManualRefreshDate,
      setupNotes: "Local Outlook setup only.",
      reviewState: .needsReview,
      tenantIDPlaceholder: "tenant-id",
      clientIDPlaceholder: "client-id",
      redirectURIPlaceholder: "msauth.app.bitrig.parcelops://auth",
      requestedScopesSummary: "User.Read Mail.Read",
      oauthReadinessStatus: "Ready",
      consentAdminNotes: "Consent reviewed locally.",
      oauthImplementationPlanStatus: "Reviewed"
    )
  }
}

private actor RecordingGmailMailboxClient: GmailMailboxClient {
  private var fetchCount = 0

  func fetchMessages(for connection: GmailMailboxConnection, sourceMailboxID: UUID) async -> GmailMailboxFetchResult {
    fetchCount += 1
    return GmailMailboxFetchResult(
      status: .success,
      messages: [
        FetchedMailboxMessage(
          providerMessageID: "recording-gmail-\(sourceMailboxID.uuidString)",
          sender: connection.emailAddress,
          subject: "Order TEST-CLIENT shipped tracking CLIENT123",
          receivedDate: "Recording client",
          plainTextBodyPreview: "Order TEST-CLIENT shipped tracking CLIENT123.",
          sourceMailboxID: sourceMailboxID
        )
      ],
      detail: "Recording Gmail client was called."
    )
  }

  func callCount() -> Int {
    fetchCount
  }
}
