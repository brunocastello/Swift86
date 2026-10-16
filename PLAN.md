# Swift86 — Phase 0 Migration Plan

Status: **approved for Phase 1** (D2–D4 decided 2026-10-16; D1 deferred to Phase 4; D5 uses the recommended default).
Author: strong model (Phase 0). Implementation tasks in §7 are written to be handed to weaker sub-agents verbatim.

---

## 1. Current state (as of `c44bfc2`)

Swift86 is ~1.9k lines of SwiftUI. All machine logic lives in `Swift86/Models/Library.swift`.

| Concern | Today |
|---|---|
| Settings | `UserDefaults` keys `EmulatorPath`, `MachinesPath`, `RomsPath`, `CustomROMs`, `Appearance`, `First Run`, `MachinesList` |
| Discovery | `Library.load()` lists `MachinesPath`; a subfolder is a machine **iff it contains `86box.plist`** |
| Machine identity | `Id` UUID stored in `86box.plist` |
| Display name | **Folder name** (also stored redundantly as `Name` in the plist). Launch uses `-V <name> -P <machinesPath>/<name>` |
| Notes | `Notes` in the plist |
| Icon | `IconCustom` bool in the plist + `Icon.png` in the machine folder |
| Order | `MachinesList` = array of UUID strings in `UserDefaults` |
| Process control | `Process` per machine; only **Start** and **Configure (-S)**. No Stop, Pause, Reset or any IPC |

**Correction to CLAUDE.md:** it says "Start / Stop / Pause (already exists)". Only **Start** exists today. Stop and Pause have to be built in Phase 2, on the IPC described in §5.

### 1.1 Every place that assumes per-machine plists or UserDefaults

| File:line | Assumption |
|---|---|
| `Models/Library.swift:104,108–128` | Discovery gated on `86box.plist`; reads `Information` dict; force-unwraps `Id` (crashes on a malformed plist) |
| `Models/Library.swift:136–139` | Sort by UUID order from `UserDefaults["MachinesList"]` |
| `Models/Library.swift:234–331` (`save`) | Writes `86box.plist`; icon copy logic |
| `Models/Library.swift:151–183` (`create`), `191–229` (`edit`), `348–383` (`clone`) | All persist through `save` → plist |
| `Models/Library.swift:336–343` (`move`) | Writes UUID order to `UserDefaults` |
| `Models/Library.swift:24–55,70,80` | Paths and the first-run flag read from `UserDefaults` |
| `Models/Machine.swift:19–23` | `id: UUID` is persisted identity; `iconCustom` is a stored flag |
| `Models/AppSettings.swift:76` | `browsePath` writes the chosen path straight to `UserDefaults` |
| `AppDelegate.swift:24–45` | Seeds/registers `UserDefaults` defaults; applies appearance |
| `Views/GeneralSettingsView.swift:22–25,51,80,117,133,144` | `@AppStorage` + direct `UserDefaults` writes |
| `Views/AppearanceSettingsView.swift:17` | `@AppStorage("Appearance")` |
| `Views/SidebarView.swift:24,121–123` | `@AppStorage("MachinesPath")` triggers reload |

### 1.2 Latent bugs to fix along the way (no UX change)
- `edit()` renames by **copy then delete** the whole machine folder. This is slow for large disk images and leaves a partial copy behind if it fails. Use `moveItem`.
- `delete()` builds its path from `machine.name`. The only thing stopping an empty name from deleting the entire library is an `isEmpty` check.
- `sizeOf` walks the whole machine folder synchronously inside `MachineView.body` on every render.
- `load()` sort comparator re-reads UserDefaults per comparison; unknown machines get index −1 (unstable order).
- `AppSettings` is instantiated twice (`.shared` and a `@StateObject` in `SettingsView`).
- `EditMachineView` dismisses the sheet even when save fails.
- The custom-icon picker copies any image type to `Icon.png` without converting it.

---

## 2. Facts verified against 86Box `master` source (Oct 2026)

- **Discovery (86Box v5 `VMManagerSystem::scanForConfigs`)**: recursive `QDirIterator` for files named `86box.cfg` under the VM path. It excludes a `86box.cfg` at the root itself. A VM's short name is its directory name.
- **v5 per-VM metadata** (`display_name`, `notes`, `icon`, `timestamp`) is **not** stored in the machine folder. It lives in a global `vmm.ini` keyed by a hash of the config path, and the icon is a built-in icon name, not a PNG. **There is nothing in the machine folder to interoperate with.** Swift86 keeps its own sidecar (§4).
- **v5 standard sub-folders**: `screenshots/` (files `Monitor_1*`), `nvr/`, `printer/`.
- **IPC (`src/qt/qt_main.cpp`, `src/qt/qt_unixmanagerfilter.cpp`)**: on non-Windows, 86Box reads env var **`86BOX_MANAGER_SOCKET`**. If set, 86Box connects as a **client** (`QLocalSocket::connectToServer(path)`; an absolute path is used as a Unix-domain socket path). It accepts newline-terminated ASCII commands:

  | Line | Effect in 86Box |
  |---|---|
  | `pause` | `togglePause` (toggle — no state is reported back) |
  | `reset` | `hardReset` |
  | `cad` | `pc_send_cad()` (Ctrl+Alt+Del) |
  | `shutdown` | `MainWindow::close` (graceful; 86Box may show its own "exit?" prompt) |
  | `shutdownnoprompt` | `do_stop()` + close (**Force Shutdown**) |
  | `showsettings` | open Settings dialog in the running VM |

  86Box writes `"1"` / `"0"` back when a modal dialog blocks / unblocks its window. **`readyToRead` handles only one line per read event**, so the manager must send exactly one command per write and must not batch.
  This "legacy" protocol has existed since 2022 (v3.x) and is still in master, separate from the v5 JSON protocol (`VMM_86BOX_SOCKET`). It satisfies "Force Shutdown via manager protocol" without pulling in the out-of-scope JSON protocol.
- Old short CLI flags `-R` (ROM path), `-V` (VM name), `-P` (VM path), `-S` (settings) are still valid.

---

## 3. New Application Support config — schema

Path: `~/Library/Application Support/Swift86/Settings.json` (directory created on launch).
Format: JSON (UTF-8, pretty-printed, sorted keys), written atomically. JSON rather than plist, so no plist files remain in the design.

```jsonc
{
  "schemaVersion": 1,
  "emulatorPath": "/Applications/86Box.app",   // .app bundle; binary = Contents/MacOS/<bundle name> (keeps PCBox-fork support)
  "machinesPath": "/Users/<u>/Documents",       // the Virtual Machines folder that gets scanned
  "customROMs": false,
  "romsPath": "/Users/<u>/Library/Application Support/net.86box.86Box/roms",
  "appearance": "",                              // "" | "NSAppearanceNameAqua" | "NSAppearanceNameDarkAqua"
  "showScreenshots": false,                      // Phase 3
  "machineOrder": ["Win98 SE", "DOS 6.22"],      // folder names; unknown folders appended alphabetically
  "hasCompletedFirstRun": true
}
```

Rules:
- Decode with a hand-written `init(from:)` that falls back to defaults for every missing key, so future fields never break old files.
- Exactly one `@MainActor final class SettingsStore: ObservableObject` (singleton injected via `.environmentObject`) owns the struct. Every mutation persists through `didSet` with a debounced atomic write. **No `@AppStorage` and no `UserDefaults` anywhere after Phase 1**, except the one-shot importer.
- `romsPath` is passed to `-R` only when `customROMs == true` (same behaviour as today).

### 3.1 One-shot settings migration
Runs when `Settings.json` does not exist:
1. Read `UserDefaults` keys `EmulatorPath`, `MachinesPath`, `RomsPath`, `CustomROMs`, `Appearance`, `First Run`. Fall back to defaults for any that are missing.
2. Translate `MachinesList` (UUID strings) into folder names. For each folder in `machinesPath`, read the legacy `86box.plist`'s `Information.Id` (read-only) and map UUID → folder name.
3. Write `Settings.json`. **Do not delete the UserDefaults domain** (keeps downgrade possible; harmless).

---

## 4. Machine model after migration

| Field | Source of truth |
|---|---|
| **Identity (persistent)** | Folder name (`URL.lastPathComponent`) — unique within `machinesPath` |
| **Identity (in-memory)** | `id: UUID`, transient. `load()` **reuses the existing UUID for a folder already in memory**, so running processes, selection and open sheets survive a rescan |
| **Display name** | Folder name (unchanged from today; it's also what `-V` receives). Rename = `FileManager.moveItem` of the folder |
| **Description / notes** | Sidecar `<machine>/.swift86.json` → `{ "schemaVersion": 1, "notes": "…" }`. Hidden, so the folder looks clean in Finder; travels with Clone, Finder copy and backups. **Always written on save, even when notes are empty.** Its existence marks the machine as created by or imported into Swift86, which stops the legacy import from bringing back notes the user has cleared |
| **Icon** | `<machine>/Icon.png` (existing files keep working). `hasCustomIcon` is **derived** from file existence; no stored flag. New custom icons are converted to real PNG data on save |
| **Screenshot (Phase 3)** | `<machine>/Screenshot.png` — exactly one |
| **Status** | Runtime only: `.stopped`, `.running`, `.paused`, `.configuring` |

**Discovery rule:** a machine is any **immediate** subfolder of `machinesPath` that contains a regular file named `86box.cfg` **or** `.swift86.json`. Hidden folders and symlinked folders are skipped. (`.swift86.json` covers machines created in Swift86 but not yet configured in 86Box. Revised 2026-10-16.) One level deep, not recursive (see §8 D3). This matches CLAUDE.md's wording and today's launch model (`-P <machinesPath>/<folder>`).

**New machine:** create the folder and write `.swift86.json`. **Never write a stub `86box.cfg`.** In 86Box's `config_load()`, a *missing* cfg takes the new-machine defaults path (`config == NULL`), while an empty or stub cfg takes the normal parse path. Leaving the cfg to 86Box keeps first-start behaviour identical to today.

### 4.0 SUPERSEDED (2026-10-16): metadata moves to 86Box's `vmm.ini`. See §4.2. The sidecar and `Icon.png` rows above are historical.

### 4.2 `vmm.ini` as the metadata store (T3b, owner decision 2026-10-16)

Verified against 86Box master source and the owner's real file:
- **Location:** `~/Library/Preferences/86Box/vmm.ini`. This is Qt `AppConfigLocation` for app name "86Box", and its `plat_get_global_config_dir()` → `vmm.ini`. Stored as `AppConfig.vmmIniPath` with that default; no UI.
- **Format:** Qt `QSettings::IniFormat`, UTF-8.
  - `[General]` comes first (manager prefs: never touched by Swift86).
  - Then one section per VM, named by its **UUIDv5**: `QUuid::createUuidV5(QUuid{}, canonicalDirPath + "/")`, i.e. SHA-1 with the nil namespace, lowercase, no braces. Verified: `…/86Box/Windows Me/` → `0fec96c9-8090-50c5-8cc6-0860eda29f5d`. `canonicalPath` resolves symlinks.
  - Keys in each section: `config_dir`, `config_file`, `system_name` (= folder name), `display_name` (only when ≠ folder name), `notes`, `icon` (absolute image path or an 86Box built-in icon name), `timestamp` (ISO-8601 UTC, last started).
  - Keys are sorted alphabetically within a section (QMap order).
  - Values use Qt escaping: `\n`, `\t`, `\r`, `\\`, `\"`, control chars as `\xNN`. Non-ASCII is raw UTF-8. A value is wrapped in `"…"` if it contains `,` `;` `=` or has a leading or trailing space. The reader must also accept quoted values and `\x` escapes, and treat a leading `@@` as a literal `@`.
- **Ownership:** Swift86 only edits its machines' sections and only these keys. Every other section, key and the `[General]` group are preserved **byte-for-byte**, including unknown keys and their order. Writes are atomic: temp file in the same directory, then rename, the same as Qt's QSaveFile. The Qt lock protocol must be honoured: create `vmm.ini.lock` with `O_EXCL` containing `"<pid>\n<appname>\n<hostname>\n"`; retry for up to 2 s; treat the lock as stale if that pid is dead; remove it after writing.

| Field | Source after T3b |
|---|---|
| Display name | `display_name` if present, else the folder name |
| Notes | `notes` |
| Icon | `icon`: if it is a loadable image file path, show it; otherwise (missing file, or an 86Box built-in icon name) show the default SF Symbol. **A custom icon is always `<machine folder>/Icon.png`** (owner, 2026-10-16), and `icon` stores its canonical path.
- **Picking an image:** it is converted to PNG. The largest representation is used, capped at 1024 px.
- **Writing it:** the PNG is staged in a temp file, then `vmm.ini` is written, then the temp file atomically replaces `Icon.png`. A failure before the swap leaves the old `Icon.png` untouched.
- **"Default icon":** removes the key and deletes `Icon.png`, unless another section references it.
- **Cleanup:** after any icon change, leftover `Icon <n>.*` / `Icon.<non-png>` copies from earlier test builds are deleted, unless they are referenced elsewhere.
- **Existing icons outside the folder** are left as they are until the user picks a new one.
- **Rename and clone** relocate an `icon` path that lies inside the source folder. |
| Discovery | Folder has `86box.cfg` **or** a `vmm.ini` section whose `config_dir` equals the folder (canonical). The second case covers machines created in Swift86 but not yet configured. |
| Rename (owner choice) | Move the folder (T4 code), then **move the section** to the new UUID: copy all keys, then update `config_dir`, `config_file` and `system_name`, remove `display_name`, then delete the old section. All in one atomic `vmm.ini` write, done after the folder move succeeds. |
| Create | Folder plus a section with `config_dir`, `config_file`, `system_name`, and `notes`/`icon` if set. Never a `86box.cfg`. |
| Start | Set `timestamp` (86Box manager parity). |
| Delete (T6) | Also removes the section. |

**Registration:** `load()` silently adds a minimal section (`config_dir`, `config_file`, `system_name`) for any discovered machine that has none, the same as the 86Box manager does on scan.

**Scan for Machines:** a File-menu command that rescans and registers, then lists **stale** sections (`config_dir` directly inside `machinesPath`, folder missing, and only when `machinesPath` itself is reachable). It asks for confirmation before removing them.

**Migration:**
- A machine without `vmm.ini` notes but with legacy plist notes or `.swift86.json` notes gets them copied into `vmm.ini`.
- A machine without a `vmm.ini` `icon` but with `Icon.png` gets `icon = <path to Icon.png>`.
- After a successful `vmm.ini` write, Swift86 deletes **its own** `.swift86.json` files.
- Plists stay read-only.

`machineOrder` stays in `Settings.json`, because `vmm.ini` has no order.

**CLAUDE.md conflicts the owner chose to accept:** "Keep existing PNG machine icons" (icons now come from `vmm.ini`), and the folder-local sidecar is gone. CLAUDE.md itself should be updated by the owner.

### 4.1 Per-machine legacy import (lazy, inside the scanner)
For each **immediate** subfolder that contains `86box.plist`:
- If `.swift86.json` is missing, write it with the plist's `Information.Notes`, or `""` if there are none. This also makes never-configured legacy machines (no `86box.cfg`) discoverable.
- Legacy `MachinesList` (UUIDs in UserDefaults) → `machineOrder`: done once, while `machineOrder` is empty. UUIDs map to folder names through each plist's `Information.Id`; stale UUIDs are dropped.
- `Icon.png` needs no action. If the plist said `IconCustom=false` but `Icon.png` exists, leave the file; it will now show (accepted edge case — the old `save()` deleted `Icon.png` whenever custom was off, so this is rare).
- **Never modify or delete `86box.plist`** (see §8 D2). The importer lives in a single file, `Models/LegacyImport.swift`, and is the **only** code that reads plists. Nothing writes them.

---

## 5. Process control & IPC design (Phase 2 foundation)

`ManagerSocket` (new, `Models/ManagerSocket.swift`), one per launched VM:
- BSD `AF_UNIX` / `SOCK_STREAM` listener plus `DispatchSourceRead`. No third-party dependencies.
- Path: `FileManager.default.temporaryDirectory/s86-<8 hex>.sock`. Assert `path.utf8.count < 104` (`sun_path` limit); fall back to `/tmp/s86-<8 hex>.sock`. `unlink` before `bind` and on teardown.
- Launch: `process.environment = ProcessInfo.processInfo.environment + ["86BOX_MANAGER_SOCKET": path]`.
- Accept a single client. `send(_ cmd: ManagerCommand)` writes `"<cmd>\n"` as **one** write. If no client is connected yet, queue at most the latest command (or simply disable menu items until connected → `isConnected` published).
- Read `"1"` / `"0"` bytes → publish `isBlockedByModal` (optional; may be ignored).
- Teardown on process termination.

Command mapping:

| Menu | Action | Enabled when |
|---|---|---|
| Start | launch (as today) | `.stopped` |
| Stop | `shutdown` | `.running` / `.paused`, socket connected |
| Pause / Resume | `pause`, flip local `.running` ↔ `.paused` | `.running` / `.paused`, connected |
| Hard Reset | `reset` | `.running` / `.paused`, connected |
| Force Shutdown | `shutdownnoprompt` | `.running` / `.paused`, connected |
| Ctrl + Alt + Del | `cad` | `.running`, connected |
| Kill | confirmation → `kill(pid, SIGKILL)` | process exists (any non-stopped state) |

Known limitation: the legacy protocol does not report pause state. If the user pauses from inside 86Box's own menu, Swift86's Pause/Resume label can be out of sync. Acceptable for this pass; the v5 JSON protocol (out of scope) fixes it later.

---

## 6. Context menu — final behaviour spec

Order and dividers exactly as in CLAUDE.md. Additional rules:

- **Confirmation sheets** (Kill, Wipe NVRAM, Remove…): replace the stringly `alertTitle` / `alertOK` closure pattern with a typed `enum PendingConfirmation: Identifiable { case kill(Machine), wipeNVRAM(Machine), remove(Machine) }`. Present it with `.alert(item:)`, which shows as a window-modal sheet on macOS, with a `.destructive` button. Keep the existing alert for plain errors.
- **Clone…**: opens a small sheet with a Name field pre-filled with a unique `"<name> copy"` / `"<name> copy 2"`, plus Cancel / Clone buttons. Validate the name (§6.1). Copy the folder to a temporary sibling `.<name>.cloning` first, then `moveItem` to the final name, so a failed copy never shows up as a machine. Inside the cloned `86box.cfg`, rewrite any absolute path that starts with the source machine folder to point at the clone folder, so the clone never shares disk images with the original. Exclude `screenshots/` and `printer/` from the copy. Only allowed when `.stopped`.
- **Remove "Name"…**: confirmation → **permanent delete** (`FileManager.removeItem`), keeping today's "You cannot undo this action." text (§8 D2b). Hard guards, all required: machine `.stopped`; resolved folder URL's parent == resolved `machinesPath`; folder contains `86box.cfg`; folder ≠ `machinesPath`. Remove from `machineOrder`.
- **Wipe NVRAM**: confirmation → delete the *contents* of `<machine>/nvr/` (or remove and recreate the folder). Only when `.stopped`. No-op without error if the folder is absent.
- **Open Printer Tray**: `<machine>/printer/`; create it with intermediates if missing; `NSWorkspace.shared.open(url)`.
- **Show in Finder**: `NSWorkspace.shared.activateFileViewerSelecting([url])`.
- **Edit…**: unchanged sheet. Rename disabled while not `.stopped`.
- **Configure…**: kept directly under Edit… (§8 D4), same behaviour as today. If the VM is already running, send `showsettings` instead of launching a second process.

### 6.0 Implementation notes from the T6 review (2026-10-16)
- **Remove guard:** a folder counts as a machine if it has `86box.cfg` **or** a matching `vmm.ini` section. The second case is needed because Swift86 never writes a cfg, so a never-configured machine must still be removable.
- **Remove:** runs `removeItem` synchronously. A partial failure (e.g. a locked file) can leave a half-deleted folder; the error is shown and the state stays consistent with disk. Possible hardening: rename to a hidden sibling, then delete off the main thread.
- **Clone:** copies symlinks inside the machine folder as they are, the same as Finder's Duplicate. A symlink pointing into the source's disks would be shared. 86Box itself never creates such links.
- **Kill / Wipe NVRAM confirmation buttons:** "Yes" is a plain button, matching 86Box Manager. "No" is the default.

### 6.1 Name validation (create / edit / clone)
Trim whitespace; non-empty; no `/` or `:`; must not start with `.`; ≤ 255 UTF-8 bytes; no existing folder with the same name **case-insensitively** (APFS default is case-insensitive). Show errors inline in the sheet. The sheet stays open on failure.

### 6.2 Strings & localization
CLAUDE.md forbids localization work. Existing translated keys are `"Edit..."`, `"Clone..."`, `"Remove \"%@\"..."` (three ASCII dots). Changing them to `…` changes the lookup key, so **every existing translation of these items silently falls back to English**. Recommendation: keep the existing keys byte-for-byte; new items are English-only (see §8 D5).

---

## 7. Task breakdown for sub-agents

Rules for every task:
- Implementer: `porter` agent, `model: sonnet`. Reviewer: `reviewer` agent, `model: sonnet`. For T5 and T6 (destructive file operations, sockets), the reviewer runs on `opus`.
- Project uses an explicit file list (`objectVersion = 56`, not folder-synced). **New `.swift` files must be added to `Swift86.xcodeproj/project.pbxproj`** (PBXFileReference, PBXBuildFile, group, Sources phase).
- Every task must end with a clean build: `xcodebuild -project Swift86.xcodeproj -scheme Swift86 -configuration Debug build` (no new warnings in touched files).
- Match existing style: `// MARK: -` sections and a short comment above each block.
- Don't touch `*.lproj`, `Localizations/` or `xcuserdata`.

| # | Task | Files that may be touched | Success criteria |
|---|---|---|---|
| **T1** | `SettingsStore` + `Settings.json` schema (§3) + one-shot UserDefaults import (§3.1, without the MachinesList→folder mapping, which is T3's job via a hook) | new `Models/SettingsStore.swift`; `Models/AppSettings.swift`; `AppDelegate.swift`; `Swift86App.swift`; `project.pbxproj` | Fresh launch creates the dir + file with defaults; an existing install produces a file with the user's old values; the file round-trips; corrupt JSON → defaults + no crash + file not overwritten until the next user change; appearance applied at launch from the store |
| **T2** | Move all settings UI to `SettingsStore`; delete every `@AppStorage` / `UserDefaults` usage outside the importer | `Views/GeneralSettingsView.swift`, `AppearanceSettingsView.swift`, `SettingsView.swift`, `SidebarView.swift`, `Models/AppSettings.swift` (`browsePath` returns a URL via completion instead of writing defaults) | `grep -rn "UserDefaults\|AppStorage" Swift86/` matches only the importer; Settings UI looks identical; changing the Machines path reloads the sidebar |
| **T3** | Folder scanner + sidecar + derived icon + transient-UUID reuse + order by `machineOrder` + lazy legacy import (§4, §4.1) + finish the MachinesList mapping | `Models/Library.swift`, `Models/Machine.swift`, new `Models/MachineMetadata.swift`, new `Models/LegacyImport.swift`, `project.pbxproj` | Machines are found with zero plist files; legacy notes appear; never-configured legacy machines still appear; order preserved from old installs; no force unwraps; plist read only in `LegacyImport.swift`; nothing writes a plist |
| **T4** | Rewrite create / edit (rename via `moveItem`) / icon save (PNG convert) / notes save on the new model; name validation (§6.1); sheet stays open on error | `Models/Library.swift`, `Views/EditMachineView.swift`, `Views/MachineView.swift` (async size calculation) | Create → folder + `.swift86.json` (never a stub `86box.cfg`, see §4); rename keeps disks and order; no copy+delete; size no longer computed in `body` |
| **T5** | `ManagerSocket` + launch env var + `.paused` status + command API on `Library` (§5) | new `Models/ManagerSocket.swift`, `Models/Library.swift`, `Models/Machine.swift`, `project.pbxproj` | Manual test against real 86Box: pause/resume, reset, CAD, shutdown, force shutdown and SIGKILL all work; socket file removed on exit; no fd leaks after 10 start/stop cycles |
| **T6** | Context menu (§6) + typed confirmations + Clone sheet + Remove/Wipe/Printer/Finder | `Views/SidebarView.swift`, `Views/ContentView.swift`, new `Views/CloneMachineView.swift`, `Models/Library.swift`, `Views/MachineView.swift` (trash button → same confirmation), `project.pbxproj` | Menu order is byte-exact vs CLAUDE.md; enablement follows the §5 table; every guard in §6 has been exercised manually; Remove deletes permanently only after confirmation and only when every guard passes |
| T7+ | Phase 3 (screenshot) and Phase 4 (macOS 27 polish + classic-styling option, §7.1) | planned after Phase 2 lands | — |

Order: T1 → T2 → T3 → T4 (Phase 1), then T5 → T6 (Phase 2). T1–T2 and T3 touch disjoint files except `pbxproj` and `AppSettings.swift`, so they **may not run in parallel**.

### 7.0 Native SwiftUI policy (owner, 2026-10-16)

The UI layer must be 100% SwiftUI.
- **Not allowed** in new or touched code: AppKit views or panels (`NSViewRepresentable`, `NSOpenPanel`/`NSSavePanel` → `.fileImporter`), `NSWindow` notifications for view lifecycle, and AppKit subclass/extension hacks (e.g. the `NSTextView.frame` override).
- **Allowed** where SwiftUI has no equivalent: AppKit *services* — `NSWorkspace` (open, reveal, file icons), `NSApp.appearance`, `NSImage` for loading/converting image data, `Process`, and BSD sockets.

Existing violations and the task that removes each:
- `Helpers/PathControl.swift` (NSPathControl): **T2**
- `AppSettings.browsePath` (NSOpenPanel) and the Settings-window close notification: **T2**
- `Library.iconPicker` (NSOpenPanel) and the `NSTextView` extension in `EditMachineView`: **T4**
- `Color(NSColor…)` usages in styles and views: **Phase 4**

Builds are verified locally from the terminal with `xcodebuild`.

### 7.1 Phase 4 scope note — "Classic styling" option (approved 2026-10-16)

The owner wants a user choice between the current Sequoia-style look and the new Liquid Glass look. Constraint: in the macOS 27 SDK the system ignores `UIDesignRequiresCompatibility` (per Apple forum reports; **verify against the Xcode 27 release notes at the start of Phase 4**). So **system chrome** (toolbar, sidebar container, standard controls, menus, sheets, alerts) is Liquid Glass on macOS 26+ regardless of the setting. The option covers **only Swift86-drawn surfaces**.

- **Setting:** `interfaceStyle: String` in `Settings.json`, `"glass"` (default) | `"classic"`. Added in Phase 4. Tolerant decoding (§3) means no migration is needed. UI: Settings → Appearance → checkbox **"Use classic styling for machine views"** (English only). Don't call it "Sequoia mode", because it can't change system chrome.
- **Surfaces that switch:** `MachineButtonStyle` (machine header buttons), `WelcomeButtonStyle` (welcome tiles), the machine header/details background, sidebar row styling, the screenshot frame (Phase 3), and any other custom style added in Phase 4.
- **Implementation pattern:** one `EnvironmentValues.interfaceStyle` key injected at the root from `SettingsStore`. Each custom style reads it and returns either the existing (classic) rendering, kept **unchanged from today's code**, or the glass rendering (`.glassEffect` and friends, behind `if #available(macOS 26, *)`). No per-view `if` chains outside the style types.
- **On macOS 13–25** (if the deployment target stays below 26), the option is hidden and the classic path is always used.
- **Success criteria:** toggling switches all listed surfaces live, without relaunch; classic mode renders pixel-identically to the pre-Phase-4 build on the same OS (compare screenshots); glass mode reads as native macOS 27; both pass a dark/light appearance check.

---

## 8. Open decisions (owner)

- **D1 – Deployment target.** *(Deferred to Phase 4.)* Currently macOS **13.0**, Swift 5.0. "macOS 27 conventions" (Liquid Glass materials, new toolbar and sidebar APIs, `@Observable`) need a minimum of **macOS 26**. Raising it drops users on 13–15. *Recommendation: raise to 26 in Phase 4, not before.*
- **D2 – Old `86box.plist` files.** **Decided: leave untouched.**
- **D2b – Remove… semantics.** **Decided: delete permanently** (as today), with the §6 guards.
- **D3 – Scan depth.** **Decided: immediate subfolders only.**
- **D4 – "Configure…" in the context menu.** It exists today but is **missing from the CLAUDE.md final menu**. Removing it from the menu is a user-visible change, although it stays reachable via the gear button in the machine view. **Decided: keep it, directly under Edit…** (deliberate deviation from the CLAUDE.md menu).
- **D5 – Ellipsis characters** (§6.2). **Default: keep the existing `...` keys** to preserve translations.
