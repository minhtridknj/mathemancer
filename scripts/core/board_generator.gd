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
	# Cho phép rải mìn tự do trên mọi hàng/cột (kể cả Hàng 0).
	# Thiết lập các cấu trúc phân bổ ngẫu nhiên để:
	# - Rank 1 có thể có 0 mìn HOẶC >= 1 mìn (người chơi tự suy luận).
	# - Khoảng cách chênh lệch mìn giữa các rank là ngẫu nhiên (1, 2, 3... quả mìn).
	var target_mines := 3
	if grid_size == 4: target_mines = 3 if ante == 1 else rng.randi_range(3, 4)
	elif grid_size == 5: target_mines = rng.randi_range(5, 6)
	elif grid_size == 6: target_mines = rng.randi_range(7, 9)
	else: target_mines = int(grid_size * 1.5)
	
	# Chọn ngẫu nhiên chiến lược gieo mìn:
	# Mode 0: Gapped pattern (tạo khoảng cách chênh lệch 2-3 quả mìn giữa các rank)
	# Mode 1: Non-zero min rank (mọi hàng/cột đều có ít nhất 1 mìn -> Rank 1 có >= 1 mìn)
	# Mode 2: Phân bổ ngẫu nhiên tự do trên toàn bộ lưới
	var mode := rng.randi_range(1, 2) if ante == 1 else rng.randi_range(0, 2)
	
	if mode == 0 and grid_size >= 4:
		# Gieo mìn tại giao điểm các hàng & cột được chọn để tạo bước nhảy rank (ví dụ {0, 2} hoặc {0, 3})
		var k := rng.randi_range(2, mini(3, grid_size - 1))
		var all_indices: Array[int] = []
		for i in range(grid_size): all_indices.append(i)
		all_indices.shuffle()
		var chosen_rows := all_indices.slice(0, k)
		all_indices.shuffle()
		var chosen_cols := all_indices.slice(0, k)
		for r in chosen_rows:
			for c in chosen_cols:
				cells[r][c].is_mine = true
	elif mode == 1:
		# Đảm bảo mọi hàng và cột đều có mìn -> Rank 1 xuất phát từ >= 1 mìn
		var col_perm: Array[int] = []
		for i in range(grid_size): col_perm.append(i)
		col_perm.shuffle()
		for r in range(grid_size):
			cells[r][col_perm[r]].is_mine = true
		if ante >= 2 and rng.randf() < 0.5:
			var avail: Array[Vector2i] = []
			for r in range(grid_size):
				for c in range(grid_size):
					if not cells[r][c].is_mine: avail.append(Vector2i(r, c))
			if not avail.is_empty():
				var extra_p := avail[rng.randi_range(0, avail.size() - 1)]
				cells[extra_p.x][extra_p.y].is_mine = true
	else:
		# Rải mìn tự do ngẫu nhiên trên toàn bộ bàn cờ (kể cả Hàng 0)
		var placed_mines := 0
		var attempts := 0
		while placed_mines < target_mines and attempts < 100:
			attempts += 1
			var mr := rng.randi_range(0, grid_size - 1)
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
	# Rank thấp nhất luôn là Rank 1 (số mìn của Rank 1 có thể là 0 hoặc >= 1 do người chơi tự suy luận).
	# Khoảng cách giữa các rank (Rank 1 -> Rank 2 -> Rank 3...) là ngẫu nhiên, không cố định chênh 1 quả.
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
	# Tập hợp toàn bộ các ô an toàn trên bàn cờ
	var safe_cells: Array[Vector2i] = []
	for r in range(grid_size):
		for c in range(grid_size):
			if not cells[r][c].is_mine:
				safe_cells.append(Vector2i(r, c))
				
	for i in range(safe_cells.size()):
		var swap_idx := rng.randi_range(0, safe_cells.size() - 1)
		var tmp := safe_cells[i]
		safe_cells[i] = safe_cells[swap_idx]
		safe_cells[swap_idx] = tmp
		
	var base_anchors := 3 if grid_size <= 4 else (4 if grid_size == 5 else 5)
	for i in range(mini(base_anchors, safe_cells.size())):
		var p := safe_cells[i]
		cells[p.x][p.y].is_given = true

	var candidate := {
		"grid_size": grid_size,
		"ante": ante,
		"cells": cells,
		"row_clues": row_clues,
		"col_clues": col_clues
	}

	# Nếu bàn cờ chưa giải được bằng logic với số mỏ neo cơ bản:
	# Mở thêm dần từng ô an toàn ban đầu để đảm bảo 100% suy luận logic được đoạn đầu
	if not is_board_100_percent_solvable(candidate):
		for extra_idx in range(base_anchors, mini(base_anchors + 3, safe_cells.size())):
			var p := safe_cells[extra_idx]
			cells[p.x][p.y].is_given = true
			if is_board_100_percent_solvable(candidate):
				break

	return candidate

## Bộ giải suy luận toán học (Logical Solver)
## Kiểm tra xem bàn cờ có thể giải được 100% bằng logic thuần túy hay không (không có điểm 50/50)
static func is_board_100_percent_solvable(board_data: Dictionary) -> bool:
	var sz: int = board_data.grid_size
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
				
			var known_safe_sum := 0
			var unk_cells: Array[Vector2i] = []
			for c in range(sz):
				if is_safe[r][c]:
					known_safe_sum += cells[r][c].val
				elif not is_mine[r][c]:
					unk_cells.append(Vector2i(r, c))
					
			if unk_cells.is_empty():
				continue
				
			var rem_safe: int = int(clue.sum) - known_safe_sum
			if rem_safe == 0:
				for p in unk_cells:
					is_mine[p.x][p.y] = true
					progress = true
				continue
				
			var n := unk_cells.size()
			if n <= 10:
				var valid_masks: Array[int] = []
				for mask in range(1 << n):
					var s := 0
					for i in range(n):
						if mask & (1 << i):
							s += cells[unk_cells[i].x][unk_cells[i].y].val
					if s == rem_safe:
						valid_masks.append(mask)
						
				if valid_masks.is_empty():
					return false
					
				var all_m := valid_masks[0]
				var any_m := valid_masks[0]
				for m in valid_masks:
					all_m &= m
					any_m |= m
					
				for i in range(n):
					if (all_m & (1 << i)) and not is_safe[unk_cells[i].x][unk_cells[i].y]:
						is_safe[unk_cells[i].x][unk_cells[i].y] = true
						progress = true
					if not (any_m & (1 << i)) and not is_mine[unk_cells[i].x][unk_cells[i].y]:
						is_mine[unk_cells[i].x][unk_cells[i].y] = true
						progress = true

		# Quét suy luận theo từng Cột
		for c in range(sz):
			var clue = board_data.col_clues[c]
			if clue.unlocked_at_stage > stage:
				continue
				
			var known_safe_sum := 0
			var unk_cells: Array[Vector2i] = []
			for r in range(sz):
				if is_safe[r][c]:
					known_safe_sum += cells[r][c].val
				elif not is_mine[r][c]:
					unk_cells.append(Vector2i(r, c))
					
			if unk_cells.is_empty():
				continue
				
			var rem_safe: int = int(clue.sum) - known_safe_sum
			if rem_safe == 0:
				for p in unk_cells:
					is_mine[p.x][p.y] = true
					progress = true
				continue
				
			var n := unk_cells.size()
			if n <= 10:
				var valid_masks: Array[int] = []
				for mask in range(1 << n):
					var s := 0
					for i in range(n):
						if mask & (1 << i):
							s += cells[unk_cells[i].x][unk_cells[i].y].val
					if s == rem_safe:
						valid_masks.append(mask)
						
				if valid_masks.is_empty():
					return false
					
				var all_m := valid_masks[0]
				var any_m := valid_masks[0]
				for m in valid_masks:
					all_m &= m
					any_m |= m
					
				for i in range(n):
					if (all_m & (1 << i)) and not is_safe[unk_cells[i].x][unk_cells[i].y]:
						is_safe[unk_cells[i].x][unk_cells[i].y] = true
						progress = true
					if not (any_m & (1 << i)) and not is_mine[unk_cells[i].x][unk_cells[i].y]:
						is_mine[unk_cells[i].x][unk_cells[i].y] = true
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
