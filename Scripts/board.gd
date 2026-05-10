extends TextureRect

@export var textures : Array[CompressedTexture2D]

var piece_scene : PackedScene = preload("res://Scenes/piece.tscn")
var pieces : Array[Piece]

var boards : PackedInt64Array = [65280, 66, 36, 129, 8, 16, 71776119061217280, 4755801206503243776, 2594073385365405696, -9151314442816847872, 576460752303423488, 1152921504606846976]

var is_white_turn : bool = true
var is_white_player : bool = true

var castle_rights : Array[bool] = [true, true, true, true]

var engine_thread : Thread
var is_engine_thinking : bool

signal move_piece(start_pos : Vector2, end_pos : Vector2)
signal delete_piece(pos : Vector2)

func _board_pos_to_grid_pos(position : Vector2) -> int:
	var tile_size : Vector2 = size / 8.0
	
	var aligned_pos : Vector2i = (position / tile_size).round()
	if is_white_player:
		aligned_pos.y = 7 - aligned_pos.y
	
	return aligned_pos.x + aligned_pos.y * 8
	
func _grid_pos_to_board_pos(position : int) -> Vector2:
	var tile_size : Vector2 = size / 8.0
	var aligned_pos : Vector2i = Vector2i(position % 8, floori(position / 8.0))
	
	if is_white_player:
		aligned_pos.y = 7 - aligned_pos.y
	
	return Vector2(aligned_pos) * tile_size

func _instantiate_piece(texture : CompressedTexture2D, pos : Vector2, piece_type : int) -> void:
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
	piece.is_draggable = (piece_type < 6) == is_white_player
	
func _instantiate_pieces() -> void:
	for i in boards.size():
		for j in range(64):
			if (boards[i] >> j) & 1 == 1:
				_instantiate_piece(textures[i], _grid_pos_to_board_pos(j), i)

func _make_move(move : int) -> void:
	if ChessEngine.is_move_legal(move, boards, castle_rights, is_white_turn):
		# Move rook piece if move was castling
		if ChessEngine.is_move_castle(move):
			var rook_from : int
			var rook_to : int
			match move >> 6 & 63:
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
					
			move_piece.emit(_grid_pos_to_board_pos(rook_from), _grid_pos_to_board_pos(rook_to))
		delete_piece.emit(_grid_pos_to_board_pos(move >> 6 & 63))
		move_piece.emit(_grid_pos_to_board_pos(move & 63), _grid_pos_to_board_pos(move >> 6 & 63))
		
		ChessEngine.apply_move(move, boards, PackedInt64Array([0,0,0,0,0,0,0,0,0,0,0,0]))
		castle_rights = ChessEngine.get_updated_castle_rights(move, castle_rights)
		
		# Change turn
		is_white_turn = !is_white_turn
		if is_white_turn != is_white_player:
			_start_engine(boards.duplicate(), is_white_turn, 4)
	else:
		move_piece.emit(_grid_pos_to_board_pos(move & 63), _grid_pos_to_board_pos(move & 63))

func _on_engine_finished(move : int) -> void:
	is_engine_thinking = false
	if engine_thread and engine_thread.is_started():
		engine_thread.wait_to_finish()
		
	if move != -1:
		_make_move(move)

func _run_engine(boards_copy : PackedInt64Array, is_white_turn : bool, depth : int, castle_rights : Array[bool]) -> void:
	var move : int = ChessEngine.find_best_move(boards_copy, is_white_turn, 2500, castle_rights)
	
	call_deferred("_on_engine_finished", move)

func _start_engine(boards_copy : PackedInt64Array, is_white_turn : bool, depth : int) -> void:
	if is_engine_thinking:
		return
	is_engine_thinking = true
	engine_thread = Thread.new()
	engine_thread.start(_run_engine.bind(boards_copy, is_white_turn, depth, castle_rights.duplicate()))

func _ready() -> void:
	await get_tree().process_frame
	_instantiate_pieces()
	
	if !is_white_player:
		_start_engine(boards.duplicate(), is_white_turn, 4)
		
func _on_picked(pos : Vector2, piece : Piece) -> void:
	pass

func _on_placed(pos : Vector2, last_pos : Vector2, piece_type : int) -> void:
	if is_engine_thinking:
		move_piece.emit(_grid_pos_to_board_pos(_board_pos_to_grid_pos(last_pos)), _grid_pos_to_board_pos(_board_pos_to_grid_pos(last_pos)))
		return
	else:
		var move : int = Move.create(_board_pos_to_grid_pos(last_pos), _board_pos_to_grid_pos(pos), piece_type)
		_make_move(move)
		
func _exit_tree() -> void:
	if engine_thread and engine_thread.is_started():
		engine_thread.wait_to_finish()
