extends Control

@export var maxProgress: float = 100.0
@export var currentProgress: float = 50
@export var currentWave: int = 1

@onready var progressBar: ProgressBar = $ProgressBar
@onready var glowOverlay: ColorRect = $ProgressBar/GlowOverlay

func _ready() -> void:
	progressBar.max_value = maxProgress
	progressBar.value = currentProgress
	_update_glow()

func _process(_delta: float) -> void:
	if progressBar.value > 0.0:
		var width_ratio: float = clamp(progressBar.value / maxProgress, 0.0, 1.0)
		var glow_front: float = progressBar.size.x * width_ratio
		glowOverlay.visible = true
		glowOverlay.position = Vector2(glow_front - 12.0, 0)
		glowOverlay.size = Vector2(34.0, progressBar.size.y)
		glowOverlay.modulate = Color(1.0, 1.0, 1.0, 0.3 + 0.5 * sin(Time.get_ticks_msec() * 0.009))
	else:
		glowOverlay.visible = false

func _update_glow() -> void:
	progressBar.max_value = maxProgress
	progressBar.value = clamp(currentProgress, 0.0, maxProgress)
	if progressBar.value <= 0.0:
		glowOverlay.visible = false
		return
	var width_ratio: float = clamp(progressBar.value / maxProgress, 0.0, 1.0)
	var glow_front: float = progressBar.size.x * width_ratio
	glowOverlay.visible = true
	glowOverlay.position = Vector2(glow_front - 12.0, 0)
	glowOverlay.size = Vector2(34.0, progressBar.size.y)

func set_progress(value: float) -> void:
	currentProgress = clamp(value, 0.0, maxProgress)
	progressBar.value = currentProgress
	_update_glow()
