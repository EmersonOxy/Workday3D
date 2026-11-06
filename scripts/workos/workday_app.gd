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

var break_button: Button
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
	for child in $Phase.get_children():
		$Phase.remove_child(child)
		child.queue_free()
	phase = str(game.career.get("phase", "menu"))
	bars.clear()
	task_signature = ""
	event_signature = ""
	var screen_id := "day"
	if phase == "menu" or phase in ["burnout", "won", "resigned"]: screen_id = "menu"
	elif phase in ["ready", "ended"]: screen_id = "summary"
	elif phase == "promotion": screen_id = "promotion"
	var screen: VBoxContainer = load("res://scenes/workos/phases/%s.tscn" % screen_id).instantiate()
	$Phase.add_child(screen)
	match screen_id:
		"menu":
			if phase != "menu": screen.get_node("Result").text = {"burnout": "Carreira encerrada por burnout.", "won": "Você chegou a CEO!", "resigned": "Demissão registrada."}[phase]
			screen.get_node("Wallet").text = "Saldo: R$ %d   Recorde: %d" % [game.profile.wallet, game.profile.best]
			var difficulty: OptionButton = screen.get_node("Difficulty")
			for name in ["Fácil", "Normal", "Difícil", "Burnout"]: difficulty.add_item(name)
			difficulty.selected = ["facil", "normal", "dificil", "burnout"].find(game.profile.difficulty)
			difficulty.item_selected.connect(func(index: int) -> void:
				game.profile.difficulty = ["facil", "normal", "dificil", "burnout"][index]
				game.save_game())
			screen.get_node("Start").pressed.connect(func() -> void: game.new_career(); _render())
		"summary":
			screen.get_node("Title").text = "EXPEDIENTE · DIA %d" % (game.day() + (1 if phase == "ended" else 0))
			screen.get_node("Summary").visible = phase == "ended"
			if phase == "ended":
				var summary: Dictionary = game.career.summary
				screen.get_node("Summary").text = "Dia concluído\nPontuação: %d\nSalário: R$ %d\nEstresse: %d%%\nCargo: %s" % [summary.points, summary.pay, summary.stress, game.texts().ranks[int(summary.rank)]]
			screen.get_node("Start").pressed.connect(func() -> void: game.start_day(); _render())
			screen.get_node("Calendar").pressed.connect(func() -> void: desktop.open_app("calendar"))
		"promotion":
			screen.get_node("Title").text = "PROMOÇÃO: " + str(game.texts().ranks[int(game.career.rank)])
			for id in game.data.perks:
				if id in game.career.perks: continue
				var description: Variant = game.texts().get("perks", {}).get(id, [id, ""])
				var title := str(description[0]) + " — " + str(description[1]) if description is Array else str(description)
				button(title, func() -> void: game.choose_perk(id); _render(), screen.get_node("Scroll/Benefits"))
		"day":
			hud = screen.get_node("HUD")
			screen.get_node("Toolbar/Pause").pressed.connect(func() -> void: game.paused = not game.paused)
			screen.get_node("Toolbar/Spreadsheet").pressed.connect(func() -> void:
				if game.events.has("boss"): game.dodge_boss()
				else: game.paused = not game.paused)
			screen.get_node("Toolbar/Coffee").pressed.connect(func() -> void: game.use_coffee())
			break_button = button("Intervalo", func() -> void:
				if game.career.get("on_break", false): game.end_break()
				else: game.start_break(), screen.get_node("Toolbar"))
			screen.get_node("Toolbar/Desktop").pressed.connect(func() -> void: game.paused = true; desktop.open_app("calendar"))
			screen.get_node("Body/Left/Board").game = game
			screen.get_node("Body/Left/Controls/Left").pressed.connect(func() -> void: game.move_file(int(game.file.lane) - 1))
			screen.get_node("Body/Left/Controls/Right").pressed.connect(func() -> void: game.move_file(int(game.file.lane) + 1))
			screen.get_node("Body/Left/Controls/Drop").pressed.connect(func() -> void: game.fast = true)
			screen.get_node("Body/Left/Controls/Delete").pressed.connect(game.delete_file)
			screen.get_node("Body/Left/Controls/Coffee").pressed.connect(func() -> void: game.use_coffee(true))
			event_box = screen.get_node("Body/Left/Events")
			task_box = screen.get_node("Body/TaskScroll/Tasks")
			status = screen.get_node("Status")
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
	var on_break: bool = game.career.get("on_break", false)
	hud.text = "Dia %d · %s · %s · %d pts · Estresse %d%% · R$ %d%s" % [game.day(), game.clock.text(), game.texts().ranks[int(game.career.rank)], game.career.day_score, game.career.stress, game.profile.wallet, " · INTERVALO" if on_break else " · PAUSADO" if game.paused else ""]
	if is_instance_valid(break_button):
		break_button.visible = game.clock.break_unlocked()
		break_button.text = "Voltar do intervalo" if on_break else "Intervalo"
		break_button.disabled = not on_break and not game.break_available()
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
		var card: VBoxContainer = preload("res://scenes/workos/components/task_card.tscn").instantiate()
		task_box.add_child(card)
		card.get_node("Title").text = str(task.text) if not task.text.is_empty() else str(task.type).capitalize()
		var panel: VBoxContainer = card.get_node("Actions")
		var timer: ProgressBar = card.get_node("Deadline")
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
