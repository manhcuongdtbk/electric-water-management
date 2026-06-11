#!/usr/bin/env bash
# Quyết định một pull request có đụng "code" không, để CI bỏ qua các job nặng
# (tests, ruby-checks) khi pull request CHỈ sửa tài liệu/meta. Xuất
# `code_touched=true|false` ra $GITHUB_OUTPUT. Xem ADR-021
# (docs/superpowers/specs/2026-06-07-ci-spec-design.md).
#
# FAIL-SAFE: mọi bất định (thiếu SHA, lỗi git, không có diff, path lạ) → `true`
# (chạy đủ test). Chỉ trả `false` khi MỌI file thay đổi đều thuộc allowlist
# docs/meta — nên không bao giờ bỏ sót test cho một thay đổi code.
set -uo pipefail

out="${GITHUB_OUTPUT:-/dev/stdout}"
emit() { echo "code_touched=$1" >>"$out"; exit 0; }

base="${BASE_SHA:-}"
head="${HEAD_SHA:-}"

# Thiếu thông tin pull request → fail-safe.
[[ -n "$base" && -n "$head" ]] || emit true

# Danh sách file thay đổi của pull request (three-dot: thay đổi của head kể từ
# khi rẽ khỏi base — khớp khái niệm "files changed" của GitHub). Lỗi git → fail-safe.
if ! files="$(git diff --name-only "$base...$head" 2>/dev/null)"; then
  emit true
fi

# Không tính được file nào (hiếm) → fail-safe.
[[ -n "$files" ]] || emit true

# Có BẤT KỲ file nào ngoài allowlist docs/meta → coi như đụng code.
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  case "$f" in
    *.md) ;;                                 # markdown bất kỳ (gồm .github/**/*.md)
    docs/*) ;;                               # toàn bộ cây tài liệu
    LICENSE | LICENSE.*) ;;                  # giấy phép
    .gitignore | .gitattributes | .editorconfig) ;;
    *) emit true ;;                          # còn lại (app/lib/spec/db/config/.github/workflows…) = code
  esac
done <<<"$files"

# Mọi file đều thuộc allowlist → pull request không đụng code.
emit false
