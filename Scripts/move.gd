class_name Move

static func create(start_pos : int, end_pos : int, type : int) -> int:
	if start_pos > 63 || start_pos < 0 || end_pos > 63 || end_pos < 0 || type > 11 || type < 0:
		print("ERROR: incorrect values for move constructor")
	return start_pos | (end_pos << 6) | (type << 12)

static func file_diff(move : int) -> int:
	var start_file : int = (move & 63) % 8
	var end_file : int = (move >> 6 & 63) % 8
	
	return end_file - start_file

# The length of the move in tiles
static func tile_length(move : int) -> int:
	var start_pos : int = move & 63
	var end_pos : int = move >> 6 & 63
	
	var start_file : int = start_pos % 8
	var start_rank : int = start_pos / 8
	
	var end_file : int = end_pos % 8
	var end_rank : int = end_pos / 8
	
	return maxi(absi(end_file - start_file), absi(end_rank - start_rank))
