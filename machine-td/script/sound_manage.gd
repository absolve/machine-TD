extends Node2D

@onready var button_sound: AudioStreamPlayer = $ButtonSound



func playEffect() -> void:
	if UserData.sfxMuted or not button_sound.stream:
		return
	button_sound.play()
