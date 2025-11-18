extends Marker2D
class_name TmpSlot

@onready var Icon:Sprite2D = $Sprite2D
var TmpID: int = -1
var TmpAmount: int = 0


func _ready() -> void:
	z_index = 10


func set_icon(id:int):
	Icon.set_texture(ResourceManager.get_item_icon(id))


func set_tmp_item(id:int, amount:int):
	TmpID = id
	TmpAmount = amount

func get_tmp_item():
	return Vector2i(TmpID, TmpAmount)
