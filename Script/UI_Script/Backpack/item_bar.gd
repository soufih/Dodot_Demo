extends BaseUI

@onready var item_container = $ScrollContainer/GridContainer
func _ready() -> void:
	begin()
	#加载物品格子
	var max_contianer = BackpackSystem.get_max_contianer()
	var slot = load("uid://6oby8ergpaw7")
	for i in range(0, max_contianer):
		item_container.add_child(slot.instantiate())
