class_name ChessEngine

static var rays : Array[Ray]
enum RayType {ROOK, BISHOP, KNIGHT, INVALID}

class Ray:
	var ray : int
	var type : RayType
	
	func _init(ray : int, type : RayType) -> void:
		self.ray = ray
		self.type = type
	

static func load_rays() -> void:
	var file : FileAccess = FileAccess.open("res://Resources/rays.dat", FileAccess.READ)
	if file:
		var data : Array = file.get_var()
		rays.clear()
		for entry in data:
			rays.append(Ray.new(entry[0], entry[1] as RayType))
	else:
		push_error("Could not load rays.dat: " + str(FileAccess.get_open_error()))
		return

static func compute_ray(move : Move) -> Ray:
	var ray : int = 0
	var start_pos : Vector2i = Vector2i(move.start_pos % 8, move.start_pos / 8)
	var end_pos : Vector2i = Vector2i(move.end_pos % 8, move.end_pos / 8)
	
	var diff : Vector2i = start_pos - end_pos
	if diff == Vector2i.ZERO: return Ray.new(0, RayType.INVALID)
	
	if abs(diff.x) == abs(diff.y):
		# Is diagonal
		var length : int = max(abs(diff.x), abs(diff.y))
		for i in range(length - 2):
			var pos : Vector2i = end_pos + diff / length * (i + 1)
			var grid_pos : int = pos.x + pos.y * 8
			ray |= (1 << grid_pos)
		return Ray.new(ray, RayType.BISHOP)
	elif (diff.x == 0) != (diff.y == 0):
		# Is straight
		var length : int = max(abs(diff.x), abs(diff.y))
		for i in range(length - 2):
			var pos : Vector2i = end_pos + diff / length * (i + 1)
			var grid_pos : int = pos.x + pos.y * 8
			ray |= (1 << grid_pos)
		return Ray.new(ray, RayType.ROOK)
	elif abs(diff.x) == 1 && abs(diff.y) == 2 || abs(diff.x) == 2 && abs(diff.y) == 1:
		# Is L shape
		return Ray.new(ray, RayType.KNIGHT)
	else:
		return Ray.new(ray, RayType.INVALID)
	
static func save_rays_in_file(path : String) -> void:
	var rays : Array
	rays.resize(4096)
	
	for i in range(64):
		for j in range(64):
			var ray : Ray = compute_ray(Move.new(i, j, 0))
			rays[i * 64 + j] = [ray.ray, ray.type]
	var file : FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_var(rays)
		file.close()
		
static func is_occupied(pos : int, boards : PackedInt64Array, count_white : bool, count_black : bool) -> bool:
	var white_board : int = boards[0] | boards[1] | boards[2] | boards[3] | boards[4] | boards[5]
	var black_board : int = boards[6] | boards[7] | boards[8] | boards[9] | boards[10] | boards[11]
	var board : int = (white_board if count_white else 0) | (black_board if count_black else 0)
	
	return board >> pos & 1 == 1

static func is_check(boards : PackedInt64Array) -> bool:
	return false

static func does_move_cause_check(move : Move, boards : PackedInt64Array):
		# Check if new board is legal
		var new_boards : PackedInt64Array = boards.duplicate()
		for i in range(12):
			new_boards[i] &= ~(1 << move.end_pos)
		new_boards[move.type] ^= 1 << move.start_pos | 1 << move.end_pos
		return is_check(new_boards)

static func is_pawn_move_legal(move : Move, boards : PackedInt64Array, is_white : bool):		
		var direction : int = 1 if is_white else -1
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
				return is_occupied(move.end_pos, boards, !is_white, is_white)
			else:
				return false
		elif rank_diff == 2 && start_rank == (1 if is_white else 6) && !is_occupied(move.start_pos + 8 * direction, boards, true, true) && !is_occupied(move.end_pos, boards, true, true):
			return true
		else:
			return false

static func is_castle_move_legal(move : Move, boards : PackedInt64Array, can_castle_kingside : bool, can_castle_queenside : bool, is_white : bool) -> bool:
	var vec_diff : Vector2i = move.vec_difference()
	
	if vec_diff == Vector2i(2, 0):
		# Castled kingside
		if !can_castle_kingside:
			return false
		
		if is_occupied(move.start_pos + 1, boards, true, true) || is_occupied(move.end_pos, boards, true, true):
			return false
		
		if is_check(boards) || does_move_cause_check(Move.new(move.start_pos, move.start_pos + 1, 5 if is_white else 11), boards) || does_move_cause_check(Move.new(move.start_pos, move.end_pos, 5 if is_white else 11), boards):
			return false
	elif vec_diff == Vector2i(-2, 0):
		# Castled queenside
		if !can_castle_queenside:
			return false
		
		if is_occupied(move.start_pos + 1, boards, true, true) || is_occupied(move.end_pos, boards, true, true) || is_occupied(move.end_pos + 1, boards, true, true):
			return false
		
		if is_check(boards) || does_move_cause_check(Move.new(move.start_pos, move.start_pos + 1, 5 if is_white else 11), boards) || does_move_cause_check(Move.new(move.start_pos, move.end_pos, 5 if is_white else 11), boards):
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
	
	if move.start_pos == move.end_pos:
		print("REJECTED: same square")
		return false
		
	var is_white : bool = true if move.type <= 5 else false
	
	if is_white != is_white_turn:
		print("REJECTED: wrong turn")
		return false
		
	var white_board : int = boards[0] | boards[1] | boards[2] | boards[3] | boards[4] | boards[5]
	var black_board : int = boards[6] | boards[7] | boards[8] | boards[9] | boards[10] | boards[11]
	
	if is_white && is_occupied(move.end_pos, boards, true, false) || !is_white && is_occupied(move.end_pos, boards, false, true):
		print("REJECTED: destination occupied by friendly")
		return false
		
	if move.type == 0 || move.type == 6:
		# Is pawn move
		if is_pawn_move_legal(move, boards, is_white) && !does_move_cause_check(move, boards):
			return true
		else:
			return false
	
	var ray : Ray = rays[move.start_pos * 64 + move.end_pos]
	
	if ray.type == RayType.INVALID:
		print("REJECTED: invalid ray between %d and %d" % [move.start_pos, move.end_pos])
		return false
		
	if ray.type == RayType.KNIGHT:
		if move.type != 1 && move.type != 7:
			return false
		return !does_move_cause_check(move, boards)
		
	if ray.type == RayType.ROOK:
		if move.type != 3 && move.type != 9 && move.type != 4 && move.type != 10 && move.type != 5 && move.type != 11:
			return false
			
		# Check for blocking piece
		if ray.ray & (white_board | black_board) != 0:
			print("REJECTED: ray is blocked. Blocking mask: %d" % [ray.ray & (white_board | black_board)])
			return false
			
		if (move.type == 5 || move.type == 11):
			if is_move_castle(move):
				return is_castle_move_legal(move, boards, true, true, is_white)
			return move.tile_length() == 1 && !does_move_cause_check(move, boards)
			
		return !does_move_cause_check(move, boards)
		
	if ray.type == RayType.BISHOP:
		if move.type != 2 && move.type != 8 && move.type != 4 && move.type != 10 && move.type != 5 && move.type != 11:
			return false
			
		# Check for blocking piece
		if ray.ray & (white_board | black_board) != 0:
			return false
		
		if (move.type == 5 || move.type == 11):
			if move.tile_length() == 1:
				return !does_move_cause_check(move, boards)
			return false
			
		return !does_move_cause_check(move, boards)
			
	return false
	
static func print_board(boards : PackedInt64Array) -> void:
	var piece_chars = ["P","N","B","R","Q","K","p","n","b","r","q","k"]
	for rank in range(7, -1, -1):
		var row = "%d | " % rank
		for file in range(8):
			var sq = rank * 8 + file
			var found = "."
			for i in range(12):
				if boards[i] >> sq & 1 == 1:
					found = piece_chars[i]
					break
			row += found + " "
		print(row)
	print("    - - - - - - - -")
	print("    a b c d e f g h")
