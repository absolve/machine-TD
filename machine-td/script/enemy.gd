extends Area2D

var hp=100 #血量
var speed  #移动速度
var vec=Vector2.ZERO
var target=[] #目标
var points=[]
var pointIndex=0

@onready var base=$base
@onready var turret=$turret


func hurt(_num):
	pass
