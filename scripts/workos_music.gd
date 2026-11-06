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
	# RADIO.EXE (osMusic de 09-telas.js): faixa atual, lista de botões com marca, volume e "Próxima faixa".
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
	var ink := Color("2a1f2d")
	var now := Label.new()
	now.add_theme_font_size_override("font_size", 22)
	now.add_theme_color_override("font_color", ink)
	parent.add_child(now)
	var sound := CheckButton.new()
	sound.text = "Reproduzir música"
	sound.button_pressed = sound_on
	sound.toggled.connect(set_sound)
	parent.add_child(sound)
	var buttons: Array[Button] = []
	for index in TRACKS.size():
		var track := Button.new()
		track.toggle_mode = true
		track.button_pressed = enabled[index]
		track.focus_mode = Control.FOCUS_NONE
		track.alignment = HORIZONTAL_ALIGNMENT_LEFT
		track.custom_minimum_size.y = 58
		track.toggled.connect(func(value: bool) -> void: set_track_enabled(index, value))
		parent.add_child(track)
		buttons.append(track)
	var volume_row := HBoxContainer.new()
	parent.add_child(volume_row)
	var volume_label := Label.new()
	volume_label.text = "Volume"
	volume_row.add_child(volume_label)
	var slider := HSlider.new()
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = volume
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(set_volume)
	volume_row.add_child(slider)
	var next := Button.new()
	next.text = "Próxima faixa"
	next.focus_mode = Control.FOCUS_NONE
	next.pressed.connect(skip)
	parent.add_child(next)
	var refresh := func() -> void:
		if not is_instance_valid(now): return
		now.text = "Som desligado." if not sound_on else ("Nada tocando (nenhuma faixa ligada)." if selected < 0 else "Tocando: " + TRACKS[selected][1])
		for index in buttons.size():
			var mark := "[x] " if enabled[index] else "[ ] "
			var playing := sound_on and index == selected
			buttons[index].text = "%s%s%s
     %s" % [mark, ("> " if playing else ""), TRACKS[index][1], TRACKS[index][2]]
			buttons[index].set_pressed_no_signal(enabled[index])
		sound.set_pressed_no_signal(sound_on)
	changed.connect(refresh)
	parent.tree_exiting.connect(func() -> void: changed.disconnect(refresh))
	refresh.call()
