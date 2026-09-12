extends Node2D

const GRID_WIDTH: int = 6
const GRID_HEIGHT: int = 6
const TILE_SIZE: int = 64
const COLORS: Array[Color] = [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW]

# 2D Array storing actual ColorRect Node references
var grid: Array = []
var is_animating: bool = false
var selected_cell: Vector2i = Vector2i(-1, -1)

var selection_indicator: ReferenceRect = null

func _ready() -> void:
	randomize()
	initialize_grid()

func initialize_grid() -> void:
	for child in get_children():
		child.queue_free()
		
	grid.clear()
	
	for x in range(GRID_WIDTH):
		var column: Array = []
		for y in range(GRID_HEIGHT):
			var color_idx: int = randi() % COLORS.size()
			
			# Avoid starting matches on initial spawn
			while (x >= 2 and grid[x-1][y].get_meta("color_idx") == color_idx and grid[x-2][y].get_meta("color_idx") == color_idx) or \
				  (y >= 2 and column[y-1].get_meta("color_idx") == color_idx and column[y-2].get_meta("color_idx") == color_idx):
				color_idx = randi() % COLORS.size()

			var tile = create_tile_node(x, y, color_idx)
			column.append(tile)
		grid.append(column)

func create_tile_node(x: int, y: int, color_idx: int) -> ColorRect:
	var tile = ColorRect.new()
	tile.size = Vector2(TILE_SIZE - 2, TILE_SIZE - 2)
	tile.color = COLORS[color_idx]
	tile.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
	
	# CRITICAL FIX: Allow clicks to pass through the tile to the main script
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Metadata tag so we can evaluate colors without reading tile.color directly
	tile.set_meta("color_idx", color_idx)
	
	add_child(tile)
	return tile

func _input(event: InputEvent) -> void:
	if is_animating:
		return
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var grid_x: int = int(event.position.x / TILE_SIZE)
		var grid_y: int = int(event.position.y / TILE_SIZE)
		
		if grid_x >= 0 and grid_x < GRID_WIDTH and grid_y >= 0 and grid_y < GRID_HEIGHT:
			handle_cell_click(Vector2i(grid_x, grid_y))

func handle_cell_click(cell: Vector2i) -> void:
	if selected_cell == Vector2i(-1, -1):
		selected_cell = cell
		show_selection_at(cell)
	else:
		hide_selection()
		
		if is_adjacent(selected_cell, cell):
			is_animating = true
			
			# 1. Visually slide nodes past each other
			await animate_swap(selected_cell, cell)
			
			# 2. Swap array references in memory
			swap_tiles(selected_cell, cell)
			
			# 3. Validate matches
			var matches = check_for_matches()
			if matches.size() == 0:
				# Invalid move: slide back smoothly
				await animate_swap(selected_cell, cell)
				swap_tiles(selected_cell, cell)
			else:
				# Run match clears
				await process_board_state()
				
			is_animating = false
		
		selected_cell = Vector2i(-1, -1)

func animate_swap(cell_a: Vector2i, cell_b: Vector2i) -> void:
	var tile_a: ColorRect = grid[cell_a.x][cell_a.y]
	var tile_b: ColorRect = grid[cell_b.x][cell_b.y]
	
	var pos_a: Vector2 = Vector2(cell_a.x * TILE_SIZE, cell_a.y * TILE_SIZE)
	var pos_b: Vector2 = Vector2(cell_b.x * TILE_SIZE, cell_b.y * TILE_SIZE)
	
	# Animate position properties over 0.4 seconds
	var tween = create_tween().set_parallel(true)
	tween.tween_property(tile_a, "position", pos_b, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(tile_b, "position", pos_a, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished

func is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return abs(a.x - b.x) + abs(a.y - b.y) == 1

func swap_tiles(a: Vector2i, b: Vector2i) -> void:
	var temp = grid[a.x][a.y]
	grid[a.x][a.y] = grid[b.x][b.y]
	grid[b.x][b.y] = temp

func check_for_matches() -> Array[Vector2i]:
	var matched_cells: Array[Vector2i] = []

	# Horizontal check
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH - 2):
			if grid[x][y] != null and grid[x+1][y] != null and grid[x+2][y] != null:
				var c1 = grid[x][y].get_meta("color_idx")
				var c2 = grid[x+1][y].get_meta("color_idx")
				var c3 = grid[x+2][y].get_meta("color_idx")
				if c1 == c2 and c1 == c3:
					matched_cells.append(Vector2i(x, y))
					matched_cells.append(Vector2i(x+1, y))
					matched_cells.append(Vector2i(x+2, y))

	# Vertical check
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT - 2):
			if grid[x][y] != null and grid[x][y+1] != null and grid[x][y+2] != null:
				var c1 = grid[x][y].get_meta("color_idx")
				var c2 = grid[x][y+1].get_meta("color_idx")
				var c3 = grid[x][y+2].get_meta("color_idx")
				if c1 == c2 and c1 == c3:
					matched_cells.append(Vector2i(x, y))
					matched_cells.append(Vector2i(x, y+1))
					matched_cells.append(Vector2i(x, y+2))

	return matched_cells

func clear_matches(matches: Array[Vector2i]) -> void:
	for cell in matches:
		if grid[cell.x][cell.y] != null:
			grid[cell.x][cell.y].color = Color.BLACK
			
func process_board_state() -> void:
	var matches = check_for_matches()
	
	while matches.size() > 0:
		# 1. Animate match removal (shrink scale to 0)
		await animate_match_clear(matches)
		
		# 2. Apply gravity & spawn replacement tiles
		await apply_gravity_and_refill()
		
		# 3. Re-check for secondary cascading matches
		matches = check_for_matches()

func animate_match_clear(matches: Array[Vector2i]) -> void:
	var tween = create_tween().set_parallel(true)
	
	for cell in matches:
		var tile: ColorRect = grid[cell.x][cell.y]
		if tile != null:
			# Animate scale down to zero over 0.25 seconds
			tween.tween_property(tile, "scale", Vector2.ZERO, 0.25)
			# Pivot scaling around center of tile
			tile.pivot_offset = tile.size / 2
			
	await tween.finished
	
	# Clean up node references and remove from scene tree
	for cell in matches:
		var tile: ColorRect = grid[cell.x][cell.y]
		if tile != null:
			tile.queue_free()
			grid[cell.x][cell.y] = null

func apply_gravity_and_refill() -> void:
	var tween = create_tween().set_parallel(true)
	
	for x in range(GRID_WIDTH):
		# 1. Drop existing tiles down into empty null slots
		for y in range(GRID_HEIGHT - 1, -1, -1):
			if grid[x][y] == null:
				# Find the nearest non-null tile above
				for above_y in range(y - 1, -1, -1):
					if grid[x][above_y] != null:
						grid[x][y] = grid[x][above_y]
						grid[x][above_y] = null
						
						# Animate drop to new grid position
						var target_pos = Vector2(x * TILE_SIZE, y * TILE_SIZE)
						tween.tween_property(grid[x][y], "position", target_pos, 0.3)\
							.set_trans(Tween.TRANS_BOUNCE)\
							.set_ease(Tween.EASE_OUT)
						break
		
		# 2. Fill remaining empty top slots with fresh tiles
		for y in range(GRID_HEIGHT - 1, -1, -1):
			if grid[x][y] == null:
				var color_idx = randi() % COLORS.size()
				var new_tile = create_tile_node(x, y, color_idx)
				grid[x][y] = new_tile
				
				# Spawn slightly above top of screen and animate drop in
				new_tile.position = Vector2(x * TILE_SIZE, -TILE_SIZE)
				new_tile.scale = Vector2.ONE
				var target_pos = Vector2(x * TILE_SIZE, y * TILE_SIZE)
				
				tween.tween_property(new_tile, "position", target_pos, 0.3)\
					.set_trans(Tween.TRANS_BOUNCE)\
					.set_ease(Tween.EASE_OUT)

	await tween.finished
			

func show_selection_at(cell: Vector2i) -> void:
	# Clear any existing indicator first
	hide_selection()
	
	var tile: ColorRect = grid[cell.x][cell.y]
	if tile != null:
		selection_indicator = ReferenceRect.new()
		selection_indicator.size = tile.size
		selection_indicator.border_color = Color.WHITE # Set outline color
		selection_indicator.border_width = 3.0       # Set line thickness
		selection_indicator.editor_only = false       # Ensures it renders in game builds
		
		tile.add_child(selection_indicator)

func hide_selection() -> void:
	if selection_indicator != null and is_instance_valid(selection_indicator):
		selection_indicator.queue_free()
		selection_indicator = null
