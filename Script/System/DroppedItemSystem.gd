extends Node

var dropped_item_scene:PackedScene = preload("uid://brjmaexsiviws")

func create_dropped_item(item_list:Array, postion:Vector2i):
	var dropped_item:DroppedItem = dropped_item_scene.instantiate()
	
	dropped_item.add_item(item_list)
	dropped_item.global_position = postion
	
	add_child(dropped_item)
