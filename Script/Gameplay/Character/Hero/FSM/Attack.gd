extends BaseState

@export var WeaponPos:Marker2D

func enter():
	if WeaponPos.get_children().is_empty() || WeaponPos.get_child(0) == null:
		return

	get_parent().attacking = true
	var Weapon:AnimatedSprite2D = WeaponPos.get_child(0)
	Entity.velocity.x = 0
	AniPlayer.play("Attack")
	Weapon.emit_signal("on_attack", 0)
	if !Weapon.is_playing():
		await Weapon.animation_finished
	await AniPlayer.animation_finished

	get_parent().attacking = false
