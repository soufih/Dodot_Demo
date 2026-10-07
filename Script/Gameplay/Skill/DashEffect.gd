extends SkillEffect

func execute(context: SkillContext) -> void:
	context.caster.set_ability_enabled(&"dash", true)

func remove(context: SkillContext) -> void:
	context.caster.set_ability_enabled(&"dash", false)
