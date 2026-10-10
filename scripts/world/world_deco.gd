class_name WorldDeco
extends Node2D
## 世界装饰（树/房/灌木/栅栏/路灯/池塘）的一个实例。
##
## 为什么要从 world._draw() 搬出来成为真实子节点：
## Godot 的 y-sort 只在父子节点之间生效，父节点 _draw() 手绘的内容永远
## 先于所有子节点绘制，于是角色从树后经过时树不会盖住角色。
## 每个装饰独立成节点、并按 y 设置 z_index 后，前后遮挡才正确。
##
## 地面（草地/土路/池塘）不在这里画：它已经由 tools/gen_ground.py 用
## Kenney 瓦片预合成成 ground_base.png，整张贴在 world 最底层。
##
## 该装饰在世界坐标系里的 y（用于排序）；节点自身 position 固定为 (0, sort_y)。
var sort_y := 0.0

## 绘制参数。pos / from / to 均为相对于节点自身原点的局部坐标。
var spec: Dictionary = {}

## 16px 素材按 2 倍放大显示，与 32px 地面格对齐。
const ART_SCALE := 2.0

## 房屋门面宽度（格）。
const HOUSE_W := 5

func _ready() -> void:
    # 池塘属于地面的一部分，固定压在最底层，不参与前后遮挡。
    if String(spec.get("kind", "")) == "pond":
        z_index = -1000
    else:
        z_index = int(sort_y)

func _process(_delta: float) -> void:
    # 树会摇曳，需要逐帧重绘；其它装饰是静态的。
    if String(spec.get("kind", "")) == "tree":
        queue_redraw()

func _draw() -> void:
    match String(spec.get("kind", "")):
        "house":
            _draw_house()
        "bush":
            _draw_bush()
        "fence":
            _draw_fence()
        "lamp":
            _draw_lamp()
        "tree":
            _draw_tree()
        "pond":
            pass   # 池塘已画进 ground_base.png，不重复画

## 贴一张 16px 瓦片（按 ART_SCALE 放大），底边落在 pos.y 上。
func _stamp(tex: Texture2D, pos: Vector2) -> void:
    if tex == null:
        return
    var s := float(WorldArt.TILE_PX) * ART_SCALE
    draw_texture_rect(tex, Rect2(pos.x - s * 0.5, pos.y - s, s, s), false)

func _draw_tree() -> void:
    var p: Vector2 = spec["pos"]
    # 树是两段式：上截树冠 + 下截树干，纵向无缝（见 WorldArt.TREE_PAIRS）。
    var pair := WorldArt.tree_tiles(int(spec.get("variant", 0)))
    var crown: Texture2D = pair[0]
    var trunk: Texture2D = pair[1]
    if crown == null and trunk == null:
        return
    var s := float(WorldArt.TILE_PX) * ART_SCALE
    # 只摆树冠、树干不动，避免接缝裂开。
    var sway := sin(float(Time.get_ticks_msec()) / 1000.0 * 0.8 + float(spec.get("sway", 0.0))) * 2.0
    if trunk != null:
        draw_texture_rect(trunk, Rect2(p.x - s * 0.5, p.y - s, s, s), false)
    if crown != null:
        draw_texture_rect(crown, Rect2(p.x - s * 0.5 + sway, p.y - s * 2.0, s, s), false)

func _draw_bush() -> void:
    # 四种小道具轮着摆：灌木 / 石头 / 花 / 草簇。
    var variant := int(spec.get("variant", 0))
    var pool := [
        WorldArt.PROP_BUSH,
        WorldArt.PROP_STONE,
        WorldArt.PROP_FLOWER,
        WorldArt.PROP_TUFT,
    ]
    _stamp(WorldArt.town_tile(pool[variant % pool.size()]), Vector2(spec["pos"]))

func _draw_house() -> void:
    # HOUSE_W 格宽、3 格高的门面：屋顶一排 / 墙体一排 / 带门的地基一排。
    # 每排的每一格都在 WorldArt 里写死，照抄即可，不做中段重复。
    var p: Vector2 = spec["pos"]
    var s := float(WorldArt.TILE_PX) * ART_SCALE
    var rows := WorldArt.house_tiles(int(spec.get("variant", 0)))
    var left := p.x - s * float(HOUSE_W) * 0.5
    for r in 3:
        var row: Array = rows[r]
        var y := p.y - s * float(3 - r)
        for i in mini(HOUSE_W, row.size()):
            var tex := WorldArt.town_tile(int(row[i]))
            if tex == null:
                continue
            draw_texture_rect(tex, Rect2(left + s * float(i), y, s, s), false)

func _draw_fence() -> void:
    # 沿两端点摆：中间用两侧出栏的连续段，两端用单侧出栏的收头。
    var a: Vector2 = spec["from"]
    var b: Vector2 = spec["to"]
    var s := float(WorldArt.TILE_PX) * ART_SCALE
    var mid := WorldArt.town_tile(WorldArt.FENCE_RAIL)
    var head := WorldArt.town_tile(WorldArt.FENCE_END_R)
    var tail := WorldArt.town_tile(WorldArt.FENCE_END_L)
    var post := WorldArt.town_tile(WorldArt.FENCE_POST)
    if mid == null:
        return
    var steps := maxi(1, int(round(a.distance_to(b) / s)))
    for i in steps + 1:
        var p := a.lerp(b, float(i) / float(steps))
        p.x -= s * 0.5
        p.y -= s
        var tex: Texture2D = mid
        if i == 0:
            tex = head if head != null else mid
        elif i == steps:
            tex = tail if tail != null else (post if post != null else mid)
        draw_texture_rect(tex, Rect2(p.x, p.y, s, s), false)

func _draw_lamp() -> void:
    _stamp(WorldArt.town_tile(WorldArt.PROP_LAMP), Vector2(spec["pos"]))
