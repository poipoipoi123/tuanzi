# 团子 Tuanzi — Godot 客户端版

原创、单机、纯本地的小镇养成冒险游戏。视觉致敬 2010 年前后的国产网页游戏，
**不使用任何第三方版权素材**：全部美术由代码程序化绘制（Canvas 2D 绘制指令），
不加载任何外部图片、不复用任何原版名称/角色/剧情。

## 直接玩

双击 `build/Tuanzi.exe` 即可，无需安装、无需联网。

| 操作 | 按键 |
|---|---|
| 移动 | `WASD` 或 `方向键` |
| 交互 / 对话 / 触发遭遇 | `E` / `空格` |
| 图鉴与背包 | `Tab` |
| 关闭面板 | `Esc` |
| 存档 | `F5` |

## 玩法现状

- **橡果小镇**：程序化绘制的地面、小径、池塘、房屋、树木、路灯、栅栏；相机平滑跟随并限制在世界边界内。
- **小团子**：呼吸、行走摆动、眨眼、朝向、受击闪白的程序化动画。
- **3 位居民 NPC**：头顶名牌，靠近按 `E` 说话，气泡对话。
- **回合制战斗**：按速度决定出手顺序、技能按钮、伤害浮动、飘字、镜头震动与白光、逃跑判定、回合上限。
- **图鉴**：已见/已收服团子兽、种族数值、队伍与背包一览。
- **存档**：便携模式（存档写在 exe 同目录），系统用户目录不可写时自动回退；`F5` 存盘，战斗结束自动存盘。

## 目录结构

```
project.godot            工程配置（输入动作由代码注册）
scenes/main.tscn         入口场景
scripts/core/            调色板、美术库、游戏状态、存档路径、输入、主控
scripts/world/           角色基类、玩家、NPC、世界场景
scripts/battle/          战斗单位与战斗场景
scripts/ui/              HUD、战斗菜单、图鉴、对话气泡
scripts/data/            数值表（团子兽、技能、道具）
tests/self_check.tscn    无头自检（53 项）
```

## 自检

```powershell
.\tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/self_check.tscn
```

全绿时打印 `ALL PASS` 并以退出码 0 结束。自检覆盖：数值表、存档读写与拒绝非法存档、
伤害公式与治疗上限、出手顺序、世界装配、障碍阻挡、战斗全流程结算。

## 重新导出 Windows 客户端

需要 Godot 4.7.2 编辑器与同版本 export templates。

```powershell
.\tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Windows Desktop" "build/Tuanzi.exe"
```

## 原创性声明

本工程不含淘米/摩尔勇士的任何素材、程序、名称或角色；不复刻原版界面；不使用 Flash/SWF。
所有角色、场景、文案与数值均为本项目原创。
