class_name ScrollSystem
extends RefCounted

## Hệ thống Cuộn Giấy Phép (tương đương Tarot Cards trong Balatro)
## Vật phẩm sử dụng một lần để can thiệp vào bàn cờ và lượt chơi

const SCROLL_DEFINITIONS = {
	"scroll_suit_transmute": {
		"name": "Transmutation Scroll",
		"desc": "Transmutes the suit of 1 tile into a chosen suit",
		"cost": 3
	},
	"scroll_mine_reveal": {
		"name": "Revelation Scroll",
		"desc": "Instantly locates and safely flags 1 random mine",
		"cost": 4
	},
	"scroll_restore_play": {
		"name": "Restoration Scroll",
		"desc": "Restores 1 Play Hand",
		"cost": 5
	},
	"scroll_value_boost": {
		"name": "Ascension Scroll",
		"desc": "Permanently increases the value of 1 tile by +2",
		"cost": 3
	}
}

static func use_scroll(scroll_id: String, target_data: Dictionary, game_state: Dictionary) -> bool:
	match scroll_id:
		"scroll_suit_transmute":
			var cell = target_data.get("cell")
			var new_suit: String = target_data.get("new_suit", "flame")
			if cell != null and cell is Dictionary:
				cell["suit"] = new_suit
				return true
				
		"scroll_mine_reveal":
			var cells: Array = game_state.get("cells", [])
			for r in range(cells.size()):
				for c in range(cells[r].size()):
					if cells[r][c].is_mine and not game_state.get("flagged", [])[r][c]:
						game_state["flagged"][r][c] = true
						return true
			return false
			
		"scroll_restore_play":
			var current_plays: int = int(game_state.get("plays_left", 0))
			game_state["plays_left"] = current_plays + 1
			return true
			
		"scroll_value_boost":
			var cell = target_data.get("cell")
			if cell != null and cell is Dictionary:
				cell["val"] = int(cell.get("val", 1)) + 2
				return true
				
	return false
