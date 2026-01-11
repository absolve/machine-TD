extends CanvasLayer


@onready var itemList=$Control/VBoxContainer/ItemList

var tower1 =preload("res://sprite/tower1.png")
var tower2=preload("res://sprite/tower2.png")
var tower3=preload("res://sprite/tower3.png")

func _ready() -> void:
	itemList.add_icon_item(tower1)
	itemList.add_icon_item(tower2)
	itemList.add_icon_item(tower3)
	itemList.set_item_metadata(0,Game.towerType.gunTower)


func _on_item_list_item_selected(index: int) -> void:
	print(index)
	pass # Replace with function body.
