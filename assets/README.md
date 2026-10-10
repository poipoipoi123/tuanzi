# assets 使用说明（README）

`assets/` 存放《团子/Tuanzi》的像素美术。**全部素材为 CC0 1.0**（许可白名单内），来源与许可见 [ATTRIBUTION.md](ATTRIBUTION.md)。

## 0. 通用导入设置（重要）

- `project.godot` 已设 `rendering/textures/canvas_textures/default_texture_filter=0`（**Nearest / 最近邻**），像素边缘保持锐利，**不需要**再逐个改 import。
- 所有 PNG 都是 **RGBA / 带 alpha**，Godot 4 默认即正确处理。
- **不要**用 Godot 的自动图集打包（AtlasTexture）除非需要；本文推荐的用法是「一个图集 + hframes/vframes」。
- **裁切/改名过的文件**已在 ATTRIBUTION 第 3 节列出（hero 三张、wild 八连、tileset 合成图）。

---

## 1. 主角团子兽（hero）

### 1.1 三张单帧贴图（代码默认查找路径）

| 文件 | 尺寸 | 帧数 | 排列 |
|---|---|---|---|
| `sprites/tuanzi_grass.png` | 56x58 | 1 | 单帧 |
| `sprites/tuanzi_water.png` | 52x60 | 1 | 单帧 |
| `sprites/tuanzi_spark.png` | 52x54 | 1 | 单帧 |

代码按 **PetDB id** 找贴图（见 `TuanziArt.SPRITE_FOR`）：grass / water / spark。**三张都是单帧，不需要 hframes/vframes**，直接 `draw_texture_rect(tex, Rect2(...), false)` 即可。贴图已按「脚底对齐」裁好，绘制时以底部中心为锚点。

### 1.2 角色选择用的三合一图集（可选）

`sprites/hero_tuanzi/tuanzi_sheet.png` — 192x64，**hframes = 3, vframes = 1**，每格 64x64，自左至右 grass / water / spark。

### 1.3 野外敌人图集

`sprites/enemies/tuanzi_wild_sheet.png` — 512x64，**hframes = 8, vframes = 1**，每格 64x64，8 只不同_blob（粉 / 绿 / 青 / 蓝 / 红 / 米 / 深绿 / 靛），可直接当野外团子兽。

---

## 2. 原始_blob 图集（备用池）

| 文件 | 尺寸 | 说明 |
|---|---|---|
| `sprites/battle_slimes32/slimes32_atlas.png` | 576x448 | 约 48 只 32x32 圆头_blob，非严格网格（间距不均）。若要整张当 atlas，需自行按连通块裁切 |
| `sprites/battle_slimes32/slimes32_atlas_alt.png` | 288x224 | 同上素材的 16x16 版本 |
| `sprites/battle_slimes32/shiny_invaders_atlas.png` | 382x134 | 小型入侵者，备用 |
| `sprites/creatures_tiny/crazy_critters_atlas.png` | 736x704 | 32x32 小怪（**无 alpha，RGB**） |
| `sprites/creatures_tiny/critters50_monochrome_32.png` | 214x279 | 单色小动物 |

---

## 3. NPC 村民

| 文件 | 尺寸 | 帧 / 排列 | Godot 建议 |
|---|---|---|---|
| `sprites/npc_villagers/fleurman_tiny_characters_set/All.png` | 288x204 | 24 个 3/4 侧脸村民，**6 列 x 4 行** | hframes=6, vframes=4 |
| `.../Females/F_01..F_12.png`、`.../Males/M_01..M_12.png` | 单个约 64x51 | 各 1 个角色，**已单独切好** | 直接单帧用，最省事 |
| `sprites/npc_villagers/atmanan_walking_character_set/Basic Character Set/Basic Char Set {Red,Blue,Green,Pink,White,Black}.png` | 384x512 | **4 行 x 3 列**，每行一个动作（行走循环），同角色 6 种配色 | 64x128 一格 → hframes=3, vframes=4；每行换 vframe 即换动作 |
| `sprites/npc_villagers/acasas_walk_sheet/.../Boy  sheet wlaking and Idle.png` | 640x640 | 64x64 一格，**4 列 x 8 行**（行走 + 待机） | hframes=4, vframes=8 |
| `sprites/npc_villagers/chicken/chicken*walk*.png` | 如 `chickenfrontwalkx4.png` 144x44 | **4 帧横向**（front / back / profile 各 4 帧） | hframes=4 |
| `sprites/npc_villagers/chicken/chicken*static*.png` | 单帧 | 1 帧 | 直接用 |
| `sprites/npc_villagers/chicken/chicken{front,back,profile}peck*.png` | 2 帧横向 | 2 帧啄食 | hframes=2 |
| `sprites/npc_villagers/chicken/chickenoriginal.png` | 82x35 | 单帧整只（原始尺寸） | 备用 |
| `sprites/npc_villagers/kenney_roguelike_characters.png` | 918x203 | 16x16 单格、**1px 间距** 的小角色表 | stride 17；作为静态 NPC 头像/小图 |
| `sprites/npc_villagers/kenney_pixelplatformer_characters.png` | 224x74 | 24x24 单格 | 静态小角色 |
| `sprites/npc_villagers/kenney_roguelike_rpg_sheet.png` | 968x526 | 16x16 单格、**1px 间距**（stride 17）的大合集，含室内家具 | 备用大图集 |
| `sprites/npc_villagers/tinyrpg_faces_ss01.png` | 800x1200 | 每方向 4 帧行走循环的整套角色 | 需要按 16px/格 + stride 17 切分 |
| `sprites/npc_villagers/tinyrpg_chars/20250303demoChar0*.png` | 288x192 | 3 个 ~48x48 角色，4 帧/方向 | 参考比例 |
| `sprites/npc_villagers/tinyrpg_faces/20250303demoFace0*.png` | 64x64 | 3 张头像 | 对话框头像 |

> **诚实缺口**：目前**没有**一套「同一像素比例、3-5 个村民、四方向行走」的开源素材。最接近的是 ATMANAN 单角色 6 配色 + Fleurman 24 个静态 3/4 侧脸 + acasas 单个 4x8 行走表。若要 3-5 个村民同时动，需按 acasas 网格裁切或对静态小人做整体位移。

---

## 4. 地砖 / Tileset

### 4.1 运行时用图（`WorldArt` 采样用）

`tiles/tileset.png` — **128x48**，即 **8 列 x 3 行**，每格 **16x16（`TILE_PX=16`）**、**格与格之间无间距**，可直接喂 Godot `TileSet`。

- **列顺序 = `WorldArt.TILE_NAMES`**：`grass | path | water | house | tree | stone | fence | lamp`。
- **行** = 同一地砖的 3 个随机变体（第 0 行=主、第 1/2 行=变体）。
- 单一纹理区域设 `texture_region_size = (16,16)`，`TileSet` 里给 8 个 atlas source，各取 3 个 tile；或直接按 `atlas_coords` 取 `(name_index, variant)`。

### 4.2 备选/扩展图集（原始 Kenney 图集，可再切）

| 文件 | 尺寸 | 网格 | 说明 |
|---|---|---|---|
| `tiles/kenney_tiny_town/tilemap_16x16.png` | 192x176 | 16px，**12 x 11 = 132 格，无间距** | 主素材来源：房屋/围栏/石头/门/窗/树桩 |
| `tiles/kenney_tiny_town/tilemap_16x16_spaced.png` | 203x186 | 16px，**1px 间距**（stride 17） | 带间距版，方便人眼索引 |
| `tiles/kenney_tiny_town/tiles/` | 132 个单张 png | 每张 16x16 | 已按格切好的单格文件 |
| `tiles/kenney_tiny_dungeon/tilemap_16x16.png` | 192x176 | 16px，12 x 11 | 地牢/火把/矿洞 |
| `tiles/kenney_tiny_battle/tilemap_16x16.png` | 288x176 | 16px，**18 x 11 = 198 格** | 战棋/水塘/草地边缘 |
| `tiles/kenney_roguelike_rpg/sheet_16x16.png` | 968x526 | 16px，**1px 间距（stride 17）**，约 57 x 31 | 树木/水/石头大合集 |
| `tiles/kenney_pixel_platformer/tilemap_18x18.png` | 360x162 | 18px，20 x 9 | 另一比例的图集 |
| `tiles/kenney_pixel_platformer/tilemap_backgrounds_24x24.png` | 192x72 | 24px，8 x 3 | 背景层 |
| `tiles/kenney_1bit/colored_16x16.png` | 832x373 | 16px，49 x 22 | 1-bit 大合集（彩色） |
| `tiles/kenney_pixel_shmup/tiles_16x16.png` | 192x160 | 16px，12 x 10 | 弹幕风地形 |
| `tiles/kenney_pixel_shmup/ships_32x32.png` | 128x192 | 32px，4 x 6 | 载具 |

---

## 5. UI

| 文件 | 尺寸 | 说明 |
|---|---|---|
| `ui/kenney_ui_rpg_expansion/uipack_rpg_sheet.png` (+ `uipack_rpg_sheet.xml`) | 512x512 | 圆角对话框底、按钮（长/方/圆，按下态）、进度条分段（红/黄/绿/蓝）、金币圈、箭头。XML 里有每块子图的 `name/x/y/width/height`，可直接查坐标 |
| `ui/kenney_ui_pixel_adventure/small_16x16_thick.png` / `small_16x16_thin.png` | 368x112 | 16px UI 元件，**23 列 x 7 行 = 161**，1px 间距 |
| `ui/kenney_ui_pixel_adventure/large_32x32_thick.png` / `large_32x32_thin.png` | 416x224 | 32px UI 元件，**13 列 x 7 行 = 91**，1px 间距 |

> `uipack_rpg_sheet.xml` 关键条目（512x512 图集内坐标）：
> - `buttonLong_brown.png` x=0 y=49 w=190 h=49；`buttonLong_brown_pressed.png` x=0 y=98 w=190 h=45
> - `buttonSquare_blue.png` x=290 y=0 w=45 h=49
> - `buttonRound_grey.png` x=335 y=0 w=35 h=38
> - `barRed_horizontalLeft/Mid/Right.png`（9/18/9 px 宽）配 `barBack_horizontal*` 拼成 HP 条
> - `coin`、`gem` 等圆形图标在图集右上部

---

## 6. 归档目录（有 `.gdignore`，不会被 Godot 导入 / 打包）

- `_originals/` — 每个包的**原始 zip / 原始 PNG**，用于追溯与二次切图。
- `_source_pages/` — 核验许可时抓下来的 OGA / Kenney **HTML 原件**。
- `_pages/` — 空占位。

---

## 7. 已知缺口（如实说明）

1. **无「同一比例、3-5 人、四方向行走」的村民包**（CC0 且许可明确）。现有替代是「1 个行走角色（6 配色）+ 24 个静态 3/4 小人 + 1 个 4x8 行走表」。
2. **鸡的 GIF 已转 PNG**：Godot 不能直接导入 GIF，21 个 GIF 已逐帧转成横向 PNG 序列（`hframes` = 帧数，见第 3 节）。
3. **`tiles/tileset.png` 的 lamp 列用的是「火把/灯笼」类小图元**（Tiny Dungeon 的火把 + Roguelike 的灯柱），Tiny Town 原包本身没有路灯砖，这是最接近的替代。
4. **`battle_slimes32` 原始合集非严格网格**（cell 间距不均），若要整张当 sprite sheet 用需按连通块自行裁切；已切好的 hero/wild 不受影响。
