class_name SplitMix64

var seed : int = 5749304859

static func _unsigned_right_shift(value: int, shift: int) -> int:
	if value >= 0:
		return value >> shift
	return (value >> shift) & (0x7FFFFFFFFFFFFFFF >> (shift - 1))

func random() -> int:
	seed += -7046029254386353131
	var z : int = seed
	z = (z ^ _unsigned_right_shift(z, 30)) * -4658895280553007687
	z = (z ^ _unsigned_right_shift(z, 27)) * -7764798050498590133
	return z ^ (z >> 31)
