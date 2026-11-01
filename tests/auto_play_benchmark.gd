class_name AutoPlayBenchmark
extends RefCounted

const GameManagerClass = preload("res://scripts/core/game_manager.gd")
const RelicSys = preload("res://scripts/core/relic_system.gd")
const ScrollSys = preload("res://scripts/core/scroll_system.gd")
const HandEval = preload("res://scripts/core/hand_evaluator.gd")

static func run_benchmark(num_runs: int = 20) -> Dictionary:
	print("\n=======================================================")
	print("🤖 STARTING AUTO-PLAY BENCHMARK: %d FULL RUNS (ANTE 1 -> 8)" % num_runs)
	print("=======================================================")
	
	var wins := 0
	var losses_by_ante := {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0}
	var run_logs: Array[Dictionary] = []
	
	for run_idx in range(num_runs):
		var seed_val := 1000 + run_idx * 73
		var run_result := _simulate_single_run(run_idx + 1, seed_val)
		run_logs.append(run_result)
		
		if run_result.won:
			wins += 1
			print("🏆 Run %2d [Seed %d]: WON ANTE 8! Relics: %s, Gold: %d" % [run_idx + 1, seed_val, str(run_result.final_relics), run_result.final_gold])
		else:
			losses_by_ante[run_result.failed_ante] += 1
			print("❌ Run %2d [Seed %d]: FAILED AT ANTE %d (Boss HP left: %d / %d, Dmg dealt: %d)" % [
				run_idx + 1, seed_val, run_result.failed_ante, run_result.boss_hp_left, run_result.max_boss_hp, run_result.dmg_dealt
			])
			
	var win_rate := float(wins) / float(num_runs) * 100.0
	print("\n=======================================================")
	print("📊 BENCHMARK RESULTS SUMMARY:")
	print("  Total Runs: %d" % num_runs)
	print("  Victories (Ante 8 Cleared): %d / %d (%.1f%%)" % [wins, num_runs, win_rate])
	print("  Losses by Ante: %s" % str(losses_by_ante))
	print("=======================================================\n")
	
	return {
		"total_runs": num_runs,
		"wins": wins,
		"win_rate": win_rate,
		"losses_by_ante": losses_by_ante,
		"logs": run_logs
	}

static func _simulate_single_run(run_id: int, seed_val: int) -> Dictionary:
	var gm := GameManagerClass.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	
	var won_game := true
	var failed_ante := -1
	var last_hp_left := 0
	var last_max_hp := 0
	var last_dmg := 0
	
	for ante in range(1, 9):
		# 1. Start Ante
		var ante_seed := seed_val + ante * 137
		gm.start_ante(ante, ante_seed)
		
		# 2. Perfect deduction: reveal all safe tiles and flag all mines
		var safe_coords: Array[Vector2i] = []
		for r in range(gm.grid_size):
			for c in range(gm.grid_size):
				if gm.board_data.cells[r][c].is_mine:
					gm.flagged[r][c] = true
					gm.correct_flags += 1
				else:
					gm.revealed[r][c] = true
					safe_coords.append(Vector2i(r, c))
					
		# Use scrolls if applicable (e.g. transmute suits to match owned relics)
		_use_inventory_scrolls(gm)
		
		# 3. Play optimal hands
		var total_ante_dmg := 0
		var ante_max_hp := gm.max_boss_hp
		
		while gm.plays_left > 0 and gm.boss_hp > 0:
			var available_coords: Array[Vector2i] = []
			for pos in safe_coords:
				if not gm.exhausted[pos.x][pos.y]:
					available_coords.append(pos)
					
			if available_coords.is_empty():
				break
				
			var best_hand_coords := _find_best_hand(gm, available_coords)
			if best_hand_coords.is_empty():
				break
				
			var play_res := gm.play_hand(best_hand_coords)
			total_ante_dmg += play_res.get("damage", 0)
			
		if gm.boss_hp > 0:
			won_game = false
			failed_ante = ante
			last_hp_left = gm.boss_hp
			last_max_hp = ante_max_hp
			last_dmg = total_ante_dmg
			break
			
		# 4. Visit Shop between Antes (Antes 1 to 7)
		if ante < 8:
			_simulate_shop_phase(gm, rng)
			
	return {
		"run_id": run_id,
		"seed": seed_val,
		"won": won_game,
		"failed_ante": failed_ante,
		"boss_hp_left": last_hp_left,
		"max_boss_hp": last_max_hp,
		"dmg_dealt": last_dmg,
		"final_relics": gm.owned_relics.duplicate(),
		"final_gold": gm.gold
	}

static func _find_best_hand(gm: GameManagerClass, available_coords: Array[Vector2i]) -> Array[Vector2i]:
	# Greedy search across all 1 to 5 card combinations from available coords
	# Returns the subset of coords yielding maximum damage
	var best_coords: Array[Vector2i] = []
	var max_dmg := -1
	
	# If small pool, evaluate all combinations up to size 5
	# If large pool, take top candidates sorted by value/suit synergy
	var pool: Array[Vector2i] = available_coords.duplicate()
	if pool.size() > 16:
		# Filter to prioritize highest cards or matching suits
		pool = _filter_priority_pool(gm, pool)
		
	var pool_size := pool.size()
	
	# Evaluate sizes 5 down to 1
	var target_sizes := [mini(5, pool_size), mini(4, pool_size), mini(3, pool_size), mini(2, pool_size), 1]
	for k in target_sizes:
		if k <= 0: continue
		var combos := _get_combinations(pool, k, 250) # Sample up to 250 combos
		for combo in combos:
			var cards: Array[Dictionary] = []
			for p in combo:
				cards.append(gm.board_data.cells[p.x][p.y])
			var eval_res := HandEval.evaluate_hand(cards)
			eval_res = RelicSys.apply_relic_modifiers(eval_res, cards, gm.owned_relics, {"correct_flags": gm.correct_flags})
			var dmg: int = int(round(float(eval_res.get("total_chips", 0)) * float(eval_res.get("mult", 1.0))))
			if dmg > max_dmg:
				max_dmg = dmg
				best_coords = combo
				
	return best_coords

static func _filter_priority_pool(gm: GameManagerClass, pool: Array[Vector2i]) -> Array[Vector2i]:
	# Sort available cards by value descending, giving preference to flame cards if flame relic owned
	var has_flame_relic := gm.owned_relics.has("relic_flame_wrath")
	var has_frost_relic := gm.owned_relics.has("relic_frost_shield")
	
	pool.sort_custom(func(a: Vector2i, b: Vector2i):
		var card_a: Dictionary = gm.board_data.cells[a.x][a.y]
		var card_b: Dictionary = gm.board_data.cells[b.x][b.y]
		var score_a := int(card_a.get("val", 0))
		var score_b := int(card_b.get("val", 0))
		if has_flame_relic:
			if card_a.get("suit", "") == "flame": score_a += 10
			if card_b.get("suit", "") == "flame": score_b += 10
		if has_frost_relic:
			if card_a.get("suit", "") == "frost": score_a += 5
			if card_b.get("suit", "") == "frost": score_b += 5
		return score_a > score_b
	)
	return pool.slice(0, 16)

static func _get_combinations(arr: Array[Vector2i], k: int, max_samples: int) -> Array[Array]:
	var results: Array[Array] = []
	var n := arr.size()
	if k > n or k <= 0:
		return results
	if k == 1:
		for item in arr:
			results.append([item])
		return results
		
	# Recursive combination sampler with sample limit
	_combine_helper(arr, k, 0, [], results, max_samples)
	return results

static func _combine_helper(arr: Array[Vector2i], k: int, start: int, current: Array[Vector2i], results: Array[Array], limit: int) -> void:
	if results.size() >= limit:
		return
	if current.size() == k:
		results.append(current.duplicate())
		return
	for i in range(start, arr.size()):
		if results.size() >= limit: break
		current.append(arr[i])
		_combine_helper(arr, k, i + 1, current, results, limit)
		current.pop_back()

static func _use_inventory_scrolls(gm: GameManagerClass) -> void:
	# Transmute non-flame safe tiles into flame if owning flame wrath
	if gm.owned_relics.has("relic_flame_wrath") and gm.owned_scrolls.has("scroll_suit_transmute"):
		for r in range(gm.grid_size):
			for c in range(gm.grid_size):
				if not gm.board_data.cells[r][c].is_mine and gm.board_data.cells[r][c].suit != "flame":
					gm.use_scroll("scroll_suit_transmute", Vector2i(r, c), "flame")
					break
			if not gm.owned_scrolls.has("scroll_suit_transmute"):
				break

static func _simulate_shop_phase(gm: GameManagerClass, rng: RandomNumberGenerator) -> void:
	# Priority list of relics to buy
	var relic_priorities := [
		"relic_flame_wrath",
		"relic_sudoku_compass",
		"relic_mine_magnifier",
		"relic_frost_shield",
		"relic_blackjack"
	]
	
	# Simulate 1 to 2 shop passes with reroll if gold allows
	for pass_num in range(2):
		var offered_relics: Array[String] = []
		var all_relics := RelicSys.RELIC_DEFINITIONS.keys()
		all_relics.shuffle()
		for r_id in all_relics:
			if not gm.owned_relics.has(r_id):
				offered_relics.append(r_id)
				if offered_relics.size() >= 3: break
				
		# Buy highest priority affordable relic
		for pref in relic_priorities:
			if offered_relics.has(pref) and gm.owned_relics.size() < 5:
				var cost: int = RelicSys.RELIC_DEFINITIONS[pref].cost
				if gm.gold >= cost:
					gm.buy_relic(pref)
					break
					
		# Check scrolls (tarots)
		if gm.owned_scrolls.size() < 2:
			var all_scrolls := ScrollSys.SCROLL_DEFINITIONS.keys()
			all_scrolls.shuffle()
			for s_id in all_scrolls:
				var s_cost: int = ScrollSys.SCROLL_DEFINITIONS[s_id].cost
				if (s_id == "scroll_restore_play" or (s_id == "scroll_suit_transmute" and gm.owned_relics.has("relic_flame_wrath"))) and gm.gold >= s_cost + 4:
					gm.buy_scroll(s_id)
					break
					
		# Optional reroll if we still have plenty of gold and haven't maxed relics
		if gm.owned_relics.size() < 5 and gm.gold >= 8:
			gm.gold -= 2
		else:
			break
