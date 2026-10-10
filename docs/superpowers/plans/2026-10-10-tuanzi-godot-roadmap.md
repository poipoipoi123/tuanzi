# 团子 Godot 版 实现路线图

> **面向 AI 代理的工作者：** 本文件是索引，不含实现步骤。逐任务实现请使用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 打开对应阶段的计划文件。

**目标：** 把 v0.1.0 的可玩原型（小镇探索 + 单体战斗）扩展为规格第 5 节所述的完整单机游戏，全程保持 IP-clean。

> **素材政策修订（2026-10-10，用户决定）：** 原「零外部素材」约束已解除。美术改用**开源像素贴图**，许可证限白名单：**CC0 / CC-BY 4.0 / MIT / Apache-2.0**；每份素材须登记在 `assets/ATTRIBUTION.md`（名称、作者、来源 URL、许可证链接、下载日期）。**禁止** CC-BY-SA / GPL / CC-BY-NC / CC-BY-ND。音频维持运行时合成 PCM，不引入音频文件。

**架构：** Godot 4.7.2 + GDScript。纯逻辑（数值表、伤害/收服/强化公式）放 `data/` 与 `systems/`，可在无头自检中直接断言；绘制从纯 `_draw()` 逐步迁移到贴图管线（`_draw()` 作为贴图缺失时的回退），由 `Sfx` 提供程序化音效。所有外部输入（随机数、文件路径）可注入，保证可测。

**技术栈：** Godot 4.7.2 stable、GDScript 4、无外部依赖、无构建步骤。

---

## 当前进度

| 阶段 | 状态 | 交付 |
|---|---|---|
| 阶段一 | **已完成** | 橡果小镇探索、程序化角色与场景、3 NPC 对话、回合制战斗、图鉴、便携存档、53 项自检 |
| 阶段二 | 进行中 | 见 `2026-10-10-tuanzi-godot-phase2.md`（8 任务；美术管线迁移到开源像素贴图已加入范围） |
| 阶段三 | 待实现 | 见 `2026-10-10-tuanzi-godot-phase3.md` |

---

## 计划文件

| 文件 | 范围 | 任务数 |
|---|---|---|
| `2026-10-10-tuanzi-godot-phase2.md` | 属性克制、暴击闪避、收服、道具实战、四维养成、外貌、音效 | 8 |
| `2026-10-10-tuanzi-godot-phase3.md` | 3v3 队伍、装备强化、商店经济、任务系统、多区域、存档迁移 | 9 |

---

## 通用约定（每个任务都适用）

**测试运行器：** 无头自检，打印 `PASS`/`FAIL`，有失败时退出码 1。

```powershell
$GODOT = ".\.tools\Godot_v4.7.2-stable_win64_console.exe"
& $GODOT --headless --path . res://tests/self_check.tscn
```

**新增断言的写法：** 在 `tests/self_check.gd` 对应分组函数内追加，用现成的 `_ok(cond, name)`：

```gdscript
_ok(ElementDB.effectiveness("草", "水") == 2.0, "草打水为 2 倍克制")
```

**导出验证（每次涉及运行时的改动都要做）：**

```powershell
& $GODOT --headless --path . --export-release "Windows Desktop" "build/Tuanzi.exe" | Out-Null
& ".uildTuanzi.exe" --headless --quit-after 150
```

**环境注意（踩过的坑，勿重复）：**
- Godot 子进程需要 `APPDATA`、`TEMP` 环境变量；`TEMP` 必须指向**工作区内**目录，否则导出时 `project.binary` 损坏。
- 工程名必须是 ASCII；中文工程名会导致 `user://` 建目录失败。
- 带反斜杠路径传给 `spawnSync` 时不要手动加引号（会 ENOENT）。
- 只读 stdout 会漏掉 Godot 的 `SCRIPT ERROR`（走 stderr），诊断时必须合并两者。
- 改动 `class_name` 后需 `--import` 一次注册到全局类缓存。

**提交约定：** Conventional Commits；每个任务末尾单独提交，不合并多个任务。

---

## 阶段门禁

每个阶段结束时必须满足：

1. `self_check.tscn` 全绿、退出码 0
2. 导出 `Tuanzi.exe` 并能无错启动
3. `docs/acceptance.md` 追加该阶段的手动验收项
4. 提交并推送；打 tag（`v0.2.0` / `v0.3.0`）并发 Release

---

## 范围外（明确不做）

联机 / 多人 / 账号体系、内购 / 付费 / 广告、移动端适配、许可不在白名单内的任何素材、模拟器式复刻原版界面。
