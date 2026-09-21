extends Node2D
## 全局音频（Autoload 场景，见 project.godot 的 SoundManage）。
##
## 三块功能：
##   ① UI 点击音  —— playEffect() / playConfirm()。**只由按钮预制体自己调**（见下面的约定）。
##   ② 通用音效    —— play("hit_metal") 按名字播 sound/sfx/ 下的文件。
##   ③ 循环音      —— start_loop("tesla", "tower_tesla_hum") / stop_loop("tesla")。
##
## 用法：
##   SoundManage.play("hit_metal")                          # 最简
##   SoundManage.play("explode_small", -6.0)                # 第二个参数是音量(dB)
##   SoundManage.play("tower_mg_fire", 0.0, randf_range(0.96, 1.04))   # 第三个是音高
##   SoundManage.play_varied(["hit_hard", "hit_armor"])     # 从几个里随机挑，带轻微音高抖动
##   SoundManage.play_at("explode_large", global_position)  # 按世界坐标摆左右声像
##
## 名字就是 sound/sfx/ 下的文件名（不带 .ogg）。加新音效直接把 ogg 丢进去就能用，
## 这里一行都不用改。
##
## 通用音效内部用**播放器池**：同时响十几个不会互相打断，也不会每次 new 一个节点。
##
## 约定：**UI 按钮的点击音只由 ui_button.gd 播一次**，
## 场景脚本不要再为同一个按钮补一遍 —— 那就会听到两声。详见 sound/CREDITS.md。

## 真正播出去时发出，参数是 "effect" / "confirm"。
## 用来排查"点一下响几声"这类问题：接上数一下就知道。
signal played(kind: String)

## 去重窗口（秒）。同一窗口内两条通道合计只放行一次。
## 取 30ms：真人双击间隔远大于它，但同帧 / 相邻帧的重复请求会被吃掉。
const DEDUPE_WINDOW := 0.03

## 通用音效所在目录（用文件名当 key）
const SFX_DIR := "res://sound/sfx/"

## 调试开关：为 true 时每次播音都把调用栈打到控制台。
## 默认跟随 OS.is_debug_build()（编辑器里 F5 跑就是开的，导出版自动关闭）。
## 排查「一次点击响两声」时看控制台：哪两条栈都触发了，就是它们。
#@export var trace_plays: bool = false

## 音效播放器池上限。池子满了就临时再加一个（很少发生）
@export var sfx_pool_size: int = 16
## play_at 用的 2D 播放器池上限
@export var pos_pool_size: int = 8

## 悬停音的节流（毫秒）。鼠标扫过一排按钮时会连续触发 mouse_entered，
## 取 60ms 让它是"清脆的一下"，而不是哒哒哒响成一片。
const HOVER_GUARD_MSEC := 60

@onready var button_sound: AudioStreamPlayer = $ButtonSound
@onready var confirm_sound: AudioStreamPlayer = $ConfirmSound
@onready var hover_sound: AudioStreamPlayer = $HoverSound

var _last_play_msec: int = -100000
## 悬停音单独计时。
## ⚠️ 不能和 _last_play_msec 共用 —— 那样"鼠标 hover 完立刻点击"会把点击吃掉。
var _last_hover_msec: int = -100000

## 通用音效的播放器池
var _sfx_pool: Array[AudioStreamPlayer] = []
## play_at 用的 2D 播放器池
var _pos_pool: Array[AudioStreamPlayer2D] = []
## 名字 -> AudioStream；查不到也缓存（存 null），避免每次都去 exists()
var _sfx_cache: Dictionary = {}
## 循环音：key -> 播放器
var _loops: Dictionary = {}


# ============================================================
# ① UI 点击音
# ============================================================

func playEffect() -> void:
	_play(button_sound, "effect")


func playConfirm() -> void:
	_play(confirm_sound, "confirm")


## 鼠标移上按钮的音（sfx/ui_hover.ogg）。
## 比点击音轻，所以不走去重闸、也不打调用栈 —— 但有自己的节流。
func playHover() -> void:
	if UserData.sfxMuted or hover_sound.stream == null:
		return
	var now := Time.get_ticks_msec()
	if now - _last_hover_msec < HOVER_GUARD_MSEC:
		return
	_last_hover_msec = now
	hover_sound.play()


func _play(player: AudioStreamPlayer, kind: String) -> void:
	if UserData.sfxMuted or player.stream == null:
		return
	var now := Time.get_ticks_msec()
	if now - _last_play_msec < int(DEDUPE_WINDOW * 1000.0):
		return
	_last_play_msec = now
	player.play()
	played.emit(kind)
	#if trace_plays or OS.is_debug_build():
		#_trace(kind)


# 把调用栈打出来（跳过本文件自己的帧），一眼看出是谁播的
#func _trace(kind: String) -> void:
	#var lines := PackedStringArray()
	#lines.append("[SoundManage] play " + kind)
	#for f in get_stack():
		#var src: String = str(f.get("source", ""))
		#if src.ends_with("sound_manage.gd"):
			#continue
		#lines.append("    %s:%s  %s()" % [src.get_file(), str(f.get("line", 0)), str(f.get("function", ""))])
	#print("\n".join(lines))


# ============================================================
# ② 通用音效（按名字播 sound/sfx/ 下的文件）
# ============================================================

## 播一个音效。sound 是文件名（不带扩展名），volume_db 是音量，pitch_scale 是音高。
## 返回正在播的播放器（方便调用方自己停），静音 / 找不到文件时返回 null。
func play(sound: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer:
	if UserData.sfxMuted:
		return null
	var stream := _get_sfx(sound)
	if stream == null:
		return null
	var p := _acquire()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch_scale
	p.play()
	return p


## 从几个音效里随机挑一个播，并给一点音高抖动 —— 连续开火 / 连续命中时不会听腻。
func play_varied(sounds: Array, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> AudioStreamPlayer:
	if sounds.is_empty():
		return null
	var pick := str(sounds[randi() % sounds.size()])
	var jitter := 1.0 if pitch_jitter <= 0.0 else randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	return play(pick, volume_db, jitter)


## 按世界坐标播（左右声像 + 距离衰减）。
## ⚠️ 场景里没有 Camera2D / AudioListener2D 时，2D 播放器会以原点当听者，
##    声音会全跑到一边。所以这里兜一手：没有听者就退化成普通播放，
##    宁可没有声像，也不要没声音或者只有一边响。
func play_at(
	sound: String,
	world_pos: Vector2,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0,
	max_distance: float = 1400.0
) -> Node:
	if UserData.sfxMuted:
		return null
	var stream := _get_sfx(sound)
	if stream == null:
		return null
	if not _has_listener():
		return play(sound, volume_db, pitch_scale)
	var p := _acquire_2d()
	p.stream = stream
	p.global_position = world_pos
	p.volume_db = volume_db
	p.pitch_scale = pitch_scale
	p.max_distance = max_distance
	p.play()
	return p


## 这个名字有没有对应文件（想在代码里先判断时用）
func has_sfx(sound: String) -> bool:
	return _get_sfx(sound) != null


# ============================================================
# ③ 循环音（持续音，比如特斯拉嗡鸣）
# ============================================================

## 开一个循环音。同一个 key 重复调用只当一次（已经在响就什么都不做）。
func start_loop(key: String, sound: String, volume_db: float = 0.0) -> void:
	if UserData.sfxMuted or _loops.has(key):
		return
	var stream := _get_sfx(sound)
	if stream == null:
		return
	# ogg 靠 loop 属性无缝循环；不勾的话播完就停
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = "Sfx"
	p.volume_db = volume_db
	add_child(p)
	p.play()
	_loops[key] = p


func stop_loop(key: String) -> void:
	if not _loops.has(key):
		return
	var p: AudioStreamPlayer = _loops[key]
	_loops.erase(key)
	if is_instance_valid(p):
		p.stop()
		p.queue_free()


func stop_all_loops() -> void:
	for key in _loops.keys():
		stop_loop(key)


# ============================================================
# 通用控制
# ============================================================

## 停掉所有正在响的音效（切场景 / 关面板时用）
func stop_all() -> void:
	for p in _sfx_pool:
		if is_instance_valid(p):
			p.stop()
	for p in _pos_pool:
		if is_instance_valid(p):
			p.stop()


## 回收空闲播放器，把节点释放掉
func trim_pools() -> void:
	_free_idle(_sfx_pool)
	_free_idle(_pos_pool)


# ============================================================
# 内部：资源查找与播放器池
# ============================================================

## 名字 -> AudioStream。查不到也缓存（存 null），这样写错名字不会反复查文件系统。
func _get_sfx(sound: String) -> AudioStream:
	if sound.is_empty():
		return null
	if _sfx_cache.has(sound):
		return _sfx_cache[sound]
	var path := SFX_DIR + sound + ".ogg"
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	elif OS.is_debug_build():
		push_warning("[SoundManage] 找不到音效 %s（%s）" % [sound, path])
	_sfx_cache[sound] = stream
	return stream


func _acquire() -> AudioStreamPlayer:
	_reap_dead(_sfx_pool)
	# 先找空闲的
	for p in _sfx_pool:
		if not p.playing:
			return p
	# 池子已经建满、又全在响 —— 抢最早开始的那个复用。
	# ⚠️ 不能"再 new 一个"，那样新建的没进池子，用完就永远漏着（这里踩过）
	if _sfx_pool.size() >= sfx_pool_size:
		var oldest: AudioStreamPlayer = _sfx_pool[0]
		for p in _sfx_pool:
			if p.get_playback_position() > oldest.get_playback_position():
				oldest = p
		return oldest
	var fresh := AudioStreamPlayer.new()
	fresh.bus = "Sfx"
	add_child(fresh)
	_sfx_pool.append(fresh)
	return fresh


func _acquire_2d() -> AudioStreamPlayer2D:
	_reap_dead(_pos_pool)
	for p in _pos_pool:
		if not p.playing:
			return p
	if _pos_pool.size() >= pos_pool_size:
		var oldest: AudioStreamPlayer2D = _pos_pool[0]
		for p in _pos_pool:
			if p.get_playback_position() > oldest.get_playback_position():
				oldest = p
		return oldest
	var fresh := AudioStreamPlayer2D.new()
	fresh.bus = "Sfx"
	add_child(fresh)
	_pos_pool.append(fresh)
	return fresh


## 场景里有没有可用的听者（Camera2D 或 AudioListener2D）
func _has_listener() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	if not tree.get_nodes_in_group("audio_listener").is_empty():
		return true
	# Camera2D 在 Godot 4 里默认充当听者，但要处于启用状态
	for n in tree.get_nodes_in_group("cameras"):
		if n is Camera2D and (n as Camera2D).enabled:
			return true
	return false


func _free_idle(pool: Array) -> void:
	for p in pool.duplicate():
		if is_instance_valid(p) and not p.playing:
			pool.erase(p)
			p.queue_free()


func _reap_dead(pool: Array) -> void:
	for p in pool.duplicate():
		if not is_instance_valid(p):
			pool.erase(p)
