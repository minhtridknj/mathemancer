class_name RelicSystem
extends RefCounted

## Hệ thống Cổ Vật (tương đương Jokers trong Balatro)
## Cung cấp các hiệu ứng bổ trợ bị động cho Chips và Mult

const RELIC_DEFINITIONS = {
	"relic_blackjack": {
		"name": "Blackjack Relic",
		"desc": "Multiplies Mult by ×3 when playing Blackjack 21",
		"cost": 6,
		"rarity": "rare",
		"icon": "🃏",
		"short_desc": "×3 Mult on Blackjack 21",
		"tip": "Form card combinations summing to exactly 21 to trigger a massive 3× multiplier!"
	},
	"relic_flame_wrath": {
		"name": "Wrath of Flame",
		"desc": "+12 Mult for each Flame 🔥 card in hand",
		"cost": 5,
		"rarity": "uncommon",
		"icon": "🔥",
		"short_desc": "+12 Mult / Flame card",
		"tip": "Select cards with the Flame element to stack heavy multiplier boosts."
	},
	"relic_frost_shield": {
		"name": "Glacial Aegis",
		"desc": "+15 Chips for each Frost ❄️ card in hand",
		"cost": 4,
		"rarity": "common",
		"icon": "❄️",
		"short_desc": "+15 Chips / Frost card",
		"tip": "Frost cards boost your base chips directly before multiplier calculation."
	},
	"relic_mine_magnifier": {
		"name": "Mine Magnifier",
		"desc": "Each correctly flagged mine grants permanent +20 Chips to all hands",
		"cost": 6,
		"rarity": "uncommon",
		"icon": "🚩",
		"short_desc": "+20 Chips / Flagged mine",
		"tip": "Deductively flag all mines on the board before playing hands to maximize free chips."
	},
	"relic_sudoku_compass": {
		"name": "Sudoku Compass",
		"desc": "If hand contains 4 all-distinct digits, grants +35 Chips and +8 Mult",
		"cost": 7,
		"rarity": "rare",
		"icon": "🧭",
		"short_desc": "+35 Chips & +8 Mult (4 distinct)",
		"tip": "Play 4 cards with all distinct numbers (e.g. 1-2-3-4) to activate both chips and mult."
	}
}

static func apply_relic_modifiers(hand_data: Dictionary, cards: Array[Dictionary], current_relics: Array[String], extra_state: Dictionary = {}) -> Dictionary:
	var res = hand_data.duplicate()
	var triggered_relics: Array[String] = []
	
	for relic_id in current_relics:
		match relic_id:
			"relic_blackjack":
				if res.get("type", "") == "BLACKJACK_21":
					res["mult"] = float(res.get("mult", 1.0)) * 3.0
					triggered_relics.append(relic_id)
					
			"relic_flame_wrath":
				var flame_count := 0
				for c in cards:
					if str(c.get("suit", "")) == "flame":
						flame_count += 1
				if flame_count > 0:
					res["mult"] = float(res.get("mult", 1.0)) + (flame_count * 12.0)
					triggered_relics.append(relic_id)
					
			"relic_frost_shield":
				var frost_count := 0
				for c in cards:
					if str(c.get("suit", "")) == "frost":
						frost_count += 1
				if frost_count > 0:
					res["total_chips"] = int(res.get("total_chips", 0)) + (frost_count * 15)
					triggered_relics.append(relic_id)
					
			"relic_mine_magnifier":
				var correct_flags: int = int(extra_state.get("correct_flags", 0))
				if correct_flags > 0:
					res["total_chips"] = int(res.get("total_chips", 0)) + (correct_flags * 20)
					triggered_relics.append(relic_id)
					
			"relic_sudoku_compass":
				var seen := {}
				var all_distinct := true
				for c in cards:
					var v = c.get("val", 0)
					if seen.has(v): all_distinct = false
					seen[v] = true
				if all_distinct and cards.size() >= 4:
					res["total_chips"] = int(res.get("total_chips", 0)) + 35
					res["mult"] = float(res.get("mult", 1.0)) + 8.0
					triggered_relics.append(relic_id)
					
	res["triggered_relics"] = triggered_relics
	return res
