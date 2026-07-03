import Foundation

enum SpaceMailMailboxRelevanceDecision: String {
  case likelyOrder
  case uncertain
  case nonOrder
}

struct SpaceMailMailboxRelevanceResult {
  var decision: SpaceMailMailboxRelevanceDecision
  var score: Int
  var reason: String
  var positiveEvidenceLabels: [String] = []
  var cautionLabels: [String] = []
}

enum SpaceMailMailboxRelevanceClassifier {
  static func classify(
    message: FetchedMailboxMessage,
    connection: SpaceMailIMAPConnection
  ) -> SpaceMailMailboxRelevanceResult {
    let text = "\(message.sender)\n\(message.subject)\n\(message.plainTextBodyPreview)"
    let lowercasedText = text.lowercased()
    let lowercasedSender = message.sender.lowercased()
    let orderNumber = detectedOrderNumber(in: text)
    let trackingNumber = detectedTrackingNumber(in: text, excluding: orderNumber)
    let hasOrderNumber = !orderNumber.isPlaceholderValidationValue
    let hasTrackingNumber = !trackingNumber.isPlaceholderValidationValue
    let trustedSenderHint = firstConfiguredHint(in: lowercasedSender, hints: connection.trustedSenderHints)
    let importKeywordHint = firstConfiguredHint(in: lowercasedText, hints: connection.importKeywordHints)
    let uncertainKeywordHint = firstConfiguredHint(in: lowercasedText, hints: connection.uncertainKeywordHints)
    let filterKeywordHint = firstConfiguredHint(in: lowercasedText, hints: connection.filterKeywordHints)

    let strongOrderSignals = [
      "order ", "order:", "order #", "order number", "order no", "order id",
      "purchase order", "po ", "refund", "return", "replacement", "claim"
    ]
    let strongShipmentSignals = [
      "tracking", "tracking number", "shipment", "shipped", "shipping", "dispatch",
      "dispatched", "delivery", "delivered", "parcel", "package", "courier", "carrier",
      "consignment", "waybill", "awb", "in transit", "out for delivery"
    ]
    let hardNonOrderSignals = [
      "newsletter", "promotion", "marketing", "sale ends", "final days",
      "password reset", "security alert", "verification code", "calendar", "invitation",
      "webinar", "social", "follow us"
    ]
    let footerSignals = ["unsubscribe", "privacy policy", "terms of service", "view this email", "sent securely from spacemail"]
    let orderQuestionSignals = [
      "delivery question", "order question", "relates to an order", "related to an order",
      "about an order", "where is my order", "do not have the tracking", "don't have the tracking",
      "tracking number yet", "tracking yet", "missing tracking"
    ]

    let hasStrongOrderSignal = strongOrderSignals.contains { lowercasedText.contains($0) }
    let hasStrongShipmentSignal = strongShipmentSignals.contains { lowercasedText.contains($0) }
    let hasHardNonOrderSignal = hardNonOrderSignals.contains { lowercasedText.contains($0) }
    let hasFooterSignal = footerSignals.contains { lowercasedText.contains($0) }
    let hasOrderQuestionSignal = orderQuestionSignals.contains { lowercasedText.contains($0) }
      || firstMatch(in: text, pattern: #"(?i)\border\s*(?:\?|\.|,|$)"#) != nil
    let hasClearShipmentPhrase = firstMatch(
      in: text,
      pattern: #"(?i)\border\s+[A-Z0-9][A-Z0-9._/-]{2,30}\s+(?:has\s+)?(?:shipped|shipping|dispatched|sent)\s+(?:with\s+)?tracking\s+[A-Z0-9][A-Z0-9 -]{4,34}"#
    ) != nil

    var score = 0
    if hasOrderNumber { score += 35 }
    if hasTrackingNumber { score += 35 }
    if hasStrongOrderSignal { score += 18 }
    if hasStrongShipmentSignal { score += 18 }
    if hasOrderQuestionSignal { score += 16 }
    if hasClearShipmentPhrase { score += 30 }
    if trustedSenderHint != nil { score += 10 }
    if importKeywordHint != nil { score += 14 }
    if uncertainKeywordHint != nil { score += 10 }
    if filterKeywordHint != nil { score -= 50 }
    if hasHardNonOrderSignal { score -= 45 }
    if hasFooterSignal { score -= 8 }

    let positiveEvidenceLabels = classifierPositiveLabels(
      orderNumber: orderNumber,
      trackingNumber: trackingNumber,
      hasStrongOrderSignal: hasStrongOrderSignal,
      hasStrongShipmentSignal: hasStrongShipmentSignal,
      hasClearShipmentPhrase: hasClearShipmentPhrase,
      trustedSenderHint: trustedSenderHint,
      importKeywordHint: importKeywordHint,
      uncertainKeywordHint: uncertainKeywordHint
    )
    let cautionLabels = classifierCautionLabels(
      orderNumber: orderNumber,
      trackingNumber: trackingNumber,
      lowercasedText: lowercasedText,
      filterKeywordHint: filterKeywordHint,
      hasHardNonOrderSignal: hasHardNonOrderSignal,
      hasFooterSignal: hasFooterSignal,
      score: score
    )

    func result(_ decision: SpaceMailMailboxRelevanceDecision, _ reason: String) -> SpaceMailMailboxRelevanceResult {
      SpaceMailMailboxRelevanceResult(
        decision: decision,
        score: score,
        reason: reason,
        positiveEvidenceLabels: ["Decision: \(reason)"] + positiveEvidenceLabels,
        cautionLabels: cautionLabels + ["Score: \(score)"]
      )
    }

    if hasOrderQuestionSignal && !hasHardNonOrderSignal && !(hasOrderNumber || hasTrackingNumber || hasClearShipmentPhrase) {
      return result(.uncertain, "order/delivery question without detected id")
    }

    if let filterKeywordHint, !(hasClearShipmentPhrase || ((hasOrderNumber || hasTrackingNumber) && (hasStrongOrderSignal || hasStrongShipmentSignal || importKeywordHint != nil))) {
      return result(.nonOrder, "local filter hint: \(filterKeywordHint)")
    }

    if hasClearShipmentPhrase {
      return result(.likelyOrder, "clear order-shipped-tracking phrase")
    }

    if let importKeywordHint, (hasOrderNumber || hasTrackingNumber) && (hasStrongOrderSignal || hasStrongShipmentSignal || trustedSenderHint != nil) {
      return result(.likelyOrder, "local import hint with detected id: \(importKeywordHint)")
    }

    if let trustedSenderHint, (hasOrderNumber || hasTrackingNumber) && (hasStrongOrderSignal || hasStrongShipmentSignal) {
      return result(.likelyOrder, "trusted sender hint with detected id: \(trustedSenderHint)")
    }

    if hasHardNonOrderSignal && !(hasOrderNumber || hasTrackingNumber) {
      return result(.nonOrder, "non-order signal without order/tracking id")
    }

    if hasHardNonOrderSignal && !(hasStrongOrderSignal && (hasOrderNumber || hasTrackingNumber)) {
      return result(.nonOrder, "marketing/security/social signal")
    }

    if hasStrongOrderSignal && hasStrongShipmentSignal && (hasOrderNumber || hasTrackingNumber) {
      return result(.likelyOrder, "order/shipping signal with detected id")
    }

    if hasStrongShipmentSignal && hasTrackingNumber {
      return result(.likelyOrder, "tracking/shipping signal with tracking id")
    }

    if hasStrongOrderSignal && hasOrderNumber {
      return result(.likelyOrder, "order/refund signal with order id")
    }

    if (hasOrderNumber || hasTrackingNumber) && (hasStrongOrderSignal || hasStrongShipmentSignal) {
      return result(.uncertain, "weak order signal with detected id")
    }

    if let uncertainKeywordHint, hasStrongOrderSignal || hasStrongShipmentSignal || hasOrderQuestionSignal || lowercasedText.contains("order") || lowercasedText.contains("tracking") || lowercasedText.contains("delivery") {
      return result(.uncertain, "local uncertain hint: \(uncertainKeywordHint)")
    }

    if let trustedSenderHint, hasStrongOrderSignal || hasStrongShipmentSignal || hasOrderQuestionSignal {
      return result(.uncertain, "trusted sender hint without detected id: \(trustedSenderHint)")
    }

    if hasOrderQuestionSignal && (hasStrongOrderSignal || hasStrongShipmentSignal || lowercasedText.contains("order") || lowercasedText.contains("tracking")) {
      return result(.uncertain, "order/delivery question without detected id")
    }

    if hasStrongOrderSignal || hasStrongShipmentSignal {
      return result(.uncertain, "order/shipping words without detected id")
    }

    return result(.nonOrder, "no strong order evidence")
  }

  private static func classifierPositiveLabels(
    orderNumber: String,
    trackingNumber: String,
    hasStrongOrderSignal: Bool,
    hasStrongShipmentSignal: Bool,
    hasClearShipmentPhrase: Bool,
    trustedSenderHint: String?,
    importKeywordHint: String?,
    uncertainKeywordHint: String?
  ) -> [String] {
    var labels: [String] = []
    if !orderNumber.isPlaceholderValidationValue {
      labels.append("Detected order ID")
    }
    if !trackingNumber.isPlaceholderValidationValue {
      labels.append("Detected tracking ID")
    }
    if hasStrongOrderSignal {
      labels.append("Order/refund wording")
    }
    if hasStrongShipmentSignal {
      labels.append("Shipping/delivery wording")
    }
    if hasClearShipmentPhrase {
      labels.append("Order-shipped-tracking phrase")
    }
    if let trustedSenderHint {
      labels.append("Trusted sender hint: \(trustedSenderHint)")
    }
    if let importKeywordHint {
      labels.append("Import hint: \(importKeywordHint)")
    }
    if let uncertainKeywordHint {
      labels.append("Uncertain hint: \(uncertainKeywordHint)")
    }
    return deduplicated(labels, limit: 8)
  }

  private static func classifierCautionLabels(
    orderNumber: String,
    trackingNumber: String,
    lowercasedText: String,
    filterKeywordHint: String?,
    hasHardNonOrderSignal: Bool,
    hasFooterSignal: Bool,
    score: Int
  ) -> [String] {
    var labels: [String] = []
    let nonOrderSignals = [
      "newsletter", "promotion", "marketing", "sale ends", "final days",
      "password reset", "security alert", "verification code", "calendar",
      "invitation", "webinar", "social", "follow us"
    ]
    if hasHardNonOrderSignal,
       let matchedSignal = nonOrderSignals.first(where: { lowercasedText.contains($0) }) {
      labels.append("Non-order signal: \(matchedSignal)")
    }
    if let filterKeywordHint {
      labels.append("Filter hint: \(filterKeywordHint)")
    }
    if orderNumber.isPlaceholderValidationValue && trackingNumber.isPlaceholderValidationValue {
      labels.append("No order/tracking ID detected")
    }
    if hasFooterSignal {
      labels.append("Marketing/footer wording")
    }
    if labels.isEmpty && score < 35 {
      labels.append("No strong order evidence")
    }
    return deduplicated(labels, limit: 8)
  }

  private static func deduplicated(_ labels: [String], limit: Int) -> [String] {
    var seen = Set<String>()
    var result: [String] = []
    for label in labels where !seen.contains(label) {
      seen.insert(label)
      result.append(label)
      if result.count == limit { break }
    }
    return result
  }

  private static func detectedOrderNumber(in text: String) -> String {
    let patterns = [
      #"(?i)\border\s+([A-Z0-9][A-Z0-9._/-]{2,30})\s+(?:has\s+)?(?:shipped|shipping|dispatched|sent)\b"#,
      #"(?i)\b(?:order|order\s+no\.?|order\s+number|order\s+id|order\s+ref(?:erence)?|purchase\s+order|po)\s*[:#-]?\s*([A-Z0-9][A-Z0-9._/-]{2,30})"#,
      #"(?i)\b(?:confirmation|receipt|invoice)\s*(?:number|no\.?|id|ref(?:erence)?)\s*[:#-]?\s*([A-Z0-9][A-Z0-9._/-]{2,30})"#,
      #"\b[A-Z]{2,8}-\d{3,12}\b"#,
      #"\b[A-Z]{2,8}\d{4,14}\b"#
    ]
    for pattern in patterns {
      if let value = firstMatch(in: text, pattern: pattern).flatMap(cleanDetectedIdentifier),
         isLikelyOrderIdentifier(value) {
        return value
      }
    }
    return "Order number needs review"
  }

  private static func detectedTrackingNumber(in text: String, excluding orderNumber: String) -> String {
    let patterns = [
      #"(?i)\b(?:shipped|shipping|shipment)\s+(?:with\s+)?tracking\s*[:#-]?\s*([A-Z0-9][A-Z0-9 -]{4,34}?)(?=\s+(?:sent|from|via|to|for|https?://)|[.,;\n\r]|$)"#,
      #"(?i)\b(?:tracking|tracking\s+number|tracking\s+no\.?|track\s+no\.?|shipment\s+number|shipment\s+id|parcel\s+number|consignment|consignment\s+number|awb|waybill)\s*[:#-]?\s*([A-Z0-9][A-Z0-9 -]{4,34}?)(?=\s+(?:sent|from|via|to|for|https?://)|[.,;\n\r]|$)"#,
      #"(?i)\b(?:carrier|courier)\s*(?:ref(?:erence)?|number|no\.?)\s*[:#-]?\s*([A-Z0-9][A-Z0-9 -]{4,34}?)(?=\s+(?:sent|from|via|to|for|https?://)|[.,;\n\r]|$)"#,
      #"\b(?:1Z[0-9A-Z]{16}|[A-Z]{2}\d{9}[A-Z]{2}|[A-Z]{2,6}\d{6,22}[A-Z0-9]*)\b"#
    ]
    for pattern in patterns {
      if let value = firstMatch(in: text, pattern: pattern).flatMap(cleanDetectedIdentifier),
         value.normalizedValidationKey != orderNumber.normalizedValidationKey,
         isLikelyTrackingIdentifier(value) {
        return value
      }
    }
    return "Tracking number needs review"
  }

  private static func firstConfiguredHint(in text: String, hints: [String]) -> String? {
    hints
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .first { text.contains($0.lowercased()) }
  }

  private static func firstMatch(in text: String, pattern: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, range: range) else { return nil }
    let captureRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range(at: 0)
    guard let swiftRange = Range(captureRange, in: text) else { return nil }
    return String(text[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func cleanDetectedIdentifier(_ value: String) -> String? {
    var cleaned = value
      .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
      .trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n.,;:()[]{}<>\"'"))
    let boilerplateMarkers = ["SENTSECURELY", "SENTFROM", "FROM", "HTTPS", "HTTP", "VIEW", "CLICK"]
    for marker in boilerplateMarkers {
      if let range = cleaned.range(of: marker, options: [.caseInsensitive]),
         cleaned.distance(from: cleaned.startIndex, to: range.lowerBound) >= 5 {
        cleaned = String(cleaned[..<range.lowerBound])
      }
    }
    guard cleaned.count >= 3 else { return nil }
    return cleaned
  }

  private static func isLikelyOrderIdentifier(_ value: String) -> Bool {
    let normalized = value.normalizedValidationKey
    guard normalized.count >= 3 else { return false }
    let rejected = ["ORDER", "NUMBER", "TRACKING", "SHIPPED", "SHIPPING", "SENT", "SECURELY", "SPACEMAIL", "FINAL", "DAYS"]
    return !rejected.contains(normalized)
  }

  private static func isLikelyTrackingIdentifier(_ value: String) -> Bool {
    let normalized = value.normalizedValidationKey
    guard normalized.count >= 5 else { return false }
    let rejected = ["TRACKING", "NUMBER", "ORDER", "SHIPPED", "SHIPPING", "SENTSECURELY", "SPACEMAIL"]
    return !rejected.contains(normalized)
  }
}
