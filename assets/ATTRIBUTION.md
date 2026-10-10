# assets 素材来源与许可清单（ATTRIBUTION）

本文件记录 `assets/` 目录下**每一项被采用的素材**的原始名称、作者、原始页面地址、许可证名称与链接、下载日期，以及在本项目中的落盘路径。

- 许可白名单（仅这四种可用）：**CC0 1.0** / **CC-BY 4.0** / **MIT** / **Apache-2.0**
- 明确禁用：CC-BY-SA、GPL、LGPL、CC-BY-NC、CC-BY-ND、OGA-BY 3.0、许可混合、许可不明、无来源页面。
- 凡白名单之外的素材一律标为「**不采用**」，并**不放在运行期目录**（见文末「不采用 / 已排除」表）。
- 全部素材下载日期：**2026-06-14**（同一批次完成）。
- 运行期目录：`assets/sprites/`、`assets/tiles/`、`assets/ui/`。归档目录 `_originals/`（原始 zip / 原始 PNG）、`_source_pages/`（用于核验许可的原始网页 HTML）、`_pages/`（空）内已放置 `.gdignore`，Godot 不会导入、不会打进 `build/Tuanzi.exe`。

---

## 1. Kenney 系列（全部 CC0 1.0，作者 Kenney）

来源站点：<https://kenney.nl/assets>。每个 zip 内均自带 `License.txt`，内容为
「Created/distributed by Kenney (www.kenney.nl) / License: (Creative Commons Zero, CC0) http://creativecommons.org/publicdomain/zero/1.0/」。
许可证链接：<http://creativecommons.org/publicdomain/zero/1.0/>

| # | 素材名 | 作者 | 原始页面 | 许可证 | 下载日期 | 落盘路径 |
|---|---|---|---|---|---|---|
| 1 | Tiny Town | Kenney | <https://kenney.nl/assets/tiny-town> | CC0 1.0 | 2026-06-14 | `tiles/kenney_tiny_town/` |
| 2 | Tiny Dungeon | Kenney | <https://kenney.nl/assets/tiny-dungeon> | CC0 1.0 | 2026-06-14 | `tiles/kenney_tiny_dungeon/` |
| 3 | Tiny Battle | Kenney | <https://kenney.nl/assets/tiny-battle> | CC0 1.0 | 2026-06-14 | `tiles/kenney_tiny_battle/` |
| 4 | Roguelike / RPG Pack | Kenney | <https://kenney.nl/assets/roguelike-rpg-pack> | CC0 1.0 | 2026-06-14 | `tiles/kenney_roguelike_rpg/`、`sprites/npc_villagers/kenney_roguelike_rpg_sheet.png` |
| 5 | Roguelike Characters | Kenney | <https://kenney.nl/assets/roguelike-characters> | CC0 1.0 | 2026-06-14 | `sprites/npc_villagers/kenney_roguelike_characters*.png` |
| 6 | Pixel Platformer | Kenney | <https://kenney.nl/assets/pixel-platformer> | CC0 1.0 | 2026-06-14 | `tiles/kenney_pixel_platformer/`、`sprites/npc_villagers/kenney_pixelplatformer_characters.png` |
| 7 | Pixel Shmup | Kenney | <https://kenney.nl/assets/pixel-shmup> | CC0 1.0 | 2026-06-14 | `tiles/kenney_pixel_shmup/` |
| 8 | 1-Bit Pack | Kenney | <https://kenney.nl/assets/1-bit-pack> | CC0 1.0 | 2026-06-14 | `tiles/kenney_1bit/` |
| 9 | UI Pack: Pixel Adventure | Kenney | <https://kenney.nl/assets/ui-pack-pixel-adventure> | CC0 1.0 | 2026-06-14 | `ui/kenney_ui_pixel_adventure/` |
| 10 | UI Pack: RPG Expansion | Kenney | <https://kenney.nl/assets/ui-pack-rpg-expansion> | CC0 1.0 | 2026-06-14 | `ui/kenney_ui_rpg_expansion/` |

## 2. OpenGameArt 系列（全部 CC0 1.0）

每一项都在其**自己的** `https://opengameart.org/content/<slug>` 页面上核对了许可区块（`creativecommons.org/publicdomain/zero/1.0`）与作者字段（`field-name-author-submitter`）。核验用的 HTML 原件保存在 `_source_pages/`。
许可证链接：<http://creativecommons.org/publicdomain/zero/1.0/>

| # | 素材名 | 作者 | 原始页面 | 许可证 | 发布日期 | 下载日期 | 落盘路径 |
|---|---|---|---|---|---|---|---|
| 11 | 32x32 Colorful Slimes | AndHeGames | <https://opengameart.org/content/32x32-colorful-slimes> | CC0 1.0 | 2019-05-03 | 2026-06-14 | `sprites/battle_slimes32/slimes32_atlas*.png`；**并切出 `sprites/tuanzi_grass.png`、`tuanzi_water.png`、`tuanzi_spark.png`、`sprites/hero_tuanzi/tuanzi_sheet.png`、`sprites/enemies/tuanzi_wild_sheet.png`** |
| 12 | Crazy Critters | GrafxKid | <https://opengameart.org/content/crazy-critters> | CC0 1.0 | 2020-02-21 | 2026-06-14 | `sprites/creatures_tiny/crazy_critters_atlas.png` |
| 13 | 50 Monochrome 32x32 Critters | gaymoo | <https://opengameart.org/content/50-monochrome-32-by-32-critters-cc0> | CC0 1.0 | 2022-04-22 | 2026-06-14 | `sprites/creatures_tiny/critters50_monochrome_32.png` |
| 14 | Shiny and Cute Invaders | Master484 | <https://opengameart.org/content/shiny-and-cute-invaders> | CC0 1.0 | 2025-03-17 | 2026-06-14 | `sprites/battle_slimes32/shiny_invaders_atlas.png` |
| 15 | Frog, Dog, Cat & Pig 2D Pixel 16x16 | davidcrybao | <https://opengameart.org/content/frog-dogcatpig2d-pixel-1616> | CC0 1.0 | 2023-08-16 | 2026-06-14 | `_originals/oga_frog_dog_cat_pig.png` |
| 16 | Tiny RPG CC0 Characters and Portraits | tiopalada | <https://opengameart.org/content/tiny-rpg-cc0-characters-and-portraits> | CC0 1.0 | 2025-03-04 | 2026-06-14 | `sprites/npc_villagers/tinyrpg_chars/`、`tinyrpg_faces/`、`tinyrpg_faces_ss01.png` |
| 17 | Chicken Sprites | Shepardskin | <https://opengameart.org/content/chicken-sprites> | CC0 1.0 | 2014-02-11 | 2026-06-14 | `sprites/npc_villagers/chicken/*.png`（原为 21 个 GIF，已逐帧转成横向 PNG 序列，见 README） |
| 18 | Tiny Characters Set | Fleurman | <https://opengameart.org/content/tiny-characters-set> | CC0 1.0 | 2017-02-16 | 2026-06-14 | `sprites/npc_villagers/fleurman_tiny_characters_set/` |
| 19 | Walking Character Set | ATMANAN | <https://opengameart.org/content/walking-character-set> | CC0 1.0 | 2022-09-09 | 2026-06-14 | `sprites/npc_villagers/atmanan_walking_character_set/` |
| 20 | Pixel Art Character | acasas | <https://opengameart.org/content/pixel-art-character> | CC0 1.0 | 2016-11-04 | 2026-06-14 | `sprites/npc_villagers/acasas_walk_sheet/` |
| 21 | Chibi Base | thecilekli | <https://opengameart.org/content/chibi-base> | CC0 1.0 | 2020-11-09 | 2026-06-14 | `sprites/npc_villagers/thecilekli_chibi_base/`（只保留 2 张小预览图，见「不采用」说明） |
| 22 | Tiny Creatures（演示截图拼版） | Clint Bellanger | <https://opengameart.org/content/tiny-creatures> | CC0 1.0 | 2024-03-18 | 2026-06-14 | `_originals/oga_tiny_creatures_*.png`（800x450 演示拼版，仅作比例参考，不作游戏素材） |

## 3. 本项目自制的合成图（derivative work，仅由上表 CC0 素材裁切/拼接而成）

| 文件 | 构成 | 说明 |
|---|---|---|
| `sprites/tuanzi_grass.png` | 「32x32 Colorful Slimes」中裁切单只绿色史莱姆 | 单一帧 56x58，Godot 直接 `draw_texture_rect`，**无需 hframes** |
| `sprites/tuanzi_water.png` | 同上，蓝色系 | 单一帧 52x60 |
| `sprites/tuanzi_spark.png` | 同上，黄褐/暖色系 | 单一帧 52x54 |
| `sprites/hero_tuanzi/tuanzi_sheet.png` | 上面 3 张按 64x64 格横向排列（hframes=3） | 便于一次导入做角色选择界面 |
| `sprites/enemies/tuanzi_wild_sheet.png` | 同图集内 8 只不同 blob，64x64 一格横排（hframes=8） | 野外团子兽敌人 |
| `tiles/tileset.png` | 从 Kenney Tiny Town / Roguelike RPG / Tiny Dungeon 三张 CC0 图集中各挑 3 张 16x16 地砖，合成 **8 列 x 3 行** | 列顺序 = `WorldArt.TILE_NAMES`：grass / path / water / house / tree / stone / fence / lamp |

---

## 不采用 / 已排除（许可不在白名单）

下列素材**已核实许可并主动排除**，一律**没有**下载、**没有**放进 `sprites/`、`tiles/`、`ui/`。对应的 HTML 快照留在 `_source_pages/` 仅为留下「查过、否掉」的痕迹。

| 素材 | 作者 | 原始页面 | 许可 | 排除原因 |
|---|---|---|---|---|
| The Jumping Blob | magdum | <https://opengameart.org/content/the-jumping-blob> | CC-BY-SA 3.0 | ShareAlike，不在白名单 |
| Tiny Fox and Dog Characters | Spring Spring | <https://opengameart.org/content/tiny-fox-and-dog-characters> | CC-BY 3.0/4.0 + CC-BY-SA 3.0/4.0（混合授权） | 含 SA 条目，整包不采用 |
| Tiny 16 More Character Animations | — | <https://opengameart.org/content/tiny-16-more-character-animations> | CC-BY 3.0 | 许可版本不在白名单（仅允许 CC-BY 4.0） |
| Tiny Hero Sprites Pixel Art | CraftPix | <https://opengameart.org/content/tiny-hero-sprites-pixel-art> | OGA-BY 3.0 | OGA 自有许可，不在白名单 |
| Top-down RPG Slime Creatures | CraftPix | <https://opengameart.org/content/top-down-rpg-slime-creatures-pixel-art> | OGA-BY 3.0 | 同上 |
| Monsters: Slime, Skeleton and Goblin | — | <https://opengameart.org/content/monsters-slime-skeleton-and-goblin> | CC-BY 4.0 | 虽在白名单，但与已选素材风格重复、来源页描述含糊，主动不用（保守起见） |

---

**CC0 1.0 全文**：<http://creativecommons.org/publicdomain/zero/1.0/> —— 素材可商用、可修改、无需署名（本项目仍在 ATTRIBUTION 中署名）。
**Kenney 主页**：<https://kenney.nl/> —— 每个 zip 内含原始 `License.txt`，已随包复制到对应子目录。
