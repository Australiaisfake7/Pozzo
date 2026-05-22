class_name ChessEngine

const PIECE_VALUES : PackedInt64Array = [120, 300, 340, 500, 900, 0]
const MAX_DEPTH = 8

enum {TT_EXACT, TT_ALPHA, TT_BETA}

static var _is_check_capture_boards : PackedInt64Array = [0,0,0,0,0,0,0,0,0,0,0,0]

static var rng : SplitMix64
static var zobrist_values : PackedInt64Array
static var transposition_table : Dictionary

# Debug vars
static var _nodes_searched : int = 0
static var _max_depth_searched : int = 0

class Ray:
	enum {ROOK, BISHOP, KNIGHT, INVALID}
	
	var ray : int
	var type : int
	
	func _init(ray : int, type : int) -> void:
		self.ray = ray
		self.type = type

static func init():
	rng = SplitMix64.new()
	zobrist_values = _compute_zobrist_values(rng)

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

static func _pawn_moves(pos : int, boards : PackedInt64Array, is_white_move : bool, en_passant_file : int) -> PackedInt64Array:
	var moves : PackedInt64Array
	var start_rank : int = 1 if is_white_move else 6
	
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
		
	var en_passant_rank : int = 4 if is_white_move else 3
		
	if en_passant_file != -1 && abs(file - en_passant_file) == 1 && rank == en_passant_rank:
		moves.append(en_passant_file + (rank + direction) * 8)
		
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

static func _king_moves(pos : int, boards : PackedInt64Array, is_white_move : bool, allow_castling : bool):
	var moves : PackedInt64Array
	
	var file : int = pos % 8
	var rank : int = pos / 8
	
	for r in range(-1, 2):
		for f in range(-1, 2):
			if f == 0 && r == 0:
				continue
			
			var offset_file : int = file + f
			var offset_rank : int = rank + r
			
			if offset_file < 0 || offset_file > 7 || offset_rank < 0 || offset_rank > 7:
				continue
			
			var offset_pos : int = offset_file + offset_rank * 8
			
			if _is_occupied(offset_pos, boards, is_white_move, !is_white_move):
				continue
			
			moves.append(offset_pos)
			
	if allow_castling && (pos == 4 || pos == 60):
		moves.append(pos - 2)
		moves.append(pos + 2)
			
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
			
	for pos in _king_moves(king_pos, boards, is_white_turn, false):
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

# Mutates boards using move
static func apply_move(move : int, boards : PackedInt64Array, capture_boards : PackedInt64Array) -> void:
	for i in range(12):
		capture_boards[i] = 0
		if boards[i] >> (move >> 6 & 63) & 1 == 1:
			# Clear pieces
			boards[i] &= ~(1 << (move >> 6 & 63))
			capture_boards[i] |= 1 << (move >> 6 & 63)
	# Move piece
	boards[move >> 12 & 15] ^= 1 << (move & 63) | 1 << (move >> 6 & 63)
	
	if _is_move_en_passant(move, boards):
		var direction : int = 1 if (move >> 12 & 15) < 6 else - 1
		var capture_pos : int = (move >> 6 & 63) - direction * 8
		
		var board : int = 6 - (move >> 12 & 15)
		boards[board] &= ~(1 << capture_pos)
		capture_boards[board] |= 1 << capture_pos
	
	if is_move_castle(move):
		var rook_from : int
		var rook_to : int
		var is_white_move : bool
		match move >> 6 & 63:
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
				
		boards[3 if is_white_move else 9] ^= 1 << rook_from | 1 << rook_to

# Unmutates boards
static func _unapply_move(move : int, boards : PackedInt64Array, capture_boards : PackedInt64Array) -> void:
	boards[move >> 12 & 15] ^= 1 << (move & 63) | 1 << (move >> 6 & 63)
	
	for i in range(12):
		if capture_boards[i] >> (move >> 6 & 63) & 1 == 1:
			boards[i] |= 1 << (move >> 6 & 63)
		
	if _is_move_en_passant(move, boards):
		var direction : int = 1 if (move >> 12 & 15) < 6 else - 1
		var capture_pos : int = (move >> 6 & 63) - direction * 8
		
		var board : int = 6 - (move >> 12 & 15)
		
		if capture_boards[board] >> capture_pos & 1 == 1:
			boards[board] |= 1 << capture_pos
	
	if is_move_castle(move):
		var rook_from : int
		var rook_to : int
		var is_white_move : bool
		match move >> 6 & 63:
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
				
		boards[3 if is_white_move else 9] ^= 1 << rook_from | 1 << rook_to
		
static func _does_move_cause_check(move : int, boards : PackedInt64Array, is_white_turn : bool) -> bool:
	# Check if new board is legal
	apply_move(move, boards, _is_check_capture_boards)
	var result : bool = _is_check(boards, is_white_turn)
	_unapply_move(move, boards, _is_check_capture_boards)
	return result
	
static func _is_move_en_passant(move : int, boards : PackedInt64Array) -> bool:
	if (move >> 12 & 15 != 0 && move >> 12 & 15 != 6):
		return false
		
	var direction : int = 1 if (move >> 12 & 15) < 6 else -1
	var start_rank : int = (move & 63) / 8
	var end_rank : int = (move >> 6 & 63) / 8
	var start_file : int = (move & 63) % 8
	var end_file : int = (move >> 6 & 63) % 8
	var rank_diff : int = (end_rank - start_rank) * direction
	var file_diff : int = abs(end_file - start_file)
		
	if start_rank != (4 if (move >> 12 & 15) < 6 else 3) || file_diff != 1 || rank_diff != 1 || _is_occupied(end_rank * 8 + end_file, boards, (move >> 12 & 15) >= 6, (move >> 12 & 15) < 6):
		return false
		
	return true

static func _is_pawn_move_legal(move : int, boards : PackedInt64Array, is_white_move : bool, en_passant_file : int):
	var direction : int = 1 if is_white_move else -1
	var start_rank : int = (move & 63) / 8
	var end_rank : int = (move >> 6 & 63) / 8
	var start_file : int = (move & 63) % 8
	var end_file : int = (move >> 6 & 63) % 8
	var rank_diff : int = (end_rank - start_rank) * direction
	var file_diff : int = abs(end_file - start_file)
	
	if rank_diff == 1:
		if file_diff == 0 && !_is_occupied(move >> 6 & 63, boards, true, true):
			return true
		elif file_diff == 1:
			return _is_occupied(move >> 6 & 63, boards, !is_white_move, is_white_move) || end_file == en_passant_file && start_rank == (4 if is_white_move else 3) && file_diff == 1 && _is_occupied((move >> 6 & 63) - 8 * direction, boards, !is_white_move, is_white_move)
		else:
			return false
	elif rank_diff == 2 && file_diff == 0 && start_rank == (1 if is_white_move else 6) && !_is_occupied((move & 63) + 8 * direction, boards, true, true) && !_is_occupied(move >> 6 & 63, boards, true, true):
		return true
	else:
		return false

static func _is_castle_move_legal(move : int, boards : PackedInt64Array, castle_rights : int, is_white_move : bool) -> bool:
	var file_diff : int = Move.file_diff(move)
	
	if file_diff == 2:
		# Castled kingside
		if !(castle_rights & 1 if is_white_move else castle_rights >> 2 & 1):
			return false
		
		if _is_occupied((move & 63) + 1, boards, true, true) || _is_occupied(move >> 6 & 63, boards, true, true):
			return false
		
		if _is_check(boards, is_white_move) || _does_move_cause_check(Move.create(move & 63, (move & 63) + 1, 5 if is_white_move else 11), boards, is_white_move) || _does_move_cause_check(Move.create(move & 63, move >> 6 & 63, 5 if is_white_move else 11), boards, is_white_move):
			return false
	elif file_diff == -2:
		# Castled queenside
		if !(castle_rights >> 1 & 1 if is_white_move else castle_rights >> 3 & 1):
			return false
		
		if _is_occupied((move >> 6 & 63) - 1, boards, true, true) || _is_occupied(move >> 6 & 63, boards, true, true) || _is_occupied((move >> 6 & 63) + 1, boards, true, true):
			return false
		
		if _is_check(boards, is_white_move) || _does_move_cause_check(Move.create(move & 63, (move & 63) - 1, 5 if is_white_move else 11), boards, is_white_move) || _does_move_cause_check(Move.create(move & 63, move >> 6 & 63, 5 if is_white_move else 11), boards, is_white_move):
			return false
	else:
		return false
	return true

static func is_move_castle(move : int) -> bool:
	if (move >> 12 & 15 == 5 || move >> 12 & 15 == 11):
			var file_diff : int = Move.file_diff(move)
			if absi(file_diff) == 2:
				return true
	return false

static func get_castle_rook_move(move : int) -> int:
	var rook_from : int
	var rook_to : int
	var color_offset : int
	match move >> 6 & 63:
		6:  # White kingside
			rook_from = 7
			rook_to = 5
			color_offset = 0
		2:  # White queenside
			rook_from = 0
			rook_to = 3
			color_offset = 0
		62: # Black kingside
			rook_from = 63
			rook_to = 61
			color_offset = 6
		58: # Black queenside
			rook_from = 56
			rook_to = 59
			color_offset = 6
			
	return rook_from | (rook_to << 6) | ((3 + color_offset) << 12)

static func is_move_legal(move : int, boards : PackedInt64Array, castle_rights : int, en_passant_file : int, is_white_turn : bool) -> bool:
	print("--- Checking move: %d -> %d (type %d) ---" % [move & 63, move >> 6 & 63, move >> 12 & 15])
	
	if move >> 6 & 63 < 0 || move >> 6 & 63 >= 64:
		print("REJECTED: outside of board")
		return false
	
	if (move & 63) == move >> 6 & 63:
		print("REJECTED: same square")
		return false
		
	# Types 0–5 are white pieces
	var is_white_move : bool = true if move >> 12 & 15 <= 5 else false
	
	if is_white_move != is_white_turn:
		print("REJECTED: wrong turn")
		return false
		
	var white_board : int = boards[0] | boards[1] | boards[2] | boards[3] | boards[4] | boards[5]
	var black_board : int = boards[6] | boards[7] | boards[8] | boards[9] | boards[10] | boards[11]
	
	if is_white_move && _is_occupied(move >> 6 & 63, boards, true, false) || !is_white_move && _is_occupied(move >> 6 & 63, boards, false, true):
		print("REJECTED: destination occupied by friendly")
		return false
		
	if move >> 12 & 15 == 0 || move >> 12 & 15 == 6:
		# Is pawn move
		if _is_pawn_move_legal(move, boards, is_white_move, en_passant_file):
			if _does_move_cause_check(move, boards, is_white_turn):
				print("REJECTED: move leaves king in check")
				return false
			return true
		else:
			print("REJECTED: illegal pawn move")
			return false
	
	var ray : Ray = _compute_ray(move & 63, move >> 6 & 63)
	
	if ray.type == Ray.INVALID:
		print("REJECTED: invalid ray between %d and %d" % [move & 63, move >> 6 & 63])
		return false
		
	if ray.type == Ray.KNIGHT:
		if move >> 12 & 15 != 1 && move >> 12 & 15 != 7:
			print("REJECTED: piece cannot make knight move")
			return false
		if _does_move_cause_check(move, boards, is_white_turn):
			print("REJECTED: move leaves king in check")
			return false
		return true
		
	if ray.type == Ray.ROOK:
		if move >> 12 & 15 != 3 && move >> 12 & 15 != 9 && move >> 12 & 15 != 4 && move >> 12 & 15 != 10 && move >> 12 & 15 != 5 && move >> 12 & 15 != 11:
			print("REJECTED: piece cannot make rook move")
			return false
			
		# Check for blocking piece
		if ray.ray & (white_board | black_board) != 0:
			print("REJECTED: ray is blocked. Blocking mask: %d" % [ray.ray & (white_board | black_board)])
			return false
			
		if (move >> 12 & 15 == 5 || move >> 12 & 15 == 11):
			if is_move_castle(move):
				return _is_castle_move_legal(move, boards, castle_rights, is_white_move)
			return Move.tile_length(move) == 1 && !_does_move_cause_check(move, boards, is_white_turn)
			
		if _does_move_cause_check(move, boards, is_white_turn):
			print("REJECTED: move leaves king in check")
			return false
		return true
		
	if ray.type == Ray.BISHOP:
		if move >> 12 & 15 != 2 && move >> 12 & 15 != 8 && move >> 12 & 15 != 4 && move >> 12 & 15 != 10 && move >> 12 & 15 != 5 && move >> 12 & 15 != 11:
			print("REJECTED: piece cannot make bishop move")
			return false
			
		# Check for blocking piece
		if ray.ray & (white_board | black_board) != 0:
			print("REJECTED: ray is blocked. Blocking mask: %d" % [ray.ray & (white_board | black_board)])
			return false
		
		if (move >> 12 & 15 == 5 || move >> 12 & 15 == 11):
			if Move.tile_length(move) == 1:
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
	
static func _is_generated_move_legal(move : int, boards : PackedInt64Array, is_white_turn : bool, castle_rights : int) -> bool:
	if is_move_castle(move):
		var is_white_move : bool = (move >> 12 & 15) < 6
		return _is_castle_move_legal(move, boards, castle_rights, is_white_move)
			
	return !_does_move_cause_check(move, boards, is_white_turn)

static func _get_pseudo_legal_moves(boards : PackedInt64Array, is_white_turn : bool, en_passant_file : int) -> PackedInt64Array:
	var color_offset : int = 0 if is_white_turn else 6
	var moves : PackedInt64Array
	
	for type in range(color_offset, color_offset + 6):
		for i in range(64):
			if !_is_piece_at(i, boards[type]):
				continue
			var move_targets : PackedInt64Array
			match type % 6:
				0: move_targets = _pawn_moves(i, boards, is_white_turn, en_passant_file)
				1: move_targets = _knight_moves(i, boards, is_white_turn)
				2: move_targets = _sliding_moves(i, false, true, boards, is_white_turn) # Bishop
				3: move_targets = _sliding_moves(i, true, false, boards, is_white_turn) # Rook
				4: move_targets = _sliding_moves(i, true, true, boards, is_white_turn)  # Queen
				5: move_targets = _king_moves(i, boards, is_white_turn, true)
				
			for pos in move_targets:
				var move : int = Move.create(i, pos, type)
				moves.append(move)
				
	return moves
	
static func _count_pieces_in_board(board : int) -> int:
	var count : int = 0
	while board != 0:
		board &= board - 1
		count += 1
	
	return count
	
static func get_updated_castle_rights(move : int, castle_rights: int) -> int:
	match move & 63:
		4:  castle_rights &= ~1; castle_rights &= ~(1 << 1) # White king
		0:  castle_rights &= ~(1 << 1)
		7:  castle_rights &= ~1
		60: castle_rights &= ~(1 << 2); castle_rights &= ~(1 << 3) # Black king
		56: castle_rights &= ~(1 << 3)
		63: castle_rights &= ~(1 << 2)

	match move >> 6 & 63:
		0:  castle_rights &= ~(1 << 1)
		7:  castle_rights &= ~1
		56: castle_rights &= ~(1 << 3)
		63: castle_rights &= ~(1 << 2)
		
	return castle_rights

static func get_en_passant_file(move : int) -> int:
	if move >> 12 & 15 != 0 && move >> 12 & 15 != 6:
		return -1
		
	if move >> 12 & 15 == 0:
		# Start on rank 1 and end on rank 3
		if (move & 63) / 8 == 1 && (move >> 6 & 63) / 8 == 3:
			return (move >> 6 & 63) % 8
	else:
			# Start on rank 6 and end on rank 4
		if (move & 63) / 8 == 6 && (move >> 6 & 63) / 8 == 4:
			return (move >> 6 & 63) % 8

	return -1

static func _compute_zobrist_values(rng : SplitMix64) -> PackedInt64Array:
	var values : PackedInt64Array
	
	values.resize(12 * 64 + 8 + 16 + 1)
	
	for i in values.size():
		values[i] = rng.random()
		
	return values

static func _compute_zobrist_hash(zobrist_values : PackedInt64Array, boards : PackedInt64Array, castle_rights : int, is_white_turn : bool, en_passant_file : int) -> int:
	var hash : int = 0
	
	for i in range(64):
		for j in range(12):
			if _is_piece_at(i, boards[j]):
				hash ^= zobrist_values[i * 12 + j]
				
	hash ^= zobrist_values[768 + castle_rights]
	if is_white_turn:
		hash ^= zobrist_values[784]
	if en_passant_file != -1:
		hash ^= zobrist_values[784 + 1 + en_passant_file]
		
	return hash
	
static func _modify_zobrist_hash(zobrist_values : PackedInt64Array, hash : int, move : int, castle_rights : int, boards : PackedInt64Array, en_passant_file : int) -> int:
	hash ^= zobrist_values[(move & 63) * 12 + (move >> 12 & 15)]
	hash ^= zobrist_values[(move >> 6 & 63) * 12 + (move >> 12 & 15)]
	
	for i in range(12):
		if boards[i] >> (move >> 6 & 63) & 1 == 1:
			hash ^= zobrist_values[(move >> 6 & 63) * 12 + i]
			break
	
	hash ^= zobrist_values[784]
	
	var new_castle_rights : int = get_updated_castle_rights(move, castle_rights)
	if new_castle_rights != castle_rights:
		hash ^= zobrist_values[768 + castle_rights]
		hash ^= zobrist_values[768 + new_castle_rights]

	if _is_move_en_passant(move, boards):
		var direction : int = 1 if (move >> 12 & 15) < 6 else -1
		var captured_sq : int = (move >> 6 & 63) - direction * 8
		var enemy_pawn_type : int = 6 if (move >> 12 & 15) < 6 else 0
		hash ^= zobrist_values[captured_sq * 12 + enemy_pawn_type]

	if is_move_castle(move):
		var rook_move : int = get_castle_rook_move(move)
		hash ^= zobrist_values[(rook_move & 63) * 12 + (rook_move >> 12 & 15)]
		hash ^= zobrist_values[(rook_move >> 6 & 63) * 12 + (rook_move >> 12 & 15)]
		
	if en_passant_file != -1:
		hash ^= zobrist_values[784 + 1 + en_passant_file]
		
	var new_en_passant_file : int = get_en_passant_file(move)
	if new_en_passant_file != -1:
		hash ^= zobrist_values[784 + 1 + new_en_passant_file]
	
	return hash

# Returns static eval where white is positive and black is negative
static func _static_eval(boards : PackedInt64Array, is_white_turn : bool) -> float:
	var sum : int = 0
	
	for j in range(6):
		sum += _count_pieces_in_board(boards[j]) * PIECE_VALUES[j]
		
	for j in range(6, 12):
		sum -= _count_pieces_in_board(boards[j]) * PIECE_VALUES[j - 6]
		
	return sum / 100.0

# Sort moves for efficient alpha beta search
static func _sort_moves(boards : PackedInt64Array, moves : PackedInt64Array, last_best : int, is_white_turn : bool) -> PackedInt64Array:
	var moves_and_scores : Array
	
	var color_offset: int = 6 if is_white_turn else 0
	for move in moves:
		var scored : bool = false
		if last_best != -1 && move == last_best:
			moves_and_scores.append([move, 10000])
			continue
		for i in range(color_offset, color_offset + 6):
			if _is_piece_at(move >> 6 & 63, boards[i]):
				var capture_value : int = PIECE_VALUES[i % 6]
				var attacker_value : int = PIECE_VALUES[(move >> 12 & 15) % 6]
				moves_and_scores.append([move, capture_value - attacker_value + 1000])
				scored = true
				break
		if !scored:
			moves_and_scores.append([move, 0])
				
	moves_and_scores.sort_custom(func(a, b): return a[1] > b[1])
	var sorted_moves : PackedInt64Array = []
	
	for move in moves_and_scores:
		sorted_moves.append(move[0])
	
	return sorted_moves

# Negamax search
static func _tree_search_eval(boards : PackedInt64Array, is_white_turn : bool, depth : int, alpha : float, beta : float, castle_rights : int, en_passant_file :int, capture_stack : Array[PackedInt64Array], hash : int) -> float:
	_nodes_searched += 1
	
	if depth == 0:
		# Static eval
		return _static_eval(boards, is_white_turn) * (1 if is_white_turn else -1)
	
	var best_move : int = -1
	
	if transposition_table.has(hash):
		if transposition_table[hash][1] >= depth:
			if transposition_table[hash][2] == TT_EXACT:
				return transposition_table[hash][0]
			if transposition_table[hash][2] == TT_ALPHA && transposition_table[hash][0] <= alpha:
				return alpha
			if transposition_table[hash][2] == TT_BETA && transposition_table[hash][0] >= beta:
				return beta
		best_move = transposition_table[hash][3]
	
	var flag : int = TT_ALPHA
	
	var legal_moves : PackedInt64Array = _get_pseudo_legal_moves(boards, is_white_turn, en_passant_file)
	legal_moves = _sort_moves(boards, legal_moves, best_move, is_white_turn)
	
	var legal_move_found : bool = false
	for move in legal_moves:
		if !_is_generated_move_legal(move, boards, is_white_turn, castle_rights):
			continue
		legal_move_found = true
		
		var new_hash : int = _modify_zobrist_hash(zobrist_values, hash, move, castle_rights, boards, en_passant_file)
		
		apply_move(move, boards, capture_stack[depth])
		
		var value : float = -_tree_search_eval(boards, !is_white_turn, depth - 1, -beta, -alpha, get_updated_castle_rights(move, castle_rights), get_en_passant_file(move), capture_stack, new_hash)
		
		if value > alpha:
			flag = TT_EXACT
			alpha = value
			best_move = move
		
		_unapply_move(move, boards, capture_stack[depth])
		
		if alpha >= beta:
			flag = TT_BETA
			break
	if !legal_move_found:
		if _is_check(boards, is_white_turn):
			return -1000.0 - depth
		else:
			return 0.0
	
	transposition_table[hash] = [alpha, depth, flag, best_move]
	return alpha
	
# Returns the best move found
static func _move_search(boards : PackedInt64Array, is_white_turn : bool, depth : int, castle_rights : int, en_passant_file : int, last_best_move : int, hash : int) -> int:
	var legal_moves : PackedInt64Array = _get_pseudo_legal_moves(boards, is_white_turn, en_passant_file)
	
	if legal_moves.size() == 0:
		print("No moves available")
		
	legal_moves = _sort_moves(boards, legal_moves, last_best_move, is_white_turn)
		
	var max_eval : float = -INF
	var alpha : float = -INF
	var beta : float = INF
	var best_move : int
	
	var capture_stack : Array[PackedInt64Array] = []
	capture_stack.resize(MAX_DEPTH + 1)
	
	for i in range(MAX_DEPTH + 1):
		capture_stack[i] = PackedInt64Array()
		capture_stack[i].resize(12)
	
	for move in legal_moves:
		if !_is_generated_move_legal(move, boards, is_white_turn, castle_rights):
			continue
		
		var new_hash : int = _modify_zobrist_hash(zobrist_values, hash, move, castle_rights, boards, en_passant_file)
		
		apply_move(move, boards, capture_stack[depth])
		var eval : float = -_tree_search_eval(boards, !is_white_turn, depth - 1, -beta, -alpha, get_updated_castle_rights(move, castle_rights), get_en_passant_file(move), capture_stack, new_hash)
		_unapply_move(move, boards, capture_stack[depth])
		
		if eval > max_eval:
			max_eval = eval
			best_move = move
		
		alpha = max(alpha, eval)
	
	return best_move

static func find_best_move(boards : PackedInt64Array, is_white_turn : bool, search_ms : int, castle_rights : int, en_passant_file : int) -> int:
	_nodes_searched = 0
	_max_depth_searched = 0
	
	var start_ms : int = Time.get_ticks_msec()
	var move : int = -1
	
	for i in range(1, MAX_DEPTH + 1):
		_max_depth_searched = i
		move = _move_search(boards, is_white_turn, i, castle_rights, en_passant_file, move, _compute_zobrist_hash(zobrist_values, boards, castle_rights, is_white_turn, en_passant_file))

		if Time.get_ticks_msec() - start_ms >= search_ms:
			break
		
	print("Search took " + str(Time.get_ticks_msec() - start_ms) + "ms")
	print("Searched " + str(_nodes_searched) + " nodes")
	print("Searched to depth " + str(_max_depth_searched))
	
	return move

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
