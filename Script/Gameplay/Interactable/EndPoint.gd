extends Interactable


func can_interact(actor: Node) -> bool:
	return actor is HeroProperty and actor.CurrentHealth > 0.0 \
		and not is_instance_valid(UIManager.end_ui) \
		and not is_instance_valid(UIManager.death_ui) and not UIManager.is_banned


func interact(actor: Node) -> void:
	if can_interact(actor):
		UIManager.show_end_screen()
