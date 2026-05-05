class_name ChessEngine

const piece_values : PackedInt64Array = [120, 300, 340, 500, 900, 0]

class Ray:
	enum {ROOK, BISHOP, KNIGHT, INVALID}
	
	var ray : int
	var type : int
	
	func _init(ray : int, type : int) -> void:
		self.ray = ray
		self.type = type

static func _compute_ray(start_pos : int, end_pos : int) -> Ray:
	var ray : Ray
	var start_pos_vec : Vector2i = Vector2i(start_pos % 8, start_pos / 8)
	var end_pos_vec : Vector2i = Vector2i(end_pos % 8, end_pos / 8)
	
	var diff : Vector2i = start_pos_vec - end_pos_vec
	if diff == Vector2i.ZERO: return Ray.new(0, Ray.INVALID)
	
	if abs(diff.x) == abs(diff.y):
		# Is diagonal
		ray = Ray.new(0, Ray.BISHOP)
	elif diff.x == 0 || diff.y == 0:
		# Is straight
		ray = Ray.new(0, Ray.ROOK)
	elif (abs(diff.x) == 1 && abs(diff.y) == 2) || (abs(diff.x) == 2 && abs(diff.y) == 1):
		# Is L shape
		return Ray.new(0, Ray.KNIGHT)
	else:
		return Ray.new(0, Ray.INVALID)

	# Sliding piece calculation
	var length : int = max(abs(diff.x), abs(diff.y))
	for i in range(1, length):
		var pos : Vector2i = end_pos_vec + diff / length * i
		var grid_pos : int = pos.x + pos.y * 8
		ray.ray |= (1 << grid_pos)
	return ray

# Checks for any piece type
static func _is_occupied(pos : int, boards : PackedInt64Array, count_white : bool, count_black : bool) -> bool:
	var white_board : int = boards[0] | boards[1] | boards[2] | boards[3] | boards[4] | boards[5]
	var black_board : int = boards[6] | boards[7] | boards[8] | boards[9] | boards[10] | boards[11]
	var board : int = (white_board if count_white else 0) | (black_board if count_black else 0)
	
	return board >> pos & 1 == 1

# Checks for specific piece type(s)
static func _is_piece_at(pos: int, board: int) -> bool:
	return board >> pos & 1 == 1

static func _pawn_moves(pos : int, boards : PackedInt64Array, is_white_move : bool) -> PackedInt64Array:
	var moves : PackedInt64Array
	var start_rank : int = 1	 if is_white_move else 6
	
	var white_board : int = boards[0] | boards[1] | boards[2] | boards[3] | boards[4] | boards[5]
	var black_board : int = boards[6] | boards[7] | boards[8] | boards[9] | boards[10] | boards[11]
	var all_board : int = white_board | black_board
	
	var file : int = pos % 8
	var rank : int = pos / 8
	
	var direction : int = 1 if is_white_move else -1
	
	if !_is_occupied(file + (rank + direction) * 8, boards, true, true):
		moves.append(file + (rank + direction) * 8)
		if rank == start_rank && !_is_occupied(file + (rank + direction * 2) * 8, boards, true, true):
			moves.append(file + (rank + direction * 2) * 8)
	
	for offset in [-1, 1]:
		var offset_file : int = file + offset
		
		if offset_file < 0 || offset_file >= 8:
			continue
		
		var capture_pos : int = offset_file + (rank + direction) * 8
		if _is_occupied(capture_pos, boards, !is_white_move, is_white_move):
			moves.append(capture_pos)
		
	return moves
	
static func _knight_moves(pos : int, boards : PackedInt64Array, is_white_move : bool) -> PackedInt64Array:
	var moves : PackedInt64Array
	var offsets = [[-2,-1],[-2,1],[-1,-2],[-1,2],[1,-2],[1,2],[2,-1],[2,1]]
	
	var file : int = pos % 8
	var rank : int = pos / 8
	
	for offset in offsets:
		var offset_file : int = file + offset[0]
		var offset_rank : int = rank + offset[1]
		
		if offset_file >= 0 && offset_file < 8 && offset_rank >= 0 && offset_rank < 8 && !_is_occupied(offset_file + offset_rank * 8, boards, is_white_move, !is_white_move):
			moves.append(offset_file + offset_rank * 8)
	
	return moves
	
static func _sliding_moves(pos : int, rook_move : bool, bishop_move : bool, boards : PackedInt64Array, is_white_move : bool) -> PackedInt64Array:
	var moves : PackedInt64Array
	
	var white_board : int = boards[0] | boards[1] | boards[2] | boards[3] | boards[4] | boards[5]
	var black_board : int = boards[6] | boards[7] | boards[8] | boards[9] | boards[10] | boards[11]
	var all_board : int = white_board | black_board
	
	var file : int = pos % 8
	var rank : int = pos / 8
	
	if rook_move:
		for dir in [-1, 1]:
			for amount in range(1, 8):
				var offset : int = dir * amount		
				var offset_file : int = offset + file
				if offset_file < 0 || offset_file >= 8:
					break
			
				var offset_pos : int = offset_file + rank * 8
			
				if _is_occupied(offset_pos, boards, true, true):
					var attacked_piece_is_white : bool = _is_occupied(offset_pos, boards, true, false)
					if attacked_piece_is_white == is_white_move:
						break
					else:
						moves.append(offset_pos)
						break
			
				moves.append(offset_pos)
			
		for dir in [-1, 1]:
			for amount in range(1, 8):
				var offset : int = dir * amount
				var offset_rank : int = offset + rank
				if offset_rank < 0 || offset_rank >= 8:
					break
			
				var offset_pos : int = file + offset_rank * 8
			
				if _is_occupied(offset_pos, boards, true, true):
					var attacked_piece_is_white : bool = _is_occupied(offset_pos, boards, true, false)
					if attacked_piece_is_white == is_white_move:
						break
					else:
						moves.append(offset_pos)
						break
			
				moves.append(offset_pos)
				
	if bishop_move:
		for dir in [-1, 1]:
			for amount in range(1, 8):
				var offset : int = dir * amount
				var offset_file : int = offset + file
				var offset_rank : int = offset + rank
				
				if offset_file < 0 || offset_file >= 8 || offset_rank < 0 || offset_rank >= 8:
					break
			
				var offset_pos : int = offset_file + offset_rank * 8
			
				if _is_occupied(offset_pos, boards, true, true):
					var attacked_piece_is_white : bool = _is_occupied(offset_pos, boards, true, false)
					if attacked_piece_is_white == is_white_move:
						break
					else:
						moves.append(offset_pos)
						break
			
				moves.append(offset_pos)
			
		for dir in [-1, 1]:
			for amount in range(1, 8):
				var offset : int = dir * amount
				var offset_file : int = offset + file
				var offset_rank : int = -offset + rank
				
				if offset_file < 0 || offset_file >= 8 || offset_rank < 0 || offset_rank >= 8:
					break
			
				var offset_pos : int = offset_file + offset_rank * 8
			
				if _is_occupied(offset_pos, boards, true, true):
					var attacked_piece_is_white : bool = _is_occupied(offset_pos, boards, true, false)
					if attacked_piece_is_white == is_white_move:
						break
					else:
						moves.append(offset_pos)
						break
			
				moves.append(offset_pos)
			
	return moves

static func _king_moves(pos : int, boards : PackedInt64Array, is_white_move : bool):
	var moves : PackedInt64Array
	
	var file : int = pos % 8
	var rank : int = pos / 8
	
	for r in range(-1, 2):
		for f in range(-1, 2):
			var offset_file : int = file + f
			var offset_rank : int = rank + r
			
			if offset_file < 0 || offset_file > 7 || offset_rank < 0 || offset_rank > 7:
				continue
			if offset_file == file && offset_rank == rank:
				continue
			
			var offset_pos : int = offset_file + offset_rank * 8
			
			if _is_occupied(offset_pos, boards, is_white_move, !is_white_move):
				continue
			
			moves.append(offset_pos)
			
	return moves

static func _is_check(boards : PackedInt64Array, is_white_turn : bool) -> bool:
	# is_white_turn represents side being checked for check, i.e. the one currently moving
	
	var white_board : int = boards[0] | boards[1] | boards[2] | boards[3] | boards[4] | boards[5]
	var black_board : int = boards[6] | boards[7] | boards[8] | boards[9] | boards[10] | boards[11]
	var all_board : int = white_board | black_board
	
	# Index shift to current side's boards
	# Use 6 - offset to get opponents boards
	var color_offset : int = 0 if is_white_turn else 6 
	
	var king_pos : int = 0
	for i in range(64):
		if _is_piece_at(i, boards[5 + color_offset]):
			king_pos = i
			break

	for pos in _knight_moves(king_pos, boards, is_white_turn):
		if _is_piece_at(pos, boards[1 + 6 - color_offset]):
			return true
			
	# Rook or queen
	for pos in _sliding_moves(king_pos, true, false, boards, is_white_turn):
		if _is_piece_at(pos, boards[3 + 6 - color_offset]) || _is_piece_at(pos, boards[4 + 6 - color_offset]):
			return true
			
	# Bishop or queen
	for pos in _sliding_moves(king_pos, false, true, boards, is_white_turn):
		if _is_piece_at(pos, boards[2 + 6 - color_offset]) || _is_piece_at(pos, boards[4 + 6 - color_offset]):
			return true
			
	for pos in _king_moves(king_pos, boards, is_white_turn):
		if _is_piece_at(pos, boards[5 + 6 - color_offset]):
			return true
	
	# Check attacking pawns
	var king_file : int = king_pos % 8
	var king_rank : int = king_pos / 8
	
	var direction : int = 1 if is_white_turn else -1
	var offset_rank : int = king_rank + direction
	
	if offset_rank >= 0 && offset_rank < 8:
		for offset in [-1, 1]:
			var offset_file = king_file + offset
		
			if offset_file < 0 || offset_file > 7:
				continue
			
			if _is_piece_at(offset_file + offset_rank * 8, boards[6 - color_offset]):
				return true
	
	return false

static func _boards_after_move(move : Move, boards : PackedInt64Array) -> PackedInt64Array:
	var new_boards : PackedInt64Array = boards.duplicate()
	for i in range(12):
		new_boards[i] &= ~(1 << move.end_pos)
	new_boards[move.type] ^= 1 << move.start_pos | 1 << move.end_pos
	
	if is_move_castle(move):
		var rook_from : int
		var rook_to : int
		var is_white_move : bool
		match move.end_pos:
			6:  # White kingside
				rook_from = 7
				rook_to = 5
				is_white_move = true
			2:  # White queenside
				rook_from = 0
				rook_to = 3
				is_white_move = true
			62: # Black kingside
				rook_from = 63
				rook_to = 61
				is_white_move = false
			58: # Black queenside
				rook_from = 56
				rook_to = 59
				is_white_move = false
				
		new_boards[3 if is_white_move else 9] ^= 1 << rook_from | 1 << rook_to
	
	return new_boards

static func _does_move_cause_check(move : Move, boards : PackedInt64Array, is_white_turn : bool):
	# Check if new board is legal
	var new_boards : PackedInt64Array = _boards_after_move(move, boards)
	return _is_check(new_boards, is_white_turn)

static func _is_pawn_move_legal(move : Move, boards : PackedInt64Array, is_white_move : bool):		
	var direction : int = 1 if is_white_move else -1
	var start_rank : int = move.start_pos / 8
	var end_rank : int = move.end_pos / 8
	var start_file : int = move.start_pos % 8
	var end_file : int = move.end_pos % 8
	var rank_diff : int = (end_rank - start_rank) * direction
	var file_diff : int = abs(end_file - start_file)		
	
	if rank_diff == 1:
		if file_diff == 0 && !_is_occupied(move.end_pos, boards, true, true):
			return true
		elif file_diff == 1:
			return _is_occupied(move.end_pos, boards, !is_white_move, is_white_move)
		else:
			return false
	elif rank_diff == 2 && file_diff == 0 && start_rank == (1 if is_white_move else 6) && !_is_occupied(move.start_pos + 8 * direction, boards, true, true) && !_is_occupied(move.end_pos, boards, true, true):
		return true
	else:
		return false

static func _is_castle_move_legal(move : Move, boards : PackedInt64Array, can_castle_kingside : bool, can_castle_queenside : bool, is_white_move : bool, is_white_turn) -> bool:
	var vec_diff : Vector2i = move.vec_difference()
	
	if vec_diff == Vector2i(2, 0):
		# Castled kingside
		if !can_castle_kingside:
			return false
		
		if _is_occupied(move.start_pos + 1, boards, true, true) || _is_occupied(move.end_pos, boards, true, true):
			return false
		
		if _is_check(boards, is_white_turn) || _does_move_cause_check(Move.new(move.start_pos, move.start_pos + 1, 5 if is_white_move else 11), boards, is_white_turn) || _does_move_cause_check(Move.new(move.start_pos, move.end_pos, 5 if is_white_move else 11), boards, is_white_turn):
			return false
	elif vec_diff == Vector2i(-2, 0):
		# Castled queenside
		if !can_castle_queenside:
			return false
		
		if _is_occupied(move.end_pos - 1, boards, true, true) || _is_occupied(move.end_pos, boards, true, true) || _is_occupied(move.end_pos + 1, boards, true, true):
			return false
		
		if _is_check(boards, is_white_turn) || _does_move_cause_check(Move.new(move.start_pos, move.start_pos - 1, 5 if is_white_move else 11), boards, is_white_turn) || _does_move_cause_check(Move.new(move.start_pos, move.end_pos, 5 if is_white_move else 11), boards, is_white_turn):
			return false
	else:
		return false
	return true

static func is_move_castle(move : Move) -> bool:
	if (move.type == 5 || move.type == 11):
			var vec_difference = move.vec_difference()
			if vec_difference.abs() == Vector2i(2, 0):
				return true
	return false

static func is_move_legal(move : Move, boards : PackedInt64Array, is_white_turn : bool) -> bool:
	print("--- Checking move: %d -> %d (type %d) ---" % [move.start_pos, move.end_pos, move.type])
	
	if move.end_pos < 0 || move.end_pos >= 64:
		print("REJECTED: outside of board")
		return false
	
	if move.start_pos == move.end_pos:
		print("REJECTED: same square")
		return false
		
	# Types 0–5 are white pieces
	var is_white_move : bool = true if move.type <= 5 else false
	
	if is_white_move != is_white_turn:
		print("REJECTED: wrong turn")
		return false
		
	var white_board : int = boards[0] | boards[1] | boards[2] | boards[3] | boards[4] | boards[5]
	var black_board : int = boards[6] | boards[7] | boards[8] | boards[9] | boards[10] | boards[11]
	
	if is_white_move && _is_occupied(move.end_pos, boards, true, false) || !is_white_move && _is_occupied(move.end_pos, boards, false, true):
		print("REJECTED: destination occupied by friendly")
		return false
		
	if move.type == 0 || move.type == 6:
		# Is pawn move
		if _is_pawn_move_legal(move, boards, is_white_move):
			if _does_move_cause_check(move, boards, is_white_turn):
				print("REJECTED: move leaves king in check")
				return false
			return true
		else:
			print("REJECTED: illegal pawn move")
			return false
	
	var ray : Ray = _compute_ray(move.start_pos, move.end_pos)
	
	if ray.type == Ray.INVALID:
		print("REJECTED: invalid ray between %d and %d" % [move.start_pos, move.end_pos])
		return false
		
	if ray.type == Ray.KNIGHT:
		if move.type != 1 && move.type != 7:
			print("REJECTED: piece cannot make knight move")
			return false
		if _does_move_cause_check(move, boards, is_white_turn):
			print("REJECTED: move leaves king in check")
			return false
		return true
		
	if ray.type == Ray.ROOK:
		if move.type != 3 && move.type != 9 && move.type != 4 && move.type != 10 && move.type != 5 && move.type != 11:
			print("REJECTED: piece cannot make rook move")
			return false
			
		# Check for blocking piece
		if ray.ray & (white_board | black_board) != 0:
			print("REJECTED: ray is blocked. Blocking mask: %d" % [ray.ray & (white_board | black_board)])
			return false
			
		if (move.type == 5 || move.type == 11):
			if is_move_castle(move):
				return _is_castle_move_legal(move, boards, true, true, is_white_move, is_white_turn)
			return move.tile_length() == 1 && !_does_move_cause_check(move, boards, is_white_turn)
			
		if _does_move_cause_check(move, boards, is_white_turn):
			print("REJECTED: move leaves king in check")
			return false
		return true
		
	if ray.type == Ray.BISHOP:
		if move.type != 2 && move.type != 8 && move.type != 4 && move.type != 10 && move.type != 5 && move.type != 11:
			print("REJECTED: piece cannot make bishop move")
			return false
			
		# Check for blocking piece
		if ray.ray & (white_board | black_board) != 0:
			print("REJECTED: ray is blocked. Blocking mask: %d" % [ray.ray & (white_board | black_board)])
			return false
		
		if (move.type == 5 || move.type == 11):
			if move.tile_length() == 1:
				if _does_move_cause_check(move, boards, is_white_turn):
					print("REJECTED: move leaves king in check")
					return false
				return true
			print("REJECTED: king cannot move more than 1 tile")
			return false
			
		if _does_move_cause_check(move, boards, is_white_turn):
			print("REJECTED: move leaves king in check")
			return false
		return true
			
	return false
	
static func _is_generated_move_legal(move : Move, boards : PackedInt64Array, is_white_turn : bool) -> bool:
	if move.end_pos < 0 || move.end_pos >= 64:
		return false
	
	if move.start_pos == move.end_pos:
		return false
		
	# Types 0–5 are white pieces
	var is_white_move : bool = true if move.type <= 5 else false
	
	if is_white_move != is_white_turn:
		return false
		
	var white_board : int = boards[0] | boards[1] | boards[2] | boards[3] | boards[4] | boards[5]
	var black_board : int = boards[6] | boards[7] | boards[8] | boards[9] | boards[10] | boards[11]
	
	if is_white_move && _is_occupied(move.end_pos, boards, true, false) || !is_white_move && _is_occupied(move.end_pos, boards, false, true):
		return false
		
	if move.type == 0 || move.type == 6:
		if _does_move_cause_check(move, boards, is_white_turn):
			return false
		return true
	
	var ray : Ray = _compute_ray(move.start_pos, move.end_pos)
	
	if ray.type == Ray.INVALID:
		return false
		
	if ray.type == Ray.KNIGHT:
		if move.type != 1 && move.type != 7:
			return false
		if _does_move_cause_check(move, boards, is_white_turn):
			return false
		return true
		
	if ray.type == Ray.ROOK:
		if move.type != 3 && move.type != 9 && move.type != 4 && move.type != 10 && move.type != 5 && move.type != 11:
			return false
			
		# Check for blocking piece
		if ray.ray & (white_board | black_board) != 0:
			return false
			
		if (move.type == 5 || move.type == 11):
			if is_move_castle(move):
				return _is_castle_move_legal(move, boards, true, true, is_white_move, is_white_turn)
			return move.tile_length() == 1 && !_does_move_cause_check(move, boards, is_white_turn)
			
		if _does_move_cause_check(move, boards, is_white_turn):
			return false
		return true
		
	if ray.type == Ray.BISHOP:
		if move.type != 2 && move.type != 8 && move.type != 4 && move.type != 10 && move.type != 5 && move.type != 11:
			return false
			
		# Check for blocking piece
		if ray.ray & (white_board | black_board) != 0:
			return false
		
		if (move.type == 5 || move.type == 11):
			if move.tile_length() == 1:
				if _does_move_cause_check(move, boards, is_white_turn):
					return false
				return true
			return false
			
		if _does_move_cause_check(move, boards, is_white_turn):
			return false
		return true
			
	return false

static func _get_legal_moves(boards : PackedInt64Array, is_white_turn : bool) -> Array[Move]:
	var color_offset : int = 0 if is_white_turn else 6
	var moves : Array[Move]
	
	for type in range(color_offset, color_offset + 6):
		for i in range(64):
			if !_is_piece_at(i, boards[type]):
				continue
			var move_targets : PackedInt64Array
			match type % 6:
				0: move_targets = _pawn_moves(i, boards, is_white_turn)
				1: move_targets = _knight_moves(i, boards, is_white_turn)
				2: move_targets = _sliding_moves(i, false, true, boards, is_white_turn) # Bishop
				3: move_targets = _sliding_moves(i, true, false, boards, is_white_turn) # Rook
				4: move_targets = _sliding_moves(i, true, true, boards, is_white_turn)  # Queen
				5: move_targets = _king_moves(i, boards, is_white_turn)
				
			for pos in move_targets:
				var move : Move = Move.new(i, pos, type)
				if !_is_generated_move_legal(move, boards, is_white_turn):
					continue
				moves.append(move)
				
	return moves
	
static func _count_pieces_in_board(board : int) -> int:
	var count : int = 0
	while board != 0:
		board &= board - 1
		count += 1
	
	return count

static func _get_all_pieces(boards : PackedInt64Array) -> PackedInt64Array:
	var pieces : PackedInt64Array
	
	for i in range(12):
		var count : int = _count_pieces_in_board(boards[i])
		var array : PackedInt64Array = []
		array.resize(count)
		array.fill(i)
		pieces.append_array(array)
					
	return pieces

# Returns static eval where white is positive and black is negative
static func _static_eval(boards : PackedInt64Array, is_white_turn : bool) -> float:
	var pieces : PackedInt64Array = _get_all_pieces(boards)
	var sum : int = 0
	
	for piece in pieces:
		sum += piece_values[piece % 6] * (1 if piece < 6 else -1)
		
	return sum / 100.0

static func _tree_search_eval(boards : PackedInt64Array, is_white_turn : bool, depth : int) -> float:
	if depth == 0:
		# Static eval
		return _static_eval(boards, is_white_turn) * (1 if is_white_turn else -1)
	
	var legal_moves : Array[Move] = _get_legal_moves(boards, is_white_turn)	
	
	# Does static eval of all legal moves
	# Eval is from the perspective of the current player
	var max_eval : float = -INF
		
	for move in legal_moves:
		max_eval = max(max_eval, -_tree_search_eval(_boards_after_move(move, boards), !is_white_turn, depth - 1))
	return max_eval
	

static func find_best_move(boards : PackedInt64Array, is_white_turn : bool, depth : int) -> Move:
	var legal_moves : Array[Move] = _get_legal_moves(boards, is_white_turn)
	
	if legal_moves.size() == 0:
		print("No moves available")
		
	var start_time : int = Time.get_ticks_usec()
		
	var max_eval : float = -INF
	var best_move : Move
	
	for move in legal_moves:
		var eval : float = -_tree_search_eval(_boards_after_move(move, boards), !is_white_turn, depth - 1)
		if eval > max_eval:
			max_eval = eval
			best_move = move
		
	var end_time : int = Time.get_ticks_usec()
	print("Search took " + str((end_time - start_time) / 1000.0) + " ms")
	
	return best_move
	
static func print_board(boards : PackedInt64Array) -> void:
	var piece_chars = ["P","N","B","R","Q","K","p","n","b","r","q","k"]
	for rank in range(7, -1, -1):
		var row = "%d | " % rank
		for file in range(8):
			var sq = rank * 8 + file
			var found = "."
			for i in range(12):
				if _is_piece_at(sq, boards[i]):
					found = piece_chars[i]
					break
			row += found + " "
		print(row)
	print("    - - - - - - - -")
	print("    a b c d e f g h")
