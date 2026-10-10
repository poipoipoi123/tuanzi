# 阶段二补充计划：美术管线迁移到开源像素贴图

> **面向 AI 代理的工作者：** 本文件是 `2026-10-10-tuanzi-godot-phase2.md` 的**附加任务**，在原 8 个任务之外新增。用户 2026-10-10 决定把美术从纯 `_draw()` 程序化绘制改为**开源像素贴图**。

**素材许可白名单（硬约束）：** 只接受 **CC0 / CC-BY 4.0 / MIT / Apache-2.0**。**禁止** CC-BY-SA / GPL / CC-BY-NC / CC-BY-ND（传染性或限制性条款）。禁止任何与淘米 / 摩尔勇士相关的素材。每份素材必须登记在 `assets/ATTRIBUTION.md`。

**核心设计原则：渐进迁移 + 优雅回退。** 贴图缺失时 `_draw()` 程序化绘制仍然工作，所以任何时候都能跑起来、能过自检。这保证素材下载失败不会阻塞游戏开发。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| 创建 `scripts/core/sprite_lib.gd` | 贴图加载器：缓存 `Texture2D`、spritesheet 帧切片、缺图回退 |
| 创建 `scripts/core/pixel_palette.gd` | 像素色板：把 16 色索引贴图重着色为团子兽三通道配色（体/边/角） |
| 修改 `scripts/core/tuanzi_art.gd` | 绘制入口优先取贴图，缺图时回退 `_draw()` |
| 修改 `scripts/core/world_art.gd` | 场景装饰优先取 tileset 贴图 |
| 修改 `project.godot` | 开启 `rendering/textures/canvas_textures/nearest`（像素风必需，否则糊） |

---

### 任务 A：像素风渲染设置

**文件：** 修改 `project.godot`

- [ ] **步骤 1：在 `project.godot` 的 `[rendering]` 段增加**

```ini
textures/canvas_textures/default_texture_filter=0
```

  值 0 = Nearest（最近邻采样），这是像素风的关键。缺了它所有贴图会被双线性插值糊掉，像素游戏不能接受。
  **注意：不要动 `[application]` 段的应用名/config/name，也不要动 `run/main_scene`。**

- [ ] **步骤 2：验证**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：全部通过，退出码 0。

- [ ] **步骤 3：Commit**

```powershell
git add project.godot
git commit -m "feat: 启用最近邻采样以适配像素风"
```

---

### 任务 B：贴图加载器 SpriteLib

**文件：**
- 创建：`scripts/core/sprite_lib.gd`
- 测试：`tests/self_check.gd`（`_check_sprite_lib`）

class_name 用 `SpriteLib`，extends RefCounted，静态方法。

**API 设计（这是权威契约，后续任务依赖它）：**

```gdscript
class_name SpriteLib
extends RefCounted
## 贴图加载器：统一入口 + 缓存 + 缺图回退。贴图缺失时 has() 返回 false，
## 调用方应回退到程序化 _draw() 绘制。

const ASSET_ROOT := "res://assets/"

static var _cache: Dictionary = {}

## 贴图是否存在（不触发加载）。
static func has(path: String) -> bool:
    return ResourceLoader.exists(path)

## 加载并缓存一张贴图；不存在返回 null。
static func load_tex(path: String) -> Texture2D:
    if _cache.has(path):
        return _cache[path]
    if not ResourceLoader.exists(path):
        return null
    var t: Texture2D = load(path)
    _cache[path] = t
    return t

## 从 spritesheet 切出第 index 帧（水平排列）。
## hframes/vframes 在导入设置里已配好时直接用 region。
static func frame(tex: Texture2D, index: int, count: int) -> AtlasTexture:
    if tex == null or count <= 0:
        return null
    var w := int(tex.get_width() / count)
    var at := AtlasTexture.new()
    at.atlas = tex
    at.region = Rect2(index * w, 0, w, tex.get_height())
    return at

## 清空缓存（测试与热重载用）。
static func clear_cache() -> void:
    _cache.clear()
```

- [ ] **步骤 1：编写失败的测试**

在 `tests/self_check.gd` 的 `_ready()` 中新增 `_check_sprite_lib()` 调用（放在 `_check_data()` 之后），并新增：

```gdscript
func _check_sprite_lib() -> void:
    print("[贴图加载]")
    _ok(SpriteLib.load_tex("res://assets/__不存在__.png") == null, "缺图返回 null 而非报错")
    _ok(not SpriteLib.has("res://assets/__不存在__.png"), "has() 对缺图返回 false")
    _ok(SpriteLib.frame(null, 0, 4) == null, "frame(null,...) 返回 null")
    var icon: Texture2D = SpriteLib.load_tex("res://icon.svg")
    _ok(icon != null, "内置 icon.svg 可加载")
    _ok(SpriteLib.frame(icon, 1, 4) != null, "可切出第 1 帧")
    _ok(SpriteLib.frame(icon, 0, 4).region.size.x > 0, "帧区域宽度为正")
    SpriteLib.clear_cache()
    _ok(true, "清缓存不报错")
```

- [ ] **步骤 2：运行测试验证失败**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：FAIL，报 `Identifier "SpriteLib" not declared in the current scope`。

- [ ] **步骤 3：编写最少实现代码**

创建 `scripts/core/sprite_lib.gd`，内容即上面的 API 契约。

- [ ] **步骤 4：运行测试验证通过**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --import
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：PASS（110 + 8 = 118），末行 `ALL PASS`。

- [ ] **步骤 5：Commit**

```powershell
git add scripts/core/sprite_lib.gd tests/self_check.gd
git commit -m "feat: 贴图加载器与缺图回退"
```

---

### 任务 C：团子兽贴图接入 TuanziArt

**前置：** `assets/sprites/` 下已有贴图（若无，则本任务只接入骨架，回退逻辑生效，画面不变）。

**文件：**
- 修改：`scripts/core/tuanzi_art.gd`
- 测试：`tests/self_check.gd`（`_check_sprite_art`）

- [ ] **步骤 1：编写失败的测试**

```gdscript
func _check_sprite_art() -> void:
    print("[贴图美术]")
    var t := SpriteLib.load_tex(TuanziArt.SPRITE_FOR["grass"])
    _ok(t == null or t is Texture2D, "grass 贴图路径可安全查询")
    var fallback_ok := TuanziArt.has_sprite("grass")
    _ok(fallback_ok == TuanziArt.has_sprite("water"), "各团子兽查询行为一致")
    _ok(not TuanziArt.has_sprite("__不存在__"), "未知团子兽报告无贴图")
    var d := TuanziArt.sprite_path_for("spark")
    _ok(d.ends_with(".png"), "贴图路径后缀为 png：%s" % d)
```

- [ ] **步骤 2：运行测试验证失败**

预期：FAIL，报 `Invalid access to property or key 'SPRITE_FOR'` 或 `Identifier "SpriteLib" not declared`。

- [ ] **步骤 3：编写最少实现代码**

在 `scripts/core/tuanzi_art.gd` 顶部新增：

```gdscript
## 团子兽 id -> 贴图路径。素材缺失时 load_tex 返回 null，绘制自动回退程序化。
const SPRITE_FOR := {
    "grass": "res://assets/sprites/tuanzi_grass.png",
    "water": "res://assets/sprites/tuanzi_water.png",
    "spark": "res://assets/sprites/tuanzi_spark.png",
}

static func sprite_path_for(pet_id: String) -> String:
    return String(SPRITE_FOR.get(pet_id, "res://assets/sprites/tuanzi_missing.png"))

static func has_sprite(pet_id: String) -> bool:
    return SpriteLib.load_tex(sprite_path_for(pet_id)) != null

static func sprite_for(pet_id: String) -> Texture2D:
    return SpriteLib.load_tex(sprite_path_for(pet_id))
```

再在**现有绘制函数**的开头加回退分支（把原来的程序化绘制整体缩进到 `else` 里）：

```gdscript
var tex := sprite_for(pet_id)
if tex != null:
    draw_texture_rect(tex, Rect2(-w / 2.0, -h / 2.0, w, h), false)
else:
    # —— 以下为原有程序化绘制 ——
    ...（原代码原样保留）
```

**要点：** 现有 `_draw()` 里的程序化绘制代码一行都不要删，只是包进 `else` 分支。这样贴图到位自动切换，贴图没到位行为与现在完全一致。

- [ ] **步骤 4：运行测试验证通过**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --import
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：PASS（118 + 5 = 123），末行 `ALL PASS`。

- [ ] **步骤 5：Commit**

```powershell
git add scripts/core/tuanzi_art.gd tests/self_check.gd
git commit -m "feat: 团子兽接入像素贴图并保留程序化回退"
```

---

### 任务 D：场景 tileset 接入 WorldArt

**文件：**
- 修改：`scripts/core/world_art.gd`
- 测试：`tests/self_check.gd`（`_check_world_art_tiles`）

- [ ] **步骤 1：编写失败的测试**

```gdscript
func _check_world_art_tiles() -> void:
    print("[场景贴图]")
    _ok(WorldArt.TILE_PX == 16, "瓦片基准尺寸为 16px")
    for k in WorldArt.TILE_NAMES:
        _ok(String(k).length() > 0, "瓦片名 %s 非空" % k)
    var missing := WorldArt.missing_tiles()
    _ok(missing is Array, "missing_tiles 返回数组")
    _ok(WorldArt.tile_path("grass") != "", "grass 有路径定义")
```

- [ ] **步骤 2：运行测试验证失败**

预期：FAIL，报 `Identifier "WorldArt" not declared`（若已存在 class_name 则报 `Invalid access to property or key 'TILE_PX'`）。

- [ ] **步骤 3：编写最少实现代码**

在 `scripts/core/world_art.gd` 新增：

```gdscript
const TILE_PX := 16
const TILE_NAMES := ["grass", "path", "water", "house", "tree", "stone", "fence", "lamp"]
const TILESET := "res://assets/tiles/tileset.png"

static func tile_path(_name: String) -> String:
    return TILESET

## 返回当前缺失的瓦片名列表（空数组表示素材齐备）。
static func missing_tiles() -> Array:
    var out: Array = []
    for n in TILE_NAMES:
        if SpriteLib.load_tex(tile_path(n)) == null:
            out.append(n)
    return out
```

再把 `world.gd` 里现有装饰绘制同样加上 `if SpriteLib.load_tex(WorldArt.tile_path("tree")) != null:` 的贴图优先分支，否则保留程序化绘制。

- [ ] **步骤 4：运行测试验证通过**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --import
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：PASS（123 + 11 = 134），末行 `ALL PASS`。

- [ ] **步骤 5：Commit**

```powershell
git add scripts/core/world_art.gd scripts/world/world.gd tests/self_check.gd
git commit -m "feat: 场景接入 tileset 并保留程序化回退"
```

---

## 阶段二-素材 门禁

1. `self_check.tscn` 全绿（134 项）、退出码 0
2. `build/Tuanzi.exe` 导出并启动无错
3. `assets/ATTRIBUTION.md` 完整登记每份素材的名称、作者、来源 URL、许可证、下载日期
4. 所有素材许可证均在白名单内（CC0 / CC-BY 4.0 / MIT / Apache-2.0）
5. 无贴图时游戏仍可正常运行（程序化回退生效）

---

## 验收补充项

在 `docs/acceptance.md` 追加：

```markdown
## 阶段二素材补充
- [ ] 画面为像素风，贴图边缘清晰无插值模糊
- [ ] `assets/ATTRIBUTION.md` 列出的每份素材都能在来源页面找到对应许可证
- [ ] 删除 assets/ 下贴图后游戏仍能启动（程序化回退生效）
- [ ] 团子兽、NPC、场景装饰在贴图存在时显示为贴图，不存在时显示为程序化绘制
```
