extends Control
class_name item_bar

@onready var item_container = $ScrollContainer/GridContainer
func _ready() -> void:
	#加载物品格子
	var max_contianer = BackpackSystem.get_max_contianer()
	var slot = load(Path.SLOT_SCENE)
	for i in range(0, max_contianer):
		item_container.add_child(slot.instantiate())
