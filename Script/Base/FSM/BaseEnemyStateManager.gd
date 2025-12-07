extends BaseStateManager
class_name BaseEnemyStateManager

@onready var Entity:BaseEnemy = self.get_parent()

func is_actived()->bool:
	if Entity:
		if Entity.Atived:
			return true
	return false
