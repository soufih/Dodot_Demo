extends Node

signal backpack_changed#释放信号后更新UI
signal quick_add#快速添加物品后触发

var Backpack: Dictionary[Vector2i, Vector2i]#[(id, index), postion]， 记录各物品位置
var Amounts:Dictionary[Vector2i, int]#[(id, index), amount]， 记录各物品数量

var ContianerX: int = 4 #垂直为x
var ContianerY: int = 4#水平为y
@onready var MaxContianer: int = ContianerX *ContianerY
var CurrentContianer: int = 0

#func test():
	#print(1)

func _ready() -> void:
	_on_backpack_changed()
	#quick_add.connect(test)
	#quick_add_item(0, 99)

func _on_backpack_changed():
	CurrentContianer = Backpack.size()

##直接添加物品到背包中,返回溢出的物品id和数量
func quick_add_item(id: int, amount: int)->Vector2i:
	#检测合法性
	if ResourceManager.get_item_config(id) == null:
		return Vector2i(id, amount)

	var MaxStack: int = ResourceManager.get_item_max_stack(id)
	var TargetIndex:int = MaxContianer
	var TargetPostion:Vector2i = Vector2i(-1, 0)
	
	#尝试在已有的物品堆中堆叠
	for index in range(1, MaxContianer+1):
		if Backpack.has(Vector2i(id, index)):
			
			var CurrentItemAmount =  Amounts[Vector2i(id, index)]
			if CurrentItemAmount < MaxStack:
				
				Amounts[Vector2i(id, index)] = min((amount+CurrentItemAmount), MaxStack)
				amount = (amount+CurrentItemAmount) - MaxStack
				
			#堆叠完毕退出
			if amount <= 0:
				break
				
		#记录最早查找到的未使用过的索引，以防上溢
		#else:
			#TargetIndex = min(index, TargetIndex)

	#如果物品在堆叠后仍有剩余
	while amount > 0:
		#若背包已满则直接返回
		if CurrentContianer+1 > MaxContianer:
			return Vector2i(id, amount)
		
		#记录最早查找到的未使用过的索引，以防上溢
		for index in range(1, MaxContianer):
			if !Backpack.has(Vector2i(id, index)):
				TargetIndex = index
				break
		
		#查找背包未被使用过的格子
		for x in range(1, ContianerY+1):
			var LastPostion = TargetPostion
			for y in range(1, ContianerX+1):
				if !Backpack.values().has(Vector2i(x, y)):
					TargetPostion = Vector2i(x, y)
					break
			if TargetPostion != LastPostion:
				break

		if TargetPostion == Vector2i(-1, 0):
			return Vector2i(id, amount)
		
		Backpack[Vector2i(id, TargetIndex)] = TargetPostion
		Amounts[Vector2i(id, TargetIndex)] = min(MaxStack, amount)
		amount -= MaxStack
		CurrentContianer += 1
		backpack_changed.emit()
		quick_add.emit()
	return Vector2i(id, 0)

##其他栏位物品与背包物品交互时使用，如仓库中物品与背包物品交互
func interact_with_slot(id: int, amount: int, TargetPostion: Vector2i)->Vector2i:
	var remain:Vector2i = Vector2i(-1, 0)
	var TargetItem = Backpack.find_key(TargetPostion)
	print(TargetPostion)
	#检测合法性
	#if TargetPostion.x > ContianerX ||  TargetPostion.y > ContianerY:
		#return Vector2i(id, amount)

	if !Backpack.values().has(TargetPostion):#若不存在则添加目标物品
		add_item(id, amount, TargetPostion)
		remain = Vector2i(-1, 0)
	else:
		if TargetItem.x == id:#若背包格子中物品类型与目标相同则堆叠，反之交换
			remain = stack_item(id, amount, TargetItem)
		else:
			remain = exchange_item(id, amount, TargetItem)

	backpack_changed.emit()
	return remain


func add_item(id: int, amount: int, TargetPostion: Vector2i):
		#检测合法性
	if ResourceManager.get_item_config(id) == null:
		return

	var TargetIndex:int
	#记录最早查找到的未使用过的索引，以防上溢
	for index in range(1, MaxContianer):
		if !Backpack.has(Vector2i(id, index)):
			TargetIndex = index
			break

	Backpack[Vector2i(id, TargetIndex)] = TargetPostion
	Amounts[Vector2i(id, TargetIndex)] = amount


func stack_item(id: int, amount: int, TargetItem: Vector2i)->Vector2i:
	var MaxStack: int = ResourceManager.get_item_max_stack(id)
	var CurrentItemAmount =  Amounts[TargetItem]
	if CurrentItemAmount < MaxStack:
		Amounts[TargetItem] = min((amount+CurrentItemAmount), MaxStack)
		amount = (amount+CurrentItemAmount) - MaxStack
	
	if amount <= 0:
		return Vector2i(-1, 0)
	
	return Vector2i(id, amount)


func exchange_item(id: int, amount: int, TargetItem: Vector2i)->Vector2i:
	#保存目标物品
	var ID: int = TargetItem.x
	var AMOUNT: int = Amounts[TargetItem]
	var Pos: Vector2i = Backpack[TargetItem]

	erase_item_by_item(TargetItem)
	add_item(id, amount, Pos)

	return Vector2i(ID, AMOUNT)

##移除目标物品
func erase_item_by_item(TargetItem: Vector2i):
	if Backpack.has(TargetItem):
		Backpack.erase(TargetItem)

	if Amounts.has(TargetItem):
		Amounts.erase(TargetItem)

	backpack_changed.emit()

##移除目标物品
func erase_item_by_position(TargetPosition: Vector2i):
	if !Backpack.values().has(TargetPosition):
		return

	var TargetItem: Vector2i
	TargetItem = Backpack.find_key(TargetPosition)

	Backpack.erase(TargetItem) 
	Amounts.erase(TargetItem)

##根据索引获取目标物品
func get_item_by_id_index(TargetItem: Vector2i)->Vector2i:
	#检测合法性
	if ResourceManager.get_item_config(TargetItem.x) == null:
		return Vector2i(-1, -1)

	if !Amounts.get(TargetItem):
		return Vector2i(-1, -1)

	return Vector2i(TargetItem.x, Amounts.get(TargetItem))

##根据位置获取目标物品
func get_item_by_postion(TargetPostion: Vector2i)->Vector2i:
	if !Backpack.values().has(TargetPostion):
		return Vector2i(-1, -1)

	var item = Backpack.find_key(TargetPostion)
	var id = item.x
	var amount = Amounts[item]

	return Vector2i(id, amount)


func get_backpack()->Dictionary:
	return Backpack


func get_amounts()->Dictionary:
	return Amounts


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
