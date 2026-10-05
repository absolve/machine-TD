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

const ICON_SIZE := Vector2(146, 146) # 徽章格图标绘制区
const BADGE_SIZE := Vector2(184, 184)
const TILE_MIN_SIZE := Vector2(300, 300) # 单格最小尺寸：5 列铺满面板宽度
const FALLBACK_ICON := "res://sprite/achievement_3d.png" # 没配图标时的兜底图

@onready var grid: GridContainer = $PanelContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var titleLabel: Label = $PanelContainer/VBoxContainer/Header/Label
@onready var closeButton: Button = $PanelContainer/VBoxContainer/Footer/btnClose
@onready var detailIcon: TextureRect = $PanelContainer/VBoxContainer/DetailBox/DetailHBox/IconCenter/detailIcon
@onready var detailName: Label = $PanelContainer/VBoxContainer/DetailBox/DetailHBox/DetailVBox/DetailHeader/detailName
@onready var detailStatus: Label = $PanelContainer/VBoxContainer/DetailBox/DetailHBox/DetailVBox/DetailHeader/detailStatus
@onready var detailDesc: Label = $PanelContainer/VBoxContainer/DetailBox/DetailHBox/DetailVBox/detailDesc
@onready var detailProgress: Label = $PanelContainer/VBoxContainer/DetailBox/DetailHBox/DetailVBox/detailProgress

# 图标置灰/原色两份共享材质（同一状态的所有格子共用，避免每格一个材质实例）
var _matUnlocked: ShaderMaterial
var _matLocked: ShaderMaterial


func _ready() -> void:
	visible = false
	_makeIconMaterials()
	#close_button.pressed.connect(close)
	if AchievementManager:
		AchievementManager.achievementUnlocked.connect(_onAchievementUnlocked)
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


func _onBtnClosePressed() -> void:
	close()


func _onAchievementUnlocked(_achievement_id: String, _achievement: Dictionary) -> void:
	refresh()


func refresh() -> void:
	for child in grid.get_children():
		child.queue_free()

	var achievementMap: Dictionary = AchievementManager.getAllAchievements()
	var ids: Array = achievementMap.keys()
	ids.sort()

	var unlockedCount: int = 0
	for achievement_id in ids:
		if AchievementManager.isUnlocked(achievement_id):
			unlockedCount += 1
		var achievement: Dictionary = achievementMap.get(achievement_id, {})
		grid.add_child(_makeTile(achievement_id, achievement))

	# 标题带上总进度，例如「成就 3/9」；语言切换后重新拼接即可生效
	titleLabel.text = "%s  %d/%d" % [Game.t("_Achievements", "Achievements"), unlockedCount, ids.size()]

	# 重置详情区为提示文案
	_showDetail("")


# ---------- 徽章格 ----------

func _makeTile(achievement_id: String, achievement: Dictionary) -> PanelContainer:
	var unlocked: bool = AchievementManager.isUnlocked(achievement_id)

	var tile: PanelContainer = PanelContainer.new()
	tile.custom_minimum_size = TILE_MIN_SIZE
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel", _makeTileStyle(unlocked))
	tile.mouse_entered.connect(_onTileMouseEntered.bind(achievement_id))
	tile.mouse_exited.connect(_onTileMouseExited)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(content)

	var iconCenter: CenterContainer = CenterContainer.new()
	iconCenter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	iconCenter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(iconCenter)

	var badge: PanelContainer = PanelContainer.new()
	badge.custom_minimum_size = BADGE_SIZE
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override("panel", makeBadgeStyle(achievement, unlocked))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	iconCenter.add_child(badge)

	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.texture = _loadIcon(achievement)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.material = _matUnlocked if unlocked else _matLocked
	badge.add_child(icon)

	var nameLabel: Label = Label.new()
	nameLabel.text = _achievementName(achievement_id, achievement)
	nameLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nameLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nameLabel.add_theme_font_size_override("font_size", 28)
	nameLabel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nameLabel.modulate = Color(0.97254902, 0.98431373, 0.99215686) if unlocked else Color(0.62352943, 0.7058824, 0.76862746)
	content.add_child(nameLabel)

	var progress: Label = Label.new()
	progress.text = _progressText(achievement_id, achievement)
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.add_theme_font_size_override("font_size", 24)
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.modulate = Color(1, 0.7764706, 0.101960786) if unlocked else Color(0.62352943, 0.7058824, 0.76862746)
	content.add_child(progress)

	return tile


# 已解锁：偏亮的深蓝底 + 金边 + 轻微外发光；未解锁：更暗的底 + 灰边
func _makeTileStyle(unlocked: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
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
		style.bg_color = Color(0.3372549, 0.42352942, 0.5254902, 0.98)
		style.border_color = Color(1, 0.7764706, 0.101960786, 0.95)
		style.shadow_color = Color(1, 0.7764706, 0.101960786, 0.28)
		style.shadow_size = 8
	else:
		style.bg_color = Color(0.26666668, 0.34509805, 0.43137255, 0.92)
		style.border_color = Color(0.5803922, 0.6901961, 0.7607843, 1)
	return style


func makeBadgeStyle(achievement: Dictionary, unlocked: bool) -> StyleBoxFlat:
	var accent: Color = categoryAccent(str(achievement.get("category", "")))
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.12, 0.17, 1.0)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 82
	style.corner_radius_top_right = 82
	style.corner_radius_bottom_left = 82
	style.corner_radius_bottom_right = 82
	style.content_margin_left = 8.0
	style.content_margin_top = 8.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 8.0
	style.border_color = accent if unlocked else Color(0.32, 0.4, 0.46, 1.0)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.28 if unlocked else 0.08)
	style.shadow_size = 12 if unlocked else 5
	style.shadow_offset = Vector2(0, 3)
	return style


func categoryAccent(category: String) -> Color:
	match category:
		"stage":
			return Color(0.32, 0.8, 0.84, 1.0)
		"combat":
			return Color(0.94, 0.42, 0.31, 1.0)
		"build":
			return Color(1.0, 0.72, 0.2, 1.0)
		"growth":
			return Color(0.53, 0.82, 0.48, 1.0)
		_:
			return Color(0.78, 0.82, 0.85, 1.0)


# ---------- 悬停详情 ----------

func _onTileMouseEntered(achievement_id: String) -> void:
	_showDetail(achievement_id)


func _onTileMouseExited() -> void:
	_showDetail("")


# 传入空字符串表示没有悬停目标，详情区回到提示文案
func _showDetail(achievement_id: String) -> void:
	if achievement_id.is_empty():
		detailIcon.texture = load(FALLBACK_ICON) as Texture2D
		detailIcon.material = _matLocked
		detailName.text = Game.t("_AchvHoverHint", "Hover an achievement to see its details")
		detailName.modulate = Color(0.62352943, 0.7058824, 0.76862746)
		detailStatus.text = ""
		detailDesc.text = ""
		detailProgress.text = ""
		return

	var achievement: Dictionary = AchievementManager.getAchievement(achievement_id)
	var unlocked: bool = AchievementManager.isUnlocked(achievement_id)

	detailIcon.texture = _loadIcon(achievement)
	detailIcon.material = _matUnlocked if unlocked else _matLocked

	detailName.text = _achievementName(achievement_id, achievement)
	detailName.modulate = Color(0.97254902, 0.98431373, 0.99215686) if unlocked else Color(0.62352943, 0.7058824, 0.76862746)

	detailStatus.text = Game.t("_AchievementUnlocked", "Unlocked") if unlocked else Game.t("_AchievementLocked", "Locked")
	detailStatus.modulate = Color(0.654902, 0.9411765, 0.4392157) if unlocked else Color(0.62352943, 0.7058824, 0.76862746)

	detailDesc.text = _achievementDesc(achievement_id, achievement)
	detailDesc.modulate = Color(0.91764706, 0.9490196, 0.96862745)

	detailProgress.text = _progressText(achievement_id, achievement)
	detailProgress.modulate = Color(1, 0.7764706, 0.101960786) if unlocked else Color(0.62352943, 0.7058824, 0.76862746)


# ---------- 工具 ----------

func _makeIconMaterials() -> void:
	var shader: Shader = load("res://shader/achievement_icon.gdshader")
	if shader == null:
		return
	_matUnlocked = ShaderMaterial.new()
	_matUnlocked.shader = shader
	_matUnlocked.set_shader_parameter("desaturate", 0.0)
	_matUnlocked.set_shader_parameter("dim", 1.0)
	_matUnlocked.set_shader_parameter("icon_zoom", 1.25)
	_matUnlocked.set_shader_parameter("outline_color", Color(1.0, 0.78, 0.2, 0.9))

	_matLocked = ShaderMaterial.new()
	_matLocked.shader = shader
	_matLocked.set_shader_parameter("desaturate", 1.0)
	_matLocked.set_shader_parameter("dim", 0.55)
	_matLocked.set_shader_parameter("icon_zoom", 1.25)
	_matLocked.set_shader_parameter("outline_color", Color(0.48, 0.6, 0.66, 0.45))


func _progressText(achievement_id: String, achievement: Dictionary) -> String:
	var currentValue: int = AchievementManager.getProgress(achievement_id)
	var targetValue: int = int(achievement.get("target", 0))
	return "%d/%d" % [currentValue, targetValue]


# 成就名称/描述在 ACHIEVEMENTS 里存的是多语言 key，这里按当前语言解析
func _achievementName(achievement_id: String, achievement: Dictionary) -> String:
	return Game.t(str(achievement.get("name", "")), achievement_id)


func _achievementDesc(achievement_id: String, achievement: Dictionary) -> String:
	return Game.t(str(achievement.get("description", "")), achievement_id)


# 取成就图标；路径缺失或加载失败时回退到默认成就图
func _loadIcon(achievement: Dictionary) -> Texture2D:
	var path: String = str(achievement.get("icon", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var tex: Resource = load(path)
		if tex is Texture2D:
			return tex
	return load(FALLBACK_ICON) as Texture2D
