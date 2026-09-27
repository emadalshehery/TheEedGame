extends Node

signal health_changed(player_id: int, new_health: float, max_health: float)
signal fighter_died(player_id: int)
signal combo_hit(victim_id: int, combo_count: int)
