# CopyThat Plugin Platform 3.0 Design

This document defines the target architecture for installable plugins that can
add behavior without modifying or rebuilding the CopyThat host application.

## Core model

- CopyThat owns a stable, versioned Host API.
- A plugin owns its matching rules, HUD action metadata, and optional restricted
  JavaScript behavior.
- Plugins cannot load Swift, dynamic libraries, shell commands, helper tools, or
  background services.
- The JavaScript runtime receives no macOS APIs directly. Every effect must pass
  through a permission-checked Host API capability.
- Existing schema-v1 HTTPS manifest plugins remain supported.

## Package format

A code plugin is a directory package ending in `.copythatplugin`:

```text
EditInPreview.copythatplugin/
  manifest.json
  main.js
```

The manifest declares a schema version, minimum Host API version, content
matches, action button, entry point, and requested permissions. Installation
copies validated files into CopyThat's Application Support container.

## Host API v1 capabilities

- Read the already-analyzed content passed to the clicked action.
- Export the current copied image to an opaque temporary-file handle.
- Open an opaque file handle with an installed application bundle identifier.
- Open an HTTPS URL.
- Write bounded text to the pasteboard.

Capabilities are requested in the manifest and checked again on every call.
Opaque handles prevent plugins from reading or opening arbitrary filesystem
paths. No plugin code runs while the clipboard is idle; JavaScript runs only
after the user clicks its HUD button.

JavaScriptCore runs in the CopyThat process in Host API v1. It has no direct
system bridge, but it is not a process-isolation boundary: users should install
only trusted plugins, and a non-terminating script could still make the app
unresponsive. Moving script evaluation into a killable XPC runner is the next
hardening milestone.

## Boundary

Plugins can implement new workflows by composing existing Host API
capabilities. A genuinely new macOS primitive still requires a Host API update,
but existing plugins remain compatible because the API is versioned.
