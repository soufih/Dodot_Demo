class_name InventoryResult
extends RefCounted
## 所有背包命令的结果；查询与预览成功也不会标记 changed。

enum Code {
	OK, CONTAINER_NOT_FOUND, DUPLICATE_CONTAINER, ITEM_NOT_FOUND,
	INVALID_POSITION, INVALID_ITEM, OUT_OF_BOUNDS, OCCUPIED,
	RULE_REJECTED, UNSUPPORTED, STALE_STATE, INTERNAL_ERROR, NO_SPACE,
}

var code: Code = Code.OK
var message: String = ""
var changed: bool = false
var affected_ids: Array[int] = []
var payload: Variant = null

## 返回结果码是否为 OK；查询或无变化操作成功时 changed 仍可为 false。
func is_ok() -> bool:
	return code == Code.OK

## 构造成功结果；data 为附加数据，ids 为受影响实例，did_change 表示实际状态变化。
## 复制 ids 列表以隔离调用方修改，data 按原值保存，其隔离性由提供者负责。
static func success(data: Variant = null, ids: Array[int] = [], did_change: bool = false) -> InventoryResult:
	var result := InventoryResult.new()
	result.payload = data
	result.affected_ids = ids.duplicate()
	result.changed = did_change
	return result

## 以 error_code 和 description 构造失败结果，changed 保持 false，payload 为 null。
static func failure(error_code: Code, description: String) -> InventoryResult:
	var result := InventoryResult.new()
	result.code = error_code
	result.message = description
	return result
