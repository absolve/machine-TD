extends Node2D

@onready var aboutPanel=$aboutPanel
@onready var settingPanel=$settingPanel


func _on_button_3_pressed():
	aboutPanel.popup_centered()


func _on_btn_s_start_pressed() -> void:
	#var map=load("res://scene/map.tscn")
	#get_tree().change_scene_to_packed(map)
	#get_tree().change_scene_to_file("res://scene/level_select.tscn")
	SceneTransition.change_scene("res://scene/level_select.tscn")

func _on_setting_pressed() -> void:
	settingPanel.popup_centered()


func _on_setting_close() -> void:
	settingPanel.hide()
	
