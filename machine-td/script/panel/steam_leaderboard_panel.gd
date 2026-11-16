extends Control

signal closed

@onready var localBestRow: PanelContainer = $PanelContainer/VBox/Table/LocalBestRow
@onready var bestWaveLabel: Label = $PanelContainer/VBox/Table/LocalBestRow/Columns/Wave
@onready var statusLabel: Label = $PanelContainer/VBox/Status


func _ready() -> void:
	visible = false


func open() -> void:
	var bestWave: int = UserData.endlessBestWave
	localBestRow.visible = bestWave > 0
	bestWaveLabel.text = str(bestWave) if bestWave > 0 else "—"
	statusLabel.text = Game.t(
		"_LeaderboardUnavailable",
		"Steam leaderboard is not connected yet."
	)
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()
