# Mathemancer (Chiêm Tinh Số) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng tựa game Roguelike Puzzle Battler độc lập hoàn chỉnh "Mathemancer" trên Godot 4.7, kết hợp cơ chế mở ô của Minesweeper, tính chất Sudoku, manh mối Kakuro với luật xếp hạng mìn tương đối, hệ thống gom tổ hợp bài Balatro (Chất + Hand), trừ lượt khi dẫm mìn, sương mù mở rộng theo chặng và Cửa hàng Cổ Vật / Cuộn Giấy Phép.

**Architecture:** Kiến trúc dạng Model-View tách biệt hoàn toàn: tầng logic toán học (`BoardGenerator`, `HandEvaluator`, `RelicSystem`, `ScrollSystem`) là các RefCounted class thuần GDScript chạy test độc lập không phụ thuộc scene; tầng điều phối `GameManager` quản lý trạng thái trận đánh, sương mù và sinh mệnh; tầng giao diện (`HUD`, `TileView`, `ShopView`) điều khiển animation lật ô 3D, hiệu ứng nổ bom rung màn hình, âm thanh Web Audio / SFX, và luồng tính điểm `Chips × Mult`.

**Tech Stack:** Godot 4.7 (GDScript), Kenney CC0 Assets (audio/fonts), headless CLI test runner.

**Spec:** [`docs/superpowers/specs/2026-11-01-mathemancer-design.md`](file:///d:/mstree/docs/superpowers/specs/2026-11-01-mathemancer-design.md)

## Global Constraints

- **Engine Floor:** Godot 4.7.x (`d:/mstree/godot/Godot_v4.7.2-stable_mono_win64/`).
- **Project Isolation:** Toàn bộ mã nguồn, scenes, và assets riêng nằm trong thư mục độc lập `d:/mstree/mathemancer/`.
- **Logic Determinism:** Bàn cờ sinh ra bắt buộc 100% giải được bằng suy luận logic dựa trên ô mỏ neo ban đầu và trọng số mìn (không để xảy ra đoán mò 50/50).
- **Naming Conventions:** ClassNames viết PascalCase, methods/variables viết snake_case, hằng số viết UPPER_SNAKE_CASE.

## Review Focus

- Bàn cờ sinh ra có bị tình trạng "bế tắc suy luận" (deadlock) buộc người chơi phải click hú họa không?
- Khi dẫm mìn, hệ thống có trừ chính xác 1 lượt Play Hand và khóa ô mìn đó mà không làm crash game?
- Thẩm định tổ hợp Hand (Blackjack 21, Straight Flush, Flush, Straight, Full House,...) có tính toán chính xác Chips và Mult theo thứ tự ưu tiên?
- Các con số sau khi ấn Play Hand có chuyển sang trạng thái "Đã tiêu hao" (Exhausted) và sương mù chặng tiếp theo có giải trừ mượt mà?
- Cửa hàng (Shop) có cập nhật đúng tiền vàng, slot Cổ Vật (tối đa 5) và hiệu ứng của Cuộn Giấy Phép?

---

### Task 1: Thiết Lập Dự Án Godot Độc Lập `mathemancer` & Tài Nguyên

**Files:**
- Create: `mathemancer/project.godot`
- Create: `mathemancer/icon.svg`
- Create: `mathemancer/scenes/test_runner.tscn`
- Create: `mathemancer/scripts/test_runner.gd`
- Assets Copy: Sao chép các font (`LilitaOne-Regular.ttf`, `PressStart2P-Regular.ttf`) và audio SFX từ `d:/mstree/assets/` vào `mathemancer/assets/`

**Interfaces:**
- Produces: Môi trường Godot độc lập sẵn sàng chạy `Godot_console.exe --headless --path d:/mstree/mathemancer scenes/test_runner.tscn` thành công.

- [ ] **Step 1: Khởi tạo cấu trúc thư mục và `mathemancer/project.godot`**
  Cấu hình application name "Mathemancer (Chiêm Tinh Số)", viewport 1280x720 canvas_items, copy icon và font/audio cơ bản.

- [ ] **Step 2: Tạo test runner khung ban đầu `scripts/test_runner.gd`**
  Viết script test runner in ra kết quả kiểm thử và tự động `get_tree().quit(0)` khi hoàn tất.

- [ ] **Step 3: Chạy test runner bằng Godot Headless để kiểm tra**
  Run: `d:\mstree\godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe --headless --path d:\mstree\mathemancer scenes/test_runner.tscn`
  Expected: In ra test ban đầu và exit code 0.

---

### Task 2: Bộ Thẩm Định Tổ Hợp Bài & Tính Điểm (Hand Evaluator)

**Files:**
- Create: `mathemancer/scripts/core/hand_evaluator.gd`
- Create: `mathemancer/tests/test_hand_evaluator.gd`
- Modify: `mathemancer/scripts/test_runner.gd`

**Interfaces:**
- Produces: `class_name HandEvaluator`
  - `static func evaluate_hand(cards: Array[Dictionary]) -> Dictionary`
    - Nhận: Danh sách từ 1 đến 5 lá bài `{ "val": int, "suit": String }`
    - Trả về: `{ "type": String, "name": String, "chips": int, "mult": float, "desc": String }`

- [ ] **Step 1: Viết bài test thất bại (Failing Test) trong `tests/test_hand_evaluator.gd`**
  Test các trường hợp:
  - Straight Flush: `[2🔥, 3🔥, 4🔥, 5🔥, 6🔥]` ➔ Thưởng +80 Chips, ×8 Mult.
  - Blackjack 21: `[9🔥, 7❄️, 5⚡]` (Tổng = 21) ➔ Thưởng +50 Chips, ×6 Mult.
  - Flush: `[1🔥, 3🔥, 5🔥, 8🔥]` ➔ Thưởng +35 Chips, ×4 Mult.
  - Straight: `[2🔥, 3❄️, 4⚡, 5🌑]` ➔ Thưởng +30 Chips, ×3.5 Mult.
  - Full House, 3 of a Kind, Two Pair, One Pair, High Sum.

- [ ] **Step 2: Chạy test để xác nhận test FAIL (Class chưa tồn tại)**
  Run: Godot headless test runner
  Expected: FAIL with "HandEvaluator not found"

- [ ] **Step 3: Cài đặt logic `HandEvaluator` trong `scripts/core/hand_evaluator.gd`**
  Cài đặt các hàm kiểm tra thứ tự ưu tiên: `is_straight_flush`, `is_blackjack_21`, `is_flush`, `is_straight`, `is_full_house`, `is_three_of_a_kind`, `is_two_pair`, `is_pair`.

- [ ] **Step 4: Chạy test để xác nhận PASS toàn bộ**
  Run: Godot headless test runner
  Expected: PASS toàn bộ 9 bộ test tổ hợp bài.

---

### Task 3: Thuật Toán Sinh Bàn Cờ & Suy Luận (Board Generator Engine)

**Files:**
- Create: `mathemancer/scripts/core/board_generator.gd`
- Create: `mathemancer/tests/test_board_generator.gd`
- Modify: `mathemancer/scripts/test_runner.gd`

**Interfaces:**
- Produces: `class_name BoardGenerator`
  - `static func generate_level(grid_size: int, ante: int, seed_val: int = -1) -> Dictionary`
    - Trả về: `{ "grid_size": int, "cells": Array, "row_clues": Array, "col_clues": Array, "stages": Array }`
    - `cells[r][c]`: `{ "val": int, "suit": String, "is_mine": bool, "is_given": bool }`
    - `clues`: `{ "sum": int, "mine_rank": int, "unlocked_at_stage": int }`

- [ ] **Step 1: Viết test thất bại `tests/test_board_generator.gd`**
  - Kiểm tra tính hợp lệ của lưới 4×4 đến 8×8 (không trùng số an toàn trên hàng/cột - Sudoku).
  - Kiểm tra tính toán Tổng Kakuro chính xác bằng tổng các số an toàn.
  - Kiểm tra quy luật Xếp Hạng Mìn Tương Đối (Rank 1 là nhóm ít mìn nhất, chỉ cùng số mìn mới cùng rank).
  - Kiểm tra có ít nhất 2–3 ô mỏ neo ban đầu (`is_given = true`).
  - Kiểm tra phân chia Sương mù theo chặng (`unlocked_at_stage`: Chặng 1 mở 50% manh mối, Chặng 2 mở 50% còn lại).

- [ ] **Step 2: Chạy test để xác nhận FAIL**
  Run: Godot headless test runner
  Expected: FAIL

- [ ] **Step 3: Cài đặt `BoardGenerator` trong `scripts/core/board_generator.gd`**
  - Thuật toán tạo ma trận số ngẫu nhiên thỏa mãn Sudoku 1..N.
  - Thuật toán gieo mìn dựa theo Ante (từ 2 đến N*N/4 mìn).
  - Thuật toán gom và tính thứ hạng mìn (Ordinal Mine Ranking).
  - Thuật toán gán ngẫu nhiên 4 Chất: Hỏa 🔥, Băng ❄️, Lôi ⚡, Ám 🌑.
  - Phân vùng sương mù (Fog of war stages).

- [ ] **Step 4: Chạy test để xác nhận PASS**
  Run: Godot headless test runner
  Expected: PASS 100% các tiêu chí bàn cờ.

---

### Task 4: Hệ Thống Cổ Vật (Jokers) & Cuộn Giấy Phép (Tarots)

**Files:**
- Create: `mathemancer/scripts/core/relic_system.gd`
- Create: `mathemancer/scripts/core/scroll_system.gd`
- Create: `mathemancer/tests/test_items.gd`
- Modify: `mathemancer/scripts/test_runner.gd`

**Interfaces:**
- Produces: `class_name RelicSystem`
  - `apply_relic_modifiers(hand_data: Dictionary, current_relics: Array) -> Dictionary`
- Produces: `class_name ScrollSystem`
  - `use_scroll(scroll_id: String, target_data: Dictionary, game_state: Dictionary) -> bool`

- [ ] **Step 1: Viết test cho Relic & Scroll trong `tests/test_items.gd`**
  - Test Relic "Thánh Tích Blackjack" nhân thêm ×3 Mult khi Hand là Blackjack.
  - Test Relic "Kính Lúp Rà Mìn" cộng +20 Chips vĩnh viễn khi cắm cờ đúng.
  - Test Relic "Ngọn Lửa Hủy Diệt" cộng +12 Mult cho mỗi lá chất Hỏa.
  - Test Scroll "Cuộn Biến Chất" đổi 2 ô thành cùng chất mong muốn.
  - Test Scroll "Cuộn Hồi Thiên" hồi lại 1 lượt Play Hand.

- [ ] **Step 2: Cài đặt `RelicSystem` và `ScrollSystem`**
  Xây dựng kho từ điển chứa dữ liệu của 15 Cổ Vật và 8 Cuộn Giấy Phép.

- [ ] **Step 3: Chạy test và xác nhận PASS**
  Run: Godot headless test runner
  Expected: PASS

---

### Task 5: Bộ Điều Phối Trận Đấu & Vòng Lặp Lượt Chơi (Game Manager)

**Files:**
- Create: `mathemancer/scripts/core/game_manager.gd`
- Create: `mathemancer/tests/test_game_manager.gd`
- Modify: `mathemancer/scripts/test_runner.gd`

**Interfaces:**
- Produces: `class_name GameManager extends Node`
  - Quản lý `boss_hp`, `max_boss_hp`, `plays_left`, `gold`, `current_stage`.
  - Signal: `mine_exploded(pos)`, `play_hand_resolved(dmg, hand_type)`, `fog_dissolved(new_clues)`, `game_won`, `game_over`.
  - `func click_tile(r: int, c: int) -> void` (Nếu mìn ➔ `plays_left -= 1`)
  - `func play_selected_hand(selected_coords: Array) -> Dictionary` (Gây sát thương, tiêu hao ô, mở sương mù chặng tiếp theo).

- [ ] **Step 1: Viết test vòng lặp trận đấu `tests/test_game_manager.gd`**
  - Test khởi tạo Ante 1 (Boss HP 700, Plays = 4).
  - Test click mìn trừ 1 Play Hand.
  - Test hết Play Hand mà Boss > 0 HP ➔ Game Over.
  - Test Play Hand gây sát thương tụt máu Boss, chuyển các ô sang trạng thái "Đã tiêu hao", và giải trừ sương mù chặng tiếp theo.
  - Test Boss HP <= 0 ➔ Chiến thắng màn, thưởng Vàng.

- [ ] **Step 2: Cài đặt `GameManager` trong `scripts/core/game_manager.gd`**

- [ ] **Step 3: Chạy test và xác nhận PASS**
  Run: Godot headless test runner
  Expected: PASS

---

### Task 6: Thành Phần Ô Cờ Giao Diện & Animation Game Feel (Tile View)

**Files:**
- Create: `mathemancer/scenes/components/tile.tscn`
- Create: `mathemancer/scripts/ui/tile_view.gd`

**Interfaces:**
- Produces: Node đại diện cho từng ô trên bàn cờ:
  - Animation lật 3D (xoay trục Y và đổi sprite số/màu chất).
  - Animation cắm cờ `🚩` (cắm nảy xuống kèm âm thanh).
  - Animation nổ mìn `💥` (chớp đỏ, hạt vỡ vụn, kích hoạt Screen Shake).
  - Animation ô đã tiêu hao (mờ đi 40% opacity, viền xám).

- [ ] **Step 1: Dựng scene `tile.tscn` với Control, TextureRect, Label, GPUParticles2D, AnimationPlayer**
- [ ] **Step 2: Viết script `tile_view.gd` xử lý tín hiệu click trái/phải, nạp dữ liệu Chất và hiệu ứng lật mở**
- [ ] **Step 3: Thử nghiệm độc lập scene `tile.tscn` đảm bảo tương tác và animation mượt mà**

---

### Task 7: Giao Diện Trận Đấu, Khay Bài & Hiệu Ứng Bắn Boss (Main Combat Scene)

**Files:**
- Create: `mathemancer/scenes/main.tscn`
- Create: `mathemancer/scripts/ui/hud.gd`
- Create: `mathemancer/scripts/ui/screen_shake.gd`

**Interfaces:**
- Produces: Màn hình trận đấu hoàn chỉnh:
  - Khung lề hiển thị Kakuro Sum & Nhãn Mìn Rank (Rank 1, Rank 2...).
  - Lớp phủ Sương mù (`FogOfWar`) che các manh mối bị khóa, tự tan biến khi Play Hand.
  - Khay Bài (Hand Tray) ở dưới chứa tối đa 5 lá bài đang chọn, hiển thị combo nhận diện (Sảnh, Blackjack 21, Thùng...).
  - Thanh đếm Play Hands (3-4 huy hiệu lấp lánh).
  - Thanh Máu Boss với thanh ma (Ghost HP Bar) và nhấp nháy đỏ khi nhận sát thương.
  - Nút **PLAY HAND** với hiệu ứng bốc cháy khi combo có sát thương cao.
  - Chuỗi âm thanh hợp âm arpeggio và chùm tia bắn thẳng vào Boss.

- [ ] **Step 1: Thiết kế layout `main.tscn` với GridContainer, Clues Container, Hand Tray và Boss Panel**
- [ ] **Step 2: Kết nối script `hud.gd` với `GameManager` để cập nhật dữ liệu thời gian thực**
- [ ] **Step 3: Cài đặt logic kéo/nhặt số vào Khay Bài và hiệu ứng âm thanh tổng hợp / SFX**
- [ ] **Step 4: Cài đặt hiệu ứng Screen Shake khi nổ mìn và chuỗi sát thương khi bấm Play Hand**

---

### Task 8: Hệ Thống Cửa Hàng (Shop View) & Tiến Trình Màn Chơi (Ante Progression)

**Files:**
- Create: `mathemancer/scenes/components/shop.tscn`
- Create: `mathemancer/scripts/ui/shop_view.gd`
- Modify: `mathemancer/scripts/ui/hud.gd`

**Interfaces:**
- Produces: Màn hình Cửa Hàng giữa các vòng đấu:
  - Hiển thị số Vàng tích lũy của người chơi.
  - 3 Thẻ Cổ Vật (Jokers) ngẫu nhiên để mua (tối đa 5 slot trang bị).
  - 2 Cuộn Giấy Phép (Tarots) ngẫu nhiên để mua.
  - Nút "Vào Vòng Tiếp Theo" (Next Ante): Nâng kích thước bàn cờ lên 5×5, 6×6..., tăng số Rank mìn và tăng máu Boss.

- [ ] **Step 1: Dựng scene `shop.tscn` với giao diện thẻ bài phong cách Balatro**
- [ ] **Step 2: Viết script `shop_view.gd` xử lý mua bán Cổ Vật, kiểm tra đủ tiền và kích hoạt hiệu ứng**
- [ ] **Step 3: Tích hợp chuyển cảnh mượt mà giữa Trận Đấu ➔ Cửa Hàng ➔ Trận Đấu Màn Mới**

---

### Task 9: Bộ Test Tự Động Tổng Hợp (End-to-End Test Suite) & Cấu Hình VS Code

**Files:**
- Modify: `mathemancer/scripts/test_runner.gd`
- Modify: `mathemancer/project.godot` (Đặt `run/main_scene="res://scenes/main.tscn"`)
- Modify: `.vscode/launch.json` (Thêm cấu hình F5 để chơi ngay Mathemancer)

**Interfaces:**
- Produces:
  - 100% test tự động pass kiểm tra logic bàn cờ, thẩm định hand bài, trừ lượt khi dẫm mìn, và chuyển cảnh shop.
  - Nhấn `F5` trong VS Code sẽ lập tức khởi chạy game Mathemancer.

- [ ] **Step 1: Viết test tích hợp toàn diện (E2E Integration Test) mô phỏng 1 ván chơi hoàn chỉnh từ đầu đến diệt Boss**
- [ ] **Step 2: Chạy bộ test tự động qua Godot Headless và xác nhận toàn bộ 25+ test case PASS**
  Run: `d:\mstree\godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe --headless --path d:\mstree\mathemancer scenes/test_runner.tscn`
  Expected: PASS 100% không cảnh báo hay lỗi.
- [ ] **Step 3: Cập nhật `.vscode/launch.json` để bổ sung configuration chạy "Play Mathemancer"**
