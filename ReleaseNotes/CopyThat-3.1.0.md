# CopyThat 3.1.0

## 中文

- 新增可选的自动版本检测，默认关闭。
- “设置 → 通用 → 软件更新”可随时开启自动检测，或手动点击“立即检查”。
- 发现新版本后，可选择保存 GitHub Release 中的 DMG；GitHub 提供 SHA-256 摘要时会在打开前校验。
- 下载完成后自动打开 DMG，由用户将 CopyThat 拖入“应用程序”并确认替换。
- 优化 SQL 代码识别热路径，避免对每个关键字重复创建完整字符串。
- 清理未使用接口和旧更新框架残留，并收紧并发安全声明与应用权限。

## English

- Adds optional automatic update checks, disabled by default.
- Enable automatic checks or use “Check Now” in Settings → General → Updates.
- Saves the GitHub Release DMG to a user-selected location and verifies GitHub’s SHA-256 digest when available.
- Opens the downloaded DMG so the user can drag CopyThat into Applications and confirm replacement.
- Optimizes SQL detection to avoid rebuilding the full input for every keyword.
- Removes unused APIs and stale updater code while tightening concurrency declarations and app permissions.
