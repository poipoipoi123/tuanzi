class_name WorldDeco
extends Node2D
## 世界装饰（树/房/灌木/栅栏/路灯/池塘）的一个实例。
## 为什么要从 world._draw() 搬出来成为真实子节点：
## Godot 的 y-sort 只在父子节点之间生效，父节点 _draw() 手绘的内容永远
## 先于所有子节点绘制，于是角色从树后经过时树不会盖住角色。
## 每个装饰独立成节点、并按 y 设置 z_index 后，前后遮挡才正确。

## 该装饰在世界坐标系里的 y（用于排序）；节点自身 position 固定为 (0, sort_y)。
var sort_y := 0.0

## 绘制参数。pos / from / to 均为相对于节点自身原点的局部坐标。
var spec: Dictionary = {}

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
    var t := float(Time.get_ticks_msec()) / 1000.0
    var kind := String(spec.get("kind", ""))
    match kind:
        "house":
            WorldArt.house(self, Vector2(spec["pos"]),
                float(spec["w"]), float(spec["h"]),
                Color(spec["wall"]), Color(spec["roof"]))
        "bush":
            WorldArt.bush(self, Vector2(spec["pos"]), float(spec["scale"]))
        "fence":
            WorldArt.fence(self, Vector2(spec["from"]), Vector2(spec["to"]))
        "lamp":
            WorldArt.lamp(self, Vector2(spec["pos"]),
                0.55 + sin(float(Time.get_ticks_msec()) / 900.0) * 0.45)
        "tree":
            _draw_tree(t)
        "pond":
            WorldArt.pond(self, Vector2(spec["pos"]),
                Vector2(float(spec["rx"]), float(spec["ry"])))

func _draw_tree(t: float) -> void:
    var p: Vector2 = spec["pos"]
    var sc := float(spec["scale"])
    # 贴图优先；tileset 缺失时回退到程序化绘制（SpriteLib.load_tex 返回 null）
    var tree_tex := SpriteLib.frame(
        SpriteLib.load_tex(WorldArt.tile_path("tree")),
        WorldArt.TILE_NAMES.find("tree"), WorldArt.TILE_NAMES.size())
    if tree_tex != null:
        var tp_px := float(WorldArt.TILE_PX) * 4.0 * sc
        draw_texture_rect(tree_tex,
            Rect2(p.x - tp_px * 0.5, p.y - tp_px, tp_px, tp_px), false)
    else:
        WorldArt.tree(self, p, sc, sin(t * 0.8 + float(spec["sway"])) * 0.6)
