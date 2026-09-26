extends Area2D

class_name Aircraft
## 空中单位基类：约定不占用碰撞层（collision_layer / collision_mask 均为 0），
## 飞行与作战行为全部由子类实现（目前为 script/drone.gd 的无人机）。
