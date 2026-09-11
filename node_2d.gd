extends Node2D

# Grid Configuration
const GRID_WIDTH: int = 6
const GRID_HEIGHT: int = 6
const TILE_SIZE: int = 64
const COLORS: Array[Color] = [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW]

# 2D Array holding color indices for each grid cell
var grid: Array = []
var visual_positions: Array = []

var is_animating: bool = false

func _ready() -> void:
	randomize()
	initialize_grid()
	queue_redraw() # Triggers Godot's built-in drawing pipeline

func initialize_grid() -> void:
	grid.clear()
	visual_positions.clear()
	
	for x in range(GRID_WIDTH):
		var column: Array = []
		var pos_column: Array = []
		for y in range(GRID_HEIGHT):
			var valid_color: int = randi() % COLORS.size()
			
			while (x >= 2 and column_has_horizontal_match(x, y, valid_color)) or (y >= 2 and column_has_vertical_match(column, y, valid_color)):
				valid_color = randi() % COLORS.size()
			
			column.append(valid_color)
			pos_column.append(Vector2(x * TILE_SIZE, y * TILE_SIZE))
			
		grid.append(column)
		visual_positions.append(pos_column)

func column_has_horizontal_match(x: int, y: int, color_index: int) -> bool:
	return grid[x - 1][y] == color_index and grid[x - 2][y] == color_index

func column_has_vertical_match(column: Array, y: int, color_index: int) -> bool:
	return column[y - 1] == color_index and column[y - 2] == color_index

func _draw() -> void:
	# Loop through the grid array and render a square for each cell
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var color_index: int = grid[x][y]
			
			if color_index == -1:
				continue
			
			var cell_color = COLORS[color_index]
			var draw_pos: Vector2 = visual_positions[x][y]
			var rect = Rect2(draw_pos.x, draw_pos.y, TILE_SIZE - 2, TILE_SIZE - 2)
			draw_rect(rect, cell_color)

#	---------------------------------------------------------------------------------------------	#

var selected_cell: Vector2i = Vector2i(-1, -1)

func _unhandled_input(event: InputEvent) -> void:
	if is_animating:
		return # Block Clicks while animations are playing
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var grid_x: int = int(event.position.x / TILE_SIZE)
		var grid_y: int = int(event.position.y / TILE_SIZE)
		
		# Ensure click is inside the grid boundaries
		if grid_x >= 0 and grid_x < GRID_WIDTH and grid_y >= 0 and grid_y < GRID_HEIGHT:
			handle_cell_click(Vector2i(grid_x, grid_y))

func handle_cell_click(cell: Vector2i) -> void:
	if selected_cell == Vector2i(-1, -1):
		# First click: store the tile location
		selected_cell = cell
		print("Selected tile at: ", selected_cell)
	else:
		# Second click: check if adjacent
		if is_adjacent(selected_cell, cell):
			is_animating = true
			
			swap_tiles(selected_cell, cell)
			var matches = check_for_matches()
			
			if matches.size() > 0:	
				#process_board_state()
				await animate_board_state()
			else:
				# Invalid move: revert the swap
				print("Invalid move! Swapping back.")
				swap_tiles(selected_cell, cell)
				queue_redraw()
				
			is_animating = false
			
		
		selected_cell = Vector2i(-1, -1)
		queue_redraw()

func is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return abs(a.x - b.x) + abs(a.y - b.y) == 1

func swap_tiles(a: Vector2i, b: Vector2i) -> void:
	var temp = grid[a.x][a.y]
	grid[a.x][a.y] = grid[b.x][b.y]
	grid[b.x][b.y] = temp

#	---------------------------------------------------------------------------------------------	#

func animate_board_state() -> void:
	var matches_found: bool = true
	
	while matches_found:
		var matched_cells = check_for_matches()
		
		if matched_cells.size() > 0:
			# Clear values in memory
			for cell in matched_cells:
				grid[cell.x][cell.y] = -1
			
			# Flash/redraw cleared tiles
			queue_redraw()
			await get_tree().create_timer(0.4).timeout
			
			# Drop existing pieces down & spawn new ones
			apply_gravity()
			refill_grid()
			
			# Smooth slide delay to simulate falling gravity
			queue_redraw()
			await animate_falling_tiles()
		else:
			matches_found = false

func animate_falling_tiles() -> void:
	# Create a tween to pause execution for a natural drop pace
	var tween = create_tween()
	tween.tween_property(self, "position", position, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tween.finished
	
func animate_swap(cell_a: Vector2i, cell_b: Vector2i, duration: float = 0.3) -> void:
	var start_pos_a: Vector2 = visual_positions[cell_a.x][cell_a.y]
	var start_pos_b: Vector2 = visual_positions[cell_b.x][cell_b.y]
	
	var tween = create_tween().set_parallel(true)
	
	# Animate Position A to Position B
	tween.tween_property(self, "visual_positions:" + str(cell_a.x) + ":" + str(cell_a.y), start_pos_b, duration)
	# Animate Position B to Position A
	tween.tween_property(self, "visual_positions:" + str(cell_b.x) + ":" + str(cell_b.y), start_pos_a, duration)
	
	# Redraw on every frame while tweening
	var step_tween = create_tween()
	step_tween.set_loops(int(duration * 60))
	step_tween.tween_callback(queue_redraw).set_delay(1.0 / 60.0)
	
	await tween.finished
	
	# Reset visual positions to snap back to alignment after grid values swap
	visual_positions[cell_a.x][cell_a.y] = start_pos_a
	visual_positions[cell_b.x][cell_b.y] = start_pos_b

#	---------------------------------------------------------------------------------------------	# 

func check_for_matches() -> Array[Vector2i]:
	var matched_cells: Array[Vector2i] = []

	# Horizontal match check
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH - 2):
			var val = grid[x][y]
			if val == grid[x+1][y] and val == grid[x+2][y]: #and val != 4 and val != 5:
				matched_cells.append(Vector2i(x, y))
				matched_cells.append(Vector2i(x+1, y))
				matched_cells.append(Vector2i(x+2, y))

	# Vertical match check
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT - 2):
			var val = grid[x][y]
			if val == grid[x][y+1] and val == grid[x][y+2]: #and val != 4 and val != 5:
				matched_cells.append(Vector2i(x, y))
				matched_cells.append(Vector2i(x, y+1))
				matched_cells.append(Vector2i(x, y+2))
				
	return matched_cells

	#if matched_cells.size() > 0:
		#print("MATCH FOUND AT: ", matched_cells)
		## Clear matched tiles (set to visual black or -1 index logic)
		#for cell in matched_cells:
			#grid[cell.x][cell.y] = -1 # -1 is an empty / cleared cell
			
		#gravity()
		#check_for_matches()

#func gravity() -> void:
	#for y in range(GRID_HEIGHT-1):
		#for x in range(GRID_WIDTH):
			#if grid[x][y+1] == 4 or grid[x][y+1] == 5:
				#print("Debugging: ", grid[x][y])
				#grid[x][y+1] = grid[x][y]
				#if y == 0:
					#grid[x][y] = randi() % (COLORS.size()-2)
				#else:
					#grid[x][y] = 5
				#
	#for y in range(GRID_HEIGHT):
		#for x in range(GRID_WIDTH):
			#if grid[x][y] == 4 or grid[x][y] == 5:
				#if y == 0:
					#grid[x][y] = randi() % (COLORS.size()-2)
				#else:
					#gravity()

func apply_gravity() -> void:
	for x in range(GRID_WIDTH):
		# Scan from the bottom row up to the top row
		for y in range(GRID_HEIGHT - 1, -1, -1):
			if grid[x][y] == -1:
				# Look upward for the first available piece
				for look_above in range(y - 1, -1, -1):
					if grid[x][look_above] != -1:
						# Move the piece down to the empty space
						grid[x][y] = grid[x][look_above]
						grid[x][look_above] = -1
						break
						
func refill_grid() -> void:
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if grid[x][y] == -1:
				grid[x][y] = randi() % COLORS.size()
				
func process_board_state() -> void:
	var matches_found: bool = true
	
	while matches_found:
		# Check if any matches exist on the board
		var matched_cells = check_for_matches()
		
		if matched_cells.size() > 0:
			# Clear the matched cells to -1
			for cell in matched_cells:
				grid[cell.x][cell.y] = -1
			
			# Drop existing tiles down and generate new ones
			apply_gravity()
			refill_grid()
		else:
			matches_found = false
			
	# Trigger Godot to redraw the updated array visually
	queue_redraw()
