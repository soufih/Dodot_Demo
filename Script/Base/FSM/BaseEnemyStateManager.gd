extends BaseStateManager
class_name BaseEnemyStateManager

@export var Entity:BaseEnemy

func is_actived()->bool:
	if Entity:
		if Entity.Atived:
			return true
	return false
