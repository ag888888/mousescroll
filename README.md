# MouseScroll

A tiny macOS menu bar app that reverses scroll direction for a **wheel mouse only**, so the trackpad keeps natural scrolling.

macOS has a single global "Natural scrolling" setting. MouseScroll leaves it alone and flips the direction of mouse-wheel events on the fly. Trackpad events pass through untouched.

## Features

- Reverse vertical and/or horizontal scrolling for the mouse
- Scroll speed multiplier (0.5x to 3x)
- Launch at login
- Menus in 20 languages (follows the system language, English is the fallback)
- No dependencies, no network access, a single Swift file

## Supported languages

English, 简体中文 (Simplified Chinese), 繁體中文 (Traditional Chinese), हिन्दी (Hindi), Español, Français, العربية (Arabic), বাংলা (Bengali), Português, Русский, اردو (Urdu), Bahasa Indonesia, Deutsch, 日本語, मराठी (Marathi), తెలుగు (Telugu), Türkçe, தமிழ் (Tamil), Tiếng Việt, 한국어

The translations were written by an AI. Corrections are welcome: edit `Resources/<language>.lproj/Localizable.strings`.

## Install

With Homebrew:

```sh
brew install --cask ag888888/mousescroll/mousescroll
```

Or download `MouseScroll.zip` from the [latest release](https://github.com/ag888888/mousescroll/releases/latest), unzip it, and move it to `/Applications`. The app is not notarized, so on first launch right-click it and choose **Open**.

## Build from source

Requires macOS 13+ and the Swift toolchain (Xcode or Command Line Tools).

```sh
./build.sh install
open /Applications/MouseScroll.app
```

On first launch, grant access under **System Settings → Privacy & Security → Accessibility**. The app starts working as soon as permission is granted.

Rebuilding may reset the permission, since the app is ad-hoc signed. If that happens, remove MouseScroll from the list and add it again.

## How it works

A `CGEventTap` intercepts scroll events. Trackpads send "continuous" events and a classic wheel mouse does not, so only non-continuous events are modified.

Limitation: Magic Mouse sends continuous events like a trackpad, so it is not reversed.

## License

[MIT](LICENSE)
