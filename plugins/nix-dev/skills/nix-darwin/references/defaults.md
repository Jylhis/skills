# system.defaults Reference

Complete reference for nix-darwin `system.defaults.*` options. These map to macOS `defaults write` commands but are managed declaratively.

Changes apply on `darwin-rebuild switch`. Some require a logout or restart to take effect.

## Table of Contents

- [NSGlobalDomain](#nsglobaldomain)
- [dock](#dock)
- [finder](#finder)
- [trackpad](#trackpad)
- [keyboard](#keyboard)
- [loginwindow](#loginwindow)
- [screencapture](#screencapture)
- [WindowManager](#windowmanager)

## NSGlobalDomain

Global settings that apply across all applications.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `AppleShowAllExtensions` | bool | `false` | Show all file extensions in Finder |
| `AppleInterfaceStyle` | null or string | `null` | `"Dark"` for dark mode, `null` for light |
| `AppleShowAllFiles` | bool | `false` | Show hidden files everywhere |
| `NSDocumentSaveNewDocumentsToCloud` | bool | `true` | Save new docs to iCloud by default |
| `PMPrintingExpandedStateForPrint` | bool | `false` | Expand print dialog by default |
| `KeyRepeat` | int | `6` | Key repeat rate (lower = faster). 1 is fastest, 2 is fast. |
| `InitialKeyRepeat` | int | `25` | Delay before key repeat starts (lower = shorter). 10 is short, 15 is reasonable. |
| `ApplePressAndHoldEnabled` | bool | `true` | `true` = accent menu on hold, `false` = key repeat |
| `NSAutomaticCapitalizationEnabled` | bool | `true` | Auto-capitalize first letter of sentences |
| `NSAutomaticSpellingCorrectionEnabled` | bool | `true` | Auto-correct spelling |

```nix
system.defaults.NSGlobalDomain = {
  AppleShowAllExtensions = true;
  AppleInterfaceStyle = "Dark";
  KeyRepeat = 2;
  InitialKeyRepeat = 15;
  ApplePressAndHoldEnabled = false;
  NSDocumentSaveNewDocumentsToCloud = false;
  PMPrintingExpandedStateForPrint = true;
  NSAutomaticCapitalizationEnabled = false;
  NSAutomaticSpellingCorrectionEnabled = false;
};
```

## dock

Dock appearance, behavior, and hot corners.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `autohide` | bool | `false` | Auto-hide the Dock |
| `autohide-delay` | float | `0.24` | Seconds before Dock shows on hover |
| `autohide-time-modifier` | float | `1.0` | Dock show/hide animation duration |
| `launchanim` | bool | `true` | Animate opening applications |
| `minimize-to-application` | bool | `false` | Minimize windows into app icon |
| `mru-spaces` | bool | `true` | Rearrange Spaces based on most recent use |
| `orientation` | string | `"bottom"` | `"left"`, `"bottom"`, or `"right"` |
| `show-process-indicators` | bool | `true` | Show dots for running apps |
| `show-recents` | bool | `true` | Show recent apps section |
| `static-only` | bool | `false` | Only show running applications |
| `tilesize` | int | `64` | Icon size in pixels |

### Hot Corners

Each corner option takes an integer action code:

| Option | Description |
|--------|-------------|
| `wvous-tl-corner` | Top-left corner |
| `wvous-tr-corner` | Top-right corner |
| `wvous-bl-corner` | Bottom-left corner |
| `wvous-br-corner` | Bottom-right corner |

Action codes:

| Code | Action |
|------|--------|
| `1` | Disabled |
| `2` | Mission Control |
| `3` | Application Windows |
| `4` | Desktop |
| `5` | Start Screen Saver |
| `6` | Disable Screen Saver |
| `10` | Put Display to Sleep |
| `11` | Launchpad |
| `12` | Notification Center |
| `13` | Lock Screen |
| `14` | Quick Note |

```nix
system.defaults.dock = {
  autohide = true;
  autohide-delay = 0.0;
  autohide-time-modifier = 0.4;
  launchanim = false;
  minimize-to-application = true;
  mru-spaces = false;
  orientation = "bottom";
  show-process-indicators = true;
  show-recents = false;
  static-only = false;
  tilesize = 48;
  wvous-tl-corner = 2;   # Mission Control
  wvous-tr-corner = 12;  # Notification Center
  wvous-bl-corner = 14;  # Quick Note
  wvous-br-corner = 4;   # Desktop
};
```

## finder

Finder appearance and behavior.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `AppleShowAllExtensions` | bool | `false` | Show all file extensions |
| `AppleShowAllFiles` | bool | `false` | Show hidden files |
| `CreateDesktop` | bool | `true` | Show icons on desktop |
| `FXDefaultSearchScope` | string | `"SCsp"` | `"SCcf"` = current folder, `"SCsp"` = previous scope, `"SCev"` = entire Mac |
| `FXPreferredViewStyle` | string | `"icnv"` | `"icnv"` = icons, `"Nlsv"` = list, `"clmv"` = columns, `"Flwv"` = gallery |
| `ShowPathbar` | bool | `false` | Show path bar at bottom |
| `ShowStatusBar` | bool | `false` | Show status bar at bottom |
| `_FXShowPosixPathInTitle` | bool | `false` | Show full POSIX path in title bar |
| `_FXSortFoldersFirst` | bool | `false` | Sort folders before files |

```nix
system.defaults.finder = {
  AppleShowAllExtensions = true;
  AppleShowAllFiles = true;
  CreateDesktop = false;
  FXDefaultSearchScope = "SCcf";
  FXPreferredViewStyle = "clmv";
  ShowPathbar = true;
  ShowStatusBar = true;
  _FXShowPosixPathInTitle = true;
  _FXSortFoldersFirst = true;
};
```

## trackpad

Trackpad gestures and behavior.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `Clicking` | bool | `false` | Tap to click |
| `TrackpadRightClick` | bool | `true` | Two-finger right click |
| `TrackpadThreeFingerDrag` | bool | `false` | Three-finger window drag |

```nix
system.defaults.trackpad = {
  Clicking = true;
  TrackpadRightClick = true;
  TrackpadThreeFingerDrag = true;
};
```

## keyboard

Keyboard behavior is controlled via `NSGlobalDomain`:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `ApplePressAndHoldEnabled` | bool | `true` | `false` = enable key repeat instead of accent menu |
| `KeyRepeat` | int | `6` | Repeat rate (lower = faster) |
| `InitialKeyRepeat` | int | `25` | Delay before repeat starts (lower = shorter) |

To enable fast key repeat for tools like Vim:

```nix
system.defaults.NSGlobalDomain = {
  ApplePressAndHoldEnabled = false;
  KeyRepeat = 2;
  InitialKeyRepeat = 15;
};
```

## loginwindow

Login window settings.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `GuestEnabled` | bool | `true` | Allow guest login |
| `SHOWFULLNAME` | bool | `false` | Show name+password fields instead of user list |

```nix
system.defaults.loginwindow = {
  GuestEnabled = false;
  SHOWFULLNAME = false;
};
```

## screencapture

Screenshot settings.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `location` | string | `"~/Desktop"` | Directory to save screenshots |
| `type` | string | `"png"` | Format: `"png"`, `"jpg"`, `"pdf"`, `"tiff"`, `"gif"` |
| `disable-shadow` | bool | `false` | Remove drop shadow from window screenshots |

```nix
system.defaults.screencapture = {
  location = "~/Screenshots";
  type = "png";
  disable-shadow = true;
};
```

## WindowManager

Stage Manager and window management (macOS Sonoma+).

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `EnableStandardClickToShowDesktop` | bool | `true` | Click wallpaper to show desktop (Sonoma default) |

```nix
system.defaults.WindowManager = {
  EnableStandardClickToShowDesktop = false;
};
```
