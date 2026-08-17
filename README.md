# CopyThat（牛马）1.5.0

![CopyThat — Copy with confidence](marketing/CopyThat-Hero.png)

A lightweight native macOS menu bar app that confirms clipboard updates with a
non-activating floating panel and offers safe, context-aware next actions.

**CopyThat** is the English product name. On a Simplified Chinese macOS system,
the localized app name is **牛马**.

## Requirements

- macOS 14 or later
- Apple Silicon Mac (arm64)
- Xcode 27 beta or later (required for the native Icon Composer app icon)
- No third-party packages

## Open and run

1. Open `ClipboardFeedback.xcodeproj` in Xcode.
2. Select the `ClipboardFeedback` scheme and **My Mac** destination.
3. Press Run.

The built product is `CopyThat.app`. It appears only in the menu bar and
intentionally has no Dock icon.

## Install a GitHub Release

1. Open `CopyThat.dmg`.
2. Drag `CopyThat.app` into the Applications folder.
3. Open CopyThat from Applications.

The current downloadable build is ad-hoc signed because this project does not
yet have a `Developer ID Application` certificate. On first launch, macOS may
require Control-clicking the app and choosing **Open**. A public release without
that step requires Apple Developer Program membership, Developer ID signing,
and Apple notarization.

## Privacy and permissions

- Clipboard contents are inspected locally and never sent over the network.
- Clipboard contents are not logged or stored as history.
- The app target uses App Sandbox without the outgoing-network entitlement.
  The app contains no update checker, telemetry, external plugin runtime, or
  script execution.
- No Accessibility, Input Monitoring, or Screen Recording permission is needed
  for the MVP because it observes `NSPasteboard.changeCount` rather than global
  keyboard events.
- **Launch at Login** uses `SMAppService`. For reliable registration, place a
  signed build in `/Applications`. macOS may show it under **System Settings →
  General → Login Items**.

## Behavior and architecture

- `ClipboardMonitor` checks only `NSPasteboard.changeCount`. It polls every 250 ms
  normally, briefly switches to 80 ms after a copy, and returns to the normal
  interval after 2.4 seconds. Timer tolerance lets macOS coalesce wakeups.
  Pausing feedback stops the timer completely.
- `ClipboardAnalyzer` performs one bounded inspection only after `changeCount`
  changes. It retains at most 1,000 text characters and 20 file URLs for the
  short-lived HUD; there is no history or database.
- Shows text, link, phone number, email address, file, image, code, or generic feedback.
- Prefers the semantic pasteboard URL type, then recognizes full `http://` and
  `https://` strings. Addresses beginning with `www.` are normalized to HTTPS.
- Uses a compile-time detector plugin protocol and one audited action interface.
  Built-in actions open links in Safari, call phone numbers through
  the system `tel:` handler, compose email through `mailto:`, and reveal files
  in Finder. Actions run only after the user clicks the toast button.
- Ordinary copied text includes a **Search** action that opens the query in Safari.
  DuckDuckGo is the default; Bing, Baidu, Google, and a custom search URL template
  are available in General settings. Custom templates use one `{query}` placeholder
  inside an `http://` or `https://` query parameter. No text leaves the app unless
  the user clicks Search.
- Includes a Detection settings tab where each smart content type can be enabled
  or disabled independently.
- Image copies are decoded directly into a temporary thumbnail no larger than
  240 pixels. The original image is never cached or written, and the thumbnail
  is released when the HUD disappears.
- Developer Mode recognizes Python, JavaScript, Swift, HTML, CSS, JSON, SQL, and
  Bash using bounded local rules. It does not use AI, a compiler, or the network.
- JSON and Python show a **Format** button. Formatting opens a review window and
  changes the pasteboard only after **Copy formatted** is clicked. Python's first
  version is deliberately conservative: it preserves indentation while cleaning
  line endings and trailing whitespace outside triple-quoted strings.
- Reuses one panel and its hosting view during rapid copies, reducing allocation
  churn while resetting the 1.8-second dismissal timer.
- Pauses dismissal while the pointer is over the panel, so link actions remain usable.
- Positions the panel at the exact horizontal center near the top of the display
  containing the mouse pointer, away from Notification Center.
- On macOS 26 and later, the floating `NSPanel` hosts the same public SwiftUI
  `glassEffect` API used by the settings preview. It does not stack
  `NSVisualEffectView`, SwiftUI Material, a surface fill, or a custom blur over
  native Liquid Glass. The system Material fallback is used only on macOS 14–15
  or when Reduce Transparency is enabled.
- General settings exposes three aligned slider positions backed by one snapped
  value: **Clear** maps to native `Glass.clear`, **Balanced** maps to native
  `Glass.regular`, and **Strong** uses native `Glass.regular` with a subtle
  semantic tint. Clear never receives a tint or surface fill. The slider and its
  three labels share the same full-width layout so their positions stay aligned.
- Native Clear glass intentionally remains adaptive: macOS may retain some
  diffusion for legibility, especially over white or high-contrast content.
  Refraction and interactive response are more apparent over varied backgrounds
  and while the pointer moves; the app does not replace that system behavior with
  a fake zero-blur surface.
- Includes adaptive mascot artwork: the light appearance uses the white cow icon,
  while the dark appearance uses the night horse icon.
- Never modifies the pasteboard when performing an external action.

## Measured performance baselines

The final CopyThat 1.5.0 Apple Silicon Release was sampled five times over 10
seconds. Every idle CPU sample reported 0.0%; memory remained approximately 25
MB with four to five threads. The HUD applies one native glass effect only while
visible, and the settings slider performs no background work.

## Known limitation

This version confirms that the pasteboard changed. It does not observe Command+C,
so it cannot report a failed copy attempt. That future feature would require a
separate global event monitor and user-granted Input Monitoring or Accessibility
permission.
