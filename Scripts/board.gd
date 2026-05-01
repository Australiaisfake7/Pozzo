extends TextureRect

@export var textures : Array[CompressedTexture2D]

var piece_scene : PackedScene = preload("res://Scenes/piece.tscn")
var pieces : Array[Piece]

var boards : PackedInt64Array = [65280, 66, 36, 129, 8, 16, 71776119061217280, 4755801206503243776, 2594073385365405696, 9295429630892703744, 576460752303423488, 1152921504606846976]

func is_move_legal(move : Move) -> bool:
	return true

func board_pos_to_grid_pos(position : Vector2) -> int:
	var tile_size : Vector2 = size / 8.0
	var aligned_pos : Vector2i = (position / tile_size).round()
	return aligned_pos.x + aligned_pos.y * 8
	
func grid_pos_to_board_pos(position : int) -> Vector2:
	var tile_size : Vector2 = size / 8.0
	var aligned_pos : Vector2i = Vector2i(position % 8, floori(position / 8.0))
	return Vector2(aligned_pos) * tile_size

func instantiate_piece(texture : CompressedTexture2D, position : Vector2, piece_type : int) -> void:
	var piece_texture : TextureRect = piece_scene.instantiate()
	var piece : Piece = piece_texture.find_child("Button")
	
	add_child(piece_texture)
	piece_texture.texture = texture
	piece_texture.position = position
	piece_texture.size = size / 8.0
	
	piece.place_piece.connect(_on_placed.bind(piece))
	piece.board_pos = position
	piece.piece_type = piece_type
	
func instantiate_pieces() -> void:
	for i in range(12):
		for j in range(64):
			if (boards[i] >> j) & 1 == 1:
				instantiate_piece(textures[i], grid_pos_to_board_pos(j), i)

func _ready() -> void:
	await get_tree().process_frame
	instantiate_pieces()

func _on_picked(position : Vector2, piece : Piece) -> void:
	pass

func _on_placed(position : Vector2, last_pos : Vector2, piece_type : int, piece : Piece) -> void:
	var move : Move = Move.new(board_pos_to_grid_pos(last_pos), board_pos_to_grid_pos(position), piece_type)
	if is_move_legal(move):
		piece.texture.position = grid_pos_to_board_pos(move.end_pos)
	else:
		piece.texture.position = grid_pos_to_board_pos(move.start_pos)
