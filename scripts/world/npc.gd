extends Actor
## NPC：可对话的团子居民。在原地小范围游走或静止。

@export var npc_name: String = "村民团子"
@export var lines: Array[String] = []
@export var wander: bool = true
@export var wander_radius: float = 46.0

var _home := Vector2.ZERO
var _target := Vector2.ZERO
var _wait := 0.0
var _dir := Vector2.ZERO

func _ready() -> void:
    move_speed = randf_range(42.0, 64.0)
    _home = position
    _pick_target()
    super._ready()

func _pick_target() -> void:
    if wander:
        _target = _home + Vector2(
            randf_range(-wander_radius, wander_radius),
            randf_range(-wander_radius * 0.6, wander_radius * 0.6))
    else:
        _target = _home
    _wait = randf_range(1.0, 3.0)

func _npc_dir() -> Vector2:
    _wait -= get_physics_process_delta_time()
    if _wait > 0.0:
        return Vector2.ZERO
    var to := _target - position
    if to.length() < 6.0:
        _pick_target()
        return Vector2.ZERO
    return to.normalized()

func speak() -> String:
    if lines.is_empty():
        return "……"
    return lines[randi() % lines.size()]
