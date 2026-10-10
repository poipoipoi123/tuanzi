extends Node2D
## 对话气泡：圆角面板 + 指示三角，自动淡出。

var _text: String = ""
var _life: float = 3.2
var _age: float = 0.0
var _font: Font

func setup(text: String) -> void:
    _text = text
    var f := Label.new()
    f.text = text
    f.add_theme_font_size_override("font_size", 17)
    f.add_theme_color_override("font_color", Palette.INK)
    # 用 Label 量宽，绘制时自绘背景
    _font = ThemeDB.fallback_font
    queue_redraw()

func _process(delta: float) -> void:
    _age += delta
    _life -= delta
    z_index = 10000
    queue_redraw()
    if _life <= 0.0:
        queue_free()

func _draw() -> void:
    var font := ThemeDB.fallback_font
    var fs := 17
    var max_w := 300.0
    var lines := _wrap(_text, font, fs, max_w)
    var line_h := 24.0
    var w := 0.0
    for l in lines:
        w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
    w = minf(max_w, w) + 34.0
    var h := lines.size() * line_h + 26.0
    var rect := Rect2(-w * 0.5, -h - 18.0, w, h)
    var alpha := clampf(_life, 0.0, 1.0)
    # 背板
    draw_rect(rect.grow(3.0), Color(Palette.PANEL_EDGE, alpha * 0.95), true)
    draw_rect(rect, Color(Palette.PANEL, alpha * 0.98), true)
    # 指示三角
    var tri := PackedVector2Array([
        Vector2(-9, rect.end.y - 2), Vector2(9, rect.end.y - 2), Vector2(0, rect.end.y + 14),
    ])
    draw_colored_polygon(tri, Color(Palette.PANEL, alpha * 0.98))
    draw_line(tri[0], tri[2], Color(Palette.PANEL_EDGE, alpha), 2.0, true)
    draw_line(tri[1], tri[2], Color(Palette.PANEL_EDGE, alpha), 2.0, true)
    # 文字
    for i in lines.size():
        var pos := Vector2(rect.position.x + 17.0, rect.position.y + 20.0 + i * line_h)
        draw_string(font, pos, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
            Color(Palette.INK, alpha))

func _wrap(text: String, font: Font, fs: int, max_w: float) -> Array:
    var out: Array = []
    var cur := ""
    for ch in text:
        var trial := cur + ch
        if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w and cur != "":
            out.append(cur)
            cur = ch
        else:
            cur = trial
    if cur != "":
        out.append(cur)
    return out
