extends Node2D

# 每行放几个关卡。行内卡片由 HBoxContainer 居中排列，每行都是满宽居中，
# 所以最后一排不足 COLUMNS_PER_ROW 个（比如 15 关排成 6+6+3）也是居中的。
const COLUMNS_PER_ROW := 6
const GAP := 40 # 行内卡片间距（行间距由 ui/levels 的 separation 控制，两边保持一致）

# 模式条的顺序（展示顺序，和 battleModeDefs 的书写顺序一致）
const MODE_ORDER: Array[String] = ["normal", "swarm", "armor", "elite"]
# 模式条的摆放位置。放在底栏左侧 —— 标题(75~202) 与关卡卡片(215~905) 之间没有余量，
# 强行塞进去会挤掉第三行卡片；底栏(947~1024) 右侧已被「主菜单」占用，左侧是空的。
const MODE_BAR_POS := Vector2(135, 947)
const MODE_BAR_GAP := 14
const MODE_DESC_POS := Vector2(135, 1030)
const MODE_BTN_MIN_SIZE := Vector2(128, 60)

@onready var levelsNode = $Ui/levels
@onready var descriptionPanel = $Ui/descriptionPanel


var levelCard = preload("res://scene/level_card.tscn")

## 当前选中的模式 id。点关卡卡片时才写进 Game.battleMode ——
## 提前写的话，玩家只是点了模式没进关，返回主菜单会残留。
var selectedMode: String = "normal"
## 模式按钮 id -> Button，用于互斥高亮
var modeButtons: Dictionary = {}
var modeDescLabel: Label = null


func _ready() -> void:
	buildModeBar()
	populateLevels()


## 底板上的模式切换条。**由代码创建**，不改场景文件 ——
## 它只是一排互斥按钮 + 一行说明，不需要 Inspector 调静态属性。
func buildModeBar() -> void:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.name = "modeBar"
	bar.position = MODE_BAR_POS
	bar.add_theme_constant_override("separation", MODE_BAR_GAP)
	$Ui.add_child(bar)

	for modeId in MODE_ORDER:
		if not Game.battleModeDefs.has(modeId):
			continue
		var btn: Button = Button.new()
		btn.text = Game.getBattleModeName(modeId)
		btn.toggle_mode = true
		btn.custom_minimum_size = MODE_BTN_MIN_SIZE
		btn.add_theme_font_size_override("font_size", 26)
		# tooltip：模式名 + 一句话规则 + （挑战模式）不记星级/成就的提醒
		btn.tooltip_text = "%s\n%s%s" % [
			Game.getBattleModeName(modeId),
			Game.getBattleModeDesc(modeId),
			"" if modeId == "normal" else Game.t("_ModeChallengeNote", " (no stars / achievements)"),
		]
		btn.toggled.connect(onModeToggled.bind(modeId))
		bar.add_child(btn)
		modeButtons[modeId] = btn

	modeDescLabel = Label.new()
	modeDescLabel.name = "modeDescLabel"
	modeDescLabel.position = MODE_DESC_POS
	modeDescLabel.add_theme_font_size_override("font_size", 22)
	modeDescLabel.add_theme_color_override("font_color", Color(0.65882355, 0.6862745, 0.65882355, 1.0))
	$Ui.add_child(modeDescLabel)

	selectedMode = Game.battleMode if Game.battleModeDefs.has(Game.battleMode) else "normal"
	refreshModeBar()


## 模式按钮被点：互斥选中（不用 ButtonGroup —— 代码建节点时手写互斥更直观，
## 也避免"程序化 set_pressed_no_signal 触发 toggled"这类连锁反应）。
func onModeToggled(pressed: bool, modeId: String) -> void:
	if not pressed:
		# 已经是当前选中的那个又被点了一下（toggle 弹起）→ 不允许"一个都不选"
		if selectedMode == modeId:
			refreshModeBar()
		return
	selectedMode = modeId
	refreshModeBar()


## 同步按钮的按下状态与说明文字
func refreshModeBar() -> void:
	for modeId in modeButtons:
		var btn: Button = modeButtons[modeId]
		var active: bool = modeId == selectedMode
		# set_pressed_no_signal 而不是 button_pressed：后者会再触发一次 toggled，造成递归刷新
		btn.set_pressed_no_signal(active)
		# 选中：正常模式用白，挑战模式用锈红（敌方色）提示"这不是普通难度"；未选中一律压暗
		if active:
			btn.modulate = Color(1, 1, 1, 1) if modeId == "normal" else Color(1.0, 0.78, 0.72, 1.0)
		else:
			btn.modulate = Color(0.78, 0.80, 0.85, 1.0)
	if modeDescLabel != null:
		var desc: String = Game.getBattleModeDesc(selectedMode)
		# 挑战模式额外说明"不记星级与成就"，否则玩家会以为是 bug
		if selectedMode == "normal":
			modeDescLabel.text = desc
		else:
			modeDescLabel.text = "%s%s" % [desc, Game.t("_ModeChallengeNote", " (no stars / achievements)")]


# 按 StageData 生成关卡卡片：逐行铺开，行随关卡数自动增加
func populateLevels() -> void:
	var row: HBoxContainer = null
	for stage in StageData.allStage:
		if stage.has('selectable') and stage.selectable == false:
			continue
		if row == null or row.get_child_count() >= COLUMNS_PER_ROW:
			row = addRow()
		row.add_child(makeCard(stage))


# 加一行空行（行本身撑满可用宽度，卡片靠 alignment 水平居中）
func addRow() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", GAP)
	levelsNode.add_child(row)
	return row


func makeCard(stage: Dictionary) -> Control:
	var card = levelCard.instantiate()
	card.level = stage['name']
	card.levelId = stage['id']
	card.rating = UserData.getStageRating(stage['id'])
	card.clicked.connect(loadMap)
	card.isLock = not UserData.isStageUnlocked(stage['id'])
	return card


# 加载地图
func loadMap(levelId: int) -> void:
	if not UserData.isStageUnlocked(levelId):
		return
	StageData.currentStageId = levelId
	# 模式在这里才真正生效（含把倍数解出来）；map 的 _exit_tree 会把它复位
	Game.setBattleMode(selectedMode)
	# get_tree().change_scene_to_file("res://scene/map.tscn")
	SceneTransition.changeScene("res://scene/map.tscn")

func onUiButtonPressed() -> void:
	# get_tree().change_scene_to_file("res://scene/welcome.tscn")
	SceneTransition.changeScene("res://scene/welcome.tscn")
