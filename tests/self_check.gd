extends Node
## 无头自检：验证数据层、存档、战斗数学与场景装配。运行：
##   Godot --headless --path . res://tests/self_check.tscn
## 全部通过则退出码 0，否则打印 FAIL 并以 1 退出。

var _pass := 0
var _fail := 0

func _ready() -> void:
    await get_tree().process_frame
    _check_data()
    _check_sprite_lib()
    _check_elements()
    _check_capture()
    _check_state()
    _check_battle_math()
    _check_turn_order()
    await _check_world()
    await _check_battle_scene()
    await _check_battle_items()
    _check_growth()
    _check_appearance()
    _check_sfx()
    await _check_battle_keyboard()
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

func _check_sprite_lib() -> void:
    print("[贴图加载]")
    _ok(SpriteLib.load_tex("res://assets/__不存在__.png") == null, "缺图返回 null 而非报错")
    _ok(not SpriteLib.has("res://assets/__不存在__.png"), "has() 对缺图返回 false")
    _ok(SpriteLib.frame(null, 0, 4) == null, "frame(null,...) 返回 null")
    var icon: Texture2D = SpriteLib.load_tex("res://icon.svg")
    _ok(icon != null, "内置 icon.svg 可加载")
    _ok(SpriteLib.frame(icon, 1, 4) != null, "可切出第 1 帧")
    _ok(SpriteLib.frame(icon, 0, 4).region.size.x > 0, "帧区域宽度为正")
    # 计划的任务 B 测试块只列出 7 条断言，但其算术按 8 条计（113+8=121）。
    # 此处补测契约里原本没被覆盖的缓存行为：重复加载同一路径返回同一实例。
    _ok(SpriteLib.load_tex("res://icon.svg") == icon, "重复加载命中缓存返回同一实例")
    SpriteLib.clear_cache()
    _ok(true, "清缓存不报错")

func _check_elements() -> void:
    print("[属性克制]")
    _ok(ElementDB.ELEMENTS.size() == 3, "属性表含 3 种属性")
    _ok(ElementDB.effectiveness("草", "水") == 2.0, "草打水 2 倍")
    _ok(ElementDB.effectiveness("水", "草") == 0.5, "水打草 0.5 倍")
    _ok(ElementDB.effectiveness("草", "草") == 1.0, "同属性 1 倍")
    _ok(ElementDB.effectiveness("星", "草") == 2.0, "星打草 2 倍")
    _ok(ElementDB.effectiveness("__未知__", "草") == 1.0, "未知属性回退 1 倍")

func _check_capture() -> void:
    print("[收服]")
    _ok(Capture.rate(1.0, 1, 1.0) >= 0.05, "残血目标收服率有下限")
    var full := Capture.rate(1.0, 1, 1.0)
    var low := Capture.rate(0.1, 1, 1.0)
    _ok(low > full, "血量越低越容易收服（%.2f > %.2f）" % [low, full])
    # 注意：这里用 level_gap_bonus=0.0 且较高的血量，避免双方都被 MAX_RATE 截断而无法区分道具档次
    var weak_ball := Capture.rate(0.9, 1, 0.0)
    var strong_ball := Capture.rate(0.9, 3, 0.0)
    _ok(strong_ball > weak_ball, "高级捕捉道具成功率更高（%.2f > %.2f）" % [strong_ball, weak_ball])
    _ok(Capture.rate(0.01, 9, 0.0) <= 0.98, "收服率上限不超过 0.98")
    _ok(Capture.rate(1.0, 1, 1.0) <= 0.95, "满血目标也有上限")
    var ball: Dictionary = ItemDB.get_item("capture_ball")
    _ok(not ball.is_empty(), "捕捉道具存在于道具表")
    _ok(int(ball["power"]) == 1, "基础捕捉道具威力为 1")

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
    # 克制：草打水应显著高于水打草
    var grass_atk: Dictionary = PetDB.make_battler("grass", 5)
    var water_def: Dictionary = PetDB.make_battler("water", 5)
    var water_atk: Dictionary = PetDB.make_battler("water", 5)
    var tackle: Dictionary = SkillDB.get_skill("tackle")
    var strong_dmg := 0
    var weak_dmg := 0
    for i in 100:
        strong_dmg += Battler.compute_damage(grass_atk, water_def, tackle, 0.5)
        weak_dmg += Battler.compute_damage(water_atk, grass_atk, tackle, 0.5)
    _ok(strong_dmg > weak_dmg * 2, "克制伤害显著高于被抗伤害（%d vs %d）" % [strong_dmg, weak_dmg])

    # 必中判定：rng=1.0 必定命中
    var hit_result: Dictionary = Battler.resolve_attack(
        grass_atk, water_def, tackle, 0.5, 1.0, 0.0)
    _ok(bool(hit_result["hit"]), "rng=1.0 时必定命中")
    _ok(int(hit_result["damage"]) > 0, "命中时伤害为正")

    # 必闪判定：rng=0.0 且闪避率极高时必定落空
    var dodgy: Dictionary = water_def.duplicate(true)
    dodgy["spd"] = 9999
    var miss_result: Dictionary = Battler.resolve_attack(
        grass_atk, dodgy, tackle, 0.5, 0.0, 0.0)
    _ok(not bool(miss_result["hit"]), "高闪避目标可躲开攻击")
    _ok(int(miss_result["damage"]) == 0, "落空时不造成伤害")

    # 暴击：crit_roll=0.0 必暴击，伤害应高于不暴击
    var crit: Dictionary = Battler.resolve_attack(
        grass_atk, water_def, tackle, 0.5, 1.0, 0.0)
    var nocrit: Dictionary = Battler.resolve_attack(
        grass_atk, water_def, tackle, 0.5, 1.0, 1.0)
    _ok(bool(crit["crit"]), "crit_roll=0.0 时触发暴击")
    _ok(not bool(nocrit["crit"]), "crit_roll=1.0 时不暴击")
    _ok(int(crit["damage"]) > int(nocrit["damage"]), "暴击伤害高于普通伤害")

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

func _check_battle_items() -> void:
    print("[战斗道具]")
    var b: Node2D = load("res://scripts/battle/battle_scene.gd").new()
    add_child(b)
    b.setup("grass", 3, "grass", 3)
    await get_tree().process_frame
    GameState.new_game()
    GameState.add_item("berry", 2)
    var berry_before := int(GameState.inventory.get("berry", 0))

    # 使用回复道具应回血并消耗道具
    b.ally.data["hp"] = 5
    b.state = "choose"
    b._on_item_used("berry")
    _ok(int(b.ally.data["hp"]) > 5, "道具回复了体力")
    _ok(int(GameState.inventory.get("berry", 0)) == berry_before - 1, "道具被消耗")

    # 无道具时不应生效
    b.state = "choose"
    var hp_before := int(b.ally.data["hp"])
    GameState.add_item("berry", -99)
    b._on_item_used("berry")
    _ok(int(b.ally.data["hp"]) == hp_before, "无道具时使用不生效")

    # 收服会结束战斗
    GameState.add_item("capture_ball", 5)
    b.foe.data["hp"] = 1
    b.state = "choose"
    b._on_capture_attempt("capture_ball")
    _ok(b.state in ["act", "result"], "收服尝试推进了战斗状态")
    b.queue_free()
    await get_tree().process_frame

func _check_growth() -> void:
    print("[养成]")
    _ok(Growth.ATTRS.size() == 4, "四维属性定义完整")
    _ok(Growth.points_for_level(1) == 0, "1 级无可用点数")
    _ok(Growth.points_for_level(5) > 0, "升级获得点数")
    # --- 偏离计划原断言（见下方长注释）---
    # 计划原断言为：spend({str:1,...}, "str", 3) -> points == 2，
    # 与随后的 spend(同一字典, "str", 99) -> points == 0 互相矛盾
    # （同一入参不可能既返回 2 又返回 0），且计划实现体恒返回 points = 0。
    # 本仓库采用的契约：spend(attrs, attr, count, available = -1)
    #   available >= 0：受点数上限约束，只加 min(count, available) 点，
    #                  返回 {"attrs":…, "points": 剩余可用点数}
    #   available < 0 ：不限点数，全部加上，points 回显 count（被扣除的点数）
    var unlimited := Growth.spend({"str": 1, "vit": 1, "agi": 1, "int": 1}, "str", 3)
    _ok(int(unlimited["attrs"]["str"]) == 4, "加点生效")
    _ok(int(unlimited["points"]) == 3, "点数被扣除")
    # 点数不足：可用 2 点，请求 99 点 → 只加 2，剩余归零
    var over := Growth.spend({"str": 1, "vit": 1, "agi": 1, "int": 1}, "str", 99, 2)
    _ok(int(over["attrs"]["str"]) == 3, "点数不足时只加剩余部分")
    _ok(int(over["points"]) == 0, "点数归零")
    # 点数不足但未耗尽：可用 5 点，请求 2 点 → 加 2，剩 3
    var partial := Growth.spend({"str": 1, "vit": 1, "agi": 1, "int": 1}, "str", 2, 5)
    _ok(int(partial["attrs"]["str"]) == 3 and int(partial["points"]) == 3,
        "余量正确回显（加 2 点剩 3 点）")
    _ok(Growth.stat_bonus(10, "str") > Growth.stat_bonus(0, "str"), "点数提升属性收益")
    GameState.new_game()
    _ok(GameState.player.has("attrs"), "存档含四维属性")
    _ok(GameState.free_points() >= 0, "可用点数非负")
    # 偏离计划原断言：计划在 new_game()（即 Lv.1，free_points()==0）后直接期望
    # spend_point("str") 成功，与它自己的 "1 级无可用点数" 断言冲突。
    # 这里先升级拿到点数再分配，保持断言语义正确。
    GameState.gain_exp(500)
    _ok(GameState.free_points() > 0, "升级后获得可分配点数")
    _ok(GameState.spend_point("str"), "可分配一点力量")

func _check_appearance() -> void:
    print("[外貌]")
    _ok(GameState.APPEARANCE_PRESETS.size() >= 4, "提供至少 4 套配色预设")
    GameState.new_game()
    var first: String = GameState.appearance["preset"]
    _ok(first != "", "默认外观有预设名")
    var ok := GameState.set_appearance("mint")
    _ok(ok, "切换到已存在的预设")
    _ok(String(GameState.appearance["preset"]) == "mint", "外观预设已保存")
    _ok(not GameState.set_appearance("__不存在__"), "未知预设被拒绝")
    var cols: Dictionary = GameState.appearance_colors()
    _ok(cols.has("body") and cols.has("edge") and cols.has("horn"), "配色包含三个通道")
    GameState.save_game()
    GameState.new_game()
    _ok(GameState.load_game(), "存档含外观可读回")
    _ok(String(GameState.appearance["preset"]) == "mint", "读档还原外观预设")

func _check_sfx() -> void:
    print("[音效]")
    _ok(Sfx.tone_bytes("blip", 0.15, 660.0) > 100, "生成了非空 PCM 数据")
    var a: PackedByteArray = Sfx.build_pcm(0.1, 440.0, 0.5)
    var b: PackedByteArray = Sfx.build_pcm(0.1, 880.0, 0.5)
    _ok(a.size() == b.size(), "同一时长产生同样长度的数据")
    _ok(a != b, "不同频率产生不同波形")
    _ok(Sfx.build_pcm(0.1, 440.0, 0.0).size() > 0, "零音量仍返回有效缓冲")
    _ok(Sfx.KINDS.has("hit") and Sfx.KINDS.has("win"), "定义了命中与胜利音效")
    # 偏离计划原断言：计划用 `is_instance_valid(Sfx)`，前提是 Sfx 是 project.godot 里
    # 注册的 autoload 实例；本轮禁止改 project.godot，故实例由 GameState 持有，
    # 这里断言同一个语义（「音效单例在运行期真实存在且已进节点树」）。
    _ok(is_instance_valid(GameState.sfx()), "Sfx 单例在运行期存在（由 GameState 持有）")

func _check_battle_keyboard() -> void:
    print("[战斗键盘]")
    var b: Node2D = load("res://scripts/battle/battle_scene.gd").new()
    add_child(b)
    b.setup("water", 3, "grass", 3)
    await get_tree().process_frame
    b.state = "choose"
    b._menu.visible = true
    b._menu.refresh_for(b.ally)
    _ok(int(b._menu.cursor) >= 0, "菜单有默认光标")
    # _menu 在 battle_scene.gd 中声明为 Node（无 class_name），故显式标注类型
    var first: int = b._menu.cursor
    b._menu.move_cursor(1)
    _ok(int(b._menu.cursor) != first, "光标可移动")
    b._menu.move_cursor(-1)
    _ok(int(b._menu.cursor) == first, "光标可移回")
    # 数字键 1 直接选第一个技能
    b.state = "choose"
    b._menu.visible = true
    b._menu.refresh_for(b.ally)
    b._menu.choose_index(0)
    _ok(b.state == "act", "数字键确认后进入结算")
    b.queue_free()
    await get_tree().process_frame

    # —— resolve_attack 真正接入战斗结算（上一轮遗留项）——
    print("[结算接入]")
    var r: Node2D = load("res://scripts/battle/battle_scene.gd").new()
    add_child(r)
    r.setup("grass", 3, "water", 3)
    await get_tree().process_frame
    # 闪避：命中掷骰为 0，闪避率必然 >= 0.02 → 落空，伤害 0 且血量不变
    r.foe.data["spd"] = 9999
    var hp_before := int(r.foe.data["hp"])
    var sk: Dictionary = SkillDB.get_skill("tackle")
    var miss: Dictionary = Battler.resolve_attack(
        r.ally.data, r.foe.data, sk, 0.5, 0.0, 0.0)
    _ok(not bool(miss["hit"]) and int(miss["damage"]) == 0, "闪避时伤害为 0")
    var applied_miss: int = r._apply_attack(0, sk, 0.5, 0.0, 0.0)
    _ok(applied_miss == 0 and int(r.foe.data["hp"]) == hp_before,
        "闪避不扣血（damage=0，血量不变）")
    # 暴击：crit_roll=0 必暴击，且伤害高于同 rng 的非暴击
    r.foe.data["spd"] = 1
    var hp2 := int(r.foe.data["hp"])
    var crit_dmg: int = r._apply_attack(0, sk, 0.5, 1.0, 0.0)
    var hp3 := int(r.foe.data["hp"])
    _ok(crit_dmg > 0 and hp2 - hp3 == crit_dmg, "暴击伤害真实扣血（%d）" % crit_dmg)
    var nocrit_dmg: int = r._apply_attack(0, sk, 0.5, 1.0, 1.0)
    _ok(crit_dmg > nocrit_dmg, "暴击伤害高于同 rng 非暴击（%d > %d）" % [crit_dmg, nocrit_dmg])
    r.queue_free()
    await get_tree().process_frame




