extends Node

var dropped_item_scene:PackedScene = preload("uid://brjmaexsiviws")
var pickup_mention_scene:PackedScene = load("uid://guh862eg7yun")
var pickup_mention:pickupMention

func create_dropped_item(item_list:Array, postion:Vector2i):
	var dropped_item:DroppedItem = dropped_item_scene.instantiate()
	
	dropped_item.add_item(item_list)
	dropped_item.global_position = postion
	
	add_child(dropped_item)

func create_pickup_mention(item:Dictionary):
	if pickup_mention:
		await get_tree().create_timer(1.25).timeout
	pickup_mention = pickup_mention_scene.instantiate()
	UIManager.UILayer.add_child(pickup_mention)
	pickup_mention.set_display(item)
