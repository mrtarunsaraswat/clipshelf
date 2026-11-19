# iCloud sync

iCloud sync is built but **disabled** in public builds until CloudKit is provisioned with a paid Apple Developer account.

## How sync works

The sync layer uses the **current Apple Account's private CloudKit database**, not an app-operated server. Each clip and pinboard has its own record. Versions and deletion tombstones persist locally, allowing offline changes to retry later without replacing another Mac's whole archive. Conflicting changes to the same item use the later timestamp, with deterministic ties; a deletion wins an exact-time tie. Keep system clocks accurate.

Sync is opt-in. Enabling it explicitly confirms that existing history, snippets, and pinboards will upload. Small metadata queries run about every 30 seconds while the app is running, with debounced uploads after local changes and a manual **Sync now** action. Asset payloads download only for changed/new items. CloudKit throttling backoff is respected. This is eventual sync, not an instant-transfer guarantee. The app must be running to participate.

An Apple Account change stops sync and requires another explicit enable action, reducing accidental uploads to a different account. Disabling sync retains local and previously uploaded data. Explicit item deletions and clearing history propagate through tombstones; saved snippets and pinned items survive Clear History. Local capacity eviction does not delete older cloud history. Tombstones retain identifiers/version metadata, not the deleted payload. CloudKit/iCloud backups and server retention are outside the app's control.

File references sync as references: the original file contents do not upload, and a path on one Mac may not exist on another. There is no app-level end-to-end encryption claim. CloudKit's platform protections apply; local history is not encrypted by the app.

## Provision an iCloud release

1. Join the Apple Developer Program. Choose a unique bundle identifier in `macos/Runner/Configs/AppInfo.xcconfig` and create its explicit App ID.
2. Enable **iCloud / CloudKit** for that App ID, create a container such as `iCloud.your.company.ClipShelf`, and associate it with the App ID.
3. In CloudKit Console, create record type **ClipShelfEntity** with **stamp** (Bytes) and **payload** (Asset). Make **recordName** / the system record ID queryable so the type can be enumerated with a true predicate. Deploy the schema to Production. The app uses a private custom zone named **ClipShelf**; the app creates this zone.
4. Create/install a **Developer ID Application** signing certificate and an explicit **Developer ID provisioning profile** authorizing the bundle ID, Production CloudKit, and that container. The profile must not permit debugging. Put the profile somewhere outside source control.
5. Store notarization credentials locally with `xcrun notarytool store-credentials`; do not send or commit passwords/private keys.
6. Run:

```sh
ICLOUD_CONTAINER_IDENTIFIER='iCloud.your.company.ClipShelf' \
ICLOUD_PROVISIONING_PROFILE='/absolute/path/ClipShelf.provisionprofile' \
DEVELOPER_ID_APPLICATION='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='your-keychain-profile' \
./scripts/release_macos.sh
```

The release script runs checks, builds, validates the profile's App ID/container/services/environment, embeds the profile, and signs with production entitlements derived from it. It signs frameworks explicitly, notarizes/staples the app, builds a DMG, signs/notarizes/staples it, and writes its checksum under `dist/`. It uploads signed artifacts to Apple's notarization service. This flow has not been run with real owner credentials.

For a local-only public release, omit the two `ICLOUD_…` variables; Developer ID signing and notarization are still needed. The bundled ad-hoc test app is not a trusted public download, and Gatekeeper may block downloaded copies. An ad-hoc update can also change the identity macOS uses for Accessibility authorization. Install the new app at a stable path, quit earlier running copies, and if access still appears denied, remove the older ClipShelf entry in Accessibility and authorize the installed build. The banner follows the running process’s actual permission, not whether the Allow button was clicked. A Mac App Store build needs a separate sandbox/permission review.
