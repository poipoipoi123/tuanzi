class_name WorldArt
extends RefCounted
## 场景装饰绘制库：草地、树木、池塘、房屋、栅栏、路灯。
## 优先使用 tileset 贴图；贴图缺失时回退到程序化绘制。

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

static func grass_tuft(canvas: CanvasItem, base: Vector2, h: float, tint: float) -> void:
    var c := Palette.GRASS_DARK.lerp(Palette.LEAF, clampf(tint, 0.0, 1.0))
    for i in 3:
        var dx := (i - 1) * 3.4
        var tip := base + Vector2(dx * 0.9, -h * (1.0 - absf(i - 1) * 0.18))
        canvas.draw_line(base + Vector2(dx, 0), tip, c, 2.0, true)

static func tree(canvas: CanvasItem, base: Vector2, scale_v: float, sway: float) -> void:
    var s := scale_v
    TuanziArt.ground_shadow(canvas, base, 28.0 * s, 0.16)
    # 树干
    canvas.draw_rect(Rect2(base.x - 5.0 * s, base.y - 46.0 * s, 10.0 * s, 48.0 * s),
        Palette.BARK, true)
    canvas.draw_rect(Rect2(base.x - 5.0 * s, base.y - 46.0 * s, 4.0 * s, 48.0 * s),
        Palette.BARK.darkened(0.18), true)
    # 树冠：三层圆球
    var top := base + Vector2(sway * 3.0 * s, -52.0 * s)
    TuanziArt.ellipse(canvas, top + Vector2(-16.0 * s, 6.0 * s),
        Vector2(20.0 * s, 17.0 * s), Palette.LEAF_DEEP)
    TuanziArt.ellipse(canvas, top + Vector2(16.0 * s, 8.0 * s),
        Vector2(19.0 * s, 16.0 * s), Palette.LEAF_DEEP)
    TuanziArt.ellipse(canvas, top + Vector2(0, -4.0 * s),
        Vector2(24.0 * s, 20.0 * s), Palette.LEAF)
    TuanziArt.ellipse_shine(canvas, top + Vector2(-6.0 * s, -8.0 * s),
        Vector2(20.0 * s, 16.0 * s), 0.30)

static func bush(canvas: CanvasItem, base: Vector2, scale_v: float) -> void:
    var s := scale_v
    TuanziArt.ground_shadow(canvas, base, 22.0 * s, 0.13)
    TuanziArt.ellipse(canvas, base + Vector2(-11.0 * s, -8.0 * s),
        Vector2(14.0 * s, 12.0 * s), Palette.GRASS_DARK)
    TuanziArt.ellipse(canvas, base + Vector2(11.0 * s, -7.0 * s),
        Vector2(13.0 * s, 11.0 * s), Palette.GRASS_DARK)
    TuanziArt.ellipse(canvas, base + Vector2(0, -14.0 * s),
        Vector2(17.0 * s, 14.0 * s), Palette.LEAF)
    TuanziArt.ellipse_shine(canvas, base + Vector2(-4.0 * s, -18.0 * s),
        Vector2(14.0 * s, 11.0 * s), 0.25)

static func pond(canvas: CanvasItem, center: Vector2, radii: Vector2) -> void:
    TuanziArt.ellipse(canvas, center + Vector2(0, 3),
        radii + Vector2(6, 6), Palette.PATH_DEEP)
    TuanziArt.ellipse(canvas, center, radii, Palette.WATER_DEEP)
    TuanziArt.ellipse(canvas, center + Vector2(0, -2), radii * Vector2(0.94, 0.92),
        Palette.WATER)
    # 水波
    for i in 3:
        var t := float(i) / 3.0
        canvas.draw_arc(center + Vector2(-radii.x * 0.3 + t * radii.x * 0.6, -radii.y * 0.2),
            radii.x * 0.22, deg_to_rad(200), deg_to_rad(340), 12,
            Color(1, 1, 1, 0.34), 1.6, true)

static func house(canvas: CanvasItem, base: Vector2, w: float, h: float,
        wall_c: Color, roof_c: Color) -> void:
    TuanziArt.ground_shadow(canvas, base + Vector2(0, 2), w * 0.62, 0.18)
    # 墙体
    canvas.draw_rect(Rect2(base.x - w * 0.5, base.y - h, w, h), wall_c, true)
    canvas.draw_rect(Rect2(base.x - w * 0.5, base.y - h, w * 0.22, h),
        wall_c.darkened(0.06), true)
    # 屋顶（梯形 + 檐口）
    var rh := h * 0.52
    var over := w * 0.14
    var pts := PackedVector2Array([
        Vector2(base.x - w * 0.5 - over, base.y - h),
        Vector2(base.x + w * 0.5 + over, base.y - h),
        Vector2(base.x + w * 0.34, base.y - h - rh),
        Vector2(base.x - w * 0.34, base.y - h - rh),
    ])
    canvas.draw_colored_polygon(pts, roof_c)
    canvas.draw_line(Vector2(base.x - w * 0.5 - over, base.y - h),
        Vector2(base.x + w * 0.5 + over, base.y - h), roof_c.darkened(0.22), 3.0, true)
    canvas.draw_line(pts[2], pts[3], roof_c.lightened(0.16), 3.0, true)
    # 门与窗
    var door_w := w * 0.26
    canvas.draw_rect(Rect2(base.x - door_w * 0.5, base.y - h * 0.46, door_w, h * 0.46),
        Palette.WOOD, true)
    TuanziArt.ellipse(canvas, Vector2(base.x + door_w * 0.28, base.y - h * 0.22),
        Vector2(1.6, 1.6), Palette.GOLD)
    var win := w * 0.20
    for side_f in [-1.0, 1.0]:
        var side: float = side_f
        var wx: float = base.x + side * w * 0.28
        var wy: float = base.y - h * 0.60
        canvas.draw_rect(Rect2(wx - win * 0.5 - 2, wy - win * 0.5 - 2, win + 4, win + 4),
            Palette.WOOD, true)
        canvas.draw_rect(Rect2(wx - win * 0.5, wy - win * 0.5, win, win),
            Palette.SKY.lightened(0.20), true)
        canvas.draw_line(Vector2(wx, wy - win * 0.5), Vector2(wx, wy + win * 0.5),
            Palette.WOOD, 1.6, true)

static func fence(canvas: CanvasItem, from: Vector2, to: Vector2) -> void:
    var n := maxi(1, int(from.distance_to(to) / 26.0))
    for i in range(n + 1):
        var p := from.lerp(to, float(i) / float(n))
        canvas.draw_line(p, p + Vector2(0, -22), Palette.WOOD, 4.0, true)
    canvas.draw_line(from + Vector2(0, -18), to + Vector2(0, -18), Palette.WOOD, 3.0, true)
    canvas.draw_line(from + Vector2(0, -8), to + Vector2(0, -8), Palette.WOOD, 3.0, true)

static func lamp(canvas: CanvasItem, base: Vector2, glow: float) -> void:
    TuanziArt.ground_shadow(canvas, base, 10.0, 0.16)
    canvas.draw_rect(Rect2(base.x - 2.5, base.y - 54, 5, 54), Palette.INK_SOFT, true)
    TuanziArt.ellipse(canvas, base + Vector2(0, -60), Vector2(11, 12), Palette.INK_SOFT)
    TuanziArt.ellipse(canvas, base + Vector2(0, -60), Vector2(8, 9),
        Palette.GOLD.lerp(Color.WHITE, clampf(glow, 0.0, 1.0) * 0.55))
    TuanziArt.ellipse(canvas, base + Vector2(0, -63), Vector2(12, 13),
        Color(Palette.GOLD, 0.12 * glow))
