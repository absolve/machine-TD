extends Node2D
## Boss 测试场景（设计见 feature_design.md §十九）
##
## 用法：在编辑器里打开本场景按 **F6** 直接运行。
##
## 它做三件事：
##   1. 加载一张**真实关卡**（第 1 关）当背景 —— 这样路线、塔位、HUD、音效全都是真的，
##      不需要另做一套假的测试关卡
##   2. 左上角列出全部 7 种 Boss，点一下就在路线上生成一只
##   3. 显示当前存活数量与"这个 Boss 该怎么打"的一句话提示
##
## ⚠️ 本场景**不进游戏流程**：`StageData.allStage` 里没有它的入口，主菜单到不了。
## ⚠️ Boss 目前**也还没配到任何关卡**（见 19.9 的 M5），所以这是唯一能见到它们的地方。

const LEVEL_STAGE_ID := 1

## 每个按钮：显示名（翻译键）+ 类型 + 一句话应对提示
const BOSS_ENTRIES := [
	{"type": "bossBulwark", "name": "_BossName_bulwark", "tip": "_BossTip_bulwark"},
	{"type": "bossHive", "name": "_BossName_hive", "tip": "_BossTip_hive"},
	{"type": "bossCharger", "name": "_BossName_charger", "tip": "_BossTip_charger"},
	{"type": "bossSplitter", "name": "_BossName_splitter", "tip": "_BossTip_splitter"},
	{"type": "bossJammer", "name": "_BossName_jammer", "tip": "_BossTip_jammer"},
	{"type": "bossGunship", "name": "_BossName_gunship", "tip": "_BossTip_gunship"},
	{"type": "bossFortress", "name": "_BossName_fortress", "tip": "_BossTip_fortress"},
]

var map: Node = null
var panel: PanelContainer = null
var listBox: VBoxContainer = null
var statusLabel: Label = null
var tipLabel: Label = null


func _ready() -> void:
	TranslationServer.set_locale("zh")
	StageData.currentStageId = LEVEL_STAGE_ID
	Game.endlessMode = false
	Game.resetBattleMode()

	map = load("res://scene/map.tscn").instantiate()
	add_child(map)
	# 等地图把关卡实例化完（map.gd 在 _ready 里读关卡，时序上要等几帧）
	for i in 30:
		await get_tree().process_frame
	var intro: Node = map.get("levelIntroPanel")
	if intro != null and intro.has_method("close"):
		intro.call("close")
	for i in 6:
		await get_tree().process_frame
	buildUi()


func buildUi() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "TestLayer"
	layer.layer = 50
	add_child(layer)

	panel = PanelContainer.new()
	panel.position = Vector2(24, 300)
	panel.custom_minimum_size = Vector2(430, 0)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.14, 0.94)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.95, 0.60, 0.30, 1.0)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_right = 8
	sb.corner_radius_bottom_left = 8
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)

	listBox = VBoxContainer.new()
	listBox.add_theme_constant_override("separation", 6)
	panel.add_child(listBox)

	var title: Label = Label.new()
	title.text = Game.t("_BossTestTitle", "BOSS TEST")
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.80, 0.55, 1.0))
	listBox.add_child(title)

	for entry in BOSS_ENTRIES:
		var key: String = str(entry["type"])
		var typeId: int = int(Game.enemyType.get(key, -1))
		if typeId < 0:
			continue
		var btn: Button = Button.new()
		btn.text = Game.t(str(entry["name"]), key)
		btn.add_theme_font_size_override("font_size", 26)
		btn.custom_minimum_size = Vector2(0, 52)
		btn.tooltip_text = Game.t(str(entry["tip"]), "")
		btn.pressed.connect(spawnBoss.bind(typeId))
		btn.mouse_entered.connect(showTip.bind(str(entry["tip"])))
		listBox.add_child(btn)

	var clearBtn: Button = Button.new()
	clearBtn.text = Game.t("_BossTestClear", "Clear bosses")
	clearBtn.add_theme_font_size_override("font_size", 26)
	clearBtn.custom_minimum_size = Vector2(0, 52)
	clearBtn.pressed.connect(clearBosses)
	listBox.add_child(clearBtn)

	statusLabel = Label.new()
	statusLabel.add_theme_font_size_override("font_size", 24)
	statusLabel.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0, 1.0))
	listBox.add_child(statusLabel)

	tipLabel = Label.new()
	tipLabel.add_theme_font_size_override("font_size", 22)
	tipLabel.add_theme_color_override("font_color", Color(1.0, 0.88, 0.70, 1.0))
	tipLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tipLabel.custom_minimum_size = Vector2(400, 0)
	listBox.add_child(tipLabel)

	var hint: Label = Label.new()
	hint.text = Game.t("_BossTestHint", "Click a boss to spawn it on route 1.")
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82, 1.0))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(400, 0)
	listBox.add_child(hint)

	refreshStatus()


func showTip(tipKey: String) -> void:
	if tipLabel != null:
		tipLabel.text = Game.t(tipKey, "")


func spawnBoss(enemyType: int) -> void:
	var level: Node = getLevel()
	if level == null:
		push_warning("boss_test: 关卡还没加载好")
		return
	level.call("spawnEnemy", {"type": enemyType, "route": 1})
	refreshStatus()


func clearBosses() -> void:
	# 顺手把召唤物一起清掉，免得越测越多
	for node in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(node):
			node.call("freeSelf")
	refreshStatus()


func getLevel() -> Node:
	if map == null:
		return null
	return map.get("level")


func _process(_delta: float) -> void:
	refreshStatus()


## 按"类型是 Boss"来统计，而不是自己记一份列表 ——
## spawnEnemy() 不返回节点，自己记列表会漏掉召唤/分裂出来的那些。
func refreshStatus() -> void:
	if statusLabel == null:
		return
	var bossCount: int = 0
	var all: Array = get_tree().get_nodes_in_group("enemy")
	for node in all:
		if is_instance_valid(node) and int(node.get("enemyType")) >= Game.enemyType.bossBulwark:
			bossCount += 1
	statusLabel.text = "存活 Boss: %d    全场敌人: %d" % [bossCount, all.size()]
