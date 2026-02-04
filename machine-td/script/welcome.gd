extends Node2D

@onready var aboutPanel=$aboutPanel


func _on_button_3_pressed():
	aboutPanel.popup_centered()
