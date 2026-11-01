extends "res://script/enemy/boss/boss.gd"
## ⑤ 压制者 `bossJammer` —— 打"把塔堆在一处"的人。
##
## 光环半径 260：每 5 秒让范围内所有防御塔**沉默 2 秒**（不能开火）。
## 它不造成任何伤害 —— 压力完全来自"你的输出被停了两秒"。
##
## 实现只依赖 `tower.applySilence()`（`tower.gd` 里用 `canShot` 做闸），
## 所以 9 个塔脚本一行都不用改。

const AURA_RADIUS := 260.0
const SILENCE_INTERVAL := 5.0
const SILENCE_SECONDS := 2.0

var silenceTimer: float = SILENCE_INTERVAL
## 上一次压制命中的塔数（给自绘/调试看）
var lastJammed: int = 0


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if dead:
		return
	silenceTimer -= delta
	if silenceTimer > 0.0:
		return
	silenceTimer = SILENCE_INTERVAL
	jam()


func jam() -> void:
	lastJammed = 0
	for node in get_tree().get_nodes_in_group("tower"):
		if not (node is Tower) or not is_instance_valid(node):
			continue
		if global_position.distance_to(node.global_position) > AURA_RADIUS:
			continue
		node.applySilence(SILENCE_SECONDS)
		lastJammed += 1
