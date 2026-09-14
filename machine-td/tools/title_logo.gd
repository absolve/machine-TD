extends Control
## 生成 "SIMPLE TOWER DEFENSE" 标题图（工厂 / 工业风）
##
## 输出两份：
##   welcome_title.png  1600x450，**透明底、无钢板、无边框**，用于欢迎页顶部
##   card_plain.png     1920x1080，保留钢板但去掉描边，透明画布（备选）
##
## 字体优先用系统已安装的 Black Ops One（SIL OFL，商用免费），
## 找不到就退回工程自带的阿里普惠体 —— 所以工程里不需要放艺术字字体文件。

const OUT := "user://logo"

# ---- 欢迎页标题画布 ----
const CANVAS := Vector2i(1600, 450)
# 在 1920x1080 视口里居中绘制，再按这个矩形裁出来
const CROP := Rect2i(160, 315, 1600, 450)

# ---- 危险条纹带（独立资源，供滚动着色器用）----
# 条纹周期 = 2 * STRIPE_W，所以宽度取它的整数倍就横向无缝
const STRIPE_W := 34.0
const STRIP_W := 272          # = 8 * STRIPE_W
const STRIP_H := 22

# ---- 备选：整张卡片 ----
const CARD := Rect2(150, 130, 1620, 820)

# ---- 调色板（与 art_style.md 一致）----
const PLATE_TOP := "#3f4a6b"
const PLATE_BOT := "#2a3145"
const PLATE_MID := "#35405e"
const PLATE_EDGE := "#94b0c2"
const HAZ_Y := "#ffc61a"
const HAZ_K := "#1a1c2c"
const OUTLINE := "#1a1c2c"
const SHADOW := "#0d1016"
const BG := "#20263a"

# ---- 排版 ----
# 两行共用同一个字号（由 driver 行定），"SIMPLE" 因为字数少而自然更短
const TRACK_RATIO := 0.12
const LINE_GAP := 26.0
const LINES := [
	{"text": "SIMPLE", "color": "#ffc61a", "bars": 1},
	{"text": "TOWER DEFENSE", "target_w": 1300.0, "max_size": 140,
		"color": "#f8fbfd", "bars": 2, "driver": true},
]

# [工程内路径, 系统字体名] —— 先试工程内，再查系统已安装字体
const FONT_CANDIDATES := [
	["", "Black Ops One"],
	["res://font/AlibabaPuHuiTi-3-85-Bold.ttf", ""],
]

var cur_font: FontFile
var text_img: ImageTexture
var line_boxes: Array = []
var draw_plate := false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)

	cur_font = _load_font()
	if cur_font == null:
		push_error("找不到任何可用字体")
		get_tree().quit(1)
		return

	# ---- 1. 欢迎页标题（不含危险条纹）----
	# 条纹已抽成独立的滚动条带 scene/ui/hazard_strip.tscn，所以标题里不再烤进去
	line_boxes.clear()
	draw_plate = false
	var img := await _render_text(Rect2(CROP))
	_punch_stencil(img, CROP)
	img.save_png(OUT + "/welcome_title.png")
	print("  -> welcome_title.png  %dx%d" % [img.get_width(), img.get_height()])

	# ---- 2. 危险条纹带：横向无缝，供滚动着色器用 ----
	_make_hazard_strip()

	# ---- 3. 备选：保留钢板但去掉描边 ----
	line_boxes.clear()
	draw_plate = true
	var img2 := await _render_text(Rect2i(0, 0, 1920, 1080))
	_punch_stencil(img2, Rect2i(0, 0, 1920, 1080))
	text_img = ImageTexture.create_from_image(img2)
	queue_redraw()
	await _settle(6)
	var shot := get_viewport().get_texture().get_image()
	shot.save_png(OUT + "/card_plain.png")
	img2.save_png(OUT + "/text_card_plain.png")
	print("  -> card_plain.png  %dx%d" % [shot.get_width(), shot.get_height()])

	print("---- 标题图生成完成 ----")
	get_tree().quit(0)


func _load_font() -> FontFile:
	for c in FONT_CANDIDATES:
		var res_path: String = c[0]
		var sys_name: String = c[1]
		if res_path != "" and ResourceLoader.exists(res_path):
			var r: Resource = load(res_path)
			if r is FontFile:
				print("  字体：%s（工程内）" % res_path)
				return r
		if sys_name != "":
			var p := OS.get_system_font_path(sys_name, 400, 100, false)
			if p != "" and FileAccess.file_exists(p):
				var f := FontFile.new()
				if f.load_dynamic_font(p) == OK:
					print("  字体：%s（系统安装 %s）" % [sys_name, p])
					return f
		print("  跳过（找不到）：%s%s" % [res_path, sys_name])
	return null


# ---------- 文字层 ----------

func _render_text(crop: Rect2i) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	add_child(vp)

	for entry in _layout(Rect2(crop)):
		_add_line(vp, entry, Rect2(crop))

	await _settle(8)
	var full := vp.get_texture().get_image()
	vp.queue_free()
	await _settle(2)
	return full.get_region(crop)


# 由 driver 行定字号，再把整块垂直居中到给定区域
func _layout(area: Rect2) -> Array:
	var size := 0
	for spec in LINES:
		if spec.get("driver", false):
			size = _fit_size(spec["text"], spec["target_w"], spec["max_size"])
	if size <= 0:
		size = _fit_size(LINES[0]["text"], 1200.0, 140)

	var out: Array = []
	var total := 0.0
	for spec in LINES:
		var h := cur_font.get_ascent(size) + cur_font.get_descent(size)
		out.append({"spec": spec, "size": size, "h": h})
		total += h
	total += LINE_GAP * float(maxi(out.size() - 1, 0))
	var y := area.position.y + area.size.y * 0.5 - total * 0.5
	for l in out:
		l["top"] = y
		y += float(l["h"]) + LINE_GAP
	return out


func _fit_size(text: String, target_w: float, max_size: int) -> int:
	var a := cur_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x / 100.0
	var denom := a + TRACK_RATIO * float(maxi(text.length() - 1, 0))
	if denom <= 0.0001:
		return max_size
	return maxi(24, mini(max_size, int(target_w / denom)))


func _add_line(vp: SubViewport, entry: Dictionary, area: Rect2) -> void:
	var spec: Dictionary = entry["spec"]
	var text: String = spec["text"]
	var size: int = entry["size"]
	var top: float = entry["top"]
	var tracking := float(size) * TRACK_RATIO
	var col := Color(spec["color"])
	var outline := maxi(4, int(float(size) * 0.085))
	var shadow_y := maxi(4, int(float(size) * 0.065))

	var widths: Array = []
	var total := 0.0
	for i in range(text.length()):
		var w := cur_font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		widths.append(w)
		total += w
	total += tracking * float(maxi(text.length() - 1, 0))

	var x := area.position.x + (area.size.x - total) * 0.5
	for i in range(text.length()):
		var l := Label.new()
		l.text = text[i]
		l.add_theme_font_override("font", cur_font)
		l.add_theme_font_size_override("font_size", size)
		l.add_theme_color_override("font_color", col)
		l.add_theme_color_override("font_outline_color", Color(OUTLINE))
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_shadow_color", Color(SHADOW, 0.85))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", shadow_y)
		l.add_theme_constant_override("shadow_outline_size", 0)
		l.position = Vector2(x, top)
		vp.add_child(l)
		x += widths[i] + tracking

	line_boxes.append(Rect2(area.position.x + (area.size.x - total) * 0.5, top, total, float(entry["h"])))
	print("     %-14s size=%3d  宽=%.0f" % [text, size, total])


# 钢印镂空：横切 1~2 道"桥"，把 alpha 清零
func _punch_stencil(img: Image, crop: Rect2i) -> void:
	for li in range(LINES.size()):
		if li >= line_boxes.size():
			continue
		var n: int = LINES[li]["bars"]
		var box: Rect2 = line_boxes[li]
		# 视口坐标 -> 裁剪后坐标
		box.position -= Vector2(crop.position)
		var cap := box.size.y
		var bar_h := maxi(4, int(cap * 0.075))
		for b in range(n):
			var t := (float(b) + 1.0) / (float(n) + 1.0)
			var y0 := int(box.position.y + cap * t - bar_h * 0.5)
			for y in range(maxi(0, y0), mini(img.get_height(), y0 + bar_h)):
				for x in range(maxi(0, int(box.position.x)), mini(img.get_width(), int(box.end.x))):
					var c := img.get_pixel(x, y)
					if c.a > 0.0:
						c.a = 0.0
						img.set_pixel(x, y, c)


# ---------- 卡片层 ----------

func _draw() -> void:
	if not draw_plate:
		return
	_draw_card()
	if text_img != null:
		draw_texture(text_img, Vector2.ZERO)


# 备选：保留钢板，但去掉那圈亮描边
func _draw_card() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(BG, 0))
	var card := StyleBoxFlat.new()
	card.bg_color = Color(PLATE_MID)
	card.set_corner_radius_all(18)
	card.shadow_color = Color(SHADOW, 0.55)
	card.shadow_size = 24
	card.shadow_offset = Vector2(0, 10)
	draw_style_box(card, CARD)
	_hazard(Rect2(CARD.position.x + 44, CARD.position.y + 40, CARD.size.x - 88, 26))
	_hazard(Rect2(CARD.position.x + 44, CARD.end.y - 66, CARD.size.x - 88, 26))


# 危险条纹带：横向无缝的小贴图，由 TextureRect 平铺 + hazard_scroll.gdshader 滚动
func _make_hazard_strip() -> void:
	var img := Image.create(STRIP_W, STRIP_H, false, Image.FORMAT_RGBA8)
	_hazard_image(img, Rect2i(0, 0, STRIP_W, STRIP_H), STRIPE_W)
	img.save_png(OUT + "/hazard_strip.png")
	print("  -> hazard_strip.png  %dx%d（横向无缝，周期 %dpx）" % [
		STRIP_W, STRIP_H, int(STRIPE_W * 2.0)])


# 直接往 Image 上刷 45° 黄黑危险条纹
func _hazard_image(img: Image, r: Rect2i, sw: float) -> void:
	for x in range(r.position.x, mini(r.end.x, img.get_width())):
		var phase := int(floor((x + r.position.y) / sw))
		var y := r.position.y
		while y < mini(r.end.y, img.get_height()):
			var ny := mini(r.end.y, int(float(phase + 1) * sw - x))
			var col := Color(HAZ_Y) if phase % 2 == 0 else Color(HAZ_K)
			for yy in range(y, ny):
				img.set_pixel(x, yy, col)
			y = ny
			phase += 1


# 45° 黄黑危险条纹（视口绘制版，用于备选卡片）
func _hazard(r: Rect2) -> void:
	var sw := 34.0
	var x := r.position.x
	while x < r.end.x:
		var phase := int(floor((x + r.position.y) / sw))
		var yy := r.position.y
		while yy < r.end.y:
			var ny: float = minf(r.end.y, float(phase + 1) * sw - x)
			draw_rect(Rect2(x, yy, 2.0, ny - yy),
				Color(HAZ_Y) if phase % 2 == 0 else Color(HAZ_K))
			yy = ny
			phase += 1
		x += 2.0


func _settle(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
