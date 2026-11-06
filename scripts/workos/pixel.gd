extends RefCounted
## Sprites em pixel art do WorkOS (porte de shared/20-pixel.js): cada desenho em texto vira uma textura 1:1,
## ampliada só por escala inteira (filtro "nearest"). Tabelas vindas de assets/data/workos_ui.json
## (tools/export_workos_ui.cjs) e a paleta fechada WD_PAL de assets/data/workday_original.json.

const UI_PATH := "res://assets/data/workos_ui.json"
const DATA_PATH := "res://assets/data/workday_original.json"
## Rampas dos setores (WD_SECTOR_RAMP): trocam F/f/9 nos glifos e no documento do Portal RH.
const SECTOR_RAMPS := {"fin": ["#a9dccf", "#5fa79a", "#2f6f78"], "rh": ["#c3d5ff", "#6f93d9", "#44609f"], "jur": ["#ffd0b0", "#f0915f", "#c25f3b"], "ti": ["#e0cff7", "#a983d6", "#7656a8"]}

static var _ui: Dictionary = {}
static var _palette: Dictionary = {}
static var _cache: Dictionary = {}

static func ui() -> Dictionary:
	if _ui.is_empty():
		_ui = JSON.parse_string(FileAccess.get_file_as_string(UI_PATH))
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		for key in data.palette: _palette[key] = Color(data.palette[key])
	return _ui

static func palette() -> Dictionary:
	ui()
	return _palette

## Textura de um desenho em texto. `overrides` troca letras da paleta (ex.: rampa de setor).
static func texture(rows: Array, scale := 1, overrides: Dictionary = {}) -> Texture2D:
	if rows.is_empty(): return null
	var key := "%s|%d|%s" % [str(rows.hash()), scale, str(overrides)]
	if _cache.has(key): return _cache[key]
	var colors := palette().duplicate()
	for letter in overrides: colors[letter] = Color(overrides[letter])
	var width := 1
	for row in rows: width = maxi(width, str(row).length())
	var image := Image.create(width * scale, rows.size() * scale, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var letter := row[x]
			if colors.has(letter): image.fill_rect(Rect2i(x * scale, y * scale, scale, scale), colors[letter])
	var result := ImageTexture.create_from_image(image)
	_cache[key] = result
	return result

static func sector_overrides(sector: String) -> Dictionary:
	if not SECTOR_RAMPS.has(sector): return {}
	var ramp: Array = SECTOR_RAMPS[sector]
	return {"f": ramp[0], "F": ramp[1], "9": ramp[2]}

static func menu_icon(id: String, scale := 2) -> Texture2D:
	return texture(ui().menu_icons.get(id, []), scale)

static func orb(scale := 3) -> Texture2D:
	return texture(ui().orb, scale)

static func os_pic(id: String, scale := 3) -> Texture2D:
	return texture(ui().os_pics.get(id, []), scale)

static func os_pic_ids() -> Array:
	return ui().os_pics.keys()

static func sprite(id: String, scale := 2, sector := "") -> Texture2D:
	var table: Dictionary = ui().sprites2
	var rows: Variant = table.get(id, ui().sprites.get(id, []))
	if not rows is Array: return null
	return texture(rows, scale, sector_overrides(sector))

## Ícones dos aplicativos como no original (osIcons/APP_ICO): o Portal RH usa o documento na rampa de TI.
static func app_icon(app: String, scale := 3) -> Texture2D:
	var icons: Dictionary = ui().app_icons
	match app:
		"workday": return sprite("doc", scale, "ti")
		"calendar": return texture(icons.cal, scale)
		"calc": return texture(icons.calc, scale)
		"notes": return texture(icons.notes, scale)
		"music": return texture(icons.music, scale)
		"customize", "settings": return texture(icons.paint, scale)
		"archive": return texture(icons.arq, scale)
		"shop": return texture(icons.shop, scale)
		"messenger": return texture(icons.msn, scale)
		"profile": return menu_icon("prof", scale)
		"backup": return sprite("box", scale)
		"config": return menu_icon("cfg", scale)
		"arcade": return menu_icon("arc", scale)
		"about": return menu_icon("how", scale)
	return menu_icon("app", scale)

## Logotipo WORKDAY (logoCanvas do original): traço de 2 px, miolo claro em três faixas, contorno de tinta e sombra latão.
static func logo(scale := 5) -> Texture2D:
	var key := "logo|%d" % scale
	if _cache.has(key): return _cache[key]
	var glyphs := {"W": ["1100011", "1100011", "1101011", "1101011", "1111111", "1110111", "1100011"], "O": ["011110", "110011", "110011", "110011", "110011", "110011", "011110"],
		"R": ["111110", "110011", "110011", "111110", "111100", "110110", "110011"], "K": ["110011", "110110", "111100", "111000", "111100", "110110", "110011"],
		"D": ["111100", "110110", "110011", "110011", "110011", "110110", "111100"], "A": ["011110", "110011", "110011", "111111", "110011", "110011", "110011"],
		"Y": ["110011", "110011", "011110", "001100", "001100", "001100", "001100"]}
	var word := "WORKDAY"
	var width := 3
	for letter in word: width += glyphs[letter][0].length() + 1
	var height := 11
	var grid := PackedByteArray()
	grid.resize(width * height)
	var cursor := 2
	for letter in word:
		var rows: Array = glyphs[letter]
		for j in rows.size():
			for i in rows[j].length():
				if rows[j][i] == "1": grid[(2 + j) * width + cursor + i] = 1
		cursor += rows[0].length() + 1
	var at := func(i: int, j: int) -> bool: return i >= 0 and j >= 0 and i < width and j < height and grid[j * width + i] == 1
	var colors := palette()
	var rows_out: Array = []
	var image := Image.create(width * scale, height * scale, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for j in height:
		for i in width:
			var color := Color.TRANSPARENT
			if at.call(i, j): color = colors.W if j < 5 else (colors.w if j < 8 else colors.p)
			elif at.call(i - 1, j) or at.call(i + 1, j) or at.call(i, j - 1) or at.call(i, j + 1) or at.call(i - 1, j - 1) or at.call(i + 1, j - 1): color = colors.k
			elif at.call(i - 1, j - 2) or (at.call(i, j - 2) and not at.call(i, j - 1)): color = colors.z
			if color.a > 0: image.fill_rect(Rect2i(i * scale, j * scale, scale, scale), color)
	var result := ImageTexture.create_from_image(image)
	_cache[key] = result
	return result
