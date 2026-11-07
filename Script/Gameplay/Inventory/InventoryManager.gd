extends Node
## Autoload 统一入口：注册、路由、通知。占位规则由 Service 负责，事务由独立模块协调。

signal container_changed(container_id: String, revision: int, changed_ids: Array[int])
signal operation_failed(code: InventoryResult.Code, message: String)

enum ServiceType { SLOT, GRID, EQUIPMENT_SLOT, WAREHOUSE }

# 内部注册表不对 UI 暴露；查询返回独立副本。
var _containers: Dictionary = {}
var _transaction_lock: bool = false
var _config_lookup: Callable

## 初始化默认配置查询，委托现有 ResourceManager 读取物品定义。
func _ready() -> void:
	configure(ResourceManager.get_item_config)

## 注入 config_lookup(config_id) -> ItemConfig 查询函数，便于替换配置来源和测试。
## 仅在无容器且无事务执行时允许设置；返回 OK 或 RULE_REJECTED。
func configure(config_lookup: Callable) -> InventoryResult:
	if _transaction_lock or not _containers.is_empty():
		return _report(InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "已有容器时不能替换配置来源"))
	_config_lookup = config_lookup
	return InventoryResult.success()

## 按 service_type 创建服务，以 id 和 size 初始化后注册。
## EQUIPMENT_SLOT 必须提供 equipment_slots，size 为槽位数量 × 1；其他类型不接受装备槽配置。
## 全部成功才保留服务；非法尺寸、重复 ID 或不支持的类型返回错误。
func create_container(id: String, size: Vector2i, service_type: ServiceType,
		equipment_slots: Array[EquipmentSlotDefinition] = []) -> InventoryResult:
	var available := _can_register(id)
	if not available.is_ok():
		return _report(available)
	if service_type in [ServiceType.SLOT, ServiceType.GRID, ServiceType.WAREHOUSE] and not equipment_slots.is_empty():
		return _report(InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "此类容器不接受装备槽配置"))
	var service: InventoryService
	match service_type:
		ServiceType.SLOT:
			service = SlotService.new(_config_lookup)
		ServiceType.GRID:
			service = GridService.new(_config_lookup)
		ServiceType.EQUIPMENT_SLOT:
			service = EquipmentSlotService.new(_config_lookup, equipment_slots)
		ServiceType.WAREHOUSE:
			service = WarehouseService.new(_config_lookup)
		_:
			return _report(InventoryResult.failure(InventoryResult.Code.UNSUPPORTED, "未知容器服务类型"))
	var result := service.initialize(id, size)
	if not result.is_ok():
		return _report(result)
	return register_container(id, service)

## 将已初始化的 service 注册到 id，校验身份、已有绑定及实例唯一归属。
## 失败不加入注册表；成功后 Manager 持有服务，服务仅弱引用其注册者。
func register_container(id: String, service: InventoryService) -> InventoryResult:
	var result := _can_register(id)
	if not result.is_ok():
		return _report(result)
	if service == null or service.container == null or service.container.container_id != id:
		return _report(InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "服务未初始化或容器 ID 不匹配"))
	if service._registered_owner != null and service._registered_owner.get_ref() != null:
		return _report(InventoryResult.failure(InventoryResult.Code.DUPLICATE_CONTAINER, "此服务已经注册"))
	result = service.validate_plan(service.stage_snapshot())
	if not result.is_ok():
		return _report(result)
	for item_id in service.container.items:
		if _has_instance(item_id):
			return _report(InventoryResult.failure(InventoryResult.Code.INVALID_ITEM, "实例已经属于已注册容器"))
	_containers[id] = service
	service._registered_owner = weakref(self)
	return InventoryResult.success()

## 注销 id 并释放本 Manager 对服务的持有关系，不清空服务内部物品。
## 事务执行时拒绝注销；未知 ID 返回 CONTAINER_NOT_FOUND。
func unregister_container(id: String) -> InventoryResult:
	if _transaction_lock:
		return _report(_locked())
	if not _containers.has(id):
		return _report(_missing())
	var service: InventoryService = _containers[id]
	service._registered_owner = null
	_containers.erase(id)
	return InventoryResult.success()

## 只读检查容器是否已注册，供角色重建时绑定既有会话，不发送失败信号。
func has_container(id: String) -> bool:
	return _containers.has(id)

## 只读检查稳定 ID 是否绑定仓库服务，交互物不会误将同名背包当作仓库打开。
func is_warehouse(id: String) -> bool:
	return _containers.get(id) is WarehouseService

## 返回排序后的容器 ID 副本，供调试或选择目标容器使用。
func get_container_ids() -> PackedStringArray:
	var ids := PackedStringArray(_containers.keys())
	ids.sort()
	return ids

## 查询 id 容器内 pos 的物品，返回 {instance, anchor} 隔离副本。
## 失败返回空字典并发送 operation_failed，不暴露内部可变实例。
func get_item_at(id: String, pos: Vector2i) -> Dictionary:
	if not _containers.has(id):
		_report(_missing())
		return {}
	var result: InventoryResult = _containers[id].query(pos)
	_report(result)
	return result.payload if result.is_ok() else {}

## 返回 id 容器的完整隔离快照，调用方修改副本不会影响容器。
## 未知 ID 返回空字典并发送 operation_failed。
func get_snapshot(id: String) -> Dictionary:
	if not _containers.has(id):
		_report(_missing())
		return {}
	return _containers[id].stage_snapshot()

## 将装备槽业务标识转换为内部坐标；只读操作，未知容器或非装备栏明确返回错误。
func get_slot_position(id: String, slot_id: StringName) -> InventoryResult:
	if not _containers.has(id):
		return _report(_missing())
	var service: InventoryService = _containers[id]
	if not service is EquipmentSlotService:
		return _report(InventoryResult.failure(InventoryResult.Code.UNSUPPORTED, "此容器不支持装备槽标识"))
	return _report(service.get_slot_position(slot_id))

## 将装备栏内部坐标转换为业务标识，不暴露服务实例及可变槽位配置。
func get_slot_id(id: String, pos: Vector2i) -> InventoryResult:
	if not _containers.has(id):
		return _report(_missing())
	var service: InventoryService = _containers[id]
	if not service is EquipmentSlotService:
		return _report(InventoryResult.failure(InventoryResult.Code.UNSUPPORTED, "此容器不支持装备槽标识"))
	return _report(service.get_slot_id(pos))

## 按配置 ID、数量及方向创建新实例并放入 pos；成功 payload 返回实际新实例的隔离副本。
## 配置、数量和占位校验由 Service 执行；已有物品保留身份的移动应使用转移接口。
func add_to_container(id: String, config_id: int, quantity: int, pos: Vector2i, rotated: bool = false) -> InventoryResult:
	if _transaction_lock:
		return _report(_locked())
	if not _containers.has(id):
		return _report(_missing())
	var item := ItemInstance.new(config_id, quantity, rotated)
	var result := _operate(id, &"add", [item, pos])
	if result.is_ok():
		result.payload = item.copy()
	return result

## 按配置 ID、数量及首选方向创建新实例，由具体服务快速添加；成功 payload 为实际锚点。
## 不接收外部实例或实例 ID，沿用统一事务锁、提交和变更通知。
func quick_add_to_container(id: String, config_id: int, quantity: int = 1, rotated: bool = false) -> InventoryResult:
	if _transaction_lock:
		return _report(_locked())
	if not _containers.has(id):
		return _report(_missing())
	var item := ItemInstance.new(config_id, quantity, rotated)
	return _operate(id, &"quick_add", [item])

## 移除 id 容器内 pos 对应的完整栈，返回结果的 payload 为脱离容器的实例。
func remove_from_container(id: String, pos: Vector2i) -> InventoryResult:
	return _operate(id, &"remove", [pos])

## 将 id 容器内 from_pos 的实例移动到以 to_pos 为锚点的位置。
## rotated 可指定落地方向，与移动一起提交；位置和方向均不变时不递增版本、不通知。
func move_in_container(id: String, from_pos: Vector2i, to_pos: Vector2i, rotated: Variant = null) -> InventoryResult:
	return _operate(id, &"move", [from_pos, to_pos, rotated])

## 交换 id 容器内 a_pos、b_pos 的实例；rotated 只应用于 a，失败时双方保持原值。
func swap_in_container(id: String, a_pos: Vector2i, b_pos: Vector2i, rotated: Variant = null) -> InventoryResult:
	return _operate(id, &"swap", [a_pos, b_pos, rotated])

## 将同容器源栈尽量合并到目标栈，余量原位保留；payload 为实际合并数量。
func stack_in_container(id: String, from_pos: Vector2i, to_pos: Vector2i) -> InventoryResult:
	return _operate(id, &"stack", [from_pos, to_pos])

## 只读预览 item 向 id 容器 pos 的栈可合并多少数量，不提交或发送变更通知。
func can_stack(id: String, item: ItemInstance, pos: Vector2i) -> InventoryResult:
	if not _containers.has(id):
		return _report(_missing())
	return _report(_containers[id].can_stack(item, pos))

## 将源栈尽量合并到目标同配置栈；同容器路由本地服务，跨容器使用双边原子事务。
## 目标实例及方向保持不变，余量留在源位置；payload 为实际合并数量。
func stack_between_containers(from_id: String, to_id: String, from_pos: Vector2i, to_pos: Vector2i) -> InventoryResult:
	if from_id == to_id:
		return stack_in_container(from_id, from_pos, to_pos)
	return _cross_container(from_id, to_id, from_pos, to_pos, InventoryTransaction.Operation.STACK)

## 只读预览 pos 栈的分割数量，默认对半向下取整，不修改数量或版本。
func can_split(id: String, pos: Vector2i, quantity: int = 0) -> InventoryResult:
	if not _containers.has(id):
		return _report(_missing())
	return _report(_containers[id].can_split(pos, quantity))

## 同容器分割并放置物品，源 ID 和方向保留；rotated 仅指定新栈方向，payload 为目标实例副本。
func split_in_container(id: String, from_pos: Vector2i, to_pos: Vector2i, quantity: int = 0, rotated: Variant = null) -> InventoryResult:
	return _operate(id, &"split", [from_pos, to_pos, quantity, rotated])

## 将源栈的一部分原子放入目标空位或同类栈，quantity=0 时对半分割。
## rotated 仅指定分割出的新栈方向；任一失败时双方保持原状，同容器 ID 路由本地分割。
func split_between_containers(from_id: String, to_id: String, from_pos: Vector2i, to_pos: Vector2i, quantity: int = 0, rotated: Variant = null) -> InventoryResult:
	if from_id == to_id:
		return split_in_container(from_id, from_pos, to_pos, quantity, rotated)
	return _cross_container(from_id, to_id, from_pos, to_pos, InventoryTransaction.Operation.SPLIT, quantity, rotated)

## 将 id 容器内 pos 对应实例的方向设置为 rotated，返回具体服务的旋转结果。
func rotate_in_container(id: String, pos: Vector2i, rotated: bool) -> InventoryResult:
	return _operate(id, &"rotate", [pos, rotated])

## 只读预览 item 以 rotated 方向放到 id 容器 pos 的结果。
## 不会提交状态；预览通过后，实际命令仍需重新校验。
func can_place(id: String, item: ItemInstance, pos: Vector2i, rotated: bool) -> InventoryResult:
	if not _containers.has(id):
		return _report(_missing())
	return _report(_containers[id].can_place(item, pos, rotated))

## 把 from_id 的 f_pos 实例完整转移到 to_id 的 t_pos，保留 ID 和数量，rotated=null 保留方向。
## 目标占用时失败，不自动合并或交换；相同容器 ID 转为本地移动。
func switch_to_container(from_id: String, to_id: String, f_pos: Vector2i, t_pos: Vector2i, rotated: Variant = null) -> InventoryResult:
	if from_id == to_id:
		return move_in_container(from_id, f_pos, t_pos, rotated)
	return _cross_container(from_id, to_id, f_pos, t_pos, InventoryTransaction.Operation.TRANSFER, 0, rotated)

## 交换 a_id/a_pos 与 b_id/b_pos 的实例，按各自目标服务规则校验最终状态。
## 同一容器转为本地交换；跨容器任一提交失败时恢复双方快照。
## rotated 指定被拖动 a 实例的落地方向，另一实例保留原方向。
func swap_between_containers(a_id: String, b_id: String, a_pos: Vector2i, b_pos: Vector2i, rotated: Variant = null) -> InventoryResult:
	if a_id == b_id:
		return swap_in_container(a_id, a_pos, b_pos, rotated)
	return _cross_container(a_id, b_id, a_pos, b_pos, InventoryTransaction.Operation.SWAP, 0, rotated)

## 持有事务锁协调两个已注册服务，operation 指定转移、交换、堆叠或分割。
## 成功后先释放锁再发送双方变更通知，失败仅报告错误；不向外暴露内部通知数据。
func _cross_container(a_id: String, b_id: String, a_pos: Vector2i,
		b_pos: Vector2i, operation: InventoryTransaction.Operation, quantity: int = 0, rotated: Variant = null) -> InventoryResult:
	if _transaction_lock:
		return _report(_locked())
	if not _containers.has(a_id) or not _containers.has(b_id):
		return _report(_missing())
	var a: InventoryService = _containers[a_id]
	var b: InventoryService = _containers[b_id]
	_transaction_lock = true
	var still_registered := func() -> bool:
		return _containers.get(a_id) == a and _containers.get(b_id) == b
	var result := InventoryTransaction.execute(a, b, a_pos, b_pos, operation, still_registered, quantity, rotated)
	_transaction_lock = false
	if result.is_ok():
		var notifications: Array = result.payload.notifications
		var payload: Dictionary = result.payload
		result.payload = null
		if operation == InventoryTransaction.Operation.STACK:
			result.payload = payload.moved_quantity
		elif operation == InventoryTransaction.Operation.SPLIT:
			result.payload = payload.split_item
		for notice in notifications:
			container_changed.emit(notice.id, notice.revision, notice.ids)
	return _report(result)

## 仓库专用整理入口；沿用统一事务锁与提交后通知，其他容器明确返回不支持。
func organize_warehouse(id: String) -> InventoryResult:
	if _transaction_lock:
		return _report(_locked())
	if not _containers.has(id):
		return _report(_missing())
	if not _containers[id] is WarehouseService:
		return _report(InventoryResult.failure(InventoryResult.Code.UNSUPPORTED, "此容器不支持仓库整理"))
	return _operate(id, &"organize", [])

## 将 method 和 args 路由到 id 对应服务，并在同步执行期间禁止重入。
## 仅成功且 changed=true 时发送容器变更通知，最后返回原操作结果。
func _operate(id: String, method: StringName, args: Array) -> InventoryResult:
	if _transaction_lock:
		return _report(_locked())
	if not _containers.has(id):
		return _report(_missing())
	_transaction_lock = true
	var service: InventoryService = _containers[id]
	var result: InventoryResult = service.callv(method, args)
	_transaction_lock = false
	if result.is_ok() and result.changed:
		container_changed.emit(id, service.container.revision, result.affected_ids.duplicate())
	return _report(result)

## 检查实例 id 是否已存在于本 Manager 的任意已注册容器，用于避免重复归属。
func _has_instance(id: int) -> bool:
	for service in _containers.values():
		if service.container.items.has(id):
			return true
	return false

## 只读检查注册前提：未持有事务锁、id 非空且未重复；返回校验结果。
func _can_register(id: String) -> InventoryResult:
	if _transaction_lock:
		return _locked()
	if id.strip_edges().is_empty():
		return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "容器 ID 不能为空")
	if _containers.has(id):
		return InventoryResult.failure(InventoryResult.Code.DUPLICATE_CONTAINER, "容器 ID 重复")
	return InventoryResult.success()

## 原样返回 result；失败时额外发送 operation_failed(code, message)，不发送变更通知。
func _report(result: InventoryResult) -> InventoryResult:
	if not result.is_ok():
		operation_failed.emit(result.code, result.message)
	return result

## 构造容器未注册的统一失败结果，供路由和查询复用。
func _missing() -> InventoryResult:
	return InventoryResult.failure(InventoryResult.Code.CONTAINER_NOT_FOUND, "容器未注册")

## 构造事务期间禁止重入或修改注册表的统一失败结果。
func _locked() -> InventoryResult:
	return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "事务期间禁止重入或修改注册表")
