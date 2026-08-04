extends Control

var sound = preload("res://sound/Pickup.wav")


@onready var master = $box/PanelContainer2/VBoxContainer/MarginContainer/VBoxContainer/master
@onready var bg = $box/PanelContainer2/VBoxContainer/MarginContainer/VBoxContainer/bg
@onready var sfx = $box/PanelContainer2/VBoxContainer/MarginContainer/VBoxContainer/sfx
@onready var language=$box/main/VBoxContainer/MarginContainer/HBoxContainer/language

func _ready() -> void:
	master.busName='Master'
	bg.busName='Bg'
	sfx.busName='Sfx'
	master.sound.stream = sound
	bg.sound.stream = sound
	sfx.sound.stream = sound
	
	print(OS.get_locale_language())

func _on_master_value_changed(value: float):
	master.volume=value/100
	master.playSound()

func _on_bg_value_changed(value: float):
	bg.volume=value/100
	bg.playSound()

	
func _on_sfx_value_changed(value: float):
	sfx.volume=value/100
	sfx.playSound()


func _on_option_button_item_selected(index: int) -> void:
	print(language.get_item_text(index)) 
	TranslationServer.set_locale(language.get_item_text(index))
