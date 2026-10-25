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
## 星级奖励的数值用强调色（安全黄），和"宝石奖励"的青色区分开，一眼能看出是"额外给的部分"
const COLOR_STAR_BONUS := Color(1.0, 0.7764706, 0.101960786, 1.0)

## 面板里那行"星级奖励规则"提示。**由代码创建**、插在 InfoBox 之后 ——
## 这样不用改场景文件，也不会影响无尽模式的介绍页（那里把它隐藏）。
## 只有普通关卡且该关确有星级奖励时才显示。
var starHintLabel: Label = null

## 挑战模式的整宽横幅（正常模式 / 无尽模式都不显示）。同样由代码创建，
## 插在副标题下方 —— 只有挑战模式才需要，挂空节点在场景里没有意义。
var modeBanner: PanelContainer = null
var modeBannerLabel: Label = null


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
	refreshModeBanner()
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
	# 无尽模式没有关卡宝石，也就没有星级奖励 —— 把这行提示收起来
	showStarHint(false)
	# 无尽模式没有战斗模式，模式横幅也收起来
	refreshModeBanner()
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
	# 关卡名规则（数字关卡 → "第 N 关"，具名关卡 → 同名翻译键）已抽到
	# StageData.getLevelDisplayName()，因为地图顶栏也要显示同一个名字，两边共用一份实现。
	titleLabel.text = StageData.getLevelDisplayName(int(stage_data.get("id", -1)))

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


## ── 战斗模式横幅（挑战模式才显示）──
##
## 需求：选了模式之后，进关开始前的介绍界面要有一个**醒目**的提醒。
## 之前只是把 `[蜂群]` 拼在副标题前面 —— 和关卡描述混在一起，等于没提醒。
## 现在单独做一条整宽横幅（锈红底 + 大字号 + 两行），并带 tooltip。
func refreshModeBanner() -> void:
	var isChallenge: bool = not Game.endlessMode and Game.isChallengeMode()
	if not isChallenge:
		if modeBanner != null:
			modeBanner.visible = false
		return
	ensureModeBanner()
	modeBanner.visible = true
	modeBannerLabel.text = "%s · %s\n%s%s" % [
		Game.t("_ModeChallengeTitle", "CHALLENGE MODE"),
		Game.getBattleModeName(),
		Game.getBattleModeDesc(),
		Game.t("_ModeChallengeNote", " (no stars / achievements)"),
	]
	var tip: String = "%s\n%s%s" % [
		Game.getBattleModeName(),
		Game.getBattleModeDesc(),
		Game.t("_ModeChallengeNote", " (no stars / achievements)"),
	]
	modeBanner.tooltip_text = tip
	modeBannerLabel.tooltip_text = tip


func ensureModeBanner() -> void:
	if modeBanner != null:
		return
	var banner: PanelContainer = PanelContainer.new()
	banner.name = "modeBanner"
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.42, 0.14, 0.10, 0.92)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.77, 0.33, 0.21, 1.0)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_right = 10
	sb.corner_radius_bottom_left = 10
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	banner.add_theme_stylebox_override("panel", sb)
	# tooltip 需要控件参与鼠标悬停，IGNORE 的控件收不到 hover
	banner.mouse_filter = Control.MOUSE_FILTER_STOP

	var label: Label = Label.new()
	label.name = "modeBannerLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.82, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(label)

	# 插在副标题正下方（比塞进副标题显眼得多，也不会被长描述淹掉）
	var parentBox: Node = subtitleLabel.get_parent()
	parentBox.add_child(banner)
	parentBox.move_child(banner, subtitleLabel.get_index() + 1)

	modeBanner = banner
	modeBannerLabel = label


# 关卡基础信息：波数 / 基地生命 / 初始金币 / 宝石奖励 / 3★ 额外宝石 / 敌人种类 / 敌人总数
#
# ⚠️ 挑战模式下这里显示的必须是**实际会发生的数值**，不是 StageData 里的原值：
#    宝石要乘 gemScale、敌人总数要乘 countScale。否则情报面板等于在骗玩家。
func buildInfo(stage_data: Dictionary) -> void:
	clearChildren(infoBox)
	var stats: Dictionary = collectEnemyStats(stage_data)
	var challenge: bool = Game.isChallengeMode()
	addChip(Game.t("_Wave", "Wave"), str(int(stage_data.get("wave", 0))), Color(0.75, 0.95, 1.0, 1.0))
	addChip(Game.t("_BaseHealth", "Base HP"), str(int(stage_data.get("health", 0))), Color(1.0, 0.78, 0.72, 1.0))
	addChip(Game.t("_StartMoney", "Start Money"), str(int(stage_data.get("money", 0))), Color(1.0, 0.85, 0.6, 1.0))
	var baseGem: int = int(stage_data.get("gemReward", 0))
	var gemShown: int = baseGem
	if challenge:
		gemShown = int(ceil(float(baseGem) * Game.modeGemScale))
	addChip(Game.t("_GemRewardShort", "Gem Reward"), str(gemShown), Color(0.4, 0.9, 1.0, 1.0))
	# 3★ 额外宝石：开打前就把"打好能多拿多少"摆出来，
	# 否则玩家只有在结算时才知道星能换宝石（那时已经打完了）。
	# 挑战模式不记星级 → 这一格与它下面的规则说明都不该出现。
	var starBonus: int = UserData.starBonusTotal(baseGem, 3)
	if starBonus > 0 and not challenge:
		addChip(Game.t("_StarBonusShort", "3★ Bonus"), "+%d" % starBonus, COLOR_STAR_BONUS)
	addChip(Game.t("_EnemyTypes", "Enemy Types"), str(stats["types"].size()), COLOR_TEXT)
	addChip(Game.t("_TotalEnemies", "Total Enemies"), str(stats["total"]), COLOR_TEXT)
	showStarHint(starBonus > 0 and not challenge)


## 星级奖励规则提示：只在该关确有星级奖励时出现。
## 内容同时交代两件玩家猜不到的事 —— ① 3★ 不再要求满血（90% 即可）② 奖励只在刷新最高星级时发。
func showStarHint(enabled: bool) -> void:
	if starHintLabel == null:
		if not enabled:
			return
		starHintLabel = Label.new()
		starHintLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		starHintLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		starHintLabel.add_theme_font_size_override("font_size", 24)
		starHintLabel.add_theme_color_override("font_color", COLOR_HEADER)
		# 插在 InfoBox 正下方（而不是塞进 InfoBox）—— 那是一条说明，不是一项数据
		var parentBox: Node = infoBox.get_parent()
		parentBox.add_child(starHintLabel)
		parentBox.move_child(starHintLabel, infoBox.get_index() + 1)
	starHintLabel.text = Game.t("_StarRuleHint",
		"3★ needs only 90% base HP. Raising your best rating pays extra gems: "
		+ "★★ +25%, ★★★ +50%.")
	starHintLabel.visible = enabled


# 按出现顺序汇总本关敌人类型和数量
#
# ⚠️ 每一条的 number 都要乘 `Game.modeCountScale`，且**逐条取整** ——
#    必须和 base_level.buildWaveSpawner() 用同一套算法（maxi(1, ceil(n × scale)))，
#    否则蜂群模式下这里显示 x94、实际刷 x188，情报面板就在骗人。
func collectEnemyStats(stage_data: Dictionary) -> Dictionary:
	var order: Array = []
	var counts: Dictionary = {}
	var total: int = 0
	var countScale: float = Game.modeCountScale
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
			if not is_equal_approx(countScale, 1.0):
				number = maxi(1, int(ceil(float(number) * countScale)))
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
	# 血量与速度都要乘模式倍数（与 enemy.gd::setupEnemyInfo 保持一致），
	# 否则显示的是"没被模式调整过"的数值 —— 情报面板就在骗人。
	for enemyType in order:
		var info: Dictionary = Game.enemyInfo.get(enemyType, {})
		var isAir: bool = bool(info.get("flying", false))
		var hpShown: int = int(info.get("hp", 0))
		if not is_equal_approx(Game.modeHpScale, 1.0):
			hpShown = maxi(1, int(ceil(float(hpShown) * Game.modeHpScale)))
		var speedShown: int = int(info.get("speed", 0))
		if not is_equal_approx(Game.modeSpeedScale, 1.0):
			speedShown = maxi(1, int(round(float(speedShown) * Game.modeSpeedScale)))
		addRow(
			Game.getEnemyDisplayName(enemyType),
			Game.getEnemyRoleName(enemyType),
			"x%d" % int(stats["counts"].get(enemyType, 0)),
			str(hpShown),
			str(speedShown),
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
