extends TextureRect

@export var textures : Array[CompressedTexture2D]

var piece_scene : PackedScene = preload("res://Scenes/piece.tscn")
var pieces : Array[Piece]

var boards : PackedInt64Array = [65280, 66, 36, 129, 8, 16, 71776119061217280, 4755801206503243776, 2594073385365405696, 9295429630892703744, 576460752303423488, 1152921504606846976]

signal delete_piece(pos : Vector2)

func board_pos_to_grid_pos(position : Vector2) -> int:
	var tile_size : Vector2 = size / 8.0
	var aligned_pos : Vector2i = (position / tile_size).round()
	return aligned_pos.x + aligned_pos.y * 8
	
func grid_pos_to_board_pos(position : int) -> Vector2:
	var tile_size : Vector2 = size / 8.0
	var aligned_pos : Vector2i = Vector2i(position % 8, floori(position / 8.0))
	return Vector2(aligned_pos) * tile_size

func instantiate_piece(texture : CompressedTexture2D, pos : Vector2, piece_type : int) -> void:
	var piece_texture : TextureRect = piece_scene.instantiate()
	var piece : Piece = piece_texture.find_child("Button")
	
	add_child(piece_texture)
	piece_texture.texture = texture
	piece_texture.size = size / 8.0
	
	piece.place_piece.connect(_on_placed.bind(piece))
	piece.board_pos = pos
	piece.piece_type = piece_type
	piece.move_to(pos)
	delete_piece.connect(piece._on_delete_piece)
	
func instantiate_pieces() -> void:
	for i in boards.size():
		for j in range(64):
			if (boards[i] >> j) & 1 == 1:
				instantiate_piece(textures[i], grid_pos_to_board_pos(j), i)

func _ready() -> void:
	await get_tree().process_frame
	instantiate_pieces()
	if not FileAccess.file_exists("res://Resources/rays.dat"):
		ChessEngine.save_rays_in_file("res://Resources/rays.dat")
	ChessEngine.load_rays()

func _on_picked(pos : Vector2, piece : Piece) -> void:
	pass

func _on_placed(pos : Vector2, last_pos : Vector2, piece_type : int, piece : Piece) -> void:
	var move : Move = Move.new(board_pos_to_grid_pos(last_pos), board_pos_to_grid_pos(pos), piece_type)
	if ChessEngine.is_move_legal(move, boards):
		delete_piece.emit(grid_pos_to_board_pos(move.end_pos))
		for i in range(12):
			boards[i] &= ~(1 << move.end_pos)
		boards[move.type] ^= (1 << move.start_pos | 1 << move.end_pos)
		piece.board_pos = grid_pos_to_board_pos(move.end_pos)
		piece.move_to(piece.board_pos)
	else:
		piece.move_to(grid_pos_to_board_pos(move.start_pos))
