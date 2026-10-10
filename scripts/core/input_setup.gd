extends Node
## 在代码中注册全部输入动作，避免手写 project.godot 的 InputEvent 序列化。

const ACTIONS := {
    "move_left":  [KEY_A, KEY_LEFT],
    "move_right": [KEY_D, KEY_RIGHT],
    "move_up":    [KEY_W, KEY_UP],
    "move_down":  [KEY_S, KEY_DOWN],
    "interact":   [KEY_E, KEY_SPACE, KEY_ENTER],
    "cancel":     [KEY_ESCAPE, KEY_X],
    "menu":       [KEY_TAB, KEY_M],
    "appearance": [KEY_C],
    "sprint":     [KEY_SHIFT],
    "debug_save": [KEY_F5],
    # F9：读取存档。此前既没有绑定任何读取键，main.gd 也没有 load_game 调用点，
    # 所以「关闭后重开进度丢失」是必然结果，不是偶发。
    "debug_load": [KEY_F9],
}

func _enter_tree() -> void:
    for action in ACTIONS.keys():
        if not InputMap.has_action(action):
            InputMap.add_action(action, 0.2)
        for key in ACTIONS[action]:
            var ev := InputEventKey.new()
            ev.physical_keycode = key
            InputMap.action_add_event(action, ev)
