class_name DeathZone
extends Area2D
## 角色进入即死亡；通过现有生命值接口触发玩家或敌人的死亡流程。


func _on_body_entered(body: Node2D) -> void:
	var character := body as BaseCharacter
	if character == null:
		return
	# 多个区域重叠或无敌状态切换时，不重复触发已死亡角色的死亡信号。
	if character.get_character_current_health() <= 0.0:
		return
	# 即死不经过普通伤害计算，因此不受伤害抗性影响。
	character.set_character_current_health(0.0)
