extends EquipmentSlotService
## 仅供回归：真实写入后返回失败，验证本地和跨容器恢复原数据及版本。

var fail_after_commit: bool = false

## 先执行服务真实提交，再按开关模拟故障；恢复逻辑必须由调用方执行。
func commit(staged: Dictionary) -> InventoryResult:
	var result := super.commit(staged)
	if fail_after_commit and result.is_ok():
		return InventoryResult.failure(InventoryResult.Code.INTERNAL_ERROR, "模拟装备提交后失败")
	return result
