extends Marker2D
class_name TmpSlot

@onready var Icon:Sprite2D = $Sprite2D
var TmpID: int = -1
var TmpAmount: int = 1


func _ready() -> void:
	#鼠标拖动物品图标显示于最上层
	z_index = 10


	#设置临时物品图标
func set_icon(id:int):
	Icon.set_texture(ResourceManager.get_item_icon(id))

	#设置临时物品数据
func set_tmp_item(id:int, amount:int):
	TmpID = id
	TmpAmount = amount

	
func get_tmp_item():
	return Vector2i(TmpID, TmpAmount)
