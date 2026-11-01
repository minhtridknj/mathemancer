# Bản Đặc Tả Thiết Kế Game: Mathemancer (Chiêm Tinh Số)
*Tài liệu đặc tả thiết kế hệ thống, cơ chế giải đố, vòng lặp chiến thuật và hiệu ứng game*

---

## 1. TỔNG QUAN DỰ ÁN (PROJECT OVERVIEW)

* **Tên dự án**: **Mathemancer (Chiêm Tinh Số)**
* **Thể loại**: Roguelike Puzzle Battler (Kết hợp Minesweeper, Sudoku, Kakuro và Balatro).
* **Cảm xúc chủ đạo**: *"Cảm giác kịch tính giữa thời gian, sự tính toán và độ khó"* — người chơi trải nghiệm sự căng thẳng nghẹt thở của việc suy luận toán học thuần túy, kết hợp với sự phấn khích tột độ khi gom được những Hand bài chất lượng cao nổ sát thương khổng lồ tiêu diệt Boss.
* **Nền tảng mục tiêu**: PC / Web (Godot 4 Engine).

---

## 2. MỤC TIÊU & GIỚI HẠN (GOALS, NON-GOALS & ANTI-GOALS)

### 2.1. Mục Tiêu (Goals)
1. **Suy luận logic 100% không đoán mò**: Bàn cờ luôn có thể giải được hoàn toàn bằng các phép tính toán và suy luận logic (nhờ ô mỏ neo ban đầu và quy luật trọng số mìn).
2. **Vòng lặp Play Hand có ý nghĩa sống còn**: Ngăn chặn tình trạng giải sạch bàn cờ rồi mới bắn một lần; bắt buộc phải Play Hand để xua sương mù và mở khóa manh mối chặng tiếp theo.
3. **Cân bằng giữa Tư Duy Toán Học & Yếu Tố May Rủi Cờ Bạc**: Các con số có "Chất" (Suits) mang tính ngẫu nhiên, cho phép người chơi tạo các siêu phẩm bài (Thùng, Thùng Phá Sảnh, Blackjack 21) để lật ngược thế cờ khi gặp khó khăn.
4. **Game Feel đỉnh cao**: Âm thanh tổng hợp biến tấu theo nốt nhạc, hiệu ứng nổ bom rung màn hình, chuỗi tính điểm nảy số `Chips × Mult` mãn nhãn kiểu Balatro.

### 2.2. Giới Hạn & Điều Không Làm (Non-Goals & Anti-Goals)
* **Non-Goal**: Không làm game chặt chém thời gian thực đòi hỏi phản xạ tay bấm; đây là game chiến thuật giải đố theo lượt với áp lực đếm số lượt và đếm nhịp.
* **Anti-Goal**: Tuyệt đối không để xảy ra tình trạng "bế tắc bắt buộc phải click hú họa" (Minesweeper 50/50 problem). Bất kỳ nước đi sai nào cũng phải là do lỗi tính toán của người chơi, không phải do game ép đoán mò.

---

## 3. CƠ CHẾ BÀN CỜ & SUY LUẬN LOGIC (THE GRID & DEDUCTION)

### 3.1. Cấu Trúc Bàn Cờ
* Bàn cờ là một lưới ô vuông úp, kích thước mở rộng dần theo độ khó: **4×4 (Màn 1) ➔ 5×5 (Màn 2) ➔ 6×6 (Màn 3) ➔ 7×7 (Màn 4) ➔ 8×8 (Màn 5)**.
* Mỗi ô trên bàn cờ có thể là:
  1. **Ô Số An Toàn**: Chứa một chữ số nguyên dương (từ 1 đến kích thước lưới hoặc 1–9) và ngẫu nhiên mang 1 trong 4 **Chất** (Suits).
  2. **Ô Mìn (Bomb / Corrupted Sigil)**: Ẩn giấu dưới lớp mặt nạ.

### 3.2. Ba Trụ Cột Giải Đố
1. **Manh Mối Kakuro (Row / Col Sums)**:
   * Ở đầu mỗi hàng và cột có một con số mục tiêu — đó là **Tổng giá trị các ô an toàn** của hàng/cột đó (các ô mìn không có giá trị số).
2. **Quy Tắc Sudoku (Unique Digits)**:
   * Trong cùng một hàng hoặc cùng một cột, **các ô số an toàn không được phép trùng lặp giá trị**.
3. **Luật Trọng Số Thứ Hạng Mìn (Ordinal Mine Ranking)**:
   * Không hiển thị số lượng mìn cụ thể.
   * Tất cả các hàng và cột trên bàn cờ được gom chung và xếp hạng theo số lượng mìn từ thấp đến cao bắt đầu từ **Rank 1**:
     * **Rank 1**: Nhóm hàng/cột có số mìn ít nhất trên bàn cờ đó (người chơi không biết trước là 0 hay 1 hay 2 mìn).
     * **Rank 2**: Chắc chắn có nhiều mìn hơn Rank 1.
     * **Rank 3**: Chắc chắn có nhiều mìn hơn Rank 2.
     * Hai hàng/cột chỉ cùng Rank khi và chỉ khi có số lượng mìn hoàn toàn bằng nhau.
4. **Ô Mỏ Neo Khởi Đầu (Given Numbers)**:
   * Mỗi ván luôn lật sẵn 2–3 ô số an toàn ngay từ đầu làm điểm tựa tính toán.

### 3.3. Cơ Chế Sương Mù Mở Rộng Theo Chặng (Staged Fog of War)
* Bàn cờ không lộ toàn bộ manh mối Kakuro ngay lập tức.
* **Chặng 1**: Chỉ một nửa số hàng/cột có manh mối Kakuro và Rank mìn (đủ để người chơi suy luận ra 3–5 ô an toàn đầu tiên). Nửa còn lại bị sương mù che phủ (`???`).
* Khi giải hết dữ liệu của Chặng 1, người chơi sẽ "bí" vì thiếu thông tin.
* **Kích hoạt Chặng tiếp theo**: Người chơi bắt buộc phải gom các số đang có và bấm **PLAY HAND**. Cú bắn vừa gây sát thương lên Boss, vừa giải trừ sương mù để hiện ra manh mối của Chặng tiếp theo!

---

## 4. HỆ THỐNG LƯỢT CHƠI & HÌNH PHẠT MÌN (TURN FLOW & STAKES)

* **Số Lượt Play Hands Khởi Đầu**: Mỗi màn chơi, người chơi chỉ có **3 đến 4 lượt Play Hands** để hạ gục Boss.
* **Hình Phạt Khi Dẫm Mìn**:
  * Khi click mở nhầm ô Mìn: **Mìn phát nổ `💥` và người chơi bị TRỪ THẲNG 1 LƯỢT PLAY HANDS!**
  * Ô mìn đó bị vỡ vụn và khóa vĩnh viễn trong ván đó.
  * Mất 1 lượt Play Hand đồng nghĩa với việc bạn mất đi 25%–33% tổng cơ hội gây sát thương trong màn!

---

## 5. HỆ THỐNG CHẤT BÀI & CÁC TỔ HỢP HAND (SUITS & SCORING)

### 5.1. Bốn Chất Bài (Suits)
Mỗi con số an toàn khi mở ra sẽ ngẫu nhiên mang 1 trong 4 Nguyên Tố / Chất Cổ Ngữ:
* 🔥 **Hỏa Tự (Flame)** — Màu Đỏ Rực
* ❄️ **Băng Tự (Frost)** — Màu Xanh Băng
* ⚡ **Lôi Tự (Spark)** — Màu Vàng Điện
* 🌑 **Ám Tự (Shadow)** — Màu Tím Huyền Bí

### 5.2. Khay Bài (Hand Rack)
* Người chơi tự do click vào các con số đã lật trên bàn cờ để đưa vào Khay Bài (chọn tối đa **5 số**).
* Có thể click bỏ chọn bất kỳ lúc nào để đổi số khác trước khi ấn bắn.

### 5.3. Bảng Xếp Hạng Tổ Hợp Hand (Hand Hierarchy)

| Tổ Hợp Hand | Điều Kiện | Thưởng Chips | Hệ Số Base Mult |
| :--- | :--- | :---: | :---: |
| 👑 **Thùng Phá Sảnh (Straight Flush)** | 5 số liên tiếp VÀ cùng 1 Chất | **+80 Chips** | **×8.0 Mult** |
| 💎 **Blackjack 21 Vàng** | Tổng chính xác các số trong Hand = 21 | **+50 Chips** | **×6.0 Mult** |
| 🌊 **Thùng (Flush)** | 4 hoặc 5 số cùng 1 Chất | **+35 Chips** | **×4.0 Mult** |
| ⚡ **Sảnh (Straight)** | 3 đến 5 số liên tiếp nhau (vd: 2-3-4-5) | **+30 Chips** | **×3.5 Mult** |
| 🏰 **Cù Lũ (Full House)** | 1 Bộ Ba + 1 Cặp Đôi | **+40 Chips** | **×4.0 Mult** |
| 🔷 **Bộ Ba (Three of a Kind)** | 3 số có cùng giá trị | **+25 Chips** | **×3.0 Mult** |
| 🧩 **Hai Đôi (Two Pair)** | 2 cặp số trùng giá trị | **+20 Chips** | **×2.5 Mult** |
| ✨ **Một Đôi (One Pair)** | 2 số trùng giá trị | **+10 Chips** | **×1.5 Mult** |
| 📜 **Tổng Điểm Thường (High Sum)** | Các con số lẻ không tạo thành combo | **+0 Chips** | **×1.0 Mult** |

* **Công thức Sát Thương Cuối Cùng**:
  $$\text{Tổng Sát Thương} = (\sum \text{Giá trị các số} + \text{Chips thưởng}) \times (\text{Base Mult} + \text{Cổ Vật Mult})$$

---

## 6. TIẾN TRÌNH ĐỘ KHÓ & MÁU BOSS TỪNG VÒNG (BOSS HP & PROGRESSION)

Người chơi trải qua 5 Tầng thử thách (Mỗi tầng gồm 2 Màn Thường + 1 Màn Boss đặc biệt):

| Tầng (Ante) | Kích Thước Bàn Cờ | Số Rank Mìn | Số Chặng Sương Mù | Máu Boss Mục Tiêu | Đặc Điểm Thử Thách |
| :---: | :---: | :---: | :---: | :---: | :--- |
| **Ante 1** | **4×4** | 2 Ranks (Rank 1–2) | 2 Chặng | **600 – 800 HP** | Làm quen cơ chế mỏ neo và tính chất |
| **Ante 2** | **5×5** | 3 Ranks (Rank 1–3) | 2 Chặng | **1,500 – 2,200 HP** | Xuất hiện thêm số 5, 6; đan xen Kakuro phức tạp |
| **Ante 3** | **6×6** | 3–4 Ranks | 3 Chặng | **4,500 – 6,500 HP** | Boss có hiệu ứng làm mờ 1 Cột ngẫu nhiên |
| **Ante 4** | **7×7** | 4 Ranks | 3 Chặng | **14,000 – 20,000 HP** | Đòi hỏi build Cổ Vật nhân Mult mạnh mới đủ điểm |
| **Ante 5 (Final)** | **8×8** | 5 Ranks | 4 Chặng | **40,000 – 65,000 HP** | Mật độ mìn dày đặc, sương mù 4 lớp |

---

## 7. HỆ THỐNG CỬA HÀNG (SHOP SYSTEM: CỔ VẬT & PHÁP BẢO)

Sau mỗi màn chơi, người chơi nhận được **Tiền Vàng (Gold)** dựa trên số lượt Play Hand còn dư và số mìn đã cắm cờ chính xác để mua sắm trong Cửa Hàng:

### 7.1. Cổ Tự / Cổ Vật (Tương đương Jokers - Tối đa 5 Slot Bị Động)
* **Thánh Tích Blackjack**: Khi kích hoạt Hand Blackjack 21, nhân thêm **×3 Mult**.
* **Kính Lúp Rà Mìn**: Mỗi khi cắm cờ đúng 1 quả mìn, cộng vĩnh viễn **+20 Chips** vào mọi Hand sau đó.
* **Ngọn Lửa Hủy Diệt**: Mọi con số mang chất Hỏa 🔥 nhận thêm **+12 Mult**.
* **Mìn Nghịch Đảo**: Khi dẫm phải mìn, thay vì trừ lượt Play Hand, biến quả mìn thành **150 Chips** nạp thẳng vào khay!
* **La Bàn Sudoku**: Nếu Hand chứa 4 số khác nhau hoàn toàn, cộng thêm **+35 Chips và +8 Mult**.

### 7.2. Cuộn Giấy Phép (Tương đương Tarot Cards - Dùng một lần)
* **Cuộn Biến Chất**: Chọn 2 ô số trên bàn cờ và đổi chúng sang cùng một Chất mong muốn.
* **Cuộn Khai Minh**: Lập tức dò và cắm cờ an toàn 1 quả mìn ngẫu nhiên trên bàn cờ.
* **Cuộn Hồi Thiên**: Hồi lại **1 lượt Play Hand** đã bị mất do dẫm mìn.
* **Cuộn Tăng Phẩm**: Nâng giá trị của 1 ô số lên thêm +2 (hỗ trợ ép tổng Blackjack 21 hoặc Sảnh).

---

## 8. ĐẶC TẢ ĐỒ HỌA, HIỆU ỨNG (ANIMATION) & GAME FEEL

### 8.1. Hiệu Ứng Lật Ô & Cắm Cờ
* **Lật Ô Số**: Ô xoay lật 3D 180 độ trong 0.15s, phát ra tiếng *click* pha lê trong trẻo. Số nhảy nảy nhẹ (pop scale 1.2 ➔ 1.0) với ánh sáng hào quang theo màu của Chất (Đỏ, Xanh, Vàng, Tím).
* **Cắm Cờ Mìn**: Lá cờ đỏ cắm phập xuống với âm thanh kim loại đanh thép (*thump*), viền ô chuyển sang ánh đỏ cảnh báo.

### 8.2. Hiệu Ứng Nổ Bom (Bomb Explosion FX)
* **Rung Màn Hình (Screen Shake)**: Chấn động giật cục mạnh (cường độ 15px trong 0.35s).
* **Hiệu Ứng Hình Ảnh**: Vệt sáng đỏ chớp toàn màn hình (red flash), mảnh vỡ ô cờ văng tung tóe kèm khói đen pixel.
* **Hiệu Ứng Trừ Lượt**: Biểu tượng Play Hand bị vỡ vụn với hiệu ứng nứt kính kèm tiếng chuông cảnh báo thê thảm.

### 8.3. Hiệu Ứng Bắn Sát Thương (Play Hand Attack Sequence)
1. **Lên Đạn (Arpeggio)**: Từng con số trong Khay Bài lần lượt bay lên với hợp âm thang âm tăng dần (đô - mi - son - đố).
2. **Nảy Điểm (Scoring Surge)**:
   * Thanh Chips nhảy số với âm thanh lách cách dồn dập.
   * Thanh Mult bốc cháy sáng rực màu đỏ lửa khi các Cổ Vật rung lên kích hoạt.
3. **Phóng Kích (Beam Blast)**: Toàn bộ con số hợp nhất thành một chùm tia năng lượng bắn xuyên qua bàn cờ thẳng vào Boss.
4. **Boss Trúng Đòn**: Boss co giật, chớp trắng (white flash 0.1s), thanh máu tụt dốc với thanh máu ma (ghost bar mờ dần), số sát thương (Floating Combat Text) văng ra cực đại nảy lên màn hình.

### 8.4. Hiệu Ứng Giải Trừ Sương Mù (Fog Dissolve)
* Khi đòn đánh kết thúc, làn khói xám đục đang phong ấn các hàng/cột tiếp theo sẽ cuộn tròn tan biến, ánh sáng vàng quét qua hé lộ các manh mối Kakuro và Rank mìn mới.
