extends CanvasLayer
## 外貌自定义面板（按 C 打开）。列出配色预设，预览当前小团子，点击即切换。

var _panel: Control
var _body: VBoxContainer
var _preview: AppearancePreview
var _grid: GridContainer

func _ready() -> void:
    layer = 21
    _panel = Control.new()
    _panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    _panel.visible = false
    add_child(_panel)

    var dim := ColorRect.new()
    dim.color = Color(0.10, 0.08, 0.06, 0.45)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    _panel.add_child(dim)

    var card := PanelContainer.new()
    card.set_anchors_preset(Control.PRESET_CENTER)
    card.custom_minimum_size = Vector2(720, 460)
    card.offset_left = -360
    card.offset_top = -230
    card.offset_right = 360
    card.offset_bottom = 230
    var st := StyleBoxFlat.new()
    st.bg_color = Palette.PANEL
    st.border_color = Palette.PANEL_EDGE
    st.set_border_width_all(4)
    st.set_corner_radius_all(20)
    st.content_margin_left = 24
    st.content_margin_right = 24
    st.content_margin_top = 18
    st.content_margin_bottom = 18
    card.add_theme_stylebox_override("panel", st)
    _panel.add_child(card)

    _body = VBoxContainer.new()
    _body.add_theme_constant_override("separation", 10)
    card.add_child(_body)

    var title := Label.new()
    title.text = "小团子外观"
    title.add_theme_font_size_override("font_size", 26)
    title.add_theme_color_override("font_color", Palette.INK)
    _body.add_child(title)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 18)
    _body.add_child(row)

    _preview = AppearancePreview.new()
    _preview.custom_minimum_size = Vector2(150, 170)
    row.add_child(_preview)

    _grid = GridContainer.new()
    _grid.columns = 2
    _grid.add_theme_constant_override("h_separation", 12)
    _grid.add_theme_constant_override("v_separation", 10)
    _grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(_grid)

    var hint := Label.new()
    hint.text = "点击预设即刻更换；按 C 或 Esc 关闭"
    hint.add_theme_font_size_override("font_size", 15)
    hint.add_theme_color_override("font_color", Palette.INK_SOFT)
    _body.add_child(hint)

func toggle() -> void:
    _panel.visible = not _panel.visible
    if _panel.visible:
        _rebuild()

func is_open() -> bool:
    return _panel.visible

func close() -> void:
    _panel.visible = false

func _rebuild() -> void:
    for c in _grid.get_children():
        c.queue_free()
    var cur := String(GameState.appearance.get("preset", "classic"))
    _preview.refresh()
    for pid in GameState.APPEARANCE_PRESETS.keys():
        var p: Dictionary = GameState.APPEARANCE_PRESETS[pid]
        var id := String(pid)
        var selected := id == cur
        var btn := Button.new()
        btn.text = ("▶ " if selected else "") + String(p["name"])
        btn.custom_minimum_size = Vector2(240, 52)
        btn.add_theme_font_size_override("font_size", 18)
        btn.add_theme_color_override("font_color", Palette.PINK_DEEP if selected else Palette.INK)
        btn.pressed.connect(_on_pick.bind(id))
        _grid.add_child(btn)

func _on_pick(id: String) -> void:
    if not GameState.set_appearance(id):
        return
    if player_ref != null and is_instance_valid(player_ref) and player_ref.has_method("apply_appearance"):
        player_ref.apply_appearance()
    _rebuild()

## 由 world.gd 在创建玩家后注入，用于切换后立即刷新世界里的角色。
var player_ref: Node = null

## 预览头像：用同一套绘制库画小团子。
class AppearancePreview extends Control:
    func refresh() -> void:
        queue_redraw()

    func _draw() -> void:
        var c := GameState.appearance_colors()
        var center := Vector2(size.x * 0.5, size.y * 0.58)
        TuanziArt.ground_shadow(self, Vector2(size.x * 0.5, size.y * 0.94), 34.0, 0.14)
        TuanziArt.draw_tuanzi(self, center, {
            "scale": 1.05, "facing": 1.0, "bob": 0.0, "leg": 0.0, "blink": 0.0,
            "mouth": 0.0, "hurt": 0.0,
            "phase": Time.get_ticks_msec() / 2600.0,
            "body": Color(String(c["body"])),
            "edge": Color(String(c["edge"])),
            "horn": Color(String(c["horn"])),
        })
