# Lattice

Grid-based space navigation for macOS. A spiritual successor to TotalSpaces 3 — arrange your native macOS Spaces in a 2D grid and navigate them with `Ctrl+Opt+arrow`.

Built on Apple Silicon, macOS 14+. SIP stays on. No Dock injection.

## What it does

- Treats your macOS Spaces as a 2D grid (default auto-fit; override per display).
- `Ctrl+Opt+←/→/↑/↓` switches spaces by grid direction. The display under the mouse cursor is the one that moves.
- `Ctrl+Opt+Space` shows a compact overview window with thumbnails of every space, current space highlighted. Click a cell to jump.
- Menu bar item shows current grid position (`[col,row]`) and lists every space for click-to-jump.
- Per-display grid layout. Independent grids on each external display.

## Requirements

- macOS 14 (Sonoma) or later, Apple Silicon recommended.
- Accessibility permission (granted once in System Settings → Privacy & Security → Accessibility).
- Two macOS settings worth changing for Lattice to behave well:
  - **System Settings → Desktop & Dock → Mission Control → Automatically rearrange Spaces** → off. Otherwise macOS reorders your spaces between switches and breaks the grid mapping.
  - **System Settings → Accessibility → Display → Reduce motion** → on (optional, but kills the slide animation that makes left/right hotkeys look wrong for vertical jumps).

## Build

```sh
./build.sh
open Lattice.app
```

Requires Swift 6 toolchain (Xcode Command Line Tools).

The script ad-hoc codesigns the bundle. macOS will warn on first launch — right-click → Open. Grant Accessibility when prompted.

## Config

Optional file at `~/.config/lattice/config.json`. Lattice runs fine without it — grids auto-fit to your space count.

```json
{
  "defaultGrid": { "cols": 3, "rows": 2 },
  "displays": {
    "37D8832A-2D66-02CA-B9F7-8F30A301B230": { "cols": 4, "rows": 2 }
  },
  "wrap": false
}
```

Display UUIDs are logged to `/tmp/lattice.log` on launch.

## How it works

- Reads spaces from `SkyLight.framework` private API (`CGSCopyManagedDisplaySpaces`, etc.).
- Pins one invisible "anchor" window per space using `CGSMoveWindowsToManagedSpace`.
- To switch spaces, raises the anchor for the target space — macOS follows focus to the window's space.
- Overview thumbnails are screenshots taken when each space becomes active (cached; first visit shows a blank cell).

## Known limitations

- The overview briefly flickers during a space switch. macOS reserves the transition compositor for system-owned windows; third-party apps can't render through it.
- Lattice doesn't reorder, create, or destroy macOS Spaces — it only navigates the ones you've created in Mission Control.
- Multi-display: navigation and overview work per-display, but the menu bar status indicator only reflects the focused display.

## License

Apache 2.0. See [LICENSE](LICENSE).
