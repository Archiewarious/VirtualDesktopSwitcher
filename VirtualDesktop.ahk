#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================================
; Virtual Desktop Switcher v0.1.0-beta
; Переключение виртуальных рабочих столов Windows по горячим клавишам,
; с оверлеем и переносом окон. Настройка клавиш — из меню в трее.
;
; Хоткеи по умолчанию:
;   Alt+1..9        — перейти на стол 1..9
;   Ctrl+Alt+1..9   — перенести активное окно на стол 1..9 (без перехода)
;   Ctrl+Alt+<тек.> — вернуть последнее перенесённое окно на текущий стол
;   Shift+Alt+1..9  — перенести окно на стол 1..9 и перейти вместе с ним
;
; Использует VirtualDesktopAccessor.dll (MIT License, (c) Jari Pennanen):
; https://github.com/Ciantic/VirtualDesktopAccessor
; ============================================================================

VERSION := "0.1.0-beta"

; ---- Константы оверлея/таймингов ----
OVERLAY_ALPHA       := 230    ; стартовая непрозрачность оверлея
OVERLAY_SHOW_MS     := 850    ; сколько держать оверлей до затухания
FADE_INTERVAL_MS    := 33     ; шаг анимации затухания (~30 к/с)
FADE_ALPHA_STEP     := 30     ; насколько гасим за шаг
OVERLAY_W           := 220
OVERLAY_H           := 150
FOCUS_POLL_MS       := 50     ; интервал опроса «переключился ли стол»
FOCUS_POLL_ATTEMPTS := 10     ; макс. попыток (×50 мс = 500 мс)

localAppData := EnvGet("LOCALAPPDATA")
installDir := localAppData "\VirtualDesktopSwitcher"
installExe := installDir "\VirtualDesktopSwitcher.exe"
installDll := installDir "\VirtualDesktopAccessor.dll"
startupLnk := A_Startup "\VirtualDesktopSwitcher.lnk"
menuDir    := A_AppData "\Microsoft\Windows\Start Menu\Programs\Virtual Desktop Switcher"

; ---- Удаление: VirtualDesktopSwitcher.exe /uninstall ----
if (A_Args.Length && A_Args[1] = "/uninstall") {
    try FileDelete(startupLnk)
    try DirDelete(menuDir, true)
    MsgBox("Virtual Desktop Switcher удалён.", "Удаление", "Iconi")
    ; Работающий exe нельзя удалить изнутри — доудаляем через cmd после выхода
    ; (две попытки с паузой на случай, если файл ещё занят антивирусом/системой)
    if A_IsCompiled
        Run(A_ComSpec ' /c timeout /t 1 >nul & del /f /q "' installExe '" 2>nul'
            . ' & timeout /t 1 >nul & del /f /q "' installExe '" 2>nul'
            . ' & rd /s /q "' installDir '"', , "Hide")
    ExitApp()
}

; ---- Первый запуск скомпилированного exe: установка в LocalAppData ----
if (A_IsCompiled && A_ScriptFullPath != installExe) {
    try {
        DirCreate(installDir)
        FileInstall("VirtualDesktopAccessor.dll", installDll, true)
        FileCopy(A_ScriptFullPath, installExe, true)
    } catch as e {
        MsgBox("Не удалось установить программу:`n" e.Message, "Virtual Desktop Switcher", "Iconx")
        ExitApp()
    }
    try FileCreateShortcut(installExe, startupLnk, installDir, , "Virtual Desktop Switcher")
    try {
        DirCreate(menuDir)
        FileCreateShortcut(installExe, menuDir "\Virtual Desktop Switcher.lnk", installDir, , "Virtual Desktop Switcher")
        FileCreateShortcut(installExe, menuDir "\Удалить.lnk", installDir, "/uninstall", "Удалить Virtual Desktop Switcher")
    }
    Run('"' installExe '"')
    ExitApp()
}

; ---- Загрузка DLL ----
dllPath := A_IsCompiled ? installDll : A_ScriptDir "\VirtualDesktopAccessor.dll"
hModule := DllCall("LoadLibrary", "Str", dllPath, "Ptr")
if !hModule {
    MsgBox("Не удалось загрузить VirtualDesktopAccessor.dll.`nПереустановите программу (скачайте exe заново).", "Virtual Desktop Switcher", "Iconx")
    ExitApp()
}

GoToDesktopNumber         := DllCall("GetProcAddress", "Ptr", hModule, "AStr", "GoToDesktopNumber", "Ptr")
GetCurrentDesktopNumber   := DllCall("GetProcAddress", "Ptr", hModule, "AStr", "GetCurrentDesktopNumber", "Ptr")
GetDesktopCount           := DllCall("GetProcAddress", "Ptr", hModule, "AStr", "GetDesktopCount", "Ptr")
MoveWindowToDesktopNumber := DllCall("GetProcAddress", "Ptr", hModule, "AStr", "MoveWindowToDesktopNumber", "Ptr")
GetWindowDesktopNumber    := DllCall("GetProcAddress", "Ptr", hModule, "AStr", "GetWindowDesktopNumber", "Ptr")

lastActiveHwnd := Map()   ; стол -> hwnd последнего активного окна (для возврата фокуса)
gLastMoved     := 0       ; последнее окно, перенесённое без перехода (для «вернуть»)
gSwitchGen     := 0       ; поколение переключений (отменяет устаревшие таймеры фокуса)

; ---- Настройки ----
settingsPath := A_IsCompiled ? installDir "\settings.ini" : A_ScriptDir "\settings.ini"
cfg := {switchMods: "!", moveMods: "^!", followMods: "+!", overlay: 1}
LoadSettings()

; Канонизация строки модификаторов: убирает порядок/дубли (^! и !^ -> !^ и т.п.)
NormMods(s) {
    out := ""
    for c in ["+", "^", "!", "#"]
        if InStr(s, c)
            out .= c
    return out
}

LoadSettings() {
    global cfg, settingsPath
    sw := NormMods(IniRead(settingsPath, "Hotkeys", "SwitchMods", "!"))
    mv := NormMods(IniRead(settingsPath, "Hotkeys", "MoveMods", "^!"))
    fl := NormMods(IniRead(settingsPath, "Hotkeys", "FollowMods", "+!"))
    ; пустые или пересекающиеся сочетания -> вернуть значения по умолчанию
    if (sw = "" || mv = "" || fl = "" || sw = mv || sw = fl || mv = fl)
        sw := "!", mv := "^!", fl := "+!"
    cfg.switchMods := sw, cfg.moveMods := mv, cfg.followMods := fl
    raw := IniRead(settingsPath, "Overlay", "Enabled", "1")
    try cfg.overlay := Integer(raw)
    catch
        cfg.overlay := 1
}

SaveSettings() {
    global cfg, settingsPath
    IniWrite(cfg.switchMods, settingsPath, "Hotkeys", "SwitchMods")
    IniWrite(cfg.moveMods, settingsPath, "Hotkeys", "MoveMods")
    IniWrite(cfg.followMods, settingsPath, "Hotkeys", "FollowMods")
    IniWrite(cfg.overlay, settingsPath, "Overlay", "Enabled")
}

; ---- Оверлей ──────────────────────────────────────────────────────────────
overlay := Gui("+AlwaysOnTop -Caption +ToolWindow")
overlay.BackColor := "1E1E2E"
overlay.MarginX := 0
overlay.MarginY := 0
overlay.SetFont("s68 cFFFFFF Bold", "Segoe UI")
overlayNum  := overlay.Add("Text", "xm ym w220 h120 Center +0x200", "")
overlay.SetFont("s12 cAAAAAA", "Segoe UI")
overlayDots := overlay.Add("Text", "xm w220 h24 Center +0x200", "")
try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", overlay.Hwnd, "UInt", 33, "Int*", 2, "UInt", 4)

overlayFadeStep := 0

; Рабочая область монитора под курсором (стабильно при асинхронном переключении столов)
GetActiveMonitorWorkArea(&L, &T, &R, &B) {
    pt := Buffer(8, 0)
    if DllCall("GetCursorPos", "Ptr", pt) {
        cx := NumGet(pt, 0, "Int"), cy := NumGet(pt, 4, "Int")
        loop MonitorGetCount() {
            MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
            if (cx >= l && cx < r && cy >= t && cy < b) {
                L := l, T := t, R := r, B := b
                return
            }
        }
    }
    MonitorGetWorkArea(, &L, &T, &R, &B)
}

ShowOverlay(n) {
    global overlay, overlayNum, overlayDots, overlayFadeStep, cfg
    global OVERLAY_ALPHA, OVERLAY_SHOW_MS, OVERLAY_W, OVERLAY_H
    if !cfg.overlay
        return
    SetTimer(FadeStep, 0)
    overlayNum.Value := n + 1
    dots := ""
    loop 9
        dots .= (A_Index - 1 == n) ? "● " : "○ "
    overlayDots.Value := Trim(dots)
    GetActiveMonitorWorkArea(&L, &T, &R, &B)
    overlay.Show("x" (L + (R-L)//2 - OVERLAY_W//2) " y" (T + (B-T)//2 - OVERLAY_H//2)
        . " w" OVERLAY_W " h" OVERLAY_H " NoActivate")
    WinSetTransparent(OVERLAY_ALPHA, overlay)
    overlayFadeStep := 0
    SetTimer(FadeStep, -OVERLAY_SHOW_MS)
}

FadeStep() {
    global overlay, overlayFadeStep, OVERLAY_ALPHA, FADE_INTERVAL_MS, FADE_ALPHA_STEP
    overlayFadeStep++
    alpha := Max(0, OVERLAY_ALPHA - overlayFadeStep * FADE_ALPHA_STEP)
    if (alpha <= 0) {
        SetTimer(FadeStep, 0)
        overlay.Hide()
        overlayFadeStep := 0
        return
    }
    WinSetTransparent(alpha, overlay)
    SetTimer(FadeStep, FADE_INTERVAL_MS)
}
; ────────────────────────────────────────────────────────────────────────────

DesktopCount() {
    global GetDesktopCount
    return DllCall(GetDesktopCount, "Int")
}

SwitchToDesktop(n) {
    global GoToDesktopNumber, GetCurrentDesktopNumber, lastActiveHwnd, gSwitchGen, FOCUS_POLL_MS, FOCUS_POLL_ATTEMPTS
    currentDesk := DllCall(GetCurrentDesktopNumber, "Int")
    if (currentDesk == n || n >= DesktopCount())
        return
    try {
        hwnd := WinGetID("A")
        if hwnd
            lastActiveHwnd[currentDesk] := hwnd
    }
    myGen := ++gSwitchGen
    DllCall(GoToDesktopNumber, "Int", n, "Int")
    ShowOverlay(n)
    if lastActiveHwnd.Has(n) {
        targetHwnd := lastActiveHwnd[n]
        SetTimer(() => WaitAndFocus(targetHwnd, n, FOCUS_POLL_ATTEMPTS, myGen), -FOCUS_POLL_MS)
    }
}

; Опрашивает DLL, пока стол реально не переключится, затем возвращает фокус.
; gen отменяет устаревшую цепочку, если следом произошло новое переключение.
WaitAndFocus(hwnd, n, attempts, gen) {
    global GetCurrentDesktopNumber, GetWindowDesktopNumber, gSwitchGen, lastActiveHwnd, FOCUS_POLL_MS
    if (gen != gSwitchGen)
        return
    if (DllCall(GetCurrentDesktopNumber, "Int") != n) {
        if (attempts > 0)
            SetTimer(() => WaitAndFocus(hwnd, n, attempts - 1, gen), -FOCUS_POLL_MS)
        return
    }
    ; окно закрылось — забываем его и выходим
    if !WinExist("ahk_id " hwnd) {
        if (lastActiveHwnd.Has(n) && lastActiveHwnd[n] = hwnd)
            lastActiveHwnd.Delete(n)
        return
    }
    ; окно уехало на другой стол — не тянуть его фокусом обратно
    if (DllCall(GetWindowDesktopNumber, "Ptr", hwnd, "Int") != n)
        return
    RestoreFocus(hwnd)
}

RestoreFocus(hwnd) {
    try {
        if !WinExist("ahk_id " hwnd)
            return
        myTid  := DllCall("GetCurrentThreadId", "UInt")
        fgHwnd := DllCall("GetForegroundWindow", "Ptr")
        if fgHwnd {
            fgTid := DllCall("GetWindowThreadProcessId", "Ptr", fgHwnd, "Ptr", 0, "UInt")
            DllCall("AttachThreadInput", "UInt", myTid, "UInt", fgTid, "Int", 1)
            DllCall("SetForegroundWindow", "Ptr", hwnd)
            DllCall("BringWindowToTop", "Ptr", hwnd)
            DllCall("AttachThreadInput", "UInt", myTid, "UInt", fgTid, "Int", 0)
        } else {
            DllCall("SetForegroundWindow", "Ptr", hwnd)
        }
    }
}

MoveActiveWindowToDesktop(n) {
    global MoveWindowToDesktopNumber, GetCurrentDesktopNumber, GetWindowDesktopNumber
    global gLastMoved, gSwitchGen, FOCUS_POLL_MS, FOCUS_POLL_ATTEMPTS
    cur := DllCall(GetCurrentDesktopNumber, "Int")
    ; «Перенести на текущий стол» = вернуть последнее перенесённое окно сюда
    if (n == cur) {
        if (gLastMoved && WinExist("ahk_id " gLastMoved)) {
            DllCall(MoveWindowToDesktopNumber, "Ptr", gLastMoved, "Int", cur, "Int")
            hwnd := gLastMoved
            gLastMoved := 0
            myGen := ++gSwitchGen
            SetTimer(() => WaitAndFocus(hwnd, cur, FOCUS_POLL_ATTEMPTS, myGen), -FOCUS_POLL_MS)
        }
        return
    }
    if (n >= DesktopCount())
        return
    hwnd := WinGetID("A")               ; при фокусе на рабочем столе вернёт 0
    if !hwnd
        return
    ; окно не на текущем столе (незавершённое асинхронное переключение) — не трогаем
    if (DllCall(GetWindowDesktopNumber, "Ptr", hwnd, "Int") != cur)
        return
    DllCall(MoveWindowToDesktopNumber, "Ptr", hwnd, "Int", n, "Int")
    gLastMoved := hwnd
}

; Перенести активное окно на стол N и перейти туда вместе с ним
MoveAndFollowToDesktop(n) {
    global MoveWindowToDesktopNumber, GoToDesktopNumber, GetCurrentDesktopNumber, GetWindowDesktopNumber
    global lastActiveHwnd, gLastMoved, gSwitchGen, FOCUS_POLL_MS, FOCUS_POLL_ATTEMPTS
    cur := DllCall(GetCurrentDesktopNumber, "Int")
    if (n == cur || n >= DesktopCount())
        return
    hwnd := WinGetID("A")
    if !hwnd
        return
    if (DllCall(GetWindowDesktopNumber, "Ptr", hwnd, "Int") != cur)
        return
    DllCall(MoveWindowToDesktopNumber, "Ptr", hwnd, "Int", n, "Int")
    gLastMoved := hwnd
    lastActiveHwnd[n] := hwnd            ; чтобы возврат на n позже сфокусировал это окно
    myGen := ++gSwitchGen
    DllCall(GoToDesktopNumber, "Int", n, "Int")
    ShowOverlay(n)
    SetTimer(() => WaitAndFocus(hwnd, n, FOCUS_POLL_ATTEMPTS, myGen), -FOCUS_POLL_MS)
}

; ---- Динамическая регистрация горячих клавиш ----
gRegistered := []

HkSwitch(n, *) => SwitchToDesktop(n)
HkMove(n, *)   => MoveActiveWindowToDesktop(n)
HkFollow(n, *) => MoveAndFollowToDesktop(n)

RegisterHotkeys() {
    global cfg, gRegistered
    for hk in gRegistered
        try Hotkey(hk, "Off")
    gRegistered := []
    errors := ""
    ; массив пар (а не Map) — так ни одно действие не «схлопнется» при совпадении модификаторов
    actions := [[cfg.switchMods, HkSwitch], [cfg.moveMods, HkMove], [cfg.followMods, HkFollow]]
    loop 9 {
        n := A_Index
        for pair in actions {
            mods := pair[1], handler := pair[2]
            try {
                Hotkey(mods . n, handler.Bind(n - 1), "On")
                gRegistered.Push(mods . n)
            } catch as e {
                errors .= mods . n " — " e.Message "`n"
            }
        }
    }
    if errors
        TrayTip("Не удалось назначить:`n" errors, "Virtual Desktop Switcher", "Iconx")
}
RegisterHotkeys()

; ---- Окно настроек ----
ShowSettings(*) {
    global cfg
    static sg := 0
    if sg {
        try sg.Destroy()
        sg := 0
    }
    sg := Gui("+AlwaysOnTop", "Настройки — Virtual Desktop Switcher")
    sg.SetFont("s10", "Segoe UI")
    sg.Add("Text", "xm w340", "Нажмите в поле нужное сочетание с цифрой 1 — оно применится ко всем цифрам 1–9. (Клавиша Win не поддерживается.)")

    sg.Add("Text", "xm y+14 w170", "Переключиться на стол:")
    hkSwitch := sg.Add("Hotkey", "x+8 w160", cfg.switchMods "1")
    sg.Add("Text", "xm w170", "Перенести окно на стол:")
    hkMove := sg.Add("Hotkey", "x+8 w160", cfg.moveMods "1")
    sg.Add("Text", "xm w170", "Перенести и перейти:")
    hkFollow := sg.Add("Hotkey", "x+8 w160", cfg.followMods "1")

    cbOverlay := sg.Add("Checkbox", "xm y+14 Checked" (cfg.overlay ? 1 : 0), "Показывать оверлей с номером стола")

    btnSave := sg.Add("Button", "xm y+14 w120 Default", "Сохранить")
    btnCancel := sg.Add("Button", "x+8 w120", "Отмена")

    btnSave.OnEvent("Click", OnSave)
    btnCancel.OnEvent("Click", (*) => sg.Destroy())

    OnSave(*) {
        vals := Map("Переключиться", hkSwitch.Value, "Перенести окно", hkMove.Value, "Перенести и перейти", hkFollow.Value)
        mods := []
        for name, v in vals {
            if !RegExMatch(v, "^([!^+#]+)[1-9]$", &m) {
                MsgBox("«" name "»: нужно сочетание модификаторов (Alt/Ctrl/Shift) с цифрой 1.`nСейчас: " (v = "" ? "(пусто)" : v), "Настройки", "Iconx")
                return
            }
            mods.Push(NormMods(m[1]))
        }
        if (mods[1] = mods[2] || mods[1] = mods[3] || mods[2] = mods[3]) {
            MsgBox("Сочетания не должны совпадать между собой.", "Настройки", "Iconx")
            return
        }
        cfg.switchMods := mods[1], cfg.moveMods := mods[2], cfg.followMods := mods[3]
        cfg.overlay := cbOverlay.Value
        SaveSettings()
        RegisterHotkeys()
        sg.Destroy()
        TrayTip("Настройки сохранены и применены.", "Virtual Desktop Switcher", "Iconi")
    }

    sg.Show()
}

; ---- Меню в трее ----
A_IconTip := "Virtual Desktop Switcher v" VERSION
A_TrayMenu.Delete()
A_TrayMenu.Add("Настройки...", ShowSettings)
A_TrayMenu.Add("Приостановить хоткеи", TogglePause)
A_TrayMenu.Add("Запускать при входе в Windows", ToggleStartup)
A_TrayMenu.Add()
A_TrayMenu.Add("Перезапустить", (*) => Reload())
if A_IsCompiled
    A_TrayMenu.Add("Удалить программу", ConfirmUninstall)
A_TrayMenu.Add("Выход", (*) => ExitApp())
A_TrayMenu.Default := "Настройки..."
UpdateStartupCheck()

TogglePause(*) {
    Suspend(-1)
    if A_IsSuspended
        A_TrayMenu.Check("Приостановить хоткеи")
    else
        A_TrayMenu.Uncheck("Приостановить хоткеи")
}

ToggleStartup(*) {
    global startupLnk, installDir, installExe
    if FileExist(startupLnk) {
        FileDelete(startupLnk)
    } else {
        if A_IsCompiled
            FileCreateShortcut(installExe, startupLnk, installDir, , "Virtual Desktop Switcher")
        else
            FileCreateShortcut(A_AhkPath, startupLnk, A_ScriptDir, '"' A_ScriptFullPath '"', "Virtual Desktop Switcher")
    }
    UpdateStartupCheck()
}

UpdateStartupCheck() {
    global startupLnk
    if FileExist(startupLnk)
        A_TrayMenu.Check("Запускать при входе в Windows")
    else
        A_TrayMenu.Uncheck("Запускать при входе в Windows")
}

ConfirmUninstall(*) {
    global installExe
    if (MsgBox("Удалить Virtual Desktop Switcher с компьютера?", "Удаление", "YesNo Iconx Default2") = "Yes")
        Run('"' installExe '" /uninstall')
}
