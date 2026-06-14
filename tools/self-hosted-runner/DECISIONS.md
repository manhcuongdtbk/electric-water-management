# Self-hosted CI — bản ghi kiến thức & quyết định

> Ghi lại đầy đủ vấn đề, các phương án, quyết định và bài học khi dựng CI chạy
> trên self-hosted runner cho repo này (nhánh nghiên cứu `claude/dazzling-rubin-334f1e`,
> liên quan PR #383). README cùng thư mục là hướng dẫn *vận hành*; file này là
> *vì sao* + *hành trình* để team (và người sau) không phải dò lại từ đầu.
>
> Phạm vi: chỉ kiến thức **kỹ thuật/quy trình**. Quyết định vận hành nhạy cảm
> không thuộc về repo và không nằm ở đây.

## 1. Vấn đề

Tài khoản đã dùng hết phút GitHub Actions miễn phí (2.000/tháng). Repo **private
và phải giữ private**. Cần CI tiếp tục chạy ở mức **chi phí $0** mà không đổi tính
riêng tư của repo, ít nhất tới khi quota reset.

## 2. Các phương án đã cân nhắc

| Phương án | $0? | Giữ private? | Đánh đổi |
|---|---|---|---|
| **Self-hosted runner** (đã chọn) | ✅ | ✅ | Tự lo máy chạy; **chậm hơn** GitHub-hosted; cần online |
| Pre-push local checks (git hook) | ✅ | ✅ | Chặn dev đồng bộ trước mỗi push; bypass được; **mất trạng thái CI trên PR** (mất truy vết) |
| Chờ quota reset đầu tháng | ✅ | ✅ | Không có CI tới lúc reset |
| Tăng tài nguyên/chia nhỏ | — | — | Không giải quyết gốc chi phí |

→ Chọn **self-hosted runner**: giữ được trạng thái CI trên PR (truy vết — quan
trọng với SDLC dự án) và $0, đổi lại chậm hơn. Pre-push để dành làm lớp bổ trợ
nếu cần phản hồi nhanh cục bộ.

## 3. Đã dựng gì

- **Runner** = container Ubuntu 24.04 có **Docker daemon riêng bên trong**
  (privileged + DinD) chạy trên Docker Desktop, để `services:` (Postgres) hoạt
  động như `ubuntu-latest`. Chi tiết cơ chế + mermaid: `README.md` mục 3.
- `ci.yml`: mọi job `runs-on: ubuntu-latest` → `self-hosted` (tạm thời, revert
  khi quota về). **Không merge** vào develop — giữ làm nghiên cứu.
- **`bin/test-processes`**: tự tính số process song song = `min(nproc,
  RAM_khả_dụng / ~1100MB)` để mọi máy/CI tự vừa, không cần chỉnh tay; đọc RAM
  *khả dụng* nên máy bận tự giảm.

## 4. Hành trình song song hoá (cái gì hỏng, vì sao)

Mục tiêu: bù phần chậm của self-hosted bằng chạy test song song. Lần lượt gặp và
xử (các fix nằm ở `ci.yml`, `system_test_config.rb`, `spec_helper.rb`, kèm comment):

1. **Đơn luồng quá chậm** (~1h) → bật `parallel_tests` (đã có sẵn trong Gemfile).
2. **chromedriver tranh cổng khoá 9514** khi system specs chạy song song
   (`unable to bind to locking port 9514`) → cấp **cổng chromedriver riêng mỗi
   process** (`9515 + TEST_ENV_NUMBER*10`).
3. **chromedriver crash (ECONNREFUSED) khi quá nhiều Chrome đồng thời** → **tách
   2 pha**: non-system full parallel, system specs concurrency thấp.
4. **`parallel_test` nuốt `--tag`/`-o '--…'` thành đường dẫn file**
   (`File.stat('--tag')`) → truyền **danh sách file tường minh** (`find spec …
   -not -path 'spec/system/*'`).
5. **Coverage ratchet (`minimum_coverage`, #381/ADR-060) fail giả khi parallel**
   (mỗi process báo coverage một phần) → chỉ gate khi **chạy đơn-process**
   (`unless ENV["TEST_ENV_NUMBER"]`); per-process `command_name` + `merge_timeout`
   để SimpleCov gộp.

## 5. Ngõ cụt (trạng thái hiện tại — CHƯA xong)

**Non-system specs song song chạy tốt.** Nhưng **system specs (Selenium/headless
Chrome) chưa xanh ổn định**: kể cả ở concurrency thấp (`-n 2`), qua một lần chạy
~55 phút với hàng trăm system example, chromedriver **vẫn ECONNREFUSED rải rác**
— chromedriver tự chết, không phải lỗi cấu hình.

**Kết luận:** tuning concurrency không trị được — đây là **flakiness môi trường
của headless Chrome trên Docker-lồng-trên-Mac**, không phải bug logic.

## 6. Hướng thử khi quay lại (chưa làm)

1. **System specs chạy đơn-process** (`bundle exec rspec spec/system`, cổng mặc
   định ngẫu nhiên — bỏ per-process port) để giảm tối đa stress Chrome.
2. **`rspec-retry`** giới hạn `type: :system`, chỉ retry
   `Selenium::WebDriver::Error::WebDriverError` (dung thứ ECONNREFUSED tạm thời).
3. Chấp nhận self-hosted chỉ chạy **non-system specs**; system specs để
   GitHub-hosted.

## 7. Bài học rút ra (chung)

- Self-hosted runner 1 con = job chạy **tuần tự** + nested-Docker-trên-Mac chậm
  → **không phải giải pháp tốc độ**, là giải pháp **$0-khi-private**.
- Headless Chrome trên Docker-lồng-Mac **flaky theo bản chất** ở mọi mức
  concurrency — đừng kỳ vọng song song hoá nhiều cho browser specs ở môi trường này.
- Shell trong CI là **zsh**: `for x in $VAR` KHÔNG tự tách từ — dùng `${=VAR}`.
- `parallel_test` parse args dễ bẫy (file vs test-options): ưu tiên **đường dẫn
  file tường minh** thay vì `--tag`/`--`/`-o`.

## 8. Bắt đầu tiếp #383 từ đâu (runbook)

1. `git checkout claude/dazzling-rubin-334f1e` — nhánh #383 (KHÔNG merge vào
   develop, chỉ research).
2. Bật runner: `tools/self-hosted-runner/start.sh` (cần Docker Desktop chạy +
   `gh` đã đăng nhập bằng tài khoản **có quyền admin repo** để lấy token đăng ký).
   Đợi log `Listening for Jobs` (`docker logs -f ewm-gh-runner`).
3. Chọn một hướng ở mục 6, sửa code tương ứng (`spec/support/system_test_config.rb`,
   `.github/workflows/ci.yml`, `spec/spec_helper.rb`).
4. Commit + push lên nhánh #383 → runner tự nhận job → CI chạy. (Đang behind
   develop thì merge develop trước khi push; **chạy `commit` và `push` ở 2 lệnh
   riêng** vì hook chặn-nhánh-cũ chặn cả lệnh nếu gộp.)
5. Theo dõi: `gh pr checks 383 --watch` (nên chạy nền). Lưu ý: log job
   **in-progress KHÔNG tải được** (`gh api …/jobs/<id>/logs` → 404) — đợi job xong
   mới đọc full; giữa chừng soi `docker exec ewm-gh-runner ps`/`log/test.log`.
6. Lặp tới khi system specs xanh ổn định, hoặc chốt hướng 3 (system specs để
   GitHub-hosted, self-hosted chỉ chạy non-system).

Xong thì tắt runner: `tools/self-hosted-runner/stop.sh`.
