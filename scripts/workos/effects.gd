extends Node

var reduced_motion := false
var sound_enabled := true
var volume := 0.35
var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var cursor := 0
var last_sound := 0

func _ready() -> void:
	for index in 8:
		var player := AudioStreamPlayer.new()
		add_child(player)
		voices.append(player)

func sound(kind: String) -> void:
	if not sound_enabled or volume <= 0: return
	var now := Time.get_ticks_msec()
	if kind == "click" and now - last_sound < 45: return
	last_sound = now
	if not streams.has(kind): streams[kind] = _synthesize(kind)
	var voice := voices[cursor]
	cursor = (cursor + 1) % voices.size()
	voice.stream = streams[kind]
	voice.volume_db = linear_to_db(volume)
	voice.play()

func _synthesize(kind: String) -> AudioStreamWAV:
	# Frequencies and short envelopes adapted from Workday's 06-audio.js.
	var score: Array = {
		"click": [[1300, 1300, 0.035, 0.0, 0.15]],
		"open": [[330, 660, 0.08, 0.0, 0.12], [990, 990, 0.06, 0.07, 0.11]],
		"close": [[700, 300, 0.09, 0.0, 0.12]],
		"min": [[900, 420, 0.12, 0.0, 0.12]],
		"max": [[420, 900, 0.12, 0.0, 0.12]],
		"success": [[660, 880, 0.08, 0.0, 0.12], [990, 990, 0.1, 0.06, 0.08]],
		"error": [[180, 92, 0.26, 0.0, 0.18]],
		"notify": [[1046, 1046, 0.12, 0.0, 0.12], [1568, 1568, 0.22, 0.09, 0.1]],
		"level": [[523, 523, 0.16, 0.0, 0.16], [659, 659, 0.16, 0.08, 0.16], [784, 784, 0.16, 0.16, 0.16], [1047, 1047, 0.16, 0.24, 0.16]],
	}.get(kind, [[660, 880, 0.09, 0.0, 0.1]])
	var rate := 22050
	var length := 0.0
	for note in score: length = maxf(length, float(note[2]) + float(note[3]))
	var bytes := PackedByteArray()
	bytes.resize(ceili((length + 0.01) * rate) * 2)
	for index in bytes.size() / 2:
		var time := float(index) / rate
		var sample := 0.0
		for note in score:
			var local := time - float(note[3])
			var duration := float(note[2])
			if local < 0 or local >= duration: continue
			var phase := TAU * (float(note[0]) * local + 0.5 * (float(note[1]) - float(note[0])) * local * local / duration)
			var envelope := minf(1.0, local / 0.004) * pow(1 - local / duration, 1.5)
			sample += sin(phase) * envelope * float(note[4])
		bytes.encode_s16(index * 2, int(clampf(sample, -1, 1) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream

func reveal(control: Control, duration := 0.16) -> void:
	if reduced_motion: return
	control.modulate.a = 0
	control.create_tween().tween_property(control, "modulate:a", 1.0, duration)

func press(button: BaseButton) -> void:
	if button.has_meta("workos_fx"): return
	button.set_meta("workos_fx", true)
	button.mouse_entered.connect(func() -> void:
		if button.disabled: return
		button.self_modulate = Color("fff2d7"))
	button.mouse_exited.connect(func() -> void: button.self_modulate = Color.WHITE)
	button.pressed.connect(func() -> void: sound("click"))
