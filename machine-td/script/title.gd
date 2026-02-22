extends Control


@onready var waveLabel=$PanelContainer/hbox/hbox1/waveLabel
@onready var hpLabel=$PanelContainer/hbox/hbox2/hpLabel
@onready var moneyLabel=$PanelContainer/hbox/hbox3/moneyLabel
@onready var scoreLabel=$PanelContainer/hbox/hbox4/scoreLabel
@onready var speedLabel=$PanelContainer/hbox/HBoxContainer3/hbox/HBoxContainer/speedLabel
@onready var btnSpeed=$PanelContainer/hbox/HBoxContainer3/hbox/HBoxContainer/btnSpeed
@onready var btnStart= $PanelContainer/hbox/HBoxContainer3/btnStart
@onready var btnSound=$PanelContainer/hbox/HBoxContainer3/btnSound
@onready var btnMusic=$PanelContainer/hbox/HBoxContainer3/btnMusic
@onready var btnHome=$PanelContainer/hbox/HBoxContainer3/btnHome


signal start
signal pause
signal soundOn
signal soundOff
signal musicOn
signal musicOff
signal speedOn
signal speedOff
signal home

var hp=0:
	set(value):
		hp=max(value,0)
		hpLabel.text=str(value)
		
var wave=1:
	set(value):
		wave=value
		waveLabel.text=str(value)
		
var money=0:
	set(value):
		money=value
		moneyLabel.text=str(value)
		
var score=0:
	set(value):
		score=value
		scoreLabel.text=str(value)


func _on_texture_button_toggled(toggled_on: bool) -> void:
	print(toggled_on)
	if toggled_on:
		start.emit()
	else:
		pause.emit()	


func _on_btn_speed_toggled(toggled_on: bool) -> void:
	if toggled_on:
		speedOn.emit()
		speedLabel.text=str("2X")
	else:
		speedOff.emit()
		speedLabel.text=str("1X")


func _on_btn_sound_toggled(toggled_on: bool) -> void:
	if toggled_on:
		soundOff.emit()
	else:
		soundOn.emit()

func _on_btn_music_toggled(toggled_on: bool) -> void:
	if toggled_on:
		musicOff.emit()
	else:
		musicOn.emit()


func _on_btn_home_pressed() -> void:
	home.emit()
