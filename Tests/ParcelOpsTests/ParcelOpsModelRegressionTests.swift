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

  private func makeSpaceMailConnection(
    credentialStorageStatus: String,
    fetched: Int,
    imported: Int,
    filtered: Int,
    uncertain: Int
  ) -> SpaceMailIMAPConnection {
    SpaceMailIMAPConnection(
      displayName: "SpaceMail tracking inbox",
      emailAddressUsername: "orders@example.test",
      imapHost: "mail.spacemail.com",
      imapPort: "993",
      securityMode: "SSL/TLS",
      folderName: "INBOX",
      connectionStatus: "Ready for IMAP",
      lastManualRefreshDate: "Today",
      setupNotes: "Local setup only",
      credentialStorageStatus: credentialStorageStatus,
      lastRefreshFetchedCount: fetched,
      lastRefreshImportedCount: imported,
      lastRefreshFilteredNonOrderCount: filtered,
      lastRefreshUncertainCount: uncertain,
      reviewState: .accepted
    )
  }

  private func makeGmailConnection(
    oauthReadinessStatus: String,
    credentialStorageStatus: String,
    fetched: Int,
    imported: Int,
    filtered: Int,
    uncertain: Int?
  ) -> GmailMailboxConnection {
    GmailMailboxConnection(
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
