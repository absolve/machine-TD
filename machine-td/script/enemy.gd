extends Area2D

class_name Enemy

@export var hp = 100 # 血量
@export var speed: int # 移动速度
@export var reward = 0 # 奖励
@export var lossPoints = 1 # 损失点数
@export var rewardExp = 2 # 经验值

var vec = Vector2.ZERO
var target = [] # 目标
var points = [] # 路径点
var pointIndex = 0
var dead = false # 是否死亡
var rotationSpeed = 10


@onready var base = $base
@onready var turret = $turret
@onready var lifeBar = $lifeBar

func hurt(_num: int, _source = null):
	hp -= _num
	lifeBar.value = hp
	if hp <= 0:
		ExplosionManage.playExplosion(global_position)
		Game.defeatEnemy.emit(reward)
		owner.queue_free()
		if _source !=null && _source is Tower:
			_source.addExp(rewardExp)

func fire(_t):
	pass
