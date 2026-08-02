extends Node2D

@onready var levelsNode = $ui/levels
@onready var descriptionPanel=$ui/descriptionPanel


var levelGrid = preload("res://scene/level_grid.tscn")
var levelCard = preload("res://scene/level_card.tscn")


func _ready() -> void:
	var temp = levelGrid.instantiate()
	for i in range(StageData.allStage.size()):
		var card = levelCard.instantiate()
		card.level = StageData.allStage[i]['id']
		temp.add_child(card)
		if i % 12 == 0 && i != 0:
			levelsNode.add_child(temp)
			temp = levelGrid.instantiate()
	levelsNode.add_child(temp)


func _on_ui_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/welcome.tscn")
	
