class_name EffectAssets
extends RefCounted
## 特效素材统一入口（替换素材只改这里）
##
## 素材全部在 res://sprite/fx/ 下，分两类：
##   粒子纹理（fx_*.png）—— 正方形软边，给 GPUParticles2D / CPUParticles2D 当贴图
##   帧动画（hit_*.png / boom_*.png）—— 直接进 AnimatedSprite2D 的 SpriteFrames
## 要换素材只改下面的常量路径。
## 注意：新素材需要先让 Godot 编辑器导入一次（生成同名 .import）后才能被加载。

# ---------- 粒子纹理 ----------
# 子弹命中反馈贴图（火花）
const HIT_EFFECT_TEXTURE_PATH := "res://sprite/fx/fx_spark.png"
# 激光塔开火粒子贴图
const LASER_PARTICLE_TEXTURE_PATH := "res://sprite/fx/fx_spark.png"
# 爆炸烟雾
const SMOKE_TEXTURE_PATH := "res://sprite/fx/fx_smoke.png"
# 爆炸火星
const EMBER_TEXTURE_PATH := "res://sprite/fx/fx_ember.png"
# 冲击波环
const SHOCKWAVE_TEXTURE_PATH := "res://sprite/fx/fx_shockwave.png"

# ---------- 帧动画（整段 SpriteFrames 用）----------
const HIT_FRAMES_DIR := "res://sprite/fx/"
const BOOM_FRAMES_DIR := "res://sprite/fx/"

# 贴图缓存：避免每次特效都重新 load 资源
static var _hit_texture: Texture2D = null
static var _laser_texture: Texture2D = null
static var _smoke_texture: Texture2D = null
static var _ember_texture: Texture2D = null
static var _shockwave_texture: Texture2D = null
# 帧动画缓存：每个路径只建一次 SpriteFrames
static var _frames_cache: Dictionary = {}
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


# 取烟雾粒子贴图
static func get_smoke_texture() -> Texture2D:
	if _smoke_texture == null:
		_smoke_texture = _load_texture(SMOKE_TEXTURE_PATH)
	return _smoke_texture


# 取火星粒子贴图
static func get_ember_texture() -> Texture2D:
	if _ember_texture == null:
		_ember_texture = _load_texture(EMBER_TEXTURE_PATH)
	return _ember_texture


# 取冲击波环贴图
static func get_shockwave_texture() -> Texture2D:
	if _shockwave_texture == null:
		_shockwave_texture = _load_texture(SHOCKWAVE_TEXTURE_PATH)
	return _shockwave_texture


# 取一组帧动画，组装成 SpriteFrames 直接给 AnimatedSprite2D 用。
#   kind  = "hit"（命中闪光，4 帧）或 "boom"（爆炸火球，6 帧）
#   count = 帧数（文件是 <kind>_1.png ... <kind>_N.png）
#   fps   = 播放速度
# 结果按 kind/count/fps 缓存，同一种特效不会反复重建资源。
static func get_frames(kind: String, count: int, fps: float) -> SpriteFrames:
	var key := "%s_%d_%.1f" % [kind, count, fps]
	if _frames_cache.has(key):
		return _frames_cache[key]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("default")
	sf.set_animation_loop("default", false)
	sf.set_animation_speed("default", fps)
	for i in range(1, count + 1):
		var tex := _load_texture(BOOM_FRAMES_DIR + "%s_%d.png" % [kind, i])
		if tex != null:
			sf.add_frame("default", tex)
	_frames_cache[key] = sf
	return sf


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
