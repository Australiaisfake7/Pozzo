extends Button
class_name Piece

@onready var texture : TextureRect = get_parent()

var is_held : bool
var board_pos : Vector2
var piece_type : int:
	set(value):
		piece_type = clampi(value, 0, 11)

signal place_piece(pos : Vector2, last_pos : Vector2, piece_type : int)

func _on_button_down() -> void:
	is_held = true

func _on_button_up() -> void:
	is_held = false
	place_piece.emit(texture.position, board_pos, piece_type)

func _process(delta: float) -> void:
	if is_held:
		texture.global_position = get_global_mouse_position() - texture.size / 2.0 

func _on_delete_piece(pos : Vector2):
	if texture.position == pos:
		texture.queue_free()

func move_to(pos : Vector2):
	var tween : Tween = create_tween()
	tween.tween_property(texture, "position", pos, 0.1).set_trans(Tween.TRANS_QUAD)
