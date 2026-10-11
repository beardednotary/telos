# Night Watch: Codemagic handoff

The existing Codemagic service builds and auto-numbers Telos. The latest
TestFlight build is **23**, confirmed by the owner on 2026-10-11. Keep that
workflow's signing, numbering, and distribution configuration. The repository
version remains `0.1.0+13`; Codemagic overrides the build number. The next upload
must be greater than 23 (normally 24 if no intervening build runs).

There is no `codemagic.yaml` in this repository. Do not introduce one merely for
this migration: Codemagic documents that a YAML workflow can take over automatic
build configuration from the workflow editor. Keep the working editor setup.
[Codemagic build triggers](https://docs.codemagic.io/flutter-running-builds/starting-builds-automatically/)

## Pre-build step

Add this to the existing workflow's **Pre-build** script alongside its existing
numbering script, keeping that script intact:

```sh
python3 tool/preflight.py
```

It checks native bundle wiring, font registration and launch XML, installs the
locked Dart dependencies, analyzes Flutter, and runs the behavior/economy suite.
It stops on failure. Golden images are reviewed on Windows and excluded from the
cloud gate because font rasterization differs across operating systems.

The script does not increment versions, choose signing profiles, build an IPA,
or publish. The existing workflow remains responsible for those operations.
Runner and ExpeditionWidget both read `FLUTTER_BUILD_NAME` and
`FLUTTER_BUILD_NUMBER`, so the established override reaches both bundles.
[Codemagic build versioning](https://docs.codemagic.io/knowledge-codemagic/build-versioning/)

## Existing build settings to preserve

| Setting | Value or check |
|---|---|
| Flutter | Repo requires 3.47.0 or newer; use the currently successful SDK/channel. |
| Build mode | Release for TestFlight. |
| Main bundle | `com.dahvio.telos` |
| Extension bundle | `com.dahvio.telos.ExpeditionWidget` |
| Shared App Group | `group.com.dahvio.telos` on both signing profiles. |
| Version | `0.1.0`; build number supplied by the existing auto-bump. |
| iOS deployment | App 15.0, Widget/Live Activity extension 16.2, unchanged. |
| Xcode signing | Supplied by the existing Codemagic configuration; no team or private signing material added to the repository. |

## Contents of this candidate

- Complete Night Watch Flutter screens, bundled Plex typography, guild identity,
  and clearer planning/equipment comparisons using the existing game rules.
- The widget and Live Activity use brass/charcoal and the actual PostScript names
  of the bundled Plex fonts. Launch and Flutter host backgrounds use charcoal.
- Read-only past reports, guided backup replacement, and an anchored native backup
  share sheet for iPad. Directory reads are asynchronous.
- Existing application icon, app identifiers, duration gates, Integrity formula,
  App Group data, and automatic build numbering are preserved.

## Build and handoff

1. Upload the reviewed source commit to the branch used by the existing workflow.
   A push may start and publish a build if that workflow is configured to do so.
2. Run the existing Codemagic workflow, with the pre-build step above. Check that
   the log names the intended commit and applies a build number greater than 23.
3. Require a successful **signed iOS archive/export**, including the widget
   extension. Windows checks and an Android APK do not establish this.
4. Install the candidate through the existing TestFlight route. Run the
   [physical iPhone pass](device-validation.md), including a real 25-minute
   session and a longer one. Exercise native Files export/import and image sharing.

Build availability is distinct from verification: an uploaded candidate still
needs the device pass. Flutter documents macOS/Xcode as the iOS build environment;
Codemagic supplies that environment here.
[Flutter iOS deployment](https://docs.flutter.dev/deployment/ios)

The Codemagic account configuration and signing profiles cannot be verified from
this Windows repository. No iOS archive or new TestFlight build has been produced
by this local preparation.
