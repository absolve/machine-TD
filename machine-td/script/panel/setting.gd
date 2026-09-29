extends Control
## 设置面板。已从 Window 改为普通 Control，否则嵌入式子窗口会盖在场景切换遮罩之上。

var sound = preload("res://sound/Pickup.wav")


@onready var master = $Box/VBoxContainer/volumeBox/VBoxContainer/master
@onready var bg = $Box/VBoxContainer/volumeBox/VBoxContainer/bg
@onready var sfx = $Box/VBoxContainer/volumeBox/VBoxContainer/sfx
@onready var language = $Box/VBoxContainer/languageBox/HBoxContainer/language

signal closed


func _ready() -> void:
	language.clear()
	var selectedIndex = 0
	var currentLanguageCode = getLanguageCode(UserData.language)
	for language_info in Game.language:
		var languageCode: String = language_info.get('code', 'en')
		language.add_item(language_info.get('text', languageCode))
		language.set_item_metadata(language.item_count - 1, languageCode)
		if languageCode == currentLanguageCode:
			selectedIndex = language.item_count - 1
	language.select(selectedIndex)
	UserData.language = currentLanguageCode
	master.busName = 'Master'
	bg.busName = 'Bg'
	sfx.busName = 'Sfx'
	master.sound.stream = sound
	bg.sound.stream = sound
	sfx.sound.stream = sound
	master.setVolume(UserData.masterVolume)
	bg.setVolume(UserData.musicVolume)
	sfx.setVolume(UserData.sfxVolume)
	master.slider.value_changed.connect(_onMasterValueChanged)
	bg.slider.value_changed.connect(_onBgValueChanged)
	sfx.slider.value_changed.connect(_onSfxValueChanged)
	# 背景音/音效显示静音开关，并同步上次保存的静音状态
	bg.muted = UserData.musicMuted
	sfx.muted = UserData.sfxMuted
	bg.muteToggled.connect(_onBgMuteToggled)
	sfx.muteToggled.connect(_onSfxMuteToggled)
	TranslationServer.set_locale(UserData.language)

func getLanguageCode(language_value: String) -> String:
	for language_info in Game.language:
		if language_value == language_info.get('code', '') or language_value == language_info.get('text', ''):
			return language_info.get('code', 'en')
	return Game.language[0].get('code', 'en') if not Game.language.is_empty() else 'en'

func _onMasterValueChanged(value: float):
	UserData.masterVolume = int(value)
	UserData.saveSettings()
	master.volume = value / 100
	master.playSound()

func _onBgValueChanged(value: float):
	UserData.musicVolume = int(value)
	UserData.saveSettings()
	bg.volume = value / 100
	bg.playSound()

	
func _onSfxValueChanged(value: float):
	UserData.sfxVolume = int(value)
	UserData.saveSettings()
	sfx.volume = value / 100
	sfx.playSound()


func _onOptionButtonItemSelected(index: int) -> void:
	UserData.language = str(language.get_item_metadata(index))
	UserData.saveSettings()
	UserData.applyLanguage()


func _onBgMuteToggled(muted: bool) -> void:
	UserData.musicMuted = muted
	UserData.saveSettings()


func _onSfxMuteToggled(muted: bool) -> void:
	UserData.sfxMuted = muted
	UserData.saveSettings()


func _onBtnClosePressed() -> void:
	closed.emit()
