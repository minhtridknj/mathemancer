class_name TestItems
extends RefCounted

const RelicSystem = preload("res://scripts/core/relic_system.gd")
const ScrollSystem = preload("res://scripts/core/scroll_system.gd")

static func run_tests() -> bool:
	print("--- Running TestItems ---")
	var all_ok := true
	
	# 1. Test Relic: Blackjack Triple
	var bj_hand = {
		"type": "BLACKJACK_21",
		"name": "Blackjack 21",
		"base_sum": 21,
		"bonus_chips": 50,
		"total_chips": 71,
		"mult": 6.0
	}
	var dummy_cards: Array[Dictionary] = [
		{"val": 9, "suit": "flame"},
		{"val": 7, "suit": "frost"},
		{"val": 5, "suit": "spark"}
	]
	var modified_bj = RelicSystem.apply_relic_modifiers(bj_hand, dummy_cards, ["relic_blackjack"])
	if modified_bj.mult != 18.0:
		print("❌ FAIL Relic Blackjack: mult should be 18.0 (6.0 * 3), got ", modified_bj.mult)
		all_ok = false
	else:
		print("  ✅ PASS Relic Blackjack (Mult: 6.0 -> 18.0)")
		
	# 2. Test Relic: Flame Wrath (+12 Mult per flame card)
	var flame_cards: Array[Dictionary] = [
		{"val": 2, "suit": "flame"},
		{"val": 3, "suit": "flame"},
		{"val": 4, "suit": "frost"}
	]
	var normal_hand = {
		"type": "STRAIGHT",
		"name": "Straight",
		"base_sum": 9,
		"bonus_chips": 30,
		"total_chips": 39,
		"mult": 3.5
	}
	var modified_flame = RelicSystem.apply_relic_modifiers(normal_hand, flame_cards, ["relic_flame_wrath"])
	if modified_flame.mult != 27.5: # 3.5 + 2 * 12.0 = 27.5
		print("❌ FAIL Relic Flame Wrath: mult should be 27.5, got ", modified_flame.mult)
		all_ok = false
	else:
		print("  ✅ PASS Relic Flame Wrath (+24 Mult from 2 flame cards -> 27.5)")
		
	# 3. Test Scroll: Transmute Suit
	var test_cell = {"val": 3, "suit": "frost"}
	var scroll_res = ScrollSystem.use_scroll("scroll_suit_transmute", {"cell": test_cell, "new_suit": "flame"}, {})
	if not scroll_res or test_cell.suit != "flame":
		print("❌ FAIL Scroll Transmute Suit: cell suit is ", test_cell.suit)
		all_ok = false
	else:
		print("  ✅ PASS Scroll Transmute Suit (frost -> flame)")
		
	# 4. Test Scroll: Restore Play Hand
	var game_state = {"plays_left": 2, "max_plays": 4}
	var scroll_res2 = ScrollSystem.use_scroll("scroll_restore_play", {}, game_state)
	if not scroll_res2 or game_state.plays_left != 3:
		print("❌ FAIL Scroll Restore Play: plays_left is ", game_state.plays_left)
		all_ok = false
	else:
		print("  ✅ PASS Scroll Restore Play (plays: 2 -> 3)")
		
	return all_ok
