extends Area2D
class_name Tower

var hp=0  #防御塔血量
var radarScope=500 #雷达范围
var delay=0.1 #开火延迟
var target=[] #目标集合
var canShot=true
var selected=false #选中
var rotationSpeed=10
var money=0 #花费


@onready var rader=$radar
@onready var base=$base
@onready var turret=$turret
@onready var mouseArea=$mouseArea
@onready var delayTimer=$delay
@onready var marker=$turret/Marker2D
@onready var player=$player

func getTarget():
	var temp=null
	if target.size()==1:
		temp=target[0]
	elif target.size()>1:
		temp=target[0]
	
	return temp


func _on_delay_timeout():
	canShot=true
	


func _on_mouse_area_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.is_pressed()&& event.button_index==MouseButton.MOUSE_BUTTON_LEFT:
			selected=!selected
			queue_redraw()
		
			
func _draw():
	if selected:
		draw_circle(Vector2.ZERO,radarScope,Color(0.1,0.1,0.1,0.2))
	
