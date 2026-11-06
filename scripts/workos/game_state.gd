extends Node

signal changed
signal notice(message: String)
signal task_changed
signal career_started
signal day_finished(summary: Dictionary)
signal decor_changed(owned: Array)

const SAVE := "user://workday_game.json"
const DATA_PATH := "res://assets/data/workday_original.json"
const RANK_POINTS := [0, 2800, 6300, 10300, 14700, 19400, 24300]
const RANK_DAYS := [1, 3, 7, 11, 16, 21, 25]
const SALARY := [40, 52, 66, 82, 100, 120, 145]
const SECTORS := ["fin", "rh", "jur", "ti"]
const DAY_SECONDS := 240.0
const CLOCK_SCRIPT := preload("res://scripts/workos/game_clock.gd")
var clock: RefCounted
var data: Dictionary
var profile: Dictionary = {"name": "Funcionário", "id": 1000, "language": "pt", "difficulty": "normal", "wallet": 0, "decor": [], "stats": {}, "best": 0, "career_number": 0}
var career: Dictionary = {}
var quests: Dictionary = {"active": {}, "done": {}, "pins": [], "unlocks": [], "ach": {}}
var social: Dictionary = {}
var arcade: Dictionary = {}
var file: Dictionary = {}
var tasks: Array = []
var events: Dictionary = {}
var focused := false
var paused := true
var fast := false
var next_task := 4.0
var next_event := 20.0
var next_coffee := 30.0
var coffee_time := 0.0
var slow_time := 0.0
var autosave := 0.0
var task_id := 0
var save_error := ""
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	clock = CLOCK_SCRIPT.new(self)
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	rng.randomize()
	profile.id = rng.randi_range(1000, 9999)
	_load_save()

func texts() -> Dictionary:
	return data.languages.get(profile.language, data.languages.pt)

func _load_save() -> void:
	if not FileAccess.file_exists(SAVE): return
	var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if not result is Dictionary or result.get("version", 0) != 1:
		save_error = "Save incompatível ou inválido; arquivo preservado."
		return
	profile.merge(result.get("profile", {}), true)
	career = result.get("career", {})
	quests.merge(result.get("quests", {}), true)
	social = result.get("social", {})
	arcade = result.get("arcade", {})
	file = result.get("file", {})
	tasks = result.get("tasks", [])
	events = result.get("events", {})
	next_task = float(result.get("next_task", 4.0))
	next_event = float(result.get("next_event", 20.0))
	for task in tasks:
		task.holding = false
		task_id = maxi(task_id, int(task.id))
	paused = true

func save_game() -> bool:
	if not save_error.is_empty(): return false
	var payload := {"version": 1, "profile": profile, "career": career, "quests": quests, "social": social, "arcade": arcade, "file": file, "tasks": tasks, "events": events, "next_task": next_task, "next_event": next_event}
	var stream := FileAccess.open(SAVE + ".tmp", FileAccess.WRITE)
	if stream == null:
		notice.emit("Não foi possível gravar o progresso.")
		return false
	stream.store_string(JSON.stringify(payload))
	stream.flush()
	stream.close()
	# Retain the previous completed write before replacing the save.
	if FileAccess.file_exists(SAVE):
		DirAccess.copy_absolute(SAVE, SAVE + ".bak")
	var error := DirAccess.rename_absolute(SAVE + ".tmp", SAVE)
	if error != OK:
		notice.emit("Falha ao substituir o save; cópia temporária preservada.")
	return error == OK

func new_career() -> void:
	if not save_error.is_empty():
		notice.emit(save_error)
		return
	profile.career_number += 1
	stat("careers")
	career = {"phase": "ready", "day": 1, "score": 0, "day_score": 0, "rank": 0, "stress": 0.0, "combo": 0, "time": 0.0, "perks": [], "today": [], "inv": {"cafe": 0, "cha": 0}, "order": [0, 1, 2, 3], "promo_day": 0, "break_day": 0, "debut": [], "mod": "first", "causes": {}, "summary": {}, "ponto": {"day": 1, "in": true}}
	file.clear()
	tasks.clear()
	events.clear()
	paused = true
	career_started.emit()
	save_game()
	changed.emit()

func start_day() -> void:
	if career.is_empty(): return
	if career.phase == "day":
		paused = false
		changed.emit()
		return
	if not career.phase in ["ready", "ended"]: return
	if not punched_in():
		notice.emit("Registre a entrada no relógio de ponto antes de começar o expediente.")
		return
	if career.phase == "ended": career.day += 1
	career.merge({"phase": "day", "on_break": false, "time": 0.0, "day_score": 0, "combo": 0, "stress": 0.0, "order": [0, 1, 2, 3], "debut": [], "causes": {}}, true)
	career.mod = "first" if career.day == 1 else ["sexta", "fecha", "home", "ar", "ti", "segunda", "audit"].pick_random()
	clock.begin_day()
	tasks.clear()
	events.clear()
	next_task = 4
	next_event = 20
	next_coffee = rng.randf_range(25, 40)
	coffee_time = 0
	slow_time = 0
	paused = false
	spawn_file()
	save_game()
	changed.emit()

func active() -> bool:
	return not career.is_empty() and career.phase == "day" and not paused and focused and not career.get("on_break", false)

## Relógio de ponto 3D: a entrada vale para o dia que vai começar; a saída só depois do expediente.
func punched_in() -> bool:
	var ponto: Dictionary = career.get("ponto", {"day": clock.today(), "in": true})
	return ponto.get("in", false) and int(ponto.get("day", 0)) == clock.today()

func on_premises() -> bool:
	return career.is_empty() or career.get("ponto", {"in": true}).get("in", false)

func punch() -> String:
	if career.is_empty(): return "Sem carreira ativa no Portal RH."
	if on_premises():
		if career.phase in ["day", "promotion"]: return "Expediente em andamento: a saída é às 18:00."
		career.ponto = {"day": int(career.get("ponto", {}).get("day", clock.today())), "in": false}
		save_game()
		changed.emit()
		return "Saída registrada às %s. Você pode ir embora." % clock.text()
	if career.phase == "ended" and int(career.get("slept", 0)) != clock.today():
		return "Você ainda não descansou. Vá para casa dormir antes do próximo expediente."
	career.ponto = {"day": clock.today(), "in": true}
	save_game()
	changed.emit()
	return "Entrada registrada · dia %d · %s · %s." % [clock.today(), clock.date_text(), clock.text(clock.arrival())]

## Casa: dormir só depois do expediente e com a saída registrada; acordar já é a manhã do dia seguinte.
func can_sleep() -> String:
	if career.is_empty() or career.phase != "ended": return "Ainda não é hora de dormir: o expediente de hoje não terminou."
	if int(career.get("slept", 0)) == clock.today(): return "Você já descansou. Hora de ir para o escritório."
	return ""

func sleep() -> void:
	if not can_sleep().is_empty(): return
	career.slept = clock.today()
	save_game()
	changed.emit()

## Mercado (porte de src/js/16-mercado.js e 17-caixa.js): consumo vai para o inventário, itens "do dia" valem
## para o próximo expediente e enfeites ficam no perfil.
func shop_item(id: String) -> Dictionary:
	for item in data.shop:
		if item.id == id: return item
	return {}

func shop_name(id: String) -> Array:
	return texts().get("shop", {}).get(id, [id, ""])

func can_add(id: String, cart: Array) -> bool:
	var item := shop_item(id)
	if item.is_empty(): return false
	if item.kind == "decor": return not id in profile.decor and not id in cart
	if item.kind == "day": return not id in career.get("today", []) and not id in cart
	return true

func cart_total(cart: Array) -> int:
	var total := 0
	for id in cart: total += int(shop_item(id).get("price", 0))
	return total

func buy(cart: Array) -> String:
	if cart.is_empty(): return "A cesta está vazia."
	if career.is_empty(): return "Sem carreira ativa no Portal RH."
	var total := cart_total(cart)
	if total > int(profile.wallet): return str(texts().ui.get("overBudget", "Saldo insuficiente."))
	profile.wallet -= total
	var decor := false
	for id in cart:
		var item := shop_item(id)
		match str(item.kind):
			"use": career.inv[id] = int(career.inv.get(id, 0)) + 1
			"day": career.today.append(id)
			"decor":
				if not id in profile.decor:
					profile.decor.append(id)
					decor = true
	stat("buy", cart.size())   # missão do amigo secreto (só conta dentro do período do evento)
	if decor: decor_changed.emit(profile.decor)
	save_game()
	changed.emit()
	return "%s · R$ %d" % [texts().ui.get("approved", "APROVADO"), total]

## Intervalo (Analista em diante, uma vez por dia): congela o expediente por 45 s reais = 1 h simulada.
func break_available() -> bool:
	return career.get("phase", "") == "day" and clock.break_unlocked() and int(career.get("break_day", 0)) != day() 		and not career.get("on_break", false) and not events.has("boss") and not events.has("virus") and not events.has("freeze") and clock.break_window()

## Debug: avança o expediente `minutes` simulados (ou até 18:00) sem esperar.
func debug_advance(minutes: float) -> String:
	if career.get("phase", "") != "day": return "Debug: nenhum expediente em andamento."
	end_break()
	career.time = minf(DAY_SECONDS, float(career.time) + clock.work_seconds(minutes))
	if career.time >= DAY_SECONDS:
		finish_day()
		return "Debug: expediente encerrado às 18:00."
	changed.emit()
	return "Debug: agora são %s." % clock.text()

func start_break() -> bool:
	if not break_available(): return false
	clock.break_start()
	career.break_day = day()
	career.on_break = true
	fast = false
	for task in tasks: task.holding = false
	notice.emit("Intervalo: o expediente volta em 45 segundos.")
	changed.emit()
	return true

func end_break() -> void:
	if not career.get("on_break", false): return
	clock.break_end()
	career.on_break = false
	save_game()
	changed.emit()

func set_focus(value: bool) -> void:
	focused = value
	if not value:
		fast = false
		for task in tasks: task.holding = false
		save_game()

func day() -> int:
	return int(career.get("day", 1))

func level() -> int:
	return mini(12, 1 + floori((day() - 1) * 0.35) + floori(float(career.get("time", 0)) * 150.0 / 240.0 / 50.0))

func difficulty(key: String) -> float:
	var base: float = data.difficulties.get(profile.difficulty, data.difficulties.normal)[key]
	var ease: float = [0.7, 0.8, 0.9][day() - 1] if day() <= 3 else 1.0
	if key == "ttl": return base / ease
	if key == "fall": return base * (0.85 + 0.15 * ease)
	return base * ease

func has_perk(id: String) -> bool:
	return id in career.get("perks", []) or id in career.get("today", [])

func available(id: String) -> bool:
	var debut: int = int(data.debut.get(id, 999))
	return day() > debut or (day() == debut and float(career.get("time", 0)) >= 20)

func frequency(id: String) -> float:
	return minf(1.0, 0.3 + 0.14 * (day() - int(data.debut[id]))) if available(id) else 0.0

func _process(delta: float) -> void:
	if not career.is_empty() and career.get("phase", "") == "day" and career.get("on_break", false):
		if clock.break_tick(delta): end_break()
		return
	if not active(): return
	var dt := minf(delta, 0.05)
	career.time += dt
	if career.time >= DAY_SECONDS:
		finish_day()
		return
	clock.work_tick()
	var sdt := dt * (0.4 if slow_time > 0 else 1.0) * (0.85 if career.mod == "sexta" else 1.0)
	slow_time = maxf(0, slow_time - dt)
	coffee_time = maxf(0, coffee_time - dt)
	if not file.is_empty():
		var speed := (55.0 + level() * 14) * (1.6 if file.kind == "urgent" else 1.0) * (6.0 if fast and not events.has("freeze") else 1.0) * (0.85 if has_perk("bandeja") else 1.0) * difficulty("fall")
		file.y += speed * sdt / 420.0
		if file.y >= 1.0: land_file()
	next_task -= sdt * difficulty("tasks") * (1.35 if career.mod == "segunda" else 1.0)
	if next_task <= 0:
		spawn_task()
		next_task = (7.5 - 4 * clampf((day() - 1) / 24.0, 0, 1)) * 1.25 * rng.randf_range(0.7, 1.3)
	next_event -= sdt * difficulty("events")
	if next_event <= 0:
		spawn_event()
		next_event = (22 - 9 * clampf((day() - 1) / 24.0, 0, 1)) * 1.25 * rng.randf_range(0.7, 1.3)
	next_coffee -= dt
	if next_coffee <= 0 and level() >= 2:
		coffee_time = 6
		next_coffee = rng.randf_range(25, 40) * (0.5 if has_perk("cafeteira") else 1.0)
	for task in tasks.duplicate():
		if task.type == "call" and task.holding:
			task.held += dt
			if task.held >= task.need: complete_task(task.id, 30, "calls")
		else: task.life += sdt
		if task.life >= task.ttl: fail_task(task.id, 12, "Prazo perdido")
	if events.has("boss"):
		events.boss -= dt
		if events.boss <= 0:
			events.erase("boss")
			fail(30, "O chefe flagrou você", "boss")
	if events.has("shuffle"):
		events.shuffle -= dt
		if events.shuffle <= 0:
			events.erase("shuffle")
			career.order.shuffle()
	if events.has("freeze"): add_stress(2.5 * dt)
	if events.has("virus"): add_stress(float(events.virus) * 0.7 * dt)
	if career.mod == "ar": add_stress(0.9 * dt)
	add_stress(-0.8 * dt * (2 if has_perk("terapia") else 1))
	_debut()
	_check_promotion()
	autosave += dt
	if autosave >= 5:
		autosave = 0
		save_game()
	changed.emit()

func spawn_file(forced := "") -> void:
	var sector: String = SECTORS.pick_random()
	var kind := forced
	if kind.is_empty():
		kind = "dead" if rng.randf() < 0.15 * frequency("dead") else ("urgent" if rng.randf() < 0.2 * frequency("urgent") else "normal")
	if kind == "normal" and career.mod == "fecha" and sector == "fin" and available("urgent") and rng.randf() < 0.5: kind = "urgent"
	file = {"sector": sector, "kind": kind, "lane": rng.randi_range(0, 3), "y": -0.14, "name": texts().docs[sector].pick_random()}
	fast = false

func move_file(lane: int) -> void:
	if active() and not events.has("freeze"): file.lane = clampi(lane, 0, 3)

func land_file() -> void:
	if file.kind == "dead": fail(12, "Documento morto deve ser excluído", "dead")
	elif SECTORS[int(career.order[int(file.lane)])] == file.sector:
		success(20 if file.kind == "urgent" else 10)
		stat("files")
	else: fail(26 if file.kind == "urgent" else 14, "Setor incorreto", "wrong")
	spawn_file()

func delete_file() -> void:
	if not active() or events.has("freeze"): return
	if file.kind == "dead": success(12)
	else: fail(18, "Documento válido excluído", "del")
	spawn_file()

func success(base: int) -> void:
	career.combo += 1
	var multiplier := mini(3 + (1 if has_perk("meta") else 0), 1 + int(career.combo) / 8)
	var points := roundi(base * (1 + mini(level() - 1, 8) * 0.1) * multiplier * (1.3 if career.mod == "audit" else 1.0))
	career.score += points
	career.day_score += points
	profile.best = maxi(int(profile.best), int(career.score))
	add_stress(-2)

func add_stress(amount: float) -> void:
	if career.is_empty(): return
	career.stress = clampf(float(career.stress) + amount * (difficulty("stress") if amount > 0 else 1.0), 0, 100)
	if career.stress >= 100 and career.phase == "day":
		career.phase = "burnout"
		paused = true
		profile.wallet += 2 * SALARY[int(career.rank)]
		notice.emit("Fim da carreira: burnout. Rescisão creditada.")
		save_game()
		changed.emit()

func fail(amount: float, message: String, cause := "deadline") -> void:
	career.combo = 0
	career.causes[cause] = float(career.causes.get(cause, 0)) + amount
	add_stress(amount * (1.3 if career.mod == "audit" else 1.0))
	notice.emit(message)

func stat(key: String, count := 1) -> void:
	profile.stats[key] = int(profile.stats.get(key, 0)) + count
	for id in quests.active:
		var quest: Dictionary = quests.active[id]
		if day() <= int(quest.end): quest.progress[key] = int(quest.progress.get(key, 0)) + count
	check_quests()

func spawn_task(forced := "") -> bool:
	if tasks.size() >= mini(5, ceili(day() / 5.0)): return false
	var options: Array = []
	for type in ["button", "email", "type", "call", "printer", "video"]:
		if available(type) and not tasks.any(func(t: Dictionary) -> bool: return t.type == type and type in ["type", "call", "video"]): options.append(type)
	var aliases := {"sector": "button", "complex": "button", "spam": "email", "call2": "call", "printer2": "printer", "video2": "video"}
	var type: String = aliases.get(forced, forced) if not forced.is_empty() else ("" if options.is_empty() else options.pick_random())
	if not type in options: return false
	task_id += 1
	var speed := (1.15 - 0.35 * clampf((day() - 1) / 24.0, 0, 1)) * difficulty("ttl") * (1.2 if has_perk("secretaria") else 1.0) * (1.25 if has_perk("postit") else 1.0)
	var task := {"id": task_id, "type": type, "variant": "", "life": 0.0, "ttl": 7.0, "holding": false, "held": 0.0, "step": 0, "sector": SECTORS.pick_random(), "text": "", "need": 1, "hits": 0}
	match type:
		"button":
			task.text = texts().buttons.pick_random()
			if forced == "complex" or rng.randf() < frequency("complex"):
				task.variant = "complex"
				task.ttl = 12
			elif forced == "sector" or rng.randf() < frequency("sector"):
				task.variant = "sector"
				task.ttl = 8
		"email":
			task.ttl = 11
			task.text = texts().emails.keys().pick_random()
			task.sector = texts().emails[task.text]
			if forced == "spam" or rng.randf() < 0.4 * frequency("spam"):
				task.variant = "spam"
				task.text = texts().ui.prog.spamSubj.pick_random()
				task.sector = "spam"
		"type":
			task.text = texts().words.pick_random()
			task.ttl = 5 + task.text.length() * 0.8
		"call":
			task.text = texts().callers.pick_random()
			var hard := forced == "call2" or rng.randf() < frequency("call2")
			task.need = rng.randf_range(1.6, 3) * (1.7 if hard else 1.0) * (0.5 if has_perk("fone") else 1.0)
			task.ttl = 12 if hard else 9
		"printer":
			task.keys = ["Q", "W"] if forced == "printer2" or rng.randf() < frequency("printer2") else ["Q"]
			task.need = rng.randi_range(6, 11)
			if has_perk("estagiario"): task.need = ceili(task.need / 2.0)
			task.ttl = 4 + task.need * 0.45
		"video":
			task.ttl = 8
			task.text = "Convite de reunião"
	task.ttl *= speed
	tasks.append(task)
	task_changed.emit()
	return true

func get_task(id: int) -> Dictionary:
	for task in tasks:
		if int(task.id) == id: return task
	return {}

func task_action(id: int, value: String) -> void:
	if not active(): return
	var task := get_task(id)
	if task.is_empty(): return
	match task.type:
		"button":
			if task.variant == "complex":
				if value != str(int(task.step)):
					fail_task(id, 8, "Fora de ordem")
					return
				task.step += 1
				if task.step >= 3: complete_task(id, 35)
			elif task.variant == "sector":
				if value == task.sector: complete_task(id, 20)
				else: fail_task(id, 8, "Setor errado")
			else: complete_task(id, 15)
		"email":
			if value == task.sector: complete_task(id, 30 if task.variant == "spam" else 25, "emails")
			else: fail_task(id, 12, "Encaminhamento incorreto")
		"type":
			if value.to_upper() == task.text: complete_task(id, 30, "typed")
		"printer":
			if value.to_upper() == task.keys[int(task.hits) % task.keys.size()]:
				task.hits += 1
				if task.hits >= task.need: complete_task(id, 25)
		"video":
			tasks.erase(task)
			events.video = {"left": 12 if available("video2") else 7, "time": 1.5, "bubble": texts().bubbles.pick_random()}
			task_changed.emit()

func complete_task(id: int, points: int, counter := "") -> void:
	var task := get_task(id)
	if task.is_empty(): return
	tasks.erase(task)
	success(points)
	if not counter.is_empty(): stat(counter)
	task_changed.emit()

func fail_task(id: int, amount: float, message: String) -> void:
	var task := get_task(id)
	if task.is_empty(): return
	tasks.erase(task)
	fail(amount, message)
	task_changed.emit()

func spawn_event(forced := "") -> bool:
	var options: Array = []
	for id in ["boss", "shuffle", "freeze", "virus"]:
		if available(id) and not events.has(id) and not (career.mod == "home" and id in ["boss", "shuffle"]): options.append(id)
	var id: String = forced if not forced.is_empty() else ("" if options.is_empty() else options.pick_random())
	if not id in options: return false
	match id:
		"boss": events.boss = (4.0 if day() <= 5 else maxf(2, 3.2 - (day() - 6) * 0.08)) + (1 if has_perk("relacoes") else 0)
		"shuffle": events.shuffle = 1.3
		"freeze": events.freeze = {"hits": 0, "direction": 0, "need": (12 + (mini(10, 2 * (day() - 16)) if available("it2") else 0)) / (2 if has_perk("mouse") else 1)}
		"virus": events.virus = ceili((5 + (mini(5, day() - 16) if available("it2") else 0)) / (2.0 if has_perk("antivirus") else 1.0))
	notice.emit({"boss": "O chefe está chegando! Abra a planilha.", "shuffle": "As bandejas vão trocar de lugar!", "freeze": "Computador travado: mova o mouse de um lado para o outro.", "virus": "Feche os avisos de vírus pelo X."}[id])
	return true

func dodge_boss() -> void:
	if not active() or not events.has("boss"): return
	events.erase("boss")
	success(20)
	stat("bosses")
	notice.emit("Planilha aberta. O chefe passou.")

func shake_mouse(relative: float) -> void:
	if not active() or not events.has("freeze") or absf(relative) < 6: return
	var state: Dictionary = events.freeze
	var direction := signf(relative)
	if state.direction != 0 and state.direction != direction: state.hits += 1
	state.direction = direction
	if state.hits >= state.need:
		events.erase("freeze")
		success(15)

func close_virus() -> void:
	if not active() or not events.has("virus"): return
	events.virus -= 1
	stat("viruses")
	if events.virus <= 0:
		events.erase("virus")
		success(20)

func use_coffee(free := false) -> void:
	if not active(): return
	if free:
		if coffee_time <= 0: return
		coffee_time = 0
		slow_time = 5
	else:
		if int(career.inv.cafe) <= 0: return
		career.inv.cafe -= 1
		add_stress(-25)
	stat("cafe")

func _debut() -> void:
	if career.time < 20: return
	for id in data.debut:
		if int(data.debut[id]) != day() or id in career.debut: continue
		var done := false
		if id in ["urgent", "dead"]:
			spawn_file(id)
			done = true
		elif id in ["boss", "shuffle", "freeze", "virus"]: done = spawn_event(id)
		elif id == "it2": done = spawn_event("freeze")
		elif id == "crisis":
			done = spawn_event()
			spawn_event()
		else: done = spawn_task(id)
		if done:
			career.debut.append(id)
			notice.emit(str(texts().tips.get(id, id)).replace("<b>", "").replace("</b>", ""))
			return

func _check_promotion() -> void:
	var next := int(career.rank) + 1
	if next < 7 and day() >= RANK_DAYS[next] and career.day_score >= RANK_POINTS[next] - RANK_POINTS[next - 1] and career.promo_day != day():
		career.rank = next
		career.promo_day = day()
		career.phase = "promotion"
		paused = true
		save_game()

func choose_perk(id: String) -> void:
	if career.get("phase", "") != "promotion" or not id in data.perks or id in career.perks: return
	career.perks.append(id)
	career.phase = "day"
	paused = false
	save_game()
	changed.emit()

func finish_day() -> void:
	if career.get("phase", "") != "day": return
	var pay: int = SALARY[int(career.rank)] + mini(30, roundi(float(career.day_score) / 90.0))
	profile.wallet += pay
	career.score += 60
	career.day_score += 60
	career.phase = "won" if day() >= 25 and career.rank == 6 else "ended"
	career.summary = {"day": day(), "pay": pay, "points": career.day_score, "stress": career.stress, "rank": career.rank}
	career.today.clear()
	stat("days")
	for id in quests.active:
		if day() <= quests.active[id].end: quests.active[id].progress.calm = career.stress
	check_quests()
	paused = true
	tasks.clear()
	events.clear()
	save_game()
	day_finished.emit(career.summary)
	changed.emit()

func quest_window(event: Dictionary) -> Vector2i:
	var cycle := floori((day() - 1) / float(data.cycle))
	var jitter := 0
	if int(event.j) > 0: jitter = posmod(int(profile.career_number) * 31 + str(event.id).hash(), int(event.j) * 2 + 1) - int(event.j)
	var start := cycle * int(data.cycle) + int(event.at) + jitter
	return Vector2i(start, start + int(event.len) - 1)

func join_quest(id: String) -> void:
	for event in data.special:
		if event.id != id or quests.done.has(id): continue
		var period := quest_window(event)
		if day() < period.x or day() > period.y: return
		if not quests.active.has(id) or quests.active[id].end < day():
			quests.active[id] = {"end": period.y, "progress": {}}
		check_quests()
		save_game()
		changed.emit()

func sign_quest(id: String) -> void:
	if quests.active.has(id) and quests.active[id].end >= day():
		quests.active[id].progress.sign = 1
		check_quests()
		save_game()

func check_quests() -> void:
	if data.is_empty(): return
	for event in data.special:
		if quests.done.has(event.id) or not quests.active.has(event.id): continue
		var active_quest: Dictionary = quests.active[event.id]
		if day() > active_quest.end: continue
		var done := true
		for step in event.steps:
			var value: float = float(active_quest.progress.get(step[0], 0))
			if step[0] == "decor": value = profile.decor.size()
			if step[0] == "calm": done = done and active_quest.progress.has("calm") and value < float(step[1])
			else: done = done and value >= float(step[1])
		if done:
			quests.done[event.id] = day()
			if not event.pin in quests.pins: quests.pins.append(event.pin)
			if event.has("unlock") and not event.unlock in quests.unlocks: quests.unlocks.append(event.unlock)
			notice.emit("Missão concluída: " + str(texts().ui.ev.names[event.id]))
	var counters := {"d1": ["days", 1], "d10": ["days", 10], "d50": ["days", 50], "f500": ["files", 500], "f3000": ["files", 3000], "e100": ["emails", 100], "c50": ["calls", 50], "v25": ["viruses", 25], "b10": ["bosses", 10]}
	for id in counters:
		if int(profile.stats.get(counters[id][0], 0)) >= counters[id][1]: unlock_achievement(id)
	for pair in [["r1", 1], ["r4", 4], ["r6", 6]]:
		if int(career.get("rank", 0)) >= pair[1]: unlock_achievement(pair[0])
	if profile.decor.size() >= 5: unlock_achievement("dec5")
	if quests.done.size() >= 3: unlock_achievement("q3")
	if quests.pins.size() >= data.pins.size(): unlock_achievement("all")

func unlock_achievement(id: String) -> void:
	if not quests.ach.has(id):
		quests.ach[id] = Time.get_datetime_string_from_system()
		notice.emit("Conquista: " + str(texts().ui.ev.ach[id][0]))

func export_backup() -> String:
	save_game()
	return FileAccess.get_file_as_string(SAVE) if FileAccess.file_exists(SAVE) else ""

func _exit_tree() -> void:
	save_game()
