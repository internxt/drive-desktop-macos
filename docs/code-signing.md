# Code signing

## Configurations

| Configuration | Used for | Signing | Notarized |
|---|---|---|---|
| Debug | Run from Xcode | Automatic, Apple Development | No |
| Beta | QA (`fastlane beta_ci`) | Manual, Developer ID + `match` | Yes, by CI |
| Release | Production (`fastlane prod_ci`) | Manual, Developer ID + `match` | Yes, by CI |

## Run locally

1. Sign in to Xcode with your Apple ID from the Internxt team (Settings → Accounts).
2. Run the `InternxtDesktop` scheme. The app is copied to `/Applications/Internxt Drive.app`
   (replacing any installed copy) and launched from there.
3. The first time you connect the VPN, approve it in System Settings → General →
   Login Items & Extensions → Network Extensions.

## Why

The VPN is a system extension (`internxt.InternxtDesktop.vpn`) embedded in the app. macOS (`sysextd`)
is strict about how it is installed and signed, and the app's original setup (Developer ID signing,
run from DerivedData, `disable-library-validation`) couldn't launch the app or activate the VPN.
These are the rules and what we changed for each one.

### The app runs from `/Applications`

`sysextd` only activates an extension whose app is in `/Applications`; from DerivedData activation
fails with `OSSystemExtensionErrorDomain` code 3. So the `InternxtDesktop` scheme has a Run pre-action
(`scripts/install-to-applications.sh`) that:

- quits the running app, copies the build to a temporary folder and only then replaces
  `/Applications/Internxt Drive.app`, so a failed copy doesn't leave you without an app;
- writes its output to `$TMPDIR/internxt-install-to-applications.log`, because Xcode doesn't show it
  and doesn't stop the launch if it fails.

The scheme launches that copy instead of the one in DerivedData. The cost: every Run replaces any
Internxt Drive installed on the Mac.

### Debug is signed with Apple Development

A Developer ID extension is only accepted if it is notarized, and builds run from Xcode aren't
(`sysextd` rejects them with code 8, "code signature invalid"). Apple Development extensions are not
checked for notarization, so Debug uses automatic Apple Development signing: Xcode creates the
profiles and registers each Mac by itself. Beta and Release keep Developer ID with `match` and are
notarized by CI.

### The Network Extension entitlement depends on the signing

Developer ID requires `app-proxy-provider-systemextension`; development profiles only allow
`app-proxy-provider`. That's why the app and the extension have one entitlements file per signing:
`InternxtDesktop.entitlements` / `VPNExtension.entitlements` for Beta and Release, and
`InternxtDesktopDebug.entitlements` / `VPNExtensionDebug.entitlements` for Debug. The extension also
needs `NSSystemExtensionUsageDescription` in its `Info.plist`, or activation fails with code 9.

### No Hardened Runtime exceptions on the app

With the system extension entitlements, AMFI refuses to launch an app that also has
`com.apple.security.cs.disable-library-validation` ("Launchd job spawn failed", POSIX 163). We removed
it from every configuration. It isn't needed: every embedded library (frameworks, ClamAV dylibs and
binaries) is copied with Code Sign On Copy, so it is signed by our team and passes library validation.
Debug's runpath lists both `@executable_path/../Frameworks` and
`@executable_path/../ClamAVResources/lib`; before, a Debug-only setting replaced the whole list with
the ClamAV folder.

### Every Debug build gives the extension a different version

`sysextd` only replaces an installed extension when its version changes; with the same version it
keeps the installed one. Without a new version:

- changes to the extension's code don't take effect on Run;
- if the installed extension came from a Beta or Release build (Developer ID), the Debug app can't
  connect to it: `nesessionmanager` logs "does not satisfy the code signature requirements".

So the last build phase of `VPNExtension` (`scripts/stamp-debug-build-number.sh`) sets its build number
to `<CURRENT_PROJECT_VERSION>.<unix timestamp>` in Debug. It edits the generated `Info.plist` before
signing, which is why that configuration has `ENABLE_USER_SCRIPT_SANDBOXING = NO`. Beta and Release
keep the project's build number, so each Beta or Release must bump it for users to get the new
extension (CI already refuses to publish a version that exists).

### What we ruled out

- `systemextensionsctl developer on` (activates extensions from anywhere): needs SIP disabled.
- A separate bundle ID for Debug, so it doesn't replace the installed app: it would duplicate the App
  Group, the shared keychain, the File Provider and the portal capabilities.

## CI

Each bundle ID needs its `match Direct <bundle id> macos` profile in `internxt/apple-certificates` and
must be listed in `fastlane/Matchfile` and in the `match` calls in `fastlane/Fastfile`.

## Troubleshooting

- **The app is killed at launch:**
  `log show --last 2m --style json --predicate 'sender == "AppleMobileFileIntegrity"'`
- **The VPN doesn't activate or connect:**
  `log show --last 5m --predicate 'process == "sysextd" OR process == "nesessionmanager"'`
- **Run launches an old build:** read the copy log in `$TMPDIR/internxt-install-to-applications.log`.
- **Xcode still launches from DerivedData:** quit and reopen Xcode.
- **The project file changed after opening it in Xcode:** check that Beta and Release still use manual
  signing with their `match` profiles and that the embed phases are still there.
