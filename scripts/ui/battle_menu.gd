extends Control
## 战斗指令菜单：技能按钮（按当前伙伴技能表动态生成）+ 逃跑。

signal skill_chosen(skill_id: String)
signal item_menu_requested()
signal capture_requested()
signal flee_chosen()

var _hb: HBoxContainer
var cursor := 0
var _entries: Array = []       # [{ id, kind }]，kind: "skill" | "item" | "capture" | "flee"

const CURSOR_PREFIX := "▶ "

func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    panel.offset_left = 32
    panel.offset_top = -196
    panel.offset_bottom = -108
    panel.offset_right = 700
    var style := StyleBoxFlat.new()
    style.bg_color = Color(Palette.PANEL, 0.97)
    style.border_color = Palette.PANEL_EDGE
    style.set_border_width_all(3)
    style.set_corner_radius_all(16)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)
    _hb = HBoxContainer.new()
    _hb.add_theme_constant_override("separation", 10)
    panel.add_child(_hb)

## 依据出战伙伴的技能表重建按钮。
func refresh_for(battler: Battler) -> void:
    for c in _hb.get_children():
        _hb.remove_child(c)
        c.queue_free()
    _entries.clear()
    cursor = 0
    var ids: Array = battler.skill_ids()
    for sid in ids:
        var sk: Dictionary = SkillDB.get_skill(String(sid))
        _entries.append({ "id": String(sid), "kind": "skill" })
        _hb.add_child(_make_button(
            "%s\n威力 %d" % [sk["name"], int(sk.get("power", 0))],
            Palette.PINK_DEEP, func(): skill_chosen.emit(String(sid))))
    _entries.append({ "id": "", "kind": "item" })
    _hb.add_child(_make_button("道具", Palette.MINT.darkened(0.3), func(): item_menu_requested.emit()))
    _entries.append({ "id": "", "kind": "capture" })
    _hb.add_child(_make_button("收服", Palette.SKY.darkened(0.2), func(): capture_requested.emit()))
    _entries.append({ "id": "", "kind": "flee" })
    _hb.add_child(_make_button("逃跑", Palette.INK_SOFT, func(): flee_chosen.emit()))
    _apply_cursor()

## 键盘左右移动光标（环绕）。
func move_cursor(delta: int) -> void:
    if _entries.is_empty():
        return
    cursor = wrapi(cursor + delta, 0, _entries.size())
    _apply_cursor()

## 数字键 / 确认键按下：直接选定第 i 项。
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

func _make_button(text: String, edge: Color, cb: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(128, 62)
    b.mouse_filter = Control.MOUSE_FILTER_STOP
    b.add_theme_font_size_override("font_size", 15)
    b.add_theme_color_override("font_color", Palette.INK)
    var bs := StyleBoxFlat.new()
    bs.bg_color = Palette.CREAM
    bs.border_color = edge
    bs.set_border_width_all(2)
    bs.set_corner_radius_all(12)
    bs.content_margin_top = 6
    bs.content_margin_bottom = 6
    b.add_theme_stylebox_override("normal", bs)
    var bh := bs.duplicate() as StyleBoxFlat
    bh.bg_color = Palette.PINK.lightened(0.40)
    b.add_theme_stylebox_override("hover", bh)
    b.add_theme_stylebox_override("pressed", bh)
    b.set_meta("base_text", text)
    var idx := _hb.get_child_count()
    b.pressed.connect(func(): cursor = idx; cb.call())
    return b
