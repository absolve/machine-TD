extends Node2D

@onready var hpBar = $VBoxContainer/hpBar
@onready var expBar = $VBoxContainer/expBar
@onready var nameLabel = $VBoxContainer/nameLabel
@onready var hpLabel = $VBoxContainer/HpRow/hpLabel
@onready var expLabel = $VBoxContainer/ExpRow/expLabel

var maxHp: int = 100
var hp: int = 100
var currExp: int = 0
var expNeeded: int = 10
var selected: bool = false
var towerName: String = "Tower"

func _ready() -> void:
	refresh()
	visible = false

func refresh() -> void:
	if nameLabel:
		nameLabel.text = towerName
	if hpBar:
		hpBar.max_value = max(1, maxHp)
		hpBar.value = clamp(hp, 0, hpBar.max_value)
	if expBar:
		expBar.max_value = max(1, expNeeded)
		expBar.value = clamp(currExp, 0, expBar.max_value)
	if hpLabel:
		hpLabel.text = "%d/%d" % [max(0, hp), max(1, maxHp)]
	if expLabel:
		if expNeeded <= 0:
			expLabel.text = "MAX"
		else:
			expLabel.text = "%d/%d" % [currExp, expNeeded]
	visible = selected

func setStatus(_hp: int, _max_hp: int, _currExp: int, _exp_needed: int, selected: bool = false, _tower_name: String = "Tower") -> void:
	hp = _hp
	maxHp = max(1, _max_hp)
	currExp = _currExp
	expNeeded = max(1, _exp_needed)
	selected = selected
	towerName = _tower_name
	refresh()

func showStatus() -> void:
	selected = true
	refresh()

func hideStatus() -> void:
	selected = false
	refresh()
