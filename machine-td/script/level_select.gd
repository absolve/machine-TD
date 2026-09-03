extends Node2D

@onready var levelsNode = $ui/levels
@onready var descriptionPanel = $ui/descriptionPanel


var levelCard = preload("res://scene/level_card.tscn")


func _ready() -> void:
	for stage in StageData.allStage:
		if stage.has('selectable')&& stage.selectable==false:
			continue
		var card = levelCard.instantiate()
		card.level = stage['name']
		card.levelId = stage['id']
		card.rating = UserData.getStageRating(stage['id'])
		card.click.connect(loadMap)
		card.isLock = not UserData.isStageUnlocked(stage['id'])
		levelsNode.add_child(card)


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
