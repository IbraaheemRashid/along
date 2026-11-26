import AuthenticationServices
import CryptoKit
import Foundation
import SwiftUI
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

struct AlongUser: Equatable {
    var id: String
    var email: String?
    var displayName: String?
    var provider: String
}

/// Firebase Auth for Apple, Google and email. No-ops until GoogleService-Info.plist
/// is present and FirebaseAuth is linked. Does not change sign-in chrome.
@MainActor @Observable final class AuthStore {
    var user: AlongUser?
    var isBusy = false
    var message: String?
    var emailDraft = ""
    var passwordDraft = ""
    var showsEmailForm = false

    private var appleNonce: String?
    private var appleSignInDelegate: AppleSignInCoordinator?

    var isConfigured: Bool {
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }

    var isSignedIn: Bool { user != nil }

    func start() {
        FirebaseBootstrap.configureIfNeeded()
        #if canImport(FirebaseAuth)
        if let current = Auth.auth().currentUser {
            user = map(current)
        }
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in
                self?.user = firebaseUser.map { self?.map($0) ?? AlongUser(id: $0.uid, email: $0.email, displayName: $0.displayName, provider: "firebase") }
            }
        }
        #endif
        #if canImport(GoogleSignIn)
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let clientID = dict["CLIENT_ID"] as? String {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        #endif
    }

    func signInWithApple() async {
        guard isConfigured else {
            message = "Add GoogleService-Info.plist from Firebase to enable accounts."
            return
        }
        #if canImport(FirebaseAuth)
        isBusy = true
        message = nil
        defer { isBusy = false }
        let nonce = randomNonce()
        appleNonce = nonce
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        do {
            let coordinator = AppleSignInCoordinator()
            appleSignInDelegate = coordinator
            let authorization = try await coordinator.perform(request)
            appleSignInDelegate = nil
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let appleNonce else {
                message = "Apple Sign In didn’t return a token. Please try again."
                return
            }
            let oauth = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: appleNonce, fullName: credential.fullName)
            let result = try await Auth.auth().signIn(with: oauth)
            user = map(result.user)
            message = nil
            showsEmailForm = false
        } catch {
            appleSignInDelegate = nil
            message = friendly(error)
        }
        #else
        message = "Firebase Auth isn’t linked in this build."
        #endif
    }

    func signInWithGoogle() async {
        guard isConfigured else {
            message = "Add GoogleService-Info.plist from Firebase to enable accounts."
            return
        }
        #if canImport(FirebaseAuth) && canImport(GoogleSignIn)
        isBusy = true
        message = nil
        defer { isBusy = false }
        guard let presenter = topViewController() else {
            message = "Couldn’t open Google Sign In from this screen."
            return
        }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                message = "Google Sign In didn’t return a token. Please try again."
                return
            }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
            let authResult = try await Auth.auth().signIn(with: credential)
            user = map(authResult.user)
            message = nil
            showsEmailForm = false
        } catch {
            message = friendly(error)
        }
        #else
        message = "Google Sign In isn’t linked in this build."
        #endif
    }

    func beginEmailSignIn() {
        showsEmailForm = true
        message = nil
    }

    /// Stash onboarding credentials; Firebase create/sign-in happens after purchase.
    func stageOnboardingCredentials(email: String, password: String) {
        emailDraft = email.trimmingCharacters(in: .whitespacesAndNewlines)
        passwordDraft = password
        message = nil
    }

    /// After a successful purchase: keep an existing session, or create/sign-in from
    /// staged email credentials. Never blocks paid access when Auth isn’t configured.
    @discardableResult
    func ensureSignedInAfterPurchase(email: String? = nil) async -> Bool {
        if isSignedIn { return true }
        if !isConfigured { return true }
        if let email {
            let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { emailDraft = trimmed }
        }
        if passwordDraft.count < 6 {
            passwordDraft = Self.generatedPassword()
        }
        await submitEmailSignIn(clearPasswordOnSuccess: true)
        return isSignedIn || !isConfigured
    }

    func submitEmailSignIn(clearPasswordOnSuccess: Bool = true) async {
        let email = emailDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordDraft
        guard isConfigured else {
            message = "Add GoogleService-Info.plist from Firebase to enable accounts."
            return
        }
        guard email.contains("@"), password.count >= 6 else {
            message = "Use a valid email and a password of at least 6 characters."
            return
        }
        #if canImport(FirebaseAuth)
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            user = map(result.user)
            if clearPasswordOnSuccess { passwordDraft = "" }
            showsEmailForm = false
        } catch {
            let ns = error as NSError
            let missingUser = ns.code == AuthErrorCode.userNotFound.rawValue
                || ns.code == AuthErrorCode.invalidCredential.rawValue
                || ns.code == AuthErrorCode.wrongPassword.rawValue
            if missingUser {
                do {
                    let created = try await Auth.auth().createUser(withEmail: email, password: password)
                    user = map(created.user)
                    if clearPasswordOnSuccess { passwordDraft = "" }
                    showsEmailForm = false
                    message = nil
                } catch {
                    message = friendly(error)
                }
            } else {
                message = friendly(error)
            }
        }
        #else
        message = "Firebase Auth isn’t linked in this build."
        #endif
    }

    private static func generatedPassword(length: Int = 24) -> String {
        let charset = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*")
        var result = ""
        result.reserveCapacity(length)
        for _ in 0..<length {
            var byte: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &byte)
            result.append(charset[Int(byte) % charset.count])
        }
        return result
    }

    func signOut() {
        #if canImport(FirebaseAuth)
        do {
            try Auth.auth().signOut()
            #if canImport(GoogleSignIn)
            GIDSignIn.sharedInstance.signOut()
            #endif
            user = nil
            message = "Signed out on this device."
        } catch {
            message = friendly(error)
        }
        #else
        user = nil
        #endif
        TokenVault.clear()
    }

    #if canImport(FirebaseAuth)
    private func map(_ user: User) -> AlongUser {
        let provider = user.providerData.first?.providerID ?? "firebase"
        return AlongUser(id: user.uid, email: user.email, displayName: user.displayName, provider: provider)
    }
    #endif

    private func friendly(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.isEmpty { return "Sign in failed. Please try again." }
        return text
    }

    private func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess { random = UInt8.random(in: 0...255) }
            if random < charset.count {
                result.append(charset[Int(random) % charset.count])
                remaining -= 1
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func topViewController(from root: UIViewController? = nil) -> UIViewController? {
        let root = root ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?.rootViewController
        if let nav = root as? UINavigationController { return topViewController(from: nav.visibleViewController) }
        if let tab = root as? UITabBarController { return topViewController(from: tab.selectedViewController) }
        if let presented = root?.presentedViewController { return topViewController(from: presented) }
        return root
    }
}

enum FirebaseBootstrap {
    static func configureIfNeeded() {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return }
        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #endif
    }
}

final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<ASAuthorization, Error>?

    func perform(_ request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation?.resume(returning: authorization)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
