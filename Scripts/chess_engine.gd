class_name ChessEngine

class Ray:
	enum {ROOK, BISHOP, KNIGHT, INVALID}
	
	var ray : int
	var type : int
	
	func _init(ray : int, type : int) -> void:
		self.ray = ray
		self.type = type

static func compute_ray(start_pos : int, end_pos : int) -> Ray:
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
static func is_occupied(pos : int, boards : PackedInt64Array, count_white : bool, count_black : bool) -> bool:
	var white_board : int = boards[0] | boards[1] | boards[2] | boards[3] | boards[4] | boards[5]
	var black_board : int = boards[6] | boards[7] | boards[8] | boards[9] | boards[10] | boards[11]
	var board : int = (white_board if count_white else 0) | (black_board if count_black else 0)
	
	return board >> pos & 1 == 1

# Checks for specific piece type(s)
static func is_piece_at(pos: int, board: int) -> bool:
	return board >> pos & 1 == 1

static func pawn_moves(pos : int, boards : PackedInt64Array, is_white_move : bool) -> Array[int]:
	var moves : Array[int]
	var start_rank : int = 1	 if is_white_move else 6
	
	var white_board : int = boards[0] | boards[1] | boards[2] | boards[3] | boards[4] | boards[5]
	var black_board : int = boards[6] | boards[7] | boards[8] | boards[9] | boards[10] | boards[11]
	var all_board : int = white_board | black_board
	
	var file : int = pos % 8
	var rank : int = pos / 8
	
	var direction : int = 1 if is_white_move else -1
	
	if !is_occupied(file + (rank + direction) * 8, boards, true, true):
		moves.append(file + (rank + direction) * 8)
		if rank == start_rank && !is_occupied(file + (rank + direction * 2) * 8, boards, true, true):
			moves.append(file + (rank + direction * 2) * 8)
	
	for offset in [-1, 1]:
		var capture_pos : int = file + offset + (rank + direction) * 8
		if is_occupied(capture_pos, boards, !is_white_move, is_white_move):
			moves.append(capture_pos)
			
		
	return moves
	
static func knight_moves(pos : int, boards : PackedInt64Array, is_white_move : bool) -> Array[int]:
	var moves : Array[int]
	var offsets = [[-2,-1],[-2,1],[-1,-2],[-1,2],[1,-2],[1,2],[2,-1],[2,1]]
	
	var file : int = pos % 8
	var rank : int = pos / 8
	
	for offset in offsets:
		var offset_file : int = file + offset[0]
		var offset_rank : int = rank + offset[1]
		
		if offset_file >= 0 && offset_file < 8 && offset_rank >= 0 && offset_rank < 8 && !is_occupied(offset_file + offset_rank * 8, boards, is_white_move, !is_white_move):
			moves.append(offset_file + offset_rank * 8)
	
	return moves
	
static func sliding_moves(pos : int, rook_move : bool, bishop_move : bool, boards : PackedInt64Array, is_white_move : bool) -> Array[int]:
	var moves : Array[int]
	
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
			
				if is_occupied(offset_pos, boards, true, true):
					var attacked_piece_is_white : bool = is_occupied(offset_pos, boards, true, false)
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
			
				if is_occupied(offset_pos, boards, true, true):
					var attacked_piece_is_white : bool = is_occupied(offset_pos, boards, true, false)
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
			
				if is_occupied(offset_pos, boards, true, true):
					var attacked_piece_is_white : bool = is_occupied(offset_pos, boards, true, false)
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
			
				if is_occupied(offset_pos, boards, true, true):
					var attacked_piece_is_white : bool = is_occupied(offset_pos, boards, true, false)
					if attacked_piece_is_white == is_white_move:
						break
					else:
						moves.append(offset_pos)
						break
			
				moves.append(offset_pos)
			
	return moves

static func king_moves(pos : int, boards : PackedInt64Array, is_white_move : bool):
	var moves : Array[int]
	
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
			
			if is_occupied(offset_pos, boards, is_white_move, !is_white_move):
				continue
			
			moves.append(offset_pos)
			
	return moves

static func is_check(boards : PackedInt64Array, is_white_turn : bool) -> bool:
	# is_white_turn represents side being checked for check, i.e. the one currently moving
	
	var white_board : int = boards[0] | boards[1] | boards[2] | boards[3] | boards[4] | boards[5]
	var black_board : int = boards[6] | boards[7] | boards[8] | boards[9] | boards[10] | boards[11]
	var all_board : int = white_board | black_board
	
	# Index shift to current side's boards
	# Use 6 - offset to get opponents boards
	var color_offset : int = 0 if is_white_turn else 6 
	
	var king_pos : int = 0
	for i in range(64):
		if is_piece_at(i, boards[5 + color_offset]):
			king_pos = i
			break

	for pos in knight_moves(king_pos, boards, is_white_turn):
		if is_piece_at(pos, boards[1 + 6 - color_offset]):
			return true
			
	# Rook or queen
	for pos in sliding_moves(king_pos, true, false, boards, is_white_turn):
		if is_piece_at(pos, boards[3 + 6 - color_offset]) || is_piece_at(pos, boards[4 + 6 - color_offset]):
			return true
			
	# Bishop or queen
	for pos in sliding_moves(king_pos, false, true, boards, is_white_turn):
		if is_piece_at(pos, boards[2 + 6 - color_offset]) || is_piece_at(pos, boards[4 + 6 - color_offset]):
			return true
			
	for pos in king_moves(king_pos, boards, is_white_turn):
		if is_piece_at(pos, boards[5 + 6 - color_offset]):
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
			
			if is_piece_at(offset_file + offset_rank * 8, boards[6 - color_offset]):
				return true
	
	return false

static func does_move_cause_check(move : Move, boards : PackedInt64Array, is_white_turn : bool):
	# Check if new board is legal
	var new_boards : PackedInt64Array = boards.duplicate()
	for i in range(12):
		new_boards[i] &= ~(1 << move.end_pos)
	new_boards[move.type] ^= 1 << move.start_pos | 1 << move.end_pos
	return is_check(new_boards, is_white_turn)

static func is_pawn_move_legal(move : Move, boards : PackedInt64Array, is_white_move : bool):		
	var direction : int = 1 if is_white_move else -1
	var start_rank : int = move.start_pos / 8
	var end_rank : int = move.end_pos / 8
	var start_file : int = move.start_pos % 8
	var end_file : int = move.end_pos % 8
	var rank_diff : int = (end_rank - start_rank) * direction
	var file_diff : int = abs(end_file - start_file)		
	
	if rank_diff == 1:
		if file_diff == 0 && !is_occupied(move.end_pos, boards, true, true):
			return true
		elif file_diff == 1:
			return is_occupied(move.end_pos, boards, !is_white_move, is_white_move)
		else:
			return false
	elif rank_diff == 2 && file_diff == 0 && start_rank == (1 if is_white_move else 6) && !is_occupied(move.start_pos + 8 * direction, boards, true, true) && !is_occupied(move.end_pos, boards, true, true):
		return true
	else:
		return false

static func is_castle_move_legal(move : Move, boards : PackedInt64Array, can_castle_kingside : bool, can_castle_queenside : bool, is_white_move : bool, is_white_turn) -> bool:
	var vec_diff : Vector2i = move.vec_difference()
	
	if vec_diff == Vector2i(2, 0):
		# Castled kingside
		if !can_castle_kingside:
			return false
		
		if is_occupied(move.start_pos + 1, boards, true, true) || is_occupied(move.end_pos, boards, true, true):
			return false
		
		if is_check(boards, is_white_turn) || does_move_cause_check(Move.new(move.start_pos, move.start_pos + 1, 5 if is_white_move else 11), boards, is_white_turn) || does_move_cause_check(Move.new(move.start_pos, move.end_pos, 5 if is_white_move else 11), boards, is_white_turn):
			return false
	elif vec_diff == Vector2i(-2, 0):
		# Castled queenside
		if !can_castle_queenside:
			return false
		
		if is_occupied(move.end_pos - 1, boards, true, true) || is_occupied(move.end_pos, boards, true, true) || is_occupied(move.end_pos + 1, boards, true, true):
			return false
		
		if is_check(boards, is_white_turn) || does_move_cause_check(Move.new(move.start_pos, move.start_pos - 1, 5 if is_white_move else 11), boards, is_white_turn) || does_move_cause_check(Move.new(move.start_pos, move.end_pos, 5 if is_white_move else 11), boards, is_white_turn):
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

static func is_move_legal(move : Move, boards : PackedInt64Array, is_white_turn : bool, allow_print : bool) -> bool:
	if allow_print:
		print("--- Checking move: %d -> %d (type %d) ---" % [move.start_pos, move.end_pos, move.type])
	
	if move.end_pos < 0 || move.end_pos >= 64:
		if allow_print:
			print("REJECTED: outside of board")
		return false
	
	if move.start_pos == move.end_pos:
		if allow_print:
			print("REJECTED: same square")
		return false
		
	# Types 0–5 are white pieces
	var is_white_move : bool = true if move.type <= 5 else false
	
	if is_white_move != is_white_turn:
		if allow_print:
			print("REJECTED: wrong turn")
		return false
		
	var white_board : int = boards[0] | boards[1] | boards[2] | boards[3] | boards[4] | boards[5]
	var black_board : int = boards[6] | boards[7] | boards[8] | boards[9] | boards[10] | boards[11]
	
	if is_white_move && is_occupied(move.end_pos, boards, true, false) || !is_white_move && is_occupied(move.end_pos, boards, false, true):
		if allow_print:
			print("REJECTED: destination occupied by friendly")
		return false
		
	if move.type == 0 || move.type == 6:
		# Is pawn move
		if is_pawn_move_legal(move, boards, is_white_move):
			if does_move_cause_check(move, boards, is_white_turn):
				if allow_print:
					print("REJECTED: move leaves king in check")
				return false
			return true
		else:
			if allow_print:
				print("REJECTED: illegal pawn move")
			return false
	
	var ray : Ray = compute_ray(move.start_pos, move.end_pos)
	
	if ray.type == Ray.INVALID:
		if allow_print:
			print("REJECTED: invalid ray between %d and %d" % [move.start_pos, move.end_pos])
		return false
		
	if ray.type == Ray.KNIGHT:
		if move.type != 1 && move.type != 7:
			if allow_print:
				print("REJECTED: piece cannot make knight move")
			return false
		if does_move_cause_check(move, boards, is_white_turn):
			if allow_print:
				print("REJECTED: move leaves king in check")
			return false
		return true
		
	if ray.type == Ray.ROOK:
		if move.type != 3 && move.type != 9 && move.type != 4 && move.type != 10 && move.type != 5 && move.type != 11:
			if allow_print:
				print("REJECTED: piece cannot make rook move")
			return false
			
		# Check for blocking piece
		if ray.ray & (white_board | black_board) != 0:
			if allow_print:
				print("REJECTED: ray is blocked. Blocking mask: %d" % [ray.ray & (white_board | black_board)])
			return false
			
		if (move.type == 5 || move.type == 11):
			if is_move_castle(move):
				return is_castle_move_legal(move, boards, true, true, is_white_move, is_white_turn)
			return move.tile_length() == 1 && !does_move_cause_check(move, boards, is_white_turn)
			
		if does_move_cause_check(move, boards, is_white_turn):
			if allow_print:
				print("REJECTED: move leaves king in check")
			return false
		return true
		
	if ray.type == Ray.BISHOP:
		if move.type != 2 && move.type != 8 && move.type != 4 && move.type != 10 && move.type != 5 && move.type != 11:
			if allow_print:
				print("REJECTED: piece cannot make bishop move")
			return false
			
		# Check for blocking piece
		if ray.ray & (white_board | black_board) != 0:
			if allow_print:
				print("REJECTED: ray is blocked. Blocking mask: %d" % [ray.ray & (white_board | black_board)])
			return false
		
		if (move.type == 5 || move.type == 11):
			if move.tile_length() == 1:
				if does_move_cause_check(move, boards, is_white_turn):
					if allow_print:
						print("REJECTED: move leaves king in check")
					return false
				return true
			if allow_print:
				print("REJECTED: king cannot move more than 1 tile")
			return false
			
		if does_move_cause_check(move, boards, is_white_turn):
			if allow_print:
				print("REJECTED: move leaves king in check")
			return false
		return true
			
	return false
	
static func get_legal_moves(boards : PackedInt64Array, is_white_turn : bool) -> Array[Move]:
	var color_offset : int = 0 if is_white_turn else 6
	var moves : Array[Move]
	
	for type in range(color_offset, color_offset + 6):
		for i in range(64):
			if !is_piece_at(i, boards[type]):
				continue
			var move_targets : Array[int]
			match type % 6:
				0: move_targets = pawn_moves(i, boards, is_white_turn)
				1: move_targets = knight_moves(i, boards, is_white_turn)
				2: move_targets = sliding_moves(i, false, true, boards, is_white_turn) # Bishop
				3: move_targets = sliding_moves(i, true, false, boards, is_white_turn) # Rook
				4: move_targets = sliding_moves(i, true, true, boards, is_white_turn)  # Queen
				5: move_targets = king_moves(i, boards, is_white_turn)
				
			for pos in move_targets:
				var move : Move = Move.new(i, pos, type)
				if !is_move_legal(move, boards, is_white_turn, false):
					continue
				moves.append(move)
				
	return moves
	
static func generate_best_move(boards : PackedInt64Array, is_white_turn : bool) -> Move:
	var legal_moves : Array[Move] = get_legal_moves(boards, is_white_turn)
	legal_moves.shuffle()
	
	return legal_moves[0]
	
static func print_board(boards : PackedInt64Array) -> void:
	var piece_chars = ["P","N","B","R","Q","K","p","n","b","r","q","k"]
	for rank in range(7, -1, -1):
		var row = "%d | " % rank
		for file in range(8):
			var sq = rank * 8 + file
			var found = "."
			for i in range(12):
				if is_piece_at(sq, boards[i]):
					found = piece_chars[i]
					break
			row += found + " "
		print(row)
	print("    - - - - - - - -")
	print("    a b c d e f g h")
