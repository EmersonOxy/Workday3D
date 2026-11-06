extends RefCounted
## Linguagem de animação do WorkOS (porte de src/js/shared/40-motion.js): antecipação antes de movimentos grandes,
## impacto com achatamento (squash) e acomodação com sobre-impulso (overshoot). Movimento físico usa curvas suaves;
## o que é "máquina" (recortes de janela, LEDs) usa degraus e fica em os_window.gd.
## Com "reduzir movimento" só a opacidade anima, e mais curta, como no original.

const T_MICRO := 0.09
const T_SHORT := 0.16
const T_MED := 0.26
const T_LONG := 0.42
const T_BEAT := 0.6

static var reduced := false

## Quadro: {"t": 0..1, "off": Vector2 (px), "sc": Vector2, "rot": graus, "a": opacidade}. Valores relativos ao estado atual.
static func frame(t: float, off := Vector2.ZERO, sc := Vector2.ONE, rot := 0.0, a := 1.0) -> Dictionary:
	return {"t": t, "off": off, "sc": sc, "rot": rot, "a": a}

## Equivalente de Motion.play: interpola entre quadros (linear por trecho). `keep` = fill "both": mantém o último quadro;
## sem `keep` (fill "none") o nó volta ao estado inicial. Devolve o Tween (ou null com o nó inválido).
static func play(node: Control, frames: Array, duration: float, keep := false, easing := Tween.TRANS_LINEAR, ease_type := Tween.EASE_OUT) -> Tween:
	if not is_instance_valid(node) or not node.is_inside_tree(): return null
	var base_pos := node.position
	var base_scale := node.scale
	var base_rot := node.rotation
	var base_alpha := node.modulate.a
	node.pivot_offset = node.size / 2.0
	if reduced:
		frames = frames.map(func(f: Dictionary) -> Dictionary: return frame(f.t, Vector2.ZERO, Vector2.ONE, 0.0, f.a))
		duration = minf(duration, 0.12)
	var apply := func(progress: float) -> void:
		if not is_instance_valid(node): return
		var upper := 1
		while upper < frames.size() - 1 and frames[upper].t < progress: upper += 1
		var a: Dictionary = frames[upper - 1]
		var b: Dictionary = frames[upper]
		var span := maxf(b.t - a.t, 0.0001)
		var k := clampf((progress - a.t) / span, 0.0, 1.0)
		node.position = base_pos + (a.off as Vector2).lerp(b.off, k)
		node.scale = base_scale * (a.sc as Vector2).lerp(b.sc, k)
		node.rotation = base_rot + deg_to_rad(lerpf(a.rot, b.rot, k))
		node.modulate.a = base_alpha * lerpf(a.a, b.a, k)
	var tween := node.create_tween()
	tween.tween_method(apply, 0.0, 1.0, duration).set_trans(easing).set_ease(ease_type)
	tween.finished.connect(func() -> void:
		if not is_instance_valid(node): return
		if not keep:
			node.position = base_pos
			node.scale = base_scale
			node.rotation = base_rot
			node.modulate.a = base_alpha)
	return tween

## Chegada: cai do alto, estica no ar, achata no impacto e acomoda.
static func drop_in(node: Control, dist := 18.0) -> Tween:
	return play(node, [frame(0.0, Vector2(0, -dist), Vector2(0.92, 1.12), 0.0, 0.0), frame(0.55, Vector2(0, 2), Vector2(1.12, 0.86)),
		frame(0.78, Vector2(0, -1), Vector2(0.97, 1.04)), frame(1.0)], T_LONG, true)

## Impacto ao pousar (documento na bandeja).
static func squash(node: Control) -> Tween:
	return play(node, [frame(0.0), frame(0.25, Vector2.ZERO, Vector2(1.18, 0.78)), frame(0.55, Vector2.ZERO, Vector2(0.94, 1.06)),
		frame(0.8, Vector2.ZERO, Vector2(1.02, 0.98)), frame(1.0)], T_MED)

## Erro: quica para fora, inclina e treme.
static func reject(node: Control) -> Tween:
	return play(node, [frame(0.0), frame(0.3, Vector2(0, -14), Vector2.ONE, -8.0), frame(0.5, Vector2(-6, -6), Vector2.ONE, 6.0),
		frame(0.68, Vector2(5, -4), Vector2.ONE, -4.0), frame(0.84, Vector2(-2, 0), Vector2.ONE, 2.0), frame(1.0)], T_BEAT)

static func _dir(from: String, distance: float) -> Vector2:
	return {"right": Vector2(distance, 0), "left": Vector2(-distance, 0), "up": Vector2(0, -distance * 0.64), "down": Vector2(0, distance * 0.64)}.get(from, Vector2(distance, 0))

## Entrada de cartão (tarefa, aviso, balão): desliza com sobre-impulso (E.back).
static func enter(node: Control, from := "right") -> Tween:
	return play(node, [frame(0.0, _dir(from, 28.0), Vector2(0.94, 0.94), 0.0, 0.0), frame(1.0)], T_MED, true, Tween.TRANS_BACK, Tween.EASE_OUT)

## Saída com antecipação: cresce um pouco, depois vai (E.anticip). Chama `done` ao terminar.
static func leave(node: Control, to := "right", done := Callable()) -> Tween:
	var tween := play(node, [frame(0.0), frame(0.3, Vector2.ZERO, Vector2(1.04, 1.04)), frame(1.0, _dir(to, 40.0), Vector2(0.9, 0.9), 0.0, 0.0)], T_MED, true, Tween.TRANS_BACK, Tween.EASE_IN)
	if tween != null and done.is_valid(): tween.finished.connect(done)
	elif done.is_valid(): done.call()
	return tween

## Aparece crescendo de 90 % (keyframes pop do CSS). Sem deslocamento: serve para filhos de contêineres.
static func pop(node: Control) -> Tween:
	return play(node, [frame(0.0, Vector2.ZERO, Vector2(0.9, 0.9), 0.0, 0.0), frame(1.0)], T_SHORT, true, Tween.TRANS_BACK, Tween.EASE_OUT)

## Carimbo de concluído: cresce, bate e assenta.
static func stamp(node: Control) -> Tween:
	return play(node, [frame(0.0, Vector2.ZERO, Vector2(2.2, 2.2), -14.0, 0.0), frame(0.55, Vector2.ZERO, Vector2(0.9, 0.9), -8.0), frame(0.8, Vector2.ZERO, Vector2(1.06, 1.06), -9.0),
		frame(1.0, Vector2.ZERO, Vector2.ONE, -8.0)], T_MED, true, Tween.TRANS_CUBIC, Tween.EASE_IN)

## Tremor curto e decrescente (erro, alerta). Força em px.
static func shake(node: Control, strength := 4.0) -> Tween:
	var frames: Array = []
	var offsets := [0.0, -strength, strength * 0.8, -strength * 0.5, strength * 0.3, 0.0]
	for index in offsets.size(): frames.append(frame(float(index) / (offsets.size() - 1), Vector2(offsets[index], 0)))
	return play(node, frames, T_MED)

## Soco: contadores e selos que "batem" ao mudar.
static func punch(node: Control, amount := 1.35) -> Tween:
	return play(node, [frame(0.0), frame(0.3, Vector2.ZERO, Vector2(amount, amount)), frame(0.65, Vector2.ZERO, Vector2(0.95, 0.95)), frame(1.0)], T_MED)

## Texto que sobe e some (+pontos, mensagens).
static func float_text(parent: Control, text: String, at: Vector2, color := Color("2f8a45"), size := 24) -> void:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	item.add_theme_color_override("font_outline_color", Color("2a1f2d"))
	item.add_theme_constant_override("outline_size", 4)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.position = at
	item.modulate.a = 0.0
	parent.add_child(item)
	var tween := play(item, [frame(0.0, Vector2(0, 6), Vector2(0.6, 0.6), 0.0, 0.0), frame(0.2, Vector2(0, -4), Vector2(1.15, 1.15)), frame(0.55, Vector2(0, -10)),
		frame(1.0, Vector2(0, -30), Vector2.ONE, 0.0, 0.0)], 0.9, true)
	if tween != null: tween.finished.connect(item.queue_free)
	else: item.queue_free()

## Pulso de urgência contínuo; devolve o Tween para cancelar (kill).
static func urgent(node: Control) -> Tween:
	if reduced: return null
	var tween := play(node, [frame(0.0), frame(0.1, Vector2.ZERO, Vector2.ONE, -2.0), frame(0.2, Vector2.ZERO, Vector2.ONE, 2.0), frame(0.3, Vector2.ZERO, Vector2.ONE, -1.0),
		frame(0.4), frame(1.0)], 0.9)
	if tween != null: tween.set_loops()
	return tween

## Botão físico: afunda ao pressionar e volta com leve sobre-impulso.
static func press(node: Control) -> Tween:
	return play(node, [frame(0.0), frame(0.35, Vector2(0, 3)), frame(0.75, Vector2(0, -1)), frame(1.0)], T_SHORT)

## Degraus como o steps(n) do CSS.
static func step(t: float, steps: int) -> float:
	return floorf(t * steps) / steps
