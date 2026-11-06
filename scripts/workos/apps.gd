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

static func backup(parent: Control, game: Node) -> void:
	var text: TextEdit = parent.get_node("Data")
	text.text = game.export_backup()
	parent.get_node("Refresh").pressed.connect(func() -> void: text.text = game.export_backup())
	parent.get_node("Copy").pressed.connect(func() -> void: DisplayServer.clipboard_set(text.text))
