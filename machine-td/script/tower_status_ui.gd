extends Node2D

@onready var hpBar = $VBoxContainer/hpBar
@onready var expBar = $VBoxContainer/expBar
@onready var hpLabel = $VBoxContainer/HpRow/hpLabel
@onready var expLabel = $VBoxContainer/ExpRow/expLabel

var max_hp: int = 100
var hp: int = 100
var currExp: int = 0
var exp_needed: int = 10
var selected: bool = false

func _ready() -> void:
	refresh()
	visible = false

func refresh() -> void:
	if hpBar:
		hpBar.max_value = max(1, max_hp)
		hpBar.value = clamp(hp, 0, hpBar.max_value)
	if expBar:
		expBar.max_value = max(1, exp_needed)
		expBar.value = clamp(currExp, 0, expBar.max_value)
	if hpLabel:
		hpLabel.text = "%d/%d" % [max(0, hp), max(1, max_hp)]
	if expLabel:
		if exp_needed <= 0:
			expLabel.text = "MAX"
		else:
			expLabel.text = "%d/%d" % [currExp, exp_needed]
	visible = selected

func set_status(_hp: int, _max_hp: int, _currExp: int, _exp_needed: int, _selected: bool = false) -> void:
	hp = _hp
	max_hp = max(1, _max_hp)
	currExp = _currExp
	exp_needed = max(1, _exp_needed)
	selected = _selected
	refresh()

func show_status() -> void:
	selected = true
	refresh()

func hide_status() -> void:
	selected = false
	refresh()
