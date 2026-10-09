extends Control
## 关卡开始前的情报弹窗。
##
## 已从 PopupPanel 改为普通 Control —— Godot 的嵌入式子窗口（Window / Popup / PopupPanel）
## 永远画在所有 CanvasLayer 之上，会让场景切换的遮罩盖不住它。
## 背景 StyleBox 因此从 PopupPanel 的 `panel` 主题项搬到了 `panelBg`（Panel 节点）上。
##
## 地图加载完成后弹出，显示关卡名、波数、基地生命、初始金币、宝石奖励，
## 以及本关会出现的全部敌人类型（名称 / 定位 / 数量 / 血量 / 速度 / 是否空中）。
## 敌人数据统一取自 Game.enemyInfo 和 StageData.allStage，避免与战斗数值不同步。

## 面板关闭时发出（点了「开始战斗」）。map 接这个信号去提示玩家点顶栏的开始按钮。
signal closed

@onready var titleLabel: Label = $Center/panelBg/Margin/VBox/titleLabel
@onready var subtitleLabel: Label = $Center/panelBg/Margin/VBox/subtitleLabel
@onready var infoBox: HBoxContainer = $Center/panelBg/Margin/VBox/InfoBox
@onready var intelTitle: Label = $Center/panelBg/Margin/VBox/intelTitle
@onready var enemyList: VBoxContainer = $Center/panelBg/Margin/VBox/ScrollContainer/enemyList
@onready var hintLabel: Label = $Center/panelBg/Margin/VBox/Footer/hintLabel
@onready var startButton: Button = $Center/panelBg/Margin/VBox/Footer/btnStart

# 敌人列表各列的固定宽度，表头与数据行共用，保证纵向对齐
const COL_WIDTH_ROLE := 200
const COL_WIDTH_COUNT := 110
const COL_WIDTH_HP := 140
const COL_WIDTH_SPEED := 140
const COL_WIDTH_AIR := 100

const COLOR_HEADER := Color(0.65882355, 0.6862745, 0.65882355, 1.0)
const COLOR_TEXT := Color(0.89411765, 0.92156863, 0.8745098, 1.0)


func _ready() -> void:
	startButton.pressed.connect(close)
	intelTitle.text = Game.t("_EnemyIntel", "Enemy Intel")
	hintLabel.text = Game.t("_IntelHint", "Close this window and press Start to begin the battle.")
	startButton.text = Game.t("_BeginBattle", "Begin Battle")


# 关闭面板。**统一走这里**，closed 信号才会一定发出去
# （直接调 hide() 的话 map 收不到通知，就不知道要提示玩家点开始了）
func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


# 地图加载完成后调用：填充关卡信息并弹出
func showLevel(stage_data: Dictionary) -> void:
	if stage_data.is_empty():
		return
	fillHeader(stage_data)
	buildInfo(stage_data)
	buildEnemyList(stage_data)
	show()


## 无尽模式的介绍页：**复用同一个面板**，但内容是"规则 + 最高记录"，
## 不读 stageData（无尽没有关卡数据）。外观、"点开始关闭"的流程与普通关卡一致。
func showEndless(bestWave: int) -> void:
	titleLabel.text = Game.t("_Endless", "Endless Mode")
	subtitleLabel.text = Game.t("_EndlessIntroHint", "No finish line — hold the base "
		+ "and see how many waves you can take.")
	clearChildren(infoBox)
	addChip(Game.t("_BaseHealth", "Base HP"), "10", Color(0.75, 0.95, 1.0, 1.0))
	addChip(Game.t("_EndlessCrowd", "On Screen"), "90", Color(1.0, 0.85, 0.6, 1.0))
	addChip(Game.t("_EndlessBest", "Best Record"), str(bestWave), Color(1.0, 0.78, 0.72, 1.0))
	# 规则用几行纯文本代替"敌人清单"，比逐条列兵种好读
	intelTitle.text = Game.t("_EndlessRules", "Rules")
	clearChildren(enemyList)
	for key in ["_EndlessRule1", "_EndlessRule2", "_EndlessRule3"]:
		var line: Label = Label.new()
		line.text = tr(key)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override("font_size", 28)
		line.add_theme_color_override("font_color", COLOR_TEXT)
		enemyList.add_child(line)
	show()


func fillHeader(stage_data: Dictionary) -> void:
	var levelName: String = str(stage_data.get("name", ""))
	if levelName.is_valid_int():
		titleLabel.text = Game.t("_LevelTitleFmt", "Level %s") % levelName
	else:
		# 教程等具名关卡：优先取同名翻译键（如 _Tutorial）
		titleLabel.text = Game.t("_" + levelName, levelName)

	var categoryKey: String = str(stage_data.get("category", ""))
	var descriptionKey: String = str(stage_data.get("description", ""))
	# ⚠️ stageData 里这两个字段存的是**翻译键**（_Level1Category / _Level1Description …），
	#    必须过 Game.t —— 以前直接把原文塞进 label，切英文后副标题还是中文。
	#    判空用 key（空串时 Game.t 会原样返回空串，不影响 "只有副标题" 的写法）。
	var category: String = Game.t(categoryKey, categoryKey)
	var description: String = Game.t(descriptionKey, descriptionKey)
	if categoryKey.is_empty():
		subtitleLabel.text = description
	elif descriptionKey.is_empty():
		subtitleLabel.text = category
	else:
		subtitleLabel.text = "%s  ·  %s" % [category, description]


# 关卡基础信息：波数 / 基地生命 / 初始金币 / 宝石奖励 / 敌人种类 / 敌人总数
func buildInfo(stage_data: Dictionary) -> void:
	clearChildren(infoBox)
	var stats: Dictionary = collectEnemyStats(stage_data)
	addChip(Game.t("_Wave", "Wave"), str(int(stage_data.get("wave", 0))), Color(0.75, 0.95, 1.0, 1.0))
	addChip(Game.t("_BaseHealth", "Base HP"), str(int(stage_data.get("health", 0))), Color(1.0, 0.78, 0.72, 1.0))
	addChip(Game.t("_StartMoney", "Start Money"), str(int(stage_data.get("money", 0))), Color(1.0, 0.85, 0.6, 1.0))
	addChip(Game.t("_GemRewardShort", "Gem Reward"), str(int(stage_data.get("gemReward", 0))), Color(0.4, 0.9, 1.0, 1.0))
	addChip(Game.t("_EnemyTypes", "Enemy Types"), str(stats["types"].size()), COLOR_TEXT)
	addChip(Game.t("_TotalEnemies", "Total Enemies"), str(stats["total"]), COLOR_TEXT)


# 按出现顺序汇总本关敌人类型和数量
func collectEnemyStats(stage_data: Dictionary) -> Dictionary:
	var order: Array = []
	var counts: Dictionary = {}
	var total: int = 0
	var spawner = stage_data.get("enemySpawner", [])
	if spawner is Array:
		for entry in spawner:
			if not (entry is Dictionary):
				continue
			var enemyType = entry.get("type", null)
			if enemyType == null:
				continue
			if not counts.has(enemyType):
				counts[enemyType] = 0
				order.append(enemyType)
			var number: int = int(entry.get("number", 0))
			counts[enemyType] += number
			total += number
	return {"types": order, "counts": counts, "total": total}


func buildEnemyList(stage_data: Dictionary) -> void:
	clearChildren(enemyList)
	var stats: Dictionary = collectEnemyStats(stage_data)
	var order: Array = stats["types"]
	if order.is_empty():
		var empty: Label = Label.new()
		empty.text = Game.t("_NoEnemyData", "No enemy data for this level.")
		empty.add_theme_font_size_override("font_size", 26)
		empty.add_theme_color_override("font_color", COLOR_HEADER)
		enemyList.add_child(empty)
		return

	# 表头
	addRow(
		Game.t("_EnemyColName", "Enemy"),
		Game.t("_EnemyColRole", "Role"),
		Game.t("_EnemyColCount", "Count"),
		Game.t("_EnemyColHp", "HP"),
		Game.t("_EnemyColSpeed", "Speed"),
		Game.t("_EnemyColAir", "Air"),
		COLOR_HEADER, 26, true)

	# 每种敌人一行，属性取 Game.enemyInfo，名称/定位取多语言显示名
	for enemyType in order:
		var info: Dictionary = Game.enemyInfo.get(enemyType, {})
		var isAir: bool = bool(info.get("flying", false))
		addRow(
			Game.getEnemyDisplayName(enemyType),
			Game.getEnemyRoleName(enemyType),
			"x%d" % int(stats["counts"].get(enemyType, 0)),
			str(int(info.get("hp", 0))),
			str(int(info.get("speed", 0))),
			Game.t("_Yes", "Yes") if isAir else "-",
			COLOR_TEXT, 30, false)


# 一行敌人信息；is_header 为 true 时在行后追加分隔线
func addRow(
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
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var nameCell: Label = makeCell(col_name, 0, HORIZONTAL_ALIGNMENT_LEFT, color, font_size)
	nameCell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(nameCell)

	row.add_child(makeCell(col_role, COL_WIDTH_ROLE, HORIZONTAL_ALIGNMENT_LEFT, color, font_size))
	row.add_child(makeCell(col_count, COL_WIDTH_COUNT, HORIZONTAL_ALIGNMENT_CENTER, color, font_size))
	row.add_child(makeCell(col_hp, COL_WIDTH_HP, HORIZONTAL_ALIGNMENT_RIGHT, color, font_size))
	row.add_child(makeCell(col_speed, COL_WIDTH_SPEED, HORIZONTAL_ALIGNMENT_RIGHT, color, font_size))
	row.add_child(makeCell(col_air, COL_WIDTH_AIR, HORIZONTAL_ALIGNMENT_CENTER, color, font_size))

	enemyList.add_child(row)
	if is_header:
		enemyList.add_child(HSeparator.new())


func makeCell(text: String, width: int, align: HorizontalAlignment, color: Color, font_size: int) -> Label:
	var cell: Label = Label.new()
	cell.text = text
	cell.horizontal_alignment = align
	cell.add_theme_font_size_override("font_size", font_size)
	cell.add_theme_color_override("font_color", color)
	if width > 0:
		cell.custom_minimum_size = Vector2(width, 0)
	return cell


# 两条路线：路线1 走上方，路线2 走下方（折点见同名 .tscn 里的两个 Path2D）
func addChip(title: String, value: String, color: Color) -> void:
	var chip: VBoxContainer = VBoxContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.alignment = BoxContainer.ALIGNMENT_CENTER

	var chipTitle: Label = Label.new()
	chipTitle.text = title
	chipTitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chipTitle.add_theme_font_size_override("font_size", 24)
	chipTitle.add_theme_color_override("font_color", COLOR_HEADER)

	var valueLabel: Label = Label.new()
	valueLabel.text = value
	valueLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	valueLabel.add_theme_font_size_override("font_size", 40)
	valueLabel.add_theme_color_override("font_color", color)

	chip.add_child(chipTitle)
	chip.add_child(valueLabel)
	infoBox.add_child(chip)


# 清空动态生成的子节点（立即移除，避免同帧残留）
func clearChildren(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
