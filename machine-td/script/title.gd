extends Control


@onready var waveLabel=$PanelContainer/hbox/hbox1/waveLabel
@onready var hpLabel=$PanelContainer/hbox/hbox2/hpLabel
@onready var moneyLabel=$PanelContainer/hbox/hbox3/moneyLabel
@onready var scoreLabel=$PanelContainer/hbox/hbox4/scoreLabel


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
