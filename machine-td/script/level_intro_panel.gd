extends PopupPanel
## 关卡开始前的情报弹窗。
## 地图加载完成后弹出，显示关卡名、波数、基地生命、初始金币、宝石奖励，
## 以及本关会出现的全部敌人类型（名称 / 定位 / 数量 / 血量 / 速度 / 是否空中）。
## 敌人数据统一取自 Game.enemyInfo 和 StageData.allStage，避免与战斗数值不同步。

@onready var title_label: Label = $Margin/VBox/titleLabel
@onready var subtitle_label: Label = $Margin/VBox/subtitleLabel
@onready var info_box: HBoxContainer = $Margin/VBox/InfoBox
@onready var intel_title: Label = $Margin/VBox/intelTitle
@onready var enemy_list: VBoxContainer = $Margin/VBox/ScrollContainer/enemyList
@onready var hint_label: Label = $Margin/VBox/Footer/hintLabel
@onready var start_button: Button = $Margin/VBox/Footer/btnStart

# 敌人列表各列的固定宽度，表头与数据行共用，保证纵向对齐
const COL_WIDTH_ROLE := 160
const COL_WIDTH_COUNT := 90
const COL_WIDTH_HP := 110
const COL_WIDTH_SPEED := 110
const COL_WIDTH_AIR := 80

const COLOR_HEADER := Color(0.62, 0.72, 0.85, 1.0)
const COLOR_TEXT := Color(1.0, 1.0, 1.0, 1.0)


func _ready() -> void:
	start_button.pressed.connect(hide)
	intel_title.text = _t("_EnemyIntel", "Enemy Intel")
	hint_label.text = _t("_IntelHint", "Close this window and press Start to begin the battle.")
	start_button.text = _t("_BeginBattle", "Begin Battle")


# 地图加载完成后调用：填充关卡信息并弹出
func show_level(stage_data: Dictionary) -> void:
	if stage_data.is_empty():
		return
	_fill_header(stage_data)
	_build_info(stage_data)
	_build_enemy_list(stage_data)
	popup_centered()


func _fill_header(stage_data: Dictionary) -> void:
	var level_name := str(stage_data.get("name", ""))
	if level_name.is_valid_int():
		title_label.text = _t("_LevelTitleFmt", "Level %s") % level_name
	else:
		# 教程等具名关卡：优先取同名翻译键（如 _Tutorial）
		title_label.text = _t("_" + level_name, level_name)

	var category := str(stage_data.get("category", ""))
	var description := str(stage_data.get("description", ""))
	if category.is_empty():
		subtitle_label.text = description
	elif description.is_empty():
		subtitle_label.text = category
	else:
		subtitle_label.text = "%s  ·  %s" % [category, description]


# 关卡基础信息：波数 / 基地生命 / 初始金币 / 宝石奖励 / 敌人种类 / 敌人总数
func _build_info(stage_data: Dictionary) -> void:
	_clear_children(info_box)
	var stats := _collect_enemy_stats(stage_data)
	_add_chip(_t("_Wave", "Wave"), str(int(stage_data.get("wave", 0))), Color(0.75, 0.95, 1.0, 1.0))
	_add_chip(_t("_BaseHealth", "Base HP"), str(int(stage_data.get("health", 0))), Color(1.0, 0.78, 0.72, 1.0))
	_add_chip(_t("_StartMoney", "Start Money"), str(int(stage_data.get("money", 0))), Color(1.0, 0.85, 0.6, 1.0))
	_add_chip(_t("_GemRewardShort", "Gem Reward"), str(int(stage_data.get("gemReward", 0))), Color(0.4, 0.9, 1.0, 1.0))
	_add_chip(_t("_EnemyTypes", "Enemy Types"), str(stats["types"].size()), COLOR_TEXT)
	_add_chip(_t("_TotalEnemies", "Total Enemies"), str(stats["total"]), COLOR_TEXT)


# 按出现顺序汇总本关敌人类型和数量
func _collect_enemy_stats(stage_data: Dictionary) -> Dictionary:
	var order: Array = []
	var counts: Dictionary = {}
	var total := 0
	var spawner = stage_data.get("enemySpawner", [])
	if spawner is Array:
		for entry in spawner:
			if not (entry is Dictionary):
				continue
			var enemy_type = entry.get("type", null)
			if enemy_type == null:
				continue
			if not counts.has(enemy_type):
				counts[enemy_type] = 0
				order.append(enemy_type)
			var number := int(entry.get("number", 0))
			counts[enemy_type] += number
			total += number
	return {"types": order, "counts": counts, "total": total}


func _build_enemy_list(stage_data: Dictionary) -> void:
	_clear_children(enemy_list)
	var stats := _collect_enemy_stats(stage_data)
	var order: Array = stats["types"]
	if order.is_empty():
		var empty := Label.new()
		empty.text = _t("_NoEnemyData", "No enemy data for this level.")
		empty.add_theme_font_size_override("font_size", 22)
		empty.add_theme_color_override("font_color", COLOR_HEADER)
		enemy_list.add_child(empty)
		return

	# 表头
	_add_row(
		_t("_EnemyColName", "Enemy"),
		_t("_EnemyColRole", "Role"),
		_t("_EnemyColCount", "Count"),
		_t("_EnemyColHp", "HP"),
		_t("_EnemyColSpeed", "Speed"),
		_t("_EnemyColAir", "Air"),
		COLOR_HEADER, 20, true)

	# 每种敌人一行，属性取 Game.enemyInfo，名称/定位取多语言显示名
	for enemy_type in order:
		var info: Dictionary = Game.enemyInfo.get(enemy_type, {})
		var is_air := bool(info.get("flying", false))
		_add_row(
			Game.get_enemy_display_name(enemy_type),
			Game.get_enemy_role_name(enemy_type),
			"x%d" % int(stats["counts"].get(enemy_type, 0)),
			str(int(info.get("hp", 0))),
			str(int(info.get("speed", 0))),
			_t("_Yes", "Yes") if is_air else "-",
			COLOR_TEXT, 24, false)


# 一行敌人信息；is_header 为 true 时在行后追加分隔线
func _add_row(
	col_name: String,
	col_role: String,
	col_count: String,
	col_hp: String,
	col_speed: String,
	col_air: String,
	color: Color,
	font_size: int,
	is_header: bool
) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var name_cell := _make_cell(col_name, 0, HORIZONTAL_ALIGNMENT_LEFT, color, font_size)
	name_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_cell)

	row.add_child(_make_cell(col_role, COL_WIDTH_ROLE, HORIZONTAL_ALIGNMENT_LEFT, color, font_size))
	row.add_child(_make_cell(col_count, COL_WIDTH_COUNT, HORIZONTAL_ALIGNMENT_CENTER, color, font_size))
	row.add_child(_make_cell(col_hp, COL_WIDTH_HP, HORIZONTAL_ALIGNMENT_RIGHT, color, font_size))
	row.add_child(_make_cell(col_speed, COL_WIDTH_SPEED, HORIZONTAL_ALIGNMENT_RIGHT, color, font_size))
	row.add_child(_make_cell(col_air, COL_WIDTH_AIR, HORIZONTAL_ALIGNMENT_CENTER, color, font_size))

	enemy_list.add_child(row)
	if is_header:
		enemy_list.add_child(HSeparator.new())


func _make_cell(text: String, width: int, align: int, color: Color, font_size: int) -> Label:
	var cell := Label.new()
	cell.text = text
	cell.horizontal_alignment = align
	cell.add_theme_font_size_override("font_size", font_size)
	cell.add_theme_color_override("font_color", color)
	if width > 0:
		cell.custom_minimum_size = Vector2(width, 0)
	return cell


# 关卡信息上方的单个数据块：标题在上，数值在下
func _add_chip(title: String, value: String, color: Color) -> void:
	var chip := VBoxContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.alignment = BoxContainer.ALIGNMENT_CENTER

	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", COLOR_HEADER)

	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 32)
	value_label.add_theme_color_override("font_color", color)

	chip.add_child(title_label)
	chip.add_child(value_label)
	info_box.add_child(chip)


# 清空动态生成的子节点（立即移除，避免同帧残留）
func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


# 取翻译；语言文件未导入该 key 时回退到默认英文文本
func _t(key: String, fallback: String) -> String:
	if key.is_empty():
		return fallback
	var translated := tr(key)
	return fallback if translated == key else translated
