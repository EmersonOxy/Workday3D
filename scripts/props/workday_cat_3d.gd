@tool
extends Sprite3D

const COAT_PATHS := [
	"res://assets/workday/cats/laranja.png",
	"res://assets/workday/cats/branco.png",
	"res://assets/workday/cats/cinza-tigrado.png",
	"res://assets/workday/cats/preto.png",
	"res://assets/workday/cats/siames.png",
	"res://assets/workday/cats/frajola.png",
	"res://assets/workday/cats/tricolor.png",
	"res://assets/workday/cats/siames-azul.png",
	"res://assets/workday/cats/preto-verde.png",
	"res://assets/workday/cats/cinza-azul.png",
]

@export_enum("Laranja", "Branco", "Cinza tigrado", "Preto", "Siamês", "Frajola", "Tricolor", "Siamês azul", "Preto e verde", "Cinza azulado") var pelagem := 0:
	set(value):
		pelagem = clampi(value, 0, COAT_PATHS.size() - 1)
		_apply_coat()


func _ready() -> void:
	_apply_coat()


func _apply_coat() -> void:
	var coat_texture := load(COAT_PATHS[clampi(pelagem, 0, COAT_PATHS.size() - 1)]) as Texture2D
	if coat_texture != null:
		texture = coat_texture
