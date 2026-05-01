class_name ChessEngine

static var rays : Array[Ray]
enum RayType {RAY, KNIGHT, INVALID}

class Ray:
	var ray : int
	var type : RayType
	
	func _init(ray : int, type : RayType):
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
	
	if abs(diff.x) == abs(diff.y) || diff.x == 0 || diff.y == 0:
		var length : int = max(abs(diff.x), abs(diff.y))
		for i in range(length - 1):
			var pos : Vector2i = end_pos + diff / length * (i + 1)
			var grid_pos : int = pos.x + pos.y * 8
			ray |= (1 << grid_pos)
		return Ray.new(ray, RayType.RAY)
	elif abs(diff.x) == 1 && abs(diff.y) == 2 || abs(diff.x) == 2 && abs(diff.y) == 1:
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

static func is_move_legal(move : Move, boards : PackedInt64Array) -> bool:
	if move.start_pos == move.end_pos:
		return false
		
	var white_board : int = boards[0] | boards[1] | boards[2] | boards[3] | boards[4] | boards[5]
	var black_board : int = boards[6] | boards[7] | boards[8] | boards[9] | boards[10] | boards[11]
	
	if move.type <= 5 && white_board >> move.end_pos & 1 == 1 || move.type >= 6 && black_board >> move.end_pos & 1 == 1:
		return false
	
	var ray : Ray = rays[move.start_pos * 64 + move.end_pos]
	
	if ray.type == RayType.INVALID:
		return false
	if ray.type == RayType.KNIGHT:
		# Check if new board is legal
		var new_boards : PackedInt64Array = boards
		for i in range(12):
			new_boards[i] &= ~(1 << move.end_pos)
		new_boards[move.type] ^= (1 << move.start_pos | 1 << move.end_pos)
		return !is_check(new_boards)
	if ray.type == RayType.RAY:
		# Check for blocking piece
		if ray.ray & (white_board | black_board) != 0:
			return false
		
		# Check if new board is legal
		var new_boards : PackedInt64Array = boards
		for i in range(12):
			new_boards[i] &= ~(1 << move.end_pos)
		new_boards[move.type] ^ (1 << move.start_pos | 1 << move.end_pos)
		return !is_check(new_boards)
	return false
