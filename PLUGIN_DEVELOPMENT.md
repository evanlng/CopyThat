# CopyThat 2.2 Plugin Development

CopyThat plugins are small Swift values compiled into the app. They are not
downloadable bundles or background processes. This keeps startup, memory use,
privacy, and release signing predictable.

CopyThat 2.2 also supports data-only `.copythatplugin` manifests for simple
HTTPS actions. Choose **Settings → Plugins → Install Plugin…** to import one.
These manifests never load executable code.

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

CopyThat 2.2 还支持只包含数据的 `.copythatplugin` 操作清单，可通过
**设置 → 插件 → 安装插件…** 导入。它只能声明匹配内容和 HTTPS 按钮动作，
不能加载可执行代码。格式示例见 [`Examples/OpenInMaps.copythatplugin`](Examples/OpenInMaps.copythatplugin)。

新增内容识别时，实现 `ClipboardContentDetector`，然后在
`ClipboardDetectionRegistry.builtIn` 注册一次；新增按钮时，实现
`ClipboardActionPlugin`，然后在 `ClipboardActionRegistry.builtIn` 注册一次。
HUD 和设置页不需要为每个新功能重新编写。

所有插件都必须本地、有界、按需运行：剪贴板没有变化时不执行，识别阶段不修改剪贴板，
外部操作只有在用户点击按钮后才发生。
