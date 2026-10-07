class_name SkillContext
extends RefCounted

var caster: HeroProperty
var definition: SkillDefinition
var direction: float
var initial_velocity: Vector2
var cancelled := false
var execution_state: Node

func _init(owner_node: HeroProperty, data: SkillDefinition, move_direction: float = 0.0) -> void:
	caster = owner_node
	definition = data
	initial_velocity = caster.velocity
	direction = move_direction
	if is_zero_approx(direction):
		var sprite := caster.get_node_or_null("HeroSpirte") as AnimatedSprite2D
		direction = -1.0 if sprite != null and sprite.flip_h else 1.0
