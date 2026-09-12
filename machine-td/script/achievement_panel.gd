extends Control
## 成就总览面板：以「图标并排」的徽章格展示全部成就（含未解锁）。
##
## 每格 = 成就图标 + 名称 + 进度；未解锁的图标会置灰压暗（走 achievement_icon.gdshader）。
## 鼠标移入某个格子时，底部详情区显示该成就的完整信息（图标 / 名称 / 描述 / 进度 / 状态）。
##
## 文案全部走 lang/language.csv：
##   界面标题 _Achievements、状态 _AchievementUnlocked / _AchievementLocked、悬停提示 _AchvHoverHint
##   每个成就的名称/描述存在 AchievementManager.ACHIEVEMENTS 的 name / description 字段里（存的是 key）

signal closed # 面板已关闭，宿主可以据此做后续处理

const ICON_SIZE := Vector2(150, 150) # 徽章格图标绘制区
const TILE_MIN_SIZE := Vector2(300, 300) # 单格最小尺寸：5 列铺满面板宽度
const FALLBACK_ICON := "res://sprite/achievement.png" # 没配图标时的兜底图

@onready var grid: GridContainer = $PanelContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var title_label: Label = $PanelContainer/VBoxContainer/Header/Label
@onready var close_button: Button = $PanelContainer/VBoxContainer/Header/btnClose
@onready var detail_icon: TextureRect = $PanelContainer/VBoxContainer/DetailBox/DetailHBox/IconCenter/detailIcon
@onready var detail_name: Label = $PanelContainer/VBoxContainer/DetailBox/DetailHBox/DetailVBox/DetailHeader/detailName
@onready var detail_status: Label = $PanelContainer/VBoxContainer/DetailBox/DetailHBox/DetailVBox/DetailHeader/detailStatus
@onready var detail_desc: Label = $PanelContainer/VBoxContainer/DetailBox/DetailHBox/DetailVBox/detailDesc
@onready var detail_progress: Label = $PanelContainer/VBoxContainer/DetailBox/DetailHBox/DetailVBox/detailProgress

# 图标置灰/原色两份共享材质（同一状态的所有格子共用，避免每格一个材质实例）
var _mat_unlocked: ShaderMaterial
var _mat_locked: ShaderMaterial


func _ready() -> void:
	visible = false
	_make_icon_materials()
	close_button.pressed.connect(close)
	if AchievementManager:
		AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)
	refresh()


# 打开面板（每次打开都刷新一遍，保证进度和语言都是最新的）
func open() -> void:
	refresh()
	visible = true


# 关闭面板
func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _on_btn_close_pressed() -> void:
	close()


func _on_achievement_unlocked(_achievement_id: String, _achievement: Dictionary) -> void:
	refresh()


func refresh() -> void:
	for child in grid.get_children():
		child.queue_free()

	var achievement_map: Dictionary = AchievementManager.get_all_achievements()
	var ids: Array = achievement_map.keys()
	ids.sort()

	var unlocked_count := 0
	for achievement_id in ids:
		if AchievementManager.is_unlocked(achievement_id):
			unlocked_count += 1
		var achievement: Dictionary = achievement_map.get(achievement_id, {})
		grid.add_child(_make_tile(achievement_id, achievement))

	# 标题带上总进度，例如「成就 3/9」；语言切换后重新拼接即可生效
	title_label.text = "%s  %d/%d" % [_t("_Achievements", "Achievements"), unlocked_count, ids.size()]

	# 重置详情区为提示文案
	_show_detail("")


# ---------- 徽章格 ----------

func _make_tile(achievement_id: String, achievement: Dictionary) -> PanelContainer:
	var unlocked: bool = AchievementManager.is_unlocked(achievement_id)

	var tile := PanelContainer.new()
	tile.custom_minimum_size = TILE_MIN_SIZE
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel", _make_tile_style(unlocked))
	tile.mouse_entered.connect(_on_tile_mouse_entered.bind(achievement_id))
	tile.mouse_exited.connect(_on_tile_mouse_exited)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(content)

	var icon_center := CenterContainer.new()
	icon_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon_center)

	var icon := TextureRect.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.texture = _load_icon(achievement)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.material = _mat_unlocked if unlocked else _mat_locked
	icon_center.add_child(icon)

	var name_label := Label.new()
	name_label.text = _achievement_name(achievement_id, achievement)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.modulate = Color(1, 1, 1) if unlocked else Color(0.72, 0.74, 0.78)
	content.add_child(name_label)

	var progress := Label.new()
	progress.text = _progress_text(achievement_id, achievement)
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.add_theme_font_size_override("font_size", 24)
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.modulate = Color(0.98, 0.85, 0.42) if unlocked else Color(0.62, 0.64, 0.68)
	content.add_child(progress)

	return tile


# 已解锁：偏亮的深蓝底 + 金边 + 轻微外发光；未解锁：更暗的底 + 灰边
func _make_tile_style(unlocked: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 14.0
	style.content_margin_top = 14.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 12.0
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	if unlocked:
		style.bg_color = Color(0.16, 0.19, 0.27, 0.95)
		style.border_color = Color(0.85, 0.74, 0.34, 0.9)
		style.shadow_color = Color(0.85, 0.74, 0.34, 0.18)
		style.shadow_size = 8
	else:
		style.bg_color = Color(0.10, 0.105, 0.12, 0.9)
		style.border_color = Color(0.26, 0.28, 0.32, 1)
	return style


# ---------- 悬停详情 ----------

func _on_tile_mouse_entered(achievement_id: String) -> void:
	_show_detail(achievement_id)


func _on_tile_mouse_exited() -> void:
	_show_detail("")


# 传入空字符串表示没有悬停目标，详情区回到提示文案
func _show_detail(achievement_id: String) -> void:
	if achievement_id.is_empty():
		detail_icon.texture = load(FALLBACK_ICON) as Texture2D
		detail_icon.material = _mat_locked
		detail_name.text = _t("_AchvHoverHint", "Hover an achievement to see its details")
		detail_name.modulate = Color(0.72, 0.76, 0.82)
		detail_status.text = ""
		detail_desc.text = ""
		detail_progress.text = ""
		return

	var achievement: Dictionary = AchievementManager.get_achievement(achievement_id)
	var unlocked: bool = AchievementManager.is_unlocked(achievement_id)

	detail_icon.texture = _load_icon(achievement)
	detail_icon.material = _mat_unlocked if unlocked else _mat_locked

	detail_name.text = _achievement_name(achievement_id, achievement)
	detail_name.modulate = Color(1, 1, 1) if unlocked else Color(0.78, 0.80, 0.84)

	detail_status.text = _t("_AchievementUnlocked", "Unlocked") if unlocked else _t("_AchievementLocked", "Locked")
	detail_status.modulate = Color(0.75, 0.96, 0.6) if unlocked else Color(0.70, 0.72, 0.76)

	detail_desc.text = _achievement_desc(achievement_id, achievement)
	detail_desc.modulate = Color(0.85, 0.87, 0.92)

	detail_progress.text = _progress_text(achievement_id, achievement)
	detail_progress.modulate = Color(0.98, 0.85, 0.42) if unlocked else Color(0.72, 0.75, 0.80)


# ---------- 工具 ----------

func _make_icon_materials() -> void:
	var shader: Shader = load("res://shader/achievement_icon.gdshader")
	if shader == null:
		return
	_mat_unlocked = ShaderMaterial.new()
	_mat_unlocked.shader = shader
	_mat_unlocked.set_shader_parameter("desaturate", 0.0)
	_mat_unlocked.set_shader_parameter("dim", 1.0)

	_mat_locked = ShaderMaterial.new()
	_mat_locked.shader = shader
	_mat_locked.set_shader_parameter("desaturate", 1.0)
	_mat_locked.set_shader_parameter("dim", 0.55)


func _progress_text(achievement_id: String, achievement: Dictionary) -> String:
	var current_value: int = AchievementManager.get_progress(achievement_id)
	var target_value: int = int(achievement.get("target", 0))
	return "%d/%d" % [current_value, target_value]


# 成就名称/描述在 ACHIEVEMENTS 里存的是多语言 key，这里按当前语言解析
func _achievement_name(achievement_id: String, achievement: Dictionary) -> String:
	return _t(str(achievement.get("name", "")), achievement_id)


func _achievement_desc(achievement_id: String, achievement: Dictionary) -> String:
	return _t(str(achievement.get("description", "")), achievement_id)


# 取成就图标；路径缺失或加载失败时回退到默认成就图
func _load_icon(achievement: Dictionary) -> Texture2D:
	var path := str(achievement.get("icon", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var tex := load(path)
		if tex is Texture2D:
			return tex
	return load(FALLBACK_ICON) as Texture2D


# 取翻译；未找到对应 key（语言文件未导入）时回退到默认文本
func _t(key: String, fallback: String) -> String:
	if key.is_empty():
		return fallback
	var translated := tr(key)
	return fallback if translated == key else translated
