extends CanvasLayer
## 顶部状态栏（含出战伙伴血量）+ 底部操作提示 + 提示气泡。

var _pet_label: Label
var _hp_label: Label
var _info_label: Label
var _hint: Label
var _toast: Label
var _toast_life := 0.0

func _ready() -> void:
    var root := Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
    panel.offset_left = 12
    panel.offset_right = -12
    panel.offset_top = 12
    var st := StyleBoxFlat.new()
    st.bg_color = Color(Palette.PANEL, 0.94)
    st.border_color = Palette.PANEL_EDGE
    st.set_border_width_all(3)
    st.set_corner_radius_all(14)
    st.content_margin_left = 16
    st.content_margin_right = 16
    st.content_margin_top = 8
    st.content_margin_bottom = 8
    panel.add_theme_stylebox_override("panel", st)
    root.add_child(panel)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 24)
    panel.add_child(row)

    _hp_label = _mk_label(Palette.HP_RED, 19)
    row.add_child(_hp_label)

    _pet_label = _mk_label(Palette.MINT.darkened(0.25), 19)
    row.add_child(_pet_label)

    _info_label = _mk_label(Palette.INK_SOFT, 19)
    row.add_child(_info_label)

    _hint = Label.new()
    _hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    _hint.offset_top = -46
    _hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _hint.add_theme_font_size_override("font_size", 16)
    _hint.add_theme_color_override("font_color", Palette.INK_SOFT)
    _hint.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
    _hint.add_theme_constant_override("outline_size", 4)
    _hint.text = "WASD / 方向键 移动    E / 空格 交互    F5 存档    Tab 图鉴"
    root.add_child(_hint)

    _toast = Label.new()
    _toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _toast.offset_top = 84
    _toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _toast.add_theme_font_size_override("font_size", 18)
    _toast.add_theme_color_override("font_color", Palette.INK)
    _toast.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.95))
    _toast.add_theme_constant_override("outline_size", 5)
    root.add_child(_toast)

    GameState.state_changed.connect(_refresh)
    _refresh()

func _mk_label(color: Color, size: int) -> Label:
    var l := Label.new()
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    return l

func toast(msg: String) -> void:
    _toast.text = msg
    _toast_life = 2.2

func _process(delta: float) -> void:
    if _toast_life > 0.0:
        _toast_life -= delta
        _toast.modulate.a = clampf(_toast_life / 0.6, 0.0, 1.0)
    elif _toast.text != "":
        _toast.text = ""

func _refresh() -> void:
    var p: Dictionary = GameState.player
    _hp_label.text = "小团子 HP %d/%d" % [int(p["hp"]), int(p["max_hp"])]
    _pet_label.text = "%s HP %d/%d" % [
        PetDB.get_pet(GameState.active_pet())["name"], GameState.pet_hp(), GameState.pet_max_hp()]
    _info_label.text = "Lv.%d  经验 %d/%d   团子币 %d   星尘 %d" % [
        int(p["level"]), int(p["exp"]), GameState.exp_to_next(int(p["level"])),
        int(p["coins"]), int(p["star_dust"])]
