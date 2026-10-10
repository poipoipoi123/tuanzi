extends CanvasLayer
## 图鉴 / 队伍面板（Tab 打开）。展示已见团子兽、队伍与背包。

var _panel: Control
var _body: VBoxContainer

func _ready() -> void:
    layer = 20
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
    card.custom_minimum_size = Vector2(760, 520)
    card.offset_left = -380
    card.offset_top = -260
    card.offset_right = 380
    card.offset_bottom = 260
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
    _body.add_theme_constant_override("separation", 8)
    card.add_child(_body)

func toggle() -> void:
    _panel.visible = not _panel.visible
    if _panel.visible:
        _rebuild()

func is_open() -> bool:
    return _panel.visible

func close() -> void:
    _panel.visible = false

func _add_title(text: String, size: int = 24) -> void:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", Palette.INK)
    _body.add_child(l)

func _add_line(text: String, color: Color = Palette.INK_SOFT, size: int = 17) -> void:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    _body.add_child(l)

func _rebuild() -> void:
    for c in _body.get_children():
        c.queue_free()

    _add_title("团子兽图鉴", 26)
    var caught: int = GameState.caught.size()
    _add_line("已收服 %d / %d 种" % [caught, PetDB.PETS.size()])

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 14)
    _body.add_child(row)
    for pid in PetDB.PETS.keys():
        var pet: Dictionary = PetDB.get_pet(String(pid))
        var owned: bool = GameState.caught.has(String(pid))
        var col := VBoxContainer.new()
        col.custom_minimum_size = Vector2(210, 0)
        row.add_child(col)
        var preview := JournalPetIcon.new()
        preview.custom_minimum_size = Vector2(120, 130)
        preview.pet_id = String(pid)
        preview.dimmed = not owned
        col.add_child(preview)
        _add_line(String(pet["name"]), Palette.INK if owned else Palette.INK_SOFT, 19)
        _add_line(String(pet["desc"]), Palette.INK_SOFT, 14)
        _add_line("体力 %d  攻 %d  防 %d  速 %d" % [
            int(pet["hp"]), int(pet["atk"]), int(pet["def"]), int(pet["spd"])],
            Palette.INK_SOFT, 14)

    _add_title("队伍与背包", 22)
    var pid2 := GameState.active_pet()
    _add_line("出战：%s  Lv.%d  体力 %d/%d" % [
        PetDB.get_pet(pid2)["name"], int(GameState.pet_state.get(pid2, {}).get("level", 1)),
        GameState.pet_hp(), GameState.pet_max_hp()])
    var inv_text: Array = []
    for iid in GameState.inventory.keys():
        var it: Dictionary = ItemDB.get_item(String(iid))
        if not it.is_empty():
            inv_text.append("%s x%d" % [it["name"], int(GameState.inventory[iid])])
    _add_line("背包：" + ("、".join(inv_text) if not inv_text.is_empty() else "空空如也"))
    _add_line("按 Tab 或 Esc 关闭", Palette.INK_SOFT, 15)

## 图鉴里的小头像：用同一套绘制库画团子兽。
class JournalPetIcon extends Control:
    var pet_id := "grass"
    var dimmed := false

    func _draw() -> void:
        var pet: Dictionary = PetDB.get_pet(pet_id)
        var c := size * Vector2(0.5, 0.62)
        TuanziArt.ground_shadow(self, Vector2(size.x * 0.5, size.y * 0.94), 34.0, 0.14)
        var col := Color(String(pet["body"]))
        if dimmed:
            col = col.lerp(Color(0.55, 0.52, 0.50), 0.75)
        TuanziArt.draw_tuanzi(self, c, {
            "scale": 1.05, "facing": 1.0, "bob": 0.0, "leg": 0.0, "blink": 0.0,
            "mouth": 0.0, "hurt": 0.0,
            "phase": Time.get_ticks_msec() / 2600.0,
            "body": col,
            "edge": Color(String(pet["edge"])) if not dimmed else col.darkened(0.25),
            "horn": Color(String(pet["horn"])) if not dimmed else col.darkened(0.3),
        })
