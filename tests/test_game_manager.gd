class_name TestGameManager
extends RefCounted

const GameManager = preload("res://scripts/core/game_manager.gd")

static func run_tests() -> bool:
	print("--- Running TestGameManager ---")
	var all_ok := true
	
	var gm := GameManager.new()
	gm.start_ante(1, 42) # fixed seed
	
	# 1. Check Ante 1 initial values
	if gm.boss_hp < 200 or gm.plays_left != 4:
		print("❌ FAIL initial values: boss_hp=%d, plays_left=%d" % [gm.boss_hp, gm.plays_left])
		all_ok = false
	else:
		print("  ✅ PASS Initial ante values (Boss HP: %d, Plays: %d)" % [gm.boss_hp, gm.plays_left])
		
	# 2. Find a mine and click it -> verify plays_left drops by 1
	var mine_pos := Vector2i(-1, -1)
	for r in range(gm.grid_size):
		for c in range(gm.grid_size):
			if gm.board_data.cells[r][c].is_mine:
				mine_pos = Vector2i(r, c)
				break
		if mine_pos.x != -1: break
		
	var initial_plays := gm.plays_left
	gm.click_tile(mine_pos.x, mine_pos.y)
	if gm.plays_left != initial_plays - 1:
		print("❌ FAIL mine click didn't decrement plays_left: was %d, now %d" % [initial_plays, gm.plays_left])
		all_ok = false
	else:
		print("  ✅ PASS Clicking mine decrements plays_left by 1 (was %d -> %d)" % [initial_plays, gm.plays_left])
		
	# 3. Open safe tiles, form a hand, and play it
	var safe_coords: Array[Vector2i] = []
	for r in range(gm.grid_size):
		for c in range(gm.grid_size):
			if not gm.board_data.cells[r][c].is_mine:
				gm.click_tile(r, c)
				safe_coords.append(Vector2i(r, c))
				if safe_coords.size() >= 3: break
		if safe_coords.size() >= 3: break
		
	var hp_before := gm.boss_hp
	var hand_res = gm.play_hand(safe_coords)
	if hand_res.total_chips <= 0 or gm.boss_hp >= hp_before:
		print("❌ FAIL play_hand didn't deal damage: hp was %d, now %d" % [hp_before, gm.boss_hp])
		all_ok = false
	else:
		print("  ✅ PASS play_hand dealt %d damage (Boss HP: %d -> %d)" % [hand_res.damage, hp_before, gm.boss_hp])
		
	# Verify tiles are marked exhausted
	var exhausted_ok := true
	for p in safe_coords:
		if not gm.exhausted[p.x][p.y]:
			exhausted_ok = false
	if exhausted_ok:
		print("  ✅ PASS Played tiles are marked exhausted")
	else:
		print("❌ FAIL Played tiles were not marked exhausted")
		all_ok = false
		
	# 4. Test Game Over when board runs out of safe tiles before Boss defeat
	var gm2 := GameManager.new()
	gm2.start_ante(1, 42)
	var tracker := {"game_over": false}
	gm2.game_over.connect(func():
		tracker["game_over"] = true
	)
	gm2.boss_hp = 10000 # Boss still alive
	gm2.plays_left = 5  # Plays still remaining (> 0)
	
	# Exhaust all safe tiles except a final hand of 2 tiles
	var remaining_safe: Array[Vector2i] = []
	for r in range(gm2.grid_size):
		for c in range(gm2.grid_size):
			if not gm2.board_data.cells[r][c].is_mine:
				if remaining_safe.size() < 2:
					remaining_safe.append(Vector2i(r, c))
				else:
					gm2.exhausted[r][c] = true
					
	gm2.play_hand(remaining_safe)
	if not tracker["game_over"]:
		print("❌ FAIL game_over not emitted when all safe tiles exhausted!")
		all_ok = false
	else:
		print("  ✅ PASS Game Over triggered when all board tiles exhausted with Boss alive")
		
	# 5. Test Relic: Blast Ward mine absorption
	var gm_ward := GameManager.new()
	gm_ward.start_ante(1, 42)
	gm_ward.owned_relics.append("relic_blast_ward")
	var ward_tracker := {"absorbed": false}
	gm_ward.ward_absorbed_mine.connect(func(r, c):
		ward_tracker["absorbed"] = true
	)
	var ward_mine := Vector2i(-1, -1)
	for r in range(gm_ward.grid_size):
		for c in range(gm_ward.grid_size):
			if gm_ward.board_data.cells[r][c].is_mine:
				ward_mine = Vector2i(r, c)
				break
		if ward_mine.x != -1: break
		
	var plays_before_ward := gm_ward.plays_left
	gm_ward.click_tile(ward_mine.x, ward_mine.y)
	if not ward_tracker["absorbed"] or gm_ward.plays_left != plays_before_ward or not gm_ward.scaling_relic_state.get("blast_ward_used", false):
		print("❌ FAIL Blast Ward did not absorb mine explosion! (absorbed=%s, plays=%d, before=%d, used=%s)" % [
			str(ward_tracker["absorbed"]), gm_ward.plays_left, plays_before_ward, str(gm_ward.scaling_relic_state.get("blast_ward_used", false))
		])
		all_ok = false
	else:
		print("  ✅ PASS Blast Ward absorbed mine explosion without losing plays (plays: %d -> %d)" % [plays_before_ward, gm_ward.plays_left])

	# 6. Test Scaling Relic state updates in GameManager
	var gm_scale := GameManager.new()
	gm_scale.start_ante(1, 42)
	gm_scale.owned_relics = ["relic_burning_geode", "relic_sacred_abacus", "relic_keen_eyeglass"]
	
	# Simulate stage dispelled
	var initial_geode: float = gm_scale.scaling_relic_state.get("geode_mult", 0.0)
	var safe_h: Array[Vector2i] = []
	for r in range(gm_scale.grid_size):
		for c in range(gm_scale.grid_size):
			if not gm_scale.board_data.cells[r][c].is_mine:
				safe_h.append(Vector2i(r, c))
				if safe_h.size() >= 3: break
		if safe_h.size() >= 3: break
	gm_scale.play_hand(safe_h)
	
	if gm_scale.scaling_relic_state.get("geode_mult", 0.0) <= initial_geode:
		print("❌ FAIL Burning Geode mult did not scale on stage dispelled!")
		all_ok = false
	else:
		print("  ✅ PASS Burning Geode mult scaled on stage dispelled (+1.5 Mult)")

	return all_ok
