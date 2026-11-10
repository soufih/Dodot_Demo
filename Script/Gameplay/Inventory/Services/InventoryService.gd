@abstract
class_name InventoryService
extends RefCounted
## 背包服务的抽象契约：只声明统一接口与独占容器，不实现具体操作。
## SlotService / GridService / EquipmentSlotService 必须实现全部方法，Manager 仅依赖该契约。

var container: InventoryContainer
var _config_lookup: Callable
var _registered_owner: WeakRef

## 初始化并独占绑定容器；id 必须非空，size 为正数宽高。
## 成功返回 OK；重复初始化或非法参数返回错误，失败时不绑定容器。
@abstract func initialize(id: String, size: Vector2i) -> InventoryResult

## 查询 pos 对应的实例，网格中任意占位格均应定位到实例锚点。
## 成功时 payload 为 {instance, anchor} 的隔离副本；空格或非法坐标返回错误。
@abstract func query(pos: Vector2i) -> InventoryResult

## 只读校验完整实例 item 能否以 pos 为锚点添加。
## 返回实例、边界或占用规则的校验结果，不修改状态和版本。
@abstract func validate_add(item: ItemInstance, pos: Vector2i) -> InventoryResult

## 按 rotated 方向预览 item 在 pos 的放置结果，不修改原实例或容器。
## 若实例已在本容器中，先在暂存副本中释放其旧占位。
@abstract func can_place(item: ItemInstance, pos: Vector2i, rotated: bool) -> InventoryResult

## 在 pos 添加完整实例栈；实例数量不改变占位面积。
## 成功提交一次版本变更；失败保持原状态，禁止重复加入同一实例。
@abstract func add(item: ItemInstance, pos: Vector2i) -> InventoryResult

## 普通、网格背包先补同类堆，再按行寻找余量位置；装备栏按槽位规则自动穿戴。
## 网格余量优先当前方向，无位置且配置允许时尝试旋转；不修改输入实例，成功 payload 为实际接收锚点。
## 无法完整接收时返回 NO_SPACE，补堆与新增均不提交。
@abstract func quick_add(item: ItemInstance) -> InventoryResult

## 移除 pos 对应的完整实例及其全部占位格。
## 成功时 payload 返回已脱离容器的实例，由调用方接管。
@abstract func remove(pos: Vector2i) -> InventoryResult

## 将 from_pos 对应的实例移动到以 to_pos 为锚点的位置。
## 允许与自身旧区域重叠；原地移动返回 OK 且 changed=false。
## rotated=null 保留方向，指定 bool 时旋转和移动在同一次提交中完成。
@abstract func move(from_pos: Vector2i, to_pos: Vector2i, rotated: Variant = null) -> InventoryResult

## 交换 a_pos、b_pos 对应实例的锚点，两端都必须存在物品。
## 按最终占位整体校验；同一实例交换无变化，失败保持原状态。
## rotated 可指定被拖动的 a 实例方向，b 保留原方向；同一实例可在原位旋转。
@abstract func swap(a_pos: Vector2i, b_pos: Vector2i, rotated: Variant = null) -> InventoryResult

## 将 from_pos 的数量尽量合并到 to_pos 的同配置栈，余量保留原锚点和方向。
## 全部合并时清空源占位；成功 payload 为实际合并数量，同一实例返回 0 且不提交。
@abstract func stack(from_pos: Vector2i, to_pos: Vector2i) -> InventoryResult

## 只读预览 item 可向 pos 的已有栈合并多少数量，成功 payload 为正整数。
## 配置不同、同一实例、目标已满或不可堆叠时拒绝，不修改输入实例和真实状态。
@abstract func can_stack(item: ItemInstance, pos: Vector2i) -> InventoryResult

## 只读计算 pos 栈的分割数量；quantity=0 表示一半向下取整，必须保留至少一个。
## 成功 payload 为可分割数量，单件、空位置或非法数量返回错误。
@abstract func can_split(pos: Vector2i, quantity: int = 0) -> InventoryResult

## 将源栈的一部分放到目标空位或完整合入同类栈，quantity=0 表示对半分割。
## 源保留身份和占位；新栈分配新 ID，失败不改变状态，成功 payload 为目标实例副本。
## rotated 只应用到分割出的新实例，源栈方向不变。
@abstract func split(from_pos: Vector2i, to_pos: Vector2i, quantity: int = 0, rotated: Variant = null) -> InventoryResult

## 将 pos 对应实例的方向设为 rotated，具体占位规则由子类决定。
## 方向不变时无需提交；校验失败时保留原方向、占位和版本。
@abstract func rotate(pos: Vector2i, rotated: bool) -> InventoryResult

## 返回容器完整状态的深复制，矩阵行及实例可变字段均独立。
## 内部事务接口；调用前必须已成功初始化容器。
@abstract func stage_snapshot() -> Dictionary

## 只在 staged 暂存状态中添加 item，pos 为实例锚点。
## 按具体服务规则校验后写入记录和占位，不提交真实状态或递增版本。
@abstract func stage_add(staged: Dictionary, item: ItemInstance, pos: Vector2i) -> InventoryResult

## 从 staged 移除 id 对应的实例及其全部占位，返回该暂存实例。
## 内部接口；调用方应先确认 id 存在，不修改真实容器。
@abstract func stage_remove(staged: Dictionary, id: int) -> ItemInstance

## 仅增加 staged 中 pos 所属目标栈的数量，保留目标身份、方向与占位。
## 成功 payload 为实际接收数量；不修改传入 item，源数量由调用方在其暂存状态中扣除。
@abstract func stage_stack(staged: Dictionary, item: ItemInstance, pos: Vector2i) -> InventoryResult

## 仅在 staged 中扣除源数量并返回新 ID 的脱离实例，源始终保留至少一个。
@abstract func stage_split(staged: Dictionary, pos: Vector2i, quantity: int = 0) -> InventoryResult

## 在 staged 中完整接收分割实例，空位添加，同类栈合并；容量不足时拒绝整个分割。
## 返回目标实例副本，不交换其他物品，不提交真实状态。
@abstract func stage_place_split(staged: Dictionary, item: ItemInstance, pos: Vector2i) -> InventoryResult

## 只读校验 staged 的身份、尺寸、实例规则及矩阵与记录的一致性。
## 返回 OK 或校验错误；用于提交前验证完整最终状态。
@abstract func validate_plan(staged: Dictionary) -> InventoryResult

## 校验 staged 及其基准版本后，同步提交真实状态。
## 实际变化仅增加一次 revision；不 await、不通知外部，过期计划返回 STALE_STATE。
@abstract func commit(staged: Dictionary) -> InventoryResult

## 直接恢复事务前 snapshot 中的矩阵、实例和版本，不重新执行添加规则。
## 内部回滚接口，snapshot 必须来自本容器；返回恢复结果。
@abstract func restore(snapshot: Dictionary) -> InventoryResult
