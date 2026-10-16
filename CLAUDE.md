# CLAUDE.md — Swift86

## Project Goal
Bring Swift86 to feature parity with the useful parts of 86Box Manager / 86Box’s built-in VM manager while preserving its VMware Fusion-inspired UI and existing user experience. All changes are under-the-hood except for carefully chosen new context-menu actions and an optional single-screenshot feature.

## Hard Constraints
- UI must remain VMware Fusion-inspired. Do **not** adopt the 86Box Manager or VirtualBox-style system-specs view.
- Screenshots: optional (user toggle in Settings), maximum **one** screenshot per machine.
- Stop using per-machine `86box.plist` files. They are only read once, read-only, by the legacy importer, and never written or deleted.
- Machine discovery uses the folder-scanning model of 86Box v5+. A machine is any **immediate**, non-hidden, non-symlink subfolder of the user-chosen Virtual Machines folder that contains `86box.cfg` or has a section in `vmm.ini`. The `vmm.ini` case covers machines created in Swift86 but not yet configured.
- **Per-machine metadata lives in 86Box's own `vmm.ini`** (`~/Library/Preferences/86Box/vmm.ini`; Qt INI format; one section per machine, keyed by UUIDv5 of the canonical folder path). That covers the display name, notes, icon and last-used timestamp. Swift86 edits only its machines' sections and only those keys. Everything else stays byte-for-byte, writes are atomic, and Qt's `vmm.ini.lock` is honoured. No sidecar files in machine folders. The details are in PLAN.md §4.2.
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
- SwiftUI code must be updated for macOS 27 UI conventions. The deployment target stays macOS 13 until Phase 4 decides otherwise.
- User-facing workflow must feel unchanged; only internal representation and persistence change.
- Do not add localization work in this pass. Keep existing localized string keys **byte-identical**, e.g. `"Edit..."`, `"Clone..."`, `"Remove \"%@\"..."` with three ASCII dots, so translations keep working. New strings are English only.

## Final Right-Click Context Menu Order

```
Start / Stop / Pause
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
- **Start / Stop / Pause** appear at the top and are state-dependent. Only Start existed before this project; Stop and Pause are new.
- **Manager protocol:** use 86Box's Unix manager socket. Swift86 hosts a Unix-domain socket and passes its path in the env var `86BOX_MANAGER_SOCKET`. 86Box connects to it and accepts newline-terminated commands: `pause`, `reset`, `cad`, `shutdown`, `shutdownnoprompt`, `showsettings`. Send one command per write. Pause state is not reported back, so Swift86 tracks it locally.
- **Stop** = `shutdown` (graceful). **Force Shutdown** = `shutdownnoprompt`.
  **Kill** = last-resort process termination (SIGKILL), matching the old 86Box Manager "Kill" behaviour. Keep both; they are different. **Kill** requires a confirmation sheet.
- **Edit…** already opens the existing modal for name + icon + description. No separate "Change display name" or "Set icon" items.
- **Configure…** stays (owner decision). It opens 86Box settings; if the machine is already running, it sends `showsettings`.
- **Clone…** exists but the current implementation is cumbersome and must be rewritten cleanly. The clone gets its own `vmm.ini` section.
- **Remove "Machine Name"…** keeps the original Swift86 string style. The underlying delete method must be rewritten (cleaner, safer). It **deletes permanently** (owner decision) behind strict guards, and also removes the `vmm.ini` section. **Wipe NVRAM**, **Kill**, and **Remove…** all require a confirmation sheet.
- **File → Scan for Machines** (⌘⇧R) rescans the VMs folder, registers new machines in `vmm.ini`, and offers, with confirmation, to remove `vmm.ini` entries whose folders no longer exist.
- **Open Printer Tray**: if the `printer` subfolder does not exist inside the machine directory, create it and then open it.
- **Open Screenshots Folder** was explicitly removed.
- **Show config file** was explicitly rejected (no end-user value).
- **Wipe NVRAM** has no ellipsis.

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
- Phase 1: T1, T2, T3 and T4 done. T3b (`vmm.ini` metadata) is in progress.
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

### Phase 4 – macOS 27 UI polish
- Update SwiftUI views, materials, and controls for macOS 27.
- Ensure the Fusion-inspired layout still feels native.
- Add Settings → Appearance → "Use classic styling for machine views". It switches only Swift86-drawn surfaces between the classic look and Liquid Glass, because system chrome follows the OS. See PLAN.md §7.1.

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
- Full 86Box v5+ JSON manager protocol (can be a later enhancement)
- System 7 / classic Mac ports of anything
- Open Screenshots Folder
- Show config file
