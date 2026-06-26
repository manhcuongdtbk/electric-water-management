// Cấu hình Conventional Commits cho commitlint (ADR-011, ADR-008).
// Mở rộng bộ luật chuẩn config-conventional. CI chạy qua `npx` nên KHÔNG cần
// package.json / node_modules trong repo — chỉ file config nhỏ này.
import { readFileSync } from 'node:fs';

// Đọc danh sách viết tắt được phép từ nguồn duy nhất: docs/THUAT_NGU.md mục 1.
// Chỉ parse bảng trong mục "## 1. Từ viết tắt được phép" (dừng ở heading ## tiếp theo).
// Mỗi dòng `| ABBR |` hoặc `| A, B, C |` → trích cột đầu, chỉ giữ token toàn hoa
// hoặc PascalCase (SemVer) — loại header bảng ("Viết tắt", "Từ", "Khái niệm").
function loadAllowedAbbreviations() {
  try {
    const content = readFileSync('docs/THUAT_NGU.md', 'utf-8');
    const lines = content.split('\n');
    let inSection = false;
    const abbreviations = new Set();
    for (const line of lines) {
      if (/^## 1\.\s/.test(line)) { inSection = true; continue; }
      if (inSection && /^## /.test(line)) break;
      if (!inSection) continue;
      if (!/^\|[^|]+\|/.test(line)) continue;
      if (/^[\s|]*-/.test(line)) continue;
      const firstCell = line.split('|')[1]?.trim();
      if (!firstCell) continue;
      for (const part of firstCell.split(',')) {
        const token = part.trim();
        if (token && /^[A-Z][A-Z0-9a-z-]*$/.test(token)) abbreviations.add(token);
      }
    }
    return abbreviations;
  } catch {
    return new Set();
  }
}

const ALLOWED_ABBREVIATIONS = loadAllowedAbbreviations();

// subject-case rule (config-conventional) cấm chữ đầu subject viết hoa.
// Commit hợp lệ có viết tắt ở đầu subject bị bắt nhầm (vd "docs: ADR-061 ...").
// Hàm này ignore commit khi từ đầu tiên của subject là viết tắt được phép.
function subjectStartsWithAllowedAbbreviation(message) {
  const firstLine = message.split('\n')[0];
  const match = firstLine.match(/^[a-z]+(?:\([^)]*\))?!?:\s+(\S+)/);
  if (!match) return false;
  const firstWord = match[1].replace(/[-:,.!?#()0-9]+$/, '');
  return ALLOWED_ABBREVIATIONS.has(firstWord);
}

export default {
  extends: ['@commitlint/config-conventional'],
  ignores: [
    (message) => message.startsWith('Merge '),
    (message) => message.includes('Signed-off-by: dependabot[bot]'),
    subjectStartsWithAllowedAbbreviation,
  ],
  rules: {
    'body-max-line-length': [0, 'always'],
    'footer-max-line-length': [0, 'always'],
    'type-enum': [2, 'always', [
      'build', 'chore', 'ci', 'docs', 'feat', 'fix',
      'perf', 'refactor', 'release', 'revert', 'style', 'test',
    ]],
  },
};
