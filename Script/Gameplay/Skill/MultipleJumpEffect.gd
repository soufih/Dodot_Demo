extends SkillEffect

@export_range(1, 10, 1, "or_greater") var max_jump_count: int = 2

func execute(context: SkillContext) -> void:
	context.caster.jump_limit_requested.emit(context.definition.id, max_jump_count)

func remove(context: SkillContext) -> void:
	context.caster.jump_limit_removed.emit(context.definition.id)
