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
	add_child(player)
	player.volume_db = linear_to_db(maxf(volume, 0.0001))
	player.finished.connect(skip)
	if sound_on: skip()

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
