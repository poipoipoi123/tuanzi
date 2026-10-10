extends Node

## 一次性截图探针：加载主场景，在几个机位各截一张 PNG。
## 只在本地人工验收时用，跑完即删。
const SHOTS := [
    {"name": "shot_plaza_w.png", "pos": Vector2(520, 560)},   # 镇中心广场（两栋房）
    {"name": "shot_pond.png", "pos": Vector2(1180, 800)},    # 池塘 + 丁字路
    {"name": "shot_plaza_e.png", "pos": Vector2(1780, 640)},   # 东侧大宅 + 花圃栅栏
    {"name": "shot_woods.png", "pos": Vector2(980, 320)},     # 林地（多棵树）
]
const WARMUP := 40
const HOLD := 12
var _frames := 0
var _main: Node = null

func _ready() -> void:
    _main = load("res://scenes/main.tscn").instantiate()
    add_child(_main)

func _process(_delta: float) -> void:
    _frames += 1
    if _frames <= WARMUP:
        return
    if _main == null:
        return
    var world := _main.get_node_or_null("World")
    if world == null or world.player == null or world.camera == null:
        return
    # 关掉相机平滑，否则截图时机对不上玩家位置。
    world.camera.position_smoothing_enabled = false
    var slot := (_frames - WARMUP) / HOLD
    var phase := (_frames - WARMUP) % HOLD
    if slot >= SHOTS.size():
        get_tree().quit()
        return
    var s: Dictionary = SHOTS[slot]
    world.player.position = s["pos"]
    world.camera.global_position = s["pos"]
    # 每个机位的最后一帧才存图，此时画面已经稳定。
    if phase != HOLD - 1:
        return
    var img := get_viewport().get_texture().get_image()
    img.save_png("res://.tmp/" + String(s["name"]))
    print("SHOT_SAVED %s %dx%d" % [s["name"], img.get_width(), img.get_height()])
