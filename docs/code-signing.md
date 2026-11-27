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

The VPN is a system extension, and macOS only activates it under these conditions:

- **The app runs from `/Applications`.** That's why Run copies it there.
- **Developer ID builds are notarized.** Builds run from Xcode aren't, so Debug uses Apple Development
  signing, which doesn't need notarization.
- **The Network Extension entitlement matches the signing:** `app-proxy-provider` in Debug,
  `app-proxy-provider-systemextension` in Beta and Release.
- **The app has no Hardened Runtime exceptions** (such as `disable-library-validation`), or it won't
  launch.
- **The extension's version changes to replace the installed one.** Every Debug build gives it a new
  build number, so each Run installs the extension you just built.

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
