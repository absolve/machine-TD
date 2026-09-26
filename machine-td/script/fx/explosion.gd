extends AnimatedSprite2D
## 爆炸动画（**基场景**脚本）。
##
## 帧序列完全由场景里的 sprite_frames 决定 —— 这里不 load 任何贴图。
## 想做一种新爆炸：新建继承自 scene/explosion/explosion.tscn 的场景，
## 在检查器里换掉 sprite_frames（帧图）、调一下 anim_scale，就完事了。
##
## 注意：粒子和音效**不在这个场景里**，它们分别是
##   scene/fx/explosion_particles.tscn （粒子，同样有基场景可继承）
##   SoundManage                        （音效，统一管理）

## 整体缩放。派生场景里按需覆盖。
@export var anim_scale := 1.5
## 播完自动销毁
@export var auto_free := true


func _ready() -> void:
	z_index = 10
	scale = Vector2.ONE * anim_scale
	play("default")
	if auto_free:
		await animation_finished
		queue_free()
