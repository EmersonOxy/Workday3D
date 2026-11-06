extends CanvasLayer
## Painel do mercado 3D: prateleiras por categoria (cesta) e caixa (forma de pagamento).
## Regras de preço, limite e efeito das compras ficam em game_state.gd (can_add, cart_total, buy).

signal closed

const MK_DESK := ["planta", "foto", "lamp", "gato", "trofeu", "cacto", "globo", "livros", "pato"]
const MK_PC := ["monitor", "webcam", "caixas", "adesivos"]
const CATEGORIES := ["use", "desk", "pc", "wall"]

var game: Node
var cart: Array = []
var view := "shelf"
var category := "use"
var method := ""
var root: PanelContainer
var body: VBoxContainer

func setup(state: Node) -> void:
	game = state
	layer = 70
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	root = PanelContainer.new()
	root.custom_minimum_size = Vector2(760, 520)
	root.theme = load("res://scenes/workos/theme.tres")
	center.add_child(root)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	root.add_child(margin)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)
	hide()

func open(target_view: String) -> void:
	view = target_view
	method = ""
	_render()
	show()

func close() -> void:
	hide()
	closed.emit()

func clear_cart() -> void:
	cart.clear()

func _ui(key: String, fallback: String) -> String:
	return str(game.texts().ui.get(key, fallback))

func _in_category(item: Dictionary, cat: String) -> bool:
	match cat:
		"use": return item.kind != "decor"
		"desk": return item.id in MK_DESK
		"pc": return item.id in MK_PC
	return item.kind == "decor" and not item.id in MK_DESK and not item.id in MK_PC

func _label(text: String, parent: Node, size := 18) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func _button(text: String, callback: Callable, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _render() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	var total: int = game.cart_total(cart)
	var top := HBoxContainer.new()
	body.add_child(top)
	_label(_ui("store", "Mercadinho") if view == "shelf" else _ui("checkoutTitle", "Caixa"), top, 26).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label("%s: R$ %d   %s: R$ %d" % [_ui("wallet", "Carteira"), int(game.profile.wallet), _ui("total", "Total"), total], top)
	_button("Fechar (Esc)", close, top)
	if view == "shelf": _render_shelf()
	else: _render_checkout(total)

func _render_shelf() -> void:
	_label(_ui("marketHint", ""), body, 15)
	var tabs := HBoxContainer.new()
	body.add_child(tabs)
	var names: Dictionary = game.texts().ui.get("mkCats", {})
	for cat in CATEGORIES:
		var tab := _button(str(names.get(cat, cat)), func() -> void: category = cat; _render(), tabs)
		tab.disabled = cat == category
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for item in game.data.shop:
		if not _in_category(item, category): continue
		var row := HBoxContainer.new()
		list.add_child(row)
		var info: Array = game.shop_name(item.id)
		_label("%s — %s" % [info[0], info[1]], row, 16).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = item.id
		var add := _button("R$ %d  +" % int(item.price), func() -> void: cart.append(id); _render(), row)
		add.disabled = not game.can_add(id, cart)
	_render_basket()
	var actions := HBoxContainer.new()
	body.add_child(actions)
	_label("Leve a cesta ao caixa, perto da saída.", actions, 15).size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _render_basket() -> void:
	var basket := HFlowContainer.new()
	body.add_child(basket)
	_label("Cesta:" if not cart.is_empty() else "Cesta vazia.", basket, 16)
	for index in cart.size():
		var id: String = cart[index]
		_button(str(game.shop_name(id)[0]) + " ✕", func() -> void: cart.remove_at(index); _render(), basket)

func _render_checkout(total: int) -> void:
	if cart.is_empty():
		_label("Nada na cesta. Pegue os produtos nas prateleiras.", body)
		return
	for id in cart: _label("%s ........ R$ %d" % [game.shop_name(id)[0], int(game.shop_item(id).price)], body, 16)
	var over: bool = total > int(game.profile.wallet)
	_label(_ui("overBudget", "Saldo insuficiente.") if over else _ui("payHint", "Escolha como pagar."), body, 15)
	_render_basket()
	_label(_ui("payWith", "Forma de pagamento"), body)
	var methods := HBoxContainer.new()
	body.add_child(methods)
	for key in ["cash", "card", "pix"]:
		var choice := _button(_ui(key, key), func() -> void: method = key; _render(), methods)
		choice.disabled = method == key
	var pay := _button(_ui("pay", "Pagar"), _pay, body)
	pay.disabled = over or method.is_empty()

func _pay() -> void:
	var result: String = game.buy(cart)
	if result.begins_with(_ui("approved", "APROVADO")): cart.clear()
	_render()
	_label(result, body, 20)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
