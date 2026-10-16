# Updates (Sparkle)

Swift86 updates itself with [Sparkle](https://sparkle-project.org). It only
offers the GitHub release marked **Latest**, never pre-releases.

## One-time setup

1. Generate the signing keys once. Build the app first so Sparkle's tools exist,
   then run:

   ```
   build/release/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
   ```

   (After a Debug build the same tool is under the DerivedData path, in
   `SourcePackages/artifacts/sparkle/Sparkle/bin/`.) The private key goes into
   your login Keychain and the public key is printed.

   Back the private key up, and keep the file safe and out of the repository:

   ```
   generate_keys -x private-key-file
   ```

   Restore it on another Mac with `generate_keys -f private-key-file`. Losing
   the key means installed copies can never update.

2. Paste the public key into `SUPublicEDKey` in `Swift86/Info.plist`, replacing
   `REPLACE_WITH_PUBLIC_ED_KEY`.

## Releasing

1. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the Xcode project
   (both Debug and Release). The build number must always increase.
2. Run `scripts/release.sh <version> <build>`, e.g. `scripts/release.sh 1.0 1`.
   It checks the versions and the key, builds Release, zips the app and writes
   a signed `appcast.xml` into `build/release/dist/`.
3. Run the `gh release create ...` command the script prints.
4. On GitHub, make sure that release is marked **Latest**. The feed URL
   (`releases/latest/download/appcast.xml`) always follows the Latest release.

## Things to know

- The first Sparkle-enabled build (1.0) must be installed manually. Older
  builds cannot update themselves.
- Updates must be signed with the same Apple team (KB99AZQYGK) and the same
  EdDSA key as the installed version, or Sparkle rejects them.
- The daily check is the "Check for Updates" checkbox in Settings > General.
