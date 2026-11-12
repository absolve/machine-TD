extends Control
## 通关 / 失败结算面板。已从 Window 改为普通 Control，否则嵌入式子窗口会盖在场景切换遮罩之上。

@onready var levelRating = $PanelContainer/VBoxContainer3/MarginContainer/vbox/levelRating
@onready var resultLabel = $PanelContainer/VBoxContainer3/MarginContainer/vbox/resultLabel
@onready var waveLabel = $PanelContainer/VBoxContainer3/MarginContainer/vbox/waveLabel
@onready var gemRewardRow = $PanelContainer/VBoxContainer3/MarginContainer/vbox/gemRewardRow
@onready var gemRewardLabel = $PanelContainer/VBoxContainer3/MarginContainer/vbox/gemRewardRow/gemRewardLabel
@onready var btnRestart:Button=$PanelContainer/VBoxContainer3/MarginContainer2/hbox/btnRestart
@onready var btnNextLevel:Button=$PanelContainer/VBoxContainer3/MarginContainer2/hbox/btnNextLevel
@onready var btnMenu:Button=$PanelContainer/VBoxContainer3/MarginContainer2/hbox/btnMenu

@export var isFailed = false # 是否失败


func _ready():
	#levelRating.rating = 1
	# setResult(true)
	
	pass

# 设置结果
func setResult(_isFailed: bool):
	isFailed = _isFailed
	if isFailed:
		resultLabel.text = tr("_LevelFailed")
		gemRewardRow.visible = false
		# 失败时没有下一关可去
		btnNextLevel.visible = false
	else:
		resultLabel.text = tr("_LevelCompleted")
		btnNextLevel.visible = true

## 设置宝石奖励并显示。
##
## ⚠️ 旧实现是 `gemRewardRow.visible = amount > 0`，而宝石**只在首次通关发放**
##    （见 userData.recordStageCompletion），所以重复打同一关时 amount 恒为 0，
##    整行直接被隐藏 —— 看起来就是"结束菜单上没有奖励宝石"。
## 现在：通关时**始终显示这一行**，amount 为 0 就明确写"本关宝石已领取过"，
## 让玩家知道不是漏发了，而是这一关的宝石已经拿过。
##
## `starBonus` 是 amount 里**来自星级**的那部分（0 表示本次没有星级提升）。
## 只在它大于 0 时才换用「含星级奖励」的文案 —— 平时不显示，避免每关都多出半句话。
func setGemReward(amount: int, starBonus: int = 0) -> void:
	if amount > 0:
		if starBonus > 0:
			gemRewardLabel.text = tr("_GemRewardWithStar") % [amount, starBonus]
		else:
			gemRewardLabel.text = tr("_GemReward") % amount
		gemRewardRow.modulate = Color(1, 1, 1, 1)
	else:
		gemRewardLabel.text = tr("_GemRewardNone")
		# 压暗一档，和"真拿到宝石"在视觉上区分开
		gemRewardRow.modulate = Color(1, 1, 1, 0.55)
	gemRewardRow.visible = true


func onBtnRestartPressed():
	pass # Replace with function body.


## ── 本局战报（feature_design.md §二十一 A）──
##
## 版式：**固定表头 + 可滚动列表**。
##   · 表头不放进滚动区 —— 否则滚下去就看不到列名了
##   · 每列用固定宽度（`REPORT_COL_WIDTHS`），表头与数据行才对得齐
##   · 高度随行数自适应，超过 `REPORT_MAX_HEIGHT` 才出现滚动条
## 只读展示，不参与任何结算逻辑。
const REPORT_COL_WIDTHS := [300.0, 90.0, 120.0, 90.0]
const REPORT_HEADER_SEP := 18
const REPORT_ROW_HEIGHT := 30.0
const REPORT_MIN_HEIGHT := 64.0
const REPORT_MAX_HEIGHT := 240.0

var reportBox: VBoxContainer = null
var reportTitle: Label = null
var reportHeader: HBoxContainer = null
var reportScroll: ScrollContainer = null
var reportGrid: GridContainer = null
var reportLeakLabel: Label = null


func setReport(report: Dictionary) -> void:
	ensureReportUi()
	var towers: Array = report.get("towers", [])
	var totalDamage: int = maxi(1, int(report.get("totalDamage", 0)))
	for child in reportGrid.get_children():
		child.queue_free()

	# 标题带上总伤害，让"占比"有参照
	reportTitle.text = "%s  ·  %s" % [
		Game.t("_ReportTitle", "Battle Report"),
		Game.t("_ReportTotalDamage", "Total %d") % int(report.get("totalDamage", 0)),
	]

	# 不再截断前 5 座 —— 有滚动条了，全部列出来
	var shown: int = 0
	for row in towers:
		var damage: int = int(row.get("damage", 0))
		var percent: int = int(round(float(damage) * 100.0 / float(totalDamage)))
		reportGrid.add_child(makeCell(
			"%s Lv.%d" % [str(row.get("name", "?")), int(row.get("level", 1))],
			Palette.UI_100, 24, 0))
		reportGrid.add_child(makeCell("%d%%" % percent, Palette.HAZARD_500, 24, 1, true))
		reportGrid.add_child(makeCell("%d" % damage, Palette.SUCCESS_LT, 24, 2, true))
		reportGrid.add_child(makeCell("%d" % int(row.get("kills", 0)), Palette.UI_100, 24, 3, true))
		shown += 1

	if shown == 0:
		reportGrid.add_child(makeCell(Game.t("_ReportNoData", "No tower dealt damage"),
			Palette.UI_300, 22, 0))

	# 高度自适应：行多才出现滚动条，行少时不占地方
	var wanted: float = maxf(REPORT_MIN_HEIGHT,
		float(shown) * REPORT_ROW_HEIGHT + 6.0)
	reportScroll.custom_minimum_size = Vector2(0.0, minf(wanted, REPORT_MAX_HEIGHT))

	# 漏怪：按类型汇总；一只没漏就明确写"没有漏怪"（这是值得炫耀的信息）
	var leaks: Array = report.get("leaks", [])
	if leaks.is_empty():
		reportLeakLabel.text = Game.t("_ReportNoLeaks", "No enemies got through")
		reportLeakLabel.add_theme_color_override("font_color", Palette.SUCCESS_LT)
	else:
		var parts: Array = []
		for item in leaks:
			parts.append("%s ×%d" % [str(item.get("name", "?")), int(item.get("count", 0))])
		reportLeakLabel.text = "%s: %s" % [
			Game.t("_ReportLeaks", "Leaked"), "  ".join(parts)]
		reportLeakLabel.add_theme_color_override("font_color", Palette.DANGER_TEXT)
	reportBox.visible = true


func ensureReportUi() -> void:
	if reportBox != null:
		return
	var parent: Node = gemRewardRow.get_parent()
	reportBox = VBoxContainer.new()
	reportBox.name = "reportBox"
	reportBox.add_theme_constant_override("separation", 3)
	reportBox.visible = false
	parent.add_child(reportBox)
	# 放到宝石行**下面**、按钮区之前
	parent.move_child(reportBox, gemRewardRow.get_index() + 1)

	reportTitle = Label.new()
	reportTitle.add_theme_font_size_override("font_size", 24)
	reportTitle.add_theme_color_override("font_color", Palette.ALERT_300)
	reportBox.add_child(reportTitle)

	# ── 固定表头 ──
	reportHeader = HBoxContainer.new()
	reportHeader.name = "reportHeader"
	reportHeader.add_theme_constant_override("separation", REPORT_HEADER_SEP)
	reportHeader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var headerColor := Palette.UI_300
	var headers := [
		Game.t("_ReportColTower", "Tower"),
		Game.t("_ReportColShare", "Share"),
		Game.t("_ReportColDamage", "Damage"),
		Game.t("_ReportColKills", "Kills"),
	]
	for i in headers.size():
		reportHeader.add_child(makeCell(str(headers[i]), headerColor, 20, i, i > 0))
	reportBox.add_child(reportHeader)

	# 表头下的分隔线：视觉上把"列名"和"数据"分开
	var line: ColorRect = ColorRect.new()
	line.name = "reportLine"
	line.color = Color(1, 1, 1, 0.14)
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reportBox.add_child(line)

	# ── 滚动区 ──
	reportScroll = ScrollContainer.new()
	reportScroll.name = "reportScroll"
	reportScroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reportScroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	reportScroll.custom_minimum_size = Vector2(0, REPORT_MIN_HEIGHT)
	reportScroll.follow_focus = false
	reportBox.add_child(reportScroll)

	reportGrid = GridContainer.new()
	reportGrid.name = "reportGrid"
	reportGrid.columns = 4
	reportGrid.add_theme_constant_override("h_separation", REPORT_HEADER_SEP)
	reportGrid.add_theme_constant_override("v_separation", 2)
	reportGrid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reportScroll.add_child(reportGrid)

	reportLeakLabel = Label.new()
	reportLeakLabel.add_theme_font_size_override("font_size", 22)
	reportLeakLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reportBox.add_child(reportLeakLabel)


## 表格单元格。
## `column` 决定固定宽度 —— 表头和数据行用同一张表，列才对齐；
## `alignRight` 用于数字列（塔名长度不一，右对齐才数得清）。
func makeCell(text: String, color: Color, fontSize: int, column: int,
		alignRight: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", fontSize)
	label.custom_minimum_size = Vector2(REPORT_COL_WIDTHS[column % REPORT_COL_WIDTHS.size()], 0)
	if alignRight:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label
