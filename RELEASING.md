# CopyThat release checklist

CopyThat checks GitHub's public latest-release API. It can download a release
DMG, but it never replaces the installed application itself. The user opens the
DMG and drags CopyThat into Applications. When GitHub supplies an asset digest,
CopyThat verifies the SHA-256 value before opening the image.

For every release:

1. Increase both `MARKETING_VERSION` and the monotonically increasing
   `CURRENT_PROJECT_VERSION` in the Xcode project.
2. Build the Release app, run the full test suite, and verify the app bundle
   with `codesign --verify --deep --strict`.
3. Create both `dist/CopyThat-<version>.dmg` and `dist/CopyThat.dmg` from the
   exact same verified app bundle.
4. Add matching bilingual notes under `ReleaseNotes/`.
5. Commit and merge the source, create GitHub Release `v<version>`, and upload
   both DMGs. Keep `CopyThat.dmg` as the stable updater asset name.
6. Confirm the latest-release API returns the new version and both asset URLs.
7. Test **Check Now…** from the previous installed release, download the DMG,
   and complete the manual drag-to-Applications replacement before announcing it.

Do not add an installer helper, disable library validation, or make CopyThat
self-replace. Rebuild both DMG files whenever the app bundle changes.
