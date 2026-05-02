class_name Move

var start_pos : int:
	set(value):
		start_pos = clampi(value, 0, 63)

var  end_pos : int:
	set(value):
		end_pos = clampi(value, 0, 63)

var type : int:
	set(value):
		type = clampi(value, 0, 11)

func _init(start_pos : int, end_pos : int, type : int) -> void:
	self.start_pos = start_pos
	self.end_pos = end_pos
	self.type = type
	
			
func is_one_tile_move() -> bool:
	var diff : Vector2i = Vector2i(start_pos % 8, start_pos / 8) - Vector2i(end_pos % 8, end_pos / 8)
	return max(abs(diff.x), abs(diff.y)) == 1
