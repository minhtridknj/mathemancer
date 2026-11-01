class_name HandEvaluator
extends RefCounted

## Bộ thẩm định tổ hợp bài và tính điểm sát thương (Chips × Mult)
## Hỗ trợ 9 loại tổ hợp theo thứ tự ưu tiên của game Mathemancer

static func evaluate_hand(cards: Array[Dictionary]) -> Dictionary:
	if cards.is_empty():
		return {
			"type": "NONE",
			"name": "No Hand",
			"base_sum": 0,
			"bonus_chips": 0,
			"total_chips": 0,
			"mult": 0.0,
			"desc": "No cards selected"
		}
	
	var values: Array[int] = []
	var base_sum := 0
	for card in cards:
		var v: int = int(card.get("val", 0))
		values.append(v)
		base_sum += v
	values.sort()
	
	var is_fl := _check_flush(cards)
	var is_st := _check_straight(values)
	var counts := _get_counts(values)
	var has_bj := (base_sum == 21)
	
	# 1. Straight Flush (5 sequential numbers of the same suit)
	if is_fl and is_st and cards.size() >= 5:
		return _build_result("STRAIGHT_FLUSH", "Straight Flush", base_sum, 80, 8.0, "5 sequential numbers of the same elemental suit")
	
	# 2. Blackjack 21 (Exact sum of 21)
	if has_bj:
		return _build_result("BLACKJACK_21", "Blackjack 21", base_sum, 50, 6.0, "Sum reaches exactly 21 gold points")
		
	# 3. Flush (4 or 5 numbers of the same suit)
	if is_fl and cards.size() >= 4:
		return _build_result("FLUSH", "Flush", base_sum, 35, 4.0, "%d numbers of the same elemental suit" % cards.size())
		
	# 4. Straight (3 to 5 consecutive numbers)
	if is_st and values.size() >= 3:
		return _build_result("STRAIGHT", "Straight", base_sum, 30, 3.5, "%d consecutive numbers in sequence" % values.size())
		
	# 5. Full House (Three of a kind + Pair)
	if _has_full_house(counts):
		return _build_result("FULL_HOUSE", "Full House", base_sum, 40, 4.0, "Three of a kind combined with a pair")
		
	# 6. Three of a Kind
	if _has_count(counts, 3):
		return _build_result("THREE_OF_A_KIND", "Three of a Kind", base_sum, 25, 3.0, "Three numbers of the same value")
		
	# 7. Two Pair
	if _has_two_pair(counts):
		return _build_result("TWO_PAIR", "Two Pair", base_sum, 20, 2.5, "Two distinct pairs of numbers")
		
	# 8. One Pair
	if _has_count(counts, 2):
		return _build_result("ONE_PAIR", "One Pair", base_sum, 10, 1.5, "Two numbers of the same value")
		
	# 9. High Sum
	return _build_result("HIGH_SUM", "High Sum", base_sum, 0, 1.0, "Individual numbers combined together")

static func _build_result(type_id: String, name_str: String, base_sum: int, bonus_chips: int, mult_val: float, desc_str: String) -> Dictionary:
	return {
		"type": type_id,
		"name": name_str,
		"base_sum": base_sum,
		"bonus_chips": bonus_chips,
		"total_chips": base_sum + bonus_chips,
		"mult": mult_val,
		"desc": desc_str
	}

static func _check_flush(cards: Array[Dictionary]) -> bool:
	if cards.is_empty():
		return false
	var first_suit: String = str(cards[0].get("suit", ""))
	if first_suit.is_empty():
		return false
	for card in cards:
		if str(card.get("suit", "")) != first_suit:
			return false
	return true

static func _check_straight(sorted_values: Array[int]) -> bool:
	if sorted_values.size() < 3:
		return false
	for i in range(1, sorted_values.size()):
		if sorted_values[i] != sorted_values[i - 1] + 1:
			return false
	return true

static func _get_counts(sorted_values: Array[int]) -> Dictionary:
	var counts := {}
	for v in sorted_values:
		counts[v] = counts.get(v, 0) + 1
	return counts

static func _has_count(counts: Dictionary, target_count: int) -> bool:
	for k in counts:
		if counts[k] >= target_count:
			return true
	return false

static func _has_full_house(counts: Dictionary) -> bool:
	var has_three := false
	var has_two := false
	for k in counts:
		if counts[k] == 3:
			has_three = true
		elif counts[k] == 2:
			has_two = true
	return has_three and has_two

static func _has_two_pair(counts: Dictionary) -> bool:
	var pair_count := 0
	for k in counts:
		if counts[k] >= 2:
			pair_count += 1
	return pair_count >= 2
