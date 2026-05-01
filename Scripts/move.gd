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
