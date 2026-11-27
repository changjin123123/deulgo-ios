#!/usr/bin/env python3
"""Generate a deterministic Xcode project; no XcodeGen/Ruby dependency required."""
import hashlib
import json
import plistlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
objects = {}

def ident(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()

def q(value):
    return json.dumps(value, ensure_ascii=False)

def add(name, body):
    objects[ident(name)] = body
    return ident(name)

def refs(values):
    return "(" + ", ".join(values) + ",)" if values else "()"

def settings(values):
    return "{ " + " ".join(f"{key} = {q(value)};" for key, value in values.items()) + " }"

app_files = sorted((ROOT / "Deulgo").glob("*.swift"))
test_files = sorted((ROOT / "DeulgoTests").glob("*.swift"))
ui_test_files = sorted((ROOT / "DeulgoUITests").glob("*.swift"))
resource_files = sorted((ROOT / "Deulgo/Resources").glob("*"))
for path in resource_files:
    key = "resource:" + path.name
    kind = "text.json" if path.suffix == ".json" else "sourcecode.javascript"
    add(key, f'isa = PBXFileReference; lastKnownFileType = {kind}; path = {q(path.name)}; sourceTree = "<group>";')
    add("build:" + key, f'isa = PBXBuildFile; fileRef = {ident(key)};')
add("resources-group", f'isa = PBXGroup; path = Resources; sourceTree = "<group>"; children = {refs([ident("resource:" + p.name) for p in resource_files])};')
for path in app_files + test_files + ui_test_files:
    key = str(path.relative_to(ROOT))
    add(key, f"isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(path.name)}; sourceTree = \"<group>\";")
    add("build:" + key, f"isa = PBXBuildFile; fileRef = {ident(key)};")

add("config", 'isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Config/Base.xcconfig; sourceTree = "<group>";')
add("plist", 'isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>";')
add("assets", 'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>";')
add("assets-build", f"isa = PBXBuildFile; fileRef = {ident('assets')};")
add("app-product", 'isa = PBXFileReference; explicitFileType = wrapper.application; path = Deulgo.app; sourceTree = BUILT_PRODUCTS_DIR; includeInIndex = 0;')
add("tests-product", 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = DeulgoTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; includeInIndex = 0;')
add("ui-tests-product", 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = DeulgoUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; includeInIndex = 0;')
add("ui-tests-group", f'isa = PBXGroup; path = DeulgoUITests; sourceTree = "<group>"; children = {refs([ident(str(p.relative_to(ROOT))) for p in ui_test_files])};')
add("app-group", f'isa = PBXGroup; path = Deulgo; sourceTree = "<group>"; children = {refs([ident(str(p.relative_to(ROOT))) for p in app_files] + [ident("plist"), ident("assets"), ident("resources-group")])};')
add("tests-group", f'isa = PBXGroup; path = DeulgoTests; sourceTree = "<group>"; children = {refs([ident(str(p.relative_to(ROOT))) for p in test_files])};')
add("products", f'isa = PBXGroup; name = Products; sourceTree = "<group>"; children = {refs([ident("app-product"), ident("tests-product"), ident("ui-tests-product")])};')
add("main-group", f'isa = PBXGroup; sourceTree = "<group>"; children = {refs([ident(x) for x in ["app-group", "tests-group", "ui-tests-group", "config", "products"]])};')

add("sdk", 'isa = XCRemoteSwiftPackageReference; repositoryURL = "https://github.com/kakao/kakao-ios-sdk"; requirement = {kind = exactVersion; version = 2.30.0;};')
for name in ["KakaoSDKCommon", "KakaoSDKNavi"]:
    add(name, f'isa = XCSwiftPackageProductDependency; package = {ident("sdk")}; productName = {name};')
    add("framework:" + name, f'isa = PBXBuildFile; productRef = {ident(name)};')

for prefix, paths in [("app", app_files), ("tests", test_files), ("ui-tests", ui_test_files)]:
    add(prefix + "-sources", f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {refs([ident("build:" + str(p.relative_to(ROOT))) for p in paths])}; runOnlyForDeploymentPostprocessing = 0;')
    frameworks = [ident("framework:" + n) for n in ["KakaoSDKCommon", "KakaoSDKNavi"]] if prefix == "app" else []
    add(prefix + "-frameworks", f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = {refs(frameworks)}; runOnlyForDeploymentPostprocessing = 0;')
    resource_builds = [ident("assets-build")] + [ident("build:resource:" + p.name) for p in resource_files] if prefix == "app" else []
    add(prefix + "-resources", f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {refs(resource_builds)}; runOnlyForDeploymentPostprocessing = 0;')

common = {"CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES", "IPHONEOS_DEPLOYMENT_TARGET": "17.0", "SDKROOT": "iphoneos", "SWIFT_VERSION": "5.0", "ENABLE_USER_SCRIPT_SANDBOXING": "YES"}
app_settings = {"PRODUCT_NAME": "$(TARGET_NAME)", "TARGETED_DEVICE_FAMILY": "1", "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "CODE_SIGN_STYLE": "Automatic", "INFOPLIST_FILE": "Deulgo/Info.plist", "GENERATE_INFOPLIST_FILE": "NO", "MARKETING_VERSION": "0.1.6", "CURRENT_PROJECT_VERSION": "8", "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor", "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks"}
tests_settings = {"PRODUCT_NAME": "$(TARGET_NAME)", "PRODUCT_BUNDLE_IDENTIFIER": "com.deulgo.delivery.tests", "GENERATE_INFOPLIST_FILE": "YES", "CODE_SIGN_STYLE": "Automatic", "TARGETED_DEVICE_FAMILY": "1", "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/Deulgo.app/Deulgo", "BUNDLE_LOADER": "$(TEST_HOST)", "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @loader_path/Frameworks"}
ui_tests_settings = {"PRODUCT_NAME": "$(TARGET_NAME)", "PRODUCT_BUNDLE_IDENTIFIER": "com.deulgo.delivery.uitests", "GENERATE_INFOPLIST_FILE": "YES", "CODE_SIGN_STYLE": "Automatic", "TARGETED_DEVICE_FAMILY": "1", "TEST_TARGET_NAME": "Deulgo", "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @loader_path/Frameworks"}
for owner, base in [("project", common), ("app", app_settings), ("tests", tests_settings), ("ui-tests", ui_tests_settings)]:
    for mode in ["Debug", "Release"]:
        opts = dict(base)
        if owner == "project":
            opts.update({"SWIFT_OPTIMIZATION_LEVEL": "-Onone" if mode == "Debug" else "-O", "DEBUG_INFORMATION_FORMAT": "dwarf" if mode == "Debug" else "dwarf-with-dsym"})
            if mode == "Debug": opts.update({"ENABLE_TESTABILITY": "YES", "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "$(inherited) DEBUG", "ONLY_ACTIVE_ARCH": "YES"})
        config = f'baseConfigurationReference = {ident("config")};' if owner == "app" else ""
        add(f"{owner}-{mode}", f'isa = XCBuildConfiguration; name = {mode}; {config} buildSettings = {settings(opts)};')
    add(owner + "-configs", f'isa = XCConfigurationList; buildConfigurations = {refs([ident(owner + "-" + m) for m in ["Debug", "Release"]])}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')

add("proxy", f'isa = PBXContainerItemProxy; containerPortal = {ident("project")}; proxyType = 1; remoteGlobalIDString = {ident("app-target")}; remoteInfo = Deulgo;')
add("test-dependency", f'isa = PBXTargetDependency; target = {ident("app-target")}; targetProxy = {ident("proxy")};')
for prefix, name, kind in [("app", "Deulgo", "application"), ("tests", "DeulgoTests", "bundle.unit-test"), ("ui-tests", "DeulgoUITests", "bundle.ui-testing")]:
    add(prefix + "-target", f'isa = PBXNativeTarget; name = {name}; productName = {name}; productType = "com.apple.product-type.{kind}"; productReference = {ident(prefix + "-product")}; buildConfigurationList = {ident(prefix + "-configs")}; buildPhases = {refs([ident(prefix + "-" + t) for t in ["sources", "frameworks", "resources"]])}; buildRules = (); dependencies = {refs([ident("test-dependency")] if prefix != "app" else [])}; packageProductDependencies = {refs([ident(n) for n in ["KakaoSDKCommon", "KakaoSDKNavi"]] if prefix == "app" else [])};')
add("project", f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2600; BuildIndependentTargetsInParallel = YES; }}; buildConfigurationList = {ident("project-configs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = ko; knownRegions = (ko, en, Base); mainGroup = {ident("main-group")}; productRefGroup = {ident("products")}; projectDirPath = ""; projectRoot = ""; packageReferences = ({ident("sdk")},); targets = {refs([ident("app-target"), ident("tests-target"), ident("ui-tests-target")])};')
project = ROOT / "Deulgo.xcodeproj"
project.mkdir(exist_ok=True)
(project / "project.pbxproj").write_text('// !$*UTF8*$!\n{\narchiveVersion = 1; classes = {}; objectVersion = 56;\nobjects = {\n' + '\n'.join(f'{k} = {{ {v} }};' for k, v in objects.items()) + f'\n}};\nrootObject = {ident("project")};\n}}\n')

plist = {"CFBundleDevelopmentRegion": "ko", "CFBundleDisplayName": "들고", "CFBundleExecutable": "$(EXECUTABLE_NAME)", "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)", "CFBundleInfoDictionaryVersion": "6.0", "CFBundleName": "$(PRODUCT_NAME)", "CFBundlePackageType": "APPL", "CFBundleShortVersionString": "$(MARKETING_VERSION)", "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)", "LSRequiresIPhoneOS": True, "KakaoNativeAppKey": "$(KAKAO_NATIVE_APP_KEY)", "LSApplicationQueriesSchemes": ["nmap", "kakaonavi-sdk"], "UILaunchScreen": {}, "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": False, "UISceneConfigurations": {}}, "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"]}
(ROOT / "Deulgo/Info.plist").write_bytes(plistlib.dumps(plist, sort_keys=False))

def buildable(target, product):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident(target)}" BuildableName="{product}" BlueprintName="{product.split(".")[0]}" ReferencedContainer="container:Deulgo.xcodeproj"/>'
app = buildable("app-target", "Deulgo.app")
tests = buildable("tests-target", "DeulgoTests.xctest")
ui_tests = buildable("ui-tests-target", "DeulgoUITests.xctest")
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{tests}</TestableReference><TestableReference skipped="NO">{ui_tests}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO"><BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/>
<ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
scheme_dir = project / "xcshareddata/xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
(scheme_dir / "Deulgo.xcscheme").write_text(scheme)
print(f"Generated {len(objects)} project objects, {len(app_files)} app sources, {len(test_files)} unit test sources, {len(ui_test_files)} UI test sources.")
