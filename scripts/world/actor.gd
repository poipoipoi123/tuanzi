class_name Actor
extends Node2D
## 可移动的团子角色基类：玩家、NPC 共用。含行走动画、朝向、待机呼吸、眨眼。

@export var move_speed: float = 190.0
@export var is_player: bool = false

var facing: float = 1.0
var bob: float = 0.0
var leg: float = 0.0
var blink: float = 0.0
var mouth: float = 0.0
var hurt: float = 0.0
var phase: float = 0.0
var body_color := Palette.TUANZI
var edge_color := Palette.TUANZI_EDGE
var horn_color := Palette.LEAF

var _moving := false
var _blink_cd := 2.0
var _walk_clock := 0.0
var _input_dir := Vector2.ZERO

func _ready() -> void:
    phase = randf()
    _blink_cd = randf_range(1.5, 5.0)
    z_index = int(position.y)

func set_colors(b: Color, e: Color, h: Color) -> void:
    body_color = b
    edge_color = e
    horn_color = h
    queue_redraw()

func set_input_dir(d: Vector2) -> void:
    _input_dir = d.limit_length(1.0)

func _physics_process(delta: float) -> void:
    var dir := _input_dir
    if not is_player and dir == Vector2.ZERO:
        dir = _npc_dir()
    _moving = dir.length() > 0.05
    if _moving:
        position += dir * move_speed * delta
        if absf(dir.x) > 0.15:
            facing = signf(dir.x)
        _walk_clock += delta * 11.0
        leg = _walk_clock
        bob = -absf(sin(_walk_clock)) * 3.4
    else:
        leg = lerpf(leg, 0.0, delta * 8.0)
        bob = lerpf(bob, 0.0, delta * 8.0)
    phase += delta * 0.55
    z_index = int(position.y)

func _npc_dir() -> Vector2:
    return Vector2.ZERO

func _process(delta: float) -> void:
    _blink_cd -= delta
    if _blink_cd <= 0.0:
        blink = minf(1.0, blink + delta * 9.0)
        if blink >= 1.0:
            blink = 0.0
            _blink_cd = randf_range(2.0, 6.0)
    hurt = maxf(0.0, hurt - delta * 2.4)
    mouth = lerpf(mouth, 0.0, delta * 5.0)
    queue_redraw()

func _draw() -> void:
    TuanziArt.draw_tuanzi(self, Vector2.ZERO, {
        "scale": 1.0, "facing": facing, "bob": bob, "leg": leg,
        "blink": blink, "mouth": mouth, "hurt": hurt, "phase": phase,
        "body": body_color, "edge": edge_color, "horn": horn_color,
    })

func get_radius() -> float:
    return 26.0

## 当前是否正在移动（供脚步声等外部逻辑只读查询）。
func is_moving() -> bool:
    return _moving
