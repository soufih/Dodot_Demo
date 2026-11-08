extends BaseUI
var opens := 0
var closes := 0

func on_open(payload: Dictionary) -> bool:
	opens += 1
	return not payload.get("reject", false)

func on_close(_reason: StringName) -> void:
	closes += 1
