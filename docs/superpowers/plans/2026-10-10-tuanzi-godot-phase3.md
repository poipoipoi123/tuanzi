# 团子阶段三：内容与长期游玩 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 把单人单体战斗扩展为 3v3 队伍战斗，加入装备强化、商店经济、任务系统与多区域，并让存档支持导入导出与版本迁移，使游戏可以长期游玩。

**架构：** 队伍用 `Array[Battler]` 表达，战斗流程改为「按回合收集全队指令 → 按速度排序执行 → 移除阵亡单位」。装备与任务均为纯数据表 + 纯计算函数，放 `data/` 与 `systems/`。存档迁移用版本号链式升级函数。

**技术栈：** Godot 4.7.2 stable、GDScript 4、无外部依赖、无构建步骤。

**前置：** 阶段二已完成（属性克制、收服、养成、音效）。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| 创建 `scripts/battle/party.gd` | 队伍容器：3 个 Battler、切换、存活判定 |
| 创建 `scripts/data/equipment.gd` | 装备表（武器/护甲/饰品） |
| 创建 `scripts/data/quests.gd` | 任务表（主线 + 日常） |
| 创建 `scripts/systems/upgrade.gd` | 强化成功率与消耗（纯函数） |
| 创建 `scripts/systems/shop.gd` | 买卖与经济（纯函数） |
| 创建 `scripts/systems/quest.gd` | 任务进度推进与结算（纯逻辑） |
| 创建 `scripts/core/save_migrate.gd` | 存档版本迁移 |
| 创建 `scripts/world/areas.gd` | 多区域定义（数据） |
| 创建 `scripts/ui/shop_panel.gd` | 商店界面 |
| 创建 `scripts/ui/quest_log.gd` | 任务日志界面 |
| 修改 `scripts/battle/battle_scene.gd` | 改为 3v3 流程 |
| 修改 `scripts/core/game_state.gd` | 队伍、装备、任务、货币 |
| 修改 `scripts/world/world.gd` | 区域切换与出入口 |
| 修改 `tests/self_check.gd` | 新增各任务断言 |

---

### 任务 1：队伍容器 battle/party.gd

**文件：**
- 创建：`scripts/battle/party.gd`
- 测试：`tests/self_check.gd`（`_check_party`）

- [ ] **步骤 1：编写失败的测试**

在 `_ready()` 中 `await _check_battle_scene()` 之前插入 `await _check_party()`，并新增：

```gdscript
func _check_party() -> void:
    print("[队伍]")
    var p := Party.new(["grass", "water", "spark"], 5)
    _ok(p.size() == 3, "队伍含 3 名成员")
    _ok(p.active() != null, "有出战成员")
    _ok(p.alive_count() == 3, "初始全员存活")
    _ok(String(p.get_member(0).data["name"]) == "草团子兽", "第 1 位是草团子兽")
    p.get_member(0).take_damage(99999)
    _ok(p.alive_count() == 2, "阵亡后存活数减 1")
    _ok(p.first_alive_index() == 1, "自动指向下一个存活成员")
    p.get_member(1).take_damage(99999)
    p.get_member(2).take_damage(99999)
    _ok(p.is_wiped(), "全员阵亡判定正确")
    _ok(p.first_alive_index() == -1, "全灭时无存活索引")
    var p2 := Party.new(["grass"], 3)
    _ok(p2.size() == 1, "可组建单人队伍")

func _check_party_switch() -> void:
    print("[队伍切换]")
    var p := Party.new(["grass", "water"], 5)
    _ok(p.active_index == 0, "默认出战索引为 0")
    _ok(p.switch_to(1), "切到第 2 位成功")
    _ok(p.active_index == 1, "出战索引已更新")
    _ok(not p.switch_to(0), "不能切到已阵亡成员")
    p.get_member(1).take_damage(99999)
    _ok(not p.switch_to(1), "不能切到刚阵亡的成员")
```

- [ ] **步骤 2：运行测试验证失败**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：FAIL，报 `Identifier "Party" not declared`。

- [ ] **步骤 3：编写最少实现代码**

```gdscript
class_name Party
extends RefCounted
## 战斗队伍：最多 3 名 Battler，管理出战与存活判定。

const MAX_SIZE := 3

var members: Array = []
var active_index := 0

func _init(pet_ids: Array, level: int) -> void:
    for pid in pet_ids:
        if members.size() >= MAX_SIZE:
            break
        members.append(Battler.new(String(pid), level, 0))

func size() -> int:
    return members.size()

func get_member(i: int) -> Battler:
    if i < 0 or i >= members.size():
        return null
    return members[i]

func active() -> Battler:
    return get_member(active_index)

func alive_count() -> int:
    var n := 0
    for m in members:
        if m != null and m.is_alive():
            n += 1
    return n

func is_wiped() -> bool:
    return alive_count() == 0

## 返回第一个存活成员的索引；全灭返回 -1。
func first_alive_index() -> int:
    for i in members.size():
        var m: Battler = members[i]
        if m != null and m.is_alive():
            return i
    return -1

## 切换出战成员；目标必须存活。成功返回 true。
func switch_to(i: int) -> bool:
    var m := get_member(i)
    if m == null or not m.is_alive():
        return false
    active_index = i
    return true
```

- [ ] **步骤 4：运行测试验证通过**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --import --headless --path . | Out-Null
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：PASS（110 + 16 = 126），末行 `ALL PASS`。

- [ ] **步骤 5：Commit**

```powershell
git add scripts/battle/party.gd tests/self_check.gd
git commit -m "feat: 战斗队伍容器"
```

---

### 任务 2：3v3 战斗流程

**文件：**
- 修改：`scripts/battle/battle_scene.gd`
- 测试：`tests/self_check.gd`（`_check_battle_3v3`）

- [ ] **步骤 1：编写失败的测试**

```gdscript
func _check_battle_3v3() -> void:
    print("[3v3 战斗]")
    var b: Node2D = load("res://scripts/battle/battle_scene.gd").new()
    add_child(b)
    b.setup_teams(["grass", "water"], ["spark", "grass"], 4)
    await get_tree().process_frame
    _ok(b.ally_party.size() == 2, "我方队伍 2 人")
    _ok(b.foe_party.size() == 2, "敌方队伍 2 人")
    _ok(String(b.foe_party.active().data["name"]) == "星团子兽", "敌方出战为星团子兽")
    # 击倒敌方首发后应自动换人
    b.foe_party.get_member(0).take_damage(99999)
    b._auto_switch(b.foe_party)
    _ok(b.foe_party.active_index == 1, "敌方阵亡后自动换下一位")
    # 全灭判定
    b.foe_party.get_member(1).take_damage(99999)
    _ok(b.foe_party.is_wiped(), "敌方全灭")
    _ok(b._decide_result() == "win", "敌方全灭判胜")
    b.queue_free()
    await get_tree().process_frame
```

- [ ] **步骤 2：运行测试验证失败**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：FAIL，报 `Nonexistent function 'setup_teams'`。

- [ ] **步骤 3：编写最少实现代码**

在 `battle_scene.gd` 中把单 `ally`/`foe` 扩展为队伍。保留 `ally`/`foe` 作为「当前出战」的只读别名，避免破坏已有绘制与测试：

```gdscript
var ally_party: Party
var foe_party: Party

## 3v3 版本入口。双方各取最多 3 名。
func setup_teams(ally_ids: Array, foe_ids: Array, level: int) -> void:
    ally_party = Party.new(ally_ids, level)
    foe_party = Party.new(foe_ids, level)
    ally = ally_party.active()
    foe = foe_party.active()
    for pid in foe_ids:
        GameState.mark_seen(String(pid))
    _configured = true
    _log.clear()
    _round = 1
    _queue.clear()
    _floaters.clear()
    _result = ""
    state = "intro"
    _timer = 1.0
    _push_log("遇到了 %d 只野生团子兽！" % foe_party.size())

## 出战单位阵亡后自动切到下一个存活成员。
func _auto_switch(p: Party) -> void:
    if p == null or p.is_wiped():
        return
    if p.active() != null and p.active().is_alive():
        return
    var idx := p.first_alive_index()
    if idx >= 0:
        p.active_index = idx

## 依据双方队伍状态决定结果。
func _decide_result() -> String:
    if foe_party != null and foe_party.is_wiped():
        return "win"
    if ally_party != null and ally_party.is_wiped():
        return "lose"
    return ""
```

在 `_step_queue()` 每次结算后调用换人并刷新别名：

```gdscript
    _auto_switch(ally_party)
    _auto_switch(foe_party)
    ally = ally_party.active()
    foe = foe_party.active()
    var decided := _decide_result()
    if decided != "":
        _result = decided
        _finish()
        return
```

把 `_apply()` 的 `target` 改为对方**当前出战**单位（`foe_party.active()` / `ally_party.active()`），并在 `setup()` 中改为调用 `setup_teams([ally_id], [wild_id], level)` 以保持向后兼容。

- [ ] **步骤 4：运行测试验证通过**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：PASS（126 + 6 = 132），末行 `ALL PASS`。既有战斗测试应仍然通过。

- [ ] **步骤 5：Commit**

```powershell
git add scripts/battle/battle_scene.gd tests/self_check.gd
git commit -m "feat: 3v3 队伍战斗"
```

---

### 任务 3：装备表与强化 systems/upgrade.gd

**文件：**
- 创建：`scripts/data/equipment.gd`
- 创建：`scripts/systems/upgrade.gd`
- 测试：`tests/self_check.gd`（`_check_upgrade`）

- [ ] **步骤 1：编写失败的测试**

```gdscript
func _check_upgrade() -> void:
    print("[装备强化]")
    _ok(EquipmentDB.EQUIPMENT.size() >= 6, "装备表至少 6 件")
    var w: Dictionary = EquipmentDB.get_equip("wood_sword")
    _ok(String(w["slot"]) == "weapon", "木剑是武器槽")
    _ok(int(w["atk"]) > 0, "武器提供攻击加成")
    _ok(Upgrade.cost_for(0) <= Upgrade.cost_for(3), "强化费用随等级上升")
    var r0 := Upgrade.success_rate(0)
    var r9 := Upgrade.success_rate(9)
    _ok(r0 > r9, "强化成功率随等级下降（%.2f > %.2f）" % [r0, r9])
    _ok(r0 <= 1.0 and r9 >= 0.05, "成功率落在合理区间")
    _ok(Upgrade.can_afford(100, 1), "金币足够可强化")
    _ok(not Upgrade.can_afford(0, 9), "金币不足不可强化")
    var bonus := Upgrade.total_bonus("wood_sword", 5)
    _ok(int(bonus["atk"]) > int(w["atk"]), "强化提升装备加成")
```

- [ ] **步骤 2：运行测试验证失败**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：FAIL，报 `Identifier "EquipmentDB" not declared`。

- [ ] **步骤 3：编写最少实现代码**

创建 `scripts/data/equipment.gd`：

```gdscript
class_name EquipmentDB
extends RefCounted
## 装备表：槽位 weapon / armor / accessory。

const SLOTS := ["weapon", "armor", "accessory"]

const EQUIPMENT := {
    "wood_sword":   { "name": "木剑",   "slot": "weapon",    "atk": 3,  "def": 0, "hp": 0,  "price": 60 },
    "iron_sword":   { "name": "铁剑",   "slot": "weapon",    "atk": 7,  "def": 0, "hp": 0,  "price": 220 },
    "star_blade":   { "name": "星屑刃", "slot": "weapon",    "atk": 12, "def": 1, "hp": 0,  "price": 620 },
    "cloth_vest":   { "name": "布背心", "slot": "armor",     "atk": 0,  "def": 3, "hp": 8,  "price": 70 },
    "leaf_mail":    { "name": "叶甲",   "slot": "armor",     "atk": 0,  "def": 7, "hp": 16, "price": 260 },
    "mint_robe":    { "name": "薄荷袍", "slot": "armor",     "atk": 1,  "def": 5, "hp": 24, "price": 480 },
    "berry_charm":  { "name": "浆果符", "slot": "accessory", "atk": 2,  "def": 1, "hp": 10, "price": 150 },
    "star_charm":   { "name": "星尘符", "slot": "accessory", "atk": 4,  "def": 2, "hp": 18, "price": 520 },
}

static func get_equip(id: String) -> Dictionary:
    return EQUIPMENT.get(id, {})

static func equipments_for_slot(slot: String) -> Array:
    var out: Array = []
    for id in EQUIPMENT.keys():
        if String(EQUIPMENT[id]["slot"]) == slot:
            out.append(id)
    return out
```

创建 `scripts/systems/upgrade.gd`：

```gdscript
class_name Upgrade
extends RefCounted
## 强化：费用随等级上升，成功率随等级下降，最低 5%。

const BASE_COST := 40
const COST_GROWTH := 1.55
const MIN_RATE := 0.05
const MAX_LEVEL := 10
const BONUS_PER_LEVEL := 0.18

## 从 level 强化到 level+1 的费用。
static func cost_for(level: int) -> int:
    var lv := clampi(level, 0, MAX_LEVEL)
    return int(round(BASE_COST * pow(COST_GROWTH, lv)))

## 从 level 强化到 level+1 的成功率。
static func success_rate(level: int) -> float:
    var lv := clampi(level, 0, MAX_LEVEL)
    return maxf(MIN_RATE, 0.95 - lv * 0.09)

static func can_afford(coins: int, level: int) -> bool:
    return coins >= cost_for(level)

static func can_upgrade(level: int) -> bool:
    return level < MAX_LEVEL

## 装备在某等级下的总加成：基础值 × (1 + 0.18 × level)
static func total_bonus(equip_id: String, level: int) -> Dictionary:
    var e: Dictionary = EquipmentDB.get_equip(equip_id)
    if e.is_empty():
        return { "atk": 0, "def": 0, "hp": 0 }
    var m := 1.0 + BONUS_PER_LEVEL * maxi(0, level)
    return {
        "atk": int(round(int(e["atk"]) * m)),
        "def": int(round(int(e["def"]) * m)),
        "hp": int(round(int(e["hp"]) * m)),
    }

## 结算一次强化：返回 { success, level, cost }
static func attempt(equip_id: String, level: int, coins: int, roll: float) -> Dictionary:
    var cost := cost_for(level)
    if not can_upgrade(level) or coins < cost:
        return { "success": false, "level": level, "cost": 0 }
    if roll < success_rate(level):
        return { "success": true, "level": level + 1, "cost": cost }
    return { "success": false, "level": level, "cost": cost }
```

- [ ] **步骤 4：运行测试验证通过**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --import --headless --path . | Out-Null
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：PASS（132 + 9 = 141），末行 `ALL PASS`。

- [ ] **步骤 5：Commit**

```powershell
git add scripts/data/equipment.gd scripts/systems/upgrade.gd tests/self_check.gd
git commit -m "feat: 装备表与强化系统"
```

---

### 任务 4：商店经济 systems/shop.gd

**文件：**
- 创建：`scripts/systems/shop.gd`
- 创建：`scripts/ui/shop_panel.gd`
- 修改：`scripts/core/game_state.gd`
- 测试：`tests/self_check.gd`（`_check_shop`）

- [ ] **步骤 1：编写失败的测试**

```gdscript
func _check_shop() -> void:
    print("[商店]")
    GameState.new_game()
    var coins0 := int(GameState.player["coins"])
    _ok(Shop.buy_price("berry") == 20, "购买价等于标价")
    _ok(Shop.sell_price("berry") == 10, "出售价为标价一半")
    _ok(Shop.can_buy("berry", coins0), "金币足够可购买")
    _ok(not Shop.can_buy("star_blade", 0), "金币不足不可购买")
    GameState.player["coins"] = 100
    _ok(GameState.buy_item("berry"), "购买成功")
    _ok(int(GameState.player["coins"]) == 80, "购买扣款正确")
    _ok(int(GameState.inventory.get("berry", 0)) == 4, "购买入库")
    _ok(not GameState.buy_item("star_blade"), "买不起时不成交")
    var coins_before := int(GameState.player["coins"])
    _ok(GameState.sell_item("berry"), "出售成功")
    _ok(int(GameState.player["coins"]) > coins_before, "出售增加金币")
    _ok(GameState.buy_equipment("wood_sword"), "购买装备成功")
    _ok(GameState.owned_equipment.has("wood_sword"), "装备进入背包")
```

- [ ] **步骤 2：运行测试验证失败**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：FAIL，报 `Identifier "Shop" not declared`。

- [ ] **步骤 3：编写最少实现代码**

创建 `scripts/systems/shop.gd`：

```gdscript
class_name Shop
extends RefCounted
## 经济规则：纯函数。

const SELL_RATIO := 0.5

static func buy_price(item_id: String) -> int:
    var it: Dictionary = ItemDB.get_item(item_id)
    if not it.is_empty():
        return int(it.get("price", 0))
    var eq: Dictionary = EquipmentDB.get_equip(item_id)
    return int(eq.get("price", 0))

static func sell_price(item_id: String) -> int:
    return int(round(buy_price(item_id) * SELL_RATIO))

static func can_buy(item_id: String, coins: int) -> bool:
    var p := buy_price(item_id)
    return p > 0 and coins >= p
```

在 `game_state.gd` 中新增：

```gdscript
var owned_equipment: Array = []          # 已拥有的装备 id
var equipped := { "weapon": "", "armor": "", "accessory": "" }

func buy_item(item_id: String) -> bool:
    if not Shop.can_buy(item_id, int(player["coins"])):
        return false
    player["coins"] = int(player["coins"]) - Shop.buy_price(item_id)
    add_item(item_id, 1)
    return true

func sell_item(item_id: String) -> bool:
    if not consume_item(item_id):
        return false
    player["coins"] = int(player["coins"]) + Shop.sell_price(item_id)
    state_changed.emit()
    return true

func buy_equipment(equip_id: String) -> bool:
    if not Shop.can_buy(equip_id, int(player["coins"])):
        return false
    player["coins"] = int(player["coins"]) - Shop.buy_price(equip_id)
    if not owned_equipment.has(equip_id):
        owned_equipment.append(equip_id)
    state_changed.emit()
    return true

## 装备到对应槽位。
func equip_item(equip_id: String) -> bool:
    if not owned_equipment.has(equip_id):
        return false
    var e: Dictionary = EquipmentDB.get_equip(equip_id)
    if e.is_empty():
        return false
    equipped[String(e["slot"])] = equip_id
    state_changed.emit()
    return true

## 所有已装备物品的合计加成。
func equipment_bonus() -> Dictionary:
    var total := { "atk": 0, "def": 0, "hp": 0 }
    for slot in equipped.keys():
        var id := String(equipped[slot])
        if id == "":
            continue
        var lv := int(equip_levels.get(id, 0))
        var b: Dictionary = Upgrade.total_bonus(id, lv)
        total["atk"] = int(total["atk"]) + int(b["atk"])
        total["def"] = int(total["def"]) + int(b["def"])
        total["hp"] = int(total["hp"]) + int(b["hp"])
    return total
```

同时在 `game_state.gd` 增加 `var equip_levels := {}`，把这两个新字段加入 `to_dict()`/`from_dict()`/`new_game()`。

创建 `scripts/ui/shop_panel.gd`：仿 `journal.gd` 的遮罩+卡片结构，用 `ItemList` 展示可买商品（名称 + 价格），按钮区含「购买/出售/装备」，全部操作后重建列表并刷新 HUD。

- [ ] **步骤 4：运行测试验证通过**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --import --headless --path . | Out-Null
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：PASS（141 + 12 = 153），末行 `ALL PASS`。

- [ ] **步骤 5：Commit**

```powershell
git add scripts/systems/shop.gd scripts/ui/shop_panel.gd scripts/core/game_state.gd tests/self_check.gd
git commit -m "feat: 商店买卖与装备穿戴"
```

---

### 任务 5：任务系统 data/quests.gd + systems/quest.gd

**文件：**
- 创建：`scripts/data/quests.gd`
- 创建：`scripts/systems/quest.gd`
- 创建：`scripts/ui/quest_log.gd`
- 测试：`tests/self_check.gd`（`_check_quest`）

- [ ] **步骤 1：编写失败的测试**

```gdscript
func _check_quest() -> void:
    print("[任务]")
    _ok(QuestDB.QUESTS.size() >= 4, "任务表至少 4 条")
    var q: Dictionary = QuestDB.get_quest("first_battle")
    _ok(String(q["type"]) == "main", "首战任务为主线")
    _ok(int(q["goal"]) >= 1, "任务目标为正数")
    GameState.new_game()
    _ok(GameState.active_quests.size() > 0, "新游戏激活初始任务")
    var before := GameState.quest_progress("first_battle")
    _ok(Quest.advance(GameState, "battle_win", 1) >= 0, "推进任务返回推进量")
    _ok(GameState.quest_progress("first_battle") > before, "任务进度增加")
    # 达成目标后应可领取
    for i in 5:
        Quest.advance(GameState, "battle_win", 1)
    _ok(Quest.is_complete(GameState, "first_battle"), "达到目标视为完成")
    GameState.player["coins"] = 0
    _ok(Quest.claim(GameState, "first_battle"), "可领取任务奖励")
    _ok(int(GameState.player["coins"]) > 0, "奖励金币到账")
    _ok(not Quest.claim(GameState, "first_battle"), "奖励不可重复领取")
    _ok(GameState.is_quest_claimed("first_battle"), "已领取状态被记录")
```

- [ ] **步骤 2：运行测试验证失败**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：FAIL，报 `Identifier "QuestDB" not declared`。

- [ ] **步骤 3：编写最少实现代码**

创建 `scripts/data/quests.gd`：

```gdscript
class_name QuestDB
extends RefCounted
## 任务表。event 与游戏内事件名对应，goal 为需要的次数。

const QUESTS := {
    "first_battle": {
        "name": "初次交手", "type": "main", "event": "battle_win", "goal": 1,
        "reward": { "coins": 60, "exp": 20, "items": { "berry": 2 } },
        "desc": "在小镇外赢得一场战斗。", "next": "catch_three",
    },
    "catch_three": {
        "name": "收服同伴", "type": "main", "event": "capture_ok", "goal": 3,
        "reward": { "coins": 140, "exp": 60, "items": { "capture_ball": 3 } },
        "desc": "收服 3 只团子兽。", "next": "reach_level_ten",
    },
    "reach_level_ten": {
        "name": "成长之路", "type": "main", "event": "level_up", "goal": 9,
        "reward": { "coins": 300, "exp": 120, "items": { "star_dust": 2 } },
        "desc": "把小团子练到 10 级。", "next": "",
    },
    "daily_battle": {
        "name": "日常：多多练习", "type": "daily", "event": "battle_win", "goal": 3,
        "reward": { "coins": 80, "exp": 30, "items": { "berry": 1 } },
        "desc": "今日赢得 3 场战斗。", "next": "",
    },
    "daily_capture": {
        "name": "日常：结识新友", "type": "daily", "event": "capture_ok", "goal": 1,
        "reward": { "coins": 50, "exp": 20, "items": {} },
        "desc": "今日收服 1 只团子兽。", "next": "",
    },
}

const INITIAL := ["first_battle"]

static func get_quest(id: String) -> Dictionary:
    return QUESTS.get(id, {})
```

创建 `scripts/systems/quest.gd`：

```gdscript
class_name Quest
extends RefCounted
## 任务进度推进与奖励结算。操作 GameState，但自身不依赖场景树。

## 推进所有监听该事件的进行中任务。返回总推进量。
static func advance(gs: Node, event: String, amount: int = 1) -> int:
    var total := 0
    for qid in gs.active_quests:
        var q: Dictionary = QuestDB.get_quest(String(qid))
        if q.is_empty() or String(q["event"]) != event:
            continue
        if is_complete(gs, String(qid)):
            continue
        gs.quest_progress_map[String(qid)] = int(gs.quest_progress_map.get(String(qid), 0)) + amount
        total += amount
    if total > 0:
        gs.state_changed.emit()
    return total

static func is_complete(gs: Node, quest_id: String) -> bool:
    var q: Dictionary = QuestDB.get_quest(quest_id)
    if q.is_empty():
        return false
    return int(gs.quest_progress_map.get(quest_id, 0)) >= int(q["goal"])

## 领取奖励；成功返回 true。完成主线后解锁下一条。
static func claim(gs: Node, quest_id: String) -> bool:
    if not is_complete(gs, quest_id) or gs.is_quest_claimed(quest_id):
        return false
    var q: Dictionary = QuestDB.get_quest(quest_id)
    var reward: Dictionary = q.get("reward", {})
    gs.player["coins"] = int(gs.player["coins"]) + int(reward.get("coins", 0))
    gs.gain_exp(int(reward.get("exp", 0)))
    for iid in (reward.get("items", {}) as Dictionary).keys():
        gs.add_item(String(iid), int(reward["items"][iid]))
    gs.claimed_quests.append(quest_id)
    var nxt := String(q.get("next", ""))
    if nxt != "" and not gs.active_quests.has(nxt):
        gs.active_quests.append(nxt)
    gs.state_changed.emit()
    return true
```

在 `game_state.gd` 增加 `active_quests`、`quest_progress_map`、`claimed_quests` 三个字段及其存取：

```gdscript
func quest_progress(quest_id: String) -> int:
    return int(quest_progress_map.get(quest_id, 0))

func is_quest_claimed(quest_id: String) -> bool:
    return claimed_quests.has(quest_id)
```

在 `new_game()` 中初始化为 `active_quests = QuestDB.INITIAL.duplicate()`、两个空容器；三者一并进入 `to_dict`/`from_dict`。

在战斗胜利与收服成功处调用 `Quest.advance(self, "battle_win")` / `Quest.advance(self, "capture_ok")`；在 `gain_exp` 的升级分支里调用 `Quest.advance(self, "level_up")`。

创建 `scripts/ui/quest_log.gd`：列表展示进行中任务的名称、描述、进度（`n/goal`）、类型，完成的可点「领取」；已领取置灰。

- [ ] **步骤 4：运行测试验证通过**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --import --headless --path . | Out-Null
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：PASS（153 + 11 = 164），末行 `ALL PASS`。

- [ ] **步骤 5：Commit**

```powershell
git add scripts/data/quests.gd scripts/systems/quest.gd scripts/ui/quest_log.gd scripts/core/game_state.gd scripts/battle/battle_scene.gd tests/self_check.gd
git commit -m "feat: 任务系统（主线与日常）"
```

---

### 任务 6：多区域与场景切换

**文件：**
- 创建：`scripts/world/areas.gd`
- 修改：`scripts/world/world.gd`
- 测试：`tests/self_check.gd`（`_check_areas`）

- [ ] **步骤 1：编写失败的测试**

```gdscript
func _check_areas() -> void:
    print("[区域]")
    _ok(AreaDB.AREAS.size() >= 3, "至少 3 个区域")
    var a: Dictionary = AreaDB.get_area("acorn")
    _ok(String(a["name"]) == "橡果小镇", "小镇名称正确")
    _ok(a.has("size") and a.has("spawn"), "区域含尺寸与出生点")
    _ok(AreaDB.get_area("__nope__").is_empty(), "未知区域返回空")
    _ok(AreaDB.AREAS.has("acorn"), "初始区域存在")
    _ok(AreaDB.get_area("acorn").has("exits"), "区域定义了出入口")
    var exits: Array = AreaDB.get_area("acorn")["exits"]
    _ok(exits.size() >= 1, "小镇至少一个出口")
    _ok(AreaDB.get_area(String(exits[0]["to"])).size() > 0, "出口指向有效区域")
```

- [ ] **步骤 2：运行测试验证失败**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：FAIL，报 `Identifier "AreaDB" not declared`。

- [ ] **步骤 3：编写最少实现代码**

创建 `scripts/world/areas.gd`：

```gdscript
class_name AreaDB
extends RefCounted
## 区域定义：每个区域的尺寸、出生点、装饰与出入口。

const AREAS := {
    "acorn": {
        "name": "橡果小镇",
        "size": Vector2(2400, 1600),
        "spawn": Vector2(1120, 760),
        "theme": "town",
        "exits": [
            { "to": "meadow", "at": Vector2(2350, 800), "radius": 120.0 },
        ],
    },
    "meadow": {
        "name": "风语草甸",
        "size": Vector2(2200, 1500),
        "spawn": Vector2(120, 780),
        "theme": "wild",
        "encounter_rate": 0.55,
        "exits": [
            { "to": "acorn", "at": Vector2(80, 780), "radius": 120.0 },
            { "to": "grove", "at": Vector2(2120, 700), "radius": 120.0 },
        ],
    },
    "grove": {
        "name": "星屑林",
        "size": Vector2(2000, 1400),
        "spawn": Vector2(120, 700),
        "theme": "forest",
        "encounter_rate": 0.65,
        "exits": [
            { "to": "meadow", "at": Vector2(80, 700), "radius": 120.0 },
        ],
    },
}

static func get_area(id: String) -> Dictionary:
    return AREAS.get(id, {})

## 检查某位置是否触发出口，返回目标区域 id（无则空串）。
static func exit_at(area_id: String, pos: Vector2) -> String:
    var a: Dictionary = get_area(area_id)
    if a.is_empty():
        return ""
    for e in (a.get("exits", []) as Array):
        var at: Vector2 = e["at"]
        if pos.distance_to(at) <= float(e.get("radius", 100.0)):
            return String(e["to"])
    return ""
```

修改 `world.gd`：把 `WORLD_SIZE` 改为从当前区域读取的成员变量，新增 `area_id`、`change_area(id)`（清空装饰与 NPC、按新区域重建、玩家放到 `spawn`、相机归位），并在 `_process` 中检测 `AreaDB.exit_at(area_id, player.position)` 非空时切区域。遭遇概率改用 `area["encounter_rate"]`（小镇无该字段则为 0，即安全区）。

- [ ] **步骤 4：运行测试验证通过**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --import --headless --path . | Out-Null
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：PASS（164 + 8 = 172），末行 `ALL PASS`。

- [ ] **步骤 5：Commit**

```powershell
git add scripts/world/areas.gd scripts/world/world.gd tests/self_check.gd
git commit -m "feat: 多区域与场景切换"
```

---

### 任务 7：存档导入导出与版本迁移

**文件：**
- 创建：`scripts/core/save_migrate.gd`
- 修改：`scripts/core/game_state.gd`
- 修改：`scripts/ui/hud.gd`
- 测试：`tests/self_check.gd`（`_check_migrate`）

- [ ] **步骤 1：编写失败的测试**

```gdscript
func _check_migrate() -> void:
    print("[存档迁移]")
    _ok(SaveMigrate.CURRENT_VERSION >= 3, "当前存档版本不低于 3")
    # v1 老存档应能迁移到当前版本
    var old := {
        "version": 1,
        "player": { "name": "小团子", "level": 4, "hp": 30, "max_hp": 90,
                    "atk": 14, "def": 11, "spd": 10, "coins": 500, "star_dust": 1 },
        "inventory": { "berry": 2 },
        "party": ["grass"],
        "seen": [], "caught": [], "flags": {},
    }
    var migrated: Dictionary = SaveMigrate.migrate(old)
    _ok(int(migrated["version"]) == SaveMigrate.CURRENT_VERSION, "版本号被提升")
    _ok(migrated.has("appearance"), "补齐了外貌字段")
    _ok(migrated["player"].has("attrs"), "补齐了四维属性")
    _ok(migrated.has("active_quests"), "补齐了任务字段")
    _ok(migrated.has("equipped"), "补齐了装备字段")
    _ok(migrated.has("owned_equipment"), "补齐了装备背包")
    _ok(int(migrated["player"]["level"]) == 4, "迁移不丢失已有数据")
    _ok(SaveMigrate.migrate({}).is_empty(), "非法存档返回空")
    # 完整往返
    GameState.new_game()
    GameState.player["coins"] = 777
    var dump: String = GameState.export_save_string()
    GameState.new_game()
    _ok(GameState.import_save_string(dump), "导入字符串存档成功")
    _ok(int(GameState.player["coins"]) == 777, "导入后数据一致")
    _ok(not GameState.import_save_string("{不是 JSON"), "非法 JSON 被拒绝")
```

- [ ] **步骤 2：运行测试验证失败**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：FAIL，报 `Identifier "SaveMigrate" not declared`。

- [ ] **步骤 3：编写最少实现代码**

创建 `scripts/core/save_migrate.gd`：

```gdscript
class_name SaveMigrate
extends RefCounted
## 存档版本迁移：链式升级，每步只处理一个版本跨度。
## 迁移函数只补字段与改格式，不改变已存在的玩家数据。

const CURRENT_VERSION := 3

## 入口：把任意版本存档提升到 CURRENT_VERSION。非法输入返回空字典。
static func migrate(d: Dictionary) -> Dictionary:
    if typeof(d) != TYPE_DICTIONARY or not d.has("player"):
        return {}
    if typeof(d["player"]) != TYPE_DICTIONARY:
        return {}
    var out: Dictionary = d.duplicate(true)
    var v := int(out.get("version", 1))
    if v < 1:
        v = 1
    while v < CURRENT_VERSION:
        out = _step(out, v)
        v = int(out["version"])
    out["version"] = CURRENT_VERSION
    return out

static func _step(d: Dictionary, from_version: int) -> Dictionary:
    match from_version:
        1: return _v1_to_v2(d)
        2: return _v2_to_v3(d)
        _: 
            d["version"] = from_version + 1
            return d

## v1 -> v2：加入外观与四维属性。
static func _v1_to_v2(d: Dictionary) -> Dictionary:
    var out := d
    if not out.has("appearance"):
        out["appearance"] = { "preset": "classic" }
    var p: Dictionary = out["player"]
    if not p.has("attrs"):
        p["attrs"] = { "str": 0, "vit": 0, "agi": 0, "int": 0 }
    if not p.has("spent_points"):
        p["spent_points"] = 0
    out["version"] = 2
    return out

## v2 -> v3：加入任务、装备与队伍状态。
static func _v2_to_v3(d: Dictionary) -> Dictionary:
    var out := d
    if not out.has("active_quests"):
        out["active_quests"] = QuestDB.INITIAL.duplicate()
    if not out.has("quest_progress_map"):
        out["quest_progress_map"] = {}
    if not out.has("claimed_quests"):
        out["claimed_quests"] = []
    if not out.has("owned_equipment"):
        out["owned_equipment"] = []
    if not out.has("equipped"):
        out["equipped"] = { "weapon": "", "armor": "", "accessory": "" }
    if not out.has("equip_levels"):
        out["equip_levels"] = {}
    out["version"] = 3
    return out
```

在 `game_state.gd` 中：`from_dict` 改为先调用 `SaveMigrate.migrate(d)`，空则返回 false；新增两个字符串级 API：

```gdscript
func export_save_string() -> String:
    return JSON.stringify(to_dict(), "  ")

func import_save_string(text: String) -> bool:
    var parsed: Variant = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        return false
    return from_dict(parsed as Dictionary)
```

在 `hud.gd` 增加按钮「导出存档 / 导入存档」：导出把 `export_save_string()` 写文件并用 `OS.shell_show_in_file_manager` 提示位置；导入用 `FileDialog` 选文件后调 `import_save_string`。

- [ ] **步骤 4：运行测试验证通过**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --import --headless --path . | Out-Null
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：PASS（172 + 12 = 184），末行 `ALL PASS`。

- [ ] **步骤 5：Commit**

```powershell
git add scripts/core/save_migrate.gd scripts/core/game_state.gd scripts/ui/hud.gd tests/self_check.gd
git commit -m "feat: 存档导入导出与版本迁移"
```

---

### 任务 8：图鉴扩充到 15 只

**文件：**
- 修改：`scripts/data/pets.gd`
- 测试：`tests/self_check.gd`（`_check_data` 内追加）

- [ ] **步骤 1：编写失败的测试**

在 `_check_data()` 末尾追加：

```gdscript
    _ok(PetDB.PETS.size() >= 15, "图鉴扩充到至少 15 只（当前 %d）" % PetDB.PETS.size())
    var names: Array = []
    var ids: Array = []
    for pid in PetDB.PETS.keys():
        var p: Dictionary = PetDB.get_pet(String(pid))
        names.append(String(p["name"]))
        ids.append(String(pid))
        _ok(ElementDB.ELEMENTS.has(String(p["element"])), "%s 的属性合法" % p["name"])
        _ok(not (p["skills"] as Array).is_empty(), "%s 拥有技能" % p["name"])
        _ok(int(p["hp"]) > 0 and int(p["atk"]) > 0, "%s 数值为正" % p["name"])
    _ok(names.size() == _unique_count(names), "图鉴名称无重复")
    _ok(ids.size() == _unique_count(ids), "图鉴 id 无重复")

func _unique_count(arr: Array) -> int:
    var seen := {}
    for x in arr:
        seen[x] = true
    return seen.size()
```

- [ ] **步骤 2：运行测试验证失败**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：FAIL，报「图鉴扩充到至少 15 只（当前 3）」。

- [ ] **步骤 3：编写最少实现代码**

把 `scripts/data/pets.gd` 的 `PETS` 扩充为 15 只。保持既有 3 只（`grass`/`water`/`spark`）的键与名不变（已有测试依赖），新增 12 只，属性分布为 草 5 / 水 5 / 星 5。每只都必须有 `name/element/hp/atk/def/spd/body/edge/horn/skills/desc` 全部字段。示例新增 3 只：

```gdscript
    "leaf": {
        "name": "叶团子兽", "element": "草",
        "hp": 50, "atk": 12, "def": 10, "spd": 10,
        "body": "b8e89a", "edge": "8bc973", "horn": "5b9448",
        "skills": ["tackle", "heal"],
        "desc": "总把叶子当被子盖的小家伙。",
    },
    "brook": {
        "name": "溪团子兽", "element": "水",
        "hp": 54, "atk": 13, "def": 9, "spd": 12,
        "body": "a8dcf0", "edge": "7fb8d8", "horn": "5a9ec0",
        "skills": ["tackle", "bubble"],
        "desc": "跑起来会发出溪水一样的叮咚声。",
    },
    "comet": {
        "name": "彗团子兽", "element": "星",
        "hp": 44, "atk": 18, "def": 6, "spd": 16,
        "body": "ffd9a8", "edge": "e0a83c", "horn": "d9b24e",
        "skills": ["tackle", "spark"],
        "desc": "夜里像一道小流星划过天空。",
    },
```

其余 9 只（合计 15 只，草 5 / 水 5 / 星 5）：

```gdscript
    "fern": {
        "name": "蕨团子兽", "element": "草",
        "hp": 48, "atk": 14, "def": 8, "spd": 13,
        "body": "a0d888", "edge": "78b866", "horn": "4f9d46",
        "skills": ["tackle", "bubble"],
        "desc": "喜欢躲在蕨叶底下打盹。",
    },
    "moss": {
        "name": "苔团子兽", "element": "草",
        "hp": 60, "atk": 10, "def": 14, "spd": 7,
        "body": "9ccc94", "edge": "6fa86a", "horn": "527f4e",
        "skills": ["tackle", "heal"],
        "desc": "背上长着软软的苔藓，摸起来凉凉的。",
    },
    "sprout_big": {
        "name": "茂团子兽", "element": "草",
        "hp": 56, "atk": 15, "def": 11, "spd": 9,
        "body": "8fd67a", "edge": "63b054", "horn": "3f8438",
        "skills": ["tackle", "spark", "heal"],
        "desc": "头顶的嫩芽长得格外茂盛，是成年的标志。",
    },
    "dew": {
        "name": "露团子兽", "element": "水",
        "hp": 50, "atk": 12, "def": 10, "spd": 13,
        "body": "c0e8f8", "edge": "8ec4dc", "horn": "6aa8c4",
        "skills": ["tackle", "heal"],
        "desc": "清晨的露水会在它身上凝成小珠子。",
    },
    "wave": {
        "name": "浪团子兽", "element": "水",
        "hp": 62, "atk": 14, "def": 12, "spd": 8,
        "body": "88c8e8", "edge": "5f9ec4", "horn": "4a86b0",
        "skills": ["tackle", "bubble", "heal"],
        "desc": "蹦跳时会溅起一小片水花。",
    },
    "frost": {
        "name": "霜团子兽", "element": "水",
        "hp": 46, "atk": 16, "def": 8, "spd": 15,
        "body": "d8f0ff", "edge": "a0c8e0", "horn": "7aa8c8",
        "skills": ["tackle", "bubble", "spark"],
        "desc": "呼出的气会结成小小的霜花。",
    },
    "nova": {
        "name": "新星团子兽", "element": "星",
        "hp": 42, "atk": 20, "def": 6, "spd": 17,
        "body": "ffe0a0", "edge": "e0b850", "horn": "d0a038",
        "skills": ["tackle", "spark"],
        "desc": "诞生时会短暂地明亮一下。",
    },
    "orbit": {
        "name": "环星团子兽", "element": "星",
        "hp": 52, "atk": 17, "def": 10, "spd": 13,
        "body": "f0dcb0", "edge": "c8b070", "horn": "b09850",
        "skills": ["tackle", "spark", "heal"],
        "desc": "身边总有一圈细细的光环在转。",
    },
    "dusk": {
        "name": "暮团子兽", "element": "星",
        "hp": 58, "atk": 15, "def": 13, "spd": 10,
        "body": "d8c8f0", "edge": "a890c8", "horn": "8f78b0",
        "skills": ["tackle", "spark", "bubble"],
        "desc": "黄昏时最活跃，身上的微光格外明显。",
    },
```

同时把 `WILD_POOL` 更新为按区域划分的字典：

```gdscript
const WILD_POOL := ["grass", "water", "spark", "leaf", "brook", "comet"]

## 按区域返回可遭遇的野生团子兽 id。
static func pool_for_area(theme: String) -> Array:
    match theme:
        "forest": return ["leaf", "comet", "grass", "spark"]
        "wild":   return ["grass", "water", "brook", "spark"]
        _:        return WILD_POOL
```

- [ ] **步骤 4：运行测试验证通过**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
```

预期：PASS（184 + 34 = 218），末行 `ALL PASS`。

- [ ] **步骤 5：Commit**

```powershell
git add scripts/data/pets.gd tests/self_check.gd
git commit -m "feat: 图鉴扩充到 15 只团子兽"
```

---

### 任务 9：阶段三收尾——验收文档、导出与发布

**文件：**
- 修改：`docs/acceptance.md`、`README.md`

- [ ] **步骤 1：追加手动验收项**

在 `docs/acceptance.md` 末尾追加：

```markdown
## 阶段三新增
- [ ] 队伍战斗：我方 3 人可依次上场，阵亡后自动换人
- [ ] 敌方全灭判胜、我方全灭判负
- [ ] 商店可买道具与装备，金币正确扣减
- [ ] 装备后属性生效，强化会失败且消耗金币
- [ ] 任务日志显示进度，完成后可领取奖励且不可重复领取
- [ ] 从橡果小镇走到风语草甸、再走到星屑林，区域切换正常
- [ ] 野外遇敌率高于小镇（小镇为安全区）
- [ ] 导出存档后清档，再导入能恢复全部进度
- [ ] 图鉴显示 15 只团子兽，未收服的显示为灰
```

- [ ] **步骤 2：更新 README 玩法段落**

在 `README.md` 的「玩法现状」中补上阶段二、三的系统（属性克制、暴击闪避、收服、四维养成、外貌、音效、3v3、装备强化、商店、任务、多区域），并把自检项数更新为当前实际数量。

- [ ] **步骤 3：完整验证**

```powershell
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/self_check.tscn
& ".\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --export-release "Windows Desktop" "build/Tuanzi.exe" | Out-Null
& ".\build\Tuanzi.exe" --headless --quit-after 150
```

预期：自检全绿、导出成功、启动退出码 0。

- [ ] **步骤 4：Commit、打 tag 并发布**

```powershell
git add docs/acceptance.md README.md
git commit -m "docs: 阶段三验收项与玩法说明"
git tag v0.3.0
git push origin main --tags
```

然后在 GitHub 用 `gh release create` 或网页上传 `build/Tuanzi.exe` 作为 v0.3.0 附件（exe 超过仓库单文件 100 MB 上限，必须走 Release）。

---

## 阶段门禁

1. `self_check.tscn` 全绿（218 项）、退出码 0
2. `build/Tuanzi.exe` 导出并启动无错
3. `docs/acceptance.md` 含阶段三验收项，README 已更新
4. 推送并打 tag `v0.3.0`，Release 附件已上传
