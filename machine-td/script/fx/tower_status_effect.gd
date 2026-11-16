extends Node2D
## 防御塔特效基场景：动画与粒子放在独立容器中，脚本只管理播放和生命周期。

@export var duration: float = 1.2
@export var autoFree: bool = true

@onready var animationPlayer: AnimationPlayer = $AnimationPlayer
@onready var particles: Node2D = $Particles


func _ready() -> void:
	var effectDuration: float = maxf(duration, 0.0)
	if animationPlayer.has_animation("effect"):
		animationPlayer.play("effect")
		effectDuration = maxf(effectDuration, animationPlayer.get_animation("effect").length)

	var longestParticleLifetime: float = 0.0
	for emitter in particles.find_children("*", "CPUParticles2D", true, false):
		emitter.restart()
		emitter.emitting = true
		longestParticleLifetime = maxf(
			longestParticleLifetime,
			emitter.lifetime * (1.0 + emitter.lifetime_randomness)
		)
	for emitter in particles.find_children("*", "GPUParticles2D", true, false):
		emitter.restart()
		emitter.emitting = true
		longestParticleLifetime = maxf(
			longestParticleLifetime,
			emitter.lifetime * (1.0 + emitter.lifetime_randomness)
		)

	if autoFree:
		await get_tree().create_timer(effectDuration).timeout
		for emitter in particles.find_children("*", "CPUParticles2D", true, false):
			emitter.emitting = false
		for emitter in particles.find_children("*", "GPUParticles2D", true, false):
			emitter.emitting = false
		await get_tree().create_timer(longestParticleLifetime).timeout
		queue_free()
