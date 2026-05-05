extends TextureRect

@export var textures : Array[CompressedTexture2D]

var piece_scene : PackedScene = preload("res://Scenes/piece.tscn")
var pieces : Array[Piece]

var boards : PackedInt64Array = [65280, 66, 36, 129, 8, 16, 71776119061217280, 4755801206503243776, 2594073385365405696, -9151314442816847872, 576460752303423488, 1152921504606846976]

var is_white_turn : bool = true
var is_white_player : bool = true

signal move_piece(start_pos : Vector2, end_pos : Vector2)
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
	
	piece.place_piece.connect(_on_placed)
	move_piece.connect(piece._on_move_piece)
	delete_piece.connect(piece._on_delete_piece)
	
	piece.piece_type = piece_type
	piece.move_to(pos)
	piece.is_draggable = piece_type < 6 == is_white_player
	
func instantiate_pieces() -> void:
	for i in boards.size():
		for j in range(64):
			if (boards[i] >> j) & 1 == 1:
				instantiate_piece(textures[i], grid_pos_to_board_pos(j), i)

func make_move(move : Move) -> void:
	if ChessEngine.is_move_legal(move, boards, is_white_turn, true):
		# Move rook piece if move was castling
		if ChessEngine.is_move_castle(move):
			var rook_from : int
			var rook_to : int
			match move.end_pos:
				6:  # White kingside
					rook_from = 7
					rook_to = 5
				2:  # White queenside
					rook_from = 0
					rook_to = 3
				62: # Black kingside
					rook_from = 63
					rook_to = 61
				58: # Black queenside
					rook_from = 56
					rook_to = 59
					
			move_piece.emit(grid_pos_to_board_pos(rook_from), grid_pos_to_board_pos(rook_to))
			if is_white_turn:
				boards[3] ^= (1 << rook_from | 1 << rook_to)
			else:
				boards[9] ^= (1 << rook_from | 1 << rook_to)
				
		delete_piece.emit(grid_pos_to_board_pos(move.end_pos))
		
		# Update bitboards
		for i in range(12):
			boards[i] = boards[i] & ~(1 << move.end_pos)
		boards[move.type] = boards[move.type] ^ (1 << move.start_pos | 1 << move.end_pos)
		
		move_piece.emit(grid_pos_to_board_pos(move.start_pos), grid_pos_to_board_pos(move.end_pos))
		
		# Change turn
		is_white_turn = !is_white_turn
		
		if is_white_turn != is_white_player:
			var engine_move : Move = ChessEngine.generate_best_move(boards, is_white_turn)
			make_move(engine_move)
	else:
		move_piece.emit(grid_pos_to_board_pos(move.start_pos), grid_pos_to_board_pos(move.start_pos))
	ChessEngine.print_board(boards)

func _ready() -> void:
	await get_tree().process_frame
	instantiate_pieces()
	ChessEngine.print_board(boards)
	
	if !is_white_player:
		var engine_move : Move = ChessEngine.generate_best_move(boards, is_white_turn)
		make_move(engine_move)
		
func _on_picked(pos : Vector2, piece : Piece) -> void:
	pass

func _on_placed(pos : Vector2, last_pos : Vector2, piece_type : int) -> void:
	var move : Move = Move.new(board_pos_to_grid_pos(last_pos), board_pos_to_grid_pos(pos), piece_type)
	make_move(move)
