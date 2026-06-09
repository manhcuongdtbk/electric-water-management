// Cấu hình Conventional Commits cho commitlint (ADR-011, ADR-008).
// Mở rộng bộ luật chuẩn config-conventional. CI chạy qua `npx` nên KHÔNG cần
// package.json / node_modules trong repo — chỉ file config nhỏ này.
export default {
  extends: ['@commitlint/config-conventional'],
  // Bỏ qua MỌI merge commit. Mặc định của commitlint chỉ bỏ qua message merge
  // chuẩn ("Merge branch ...", "Merge pull request ..."); message merge tự viết
  // (vd khi sync base vào nhánh) sẽ bị lint như commit thường và báo đỏ. Merge
  // commit không phải dòng changelog nên không cần đúng Conventional Commits.
  ignores: [(message) => message.startsWith('Merge ')],
  rules: {
    // Tắt giới hạn độ dài dòng body/footer để không báo sai với URL dài trong
    // body hoặc trailer "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>".
    'body-max-line-length': [0, 'always'],
    'footer-max-line-length': [0, 'always'],
  },
};
