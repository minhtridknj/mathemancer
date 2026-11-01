class_name TestTileView
extends RefCounted

const TileView = preload("res://scripts/ui/tile_view.gd")
const TileScene = preload("res://scenes/components/tile.tscn")

static func run_tests() -> bool:
	print("--- Running TestTileView ---")
	var tile: TileView = TileScene.instantiate()
	if not tile:
		print("❌ FAIL cannot instantiate tile.tscn")
		return false
		
	# Test initial hidden setup
	var cell_info := {
		"val": 4,
		"suit": "flame",
		"is_mine": false,
		"is_given": false
	}
	tile.setup(1, 2, cell_info, false, false, false)
	tile._ready()
	tile._update_visuals()
	
	if tile.is_revealed or tile.is_flagged:
		print("❌ FAIL initial tile state should be hidden & unflagged")
		tile.queue_free()
		return false
	print("  ✅ PASS Tile initialized hidden successfully")
	
	# Test flag toggle
	tile.set_flag(true, false)
	if not tile.is_flagged:
		print("❌ FAIL set_flag didn't set is_flagged")
		tile.queue_free()
		return false
	print("  ✅ PASS Tile flagging works")
	
	# Test reveal
	tile.reveal(cell_info, false)
	if not tile.is_revealed:
		print("❌ FAIL reveal didn't set is_revealed")
		tile.queue_free()
		return false
	print("  ✅ PASS Tile reveal works")
	
	# Test selection
	tile.set_selected(true)
	if not tile.is_selected:
		print("❌ FAIL set_selected didn't set is_selected")
		tile.queue_free()
		return false
	print("  ✅ PASS Tile selection works")
	
	# Test exhausted
	tile.set_exhausted(true)
	if not tile.is_exhausted:
		print("❌ FAIL set_exhausted didn't set is_exhausted")
		tile.queue_free()
		return false
	print("  ✅ PASS Tile exhausted state works")
	
	tile.queue_free()
	return true
