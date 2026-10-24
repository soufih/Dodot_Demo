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
