extends RefCounted
## Relógio global do jogo (porte do GameClock de src/js/49-atestado.js do original).
## Três tempos, nunca misturados:
##   • tempo real: relógio do aparelho, só para metadados; nunca aparece no jogo.
##   • tempo de expediente: career.time, segundos de trabalho efetivo (0..DAY_SECONDS); para em pausas e no intervalo.
##   • tempo simulado: data da carreira + minuto do dia (minute()), derivado dos dois acima.
## Data: o dia N da carreira é o N-ésimo dia útil a partir da data inicial (padrão seg 05/01/2026).
## Hora: chegada sorteada entre 07:00 e 07:59 (estável por carreira+dia); expediente das 09:00 às 18:00 em
## DAY_SECONDS de trabalho. Quem tem intervalo (Analista+) recebe um horário sorteado entre 11h e 14h; o intervalo
## dura 45 s reais = 1 h simulada. Com intervalo previsto o trabalho anda 480 min em 240 s; se ele atrasar ou não
## acontecer, o restante é redistribuído até 18:00.

const WORK_IN := 9 * 60
const WORK_OUT := 18 * 60
const BRK_A := 11 * 60
const BRK_B := 14 * 60
const BRK_LEN := 60.0
const BRK_REAL := 45.0
const BREAK_RANK := 2
const EPOCH := [2026, 1, 5]

var game: Node

func _init(state: Node) -> void:
	game = state

func _seeded(seed: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng.randf()

func _career_id() -> int:
	return int(game.profile.get("career_number", 0))

func _clk() -> Dictionary:
	return game.career.get("clk", {})

## Dia da carreira em que a pessoa está ou vai entrar (depois do fim do expediente, o próximo).
func today() -> int:
	return game.day() + (1 if game.career.get("phase", "") == "ended" else 0)

func _start_unix() -> int:
	var start: Array = game.career.get("clock_start", EPOCH)
	return Time.get_unix_time_from_datetime_dict({"year": start[0], "month": start[1], "day": start[2]})

## Data simulada (dicionário de Time) do dia N da carreira: só dias úteis.
func date(day := -1) -> Dictionary:
	if day < 0: day = today()
	var unix := _start_unix()
	var left := maxi(1, day) - 1
	while left > 0:
		unix += 86400
		var weekday := int(Time.get_datetime_dict_from_unix_time(unix).weekday)
		if weekday != 0 and weekday != 6: left -= 1
	return Time.get_datetime_dict_from_unix_time(unix)

func date_text(day := -1) -> String:
	var d := date(day)
	return "%02d/%02d/%04d" % [d.day, d.month, d.year]

func arrival(day := -1) -> float:
	if day < 0: day = today()
	return 7 * 60 + floorf(_seeded(int(game.profile.id) * 977 + _career_id() * 131 + day * 7) * 60)

func break_unlocked() -> bool:
	return int(game.career.get("rank", 0)) >= BREAK_RANK

## Começo do expediente: 09:00; plan = minuto sorteado do intervalo (só quem tem intervalo).
func begin_day() -> void:
	var plan: Variant = null
	if break_unlocked():
		plan = BRK_A + floorf(_seeded(int(game.profile.id) * 541 + _career_id() * 37 + game.day() * 11) * (BRK_B - BRK_A))
	game.career.clk = {"m0": WORK_IN, "t0": 0.0, "plan": plan, "brk": null, "bt": 0.0}

func pending() -> bool:
	var c := _clk()
	return c.get("plan") != null and int(game.career.get("break_day", 0)) != game.day()

## Minuto simulado do momento atual (contínuo).
func minute() -> float:
	var phase := str(game.career.get("phase", ""))
	var c := _clk()
	if phase == "day":
		if c.get("brk") != null: return minf(c.brk + BRK_LEN, c.brk + c.bt * BRK_LEN / BRK_REAL)
		var m0 := float(c.get("m0", WORK_IN))
		var t0 := float(c.get("t0", 0.0))
		var left: float = game.DAY_SECONDS - t0
		var end := WORK_OUT - (BRK_LEN if pending() else 0.0)
		return minf(WORK_OUT, m0 + (maxf(0, float(game.career.time) - t0) * (end - m0) / left if left > 0 else 0.0))
	if phase in ["ended", "promotion", "won", "burnout"]: return WORK_OUT if not c.is_empty() else arrival()
	return arrival()

func text(m := -1.0) -> String:
	if m < 0: m = minute()
	var whole := floori(m)
	return "%02d:%02d" % [whole / 60, whole % 60]

## O restante do expediente passa a ser distribuído a partir de agora, sem salto.
func rebase() -> void:
	var m := minute()
	game.career.clk.m0 = m
	game.career.clk.t0 = float(game.career.time)

func break_window() -> bool:
	var m := minute()
	return m >= BRK_A and m < BRK_B

## A cada quadro de trabalho: no horário sorteado, entra no intervalo assim que der; até 14h, senão desiste.
func work_tick() -> void:
	if not pending() or game.career.get("on_break", false): return
	var m := minute()
	if m >= BRK_B:
		rebase()
		game.career.clk.plan = null
		return
	if m >= float(_clk().plan): game.start_break()

func break_start() -> void:
	if _clk().is_empty(): return
	var m := minute()
	game.career.clk.brk = m
	game.career.clk.bt = 0.0

## Devolve true quando os 45 s reais do intervalo acabaram.
func break_tick(dt: float) -> bool:
	var c := _clk()
	if c.get("brk") == null: return false
	c.bt = minf(BRK_REAL, float(c.bt) + dt)
	return c.bt >= BRK_REAL

func break_end() -> void:
	var c := _clk()
	if c.get("brk") == null: return
	var m := minute()
	c.m0 = m
	c.t0 = float(game.career.time)
	c.brk = null
	c.bt = 0.0
