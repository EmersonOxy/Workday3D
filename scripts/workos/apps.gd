extends RefCounted

static func label(parent: Node, message: String) -> Label:
	var item := Label.new()
	item.text = message
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(item)
	return item

static func button(parent: Node, title: String, callback: Callable) -> Button:
	var item := Button.new()
	item.text = title
	item.pressed.connect(callback)
	parent.add_child(item)
	return item

static func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

static func column(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	return list

static func calendar(parent: Control, game: Node) -> void:
	parent = parent.get_node("Scroll/Content")
	var navigation: HBoxContainer = parent.get_node("Navigation")
	var cycle := [floori((game.day() - 1) / float(game.data.cycle))]
	var title: Label = navigation.get_node("Title")
	var body: VBoxContainer = parent.get_node("Body")
	var details: VBoxContainer = parent.get_node("Details")
	var paint := func() -> void:
		clear(body)
		clear(details)
		title.text = "Expediente · ciclo %d · dia %d" % [cycle[0] + 1, game.day()]
		var grid := GridContainer.new()
		grid.columns = 5
		body.add_child(grid)
		for weekday in ["Seg", "Ter", "Qua", "Qui", "Sex"]: label(grid, weekday)
		for index in int(game.data.cycle):
			var day: int = cycle[0] * int(game.data.cycle) + index + 1
			var names: Array[String] = []
			var matches: Array = []
			for event in game.data.special:
				var period: Vector2i = game.quest_window(event)
				var offset: int = (cycle[0] - floori((game.day() - 1) / float(game.data.cycle))) * int(game.data.cycle)
				if day >= period.x + offset and day <= period.y + offset:
					names.append(str(game.texts().ui.ev.names[event.id]))
					matches.append(event)
			var cell := button(grid, str(day) + (" *" if not matches.is_empty() else ""), func() -> void:
				clear(details)
				label(details, "Dia %d" % day)
				if matches.is_empty(): label(details, "Sem evento especial neste dia.")
				for event in matches:
					label(details, str(game.texts().ui.ev.names[event.id]) + "\n" + str(game.texts().ui.ev.desc[event.id]))
					var progress: Dictionary = game.quests.active.get(event.id, {}).get("progress", {})
					for step in event.steps: label(details, "%s: %d / %d" % [_step_name(step[0]), progress.get(step[0], game.profile.decor.size() if step[0] == "decor" else 0), step[1]])
					label(details, "Recompensa: " + str(game.texts().ui.ev.pins[event.pin]))
					if game.quests.done.has(event.id): label(details, "Concluída")
					else:
						var join := button(details, "Participar", func() -> void: game.join_quest(event.id))
						var period: Vector2i = game.quest_window(event)
						join.disabled = game.day() < period.x or game.day() > period.y or cycle[0] != floori((game.day() - 1) / float(game.data.cycle))
						if event.steps.any(func(step: Array) -> bool: return step[0] == "sign"):
							button(details, "Assinar cartão", func() -> void: game.sign_quest(event.id)))
			cell.custom_minimum_size = Vector2(90, 48)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.tooltip_text = "\n".join(names)
			if day == game.day(): cell.modulate = Color("a4e4d2")
	navigation.get_node("Previous").pressed.connect(func() -> void: cycle[0] = maxi(0, cycle[0] - 1); paint.call())
	navigation.get_node("Next").pressed.connect(func() -> void: cycle[0] += 1; paint.call())
	navigation.get_node("Today").pressed.connect(func() -> void: cycle[0] = floori((game.day() - 1) / float(game.data.cycle)); paint.call())
	paint.call()
	var date := Time.get_date_dict_from_system()
	parent.get_node("Date").text = "Data do aparelho: %02d/%02d/%04d. Eventos seguem os dias do expediente." % [date.day, date.month, date.year]

static func _step_name(id: String) -> String:
	return {"files": "Documentos arquivados", "emails": "E-mails respondidos", "typed": "Relatórios digitados", "cafe": "Cafés", "bosses": "Escapar do chefe", "sign": "Assinar cartão", "decor": "Enfeites adquiridos", "duda": "Partidas com Duda", "buy": "Presentes comprados", "calm": "Estresse abaixo de"}.get(id, id)

static func archive(parent: Control, game: Node) -> void:
	var tabs: HBoxContainer = parent.get_node("Tabs")
	var list: VBoxContainer = parent.get_node("Scroll/List")
	var show := func(section: String) -> void:
		clear(list)
		match section:
			"quests":
				for event in game.data.special:
					label(list, str(game.texts().ui.ev.names[event.id]) + (" · Concluída" if game.quests.done.has(event.id) else " · Pendente"))
					label(list, str(game.texts().ui.ev.desc[event.id]))
					list.add_child(HSeparator.new())
			"pins":
				for id in game.data.pins: label(list, str(game.texts().ui.ev.pins[id]) + (" · Na coleção" if id in game.quests.pins else " · Bloqueado"))
			"unlocks":
				for id in game.data.locked:
					label(list, str(game.texts().ui.ev.unlocks[id]) + (" · Liberado" if id in game.quests.unlocks else " · Complete " + str(game.texts().ui.ev.names[game.data.locked[id]])))
			"ach":
				for id in game.texts().ui.ev.ach:
					var achievement: Array = game.texts().ui.ev.ach[id]
					label(list, str(achievement[0]) + (" · " + str(game.quests.ach[id]) if game.quests.ach.has(id) else " · Bloqueada"))
					label(list, achievement[1])
	for key in ["quests", "pins", "unlocks", "ach"]:
		tabs.get_node(key).text = str(game.texts().ui.ev.sections[key])
		tabs.get_node(key).pressed.connect(show.bind(key))
	show.call("quests")

static func profile(parent: Control, game: Node) -> void:
	parent.get_node("Identity").text = "Nº %d\n%s" % [game.profile.id, game.texts().ranks[int(game.career.get("rank", 0))]]
	var name: LineEdit = parent.get_node("EmployeeName")
	name.text = game.profile.name
	var status: Label = parent.get_node("Status")
	parent.get_node("Save").pressed.connect(func() -> void:
		if name.text.strip_edges().is_empty(): return
		game.profile.name = name.text.strip_edges()
		status.text = "Perfil salvo" if game.save_game() else "Não foi possível salvar")
	parent.get_node("Pins").text = "Broches: " + ", ".join(game.quests.pins)
	parent.get_node("Statistics").text = "Saldo: R$ %d\nRecorde: %d\nDias trabalhados: %d" % [game.profile.wallet, game.profile.best, game.profile.stats.get("days", 0)]

static func messenger(parent: Control, social: Node) -> void:
	var game: Node = social.game
	var status: OptionButton = parent.get_node("Header/Presence")
	for title in ["Online", "Ocupado", "Ausente", "Não perturbe", "Invisível"]: status.add_item(title)
	var statuses := ["online", "busy", "away", "dnd", "invisible"]
	status.selected = maxi(0, statuses.find(social.state.status))
	status.item_selected.connect(func(index: int) -> void: social.state.status = statuses[index]; game.save_game())
	var personal: LineEdit = parent.get_node("Header/Personal")
	personal.text = social.state.message
	personal.text_submitted.connect(func(value: String) -> void: social.state.message = value; game.save_game())
	var contacts: VBoxContainer = parent.get_node("Body/Contacts")
	contacts.custom_minimum_size.x = 160
	var chat: VBoxContainer = parent.get_node("Body/Chat")
	var title: Label = chat.get_node("Title")
	var log: RichTextLabel = chat.get_node("Log")
	log.custom_minimum_size.y = 140
	log.add_theme_color_override("default_color", Color("2a1f2d"))
	var choices: VBoxContainer = chat.get_node("Choices")
	var input: LineEdit = chat.get_node("Input")
	var selected := [""]
	var signature := [""]
	var refresh := func() -> void:
		if not is_instance_valid(chat): return
		clear(contacts)
		for id in game.data.cast:
			var contact: Dictionary = social.state.contacts[id]
			if contact.status == "none": continue
			var caption := str(game.data.cast[id].name) + (" (+)" if contact.status == "request" else " (%d)" % contact.unread)
			button(contacts, caption, func() -> void:
				selected[0] = id
				social.reading = id
				contact.unread = 0
				signature[0] = ""
				social.changed.emit())
		var id: String = selected[0]
		if id.is_empty(): return
		var contact: Dictionary = social.state.contacts[id]
		var options: Array = social.choices(id)
		var next_signature := str(contact) + str(options) + str(social.state.threads.get(id, {}).get("queue", []))
		if signature[0] == next_signature: return
		signature[0] = next_signature
		title.text = "%s · %s\nAfinidade %d · Confiança %d · Familiaridade %d" % [game.data.cast[id].name, social.presence(id), contact.aff, contact.trust, contact.fam]
		log.clear()
		for message in contact.log:
			log.add_text(("Você: " if message.mine else str(game.data.cast[id].name) + ": ") + str(message.text) + "\n\n")
		clear(choices)
		input.editable = contact.status == "known"
		if contact.status == "request":
			label(choices, social.text(game.data.cast[id].get("bio", "")))
			button(choices, "Aceitar contato", social.accept_contact.bind(id))
		elif not options.is_empty():
			for index in options.size():
				var option := button(choices, social.fill(options[index].t), social.choose.bind(id, index))
				option.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		elif social.state.threads.has(id): label(choices, "Digitando…")
		else:
			var topics: Array = social.topics(id)
			for topic in topics:
				button(choices, social.text(topic.get("topic", topic.id)), social.start_thread.bind(topic.id))
			if id == "duda" and not social.done("duda_hello"): button(choices, "Dizer oi ao Duda", social.start_thread.bind("duda_hello"))
	input.text_submitted.connect(func(value: String) -> void:
		if not selected[0].is_empty():
			social.send_text(selected[0], value)
			input.clear())
	social.changed.connect(refresh)
	parent.tree_exiting.connect(func() -> void: social.reading = ""; social.changed.disconnect(refresh))
	refresh.call()

static func backup(parent: Control, game: Node) -> void:
	var text: TextEdit = parent.get_node("Data")
	text.text = game.export_backup()
	parent.get_node("Refresh").pressed.connect(func() -> void: text.text = game.export_backup())
	parent.get_node("Copy").pressed.connect(func() -> void: DisplayServer.clipboard_set(text.text))
