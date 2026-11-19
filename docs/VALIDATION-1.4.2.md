# ClipShelf 1.4.2 — free local widget signing

Verified on November 18, 2026:

- Xcode selected the user's free Personal Team for the app and extension, then completed Product → Archive. No paid membership or Developer ID signing was used.
- Universal Intel/Apple Silicon app and widget versions are 1.4.2 (10).
- Deep/strict code-signature verification passed. Both bundles have the same actual Personal Team identifier and signed macOS Team-ID App Group entitlement. Both Info.plists name that same group. Neither bundle has CloudKit entitlements in this build.
- The signed app was launched using the native UI tool. Preferences showed Desktop Favorites as enabled for interaction, rather than disabled for missing setup. Turning it on succeeded, proving the host's shared-directory access probe and snapshot write completed.
- The Snippets collection contained no entries; no test snippet was inserted into the user's library. Actual widget display, configuration/deep links and AppIntent copying remain unverified. The desktop widget host could not be inspected through the automation tool. Add a text snippet and re-add the widget to finish the live test.
- Flutter analyzer: no issues. All 34 Flutter tests passed.
- All 78 native assertions passed, including accepting a matching signed Team-ID group, rejecting wrong/absent teams and missing membership, preserving the provisioned group path, rejecting unusable storage and cleaning up the access probe.
- All 11 signing-generation/validation checks passed with fictional inputs. Widget Swift code also compiled with application-extension API restrictions.

The command-line signing identity lookup in the agent environment exposed no usable identities; Xcode's normal Keychain signing succeeded. No certificate private keys or passwords were exported. Device-local team configuration and generated local entitlements are ignored and excluded from the source package.

The app was left running from outputs/ClipShelf-1.4.2-personal-team/ClipShelf.app with Desktop Favorites enabled. Existing history was retained. Direct paste may require Accessibility authorization for the new signing identity; iCloud remains off. This is a local development-signed build, not a notarized public release.
