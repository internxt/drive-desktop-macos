# Code signing

How each build configuration is signed, and what you need to run the app locally with the VPN.

## The problem, in short

The VPN is a macOS system extension (`internxt.InternxtDesktop.vpn`) embedded in the app. macOS only
activates a system extension when the app that installs it is in `/Applications`, is signed in a way
`sysextd` accepts (notarized if it is Developer ID), carries the right Network Extension entitlement
for that signing, and has no Hardened Runtime exceptions. Before the VPN, the app ran from Xcode with
Developer ID signing straight from DerivedData and with `disable-library-validation`; with the
extension inside, that setup can't launch the app or activate the VPN.

The solution below is the smallest change we found that keeps CI as it was and lets anyone run the
VPN from Xcode. If you see a simpler way, propose it: nothing here is meant to be final.

## Summary

| Configuration | Used for | Signing | Profiles | Notarized |
|---|---|---|---|---|
| Debug | Running from Xcode, including the VPN | Automatic, Apple Development | Created by Xcode with your Apple ID | No (not needed) |
| Beta | QA builds from CI (`fastlane beta_ci`) | Manual, Developer ID Application | `match Direct …` (fastlane match) | Yes, by CI |
| Release | Production builds from CI (`fastlane prod_ci`) | Manual, Developer ID Application | `match Direct …` (fastlane match) | Yes, by CI |

Team: `JR4S3SY396`. Bundle IDs: `internxt.InternxtDesktop` (app), `internxt.InternxtDesktop.sync` (File Provider),
`com.internxt.XPCBackupService` (backups), `internxt.InternxtDesktop.vpn` (VPN system extension),
`internxt.InternxtDesktop.cleaner.helper` (cleaner helper).

## How running behaves now

| Where | What happens |
|---|---|
| Xcode, Run (`InternxtDesktop` scheme) | Builds **Debug** with automatic Apple Development signing, copies the app to `/Applications/Internxt Drive.app` (quitting any running copy and replacing the installed one) and launches that copy. The VPN works after approving the extension once. |
| Xcode, Test | Tests build with the app as host in Debug, so locally they need the same Apple ID setup as Run. They don't need the VPN to be approved. CI runs them with code signing disabled. |
| CI, Beta (`fastlane beta_ci`) | Same flow (Developer ID signing with `match`, then notarization), with two differences: `match` also fetches the VPN extension's profile, and the app no longer has `disable-library-validation`. |
| CI, Release (`fastlane prod_ci`) | Same as Beta. |
| A Developer ID build run from Xcode | Not supported anymore: the extension is rejected because the build isn't notarized. Use Debug locally, or a notarized build from CI. |

**Removing `disable-library-validation` also affects Beta and Release.** It is required there too: AMFI
refuses to launch any app that has both the system-extension entitlements and that exception. Every
embedded library (the `ClamAVResources/lib` dylibs, `clamscan`/`freshclam`, the frameworks) is copied
with Code Sign On Copy, so it is re-signed by our team and library validation passes. Check it once on
the first Beta build from CI: `codesign -dv` on every file under `Contents/ClamAVResources` and
`Contents/Frameworks` must show `TeamIdentifier=JR4S3SY396`, and the notarized app must launch and run
a scan.

## Running locally (Debug)

1. In Xcode, sign in with your Apple ID (Settings → Accounts). It must belong to team `JR4S3SY396`
   with a role that can create development profiles. Xcode creates the profiles, but it can't enable
   capabilities on the App IDs: `internxt.InternxtDesktop` needs Network Extensions, System Extension,
   App Groups, Keychain Sharing, Push Notifications and Associated Domains, and
   `internxt.InternxtDesktop.vpn` needs Network Extensions and App Groups, enabled in the developer portal.
2. Run the `InternxtDesktop` scheme. The Run action uses Debug, and Xcode creates and renews the
   development profiles and registers your Mac the first time.
3. Before launching, the scheme's Run pre-action (`scripts/install-to-applications.sh`) copies the
   app to `/Applications/Internxt Drive.app` and Xcode launches that copy. This overwrites any
   Internxt Drive already installed there.
4. The first time you connect the VPN, approve the extension in System Settings → General →
   Login Items & Extensions → Network Extensions.

The pre-action's output is not shown in Xcode; it is written to
`$TMPDIR/internxt-install-to-applications.log`. The new build is copied to a temporary folder first and
only then replaces the installed app, so a failed copy doesn't leave `/Applications` without it. Xcode
doesn't stop the launch when a pre-action fails, so if the app you see is older than your build, read
that log.

Debug also adds `@executable_path/../ClamAVResources/lib` to the runpath next to
`@executable_path/../Frameworks` (before, a conditional setting replaced the whole list).

## Why it is set up this way

macOS enforces these rules on the VPN system extension and on the app that installs it:

- **The app must be in `/Applications`.** Otherwise activation fails with
  `OSSystemExtensionErrorDomain` code 3. Hence the Run pre-action.
- **Developer ID-signed extensions must be notarized.** A Developer ID build run from Xcode is not
  notarized, so `sysextd` rejects it with code 8, "code signature invalid". Extensions signed with
  Apple Development are not checked for notarization, which is why Debug uses development signing.
  The other way out, `systemextensionsctl developer on`, needs SIP disabled.
- **The Network Extension entitlement value depends on the signing.** Developer ID uses
  `app-proxy-provider-systemextension` (`InternxtDesktop.entitlements`, `VPNExtension.entitlements`).
  Development signing uses `app-proxy-provider` (`InternxtDesktopDebug.entitlements`,
  `VPNExtensionDebug.entitlements`).
- **No Hardened Runtime relaxation entitlements on the app.** Since the app carries the
  system-extension entitlements, AMFI refuses to launch it if it also has
  `com.apple.security.cs.disable-library-validation` or similar ("Launchd job spawn failed",
  POSIX 163). Every embedded library is signed by our team, so library validation passes without it.
- **The extension needs `NSSystemExtensionUsageDescription`** in its `Info.plist`, or activation
  fails with code 9.

## CI

CI builds Beta and Release with fastlane, downloads the Developer ID profiles with `match`
(`fastlane/Matchfile`, repo `internxt/apple-certificates`) and notarizes the app and the DMG.
Tests run with code signing disabled, so they don't depend on any of this.

Every bundle ID above needs its `match Direct` profile in the certificates repo and must be listed in
`fastlane/Matchfile` and in the `match` calls in `fastlane/Fastfile`. `internxt.InternxtDesktop.vpn`
is listed in both; its profile (`match Direct internxt.InternxtDesktop.vpn macos`) must exist in
`internxt/apple-certificates` with the `networkextension` (app proxy, system extension) capability,
and the app's profile must include `networkextension` and `system-extension.install`.

## Open questions for the team

- **Copying to `/Applications` on every Run** replaces any Internxt Drive installed there. It is the
  only way we found to activate the extension from Xcode without disabling SIP
  (`systemextensionsctl developer on`). A different install path or a separate local bundle ID could
  avoid overwriting the installed app.
- **`internxt.InternxtDesktop.cleaner.helper`** is in the `Matchfile` but not in the `match` calls of
  the `Fastfile`, and its Debug configuration still uses manual Developer ID signing. It doesn't block
  the VPN, but it should be checked.
- **Extension approval UX:** today the user goes to System Settings by hand. Opening the right pane
  directly and connecting as soon as it is approved would be smoother.

## Troubleshooting

- **The app is killed at launch.** Read the real reason with
  `log show --last 2m --style json --predicate 'sender == "AppleMobileFileIntegrity"'`.
  The compact log style truncates the message.
- **The VPN extension is rejected.** Read `log show --last 5m --predicate 'process == "sysextd"'`.
- **Xcode keeps launching from DerivedData.** Xcode didn't reload the scheme after it changed on
  disk. Quit and reopen Xcode.
- **The project file changed after opening it in Xcode.** Check that Beta and Release still have
  `CODE_SIGN_STYLE = Manual` and their `match Direct` profiles, and that the embed phases (Foundation
  Extensions, XPC Services, System Extensions) are still there. Xcode can rewrite them silently.
