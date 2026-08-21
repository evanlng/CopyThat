# CopyThat Plugin Development

CopyThat plugins are small Swift values compiled into the app. They are not
downloadable bundles or background processes. This keeps startup, memory use,
privacy, and release signing predictable.

CopyThat 2.2 also supports data-only `.copythatplugin` manifests for simple
HTTPS actions. Choose **Settings → Plugins → Install Plugin…** to import one.
These manifests never load executable code.

The current plugin platform supports schema v2 and CopyThat Host API v2.
Schema-v2 plugins may include restricted JavaScript that runs only after the
user clicks the plugin's HUD button. JavaScriptCore receives no macOS APIs
directly. Every effect passes through a declared, permission-checked Host API;
Swift, dynamic libraries, shell commands, helpers, and background services are
still rejected. Schema-v1 HTTPS plugins remain compatible.

## Create a Host API v2 plugin

The included [`EditInPreview.copythatplugin`](Examples/EditInPreview.copythatplugin)
shows the complete image-editing workflow. Its important fields are:

For editors and AI coding tools, use the machine-readable
[`CopyThatPlugin.schema.json`](Schemas/CopyThatPlugin.schema.json) as the source
of truth for supported fields and values.

```json
{
  "schemaVersion": 2,
  "minimumHostAPIVersion": 2,
  "identifier": "com.copythat.example.edit-in-preview",
  "matches": ["image", "imageFiles"],
  "permissions": [
    "clipboard.readImage",
    "clipboard.readFiles",
    "system.openApplication"
  ],
  "action": {
    "type": "runScript",
    "title": { "en": "Edit in Preview", "zh-Hans": "在预览中编辑" }
  },
  "script": "function run(context) { return copythat.openCopiedContent(\"com.apple.Preview\"); }"
}
```

Host API v2 keeps the same safe JavaScript functions as v1 and adds the
`imageFiles` match type. It matches Finder copies only when every copied file is
a recognised image format such as PNG, JPEG, HEIC, TIFF, GIF, or WebP. The HUD
can show up to two applicable actions together, so an image-file plugin can sit
beside the built-in **Show in Finder** action.

The same included plugin opens copied Finder image files in Preview through Host API v2.

Host API functions:

- `copythat.openCopiedContent(bundleIdentifier)` opens the current copied
  content in an installed app. Images and bounded text are written to temporary
  files; Finder files retain their existing URLs. Requires
  `system.openApplication` plus the matching `clipboard.readImage`,
  `clipboard.readText`, or `clipboard.readFiles` permission.
- `copythat.openHTTPS(url)` opens an HTTPS address. Requires
  `network.openHTTPS`.
- `copythat.writeText(text)` writes at most 20,000 characters to the pasteboard.
  Requires `clipboard.writeText`.
- `copythat.hostAPIVersion` is `2`.

`run(context)` receives `context.kind`. It receives `context.text` only when the
plugin declares `clipboard.readText`. A plugin may request only the permissions
it uses; CopyThat displays them before installation and enforces them again on
every Host API call.

Host API v2 is restricted but in-process. Install only trusted plugins: a
non-terminating JavaScript loop could still make CopyThat unresponsive. A future
XPC runner can add a killable process boundary without changing the versioned
plugin interface.

## Create an importable action plugin

Use this bounded format:

```json
{
  "schemaVersion": 1,
  "identifier": "com.example.copythat.maps",
  "name": { "en": "Maps Search", "zh-Hans": "地图搜索" },
  "description": { "en": "Find copied text in Maps.", "zh-Hans": "在地图中查找复制文字。" },
  "systemImage": "map",
  "matches": ["text"],
  "action": {
    "type": "openURL",
    "title": { "en": "Find Place", "zh-Hans": "查找位置" },
    "urlTemplate": "https://maps.apple.com/?q={content}"
  }
}
```

Save it with the `.copythatplugin` extension. Supported `matches` values are
`text`, `calculation`, `englishWord`, `chineseCharacter`, `link`, `phoneNumber`,
`emailAddress`, and `code`. Only HTTPS URLs are accepted, and `{content}` must
occur exactly once inside a query-item value. The file limit is 64 KB.

## Add a content detector

1. Add a stable case to `ClipboardContentKind` and the corresponding result to
   `ClipboardContent`.
2. Implement `ClipboardContentDetector` in a focused Swift file.
3. Register one instance in `ClipboardDetectionRegistry.builtIn`.

A detector must be local, deterministic, bounded by input length, and must not
write to the pasteboard. Detectors run only once after `changeCount` changes.
Put cheap, specific checks before expensive or general checks.

## Add an action button

1. Add a stable case to `ClipboardActionPluginID`.
2. Implement `ClipboardActionPlugin`.
3. Register it in `ClipboardActionRegistry.builtIn`.
4. If the action needs a new behavior, add an audited `ClipboardActionTarget`
   and handle it once in `OverlayManager`.

The HUD and settings screen consume registry metadata automatically. A plugin
must not perform its action during recognition; external work starts only after
the user clicks the button.

## Performance checklist

- Do nothing while the clipboard is unchanged.
- Reject oversized or obviously irrelevant input before parsing.
- Do not add polling timers, helper processes, databases, analytics, or caches.
- Do not retain the full clipboard value after the HUD disappears.
- Use system frameworks and local data before considering a dependency.
- Add unit tests for matches, non-matches, input limits, and disabled state.

## 中文说明

CopyThat 2.0 的“插件”是编译进 App 的轻量 Swift 模块，不是可下载脚本、独立进程或后台服务。

CopyThat 2.2 还支持只包含数据的 schema v1 `.copythatplugin` 操作清单，可通过
**设置 → 插件 → 安装插件…** 导入。它只能声明匹配内容和 HTTPS 按钮动作，
不能加载可执行代码。格式示例见 [`Examples/OpenInMaps.copythatplugin`](Examples/OpenInMaps.copythatplugin)。

新的 schema v2 插件可以包含受限 JavaScript，并通过 CopyThat Host API v2 调用
经过权限检查的通用能力。脚本只有在用户点击插件按钮后才运行，无法直接访问 AppKit、
文件系统、进程、网络或剪贴板。安装时会显示插件申请的权限，每次调用 Host API 时
主程序还会再次检查。[`Examples/EditInPreview.copythatplugin`](Examples/EditInPreview.copythatplugin)
统一支持直接复制的图片，以及从访达复制的 PNG、JPEG、HEIC、TIFF、GIF、WebP
等图片文件；后者会和内置“在访达中显示”同时出现，方便选择。

Host API v2 的 JavaScriptCore 仍在主进程内运行，因此只应安装可信插件；死循环脚本
仍可能让 App 暂时失去响应。后续可把执行器迁移到可终止的 XPC 进程，同时保持插件接口版本兼容。

新增内容识别时，实现 `ClipboardContentDetector`，然后在
`ClipboardDetectionRegistry.builtIn` 注册一次；新增按钮时，实现
`ClipboardActionPlugin`，然后在 `ClipboardActionRegistry.builtIn` 注册一次。
HUD 和设置页不需要为每个新功能重新编写。

所有插件都必须本地、有界、按需运行：剪贴板没有变化时不执行，识别阶段不修改剪贴板，
外部操作只有在用户点击按钮后才发生。
