extends Actor
## 玩家：小团子。读取输入、驱动动画、暴露交互目标。

signal interact_requested()

var can_move := true

func _ready() -> void:
    is_player = true
    body_color = Palette.TUANZI
    edge_color = Palette.TUANZI_EDGE
    horn_color = Palette.LEAF
    super._ready()

func _physics_process(delta: float) -> void:
    if can_move:
        var d := Vector2(
            Input.get_axis("move_left", "move_right"),
            Input.get_axis("move_up", "move_down"))
        set_input_dir(d)
    else:
        set_input_dir(Vector2.ZERO)
    super._physics_process(delta)

func _unhandled_input(e: InputEvent) -> void:
    if e.is_action_pressed("interact"):
        interact_requested.emit()
        get_viewport().set_input_as_handled()
