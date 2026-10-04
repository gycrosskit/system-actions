# 0.2.0-rc.3 远程发布验收

2026-10-04，[修复 PR](https://github.com/gycrosskit/system-actions/pull/16) 已合并到实际 `main`。不可变 tag `0.2.0-rc.3` 指向确认的 merge commit `9add6f2b216d703b9d9dc1c93429872963fb8180`；[Release](https://github.com/gycrosskit/system-actions/releases/tag/0.2.0-rc.3) 为 prerelease，旧 tag/资产未覆盖。

- Maven 归档 SHA256：`5b11e2f3fdc5e2932a18ebfdba797c482169e012a11e0c6d91eea443b8e26188`。
- Release HAR SHA256：`be9848a78a1c9b801d025d45a3fb2961f5f38913f21e6f14ec73ee9c1cbe4051`。
- 两资产实际重下载 SHA 与字节均匹配本地通过门禁的候选，`SHA256SUMS` 与 GitHub asset digest 一致。
- fresh staging 共 124 tasks 与 HAR 29 tasks 成功；本地精确 9 publications、四 sidecars/声明 hash、POM/license、available-at 与解包复验通过，所有 ZIP CRC 正常；checker 13 项和 metadata 7 项回归通过。
- JitPack API 最终 `ok`，commit 与 tag 相同，9 模块。完整远程 IO 核验 11 variant file 引用、9 实际 artifact：size、声明 MD5/SHA-1/SHA-256/SHA-512、ZIP CRC、POM/许可证、内部精确版本、available-at 身份及同名变体、四 Native targets 全通过。
- JitPack 公开 MD5/SHA-1 sidecars 与实际内容匹配；27 SHA-256 与 27 SHA-512 sidecars 返回 HTTP 404，单列渠道边界，没有视为下载通过。JitPack 改写的 1 个顶层 component.url identity redirect 返回 404，必要的 variant/available-at 文件全部存在，未建立伪坐标。
- actual Release HAR 已在独立 API22 consumer 安装；真实 JitPack 全平台编译/Simulator 最终链接、Release HAR consumer 编译尚待独立重型窗口，不由本地源码构建替代。
- `ohpm prepublish` 通过，`ohpm publish --tag next` 接受并明确 **under review**；随后精确版本 `ohpm info` 返回 **NOTFOUND**，没有宣称已上架或 Registry 安装通过。旧 latest 保持原稳定版本。

UIKit 原生源码未变，Swift Package/Git Pod 保留实际验证的 `0.2.0-rc.2`。Web HAR 必须配套 system-actions-native `0.2.0-rc.3`，由同版本 WindowPolicyController.shared 提供唯一 owner。

日志均位于独占 worktree 忽略目录 `build/publish-review/`：staging.log、har.log、archive.log、remote-audit.log、ohpm-prepublish.log、ohpm-publish.log、ohpm-info.log、remote-har-install.log。设备系统交互/微信真实 SDK、存储故障及业务回跳未验收。
