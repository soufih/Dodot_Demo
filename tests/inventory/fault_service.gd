extends GridService
## 故障注入：覆盖提交/校验接口，验证真正的回滚和版本冲突分支。

var fail_commit: bool = false
var stale_on_validate: bool = false
var validation_hook: Callable

## 执行真实校验后，按测试开关注入一次版本变化或调用 validation_hook，返回原校验结果。
func validate_plan(staged: Dictionary) -> InventoryResult:
	var result := super.validate_plan(staged)
	if stale_on_validate:
		stale_on_validate = false
		container.revision += 1
	if validation_hook.is_valid():
		var hook := validation_hook
		validation_hook = Callable()
		hook.call()
	return result

## 执行真实提交后，fail_commit=true 时返回模拟失败，用于验证写入后的快照回滚。
func commit(staged: Dictionary) -> InventoryResult:
	var result := super.commit(staged)
	if fail_commit and result.is_ok():
		return InventoryResult.failure(InventoryResult.Code.INTERNAL_ERROR, "模拟提交后失败")
	return result
