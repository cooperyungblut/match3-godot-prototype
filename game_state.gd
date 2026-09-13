class_name GameState
extends Node

# Tier 1 Generator Data
var score: float = 0.0
var auto_clicker_count: int = 0
var auto_clicker_cost: float = 10.0
const BASE_COST: float = 10.0

# Tier 2 Generator Data (Solar Panel?)
var solar_panel_count: int = 0
var solar_panel_cost: float = 100.0
const SOLAR_BASE_COST: float = 100.0

func add_score(amount: float) -> void:
	score += amount

# --- Tier 1 Logic ---
func can_afford_auto_clicker() -> bool:
	return score >= auto_clicker_cost

func buy_auto_clicker() -> bool:
	if not can_afford_auto_clicker():
		return false
		
	score -= auto_clicker_cost
	auto_clicker_count += 1
	auto_clicker_cost = BASE_COST * pow(1.15, auto_clicker_count)
	return true

# --- Tier 2 Logic ---
func can_afford_solar_panel() -> bool:
	return score >= solar_panel_cost

func buy_solar_panel() -> bool:
	if not can_afford_solar_panel():
		return false
		
	score -= solar_panel_cost
	solar_panel_count += 1
	# Multiplier curve: 15% increase per purchase
	solar_panel_cost = SOLAR_BASE_COST * pow(1.15, solar_panel_count)
	return true

# --- Passive Income Loop ---
func process_passive_income(delta: float) -> void:
	# Tier 1 gives +1/sec, Tier 2 gives +10/sec
	var tier1_income: float = auto_clicker_count * 1.0
	var tier2_income: float = solar_panel_count * 10.0
	
	score += (tier1_income + tier2_income) * delta
	
# File path targeting user storage
const SAVE_PATH: String = "user://save_game.cfg"

func save_to_disk() -> void:
	var config = ConfigFile.new()
	
	# Section, Key, Value
	config.set_value("Player", "score", score)
	config.set_value("Generators", "auto_clicker_count", auto_clicker_count)
	config.set_value("Generators", "auto_clicker_cost", auto_clicker_cost)
	config.set_value("Generators", "solar_panel_count", solar_panel_count)
	config.set_value("Generators", "solar_panel_cost", solar_panel_cost)
	
	config.save(SAVE_PATH)

func load_from_disk() -> void:
	var config = ConfigFile.new()
	var error = config.load(SAVE_PATH)
	
	# If file doesn't exist, skip loading
	if error != OK:
		return
		
	# Fallback values preserve defaults if a key is missing
	score = config.get_value("Player", "score", 0.0)
	auto_clicker_count = config.get_value("Generators", "auto_clicker_count", 0)
	auto_clicker_cost = config.get_value("Generators", "auto_clicker_cost", 10.0)
	solar_panel_count = config.get_value("Generators", "solar_panel_count", 0)
	solar_panel_cost = config.get_value("Generators", "solar_panel_cost", 100.0)
