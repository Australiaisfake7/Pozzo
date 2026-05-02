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

static func is_check(boards : PackedInt64Array) -> bool:
	return false

static func does_move_cause_check(move : Move, boards : PackedInt64Array):
		# Check if new board is legal
		var new_boards : PackedInt64Array = boards
		for i in range(12):
			new_boards[i] &= ~(1 << move.end_pos)
		new_boards[move.type] ^= (1 << move.start_pos | 1 << move.end_pos)
		return is_check(new_boards)

static func is_pawn_move_legal(move : Move, boards : PackedInt64Array):
		var white_board : int = boards[0] | boards[1] | boards[2] | boards[3] | boards[4] | boards[5]
		var black_board : int = boards[6] | boards[7] | boards[8] | boards[9] | boards[10] | boards[11]
		var all_board : int = white_board | black_board
		
		var is_white : bool = move.type == 0
		var direction : int = 1 if is_white else -1
		var start_rank : int = move.start_pos / 8
		var end_rank : int = move.end_pos / 8
		var start_file : int = move.start_pos % 8
		var end_file : int = move.end_pos % 8
		var rank_diff : int = (end_rank - start_rank) * direction
		var file_diff : int = abs(end_file - start_file)		
		
		if rank_diff == 1:
			if file_diff == 0 && all_board >> move.end_pos & 1 == 0:
				return true
			elif file_diff == 1:
				if is_white:
					return black_board >> move.end_pos & 1 == 1
				else:
					return white_board >> move.end_pos & 1 == 1
			else:
				return false
		elif rank_diff == 2 && start_rank == (1 if is_white else 6) && (all_board >> (move.start_pos + 8 * direction)) & 1 == 0 && all_board >> move.end_pos & 1 == 0:
			return true
		else:
			return false

static func is_move_legal(move : Move, boards : PackedInt64Array) -> bool:
	if move.start_pos == move.end_pos:
		return false
		
	var white_board : int = boards[0] | boards[1] | boards[2] | boards[3] | boards[4] | boards[5]
	var black_board : int = boards[6] | boards[7] | boards[8] | boards[9] | boards[10] | boards[11]
	
	if move.type <= 5 && white_board >> move.end_pos & 1 == 1 || move.type >= 6 && black_board >> move.end_pos & 1 == 1:
		return false
		
	if move.type == 0 || move.type == 6:
		# Is pawn move
		if is_pawn_move_legal(move, boards) && !does_move_cause_check(move, boards):
			return true
		else:
			return false
	
	var ray : Ray = rays[move.start_pos * 64 + move.end_pos]
	
	if ray.type == RayType.INVALID:
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
			return false
			
		if (move.type == 5 || move.type == 11) && !move.is_one_tile_move():
			return false
			
		return !does_move_cause_check(move, boards)
		
	if ray.type == RayType.BISHOP:
		if move.type != 2 && move.type != 8 && move.type != 4 && move.type != 10 && move.type != 5 && move.type != 11:
			return false
			
		# Check for blocking piece
		if ray.ray & (white_board | black_board) != 0:
			return false
		
		if (move.type == 5 || move.type == 11) && !move.is_one_tile_move():
			return false
			
		return !does_move_cause_check(move, boards)
			
	return false
