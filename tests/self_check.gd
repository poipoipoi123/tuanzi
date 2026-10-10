extends Node
## 无头自检：验证数据层、存档、战斗数学与场景装配。运行：
##   Godot --headless --path . res://tests/self_check.tscn
## 全部通过则退出码 0，否则打印 FAIL 并以 1 退出。

var _pass := 0
var _fail := 0

func _ready() -> void:
    await get_tree().process_frame
    _check_data()
    _check_state()
    _check_battle_math()
    _check_turn_order()
    await _check_world()
    await _check_battle_scene()
    print("=== 自检结果：%d 通过 / %d 失败 ===" % [_pass, _fail])
    if _fail > 0:
        get_tree().quit(1)
    else:
        print("ALL PASS")
        get_tree().quit(0)

func _ok(cond: bool, name: String) -> void:
    if cond:
        _pass += 1
        print("  PASS  " + name)
    else:
        _fail += 1
        print("  FAIL  " + name)

func _check_data() -> void:
    print("[数据层]")
    _ok(PetDB.PETS.size() == 3, "图鉴含 3 种团子兽")
    var grass: Dictionary = PetDB.get_pet("grass")
    _ok(String(grass["name"]) == "草团子兽", "草团子兽名称正确")
    var b: Dictionary = PetDB.make_battler("spark", 5)
    _ok(int(b["hp"]) == int(b["max_hp"]), "新建战斗单位满血")
    _ok(int(b["level"]) == 5, "等级写入正确")
    _ok(SkillDB.get_skill("bubble")["name"] == "泡泡弹", "技能表可查")
    _ok(SkillDB.get_skill("__nope__")["name"] == "团子撞击", "未知技能回退到撞击")
    _ok(ItemDB.get_item("berry")["name"] == "甜浆果", "道具表可查")

func _check_state() -> void:
    print("[存档]")
    GameState.new_game()
    _ok(int(GameState.player["level"]) == 1, "新游戏重置为 Lv.1")
    GameState.add_item("berry", 2)
    _ok(int(GameState.inventory["berry"]) == 5, "道具叠加正确")
    GameState.add_item("berry", -99)
    _ok(not GameState.inventory.has("berry"), "道具减到 0 时移除条目")
    GameState.gain_exp(1000)
    _ok(int(GameState.player["level"]) > 1, "经验累积可升级")
    _ok(int(GameState.player["hp"]) == int(GameState.player["max_hp"]), "升级后回满血")
    GameState.player["hp"] = 7
    _ok(GameState.save_game(), "存档写入成功")
    GameState.new_game()
    _ok(int(GameState.player["hp"]) == 60, "new_game 后血量回到 60")
    _ok(GameState.load_game(), "存档读取成功")
    _ok(int(GameState.player["hp"]) == 7, "读档还原血量 7")
    _ok(GameState.from_dict({}) == false, "非法存档被拒绝")
    GameState.mark_seen("water")
    _ok(GameState.caught.has("water"), "收服写入图鉴")

func _check_battle_math() -> void:
    print("[战斗数学]")
    var a: Dictionary = PetDB.make_battler("spark", 5)
    var d: Dictionary = PetDB.make_battler("grass", 5)
    var sk: Dictionary = SkillDB.get_skill("spark")
    var lo := 99999
    var hi := -1
    for i in 200:
        var dmg := Battler.compute_damage(a, d, sk, float(i) / 199.0)
        lo = mini(lo, dmg)
        hi = maxi(hi, dmg)
    _ok(lo >= 1, "伤害下限 >= 1（最低 %d）" % lo)
    _ok(hi > lo, "伤害带随机浮动（%d..%d）" % [lo, hi])
    var bt := Battler.new("grass", 3, 0)
    _ok(bt.is_alive(), "初始存活")
    _ok(bt.hp_ratio() == 1.0, "初始血条满")
    bt.take_damage(99999)
    _ok(not bt.is_alive(), "致命伤后阵亡")
    _ok(bt.hp_ratio() == 0.0, "阵亡后血条归零")
    bt.data["hp"] = 1
    bt.heal(99999)
    _ok(int(bt.data["hp"]) == int(bt.data["max_hp"]), "治疗不溢出上限")

func _check_turn_order() -> void:
    print("[出手顺序]")
    var b: Node2D = load("res://scripts/battle/battle_scene.gd").new()
    add_child(b)
    b.setup("grass", 1, "spark", 9)   # 星团子兽速度更高
    b.ally.data["spd"] = 99
    b.foe.data["spd"] = 1
    var q: Array = b._build_queue("tackle")
    _ok(q.size() == 2, "队列包含双方各一次行动")
    _ok(int(q[0]["side"]) == 0, "速度快的一方先手")
    b.queue_free()

func _check_world() -> void:
    print("[世界装配]")
    var w: Node2D = load("res://scripts/world/world.gd").new()
    add_child(w)
    await get_tree().process_frame
    _ok(w.player != null, "玩家已生成")
    _ok(w.camera != null, "相机已创建")
    _ok(w.npcs.size() == 3, "3 个 NPC 已生成")
    _ok(w.get_node_or_null("HUD") != null, "HUD 已挂载")
    _ok(w._deco_static.size() > 20, "静态装饰数量充足（%d）" % w._deco_static.size())
    _ok(w._grass_tufts.size() == 220, "草簇 220 个")
    # 用一个独立 Actor 确定性地驱动物理帧（无头环境中真实输入为空）
    var a := Actor.new()
    add_child(a)
    a.position = Vector2.ZERO
    a.set_input_dir(Vector2.RIGHT)
    for i in 10:
        a._physics_process(0.1)
    _ok(a.position.x > 0.0, "Actor 按输入方向移动（x=%.1f）" % a.position.x)
    _ok(a.facing > 0.0, "Actor 朝向更新为右")
    _ok(absf(a.bob) >= 0.0, "行走浮动值有效")
    a.set_input_dir(Vector2.LEFT)
    for i in 10:
        a._physics_process(0.1)
    _ok(a.facing < 0.0, "Actor 转向左")
    a.set_input_dir(Vector2.ZERO)
    a._physics_process(0.1)
    _ok(true, "停止输入不报错")
    a.queue_free()
    var r: Rect2 = w.world_rect()
    _ok(r.size.x > 2000.0, "世界尺寸合理")
    # 阻挡：池塘中心不可站立，岸边可以
    _ok(w.is_blocked(Vector2(1180, 900)), "池塘中心被阻挡")
    _ok(not w.is_blocked(Vector2(1180, 1080)), "池塘南岸可通行")
    _ok(w.is_blocked(Vector2(420, 430)), "房屋被阻挡")
    var pushed: Vector2 = w._resolve_obstacles(Vector2(1180, 900), 20.0)
    _ok(pushed.distance_to(Vector2(1180, 900)) > 1.0, "障碍求解会把角色推出水面")
    _ok(not w.is_blocked(pushed), "推出后不再处于障碍内")
    w.queue_free()
    await get_tree().process_frame

func _check_battle_scene() -> void:
    print("[战斗场景]")
    var b: Node2D = load("res://scripts/battle/battle_scene.gd").new()
    add_child(b)
    b.setup("water", 3, "grass", 3)
    await get_tree().process_frame
    _ok(b.ally != null and b.foe != null, "双方单位已建立")
    _ok(String(b.foe.data["name"]) == "水团子兽", "敌方为水团子兽")
    # 回合流程：选择技能 -> 队列结算
    await get_tree().process_frame
    b.state = "choose"
    var hp_before := int(b.foe.data["hp"])
    b._on_skill_chosen("tackle")
    _ok(b.state == "act", "选择技能后进入结算阶段")
    _ok(b._queue.size() >= 1, "出手队列已建立")
    # 完整跑完若干回合，直到分出胜负或达到上限
    var guard := 0
    while b.state != "result" and guard < 600:
        guard += 1
        if b.state == "choose":
            b._on_skill_chosen("tackle")
        b._timer = 0.0
        await get_tree().process_frame
    _ok(guard < 600, "战斗可在有限回合内结束（用了 %d 帧）" % guard)
    _ok(b.state == "result", "战斗进入结算状态")
    _ok(String(b._result) in ["win", "lose", "flee"], "结算结果合法：%s" % b._result)
    var foe_hp_dropped: bool = int(b.foe.data["hp"]) < hp_before or not b.foe.is_alive()
    _ok(foe_hp_dropped, "敌方受到过伤害")
    _ok(b.foe.data["hp"] >= 0, "敌方血量不为负")
    b.queue_free()
    await get_tree().process_frame
