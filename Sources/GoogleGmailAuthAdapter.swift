import Foundation

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

struct GoogleGmailAuthAdapter {
  static let bundleID = "app.bitrig.parcelops"
  static let placeholderClientID = "GMAIL_CLIENT_ID_PLACEHOLDER_REPLACE_BEFORE_REAL_SIGN_IN"
  static let placeholderCallbackScheme = "com.googleusercontent.apps.parcelops-placeholder"

  var dependencyStatus: String {
    #if canImport(GoogleSignIn)
    "GoogleSignIn package is linked for compile-time readiness."
    #else
    "GoogleSignIn package is not available to this build."
    #endif
  }

  static func isPotentialCallbackURL(_ url: URL) -> Bool {
    url.scheme == Self.placeholderCallbackScheme || (url.scheme ?? "").hasPrefix("com.googleusercontent.apps.")
  }

  func setupReadinessDetail(for connection: GmailMailboxConnection) -> String {
    let problems = GmailReadinessValidator.problems(for: connection, checkBundle: true)
    let missingText = problems.isEmpty ? "No missing setup values detected." : "Missing or blocked: \(problems.joined(separator: ", "))."
    return "\(dependencyStatus) \(missingText) Real Gmail sign-in is opt-in from the explicit test action. Use a Google Cloud iOS OAuth client ID ending in .apps.googleusercontent.com, set the reversed client ID URL scheme in ParcelOps, and make sure the compiled App Info.plist GIDClientID and URL scheme match before opening browser sign-in."
  }

  @MainActor
  func callbackReadinessStatus(for url: URL) -> String {
    guard Self.isPotentialCallbackURL(url) else {
      return "Ignored non-Gmail callback URL."
    }

    #if canImport(GoogleSignIn)
    let handled = GIDSignIn.sharedInstance.handle(url)
    return handled
      ? "Gmail callback URL scheme detected and forwarded to GoogleSignIn. No Gmail API mailbox fetch was started by this callback."
      : "Gmail callback URL scheme detected, but GoogleSignIn did not match it to an active sign-in session. Real Gmail sign-in is not enabled yet."
    #else
    return "Gmail callback URL scheme detected, but GoogleSignIn is not linked in this build."
    #endif
  }
}

struct GoogleGmailAuthClient: GmailAuthClient {
  func connect(connection: GmailMailboxConnection) async -> GmailAuthResult {
    #if canImport(GoogleSignIn)
    let missingFields = missingReadinessFields(for: connection)
    guard missingFields.isEmpty else {
      return GmailAuthResult(
        status: .notConfigured,
        signedInAccount: "Not signed in",
        detailText: "Setup incomplete: \(missingFields.joined(separator: ", ")). Real Gmail sign-in was not started, no browser opened, no token request was made, no Keychain token access occurred, and no Gmail API mailbox call was made."
      )
    }

    return await performInteractiveSignIn(connection: connection)
    #else
    return GmailAuthResult(
      status: .notConfigured,
      signedInAccount: "Not signed in",
      detailText: "Real Gmail sign-in is unavailable because GoogleSignIn is not linked in this build."
    )
    #endif
  }

  func simulateFailure(connection: GmailMailboxConnection) async -> GmailAuthResult {
    GmailAuthResult(
      status: .authFailed,
      signedInAccount: "Not signed in",
      detailText: "Real Gmail sign-in failure simulation is not used. Use mock Gmail auth for local failure testing."
    )
  }

  private func missingReadinessFields(for connection: GmailMailboxConnection) -> [String] {
    GmailReadinessValidator.problems(for: connection, checkBundle: true)
  }

  private func readOnlyScopes(from connection: GmailMailboxConnection) -> [String] {
    let summary = connection.requestedScopesSummary
    let candidates = summary
      .replacingOccurrences(of: ",", with: " ")
      .replacingOccurrences(of: "\n", with: " ")
      .split(separator: " ")
      .map(String.init)
    let scopes = candidates.filter { value in
      value.localizedCaseInsensitiveContains("gmail.readonly")
        || value.localizedCaseInsensitiveContains("gmail.metadata")
    }
    if scopes.isEmpty {
      return []
    }
    return scopes.map { value in
      if value.localizedCaseInsensitiveContains("gmail.readonly") {
        return "https://www.googleapis.com/auth/gmail.readonly"
      }
      if value.localizedCaseInsensitiveContains("gmail.metadata") {
        return "https://www.googleapis.com/auth/gmail.metadata"
      }
      return value
    }
  }

  #if canImport(GoogleSignIn)
  @MainActor
  private func performInteractiveSignIn(connection: GmailMailboxConnection) async -> GmailAuthResult {
    let clientID = (connection.oauthClientIDPlaceholder ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    let scopes = readOnlyScopes(from: connection)

    do {
      let result = try await signIn(connection: connection, scopes: scopes)
      let user = result.user
      let email = user.profile?.email ?? connection.emailAddress
      let granted = user.grantedScopes ?? []
      let hasReadScope = granted.contains { scope in
        scope.localizedCaseInsensitiveContains("gmail.readonly")
          || scope.localizedCaseInsensitiveContains("gmail.metadata")
      }
      let scopeSummary = granted.isEmpty ? "No optional scopes reported" : granted.map(safeScopeLabel).joined(separator: ", ")
      return GmailAuthResult(
        status: hasReadScope ? .connected : .consentRequired,
        signedInAccount: email.isEmpty ? "Signed in Google account" : email,
        detailText: "Real Gmail sign-in completed through GoogleSignIn. Granted scopes: \(scopeSummary). Read-only Gmail scope present: \(hasReadScope ? "yes" : "no"). GoogleSignIn may manage its own token cache, but ParcelOps did not store or log access tokens, refresh tokens, ID tokens, auth codes, client secrets, passwords, raw callback URLs, or Gmail messages. No Gmail API mailbox call was made."
      )
    } catch {
      return GmailAuthResult(
        status: authStatus(for: error),
        signedInAccount: "Not signed in",
        detailText: authFailureDetail(for: error)
      )
    }
  }

  @MainActor
  private func signIn(connection: GmailMailboxConnection, scopes: [String]) async throws -> GIDSignInResult {
    try await withCheckedThrowingContinuation { continuation in
      #if os(iOS)
      guard let presenter = Self.activeViewController() else {
        continuation.resume(throwing: GoogleGmailAuthError.missingPresentationSurface)
        return
      }
      GIDSignIn.sharedInstance.signIn(
        withPresenting: presenter,
        hint: connection.emailAddress,
        additionalScopes: scopes
      ) { result, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        guard let result else {
          continuation.resume(throwing: GoogleGmailAuthError.missingSignInResult)
          return
        }
        continuation.resume(returning: result)
      }
      #elseif os(macOS)
      guard let presenter = Self.activeWindow() else {
        continuation.resume(throwing: GoogleGmailAuthError.missingPresentationSurface)
        return
      }
      GIDSignIn.sharedInstance.signIn(
        withPresenting: presenter,
        hint: connection.emailAddress,
        additionalScopes: scopes
      ) { result, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        guard let result else {
          continuation.resume(throwing: GoogleGmailAuthError.missingSignInResult)
          return
        }
        continuation.resume(returning: result)
      }
      #else
      continuation.resume(throwing: GoogleGmailAuthError.unsupportedPlatform)
      #endif
    }
  }

  private func authStatus(for error: Error) -> GmailAuthStatus {
    let nsError = error as NSError
    let text = "\(nsError.domain) \(nsError.code) \(nsError.localizedDescription)".lowercased()
    if text.contains("cancel") {
      return .notConnected
    }
    if text.contains("consent") || text.contains("scope") || text.contains("access_denied") {
      return .consentRequired
    }
    if error is GoogleGmailAuthError {
      return .authFailed
    }
    return .authFailed
  }

  private func authFailureDetail(for error: Error) -> String {
    let nsError = error as NSError
    let suffix = "No Google access token, refresh token, ID token, auth code, client secret, password, raw callback URL, or Gmail message was stored in ParcelOps JSON or audit logs. No Gmail API mailbox call was made."
    if error is GoogleGmailAuthError {
      return "Missing presentation surface: ParcelOps could not find an active app window or view controller for Google sign-in. Bring the app window forward and try again. \(suffix)"
    }
    let safeSummary = "\(nsError.domain) code \(nsError.code): \(nsError.localizedDescription)"
    let lowerSummary = safeSummary.lowercased()
    if lowerSummary.contains("cancel") {
      return "Google sign-in was cancelled or closed before completion. \(suffix)"
    }
    if lowerSummary.contains("url") || lowerSummary.contains("redirect") || lowerSummary.contains("scheme") {
      return "Google sign-in failed with a redirect or URL scheme issue: \(safeSummary). Check that the app Info.plist URL scheme matches the reversed iOS OAuth client ID from Google Cloud. \(suffix)"
    }
    if lowerSummary.contains("access_denied") || lowerSummary.contains("consent") || lowerSummary.contains("scope") {
      return "Google sign-in requires consent or scope review: \(safeSummary). Confirm the OAuth consent screen and read-only Gmail scope configuration in Google Cloud. \(suffix)"
    }
    return "Google sign-in failed: \(safeSummary). Check Google Cloud OAuth client type, bundle ID \(GoogleGmailAuthAdapter.bundleID), URL scheme, consent screen, Xcode signing, and network access. \(suffix)"
  }

  private func safeScopeLabel(_ scope: String) -> String {
    if scope.localizedCaseInsensitiveContains("gmail.readonly") { return "gmail.readonly" }
    if scope.localizedCaseInsensitiveContains("gmail.metadata") { return "gmail.metadata" }
    if scope.localizedCaseInsensitiveContains("openid") { return "openid" }
    if scope.localizedCaseInsensitiveContains("email") { return "email" }
    if scope.localizedCaseInsensitiveContains("profile") { return "profile" }
    return "other"
  }

  #if canImport(UIKit)
  @MainActor
  private static func activeViewController() -> UIViewController? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first { $0.isKeyWindow }?
      .rootViewController
  }
  #endif

  #if canImport(AppKit)
  @MainActor
  private static func activeWindow() -> NSWindow? {
    NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first { $0.isVisible }
  }
  #endif
  #endif
}

private enum GmailReadinessValidator {
  static func problems(for connection: GmailMailboxConnection, checkBundle: Bool) -> [String] {
    var problems: [String] = []
    let email = connection.emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    let clientID = normalized((connection.oauthClientIDPlaceholder ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
    let redirectScheme = urlScheme(from: (connection.redirectURIPlaceholder ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
    let scopes = connection.requestedScopesSummary.trimmingCharacters(in: .whitespacesAndNewlines)

    if email.isEmpty {
      problems.append("Gmail address")
    }

    if clientID.isEmpty {
      problems.append("Google OAuth iOS client ID")
    } else if isPlaceholderClientID(clientID) {
      problems.append("placeholder Google OAuth iOS client ID")
    } else if expectedReversedClientID(for: clientID) == nil {
      problems.append("Google OAuth iOS client ID must end in .apps.googleusercontent.com")
    }

    if redirectScheme.isEmpty {
      problems.append("reversed client ID URL scheme")
    } else if isPlaceholderCallbackScheme(redirectScheme) {
      problems.append("placeholder Gmail callback URL scheme")
    } else if !redirectScheme.hasPrefix("com.googleusercontent.apps.") {
      problems.append("Gmail callback URL scheme must start with com.googleusercontent.apps.")
    }

    if let expectedScheme = expectedReversedClientID(for: clientID),
       !redirectScheme.isEmpty,
       !isPlaceholderCallbackScheme(redirectScheme),
       redirectScheme != expectedScheme {
      problems.append("callback URL scheme does not match the reversed Google OAuth client ID")
    }

    if !scopes.localizedCaseInsensitiveContains("gmail.readonly")
      && !scopes.localizedCaseInsensitiveContains("gmail.metadata") {
      problems.append("read-only Gmail scope")
    }

    guard checkBundle else {
      return problems
    }

    let bundleClientID = normalized(Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String ?? "")
    if bundleClientID.isEmpty {
      problems.append("compiled App Info.plist GIDClientID")
    } else if isPlaceholderClientID(bundleClientID) {
      problems.append("compiled App Info.plist GIDClientID is still the placeholder")
    } else if !clientID.isEmpty, !isPlaceholderClientID(clientID), bundleClientID != clientID {
      problems.append("compiled App Info.plist GIDClientID does not match this Gmail setup")
    }

    let bundleSchemes = bundleURLSchemes()
    if !redirectScheme.isEmpty,
       !isPlaceholderCallbackScheme(redirectScheme),
       !bundleSchemes.contains(redirectScheme) {
      problems.append("compiled App Info.plist does not register this Gmail callback URL scheme")
    }
    if bundleSchemes.contains(GoogleGmailAuthAdapter.placeholderCallbackScheme),
       !bundleSchemes.contains(redirectScheme) {
      problems.append("compiled App Info.plist still contains only the placeholder Gmail callback scheme")
    }

    return Array(NSOrderedSet(array: problems).compactMap { $0 as? String })
  }

  private static func normalized(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func urlScheme(from value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return ""
    }
    if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty {
      return scheme
    }
    if let scheme = trimmed.components(separatedBy: "://").first, scheme != trimmed {
      return scheme
    }
    if let scheme = trimmed.components(separatedBy: ":").first, scheme != trimmed {
      return scheme
    }
    return trimmed
  }

  private static func expectedReversedClientID(for clientID: String) -> String? {
    let suffix = ".apps.googleusercontent.com"
    guard clientID.hasSuffix(suffix), clientID.count > suffix.count else {
      return nil
    }
    return "com.googleusercontent.apps.\(clientID.dropLast(suffix.count))"
  }

  private static func isPlaceholderClientID(_ value: String) -> Bool {
    value.isEmpty
      || value == GoogleGmailAuthAdapter.placeholderClientID
      || value.localizedCaseInsensitiveContains("placeholder")
      || value.localizedCaseInsensitiveContains("replace_before_real")
  }

  private static func isPlaceholderCallbackScheme(_ value: String) -> Bool {
    value.isEmpty
      || value == GoogleGmailAuthAdapter.placeholderCallbackScheme
      || value.localizedCaseInsensitiveContains("parcelops-placeholder")
      || value.localizedCaseInsensitiveContains("placeholder")
  }

  private static func bundleURLSchemes() -> [String] {
    guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
      return []
    }
    return urlTypes.flatMap { entry -> [String] in
      (entry["CFBundleURLSchemes"] as? [String]) ?? []
    }
  }
}

enum GoogleGmailAuthError: Error {
  case missingPresentationSurface
  case missingSignInResult
  case unsupportedPlatform
}
