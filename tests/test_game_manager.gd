class_name TestGameManager
extends RefCounted

const GameManager = preload("res://scripts/core/game_manager.gd")

static func run_tests() -> bool:
	print("--- Running TestGameManager ---")
	var all_ok := true
	
	var gm := GameManager.new()
	gm.start_ante(1, 42) # fixed seed
	
	# 1. Check Ante 1 initial values
	if gm.boss_hp < 600 or gm.plays_left != 4:
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
		
	return all_ok
