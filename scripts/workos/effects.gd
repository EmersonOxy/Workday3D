extends Node
## Efeitos sonoros do WorkOS sintetizados como em 06-audio.js: osciladores (seno, quadrada, triângulo, dente de
## serra) com varredura exponencial de frequência, envelope exponencial (ataque `a`, duração `d`), filtro passa-baixa
## opcional (`lp`) e ruído filtrado (passa-faixa ou passa-baixa, `q`, varredura `f2`). Cada som é gerado uma vez e
## guardado; os nomes são os mesmos do original (winOpen, winClose, notify, shutdown...).

var reduced_motion := false
var sound_enabled := true
var volume := 0.35
var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var cursor := 0
var last_sound := 0

const RATE := 22050
## Tabela do original. Cada item: ["t", {tom}] ou ["n", {ruído}].
const SOUNDS := {
	"ok": [["n", {"f": 700, "d": 0.07, "v": 0.25}], ["t", {"type": "triangle", "f": 660, "d": 0.09, "v": 0.22, "at": 0.01}], ["t", {"type": "triangle", "f": 990, "d": 0.16, "v": 0.2, "at": 0.07}]],
	"err": [["t", {"type": "square", "f": 180, "f2": 92, "d": 0.26, "v": 0.2, "lp": 900}], ["t", {"type": "square", "f": 186, "f2": 95, "d": 0.26, "v": 0.12, "lp": 700}], ["n", {"f": 200, "d": 0.12, "v": 0.3, "type": "lowpass"}]],
	"click": [["t", {"type": "triangle", "f": 1300, "d": 0.035, "v": 0.16}], ["n", {"f": 4000, "d": 0.02, "v": 0.1}]],
	"pop": [["t", {"type": "sine", "f": 420, "f2": 1250, "d": 0.09, "v": 0.3}], ["n", {"f": 3000, "d": 0.03, "v": 0.08}]],
	"key": [["n", {"f": 3200, "d": 0.028, "v": 0.18, "q": 2}], ["t", {"type": "square", "f": 1800, "d": 0.012, "v": 0.04}]],
	"task": [["t", {"type": "sine", "f": 660, "f2": 880, "d": 0.09, "v": 0.14}]],
	"mail": [["t", {"type": "sine", "f": 1046, "d": 0.12, "v": 0.18}], ["t", {"type": "sine", "f": 1568, "d": 0.22, "v": 0.15, "at": 0.09}]],
	"alarm": [["t", {"type": "square", "f": 880, "d": 0.11, "v": 0.13, "lp": 2600}], ["t", {"type": "square", "f": 660, "d": 0.11, "v": 0.13, "at": 0.12, "lp": 2600}], ["t", {"type": "square", "f": 880, "d": 0.11, "v": 0.13, "at": 0.24, "lp": 2600}], ["t", {"type": "square", "f": 660, "d": 0.11, "v": 0.13, "at": 0.36, "lp": 2600}]],
	"freeze": [["t", {"type": "sawtooth", "f": 320, "f2": 55, "d": 0.7, "v": 0.16, "lp": 1200}], ["n", {"f": 300, "d": 0.5, "v": 0.1, "type": "lowpass"}]],
	"unfreeze": [["t", {"type": "triangle", "f": 300, "f2": 1200, "d": 0.22, "v": 0.2}], ["t", {"type": "triangle", "f": 1200, "d": 0.12, "v": 0.15, "at": 0.2}]],
	"coffee": [["n", {"f": 450, "f2": 1900, "d": 0.4, "v": 0.22, "q": 3, "a": 0.1}], ["t", {"type": "sine", "f": 520, "f2": 780, "d": 0.3, "v": 0.1, "at": 0.2}]],
	"whoosh": [["n", {"f": 300, "f2": 3200, "d": 0.38, "v": 0.25, "q": 0.8, "a": 0.12}]],
	"coin": [["t", {"type": "square", "f": 988, "d": 0.08, "v": 0.13}], ["t", {"type": "square", "f": 1319, "d": 0.3, "v": 0.13, "at": 0.07}]],
	"beep": [["t", {"type": "sine", "f": 1760, "d": 0.12, "v": 0.25, "a": 0.002}]],
	"level": [["t", {"type": "triangle", "f": 523, "d": 0.16, "v": 0.2}], ["t", {"type": "triangle", "f": 659, "d": 0.16, "v": 0.2, "at": 0.08}], ["t", {"type": "triangle", "f": 784, "d": 0.16, "v": 0.2, "at": 0.16}], ["t", {"type": "triangle", "f": 1047, "d": 0.16, "v": 0.2, "at": 0.24}], ["t", {"type": "sine", "f": 2093, "d": 0.3, "v": 0.08, "at": 0.32}]],
	"join": [["t", {"type": "sine", "f": 523, "d": 0.1, "v": 0.16}], ["t", {"type": "sine", "f": 784, "d": 0.18, "v": 0.16, "at": 0.09}]],
	"select": [["t", {"type": "square", "f": 990, "d": 0.03, "v": 0.06, "lp": 3000}], ["t", {"type": "triangle", "f": 1480, "d": 0.04, "v": 0.1, "at": 0.025}]],
	"confirm": [["t", {"type": "triangle", "f": 660, "d": 0.06, "v": 0.16}], ["t", {"type": "triangle", "f": 990, "d": 0.1, "v": 0.16, "at": 0.055}], ["n", {"f": 3500, "d": 0.02, "v": 0.06}]],
	"cancel": [["t", {"type": "triangle", "f": 880, "f2": 520, "d": 0.09, "v": 0.15}], ["n", {"f": 1800, "d": 0.02, "v": 0.06}]],
	"winOpen": [["t", {"type": "square", "f": 330, "f2": 660, "d": 0.08, "v": 0.07, "lp": 2400}], ["t", {"type": "triangle", "f": 990, "d": 0.06, "v": 0.11, "at": 0.07}]],
	"winClose": [["t", {"type": "square", "f": 700, "f2": 300, "d": 0.09, "v": 0.07, "lp": 2000}], ["n", {"f": 900, "d": 0.04, "v": 0.08, "at": 0.05, "type": "lowpass"}]],
	"winMin": [["t", {"type": "triangle", "f": 900, "f2": 420, "d": 0.12, "v": 0.12}]],
	"winMax": [["t", {"type": "triangle", "f": 420, "f2": 900, "d": 0.12, "v": 0.12}]],
	"start": [["n", {"f": 2600, "d": 0.02, "v": 0.1, "q": 3}], ["t", {"type": "triangle", "f": 523, "d": 0.07, "v": 0.12, "at": 0.02}], ["t", {"type": "triangle", "f": 784, "d": 0.07, "v": 0.12, "at": 0.065}]],
	"notify": [["t", {"type": "sine", "f": 1175, "d": 0.08, "v": 0.15}], ["t", {"type": "sine", "f": 1760, "d": 0.16, "v": 0.13, "at": 0.08}]],
	"msnIn": [["t", {"type": "triangle", "f": 784, "d": 0.07, "v": 0.13}], ["t", {"type": "triangle", "f": 1175, "d": 0.12, "v": 0.12, "at": 0.075}], ["t", {"type": "sine", "f": 2349, "d": 0.08, "v": 0.04, "at": 0.075}]],
	"msnOn": [["t", {"type": "sine", "f": 523, "d": 0.09, "v": 0.09}], ["t", {"type": "sine", "f": 659, "d": 0.09, "v": 0.09, "at": 0.06}], ["t", {"type": "sine", "f": 988, "d": 0.09, "v": 0.09, "at": 0.12}]],
	"msnReq": [["t", {"type": "triangle", "f": 660, "d": 0.08, "v": 0.12}], ["t", {"type": "triangle", "f": 880, "d": 0.08, "v": 0.12, "at": 0.09}], ["t", {"type": "triangle", "f": 1320, "d": 0.14, "v": 0.1, "at": 0.18}]],
	"ring": [["t", {"type": "square", "f": 1480, "d": 0.07, "v": 0.1, "lp": 3600}], ["t", {"type": "square", "f": 1180, "d": 0.07, "v": 0.1, "at": 0.09, "lp": 3600}], ["t", {"type": "square", "f": 1480, "d": 0.07, "v": 0.1, "at": 0.22, "lp": 3600}], ["t", {"type": "square", "f": 1180, "d": 0.07, "v": 0.1, "at": 0.31, "lp": 3600}]],
	"achieve": [["t", {"type": "square", "f": 659, "d": 0.09, "v": 0.08, "lp": 3200}], ["t", {"type": "square", "f": 784, "d": 0.09, "v": 0.08, "at": 0.07, "lp": 3200}], ["t", {"type": "square", "f": 988, "d": 0.09, "v": 0.08, "at": 0.14, "lp": 3200}], ["t", {"type": "square", "f": 1319, "d": 0.09, "v": 0.08, "at": 0.21, "lp": 3200}], ["t", {"type": "triangle", "f": 1976, "d": 0.35, "v": 0.1, "at": 0.3}]],
	"buy": [["n", {"f": 2400, "d": 0.03, "v": 0.14, "q": 2}], ["t", {"type": "square", "f": 1568, "d": 0.06, "v": 0.1, "at": 0.04, "lp": 4000}], ["t", {"type": "square", "f": 2093, "d": 0.22, "v": 0.1, "at": 0.1, "lp": 4000}]],
	"page": [["n", {"f": 1400, "f2": 3600, "d": 0.12, "v": 0.16, "q": 1.2, "a": 0.02}], ["n", {"f": 900, "d": 0.05, "v": 0.08, "at": 0.1, "type": "lowpass"}]],
	"shutdown": [["t", {"type": "triangle", "f": 784, "d": 0.12, "v": 0.13}], ["t", {"type": "triangle", "f": 659, "d": 0.12, "v": 0.13, "at": 0.1}], ["t", {"type": "triangle", "f": 523, "d": 0.12, "v": 0.13, "at": 0.2}], ["t", {"type": "triangle", "f": 392, "d": 0.12, "v": 0.13, "at": 0.3}], ["t", {"type": "sine", "f": 196, "f2": 60, "d": 0.5, "v": 0.12, "at": 0.4}]],
	# Ligar: o desligar ao contrário, com um brilho no fim (não existia no HTML).
	"boot": [["t", {"type": "sine", "f": 60, "f2": 196, "d": 0.4, "v": 0.1}], ["t", {"type": "triangle", "f": 392, "d": 0.14, "v": 0.12, "at": 0.35}], ["t", {"type": "triangle", "f": 523, "d": 0.14, "v": 0.12, "at": 0.45}], ["t", {"type": "triangle", "f": 659, "d": 0.14, "v": 0.12, "at": 0.55}], ["t", {"type": "triangle", "f": 784, "d": 0.3, "v": 0.13, "at": 0.65}], ["n", {"f": 7000, "d": 0.25, "v": 0.03, "at": 0.7}]],
}
## Nomes usados pela área de trabalho → nomes do original.
const ALIASES := {"open": "winOpen", "close": "winClose", "min": "winMin", "max": "winMax", "success": "ok", "error": "err"}

func _ready() -> void:
	for index in 8:
		var player := AudioStreamPlayer.new()
		add_child(player)
		voices.append(player)

func sound(kind: String) -> void:
	if not sound_enabled or volume <= 0: return
	kind = ALIASES.get(kind, kind)
	var now := Time.get_ticks_msec()
	if kind in ["click", "key"] and now - last_sound < 45: return
	last_sound = now
	if not streams.has(kind): streams[kind] = _synthesize(SOUNDS.get(kind, SOUNDS.click))
	var voice := voices[cursor]
	cursor = (cursor + 1) % voices.size()
	voice.stream = streams[kind]
	voice.volume_db = linear_to_db(volume * 2.2)
	voice.play()

func _synthesize(score: Array) -> AudioStreamWAV:
	var length := 0.0
	for part in score: length = maxf(length, float(part[1].get("d", 0.1)) + float(part[1].get("at", 0.0)))
	var samples := PackedFloat32Array()
	samples.resize(ceili((length + 0.03) * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for part in score:
		if part[0] == "t": _tone(samples, part[1])
		else: _noise(samples, part[1], rng)
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for index in samples.size(): bytes.encode_s16(index * 2, int(clampf(samples[index], -1, 1) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	return stream

## Envelope do original: sobe de 0,0001 até v em `a` segundos e cai exponencialmente até 0,0001 no fim.
static func _envelope(local: float, attack: float, duration: float, level: float) -> float:
	if local < attack: return 0.0001 * pow(level / 0.0001, local / attack)
	return level * pow(0.0001 / level, (local - attack) / maxf(duration - attack, 0.001))

static func _frequency(f: float, f2: float, local: float, duration: float) -> float:
	return f if f2 <= 0 else f * pow(f2 / f, clampf(local / duration, 0, 1))

func _tone(samples: PackedFloat32Array, o: Dictionary) -> void:
	var start := int(float(o.get("at", 0.0)) * RATE)
	var duration := float(o.get("d", 0.1))
	var level := float(o.get("v", 0.3))
	var attack := float(o.get("a", 0.005))
	var type: String = o.get("type", "square")
	var f := float(o.f)
	var f2 := float(o.get("f2", 0.0))
	var lp := float(o.get("lp", 0.0))
	var alpha := 1.0 if lp <= 0 else 1.0 - exp(-TAU * lp / RATE)
	var phase := 0.0
	var filtered := 0.0
	for index in int(duration * RATE):
		var at := start + index
		if at >= samples.size(): break
		var local := float(index) / RATE
		phase = fmod(phase + _frequency(f, f2, local, duration) / RATE, 1.0)
		var wave := 0.0
		match type:
			"sine": wave = sin(TAU * phase)
			"triangle": wave = 1.0 - 4.0 * absf(phase - 0.5)
			"sawtooth": wave = 2.0 * phase - 1.0
			_: wave = 1.0 if phase < 0.5 else -1.0
		filtered += alpha * (wave - filtered)
		samples[at] += filtered * _envelope(local, attack, duration, level)

## Ruído branco num filtro biquad (passa-faixa ou passa-baixa) com frequência que pode varrer até f2.
func _noise(samples: PackedFloat32Array, o: Dictionary, rng: RandomNumberGenerator) -> void:
	var start := int(float(o.get("at", 0.0)) * RATE)
	var duration := float(o.get("d", 0.1))
	var level := float(o.get("v", 0.3))
	var attack := float(o.get("a", 0.004))
	var q := float(o.get("q", 1.2))
	var lowpass: bool = o.get("type", "bandpass") == "lowpass"
	var f := float(o.get("f", 1500))
	var f2 := float(o.get("f2", 0.0))
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for index in int(duration * RATE):
		var at := start + index
		if at >= samples.size(): break
		var local := float(index) / RATE
		var w := TAU * minf(_frequency(f, f2, local, duration), RATE * 0.45) / RATE
		var alpha := sin(w) / (2.0 * q)
		var cw := cos(w)
		var b0 := (1.0 - cw) / 2.0 if lowpass else alpha
		var b1 := (1.0 - cw) if lowpass else 0.0
		var b2 := b0 if lowpass else -alpha
		var a0 := 1.0 + alpha
		var x := rng.randf_range(-1.0, 1.0)
		var y := (b0 * x + b1 * x1 + b2 * x2 - (-2.0 * cw) * y1 - (1.0 - alpha) * y2) / a0
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		samples[at] += y * _envelope(local, attack, duration, level)

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
