extends Control

var sound = preload("res://sound/Pickup.wav")


@onready var master = $box/PanelContainer2/VBoxContainer/MarginContainer/VBoxContainer/master
@onready var bg = $box/PanelContainer2/VBoxContainer/MarginContainer/VBoxContainer/bg
@onready var sfx = $box/PanelContainer2/VBoxContainer/MarginContainer/VBoxContainer/sfx
@onready var language = $box/main/VBoxContainer/MarginContainer/HBoxContainer/language

signal close


func _ready() -> void:
	master.busName = 'Master'
	bg.busName = 'Bg'
	sfx.busName = 'Sfx'
	master.sound.stream = sound
	bg.sound.stream = sound
	sfx.sound.stream = sound
	master.setVolume(UserData.masterVolume)
	bg.setVolume(UserData.musicVolume)
	sfx.setVolume(UserData.sfxVolume)
	#var language_index := language.get_item_text(0) == UserData.language ? 0 : 1
	#language.select(language_index)
	TranslationServer.set_locale(UserData.language)

func _on_master_value_changed(value: float):
	UserData.masterVolume = int(value)
	UserData.saveSettings()
	master.volume = value / 100
	master.playSound()

func _on_bg_value_changed(value: float):
	UserData.musicVolume = int(value)
	UserData.saveSettings()
	bg.volume = value / 100
	bg.playSound()

	
func _on_sfx_value_changed(value: float):
	UserData.sfxVolume = int(value)
	UserData.saveSettings()
	sfx.volume = value / 100
	sfx.playSound()


func _on_option_button_item_selected(index: int) -> void:
	UserData.language = language.get_item_text(index)
	UserData.saveSettings()
	TranslationServer.set_locale(UserData.language)


func _on_btn_close_pressed() -> void:
	close.emit()
