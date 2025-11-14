extends Node

var Backpack: Dictionary[Vector2i, int]

var MaxContianer: int
var CurrentContianer: int

func add_item(id: int):
	if CurrentContianer < MaxContianer:
		if Backpack.has(id):
			var MaxStack = ResourceManager.get_item_max_stack(id)
			if Backpack[id] < MaxStack:
				Backpack[id] += 1
		else:
			Backpack[id] = 1
			CurrentContianer += 1

func erase_item(id: int):
	if Backpack.has(id):
		Backpack.erase(id)
		CurrentContianer -= 1

func get_current_contianer()->int:
	return CurrentContianer

func get_max_contianer()->int:
	return MaxContianer

func set_current_contianer(newCurrentContianer: int):
	CurrentContianer = newCurrentContianer

func set_max_contianer(newMaxContianer: int):
	MaxContianer = newMaxContianer
