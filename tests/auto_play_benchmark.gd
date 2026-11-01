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
	var total_boards := 0
	var boards_fully_solved := 0
	var losses_by_ante := {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0}
	var run_logs: Array[Dictionary] = []
	
	for run_idx in range(num_runs):
		var seed_val := 1000 + run_idx * 73
		var run_result := _simulate_single_run(run_idx + 1, seed_val)
		run_logs.append(run_result)
		total_boards += int(run_result.get("boards_tested", 0))
		boards_fully_solved += int(run_result.get("boards_solved", 0))
		
		if run_result.won:
			wins += 1
			print("🏆 Run %2d [Seed %d]: WON ANTE 8! All boards fully solved by pure deduction. Relics: %s, Gold: %d" % [
				run_idx + 1, seed_val, str(run_result.final_relics), run_result.final_gold
			])
		else:
			losses_by_ante[run_result.failed_ante] += 1
			print("❌ Run %2d [Seed %d]: FAILED AT ANTE %d (%s)" % [
				run_idx + 1, seed_val, run_result.failed_ante, run_result.get("fail_reason", "Boss not defeated")
			])
			
	var win_rate := float(wins) / float(num_runs) * 100.0
	var full_board_solve_rate := float(boards_fully_solved) / float(maxi(1, total_boards)) * 100.0
	print("\n=======================================================")
	print("📊 BENCHMARK RESULTS SUMMARY:")
	print("  Total Runs: %d (Total Ante Boards Tested: %d)" % [num_runs, total_boards])
	print("  Full Board Solved by Deduction: %d / %d (%.1f%%)" % [boards_fully_solved, total_boards, full_board_solve_rate])
	print("  Victories (Ante 8 Cleared): %d / %d (%.1f%%)" % [wins, num_runs, win_rate])
	print("  Losses by Ante: %s" % str(losses_by_ante))
	print("=======================================================\n")
	
	return {
		"total_runs": num_runs,
		"wins": wins,
		"win_rate": win_rate,
		"total_boards": total_boards,
		"boards_fully_solved": boards_fully_solved,
		"full_board_solve_rate": full_board_solve_rate,
		"losses_by_ante": losses_by_ante,
		"logs": run_logs
	}

static func _simulate_single_run(run_id: int, seed_val: int) -> Dictionary:
	var gm := GameManagerClass.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	
	var won_game := true
	var failed_ante := -1
	var fail_reason := ""
	var last_hp_left := 0
	var last_max_hp := 0
	var last_dmg := 0
	var boards_tested := 0
	var boards_solved := 0
	
	for ante in range(1, 9):
		boards_tested += 1
		var ante_seed := seed_val + ante * 137
		
		# 1. Step-by-Step Deductive Solver:
		# Không nhìn trộm trước mìn, giải toàn bộ 100% ô trên bàn cờ bằng suy luận thuần túy
		var test_gm := GameManagerClass.new()
		test_gm.start_ante(ante, ante_seed)
		var solve_ok := _deductive_solve_board(test_gm)
		if not solve_ok:
			won_game = false
			failed_ante = ante
			fail_reason = "Deduction incomplete: board could not be 100% solved by logic"
			break
			
		boards_solved += 1
		
		# 2. Bắt đầu Ante và áp dụng các ô an toàn & cờ đã được suy luận 100% chính xác
		gm.start_ante(ante, ante_seed)
		for r in range(gm.grid_size):
			for c in range(gm.grid_size):
				if gm.board_data.cells[r][c].is_mine:
					gm.flagged[r][c] = true
					gm.correct_flags += 1
				else:
					gm.revealed[r][c] = true
					
		# 3. Sử dụng Cuộn Giấy Phép (Tarots) nếu có
		_use_inventory_scrolls(gm)
		
		# 4. Chơi các Hand bài tối ưu từ các ô an toàn đã giải mã
		var total_ante_dmg := 0
		var ante_max_hp := gm.max_boss_hp
		
		while gm.plays_left > 0 and gm.boss_hp > 0:
			var available_coords: Array[Vector2i] = []
			for r in range(gm.grid_size):
				for c in range(gm.grid_size):
					if gm.revealed[r][c] and not gm.exhausted[r][c]:
						available_coords.append(Vector2i(r, c))
						
			if available_coords.is_empty():
				break
				
			var best_hand_coords := _find_best_hand(gm, available_coords)
			if best_hand_coords.is_empty():
				break
			if best_hand_coords.size() > 5:
				best_hand_coords = best_hand_coords.slice(0, 5)
				
			var play_res := gm.play_hand(best_hand_coords)
			if play_res.is_empty():
				break
			total_ante_dmg += play_res.get("damage", 0)
			
		if gm.boss_hp > 0:
			won_game = false
			failed_ante = ante
			fail_reason = "Boss HP left: %d / %d, Dmg dealt: %d" % [gm.boss_hp, ante_max_hp, total_ante_dmg]
			last_hp_left = gm.boss_hp
			last_max_hp = ante_max_hp
			last_dmg = total_ante_dmg
			break
			
		# 5. Vào Chợ mua sắm giữa các Ante (Antes 1 to 7)
		if ante < 8:
			_simulate_shop_phase(gm, rng)
			
	return {
		"run_id": run_id,
		"seed": seed_val,
		"won": won_game,
		"failed_ante": failed_ante,
		"fail_reason": fail_reason,
		"boards_tested": boards_tested,
		"boards_solved": boards_solved,
		"boss_hp_left": last_hp_left,
		"max_boss_hp": last_max_hp,
		"dmg_dealt": last_dmg,
		"final_relics": gm.owned_relics.duplicate(),
		"final_gold": gm.gold
	}

static func _deductive_solve_board(gm: GameManagerClass) -> bool:
	var sz := gm.grid_size
	
	# Mở các ô mỏ neo ban đầu (given anchors)
	for r in range(sz):
		for c in range(sz):
			if gm.board_data.cells[r][c].is_given and not gm.revealed[r][c]:
				gm.click_tile(r, c)
				
	var max_iterations := 60
	var iter := 0
	
	while iter < max_iterations:
		iter += 1
		var progress := false
		
		# Quét suy luận liên tục qua các hàng và cột khả dụng
		var line_progress := true
		while line_progress:
			line_progress = false
			
			# Quét Hàng
			for r in range(sz):
				var clue: Dictionary = gm.board_data.row_clues[r]
				if clue.unlocked_at_stage > gm.current_stage:
					continue
					
				var known_safe_sum := 0
				var unk: Array[Vector2i] = []
				for c in range(sz):
					if gm.revealed[r][c]:
						known_safe_sum += int(gm.board_data.cells[r][c].val)
					elif not gm.flagged[r][c]:
						unk.append(Vector2i(r, c))
						
				if unk.is_empty():
					continue
					
				var rem_safe: int = int(clue.sum) - known_safe_sum
				if rem_safe == 0:
					for p in unk:
						if not gm.flagged[p.x][p.y]:
							gm.toggle_flag(p.x, p.y)
							line_progress = true
							progress = true
					continue
					
				var n := unk.size()
				if n <= 10:
					var valid_masks: Array[int] = []
					for mask in range(1 << n):
						var s := 0
						for k in range(n):
							if mask & (1 << k):
								s += int(gm.board_data.cells[unk[k].x][unk[k].y].val)
						if s == rem_safe:
							valid_masks.append(mask)
							
					if valid_masks.is_empty():
						return false
						
					var all_m := valid_masks[0]
					var any_m := valid_masks[0]
					for m in valid_masks:
						all_m &= m
						any_m |= m
						
					for k in range(n):
						var p := unk[k]
						if (all_m & (1 << k)) and not gm.revealed[p.x][p.y]:
							if gm.board_data.cells[p.x][p.y].is_mine:
								return false # Lỗi suy luận nếu click trúng mìn
							gm.click_tile(p.x, p.y)
							line_progress = true
							progress = true
						if not (any_m & (1 << k)) and not gm.flagged[p.x][p.y]:
							gm.toggle_flag(p.x, p.y)
							line_progress = true
							progress = true

			# Quét Cột
			for c in range(sz):
				var clue: Dictionary = gm.board_data.col_clues[c]
				if clue.unlocked_at_stage > gm.current_stage:
					continue
					
				var known_safe_sum := 0
				var unk: Array[Vector2i] = []
				for r in range(sz):
					if gm.revealed[r][c]:
						known_safe_sum += int(gm.board_data.cells[r][c].val)
					elif not gm.flagged[r][c]:
						unk.append(Vector2i(r, c))
						
				if unk.is_empty():
					continue
					
				var rem_safe: int = int(clue.sum) - known_safe_sum
				if rem_safe == 0:
					for p in unk:
						if not gm.flagged[p.x][p.y]:
							gm.toggle_flag(p.x, p.y)
							line_progress = true
							progress = true
					continue
					
				var n := unk.size()
				if n <= 10:
					var valid_masks: Array[int] = []
					for mask in range(1 << n):
						var s := 0
						for k in range(n):
							if mask & (1 << k):
								s += int(gm.board_data.cells[unk[k].x][unk[k].y].val)
						if s == rem_safe:
							valid_masks.append(mask)
							
					if valid_masks.is_empty():
						return false
						
					var all_m := valid_masks[0]
					var any_m := valid_masks[0]
					for m in valid_masks:
						all_m &= m
						any_m |= m
						
					for k in range(n):
						var p := unk[k]
						if (all_m & (1 << k)) and not gm.revealed[p.x][p.y]:
							if gm.board_data.cells[p.x][p.y].is_mine:
								return false
							gm.click_tile(p.x, p.y)
							line_progress = true
							progress = true
						if not (any_m & (1 << k)) and not gm.flagged[p.x][p.y]:
							gm.toggle_flag(p.x, p.y)
							line_progress = true
							progress = true

		# Kiểm tra xem toàn bộ ô đã được phân định rõ ràng hay chưa
		var unresolved := 0
		for r in range(sz):
			for c in range(sz):
				if not gm.revealed[r][c] and not gm.flagged[r][c]:
					unresolved += 1
					
		if unresolved == 0:
			# Xác thực 100% chính xác: không cắm cờ nhầm và không bỏ sót ô an toàn
			for r in range(sz):
				for c in range(sz):
					if gm.board_data.cells[r][c].is_mine and not gm.flagged[r][c]:
						return false
					if not gm.board_data.cells[r][c].is_mine and not gm.revealed[r][c]:
						return false
			return true
			
		# Nếu hết đường suy luận ở Chặng 1, giải trừ sương mù sang Chặng 2 bằng 1 Hand bài an toàn
		if not progress and gm.current_stage == 1:
			var safe_avail: Array[Vector2i] = []
			for r in range(sz):
				for c in range(sz):
					if gm.revealed[r][c] and not gm.exhausted[r][c]:
						safe_avail.append(Vector2i(r, c))
			if safe_avail.is_empty():
				return false
				
			safe_avail.sort_custom(func(a, b):
				return int(gm.board_data.cells[a.x][a.y].val) < int(gm.board_data.cells[b.x][b.y].val)
			)
			gm.play_hand([safe_avail[0]])
			progress = true
		elif not progress:
			# Kẹt không thể suy luận tiếp mà không đoán mò
			return false
			
	return false

static func _find_best_hand(gm: GameManagerClass, in_pool: Array[Vector2i]) -> Array[Vector2i]:
	var pool := in_pool.duplicate()
	if pool.size() > 16:
		pool = _filter_priority_pool(gm, pool)
	var candidates: Array[Array] = []
	var pool_size := pool.size()
	if pool_size == 0: return []
	
	# Group by suit
	var by_suit := {"flame": [], "frost": [], "spark": [], "shadow": []}
	for p in pool:
		var s: String = gm.board_data.cells[p.x][p.y].suit
		if by_suit.has(s):
			by_suit[s].append(p)
			
	var top_val_pool: Array[Vector2i] = pool.duplicate()
	top_val_pool.sort_custom(func(a, b): return int(gm.board_data.cells[a.x][a.y].val) > int(gm.board_data.cells[b.x][b.y].val))

	var fill_to_5 := func(base_hand: Array) -> Array:
		if base_hand.size() >= 5 or base_hand.size() >= pool_size:
			return base_hand.slice(0, 5)
		var filled := base_hand.duplicate()
		if gm.owned_relics.has("relic_flame_wrath"):
			for p in pool:
				if not filled.has(p) and gm.board_data.cells[p.x][p.y].suit == "flame":
					filled.append(p)
					if filled.size() == mini(5, pool_size): return filled
		for p in top_val_pool:
			if not filled.has(p):
				filled.append(p)
				if filled.size() == mini(5, pool_size):
					return filled
		return filled.slice(0, 5)

	for s in by_suit.keys():
		var s_pool: Array = by_suit[s]
		if s_pool.size() >= 5:
			var combos := _get_sample_combos(s_pool, 5, 10)
			candidates.append_array(combos)
			s_pool.sort_custom(func(a, b): return int(gm.board_data.cells[a.x][a.y].val) > int(gm.board_data.cells[b.x][b.y].val))
			candidates.append(s_pool.slice(0, 5))
		elif s_pool.size() >= 2:
			candidates.append(fill_to_5.call(s_pool))
			
	# Group by value (Pairs, 3-of-a-kind, 4-of-a-kind, Full House)
	var by_val := {}
	for p in pool:
		var v: int = int(gm.board_data.cells[p.x][p.y].val)
		if not by_val.has(v): by_val[v] = []
		by_val[v].append(p)
		
	var trips: Array = []
	var pairs: Array = []
	for v in by_val.keys():
		var v_list: Array = by_val[v]
		if v_list.size() >= 4:
			candidates.append(fill_to_5.call(v_list.slice(0, 4)))
		if v_list.size() >= 3:
			trips.append(v_list.slice(0, 3))
			candidates.append(fill_to_5.call(v_list.slice(0, 3)))
		if v_list.size() >= 2:
			pairs.append(v_list.slice(0, 2))
			candidates.append(fill_to_5.call(v_list.slice(0, 2)))
			
	# Full Houses (trip + pair)
	if trips.size() >= 1 and pairs.size() >= 1:
		for t in trips:
			for pr in pairs:
				if t[0] != pr[0]:
					var fh = t.duplicate()
					fh.append_array(pr)
					candidates.append(fh)
					break
	if trips.size() >= 2:
		var fh = trips[0].duplicate()
		fh.append_array(trips[1].slice(0, 2))
		candidates.append(fh)
		
	# Two pairs filled to 5
	if pairs.size() >= 2:
		var tp = pairs[0].duplicate()
		tp.append_array(pairs[1])
		candidates.append(fill_to_5.call(tp))
		
	# Straights: check consecutive values 5-card, 4-card, and 3-card
	for length in [5, 4, 3]:
		for start_val in range(1, 10 - length + 1):
			var has_all := true
			for v in range(start_val, start_val + length):
				if not by_val.has(v) or by_val[v].is_empty():
					has_all = false
					break
			if has_all:
				var str_cand: Array[Vector2i] = []
				for v in range(start_val, start_val + length):
					str_cand.append(by_val[v][0])
				candidates.append(fill_to_5.call(str_cand))

	# Relic specific synergy candidates:
	# 1. Fibonacci cards (1, 2, 3, 5, 8)
	var fib_cards: Array[Vector2i] = []
	for p in pool:
		var v: int = int(gm.board_data.cells[p.x][p.y].val)
		if v == 1 or v == 2 or v == 3 or v == 5 or v == 8:
			fib_cards.append(p)
	fib_cards.sort_custom(func(a, b): return int(gm.board_data.cells[a.x][a.y].val) > int(gm.board_data.cells[b.x][b.y].val))
	if fib_cards.size() >= 5:
		candidates.append(fib_cards.slice(0, 5))
		candidates.append_array(_get_sample_combos(fib_cards, 5, 10))
	elif fib_cards.size() >= 2:
		candidates.append(fill_to_5.call(fib_cards))
		
	# 2. Odd cards
	var odd_cards: Array[Vector2i] = []
	for p in pool:
		var v: int = int(gm.board_data.cells[p.x][p.y].val)
		if v % 2 != 0: odd_cards.append(p)
	odd_cards.sort_custom(func(a, b): return int(gm.board_data.cells[a.x][a.y].val) > int(gm.board_data.cells[b.x][b.y].val))
	if odd_cards.size() >= 5:
		candidates.append(odd_cards.slice(0, 5))
		candidates.append_array(_get_sample_combos(odd_cards, 5, 10))
	elif odd_cards.size() >= 2:
		candidates.append(fill_to_5.call(odd_cards))
		
	# 3. Even cards
	var even_cards: Array[Vector2i] = []
	for p in pool:
		var v: int = int(gm.board_data.cells[p.x][p.y].val)
		if v > 0 and v % 2 == 0: even_cards.append(p)
	even_cards.sort_custom(func(a, b): return int(gm.board_data.cells[a.x][a.y].val) > int(gm.board_data.cells[b.x][b.y].val))
	if even_cards.size() >= 5:
		candidates.append(even_cards.slice(0, 5))
		candidates.append_array(_get_sample_combos(even_cards, 5, 10))
	elif even_cards.size() >= 2:
		candidates.append(fill_to_5.call(even_cards))
		
	# 4. Flame cards filled to 5
	var flame_cards: Array = by_suit["flame"]
	if flame_cards.size() >= 4 and pool_size >= 5:
		var best_other := Vector2i(-1, -1)
		var max_other_v := -1
		for p in pool:
			if not flame_cards.has(p):
				var v: int = int(gm.board_data.cells[p.x][p.y].val)
				if v > max_other_v:
					max_other_v = v
					best_other = p
		if best_other.x >= 0:
			var f5 = flame_cards.slice(0, 4)
			f5.append(best_other)
			candidates.append(f5)
			
	# Blackjack 21: search combinations that sum to 21
	for k in range(2, mini(6, pool_size + 1)):
		var combos := _get_sample_combos(pool, k, 15)
		for combo in combos:
			var sm := 0
			for p in combo: sm += int(gm.board_data.cells[p.x][p.y].val)
			if sm == 21:
				candidates.append(combo)
				
	for k in range(1, mini(6, pool_size + 1)):
		candidates.append(top_val_pool.slice(0, k))
		
	# Sample diverse 5-card combos
	if pool_size >= 5:
		candidates.append_array(_get_sample_combos(pool, 5, 25))
			
	# Evaluate all candidates and pick highest score
	var best: Array[Vector2i] = []
	var max_score := -1
	var extra_st := {
		"correct_flags": gm.correct_flags,
		"keen_mult": gm.scaling_relic_state.get("keen_mult", 0.0),
		"abacus_chips": gm.scaling_relic_state.get("abacus_chips", 0),
		"geode_mult": gm.scaling_relic_state.get("geode_mult", 0.0)
	}
	
	var eval_cards := func(coords_list: Array) -> int:
		var c_cards: Array[Dictionary] = []
		for p in coords_list: c_cards.append(gm.board_data.cells[p.x][p.y])
		var ev := HandEval.evaluate_hand(c_cards)
		ev = RelicSys.apply_relic_modifiers(ev, c_cards, gm.owned_relics, extra_st)
		return int(round(float(ev.get("total_chips", 0)) * float(ev.get("mult", 1.0))))
		
	var do_lookahead := (pool_size <= 13 and gm.plays_left >= 2)
	
	for combo in candidates:
		if combo.is_empty(): continue
		if combo.size() > 5: combo = combo.slice(0, 5)
		var dmg: int = eval_cards.call(combo)
		var score := dmg
		
		if do_lookahead:
			var rem: Array[Vector2i] = []
			for p in pool:
				if not combo.has(p): rem.append(p)
			if not rem.is_empty():
				var best_rem_dmg := 0
				var rem_top: Array[Vector2i] = rem.duplicate()
				rem_top.sort_custom(func(a, b): return int(gm.board_data.cells[a.x][a.y].val) > int(gm.board_data.cells[b.x][b.y].val))
				for rk in range(1, mini(6, rem.size() + 1)):
					var rd: int = eval_cards.call(rem_top.slice(0, rk))
					if rd > best_rem_dmg: best_rem_dmg = rd
				score = dmg + best_rem_dmg
				
		if score > max_score:
			max_score = score
			best.clear()
			for p in combo:
				best.append(p)
			
	return best

static func _filter_priority_pool(gm: GameManagerClass, pool: Array[Vector2i]) -> Array[Vector2i]:
	var has_flame_relic := gm.owned_relics.has("relic_flame_wrath")
	var has_frost_relic := gm.owned_relics.has("relic_frost_shield")
	var has_fib_relic := gm.owned_relics.has("relic_fibonacci_sigil")
	var has_even_relic := gm.owned_relics.has("relic_even_magus")
	var has_odd_relic := gm.owned_relics.has("relic_odd_astrologer")
	
	var sorted := pool.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i):
		var card_a: Dictionary = gm.board_data.cells[a.x][a.y]
		var card_b: Dictionary = gm.board_data.cells[b.x][b.y]
		var score_a := int(card_a.get("val", 0))
		var score_b := int(card_b.get("val", 0))
		if has_flame_relic:
			if card_a.get("suit", "") == "flame": score_a += 15
			if card_b.get("suit", "") == "flame": score_b += 15
		if has_frost_relic:
			if card_a.get("suit", "") == "frost": score_a += 5
			if card_b.get("suit", "") == "frost": score_b += 5
		if has_fib_relic:
			var va: int = card_a.get("val", 0)
			var vb: int = card_b.get("val", 0)
			if va == 1 or va == 2 or va == 3 or va == 5 or va == 8: score_a += 10
			if vb == 1 or vb == 2 or vb == 3 or vb == 5 or vb == 8: score_b += 10
		if has_even_relic:
			if int(card_a.get("val", 0)) % 2 == 0: score_a += 6
			if int(card_b.get("val", 0)) % 2 == 0: score_b += 6
		if has_odd_relic:
			if int(card_a.get("val", 0)) % 2 != 0: score_a += 6
			if int(card_b.get("val", 0)) % 2 != 0: score_b += 6
		return score_a > score_b
	)
	return sorted.slice(0, 18)

static func _get_sample_combos(arr: Array, k: int, max_cnt: int) -> Array[Array]:
	var res: Array[Array] = []
	var n := arr.size()
	if k > n or k <= 0: return res
	var shuf := arr.duplicate()
	for s in range(max_cnt):
		shuf.shuffle()
		res.append(shuf.slice(0, k))
	return res

static func _use_inventory_scrolls(gm: GameManagerClass) -> void:
	# Use scroll_restore_play immediately if owned
	var scrolls_copy := gm.owned_scrolls.duplicate()
	for s_id in scrolls_copy:
		if s_id == "scroll_restore_play":
			gm.use_scroll("scroll_restore_play")
		elif s_id == "scroll_suit_transmute":
			var target_suit := "flame"
			for r in range(gm.grid_size):
				for c in range(gm.grid_size):
					if gm.revealed[r][c] and not gm.board_data.cells[r][c].is_mine and gm.board_data.cells[r][c].suit != target_suit:
						gm.use_scroll("scroll_suit_transmute", Vector2i(r, c), target_suit)
						break
				if not gm.owned_scrolls.has("scroll_suit_transmute"): break
		elif s_id == "scroll_value_boost":
			for r in range(gm.grid_size):
				for c in range(gm.grid_size):
					if gm.revealed[r][c] and not gm.board_data.cells[r][c].is_mine:
						gm.use_scroll("scroll_value_boost", Vector2i(r, c))
						break
				if not gm.owned_scrolls.has("scroll_value_boost"): break

static func _simulate_shop_phase(gm: GameManagerClass, rng: RandomNumberGenerator) -> void:
	var relic_priorities := [
		"relic_flame_wrath",
		"relic_fibonacci_sigil",
		"relic_even_magus",
		"relic_odd_astrologer",
		"relic_astral_duo",
		"relic_celestial_trio",
		"relic_sacred_order",
		"relic_elemental_surge",
		"relic_burning_geode",
		"relic_keen_eyeglass",
		"relic_sudoku_compass",
		"relic_blackjack",
		"relic_sacred_abacus",
		"relic_blast_ward",
		"relic_mine_magnifier",
		"relic_frost_shield"
	]
	
	# Simulate up to 4 shop passes with reroll (reroll cost 2)
	for pass_num in range(4):
		var offered_relics: Array[String] = []
		var all_relics := RelicSys.RELIC_DEFINITIONS.keys()
		# Deterministic shuffle using run-specific rng
		for i in range(all_relics.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp = all_relics[i]
			all_relics[i] = all_relics[j]
			all_relics[j] = tmp
		for r_id in all_relics:
			if not gm.owned_relics.has(r_id):
				offered_relics.append(r_id)
				if offered_relics.size() >= 3: break
				
		for pref in relic_priorities:
			if offered_relics.has(pref):
				var cost: int = RelicSys.RELIC_DEFINITIONS[pref].cost
				if gm.owned_relics.size() < 5 and gm.gold >= cost:
					gm.buy_relic(pref)
				elif gm.owned_relics.size() >= 5:
					var lowest_idx := -1
					var lowest_relic := ""
					for o_id in gm.owned_relics:
						var idx := relic_priorities.find(o_id)
						if idx > lowest_idx:
							lowest_idx = idx
							lowest_relic = o_id
					var pref_idx := relic_priorities.find(pref)
					if pref_idx < lowest_idx and (gm.gold + 2) >= cost:
						gm.owned_relics.erase(lowest_relic)
						gm.gold += 2
						gm.buy_relic(pref)
					
		if gm.owned_scrolls.size() < 2:
			var all_scrolls := ["scroll_restore_play", "scroll_suit_transmute", "scroll_value_boost"]
			for s_id in all_scrolls:
				var s_cost: int = ScrollSys.SCROLL_DEFINITIONS[s_id].cost
				if gm.gold >= s_cost and not gm.owned_scrolls.has(s_id):
					gm.buy_scroll(s_id)
					if gm.owned_scrolls.size() >= 2: break
					
		if gm.gold >= 4:
			gm.gold -= 2
		else:
			break
