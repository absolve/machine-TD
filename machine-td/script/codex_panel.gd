extends Control
## 单位图鉴面板：一页看全所有敌人与防御塔，页签切换两类。
##
## 面板只用图片陈列单位（每行居中，鼠标放上去底下就铺出这条的完整信息），整个脚本只有两层：
##   数据层 _enemy_entry / _tower_entry —— 把一个单位整理成统一格式的「条目」字典
##     （name / tag / desc / icon / color / stats），数值全部实时读
##     Game.enemyInfo / Game.towerInfo，改战斗数值这里自动同步。
##   显示层 _make_icon / _show_detail —— 只认这个字典，完全不区分敌人还是塔。
##
## 图标也不另存一份贴图映射，而是从各自场景里现取（敌人取 base、塔取 turret 的第一帧），
## 所以新增敌人 / 防御塔时，只要进了 Game 的表（敌人还需进 StageData.enemyScenes），
## 图鉴自动多一张图，这个脚本一行都不用改。
##
## 文案走 lang/language.csv：标题 _Codex、页签 _CodexEnemies / _CodexTowers、悬停提示 _CodexHoverHint。

signal closed # 面板已关闭，宿主可以据此做后续处理

enum Tab { ENEMY, TOWER }

const ICON_SIZE := Vector2(150, 150) # 每个单位的图片绘制区（工程默认 NEAREST 过滤，放大是像素风）
const ICON_GAP := 20 # 同一行里两张图的间距
const MAX_PER_ROW := 10 # 每行最多几个，多余的换行；每行各自居中
const STAT_WIDTH := 150 # 详情条里每个数值块的最小宽度

const HOVER_TINT := Color(1.35, 1.35, 1.35) # 鼠标指向的图会亮一点，一眼能看出在看哪个
const COLOR_TEXT := Color(0.91764706, 0.9490196, 0.96862745, 1.0)
const COLOR_DIM := Color(0.62352943, 0.7058824, 0.76862746, 1.0)
const COLOR_LABEL := Color(0.65882355, 0.6862745, 0.65882355, 1.0)
const COLOR_GOLD := Color(1, 0.7764706, 0.101960786, 1.0)
const COLOR_RED := Color(1, 0.5529412, 0.5019608, 1.0) # 敌人主色：暖红
const COLOR_TEAL := Color(0.49803922, 0.8156863, 0.7764706, 1.0) # 防御塔主色：青

# 敌人行为定位 -> 一句话说明（两边存的都是翻译键）
const ENEMY_DESC_KEYS := {
	"_EnemyRole_pusher": "_EnemyDesc_pusher",
	"_EnemyRole_attacker": "_EnemyDesc_attacker",
	"_EnemyRole_support": "_EnemyDesc_support",
	"_EnemyRole_bomber": "_EnemyDesc_bomber",
	"_EnemyRole_siege": "_EnemyDesc_siege",
	"_EnemyRole_air": "_EnemyDesc_air",
}

# 防御塔场景路径：和 script/map.gd 顶部那批 preload 是同一批文件。
# 存路径按需 load()（图鉴是手动打开的，不必在启动时就拉场景）。
# 用 var 不用 const —— Game 是自动加载单例，它的枚举值不是编译期常量。
var tower_scenes := {
	Game.towerType.machineGunTower: "res://scene/tower/machineGunTower.tscn",
	Game.towerType.cannonTower: "res://scene/tower/cannonTower.tscn",
	Game.towerType.rocketTower: "res://scene/tower/rocketTower.tscn",
	Game.towerType.EMPTower: "res://scene/tower/EMPTower.tscn",
	Game.towerType.droneBase: "res://scene/tower/droneBase.tscn",
	Game.towerType.teslaCoilTower: "res://scene/tower/teslaCoilTower.tscn",
	Game.towerType.laserTower: "res://scene/tower/laserTower.tscn",
}

@onready var title_label: Label = $PanelContainer/VBoxContainer/Header/Label
@onready var close_button: Button = $PanelContainer/VBoxContainer/Header/btnClose
@onready var tab_enemies: Button = $PanelContainer/VBoxContainer/Tabs/btnEnemies
@onready var tab_towers: Button = $PanelContainer/VBoxContainer/Tabs/btnTowers
@onready var icons: VBoxContainer = $PanelContainer/VBoxContainer/icons
@onready var detail_icon: TextureRect = $PanelContainer/VBoxContainer/DetailBox/DetailVBox/DetailTop/IconCenter/detailIcon
@onready var detail_name: Label = $PanelContainer/VBoxContainer/DetailBox/DetailVBox/DetailTop/DetailInfo/DetailHeader/detailName
@onready var detail_tag: Label = $PanelContainer/VBoxContainer/DetailBox/DetailVBox/DetailTop/DetailInfo/DetailHeader/detailTag
@onready var detail_desc: Label = $PanelContainer/VBoxContainer/DetailBox/DetailVBox/DetailTop/DetailInfo/detailDesc
@onready var detail_stats: GridContainer = $PanelContainer/VBoxContainer/DetailBox/DetailVBox/detailStats

var _tab: int = Tab.ENEMY
var _icon_cache := {} # 图标缓存："e:8" / "t:1000"，切页签、切语言都不用重新取图


func _ready() -> void:
	# 这里只接信号：内容等 open() -> refresh() 时再生成，
	# 不让人在欢迎界面就提前实例化 10 个敌人场景
	visible = false
	tab_enemies.pressed.connect(_on_tab_pressed.bind(Tab.ENEMY))
	tab_towers.pressed.connect(_on_tab_pressed.bind(Tab.TOWER))


# 打开面板（每次打开都刷新一遍，保证数值和语言都是最新的）
func open() -> void:
	refresh()
	visible = true


# 关闭面板
func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _on_tab_pressed(tab: int) -> void:
	if _tab == tab:
		return
	_tab = tab
	refresh()


# ---------- 页面 ----------

# 重建当前页签的内容；打开面板 / 切页签都走这里
func refresh() -> void:
	_apply_texts()
	# 当前页签高亮金色，另一页压暗
	_style_tab(tab_enemies, _tab == Tab.ENEMY)
	_style_tab(tab_towers, _tab == Tab.TOWER)
	_clear_children(icons)
	_build_icons(_collect_entries())
	_clear_detail()


func _apply_texts() -> void:
	title_label.text = _t("_Codex", "Codex")
	close_button.text = _t("_Close", "Close")
	# 页签带上条目数，新增敌人 / 塔时会自己变
	tab_enemies.text = "%s  %d" % [_t("_CodexEnemies", "Enemies"), Game.enemyInfo.size()]
	tab_towers.text = "%s  %d" % [_t("_CodexTowers", "Towers"), Game.towerInfo.size()]


func _style_tab(button: Button, active: bool) -> void:
	var hover := Color(1, 0.8509804, 0.39215687, 1.0)
	var base := COLOR_GOLD if active else COLOR_TEXT
	button.add_theme_color_override("font_color", base)
	button.add_theme_color_override("font_focus_color", base)
	button.add_theme_color_override("font_pressed_color", hover)
	button.add_theme_color_override("font_hover_color", hover)
	button.modulate = Color(1, 1, 1, 1) if active else Color(0.82, 0.87, 0.92, 0.8)


# ---------- 显示层：单位只用图片，信息全在底下详情条（只认条目字典） ----------

# 一个单位 = 一张图
func _make_icon(entry: Dictionary) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.texture = entry["icon"]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_entered.connect(_on_icon_entered.bind(icon, entry))
	icon.mouse_exited.connect(_on_icon_exited.bind(icon))
	return icon


# 鼠标放到图上：图亮一点，底下直接铺开它的信息
func _on_icon_entered(icon: TextureRect, entry: Dictionary) -> void:
	icon.modulate = HOVER_TINT
	_show_detail(entry)


func _on_icon_exited(icon: TextureRect) -> void:
	icon.modulate = Color.WHITE
	_clear_detail()


# 图逐行铺开，每行各自居中 —— 最后一排不满也不会贴左边
func _build_icons(entries: Array) -> void:
	var row: HBoxContainer = null
	for entry in entries:
		if row == null or row.get_child_count() >= MAX_PER_ROW:
			row = _add_row()
		row.add_child(_make_icon(entry))


func _add_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", ICON_GAP)
	icons.add_child(row)
	return row


# 悬停某条 -> 直接把它的信息铺到面板底部（颜色 / 字号都是场景里定好的，这里只填内容）
func _show_detail(entry: Dictionary) -> void:
	detail_icon.texture = entry["icon"]
	detail_name.text = entry["name"]
	detail_name.modulate = COLOR_TEXT
	detail_tag.text = entry["tag"]
	detail_tag.modulate = entry["color"]
	detail_desc.text = entry["desc"]

	_clear_children(detail_stats)
	detail_stats.columns = int(entry["stat_columns"])
	for stat in entry["stats"]:
		_add_stat(str(stat[0]), str(stat[1]), stat[2])


# 鼠标移开 -> 回到提示文案
func _clear_detail() -> void:
	detail_icon.texture = null
	detail_name.text = _t("_CodexHoverHint", "Hover a unit to see its details")
	detail_name.modulate = COLOR_DIM
	detail_tag.text = ""
	detail_desc.text = ""
	_clear_children(detail_stats)


# 一个数值块：小标题 + 大数值
func _add_stat(title: String, value: String, color: Color) -> void:
	var chip := VBoxContainer.new()
	chip.custom_minimum_size = Vector2(STAT_WIDTH, 0)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(_make_label(title, 22, COLOR_LABEL))
	chip.add_child(_make_label(value, 32, color))
	detail_stats.add_child(chip)


# 详情条里的一行小文字（鼠标事件交给所在容器处理，自己不挡）
func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# ---------- 数据层：唯一需要区分敌人 / 塔的地方 ----------

# 当前页签 -> 条目数组（顺序 = Game 表里的声明顺序）
func _collect_entries() -> Array:
	var entries := []
	if _tab == Tab.ENEMY:
		for id in Game.enemyInfo:
			entries.append(_enemy_entry(id))
	else:
		for id in Game.towerInfo:
			entries.append(_tower_entry(id))
	return entries


# 条目格式（显示层只认这几个 key）：name / tag / desc / icon / color / stat_columns / stats
func _enemy_entry(id: int) -> Dictionary:
	var info: Dictionary = Game.enemyInfo.get(id, {})
	var atk := int(info.get("atk", 0))
	var delay := float(info.get("shootDelay", 0.0))
	return {
		"name": Game.get_enemy_display_name(id),
		"tag": Game.get_enemy_role_name(id),
		"desc": _t(str(ENEMY_DESC_KEYS.get(str(info.get("role", "")), "")), ""),
		"icon": _enemy_texture(id),
		"color": COLOR_RED,
		"stat_columns": 6, # 11 项数值排两行
		"stats": [
			[_t("_HP", "HP"), str(int(info.get("hp", 0))), COLOR_RED],
			[_t("_Speed", "Speed"), str(int(info.get("speed", 0))), COLOR_TEXT],
			[_t("_Armor", "Armor"), "%d%%" % roundi(float(info.get("armor", 0.0)) * 100.0), COLOR_TEXT],
			[_t("_Flying", "Flying"), _yes_no(bool(info.get("flying", false))), COLOR_TEXT],
			[_t("_Atk", "ATK"), _positive(atk), COLOR_TEXT],
			[_t("_FireRate", "Fire Rate"), _fire_rate(atk, delay), COLOR_TEXT],
			[_t("_Dps", "DPS"), _dps(atk, delay), COLOR_TEXT],
			[_t("_Range", "Range"), _positive(int(info.get("scope", 0))), COLOR_TEXT],
			[_t("_Reward", "Kill Reward"), str(int(info.get("reward", 0))), COLOR_GOLD],
			[_t("_EscapeCost", "Escape Loss"), str(int(info.get("lossPoints", 0))), COLOR_RED],
			[_t("_RewardExp", "Kill EXP"), str(int(info.get("rewardExp", 0))), COLOR_GOLD],
		],
	}


func _tower_entry(id: int) -> Dictionary:
	var info: Dictionary = Game.towerInfo.get(id, {})
	var atk := int(info.get("atk", 0))
	var reload := float(info.get("reload", 0.0))
	var grid_size: Vector2i = info.get("gridSize", Vector2i.ONE)
	return {
		"name": Game.get_tower_display_name(id),
		"tag": "%s %d" % [_t("_Cost", "Cost"), int(info.get("cost", 0))],
		"desc": _t(str(info.get("desc", "")), ""),
		"icon": _tower_texture(id),
		"color": COLOR_TEAL,
		"stat_columns": 4, # 8 项数值排两行
		"stats": [
			[_t("_Atk", "ATK"), str(atk), COLOR_TEXT],
			[_t("_FireRate", "Fire Rate"), _fire_rate(atk, reload), COLOR_TEXT],
			[_t("_Dps", "DPS"), _dps(atk, reload), COLOR_TEXT],
			[_t("_Range", "Range"), str(int(info.get("scope", 0))), COLOR_TEXT],
			[_t("_HP", "HP"), str(int(info.get("hp", 0))), COLOR_TEXT],
			[_t("_Cost", "Cost"), str(int(info.get("cost", 0))), COLOR_GOLD],
			[_t("_InitTime", "Build Time"), "%.1fs" % float(info.get("initTime", 0.0)), COLOR_TEXT],
			[_t("_GridSize", "Grid"), "%dx%d" % [grid_size.x, grid_size.y], COLOR_TEXT],
		],
	}


# ---------- 图标：从场景里现取，不另存一份贴图映射 ----------

func _enemy_texture(id: int) -> Texture2D:
	# 敌人场景表在 StageData；场景根是 PathFollow2D，敌人挂在子节点上，按名字递归找就行
	return _scene_texture("e:%d" % id, StageData.enemyScenes.get(id), "base")


func _tower_texture(id: int) -> Texture2D:
	return _scene_texture("t:%d" % id, _tower_scene(id), "turret")


func _tower_scene(id: int) -> PackedScene:
	var path := str(tower_scenes.get(id, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene


# 取场景里某个 AnimatedSprite2D 的第一帧当图标；结果按 key 缓存
func _scene_texture(key: String, scene: PackedScene, sprite_name: String) -> Texture2D:
	if not _icon_cache.has(key):
		_icon_cache[key] = _extract_texture(scene, sprite_name)
	return _icon_cache[key]


func _extract_texture(scene: PackedScene, sprite_name: String) -> Texture2D:
	if scene == null:
		return null
	var inst := scene.instantiate()
	var sprite := _find_sprite(inst, sprite_name)
	# ⚠️ 贴图必须在 inst.free() 之前取出来：free 之后 sprite 就是个失效对象，
	# 再读它会被当成 null，图就直接白了（这里踩过）
	var texture := _sprite_texture(sprite)
	inst.free()
	return texture


# 取 AnimatedSprite2D 当前帧的贴图（各单位场景里的动画名都是 default）
func _sprite_texture(sprite: AnimatedSprite2D) -> Texture2D:
	if sprite == null or sprite.sprite_frames == null:
		return null
	if not sprite.sprite_frames.has_animation(sprite.animation):
		return null
	return sprite.sprite_frames.get_frame_texture(sprite.animation, 0)


# 按名字递归找一个 AnimatedSprite2D（深度优先，先命中画在最前面的那一层）
func _find_sprite(node: Node, wanted: String) -> AnimatedSprite2D:
	if node is AnimatedSprite2D and String(node.name) == wanted:
		return node as AnimatedSprite2D
	for child in node.get_children():
		var found := _find_sprite(child, wanted)
		if found != null:
			return found
	return null


# ---------- 工具 ----------

# 清空动态生成的子节点（先脱离父节点再 queue_free，避免同一帧里新旧内容同时存在）
func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _yes_no(value: bool) -> String:
	return _t("_Yes", "Yes") if value else _t("_No", "No")


# 只有正数才有意义的值（不参战的敌人 scope / atk 都是 0）
func _positive(value: int) -> String:
	return str(value) if value > 0 else "--"


# 开火间隔(秒) -> 每秒攻击次数；atk=0 表示不参战，delay=0 表示自爆型的一次性伤害
func _fire_rate(atk: int, delay_s: float) -> String:
	if atk <= 0:
		return "--"
	return _t("_OneShot", "One-shot") if delay_s <= 0.0 else "%.1f/s" % (1.0 / delay_s)


func _dps(atk: int, delay_s: float) -> String:
	if atk <= 0 or delay_s <= 0.0:
		return "--"
	return "%.1f" % (float(atk) / delay_s)


# 取翻译；未找到对应 key（语言文件未导入）时回退到默认英文文本
func _t(key: String, fallback: String) -> String:
	if key.is_empty():
		return fallback
	var translated := tr(key)
	return fallback if translated == key else translated
