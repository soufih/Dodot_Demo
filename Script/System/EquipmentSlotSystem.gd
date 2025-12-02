extends Node

signal equipment_slot_changed

#索引为位置，值为物品id
var WeaponSlot:Array[int]
var RelicSlot:Array[int]

var WeaponMaxContianer: int = 2
var WeaponCurrentContianer: int = 0
var RelicMaxContianer: int = 4
var RelicCurrentContianer: int = 0

func _ready() -> void:
	#0号位用于记录类型
	WeaponSlot.append(ENUM.ItemType.Weapon)
	RelicSlot.append(ENUM.ItemType.Relic)
	
	equipment_slot_changed.connect(_on_equipment_slot_changed)
	
	for i in range(0, WeaponMaxContianer):
		WeaponSlot.push_back(-1)
	
	for i in range(0, RelicMaxContianer):
		RelicSlot.push_back(-1)

#更新长度数值
func _on_equipment_slot_changed():
	WeaponCurrentContianer = WeaponSlot.size()
	RelicCurrentContianer  = RelicSlot.size()

#其他栏位装备与装备栏交互时使用，如背包中装备与装备栏交互
func interact_with_equipment_slot(id: int,amount: int,Postion: int, arr:Array)->Vector2i:
		#判断合法性
	if ResourceManager.get_item_config(id) == null && id != -1:
		return Vector2i(-1, 0)

	#判断合法性
	if !ResourceManager.get_item_item_type(id).has(arr[0]) && id != -1:
		return Vector2i(id, amount)

	if (arr.get(Postion) != -1 && Postion )|| id == -1: #若当前位置已存在装备，则进行交换
		return Vector2i(exchange_equipment(id, Postion, arr), 1)
	else:#不存在装备，放入物装备
		arr[Postion] = id
		equipment_slot_changed.emit()

	return Vector2i(-1, 0)


func exchange_equipment(id: int, TargetPostion: int, arr: Array)->int:
	var TargetItem = arr[TargetPostion]

	arr[TargetPostion] = id
	
	equipment_slot_changed.emit()
	return TargetItem

#移除装备
func erase_equipment(TargetPostion: int, arr: Array):
	if arr && TargetPostion:
		if arr.get(TargetPostion):
			arr.remove_at(TargetPostion)
			equipment_slot_changed.emit()

#获取指定位置的装备id
func get_equipment(TargetPostion: int, arr: Array)->int:
	if arr:
			return arr[TargetPostion]

	return -1


func get_weapon_slot()->Array:
	return WeaponSlot


func get_relic_slot()->Array:
	return RelicSlot


func get_weapon_current_contianer()->int:
	return WeaponCurrentContianer


func get_weapon_max_contianer()->int:
	return WeaponMaxContianer


func get_relic_current_contianer()->int:
	return RelicCurrentContianer


func get_relic_max_contianer()->int:
	return RelicMaxContianer


func set_weapon_current_contianer(newWeaponCurrentContianer:int):
	WeaponCurrentContianer = newWeaponCurrentContianer


func set_weapon_max_contianer(newWeaponMaxContianer:int):
	WeaponMaxContianer = newWeaponMaxContianer


func set_relic_current_contianer(newRelicCurrentContianer:int):
	RelicCurrentContianer = newRelicCurrentContianer


func set_relic_max_contianer(newRelicMaxContianer:int):
	RelicMaxContianer = newRelicMaxContianer
