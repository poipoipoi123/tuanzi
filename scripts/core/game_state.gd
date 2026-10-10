extends Node
## 全局游戏状态：玩家、背包、队伍、图鉴、存档。autoload 单例。

# 存档路径由 SavePaths 动态解析（便携优先、自动回退）

## 外观配色预设：body / edge / horn 三个通道（HEX 字符串，便于存进 JSON 存档）。
const APPEARANCE_PRESETS := {
    "classic": { "name": "经典白", "body": "fff6e8", "edge": "e8b48a", "horn": "6fbf5f" },
    "mint":    { "name": "薄荷绿", "body": "d8f5d0", "edge": "8fce80", "horn": "4f9d46" },
    "sakura":  { "name": "樱花粉", "body": "ffe0e6", "edge": "f0a8b8", "horn": "e07f8c" },
    "sky":     { "name": "晴空蓝", "body": "dcefff", "edge": "9ec9f0", "horn": "7fb3e0" },
    "honey":   { "name": "蜂蜜黄", "body": "fff3d0", "edge": "e8c86a", "horn": "d9b24e" },
}

signal state_changed
signal item_gained(item_id: String, count: int)
signal level_up(new_level: int)

var player := {
    "name": "小团子",
    "level": 1,
    "exp": 0,
    "hp": 60,
    "max_hp": 60,
    "atk": 12,
    "def": 10,
    "spd": 10,
    "coins": 120,
    "star_dust": 3,
    "attrs": { "str": 0, "vit": 0, "agi": 0, "int": 0 },
    "spent_points": 0,
}

var inventory := { "berry": 3, "honey": 1 }
var party := ["grass"]          # 已收服团子兽
var pet_state := {}             # 伙伴团子兽状态：{ id: {level, hp} }
var seen: Array = []            # 图鉴：已见
var caught: Array = []          # 图鉴：已收服
var flags := {}                 # 剧情开关
var appearance := { "preset": "classic" }   # 外观：{ preset: 预设 id }
var play_seconds := 0.0

func _ready() -> void:
    randomize()
    if pet_state.is_empty():
        _ensure_pet_state()

func _ensure_pet_state() -> void:
    for pid in party:
        if not pet_state.has(pid):
            var b: Dictionary = PetDB.make_battler(String(pid), maxi(1, int(player["level"])))
            pet_state[pid] = { "level": int(b["level"]), "hp": int(b["max_hp"]) }

## 当前出战伙伴 id。
func active_pet() -> String:
    if party.is_empty():
        return "grass"
    return String(party[0])

func exp_to_next(level: int) -> int:
    return 20 + int(level * 14)

func gain_exp(amount: int) -> void:
    player["exp"] = int(player["exp"]) + maxi(0, amount)
    var guard := 0
    while int(player["exp"]) >= exp_to_next(int(player["level"])) and guard < 99:
        player["exp"] = int(player["exp"]) - exp_to_next(int(player["level"]))
        player["level"] = int(player["level"]) + 1
        player["max_hp"] = int(player["max_hp"]) + 8
        player["hp"] = int(player["max_hp"])
        player["atk"] = int(player["atk"]) + 2
        player["def"] = int(player["def"]) + 2
        player["spd"] = int(player["spd"]) + 1
        level_up.emit(int(player["level"]))
        guard += 1
    state_changed.emit()

## 当前可分配点数 = 升级应得 - 已花费
func free_points() -> int:
    return maxi(0, Growth.points_for_level(int(player["level"]))
        - int(player.get("spent_points", 0)))

## 分配一点属性，并按四维重算战斗数值。
func spend_point(attr: String) -> bool:
    if free_points() <= 0 or not Growth.ATTRS.has(attr):
        return false
    var attrs: Dictionary = player.get("attrs", {})
    var res: Dictionary = Growth.spend(attrs, attr, 1, free_points())
    player["attrs"] = res["attrs"]
    player["spent_points"] = int(player.get("spent_points", 0)) + 1
    _apply_derived()
    state_changed.emit()
    return true

## 用四维属性覆盖派生数值（不碰当前血量上限以外的字段）。
func _apply_derived() -> void:
    var d: Dictionary = Growth.derive_at(player.get("attrs", {}), int(player["level"]))
    player["atk"] = int(d["atk"])
    player["def"] = int(d["def"])
    player["spd"] = int(d["spd"])
    var new_max := int(d["max_hp"])
    if new_max != int(player["max_hp"]):
        player["max_hp"] = new_max
        player["hp"] = mini(int(player["hp"]), new_max)

func set_appearance(preset: String) -> bool:
    if not APPEARANCE_PRESETS.has(preset):
        return false
    appearance["preset"] = preset
    state_changed.emit()
    return true

func appearance_colors() -> Dictionary:
    var p: Dictionary = APPEARANCE_PRESETS.get(
        String(appearance.get("preset", "classic")), APPEARANCE_PRESETS["classic"])
    return { "body": String(p["body"]), "edge": String(p["edge"]), "horn": String(p["horn"]) }

func appearance_name() -> String:
    var p: Dictionary = APPEARANCE_PRESETS.get(String(appearance.get("preset", "classic")), {})
    return String(p.get("name", "经典白"))

func add_item(item_id: String, count: int = 1) -> void:
    if count == 0:
        return
    inventory[item_id] = maxi(0, int(inventory.get(item_id, 0)) + count)
    if inventory[item_id] <= 0:
        inventory.erase(item_id)
    item_gained.emit(item_id, count)
    state_changed.emit()

func consume_item(item_id: String) -> bool:
    if int(inventory.get(item_id, 0)) <= 0:
        return false
    add_item(item_id, -1)
    return true

func heal(amount: int) -> int:
    var before := int(player["hp"])
    player["hp"] = mini(int(player["max_hp"]), before + maxi(0, amount))
    state_changed.emit()
    return int(player["hp"]) - before

func mark_seen(pet_id: String) -> void:
    if not seen.has(pet_id):
        seen.append(pet_id)
    if not caught.has(pet_id):
        caught.append(pet_id)
        add_item("star_dust", 1)
    state_changed.emit()

func to_dict() -> Dictionary:
    return {
        "version": 1,
        "saved_at": Time.get_datetime_string_from_system(),
        "play_seconds": play_seconds,
        "player": player.duplicate(true),
        "inventory": inventory.duplicate(true),
        "party": party.duplicate(),
        "pet_state": pet_state.duplicate(true),
        "seen": seen.duplicate(),
        "caught": caught.duplicate(),
        "flags": flags.duplicate(true),
        "appearance": appearance.duplicate(true),
    }

func from_dict(d: Dictionary) -> bool:
    if typeof(d) != TYPE_DICTIONARY or not d.has("player"):
        return false
    var p: Variant = d.get("player")
    if typeof(p) != TYPE_DICTIONARY:
        return false
    for k in player.keys():
        if p.has(k):
            player[k] = p[k]
    player["hp"] = clampi(int(player["hp"]), 0, int(player["max_hp"]))
    if not player.has("attrs"):
        player["attrs"] = { "str": 0, "vit": 0, "agi": 0, "int": 0 }
    if not player.has("spent_points"):
        player["spent_points"] = 0
    _apply_derived()
    var inv: Variant = d.get("inventory", {})
    if typeof(inv) == TYPE_DICTIONARY:
        inventory = (inv as Dictionary).duplicate(true)
    party = _as_string_array(d.get("party", party))
    seen = _as_string_array(d.get("seen", seen))
    caught = _as_string_array(d.get("caught", caught))
    var f: Variant = d.get("flags", {})
    if typeof(f) == TYPE_DICTIONARY:
        flags = (f as Dictionary).duplicate(true)
    play_seconds = float(d.get("play_seconds", play_seconds))
    var ps: Variant = d.get("pet_state", {})
    if typeof(ps) == TYPE_DICTIONARY:
        pet_state = (ps as Dictionary).duplicate(true)
    var ap: Variant = d.get("appearance", {})
    if typeof(ap) == TYPE_DICTIONARY and (ap as Dictionary).has("preset"):
        var pid_ap := String((ap as Dictionary)["preset"])
        if APPEARANCE_PRESETS.has(pid_ap):
            appearance["preset"] = pid_ap
    _ensure_pet_state()
    state_changed.emit()
    return true

func _as_string_array(v: Variant) -> Array:
    var out: Array = []
    if typeof(v) == TYPE_ARRAY:
        for x in (v as Array):
            out.append(str(x))
    return out

func save_game() -> bool:
    var path: String = SavePaths.save_path()
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        push_warning("存档写入失败：%s" % path)
        return false
    f.store_string(JSON.stringify(to_dict(), "  "))
    f.close()
    return true

func has_save() -> bool:
    return FileAccess.file_exists(SavePaths.save_path())

func load_game() -> bool:
    if not has_save():
        return false
    var f := FileAccess.open(SavePaths.save_path(), FileAccess.READ)
    if f == null:
        return false
    var txt := f.get_as_text()
    f.close()
    var parsed: Variant = JSON.parse_string(txt)
    if typeof(parsed) != TYPE_DICTIONARY:
        return false
    return from_dict(parsed as Dictionary)

func export_save() -> String:
    var path: String = SavePaths.export_path()
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        return ""
    f.store_string(JSON.stringify(to_dict(), "  "))
    f.close()
    return ProjectSettings.globalize_path(path)

## 伙伴满血恢复（镇上休息/道具）。
func heal_pet(amount: int = 999999) -> void:
    _ensure_pet_state()
    var pid := active_pet()
    var st: Dictionary = pet_state[pid]
    var b: Dictionary = PetDB.make_battler(pid, int(st["level"]))
    st["hp"] = mini(int(b["max_hp"]), int(st["hp"]) + amount)
    state_changed.emit()

func pet_hp() -> int:
    _ensure_pet_state()
    var st: Dictionary = pet_state[active_pet()]
    var b: Dictionary = PetDB.make_battler(active_pet(), int(st["level"]))
    return clampi(int(st["hp"]), 0, int(b["max_hp"]))

func pet_max_hp() -> int:
    _ensure_pet_state()
    var st: Dictionary = pet_state[active_pet()]
    return int(PetDB.make_battler(active_pet(), int(st["level"]))["max_hp"])

## 战斗结束后把伙伴血量写回存档状态。
func sync_pet_from_battle(pid: String, level: int, hp: int) -> void:
    pet_state[pid] = { "level": level, "hp": hp }
    state_changed.emit()

func new_game() -> void:
    player = {
        "name": "小团子", "level": 1, "exp": 0, "hp": 60, "max_hp": 60,
        "atk": 12, "def": 10, "spd": 10, "coins": 120, "star_dust": 3,
        "attrs": { "str": 0, "vit": 0, "agi": 0, "int": 0 },
        "spent_points": 0,
    }
    inventory = { "berry": 3, "honey": 1 }
    party = ["grass"]
    seen = []
    caught = []
    flags = {}
    play_seconds = 0.0
    appearance = { "preset": "classic" }
    pet_state = {}
    _ensure_pet_state()
    state_changed.emit()
