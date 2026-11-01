extends "res://script/enemy/boss/boss.gd"
## ③ 突袭者 `bossCharger` —— 打"塔摆得太稀"的人。
##
## 移速 90（普通敌人基准 50 的 1.8 倍）、血薄、**不还击**，纯粹冲线。
## 它是唯一依赖 EMP 减速的 boss —— 所以**刻意不免疫减速**（§19.7 第 1 条）。
## 数值全在 enemyInfo，没有专属行为。

func _ready() -> void:
	super._ready()
