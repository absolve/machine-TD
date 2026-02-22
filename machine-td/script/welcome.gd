extends Node2D

@onready var aboutPanel=$aboutPanel


func _on_button_3_pressed():
	aboutPanel.popup_centered()


func _on_btn_s_start_pressed() -> void:
	var map=load("res://scene/map.tscn")
	get_tree().change_scene_to_packed(map)
