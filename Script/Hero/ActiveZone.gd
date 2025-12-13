extends Node

var FreezeQueue:Array[BaseEnemy]

#活化进入区域的敌人
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Enemy"):
		body.Atived = true
		if FreezeQueue.has(body):
			FreezeQueue.erase(body)

#将离开区域的敌人加入冷冻队列
func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Enemy"):
		FreezeQueue.append(body)

#定期冷冻最长时间未再次进入区域的敌人
func _on_active_timer_timeout() -> void:
	if FreezeQueue.get(0):
		FreezeQueue.get(0).Atived = false
	FreezeQueue.pop_front()
