extends WarehouseService
## 整理故障夹具：验证真实写入后的恢复，以及版本冲突不覆盖外部变化。

var fail_after_commit: bool = false
var stale_on_commit: bool = false

## 根据开关制造旧版本或真实提交后失败，生产服务的整理逻辑保持不变。
func commit(staged: Dictionary) -> InventoryResult:
	if stale_on_commit:
		container.revision += 1
	var result := super.commit(staged)
	if fail_after_commit and result.is_ok():
		return InventoryResult.failure(InventoryResult.Code.INTERNAL_ERROR, "模拟仓库提交后失败")
	return result
