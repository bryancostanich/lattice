# Lattice

Grid-based space navigation for macOS — a spiritual successor to TotalSpaces 3.

macOS treats Spaces as a 1D list. Lattice lays them out as a 2D grid and lets you navigate with `Ctrl+Opt+arrow`. Pop an overview with thumbnails, click to jump, or use the menu bar list. Apple Silicon, macOS 14+. SIP stays on. No Dock injection. No scripting addition.

## Features

- **2D grid navigation.** `Ctrl+Opt+←/→/↑/↓` switches spaces by grid direction. Per-display: the display under the mouse cursor is the one that moves.
- **Overview window.** `Ctrl+Opt+Space` shows a compact grid of thumbnails. Current space highlighted. Click any cell to jump. Auto-dismisses after 1s of idle.
- **Auto-appear on space change.** Switching by any means (Lattice's hotkey or Apple's `Ctrl+arrow`) pops the overview briefly so you always know where you are.
- **Menu bar item.** Shows current position as `[col,row]`. Click for a list of all spaces with checkmark on current — click an entry to jump.
- **Per-display grids.** Multiple monitors each get their own independent grid layout, sized to that display's space count by default.
- **Auto-fit defaults.** With 4 spaces you get 2×2, with 6 you get 3×2, with 9 you get 3×3 — `ceil(sqrt(N))` columns by default. Override per-display in config.
- **No animation needed.** Designed to feel right with `Reduce motion` enabled (instant snap between spaces).

## Hotkeys

| Chord | Action |
|---|---|
| `Ctrl+Opt+←` | Move one cell left |
| `Ctrl+Opt+→` | Move one cell right |
| `Ctrl+Opt+↑` | Move one cell up |
| `Ctrl+Opt+↓` | Move one cell down |
| `Ctrl+Opt+Space` | Toggle overview |
| `Esc` (when overview is open) | Dismiss overview |

## Requirements

- macOS 14 (Sonoma) or later. Apple Silicon recommended.

## Install

Download the latest release from [Releases](https://github.com/bryancostanich/lattice/releases), unzip, drag `Lattice.app` to `/Applications`, open it.

First launch shows the standard ad-hoc-signing warning — right-click → **Open** to bypass. Lattice appears in the menu bar; no Dock icon.

## Required macOS setup

Lattice will not work correctly until you change the following settings. The two marked **required** are non-negotiable; the rest are strongly recommended.

### 1. Disable "Automatically rearrange Spaces" — **required**

**System Settings → Desktop & Dock → Mission Control → Automatically rearrange Spaces based on most recent use → off**

macOS reorders your Spaces in the background every time you visit one when this is on. Lattice's grid mapping operates on the order of spaces — if the order shuffles, "the space to the right" stops meaning anything stable. With this off, your space order is fixed and Lattice works.

Terminal equivalent:
```sh
defaults write com.apple.dock mru-spaces -bool false && killall Dock
```

### 2. Grant Accessibility permission — **required**

**System Settings → Privacy & Security → Accessibility → enable Lattice**

macOS will prompt on first launch. Required because Lattice uses `AXUIElement` to raise anchor windows across spaces.

### 3. Enable "Displays have separate Spaces" — required for multi-monitor

**System Settings → Desktop & Dock → Mission Control → Displays have separate Spaces → on**

Only relevant if you have more than one monitor. With this off, all displays share a single linear space list and per-display grids are meaningless. With it on, each display has its own independent space list, which is what Lattice's per-display grid model assumes.

### 4. Enable "Reduce motion" — strongly recommended

**System Settings → Accessibility → Display → Reduce motion → on**

macOS's space-switch animation is hardcoded to a horizontal slide regardless of direction. Going "down" in a 2D grid playing a left/right slide looks wrong. Reduce Motion replaces all space-switch animations with instant snaps. This also minimizes the brief overview flicker during transitions.

### 5. Grant Screen Recording permission — recommended

**System Settings → Privacy & Security → Screen & System Audio Recording → enable Lattice**

macOS will prompt the first time Lattice tries to capture a thumbnail. Without it, thumbnails will only show the wallpaper, not actual app windows.

## Build from source

```sh
git clone https://github.com/bryancostanich/lattice.git
cd lattice
./build.sh
open Lattice.app
```

Requires Swift 6 (Xcode Command Line Tools). `build.sh` produces `Lattice.app` and ad-hoc codesigns it.

## Config

Optional. Lives at `~/.config/lattice/config.json`. Without it, Lattice auto-fits grids to your space count.

```json
{
  "defaultGrid": { "cols": 3, "rows": 2 },
  "displays": {
    "37D8832A-2D66-02CA-B9F7-8F30A301B230": { "cols": 4, "rows": 2 }
  },
  "wrap": false
}
```

- `defaultGrid` (optional): fallback grid for any display without an entry in `displays`. Omit to use auto-fit.
- `displays` (optional): per-display grid, keyed by display UUID. Display UUIDs are logged to `/tmp/lattice.log` on launch.
- `wrap` (optional, default `false`): when `true`, navigating past an edge wraps to the opposite edge.

Click **Reload Config** in the menu bar after editing.

## How it works

- **Reading state**: private `SkyLight.framework` APIs (`CGSCopyManagedDisplaySpaces`, `CGSCopySpacesForWindows`, etc.) via `dlsym`. No SIP changes.
- **Switching spaces**: Lattice creates one invisible 1×1 NSWindow per macOS Space ("anchor") and pins each to its space via `CGSMoveWindowsToManagedSpace`. To jump to space N, Lattice raises anchor N. macOS's built-in "follow focus to the window's space" behavior does the rest. Same mechanism `AltTab` and `yabai` use.
- **Overview thumbnails**: captured per-display with `CGWindowListCreateImage` when you visit a space. Cached in memory and excluded from re-capture via `sharingType = .none` on the overview window itself.
- **Hotkeys**: Carbon `RegisterEventHotKey`.

## Known limitations

- **Overview flickers during transitions.** macOS reserves the transition compositor for system-owned windows (menubar, Dock); third-party windows can't render through it even at `.screenSaver` level with `.canJoinAllSpaces`. With Reduce Motion on the flicker is minimal.
- **Thumbnails populate lazily.** A space's thumbnail isn't captured until you've visited it at least once. First-time use shows blank cells; coverage builds with use.
- **Lattice doesn't manage Spaces themselves.** It navigates the spaces you've created in Mission Control. It won't create, destroy, or reorder spaces — those operations need Dock injection (SIP off), which Lattice deliberately avoids.
- **Menu bar status reflects only the main display.** Multi-display navigation works per-display, but the `[col,row]` indicator shows position on whichever screen has focus.

## License

Apache 2.0. See [LICENSE](LICENSE).
