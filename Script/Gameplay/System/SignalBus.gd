extends Node

signal input_control(bool)
signal player_death
signal weapon_switch

signal ability_granted(player: Node2D, ability_id: StringName)
signal ability_granted_failed(player: Node, reason: StringName)

signal ability_cooldown_start(player: Node2D, id:StringName, ico:Texture2D,cooldown: float)

signal camera_room_entered(player: Node2D, boundary: CameraBoundary)
signal camera_room_exited(player: Node2D, boundary: CameraBoundary)
signal camera_boundary_changed(boundary: CameraBoundary)

## 关卡统计事件；由业务入口发布，关卡内的统计组件负责汇总。
signal character_damaged(source: BaseCharacter, target: BaseCharacter, amount: float)
signal enemy_defeated(enemy: BaseEnemy)
signal item_picked_up(actor: Node, config_id: int, quantity: int)
signal level_completed
signal level_statistics_requested
signal level_statistics_updated(statistics: Dictionary)
