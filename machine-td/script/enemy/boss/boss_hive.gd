extends "res://script/enemy/boss/boss.gd"
## ② 巢母 `bossHive` —— 打"只盯单体"的人。
##
## 血厚、**不还手**，但每 6 秒在身后召唤 3 只该关最低级的敌人。
## 不先处理小兵就会被淹没；只顾清小兵又打不动本体。
##
## ⚠️ 本体死亡后必须停止召唤：`finish()` 的判据是"队列空 + 场上无敌人"，
##    如果死了还在召唤，最后一波永远结算不了。

const SPAWN_INTERVAL := 6.0
const SPAWN_COUNT := 3
## 召唤物落后本体的距离（像素）。26px 太近 —— 三只小坦克的贴图会互相压住，
## 看起来像"一坨"（玩家反馈）。改成 90px，队列才真的散开。
const SPAWN_BACK_STEP := 90.0
## 横向左右交替（PathFollow2D 的 v_offset）：让三只不在同一条直线上
const SPAWN_LATERAL := [-22.0, 0.0, 22.0]
## 同屏上限（与无尽模式对齐，§19.7 第 8 条）
const MAX_ON_SCREEN := 90

var spawnTimer: float = SPAWN_INTERVAL


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if dead:
		return
	spawnTimer -= delta
	if spawnTimer > 0.0:
		return
	spawnTimer = SPAWN_INTERVAL
	doSpawn()


func doSpawn() -> void:
	# 先查上限：差三只以内就跳过这一轮，而不是只补一部分
	if aliveEnemyCount() + SPAWN_COUNT > MAX_ON_SCREEN:
		return
	for i in SPAWN_COUNT:
		var lateral: float = SPAWN_LATERAL[i % SPAWN_LATERAL.size()]
		summonAt(Game.enemyType.miniTank, SPAWN_BACK_STEP * float(i + 1), 1.0, {}, lateral)
