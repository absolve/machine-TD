extends PanelContainer


@onready var towerNameNode=$vbox/towerName
@onready var atkLabelNode=$vbox/hbox/hbox1/atkLabel
@onready var costLabelNode=$vbox/hbox/hbox2/costLabel
@onready var reloadLabelNode=$vbox/hbox/hbox3/reloadLabel
@onready var scopeLabelNode=$vbox/hbox/hbox4/scopeLabel
@onready var towerDetailNode=$vbox/towerDetail

var towerName:String:
	set(value):
		towerNameNode.text=value
var towerDetail:String:
	set(value):
		towerDetailNode.text=value
var atkLabel:String:
	set(value):
		atkLabelNode.text=value
var costLabel:String:
	set(value):
		costLabelNode.text=value
var reloadLabel:String:
	set(value):
		reloadLabelNode.text=value
var scopeLabel:String:
	set(value):
		scopeLabelNode.text=value

func showDetail(obj):
	towerName=str(obj.name)
	towerDetail=str(obj.desc)
	costLabel=str(obj.cost)
	reloadLabel=str(obj.cost)
	atkLabel=str(obj.atk)
	
	visible=true
	
func hideDetail():
	visible=false	
	
