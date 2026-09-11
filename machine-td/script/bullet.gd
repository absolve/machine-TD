extends Area2D

const HIT_EFFECT_SCENE := preload("res://scene/bullet_hit_effect.tscn")

var vec = Vector2.ZERO # 速度
var target = null # 目标
var timer = 0
var lifetime = 0 # 存活时间
var angle = 0 # 角度
var damage = 0 # 伤害
var speed = 0 # 速度
var source_tower: Tower = null

@onready var aniNode = $ani


# 命中反馈：在当前位置播放一次性命中特效（贴图见 EffectAssets，替换素材只改那里）
func spawn_hit_effect() -> void:
	if not is_inside_tree():
		return
	var effect := HIT_EFFECT_SCENE.instantiate()
	if vec != Vector2.ZERO:
		effect.rotation = vec.angle()
	Game.addObj(effect)
	# 加入场景树后再设置全局坐标，避免父节点偏移导致位置错误
	effect.global_position = global_position
