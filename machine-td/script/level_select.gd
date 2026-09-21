extends Node2D

# 每行放几个关卡。行内卡片由 HBoxContainer 居中排列，每行都是满宽居中，
# 所以最后一排不足 COLUMNS_PER_ROW 个（比如 15 关排成 6+6+3）也是居中的。
const COLUMNS_PER_ROW := 6
const GAP := 40 # 行内卡片间距（行间距由 ui/levels 的 separation 控制，两边保持一致）

@onready var levelsNode = $ui/levels
@onready var descriptionPanel = $ui/descriptionPanel


var levelCard = preload("res://scene/level_card.tscn")


func _ready() -> void:
	populateLevels()


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
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", GAP)
	levelsNode.add_child(row)
	return row


func makeCard(stage: Dictionary) -> Control:
	var card = levelCard.instantiate()
	card.level = stage['name']
	card.levelId = stage['id']
	card.rating = UserData.getStageRating(stage['id'])
	card.click.connect(loadMap)
	card.isLock = not UserData.isStageUnlocked(stage['id'])
	return card


# 加载地图
func loadMap(levelId: int) -> void:
	if not UserData.isStageUnlocked(levelId):
		return
	StageData.currentStageId = levelId
	# get_tree().change_scene_to_file("res://scene/map.tscn")
	SceneTransition.change_scene("res://scene/map.tscn")

func _on_ui_button_pressed() -> void:
	# get_tree().change_scene_to_file("res://scene/welcome.tscn")
	SceneTransition.change_scene("res://scene/welcome.tscn")
