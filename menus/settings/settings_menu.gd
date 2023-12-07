extends CanvasLayer

signal opponent(who)
signal close
signal starter(who)
signal reset_score
signal keep_score(value)

func _on_person_button_pressed():
	opponent.emit("player")

func _on_easy_ai_button_pressed():
	opponent.emit("easy_ai")

func _on_medium_ai_button_pressed():
	opponent.emit("medium_ai")

func _on_hard_ai_button_pressed():	
	opponent.emit("hard_ai")

func _on_circle_start_button_pressed():
	starter.emit("circle")

func _on_winner_start_button_pressed():
	starter.emit("winner")

func _on_loser_start_button_pressed():
	starter.emit("loser")

func _on_alternate_start_button_pressed():
	starter.emit("alternate")

func _on_reset_score_button_pressed():
	reset_score.emit()

func _on_close_button_pressed():
	close.emit()

func _on_keep_score_button_toggled(button_pressed):
	keep_score.emit(button_pressed)
