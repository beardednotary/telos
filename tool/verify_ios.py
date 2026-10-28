"""Check Telos's native bundle wiring without Xcode or third-party packages.

This is a source preflight, not a substitute for compiling/signing on macOS.
Run from any directory: python3 tool/verify_ios.py
"""

from pathlib import Path
import plistlib
import re
import struct
import sys
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def plist(path):
    with (ROOT / path).open("rb") as source:
        return plistlib.load(source)


def postscript_names(path):
    """Read name ID 6 from an SFNT font's name table (no fontTools dependency)."""
    data = path.read_bytes()
    count = struct.unpack_from(">H", data, 4)[0]
    for index in range(count):
        tag, _, offset, _ = struct.unpack_from(">4sIII", data, 12 + index * 16)
        if tag != b"name":
            continue
        _, records, strings = struct.unpack_from(">HHH", data, offset)
        names = set()
        for record in range(records):
            platform, _, _, name_id, length, start = struct.unpack_from(
                ">HHHHHH", data, offset + 6 + record * 12
            )
            if name_id != 6:
                continue
            raw = data[offset + strings + start:offset + strings + start + length]
            names.add(raw.decode("utf-16-be" if platform in (0, 3) else "mac_roman"))
        return names
    raise ValueError(f"Font has no name table: {path.name}")


def verify():
    project = (ROOT / "ios/Runner.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
    app = plist("ios/Runner/Info.plist")
    widget = plist("ios/ExpeditionWidget/Info.plist")
    for label, info in (("Runner", app), ("Widget", widget)):
        require(info["CFBundleShortVersionString"] == "$(FLUTTER_BUILD_NAME)",
                f"{label} must use Codemagic's Flutter build name")
        require(info["CFBundleVersion"] == "$(FLUTTER_BUILD_NUMBER)",
                f"{label} must use Codemagic's Flutter build number")
    require(app["NSSupportsLiveActivities"], "Runner must support Live Activities")
    require(app["UIFileSharingEnabled"] and app["LSSupportsOpeningDocumentsInPlace"],
            "Backup imports need the app's Documents folder in Files")
    require(widget["NSExtension"]["NSExtensionPointIdentifier"] == "com.apple.widgetkit-extension",
            "The extension must remain a WidgetKit extension")

    shared = (ROOT / "ios/Shared/WidgetStore.swift").read_text(encoding="utf-8")
    group = re.search(r'static let group = "([^"]+)"', shared).group(1)
    for path in ("ios/Runner/Runner.entitlements",
                 "ios/ExpeditionWidget/ExpeditionWidget.entitlements"):
        require(plist(path)["com.apple.security.application-groups"] == [group],
                f"App Group mismatch in {path}")
    for bundle in ("com.dahvio.telos", "com.dahvio.telos.ExpeditionWidget"):
        require(project.count(f"PRODUCT_BUNDLE_IDENTIFIER = {bundle};") == 3,
                f"Preserve {bundle} in Debug, Profile, and Release")

    # Map each UIAppFonts entry all the way to its on-disk font and build phase.
    names = set()
    for filename in widget["UIAppFonts"]:
        ref = re.search(
            r'([A-F0-9]{24}) /\* ' + re.escape(filename) +
            r' \*/ = \{isa = PBXFileReference;[^\n]*path = "([^"]+)";', project)
        require(ref is not None, f"No Xcode file reference for {filename}")
        font = (ROOT / "ios" / ref.group(2)).resolve()
        require(font.is_file(), f"Missing extension font: {filename}")
        build = re.search(
            r'([A-F0-9]{24}) /\* ' + re.escape(filename) +
            r' in Resources \*/ = \{isa = PBXBuildFile; fileRef = ' + ref.group(1), project)
        require(build is not None, f"Font has no resources build entry: {filename}")
        resource_phase = re.search(
            r'/\* Resources \*/ = \{\s*isa = PBXResourcesBuildPhase;[^}]*' + build.group(1), project)
        require(resource_phase is not None, f"Font is not copied into the extension: {filename}")
        names.update(postscript_names(font))
    swift = "\n".join(p.read_text(encoding="utf-8")
                      for p in (ROOT / "ios/ExpeditionWidget").glob("*.swift"))
    for custom_name in set(re.findall(r'\.custom\("([^"]+)"', swift)):
        require(custom_name in names, f"Unregistered SwiftUI font: {custom_name}")

    # Each bundle carries a privacy manifest declaring the required-reason APIs
    # its own code calls. Apple scans for these at upload, and the plugins'
    # manifests do not cover Telos's own Swift or Dart.
    manifests = {
        "Runner": {
            "NSPrivacyAccessedAPICategoryUserDefaults": {"CA92.1", "1C8F.1"},
            "NSPrivacyAccessedAPICategoryFileTimestamp": {"C617.1"},
        },
        "ExpeditionWidget": {
            "NSPrivacyAccessedAPICategoryUserDefaults": {"1C8F.1"},
        },
    }
    targets = {"Runner": "Runner", "ExpeditionWidget": "ExpeditionWidgetExtension"}
    for folder, reasons in manifests.items():
        path = f"ios/{folder}/PrivacyInfo.xcprivacy"
        manifest = plist(path)
        require(manifest["NSPrivacyTracking"] is False, f"{path} must not declare tracking")
        declared = {entry["NSPrivacyAccessedAPIType"]: set(entry["NSPrivacyAccessedAPITypeReasons"])
                    for entry in manifest["NSPrivacyAccessedAPITypes"]}
        for api, codes in reasons.items():
            require(codes <= declared.get(api, set()),
                    f"{path} must declare {api} with {sorted(codes)}")
        group = re.search(r'isa = PBXGroup;\s*children = \(([^)]*)\);\s*path = '
                          + re.escape(folder) + ';', project)
        ref = re.search(r'([A-F0-9]{24}) /\* PrivacyInfo\.xcprivacy \*/', group.group(1))
        require(ref is not None, f"{path} is not in the Xcode project")
        build = re.search(r'([A-F0-9]{24}) /\* PrivacyInfo\.xcprivacy in Resources \*/ = '
                          r'\{isa = PBXBuildFile; fileRef = ' + ref.group(1), project)
        require(build is not None, f"{path} has no resources build entry")
        target = re.search(r'/\* ' + re.escape(targets[folder]) +
                           r' \*/ = \{[^{}]*?isa = PBXNativeTarget;[^{}]*?buildPhases = \(([^)]*)\)',
                           project)
        phase = re.search(r'([A-F0-9]{24}) /\* Resources \*/', target.group(1)).group(1)
        resources = re.search(phase + r' /\* Resources \*/ = \{\s*isa = PBXResourcesBuildPhase;[^}]*',
                              project).group(0)
        require(build.group(1) in resources, f"{path} is not copied into {targets[folder]}")

    # Plists and storyboards must at least parse before the native build starts.
    for path in (ROOT / "ios").rglob("*.entitlements"):
        with path.open("rb") as source:
            plistlib.load(source)
    for filename in ("LaunchScreen.storyboard", "Main.storyboard"):
        tree = ET.parse(ROOT / "ios/Runner/Base.lproj" / filename)
        color = tree.find(".//color[@key='backgroundColor']")
        require(color is not None, f"No background in {filename}")
        actual = [float(color.get(channel, "-1")) for channel in ("red", "green", "blue")]
        require(all(abs(a - b / 255) < 0.00001 for a, b in zip(actual, (30, 37, 43))),
                f"{filename} must start on Night Watch charcoal")

    print("iOS source preflight passed: version wiring, App Groups, bundles, fonts, "
          "privacy manifests, launch screens.")
    print("Xcode compilation, signing, and device behavior still require the macOS build.")


if __name__ == "__main__":
    try:
        verify()
    except (ValueError, KeyError, AttributeError, OSError, struct.error, ET.ParseError) as error:
        print(f"iOS source preflight failed: {error}", file=sys.stderr)
        sys.exit(1)
