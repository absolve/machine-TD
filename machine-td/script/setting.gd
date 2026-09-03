extends Window

var sound = preload("res://sound/Pickup.wav")


@onready var master = $box/VBoxContainer/volumeBox/VBoxContainer/master
@onready var bg = $box/VBoxContainer/volumeBox/VBoxContainer/bg
@onready var sfx = $box/VBoxContainer/volumeBox/VBoxContainer/sfx
@onready var language = $box/VBoxContainer/languageBox/HBoxContainer/language

signal close


func _ready() -> void:
	language.clear()
	var selected_index = 0
	var current_language_code = getLanguageCode(UserData.language)
	for language_info in Game.language:
		var language_code: String = language_info.get('code', 'en')
		language.add_item(language_info.get('text', language_code))
		language.set_item_metadata(language.item_count - 1, language_code)
		if language_code == current_language_code:
			selected_index = language.item_count - 1
	language.select(selected_index)
	UserData.language = current_language_code
	master.busName = 'Master'
	bg.busName = 'Bg'
	sfx.busName = 'Sfx'
	master.sound.stream = sound
	bg.sound.stream = sound
	sfx.sound.stream = sound
	master.setVolume(UserData.masterVolume)
	bg.setVolume(UserData.musicVolume)
	sfx.setVolume(UserData.sfxVolume)
	TranslationServer.set_locale(UserData.language)

func getLanguageCode(language_value: String) -> String:
	for language_info in Game.language:
		if language_value == language_info.get('code', '') or language_value == language_info.get('text', ''):
			return language_info.get('code', 'en')
	return Game.language[0].get('code', 'en') if not Game.language.is_empty() else 'en'

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
	UserData.language = str(language.get_item_metadata(index))
	UserData.saveSettings()
	TranslationServer.set_locale(UserData.language)


func _on_btn_close_pressed() -> void:
	close.emit()
