# 音频素材来源与授权

## 来源

全部来自 **Sonniss #GameAudioGDC Bundle Part 9**（`E:\音乐文件`）。

> **LICENSE: ROYALTY-FREE**
> *"Use them personally or commercially without attribution."*
> —— `E:\音乐文件\Readme.txt` / `License - GDC Game Audio.pdf`
> 联系：timothy@sonniss.com ｜ https://sonniss.com

即：**可商用、免版税、无需署名**。下表仍记录原始文件名，便于日后追溯或替换。

## 目录结构

```
sound/
├── bgm/            4 首环境循环（.import 里 loop=true）
├── sfx/           26 个音效
├── Pickup.wav     设置页音量滑块的试听音（保留）
├── button_on.mp3  ⚠️ 孤立文件，已无任何引用，可删
└── CREDITS.md
```

> **2026-09-13 重组**：原先散在 `sound/` 根目录的 `Ting Coins.ogg` 与 `Tower Deploy.ogg`
> 和这次转换出的 `sfx/coin.ogg` / `sfx/tower_deploy.ogg` 是**同一批音源的两个副本**
> （体积一致、内容有细微差异）。已删除根目录那两份，引用同步改到 `sfx/` 下：
> `sound_manage.tscn`(UI 点击) / `setting.tscn`(音量试听) / `tower/Tower.tscn`(建塔音)。

### UI 音效怎么选

| 场景 | 方法 | 文件 |
| --- | --- | --- |
| 菜单 / 通用 UI 按钮（`ui_button.tscn` 预制体，`click_sound = COIN`） | `SoundManage.playEffect()` | `sfx/coin.ogg` |
| 地图内按钮（`title.gd` 的 5 个、`map.gd` 的测试按钮） | `SoundManage.playConfirm()` | `sfx/ui_confirm.ogg` |

两个 `AudioStreamPlayer` 都挂在 `Sfx` 总线上，静音开关对它们同时生效。

### ⚠️ 一次点击只响一声

**`ui_button.tscn` 自带 `ui_button.gd`，它自己就会播点击音。**
用了这个预制体的按钮，**场景脚本不要再调一次 `SoundManage.playXxx()`** —— 那会响两声。
想换音色请改实例上的 `click_sound`（`COIN` / `CONFIRM`），不要在外面补一句。

反过来，`menuBtn.tscn`（地图顶栏那 5 个按钮用的是它）也**自己播** ——
脚本 `menu_btn.gd` 挂在 `menuBtn.tscn` 根节点上，`_ready()` 按内部按钮是不是
`toggle_mode` 去接 `toggled` 或 `pressed`。
所以 **`title.gd` 里不要再补 `playConfirm()`** —— 之前补过，那是「顶栏点一下响两声」的来源。

三套按钮预制体各自的归属：

| 预制体 | 谁播 |
| --- | --- |
| `ui_button.tscn` | `ui_button.gd`（`click_sound` 选 COIN / CONFIRM） |
| `menuBtn.tscn` | `menu_btn.gd`（固定 CONFIRM） |
| 面板里的普通 `Button`（确认 / 取消等） | 场景脚本自己调，或干脆不播 |

### ⚠️ toggle 按钮的状态同步必须静默

顶栏的 ▶/⏸ 是 `toggle_mode = true`。两种状态的语义：

| `button_pressed` | 显示 | 含义 |
| --- | --- | --- |
| `true` | ⏸（`texture_pressed`） | **正在运行**，点我暂停 |
| `false` | ▶（`texture_normal`） | **已暂停**（或还没开始），点我继续 |

所以 `map.gd` 里同步的是 **`title.set_playing(正在运行)`** ——
`startGame` / `resumeGame` 传 `true`，`pauseGame` 传 `false`。

**内部必须走 `set_pressed_no_signal`** —— 直接写 `button_pressed` 会触发 `toggled`，
反过来又发一次 `start` / `pause`，声音和状态都会错乱。



三道防线，任何一道都能单独挡住"一声变两声"：

1. **`ui_button.gd` 的按钮级连点保护**（`CLICK_GUARD_MSEC = 120`）——
   同一个按钮 120ms 内只认一次点击。一次点击被重复派发（两条信号路径 / 重复事件）
   会落进窗口里被吃掉；不同按钮互不影响。
2. **`SoundManage` 的全局去重闸**（`DEDUPE_WINDOW = 30ms`）——
   两条通道共用一把闸，同帧的 `coin + confirm` 也只放行一次。
3. **调用栈追踪**：`SoundManage.trace_plays`（调试版自动开启）。
   真的还听到两声时，看控制台里哪两条栈都触发了 —— 那就是元凶。
   正常只应该看到一条：
   ```
   [SoundManage] play effect
	   ui_button.gd:34  _on_pressed()
   ```




## 为什么是 OGG 而不是 MP3

源文件是 96kHz/24bit 立体声 WAV，不能直接进项目。转换用的是 `D:\VLC\vlc.exe`，
输出 **Ogg Vorbis / 44.1kHz / 立体声**：

- **OGG 支持无缝循环** —— Godot 导入时可勾 `loop`，BGM 不会有接缝。
  MP3 编码器会在首尾加静音填充，循环时必然有可听见的断点。
- 项目里原本就在用 `.ogg`（`Tower Deploy.ogg` / `Ting Coins.ogg`），保持一致。
- 体积：源 WAV 约 330 MB → 产出 **6.8 MB**。

转换命令（可重复执行）：

```powershell
D:\VLC\vlc.exe -I dummy --no-video --quiet "<源.wav>" `
  --sout="#transcode{acodec=vorb,ab=192,channels=2,samplerate=44100}:standard{access=file,mux=ogg,dst=<目标.ogg>}" `
  vlc://quit
```

---

## BGM（`sound/bgm/`，60 秒级循环）

| 项目文件 | 码率 | 原始文件 | 用途 |
| --- | --- | --- | --- |
| `factory_ambient.ogg` | 192k | AMBRoom_Factory Loop Heavy Machinery Tonal Roomtone Dark Wind Vent_ESM_SGA3.wav | 工厂车间底噪（重型机械 + 通风管），**与游戏主题完全吻合**，适合常规关卡 |
| `combat_reactor.ogg` | 192k | DSGNSynth_Scifi Loop Ship Reactor Synth Layer Layered Saw Buzz_ESM_SGA3.wav | 科幻反应堆锯齿合成器，适合高压战斗关 |
| `dark_synth.ogg` | 192k | DSGNSynth_Dark Loop Mystic Forest Tonal Steady Synth_ESM_SGA3.wav | 暗色稳定合成器，适合高难度关 |
| `shimmer_bells.ogg` | 192k | MAGShim_Shimmer Loop Small Bell Metal Taps_ESM_SGA3.wav | 金属铃铛微光，适合菜单 / 结算 |

> ⚠️ 这四首**都是环境音循环，不是旋律配乐**。这个音源包是音效库，本身没有配乐曲目。
> 当作"底噪 + 氛围"用效果不错；如果之后想要真正的主题旋律，需要另外找音源。

## 音效（`sound/sfx/`，128k）

| 类别 | 项目文件 | 原始文件（摘） |
| --- | --- | --- |
| 塔 | `tower_deploy.ogg` | ROBTMvmt_Tower Deploy Hitech Robot Motor Dark Thump Servo Whine 04_ESM_TDG.wav |
| 塔 | `skill_deploy.ogg` | DSGNStngr_Action Deploy Units Sword Slice Special Move Layered Swish 04_ESM_TDG.wav |
| 塔 | `skill_freeze.ogg` | ICEBrk_Skill Freeze Whoosh Break Impact Layered Movement Shatter 03_ESM_TDG.wav |
| 塔 | `hit_squish.ogg` | WOODImpt_Hit Blood Spill Splat Wood Impact Light Hit Squelch Small Thump 03_ESM_TDG.wav |
| 电 | `arc_zap.ogg` | ELECArc_ArcDesign15_InMotionAudio_Arc.wav |
| 电 | `arc_charge.ogg` | ELECArc_ArcPowerUpDesign04_InMotionAudio_Arc.wav |
| 电 | `electric_buzz.ogg` | ELECBuzz_Buzz27_InMotionAudio_Arc.wav |
| 电 | `glitch_hi.ogg` | UIGlitch_User interface_Glitch_High_Electronic_The Noisery_Rich Glitch_05.wav |
| 电 | `glitch_error.ogg` | UIGlitch_Designed_Glitch_Corrupted_Data Error_The Noisery_Rich Glitch_06.wav |
| 爆 | `boom_big.ogg` | EffectiveTrailer_Booms_Vol2_011.wav |
| 爆 | `impact_cut.ogg` | Cinematic Sound Design - Colossal Impacts/Impact Cut Sweep.wav |
| 爆 | `woosh_debris.ogg` | Cinematic Sound Design - Colossal Impacts/Woosh Debris.wav |
| 波 | `wave_horn_a.ogg` | DSGNBram____Cinematic Horn Braam, Epic, Cinematic, Dark, Instrument, Huge-32.wav |
| 波 | `wave_horn_b.ogg` | DSGNBram____Cinematic Horn Braam, Epic, Cinematic, Dark, Instrument, Huge-67.wav |
| 波 | `wave_alarm.ogg` | EffectiveTrailer_Alarms_Vol2_WholeNotes_011.wav |
| UI | `ui_click.ogg` | Interface Pop High Short.wav |
| UI | `ui_accept.ogg` | Interface Accept Glassy Snap.wav |
| UI | `ui_deny.ogg` | Interface Deny Low Fat Dark.wav |
| UI | `ui_confirm.ogg` | Interface Percussion Snap.wav |
| UI | `ui_reveal.ogg` | Interface Arp Reveal Down Long.wav |
| UI | `ui_ping.ogg` | Interface Sci-Fi Ping Down.wav |
| UI | `ui_kalimba.ogg` | UIMisc_Kalimba 3 Up_CB Sounddesign_APPlicable Sounds.wav |
| UI | `coin.ogg` | Cinematic Sound Design - UI Interaction Elements/Ting Coins.wav |
| 造 | `mech_click.ogg` | MECHLtch_Click Deep Mechanism Latch Button Nearfield Thunk 02_ESM_HDLM.wav |
| 造 | `mech_count.ogg` | MACHMech_Mechanism Counting Machine Interact Loose Container Short 01_ESM_HDLM.wav |
| 敌 | `enemy_attack.ogg` | CREAHmn_Designed Orc Male Attack Long Heavy Hit Charged Up 03_ESM_HC4.wav |

---

## 尚未使用但值得留意的候选

`E:\音乐文件` 里还有这些和塔防/工厂题材相关、这次没转的：

| 原始文件 | 时长 | 可能的用途 |
| --- | --- | --- |
| `Victor Ermakov - Industrial Ambiences - Ship Repair Factory\AMBInd_Factory Hall Busy Alarm Machines Voices_CW.wav` | 37.7 MB | 更"有人气"的工厂环境（含人声与警报），可做另一首关卡 BGM |
| `Epic Stock Media - Strange Game Ambient Loops 3\DSGNSynth_Dark Loop Mystic Forest…` | 33.3 MB | 已转 |
| `Sonic Bat - Music Boxes\SBmb_Music Box B / C` | 1.9 / 2.0 MB | 短旋律片段，可做开箱 / 奖励小铃 |
| `344 Audio - Elemental Palette Designed Vol. 1` | 3 个 | 元素类 whoosh，可做子弹命中 |
| `The Noisery - Moaning Metal` | 3 个 | 金属呻吟，可做基地受损 |
| `Ivo Vicic - Church Bells\n04 Church Bells, Near Distance…` | 38.5 MB | 近景钟声，可做"关卡开始"仪式感 |
