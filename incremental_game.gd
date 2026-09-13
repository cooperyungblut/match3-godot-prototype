extends Control

# View Layer UI References
@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var click_button: Button = $VBoxContainer/ClickButton
@onready var auto_clicker_button: Button = $VBoxContainer/AutoClickerButton
@onready var solar_panel_button: Button = $VBoxContainer/SolarPanelButton

# Reference to Data Model
@onready var game_state: GameState = $GameState

# Add UI References
@onready var save_button: Button = $VBoxContainer/SaveButton
@onready var load_button: Button = $VBoxContainer/LoadButton

func _ready() -> void:
	click_button.text = "Gather Energy (+1)"
	save_button.text = "Save Game"
	load_button.text = "Load Game"
	
	# Bind Signals
	click_button.pressed.connect(_on_click_button_pressed)
	auto_clicker_button.pressed.connect(_on_auto_clicker_button_pressed)
	solar_panel_button.pressed.connect(_on_solar_panel_button_pressed)
	save_button.pressed.connect(_on_save_button_pressed)
	load_button.pressed.connect(_on_load_button_pressed)
	
	update_ui()

func _on_save_button_pressed() -> void:
	game_state.save_to_disk()

func _on_load_button_pressed() -> void:
	game_state.load_from_disk()
	update_ui()

func _process(delta: float) -> void:
	game_state.process_passive_income(delta)
	update_ui()

func _on_click_button_pressed() -> void:
	game_state.add_score(1.0)
	update_ui()

func _on_auto_clicker_button_pressed() -> void:
	if game_state.buy_auto_clicker():
		update_ui()

func _on_solar_panel_button_pressed() -> void:
	if game_state.buy_solar_panel():
		update_ui()

func update_ui() -> void:
	score_label.text = "Energy: %d" % int(game_state.score)
	
	# Tier 1 UI
	auto_clicker_button.text = "Buy Auto Generator (+1/s) [Cost: %d] Owned: %d" % [
		int(game_state.auto_clicker_cost), 
		game_state.auto_clicker_count
	]
	auto_clicker_button.disabled = not game_state.can_afford_auto_clicker()
	
	# Tier 2 UI
	solar_panel_button.text = "Buy Solar Panel (+10/s) [Cost: %d] Owned: %d" % [
		int(game_state.solar_panel_cost), 
		game_state.solar_panel_count
	]
	solar_panel_button.disabled = not game_state.can_afford_solar_panel()
