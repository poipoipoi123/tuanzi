# 团子阶段二：玩法深度 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让战斗有策略深度（属性克制、暴击、闪避、道具），让小团子可养成（四维属性、外貌），并补上程序化音效，使游戏从「能玩」变为「好玩」。

**架构：** 新增纯逻辑系统放 `scripts/systems/`，数值表放 `scripts/data/`，两者均不依赖场景树，可直接在无头自检中断言。`Battler.compute_damage` 扩展为接收攻击方/防守方完整数据并应用克制、暴击、闪避。音效用运行时 PCM 合成，不引入任何音频文件。

**技术栈：** Godot 4.7.2 stable、GDScript 4、无外部依赖、无构建步骤。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| 创建 `scripts/data/elements.gd` | 属性克制表（纯数据 + 查表函数） |
| 创建 `scripts/systems/capture.gd` | 收服成功率计算（纯函数） |
| 创建 `scripts/systems/growth.gd` | 四维属性成长与分配（纯逻辑） |
| 创建 `scripts/core/sfx.gd` | autoload：程序化音效合成与播放 |
| 创建 `scripts/ui/appearance_panel.gd` | 外貌自定义面板 |
| 修改 `scripts/battle/battler.gd` | 伤害公式接入克制/暴击/闪避 |
| 修改 `scripts/battle/battle_scene.gd` | 道具指令、收服指令、命中反馈 |
| 修改 `scripts/ui/battle_menu.gd` | 增加道具与收服按钮 |
| 修改 `scripts/core/game_state.gd` | 四维属性、外貌、音效开关 |
| 修改 `scripts/data/items.gd` | 捕捉道具 |
| 修改 `scripts/world/player.gd` | 应用外貌配色 |
| 修改 `tests/self_check.gd` | 新增各任务断言 |

---

### 任务 1：属性克制表 data/elements.gd

**文件：**
- 创建：`scripts/data/elements.gd`
- 测试：`tests/self_check.gd`（`_check_elements`）

- [ ] **步骤 1：编写失败的测试**

在 `tests/self_check.gd` 的 `_ready()` 中，`_check_data()` 之后插入 `_check_elements()`：

```gdscript
    _check_data()
    _check_elements()
    _check_state()
```

新增测试函数：

```gdscript
func _check_elements() -> void:
    print("[属性克制]")
    _ok(ElementDB.ELEMENTS.size() == 3, "属性表含 3 种属性")
    _ok(ElementDB.effectiveness("草", "水") == 2.0, "草打水 2 倍")
    _ok(ElementDB.effectiveness("水", "草") == 0.5, "水打草 0.5 倍")
    _ok(ElementDB.effectiveness("草", "草") == 1.0, "同属性 1 倍")
    _ok(ElementDB.effectiveness("星", "草") == 2.0, "星打草 2 倍")
    _ok(ElementDB.effectiveness("__未知__", "草") == 1.0, "未知属性回退 1 倍")
```

- [ ] **步骤 2：运行测试验证失败**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：FAIL，报 `Identifier "ElementDB" not declared in the current scope`。

- [ ] **步骤 3：编写最少实现代码**

```gdscript
class_name ElementDB
extends RefCounted
## 属性克制表：纯数据 + 查表，改平衡只需改 STRONG。

const ELEMENTS := ["草", "水", "星"]

## 攻击方 -> 被克制的属性集合（造成 2 倍伤害）
const STRONG := {
    "草": ["水"],
    "水": ["星"],
    "星": ["草"],
}

## 返回伤害倍率：2.0 克制 / 0.5 被抗 / 1.0 中性。
static func effectiveness(attacker: String, defender: String) -> float:
    if not STRONG.has(attacker):
        return 1.0
    var beats: Array = STRONG[attacker]
    if beats.has(defender):
        return 2.0
    # 反向：若防守方克制攻击方，则攻击方吃 0.5 倍
    if STRONG.has(defender) and (STRONG[defender] as Array).has(attacker):
        return 0.5
    return 1.0
```

- [ ] **步骤 4：运行测试验证通过**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --import --headless --path . | Out-Null
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：PASS（总数 53 + 6 = 59），末行 `ALL PASS`。

注意：新增 `class_name` 必须先 `--import` 一次，否则报「not declared in the current scope」。

- [ ] **步骤 5：Commit**

```powershell
git add scripts/data/elements.gd tests/self_check.gd
git commit -m "feat: 新增属性克制表"
```

---

### 任务 2：伤害公式接入克制 / 暴击 / 闪避

**文件：**
- 修改：`scripts/battle/battler.gd`
- 测试：`tests/self_check.gd`（`_check_battle_math` 内追加）

- [ ] **步骤 1：编写失败的测试**

在 `_check_battle_math()` 末尾（`bt.heal(99999)` 那行之后）追加：

```gdscript
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
```

- [ ] **步骤 2：运行测试验证失败**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：FAIL，报 `Invalid call. Nonexistent function 'resolve_attack'`，且克制断言失败。

- [ ] **步骤 3：编写最少实现代码**

修改 `scripts/battle/battler.gd`，在文件末尾追加常量与两个静态函数，并替换 `compute_damage`：

```gdscript
const CRIT_MULTIPLIER := 1.6
const CRIT_BASE_RATE := 0.06        # 基础暴击率
const CRIT_SPD_BONUS := 0.0015      # 每点速度增加的暴击率
const DODGE_BASE := 0.03            # 基础闪避率
const DODGE_SPD_FACTOR := 0.0022    # 速度差对闪避的影响

## 暴击率：基础 + 自身速度加成，上限 0.6。
static func crit_chance(attacker: Dictionary) -> float:
    var spd := float(attacker.get("spd", 10))
    return minf(0.6, CRIT_BASE_RATE + spd * CRIT_SPD_BONUS)

## 闪避率：基础 + 双方速度差，限制在 0.02..0.45。
static func dodge_chance(attacker: Dictionary, defender: Dictionary) -> float:
    var diff := float(defender.get("spd", 10)) - float(attacker.get("spd", 10))
    return clampf(DODGE_BASE + diff * DODGE_SPD_FACTOR, 0.02, 0.45)

## 伤害公式：威力 + 攻击 + 等级 - 防御，乘属性克制，再乘随机浮动。
static func compute_damage(attacker: Dictionary, defender: Dictionary,
        skill: Dictionary, rng_value: float) -> int:
    var atk := float(attacker.get("atk", 10))
    var dfn := float(defender.get("def", 10))
    var power := float(skill.get("power", 10))
    var lv := float(attacker.get("level", 1))
    var base := (power + atk * 1.25 + lv * 0.9) - dfn * 0.85
    base = maxf(4.0, base)
    var elem := ElementDB.effectiveness(
        String(attacker.get("element", "")), String(defender.get("element", "")))
    var variance := 0.88 + clampf(rng_value, 0.0, 1.0) * 0.24
    return maxi(1, int(round(base * elem * variance)))

## 完整一次攻击结算：命中判定 -> 伤害 -> 暴击判定。
## 三个随机数分开传入，便于测试确定性。
static func resolve_attack(attacker: Dictionary, defender: Dictionary, skill: Dictionary,
        rng_value: float, hit_roll: float, crit_roll: float) -> Dictionary:
    if hit_roll < dodge_chance(attacker, defender):
        return { "hit": false, "crit": false, "damage": 0 }
    var dmg := compute_damage(attacker, defender, skill, rng_value)
    var is_crit := crit_roll < crit_chance(attacker)
    if is_crit:
        dmg = maxi(1, int(round(dmg * CRIT_MULTIPLIER)))
    return { "hit": true, "crit": is_crit, "damage": dmg }
```

- [ ] **步骤 4：运行测试验证通过**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：PASS（59 + 8 = 67），末行 `ALL PASS`。

- [ ] **步骤 5：Commit**

```powershell
git add scripts/battle/battler.gd tests/self_check.gd
git commit -m "feat: 伤害公式接入属性克制、暴击与闪避"
```

---

### 任务 3：收服系统 systems/capture.gd

**文件：**
- 创建：`scripts/systems/capture.gd`
- 修改：`scripts/data/items.gd`
- 测试：`tests/self_check.gd`（`_check_capture`）

- [ ] **步骤 1：编写失败的测试**

插入调用 `_check_capture()`，并新增：

```gdscript
func _check_capture() -> void:
    print("[收服]")
    _ok(Capture.rate(1.0, 1, 1.0) >= 0.05, "残血目标收服率有下限")
    var full := Capture.rate(1.0, 1, 1.0)
    var low := Capture.rate(0.1, 1, 1.0)
    _ok(low > full, "血量越低越容易收服（%.2f > %.2f）" % [low, full])
    var weak_ball := Capture.rate(0.1, 1, 1.0)
    var strong_ball := Capture.rate(0.1, 3, 1.0)
    _ok(strong_ball > weak_ball, "高级捕捉道具成功率更高")
    _ok(Capture.rate(0.01, 9, 0.0) <= 0.98, "收服率上限不超过 0.98")
    _ok(Capture.rate(1.0, 1, 1.0) <= 0.95, "满血目标也有上限")
    var ball: Dictionary = ItemDB.get_item("capture_ball")
    _ok(not ball.is_empty(), "捕捉道具存在于道具表")
    _ok(int(ball["power"]) == 1, "基础捕捉道具威力为 1")
```

- [ ] **步骤 2：运行测试验证失败**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：FAIL，报 `Identifier "Capture" not declared`。

- [ ] **步骤 3：编写最少实现代码**

创建 `scripts/systems/capture.gd`：

```gdscript
class_name Capture
extends RefCounted
## 收服成功率：纯函数，便于调参与测试。

const MIN_RATE := 0.05
const MAX_RATE := 0.98
const LOW_HP_BONUS := 2.2      # 残血加成强度

## hp_ratio: 目标当前血量比例(0..1)
## ball_power: 捕捉道具威力（1 基础 / 2 中级 / 3 高级）
## level_gap_bonus: 额外加成，来自等级差或状态
static func rate(hp_ratio: float, ball_power: int, level_gap_bonus: float) -> float:
    var low := clampf(hp_ratio, 0.0, 1.0)
    # 血量越低，加成越大（1.0 -> 0，0.0 -> LOW_HP_BONUS）
    var hp_factor := (1.0 - low) * LOW_HP_BONUS
    var base := 0.10 + hp_factor * 0.28
    var ball_factor := 1.0 + (maxf(1.0, float(ball_power)) - 1.0) * 0.45
    var r := base * ball_factor * (1.0 + maxf(0.0, level_gap_bonus))
    return clampf(r, MIN_RATE, MAX_RATE)

## 掷骰：roll 属于 [0,1)，小于成功率即收服成功。
static func attempt(hp_ratio: float, ball_power: int, level_gap_bonus: float,
        roll: float) -> bool:
    return roll < rate(hp_ratio, ball_power, level_gap_bonus)
```

在 `scripts/data/items.gd` 的 `ITEMS` 字典中追加：

```gdscript
    "capture_ball": { "name": "团子球", "type": "capture", "power": 1, "price": 30,
        "desc": "基础捕捉道具，对残血的团子兽效果更好。" },
    "capture_ball_good": { "name": "好团子球", "type": "capture", "power": 2, "price": 90,
        "desc": "成功率更高的捕捉道具。" },
    "capture_ball_great": { "name": "高级团子球", "type": "capture", "power": 3, "price": 240,
        "desc": "对稀有团子兽也相当可靠。" },
```

- [ ] **步骤 4：运行测试验证通过**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：PASS（67 + 7 = 74），末行 `ALL PASS`。

- [ ] **步骤 5：Commit**

```powershell
git add scripts/systems/capture.gd scripts/data/items.gd tests/self_check.gd
git commit -m "feat: 收服系统与捕捉道具"
```

---

### 任务 4：战斗中道具与收服指令

**文件：**
- 修改：`scripts/battle/battle_scene.gd`
- 修改：`scripts/ui/battle_menu.gd`
- 测试：`tests/self_check.gd`（`_check_battle_items`）

- [ ] **步骤 1：编写失败的测试**

```gdscript
func _check_battle_items() -> void:
    print("[战斗道具]")
    var b: Node2D = load("res://scripts/battle/battle_scene.gd").new()
    add_child(b)
    b.setup("grass", 3, "grass", 3)
    await get_tree().process_frame
    GameState.new_game()
    GameState.add_item("berry", 2)

    # 使用回复道具应回血并消耗道具
    b.ally.data["hp"] = 5
    b.state = "choose"
    b._on_item_used("berry")
    _ok(int(b.ally.data["hp"]) > 5, "道具回复了体力")
    _ok(int(GameState.inventory.get("berry", 0)) == 1, "道具被消耗")

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
```

- [ ] **步骤 2：运行测试验证失败**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：FAIL，报 `Nonexistent function '_on_item_used'`。

- [ ] **步骤 3：编写最少实现代码**

在 `scripts/battle/battle_scene.gd` 中新增（放在 `_on_flee` 之后）：

```gdscript
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
```

在 `scripts/ui/battle_menu.gd` 增加信号与按钮。`refresh_for` 末尾追加：

```gdscript
    _hb.add_child(_make_button("道具", Palette.MINT.darkened(0.3), func(): item_menu_requested.emit()))
    _hb.add_child(_make_button("收服", Palette.SKY.darkened(0.2), func(): capture_requested.emit()))
```

并在文件顶部信号区追加：

```gdscript
signal item_menu_requested()
signal capture_requested()
```

在 `battle_scene.gd` 的 `_ready()` 中连接这两个信号：`_menu.item_menu_requested.connect(_on_item_menu)`、`_menu.capture_requested.connect(_on_capture_menu)`，并新增两个方法，各自挑一个可用道具后调用上面两个函数：

```gdscript
func _first_item_of_type(t: String) -> String:
    for iid in GameState.inventory.keys():
        var it: Dictionary = ItemDB.get_item(String(iid))
        if String(it.get("type", "")) == t and int(GameState.inventory[iid]) > 0:
            return String(iid)
    return ""

func _on_item_menu() -> void:
    var iid := _first_item_of_type("heal")
    if iid == "":
        iid = _first_item_of_type("buff")
    if iid == "":
        _push_log("背包里没有可用的道具。")
        return
    _on_item_used(iid)

func _on_capture_menu() -> void:
    var iid := _first_item_of_type("capture")
    if iid == "":
        _push_log("没有捕捉道具，去商店看看吧。")
        return
    _on_capture_attempt(iid)
```

- [ ] **步骤 4：运行测试验证通过**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：PASS（74 + 5 = 79），末行 `ALL PASS`。

- [ ] **步骤 5：Commit**

```powershell
git add scripts/battle/battle_scene.gd scripts/ui/battle_menu.gd tests/self_check.gd
git commit -m "feat: 战斗中可使用道具与收服团子兽"
```

---

### 任务 5：四维属性养成 systems/growth.gd

**文件：**
- 创建：`scripts/systems/growth.gd`
- 修改：`scripts/core/game_state.gd`
- 测试：`tests/self_check.gd`（`_check_growth`）

- [ ] **步骤 1：编写失败的测试**

```gdscript
func _check_growth() -> void:
    print("[养成]")
    _ok(Growth.ATTRS.size() == 4, "四维属性定义完整")
    _ok(Growth.points_for_level(1) == 0, "1 级无可用点数")
    _ok(Growth.points_for_level(5) > 0, "升级获得点数")
    var spend := Growth.spend({"str": 1, "vit": 1, "agi": 1, "int": 1}, "str", 3)
    _ok(int(spend["attrs"]["str"]) == 4, "加点生效")
    _ok(int(spend["points"]) == 2, "点数被扣除")
    var over := Growth.spend({"str": 1, "vit": 1, "agi": 1, "int": 1}, "str", 99)
    _ok(int(over["attrs"]["str"]) == 100, "点数不足时只加剩余部分")
    _ok(int(over["points"]) == 0, "点数归零")
    _ok(Growth.stat_bonus(10, "str") > Growth.stat_bonus(0, "str"), "点数提升属性收益")
    GameState.new_game()
    _ok(GameState.player.has("attrs"), "存档含四维属性")
    _ok(GameState.free_points() >= 0, "可用点数非负")
    _ok(GameState.spend_point("str"), "可分配一点力量")
    GameState.gain_exp(500)
    _ok(GameState.free_points() > 0, "升级后获得可分配点数")
```

- [ ] **步骤 2：运行测试验证失败**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：FAIL，报 `Identifier "Growth" not declared`。

- [ ] **步骤 3：编写最少实现代码**

创建 `scripts/systems/growth.gd`：

```gdscript
class_name Growth
extends RefCounted
## 小团子四维属性成长：纯逻辑，可测。

const ATTRS := ["str", "vit", "agi", "int"]
const POINTS_PER_LEVEL := 3
const HP_PER_VIT := 4
const ATK_PER_STR := 1.5

## 到 level 级时累计应得点数（不含已花费）。
static func points_for_level(level: int) -> int:
    return maxi(0, (maxi(1, level) - 1) * POINTS_PER_LEVEL)

## 分配 count 点到 attr。返回新的 { attrs, points }。
## 点数不足时只分配剩余部分。
static func spend(attrs: Dictionary, attr: String, count: int) -> Dictionary:
    var a: Dictionary = attrs.duplicate(true)
    if not a.has(attr):
        return { "attrs": a, "points": maxi(0, count) }
    # 约定：调用方把「可用点数」放在 points 字段随同传入时由其自行扣减
    var take := maxi(0, count)
    a[attr] = int(a[attr]) + take
    return { "attrs": a, "points": 0 }

## 属性点带来的派生收益。
static func stat_bonus(points: int, attr: String) -> int:
    var p := maxi(0, points)
    match attr:
        "str": return int(round(p * ATK_PER_STR))
        "vit": return p * HP_PER_VIT
        "agi": return int(round(p * 0.8))
        "int": return int(round(p * 1.1))
    return 0

## 从四维属性推导战斗数值。
static func derive(attrs: Dictionary) -> Dictionary:
    return {
        "atk": 12 + stat_bonus(int(attrs.get("str", 0)), "str"),
        "max_hp": 60 + stat_bonus(int(attrs.get("vit", 0)), "vit"),
        "spd": 10 + stat_bonus(int(attrs.get("agi", 0)), "agi"),
        "def": 10 + stat_bonus(int(attrs.get("int", 0)), "int"),
    }
```

在 `scripts/core/game_state.gd` 的 `player` 字典中增加 `"attrs": { "str": 0, "vit": 0, "agi": 0, "int": 0 },`、`"spent_points": 0,`，并新增：

```gdscript
## 当前可分配点数 = 升级应得 - 已花费
func free_points() -> int:
    return maxi(0, Growth.points_for_level(int(player["level"]))
        - int(player.get("spent_points", 0)))

## 分配一点属性，并按四维重算战斗数值。
func spend_point(attr: String) -> bool:
    if free_points() <= 0 or not Growth.ATTRS.has(attr):
        return false
    var attrs: Dictionary = player.get("attrs", {})
    var res: Dictionary = Growth.spend(attrs, attr, 1)
    player["attrs"] = res["attrs"]
    player["spent_points"] = int(player.get("spent_points", 0)) + 1
    _apply_derived()
    state_changed.emit()
    return true

## 用四维属性覆盖派生数值（不碰当前血量上限以外的字段）。
func _apply_derived() -> void:
    var d: Dictionary = Growth.derive(player.get("attrs", {}))
    player["atk"] = int(d["atk"])
    player["def"] = int(d["def"])
    player["spd"] = int(d["spd"])
    var new_max := int(d["max_hp"])
    if new_max != int(player["max_hp"]):
        player["max_hp"] = new_max
        player["hp"] = mini(int(player["hp"]), new_max)
```

同时把 `new_game()` 中重建的 `player` 字典补上 `attrs` 与 `spent_points` 两个键，并让 `from_dict` 在读到旧存档（无这些键）时补默认值：

```gdscript
    if not player.has("attrs"):
        player["attrs"] = { "str": 0, "vit": 0, "agi": 0, "int": 0 }
    if not player.has("spent_points"):
        player["spent_points"] = 0
```

- [ ] **步骤 4：运行测试验证通过**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：PASS（79 + 12 = 91），末行 `ALL PASS`。

- [ ] **步骤 5：Commit**

```powershell
git add scripts/systems/growth.gd scripts/core/game_state.gd tests/self_check.gd
git commit -m "feat: 四维属性养成与派生数值"
```

---

### 任务 6：外貌自定义

**文件：**
- 创建：`scripts/ui/appearance_panel.gd`
- 修改：`scripts/core/game_state.gd`、`scripts/world/player.gd`、`scripts/world/world.gd`
- 测试：`tests/self_check.gd`（`_check_appearance`）

- [ ] **步骤 1：编写失败的测试**

```gdscript
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
```

- [ ] **步骤 2：运行测试验证失败**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：FAIL，报 `Invalid access to property or key 'APPEARANCE_PRESETS'`。

- [ ] **步骤 3：编写最少实现代码**

在 `scripts/core/game_state.gd` 中新增：

```gdscript
const APPEARANCE_PRESETS := {
    "classic": { "name": "经典白", "body": "fff6e8", "edge": "e8b48a", "horn": "6fbf5f" },
    "mint":    { "name": "薄荷绿", "body": "d8f5d0", "edge": "8fce80", "horn": "4f9d46" },
    "sakura":  { "name": "樱花粉", "body": "ffe0e6", "edge": "f0a8b8", "horn": "e07f8c" },
    "sky":     { "name": "晴空蓝", "body": "dcefff", "edge": "9ec9f0", "horn": "7fb3e0" },
    "honey":   { "name": "蜂蜜黄", "body": "fff3d0", "edge": "e8c86a", "horn": "d9b24e" },
}

var appearance := { "preset": "classic" }

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
```

在 `to_dict()` 中加 `"appearance": appearance.duplicate(true),`；在 `from_dict()` 中加：

```gdscript
    var ap: Variant = d.get("appearance", {})
    if typeof(ap) == TYPE_DICTIONARY and (ap as Dictionary).has("preset"):
        var pid_ap := String((ap as Dictionary)["preset"])
        if APPEARANCE_PRESETS.has(pid_ap):
            appearance["preset"] = pid_ap
```

在 `new_game()` 中重置 `appearance = { "preset": "classic" }`。

修改 `scripts/world/player.gd` 的 `_ready()`，改为读取外观：

```gdscript
func _ready() -> void:
    is_player = true
    var c := GameState.appearance_colors()
    body_color = Color(c["body"])
    edge_color = Color(c["edge"])
    horn_color = Color(c["horn"])
    super._ready()
```

新增 `scripts/ui/appearance_panel.gd`（仿 `journal.gd` 的全屏遮罩 + 居中卡片结构，用 `GridContainer` 列出预设按钮；点击调用 `GameState.set_appearance(id)` 后重建列表，并用 `TuanziArt.draw_tuanzi` 画预览头像）。

在 `scripts/world/world.gd` 的 `input_setup.gd` 中给 `ACTIONS` 增加 `"appearance": [KEY_C]`；在 `world.gd` 的 `_unhandled_input` 中加：

```gdscript
    elif e.is_action_pressed("appearance"):
        _appearance.toggle()
        get_viewport().set_input_as_handled()
```

并仿 `_journal` 创建 `_appearance` 成员与在 `_setup_ui()` 中挂载。

- [ ] **步骤 4：运行测试验证通过**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --import --headless --path . | Out-Null
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：PASS（91 + 8 = 99），末行 `ALL PASS`。

- [ ] **步骤 5：Commit**

```powershell
git add scripts/ui/appearance_panel.gd scripts/core/game_state.gd scripts/world/player.gd scripts/world/world.gd scripts/core/input_setup.gd tests/self_check.gd
git commit -m "feat: 小团子外貌自定义"
```

---

### 任务 7：程序化音效 Sfx

**文件：**
- 创建：`scripts/core/sfx.gd`
- 修改：`project.godot`（autoload）、`scripts/battle/battle_scene.gd`、`scripts/world/world.gd`
- 测试：`tests/self_check.gd`（`_check_sfx`）

- [ ] **步骤 1：编写失败的测试**

```gdscript
func _check_sfx() -> void:
    print("[音效]")
    _ok(Sfx.tone_bytes("blip", 0.15, 660.0) > 100, "生成了非空 PCM 数据")
    var a: PackedByteArray = Sfx.build_pcm(0.1, 440.0, 0.5)
    var b: PackedByteArray = Sfx.build_pcm(0.1, 880.0, 0.5)
    _ok(a.size() == b.size(), "同一时长产生同样长度的数据")
    _ok(a != b, "不同频率产生不同波形")
    _ok(Sfx.build_pcm(0.1, 440.0, 0.0).size() > 0, "零音量仍返回有效缓冲")
    _ok(Sfx.KINDS.has("hit") and Sfx.KINDS.has("win"), "定义了命中与胜利音效")
    _ok(is_instance_valid(Sfx), "Sfx 作为 autoload 存在")
```

- [ ] **步骤 2：运行测试验证失败**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：FAIL，报 `Identifier "Sfx" not declared`。

- [ ] **步骤 3：编写最少实现代码**

创建 `scripts/core/sfx.gd`：

```gdscript
extends Node
## 程序化音效：运行时合成 PCM 波形，不加载任何音频文件。
## 音效本身是「数据 + 合成」，因此可被无头自检断言。

const SAMPLE_RATE := 22050
const MAX_VOICES := 6

## 音效定义：频率、时长、波形、音量
const KINDS := {
    "blip":    { "freq": 660.0, "dur": 0.07, "wave": "sine",     "vol": 0.25 },
    "select":  { "freq": 880.0, "dur": 0.05, "wave": "sine",     "vol": 0.22 },
    "hit":     { "freq": 180.0, "dur": 0.14, "wave": "square",   "vol": 0.20 },
    "crit":    { "freq": 240.0, "dur": 0.18, "wave": "saw",      "vol": 0.24 },
    "heal":    { "freq": 700.0, "dur": 0.22, "wave": "sine",     "vol": 0.22, "slide": 420.0 },
    "capture": { "freq": 520.0, "dur": 0.26, "wave": "triangle", "vol": 0.22, "slide": 260.0 },
    "win":     { "freq": 620.0, "dur": 0.42, "wave": "sine",     "vol": 0.26, "slide": 760.0 },
    "lose":    { "freq": 300.0, "dur": 0.44, "wave": "triangle", "vol": 0.24, "slide": 160.0 },
    "step":    { "freq": 220.0, "dur": 0.04, "wave": "sine",     "vol": 0.12 },
}

var enabled := true
var _players: Array = []
var _next := 0

func _ready() -> void:
    for i in MAX_VOICES:
        var p := AudioStreamPlayer.new()
        add_child(p)
        _players.append(p)

## 合成一段 16-bit 单声道 PCM。
## wave: sine / square / saw / triangle；slide 为结束频率（线性滑音）。
static func build_pcm(dur: float, freq: float, vol: float,
        wave: String = "sine", slide: float = 0.0) -> PackedByteArray:
    var n := int(maxf(0.0, dur) * SAMPLE_RATE)
    var data := PackedByteArray()
    data.resize(n * 2)
    var f_end := slide if slide > 0.0 else freq
    for i in n:
        var t := float(i) / float(SAMPLE_RATE)
        var prog := float(i) / maxf(1.0, float(n))
        var f := lerpf(freq, f_end, prog)
        var phase := TAU * f * t
        var s := 0.0
        match wave:
            "square":   s = 1.0 if sin(phase) >= 0.0 else -1.0
            "saw":      s = 2.0 * (prog - floorf(prog + 0.5))
            "triangle": s = 2.0 * absf(2.0 * (prog - floorf(prog + 0.5))) - 1.0
            _:          s = sin(phase)
        # 起音与收尾包络，避免爆音
        var env := minf(1.0, prog * 12.0) * minf(1.0, (1.0 - prog) * 5.0)
        var v := int(clampf(s * vol * env, -1.0, 1.0) * 32767.0)
        data.encode_s16(i * 2, v)
    return data

## 便捷：直接得到某音效的字节长度（供测试使用）。
static func tone_bytes(kind: String, dur: float, freq: float) -> int:
    var k: Dictionary = KINDS.get(kind, KINDS["blip"])
    return build_pcm(dur, freq, float(k["vol"]), String(k["wave"])).size()

func play(kind: String) -> void:
    if not enabled or not KINDS.has(kind):
        return
    var k: Dictionary = KINDS[kind]
    var pcm := build_pcm(float(k["dur"]), float(k["freq"]), float(k["vol"]),
        String(k["wave"]), float(k.get("slide", 0.0)))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = SAMPLE_RATE
    stream.stereo = false
    stream.data = pcm
    var p: AudioStreamPlayer = _players[_next]
    _next = (_next + 1) % _players.size()
    p.stream = stream
    p.play()

func set_enabled(on: bool) -> void:
    enabled = on
```

在 `project.godot` 的 `[autoload]` 段追加：

```
Sfx="*res://scripts/core/sfx.gd"
```

在 `battle_scene.gd` 的关键点调用：命中时 `Sfx.play("hit")`、暴击时 `Sfx.play("crit")`、治疗时 `Sfx.play("heal")`、收服尝试 `Sfx.play("capture")`、胜负结算 `Sfx.play("win")` / `Sfx.play("lose")`。在 `world.gd` 中移动时每隔 0.36 秒 `Sfx.play("step")`、对话时 `Sfx.play("blip")`。

- [ ] **步骤 4：运行测试验证通过**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：PASS（99 + 6 = 105），末行 `ALL PASS`。

- [ ] **步骤 5：导出并验证**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --export-release "Windows Desktop" "build/Tuanzi.exe" | Out-Null
& ".\build\Tuanzi.exe" --headless --quit-after 150
```

预期：退出码 0，无 `SCRIPT ERROR`。

- [ ] **步骤 6：Commit**

```powershell
git add scripts/core/sfx.gd project.godot scripts/battle/battle_scene.gd scripts/world/world.gd tests/self_check.gd
git commit -m "feat: 程序化合成音效"
```

---

### 任务 8：战斗全键盘操作与验收文档

**文件：**
- 修改：`scripts/ui/battle_menu.gd`、`scripts/battle/battle_scene.gd`
- 修改：`docs/acceptance.md`
- 测试：`tests/self_check.gd`（`_check_battle_keyboard`）

- [ ] **步骤 1：编写失败的测试**

```gdscript
func _check_battle_keyboard() -> void:
    print("[战斗键盘]")
    var b: Node2D = load("res://scripts/battle/battle_scene.gd").new()
    add_child(b)
    b.setup("water", 3, "grass", 3)
    await get_tree().process_frame
    b.state = "choose"
    b._menu.visible = true
    _ok(b._menu.cursor >= 0, "菜单有默认光标")
    var first := b._menu.cursor
    b._menu.move_cursor(1)
    _ok(b._menu.cursor != first, "光标可移动")
    b._menu.move_cursor(-1)
    _ok(b._menu.cursor == first, "光标可移回")
    # 数字键 1 直接选第一个技能
    b.state = "choose"
    b._menu.visible = true
    b._menu.choose_index(0)
    _ok(b.state == "act", "数字键确认后进入结算")
    b.queue_free()
    await get_tree().process_frame
```

- [ ] **步骤 2：运行测试验证失败**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：FAIL，报 `Invalid access to property or key 'cursor'`。

- [ ] **步骤 3：编写最少实现代码**

在 `scripts/ui/battle_menu.gd` 中加入光标与键盘选择：

```gdscript
var cursor := 0
var _entries: Array = []       # [{ id, kind }]，kind: "skill" | "item" | "capture" | "flee"

const CURSOR_PREFIX := "▶ "

func move_cursor(delta: int) -> void:
    if _entries.is_empty():
        return
    cursor = wrapi(cursor + delta, 0, _entries.size())
    _apply_cursor()

func choose_index(i: int) -> void:
    if i < 0 or i >= _entries.size():
        return
    cursor = i
    _activate()

func _activate() -> void:
    var e: Dictionary = _entries[cursor]
    match String(e["kind"]):
        "skill":   skill_chosen.emit(String(e["id"]))
        "item":    item_menu_requested.emit()
        "capture": capture_requested.emit()
        "flee":    flee_chosen.emit()

func _apply_cursor() -> void:
    var btns := _hb.get_children()
    for i in btns.size():
        var b := btns[i] as Button
        if b == null:
            continue
        var base := String(b.get_meta("base_text", b.text))
        b.text = (CURSOR_PREFIX + base) if i == cursor else base
        b.add_theme_color_override("font_color",
            Palette.PINK_DEEP if i == cursor else Palette.INK)

func has_focus_inkey() -> bool:
    return true
```

在 `_make_button` 里保存基准文本并对齐索引：

```gdscript
    b.set_meta("base_text", text)
    var idx := _hb.get_child_count()
    b.pressed.connect(func(): cursor = idx; cb.call())
```

在 `refresh_for` 开头清空 `_entries` 并逐个登记：

```gdscript
    _entries.clear()
    cursor = 0
```

每个技能按钮前加 `_entries.append({ "id": String(sid), "kind": "skill" })`，道具/收服/逃跑同理登记。然后在 `battle_scene.gd` 的 `_unhandled_input` 中处理键盘：

```gdscript
func _unhandled_input(e: InputEvent) -> void:
    if _menu == null or not _menu.visible:
        return
    if e.is_action_pressed("move_left"):
        _menu.move_cursor(-1)
    elif e.is_action_pressed("move_right"):
        _menu.move_cursor(1)
    elif e.is_action_pressed("interact"):
        _menu.choose_index(_menu.cursor)
    else:
        for i in 4:
            if e is InputEventKey and (e as InputEventKey).pressed                     and (e as InputEventKey).keycode == KEY_1 + i:
                _menu.choose_index(i)
                break
    get_viewport().set_input_as_handled()
```

- [ ] **步骤 4：运行测试验证通过**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：PASS（105 + 5 = 110），末行 `ALL PASS`。

- [ ] **步骤 5：追加手动验收项**

在 `docs/acceptance.md` 末尾追加：

```markdown
## 阶段二新增
- [ ] 战斗中可用方向键移动光标、E/空格确认，全程不碰鼠标
- [ ] 数字键 1-4 可直接选定对应指令
- [ ] 草打水时伤害明显高于水打草（属性克制生效）
- [ ] 偶尔出现暴击伤害（约 1.6 倍）与「落空」提示
- [ ] 战斗中可用道具回血、可投掷团子球收服
- [ ] 收服成功后该团子兽出现在图鉴与队伍中
- [ ] 升级后可分配属性点，血条上限随之提高
- [ ] 按 C 打开外貌面板，切换配色后世界里的角色立刻变色
- [ ] 移动、命中、暴击、收服、胜负均有音效，且无爆音
```

- [ ] **步骤 6：Commit**

```powershell
git add scripts/ui/battle_menu.gd scripts/battle/battle_scene.gd docs/acceptance.md tests/self_check.gd
git commit -m "feat: 战斗全键盘操作"
```

---

## 阶段门禁

1. `self_check.tscn` 全绿（110 项）、退出码 0
2. `build/Tuanzi.exe` 导出并启动无错
3. `docs/acceptance.md` 已追加阶段二验收项
4. 推送并打 tag `v0.2.0`、发 Release
