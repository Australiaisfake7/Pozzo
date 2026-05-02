class_name Move

var start_pos : int:
	set(value):
		start_pos = clampi(value, 0, 63)

var end_pos : int:
	set(value):
		end_pos = clampi(value, 0, 63)

var type : int:
	set(value):
		type = clampi(value, 0, 11)

func _init(start_pos : int, end_pos : int, type : int) -> void:
	self.start_pos = start_pos
	self.end_pos = end_pos
	self.type = type
	
			
func vec_difference() -> Vector2i:
	var start_aligned_pos : Vector2i = Vector2i(start_pos % 8, floori(start_pos / 8.0))
	var end_aligned_pos : Vector2i = Vector2i(end_pos % 8, floori(end_pos / 8.0))
	
	return end_aligned_pos - start_aligned_pos

func tile_length() -> int:
	var vec_diff : Vector2i = vec_difference()
	
	return max(absi(vec_diff.x), absi(vec_diff.y))
	
