extends Node2D
## 主控制器：管理世界 <-> 战斗的场景切换与全局快捷键。

var world: Node2D
var battle: Node2D
var _hud: CanvasLayer

func _ready() -> void:
    DisplayServer.window_set_title("团子 Tuanzi — 橡果小镇")
    _enter_world()

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

func _unhandled_input(e: InputEvent) -> void:
    if e.is_action_pressed("debug_save"):
        if GameState.save_game():
            if world != null:
                var hud := world.get_node_or_null("HUD")
                if hud != null and hud.has_method("toast"):
                    hud.toast("已存档")
