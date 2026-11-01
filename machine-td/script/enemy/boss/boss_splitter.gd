extends "res://script/enemy/boss/boss.gd"
## ④ 分裂体 `bossSplitter` —— 打"只在最后补一刀"的人。
##
## 死亡时分裂成 2 个各 40% 血的小号。**只分裂一层**：
## 小号通过 `props = {"canSplit": false}` 生成，否则会无限分裂。
##
## 让"击杀时机"变成决策：在基地门口才打死本体，等于把两个小号直接送到门口。

const SPLIT_COUNT := 2
const SPLIT_HP_RATIO := 0.4
const SPLIT_BACK_STEP := 40.0

## 是否还能分裂（小号会被 spawnEnemy 的 props 设成 false）
var canSplit: bool = true
var splitDone: bool = false


func hurt(_num: int, _source = null, _damage_type: String = "physical") -> void:
	super.hurt(_num, _source, _damage_type)
	# super 会把 dead 置 true 并排队释放；本帧内节点仍有效，
	# 所以分裂必须在这里做，不能等到 _exit_tree()（逃脱也会走那条路）。
	if dead and canSplit and not splitDone:
		splitDone = true
		doSplit()


func doSplit() -> void:
	for i in SPLIT_COUNT:
		summonAt(Game.enemyType.bossSplitter, SPLIT_BACK_STEP * float(i + 1),
			SPLIT_HP_RATIO, {"canSplit": false, "silentBoss": true})
