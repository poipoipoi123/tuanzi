extends Node2D
## 主控制器：管理世界 <-> 战斗的场景切换与全局快捷键。

var world: Node2D
var battle: Node2D
var _hud: CanvasLayer

func _ready() -> void:
    get_window().title = "团子 Tuanzi — 橡果小镇"
    _enter_world()
    # 启动时自动读档：存档存在就恢复，否则保持新游戏状态。
    # 没有这一步，退出再打开永远是满血新档，等于没有存档功能。
    if GameState.has_save() and GameState.load_game():
        _toast("已读取存档")

func _enter_world() -> void:
    if battle != null and is_instance_valid(battle):
        battle.queue_free()
        battle = null
    world = preload("res://scripts/world/world.gd").new()
    world.name = "World"
    add_child(world)
    world.battle_requested.connect(_start_battle)

func _start_battle(wild_id: String, level: int) -> void:
    if battle != null:
        return
    if world != null:
        world.queue_free()
        world = null
    battle = preload("res://scripts/battle/battle_scene.gd").new()
    battle.name = "Battle"
    add_child(battle)
    var pid := "grass"
    if not GameState.party.is_empty():
        pid = String(GameState.party[0])
    battle.setup(wild_id, level, pid, maxi(1, int(GameState.player["level"])))
    battle.battle_finished.connect(_on_battle_finished)

func _on_battle_finished(result: String) -> void:
    _enter_world()
    if _pending_toast != "":
        _toast(_pending_toast)
        _pending_toast = ""
    var hud := world.get_node_or_null("HUD")
    if hud != null and hud.has_method("toast"):
        match result:
            "win":
                hud.toast("战斗胜利！获得经验与团子币。")
            "lose":
                hud.toast("小团子有点累了……回镇上歇歇吧。")
                GameState.player["hp"] = maxi(1, int(GameState.player["max_hp"]) / 3)
            _:
                hud.toast("安全撤退。")

var _pending_toast := ""

## 在世界场景里找 HUD 并弹提示；战斗期间没有 HUD，暂存到回城后显示。
func _toast(msg: String) -> void:
    if world != null and is_instance_valid(world):
        var hud := world.get_node_or_null("HUD")
        if hud != null and hud.has_method("toast"):
            hud.toast(msg)
            return
    _pending_toast = msg

func _unhandled_input(e: InputEvent) -> void:
    if e.is_action_pressed("debug_save"):
        if GameState.save_game():
            _toast("已存档")
        else:
            _toast("存档失败")
        get_viewport().set_input_as_handled()
    elif e.is_action_pressed("debug_load"):
        if not GameState.has_save():
            _toast("没有存档")
        elif GameState.load_game():
            _toast("已读取存档　Lv.%d　HP %d/%d　背包 %d 种" % [
                int(GameState.player["level"]), int(GameState.player["hp"]),
                int(GameState.player["max_hp"]), GameState.inventory.size()])
        else:
            _toast("存档读取失败")
        get_viewport().set_input_as_handled()
