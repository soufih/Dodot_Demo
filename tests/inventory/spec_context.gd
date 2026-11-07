extends RefCounted
## 轻量断言与独立配置夹具，无第三方测试框架依赖。

var assertions: int = 0
var failures: int = 0
var configs: Dictionary = {}

## 创建单格、可旋转矩形和不可旋转方形等独立测试配置，避免依赖实际物品资源。
func _init() -> void:
	for data in [[1, Vector2i.ONE, 10, false], [2, Vector2i(2, 1), 10, true],
			[3, Vector2i(2, 2), 1, false], [4, Vector2i(3, 1), 1, true]]:
		var config := ItemConfig.new()
		config.ItemID = data[0]
		config.GridSize = data[1]
		config.MaxStack = data[2]
		config.CanRotate = data[3]
		configs[config.ItemID] = config

## 按 id 返回测试配置，不存在时返回 null，供服务以 Callable 注入。
func lookup(id: int) -> ItemConfig:
	return configs.get(id)

## 按 grid 选择具体服务，以 size 和 id 初始化，并断言初始化成功后返回统一服务类型。
func service(grid: bool, size: Vector2i, id: String = "unit") -> InventoryService:
	var result: InventoryService = GridService.new(lookup) if grid else SlotService.new(lookup)
	code(result.initialize(id, size), InventoryResult.Code.OK, "初始化测试服务")
	return result

## 累计一条断言；condition=false 时记录失败并输出 label，不中断后续测试。
func expect(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

## 比较 actual 与 expected 的值是否相等，并把实际值和期望值附到失败说明。
func equal(actual: Variant, expected: Variant, label: String) -> void:
	expect(actual == expected, "%s (actual=%s, expected=%s)" % [label, actual, expected])

## 检查 result 的错误码；预期失败时额外断言 changed=false。
func code(result: InventoryResult, expected: InventoryResult.Code, label: String) -> void:
	equal(result.code, expected, label)
	if expected != InventoryResult.Code.OK:
		expect(not result.changed, label + "：失败 changed=false")

## 将 state 副本中的实例转为字段值数组，便于比较数量、方向、锚点和版本等完整状态。
func value(state: Dictionary) -> Dictionary:
	var normalized := state.duplicate(true)
	for id in normalized.items:
		var item: ItemInstance = normalized.items[id].instance
		normalized.items[id].instance = [item.instance_id, item.config_id, item.quantity, item.rotated]
	return normalized
