class_name EffectAssets
extends RefCounted
## 特效素材统一入口（替换素材只改这里）
##
## 目前统一使用 res://sprite/game_226.png 作为特效贴图。
## 以后要换素材时，只改下面两个常量指向的路径即可，所有子弹命中和激光粒子效果会一起生效。
## 注意：新素材需要先让 Godot 编辑器导入一次（生成同名 .import）后才能被加载。

# 子弹命中反馈贴图
const HIT_EFFECT_TEXTURE_PATH := "res://sprite/game_226.png"
# 激光塔开火粒子贴图
const LASER_PARTICLE_TEXTURE_PATH := "res://sprite/game_226.png"

# 贴图缓存：避免每次特效都重新 load 资源
static var _hit_texture: Texture2D = null
static var _laser_texture: Texture2D = null
# 已经提示过缺失的路径，避免刷屏
static var _warned_paths: Dictionary = {}


# 取子弹命中特效贴图；素材不可用时返回 null（调用方直接跳过特效）
static func get_hit_texture() -> Texture2D:
	if _hit_texture == null:
		_hit_texture = _load_texture(HIT_EFFECT_TEXTURE_PATH)
	return _hit_texture


# 取激光开火粒子贴图；素材不可用时返回 null（调用方直接跳过特效）
static func get_laser_particle_texture() -> Texture2D:
	if _laser_texture == null:
		_laser_texture = _load_texture(LASER_PARTICLE_TEXTURE_PATH)
	return _laser_texture


static func _load_texture(path: String) -> Texture2D:
	var res: Resource = null
	if ResourceLoader.exists(path):
		res = load(path)
	if res is Texture2D:
		return res
	if not _warned_paths.has(path):
		_warned_paths[path] = true
		push_warning("特效素材无法加载，请确认已在 Godot 编辑器中导入: " + path)
	return null
