extends Node2D
## 回合制战斗场景：按速度排定出手顺序，逐次结算，带伤害飘字与镜头震动。
## 单位站位有前后景深：敌方在后（偏上、略小），我方在前（偏下、更大）。

signal battle_finished(result: String)   # "win" | "lose" | "flee"

# 站位（脚底坐标）
const FOE_ORIGIN := Vector2(858, 452)
const ALLY_ORIGIN := Vector2(432, 604)
const FOE_SCALE := 1.0
const ALLY_SCALE := 1.28
const MAX_ROUNDS := 60          # 防止双方持续治疗导致无限回合

var ally: Battler
var foe: Battler
var state := "intro"           # intro | choose | act | result
var _timer := 0.0
var _result := ""
var _round := 1
var _queue: Array = []
var _log: Array = []
var _floaters: Array = []
var _shake := 0.0
var _flash := 0.0
var _ally_anim := { "bob": 0.0, "hurt": 0.0, "mouth": 0.0, "lunge": 0.0 }
var _foe_anim := { "bob": 0.0, "hurt": 0.0, "mouth": 0.0, "lunge": 0.0 }
var _menu: Node = null
var _rng := RandomNumberGenerator.new()
var _configured := false

## 必须在 add_child 之前或之后尽早调用；会重置开场状态与日志。
func setup(wild_id: String, level: int, ally_id: String, ally_level: int) -> void:
    ally = Battler.new(ally_id, ally_level, 0)
    foe = Battler.new(wild_id, level, 1)
    GameState.mark_seen(wild_id)
    _configured = true
    _log.clear()
    _round = 1
    _queue.clear()
    _floaters.clear()
    _result = ""
    state = "intro"
    _timer = 1.0
    _push_log("野生的 %s 出现了！" % foe.data["name"])
    if _menu != null:
        _menu.visible = false

func _ready() -> void:
    _rng.randomize()
    if ally == null:
        var pid := GameState.active_pet()
        ally = Battler.new(pid, maxi(1, int(GameState.player["level"])), 0)
    if foe == null:
        foe = Battler.new("grass", 2, 1)
    # 我方血量取自伙伴存档状态（此前战斗的损耗会保留）
    if GameState.pet_state.has(ally.data["id"]):
        var st: Dictionary = GameState.pet_state[ally.data["id"]]
        ally.data["level"] = int(st.get("level", ally.data["level"]))
        ally.data["hp"] = clampi(int(st.get("hp", ally.data["hp"])), 1,
            int(ally.data["max_hp"]))
    if not _configured:
        _log.clear()
        _push_log("野生的 %s 出现了！" % foe.data["name"])
    _menu = preload("res://scripts/ui/battle_menu.gd").new()
    _menu.name = "BattleMenu"
    _menu.visible = false
    add_child(_menu)
    _menu.skill_chosen.connect(_on_skill_chosen)
    _menu.flee_chosen.connect(_on_flee)
    _menu.item_menu_requested.connect(_on_item_menu)
    _menu.capture_requested.connect(_on_capture_menu)
    state = "intro"
    if _timer <= 0.0:
        _timer = 1.0

func _push_log(s: String) -> void:
    _log.append(s)
    while _log.size() > 4:
        _log.pop_front()

func _process(delta: float) -> void:
    _timer -= delta
    _shake = maxf(0.0, _shake - delta * 24.0)
    _flash = maxf(0.0, _flash - delta * 2.2)
    for a in [_ally_anim, _foe_anim]:
        a["hurt"] = maxf(0.0, float(a["hurt"]) - delta * 2.6)
        a["bob"] = lerpf(float(a["bob"]), 0.0, delta * 7.0)
        a["mouth"] = lerpf(float(a["mouth"]), 0.0, delta * 6.0)
        a["lunge"] = lerpf(float(a["lunge"]), 0.0, delta * 9.0)
    var i := _floaters.size() - 1
    while i >= 0:
        var f: Dictionary = _floaters[i]
        f["age"] = float(f["age"]) + delta
        f["y"] = float(f["y"]) - delta * 48.0
        if float(f["age"]) > 1.1:
            _floaters.remove_at(i)
        i -= 1

    match state:
        "intro":
            if _timer <= 0.0:
                _begin_round()
        "act":
            if _timer <= 0.0:
                _step_queue()
        "result":
            if _timer <= 0.0:
                battle_finished.emit(_result)
    queue_redraw()

# —— 回合流程 ——

func _begin_round() -> void:
    if not foe.is_alive() or not ally.is_alive():
        _finish()
        return
    if _round > MAX_ROUNDS:
        _push_log("双方都累了，战斗平局收场。")
        _result = "flee"
        GameState.sync_pet_from_battle(String(ally.data["id"]), int(ally.data["level"]),
            int(ally.data["hp"]))
        GameState.save_game()
        state = "result"
        _timer = 1.2
        return
    state = "choose"
    _menu.visible = true
    _menu.refresh_for(ally)

func _build_queue(player_skill: String) -> Array:
    var pskill: Dictionary = SkillDB.get_skill(player_skill)
    var ids := foe.skill_ids()
    var fskill: Dictionary = SkillDB.get_skill(String(ids[_rng.randi() % ids.size()]))
    var entries: Array = [
        { "side": 0, "skill": pskill },
        { "side": 1, "skill": fskill },
    ]
    # 速度高者先手
    entries.sort_custom(func(a, b):
        var sa: int = int(ally.data["spd"]) if int(a["side"]) == 0 else int(foe.data["spd"])
        var sb: int = int(ally.data["spd"]) if int(b["side"]) == 0 else int(foe.data["spd"])
        return sa > sb)
    return entries

func _on_skill_chosen(skill_id: String) -> void:
    if state != "choose":
        return
    _menu.visible = false
    _queue = _build_queue(skill_id)
    state = "act"
    _timer = 0.25

func _on_flee() -> void:
    if state != "choose":
        return
    _menu.visible = false
    if _rng.randf() < 0.65:
        _push_log("成功脱离了战斗。")
        _result = "flee"
        state = "result"
        _timer = 0.9
    else:
        _push_log("没能逃掉！")
        var ids := foe.skill_ids()
        var sk: Dictionary = SkillDB.get_skill(String(ids[_rng.randi() % ids.size()]))
        _apply(1, sk)
        state = "act"
        _timer = 0.75

## 使用背包道具（战斗中）。只处理 heal / buff 两类。
func _on_item_used(item_id: String) -> void:
    if state != "choose":
        return
    var it: Dictionary = ItemDB.get_item(item_id)
    if it.is_empty() or not GameState.consume_item(item_id):
        _push_log("没有可用的 %s。" % ItemDB.get_item(item_id).get("name", item_id))
        return
    _menu.visible = false
    match String(it.get("type", "")):
        "heal":
            var h := ally.heal(int(it["power"]))
            _push_log("使用 %s，%s 恢复了 %d 点体力。" % [it["name"], ally.data["name"], h])
            _add_floater(0, "+%d" % h, Palette.HP_GREEN)
            GameState.play_sfx("heal")
        "buff":
            ally.data["atk"] = int(ally.data["atk"]) + int(it["power"])
            _push_log("使用 %s，攻击提升 %d 点。" % [it["name"], int(it["power"])])
        _:
            _push_log("%s 在这里派不上用场。" % it["name"])
    _queue = _build_queue("tackle")
    _queue.pop_front()          # 用道具消耗本回合行动
    state = "act"
    _timer = 0.6

## 尝试收服当前野生团子兽。
func _on_capture_attempt(item_id: String) -> void:
    if state != "choose":
        return
    if not GameState.consume_item(item_id):
        _push_log("没有 %s 了。" % item_id)
        return
    _menu.visible = false
    var it: Dictionary = ItemDB.get_item(item_id)
    var ball_power := int(it.get("power", 1))
    var gap := float(ally.data["level"]) - float(foe.data["level"])
    var ok := Capture.attempt(foe.hp_ratio(), ball_power, maxf(0.0, gap) * 0.05, _rng.randf())
    GameState.play_sfx("capture")
    if ok:
        _push_log("成功收服了 %s！" % foe.data["name"])
        var pid := String(foe.data["id"])
        if not GameState.party.has(pid):
            GameState.party.append(pid)
        GameState.pet_state[pid] = { "level": int(foe.data["level"]), "hp": int(foe.data["hp"]) }
        GameState.mark_seen(pid)
        _result = "win"
        GameState.save_game()
        state = "result"
        _timer = 1.4
    else:
        _push_log("%s 挣脱了！" % foe.data["name"])
        var ids := foe.skill_ids()
        _apply(1, SkillDB.get_skill(String(ids[_rng.randi() % ids.size()])))
        state = "act"
        _timer = 0.75

## 找出背包里第一个指定类型的可用道具 id。
func _first_item_of_type(t: String) -> String:
    for iid in GameState.inventory.keys():
        var it: Dictionary = ItemDB.get_item(String(iid))
        if String(it.get("type", "")) == t and int(GameState.inventory[iid]) > 0:
            return String(iid)
    return ""

## 道具按钮：优先回复类，其次增益类。
func _on_item_menu() -> void:
    var iid := _first_item_of_type("heal")
    if iid == "":
        iid = _first_item_of_type("buff")
    if iid == "":
        _push_log("背包里没有可用的道具。")
        return
    _on_item_used(iid)

## 收服按钮：投掷第一个捕捉类道具。
func _on_capture_menu() -> void:
    var iid := _first_item_of_type("capture")
    if iid == "":
        _push_log("没有捕捉道具，去商店看看吧。")
        return
    _on_capture_attempt(iid)

func _step_queue() -> void:
    if not ally.is_alive() or not foe.is_alive():
        _finish()
        return
    if _queue.is_empty():
        _round += 1
        _begin_round()
        return
    var e: Dictionary = _queue.pop_front()
    _apply(int(e["side"]), e["skill"] as Dictionary)
    state = "act"
    _timer = 0.78

func _apply(side: int, sk: Dictionary) -> void:
    var actor: Battler = ally if side == 0 else foe
    var target: Battler = foe if side == 0 else ally
    if not actor.is_alive():
        return
    var anim: Dictionary = _ally_anim if side == 0 else _foe_anim
    var t_anim: Dictionary = _foe_anim if side == 0 else _ally_anim
    anim["lunge"] = 16.0
    anim["mouth"] = 1.0

    if String(sk.get("type", "attack")) == "heal":
        var h := actor.heal(int(sk["power"]))
        _push_log("%s 使用了 %s，恢复 %d 点体力。" % [actor.data["name"], sk["name"], h])
        _add_floater(side, "+%d" % h, Palette.HP_GREEN)
        GameState.play_sfx("heal")
        return

    var dmg := Battler.compute_damage(actor.data, target.data, sk, _rng.randf())
    target.take_damage(dmg)
    t_anim["hurt"] = 1.0
    t_anim["bob"] = -10.0
    _shake = 7.0 if side == 0 else 5.0
    _flash = 0.5 if side == 0 else 0.0
    _push_log("%s 使用了 %s，造成 %d 点伤害。" % [actor.data["name"], sk["name"], dmg])
    _add_floater(1 - side, "-%d" % dmg, Palette.HP_RED)

func _add_floater(target_side: int, text: String, color: Color) -> void:
    var base := FOE_ORIGIN if target_side == 1 else ALLY_ORIGIN
    var p := Vector2(base.x, base.y - 118.0)
    _floaters.append({ "text": text, "color": color, "pos": p, "age": 0.0, "y": p.y })

func _finish() -> void:
    if not foe.is_alive():
        GameState.play_sfx("win")
        _result = "win"
        var exp_gain := 12 + int(foe.data["level"]) * 7
        var coin_gain := 10 + int(foe.data["level"]) * 4
        GameState.gain_exp(exp_gain)
        GameState.player["coins"] = int(GameState.player["coins"]) + coin_gain
        GameState.mark_seen(String(foe.data["id"]))
        _push_log("%s 倒下了！获得 %d 经验、%d 团子币。" % [
            foe.data["name"], exp_gain, coin_gain])
    elif not ally.is_alive():
        GameState.play_sfx("lose")
        _result = "lose"
        _push_log("小团子失去了战斗能力……")
    else:
        _result = "flee"
    # 血量写回伙伴状态
    GameState.sync_pet_from_battle(String(ally.data["id"]), int(ally.data["level"]),
        int(ally.data["hp"]))
    GameState.save_game()
    state = "result"
    _timer = 1.35

# —— 绘制 ——

func _draw() -> void:
    var vp := get_viewport_rect().size
    var off := Vector2.ZERO
    if _shake > 0.0:
        off = Vector2(_rng.randf_range(-_shake, _shake), _rng.randf_range(-_shake, _shake))

    # 天空与远景
    draw_rect(Rect2(Vector2.ZERO, vp), Palette.CREAM, true)
    draw_rect(Rect2(Vector2(0, vp.y * 0.52), Vector2(vp.x, vp.y * 0.48)),
        Palette.GRASS_DEEP, true)
    # 远山
    TuanziArt.ellipse(self, Vector2(240 + off.x, 430 + off.y), Vector2(360, 180),
        Palette.GRASS_DARK)
    TuanziArt.ellipse(self, Vector2(640 + off.x, 400 + off.y), Vector2(420, 200),
        Palette.GRASS_DARK)
    TuanziArt.ellipse(self, Vector2(1080 + off.x, 440 + off.y), Vector2(380, 190),
        Palette.GRASS_DARK)
    # 近景草坡
    TuanziArt.ellipse(self, Vector2(vp.x * 0.5 + off.x, 780 + off.y),
        Vector2(vp.x * 0.78, 240), Palette.GRASS)
    # 云朵
    for c in [Vector2(200, 120), Vector2(980, 96), Vector2(620, 74)]:
        TuanziArt.ellipse(self, c + off, Vector2(74, 30), Color(1, 1, 1, 0.75))
        TuanziArt.ellipse(self, c + Vector2(-34, 8) + off, Vector2(46, 22),
            Color(1, 1, 1, 0.65))

    # 敌方台座（后）
    TuanziArt.ellipse(self, FOE_ORIGIN + Vector2(0, 4) + off, Vector2(132, 40), Palette.PATH_DEEP)
    TuanziArt.ellipse(self, FOE_ORIGIN + off, Vector2(126, 36), Palette.PATH)
    # 我方台座（前）
    TuanziArt.ellipse(self, ALLY_ORIGIN + Vector2(0, 6) + off, Vector2(168, 50), Palette.PATH_DEEP)
    TuanziArt.ellipse(self, ALLY_ORIGIN + off, Vector2(160, 45), Palette.PATH)

    var t := Time.get_ticks_msec() / 1000.0

    # 单位（先敌后我，保证前后遮挡正确）
    if foe != null and foe.is_alive():
        TuanziArt.draw_tuanzi(self, FOE_ORIGIN + Vector2(-float(_foe_anim["lunge"]), 0) + off, {
            "scale": FOE_SCALE, "facing": -1.0,
            "bob": float(_foe_anim["bob"]), "leg": 0.0, "blink": 0.0,
            "mouth": float(_foe_anim["mouth"]), "hurt": float(_foe_anim["hurt"]),
            "phase": t * 0.55,
            "body": Color(String(foe.data["body"])), "edge": Color(String(foe.data["edge"])),
            "horn": Color(String(foe.data["horn"])),
        })
    if ally != null and ally.is_alive():
        TuanziArt.draw_tuanzi(self, ALLY_ORIGIN + Vector2(float(_ally_anim["lunge"]), 0) + off, {
            "scale": ALLY_SCALE, "facing": 1.0,
            "bob": float(_ally_anim["bob"]), "leg": 0.0, "blink": 0.0,
            "mouth": float(_ally_anim["mouth"]), "hurt": float(_ally_anim["hurt"]),
            "phase": t * 0.6 + 0.4,
            "body": Color(String(ally.data["body"])), "edge": Color(String(ally.data["edge"])),
            "horn": Color(String(ally.data["horn"])),
        })

    # 受击白光
    if _flash > 0.01:
        draw_rect(Rect2(Vector2.ZERO, vp), Color(1, 1, 1, _flash * 0.28), true)

    # 飘字
    var font := ThemeDB.fallback_font
    for f in _floaters:
        var a := clampf(1.0 - float(f["age"]) / 1.1, 0.0, 1.0)
        var s := String(f["text"])
        var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
        draw_string(font, Vector2(float(f["pos"].x) - w * 0.5, float(f["y"])), s,
            HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(Color(f["color"]), a))

    # 双方名牌血条
    _draw_hp_bar(Vector2(96, 92 + off.y), Vector2(300, 20), foe, "敌方")
    _draw_hp_bar(Vector2(vp.x - 396, 92 + off.y), Vector2(300, 20), ally, "我方")

    # 回合数
    draw_string(font, Vector2(vp.x * 0.5 - 40, 66), "第 %d 回合" % _round,
        HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.INK_SOFT)

    # 日志
    var ly := vp.y - 150.0
    for i in _log.size():
        var a2 := 0.40 + 0.60 * (float(i + 1) / float(_log.size()))
        draw_string(font, Vector2(40, ly + i * 27), String(_log[i]),
            HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Palette.INK, a2))

func _draw_hp_bar(pos: Vector2, size: Vector2, b: Battler, tag: String) -> void:
    if b == null:
        return
    var font := ThemeDB.fallback_font
    draw_rect(Rect2(pos, size).grow(3.0), Palette.PANEL_EDGE, true)
    draw_rect(Rect2(pos, size), Color(0.35, 0.30, 0.26, 0.35), true)
    var ratio := b.hp_ratio()
    if ratio > 0.0:
        draw_rect(Rect2(pos, Vector2(size.x * ratio, size.y)),
            Palette.HP_GREEN if ratio > 0.35 else Palette.HP_RED, true)
    var label := "%s  Lv.%d   %d/%d" % [b.data["name"], int(b.data["level"]),
        int(b.data["hp"]), int(b.data["max_hp"])]
    draw_string(font, pos + Vector2(0, -8), label,
        HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.INK)
    draw_string(font, pos + Vector2(size.x + 10, size.y - 3), tag,
        HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.INK_SOFT)
