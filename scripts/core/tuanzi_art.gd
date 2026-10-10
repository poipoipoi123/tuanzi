class_name TuanziArt
extends RefCounted
## 团子角色绘制库。优先使用开源像素贴图；贴图缺失时回退到程序化绘制。
## 复用者：玩家、NPC、战斗单位、图鉴。

## 团子兽 id -> 贴图路径。素材缺失时 load_tex 返回 null，绘制自动回退程序化。
const SPRITE_FOR := {
    "grass": "res://assets/sprites/tuanzi_grass.png",
    "water": "res://assets/sprites/tuanzi_water.png",
    "spark": "res://assets/sprites/tuanzi_spark.png",
}

static func sprite_path_for(pet_id: String) -> String:
    return String(SPRITE_FOR.get(pet_id, "res://assets/sprites/tuanzi_missing.png"))

static func has_sprite(pet_id: String) -> bool:
    return SpriteLib.load_tex(sprite_path_for(pet_id)) != null

static func sprite_for(pet_id: String) -> Texture2D:
    return SpriteLib.load_tex(sprite_path_for(pet_id))

# —— 基础图元 ——

## 以「变换缩放画圆」实现任意椭圆，保持描边圆滑。
static func ellipse(canvas: CanvasItem, center: Vector2, radii: Vector2, color: Color) -> void:
    var r: float = maxf(radii.x, radii.y)
    if r <= 0.01:
        return
    canvas.draw_set_transform(center, 0.0, Vector2(radii.x / r, radii.y / r))
    canvas.draw_circle(Vector2.ZERO, r, color)
    canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 带描边的椭圆。
static func ellipse_outlined(canvas: CanvasItem, center: Vector2, radii: Vector2,
        fill: Color, edge: Color, width: float = 2.0) -> void:
    ellipse(canvas, center, radii + Vector2(width, width), edge)
    ellipse(canvas, center, radii, fill)

## 椭圆上缘高光，制造柔软球体的立体感。
static func ellipse_shine(canvas: CanvasItem, center: Vector2, radii: Vector2,
        alpha: float = 0.5) -> void:
    ellipse(canvas, center + Vector2(-radii.x * 0.28, -radii.y * 0.34),
        radii * Vector2(0.34, 0.24), Color(1, 1, 1, alpha))

## 地面软阴影。
static func ground_shadow(canvas: CanvasItem, center: Vector2, rx: float,
        alpha: float = 0.18) -> void:
    ellipse(canvas, center, Vector2(rx, rx * 0.34), Color(0.2, 0.26, 0.18, alpha))

## 叶片（头顶嫩芽）：两段贝塞尔感的多边形。
static func leaf(canvas: CanvasItem, base: Vector2, height: float, lean: float,
        color: Color, edge: Color) -> void:
    var tip := base + Vector2(lean * height * 0.5, -height)
    var mid := base.lerp(tip, 0.5)
    var side := Vector2(height * 0.30, 0.0)
    var pts := PackedVector2Array([
        base,
        base + Vector2(-side.x * 0.6, -height * 0.28),
        mid + Vector2(-side.x, -height * 0.10),
        tip,
        mid + Vector2(side.x, -height * 0.10),
        base + Vector2(side.x * 0.6, -height * 0.28),
    ])
    canvas.draw_colored_polygon(pts, edge)
    var inner := PackedVector2Array()
    for p in pts:
        inner.append(mid + (p - mid) * 0.72)
    canvas.draw_colored_polygon(inner, color)
    canvas.draw_line(base, tip, color.lightened(0.25), 1.4, true)

## 小爪子 / 脚掌。
static func paw(canvas: CanvasItem, center: Vector2, r: float, fill: Color,
        edge: Color) -> void:
    ellipse_outlined(canvas, center, Vector2(r, r * 0.82), fill, edge, 1.6)

# —— 主体 ——

## 绘制一只团子。
## state 支持字段：
##   scale(float) 整体缩放 | facing(1/-1) 朝向 | bob(float) 上下浮动
##   leg(float) 步伐相位 | blink(float 0..1) 眨眼 | mouth(float 0..1) 张嘴
##   hurt(float) 受击闪白 | body/edge/horn(Color) 配色 | phase(float) 待机呼吸相位
static func draw_tuanzi(canvas: CanvasItem, origin: Vector2, state: Dictionary) -> void:
    var s: float = state.get("scale", 1.0)
    var facing: float = state.get("facing", 1.0)
    var bob: float = state.get("bob", 0.0)
    var leg: float = state.get("leg", 0.0)
    var blink: float = state.get("blink", 0.0)
    var mouth: float = state.get("mouth", 0.0)
    var hurt: float = state.get("hurt", 0.0)
    var phase: float = state.get("phase", 0.0)
    var body: Color = state.get("body", Palette.TUANZI)
    var edge: Color = state.get("edge", Palette.TUANZI_EDGE)
    var horn: Color = state.get("horn", Palette.LEAF)

    # —— 贴图优先，缺图时优雅回退到下方程序化绘制 ——
    var pet_id := String(state.get("pet_id", ""))
    var tex := sprite_for(pet_id)
    if tex != null:
        var px := 56.0 * s
        canvas.draw_texture_rect(tex, Rect2(-px / 2.0, origin.y - px, px, px), false)
        return
    else:
        # —— 以下为原有程序化绘制，原样保留 ——
        # 呼吸：整体轻微纵向缩放
        var breathe := 1.0 + sin(phase * TAU) * 0.022
        var squash := Vector2(1.0 / breathe, breathe)

        var body_r := Vector2(26.0, 23.0) * s
        var body_c := origin + Vector2(0, -30.0 * s + bob)

        # 1) 落地阴影（跟随浮动收缩）
        ground_shadow(canvas, origin + Vector2(0, 2.0 * s),
            body_r.x * (1.0 - absf(bob) / (40.0 * s) * 2.2), 0.16)

        # 2) 双脚
        var foot_y := origin.y - 3.0 * s
        var swing := sin(leg) * 7.0 * s
        paw(canvas, Vector2(origin.x - 11.0 * s + swing, foot_y), 9.0 * s, body, edge)
        paw(canvas, Vector2(origin.x + 11.0 * s - swing, foot_y), 9.0 * s, body, edge)

        # 3) 身体（上色 + 描边 + 高光）
        var r_scaled := Vector2(body_r.x * squash.x, body_r.y * squash.y)
        ellipse_outlined(canvas, body_c, r_scaled, body, edge, 2.4 * s)
        ellipse(canvas, body_c + Vector2(0, -r_scaled.y * 0.30),
            Vector2(r_scaled.x * 0.98, r_scaled.y * 0.62),
            body.lightened(0.06))
        ellipse_shine(canvas, body_c, r_scaled, 0.55)

        # 4) 脸
        var face_c := body_c + Vector2(0, -r_scaled.y * 0.06)
        _draw_face(canvas, face_c, s, facing, blink, mouth, hurt)

        # 5) 头顶嫩芽
        leaf(canvas, body_c + Vector2(-1.0 * s, -r_scaled.y * 0.92),
            20.0 * s, facing * 0.5 + sin(phase * TAU) * 0.18, horn, horn.darkened(0.30))

        # 6) 小手（朝向侧前方）
        var arm_x := body_c.x + facing * r_scaled.x * 0.92
        paw(canvas, Vector2(arm_x, body_c.y + 3.0 * s), 6.2 * s, body, edge)


static func _draw_face(canvas: CanvasItem, face_c: Vector2, s: float, facing: float,
        blink: float, mouth: float, hurt: float) -> void:
    var eye_dx := 9.5 * s
    var eye_y := face_c.y - 2.0 * s
    var eye_r := Vector2(4.2 * s, 5.0 * s)
    # 眨眼：纵向压扁
    eye_r.y *= (1.0 - clampf(blink, 0.0, 1.0) * 0.92)

    var iris := Palette.INK
    if hurt > 0.01:
        iris = Palette.INK.lerp(Color.WHITE, hurt * 0.85)

    for side in [-1.0, 1.0]:
        var ec := Vector2(face_c.x + side * eye_dx, eye_y)
        if eye_r.y < 0.8 * s:
            canvas.draw_line(ec + Vector2(-4.0 * s, 0), ec + Vector2(4.0 * s, 0),
                iris, 2.0 * s, true)
        else:
            ellipse(canvas, ec, eye_r, iris)
            # 眼神高光：朝当前朝向偏一点
            ellipse(canvas, ec + Vector2(facing * 1.3 * s, -1.6 * s),
                eye_r * 0.34, Color(1, 1, 1, 0.95))

    # 腮红
    for side in [-1.0, 1.0]:
        ellipse(canvas, Vector2(face_c.x + side * 16.5 * s, face_c.y + 4.5 * s),
            Vector2(5.4 * s, 3.4 * s), Color(Palette.BLUSH, 0.75))

    # 嘴：受击时张开成圆
    var m: float = clampf(mouth, 0.0, 1.0)
    if hurt > 0.05:
        ellipse(canvas, Vector2(face_c.x, face_c.y + 9.0 * s),
            Vector2(4.6 * s, 5.2 * s), Palette.MOUTH.darkened(0.15))
    elif m > 0.15:
        ellipse(canvas, Vector2(face_c.x, face_c.y + 9.0 * s),
            Vector2(3.4 * s * m, 3.8 * s * m), Palette.MOUTH)
    else:
        # 微笑弧
        var mx := face_c.x
        var my := face_c.y + 8.0 * s
        canvas.draw_arc(Vector2(mx, my), 4.0 * s, deg_to_rad(20), deg_to_rad(160),
            14, Palette.MOUTH, 1.8 * s, true)

## 宠物（团子兽）小体型版本，用于战斗与跟随。
static func draw_pet(canvas: CanvasItem, origin: Vector2, state: Dictionary) -> void:
    var st := state.duplicate()
    st["scale"] = float(state.get("scale", 0.78))
    draw_tuanzi(canvas, origin, st)