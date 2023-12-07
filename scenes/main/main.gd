## Paper Games - Tic Tac Toe
##
## Play 2-player or against varied difficulty AI
extends Node2D

enum WinLocations {
	NONE = 0,
	ROW_TOP = 1,
	ROW_MIDDLE = 2,
	ROW_BOTTOM = 3,
	COLUMN_LEFT = 4,
	COLUMN_MIDDLE = 5,
	COLUMN_RIGHT = 6,
	DIAGONAL_DESC = 7,
	DIAGONAL_ASC = 8, }

enum Opponents { 
	HUMAN, 
	TOASTER, 
	ROOMBA, 
	MEGATRON, }

# possible rules for who starts the next game
enum StartRules { 
	ALTERNATE, 
	CIRCLE, 
	WINNER, 
	LOSER, }

# these allow allow us to use the o or x images as vars in code
@export var o_scene : PackedScene
@export var x_scene : PackedScene
@export var winning_line_scene : PackedScene

# TODO: complete mini max with a/b pruning
# we only want to show this option when it is working
var hide_minimax = true

# whose turn it is can be 1 or -1 (player 2)
var active_player : int
var start_player : int
var start_rule : StartRules
var opponent : Opponents
# this prop makes getting active opponent more readable in code
var active_opponent: int:
	get:
		return active_player*-1

# used to show the next turn
# this var is so we can clear the next player square on game end
var next_player_marker: Node  
# this is just the location of the next player square in the UI
var next_player_position : Vector2i

# game state data
var grid_data : Array
var move_count : int

# what is the position/orientation of the line through the winning trio
var winning_line : WinLocations
var winning_line_marker

# scorekeeping
var is_keeping_score : bool
var player1_score : int
var player2_score : int
var tie_score : int

var GAME_SIZE : int

# Called when the node enters the scene tree for the first time.
func _ready():
	# set the location for the next marker placement
	var panel_position := $side_panel/next_player_panel.get_position() as Vector2
	next_player_position = Vector2i(int(panel_position.x) + 920, int(panel_position.y))
	start_player = 1
	is_keeping_score = true
	start_rule = StartRules.ALTERNATE
	opponent = Opponents.HUMAN
	GAME_SIZE = 3
	
	if hide_minimax: 
		$settings_menu/hard_ai_button.hide()
		
	# do new game setup
	new_game()


# reset game data for a new game
func new_game():
	# manage active player
	active_player = start_player
	
	# clear game state
	grid_data = [
		[0, 0, 0],
		[0, 0, 0],
		[0, 0, 0]
		]
	winning_line = WinLocations.NONE
	move_count = 0
	
	
	# delete the groups of x and o images, winning line, and menus
	get_tree().call_group("ogroup", "queue_free")
	get_tree().call_group("xgroup", "queue_free")
	if winning_line_marker != null:
		winning_line_marker.queue_free()
	$game_over_menu.hide()
	$settings_menu.hide()
	
	show_next_player(active_player)
	
	# unpause the game
	get_tree().paused = false
	
	# if AI goes first, make move
	if opponent != Opponents.HUMAN and active_player == -1:
		do_ai_move()


# Called when any input is received
func _input(event):
	# we only care about left button clicks up in here
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			handle_left_click(event.position)


func handle_left_click(left_click_position):
	# only proceed if click is in the game grid
	var click_position := get_grid_position(left_click_position) as Vector2i
	if is_in_game_grid(click_position):
		process_game_grid_click(click_position)


func is_in_game_grid(click_position) -> bool:
	# -1 in either x or y means the click was not in the game grid
	return click_position.x != -1 and click_position.y != -1


# return x,y position in the grid based on pixel position on the board
func get_grid_position(click_position) -> Vector2i:
	var grid_position := Vector2i(-1, -1)
	if click_position.x > 485 and click_position.x < 610:
			grid_position.x = 0
	elif click_position.x > 620 and click_position.x < 735:
			grid_position.x = 1
	elif click_position.x > 745 and click_position.x < 860:
			grid_position.x = 2
	if click_position.y > 140 and click_position.y < 265:
			grid_position.y = 0
	elif click_position.y > 280 and click_position.y < 400:
			grid_position.y = 1
	elif click_position.y > 410 and click_position.y < 530:
			grid_position.y = 2
	return grid_position


# return the center of the grid square for move marker placement
func get_marker_position(grid_position) -> Vector2i:
	var marker_position := Vector2i(-1, -1)
	if grid_position.x == 0:
			marker_position.x = 550
	elif grid_position.x == 1:
			marker_position.x = 675
	elif grid_position.x == 2:
			marker_position.x = 800
	if grid_position.y == 0:
			marker_position.y = 210
	elif grid_position.y == 1:
			marker_position.y = 340
	elif grid_position.y == 2:
			marker_position.y = 470
	return marker_position


func process_game_grid_click(grid_position):
	if is_grid_location_open(grid_position):
		make_move(grid_position, active_player)
		end_move()


func is_grid_location_open(grid_position) -> bool:
	return grid_data[grid_position.y][grid_position.x] == 0


func make_move(grid_position, moving_player):
	move_count+=1
	grid_data[grid_position.y][grid_position.x] = moving_player
	# place move on UI
	place_marker(moving_player, get_marker_position(grid_position))
	# clear the previous next player marker in UI
	if next_player_marker != null:
		next_player_marker.queue_free()


func end_move():
		if move_count >= 5 and is_win():
			process_win()
		elif move_count == 9 and is_tie():
			process_tie()
		else:
			process_next_turn()


# render an x or o on the game board
func place_marker(marking_player, marker_position, update_next = false):
	var marker : Node
	if marking_player == 1:
		marker = o_scene.instantiate()
	else:
		marker = x_scene.instantiate()
	
	marker.position = marker_position
	add_child(marker)
	if update_next: 
		next_player_marker = marker


# return true if the game is in a win state, false if not
# set winning line orientation
func is_win() -> bool:
	if (active_player == grid_data[0][0] and 
			active_player == grid_data[0][1] and 
			active_player == grid_data[0][2]):
		winning_line = WinLocations.ROW_TOP
	if (active_player == grid_data[1][0] and 
			active_player == grid_data[1][1] and 
			active_player == grid_data[1][2]):
		winning_line = WinLocations.ROW_MIDDLE
	if (active_player == grid_data[2][0] and 
			active_player == grid_data[2][1] and 
			active_player == grid_data[2][2]):
		winning_line = WinLocations.ROW_BOTTOM
	if (active_player == grid_data[0][0] and 
			active_player == grid_data[1][0] and 
			active_player == grid_data[2][0]):
		winning_line = WinLocations.COLUMN_LEFT
	if (active_player == grid_data[0][1] and 
			active_player == grid_data[1][1] and 
			active_player == grid_data[2][1]):
		winning_line = WinLocations.COLUMN_MIDDLE
	if (active_player == grid_data[0][2] and 
			active_player == grid_data[1][2] and 
			active_player == grid_data[2][2]):
		winning_line = WinLocations.COLUMN_RIGHT
	if (active_player == grid_data[0][0] and 
			active_player == grid_data[1][1] and 
			active_player == grid_data[2][2]):
		winning_line = WinLocations.DIAGONAL_DESC
	if (active_player == grid_data[2][0] and 
			active_player == grid_data[1][1] and 
			active_player == grid_data[0][2]):
		winning_line = WinLocations.DIAGONAL_ASC	
	
	if winning_line > 0:
		return true
	return false


# only call after is_win() or 
# it could result in false positive if the final move is winning
func is_tie() -> bool:
	for i in range(GAME_SIZE):
		for j in range(GAME_SIZE):
			if grid_data[i][j] == 0:
				return false
	return true


# take the end game steps for draw
func process_tie():
	get_tree().paused = true
	if is_keeping_score: 
		tie_score += 1
	get_node("side_panel/tie_score_label").text = str(tie_score)
	$game_over_menu.show()
	$game_over_menu.get_node("result_label").text = "It's a tie!"
	set_start_player(false)


# take the end game steps for win
func process_win():
	draw_win_line()
	get_tree().paused = true
	$game_over_menu.show()
	if active_player == 1:
		$game_over_menu.get_node("result_label").text = "Player 1 wins!"
		if is_keeping_score: 
			player1_score += 1
		get_node("side_panel/player1_score_label").text = str(player1_score)
	else:
		$game_over_menu.get_node("result_label").text = "Player 2 wins!"
		if is_keeping_score: 
			player2_score += 1
		get_node("side_panel/player2_score_label").text = str(player2_score)
	set_start_player(true)


# decide who goes first next turn based on setting
func set_start_player(was_win):
	if start_rule == StartRules.ALTERNATE:
		start_player *= -1
	elif start_rule == StartRules.CIRCLE:
		start_player = 1
	elif start_rule == StartRules.LOSER and was_win:
		start_player = active_opponent
	elif start_rule == StartRules.WINNER and was_win:
		start_player = active_player


func show_next_player(next_player):
	# offset centers it in the square
	place_marker(next_player, next_player_position + Vector2i(75, 75), true)


# check the orientation and draw the line to match
func draw_win_line():
	var marker : Node
	marker = winning_line_scene.instantiate()
	
	match winning_line:
		WinLocations.ROW_TOP:
			marker.position = Vector2i(675, 210)
			marker.rotation_degrees += 90
		WinLocations.ROW_MIDDLE:
			marker.position = Vector2i(675, 340)
			marker.rotation_degrees += 90
		WinLocations.ROW_BOTTOM:
			marker.position = Vector2i(675, 470)
			marker.rotation_degrees += 90
		WinLocations.COLUMN_LEFT:
			marker.position = Vector2i(550, 340)
		WinLocations.COLUMN_MIDDLE:
			marker.position = Vector2i(675, 340)
		WinLocations.COLUMN_RIGHT:
			marker.position = Vector2i(800, 340)
		WinLocations.DIAGONAL_DESC:
			marker.position = Vector2i(675, 340)
			marker.rotation_degrees += 135
		WinLocations.DIAGONAL_ASC:
			marker.position = Vector2i(675, 340)
			marker.rotation_degrees += 45
			
	add_child(marker)
	winning_line_marker = marker


# queue up the screen for the next player to go
func process_next_turn():
	active_player = active_opponent
	# update the next turn box
	show_next_player(active_player)
	
	if opponent != Opponents.HUMAN and active_player == -1:
		do_ai_move()
	
	
# play as the computer using custom logic
func do_ai_move():
	# pause a half second for the AI to "think"
	await get_tree().create_timer(0.5).timeout 
	
	# basic AI: look for available win if 4 moves have passed
	var winning_move := Vector2i(-1,-1) 
	if move_count >= 4: 
		winning_move = find_winning_move(active_player)
	if is_in_game_grid(winning_move):
		process_game_grid_click(winning_move)
	else:	
		# basic AI: look for available block (negative player is opponent)
		var blocking_move := Vector2i(-1,-1)
		if move_count >= 3: 
			blocking_move = find_winning_move(active_opponent)
		if is_in_game_grid(blocking_move):
			process_game_grid_click(blocking_move)
		else:
			# no single move win or block available, do custom
			if opponent == Opponents.TOASTER:
				# a toaster is a dumb robot, so its moves are random af
				process_game_grid_click(get_random_valid_play())
			elif opponent == Opponents.ROOMBA:
				# find a square where win is technically possible and go there 
				var potentially_winning_move = find_potential_winning_move(active_player)
				if is_in_game_grid(potentially_winning_move):
					process_game_grid_click(potentially_winning_move)
				else:					
					# winning not possible, do random
					process_game_grid_click(get_random_valid_play())
			elif opponent == Opponents.MEGATRON:			
				process_game_grid_click(get_minimax_play())


# return coordinates of a winning move or (-1,-1) if none
func find_winning_move(potential_winning_player) -> Vector2i:
	var winning_move = Vector2i(-1,-1)
	# any trio whose sum is 2 or -2 is a winning trio
	# find one and return the location of the 0 in the row
	var target = potential_winning_player * 2
	if target == grid_data[0][0] + grid_data[0][1] + grid_data[0][2]:
		if grid_data[0][0] == 0: 
			winning_move = Vector2i(0,0)
		elif grid_data[0][1] == 0: 
			winning_move =  Vector2i(1,0) 
		else: 
			winning_move = Vector2i(2,0)
	elif target == grid_data[1][0] + grid_data[1][1] + grid_data[1][2]:
		if grid_data[1][0] == 0: 
			winning_move = Vector2i(0,1)
		elif grid_data[1][1] == 0: 
			winning_move =  Vector2i(1,1) 
		else: 
			winning_move = Vector2i(2,1)
	elif target == grid_data[2][0] + grid_data[2][1] + grid_data[2][2]:
		if grid_data[2][0] == 0: 
			winning_move = Vector2i(0,2)
		elif grid_data[2][1] == 0: 
			winning_move =  Vector2i(1,2) 
		else: 
			winning_move = Vector2i(2,2)
	elif target == grid_data[0][0] + grid_data[1][0] + grid_data[2][0]:
		if grid_data[0][0] == 0: 
			winning_move = Vector2i(0,0)
		elif grid_data[1][0] == 0: 
			winning_move =  Vector2i(0,1) 
		else: 
			winning_move = Vector2i(0,2)
	elif target == grid_data[0][1] + grid_data[1][1] + grid_data[2][1]:
		if grid_data[0][1] == 0: 
			winning_move = Vector2i(1,0)
		elif grid_data[1][1] == 0: 
			winning_move =  Vector2i(1,1) 
		else: 
			winning_move = Vector2i(1,2)
	elif target == grid_data[0][2] + grid_data[1][2] + grid_data[2][2]:
		if grid_data[0][2] == 0: 
			winning_move = Vector2i(2,0)
		elif grid_data[1][2] == 0: 
			winning_move =  Vector2i(2,1) 
		else: 
			winning_move = Vector2i(2,2)
	elif target == grid_data[0][0] + grid_data[1][1] + grid_data[2][2]:
		if grid_data[0][0] == 0: 
			winning_move = Vector2i(0,0)
		elif grid_data[1][1] == 0: 
			winning_move =  Vector2i(1,1) 
		else: 
			winning_move = Vector2i(2,2)
	elif target == grid_data[2][0] + grid_data[1][1] + grid_data[0][2]:
		if grid_data[2][0] == 0: 
			winning_move = Vector2i(0,2)
		elif grid_data[1][1] == 0: 
			winning_move =  Vector2i(1,1) 
		else: 
			winning_move = Vector2i(2,0)
			
	return winning_move


# return coordinates of a move in a row that could win or (-1,-1) if none
func find_potential_winning_move(potential_winner) -> Vector2i:
	var winner = Vector2i(-1,-1)
	# any trio whose sum is 1 or -1 is a potential winner
	# find one and return the location of the first 0 in the row
	var target = potential_winner * 1
	if target == grid_data[0][0] + grid_data[0][1] + grid_data[0][2]:
		if grid_data[0][0] == 0: winner = Vector2i(0,0)
		elif grid_data[0][1] == 0: winner =  Vector2i(1,0) 
		elif grid_data[0][2] == 0: winner = Vector2i(2,0)
	if winner.x == -1 and target == grid_data[1][0] + grid_data[1][1] + grid_data[1][2]:
		if grid_data[1][0] == 0: winner = Vector2i(0,1)
		elif grid_data[1][1] == 0: winner =  Vector2i(1,1) 
		elif grid_data[1][2] == 0: winner =  Vector2i(2,1) 
	if winner.x == -1 and target == grid_data[2][0] + grid_data[2][1] + grid_data[2][2]:
		if grid_data[2][0] == 0: winner = Vector2i(0,2)
		elif grid_data[2][1] == 0: winner =  Vector2i(1,2) 
		elif grid_data[2][2] == 0: winner =  Vector2i(2,2) 
	if winner.x == -1 and target == grid_data[0][0] + grid_data[1][0] + grid_data[2][0]:
		if grid_data[0][0] == 0: winner = Vector2i(0,0)
		elif grid_data[1][0] == 0: winner =  Vector2i(0,1) 
		elif grid_data[2][0] == 0: winner =  Vector2i(0,2) 
	if winner.x == -1 and target == grid_data[0][1] + grid_data[1][1] + grid_data[2][1]:
		if grid_data[0][1] == 0: winner = Vector2i(1,0)
		elif grid_data[1][1] == 0: winner =  Vector2i(1,1) 
		elif grid_data[2][1] == 0: winner =  Vector2i(1,2) 
	if winner.x == -1 and target == grid_data[0][2] + grid_data[1][2] + grid_data[2][2]:
		if grid_data[0][2] == 0: winner = Vector2i(2,0)
		elif grid_data[1][2] == 0: winner =  Vector2i(2,1)
		elif grid_data[2][2] == 0: winner =  Vector2i(2,2) 
	if winner.x == -1 and target == grid_data[0][0] + grid_data[1][1] + grid_data[2][2]:
		if grid_data[0][0] == 0: winner = Vector2i(0,0)
		elif grid_data[1][1] == 0: winner =  Vector2i(1,1) 
		elif grid_data[2][2] == 0: winner =  Vector2i(2,2) 
	if winner.x == -1 and target == grid_data[2][0] + grid_data[1][1] + grid_data[0][2]:
		if grid_data[2][0] == 0: winner = Vector2i(0,2)
		elif grid_data[1][1] == 0: winner =  Vector2i(1,1) 
		elif grid_data[0][2] == 0: winner =  Vector2i(2,0) 
	return winner


# any open square at random
func get_random_valid_play() -> Vector2i:
	var random_row = randi() % GAME_SIZE
	var random_column = randi() % GAME_SIZE

	# Get the value at the random coordinate	
	var random_value = grid_data[random_row][random_column]
	if (random_value != 0):
		# recurse until we find an open square 
		# ideally we would take random from available open moves
		# but performance is not a concern at this scale
		return get_random_valid_play()
	else:
		return Vector2i(random_column,random_row)


func get_minimax_play() -> Vector2i:
	var board_copy = grid_data.duplicate(true)
	var best_move = minimax(board_copy, 0, true, -100, 100, null)
	print(best_move)
	return best_move


# play again was clicked in the game over menu
func _on_game_over_menu_restart():
	new_game()


# setting gear icon was pressed
func _on_settings_button_pressed():
	get_tree().paused = true
	$settings_menu.show()


# close the settings menu
func _on_settings_menu_close():	
	$settings_menu.hide()
	get_tree().paused = false


# toggle score keeping and hide scoring elements
func _on_settings_menu_keep_score(value):
	is_keeping_score = value
	if not is_keeping_score:
		player1_score = 0
		player2_score = 0
		tie_score = 0
		get_node("side_panel/player1_score_label").text = "0"
		get_node("side_panel/player2_score_label").text = "0"
		get_node("side_panel/tie_score_label").text = "0"
		get_node("side_panel/player1_score_label").hide()
		get_node("side_panel/player2_score_label").hide()
		get_node("side_panel/tie_score_label").hide()
		get_node("side_panel/player1_label").hide()
		get_node("side_panel/player2_label").hide()
		get_node("side_panel/tie_label").hide()
	else:
		get_node("side_panel/player1_score_label").show()
		get_node("side_panel/player2_score_label").show()
		get_node("side_panel/tie_score_label").show()
		get_node("side_panel/player1_label").show()
		get_node("side_panel/player2_label").show()
		get_node("side_panel/tie_label").show()


# set the scores back to 0
func _on_settings_menu_reset_score():
		player1_score = 0
		player2_score = 0
		tie_score = 0
		get_node("side_panel/player1_score_label").text = ""
		get_node("side_panel/player2_score_label").text = ""
		get_node("side_panel/tie_score_label").text = ""


# set how first player is chosen (alternate, loser, winner, or always circle)
func _on_settings_menu_starter(who):
	if who == "alternate":
		start_rule = StartRules.ALTERNATE
	elif who == "circle":
		start_rule = StartRules.CIRCLE
	elif who == "winner":
		start_rule = StartRules.WINNER
	elif who == "loser":
		start_rule = StartRules.LOSER


# set opponent from settings
func _on_settings_menu_opponent(who):
	if who == "player":
		opponent = Opponents.HUMAN
	elif who == "easy_ai":
		opponent = Opponents.TOASTER
	elif who == "medium_ai":
		opponent = Opponents.ROOMBA
	elif who == "hard_ai":
		opponent = Opponents.MEGATRON

#region minimax
#############################################
# ignore past this line for now
# this logic is close to working, but not quite there, hidden in variable above
func minimax(board, depth, is_max, alpha, beta, last_move):
	# check for terminal state; return score and last_move
	var board_winner = mm_get_winner(board)
	if board_winner == -1: # ai win
		return [last_move, 10 - depth]
	if board_winner == 1: # human win
		return [last_move, -10 + depth]
	if mm_is_draw(board):
		return [last_move, 0]
	
	# get possible moves remaining
	var possible_moves = mm_get_possible_moves(board)
	
	var best_move : Array
	if is_max:
		for move in possible_moves:
			var newboard = board.duplicate(true)
			newboard = mm_do_move(newboard, move, -1)
			var value = minimax(newboard, depth+1, false, alpha, beta, move)			
			alpha = max(alpha, value[1])
			if alpha >= beta:
				return value
			if best_move.is_empty() or value[1] > best_move[1]:
				best_move = value
	else:
		for move in possible_moves :
			var newboard = board.duplicate(true)
			newboard = mm_do_move(newboard, move, 1)
			var value = minimax(newboard, depth+1, true, alpha, beta, move)
			beta = min(beta, value[1])
			if beta <= alpha:
				return value
			if best_move.is_empty() or value[1] < best_move[1]:
				best_move = value
	return best_move


func mm_is_draw(board):
	for i in range(GAME_SIZE):
		for j in range(GAME_SIZE):
			if board[i][j] == 0:
				return false
	return true


func mm_get_winner(board):
	if abs(board[0][0] + board[0][1] + board[0][2]) == GAME_SIZE:
		return board[0][0]
	if abs(board[1][0] + board[1][1] + board[1][2]) == GAME_SIZE:
		return board[1][0]
	if abs(board[2][0] + board[2][1] + board[2][2]) == GAME_SIZE:
		return board[2][0]
	if abs(board[0][0] + board[1][0] + board[2][0]) == GAME_SIZE:
		return board[0][0]
	if abs(board[0][1] + board[1][1] + board[2][1]) == GAME_SIZE:
		return board[0][1]
	if abs(board[0][2] + board[1][2] + board[2][2]) == GAME_SIZE:
		return board[0][2]
	if abs(board[0][0] + board[1][1] + board[2][2]) == GAME_SIZE:
		return board[0][0]
	if abs(board[2][0] + board[1][1] + board[0][2]) == GAME_SIZE:
		return board[2][0]
	
	return 0


func mm_get_possible_moves(board):
	var moves : Array = []
	for i in range(GAME_SIZE):
		for j in range(GAME_SIZE):
			if board[i][j] == 0:
				moves.append([i,j])
	return moves


func mm_do_move(board, move, move_player):
	if board[move[0]][move[1]] == 0:
		# valid move
		board[move[0]][move[1]] = move_player
	else:
		print("trying to make invalid move in mm")
	return board

# potential guides to help finish minmax
# https://github.com/jesushinojosa/godot_tictactoe/blob/master/AI.gd
# https://thesharperdev.com/optimizing-our-perfect-tic-tac-toe-bot/
# https://codepen.io/garbot/pen/bWLGGL?editors=0010
#endregion
