extends Node

signal input_control(bool)
signal player_death
signal weapon_switch
signal skill_acquire_requested(target: HeroProperty, id: StringName)
signal skill_remove_requested(target: HeroProperty, id: StringName)
## 冷却通知携带所属人物，供界面或其他节点区分不同人物的技能。
signal skill_cooldown_started(target: HeroProperty, id: StringName, duration: float)
signal skill_cooldown_finished(target: HeroProperty, id: StringName)

signal camera_room_entered(player: Node2D, boundary: CameraBoundary)
signal camera_room_exited(player: Node2D, boundary: CameraBoundary)
signal camera_boundary_changed(boundary: CameraBoundary)

## 物品进入背包后通知玩家的掉落组件显示拾取提示。
signal items_picked_up(item: Dictionary)
