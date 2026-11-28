"""Generate the small native Xcode project without a third-party build generator."""
from pathlib import Path
import hashlib
import plistlib

root = Path(__file__).resolve().parent
along = root / "Along"
project = root / "Along.xcodeproj"
project.mkdir(exist_ok=True)

def ident(value):
    return hashlib.sha1(value.encode()).hexdigest()[:24].upper()

files = sorted(along.glob("*.swift"))
google_plist = along / "GoogleService-Info.plist"
reversed_client_id = None
if google_plist.exists():
    with google_plist.open("rb") as handle:
        info = plistlib.load(handle)
    reversed_client_id = info.get("REVERSED_CLIENT_ID")

lines = ["// !$*UTF8*$!", "{", "archiveVersion = 1;", "classes = {};", "objectVersion = 56;", "objects = {"]

def obj(key, content):
    lines.append(f"{ident(key)} = {{ {content} }};")

for file in files:
    obj("build:" + file.name, f'isa = PBXBuildFile; fileRef = {ident("file:" + file.name)};')
    obj("file:" + file.name, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{file.name}"; sourceTree = "<group>";')

obj("product", "isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Along.app; sourceTree = BUILT_PRODUCTS_DIR;")
obj("assets", "isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\";")
obj("assetbuild", f'isa = PBXBuildFile; fileRef = {ident("assets")};')
obj("privacy", "isa = PBXFileReference; lastKnownFileType = text.xml; path = PrivacyInfo.xcprivacy; sourceTree = \"<group>\";")
obj("privacybuild", f'isa = PBXBuildFile; fileRef = {ident("privacy")};')
obj("storekit", "isa = PBXFileReference; lastKnownFileType = text; path = Along.storekit; sourceTree = \"<group>\";")
obj("entitlements", "isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Along.entitlements; sourceTree = \"<group>\";")
obj("healthkit", "isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = HealthKit.framework; path = System/Library/Frameworks/HealthKit.framework; sourceTree = SDKROOT;")
obj("healthkitbuild", f'isa = PBXBuildFile; fileRef = {ident("healthkit")};')
obj("authservice", "isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = AuthenticationServices.framework; path = System/Library/Frameworks/AuthenticationServices.framework; sourceTree = SDKROOT;")
obj("authservicebuild", f'isa = PBXBuildFile; fileRef = {ident("authservice")};')

resource_builds = [ident("assetbuild"), ident("privacybuild")]
source_children = [ident("file:" + f.name) for f in files] + [ident("assets"), ident("privacy"), ident("storekit"), ident("entitlements")]
if google_plist.exists():
    obj("googleplist", 'isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "GoogleService-Info.plist"; sourceTree = "<group>";')
    obj("googleplistbuild", f'isa = PBXBuildFile; fileRef = {ident("googleplist")};')
    resource_builds.append(ident("googleplistbuild"))
    source_children.append(ident("googleplist"))

obj("sourcegroup", f'isa = PBXGroup; children = ({",".join(source_children)},); path = Along; sourceTree = "<group>";')
obj("productgroup", f'isa = PBXGroup; children = ({ident("product")},); name = Products; sourceTree = "<group>";')
obj("rootgroup", f'isa = PBXGroup; children = ({ident("sourcegroup")},{ident("uitestgroup")},{ident("productgroup")},); sourceTree = "<group>";')
obj("sources", f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(ident("build:"+f.name) for f in files)},); runOnlyForDeploymentPostprocessing = 0;')

# Packages
obj("superwallpackage", 'isa = XCRemoteSwiftPackageReference; repositoryURL = "https://github.com/superwall/Superwall-iOS.git"; requirement = { kind = exactVersion; version = 4.18.3; };')
obj("superwallproduct", f'isa = XCSwiftPackageProductDependency; package = {ident("superwallpackage")}; productName = SuperwallKit;')
obj("superwallbuild", f'isa = PBXBuildFile; productRef = {ident("superwallproduct")};')

obj("firebasepackage", 'isa = XCRemoteSwiftPackageReference; repositoryURL = "https://github.com/firebase/firebase-ios-sdk.git"; requirement = { kind = upToNextMajorVersion; minimumVersion = 11.6.0; };')
firebase_products = [
    ("FirebaseCore", "firebasecore"),
    ("FirebaseAuth", "firebaseauth"),
    ("FirebaseFirestore", "firebasefirestore"),
    ("FirebaseCrashlytics", "firebasecrashlytics"),
]
for product_name, key in firebase_products:
    obj(key + "product", f'isa = XCSwiftPackageProductDependency; package = {ident("firebasepackage")}; productName = {product_name};')
    obj(key + "build", f'isa = PBXBuildFile; productRef = {ident(key + "product")};')

obj("googlesigninpackage", 'isa = XCRemoteSwiftPackageReference; repositoryURL = "https://github.com/google/GoogleSignIn-iOS.git"; requirement = { kind = upToNextMajorVersion; minimumVersion = 8.0.0; };')
obj("googlesigninproduct", f'isa = XCSwiftPackageProductDependency; package = {ident("googlesigninpackage")}; productName = GoogleSignIn;')
obj("googlesigninbuild", f'isa = PBXBuildFile; productRef = {ident("googlesigninproduct")};')

framework_builds = [
    ident("superwallbuild"),
    ident("healthkitbuild"),
    ident("authservicebuild"),
    ident("firebasecorebuild"),
    ident("firebaseauthbuild"),
    ident("firebasefirestorebuild"),
    ident("firebasecrashlyticsbuild"),
    ident("googlesigninbuild"),
]
obj("frameworks", f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ({",".join(framework_builds)},); runOnlyForDeploymentPostprocessing = 0;')
obj("resources", f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(resource_builds)},); runOnlyForDeploymentPostprocessing = 0;')

info_plist = Path("Along/BuildInfo.plist")
if reversed_client_id:
    # URL types must be a plist array of dictionaries for iOS to register the callback.
    with (root / info_plist).open("rb") as handle:
        build_info = plistlib.load(handle)
    build_info["CFBundleURLTypes"] = [{
        "CFBundleTypeRole": "Editor",
        "CFBundleURLSchemes": [reversed_client_id],
    }]
    info_plist = Path(".build/Along-Google-Info.plist")
    (root / info_plist).parent.mkdir(exist_ok=True)
    (root / info_plist).write_bytes(plistlib.dumps(build_info))

package_product_deps = ",".join(
    [ident("superwallproduct")]
    + [ident(key + "product") for _, key in firebase_products]
    + [ident("googlesigninproduct")]
)
package_refs = ",".join([
    ident("superwallpackage"),
    ident("firebasepackage"),
    ident("googlesigninpackage"),
])

for scope in ["project", "target"]:
    for config in ["Debug", "Release"]:
        settings = "CLANG_ENABLE_MODULES = YES; SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0;"
        if scope == "target":
            settings += " ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;"
            settings += (
                ' PRODUCT_NAME = Along; PRODUCT_BUNDLE_IDENTIFIER = dev.along.prototype; TARGETED_DEVICE_FAMILY = "1,2";'
                f" GENERATE_INFOPLIST_FILE = YES; INFOPLIST_FILE = {info_plist}; INFOPLIST_KEY_CFBundleDisplayName = Along;"
                ' INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.healthcare-fitness";'
                " INFOPLIST_KEY_UILaunchScreen_Generation = YES; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;"
                " INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;"
                " INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait;"
                ' INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";'
                " INFOPLIST_KEY_FIREBASE_ANALYTICS_COLLECTION_ENABLED = NO;"
                " CURRENT_PROJECT_VERSION = 6; MARKETING_VERSION = 1.0.0; CODE_SIGN_STYLE = Automatic;"
                " CODE_SIGN_ENTITLEMENTS = Along/Along.entitlements; SWIFT_EMIT_LOC_STRINGS = YES;"
            )
        if config == "Debug":
            settings += ' ONLY_ACTIVE_ARCH = YES; SWIFT_OPTIMIZATION_LEVEL = "-Onone"; DEBUG_INFORMATION_FORMAT = dwarf; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;'
            if scope == "target":
                settings += (
                    ' ALONG_BILLING_ANNUAL_PRODUCT_ID = "dev.along.membership.annual";'
                    ' ALONG_BILLING_MONTHLY_PRODUCT_ID = "dev.along.membership.monthly";'
                    ' ALONG_SUPERWALL_PUBLIC_KEY = "pk_local_storekit";'
                    ' ALONG_BILLING_ENTITLEMENT_ID = "along.membership";'
                    ' ALONG_TERMS_URL = "https://example.com/terms";'
                    ' ALONG_PRIVACY_URL = "https://example.com/privacy";'
                )
        else:
            settings += ' SWIFT_OPTIMIZATION_LEVEL = "-O"; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";'
        obj(scope + config, f"isa = XCBuildConfiguration; buildSettings = {{ {settings} }}; name = {config};")
    obj(
        scope + "configs",
        f"isa = XCConfigurationList; buildConfigurations = ({ident(scope + 'Debug')},{ident(scope + 'Release')},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;",
    )

obj(
    "target",
    f'isa = PBXNativeTarget; buildConfigurationList = {ident("targetconfigs")}; buildPhases = ({ident("sources")},{ident("frameworks")},{ident("resources")},); buildRules = (); dependencies = (); name = Along; productName = Along; packageProductDependencies = ({package_product_deps},); productReference = {ident("product")}; productType = "com.apple.product-type.application";',
)

obj("uitestfile", "isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AlongUITests.swift; sourceTree = \"<group>\";")
obj("uitestbuildfile", f'isa = PBXBuildFile; fileRef = {ident("uitestfile")};')
obj("uitestgroup", f'isa = PBXGroup; children = ({ident("uitestfile")},); path = AlongUITests; sourceTree = "<group>";')
obj("uitestproduct", "isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = AlongUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;")
obj("uitestsources", f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({ident("uitestbuildfile")},); runOnlyForDeploymentPostprocessing = 0;')
obj("uitestframeworks", "isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;")
obj("uiteststorekit", f'isa = PBXBuildFile; fileRef = {ident("storekit")};')
obj("uitestresources", f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({ident("uiteststorekit")},); runOnlyForDeploymentPostprocessing = 0;')
obj("uitestproxy", f'isa = PBXContainerItemProxy; containerPortal = {ident("project")}; proxyType = 1; remoteGlobalIDString = {ident("target")}; remoteInfo = Along;')
obj("uitestdependency", f'isa = PBXTargetDependency; target = {ident("target")}; targetProxy = {ident("uitestproxy")};')
for config in ["Debug", "Release"]:
    obj(
        "uitest" + config,
        'isa = XCBuildConfiguration; buildSettings = { SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0; GENERATE_INFOPLIST_FILE = YES; PRODUCT_NAME = AlongUITests; PRODUCT_BUNDLE_IDENTIFIER = dev.along.prototype.UITests; TARGETED_DEVICE_FAMILY = "1,2"; TEST_TARGET_NAME = Along; CODE_SIGN_STYLE = Automatic; }; name = '
        + config
        + ";",
    )
obj("uitestconfigs", f'isa = XCConfigurationList; buildConfigurations = ({ident("uitestDebug")},{ident("uitestRelease")},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj(
    "uitesttarget",
    f'isa = PBXNativeTarget; buildConfigurationList = {ident("uitestconfigs")}; buildPhases = ({ident("uitestsources")},{ident("uitestframeworks")},{ident("uitestresources")},); buildRules = (); dependencies = ({ident("uitestdependency")},); name = AlongUITests; productName = AlongUITests; productReference = {ident("uitestproduct")}; productType = "com.apple.product-type.bundle.ui-testing";',
)
obj(
    "project",
    f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastSwiftUpdateCheck = 2630; LastUpgradeCheck = 2630; TargetAttributes = {{ {ident("uitesttarget")} = {{ TestTargetID = {ident("target")}; }}; }}; }}; buildConfigurationList = {ident("projectconfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base,); mainGroup = {ident("rootgroup")}; packageReferences = ({package_refs},); productRefGroup = {ident("productgroup")}; projectDirPath = ""; projectRoot = ""; targets = ({ident("target")},{ident("uitesttarget")},);',
)

lines += ["};", f'rootObject = {ident("project")};', "}"]
(project / "project.pbxproj").write_text("\n".join(lines) + "\n")

schemes = project / "xcshareddata/xcschemes"
schemes.mkdir(parents=True, exist_ok=True)
reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident("target")}" BuildableName="Along.app" BlueprintName="Along" ReferencedContainer="container:Along.xcodeproj"/>'
(schemes / "Along.xcscheme").write_text(
    f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2630" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident('uitesttarget')}" BuildableName="AlongUITests.xctest" BlueprintName="AlongUITests" ReferencedContainer="container:Along.xcodeproj"/></TestableReference></Testables></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable><StoreKitConfigurationFileReference identifier = "../../Along/Along.storekit"/></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
)
extra = " + GoogleService-Info.plist" if google_plist.exists() else " (no GoogleService-Info.plist yet)"
print(f"Generated {project} ({len(files)} Swift files{extra})")
