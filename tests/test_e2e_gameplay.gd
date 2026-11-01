class_name TestE2EGameplay
extends RefCounted

## Kiểm thử Tích Hợp Toàn Diện (End-to-End Gameplay Loop)
## Mô phỏng toàn bộ hành trình của người chơi từ Ante 1 -> Hạ gục Boss -> Mua Cổ vật ở Chợ -> Chuyển sang Ante 2

const GameManagerClass = preload("res://scripts/core/game_manager.gd")
const RelicSys = preload("res://scripts/core/relic_system.gd")
const HandEval = preload("res://scripts/core/hand_evaluator.gd")

static func run_tests() -> bool:
	print("--- Running TestE2EGameplay ---")
	var all_ok := true
	var gm := GameManagerClass.new()
	
	# ==========================================
	# 1. INITIALIZE GOLD AND START ANTE 1
	# ==========================================
	gm.gold = 10
	gm.start_ante(1, 100) # Fixed seed 100 for deterministic testing
	print("  [E2E] Initialized Ante 1 (Boss HP: %d, Grid: %dx%d, Plays: %d)" % [gm.boss_hp, gm.grid_size, gm.grid_size, gm.plays_left])
	
	if gm.boss_hp != 600 or gm.grid_size != 4 or gm.plays_left != 4:
		print("❌ FAIL [E2E] Invalid Ante 1 initial stats")
		return false
	print("  ✅ PASS [E2E] Ante 1 initialized correctly")
	
	# ==========================================
	# 2. SURVEY BOARD AND SAFELY FLAG MINES
	# ==========================================
	var mine_count := 0
	for r in range(gm.grid_size):
		for c in range(gm.grid_size):
			if gm.board_data.cells[r][c].is_mine:
				gm.toggle_flag(r, c)
				mine_count += 1
	print("  [E2E] Flagged all %d mines on the board" % mine_count)
	if gm.correct_flags != mine_count:
		print("❌ FAIL [E2E] Flag count mismatch: %d != %d" % [gm.correct_flags, mine_count])
		return false
	print("  ✅ PASS [E2E] Mines flagged successfully (%d correct flags)" % gm.correct_flags)
	
	# ==========================================
	# 3. REVEAL SAFE TILES AND PLAY HAND COMBOS
	# ==========================================
	var signal_tracker := {"won": false}
	gm.round_won.connect(func():
		signal_tracker["won"] = true
	)
	
	# Reveal all safe tiles
	var safe_pool: Array[Vector2i] = []
	for r in range(gm.grid_size):
		for c in range(gm.grid_size):
			if not gm.board_data.cells[r][c].is_mine and not gm.revealed[r][c]:
				gm.click_tile(r, c)
				safe_pool.append(Vector2i(r, c))
				
	# Play first hand (3 cards)
	var hand1_cards: Array[Vector2i] = safe_pool.slice(0, mini(3, safe_pool.size()))
	var res1 = gm.play_hand(hand1_cards)
	print("  [E2E] Turn 1: Played '%s' for %d dmg (Boss HP left: %d)" % [res1.name, res1.damage, gm.boss_hp])
	
	# Lower boss HP so the next hand naturally defeats the boss
	gm.boss_hp = 5
	var hand2_cards: Array[Vector2i] = safe_pool.slice(3, mini(6, safe_pool.size()))
	var res2 = gm.play_hand(hand2_cards)
	print("  [E2E] Turn 2: Defeated Boss with '%s' for %d dmg (Boss HP: %d)" % [res2.name, res2.damage, gm.boss_hp])
	
	if not signal_tracker["won"] or gm.gold <= 10:
		print("❌ FAIL [E2E] round_won signal not triggered or reward missing: won=%s, gold=%d" % [str(signal_tracker["won"]), gm.gold])
		return false
	print("  ✅ PASS [E2E] Defeated Ante 1 Boss naturally! Current gold: %d" % gm.gold)
	
	# ==========================================
	# 4. SHOP PHASE TRANSACTIONS
	# ==========================================
	var target_relic = "relic_flame_wrath"
	var relic_cost: int = RelicSys.RELIC_DEFINITIONS[target_relic].cost
	var gold_before_shop = gm.gold
	var buy_ok = gm.buy_relic(target_relic)
	if not buy_ok or not gm.owned_relics.has(target_relic) or gm.gold != gold_before_shop - relic_cost:
		print("❌ FAIL [E2E] Relic purchase failed")
		return false
	print("  ✅ PASS [E2E] Successfully purchased Relic '%s' (-%d Gold -> %d Gold)" % [target_relic, relic_cost, gm.gold])
	
	# ==========================================
	# 5. ADVANCE TO ANTE 2 WITH OWNED RELIC
	# ==========================================
	gm.start_ante(2, 200)
	if gm.ante != 2 or gm.boss_hp != 1200 or gm.plays_left != 4 or not gm.owned_relics.has(target_relic):
		print("❌ FAIL [E2E] Ante 2 data inconsistency")
		return false
	print("  ✅ PASS [E2E] Started Ante 2 successfully (Boss HP: 1200, Retained Relics: %s)" % str(gm.owned_relics))
	
	# Verify purchased relic triggers in Ante 2
	var test_flame_card: Array[Dictionary] = [{"val": 4, "suit": "flame"}, {"val": 3, "suit": "flame"}]
	var eval_with_relic = RelicSys.apply_relic_modifiers(HandEval.evaluate_hand(test_flame_card), test_flame_card, gm.owned_relics)
	if not eval_with_relic.triggered_relics.has(target_relic):
		print("❌ FAIL [E2E] Purchased relic did not trigger in Ante 2")
		return false
	print("  ✅ PASS [E2E] Relic '%s' triggered successfully in Ante 2!" % target_relic)
	
	return all_ok
