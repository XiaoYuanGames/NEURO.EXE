extends Node
## AudioManager — 程序化音频总线与音效管理器
##
## 由于项目无外部音频文件,所有 BGM/SFX 在 _ready 中以 AudioStreamWAV
## 实时生成 PCM 样本。生成结果缓存,可重复使用。
##
## 公开 API:
##   AudioManager.play_music()
##   AudioManager.stop_music()
##   AudioManager.play_sfx(name)         # hover / click / switch / error
##   AudioManager.set_bus_volume_db(bus, db)
##   AudioManager.set_bus_mute(bus, mute)
##   AudioManager.apply_volumes()        # 一次性从 UserSettings 拉取
##
## 启动时自动连接 UserSettings.setting_changed,同步音频设置。

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_HIT := "Hit"

const SAMPLE_RATE := 44100
const SAMPLE_FMT := AudioStreamWAV.FORMAT_16_BITS

# BGM 节奏: 90 BPM, 一个 bar 4 拍, 一拍 = 60/90 s
const BPM := 90.0
const SEC_PER_BEAT: float = 60.0 / BPM
const BGM_BARS := 4
const BGM_SECONDS: float = SEC_PER_BEAT * 4.0 * BGM_BARS  # 10.666s

var _stream_hover: AudioStreamWAV
var _stream_click: AudioStreamWAV
var _stream_switch: AudioStreamWAV
var _stream_error: AudioStreamWAV
var _stream_bgm: AudioStreamWAV

var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_size := 6
var _sfx_index := 0

var _user_settings: Node


func _ready() -> void:
	_ensure_buses()
	_generate_streams()
	_build_players()
	_apply_initial_volumes()
	_user_settings = get_node_or_null("/root/UserSettings")
	if _user_settings:
		_user_settings.setting_changed.connect(_on_setting_changed)


# -------------------- 总线 --------------------

func _ensure_buses() -> void:
	_add_bus_if_missing(BUS_MUSIC)
	_add_bus_if_missing(BUS_SFX)
	_add_bus_if_missing(BUS_HIT)


func _add_bus_if_missing(name: String) -> void:
	for i in AudioServer.bus_count:
		if AudioServer.get_bus_name(i) == name:
			return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, name)
	AudioServer.set_bus_send(idx, BUS_MASTER)


func set_bus_volume_db(bus: String, db: float) -> void:
	var idx := _bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, db)


func set_bus_volume_pct(bus: String, pct: float) -> void:
	# 0..100 -> -60..0 dB
	var db: float = lerpf(-60.0, 0.0, clampf(pct, 0.0, 100.0) / 100.0)
	set_bus_volume_db(bus, db)


func set_bus_mute(bus: String, mute: bool) -> void:
	var idx := _bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, mute)


func _bus_index(name: String) -> int:
	for i in AudioServer.bus_count:
		if AudioServer.get_bus_name(i) == name:
			return i
	return -1


func _apply_initial_volumes() -> void:
	var us := get_node_or_null("/root/UserSettings")
	if not us:
		return
	set_bus_mute(BUS_MASTER, bool(us.get_value("mute_all", false)))
	set_bus_volume_pct(BUS_MASTER, float(us.get_value("master_volume", 100)))
	set_bus_volume_pct(BUS_MUSIC, float(us.get_value("music_volume", 50)))
	set_bus_volume_pct(BUS_SFX, float(us.get_value("sfx_volume", 70)))
	set_bus_volume_pct(BUS_HIT, float(us.get_value("hit_volume", 100)))


func _on_setting_changed(key: String, value: Variant) -> void:
	match key:
		"mute_all":
			set_bus_mute(BUS_MASTER, bool(value))
		"master_volume":
			set_bus_volume_pct(BUS_MASTER, float(value))
		"music_volume":
			set_bus_volume_pct(BUS_MUSIC, float(value))
		"sfx_volume":
			set_bus_volume_pct(BUS_SFX, float(value))
		"hit_volume":
			set_bus_volume_pct(BUS_HIT, float(value))
		"audio_device":
			if value is String and value != "Default" and value != "":
				var idx: int = AudioServer.get_output_device_list().find(value)
				if idx >= 0:
					AudioServer.set_output_device(value)


# -------------------- 播放器 --------------------

func _build_players() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = BUS_MUSIC
	_music_player.stream = _stream_bgm
	_music_player.volume_db = 0.0
	add_child(_music_player)
	for i in _sfx_pool_size:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_sfx_pool.append(p)


# -------------------- 播放 API --------------------

func play_music() -> void:
	if not _music_player:
		return
	if not _music_player.playing:
		_music_player.play()


func stop_music() -> void:
	if _music_player and _music_player.playing:
		_music_player.stop()


func play_sfx(name: String) -> void:
	if _sfx_pool.is_empty():
		return
	var stream: AudioStreamWAV = null
	match name:
		"hover":  stream = _stream_hover
		"click":  stream = _stream_click
		"switch": stream = _stream_switch
		"error":  stream = _stream_error
		_: stream = _stream_click
	var p: AudioStreamPlayer = _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool_size
	p.stream = stream
	p.play()


# -------------------- 流生成 --------------------

func _generate_streams() -> void:
	_stream_hover = _gen_hover()
	_stream_click = _gen_click()
	_stream_switch = _gen_switch()
	_stream_error = _gen_error()
	_stream_bgm = _gen_bgm()


# ---- SFX 工具 ----

func _wav_from_pcm(pcm: PackedByteArray, loop: bool = false) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = SAMPLE_FMT
	s.mix_rate = SAMPLE_RATE
	s.stereo = false
	s.data = pcm
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = pcm.size() / 2  # 16-bit = 2 bytes per sample
	return s


func _pcm_from_samples(samples: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v: float = clampf(samples[i], -1.0, 1.0)
		var i16: int = int(v * 32767.0)
		if i16 < 0:
			i16 += 65536
		bytes[i * 2] = i16 & 0xFF
		bytes[i * 2 + 1] = (i16 >> 8) & 0xFF
	return bytes


func _apply_envelope(samples: PackedFloat32Array, attack: float, release: float) -> PackedFloat32Array:
	var n: int = samples.size()
	var out := samples.duplicate()
	var a: int = int(attack * SAMPLE_RATE)
	var r: int = int(release * SAMPLE_RATE)
	for i in n:
		var env: float = 1.0
		if i < a:
			env = float(i) / max(1, a)
		elif i > n - r:
			env = float(n - i) / max(1, r)
		out[i] *= clampf(env, 0.0, 1.0)
	return out


func _mix(target: PackedFloat32Array, source: PackedFloat32Array, gain: float = 1.0) -> PackedFloat32Array:
	var n: int = min(target.size(), source.size())
	var out := target.duplicate()
	for i in n:
		out[i] += source[i] * gain
	return out


# ---- SFX 生成 ----

func _gen_hover() -> AudioStreamWAV:
	# 短促 880Hz sine, 60ms, attack 5ms, release 55ms
	var dur := 0.06
	var n: int = int(dur * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		samples[i] = sin(TAU * 880.0 * t) * 0.12
	samples = _apply_envelope(samples, 0.005, 0.055)
	return _wav_from_pcm(_pcm_from_samples(samples))


func _gen_click() -> AudioStreamWAV:
	# 1200Hz + 600Hz, 80ms, attack 2ms, release 78ms
	var dur := 0.08
	var n: int = int(dur * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var s: float = sin(TAU * 1200.0 * t) * 0.5 + sin(TAU * 600.0 * t) * 0.4
		s += randf_range(-0.05, 0.05) if i < 200 else 0.0
		samples[i] = s * 0.3
	samples = _apply_envelope(samples, 0.002, 0.078)
	return _wav_from_pcm(_pcm_from_samples(samples))


func _gen_switch() -> AudioStreamWAV:
	# 200 -> 800Hz 上滑, 180ms
	var dur := 0.18
	var n: int = int(dur * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var k: float = float(i) / n
		var freq: float = lerpf(200.0, 800.0, k)
		samples[i] = sin(TAU * freq * t) * 0.2
	samples = _apply_envelope(samples, 0.01, 0.05)
	return _wav_from_pcm(_pcm_from_samples(samples))


func _gen_error() -> AudioStreamWAV:
	# 400 -> 200Hz 下滑, 300ms
	var dur := 0.3
	var n: int = int(dur * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var k: float = float(i) / n
		var freq: float = lerpf(400.0, 200.0, k)
		samples[i] = sin(TAU * freq * t) * 0.25
	samples = _apply_envelope(samples, 0.01, 0.08)
	return _wav_from_pcm(_pcm_from_samples(samples))


# ---- BGM 生成 ----
# 风格:极简科技氛围 + 90 BPM 鼓点 + pad 持续低音 + 偶尔琶音
func _gen_bgm() -> AudioStreamWAV:
	var n: int = int(BGM_SECONDS * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)

	# 1) 持续 pad: 根音 110Hz (A2) + 五度 165Hz + 八度 220Hz 缓慢 LFO
	var pad := _gen_pad([110.0, 165.0, 220.0], n, 0.18)
	samples = _mix(samples, pad, 0.35)

	# 2) 鼓点: 每个 beat 一次 kick + 偶数 beat 上 hat
	var kick := _gen_kick_pattern(n, BGM_SECONDS)
	samples = _mix(samples, kick, 0.35)

	var hat := _gen_hat_pattern(n, BGM_SECONDS)
	samples = _mix(samples, hat, 0.15)

	# 3) 琶音: 每 2 拍 8 分音符,A 小调: A C E A C E A E
	var arp_notes := [220.0, 261.63, 329.63, 440.0, 523.25, 659.25, 440.0, 329.63]
	var arp := _gen_arpeggio(arp_notes, n, BGM_SECONDS)
	samples = _mix(samples, arp, 0.15)

	# 软裁剪 / 限制
	for i in n:
		samples[i] = clampf(samples[i] * 0.4, -1.0, 1.0)

	# 头尾淡入淡出避免 click
	var fade := int(0.05 * SAMPLE_RATE)
	for i in fade:
		var k: float = float(i) / fade
		samples[i] *= k
		samples[n - 1 - i] *= k

	return _wav_from_pcm(_pcm_from_samples(samples), true)


func _gen_pad(freqs: PackedFloat32Array, n: int, gain: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var s: float = 0.0
		for f in freqs:
			# 略 detune 营造厚度
			s += sin(TAU * f * t) * 0.5
			s += sin(TAU * (f * 1.005) * t) * 0.4
		# 慢 LFO
		var lfo: float = 0.5 + 0.5 * sin(TAU * 0.15 * t)
		out[i] = s * gain * (0.7 + 0.3 * lfo) * 0.3
	return out


func _gen_kick_pattern(n: int, dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var total_beats: int = int(dur / SEC_PER_BEAT)
	for b in total_beats:
		var start: int = int(float(b) * SEC_PER_BEAT * SAMPLE_RATE)
		var end: int = min(n, start + int(0.18 * SAMPLE_RATE))
		for i in range(start, end):
			var t: float = float(i - start) / SAMPLE_RATE
			# 频率从 90Hz 跌至 45Hz
			var freq: float = lerpf(90.0, 45.0, t / 0.18)
			var env: float = exp(-t * 18.0)
			out[i] += sin(TAU * freq * t) * env * 0.9
	return out


func _gen_hat_pattern(n: int, dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var total_beats: int = int(dur / SEC_PER_BEAT)
	for b in total_beats:
		# 落在第 2, 4 拍 (off-beat 弱拍)
		for off in [1, 3]:
			var beat_idx: int = b * 4 + off
			var start: int = int(float(beat_idx) * SEC_PER_BEAT * 0.25 * SAMPLE_RATE)
			var end: int = min(n, start + int(0.04 * SAMPLE_RATE))
			for i in range(start, end):
				var t: float = float(i - start) / SAMPLE_RATE
				var env: float = exp(-t * 80.0)
				# 高频噪声
				out[i] += (randf() * 2.0 - 1.0) * env * 0.35
	return out


func _gen_arpeggio(notes: PackedFloat32Array, n: int, dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var step_dur: float = SEC_PER_BEAT * 0.5  # 8 分音符
	var step_samples: int = int(step_dur * SAMPLE_RATE)
	var steps_total: int = int(dur / step_dur)
	for s in steps_total:
		var note: float = notes[s % notes.size()]
		var start: int = s * step_samples
		var end: int = min(n, start + int(step_dur * 1.2 * SAMPLE_RATE))
		for i in range(start, end):
			var t: float = float(i - start) / SAMPLE_RATE
			var env: float = exp(-t * 4.5)
			out[i] += sin(TAU * note * t) * env * 0.35
			out[i] += sin(TAU * note * 2.0 * t) * env * 0.15
	return out
