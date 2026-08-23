extends PanelContainer


@onready var towerNameNode = $MarginContainer/vbox/towerName
@onready var atkLabelNode = $MarginContainer/vbox/hbox/hbox1/atkLabel
@onready var costLabelNode = $MarginContainer/vbox/hbox/hbox2/costLabel
@onready var reloadLabelNode = $MarginContainer/vbox/hbox/hbox3/reloadLabel
@onready var scopeLabelNode = $MarginContainer/vbox/hbox/hbox4/scopeLabel
@onready var towerDetailNode = $MarginContainer/vbox/MarginContainer/towerDetail

var towerName: String:
	set(value):
		towerNameNode.text = value
var towerDetail: String:
	set(value):
		towerDetailNode.text = value
var atkLabel: String:
	set(value):
		atkLabelNode.text = value
var costLabel: String:
	set(value):
		costLabelNode.text = value
var reloadLabel: String:
	set(value):
		reloadLabelNode.text = value
var scopeLabel: String:
	set(value):
		scopeLabelNode.text = value

func showDetail(obj):
	towerName = str(obj.name)
	towerDetail = tr(obj.desc)
	costLabel = str(obj.cost)
	reloadLabel = str(obj.cost)
	atkLabel = str(obj.atk)
	scopeLabel = str(obj.scope)
	visible = true
	
func hideDetail():
	visible = false
