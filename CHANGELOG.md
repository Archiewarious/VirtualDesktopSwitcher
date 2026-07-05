# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.1.0-beta] - 2026-07-05

First public beta release.

### Added
- Switch desktops with `Alt+1…9`, move the active window with `Ctrl+Alt+1…9`,
  move-and-follow with `Shift+Alt+1…9`.
- **Recall**: `Ctrl+Alt+<current desktop>` brings the last-moved window back to
  the current desktop.
- On-screen overlay with the desktop number and position dots, shown on the
  monitor under the cursor, with a smooth fade-out.
- Focus memory: restores focus to the last active window on each desktop.
- Tray menu: settings, pause hotkeys, autostart toggle, restart, uninstall.
- Settings window to rebind the modifier combos; stored in `settings.ini`.
- Self-installing / self-uninstalling portable `.exe` (bundles
  VirtualDesktopAccessor.dll); no AutoHotkey install required.
- `build.ps1` to compile the exe and optionally refresh the bundled DLL.

### Fixed
- Move-then-recall now works: the plain move remembers the window it moved, and
  a move to the current desktop recalls it (previously a window sent away could
  not be brought back).
- Hotkeys are registered from an ordered list, so no action is silently dropped
  when modifier combos collide.
- Malformed `settings.ini` no longer crashes startup; modifier strings are
  canonicalized and validated on load.
- Guards against acting on the wrong window during asynchronous desktop
  switches; stale focus timers are cancelled on rapid switching.
- Desktop-count guard: hotkeys for non-existent desktops no longer no-op while
  the overlay falsely reports success.

[0.1.0-beta]: https://github.com/Archiewarious/VirtualDesktopSwitcher/releases/tag/v0.1.0-beta
