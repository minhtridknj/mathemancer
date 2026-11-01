# Hệ Thống Jokers Mở Rộng & Sử Dụng Bài Tarot (Consumables UI) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Triển khai thêm 11 lá Joker (Relics) mới đa dạng theo phong cách Balatro (Scaling theo thời gian, Hand multipliers, Logic độc quyền Mathemancer) và xây dựng giao diện kho bài Tarot Consumables (2 ô) trên thanh HUD cho phép click chọn bài trên bàn cờ và bấm DÙNG (USE).

**Architecture:** Mở rộng `RelicSystem` với 11 định nghĩa Joker và bộ tính điểm Chips/Mult tương ứng; tích hợp trạng thái tích lũy (scaling state) và khiên chống mìn vào `GameManager`; thiết kế `TarotsBox` trên thanh TopBar của `HUD` kèm `TarotUseModal` hỗ trợ áp dụng phép lên ô đã chọn hoặc kích hoạt tức thì.

**Tech Stack:** Godot 4 (GDScript), Vanilla UI styling (StyleBoxFlat), Event Signals.

**Spec:** [docs/superpowers/specs/2026-11-01-mathemancer-design.md](file:///d:/mstree/mathemancer/docs/superpowers/specs/2026-11-01-mathemancer-design.md) (Mục 5, 7) & thỏa thuận thiết kế trong phiên làm việc 2026-11-01.

## Global Constraints

- Không làm ảnh hưởng đến độ giải được 100% bằng suy luận logic của bàn cờ.
- Roster Joker tối đa 5 slot sở hữu cùng lúc.
- Roster Tarot tối đa 2 slot sở hữu cùng lúc.
- Tất cả bài Tarot dùng xong sẽ bị tiêu biến khỏi túi đồ.
- Tương thích 100% với hệ thống kiểm thử hiện có (`scenes/test_runner.tscn`).

## Review Focus

1. Sử dụng cuộn phép chọn ô (`scroll_suit_transmute`, `scroll_value_boost`) khi người chơi chưa chọn ô nào trên bàn cờ: Phải hiển thị nhắc nhở người chơi chọn 1 ô thay vì bị lỗi crash hoặc mất bài vô ích.
2. Lá `relic_blast_ward` (Khiên Gỡ Mìn) chỉ được kích hoạt tối đa 1 lần trong mỗi Ante; sang Ante tiếp theo phải được hồi phục lại.
3. Các lá Joker tích lũy (Scaling) như `relic_burning_geode`, `relic_sacred_abacus`, `relic_keen_eyeglass` phải bảo toàn giá trị cộng dồn qua các vòng chơi (giữ nguyên khi sang Ante mới).
4. Cửa hàng (`ShopView`) phải tự động bốc ngẫu nhiên từ kho Joker mở rộng (16 lá) và Tarot (4 lá), không chào bán Joker người chơi đã sở hữu.
5. Bài Tarot `scroll_mine_reveal` chỉ tự động gắn cờ vào mìn chưa được cắm cờ; nếu tất cả mìn đã được cắm cờ thì không tiêu hao phí phạm hoặc thông báo hoàn tất.

---

### Task 1: Mở Rộng 11 Lá Joker Mới Trong `RelicSystem`

**Files:**
- Modify: `scripts/core/relic_system.gd`
- Test: `tests/test_items.gd`

**Interfaces:**
- Consumes: `HandEval.evaluate_hand(cards)` output dictionary (`type`, `total_chips`, `mult`).
- Produces: 11 Joker IDs mới trong `RELIC_DEFINITIONS`:
  - `relic_keen_eyeglass`: Thấu Kính Tinh Thông (+3 Mult vĩnh viễn mỗi ván thắng sạch không dẫm mìn).
  - `relic_sacred_abacus`: Bàn Tính Thần Kỳ (+8 Chips vĩnh viễn mỗi lần chơi Blackjack 21 hoặc Straight).
  - `relic_burning_geode`: Hạt Tinh Thể Rực Cháy (+1.5 Mult vĩnh viễn mỗi chặng sương mù xua tan).
  - `relic_astral_duo`: Cặp Song Sinh (×2.0 Mult với One Pair hoặc Two Pair).
  - `relic_celestial_trio`: Tam Hợp Tinh Tú (×2.5 Mult với Three of a Kind hoặc Full House).
  - `relic_elemental_surge`: Dòng Chảy Nguyên Tố (×2.5 Mult với Flush).
  - `relic_sacred_order`: Sảnh Thần Thánh (×3.0 Mult & +30 Chips với Straight / Straight Flush).
  - `relic_odd_astrologer`: Học Giả Số Lẻ (+8 Mult / mỗi lá số 1, 3, 5, 7).
  - `relic_even_magus`: Thần Tài Số Chẵn (+25 Chips / mỗi lá số 2, 4, 6, 8).
  - `relic_fibonacci_sigil`: Cổ Tự Fibonacci (+10 Mult / mỗi lá số 1, 2, 3, 5, 8).
  - `relic_blast_ward`: Khiên Gỡ Mìn (Chặn 1 lần phát nổ mìn mỗi Ante).

- [ ] **Step 1: Viết test mở rộng trong `tests/test_items.gd` cho các Joker mới**
- [ ] **Step 2: Chạy test để xác nhận test ban đầu thất bại với Joker mới chưa có định nghĩa**
- [ ] **Step 3: Triển khai 11 định nghĩa và hàm tính điểm trong `scripts/core/relic_system.gd`**
- [ ] **Step 4: Chạy lại `tests/test_items.gd` và xác nhận PASS 100%**
- [ ] **Step 5: Commit task 1**
  ```bash
  git add scripts/core/relic_system.gd tests/test_items.gd
  git commit -m "feat(relics): add 11 new Balatro-inspired jokers with scaling and hand combos"
  ```

---

### Task 2: Quản Lý Trạng Thái Scaling & Khiên Đỡ Mìn Trong `GameManager`

**Files:**
- Modify: `scripts/core/game_manager.gd`
- Test: `tests/test_game_manager.gd`

**Interfaces:**
- Consumes: Signals `stage_dispelled`, `boss_damaged`, `round_won`, `mine_triggered`.
- Produces:
  - `scaling_relic_state: Dictionary`: `{ "keen_mult": float, "abacus_chips": int, "geode_mult": float, "blast_ward_used": bool }`
  - Signal `ward_absorbed_mine(r: int, c: int)` khi khiên đỡ mìn hoạt động.
  - Cập nhật logic `click_tile` kiểm tra `blast_ward`.
  - Cập nhật `play_hand` truyền `scaling_relic_state` vào `extra_state`.

- [ ] **Step 1: Viết test kiểm tra trạng thái scaling và kích hoạt khiên đỡ mìn trong `tests/test_game_manager.gd`**
- [ ] **Step 2: Chạy test xác nhận fail**
- [ ] **Step 3: Cập nhật `scripts/core/game_manager.gd`**
- [ ] **Step 4: Chạy test xác nhận PASS**
- [ ] **Step 5: Commit task 2**
  ```bash
  git add scripts/core/game_manager.gd tests/test_game_manager.gd
  git commit -m "feat(game_manager): add persistent scaling relic state and blast ward absorption"
  ```

---

### Task 3: Xây Dựng Giao Diện Tarot Slots (Consumables) & Modal Dùng Phép Trong HUD

**Files:**
- Modify: `scenes/main.tscn`
- Modify: `scripts/ui/hud.gd`
- Test: `tests/test_main_scene.gd`

**Interfaces:**
- Consumes: `game_manager.owned_scrolls`, `game_manager.use_scroll()`.
- Produces:
  - Node `TarotsBox` (HBoxContainer) trên `TopBar/Margin/HBox` hiển thị 2 slot cuộn phép.
  - Node `TarotActionModal` hiển thị thông tin cuộn phép và nút bấm **DÙNG (USE)**.
  - Xử lý click lá Tarot:
    - Nếu là `scroll_suit_transmute` hoặc `scroll_value_boost`: Kiểm tra ô đã chọn, áp dụng và cập nhật UI bàn cờ.
    - Nếu là `scroll_restore_play` hoặc `scroll_mine_reveal`: Kích hoạt ngay lập tức.
  - Cập nhật lại UI TarotSlots sau khi dùng.

- [ ] **Step 1: Bổ sung cấu trúc `TarotsBox` và `TarotActionModal` vào `scenes/main.tscn`**
- [ ] **Step 2: Viết logic render Tarot mini-cards và modal tương tác trong `scripts/ui/hud.gd`**
- [ ] **Step 3: Viết test tự động click và sử dụng bài Tarot trong `tests/test_main_scene.gd`**
- [ ] **Step 4: Chạy test runner xác nhận toàn bộ test UI và gameplay pass**
- [ ] **Step 5: Commit task 3**
  ```bash
  git add scenes/main.tscn scripts/ui/hud.gd tests/test_main_scene.gd
  git commit -m "feat(ui): add Tarot consumables tray and interactive use modal in HUD"
  ```

---

### Task 4: Chạy Benchmark, Kiểm Thử Toàn Diện & Push GitHub

**Files:**
- Test: `scenes/test_runner.tscn`

- [ ] **Step 1: Chạy toàn bộ test runner và 20-run auto-play benchmark**
- [ ] **Step 2: Xác nhận 100% unit tests pass và win rate benchmark $\ge 75\%$**
- [ ] **Step 3: Push toàn bộ các commit lên GitHub `origin/main` với token cá nhân**
