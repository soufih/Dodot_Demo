class_name SkillEffect
extends Resource

func can_execute(context: SkillContext) -> bool:
	return true

func execute(context: SkillContext) -> void:
	pass

func remove(context: SkillContext) -> void:
	pass

func should_finish(context: SkillContext) -> bool:
	return false
