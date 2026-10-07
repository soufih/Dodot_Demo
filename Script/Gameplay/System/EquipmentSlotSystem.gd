extends Node

signal equipment_slot_changed
signal current_weapon_changed

#索引为位置，值为物品id
var WeaponSlot:Array[int]
var RelicSlot:Array[int]

var WeaponMaxContianer: int = 2
var WeaponCurrentContianer: int = 0
var RelicMaxContianer: int = 4
var RelicCurrentContianer: int = 0

var CurrentWeapon:int = 1


func _ready() -> void:
	#0号位用于记录类型
	WeaponSlot.append(ENUM.ItemType.Weapon)
	RelicSlot.append(ENUM.ItemType.Relic)
	
	equipment_slot_changed.connect(_on_equipment_slot_changed)
	
	for i in range(0, WeaponMaxContianer):
		WeaponSlot.push_back(-1)
	
	for i in range(0, RelicMaxContianer):
		RelicSlot.push_back(-1)



func has_item(Slot:Array, index: int)->bool:
	if index >= Slot.size() || Slot[index] == -1:
		return false
	return true


func get_current_weapon()->int:
	return WeaponSlot.get(CurrentWeapon)


func get_next_weapon()->int:
	var NextIndex = get_next_weapon_index()
	if NextIndex == CurrentWeapon:
		return -1
	return WeaponSlot.get(NextIndex)


func get_next_weapon_index()->int:
	var index:int = CurrentWeapon
	index = index % WeaponMaxContianer + 1
	while !has_item(WeaponSlot, index) && index != CurrentWeapon:
		index = index % WeaponMaxContianer + 1
	return index


func switch_current_weapon(index:int):
	if index > WeaponMaxContianer:
		return

	CurrentWeapon = index
	current_weapon_changed.emit()

#更新已占用的装备格数量，不包含类型标记和空格。
func _on_equipment_slot_changed():
	WeaponCurrentContianer = 0
	RelicCurrentContianer = 0
	for index in range(1, WeaponSlot.size()):
		if WeaponSlot[index] != -1:
			WeaponCurrentContianer += 1
	for index in range(1, RelicSlot.size()):
		if RelicSlot[index] != -1:
			RelicCurrentContianer += 1

##原地重置装备数组，保留容量、类型标记和 UI 持有的引用。
func clear_equipment() -> void:
	WeaponSlot.resize(WeaponMaxContianer + 1)
	WeaponSlot.fill(-1)
	WeaponSlot[0] = ENUM.ItemType.Weapon
	RelicSlot.resize(RelicMaxContianer + 1)
	RelicSlot.fill(-1)
	RelicSlot[0] = ENUM.ItemType.Relic
	CurrentWeapon = 1
	equipment_slot_changed.emit()
	current_weapon_changed.emit()

#其他栏位装备与装备栏交互时使用，如背包中装备与装备栏交互
func interact_with_equipment_slot(id: int,amount: int,Postion: int, arr:Array)->Vector2i:
		#判断合法性
	if ResourceManager.get_item_config(id) == null && id != -1:
		return Vector2i(-1, 0)

	#判断合法性
	if !ResourceManager.get_item_item_type(id).has(arr[0]) && id != -1:
		return Vector2i(id, amount)

	var result:Vector2i = Vector2i(-1, 0)
	if (arr.get(Postion) != -1 && Postion )|| id == -1: #若当前位置已存在装备，则进行交换
		result = Vector2i(exchange_equipment(id, Postion, arr), 1)
	else:#不存在装备，放入物装备
		arr[Postion] = id
	
	equipment_slot_changed.emit()
	current_weapon_changed.emit()

	return result


func exchange_equipment(id: int, TargetPostion: int, arr: Array)->int:
	var TargetItem = arr[TargetPostion]
	arr[TargetPostion] = id

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
