extends Node

signal changed

const TRACKS := [
	["menu-1", "Café das Nove", "Piano manso para bater o ponto"],
	["menu-2", "Elevador Panorâmico", "Jazz de sala de espera"],
	["menu-3", "Relatório ao Pôr do Sol", "Para fechar o dia"],
	["office-1", "Planilha em Loop", "A trilha do expediente"],
]

var player: AudioStreamPlayer
var preferences: ConfigFile
var save_path: String
var selected := -1
var enabled: Array[bool] = [true, true, true, true]
var volume := 0.6
var sound_on := false

func configure(config: ConfigFile, path: String) -> void:
	preferences = config
	save_path = path
	volume = clampf(float(config.get_value("music", "volume", 0.6)), 0.0, 1.0)
	sound_on = bool(config.get_value("music", "enabled", false))
	for index in TRACKS.size():
		enabled[index] = bool(config.get_value("music", TRACKS[index][0], true))
	player = AudioStreamPlayer.new()
	player.bus = _music_bus()
	add_child(player)
	player.volume_db = linear_to_db(maxf(volume, 0.0001))
	player.finished.connect(skip)
	if sound_on: skip()

## Barramento "Música" com filtro passa-baixa e eco: a música do WorkOS sai das caixinhas do PC.
## "pc" = jogador no computador (som limpo); "room" = na sala (abafado, mais baixo, com eco);
## "away" = fora do escritório (some); "off" = PC desligado.
const BUS := "Musica"
var listening := "pc"
var _filter: AudioEffectLowPassFilter
var _reverb: AudioEffectReverb

func _music_bus() -> String:
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS)
		AudioServer.set_bus_send(index, "Master")
		_filter = AudioEffectLowPassFilter.new()
		_filter.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(index, _filter)
		_reverb = AudioEffectReverb.new()
		_reverb.room_size = 0.55
		_reverb.damping = 0.6
		_reverb.wet = 0.0
		_reverb.dry = 1.0
		AudioServer.add_bus_effect(index, _reverb)
	else:
		var index := AudioServer.get_bus_index(BUS)
		_filter = AudioServer.get_bus_effect(index, 0)
		_reverb = AudioServer.get_bus_effect(index, 1)
	return BUS

func set_listening(mode: String) -> void:
	if mode == listening: return
	listening = mode
	var targets: Array = {"pc": [20000.0, 0.0, 0.0], "room": [900.0, 0.28, -9.0], "away": [400.0, 0.4, -60.0], "off": [400.0, 0.0, -60.0]}[mode]
	var index := AudioServer.get_bus_index(BUS)
	var tween := create_tween().set_parallel(true)
	tween.tween_method(func(hz: float) -> void: _filter.cutoff_hz = hz, _filter.cutoff_hz, targets[0], 0.6)
	tween.tween_method(func(wet: float) -> void: _reverb.wet = wet, _reverb.wet, targets[1], 0.6)
	tween.tween_method(func(db: float) -> void: AudioServer.set_bus_volume_db(index, db), AudioServer.get_bus_volume_db(index), targets[2], 0.6)

func set_sound(value: bool) -> void:
	sound_on = value
	if sound_on:
		if selected >= 0 and enabled[selected] and player.stream != null:
			player.stream_paused = false
			if not player.playing: player.play()
		else:
			skip()
	else:
		player.stream_paused = true
	_save()
	changed.emit()

func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	player.volume_db = linear_to_db(maxf(volume, 0.0001))
	_save()

func set_track_enabled(index: int, value: bool) -> void:
	enabled[index] = value
	if selected == index and not value:
		player.stop()
		skip()
	elif selected < 0 and sound_on:
		skip()
	_save()
	changed.emit()

func skip() -> void:
	var next := -1
	for offset in range(1, TRACKS.size() + 1):
		var index := (selected + offset) % TRACKS.size()
		if enabled[index]:
			next = index
			break
	selected = next
	player.stop()
	if selected >= 0:
		player.stream = load("res://assets/audio/workos/%s.mp3" % TRACKS[selected][0])
		if sound_on:
			player.stream_paused = false
			player.play()
	changed.emit()

func _save() -> void:
	preferences.set_value("music", "enabled", sound_on)
	preferences.set_value("music", "volume", volume)
	for index in TRACKS.size():
		preferences.set_value("music", TRACKS[index][0], enabled[index])
	preferences.save(save_path)

func build_ui(parent: Control) -> void:
	var now: Label = parent.get_node("Now")
	var sound: CheckButton = parent.get_node("Sound")
	sound.button_pressed = sound_on
	sound.toggled.connect(set_sound)
	for index in TRACKS.size():
		var track: CheckBox = parent.get_node("Tracks/Track%d" % index)
		track.text = "%s\n%s" % [TRACKS[index][1], TRACKS[index][2]]
		track.button_pressed = enabled[index]
		track.toggled.connect(func(value: bool) -> void: set_track_enabled(index, value))
	var slider: HSlider = parent.get_node("Volume")
	slider.value = volume
	slider.value_changed.connect(set_volume)
	parent.get_node("Next").pressed.connect(skip)
	var refresh := func() -> void:
		if not is_instance_valid(now): return
		now.text = "Som desligado" if not sound_on else ("Nenhuma faixa selecionada" if selected < 0 else "Tocando: " + TRACKS[selected][1])
	changed.connect(refresh)
	parent.tree_exiting.connect(func() -> void: changed.disconnect(refresh))
	refresh.call()
