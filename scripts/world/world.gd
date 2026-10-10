extends Node2D
## 主世界：橡果小镇。程序化绘制地面、装饰、NPC、玩家与相机。

signal battle_requested(wild_id: String, level: int)

const WORLD_SIZE := Vector2(2400, 1600)

var player: Actor
var camera: Camera2D
var npcs: Array = []
var _deco_static := []      # 静态装饰（树/房/栅栏）配置；_build_decor 后转为 _deco_nodes
var _deco_nodes: Array = []   # 对应的 WorldDeco 子节点（参与 y-sort）
var _grass_tufts := []
var _lamp_glow := 0.0
var _obstacles := []            # 阻挡椭圆 { center: Vector2, radii: Vector2 }
var _npc_bubble: Node = null
var _journal: CanvasLayer = null
var _appearance: CanvasLayer = null
var _step_cd := 0.0

func _ready() -> void:
    # y-sort：让树/房/栅栏与 player、NPC 按 y 正确前后遮挡。
    # Godot 的 y_sort 只在父子节点之间生效，而装饰是 world._draw() 里
    # 手绘的普通数组（_deco_static），永远先于子节点绘制 —— 角色会
    # 从树后面直接穿过去显示。开启 y_sort 后装饰需改为真实子节点。
    y_sort_enabled = true
    _build_decor()
    _spawn_player()
    _spawn_npcs()
    _setup_camera()
    _setup_ui()

func world_rect() -> Rect2:
    return Rect2(Vector2(15, 15), WORLD_SIZE - Vector2(30, 30))

# —— 场景搭建 ——

func _build_decor() -> void:
    # 随机草簇（固定种子保证每次一致）
    var rng := RandomNumberGenerator.new()
    rng.seed = 20261010
    for i in 220:
        _grass_tufts.append({
            "pos": Vector2(rng.randf_range(60, WORLD_SIZE.x - 60),
                           rng.randf_range(60, WORLD_SIZE.y - 60)),
            "h": rng.randf_range(6, 12),
            "tint": rng.randf(),
            "sway": rng.randf() * TAU,
        })
    # 房屋
    _deco_static.append({ "kind": "house", "pos": Vector2(420, 430), "w": 190.0, "h": 130.0,
        "wall": Palette.WALL, "roof": Palette.ROOF })
    _deco_static.append({ "kind": "house", "pos": Vector2(700, 360), "w": 150.0, "h": 110.0,
        "wall": Palette.WALL_DEEP, "roof": Palette.ROOF_DEEP })
    _deco_static.append({ "kind": "house", "pos": Vector2(1780, 520), "w": 200.0, "h": 140.0,
        "wall": Palette.WALL, "roof": Palette.PINK_DEEP })
    # 池塘
    _deco_static.append({ "kind": "pond", "pos": Vector2(1180, 900),
        "rx": 170.0, "ry": 96.0 })
    # 水面不可涉入（收窄一点，让边缘看起来是岸）
    _obstacles.append({ "center": Vector2(1180, 900), "radii": Vector2(158.0, 84.0) })
    # 房屋占位
    _obstacles.append({ "center": Vector2(420, 430), "radii": Vector2(100.0, 70.0) })
    _obstacles.append({ "center": Vector2(700, 360), "radii": Vector2(80.0, 58.0) })
    _obstacles.append({ "center": Vector2(1780, 520), "radii": Vector2(105.0, 74.0) })
    # 树
    var tree_spots := [
        Vector2(180, 300), Vector2(250, 780), Vector2(560, 1150), Vector2(980, 320),
        Vector2(1500, 260), Vector2(2050, 980), Vector2(2200, 380), Vector2(1330, 1330),
        Vector2(760, 1420), Vector2(300, 1330), Vector2(1900, 1350), Vector2(1660, 1180),
    ]
    for i in tree_spots.size():
        _deco_static.append({ "kind": "tree", "pos": tree_spots[i],
            "scale": 0.85 + float(i % 4) * 0.13, "sway": float(i) })
    # 灌木
    var bush_spots := [Vector2(880, 720), Vector2(1420, 700), Vector2(640, 900),
        Vector2(1700, 880), Vector2(1080, 1180), Vector2(2050, 700)]
    for i in bush_spots.size():
        _deco_static.append({ "kind": "bush", "pos": bush_spots[i],
            "scale": 0.9 + float(i % 3) * 0.15 })
    # 路灯
    for p in [Vector2(620, 620), Vector2(1000, 640), Vector2(1560, 620), Vector2(1960, 760)]:
        _deco_static.append({ "kind": "lamp", "pos": p })
    # 栅栏（围出一片花圃）
    _deco_static.append({ "kind": "fence", "from": Vector2(1600, 300), "to": Vector2(1900, 300) })
    _deco_static.append({ "kind": "fence", "from": Vector2(1600, 300), "to": Vector2(1600, 460) })
    _deco_static.append({ "kind": "fence", "from": Vector2(900, 1250), "to": Vector2(900, 1420) })
    _deco_static.append({ "kind": "fence", "from": Vector2(900, 1420), "to": Vector2(1140, 1420) })

    # 装饰必须成为真实子节点才能参与 y-sort（见 WorldDeco 顶部说明）。
    _spawn_deco_nodes()

## 把 _deco_static 里的每一项实例化成 WorldDeco 子节点。
## world 自身只保留地面、小径与草簇（地面永远在最底，装饰与角色的前后关系
## 完全交给 y_sort 处理）。
func _spawn_deco_nodes() -> void:
    # _deco_static 保留为配置来源（自检会断言装饰数量），不再被清空。
    for i in _deco_static.size():
        var d: Dictionary = _deco_static[i]
        var node := WorldDeco.new()
        var py: float = 0.0
        if d.has("pos"):
            py = float((d["pos"] as Vector2).y)
        elif d.has("from"):
            py = maxf(float((d["from"] as Vector2).y), float((d["to"] as Vector2).y))
        node.sort_y = py
        node.position = Vector2(0, py)
        # 绘制改用局部坐标（以自身 y 为原点），z_index 仍按世界 y 设置，
        # 于是「z 序 = 世界 y 序」，与 player 的 z_index=int(position.y) 对齐。
        node.spec = d.duplicate(true)
        if d.has("pos"):
            node.spec["pos"] = (d["pos"] as Vector2) - Vector2(0, py)
        if d.has("from"):
            node.spec["from"] = (d["from"] as Vector2) - Vector2(0, py)
            node.spec["to"] = (d["to"] as Vector2) - Vector2(0, py)
        node.name = "Deco_%s_%d" % [String(d["kind"]), i]
        add_child(node)
        _deco_nodes.append(node)

func _spawn_player() -> void:
    player = preload("res://scripts/world/player.gd").new()
    player.position = Vector2(1120, 760)
    add_child(player)
    player.interact_requested.connect(_on_interact)

func _spawn_npcs() -> void:
    var defs := [
        { "name": "阿栗", "pos": Vector2(640, 700), "wander": false,
          "body": "f7d98a", "edge": "d9b24e", "horn": "e0a83c",
          "lines": ["欢迎来到橡果小镇，小团子！", "往东边走能看到大池塘哦。"] },
        { "name": "莓莓", "pos": Vector2(1260, 980), "wander": true,
          "body": "f4a0a8", "edge": "d97f8c", "horn": "6fbf5f",
          "lines": ["池塘边凉快得很～", "听说星团子兽只在夜里出现。"] },
        { "name": "老橡", "pos": Vector2(1820, 700), "wander": false,
          "body": "c9a27a", "edge": "a8825c", "horn": "5b9448",
          "lines": ["这片林子我守了三十年喽。", "想练练手？野地里随时能碰上团子兽。"] },
    ]
    for d in defs:
        var n := preload("res://scripts/world/npc.gd").new()
        n.npc_name = String(d["name"])
        n.position = Vector2(d["pos"])
        n.wander = bool(d["wander"])
        for l in (d["lines"] as Array):
            n.lines.append(String(l))
        n.set_colors(Color(String(d["body"])), Color(String(d["edge"])), Color(String(d["horn"])))
        add_child(n)
        # 头顶名牌
        n.add_child(_make_label(String(d["name"])))
        npcs.append(n)

func _make_label(text: String) -> Label:
    var label := Label.new()
    label.text = text
    label.position = Vector2(-40, -96)
    label.custom_minimum_size = Vector2(80, 0)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 15)
    label.add_theme_color_override("font_color", Palette.INK)
    label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
    label.add_theme_constant_override("outline_size", 4)
    return label

func _setup_camera() -> void:
    camera = Camera2D.new()
    camera.position_smoothing_enabled = true
    camera.position_smoothing_speed = 6.0
    camera.zoom = Vector2(1.35, 1.35)
    add_child(camera)
    camera.make_current()
    camera.global_position = player.global_position
    _clamp_camera()

func _setup_ui() -> void:
    var hud := preload("res://scripts/ui/hud.gd").new()
    hud.name = "HUD"
    add_child(hud)
    _journal = preload("res://scripts/ui/journal.gd").new()
    _journal.name = "Journal"
    add_child(_journal)
    _appearance = preload("res://scripts/ui/appearance_panel.gd").new()
    _appearance.name = "Appearance"
    add_child(_appearance)
    _appearance.player_ref = player

func _unhandled_input(e: InputEvent) -> void:
    if _journal == null:
        return
    if e.is_action_pressed("menu"):
        _journal.toggle()
        get_viewport().set_input_as_handled()
    elif e.is_action_pressed("appearance"):
        _appearance.toggle()
        get_viewport().set_input_as_handled()
    elif e.is_action_pressed("cancel") and _appearance.is_open():
        _appearance.close()
        get_viewport().set_input_as_handled()
    elif e.is_action_pressed("cancel") and _journal.is_open():
        _journal.close()
        get_viewport().set_input_as_handled()

# —— 逐帧 ——

func _process(delta: float) -> void:
    if player != null:
        var p := player.position
        p.x = clampf(p.x, 40, WORLD_SIZE.x - 40)
        p.y = clampf(p.y, 80, WORLD_SIZE.y - 40)
        p = _resolve_obstacles(p, 20.0)
        player.position = p
        camera.global_position = camera.global_position.lerp(p, clampf(delta * 7.0, 0, 1))
        _clamp_camera()
        # 移动脚步声：每 0.36 秒一次
        _step_cd -= delta
        if player.is_moving() and _step_cd <= 0.0:
            _step_cd = 0.36
            GameState.play_sfx("step")
    _lamp_glow = 0.55 + sin(Time.get_ticks_msec() / 900.0) * 0.45
    queue_redraw()

func _clamp_camera() -> void:
    if camera == null:
        return
    var vp := get_viewport_rect().size / camera.zoom
    var half := vp * 0.5
    var pos := camera.position
    if WORLD_SIZE.x > vp.x:
        pos.x = clampf(pos.x, half.x, WORLD_SIZE.x - half.x)
    else:
        pos.x = WORLD_SIZE.x * 0.5
    if WORLD_SIZE.y > vp.y:
        pos.y = clampf(pos.y, half.y, WORLD_SIZE.y - half.y)
    else:
        pos.y = WORLD_SIZE.y * 0.5
    camera.position = pos

# —— 绘制 ——

func _draw() -> void:
    # 地面底色（分块草地，制造深浅）
    draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Palette.GRASS, true)
    draw_rect(Rect2(0, 0, WORLD_SIZE.x, 520), Palette.GRASS_DEEP, true)
    draw_rect(Rect2(0, WORLD_SIZE.y - 380, WORLD_SIZE.x, 380), Palette.GRASS_DEEP, true)
    # 小径
    var path_pts := PackedVector2Array([
        Vector2(0, 820), Vector2(500, 780), Vector2(1000, 830), Vector2(1500, 760),
        Vector2(2000, 820), Vector2(WORLD_SIZE.x, 780),
    ])
    for i in range(path_pts.size() - 1):
        draw_line(path_pts[i], path_pts[i + 1], Palette.PATH_DEEP, 74.0, true)
    for i in range(path_pts.size() - 1):
        draw_line(path_pts[i], path_pts[i + 1], Palette.PATH, 64.0, true)
    # 丁字路
    draw_line(Vector2(1180, 830), Vector2(1180, 1180), Palette.PATH_DEEP, 64.0, true)
    draw_line(Vector2(1180, 830), Vector2(1180, 1180), Palette.PATH, 54.0, true)

    # 草簇
    var t := Time.get_ticks_msec() / 1000.0
    for g in _grass_tufts:
        var p: Vector2 = g["pos"]
        var sway := sin(t * 1.3 + float(g["sway"])) * 1.4
        draw_line(p, p + Vector2(sway, -float(g["h"])), 
            Palette.GRASS_DARK.lerp(Palette.LEAF, float(g["tint"])), 2.0, true)

    # 装饰已拆成 WorldDeco 子节点由 y-sort 绘制
    # 世界边界
    draw_rect(Rect2(Vector2(4, 4), WORLD_SIZE - Vector2(8, 8)),
        Palette.LEAF_DEEP, false, 6.0)

# —— 交互 ——

func _on_interact() -> void:
    if _journal != null and _journal.is_open():
        _journal.close()
        return
    if _appearance != null and _appearance.is_open():
        _appearance.close()
        return
    if player == null:
        return
    var best: Actor = null
    var best_d := 96.0
    for n in npcs:
        var d: float = player.position.distance_to(n.position)
        if d < best_d:
            best_d = d
            best = n
    if best != null:
        _show_bubble(best.position, best.speak())
        return
    # 没有 NPC：靠近草地点时触发遭遇
    if randf() < 0.34:
        var pool: Array = PetDB.WILD_POOL
        var wid := String(pool[randi() % pool.size()])
        battle_requested.emit(wid, maxi(1, int(GameState.player["level"]) + randi_range(-1, 1)))

func _show_bubble(world_pos: Vector2, text: String) -> void:
    if _npc_bubble != null and is_instance_valid(_npc_bubble):
        _npc_bubble.queue_free()
    _npc_bubble = preload("res://scripts/ui/speech_bubble.gd").new()
    _npc_bubble.position = world_pos + Vector2(0, -104)
    _npc_bubble.setup(text)
    add_child(_npc_bubble)
    GameState.play_sfx("blip")

## 装饰排序：无 pos 的（栅栏）按两端点 y 的较大值参与排序。
func _deco_less(a: Dictionary, b: Dictionary) -> bool:
    return _deco_y(a) < _deco_y(b)

func _deco_y(d: Dictionary) -> float:
    if d.has("pos"):
        return float(d["pos"].y)
    if d.has("from"):
        return maxf(float(d["from"].y), float(d["to"].y))
    return 0.0

## 把位置推出所有阻挡椭圆（保留一点身位半径）。
func _resolve_obstacles(p: Vector2, body_r: float) -> Vector2:
    for o in _obstacles:
        var c: Vector2 = o["center"]
        var r: Vector2 = o["radii"] + Vector2(body_r, body_r * 0.6)
        var d := p - c
        if r.x <= 0.01 or r.y <= 0.01:
            continue
        # 归一化到单位圆判断是否在椭圆内
        var nx := d.x / r.x
        var ny := d.y / r.y
        var dist := sqrt(nx * nx + ny * ny)
        if dist >= 1.0:
            continue
        if dist <= 0.0001:
            # 恰好在中心：没有可用方向，向下（南岸）推出
            p = Vector2(c.x, c.y + r.y)
            continue
        # 推到椭圆边界
        var scale_out := 1.0 / dist
        p = c + Vector2(d.x * scale_out, d.y * scale_out)
    return p

## 供测试或其他系统查询阻挡是否生效。
func is_blocked(pos: Vector2) -> bool:
    for o in _obstacles:
        var c: Vector2 = o["center"]
        var r: Vector2 = o["radii"]
        var nx := (pos.x - c.x) / r.x
        var ny := (pos.y - c.y) / r.y
        if nx * nx + ny * ny < 1.0:
            return true
    return false
