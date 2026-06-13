---
title: Nội dung CI — phần chạy test (rspec + system, schema-drift, zeitwerk) — Mảnh "CI spec chi tiết"
version: 0.2.1
date: 2026-06-07
governed_by: 2026-06-07-sdlc-overview-design.md
---

# Nội dung CI — phần chạy test trên Continuous Integration

Mảnh **"CI spec chi tiết"** (Backlog #1 trong [quy trình phát hành](2026-06-07-quy-trinh-release-design.md)). Tiếp nối trực tiếp **ADR-011**: P2 đã dựng tập kiểm tra **tĩnh** (rubocop, brakeman, bundler-audit, commitlint, branch-source guard); mảnh này bổ sung phần **chạy test** mà P2 cố ý hoãn vì cần thêm hạ tầng (Postgres + trình duyệt headless) và các quyết định runner/cache/headless. Về sau mảnh này bổ sung **ADR-021** — cắt chi phí & độ trễ CI (path filter bỏ qua job nặng cho pull request không đụng code + bỏ trigger `edited`), kích hoạt từ chính "Điều kiện xem lại" của ADR-012.

> **Cách đọc:** quyết định viết theo **ADR** (xem [ADR-012](#adr-012-nội-dung-ci--phần-chạy-test)): Bối cảnh → Quyết định → Lý do → Tradeoff → Phương án đã loại → Điều kiện xem lại → Trạng thái.

## Goals

- Trên mỗi pull request, chạy **toàn bộ bộ test** (model/request/service spec **và** system spec điều khiển trình duyệt thật) để bắt lỗi hồi quy trước khi tới môi trường Nghiệm thu.
- Bắt **trôi schema** (`db/schema.rb` không khớp migration) và **lỗi tự động nạp** (`zeitwerk:check`) sớm, ngay trên pull request.
- **Chi phí thấp**, tận dụng GitHub Actions miễn phí; **không thêm phụ thuộc** dễ bị bỏ rơi.
- Cộng thêm vào CI tĩnh hiện có (cùng `.github/workflows/ci.yml`), **không sửa code ứng dụng / code test**.

## Non-Goals (cố ý KHÔNG làm ở mảnh này)

- **Khoá cứng** ở server (branch protection) — vẫn theo ADR-007: CI chỉ **hiện trạng thái** đỏ/xanh; kỷ luật một người merge giữ luật.
- **Tách / song song hoá** job system spec, hoặc thêm gem retry chống chập chờn — chỉ làm khi thực sự cần (xem [Điều kiện xem lại](#adr-012-nội-dung-ci--phần-chạy-test)).
- **Định tuyến workflow qua `bin/ci` / `config/ci.rb`** — workflow giữ nguyên kiểu khai báo tường minh từng bước qua nhiều job song song (lựa chọn của P2). `config/ci.rb` (bộ chạy CI cục bộ của Rails 8) giữ nguyên phạm vi tĩnh; luồng chạy test cục bộ vẫn là `bin/docker rspec` theo `AGENTS.md`.
- Môi trường Railway (Nghiệm thu + Mốc) — là **P4**, mảnh khác.

## Bối cảnh & hiện trạng

- `.github/workflows/ci.yml` (P2) có 3 job chạy trên pull request: `ruby-checks` (rubocop + brakeman + bundler-audit), `commitlint`, `branch-source-guard`. Cả ba đều **tĩnh** — không cần Postgres, không cần trình duyệt, không boot app. `ruby-checks` dùng `ruby/setup-ruby@v1` với `bundler-cache: false` và bước `bundle install` thủ công (P2 cố ý hoãn cache).
- `config/database.yml` lấy cấu hình từ biến môi trường (`DATABASE_HOST`/`DATABASE_PORT`/`DATABASE_USERNAME` + `ELECTRIC_WATER_MANAGEMENT_DATABASE_PASSWORD`), mặc định `localhost` → khớp một **service container** Postgres.
- `spec/support/system_test_config.rb` đăng ký driver Capybara `:headless_chromium`. Khi binary `/usr/bin/chromium` + `/usr/bin/chromedriver` **không tồn tại** (ngoài Docker), driver tự lùi về **Selenium Manager** để dò trình duyệt + tải chromedriver khớp. Các cờ Chromium (`--headless=new`, `--no-sandbox`, `--disable-gpu`, `--disable-dev-shm-usage`) an toàn ở mọi bối cảnh.
- Bộ test: 85 spec, trong đó **12 system spec** (`type: :system`). `.rspec` chỉ có `--require spec_helper`; `bundle exec rspec` chạy toàn bộ.
- Stack neo: Ruby 3.4.3, Postgres 16 (`postgres:16-alpine` trong `compose.yml`), selenium-webdriver 4.44 (kèm sẵn Selenium Manager), capybara 3.40.

## Thiết kế

Thêm **một job `tests`** vào `.github/workflows/ci.yml`, chạy `ubuntu-latest`, đứng cạnh các job tĩnh hiện có (cùng `on: pull_request` + nhóm `concurrency` — không đổi).

### Hạ tầng job

- **Postgres:** service container `postgres:16-alpine` (khớp `compose.yml`), kiểm tra sức khoẻ bằng `pg_isready`, expose `localhost:5432`.
- **Biến môi trường DB** nối đúng vào `config/database.yml`: `RAILS_ENV=test`, `DATABASE_HOST=localhost`, `DATABASE_PORT=5432`, `DATABASE_USERNAME=postgres`, `ELECTRIC_WATER_MANAGEMENT_DATABASE_PASSWORD=postgres`.
- **Trình duyệt:** dùng **Google Chrome cài sẵn** trên ảnh `ubuntu-latest` + **Selenium Manager** (kèm trong selenium-webdriver 4.44) tự tải chromedriver khớp phiên bản — đúng nhánh lùi mà `system_test_config.rb` đã hỗ trợ khi chạy ngoài Docker. Để hành vi **tất định** bất kể ảnh runner pre-bake gì ở `/usr/bin`, job đặt `CHROMIUM_BINARY` và `CHROMEDRIVER_BINARY` trỏ tới **đường dẫn không tồn tại** → cả hai guard `File.exist?` cùng trượt → Selenium Manager dò mọi thứ theo Chrome cài sẵn. **Không sửa code ứng dụng / code test.** Đây là dòng dễ phải tinh chỉnh nhất sau lần chạy pull request đầu (đánh dấu rõ trong [Rủi ro](#rủi-ro--giảm-thiểu)).

### Các bước job (mỗi bước gắn `if: ${{ !cancelled() }}` để một bước đỏ không che các bước sau — khớp kiểu của job tĩnh hiện có)

1. `actions/checkout@v4`.
2. `ruby/setup-ruby@v1` với `ruby-version: .ruby-version` và **`bundler-cache: true`**.
3. **DB + kiểm schema không lệch:** `bin/rails db:create db:migrate` rồi `git diff --exit-code db/schema.rb`. Trên DB rỗng, chạy hết migration phải tái tạo `db/schema.rb` **đúng từng byte** so với bản đã commit (bắt trôi schema cả hai chiều: migration chưa cập nhật schema, hoặc schema sửa tay không khớp migration). Bước này cũng để lại **DB test đã chuẩn bị**, nên `maintain_test_schema!` trong `rails_helper` thành no-op.
4. **`bin/rails zeitwerk:check`** — bắt lỗi đặt tên / tự động nạp.
5. **`bundle exec rspec`** — chạy cả 85 spec, gồm 12 system spec (headless Chrome).

### Cache (quyết định P2 hoãn)

Bật cache: **`bundler-cache: true`** ở job `tests`, và **đổi luôn job `ruby-checks`** hiện có từ `bundler-cache: false` + `bundle install` thủ công sang `bundler-cache: true` cho nhất quán + nhanh (bỏ bước cài thủ công và các ghi chú "cache để dành"). Cập nhật luôn ghi chú đầu file `ci.yml`: các mục từng hoãn nay đã xong, trỏ về spec này.

### Phác workflow (bản dựng nằm ở `.github/workflows/ci.yml` mới là nguồn sự thật)

```yaml
  tests:
    name: Tests (rspec incl. system specs, zeitwerk, schema drift)
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
        ports:
          - 5432:5432
        options: >-
          --health-cmd "pg_isready -U postgres"
          --health-interval 10s --health-timeout 5s --health-retries 5
    env:
      RAILS_ENV: test
      DATABASE_HOST: localhost
      DATABASE_PORT: 5432
      DATABASE_USERNAME: postgres
      ELECTRIC_WATER_MANAGEMENT_DATABASE_PASSWORD: postgres
      # Buộc nhánh Selenium Manager: hai đường dẫn không tồn tại → File.exist? trượt
      # → Selenium Manager dò Google Chrome cài sẵn + tải chromedriver khớp.
      CHROMIUM_BINARY: /nonexistent/chromium
      CHROMEDRIVER_BINARY: /nonexistent/chromedriver
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version
          bundler-cache: true
      - name: Set up test database and check for schema drift
        if: ${{ !cancelled() }}
        run: |
          bin/rails db:create db:migrate
          git diff --exit-code db/schema.rb
      - name: Zeitwerk check (autoloading)
        if: ${{ !cancelled() }}
        run: bin/rails zeitwerk:check
      - name: rspec (model, request, and system specs with headless Chrome)
        if: ${{ !cancelled() }}
        run: bundle exec rspec
```

---

## Quyết định (ADR)

### ADR-012: Nội dung CI — phần chạy test
- **Trạng thái:** Accepted · 2026-06-07
- **Bối cảnh:** ADR-011 chốt CI phải chạy test trên pull request; P2 hoãn vì cần Postgres + trình duyệt headless + quyết định runner/cache/headless. Bộ test nhỏ (85 spec, 12 system). `config/database.yml` đã ENV-driven; `system_test_config.rb` đã có nhánh Selenium Manager.
- **Quyết định:**
  1. **Runner native** `ubuntu-latest` + `ruby/setup-ruby@v1` + service container `postgres:16-alpine` + Google Chrome cài sẵn của runner. KHÔNG dùng image Docker của dự án.
  2. **Một job `tests` gộp** chạy lần lượt: kiểm schema không lệch (`db:create db:migrate` + `git diff --exit-code db/schema.rb`), `zeitwerk:check`, rồi `rspec` toàn bộ (gồm system spec).
  3. **Chrome qua Selenium Manager:** ép bằng `CHROMIUM_BINARY`/`CHROMEDRIVER_BINARY` trỏ đường dẫn không tồn tại; tận dụng nhánh lùi sẵn có, **không sửa code test**.
  4. **Bật cache** `bundler-cache: true` ở job mới, và đổi luôn job `ruby-checks` sang cache cho nhất quán.
  5. **Không gem retry** lúc đầu — dựa vào cơ chế chờ sẵn của Capybara; xem lại nếu thực sự chập chờn.
  6. **Chỉ sửa workflow**, không đụng `config/ci.rb` (giữ phạm vi tĩnh cục bộ).
- **Lý do:** Native nhẹ, khớp job tĩnh hiện có, là lựa chọn phổ biến; job gộp đơn giản nhất cho bộ test nhỏ (một trạng thái, một lần dựng DB+gem, ít YAML); Selenium Manager loại bỏ việc ghim chromedriver tay và luôn khớp Chrome của runner; cache cắt thời gian `bundle install`; bỏ qua phức tạp chưa cần (split job, retry gem) theo YAGNI.
- **Tradeoff:** (+) thêm bắt lỗi (test/schema/autoload) trước khi tới khách, chi phí thấp, không phụ thuộc mới. (−) trình duyệt trên runner (Google Chrome) khác Debian chromium bake trong `Dockerfile.dev` — sai khác nhỏ chấp nhận được vì system spec kiểm hành vi, không kiểm pixel; (−) job gộp che thời gian từng phần (đổi lại đơn giản); (−) Selenium Manager tải driver cần mạng (có trên runner) + là điểm chập chờn tiềm tàng.
- **Phương án đã loại:**
  - *Reuse image Docker (`Dockerfile.dev`)* — trình duyệt khớp prod từng byte nhưng mỗi lần CI phải build/pull image + mất cache của `setup-ruby` → nặng, nhiều mảnh hơn.
  - *Tách job fast vs system spec* — lợi wall-clock không đáng với 12 system spec; thêm YAML + lặp dựng DB/setup. Giữ làm đường nâng cấp (Điều kiện xem lại).
  - *Định tuyến workflow qua `bin/ci`/`config/ci.rb`* — serialize, mất job song song + chi tiết từng bước của GitHub; tái-tranh-luận lựa chọn P2.
  - *Gem retry (`rspec-retry`)* — thêm phụ thuộc; chỉ cần khi chứng minh có chập chờn.
  - *apt-install chromium + chromium-driver* — trên Ubuntu mới chromium là snap, cài apt trục trặc; Google Chrome cài sẵn ổn định hơn.
- **Điều kiện xem lại:** thời gian job `tests` quá lâu → tách system spec / chạy song song; system spec chập chờn lặp lại → thêm `rspec-retry` hoặc tinh chỉnh thời gian chờ Capybara; cần khớp trình duyệt prod tuyệt đối → cân nhắc chạy trong image Docker.

### ADR-021: Cắt chi phí & độ trễ CI — path filter cho pull request không đụng code + bỏ trigger `edited`
- **Trạng thái:** Accepted · 2026-06-09
- **Bối cảnh:** Repo private dùng **GitHub Free** (2000 phút Actions/tháng). `ci.yml` chạy trên mỗi pull request; job `tests` ~8 phút (Postgres + headless Chrome), `ruby-checks` ~1.5 phút. Hai nguồn lãng phí: (1) pull request **chỉ sửa tài liệu** vẫn chạy full `tests` + `ruby-checks`; (2) trigger có `edited` → mỗi lần sửa **tiêu đề/mô tả** pull request là **chạy lại toàn bộ CI** (~10 phút). `concurrency: cancel-in-progress` đã bật. Đội than: docs vẫn chạy full test; phút eo hẹp; việc nối tiếp phụ thuộc kẹt chờ ~10 phút CI mới merge được. Đây chính là **Điều kiện xem lại của ADR-012** ("CI quá lâu") cộng góc **chi phí phút**.
- **Quyết định:**
  1. **Path filter fail-safe (native bash).** Thêm job `changes` chạy `.github/scripts/detect-code-changes.sh`: so file thay đổi `base...head`, xuất `code_touched`. Hai job nặng `tests` + `ruby-checks` thêm `needs: changes` + `if: needs.changes.outputs.code_touched == 'true'`. `commitlint` + `branch-source-guard` **luôn chạy** (vài giây). **Fail-safe:** chỉ trả `false` khi MỌI file thay đổi thuộc allowlist docs/meta (`*.md`, `docs/**`, `LICENSE`, `.gitignore`, `.gitattributes`, `.editorconfig`); thiếu SHA / lỗi git / path lạ → `true` ⇒ **không bao giờ bỏ sót test cho thay đổi code**. `.github/workflows/**` và `.github/scripts/**` (không phải `*.md`) tính là code → đổi chính workflow vẫn chạy full để tự kiểm.
  2. **Bỏ `edited` khỏi trigger** → `types: [opened, synchronize, reopened]`. Sửa tiêu đề/mô tả/base pull request không còn chạy lại CI. (`commitlint` lint dải commit, không phụ thuộc mô tả; `branch-source-guard` vẫn chạy ở `opened`/`synchronize`.)
  3. **Giữ `concurrency: cancel-in-progress`** (đã có) — push dồn thì huỷ run cũ.
  4. **KHÔNG split / song song hoá job `tests`.** Split system spec ra job riêng (hoặc `parallel_tests`) giảm wall-clock nhưng **tăng tổng phút bill** (mỗi job trả phí setup Ruby+gem+DB riêng) → sai cho repo free khi **phút là ràng buộc đang siết**. Giữ làm escape hatch của ADR-012 cho khi wall-clock vượt giá trị tiết kiệm phút.
- **Lý do:** Path filter + bỏ `edited` cắt phần lớn phút lãng phí mà **không giảm độ phủ test cho code** (allowlist fail-safe nghiêng về chạy). Native bash khớp ethos "miễn phí trước, không phụ thuộc công cụ bị bỏ rơi" (ADR-007/011), tái dùng pattern `.github/scripts/` của branch-source-guard. Không split vì tối ưu cho **phút** (ràng buộc thật), không phải wall-clock. **Việc nối tiếp phụ thuộc** (kẹt chờ CI để merge) là vấn đề *quy trình*, giải bằng **nhánh xếp chồng** (`CONTRIBUTING.md`) — không đáng đổi phút lấy wall-clock.
- **Tradeoff:** (+) pull request docs gần như 0 phút CI; sửa mô tả pull request không đốt phút; độ phủ code giữ nguyên; native, không phụ thuộc mới. (−) job nặng hiện trạng thái **"skipped"** trên pull request docs — nếu sau này bật branch protection coi chúng *required* thì "skipped" có thể chặn merge (chưa phải vấn đề: ADR-007 CI chỉ hiện trạng thái). (−) allowlist phải bảo trì khi có loại file mới — fail-safe nghiêng "chạy" nên rủi ro chỉ là **chạy thừa**, không **bỏ sót**. (−) đổi base pull request sau khi mở không tự re-check guard (hiếm; push lại là chạy). (−) job `changes` thêm ~20–30s trước khi `tests` bắt đầu trên pull request code (đổi lại tiết kiệm lớn ở pull request docs).
- **Phương án đã loại:**
  - *`dorny/paths-filter`* — robust + chuẩn cộng đồng nhưng thêm **third-party action** (đội đã thay action bằng bash native vì sợ bỏ rơi — ADR-007/011); native + allowlist fail-safe đủ tốt.
  - *`paths-ignore` mức workflow* — bỏ qua **cả** `commitlint` + `branch-source-guard` trên pull request docs → mất lint commit; per-job `if` giữ được các check rẻ.
  - *Split / `parallel_tests` job `tests`* — đổi phút lấy wall-clock, sai ràng buộc free-tier (xem Quyết định 4); để dành escape hatch ADR-012.
  - *Bỏ CI cho pull request docs hẳn / merge không CI* — mất `commitlint` + guard + dấu vết; path filter giữ check rẻ mà vẫn nhanh.
  - *Inline detect trong từng job nặng (không job `changes` riêng)* — lặp logic + không chia sẻ output; một job `changes` gọn hơn.
- **Điều kiện xem lại:** phút Actions vẫn căng sau tối ưu → cân nhắc self-hosted runner hoặc giảm tần suất chạy; wall-clock job `tests` thành nút thắt (vượt giá trị tiết kiệm phút) → bật split/`parallel_tests` theo escape hatch ADR-012; bật GitHub Team + branch protection (required checks) → đổi job nặng từ "skip" sang trạng thái *neutral/success* (vd luôn chạy job nhưng các bước tự no-op khi docs-only) để "skipped" không kẹt merge; allowlist bỏ sót loại file docs mới khiến chạy thừa thường xuyên → bổ sung allowlist.

---

## Tiêu chí thành công (đo được)

- Pull request có lỗi test (model/request/service/system), trôi schema, hoặc lỗi autoload → job `tests` **đỏ**; pull request sạch → **xanh**.
- Lần chạy pull request thật đầu tiên: 12 system spec chạy được với headless Chrome trên runner (Postgres + Chrome) — đây là **xác nhận end-to-end thực sự**.
- Không sửa code ứng dụng / code test; thay đổi thuần workflow + tài liệu.
- Thời gian job `tests` trong ngân sách hợp lý (mục tiêu ~3–5 phút với cache gem ấm).

## Rủi ro & giảm thiểu

| Rủi ro | Giảm thiểu |
|---|---|
| Chrome/chromedriver lệch version trên runner | Ép Selenium Manager (env trỏ đường dẫn không tồn tại) → driver luôn khớp Chrome cài sẵn. Dòng dễ phải chỉnh nhất sau lần chạy đầu — theo dõi log lần chạy pull request đầu. |
| System spec chập chờn | Trước mắt dựa cơ chế chờ của Capybara; nếu lặp lại → `rspec-retry` / tinh chỉnh `default_max_wait_time` (Điều kiện xem lại ADR-012). |
| Job test lâu | Cache gem; nếu vẫn lâu → tách system spec / song song (ADR-011 + ADR-012 đã nêu đường nâng cấp). |
| Selenium Manager cần mạng tải driver | Mạng có sẵn trên runner GitHub; là hành vi mặc định của Selenium, ổn định + có cache. |
| Trình duyệt CI ≠ prod (Chrome vs chromium) | Chấp nhận: system spec kiểm hành vi, không pixel. Cần khớp tuyệt đối → chạy trong image Docker (Điều kiện xem lại). |

## Kiểm chứng

- Chạy **`actionlint`** cục bộ trước khi trình để push (bắt lỗi cú pháp workflow).
- Chạy **`bin/docker rspec`** xác nhận không làm hỏng gì đụng tới.
- **Xác nhận thật = lần chạy pull request đầu tiên**: theo dõi job `tests`, chỉnh dòng Chrome nếu cần (ADR-011 + Heads-up: system spec cần Chrome + Postgres trên runner).

## Truy vết

- Umbrella: [SDLC Overview](2026-06-07-sdlc-overview-design.md) (ADR-001 mô hình, ADR-002 tài liệu/tri thức).
- Mảnh cha: [Quy trình phát hành](2026-06-07-quy-trinh-release-design.md) — **ADR-011** (nội dung CI) + Backlog #1 (mảnh này). ADR-012 ở đây hiện thực phần test mà ADR-011 hoãn.
- Code liên quan: `.github/workflows/ci.yml` (workflow), `config/database.yml` (ENV-driven DB), `spec/support/system_test_config.rb` (driver `:headless_chromium`).

## Changelog

- **0.2.1 (2026-06-13):** Theo ADR-033 (#339): bỏ field frontmatter `status:` (nguồn duy nhất = inline `**Trạng thái:**`); lật trạng thái các ADR đã merge sang `Accepted`.
- **0.2.0 (2026-06-09):** Thêm **ADR-021** (cắt chi phí & độ trễ CI) — path filter fail-safe native bash (`.github/scripts/detect-code-changes.sh` + job `changes`) bỏ qua `tests`/`ruby-checks` cho pull request chỉ sửa docs/meta; bỏ trigger `edited`; giữ `concurrency` + KHÔNG split job `tests` (tối ưu phút, không wall-clock). Hiện thực ở `.github/workflows/ci.yml` + script; ghi chú CONTRIBUTING §8 + mục "nhánh xếp chồng". Kích hoạt từ Điều kiện xem lại của ADR-012.
- **0.1.0 (2026-06-07):** Bản thảo đầu — ADR-012 (runner native + Postgres service container + Chrome qua Selenium Manager; một job `tests` gộp schema-drift + zeitwerk + rspec gồm system; bật cache gem; không gem retry; chỉ sửa workflow). Hiện thực phần chạy test mà ADR-011 hoãn (Backlog #1).
