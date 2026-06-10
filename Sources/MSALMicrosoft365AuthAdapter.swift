import Foundation

#if canImport(MSAL)
import MSAL
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

struct MSALMicrosoft365AuthAdapter {
  static let bundleID = "app.bitrig.parcelops"
  static let redirectScheme = "msauth.app.bitrig.parcelops"
  static let redirectURI = "msauth.app.bitrig.parcelops://auth"
  static let iOSKeychainGroup = "com.microsoft.adalcache"
  static let macOSKeychainGroup = "com.microsoft.identity.universalstorage"

  var dependencyStatus: String {
    #if canImport(MSAL)
    "MSAL package is linked for compile-time readiness."
    #else
    "MSAL package is not available to this build."
    #endif
  }

  @MainActor
  func callbackReadinessStatus(for url: URL) -> String {
    guard url.scheme == Self.redirectScheme else {
      return "Ignored non-MSAL callback URL."
    }
    #if canImport(MSAL) && os(iOS)
    let handled = MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: nil)
    return handled
      ? "MSAL callback URL scheme detected and forwarded to the Microsoft sign-in completion handler."
      : "MSAL callback URL scheme detected, but MSAL did not match it to an active sign-in session."
    #elseif canImport(MSAL) && os(macOS)
    return "MSAL callback URL scheme detected on macOS. MSAL for macOS completes through its web authentication session rather than the iOS callback forwarding API."
    #else
    return "MSAL callback URL scheme detected, but MSAL is not linked in this build."
    #endif
  }
}

struct MSALMicrosoft365AuthClient: Microsoft365AuthClient {
  func connect(connection: Microsoft365MailboxConnection) async -> Microsoft365AuthResult {
    #if canImport(MSAL)
    let missingFields = missingReadinessFields(for: connection)
    guard missingFields.isEmpty else {
      return Microsoft365AuthResult(
        status: .notConfigured,
        signedInAccount: "Not signed in",
        detailText: "Setup incomplete: \(missingFields.joined(separator: ", ")). Real Microsoft 365 sign-in was not started, no browser opened, and no token request was made. Use Edit setup to add Entra tenant/client/redirect values, or use mock auth for local testing."
      )
    }

    return await performInteractiveSignIn(connection: connection)
    #else
    Microsoft365AuthResult(
      status: .notConfigured,
      signedInAccount: "Not signed in",
      detailText: "Real Microsoft 365 sign-in is unavailable because MSAL is not linked in this build."
    )
    #endif
  }

  func simulateFailure(connection: Microsoft365MailboxConnection) async -> Microsoft365AuthResult {
    Microsoft365AuthResult(
      status: .authFailed,
      signedInAccount: "Not signed in",
      detailText: "Real Microsoft 365 sign-in failure simulation is not used. Use the mock auth client for local failure testing."
    )
  }

  private static let redirectURI = "msauth.app.bitrig.parcelops://auth"

  private func missingReadinessFields(for connection: Microsoft365MailboxConnection) -> [String] {
    var missingFields: [String] = []
    if connection.tenantIDPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && connection.tenantDomainHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      missingFields.append("Tenant ID or tenant domain")
    }
    if connection.clientIDPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      missingFields.append("Client ID")
    }
    let redirect = connection.redirectURIPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines)
    if redirect.isEmpty {
      missingFields.append("Redirect URI")
    } else if redirect != Self.redirectURI {
      missingFields.append("Redirect URI must be \(Self.redirectURI)")
    }
    return missingFields
  }

  private func normalizedTenant(for connection: Microsoft365MailboxConnection) -> String {
    let tenantID = connection.tenantIDPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines)
    if !tenantID.isEmpty {
      return tenantID
    }
    let domainHint = connection.tenantDomainHint.trimmingCharacters(in: .whitespacesAndNewlines)
    return domainHint.isEmpty ? "organizations" : domainHint
  }

  @MainActor
  private func performInteractiveSignIn(connection: Microsoft365MailboxConnection) async -> Microsoft365AuthResult {
    let tenant = normalizedTenant(for: connection)
    guard let authorityURL = URL(string: "https://login.microsoftonline.com/\(tenant)") else {
      return Microsoft365AuthResult(
          status: .notConfigured,
          signedInAccount: "Not signed in",
          detailText: "Setup issue: the tenant placeholder could not form a Microsoft identity authority URL. Use a tenant ID GUID or domain such as company.onmicrosoft.com. No token value was stored and no mailbox call was made."
        )
    }

    do {
      let authority = try MSALAADAuthority(url: authorityURL)
      let config = MSALPublicClientApplicationConfig(
        clientId: connection.clientIDPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines),
        redirectUri: Self.redirectURI,
        authority: authority
      )
      #if os(iOS)
      config.cacheConfig.keychainSharingGroup = MSALMicrosoft365AuthAdapter.iOSKeychainGroup
      #elseif os(macOS)
      config.cacheConfig.keychainSharingGroup = MSALMicrosoft365AuthAdapter.macOSKeychainGroup
      #endif
      let application = try MSALPublicClientApplication(configuration: config)
      let webParameters = try Self.webviewParameters()
      let parameters = MSALInteractiveTokenParameters(scopes: ["User.Read"], webviewParameters: webParameters)
      parameters.promptType = .selectAccount
      return await acquireToken(application: application, parameters: parameters, connection: connection)
    } catch {
      return Microsoft365AuthResult(
        status: .authFailed,
        signedInAccount: "Not signed in",
        detailText: authFailureDetail(for: error)
      )
    }
  }

  @MainActor
  private func acquireToken(
    application: MSALPublicClientApplication,
    parameters: MSALInteractiveTokenParameters,
    connection: Microsoft365MailboxConnection
  ) async -> Microsoft365AuthResult {
    await withCheckedContinuation { continuation in
      application.acquireToken(with: parameters) { result, error in
        if let error {
          continuation.resume(returning: self.authResult(from: error))
          return
        }

        guard let result else {
          continuation.resume(returning: Microsoft365AuthResult(
            status: .authFailed,
            signedInAccount: "Not signed in",
            detailText: "Sign-in ended without an MSAL result. Try again from an active ParcelOps window, or use mock auth for local testing. No token value was stored in ParcelOps JSON and no Microsoft Graph mailbox call was made."
          ))
          return
        }

        let account = result.account.username ?? connection.mailboxAddress
        continuation.resume(returning: Microsoft365AuthResult(
          status: .connected,
          signedInAccount: account.isEmpty ? "Signed in Microsoft account" : account,
          detailText: "Success: real Microsoft 365 identity sign-in completed with User.Read only. MSAL handled its token cache internally; ParcelOps did not store or log access tokens, refresh tokens, ID tokens, auth codes, passwords, or client secrets. Microsoft Graph mailbox calls remain mocked."
        ))
      }
    }
  }

  private func authResult(from error: Error) -> Microsoft365AuthResult {
    let status = authStatus(for: error)
    return Microsoft365AuthResult(
      status: status,
      signedInAccount: "Not signed in",
      detailText: authFailureDetail(for: error)
    )
  }

  private func authStatus(for error: Error) -> Microsoft365AuthStatus {
    if error is MSALMicrosoft365AuthError {
      return .authFailed
    }

    let nsError = error as NSError
    guard nsError.domain == "MSALErrorDomain" else {
      return .authFailed
    }

    switch nsError.code {
    case -50005:
      return .notConnected
    case -50002, -50003, -50004, -50142:
      return .consentRequired
    default:
      return .authFailed
    }
  }

  private func authFailureDetail(for error: Error) -> String {
    let nsError = error as NSError
    let summary = safeErrorSummary(error)
    let safeSuffix = "No token value was stored in ParcelOps JSON and no Microsoft Graph mailbox call was made."

    if error is MSALMicrosoft365AuthError {
      return "Missing presentation window: ParcelOps could not find an active app window for Microsoft sign-in. Bring the app window forward and try again from Settings or Mailbox Monitor. \(safeSuffix)"
    }

    if nsError.domain == "NSURLErrorDomain" {
      return "Network/login endpoint issue: \(summary). Check macOS sandbox network client entitlement, DNS/network access, and whether Microsoft login is reachable. \(safeSuffix)"
    }

    guard nsError.domain == "MSALErrorDomain" else {
      return "Sign-in failed outside MSAL: \(summary). Check the active app window, Xcode signing, sandbox permissions, and network access. \(safeSuffix)"
    }

    let internalCode = safeMSALInternalErrorCode(from: nsError)
    let oauthHint = safeOAuthHint(from: nsError)
    let diagnosticContext = [internalCode, oauthHint].compactMap { $0 }.joined(separator: " ")
    let contextSuffix = diagnosticContext.isEmpty ? "" : " \(diagnosticContext)"

    switch nsError.code {
    case -50005:
      return "Cancelled: Microsoft 365 sign-in was closed before completion. No account was connected. \(safeSuffix)"
    case -50002:
      return "Interaction or consent required: MSAL says additional sign-in interaction is needed.\(contextSuffix) Check user/admin consent and tenant policy for User.Read. \(safeSuffix)"
    case -50003:
      return "Consent or scope issue: Microsoft declined one or more requested scopes.\(contextSuffix) For this test, keep the app registration and ParcelOps setup to identity-only User.Read. \(safeSuffix)"
    case -50004, -50007:
      return "Tenant protection policy issue: Microsoft requires device compliance, Intune, or stronger device state before sign-in can complete.\(contextSuffix) Review tenant conditional access policy. \(safeSuffix)"
    case -50142:
      return "Account action required: Microsoft reports a password reset or secure change requirement before sign-in can complete.\(contextSuffix) Complete the account requirement in Microsoft 365, then retry. \(safeSuffix)"
    case -50006:
      return "Microsoft sign-in server error: \(summary). Retry once, then check tenant/app registration status if it continues.\(contextSuffix) \(safeSuffix)"
    case -50000:
      return "Internal MSAL error: \(summary).\(contextSuffix) Common causes are redirect URI or URL scheme mismatch, invalid tenant/client setup, missing active presentation window, MSAL token cache access failure, or Keychain Sharing entitlement/signing mismatch. Verify redirect URI \(MSALMicrosoft365AuthAdapter.redirectURI), bundle ID \(MSALMicrosoft365AuthAdapter.bundleID), Keychain groups \(MSALMicrosoft365AuthAdapter.iOSKeychainGroup) and \(MSALMicrosoft365AuthAdapter.macOSKeychainGroup), and Xcode signing. \(safeSuffix)"
    default:
      return "MSAL sign-in failed: \(summary).\(contextSuffix) Check Entra app registration, tenant policy, User.Read consent, redirect URI, URL scheme, Xcode signing, network access, and MSAL Keychain cache entitlement. \(safeSuffix)"
    }
  }

  private func safeMSALInternalErrorCode(from error: NSError) -> String? {
    guard let value = error.userInfo["MSALInternalErrorCodeKey"] else { return nil }
    return "MSAL internal code: \(value)."
  }

  private func safeOAuthHint(from error: NSError) -> String? {
    let oauthError = error.userInfo["MSALOAuthErrorKey"].map { "OAuth error: \($0)." }
    let subError = error.userInfo["MSALOAuthSubErrorKey"].map { "OAuth suberror: \($0)." }
    let httpStatus = error.userInfo["MSALHTTPResponseCodeKey"].map { "HTTP status: \($0)." }
    let text = [oauthError, subError, httpStatus].compactMap { $0 }.joined(separator: " ")
    return text.isEmpty ? nil : text
  }

  private func safeErrorSummary(_ error: Error) -> String {
    let description = error.localizedDescription
    return description.isEmpty ? "MSAL returned an authentication error." : description
  }

  #if canImport(UIKit)
  @MainActor
  private static func webviewParameters() throws -> MSALWebviewParameters {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let keyWindow = scenes.flatMap(\.windows).first { $0.isKeyWindow }
    var controller = keyWindow?.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    guard let controller else {
      throw MSALMicrosoft365AuthError.missingPresentationWindow
    }
    return MSALWebviewParameters(authPresentationViewController: controller)
  }
  #elseif canImport(AppKit)
  @MainActor
  private static func webviewParameters() throws -> MSALWebviewParameters {
    guard let controller = NSApplication.shared.keyWindow?.contentViewController ?? NSApplication.shared.mainWindow?.contentViewController else {
      throw MSALMicrosoft365AuthError.missingPresentationWindow
    }
    return MSALWebviewParameters(authPresentationViewController: controller)
  }
  #else
  @MainActor
  private static func webviewParameters() throws -> MSALWebviewParameters {
    throw MSALMicrosoft365AuthError.missingPresentationWindow
  }
  #endif
}

enum MSALMicrosoft365AuthError: LocalizedError {
  case missingPresentationWindow

  var errorDescription: String? {
    switch self {
    case .missingPresentationWindow:
      "ParcelOps could not find an active presentation window for Microsoft sign-in."
    }
  }
}
