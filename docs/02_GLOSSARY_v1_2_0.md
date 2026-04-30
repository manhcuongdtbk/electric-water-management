# 02. Bảng thuật ngữ / Glossary — v1.2.0

> **Đọc lần đầu?** Đọc 01_OVERVIEW trước để hiểu dự án là gì, phục vụ ai. File này là bảng tra cứu thuật ngữ, không giải thích bối cảnh.
>
> **Tra cứu?** Dùng mục 14 (Index Anh → Việt) ở cuối file để tìm nhanh từ code.
>
> **Quy ước ngôn ngữ:** Code (model, cột, biến) luôn tiếng Anh. Giao diện người dùng (UI, flash message, label) luôn tiếng Việt qua i18n (`config/locales/vi.yml`).

---

## 1. Tổ chức và nhân sự

| Tiếng Việt | English (code) | Model / Table | Giải thích |
|---|---|---|---|
| Sư đoàn | Division | `Organization` (level: `division`) | Đơn vị cấp cao nhất trong hệ thống. Chỉ có 1 Sư đoàn. Quản lý 13 đơn vị trực thuộc. |
| Đơn vị (cấp 2) | Unit | `Organization` (level: `unit`) | Đơn vị trực thuộc Sư đoàn. 13 đơn vị: Sư đoàn bộ, 3 Trung đoàn, 7 Tiểu đoàn, 2 Đại đội. Liên kết với Sư đoàn qua `parent_id`. |
| Ban Doanh trại | — (không có model riêng) | — | Bộ phận thuộc Sư đoàn chịu trách nhiệm quản lý điện nước toàn Sư đoàn. Trong phần mềm, đây là người dùng role admin_level1. Đây cũng là bên đặt hàng dự án. |
| Đầu mối | Contact Point | `ContactPoint` | Đơn vị nhỏ nhất có công tơ điện riêng, thuộc một đơn vị cấp 2. Ví dụ: Ban Tác huấn, Tổ xe, Nhà ăn. Sư đoàn bộ có 79 đầu mối (data tháng 02/2026). Mỗi đầu mối có quân số riêng và ít nhất một công tơ. |
| Quân số | Personnel | `Personnel` | Số người thuộc một đầu mối, chia theo 7 nhóm cấp bậc. Dùng để tính tiêu chuẩn điện được hưởng. Kế thừa từ tháng trước sang tháng sau. |
| Nhóm cấp bậc | Rank Group | `RankQuota` | 7 nhóm cấp bậc quân đội, mỗi nhóm có định mức điện riêng (kW/tháng). Xem bảng chi tiết ở mục 9. |
| Định mức | Quota | `RankQuota.quota_kw` | Lượng điện tiêu chuẩn (kW/tháng) cho mỗi người thuộc một nhóm cấp bậc. Ví dụ: Đại tá = 570 kW, Binh sĩ = 24 kW. Có thể thay đổi khi có nghị định mới (admin_level1 sửa qua F21). Cột `effective_from` ghi nhận ngày định mức bắt đầu có hiệu lực. |

---

## 2. Công tơ và đo đếm

| Tiếng Việt | English (code) | Model / Table | Giải thích |
|---|---|---|---|
| Công tơ | Meter | `Meter` | Đồng hồ đo điện gắn tại một đầu mối. Mỗi đầu mối có ít nhất một công tơ. Có 3 loại đã implement (xem bên dưới). Loại được xác định bởi cột `meter_type`. |
| Công tơ thường | Normal meter | `Meter` (meter_type: `normal`) | Công tơ đo điện sinh hoạt bình thường. Xuất hiện trong bản thu tiền. Tham gia tính tổn hao. |
| Công tơ công cộng | Public meter | `Meter` (meter_type: `public_meter`) | Công tơ đo điện dùng chung (hội trường, trường bắn, đèn đường...). **Không xuất hiện** trong bản thu tiền. Vẫn tham gia tính tổn hao. Nghiệp vụ: khi thu mỗi người % công cộng, tiền đó dùng để trả cho các vị trí công cộng này. |
| Công tơ trạm bơm | Pump station meter | `Meter` (meter_type: `pump_station`) | Công tơ đo điện bơm nước. Liên kết với `PumpStation`. Điện bơm được phân bổ cho các đầu mối theo quân số. |
| Công tơ vị trí không tổn hao | No-loss meter | `Meter` (meter_type: `no_loss`) | Công tơ đặt tại vị trí trước hoặc tại trạm biến áp — tức điện đo tại đây đã bao gồm tổn hao đường dây rồi, nên phần mềm **bỏ qua** công tơ này khi tính tổn hao phân bổ (tránh tính tổn hao hai lần). (chưa implement trong code — xem 04_DATABASE_MODELS mục TODO #1) |
| Đồng hồ tổng | Electricity supply meter | — | Đồng hồ tổng mà điện lực lắp để đo tổng điện cấp cho một đơn vị cấp 2. Khác với công tơ từng đầu mối: đồng hồ tổng đo toàn bộ điện đơn vị nhận, công tơ đầu mối đo từng vị trí tiêu thụ. Hiệu giữa đồng hồ tổng và tổng các công tơ = tổn hao. |
| Bản thu tiền | Billing summary | — (view output) | Bảng tổng hợp liệt kê từng đầu mối phải trả bao nhiêu tiền. Công tơ "công cộng" không xuất hiện trong bản này vì đã được trả bằng % công cộng thu từ mọi người. |
| Chỉ số đầu kỳ | Reading start | `MeterReading.reading_start` | Chỉ số công tơ đầu tháng. Tháng đầu tiên: nhập tay. Tháng sau: tự động = cuối kỳ tháng trước. |
| Chỉ số cuối kỳ | Reading end | `MeterReading.reading_end` | Chỉ số công tơ cuối tháng. Admin_unit nhập mỗi tháng. |
| Sử dụng (kW) | Usage / consumption | `MeterReading.consumption` | Lượng điện tiêu thụ = cuối kỳ − đầu kỳ. Phần mềm tự tính. |
| Số điện lực | Electricity supply | `UnitConfig.electricity_supply_kw` | Lưu trong `UnitConfig.electricity_supply_kw` (decimal 12,2). Admin_unit nhập qua F05. Số liệu từ đồng hồ tổng: tổng kW điện lực cấp cho đơn vị trong tháng. Dùng để tính tổn hao = số điện lực − tổng các công tơ. |
| Trạm bơm nước | Pump Station | `PumpStation` | Trạm bơm nước có công tơ riêng. Quản lý như công tơ thường (thêm, bớt được). Quản trị viên chỉ định trạm bơm phục vụ nhóm đối tượng nào. Data tháng 02 có 3 trạm: Trạm nước bên sông, cấp 1, cấp 2. |

---

## 3. Bảng 24 cột — tính toán tiêu chuẩn và sử dụng

### 3.1 Tổng quan

| Tiếng Việt | English (code) | Giải thích |
|---|---|---|
| Bảng tổng hợp / Bảng 24 cột | Monthly summary (24 columns) | Bảng tính toán chính của hệ thống, hiển thị chi tiết từng đầu mối trong một tháng. Gốc là 22 cột theo mẫu Excel khách cung cấp, đã tách thành 24 cột (PR#62): cột "Chênh lệch" tách thành "Thừa" + "Thiếu", cột "Thành tiền" cũng tách thành "Thừa" + "Thiếu". |
| Kỳ tính toán | Monthly period | `MonthlyPeriod` | Một tháng cụ thể (ví dụ: 02/2026). Mỗi kỳ có đơn giá riêng và trạng thái khóa. |

### 3.2 Cấu trúc 24 cột

| Cột | Tiếng Việt | English (code) | Nguồn / Cách tính |
|---|---|---|---|
| 1 | TT (số thứ tự) | serial_number | Tự động đánh số |
| 2 | Đơn vị (tên đầu mối) | contact_point_name | Từ `ContactPoint.name` |
| 3 | Tổng quân số | total_personnel | Tổng 7 nhóm cấp bậc |
| 4 | (cột phân cách) | — | Cột trống trong mẫu Excel gốc của khách, giữ nguyên để bảng phần mềm khớp layout mẫu giấy đang dùng. |
| 5 | Nhóm 1: Chỉ huy Sư đoàn; Đại tá | rank1_count | Từ `Personnel.rank1_count` |
| 6 | Nhóm 2: Chỉ huy Trung đoàn; Thượng tá | rank2_count | Từ `Personnel.rank2_count` |
| 7 | Nhóm 3: Chỉ huy Tiểu đoàn; Trung tá/Thiếu tá | rank3_count | Từ `Personnel.rank3_count` |
| 8 | Nhóm 4: Chỉ huy Đại đội, Trung đội; cấp Úy | rank4_count | Từ `Personnel.rank4_count` |
| 9 | Nhóm 5: Cơ quan Sư đoàn, Trung đoàn | rank5_count | Từ `Personnel.rank5_count` |
| 10 | Nhóm 6: Tiểu đoàn, Đại đội | rank6_count | Từ `Personnel.rank6_count` |
| 11 | Nhóm 7: Hạ sĩ quan, Binh sĩ | rank7_count | Từ `Personnel.rank7_count` |
| 12 | Điện bơm nước (tiêu chuẩn) | water_pump_standard_kw | = tổng quân số × 9,45 kW. Cố định theo nghị định. |
| 13 | Quân số | personnel_count | = cột 3 (lặp lại để tiện đọc bảng, theo layout mẫu gốc) |
| 14 | Cộng được hưởng theo NĐ 02 | total_standard_kw | = Σ(số người nhóm i × định mức nhóm i) + cột 12. Phần mềm tự tính. |
| 15 | Tiết kiệm của Bộ | savings_kw | = cột 14 × tỷ lệ tiết kiệm (5–10%). Cấp 1 cấu hình tỷ lệ. |
| 16 | Tổn hao | loss_kw | Phân bổ tổn hao cho đầu mối này. Xem công thức và ví dụ ở mục 4. |
| 17 | Công cộng | public_kw | = cột 14 × (tỷ lệ công cộng Sư đoàn + tỷ lệ công cộng đơn vị). Hai tỷ lệ cấu hình riêng. |
| 18 | Khác + Cộng | other_deduction_kw | Nhập số cụ thể hoặc hệ số × số người. **Cho phép giá trị âm** — xem giải thích và ví dụ ở mục 4. |
| 19 | Tiêu chuẩn còn lại (kW) | remaining_standard_kw | = cột 14 − cột 15 − cột 16 − cột 17 − cột 18. Nếu cột 18 âm thì cộng ngược (trừ số âm = cộng). |
| 20 | Sử dụng (kW) | actual_usage_kw | = sử dụng công tơ + bơm nước thực tế. **Không** cộng tổn hao vào sử dụng. |
| 21 | Thừa (kW) | surplus_kw (biến controller) | = cột 19 − cột 20 (chỉ khi dương, tức tiêu chuẩn > sử dụng). Hiển thị màu xanh. Nếu không thừa thì = 0. (derived ở view/controller, không phải cột DB — DB lưu `over_under_kw` signed) |
| 22 | Thiếu (kW) | deficit_kw (biến controller) | = cột 20 − cột 19 (chỉ khi dương, tức sử dụng > tiêu chuẩn). Hiển thị màu đỏ. Nếu không thiếu thì = 0. (derived ở view/controller, không phải cột DB — DB lưu `over_under_kw` signed) |
| 23 | Thừa (đồng) | surplus_amount (biến controller) | = cột 21 × đơn giá. Tiền thừa (đơn vị dùng ít hơn tiêu chuẩn). (derived ở view/controller, không phải cột DB — DB lưu `over_under_kw` signed) |
| 24 | Thiếu (đồng) | deficit_amount (biến controller) | = cột 22 × đơn giá. Tiền thiếu = số phải thu (đơn vị dùng vượt tiêu chuẩn). (derived ở view/controller, không phải cột DB — DB lưu `over_under_kw` signed) |

**Lưu ý quan trọng:**
- Cột 21–24 thay thế cột "Chênh lệch" và "Thành tiền" của bảng 22 cột gốc (PR#62). Thừa và Thiếu tính riêng, **không bù trừ** nhau trong dòng tổng.
- Dòng tổng (totals): tổng Thừa và tổng Thiếu tính riêng biệt — tức là cộng tất cả Thừa của các đầu mối, và cộng tất cả Thiếu của các đầu mối, không lấy hiệu.
- "Thâm điện" là thuật ngữ khách dùng trong trao đổi, nghĩa tương đương "Thiếu" (cột 22). Trong code và UI dùng "Thiếu" / `deficit`.

---

## 4. Các khoản trừ

Bốn khoản trừ khỏi tiêu chuẩn (cột 15–18) trước khi so sánh với sử dụng thực tế.

| Tiếng Việt | English (code) | Model / Config | Giải thích |
|---|---|---|---|
| Số phải trừ | Deductions | Cột 15–18 | Gom chung 4 khoản bên dưới. |
| Tiết kiệm của Bộ | Savings | `UnitConfig.savings_rate` | Tỷ lệ % trừ theo chỉ thị Bộ Quốc phòng (5–10%). Admin_level1 cấu hình, áp dụng chung tất cả đơn vị. |
| Tổn hao | Loss | Phần mềm tự tính | Điện thất thoát trên đường dây từ đồng hồ tổng đến các công tơ. Xem công thức và ví dụ bên dưới. |
| Công cộng dùng chung Sư đoàn | Division public | `UnitConfig.division_public_rate` | Tỷ lệ % do cấp 1 (Ban Doanh trại) quy định (5–10%). Áp dụng chung tất cả đơn vị. |
| Công cộng dùng chung đơn vị | Unit public | `UnitConfig.unit_public_rate` | Tỷ lệ % do đơn vị tự cấu hình (10–20%). Mỗi đơn vị có tỷ lệ riêng. |
| Khác | Other deduction | `ContactPointOtherDeduction` | Khoản trừ đặc thù từng đầu mối. Xem giải thích bên dưới. |

### Tổn hao — công thức và ví dụ

**Công thức:**
- Tổng tổn hao = số điện lực (đồng hồ tổng) − tổng kW tất cả công tơ
- Tổn hao đầu mối X = tổng tổn hao × (kW công tơ X ÷ tổng kW tất cả công tơ tham gia tính tổn hao)
- Công tơ "vị trí không tổn hao" (`no_loss`) bị loại khỏi cả tử số (kW đầu mối) lẫn mẫu số (tổng kW) khi phân bổ

**Ví dụ:** Đơn vị nhận 1.050 kW từ điện lực. Có 3 đầu mối: A dùng 400 kW (công tơ thường), B dùng 300 kW (công tơ thường), C dùng 250 kW (công tơ vị trí không tổn hao). Tổng các công tơ = 400 + 300 + 250 = 950 kW. Tổng tổn hao = 1.050 − 950 = 100 kW. Khi phân bổ tổn hao, loại C (no_loss) ra khỏi phép tính → mẫu số = 400 + 300 = 700 kW. Tổn hao A = 100 × (400 ÷ 700) ≈ 57,14 kW. Tổn hao B = 100 × (300 ÷ 700) ≈ 42,86 kW. C không chịu tổn hao.

**Điểm khác trực giác:** Tổn hao **trừ khỏi tiêu chuẩn** (nằm trong "Số phải trừ"), **không** cộng vào sử dụng. Nghĩa là tổn hao làm giảm lượng điện đầu mối được hưởng, chứ không tăng lượng điện tính là đã dùng.

### Cột "Khác" — cho phép âm

Khoản trừ đặc thù từng đầu mối. Hai cách nhập: (1) số kW cụ thể, hoặc (2) hệ số × số người.

**Giá trị dương** = trừ khỏi tiêu chuẩn (giảm tiêu chuẩn đầu mối). Ví dụ: đầu mối X có khoản "Khác" = 30 kW → tiêu chuẩn còn lại giảm 30 kW.

**Giá trị âm** = cộng ngược vào tiêu chuẩn (tăng tiêu chuẩn đầu mối). Ví dụ: Nhà bếp phục vụ ăn cho nhiều đầu mối khác → nhận thêm tiêu chuẩn điện, nhập −50 kW → tiêu chuẩn còn lại tăng thêm 50 kW.

---

## 5. Bơm nước

| Tiếng Việt | English (code) | Giải thích |
|---|---|---|
| Tiêu chuẩn bơm nước | Water pump standard | = 9,45 kW/người/tháng. Cố định theo Nghị định 02. Dùng để tính cột 12 và cộng vào cột 14 "Cộng được hưởng theo NĐ 02". Lịch sử: trước tháng 03/2026 là 6,3 kW (nghị định cũ). |
| Sử dụng bơm nước (thực tế) | Water pump actual | Điện bơm thực tế từ trạm bơm, phân bổ cho các đầu mối theo quân số. Con số này **thay đổi hàng tháng** tùy lượng điện bơm thực tế. Cộng vào cột 20 "Sử dụng". |
| Phân bổ bơm nước | Pump allocation | Tổng kW bơm ÷ tổng quân số × quân số đầu mối. Trạm bơm có thể chỉ định phục vụ nhóm đối tượng cụ thể (ví dụ: Chỉ huy Sư đoàn + nhà khách được 30% riêng, 70% còn lại chia đều theo quân số). |
| Phân bổ bơm nước cho đầu mối | Pump station assignment | `PumpStationAssignment` | Bản ghi liên kết trạm bơm với đơn vị/đầu mối mà trạm đó phục vụ. |

**Phân biệt quan trọng:** Tiêu chuẩn bơm nước (9,45 kW, cố định) ≠ Sử dụng bơm nước (thay đổi hàng tháng). Hai con số này xuất hiện ở hai vị trí khác nhau trong bảng 24 cột: tiêu chuẩn ở cột 12 (cộng vào tiêu chuẩn được hưởng), sử dụng ở cột 20 (cộng vào tổng sử dụng).

---

## 6. Kỳ tính toán và dữ liệu

| Tiếng Việt | English (code) | Model / Table | Giải thích |
|---|---|---|---|
| Kỳ tính toán | Monthly period | `MonthlyPeriod` | Tháng cụ thể (year + month). Lưu đơn giá và trạng thái khóa. |
| Đơn giá | Unit price | `MonthlyPeriod.unit_price` | Giá điện (đồng/kW). Thay đổi hàng tháng theo quy định nhà nước. Admin_level1 nhập qua F20. Data tháng 02/2026: 2.336,4 đồng/kW. |
| Khóa dữ liệu | Lock period | `MonthlyPeriod.locked` | Khi khóa, admin_unit không sửa được dữ liệu tháng đó. Chỉ admin_level1 mở khóa. Nghiệp vụ: tránh sửa dữ liệu đã báo cáo lên trên. |
| Kế thừa tháng | Month carry-over | — | Khi mở kỳ mới, chỉ **quân số** (`Personnel`) tự copy qua `PeriodInheritanceService` — `reviewed_at` set NULL để buộc soát lại qua F07. **Đầu mối** và **công tơ** không phụ thuộc kỳ (dùng chung mọi kỳ), không cần copy. **Cấu hình** (`UnitConfig`) và **khoản "Khác"** (`ContactPointOtherDeduction`) không copy — admin_unit nhập lại mỗi tháng qua F04 + F05. **Chỉ số đầu kỳ** (`MeterReading.reading_start`): pre-fill trên form F06 = cuối kỳ tháng trước (controller), chưa lưu DB cho đến khi user submit. |
| Kết quả tính toán | Monthly calculation | `MonthlyCalculation` | Kết quả tính toán bảng 24 cột cho mỗi đầu mối trong mỗi tháng. Lưu tất cả giá trị các cột. |
| Cấu hình đơn vị | Unit config | `UnitConfig` | Tỷ lệ tiết kiệm, tỷ lệ công cộng Sư đoàn, tỷ lệ công cộng đơn vị — theo đơn vị và theo tháng. |
| Nghị định 02 | Decree 02 / NĐ 02 | — | Nghị định của Bộ Quốc phòng quy định tiêu chuẩn sử dụng điện cho các đơn vị quân đội. Định mức 7 nhóm cấp bậc và tiêu chuẩn bơm nước 9,45 kW đều từ nghị định này. Khi có nghị định mới, admin_level1 cập nhật định mức qua F21. |

---

## 7. Vai trò người dùng

| Tiếng Việt | English (code) | Enum value | Phạm vi |
|---|---|---|---|
| Quản trị viên cấp 1 | Level 1 Admin | `admin_level1` | Thuộc Sư đoàn (division). Cấu hình toàn hệ thống: đơn giá, tỷ lệ tiết kiệm, tỷ lệ công cộng Sư đoàn, định mức cấp bậc. Xem dữ liệu tất cả đơn vị. Mở khóa kỳ cũ. Trong thực tế: Ban Doanh trại Sư đoàn. |
| Quản trị viên đơn vị | Unit Admin | `admin_unit` | Thuộc 1 đơn vị cấp 2 cụ thể. CRUD đầu mối, công tơ, quân số của đơn vị mình. Nhập liệu hàng tháng (chỉ số công tơ, số điện lực). Cấu hình tỷ lệ công cộng đơn vị. **Chỉ thấy** data đơn vị mình. |
| Chỉ huy đơn vị | Commander | `commander` | Thuộc 1 đơn vị cấp 2 cụ thể. **Chỉ xem**, không thao tác. Kiểm tra số liệu do admin_unit nhập. Chỉ thấy data đơn vị mình. |
| Kỹ thuật | Tech | `tech` | Thuộc Sư đoàn (division). Quản lý tài khoản người dùng (F15). Xem nhật ký hoạt động (F19). Sao lưu & phục hồi. **Không** truy cập dữ liệu nghiệp vụ (quân số, công tơ, bảng tổng hợp). |

---

## 8. Chức năng (F-number)

### 8.1 Khai báo ban đầu

| F# | Tiếng Việt | English | Roles | Mô tả ngắn |
|---|---|---|---|---|
| F01 | Khai báo đầu mối | Contact point CRUD | admin_unit, admin_level1 | Thêm, sửa, xóa đầu mối trong đơn vị |
| F02 | Khai báo công tơ | Meter CRUD | admin_unit, admin_level1 | Thêm, sửa, xóa công tơ trong đầu mối. Đánh dấu loại: thường/công cộng/trạm bơm/không tổn hao |
| F03 | Khai báo quân số | Personnel management | admin_unit, admin_level1 | Nhập số người theo 7 nhóm cấp bậc cho từng đầu mối |
| F04 | Cấu hình tỷ lệ và cột "Khác" | Unit config | admin_unit (tỷ lệ đơn vị), admin_level1 (tỷ lệ Sư đoàn) | Cấu hình tiết kiệm, công cộng, khoản "Khác" |

### 8.2 Nhập liệu hàng tháng

| F# | Tiếng Việt | English | Roles | Mô tả ngắn |
|---|---|---|---|---|
| F05 | Nhập số điện lực | Electricity supply input | admin_unit | Nhập tổng kW điện lực cấp cho đơn vị trong tháng (từ đồng hồ tổng) |
| F06 | Nhập chỉ số công tơ | Meter reading input | admin_unit | Nhập chỉ số đầu kỳ, cuối kỳ cho từng công tơ |
| F07 | Soát lại quân số | Personnel review | admin_unit | Kiểm tra và sửa quân số kế thừa từ tháng trước |

### 8.3 Tính toán (phần mềm tự động)

| F# | Tiếng Việt | English | Mô tả ngắn |
|---|---|---|---|
| F08 | Tính tiêu chuẩn theo NĐ 02 | Standard calculation | Tính tiêu chuẩn = Σ(quân số × định mức) + bơm nước |
| F09 | Tính sử dụng và so sánh | Usage comparison | So sánh sử dụng vs tiêu chuẩn → thừa/thiếu → thành tiền |
| F10 | Phân bổ bơm nước | Pump water allocation | Chia điện bơm thực tế cho các đầu mối theo quân số |

### 8.4 Báo cáo và tra cứu

| F# | Tiếng Việt | English | Roles | Mô tả ngắn |
|---|---|---|---|---|
| F11 | Bảng tổng hợp 24 cột | Monthly summary table | admin_unit, admin_level1, commander (xem) | Hiển thị bảng tính toán chi tiết |
| F12 | Dashboard (tháng/quý/năm) | Dashboard | Tất cả 4 vai trò | Biểu đồ so sánh tiêu chuẩn vs sử dụng |
| F13 | Tra cứu lịch sử + so sánh cùng kỳ | Historical lookup | admin_unit, admin_level1, commander | Xem data tháng cũ, so sánh delta ▲/▼/= |
| F14 | Xuất CSV | CSV export | admin_unit, admin_level1 | Xuất bảng tổng hợp ra file CSV |

### 8.5 Quản trị hệ thống

| F# | Tiếng Việt | English | Roles | Mô tả ngắn |
|---|---|---|---|---|
| F15 | Quản lý tài khoản | User management | tech | Tạo, khóa, mở khóa tài khoản. Gán role + đơn vị |
| F16 | Đăng nhập | Authentication | Tất cả | Đăng nhập bằng email + mật khẩu |
| F17 | Khóa tài khoản | Account lockout | Tự động | Devise khóa sau 5 lần nhập sai mật khẩu liên tiếp |
| F18 | Bắt buộc đổi mật khẩu lần đầu | Force password change | Tất cả (user mới) | Tài khoản mới phải đổi mật khẩu khi đăng nhập lần đầu |
| F19 | Nhật ký hoạt động | Audit log | tech, admin_level1 (xem) | Xem ai sửa gì, lúc nào, giá trị cũ/mới (PaperTrail) |
| F20 | Quản lý đơn giá | Unit price management | admin_level1 | Nhập/sửa giá điện theo tháng |
| F21 | Quản lý định mức cấp bậc | Rank quota management | admin_level1 | Sửa tên nhóm cấp bậc và định mức kW khi có nghị định mới |

**Lưu ý:** Sao lưu & phục hồi (backup/restore) không có F-number riêng — đây là tính năng hạ tầng, không phải chức năng nghiệp vụ. Tech user thao tác qua giao diện riêng.

---

## 9. 7 nhóm cấp bậc chi tiết

| Nhóm | Tên đầy đủ (tiếng Việt) | rank_field | Định mức (kW/tháng) |
|---|---|---|---|
| 1 | Chỉ huy Sư đoàn; SQ có trần quân hàm là Đại tá | rank1_count | 570 |
| 2 | Chỉ huy Trung đoàn; SQ có trần quân hàm là Thượng tá | rank2_count | 440 |
| 3 | Chỉ huy tiểu đoàn; SQ có trần quân hàm là Trung tá, Thiếu tá | rank3_count | 305 |
| 4 | Chỉ huy đại đội, trung đội; SQ có trần quân hàm là cấp Úy | rank4_count | 130 |
| 5 | Cơ quan sư đoàn, trung đoàn | rank5_count | 210 |
| 6 | Tiểu đoàn, đại đội | rank6_count | 110 |
| 7 | Hạ sĩ quan, binh sĩ | rank7_count | 24 |

**Lưu ý:**
- Tên nhóm cấp bậc lưu trong database (`RankQuota.rank_name`), không hardcode trong i18n (đã refactor PR#63).
- Định mức có thể thay đổi khi có nghị định mới — admin_level1 sửa qua F21.
- Cột `effective_from` ghi nhận ngày định mức bắt đầu có hiệu lực.
- "SQ" = Sĩ quan. Viết tắt duy nhất được chấp nhận trong dự án, là thuật ngữ khách dùng.

---

## 10. Hạ tầng và vận hành

| Tiếng Việt | English (code) | Giải thích |
|---|---|---|
| Sao lưu | Backup | pg_dump toàn bộ database PostgreSQL. File `.dump`. Lưu trong `db/backups/` (bind mount trong Docker). Tech user thao tác qua UI hoặc rake task (`rails db:backup`). |
| Phục hồi | Restore | pg_restore từ file backup. Sign out tất cả user, redirect về login. Database quay về đúng trạng thái tại thời điểm backup. Rake task: `rails 'db:restore[filename.dump]'`. |
| Nhật ký hoạt động | Audit log | PaperTrail ghi lại mọi thay đổi dữ liệu: ai (`whodunnit` = user ID), sửa gì (`item_type` = model name), lúc nào, giá trị cũ/mới. Lưu trong bảng `versions`. UI chỉ cho xem, không có chức năng revert. |

---

## 11. Danh sách 14 đơn vị

| # | Code (DB) | Tên đầy đủ | Level | Ghi chú |
|---|---|---|---|---|
| 1 | SD | Sư đoàn | division | Đơn vị cấp 1, parent của tất cả |
| 2 | SDB | Sư đoàn bộ | unit | Có data tháng 02 (79 đầu mối) |
| 3 | TR101 | Trung đoàn 101 | unit | |
| 4 | TR18 | Trung đoàn 18 | unit | |
| 5 | TR95 | Trung đoàn 95 | unit | |
| 6 | TD14 | Tiểu đoàn 14 | unit | |
| 7 | TD15 | Tiểu đoàn 15 | unit | |
| 8 | TD16 | Tiểu đoàn 16 | unit | |
| 9 | TD17 | Tiểu đoàn 17 | unit | |
| 10 | TD18 | Tiểu đoàn 18 | unit | |
| 11 | TD24 | Tiểu đoàn 24 | unit | |
| 12 | TD25 | Tiểu đoàn 25 | unit | |
| 13 | DH26 | Đại đội 26 | unit | |
| 14 | DH29 | Đại đội 29 | unit | |

---

## 12. Thuật ngữ kỹ thuật

| Thuật ngữ | Giải thích |
|---|---|
| BigDecimal | Kiểu số chính xác cao, dùng cho tất cả cột liên quan tiền và kW. Không dùng float để tránh sai số làm tròn trong tính toán tài chính. |
| CalculationEngine | Service object tính toán bảng 24 cột. Input: đầu mối + quân số + công tơ + cấu hình → Output: `MonthlyCalculation` với 24 giá trị. |
| ImportFeb2026Service | Service import data tháng 02/2026 từ file Excel khách. Chỉ import cho SDB (Sư đoàn bộ). Idempotent — chạy lại không tạo duplicate (dùng `find_or_initialize_by`). |
| BackupService | Service sao lưu/phục hồi dùng `pg_dump`/`pg_restore` qua `Open3.capture3`. Có path traversal protection. |
| PaperTrail | Gem Rails ghi lại lịch sử thay đổi model. Bảng `versions`. `whodunnit` = user ID của người thực hiện thay đổi. |
| CanCanCan | Gem Rails phân quyền. Ability class dùng hash conditions (không blocks) để hỗ trợ `accessible_by` — pattern quan trọng cho scope isolation. |
| Devise | Gem Rails xác thực. Modules: `database_authenticatable`, `lockable` (5 lần sai), `timeoutable`, `trackable`. Custom: `force_password_change` flag. |
| Hotwire (Turbo / Stimulus) | Stack frontend của Rails. Turbo Frames cho cập nhật partial page không reload. Stimulus controllers cho JS behavior nhẹ. |
| Seeds | `db/seeds.rb` — tạo organizations + users ban đầu. Idempotent (`find_or_create_by`). |

---

## 13. Viết tắt

| Viết tắt | Đầy đủ | Ghi chú |
|---|---|---|
| SQ | Sĩ quan | Viết tắt duy nhất được chấp nhận trong tài liệu và UI, là thuật ngữ khách dùng |
| NĐ 02 | Nghị định 02 | Nghị định Bộ Quốc phòng quy định tiêu chuẩn điện cho quân đội |
| F## | Feature number | Đánh số chức năng từ F01 đến F21 |
| PR# | Pull Request | Đánh số PR trên GitHub |
| M# | Milestone | M1–M6, đánh số giai đoạn phát triển |
| SD | Sư đoàn | Code trong database |
| SDB | Sư đoàn bộ | Code trong database |
| TR | Trung đoàn | Prefix code trong database |
| TD | Tiểu đoàn | Prefix code trong database |
| DH | Đại đội | Prefix code trong database |

---

## 14. Index Anh → Việt (tra cứu từ code)

Dùng bảng này khi đọc code và cần biết nghĩa tiếng Việt.

| English (code) | Tiếng Việt | Mục |
|---|---|---|
| `actual_usage_kw` | Sử dụng (kW) — cột 20 | 3.2 |
| `admin_level1` | Quản trị viên cấp 1 | 7 |
| `admin_unit` | Quản trị viên đơn vị | 7 |
| `BackupService` | Sao lưu | 12 |
| `CalculationEngine` | Engine tính toán bảng 24 cột | 12 |
| `commander` | Chỉ huy đơn vị | 7 |
| `consumption` | Sử dụng (kW) — mức công tơ | 2 |
| `ContactPoint` | Đầu mối | 1 |
| `ContactPointOtherDeduction` | Khoản trừ "Khác" | 4 |
| `deficit_amount` | Thiếu (đồng) — cột 24 (biến controller, derived) | 3.2 |
| `deficit_kw` | Thiếu (kW) — cột 22 (biến controller, derived từ `over_under_kw`) | 3.2 |
| `division` | Sư đoàn | 1 |
| `division_public_rate` | Tỷ lệ công cộng Sư đoàn | 4 |
| `effective_from` | Ngày hiệu lực định mức | 1, 9 |
| `electricity_supply_kw` | Số điện lực (đồng hồ tổng) | 2 |
| `force_password_change` | Bắt buộc đổi mật khẩu lần đầu | 8.5 |
| `ImportFeb2026Service` | Service import data tháng 02 | 12 |
| `item_type` | Loại model bị thay đổi (PaperTrail) | 10 |
| `level` | Cấp tổ chức: `division` hoặc `unit` | 1 |
| `locked` | Khóa dữ liệu | 6 |
| `loss_kw` | Tổn hao — cột 16 | 3.2, 4 |
| `Meter` | Công tơ | 2 |
| `meter_type` | Loại công tơ: `normal`, `public_meter`, `pump_station`, `no_loss` (no_loss chưa implement) | 2 |
| `MeterReading` | Bản ghi chỉ số công tơ | 2 |
| `MonthlyCalculation` | Kết quả tính toán | 6 |
| `MonthlyPeriod` | Kỳ tính toán | 6 |
| `no_loss` | Vị trí không tổn hao | 2 |
| `normal` | Công tơ thường | 2 |
| `Organization` | Sư đoàn hoặc Đơn vị | 1 |
| `other_deduction_kw` | Khác + Cộng — cột 18 | 3.2, 4 |
| `over_under_kw` | Chênh lệch kW (signed: dương = thừa, âm = thiếu) — cột DB | 3.2 |
| `parent_id` | ID Sư đoàn (liên kết đơn vị cấp 2 → cấp 1) | 1 |
| `Personnel` | Quân số | 1 |
| `public_kw` | Công cộng — cột 17 | 3.2, 4 |
| `public_meter` | Công tơ công cộng | 2 |
| `pump_station` | Công tơ trạm bơm | 2 |
| `PumpStation` | Trạm bơm nước | 2 |
| `PumpStationAssignment` | Phân bổ bơm nước cho đầu mối | 5 |
| `quota_kw` | Định mức (kW/tháng) | 1, 9 |
| `rank1_count` ... `rank7_count` | Quân số nhóm 1–7 | 9 |
| `rank_name` | Tên nhóm cấp bậc | 9 |
| `RankQuota` | Nhóm cấp bậc + định mức | 1, 9 |
| `reading_end` | Chỉ số cuối kỳ | 2 |
| `reading_start` | Chỉ số đầu kỳ | 2 |
| `remaining_standard_kw` | Tiêu chuẩn còn lại — cột 19 | 3.2 |
| `savings_kw` | Tiết kiệm của Bộ — cột 15 | 3.2, 4 |
| `savings_rate` | Tỷ lệ tiết kiệm | 4 |
| `surplus_amount` | Thừa (đồng) — cột 23 (biến controller, derived) | 3.2 |
| `surplus_kw` | Thừa (kW) — cột 21 (biến controller, derived từ `over_under_kw`) | 3.2 |
| `tech` | Kỹ thuật | 7 |
| `total_standard_kw` | Cộng được hưởng theo NĐ 02 — cột 14 | 3.2 |
| `unit` | Đơn vị (cấp 2) | 1 |
| `unit_price` | Đơn giá | 6 |
| `unit_public_rate` | Tỷ lệ công cộng đơn vị | 4 |
| `UnitConfig` | Cấu hình đơn vị | 6 |
| `User` | Tài khoản người dùng | 7 |
| `versions` | Bảng PaperTrail lưu lịch sử thay đổi | 10, 12 |
| `water_pump_standard_kw` | Điện bơm nước tiêu chuẩn — cột 12 | 3.2, 5 |
| `whodunnit` | User ID người thực hiện thay đổi (PaperTrail) | 10, 12 |

---

## Changelog

| Version | Ngày | Thay đổi |
|---|---|---|
| v1.0.0 | 28/04/2026 | Khởi tạo. |
| v1.1.0 | 30/04/2026 | Sửa tên cột MeterReading (reading_start/reading_end/consumption). Sửa meter_type public_use → public_meter. Ghi rõ cột 21–24 là derived (view layer). Thêm electricity_supply_kw vào mục 2. Đóng 4 TODO. Cập nhật index mục 14. |
| v1.2.0 | 30/04/2026 | Sửa mục 6 "Kế thừa tháng": mô tả chính xác phạm vi copy theo code thực tế — chỉ Personnel được copy; đầu mối + công tơ dùng chung kỳ; UnitConfig + ContactPointOtherDeduction không copy; chỉ số đầu kỳ pre-fill trên form F06. |
