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
		
	# 5. Test Hand Multiplier Relics: Astral Duo (x2 Mult on Pair)
	var pair_hand = {"type": "ONE_PAIR", "total_chips": 30, "mult": 2.0}
	var res_duo = RelicSystem.apply_relic_modifiers(pair_hand, [{"val": 4}, {"val": 4}], ["relic_astral_duo"])
	if res_duo.mult != 4.0:
		print("❌ FAIL Relic Astral Duo: expected mult 4.0, got ", res_duo.mult)
		all_ok = false
	else:
		print("  ✅ PASS Relic Astral Duo (One Pair: 2.0 -> 4.0)")

	# 6. Test Hand Multiplier Relics: Celestial Trio (x2.5 Mult on Three of a Kind)
	var trio_hand = {"type": "THREE_OF_A_KIND", "total_chips": 45, "mult": 3.0}
	var res_trio = RelicSystem.apply_relic_modifiers(trio_hand, [{"val": 3}, {"val": 3}, {"val": 3}], ["relic_celestial_trio"])
	if res_trio.mult != 7.5:
		print("❌ FAIL Relic Celestial Trio: expected mult 7.5, got ", res_trio.mult)
		all_ok = false
	else:
		print("  ✅ PASS Relic Celestial Trio (Three of a Kind: 3.0 -> 7.5)")

	# 7. Test Hand Multiplier Relics: Elemental Surge (x2.5 Mult on Flush)
	var flush_hand = {"type": "FLUSH", "total_chips": 50, "mult": 4.0}
	var res_flush = RelicSystem.apply_relic_modifiers(flush_hand, [{"val": 1, "suit": "flame"}, {"val": 2, "suit": "flame"}], ["relic_elemental_surge"])
	if res_flush.mult != 10.0:
		print("❌ FAIL Relic Elemental Surge: expected mult 10.0, got ", res_flush.mult)
		all_ok = false
	else:
		print("  ✅ PASS Relic Elemental Surge (Flush: 4.0 -> 10.0)")

	# 8. Test Hand Multiplier Relics: Sacred Order (x3.0 Mult & +30 Chips on Straight)
	var straight_hand = {"type": "STRAIGHT", "total_chips": 40, "mult": 3.5}
	var res_order = RelicSystem.apply_relic_modifiers(straight_hand, [{"val": 1}, {"val": 2}, {"val": 3}], ["relic_sacred_order"])
	if res_order.mult != 10.5 or res_order.total_chips != 70:
		print("❌ FAIL Relic Sacred Order: expected mult 10.5 & 70 chips, got ", res_order.mult, " & ", res_order.total_chips)
		all_ok = false
	else:
		print("  ✅ PASS Relic Sacred Order (Straight: 3.5 -> 10.5 Mult, 40 -> 70 Chips)")

	# 9. Test Odd & Even Astrologers
	var odd_even_cards: Array[Dictionary] = [
		{"val": 1}, {"val": 3}, # 2 odd
		{"val": 2}, {"val": 4}  # 2 even
	]
	var base_h = {"type": "HIGH_SUM", "total_chips": 20, "mult": 1.0}
	var res_odd = RelicSystem.apply_relic_modifiers(base_h, odd_even_cards, ["relic_odd_astrologer"])
	if res_odd.mult != 17.0: # 1.0 + 2 * 8.0 = 17.0
		print("❌ FAIL Relic Odd Astrologer: expected mult 17.0, got ", res_odd.mult)
		all_ok = false
	else:
		print("  ✅ PASS Relic Odd Astrologer (+16 Mult from 2 odd cards -> 17.0)")

	var res_even = RelicSystem.apply_relic_modifiers(base_h, odd_even_cards, ["relic_even_magus"])
	if res_even.total_chips != 70: # 20 + 2 * 25 = 70
		print("❌ FAIL Relic Even Magus: expected chips 70, got ", res_even.total_chips)
		all_ok = false
	else:
		print("  ✅ PASS Relic Even Magus (+50 Chips from 2 even cards -> 70)")

	# 10. Test Fibonacci Sigil (+10 Mult per 1, 2, 3, 5, 8)
	var fib_cards: Array[Dictionary] = [
		{"val": 1}, {"val": 2}, {"val": 5}, {"val": 6} # 3 fibonacci (1, 2, 5), 6 is not
	]
	var res_fib = RelicSystem.apply_relic_modifiers(base_h, fib_cards, ["relic_fibonacci_sigil"])
	if res_fib.mult != 31.0: # 1.0 + 3 * 10.0 = 31.0
		print("❌ FAIL Relic Fibonacci: expected mult 31.0, got ", res_fib.mult)
		all_ok = false
	else:
		print("  ✅ PASS Relic Fibonacci Sigil (+30 Mult from 3 Fibonacci numbers -> 31.0)")

	# 11. Test Scaling Relics: Keen Eyeglass, Sacred Abacus, Burning Geode
	var scaling_state = {
		"keen_mult": 6.0,
		"abacus_chips": 24,
		"geode_mult": 4.5
	}
	var res_scale = RelicSystem.apply_relic_modifiers(base_h, dummy_cards, [
		"relic_keen_eyeglass", "relic_sacred_abacus", "relic_burning_geode"
	], scaling_state)
	if res_scale.mult != 11.5 or res_scale.total_chips != 44: # Mult: 1.0 + 6.0 + 4.5 = 11.5; Chips: 20 + 24 = 44
		print("❌ FAIL Scaling Relics: expected mult 11.5 & chips 44, got ", res_scale.mult, " & ", res_scale.total_chips)
		all_ok = false
	else:
		print("  ✅ PASS Scaling Relics (Keen Eyeglass, Sacred Abacus, Burning Geode integrated)")

	# 12. Verify all 16 Relics exist in RELIC_DEFINITIONS with rich metadata
	var expected_keys = [
		"relic_blackjack", "relic_flame_wrath", "relic_frost_shield", "relic_mine_magnifier", "relic_sudoku_compass",
		"relic_keen_eyeglass", "relic_sacred_abacus", "relic_burning_geode",
		"relic_astral_duo", "relic_celestial_trio", "relic_elemental_surge", "relic_sacred_order",
		"relic_odd_astrologer", "relic_even_magus", "relic_fibonacci_sigil", "relic_blast_ward"
	]
	for k in expected_keys:
		if not RelicSystem.RELIC_DEFINITIONS.has(k):
			print("❌ FAIL Missing relic definition: ", k)
			all_ok = false
		else:
			var def = RelicSystem.RELIC_DEFINITIONS[k]
			if not def.has("name") or not def.has("desc") or not def.has("icon") or not def.has("short_desc") or not def.has("tip"):
				print("❌ FAIL Incomplete metadata for relic: ", k)
				all_ok = false
	if all_ok:
		print("  ✅ PASS All 16 Relic Definitions verified with complete metadata & icons")
		
	return all_ok
