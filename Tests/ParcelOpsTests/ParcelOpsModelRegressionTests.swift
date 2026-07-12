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
