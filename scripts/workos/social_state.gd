extends Node

signal changed
signal incoming(npc: String, text: String)
var game: Node
var tick := 0.0
var elapsed := 0.0
var reading := ""
var state: Dictionary

func setup(store: Node) -> void:
	game = store
	state = game.social
	for key in ["contacts", "threads", "done", "arc", "pub", "pk", "prom", "overrides"]:
		if not state.has(key): state[key] = {}
	if not state.has("performance"): state.performance = []
	if not state.has("status"): state.status = "online"
	if not state.has("message"): state.message = ""
	for id in game.data.cast:
		if not state.contacts.has(id): state.contacts[id] = fresh_contact()
		if id in ["lu", "duda"]: state.contacts[id].status = "known"
	game.career_started.connect(_new_career)
	game.day_finished.connect(_day_finished)
	_sync()

func fresh_contact() -> Dictionary:
	return {"status": "none", "since": game.day(), "aff": 0, "trust": 0, "fam": 0, "riv": 0, "f": {}, "choices": {}, "log": [], "unread": 0}

func _new_career() -> void:
	for id in game.data.cast:
		if game.data.cast[id].get("scope", "work") == "work":
			state.contacts[id] = fresh_contact()
			if id == "duda": state.contacts[id].status = "known"
	for id in state.threads.keys():
		if game.data.cast[id].get("scope", "work") == "work": state.threads.erase(id)
	for key in state.done.keys():
		var thread_id := str(key).split("#")[0].split("@")[0]
		if game.data.threads.has(thread_id) and game.data.cast[game.data.threads[thread_id].npc].get("scope", "work") == "work": state.done.erase(key)
	state.performance.clear()
	_sync()

func _day_finished(summary: Dictionary) -> void:
	state.performance.append({"d": summary.day, "score": summary.points, "stress": summary.stress, "rank": summary.rank})
	if state.performance.size() > 30: state.performance.pop_front()
	game.save_game()
	_sync()

func text(value: Variant) -> String:
	if value == null: return ""
	if value is Array:
		var index := maxi(0, ["pt", "en", "es"].find(game.profile.language))
		return str(value[mini(index, value.size() - 1)]) if not value.is_empty() else ""
	return str(value)

func fill(value: Variant) -> String:
	var result := text(value)
	var perf: Dictionary = state.performance.back() if not state.performance.is_empty() else {"score": 0, "stress": 0}
	var vars := {"name": game.profile.name, "day": game.day(), "cyc": cycle() + 1, "score": perf.score, "stress": perf.stress, "rank": game.texts().ranks[int(game.career.get("rank", 0))], "decorN": game.profile.decor.size(), "decor": ", ".join(game.profile.decor), "rafa": rafa_score(), "w": game.arcade.get("wins", 0), "l": game.arcade.get("losses", 0), "dd": game.arcade.get("draws", 0)}
	for key in vars: result = result.replace("{" + key + "}", str(vars[key]))
	for id in game.data.cast: result = result.replace("{n:" + id + "}", str(game.data.cast[id].name).split(" ")[0])
	return result

func cycle() -> int:
	return floori((game.day() - 1) / float(game.data.cycle))

func slot() -> String:
	if game.career.get("phase", "") != "day": return "off"
	var time := float(game.career.time)
	if game.career.get("on_break", false): return "lunch"
	if time < 80: return "am"
	if time < 120: return "lunch"
	return "pm"

func as_list(value: Variant) -> Array:
	if value == null: return []
	return value if value is Array else [value]

func in_range(value: Variant, actual: float) -> bool:
	if value is Array: return actual >= float(value[0]) and actual <= float(value[1])
	return actual >= float(value)

func event_active(id: String) -> bool:
	for event in game.data.special:
		if event.id == id:
			var period: Vector2i = game.quest_window(event)
			return game.day() >= period.x and game.day() <= period.y
	return false

func done(id: String) -> bool:
	for key in state.done:
		if str(key).split("#")[0].split("@")[0] == id: return true
	return false

func relation_matches(relation: Dictionary, spec: Dictionary) -> bool:
	for key in spec:
		if not in_range(spec[key], float(relation.get(key, 0))): return false
	return true

func condition(spec: Variant, npc: String) -> bool:
	if spec == null: return true
	if not spec is Dictionary: return false
	var me: Dictionary = state.contacts[npc]
	for key in spec:
		var value: Variant = spec[key]
		var ok := true
		match key:
			"day": ok = in_range(value, game.day())
			"slot": ok = slot() in as_list(value)
			"working": ok = (game.career.get("phase", "") == "day") == value
			"career": ok = (not game.career.is_empty() and not game.career.get("phase", "") in ["burnout", "resigned", "won"]) == value
			"rank": ok = in_range(value, float(game.career.get("rank", 0)))
			"careers": ok = in_range(value, float(game.profile.career_number))
			"cyc": ok = in_range(value, cycle())
			"ev": ok = as_list(value).any(func(id: String) -> bool: return event_active(id))
			"nev": ok = not as_list(value).any(func(id: String) -> bool: return event_active(id))
			"evDone": ok = game.quests.done.has(value)
			"evJoined": ok = game.quests.active.has(value) or game.quests.done.has(value)
			"evNotJoined": ok = not game.quests.active.has(value) and not game.quests.done.has(value)
			"evPast":
				ok = false
				for event in game.data.special:
					if event.id == value: ok = game.day() > game.quest_window(event).y
			"known", "nknown":
				for id in as_list(value):
					ok = ok and ((state.contacts[id].status == "known") == (key == "known"))
			"k": ok = relation_matches(me, value)
			"kOf":
				for id in value: ok = ok and relation_matches(state.contacts[id], value[id])
			"f", "nf", "pub", "npub", "pk", "npk":
				var negative: bool = str(key).begins_with("n")
				var collection: Dictionary = me.f if key in ["f", "nf"] else (state.pub if key in ["pub", "npub"] else state.pk)
				for flag in as_list(value): ok = ok and (collection.has(flag) != negative)
			"fOf", "nfOf":
				for id in value:
					for flag in as_list(value[id]): ok = ok and (state.contacts[id].f.has(flag) == (key == "fOf"))
			"arc":
				for id in value: ok = ok and state.arc.has(id) and state.arc[id].s in as_list(value[id])
			"narc":
				for id in as_list(value): ok = ok and not state.arc.has(id)
			"arcAge":
				for id in value: ok = ok and state.arc.has(id) and game.day() - state.arc[id].d >= value[id]
			"done", "ndone":
				for id in as_list(value): ok = ok and (done(id) == (key == "done"))
			"doneAge":
				for id in value:
					var when := int(state.done.get(id, state.done.get(id + "#" + str(cycle()), 999999)))
					ok = ok and game.day() - when >= value[id]
			"chose":
				for id in value: ok = ok and me.choices.get(id, "") in as_list(value[id])
			"choseOf":
				for id in value:
					for thread in value[id]: ok = ok and state.contacts[id].choices.get(thread, "") in as_list(value[id][thread])
			"st": ok = state.status in as_list(value)
			"perf": ok = not state.performance.is_empty() and relation_matches(state.performance.back(), value)
			"any": ok = value.any(func(item: Dictionary) -> bool: return condition(item, npc))
			"fn": ok = native_condition(str(value.source_function), npc)
			_: ok = false
		if not ok: return false
	return true

func native_condition(source: String, npc: String) -> bool:
	var perf: Dictionary = state.performance.back() if not state.performance.is_empty() else {}
	if source.contains("!SOC.pre"): return not game.career.is_empty()
	if source.contains("P.decor.length >= 3"): return game.profile.decor.size() >= 3
	if source.contains("P.decor.length < 3"): return game.profile.decor.size() < 3
	if source.contains("ctx.day % 3"): return game.day() % 3 == 0
	if source.contains("socRafaScore"):
		return float(perf.get("score", 0)) >= rafa_score() if source.contains(">=") else float(perf.get("score", 0)) < rafa_score()
	if source.contains("santaGot"): return game.quests.done.has("amigo") or int(game.quests.active.get("amigo", {}).get("progress", {}).get("buy", 0)) > 0
	if source.contains("SOC.pub.promo"): return state.pub.has("promo") and state.pub.promo >= state.arc.get("rafa", {}).get("d", 9999) - 4
	if source.contains("T.w > T.l"): return int(game.arcade.get("wins", 0)) > int(game.arcade.get("losses", 0))
	if source.contains("T.w <= T.l"): return int(game.arcade.get("wins", 0)) <= int(game.arcade.get("losses", 0))
	if source.contains("matchSeen"): return int(game.arcade.get("matches", 0)) > int(state.contacts[npc].get("matchSeen", 0))
	if source.contains("f.bet"): return not perf.is_empty() and int(perf.d) >= int(state.contacts.rafa.f.get("bet", 0))
	if source.contains("ctx.ev.includes"):
		return not perf.is_empty() and (event_active("produtividade") or game.day() % 2 == 0) and game.day() > int(state.contacts.rafa.since)
	if source.contains("since"):
		var days := int(source.get_slice(">=", 1).strip_edges())
		return game.day() - int(state.contacts[npc].since) >= days
	if source.contains("!SOC.perf.length"): return state.performance.is_empty()
	if source.contains("SOC.perf.length"): return not state.performance.is_empty()
	return false

func rafa_score() -> int:
	var base := float(state.performance.back().score) if not state.performance.is_empty() else 1500.0
	return maxi(300, roundi(base * (0.82 + posmod(("rafa" + str(game.day())).hash(), 1000) / 1000.0 * 0.4) / 10) * 10)

func thread_key(thread: Dictionary) -> String:
	return str(thread.id) + ("#" + str(cycle()) if thread.get("perCycle", false) else "") + ("@d" + str(game.day()) if thread.get("daily", false) else "") + ("@c" + str(game.profile.career_number) if thread.get("perCareer", false) else "")

func presence(id: String) -> String:
	var definition: Dictionary = game.data.cast[id]
	if state.contacts[id].status != "known": return "offline"
	if state.overrides.has(id):
		var override: Dictionary = state.overrides[id]
		if game.day() <= int(override.until): return str(override.s)
	if game.career.get("phase", "") == "day":
		for block in definition.get("blocks", []):
				var minute: float = game.clock.minute() - game.clock.WORK_IN
				if minute >= block[0] and minute <= block[1]: return str(block[2])
		return "online" if definition.get("scope", "work") == "work" else "away"
	return "online" if id in ["lu", "duda"] else "away"

func _process(delta: float) -> void:
	if game == null: return
	elapsed += delta
	if elapsed < 1: return
	elapsed = 0
	_sync()

func _sync() -> void:
	for id in game.data.cast:
		var definition: Dictionary = game.data.cast[id]
		if state.contacts[id].status == "none" and definition.has("unlock") and condition(definition.unlock.when, id):
			state.contacts[id].status = "request"
			incoming.emit(id, "Nova solicitação de contato")
	for id in state.threads.keys():
		var thread: Dictionary = state.threads[id]
		if thread.has("due") and game.day() > int(thread.due):
			effects(id, game.data.threads[thread.id].get("ignore"), "")
			state.threads.erase(id)
			continue
		if not thread.queue.is_empty():
			thread.wait -= 1
			if thread.wait <= 0 and presence(id) != "offline":
				log_message(id, false, str(thread.queue.pop_front()))
				thread.wait = 2
				if thread.queue.is_empty(): _after_lines(id)
	for id in state.prom.keys():
		var promise: Dictionary = state.prom[id]
		if game.day() > int(promise.due):
			var met: bool = game.quests.done.has("chefe") or int(game.quests.active.get("chefe", {}).get("progress", {}).get("sign", 0)) > 0
			effects(promise.npc, {"trust": 1 if met else -2, "f": "keptPromise" if met else "brokePromise"}, "")
			state.prom.erase(id)
	var candidates: Array = game.data.threads.values()
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.prio) > int(b.prio))
	for definition in candidates:
		var id: String = definition.npc
		if definition.by != "npc" or state.contacts[id].status != "known" or state.threads.has(id): continue
		if presence(id) != "online" or state.status in ["dnd", "invisible"]: continue
		if state.done.has(thread_key(definition)) or not condition(definition.get("when"), id): continue
		if game.active() and not definition.get("work", false): continue
		start_thread(definition.id)
		break
	changed.emit()

func accept_contact(id: String) -> void:
	state.contacts[id].status = "known"
	state.contacts[id].since = game.day()
	game.save_game()
	_sync()

func log_message(id: String, mine: bool, message: String) -> void:
	var contact: Dictionary = state.contacts[id]
	contact.log.append({"mine": mine, "text": fill(message), "day": game.day()})
	if contact.log.size() > 140: contact.log.pop_front()
	if not mine and reading != id:
		contact.unread += 1
		incoming.emit(id, fill(message))
	game.save_game()
	changed.emit()

func start_thread(id: String) -> void:
	if not game.data.threads.has(id): return
	var definition: Dictionary = game.data.threads[id]
	if state.threads.has(definition.npc): return
	state.done[thread_key(definition)] = game.day()
	state.threads[definition.npc] = {"id": id, "node": definition.start, "queue": [], "wait": 1, "after": null, "due": game.day() + int(definition.ttl), "chosen": false}
	enter_node(definition.npc, definition.start)
	game.save_game()

func lines(items: Array, npc: String) -> Array:
	var output: Array = []
	for line in items:
		if line is Dictionary:
			if not condition(line.get("if"), npc): continue
			output.append(fill(line.pick.pick_random() if line.has("pick") else line.get("t", "")))
		else: output.append(fill(line))
	return output

func enter_node(npc: String, node_id: String) -> void:
	var thread: Dictionary = state.threads[npc]
	var definition: Dictionary = game.data.threads[thread.id]
	if not definition.n.has(node_id):
		finish_thread(npc)
		return
	thread.node = node_id
	var node: Dictionary = definition.n[node_id]
	thread.queue = lines(node.get("say", []), npc)
	thread.after = null
	thread.wait = 1
	thread.phase = "npc"
	effects(npc, node.get("fx"), "")
	if thread.queue.is_empty(): _after_lines(npc)

func go(value: Variant, npc: String) -> String:
	if value == null: return ""
	if value is String: return value
	if value is Array:
		for item in value:
			if item is String: return item
			if condition(item.get("if"), npc): return str(item.get("to", item.get("go", "")))
	return ""

func _after_lines(npc: String) -> void:
	if not state.threads.has(npc): return
	var thread: Dictionary = state.threads[npc]
	var node: Dictionary = game.data.threads[thread.id].n[thread.node]
	if thread.chosen:
		var target := go(thread.after, npc)
		thread.chosen = false
		if target.is_empty(): finish_thread(npc)
		else: enter_node(npc, target)
	elif node.has("ch"):
		thread.phase = "choice"
	else:
		var target := go(node.get("go"), npc)
		if target.is_empty(): finish_thread(npc)
		else: enter_node(npc, target)

func choices(npc: String) -> Array:
	if not state.threads.has(npc): return []
	var thread: Dictionary = state.threads[npc]
	if thread.phase != "choice": return []
	var all: Array = game.data.threads[thread.id].n[thread.node].get("ch", [])
	return all.filter(func(choice: Dictionary) -> bool: return condition(choice.get("if"), npc))

func choose(npc: String, index: int) -> void:
	var available := choices(npc)
	if index < 0 or index >= available.size(): return
	var choice: Dictionary = available[index]
	var thread: Dictionary = state.threads[npc]
	log_message(npc, true, fill(choice.t))
	var tone := str(choice.get("tone", ""))
	var change := effects(npc, choice.get("fx"), tone)
	state.contacts[npc].choices[thread.id] = str(choice.get("k", index))
	var node: Dictionary = game.data.threads[thread.id].n[thread.node]
	var replies: Array = choice.get("re", [])
	if replies.is_empty() and node.has("react"): replies = node.react.get("good" if change > 0 else ("bad" if change < 0 else "meh"), node.react.get("meh", []))
	thread.queue = lines(replies, npc)
	thread.after = choice.get("go")
	thread.phase = "npc"
	thread.chosen = true
	thread.wait = 2
	if thread.queue.is_empty(): _after_lines(npc)
	game.save_game()
	changed.emit()

func finish_thread(npc: String) -> void:
	var thread: Dictionary = state.threads[npc]
	effects(npc, game.data.threads[thread.id].get("end"), "")
	state.contacts[npc].fam = minf(10, float(state.contacts[npc].fam) + 0.5)
	state.threads.erase(npc)
	game.save_game()

func effects(npc: String, fx: Variant, tone: String) -> float:
	var relation: Dictionary = state.contacts[npc]
	var definition: Dictionary = game.data.cast[npc]
	var effect: Dictionary = fx if fx is Dictionary else {}
	var delta := float(definition.likes.get(tone, 0)) + float(effect.get("aff", 0))
	relation.aff = clampf(float(relation.aff) + delta, -10, 10)
	if tone == "tease" and definition.get("rival", false): relation.riv = minf(10, float(relation.riv) + 1)
	for key in ["riv", "fam", "trust"]:
		relation[key] = clampf(float(relation[key]) + float(effect.get(key, 0)), 0, 10)
	if float(effect.get("trust", 0)) > 0: relation.trust = minf(float(relation.trust), 1 + float(relation.fam) * float(definition.get("open", 1)))
	for flag in as_list(effect.get("f")): relation.f[flag] = game.day()
	for flag in as_list(effect.get("uf")): relation.f.erase(flag)
	for key in ["pub", "pk"]:
		for flag in as_list(effect.get(key)): state[key][flag] = game.day()
	if effect.has("arc"): state.arc[effect.arc[0]] = {"s": effect.arc[1], "d": game.day()}
	for id in effect.get("tell", {}):
		for flag in as_list(effect.tell[id]): state.contacts[id].f[flag] = game.day()
	if effect.has("req"):
		var id: String = effect.req if effect.req is String else effect.req.id
		if state.contacts.has(id) and state.contacts[id].status == "none": state.contacts[id].status = "request"
	if effect.has("prom"): state.prom[effect.prom.id] = {"npc": npc, "due": game.day() + int(effect.prom.get("days", 1))}
	if effect.has("ov"): state.overrides[effect.ov.get("id", npc)] = {"s": effect.ov.s, "until": game.day() + int(effect.ov.get("days", 0))}
	for id in effect.get("relOf", {}):
		for key in effect.relOf[id]: state.contacts[id][key] = clampf(float(state.contacts[id].get(key, 0)) + float(effect.relOf[id][key]), -10 if key == "aff" else 0, 10)
	if effect.has("fn"):
		var source: String = effect.fn.source_function
		if source.contains("matchSeen"): relation.matchSeen = game.arcade.get("matches", 0)
		if source.contains("Padeiro"):
			relation.role = ["Padeiro · ex-Financeiro", "Baker · former Finance", "Panadero · ex-Finanzas"]
			relation.group = "other"
	return delta

func topics(npc: String) -> Array:
	var output: Array = []
	for definition in game.data.threads.values():
		if definition.npc != npc or definition.by != "player" or not condition(definition.get("when"), npc): continue
		if state.done.has(thread_key(definition)) and game.day() - int(state.done[thread_key(definition)]) < int(definition.get("repeat", 999999)): continue
		output.append(definition)
	return output

func send_text(npc: String, message: String) -> void:
	message = message.strip_edges().left(500)
	if message.is_empty(): return
	var available := choices(npc)
	for index in available.size():
		if fill(available[index].t).to_lower() == message.to_lower():
			choose(npc, index)
			return
	if not available.is_empty():
		incoming.emit(npc, "Escolha uma das respostas da conversa.")
		return
	log_message(npc, true, message)
	var intent := "unknown"
	var keywords := {"hi": ["oi", "olá", "bom dia"], "thanks": ["obrigad", "valeu"], "sorry": ["desculp", "foi mal"], "bye": ["tchau", "até mais"], "how": ["tudo bem", "como vai"], "joke": ["kkk", "haha", "piada"], "coffee": ["café", "cafe"], "game": ["jogo", "partida", "jogar"], "work": ["trabalh", "chefe", "reunião"]}
	for key in keywords:
		for word in keywords[key]:
			if message.to_lower().contains(word): intent = key
	var replies: Array = game.data.cast[npc].get("intents", {}).get(intent, [])
	if not replies.is_empty(): log_message(npc, false, fill(replies.pick_random()))
	else: log_message(npc, false, "Agora não sei o que dizer. Vamos conversar sobre outro assunto?")
	changed.emit()
