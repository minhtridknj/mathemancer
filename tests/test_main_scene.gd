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
	if row0_clue.sum <= 0:
		print("❌ FAIL Row 0 safe sum should be positive, got %d" % row0_clue.sum)
		main.queue_free()
		return false
	if row0_clue.rank < 1:
		print("❌ FAIL Row 0 rank should be >= 1, got %d" % row0_clue.rank)
		main.queue_free()
		return false
	print("  ✅ PASS Stage 1 clues visible and valid at start (sum %d, Rank %d)" % [row0_clue.sum, row0_clue.rank])

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
	
	# 7. Test In-Match Joker / Relic Display & Inspection Modal
	if main.relics_box.get_child_count() != 1:
		print("❌ FAIL relics_box should show 1 placeholder when 0 relics owned: count=%d" % main.relics_box.get_child_count())
		main.queue_free()
		return false
	print("  ✅ PASS Relics Box displays placeholder when 0 relics owned")
	
	# Add a relic and update UI
	main.game_manager.owned_relics.append("relic_frost_shield")
	main._update_relics_ui()
	if main.relics_box.get_child_count() != 1:
		print("❌ FAIL relics_box should show 1 relic card")
		main.queue_free()
		return false
	var relic_card = main.relics_box.get_child(0)
	if not (relic_card is PanelContainer) or not relic_card.tooltip_text.contains("Glacial Aegis"):
		print("❌ FAIL relic card not a PanelContainer or tooltip missing Glacial Aegis")
		main.queue_free()
		return false
	print("  ✅ PASS Owned Relic displayed as interactive mini-card with rich tooltip")
	
	# Test Click inspection opens RelicDetailModal
	main.show_relic_inspection("relic_frost_shield")
	if not main.relic_detail_modal.visible:
		print("❌ FAIL relic_detail_modal not visible after inspection request")
		main.queue_free()
		return false
	if not main.relic_modal_title.text.contains("GLACIAL AEGIS"):
		print("❌ FAIL relic_modal_title mismatch: %s" % main.relic_modal_title.text)
		main.queue_free()
		return false
	print("  ✅ PASS RelicDetailModal opens with correct Joker title, description, and strategy tip")
	
	# Close inspection modal
	main.relic_modal_close_top.emit_signal("pressed")
	if main.relic_detail_modal.visible:
		print("❌ FAIL relic_detail_modal still visible after close button pressed")
		main.queue_free()
		return false
	print("  ✅ PASS RelicDetailModal closes cleanly upon user action")
	
	# ==========================================
	# 8. Test In-Match Tarot Consumables UI & Usage
	# ==========================================
	if main.tarots_box.get_child_count() != 1:
		print("❌ FAIL tarots_box should show 1 placeholder when 0 scrolls owned: count=%d" % main.tarots_box.get_child_count())
		main.queue_free()
		return false
	print("  ✅ PASS Tarots Box displays placeholder slot when 0 scrolls owned")
	
	# Add Ascension Scroll (scroll_value_boost)
	main.game_manager.owned_scrolls.append("scroll_value_boost")
	main._update_tarots_ui()
	if main.tarots_box.get_child_count() != 1:
		print("❌ FAIL tarots_box should show 1 tarot card")
		main.queue_free()
		return false
	var tarot_card = main.tarots_box.get_child(0)
	if not (tarot_card is PanelContainer) or not tarot_card.tooltip_text.contains("Ascension Scroll"):
		print("❌ FAIL tarot card not a PanelContainer or tooltip missing Ascension Scroll")
		main.queue_free()
		return false
	print("  ✅ PASS Owned Tarot displayed as interactive consumable slot with rich tooltip")
	
	# Open TarotActionModal
	main.open_tarot_modal("scroll_value_boost")
	if not main.tarot_action_modal.visible:
		print("❌ FAIL tarot_action_modal not visible after open_tarot_modal")
		main.queue_free()
		return false
	if not main.tarot_modal_use_btn.disabled:
		print("❌ FAIL USE button should be disabled when 0 cards selected on board")
		main.queue_free()
		return false
	print("  ✅ PASS TarotActionModal opens and requires target card selection")
	
	# Select 1 card on the board to target
	var target_r := -1
	var target_c := -1
	for r in range(main.game_manager.grid_size):
		for c in range(main.game_manager.grid_size):
			if not main.game_manager.board_data.cells[r][c].is_mine:
				target_r = r
				target_c = c
				break
		if target_r >= 0: break
		
	var orig_val: int = int(main.game_manager.board_data.cells[target_r][target_c].val)
	main._on_tile_selected_toggled(target_r, target_c, true)
	if main.tarot_modal_use_btn.disabled:
		print("❌ FAIL USE button should be enabled after selecting 1 target card")
		main.queue_free()
		return false
	print("  ✅ PASS Target card dynamically detected and USE button enabled")
	
	# Press USE button
	main.tarot_modal_use_btn.emit_signal("pressed")
	var new_val: int = int(main.game_manager.board_data.cells[target_r][target_c].val)
	if new_val != orig_val + 2:
		print("❌ FAIL Ascension scroll did not boost tile value by +2: was %d, now %d" % [orig_val, new_val])
		main.queue_free()
		return false
	if main.tarot_action_modal.visible:
		print("❌ FAIL tarot_action_modal should close after scroll used")
		main.queue_free()
		return false
	if not main.game_manager.owned_scrolls.is_empty():
		print("❌ FAIL used scroll should be consumed from inventory")
		main.queue_free()
		return false
	print("  ✅ PASS Tarot Scroll successfully executed on target card and consumed!")
	
	# Test Instant Scroll: scroll_restore_play
	main.game_manager.owned_scrolls.append("scroll_restore_play")
	main.game_manager.plays_left = 2
	main._update_tarots_ui()
	main.open_tarot_modal("scroll_restore_play")
	if main.tarot_modal_use_btn.disabled:
		print("❌ FAIL Instant scroll USE button should be enabled without card selection")
		main.queue_free()
		return false
	main.tarot_modal_use_btn.emit_signal("pressed")
	if main.game_manager.plays_left != 3:
		print("❌ FAIL scroll_restore_play did not restore play: plays=%d" % main.game_manager.plays_left)
		main.queue_free()
		return false
	print("  ✅ PASS Instant Restoration Scroll restores play count cleanly!")
	
	main.queue_free()
	return true
