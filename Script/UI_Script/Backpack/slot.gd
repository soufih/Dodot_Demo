extends Button

@onready var label_item_amount: Label = $Label_item_amount
@onready var item_icon: TextureRect = $item_icon

var button_down_sign = false
var self_position:Vector2i
var self_icon:Texture2D
var self_id:int
var self_amount:int
var self_index:int
var tmp_slot:TmpSlot

func _ready() -> void:
	init()
	BackpackSystem.backpack_changed.connect(init)
	tmp_slot = UIManager.tmp_slot


func init():
	self_position = get_self_position()
	var item = BackpackSystem.get_item_by_postion(self_position)
	
	self_id = item.x
	self_amount = item.y
	item_icon.texture = ResourceManager.get_item_icon(self_id)
	set_button_icon(self_icon)
	#显示物品数量
	if self_amount > 1:
		label_item_amount.text = "%s" % self_amount
		label_item_amount.show()
	else:
		label_item_amount.hide()


func get_self_position()->Vector2i:
	var serial_number = get_parent().get_index()
	var column = get_parent().get_parent().get_columns()
	var x = serial_number / column + 1
	var y = serial_number % column + 1
	return Vector2i(x,y)


func _on_button_down() -> void:
	var result:Vector2i = BackpackSystem.interact_with_slot(tmp_slot.get_tmp_item().x, tmp_slot.get_tmp_item().y, self_position)
	
	#print(result)
	tmp_slot.set_icon(result.x)
	tmp_slot.set_tmp_item(result.x, result.y)
	tmp_slot.set_button_down_sign(true)
