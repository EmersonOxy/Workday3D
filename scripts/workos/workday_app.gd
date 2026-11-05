extends VBoxContainer

const BOARD := preload("res://scripts/workos/work_board.gd")
var game: Node
var desktop: Control
var phase := ""
var hud: Label
var status: Label
var task_box: VBoxContainer
var event_box: VBoxContainer
var bars: Dictionary = {}
var task_signature := ""
var event_signature := ""
var elapsed := 0.0

func setup(state: Node, host: Control) -> void:
	game = state
	desktop = host
	size_flags_vertical = SIZE_EXPAND_FILL
	size_flags_horizontal = SIZE_EXPAND_FILL
	_render()

func label(text: String, parent: Node = null) -> Label:
	var item := Label.new()
	item.text = text
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(parent if parent != null else self).add_child(item)
	return item

func button(text: String, callback: Callable, parent: Node = null) -> Button:
	var item := Button.new()
	item.text = text
	item.pressed.connect(callback)
	(parent if parent != null else self).add_child(item)
	return item

func _render() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	phase = str(game.career.get("phase", "menu"))
	bars.clear()
	task_signature = ""
	event_signature = ""
	if phase == "menu" or phase in ["burnout", "won", "resigned"]:
		label("PORTAL RH · WORKDAY LTDA.")
		label("Arquive documentos no setor correto e resolva pendências antes do prazo.\nA carreira tem 25 dias mínimos até CEO. O expediente dura quatro minutos.")
		if phase != "menu": label({"burnout": "Carreira encerrada por burnout.", "won": "Você chegou a CEO!", "resigned": "Demissão registrada."}[phase])
		label("Saldo: R$ %d   Recorde: %d" % [game.profile.wallet, game.profile.best])
		var difficulty := OptionButton.new()
		for name in ["Fácil", "Normal", "Difícil", "Burnout"]: difficulty.add_item(name)
		difficulty.selected = ["facil", "normal", "dificil", "burnout"].find(game.profile.difficulty)
		add_child(difficulty)
		difficulty.item_selected.connect(func(index: int) -> void:
			game.profile.difficulty = ["facil", "normal", "dificil", "burnout"][index]
			game.save_game())
		button("Iniciar nova carreira", func() -> void: game.new_career(); _render())
		return
	if phase == "ready" or phase == "ended":
		label("EXPEDIENTE · DIA %d" % (game.day() + (1 if phase == "ended" else 0)))
		if phase == "ended":
			var summary: Dictionary = game.career.summary
			label("Dia concluído\nPontuação: %d\nSalário: R$ %d\nEstresse: %d%%\nCargo: %s" % [summary.points, summary.pay, summary.stress, game.texts().ranks[int(summary.rank)]])
		label("Setas: mover documento · Espaço: acelerar queda · Delete: descartar\nEsc: planilha/pausa · Pendências: mouse e teclado")
		button("Começar expediente", func() -> void: game.start_day(); _render())
		button("Abrir calendário", func() -> void: desktop.open_app("calendar"))
		return
	if phase == "promotion":
		label("PROMOÇÃO: " + str(game.texts().ranks[int(game.career.rank)]))
		label("Escolha um benefício permanente para esta carreira:")
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = SIZE_EXPAND_FILL
		add_child(scroll)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = SIZE_EXPAND_FILL
		scroll.add_child(list)
		for id in game.data.perks:
			if id in game.career.perks: continue
			var description: Variant = game.texts().get("perks", {}).get(id, [id, ""])
			var title := str(description[0]) + " — " + str(description[1]) if description is Array else str(description)
			button(title, func() -> void: game.choose_perk(id); _render(), list)
		return
	hud = label("")
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	button("Pausar / continuar", func() -> void: game.paused = not game.paused, toolbar)
	button("Planilha", func() -> void:
		if game.events.has("boss"): game.dodge_boss()
		else: game.paused = not game.paused, toolbar)
	button("Café", func() -> void: game.use_coffee(), toolbar)
	button("WorkOS", func() -> void: game.paused = true; desktop.open_app("calendar"), toolbar)
	var body := HBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(left)
	var board := BOARD.new()
	board.game = game
	left.add_child(board)
	var controls := HBoxContainer.new()
	left.add_child(controls)
	button("←", func() -> void: game.move_file(int(game.file.lane) - 1), controls)
	button("Soltar", func() -> void: game.fast = true, controls)
	button("→", func() -> void: game.move_file(int(game.file.lane) + 1), controls)
	button("Excluir", game.delete_file, controls)
	button("Pegar café", func() -> void: game.use_coffee(true), controls)
	event_box = VBoxContainer.new()
	left.add_child(event_box)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 370
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_child(scroll)
	task_box = VBoxContainer.new()
	task_box.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(task_box)
	status = label("Organize as bandejas e acompanhe os prazos.")
	_refresh()

func _process(delta: float) -> void:
	if game == null: return
	if phase != str(game.career.get("phase", "menu")):
		_render()
		return
	elapsed += delta
	if phase == "day" and elapsed >= 0.08:
		elapsed = 0
		_refresh()

func _refresh() -> void:
	if phase != "day" or not is_instance_valid(hud): return
	var minutes := 540 + floori(float(game.career.time) / 240 * 540)
	hud.text = "Dia %d · %02d:%02d · %s · %d pts · Estresse %d%% · R$ %d%s" % [game.day(), minutes / 60, minutes % 60, game.texts().ranks[int(game.career.rank)], game.career.day_score, game.career.stress, game.profile.wallet, " · PAUSADO" if game.paused else ""]
	var ids: Array = []
	for task in game.tasks: ids.append(task.id)
	var signature := str(ids)
	if signature != task_signature:
		task_signature = signature
		_build_tasks()
	for id in bars:
		var task: Dictionary = game.get_task(id)
		if not task.is_empty(): bars[id].value = maxf(0, 100 * (1 - float(task.life) / float(task.ttl)))
	var event_key := str(game.events.keys()) + str(game.events.get("virus", 0))
	if event_signature != event_key:
		event_signature = event_key
		_build_events()

func _build_tasks() -> void:
	for child in task_box.get_children():
		task_box.remove_child(child)
		child.queue_free()
	bars.clear()
	for task in game.tasks:
		var id := int(task.id)
		var panel := VBoxContainer.new()
		task_box.add_child(panel)
		label(str(task.text) if not task.text.is_empty() else str(task.type).capitalize(), panel)
		var timer := ProgressBar.new()
		timer.custom_minimum_size.y = 12
		timer.show_percentage = false
		panel.add_child(timer)
		bars[id] = timer
		match task.type:
			"button", "email":
				if task.variant == "complex":
					for step in 3: button("%d. %s" % [step + 1, game.texts().ui.prog.steps[step]], game.task_action.bind(id, str(step)), panel)
				elif task.variant == "sector" or task.type == "email":
					if task.type == "button": label("Setor: " + str(game.texts().sectors[task.sector]), panel)
					var grid := GridContainer.new()
					grid.columns = 2
					panel.add_child(grid)
					for sector in game.SECTORS: button(game.texts().sectors[sector], game.task_action.bind(id, sector), grid)
					if task.type == "email" and game.available("spam"): button("Spam", game.task_action.bind(id, "spam"), panel)
				else: button("Confirmar", game.task_action.bind(id, ""), panel)
			"type":
				var input := LineEdit.new()
				input.placeholder_text = "Digite o relatório e Enter"
				panel.add_child(input)
				input.text_submitted.connect(func(value: String) -> void: game.task_action(id, value))
			"call":
				var phone := button("Segure para atender (%.1f s)" % task.need, func() -> void: pass, panel)
				phone.button_down.connect(func() -> void: task.holding = true)
				phone.button_up.connect(func() -> void: task.holding = false; task.held = 0.0)
			"printer":
				label("Pressione %s, %d vezes" % [" / ".join(task.keys), task.need], panel)
				for key in task.keys: button(key, game.task_action.bind(id, key), panel)
			"video": button("Aceitar reunião", game.task_action.bind(id, ""), panel)
		panel.add_child(HSeparator.new())

func _build_events() -> void:
	for child in event_box.get_children():
		event_box.remove_child(child)
		child.queue_free()
	if game.events.has("boss"): button("CHEFE CHEGANDO! Abrir planilha", game.dodge_boss, event_box)
	if game.events.has("virus"):
		button("X — Fechar aviso de vírus (%d)" % game.events.virus, game.close_virus, event_box)
	if game.events.has("video"):
		button("Reunião: responder à fala", func() -> void:
			if not game.active() or not game.events.has("video"): return
			game.success(8)
			game.events.video.left -= 1
			if game.events.video.left <= 0:
				game.events.erase("video")
				game.stat("videos"), event_box)

func _unhandled_key_input(event: InputEvent) -> void:
	if desktop == null or desktop.current_app != "workday" or not visible or phase != "day" or not game.active(): return
	if not event is InputEventKey: return
	if event.keycode == KEY_SPACE:
		game.fast = event.pressed
		get_viewport().set_input_as_handled()
	if not event.pressed or event.echo: return
	match event.keycode:
		KEY_LEFT: game.move_file(int(game.file.lane) - 1)
		KEY_RIGHT: game.move_file(int(game.file.lane) + 1)
		KEY_DELETE: game.delete_file()
		_:
			for task in game.tasks.duplicate():
				if task.type == "printer": game.task_action(task.id, OS.get_keycode_string(event.keycode))
