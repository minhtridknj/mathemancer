class_name TestHandEvaluator
extends RefCounted

const HandEvaluator = preload("res://scripts/core/hand_evaluator.gd")

static func run_tests() -> bool:
	print("--- Running TestHandEvaluator ---")
	var all_ok := true
	
	# 1. Straight Flush
	var sf_cards: Array[Dictionary] = [
		{"val": 2, "suit": "flame"},
		{"val": 3, "suit": "flame"},
		{"val": 4, "suit": "flame"},
		{"val": 5, "suit": "flame"},
		{"val": 6, "suit": "flame"}
	]
	var res_sf = HandEvaluator.evaluate_hand(sf_cards)
	if res_sf.type != "STRAIGHT_FLUSH" or res_sf.bonus_chips != 80 or res_sf.mult != 8.0:
		print("❌ FAIL Straight Flush: ", res_sf)
		all_ok = false
	else:
		print("  ✅ PASS Straight Flush (type: %s, chips: %d, mult: %s)" % [res_sf.type, res_sf.total_chips, str(res_sf.mult)])
	
	# 2. Blackjack 21
	var bj_cards: Array[Dictionary] = [
		{"val": 9, "suit": "flame"},
		{"val": 7, "suit": "frost"},
		{"val": 5, "suit": "spark"}
	]
	var res_bj = HandEvaluator.evaluate_hand(bj_cards)
	if res_bj.type != "BLACKJACK_21" or res_bj.bonus_chips != 50 or res_bj.mult != 6.0:
		print("❌ FAIL Blackjack 21: ", res_bj)
		all_ok = false
	else:
		print("  ✅ PASS Blackjack 21 (type: %s, chips: %d, mult: %s)" % [res_bj.type, res_bj.total_chips, str(res_bj.mult)])
		
	# 3. Flush
	var fl_cards: Array[Dictionary] = [
		{"val": 1, "suit": "frost"},
		{"val": 3, "suit": "frost"},
		{"val": 5, "suit": "frost"},
		{"val": 8, "suit": "frost"}
	]
	var res_fl = HandEvaluator.evaluate_hand(fl_cards)
	if res_fl.type != "FLUSH" or res_fl.bonus_chips != 35 or res_fl.mult != 4.0:
		print("❌ FAIL Flush: ", res_fl)
		all_ok = false
	else:
		print("  ✅ PASS Flush (type: %s, chips: %d, mult: %s)" % [res_fl.type, res_fl.total_chips, str(res_fl.mult)])
		
	# 4. Straight
	var st_cards: Array[Dictionary] = [
		{"val": 2, "suit": "flame"},
		{"val": 3, "suit": "frost"},
		{"val": 4, "suit": "spark"},
		{"val": 5, "suit": "shadow"}
	]
	var res_st = HandEvaluator.evaluate_hand(st_cards)
	if res_st.type != "STRAIGHT" or res_st.bonus_chips != 30 or res_st.mult != 3.5:
		print("❌ FAIL Straight: ", res_st)
		all_ok = false
	else:
		print("  ✅ PASS Straight (type: %s, chips: %d, mult: %s)" % [res_st.type, res_st.total_chips, str(res_st.mult)])
		
	# 5. Full House
	var fh_cards: Array[Dictionary] = [
		{"val": 3, "suit": "flame"},
		{"val": 3, "suit": "frost"},
		{"val": 3, "suit": "spark"},
		{"val": 5, "suit": "shadow"},
		{"val": 5, "suit": "flame"}
	]
	var res_fh = HandEvaluator.evaluate_hand(fh_cards)
	if res_fh.type != "FULL_HOUSE" or res_fh.bonus_chips != 40 or res_fh.mult != 4.0:
		print("❌ FAIL Full House: ", res_fh)
		all_ok = false
	else:
		print("  ✅ PASS Full House (type: %s, chips: %d, mult: %s)" % [res_fh.type, res_fh.total_chips, str(res_fh.mult)])

	# 6. Three of a Kind
	var tok_cards: Array[Dictionary] = [
		{"val": 4, "suit": "flame"},
		{"val": 4, "suit": "frost"},
		{"val": 4, "suit": "spark"},
		{"val": 1, "suit": "shadow"}
	]
	var res_tok = HandEvaluator.evaluate_hand(tok_cards)
	if res_tok.type != "THREE_OF_A_KIND" or res_tok.bonus_chips != 25 or res_tok.mult != 3.0:
		print("❌ FAIL Three of a Kind: ", res_tok)
		all_ok = false
	else:
		print("  ✅ PASS Three of a Kind (type: %s, chips: %d, mult: %s)" % [res_tok.type, res_tok.total_chips, str(res_tok.mult)])

	# 7. Two Pair
	var tp_cards: Array[Dictionary] = [
		{"val": 2, "suit": "flame"},
		{"val": 2, "suit": "frost"},
		{"val": 6, "suit": "spark"},
		{"val": 6, "suit": "shadow"}
	]
	var res_tp = HandEvaluator.evaluate_hand(tp_cards)
	if res_tp.type != "TWO_PAIR" or res_tp.bonus_chips != 20 or res_tp.mult != 2.5:
		print("❌ FAIL Two Pair: ", res_tp)
		all_ok = false
	else:
		print("  ✅ PASS Two Pair (type: %s, chips: %d, mult: %s)" % [res_tp.type, res_tp.total_chips, str(res_tp.mult)])

	# 8. One Pair
	var op_cards: Array[Dictionary] = [
		{"val": 5, "suit": "flame"},
		{"val": 5, "suit": "frost"},
		{"val": 1, "suit": "spark"}
	]
	var res_op = HandEvaluator.evaluate_hand(op_cards)
	if res_op.type != "ONE_PAIR" or res_op.bonus_chips != 10 or res_op.mult != 1.5:
		print("❌ FAIL One Pair: ", res_op)
		all_ok = false
	else:
		print("  ✅ PASS One Pair (type: %s, chips: %d, mult: %s)" % [res_op.type, res_op.total_chips, str(res_op.mult)])

	# 9. High Sum
	var hs_cards: Array[Dictionary] = [
		{"val": 1, "suit": "flame"},
		{"val": 3, "suit": "frost"},
		{"val": 7, "suit": "spark"}
	]
	var res_hs = HandEvaluator.evaluate_hand(hs_cards)
	if res_hs.type != "HIGH_SUM" or res_hs.bonus_chips != 0 or res_hs.mult != 1.0:
		print("❌ FAIL High Sum: ", res_hs)
		all_ok = false
	else:
		print("  ✅ PASS High Sum (type: %s, chips: %d, mult: %s)" % [res_hs.type, res_hs.total_chips, str(res_hs.mult)])

	return all_ok
