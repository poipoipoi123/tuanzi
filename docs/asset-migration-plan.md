# 开源素材接入改造计划（用户 2026-06-15 要求）

## 背景
用户验收发现游戏仍是「自定义绘制」而非开源素材。核实结论：
- `assets/` 有 2446 个开源文件，但真正生效的只有 4 张。
- 其中 3 张 `assets/sprites/tuanzi_{grass,water,spark}.png` 是绿色长腿怪物，**不是团子**，映射接错。
- `assets/ui/` 的 1199 个文件在 `scripts/` 里引用 **0 处**，界面全是 `StyleBoxFlat` 手搓。
- `world_art.gd:10` 的 `tile_path()` 无视入参恒返回同一张 `tileset.png`（仅 128x16=8 个色块，无树/房/栅栏）。

## 决策
用户确认：**统一用 `kenney_tiny_town` 像素包**（CC0，16px，132 瓦片），分批推进，每批给用户看截图。

## 批次

### 批次 1：世界地形 + 装饰遮挡
- 拆掉 `world_art.gd` 的假 `tile_path()`，为 TILE_NAMES 映射到 kenney_tiny_town 真实瓦片索引。
- 世界地面改用 `TileMapLayer` 渲染（`_draw()` 只保留无法瓦片化的部分）。
- 树/房/栅栏/路灯作为瓦片物件落进 TileMapLayer，保持 `z_index = int(y)` y-sort 不被破坏。
- 保持 `_deco_static` 数组（自检 `size() > 20` 依赖它）与 `_obstacles` 碰撞不变。

### 批次 2：团子兽 / NPC / 主角贴图
- 重做 `tuanzi_art.gd` 的 `SPRITE_FOR`，换掉 3 张错误图。
- `actor.gd` / `battle_scene.gd` / `journal.gd` 的绘制路径同步。

### 批次 3：界面 UI
- `hud.gd` / `battle_menu.gd` / `journal.gd` / `appearance_panel.gd` 的 `StyleBoxFlat` 换 Kenney UI 九宫格与图标。

### 批次 4：门禁 + 交付
- 重新导出 `build/Tuanzi.exe`，跑完整门禁（自检 / stderr 洁净 / 启动存活）。
- 更新 `docs/acceptance.md`，提交并打 tag。

## 每批硬门禁
```
--headless --path . --import                       exit 0，0 条脚本错误
res://tests/self_check.tscn --quit-after 900       exit 0，137 通过 / 0 失败，ALL PASS
合并 stdout+stderr                                无 SCRIPT ERROR / Parse Error / Compile Error
```

## 素材许可
`kenney_tiny_town` License.txt = CC0 1.0（Kenney, 2023-11-01），符合项目白名单。
