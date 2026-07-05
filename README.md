# Virtual Desktop Switcher

Fast Windows virtual desktop switching with hotkeys, a clean on-screen overlay, and window moving. One portable `.exe` — download, run, done.

![AutoHotkey v2](https://img.shields.io/badge/AutoHotkey-v2-green) ![Windows 10/11](https://img.shields.io/badge/Windows-10%2F11-blue) ![License MIT](https://img.shields.io/badge/License-MIT-lightgrey)

## Features

- **`Alt+1…9`** — switch to desktop 1–9 instantly (no animation lag)
- **`Ctrl+Alt+1…9`** — move the active window to desktop N (stay where you are)
- **`Ctrl+Alt+<current desktop>`** — recall the window you last moved away, back to the current desktop
- **`Shift+Alt+1…9`** — move the active window to desktop N **and follow it**
- Centered overlay showing the desktop number and position dots, with smooth fade-out, on the monitor you're working on
- Remembers the last active window on each desktop and restores focus to it
- Tray menu: settings, pause hotkeys, autostart toggle, uninstall
- **Rebind hotkeys from the settings window** — press the combo you want, it applies to all 9 digits
- Installs itself to `%LocalAppData%\VirtualDesktopSwitcher` on first run and adds itself to autostart; full uninstall from the tray menu

## Install

1. Download `VirtualDesktopSwitcher.exe` from [Releases](../../releases).
2. Run it. That's it — it installs itself and starts.

No AutoHotkey installation required — everything is bundled.

> **Windows SmartScreen note:** the `.exe` is not code-signed (signing costs money), so on first run Windows may show *"Windows protected your PC"*. Click **More info → Run anyway**. This is expected for unsigned open-source tools — you can read all the source here and build it yourself if you prefer.

## Uninstall

Tray icon → **Удалить программу** (Uninstall), or Start Menu → Virtual Desktop Switcher → Удалить.

## Build from source

Requirements: [AutoHotkey v2](https://www.autohotkey.com/) installed, PowerShell.

```powershell
# Compile dist\VirtualDesktopSwitcher.exe
.\build.ps1

# Also download the latest VirtualDesktopAccessor.dll before compiling
.\build.ps1 -UpdateDll
```

Or just run `VirtualDesktop.ahk` directly with AutoHotkey v2 (keep `VirtualDesktopAccessor.dll` next to it).

## Credits

- [VirtualDesktopAccessor](https://github.com/Ciantic/VirtualDesktopAccessor) by Jari Pennanen (MIT License) — the DLL that exposes Windows' undocumented virtual desktop API. Bundled inside the exe.
- Built with [AutoHotkey v2](https://www.autohotkey.com/).

## License

MIT — see [LICENSE](LICENSE).

---

# Virtual Desktop Switcher (по-русски)

Быстрое переключение виртуальных рабочих столов Windows по горячим клавишам, с оверлеем и переносом окон. Один портативный `.exe` — скачал, запустил, готово.

## Возможности

- **`Alt+1…9`** — мгновенно переключиться на стол 1–9
- **`Ctrl+Alt+1…9`** — перенести активное окно на стол N (сам остаёшься на месте)
- **`Ctrl+Alt+<номер текущего стола>`** — вернуть последнее перенесённое окно обратно на текущий стол
- **`Shift+Alt+1…9`** — перенести активное окно на стол N **и перейти вместе с ним**
- Оверлей с номером стола и точками-индикаторами, с плавным затуханием, на том мониторе, где ты работаешь
- Запоминает последнее активное окно на каждом столе и возвращает ему фокус
- Меню в трее: настройки, пауза хоткеев, автозапуск, удаление
- **Переназначение клавиш прямо из окна настроек** — нажми нужное сочетание, оно применится ко всем 9 цифрам
- При первом запуске устанавливается в `%LocalAppData%\VirtualDesktopSwitcher` и добавляется в автозагрузку; полное удаление — из меню в трее

## Установка

1. Скачай `VirtualDesktopSwitcher.exe` из [Releases](../../releases).
2. Запусти. Всё — программа установится и запустится сама.

Устанавливать AutoHotkey не нужно — всё внутри.

> **Про SmartScreen:** `.exe` не подписан цифровой подписью (это платно), поэтому при первом запуске Windows может показать *«Система Windows защитила ваш компьютер»*. Нажми **Подробнее → Выполнить в любом случае**. Для неподписанных open-source утилит это нормально — весь исходный код открыт, можешь собрать сам.

## Удаление

Иконка в трее → **Удалить программу**, или Пуск → Virtual Desktop Switcher → Удалить.
