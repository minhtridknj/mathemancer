class_name TestMainScene
extends RefCounted

const MainScene = preload("res://scenes/main.tscn")
const HUD = preload("res://scripts/ui/hud.gd")

static func run_tests(parent_node: Node) -> bool:
	print("--- Running TestMainScene ---")
	var main = MainScene.instantiate()
	if not main:
		print("❌ FAIL cannot instantiate main.tscn")
		return false
		
	parent_node.add_child(main)
	
	# 1. Check initial values
	if not main.game_manager:
		print("❌ FAIL game_manager is null")
		main.queue_free()
		return false
	print("  ✅ PASS GameManager attached and initialized")
	
	if main.tile_nodes.size() != 4 or main.tile_nodes[0].size() != 4:
		print("❌ FAIL tile_nodes 4x4 not populated: rows=%d" % main.tile_nodes.size())
		main.queue_free()
		return false
	print("  ✅ PASS 4x4 Grid UI correctly populated with TileView instances")
	
	# 2. Check Boss initial HP
	if main.boss_hp_bar.value != 200:
		print("❌ FAIL boss hp bar not 200: %f" % main.boss_hp_bar.value)
		main.queue_free()
		return false
	print("  ✅ PASS Boss HP Bar matches 200 HP")
	
	# 3. Check 5 card slots in hand tray
	if main.tray_container.get_child_count() != 5:
		print("❌ FAIL tray_container must contain 5 card slots: count=%d" % main.tray_container.get_child_count())
		main.queue_free()
		return false
	print("  ✅ PASS Hand tray contains 5 dedicated card slots")

	# Check Stage 1 clues are visible and not locked by fog
	var row0_clue: Dictionary = main.game_manager.board_data.row_clues[0]
	if row0_clue.unlocked_at_stage > main.game_manager.current_stage:
		print("❌ FAIL Row 0 clue is fogged at start!")
		main.queue_free()
		return false
	if row0_clue.sum != 10:
		print("❌ FAIL Row 0 safe sum should be 10 for deterministic start, got %d" % row0_clue.sum)
		main.queue_free()
		return false
	print("  ✅ PASS Stage 1 clues visible with guaranteed safe Row 0 (sum 10, Rank 1)")

	# 4. Simulate selecting an open tile and checking hand preview
	var opened_pos: Vector2i = Vector2i(-1, -1)
	for r in range(4):
		for c in range(4):
			if not main.game_manager.board_data.cells[r][c].is_mine:
				main.game_manager.click_tile(r, c)
				opened_pos = Vector2i(r, c)
				break
		if opened_pos.x != -1: break
		
	main._on_tile_selected_toggled(opened_pos.x, opened_pos.y, true)
	if main.selected_coords.size() != 1:
		print("❌ FAIL selected_coords not updated")
		main.queue_free()
		return false
	print("  ✅ PASS Tile selection toggled and hand tray updated")
	
	# Test returning card from tray back to board
	main._return_card_from_tray(opened_pos)
	if main.selected_coords.size() != 0:
		print("❌ FAIL return card did not remove from selected_coords")
		main.queue_free()
		return false
	if main.tile_nodes[opened_pos.x][opened_pos.y].is_selected:
		print("❌ FAIL return card did not unselect tile on board")
		main.queue_free()
		return false
	print("  ✅ PASS Return card from tray deselects tile and returns it to board")
	
	# Select tile again for playing hand
	main._on_tile_selected_toggled(opened_pos.x, opened_pos.y, true)
	
	# 5. Check play button enabled
	if main.play_button.disabled:
		print("❌ FAIL play_button should be enabled with 1 tile")
		main.queue_free()
		return false
	print("  ✅ PASS Play Hand button enabled when tiles selected")
	
	# 5. Play hand
	var hp_before: int = main.game_manager.boss_hp
	main._on_play_button_pressed()
	if main.game_manager.boss_hp >= hp_before:
		print("❌ FAIL play button didn't deal damage: %d >= %d" % [main.game_manager.boss_hp, hp_before])
		main.queue_free()
		return false
	print("  ✅ PASS Play Hand dealt damage from HUD (Boss HP: %d -> %d)" % [hp_before, main.game_manager.boss_hp])
	
	# 6. Test Shop opening
	main._open_shop()
	if not main.shop_modal.visible:
		print("❌ FAIL shop_modal not visible after _open_shop")
		main.queue_free()
		return false
	print("  ✅ PASS Shop modal opens successfully")
	
	main.queue_free()
	return true
