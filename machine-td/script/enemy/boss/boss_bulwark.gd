extends "res://script/enemy/boss/boss.gd"
## ① 铁壁 `bossBulwark` —— 打"只会堆物理伤害"的人。
##
## 它**没有任何专属行为**：全部特点都在 enemyInfo 的 `armor = 0.7` 上。
## 物理伤害被砍 70%，能量伤害（特斯拉电弧 / 加农炮「破甲弹」）打满额。
## 保持无行为是刻意的 —— 第一个遇到的 boss 应该先教"伤害类型"这件事，
## 而不是一上来就叠加一堆机制。

func _ready() -> void:
	super._ready()
