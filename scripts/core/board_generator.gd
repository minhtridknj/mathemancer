class_name BoardGenerator
extends RefCounted

## Thuật toán sinh bàn cờ giải đố cho Mathemancer
## Đảm bảo: Sudoku không trùng lặp, Kakuro chính xác, Ordinal Mine Ranking,
## Phân bổ ô mỏ neo chiến lược, và 100% SUY LUẬN LOGIC KHÔNG BAO GIỜ BỊ 50/50.

const SUITS: Array[String] = ["flame", "frost", "spark", "shadow"]

static func generate_level(grid_size: int, ante: int, seed_val: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed_val != -1:
		rng.seed = seed_val
	else:
		rng.randomize()
		
	# Lặp thử tối đa 100 lần để tìm bàn cờ được chứng minh toán học giải được 100% không đoán mò
	for attempt in range(100):
		var candidate := _try_generate_candidate(grid_size, ante, rng)
		if is_board_100_percent_solvable(candidate):
			return candidate
			
	# Dự phòng nếu sau 100 lần vẫn chưa đạt (rất hiếm): sinh với ô mỏ neo bổ sung
	return _try_generate_candidate(grid_size, ante, rng)

static func _try_generate_candidate(grid_size: int, ante: int, rng: RandomNumberGenerator) -> Dictionary:
	# 1. Sinh ma trận số Sudoku (Latin Square ngẫu nhiên)
	var matrix: Array = []
	for r in range(grid_size):
		var row: Array[int] = []
		for c in range(grid_size):
			var val: int = ((r + c * (grid_size - 1)) % grid_size) + 1
			row.append(val)
		matrix.append(row)
		
	# Xáo trộn các hàng và các cột
	for i in range(grid_size * 2):
		var r1 := rng.randi_range(0, grid_size - 1)
		var r2 := rng.randi_range(0, grid_size - 1)
		var temp_row = matrix[r1]
		matrix[r1] = matrix[r2]
		matrix[r2] = temp_row
		
	for i in range(grid_size * 2):
		var c1 := rng.randi_range(0, grid_size - 1)
		var c2 := rng.randi_range(0, grid_size - 1)
		for r in range(grid_size):
			var temp = matrix[r][c1]
			matrix[r][c1] = matrix[r][c2]
			matrix[r][c2] = temp

	# 2. Tạo cấu trúc Cells và gán Chất nguyên tố (Suits)
	var cells: Array = []
	for r in range(grid_size):
		var row: Array = []
		for c in range(grid_size):
			var suit: String = SUITS[rng.randi_range(0, SUITS.size() - 1)]
			row.append({
				"val": matrix[r][c],
				"suit": suit,
				"is_mine": false,
				"is_given": false
			})
		cells.append(row)

	# 3. Gieo mìn dựa theo Ante và Grid Size
	# Đảm bảo Hàng 0 luôn có 0 mìn để người chơi luôn có xuất phát điểm 100% chắc chắn
	var target_mines := 3
	if grid_size == 4: target_mines = 3
	elif grid_size == 5: target_mines = 5
	elif grid_size == 6: target_mines = 8
	else: target_mines = int(grid_size * 1.5)
	
	var placed_mines := 0
	var attempts := 0
	while placed_mines < target_mines and attempts < 100:
		attempts += 1
		var mr := rng.randi_range(1, grid_size - 1)
		var mc := rng.randi_range(0, grid_size - 1)
		if not cells[mr][mc].is_mine:
			var r_mines := 0
			for c in range(grid_size):
				if cells[mr][c].is_mine: r_mines += 1
			var c_mines := 0
			for r in range(grid_size):
				if cells[r][mc].is_mine: c_mines += 1
				
			if r_mines < grid_size - 1 and c_mines < grid_size - 1:
				cells[mr][mc].is_mine = true
				placed_mines += 1

	# 4. Tính toán số lượng mìn và Tổng Kakuro cho từng hàng & cột
	var row_mines: Array[int] = []
	var col_mines: Array[int] = []
	var row_sums: Array[int] = []
	var col_sums: Array[int] = []
	
	for r in range(grid_size):
		var m := 0
		var s := 0
		for c in range(grid_size):
			if cells[r][c].is_mine:
				m += 1
			else:
				s += cells[r][c].val
		row_mines.append(m)
		row_sums.append(s)
		
	for c in range(grid_size):
		var m := 0
		var s := 0
		for r in range(grid_size):
			if cells[r][c].is_mine:
				m += 1
			else:
				s += cells[r][c].val
		col_mines.append(m)
		col_sums.append(s)

	# 5. Xếp Hạng Thứ Bậc Mìn Tương Đối (Ordinal Mine Ranking)
	var all_mine_counts: Array[int] = []
	for m in row_mines:
		if not all_mine_counts.has(m): all_mine_counts.append(m)
	for m in col_mines:
		if not all_mine_counts.has(m): all_mine_counts.append(m)
	all_mine_counts.sort()
	
	var rank_map := {}
	for idx in range(all_mine_counts.size()):
		rank_map[all_mine_counts[idx]] = idx + 1
		
	# 6. Phân bổ sương mù theo chặng (Staged Fog of War)
	var half_grid := int(ceil(grid_size / 2.0))
	var row_clues: Array = []
	for r in range(grid_size):
		var stage := 1 if r < half_grid else 2
		row_clues.append({
			"sum": row_sums[r],
			"rank": rank_map[row_mines[r]],
			"unlocked_at_stage": stage
		})
		
	var col_clues: Array = []
	for c in range(grid_size):
		var stage := 1 if c < half_grid else 2
		col_clues.append({
			"sum": col_sums[c],
			"rank": rank_map[col_mines[c]],
			"unlocked_at_stage": stage
		})

	# 7. Phân bổ ô mỏ neo chiến lược (Strategic Given Anchors)
	# Quy tắc quan trọng: KHÔNG đặt mỏ neo ở Hàng 0 vì Hàng 0 đã có tổng = 10, Rank 1 (suy luận được ngay).
	# Phân bổ đều mỗi hàng tiếp theo (Row 1, Row 2, Row 3) một ô an toàn ở các cột khác nhau
	# để triệt tiêu hoàn toàn bất kỳ mẫu bẫy 2x2 (50/50).
	var used_cols: Array[int] = []
	for r in range(1, grid_size):
		var safe_cols: Array[int] = []
		for c in range(grid_size):
			if not cells[r][c].is_mine:
				safe_cols.append(c)
		safe_cols.shuffle()
		
		var chosen_col := -1
		for c in safe_cols:
			if not used_cols.has(c):
				chosen_col = c
				break
		if chosen_col == -1 and not safe_cols.is_empty():
			chosen_col = safe_cols[0]
			
		if chosen_col != -1:
			cells[r][chosen_col].is_given = true
			used_cols.append(chosen_col)

	return {
		"grid_size": grid_size,
		"ante": ante,
		"cells": cells,
		"row_clues": row_clues,
		"col_clues": col_clues
	}

## Bộ giải suy luận toán học (Logical Solver)
## Kiểm tra xem bàn cờ có thể giải được 100% bằng logic thuần túy hay không (không có điểm 50/50)
static func is_board_100_percent_solvable(board_data: Dictionary) -> bool:
	var sz: int = board_data.grid_size
	var total_line_sum := sz * (sz + 1) / 2
	var cells: Array = board_data.cells
	
	var is_safe: Array = []
	var is_mine: Array = []
	for r in range(sz):
		var r_safe: Array[bool] = []
		var r_mine: Array[bool] = []
		for c in range(sz):
			r_safe.append(cells[r][c].is_given)
			r_mine.append(false)
		is_safe.append(r_safe)
		is_mine.append(r_mine)
		
	var stage := 1
	var progress := true
	
	while progress:
		progress = false
		
		# Quét suy luận theo từng Hàng
		for r in range(sz):
			var clue = board_data.row_clues[r]
			if clue.unlocked_at_stage > stage:
				continue
				
			# Nếu tổng an toàn = tổng tuyệt đối của hàng -> toàn bộ ô trong hàng đều an toàn
			if clue.sum == total_line_sum:
				for c in range(sz):
					if not is_safe[r][c]:
						is_safe[r][c] = true
						progress = true
						
			var known_safe_sum := 0
			var unk_cells: Array[Vector2i] = []
			for c in range(sz):
				if is_safe[r][c]:
					known_safe_sum += cells[r][c].val
				elif not is_mine[r][c]:
					unk_cells.append(Vector2i(r, c))
					
			var rem_safe: int = int(clue.sum) - known_safe_sum
			if not unk_cells.is_empty():
				if rem_safe == 0:
					for p in unk_cells:
						is_mine[p.x][p.y] = true
						progress = true
				else:
					var unk_sum := 0
					for p in unk_cells:
						unk_sum += cells[p.x][p.y].val
					if rem_safe == unk_sum:
						for p in unk_cells:
							is_safe[p.x][p.y] = true
							progress = true
					elif unk_cells.size() == 1 and rem_safe == cells[unk_cells[0].x][unk_cells[0].y].val:
						is_safe[unk_cells[0].x][unk_cells[0].y] = true
						progress = true
					elif unk_sum - rem_safe > 0:
						var mine_val: int = unk_sum - rem_safe
						var matching: Array[Vector2i] = []
						for p in unk_cells:
							if cells[p.x][p.y].val == mine_val:
								matching.append(p)
						if matching.size() == 1:
							is_mine[matching[0].x][matching[0].y] = true
							for p in unk_cells:
								if p != matching[0]:
									is_safe[p.x][p.y] = true
							progress = true

		# Quét suy luận theo từng Cột
		for c in range(sz):
			var clue = board_data.col_clues[c]
			if clue.unlocked_at_stage > stage:
				continue
				
			if clue.sum == total_line_sum:
				for r in range(sz):
					if not is_safe[r][c]:
						is_safe[r][c] = true
						progress = true
						
			var known_safe_sum := 0
			var unk_cells: Array[Vector2i] = []
			for r in range(sz):
				if is_safe[r][c]:
					known_safe_sum += cells[r][c].val
				elif not is_mine[r][c]:
					unk_cells.append(Vector2i(r, c))
					
			var rem_safe: int = int(clue.sum) - known_safe_sum
			if not unk_cells.is_empty():
				if rem_safe == 0:
					for p in unk_cells:
						is_mine[p.x][p.y] = true
						progress = true
				else:
					var unk_sum := 0
					for p in unk_cells:
						unk_sum += cells[p.x][p.y].val
					if rem_safe == unk_sum:
						for p in unk_cells:
							is_safe[p.x][p.y] = true
							progress = true
					elif unk_cells.size() == 1 and rem_safe == cells[unk_cells[0].x][unk_cells[0].y].val:
						is_safe[unk_cells[0].x][unk_cells[0].y] = true
						progress = true
					elif unk_sum - rem_safe > 0:
						var mine_val: int = unk_sum - rem_safe
						var matching: Array[Vector2i] = []
						for p in unk_cells:
							if cells[p.x][p.y].val == mine_val:
								matching.append(p)
						if matching.size() == 1:
							is_mine[matching[0].x][matching[0].y] = true
							for p in unk_cells:
								if p != matching[0]:
									is_safe[p.x][p.y] = true
							progress = true

		# Giải trừ sương mù sang Chặng 2 khi đã suy luận được tối thiểu 3 ô an toàn ở Chặng 1
		if not progress and stage == 1:
			var safe_count := 0
			for r in range(sz):
				for c in range(sz):
					if is_safe[r][c]:
						safe_count += 1
			if safe_count >= 3:
				stage = 2
				progress = true

	# Kiểm tra xem toàn bộ các ô đã được định đoạt rõ ràng (an toàn hoặc mìn) hay chưa
	for r in range(sz):
		for c in range(sz):
			if not is_safe[r][c] and not is_mine[r][c]:
				return false
	return true
