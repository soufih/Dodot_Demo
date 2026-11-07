extends Interactable


func can_interact(actor: Node) -> bool:
	return actor is HeroProperty and actor.CurrentHealth > 0.0 \
		and not UIManager.has_blocking_ui() and not UIManager.has_result_or_loading()


func interact(actor: Node) -> void:
	if can_interact(actor):
		UIManager.show_end_screen()
