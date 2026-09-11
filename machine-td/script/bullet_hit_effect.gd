extends Node2D
## 子弹命中反馈特效：在命中位置播放一次，放大并淡出后自动销毁。
## 贴图来自 EffectAssets（当前使用 sprite/game_226.png），便于后续统一替换素材。

const FADE_TIME := 0.18 # 播放时长
const START_SCALE := 0.8 # 起始缩放
const END_SCALE := 1.9 # 结束缩放
const RANDOM_TINT := 0.18 # 亮度随机浮动范围，让连续命中不呆板

@onready var sprite: Sprite2D = $sprite


func _ready() -> void:
	var texture := EffectAssets.get_hit_texture()
	if texture == null:
		# 素材尚未导入时不报错，直接跳过特效
		queue_free()
		return

	sprite.texture = texture
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

	var brightness := 1.0 - randf() * RANDOM_TINT
	sprite.modulate = Color(brightness, brightness, brightness, 1.0)
	scale = Vector2.ONE * START_SCALE
	rotation = randf_range(0.0, TAU)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE * END_SCALE, FADE_TIME)
	tween.tween_property(sprite, "modulate:a", 0.0, FADE_TIME)
	# 三个并行动画结束后再销毁节点
	tween.chain().tween_callback(queue_free)
