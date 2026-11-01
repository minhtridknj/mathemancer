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
	},
	"relic_keen_eyeglass": {
		"name": "Keen Eyeglass",
		"desc": "Permanently gains +3 Mult whenever an Ante is cleared without triggering any mines",
		"cost": 6,
		"rarity": "rare",
		"icon": "🧐",
		"short_desc": "Scales +3 Mult on clean Ante win",
		"tip": "Deduce every mine cleanly to grow this relic's multiplier across the whole run."
	},
	"relic_sacred_abacus": {
		"name": "Sacred Abacus",
		"desc": "Permanently gains +8 Chips every time Blackjack 21 or Straight is played",
		"cost": 6,
		"rarity": "uncommon",
		"icon": "🧮",
		"short_desc": "Scales +8 Chips on 21 / Straight",
		"tip": "Frequent combos build an astronomical chip count over time."
	},
	"relic_burning_geode": {
		"name": "Burning Geode",
		"desc": "Permanently gains +1.5 Mult for each Fog of War stage dispelled",
		"cost": 5,
		"rarity": "uncommon",
		"icon": "💎",
		"short_desc": "Scales +1.5 Mult per dispelled fog",
		"tip": "Advance through puzzle stages by playing hands to feed this growing geode."
	},
	"relic_astral_duo": {
		"name": "The Astral Duo",
		"desc": "Multiplies Mult by ×2.0 if hand contains One Pair or Two Pair",
		"cost": 5,
		"rarity": "uncommon",
		"icon": "♊",
		"short_desc": "×2.0 Mult on Pair / Two Pair",
		"tip": "Combine two matching numbers to instantly double your hand multiplier."
	},
	"relic_celestial_trio": {
		"name": "Celestial Trio",
		"desc": "Multiplies Mult by ×2.5 if hand contains Three of a Kind or Full House",
		"cost": 6,
		"rarity": "rare",
		"icon": "🔺",
		"short_desc": "×2.5 Mult on Three of a Kind",
		"tip": "Triplet combinations hit significantly harder with this cosmic relic."
	},
	"relic_elemental_surge": {
		"name": "Elemental Surge",
		"desc": "Multiplies Mult by ×2.5 if hand contains a Flush",
		"cost": 6,
		"rarity": "rare",
		"icon": "🌊",
		"short_desc": "×2.5 Mult on Flush",
		"tip": "Collect 4 or 5 numbers of the exact same element to trigger this surge."
	},
	"relic_sacred_order": {
		"name": "Sacred Order",
		"desc": "Multiplies Mult by ×3.0 and adds +30 Chips when playing a Straight or Straight Flush",
		"cost": 7,
		"rarity": "rare",
		"icon": "📜",
		"short_desc": "×3.0 Mult & +30 Chips on Straight",
		"tip": "Consecutive sequences (like 2-3-4-5) yield game-winning burst damage."
	},
	"relic_odd_astrologer": {
		"name": "Odd Astrologer",
		"desc": "+8 Mult for each Odd numbered card (1, 3, 5, 7) in hand",
		"cost": 5,
		"rarity": "common",
		"icon": "🌙",
		"short_desc": "+8 Mult / Odd card",
		"tip": "Stack odd-value numbers into your hand for explosive flat mult bonuses."
	},
	"relic_even_magus": {
		"name": "Even Magus",
		"desc": "+25 Chips for each Even numbered card (2, 4, 6, 8) in hand",
		"cost": 5,
		"rarity": "common",
		"icon": "☀️",
		"short_desc": "+25 Chips / Even card",
		"tip": "Even numbers build a solid foundation of raw chips before multipliers."
	},
	"relic_fibonacci_sigil": {
		"name": "Fibonacci Sigil",
		"desc": "+10 Mult for each card with a Fibonacci number (1, 2, 3, 5, 8) in hand",
		"cost": 6,
		"rarity": "uncommon",
		"icon": "🌀",
		"short_desc": "+10 Mult / Fibonacci number",
		"tip": "Sacred mathematical numbers (1, 2, 3, 5, 8) harmonize to boost your mult."
	},
	"relic_blast_ward": {
		"name": "Blast Ward",
		"desc": "Absorbs the first mine explosion in each Ante, preventing play count loss",
		"cost": 7,
		"rarity": "rare",
		"icon": "🛡️",
		"short_desc": "Absorbs 1 mine blast per Ante",
		"tip": "A powerful safety net allowing you to take calculated risks on difficult boards."
	}
}

static func apply_relic_modifiers(hand_data: Dictionary, cards: Array[Dictionary], current_relics: Array[String], extra_state: Dictionary = {}) -> Dictionary:
	var res = hand_data.duplicate()
	var triggered_relics: Array[String] = []
	var h_type: String = str(res.get("type", ""))
	
	for relic_id in current_relics:
		match relic_id:
			"relic_blackjack":
				if h_type == "BLACKJACK_21":
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

			"relic_astral_duo":
				if h_type == "ONE_PAIR" or h_type == "TWO_PAIR":
					res["mult"] = float(res.get("mult", 1.0)) * 2.0
					triggered_relics.append(relic_id)

			"relic_celestial_trio":
				if h_type == "THREE_OF_A_KIND" or h_type == "FULL_HOUSE":
					res["mult"] = float(res.get("mult", 1.0)) * 2.5
					triggered_relics.append(relic_id)

			"relic_elemental_surge":
				if h_type == "FLUSH" or h_type == "STRAIGHT_FLUSH":
					res["mult"] = float(res.get("mult", 1.0)) * 2.5
					triggered_relics.append(relic_id)

			"relic_sacred_order":
				if h_type == "STRAIGHT" or h_type == "STRAIGHT_FLUSH":
					res["mult"] = float(res.get("mult", 1.0)) * 3.0
					res["total_chips"] = int(res.get("total_chips", 0)) + 30
					triggered_relics.append(relic_id)

			"relic_odd_astrologer":
				var odd_cnt := 0
				for c in cards:
					var v: int = int(c.get("val", 0))
					if v % 2 != 0: odd_cnt += 1
				if odd_cnt > 0:
					res["mult"] = float(res.get("mult", 1.0)) + (odd_cnt * 8.0)
					triggered_relics.append(relic_id)

			"relic_even_magus":
				var even_cnt := 0
				for c in cards:
					var v: int = int(c.get("val", 0))
					if v > 0 and v % 2 == 0: even_cnt += 1
				if even_cnt > 0:
					res["total_chips"] = int(res.get("total_chips", 0)) + (even_cnt * 25)
					triggered_relics.append(relic_id)

			"relic_fibonacci_sigil":
				var fib_cnt := 0
				for c in cards:
					var v: int = int(c.get("val", 0))
					if v == 1 or v == 2 or v == 3 or v == 5 or v == 8:
						fib_cnt += 1
				if fib_cnt > 0:
					res["mult"] = float(res.get("mult", 1.0)) + (fib_cnt * 10.0)
					triggered_relics.append(relic_id)

			"relic_keen_eyeglass":
				var k_mult: float = float(extra_state.get("keen_mult", 0.0))
				if k_mult > 0.0:
					res["mult"] = float(res.get("mult", 1.0)) + k_mult
					triggered_relics.append(relic_id)

			"relic_sacred_abacus":
				var a_chips: int = int(extra_state.get("abacus_chips", 0))
				if a_chips > 0:
					res["total_chips"] = int(res.get("total_chips", 0)) + a_chips
					triggered_relics.append(relic_id)

			"relic_burning_geode":
				var g_mult: float = float(extra_state.get("geode_mult", 0.0))
				if g_mult > 0.0:
					res["mult"] = float(res.get("mult", 1.0)) + g_mult
					triggered_relics.append(relic_id)

			"relic_blast_ward":
				# Blast Ward là Cổ vật phòng ngự thụ động (bảo vệ khỏi mìn), không thay đổi điểm Chips/Mult
				pass

	res["triggered_relics"] = triggered_relics
	return res
