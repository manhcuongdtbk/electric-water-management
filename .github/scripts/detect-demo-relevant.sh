#!/usr/bin/env bash
# Quyết định một pull request có thể LÀM ĐỔI output của bản demo không, để job
# `Demo recordings (Playwright)` chỉ upload artifact + post comment khi thực sự
# có thể có demo mới — bỏ nhiễu "tưởng có demo mới" trên PR thuần infra (#367,
# Option C). Job vẫn QUAY để verify anti-drift trên mọi code PR (gate qua
# `code_touched`); script này chỉ gate hai bước phụ Upload + Comment.
# Xuất `demo_relevant=true|false` ra $GITHUB_OUTPUT. Xem ADR-021/ADR-036.
#
# FAIL-SAFE: mọi bất định (thiếu SHA, lỗi git, không có diff) → `true` (vẫn
# upload + comment) — thà nhiễu nhẹ còn hơn giấu mất một demo thật sự đổi.
set -uo pipefail

out="${GITHUB_OUTPUT:-/dev/stdout}"
emit() { echo "demo_relevant=$1" >>"$out"; exit 0; }

base="${BASE_SHA:-}"
head="${HEAD_SHA:-}"

# Thiếu thông tin pull request → fail-safe.
[[ -n "$base" && -n "$head" ]] || emit true

# Danh sách file thay đổi (three-dot, khớp "files changed" của GitHub). Lỗi git
# hoặc không có diff (hiếm) → fail-safe.
if ! files="$(git diff --name-only "$base...$head" 2>/dev/null)"; then
  emit true
fi
[[ -n "$files" ]] || emit true

# Có BẤT KỲ file nào thuộc các path mà bản demo lái qua → output demo có thể đổi.
# Lưu ý: trong `case`, `*` khớp cả dấu `/` (giống detect-code-changes.sh), nên
# `app/views/*` phủ toàn bộ cây con.
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  case "$f" in
    spec/demo/*) emit true ;;          # demo spec — nguồn trực tiếp của video
    app/views/*) emit true ;;          # UI hiển thị trong recording
    app/controllers/*) emit true ;;    # luồng demo lái qua
    config/routes.rb) emit true ;;     # đường đi của demo
    db/seeds/demo.rb) emit true ;;     # dữ liệu seed cho demo
    spec/support/*demo*) emit true ;;  # helper/recorder của demo
  esac
done <<<"$files"

# Không file nào chạm vào path demo lái qua → output demo không thể đổi.
emit false
