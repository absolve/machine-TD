extends Area2D

const HIT_EFFECT_SCENE := preload("res://scene/explosion/bullet_hit_effect.tscn")
## 命中时迸溅的火星（独立场景，俯视角做法：无重力、从命中点径向飞散）
const SPARK_BURST_SCENE := preload("res://scene/fx/spark_burst.tscn")

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

	# 再迸一小撮火星。挂在关卡子弹基类上，所以机枪/加农/火箭/敌方子弹
	# 五种子弹（都走 spawn_hit_effect）自动全都有。
	var sparks := SPARK_BURST_SCENE.instantiate()
	if vec != Vector2.ZERO:
		# 传飞行方向过去，火星会略微顺着被打飞的方向偏，有冲劲
		sparks.rotation = vec.angle()
	Game.addObj(sparks)
	sparks.global_position = global_position
