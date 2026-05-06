# macOS-Specific Documentation

Documentation sources specific to macOS. These supplement the general Unix documentation described in the parent skill.

## System Man Pages

macOS ships ~3,700 man pages at `/usr/share/man/` covering BSD utilities, POSIX interfaces, the C standard library, and macOS-specific APIs.

Notable macOS-specific man pages:

| Man page | Coverage |
|---|---|
| `man defaults` | Read/write macOS preference domains |
| `man launchctl` | Manage launchd services |
| `man launchd.plist` | launchd job definition format |
| `man plutil` | Property list utility |
| `man xattr` | Extended file attributes |
| `man diskutil` | Disk management |
| `man hdiutil` | Disk image manipulation |
| `man security` | Keychain and security framework CLI |
| `man dscl` | Directory Services command line |
| `man sysctl` | Kernel state parameters |
| `man pmset` | Power management settings |
| `man scutil` | System configuration utility |
| `man networksetup` | Network configuration |
| `man codesign` | Code signing |
| `man mdls` | Spotlight metadata attributes |
| `man mdfind` | Spotlight search from CLI |
| `man open` | Open files, URLs, and applications |
| `man pbcopy` / `man pbpaste` | Clipboard access |
| `man caffeinate` | Prevent sleep |
| `man say` | Text to speech |

## Terminal Man Page Viewer

Open a man page in a dedicated Terminal.app window with rich formatting:

```bash
open x-man-page://<name>
# Example:
open x-man-page://ls
```

This renders with bold, underline, and color -- easier to read than terminal output for long pages.

## Xcode Command Line Tools

Xcode CLI tools add man pages for developer utilities:

| Man page | Coverage |
|---|---|
| `man xcrun` | Run Xcode developer tools |
| `man xcodebuild` | Build Xcode projects from CLI |
| `man xcode-select` | Manage active Xcode/CLT installation |
| `man clang` | C/C++/Objective-C compiler |
| `man ld` | macOS linker |
| `man otool` | Object file display tool |
| `man install_name_tool` | Change dynamic library paths |
| `man dwarfdump` | DWARF debug info |

Access with: `man <tool>` or `xcrun man <tool>`.

## System Settings Discovery

macOS system settings (System Preferences / System Settings) don't have traditional man pages, but you can discover configuration keys:

```bash
# List all preference domains
defaults domains | tr ',' '\n'

# Read all settings in a domain
defaults read <domain>

# Example: Dock settings
defaults read com.apple.dock

# Find a specific key across all domains
defaults find <keyword>
```

For nix-darwin managed systems, use `darwin-option` or `man 5 configuration.nix` instead -- see `references/nix-managed.md`.

## macOS Frameworks Documentation

Apple framework documentation is not shipped as man pages. For CoreFoundation, AppKit, SwiftUI, etc., the authoritative offline source is Xcode's built-in documentation browser (accessible via Xcode > Window > Developer Documentation). There is no CLI equivalent for Apple framework docs.
