extends PanelContainer

@export var level=1:   #关卡名字
	set(val):
		level=val
		num.text=str(level)
		
@export var rating=0  #评分
@export var description=''  #关卡描述


@onready var num=$VBoxContainer/num
