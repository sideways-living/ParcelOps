import Foundation

#if canImport(GoogleSignIn)
import GoogleSignIn
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

  func setupReadinessDetail(for connection: GmailMailboxConnection) -> String {
    var missing: [String] = []
    if connection.emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      missing.append("Gmail address")
    }
    let clientID = (connection.oauthClientIDPlaceholder ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if clientID.isEmpty {
      missing.append("Google OAuth iOS client ID")
    }
    let redirect = (connection.redirectURIPlaceholder ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if redirect.isEmpty {
      missing.append("reversed client ID URL scheme")
    }
    let scopes = connection.requestedScopesSummary.trimmingCharacters(in: .whitespacesAndNewlines)
    if !scopes.localizedCaseInsensitiveContains("gmail.readonly") && !scopes.localizedCaseInsensitiveContains("gmail.metadata") {
      missing.append("read-only Gmail scope")
    }

    let missingText = missing.isEmpty ? "No missing setup values detected." : "Missing: \(missing.joined(separator: ", "))."
    return "\(dependencyStatus) \(missingText) Real Gmail sign-in still is not invoked by ParcelOps. Replace the placeholder GIDClientID and callback URL scheme with the Google Cloud iOS OAuth client values before enabling a browser sign-in flow."
  }

  @MainActor
  func callbackReadinessStatus(for url: URL) -> String {
    guard url.scheme == Self.placeholderCallbackScheme else {
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
