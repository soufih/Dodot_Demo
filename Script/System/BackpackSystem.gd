extends Node

signal backpack_changed#释放信号后更新UI

var Backpack: Dictionary[Vector2i, Vector2i]#[(id, index), postion]， 记录各物品位置
var Amounts:Dictionary[Vector2i, int]#[(id, index), amount]， 记录各物品数量

var ContianerX: int = 4
var ContianerY: int = 10
@onready var MaxContianer: int = ContianerX *ContianerY
var CurrentContianer: int = 0

#直接添加物品到背包中,返回溢出的物品id和数量
func direct_add_item(id: int, amount: int)->Vector2i:
	#检测合法性
	if ResourceManager.get_item_config(id) == null:
		return Vector2i(id, amount)
		
	var MaxStack: int = ResourceManager.get_item_max_stack(id)
	var TargetIndex:int = MaxContianer
	var TargetPostion:Vector2i = Vector2i(0, 0)
	
	#尝试在已有的物品堆中堆叠
	for index in range(1, MaxContianer):
		if Backpack.has(Vector2i(id, index)):
			var CurrentItemAmount =  Amounts[Vector2i(id, index)]
			if CurrentItemAmount < MaxStack:
				Amounts[Vector2i(id, index)] = min((amount+CurrentItemAmount), MaxStack)
				amount = (amount+CurrentItemAmount) - MaxStack
				
			#堆叠完毕退出
			if amount <= 0:
				break
				
		#记录最早查找到的未使用过的索引，以防上溢
		else:
			TargetIndex = min(index, TargetIndex)
	
	#如果物品在堆叠后仍有剩余
	if amount > 0:
		#若背包已满则直接返回
		if CurrentContianer+1 > MaxContianer:
			return Vector2i(id, amount)
		
		#查找背包未被使用过的格子
		for y in range(1, ContianerY):
			for x in range(1, ContianerX):
				if !Backpack.values().has(Vector2i(x, y)):
					TargetPostion = Vector2i(x, y)
					break
		
		if TargetPostion == Vector2i(0, 0):
			return Vector2i(id, amount)
		
		Backpack[Vector2i(id, TargetIndex)] = TargetPostion
		Amounts[Vector2i(id, TargetIndex)] = amount
		CurrentContianer += 1
		backpack_changed.emit()

	return Vector2i(id, 0)

#其他栏位物品与背包物品交互时使用，如仓库中物品与背包物品交互
func interact_with_slot(id: int, amount: int, TargetPostion: Vector2i)->Vector2i:
	var remain:Vector2i = Vector2i(-1, 0)
	var TargetItem = Backpack.find_key(TargetPostion)
	#检测合法性
	if TargetPostion.x > ContianerX ||  TargetPostion.y > ContianerY:
		erase_item(TargetItem)
		return Vector2i(id, amount)

	#检测合法性
	if ResourceManager.get_item_config(id) == null:
		erase_item(TargetItem)
		return Vector2i(id, amount)

	if !Backpack.values().has(TargetPostion):#若不存在则添加目标物品
		add_item(id, amount, TargetPostion)
		remain = Vector2i(id, 0)
	else:
		if TargetItem.x == id:#若背包格子中物品类型与目标相同则堆叠，反之交换
			remain = stack_item(id, amount, TargetItem)
		else:
			remain = exchange_item(id, amount, TargetItem)
			
	backpack_changed.emit()
	return remain

func add_item(id: int, amount: int, TargetPostion: Vector2i):
	var TargetIndex:int
	#记录最早查找到的未使用过的索引，以防上溢
	for index in range(1, MaxContianer):
		if !Backpack.has(Vector2i(id, index)):
			TargetIndex = index

	Backpack[Vector2i(id, TargetIndex)] = TargetPostion
	Amounts[Vector2i(id, TargetIndex)] = amount
	CurrentContianer += 1


func stack_item(id: int, amount: int, TargetItem: Vector2i)->Vector2i:
	var MaxStack: int = ResourceManager.get_item_max_stack(id)
	var CurrentItemAmount =  Amounts[TargetItem]
	if CurrentItemAmount < MaxStack:
		Amounts[TargetItem] = min((amount+CurrentItemAmount), MaxStack)
		amount = (amount+CurrentItemAmount) - MaxStack
	
	return Vector2i(id, max(0, amount))


func exchange_item(id: int, amount: int, TargetItem: Vector2i)->Vector2i:
	#保存目标物品
	var ID: int = TargetItem.x
	var AMOUNT: int = Amounts[TargetItem]

	add_item(id, amount, Backpack[TargetItem])

	return Vector2i(ID, AMOUNT)

#移除目标物品
func erase_item(TargetItem: Vector2i):
	if Backpack.has(TargetItem):
		Backpack.erase(TargetItem)
	
	if Amounts.has(TargetItem):
		Amounts.erase(TargetItem)
		
	CurrentContianer-=1
	backpack_changed.emit()

#获取目标物品
func get_item(TargetItem: Vector2i)->Vector2i:
	#检测合法性
	if ResourceManager.get_item_config(TargetItem.x) == null:
		erase_item(TargetItem)
		return Vector2i(-1, -1)

	return Vector2i(TargetItem.x, Amounts[TargetItem])


func get_contianer_x()->int:
	return ContianerX


func get_contianer_y()->int:
	return ContianerY


func get_current_contianer()->int:
	return CurrentContianer


func get_max_contianer()->int:
	return MaxContianer


func set_contianer_x(newContianerX: int):
	ContianerX = newContianerX
	backpack_changed.emit()

func set_contianer_y(newContianerY: int):
	ContianerY = newContianerY
	backpack_changed.emit()

func set_current_contianer(newCurrentContianer: int):
	CurrentContianer = newCurrentContianer
	backpack_changed.emit()


func set_max_contianer(newMaxContianer: int):
	MaxContianer = newMaxContianer
	backpack_changed.emit()
