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
    let journals: AccountJournals?
    init(journals: AccountJournals? = nil) { self.journals = journals }

    private(set) var user: AlongUser? {
        didSet {
            guard user?.id != oldValue?.id else { return }
            journals?.select(user?.id)
            emailDraft = ""
            passwordDraft = ""
            showsEmailForm = false
            message = nil
        }
    }
    var isBusy = false
    var message: String?
    var emailDraft = ""
    var passwordDraft = ""
    var showsEmailForm = false

    private var appleNonce: String?
    private var appleSignInDelegate: AppleSignInCoordinator?

    var isConfigured: Bool {
        #if DEBUG
        guard journals != nil, !ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return false }
        #endif
        return Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }

    var isSignedIn: Bool { user != nil }

    func start() {
        guard isConfigured else { return }
        FirebaseBootstrap.configureIfNeeded()
        #if canImport(FirebaseAuth)
        if let current = Auth.auth().currentUser {
            user = map(current)
        }
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                // A previously queued callback may arrive after a sign-out or a second sign-in.
                self.user = Auth.auth().currentUser.map(self.map)
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

    @discardableResult func signInWithApple() async -> String? {
        guard !isBusy else { return nil }
        guard isConfigured else {
            message = "Add GoogleService-Info.plist from Firebase to enable accounts."
            return nil
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
                return nil
            }
            let oauth = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: appleNonce, fullName: credential.fullName)
            let result = try await Auth.auth().signIn(with: oauth)
            guard Auth.auth().currentUser?.uid == result.user.uid else { return nil }
            user = map(result.user)
            message = nil
            showsEmailForm = false
            return result.user.uid
        } catch {
            appleSignInDelegate = nil
            message = friendly(error)
        }
        #else
        message = "Firebase Auth isn’t linked in this build."
        #endif
        return nil
    }

    @discardableResult func signInWithGoogle() async -> String? {
        guard !isBusy else { return nil }
        guard isConfigured else {
            message = "Add GoogleService-Info.plist from Firebase to enable accounts."
            return nil
        }
        #if canImport(FirebaseAuth) && canImport(GoogleSignIn)
        isBusy = true
        message = nil
        defer { isBusy = false }
        guard let presenter = topViewController() else {
            message = "Couldn’t open Google Sign In from this screen."
            return nil
        }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                message = "Google Sign In didn’t return a token. Please try again."
                return nil
            }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
            let authResult = try await Auth.auth().signIn(with: credential)
            guard Auth.auth().currentUser?.uid == authResult.user.uid else { return nil }
            user = map(authResult.user)
            message = nil
            showsEmailForm = false
            return authResult.user.uid
        } catch {
            message = friendly(error)
        }
        #else
        message = "Google Sign In isn’t linked in this build."
        #endif
        return nil
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

    /// After a successful purchase (or temporary paywall skip): keep an existing
    /// session, or create/sign-in from credentials staged during the account step.
    /// Never blocks app access when Auth isn’t configured.
    @discardableResult
    func ensureSignedInAfterPurchase(email: String? = nil) async -> String? {
        if let user { return user.id }
        if !isConfigured { return nil }
        if let email {
            let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { emailDraft = trimmed }
        }
        guard emailDraft.contains("@"), passwordDraft.count >= 6 else {
            message = "Your email and password from setup are needed to create the account. Go back one step and enter them again."
            return nil
        }
        return await submitEmailSignIn(allowAccountCreation: true)
    }

    @discardableResult func submitEmailSignIn(allowAccountCreation: Bool = false) async -> String? {
        guard !isBusy else { return nil }
        let email = emailDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordDraft
        guard isConfigured else {
            message = "Add GoogleService-Info.plist from Firebase to enable accounts."
            return nil
        }
        guard email.contains("@"), password.count >= 6 else {
            message = "Use a valid email and a password of at least 6 characters."
            return nil
        }
        #if canImport(FirebaseAuth)
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            guard Auth.auth().currentUser?.uid == result.user.uid else { return nil }
            user = map(result.user)
            passwordDraft = ""
            showsEmailForm = false
            return result.user.uid
        } catch {
            let ns = error as NSError
            let missingUser = ns.code == AuthErrorCode.userNotFound.rawValue
                || ns.code == AuthErrorCode.invalidCredential.rawValue
                || ns.code == AuthErrorCode.wrongPassword.rawValue
            if allowAccountCreation && missingUser {
                do {
                    let created = try await Auth.auth().createUser(withEmail: email, password: password)
                    guard Auth.auth().currentUser?.uid == created.user.uid else { return nil }
                    user = map(created.user)
                    passwordDraft = ""
                    showsEmailForm = false
                    message = nil
                    return created.user.uid
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
        return nil
    }

    /// Reauthenticate the same user before removing any journal data.
    func deleteAccount(password: String, reminders: ReminderStore) async {
        guard !isBusy, let journals, let uid = user?.id, journals.active.accountID == uid else { return }
        #if canImport(FirebaseAuth)
        guard isConfigured, let current = Auth.auth().currentUser, current.uid == uid else { return }
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            let provider = user?.provider
            let credential: AuthCredential
            var appleCode: String?
            switch provider {
            case "apple.com":
                let nonce = randomNonce()
                let request = ASAuthorizationAppleIDProvider().createRequest()
                request.nonce = sha256(nonce)
                let coordinator = AppleSignInCoordinator()
                appleSignInDelegate = coordinator
                defer { appleSignInDelegate = nil }
                let authorization = try await coordinator.perform(request)
                guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let data = apple.identityToken, let token = String(data: data, encoding: .utf8),
                      let codeData = apple.authorizationCode, let code = String(data: codeData, encoding: .utf8) else {
                    message = "Apple could not confirm this account. Try again."
                    return
                }
                credential = OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce, fullName: apple.fullName)
                appleCode = code
            case "google.com":
                #if canImport(GoogleSignIn)
                guard let presenter = topViewController() else { message = "Open this screen again to confirm with Google."; return }
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
                guard let token = result.user.idToken?.tokenString else { message = "Google could not confirm this account."; return }
                credential = GoogleAuthProvider.credential(withIDToken: token, accessToken: result.user.accessToken.tokenString)
                #else
                message = "Google Sign In is unavailable in this build."
                return
                #endif
            case "password":
                guard let email = current.email, !password.isEmpty else { message = "Enter your password to confirm."; return }
                credential = EmailAuthProvider.credential(withEmail: email, password: password)
            default:
                message = "Reopen the app and sign in again to confirm your account."
                return
            }
            let verified = try await current.reauthenticate(with: credential)
            guard verified.user.uid == uid, Auth.auth().currentUser?.uid == uid else { throw CocoaError(.userCancelled) }
            try await journals.eraseAccount(uid) {
                guard Auth.auth().currentUser?.uid == uid else { throw CocoaError(.userCancelled) }
                if let appleCode { try await Auth.auth().revokeToken(withAuthorizationCode: appleCode) }
                if reminders.deliveryEnabled, !(await reminders.reset()) { throw CocoaError(.fileWriteUnknown) }
            } deleteIdentity: {
                guard Auth.auth().currentUser?.uid == uid else { throw CocoaError(.userCancelled) }
                try await current.delete()
            }
            if Auth.auth().currentUser == nil {
                #if canImport(GoogleSignIn)
                GIDSignIn.sharedInstance.signOut()
                #endif
                TokenVault.clear()
                user = nil
            }
        } catch { message = error.localizedDescription }
        #else
        message = "Accounts are unavailable in this build."
        #endif
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
        let providers = user.providerData.map(\.providerID)
        let provider = ["apple.com", "google.com", "password"].first(where: providers.contains) ?? "firebase"
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
