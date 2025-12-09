extends Button


var button_down_sign = false
var self_position:int
var self_icon:Texture2D
var self_id:int
const self_amount:int = 1
var tmp_slot:TmpSlot

func _ready() -> void:
	EquipmentSlotSystem.equipment_slot_changed.connect(init)
	init()
	tmp_slot = get_parent().get_parent().get_parent().get_parent().get_parent().get_node("tmp_slot")


func _process(delta: float) -> void:
	#临时物品图标跟随鼠标移动
	if button_down_sign:
		tmp_slot.global_position = get_global_mouse_position()


func init():
	self_position = get_self_position()

	if get_parent().get_parent().name == "WeaponSlot":
		self_id = 	EquipmentSlotSystem.get_equipment(self_position, EquipmentSlotSystem.get_weapon_slot())

	else:
		self_id = 	EquipmentSlotSystem.get_equipment(self_position, EquipmentSlotSystem.get_relic_slot())


	self_icon = ResourceManager.get_item_icon(self_id)
	set_button_icon(self_icon)


func get_self_position()->int:
	var serial_number = get_parent().get_index()
	var x = serial_number + 1
	return x



func _on_button_down() -> void:
	var result
	if get_parent().get_parent().name == "WeaponSlot":
		result = EquipmentSlotSystem.interact_with_equipment_slot(tmp_slot.get_tmp_item().x,tmp_slot.get_tmp_item().y,self_position, EquipmentSlotSystem.get_weapon_slot())
		
	else:
		result = EquipmentSlotSystem.interact_with_equipment_slot(tmp_slot.get_tmp_item().x, tmp_slot.get_tmp_item().y,self_position, EquipmentSlotSystem.get_relic_slot())


	tmp_slot.set_icon(result.x)
	tmp_slot.set_tmp_item(result.x, result.y)
	button_down_sign = true
