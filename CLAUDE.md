# CLAUDE.md — Swift86

## Project Goal
Bring Swift86 to feature parity with the useful parts of 86Box Manager / 86Box’s built-in VM manager while preserving its VMware Fusion-inspired UI and existing user experience. All changes are under-the-hood except for carefully chosen new context-menu actions and an optional single-screenshot feature.

## Hard Constraints
- UI must remain VMware Fusion-inspired. Do **not** adopt the 86Box Manager or VirtualBox-style system-specs view.
- Screenshots: optional (user toggle in Settings), maximum **one** screenshot per machine.
- Stop using per-machine `86box.plist` files. They are only read once, read-only, by the legacy importer, and never written or deleted.
- Machine discovery uses the folder-scanning model of 86Box v5+. A machine is any **immediate**, non-hidden, non-symlink subfolder of the user-chosen Virtual Machines folder that contains `86box.cfg`, has a section in `vmm.ini`, or (legacy, never configured) contains only an old `86box.plist`. A legacy folder is registered in `vmm.ini` on first scan. The `vmm.ini` case covers machines created in Swift86 but not yet configured.
- **Per-machine metadata lives in 86Box's own `vmm.ini`** (`~/Library/Preferences/86Box/vmm.ini`; Qt INI format; one section per machine, keyed by UUIDv5 of the canonical folder path). That covers the display name, notes, icon and last-used timestamp. These are 86Box's own keys only; Swift86 adds no keys of its own. Swift86 edits only its machines' sections and only those keys. Everything else stays byte-for-byte, writes are atomic, and Qt's `vmm.ini.lock` is honoured. No sidecar files in machine folders. The details are in PLAN.md §4.2.
- **Icons follow 86Box's model:** the `vmm.ini` `icon` key, an image path, is the source. Swift86's own replacement UX stays: Default/Custom icon radio, plus a click on the thumbnail opens the picker, which accepts any image including `.icns`.
  - A picked image is converted and saved as **`<machine folder>/Icon.png`**, and `icon` points to it. Replacing the icon replaces that file (staged, then atomically swapped after `vmm.ini` is written). There is always exactly one `Icon.png`; there is no `Icon 2.png`.
  - "Default icon" removes the key and deletes `Icon.png`.
  - Existing icons are never overwritten except by an explicit user change.
  - 86Box built-in icon names are preserved untouched and shown with the default symbol.
  - A legacy `Icon.png` becomes the icon only when `vmm.ini` has none.
- **Renaming** a machine moves its folder **and** moves its `vmm.ini` section to the new UUID. It is blocked while the machine is running.
- Never write a stub `86box.cfg`. 86Box creates it on first configure.
- Settings live in `~/Library/Application Support/Swift86/Settings.json`. It is a single JSON file holding the 86Box app path, VMs folder, ROMs, appearance, screenshot toggle, `vmm.ini` path and sidebar order (folder names). Unknown or missing keys are tolerated. No `UserDefaults`/`@AppStorage` except the one-shot legacy importer.
- **UI layer is 100% SwiftUI.** No `NSViewRepresentable`, `NSOpenPanel` (use `.fileImporter`), `NSColor`, or AppKit subclass hacks. AppKit *services* are allowed: `NSWorkspace`, `NSApp.appearance`, `NSImage` for image data, `Process`, and BSD sockets.
- SwiftUI code must be updated for macOS 27 UI conventions. The deployment target is **macOS 26.0** from Phase 4 on (owner decision).
- User-facing workflow must feel unchanged; only internal representation and persistence change.
- Do not add localization work in this pass. Keep existing localized string keys **byte-identical**, e.g. `"Edit..."`, `"Clone..."`, `"Remove \"%@\"..."` with three ASCII dots, so translations keep working. New strings are English only.

## Final Right-Click Context Menu Order

```
Start / Pause / Resume
────────────────────────
Hard Reset
Force Shutdown
Ctrl + Alt + Del
Kill
────────────────────────
Edit…
Configure…
Clone…
────────────────────────
Show in Finder
Open Printer Tray
────────────────────────
Wipe NVRAM
Remove “Machine Name”…
```

### Context Menu Notes
- **Start / Pause / Resume** appear at the top and are state-dependent: Start when powered off, Pause when running, Resume when paused. There is **no "Stop" item** (owner decision, matching 86Box Manager); Force Shutdown and Kill cover it.
- The powered-off status is shown as **"Powered Off"**, not "Stopped".
- The Kill confirmation copies 86Box Manager. The text is "Killing a virtual machine can cause data loss. Only do this if the 86Box process gets stuck.\n\nDo you really wish to kill the virtual machine "<name>"?". The buttons are **No** (the default) and **Yes**.
- **Manager protocol** (owner decision, 2026-10-16): use **86Box's official v5 manager protocol**, the same one as its built-in manager. Swift86 hosts a Unix-domain socket and passes its path in `VMM_86BOX_SOCKET`.
  - Framing: messages are framed as a 4-byte big-endian length plus compact JSON.
  - Commands: `Pause`, `CtrlAltDel`, `ShowSettings`, `ResetVM`, `RequestShutdown`, `ForceShutdown`.
  - State: 86Box reports `RunningStateChanged` (running/paused, with or without a modal), so the status is authoritative.
  - **Fallback:** if the 86Box app is older than 5.0, or its version is unknown (e.g. forks), use the legacy line protocol via `86BOX_MANAGER_SOCKET`. It accepts `pause`, `reset`, `cad`, `shutdown`, `shutdownnoprompt` and `showsettings`, and its pause state is tracked locally.
- **Force Shutdown** = `ForceShutdown` (official protocol) / `shutdownnoprompt` (legacy).
  **Kill** = last-resort process termination (SIGKILL), matching the old 86Box Manager "Kill" behaviour. Keep both; they are different. **Kill** requires a confirmation sheet.
- **Edit…** already opens the existing modal for name + icon + description. No separate "Change display name" or "Set icon" items.
- **Configure…** stays (owner decision). It opens 86Box settings; if the machine is already running, it sends `showsettings`.
- **Clone…** exists but the current implementation is cumbersome and must be rewritten cleanly.
  - It copies the **whole** machine folder, including `printer/` and `screenshots/`, as both 86Box managers do.
  - The clone gets its own `vmm.ini` section, with notes and icon carried over.
  - Absolute cfg paths that point into the source are redirected to the clone.
- **Remove "Machine Name"…** keeps the original Swift86 string style. The underlying delete method must be rewritten (cleaner, safer). It **deletes permanently** (owner decision) behind strict guards, and also removes the `vmm.ini` section. **Wipe NVRAM**, **Kill**, and **Remove…** all require a confirmation sheet.
- **File → Scan for Machines** (⌘⇧R) rescans the VMs folder, registers new machines in `vmm.ini`, and offers, with confirmation, to remove `vmm.ini` entries whose folders no longer exist.
- **Open Printer Tray**: if the `printer` subfolder does not exist inside the machine directory, create it and then open it.
- **Open Screenshots Folder** was explicitly removed.
- **Show config file** was explicitly rejected (no end-user value).
- **Wipe NVRAM** has no ellipsis. It deletes only the contents of `<machine>/nvr` (unlike 86Box Manager's "Wipe", which also deletes `86box.cfg`). The confirmation uses 86Box Manager's style: "Wiping a virtual machine's NVRAM deletes its nvr files. You'll have to reconfigure the BIOS if applicable.\n\nAre you sure you wish to wipe the NVRAM of the virtual machine "<name>"?". The buttons are No (default) and Yes. No success message is shown.

## Sub-agent Workflow (mandatory)
1. **Strong model** writes / updates the detailed plan and success criteria.
2. **Weaker models** implement discrete, well-scoped tasks.
3. **Weaker or strong model** reviews each implementation.
4. **Strong model** performs a final overall review of the complete diff before merge.

Every sub-agent task must be given:
- Exact goal
- Relevant existing files / code snippets
- Success criteria
- List of files that may be touched

## Plan & Status
The detailed plan, schemas and task breakdown are in `PLAN.md`; keep it in sync with decisions.
- Phase 0: done.
- Phase 1: done (T1–T4, T3b).
- Phase 2: done (T5, T6) on branch `phase-2-menu`.
- Phase 3: done (T7) on branch `phase-3-screenshot`.
- Phase 4: T8 (macOS 26 + modern APIs), T9 (Liquid Glass), T10 (Sparkle) and T11 (Settings tabs; classic option removed) on branch `phase-4-polish`.
- Builds are verified locally from the terminal with `xcodebuild`.

## Priority Order (this iteration)

### Phase 0 – Planning (strong model only)
- Produce a short migration plan that maps current plist-based machines → new folder + `86box.cfg` model.
- Confirm the exact schema of the new Application Support config file.
- Identify all places in the current SwiftUI code that still assume per-machine plists.
- Document how display name, description and icon (existing PNG) will be stored/read after the migration.

### Phase 1 – Settings & Discovery (core)
1. Create `~/Library/Application Support/Swift86/` and the new config file.
2. Migrate existing settings (86Box path, VMs path, ROMs, Appearance) into it.
3. Implement folder scanner that discovers machines by presence of `86box.cfg`.
4. Load display name, description, and icon (existing PNG) from the machine folder or a lightweight sidecar if needed.
5. Remove all code that reads/writes per-machine `86box.plist`.

### Phase 2 – Context Menu
Implement / optimise the final menu defined above:
- Start / Stop / Pause (already exists, keep state-dependent at top)
- Hard Reset
- Force Shutdown (clean manager-protocol request)
- Ctrl + Alt + Del
- Kill (last-resort process kill – confirmation sheet required)
- Edit… (already exists)
- Clone… (rewrite the cumbersome implementation)
- Show in Finder (already exists)
- Open Printer Tray (new – create folder if missing, then open)
- Wipe NVRAM (new – confirmation sheet required)
- Remove “Machine Name”… (rewrite the delete method – confirmation sheet required)

### Phase 3 – Optional Screenshot
- Add Settings toggle “Show machine screenshots”.
- When enabled, display exactly one screenshot per machine (user-supplied or auto-captured).
- Store the screenshot inside the machine’s folder.
- **Decisions (owner, 2026-10-17): VMware Fusion style.**
  - **Shown:** `<machine>/screenshots/Screenshot.png` if the user chose one. Otherwise the latest `Monitor_1*` screenshot 86Box took, newest by modification date.
  - **Choosing:** click the preview, or right-click → "Choose Screenshot…", to open the standard macOS Open dialog (`.fileImporter`). Any image is allowed. It is converted and copied to `screenshots/Screenshot.png` (staged, then atomically swapped). Right-click → "Remove Screenshot" deletes it (back to the latest 86Box screenshot, or the "No screenshot" box).
  - **Storage:** the choice lives only in that file, which follows rename and clone automatically. Nothing is written to `vmm.ini` or `Settings.json`.
  - **Look:** placed **above the machine header**, as in Fusion, centred. Square corners, no border, no arrows, and a subtle drop shadow below.
  - **Size (owner, 2026-10-17):**
    - Start from a 3:2 box (86Box's 240 × 160 shape), scaled to at most 55% of the visible height. The header, notes and size panel must stay visible. The minimum is 200 pt.
    - **Every preview has one height:** the height a 1280 × 700 (Windows 3.11) screenshot gets at that box's width.
    - The width follows each image's own proportions, with no black bars, limited only by the panel width.
    - The "No screenshot" box is the 3:2 width × that height.
  - **No screenshots:** a "No screenshot" box is shown when the toggle is on.
  - **No "Open Screenshots Folder"** item (rejected earlier).
- **Never store per-machine data in `Settings.json`** (owner). For machine features, match 86Box's built-in manager.

### Phase 4 – macOS 27 UI polish
- Update SwiftUI views, materials, and controls for macOS 27.
- Ensure the Fusion-inspired layout still feels native.
- **Decisions (owner, 2026-10-17):**
  - **Deployment target:** **macOS 26.0**, built with Xcode 27.
  - **Look:** system chrome (toolbar, sidebar, buttons, Settings tabs) follows macOS 27 defaults, which is Liquid Glass. There is no classic option; it was tried and removed by the owner.
  - **Swift86-drawn surfaces are flat, never glass** (owner): the notes and size panels (light fill, 1 pt border, 8 pt corner radius), the header button hover tiles, the Welcome tiles and the Edit icon thumbnail all use the original pre-T9 code. Do not add `.glassEffect` to custom views.
- **Settings tabs (owner):**
  - **General:** Check for Updates, Show machine screenshots.
  - **Application:** 86Box app, machines folder, ROMs.
  - **Appearance:** only the System/Light/Dark pop-up.
  - The tabs are the system Settings `TabView`.

### Updates (T10, owner decisions 2026-10-17)
- **Sparkle 2** via Swift Package Manager. Its standard update windows (AppKit) are the one accepted exception to the SwiftUI-only rule.
- **Menu:** "Check for Updates…" in the app menu. **Settings → General → "Check for Updates"** (default on) enables a daily automatic check. The setting lives in `Settings.json`.
- **Feed:** `https://github.com/brunocastello/Swift86/releases/latest/download/appcast.xml`, so only the release marked **Latest** is offered and pre-releases never are.
- **Versions:** plain `1.0`, `1.1`, … (`MARKETING_VERSION`), with an integer build number (`CURRENT_PROJECT_VERSION`). The first Sparkle release is 1.0, build 1.
- **Release flow:** `scripts/release.sh <version> <build>` builds, zips (`Swift86.zip`) and signs the appcast. The owner publishes with the printed `gh release create` command. Setup is in `docs/UPDATES.md`.
- **Keys:** the EdDSA private key stays in the owner's Keychain. Claude never generates or handles it.

### Phase 5 – Final Review
- Strong model reviews the entire diff.
- Verify no user-visible regression in how machines are started, stopped, or configured.
- Confirm old plist files are no longer required.

## Success Criteria
- Swift86 launches, discovers all existing machines from the VMs folder without any `.plist` files.
- App settings are read from and written to Application Support/Swift86 only. Per-machine metadata is read from and written to 86Box's `vmm.ini`, so 86Box's own manager and Swift86 always agree.
- The exact context menu defined above works correctly.
- Screenshot feature is optional and limited to one image per machine.
- UI still looks and feels like the current VMware Fusion-inspired design, updated for macOS 27.
- No new dependencies on 86Box’s own manager UI or VirtualBox-style detail panes.

## Out of Scope for this pass
- Localization
- Changing the visual style away from Fusion
- 86Box v5 manager-protocol extras beyond machine control, e.g. reacting to `ConfigurationChanged`/`GlobalConfigurationChanged` or window IDs. Machine control itself uses the official protocol (see Context Menu Notes).
- System 7 / classic Mac ports of anything
- Open Screenshots Folder
- Show config file
