class_name Util
extends RefCounted

func has_intersection(a: Array, b: Array) -> bool:
	for item in a:
		if b.has(item):
			return true
	return false
