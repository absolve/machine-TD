extends Node2D


var hp  #防御塔血量
var radarScope=50 #雷达范围
var delay=0.1 #开火延迟
var target=[] #目标集合
var canShot=true

@onready var rader=$radar
@onready var base=$base
@onready var turret=$turret
@onready var mouseArea=$mouseArea
@onready var delayTimer=$delay
@onready var marker=$turret/Marker2D

func getTarget():
	var temp=null
	if target.size()==1:
		temp=target[0]
	elif target.size()>1:
		temp=target[0]
	
	return temp


func _on_delay_timeout():
	canShot=true
	
