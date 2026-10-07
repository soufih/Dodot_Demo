extends Marker2D
class_name TmpSlot

@onready var Icon:Sprite2D = $Sprite2D
var TmpID: int = -1
var TmpAmount: int = 1

func _ready() -> void:
	#鼠标拖动物品图标显示于最上层
	z_index = 10

func _process(_delta: float) -> void:
	#临时物品图标跟随鼠标移动
	global_position = get_global_mouse_position()

##设置临时物品图标s
func set_icon(id:int):
	Icon.set_texture(ResourceManager.get_item_icon(id))

##设置临时物品数据
func set_tmp_item(id:int, amount:int):
	TmpID = id
	TmpAmount = amount

##获取临时物品数据
func get_tmp_item():
	return Vector2i(TmpID, TmpAmount)

func refresh():
	set_icon(TmpID)

##丢弃正在拖拽的物品，避免跨场景重新放回背包。
func clear_item() -> void:
	set_tmp_item(-1, 0)
	refresh()
