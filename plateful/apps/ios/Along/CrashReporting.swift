import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

/// Optional Firebase Crashlytics. Starts only when GoogleService-Info.plist is
/// present in the bundle. Firebase Analytics collection stays disabled.
///
/// To enable: add `GoogleService-Info.plist` (never commit secrets), link
/// FirebaseCore + FirebaseCrashlytics via SPM, then rebuild. Until then this
/// is a no-op and Apple's MetricKit / Xcode Organizer remain available.
enum CrashReporting {
    static var isConfigured: Bool {
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }

    static func start() {
        guard isConfigured, !FirebaseBootstrap.usesAccountEmulators else { return }
        FirebaseBootstrap.configureIfNeeded()
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #endif
    }
}
