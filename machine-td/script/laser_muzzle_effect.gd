extends Node2D
## 激光塔开火粒子特效：每次发射在炮口/命中点播放一次火花，播完自动销毁。
## 贴图来自 EffectAssets（当前使用 sprite/game_226.png），便于后续统一替换素材。

const EXTRA_LIFETIME := 0.15 # 粒子寿命之外额外等待，确保播完再销毁

@onready var particles: CPUParticles2D = $particles


func _ready() -> void:
	var texture := EffectAssets.get_laser_particle_texture()
	if texture == null:
		# 素材尚未导入时不报错，直接跳过特效
		queue_free()
		return

	particles.texture = texture
	particles.emitting = true

	# 用 SceneTreeTimer 而不是 Tween：即使游戏暂停也能正常回收节点
	await get_tree().create_timer(particles.lifetime + EXTRA_LIFETIME).timeout
	queue_free()
