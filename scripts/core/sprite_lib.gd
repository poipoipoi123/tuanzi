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
