extends Area2D

class_name Aircraft

@export var hp = 100 # 血量
@export var speed: int # 移动速度

var vec = Vector2.ZERO
var dead = false # 是否死亡
var target = [] # 目标

@onready var radar = $radar
