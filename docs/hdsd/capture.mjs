// Chụp toàn bộ ảnh cho hướng dẫn sử dụng.
// Không chạy trực tiếp — dùng docs/hdsd/capture-screenshots.
//
// Thêm/sửa trang: thêm entry vào mảng PAGES bên dưới.
// Thêm/sửa role: thêm entry vào mảng ROLES bên dưới.

import puppeteer from 'puppeteer';
import path from 'path';
import { mkdir } from 'fs/promises';

const BASE = 'http://localhost';
const OUTPUT = 'docs/hdsd/images';
const PW = 'Abc@1234';

await mkdir(OUTPUT, { recursive: true });

// ============================================================
// CẤU HÌNH: Thêm/sửa/xóa trang ở đây
// ============================================================

const ROLES = {
  sa:      { username: 'quanTri',      label: 'Quản trị viên hệ thống' },
  ua_zm:   { username: 'quanTriTD95',  label: 'Quản trị viên đơn vị quản lý khu vực' },
  ua:      { username: 'quanTriTD14',  label: 'Quản trị viên đơn vị' },
  cmd_zm:  { username: 'chiHuyTD95',   label: 'Chỉ huy đơn vị quản lý khu vực' },
  cmd:     { username: 'chiHuyTD14',   label: 'Chỉ huy đơn vị' },
  tech:    { username: 'kyThuat',      label: 'Kỹ thuật viên' },
};

// Mỗi entry: { file, role, url, desc, pre?, viewport? }
// pre: function(page) chạy trước khi chụp (click tab, chọn dropdown...)
// viewport: { width, height } override cho trang cần kích thước đặc biệt
const PAGES = [
  // B — Đăng nhập, đổi mật khẩu
  { file: '01_dang_nhap.png', role: null, url: '/users/sign_in', desc: 'Trang đăng nhập' },
  { file: '74_doi_mat_khau_lan_dau.png', role: 'force_pw', url: null, desc: 'Đổi mật khẩu lần đầu' },
  { file: '49_doi_mat_khau.png', role: 'sa', url: '/password_change/edit', desc: 'Tự đổi mật khẩu' },

  // D — Nhập liệu
  { file: '31_nhap_so_dien_luc_ua_zm.png', role: 'ua_zm', url: '/electricity_supply', desc: 'Nhập số điện lực' },
  { file: '38_chi_so_dau_moi_ua.png', role: 'ua', url: '/meter_entries', desc: 'Chỉ số đầu mối' },
  { file: '06_chi_so_dau_moi_sa.png', role: 'sa', url: '/meter_entries', desc: 'Chỉ số đầu mối SA' },
  { file: '30_chi_so_bom_nuoc_ua_zm.png', role: 'ua_zm', url: '/pump_entries', desc: 'Chỉ số bơm nước' },

  // E — Xem kết quả
  { file: '02_tong_quan_sa.png', role: 'sa', url: null, desc: 'Tổng quan SA' },
  { file: '36_tong_quan_ua.png', role: 'ua', url: null, desc: 'Tổng quan UA' },
  { file: '03_bang_tinh_tien_sa.png', role: 'sa', url: '/billing', desc: 'Bảng tính tiền SA',
    viewport: { width: 1440, height: 900 }, useBillingCapture: true },
  { file: '45_bang_tinh_tien_cmd.png', role: 'cmd', url: '/billing', desc: 'Bảng tính tiền CMD',
    viewport: { width: 1440, height: 900 }, useBillingCapture: true },
  { file: '04_tra_cuu_lich_su_sa.png', role: 'sa', url: '/history', desc: 'Tra cứu lịch sử — So sánh 2 kỳ' },
  { file: '75_tra_cuu_theo_khoang_thoi_gian.png', role: 'sa', url: '/history', desc: 'Tra cứu lịch sử — Theo khoảng thời gian',
    pre: async (page) => {
      const tabs = await page.$$('a, button');
      for (const tab of tabs) {
        const text = await page.evaluate(el => el.textContent.trim(), tab);
        if (text.includes('Theo khoảng thời gian')) { await tab.click(); await sleep(1000); break; }
      }
    }
  },

  // F1 — Đầu mối
  { file: '39_dau_moi_ua.png', role: 'ua', url: '/contact_points', desc: 'Đầu mối danh sách' },
  { file: '09_dau_moi_tao_sinh_hoat.png', role: 'sa', url: '/contact_points/new', desc: 'Tạo đầu mối sinh hoạt',
    viewport: { width: 1440, height: 1600 },
    pre: async (page) => {
      await page.select('select[name="contact_point[contact_point_type]"]', 'residential');
      await sleep(1500);
    }
  },
  { file: '10_dau_moi_tao_cong_cong.png', role: 'sa', url: '/contact_points/new', desc: 'Tạo đầu mối công cộng',
    viewport: { width: 1440, height: 1200 },
    pre: async (page) => {
      await page.select('select[name="contact_point[contact_point_type]"]', 'public');
      await sleep(1500);
      const zoneRadio = await page.$('input[type="radio"][value="zone"]');
      if (zoneRadio) { await zoneRadio.click(); await sleep(1000); }
    }
  },
  { file: '11_dau_moi_tao_bom_nuoc.png', role: 'sa', url: '/contact_points/new', desc: 'Tạo đầu mối bơm nước',
    pre: async (page) => {
      await page.select('select[name="contact_point[contact_point_type]"]', 'water_pump');
      await sleep(1500);
    }
  },
  { file: '12_dau_moi_tao_ngoai_bien_che.png', role: 'sa', url: '/contact_points/new', desc: 'Tạo đầu mối ngoài biên chế',
    pre: async (page) => {
      await page.select('select[name="contact_point[contact_point_type]"]', 'non_establishment');
      await sleep(1500);
    }
  },
  { file: '52_dau_moi_tao_sinh_hoat_ua_zm.png', role: 'ua_zm', url: '/contact_points/new?contact_point_type=residential', desc: 'Tạo đầu mối sinh hoạt UA-ZM' },

  // F2 — Khối, nhóm
  { file: '14_khoi_danh_sach.png', role: 'sa', url: '/blocks', desc: 'Khối' },
  { file: '15_nhom_danh_sach.png', role: 'sa', url: '/groups', desc: 'Nhóm' },

  // F3 — Cấu hình đơn vị
  { file: '59_cau_hinh_don_vi_ua.png', role: 'ua_zm', url: '/unit_config', desc: 'Cấu hình đơn vị',
    viewport: { width: 1440, height: 1400 } },

  // F4 — Khu vực
  { file: '17_khu_vuc_danh_sach.png', role: 'sa', url: '/zones', desc: 'Khu vực danh sách' },
  { file: '18_khu_vuc_tao_moi.png', role: 'sa', url: '/zones/new', desc: 'Tạo khu vực' },
  { file: '19_khu_vuc_sua.png', role: 'sa', url: '/zones', desc: 'Sửa khu vực',
    pre: async (page) => {
      const link = await page.$('a[href*="/zones/"][href*="/edit"]');
      if (link) { await link.click(); await page.waitForNavigation({ waitUntil: 'networkidle0' }).catch(() => {}); }
      await sleep(500);
    }
  },

  // F5 — Đơn vị
  { file: '20_don_vi_danh_sach.png', role: 'sa', url: '/units', desc: 'Đơn vị danh sách' },
  { file: '76_don_vi_tao_moi.png', role: 'sa', url: '/units/new', desc: 'Tạo đơn vị' },

  // F6 — Phân bổ bơm nước
  { file: '21_phan_bo_bom_nuoc_sa.png', role: 'sa', url: '/pump_allocations', desc: 'Phân bổ bơm nước' },

  // F7 — Đơn giá điện
  { file: '22_don_gia_dien.png', role: 'sa', url: '/pricing', desc: 'Đơn giá điện' },

  // F8 — Nhóm cấp bậc
  { file: '23_nhom_cap_bac.png', role: 'sa', url: '/ranks', desc: 'Nhóm cấp bậc' },

  // G1 — Tài khoản
  { file: '24_tai_khoan_danh_sach.png', role: 'sa', url: '/users', desc: 'Tài khoản' },

  // G2 — Nhật ký
  { file: '77_nhat_ky_hoat_dong.png', role: 'sa', url: '/audit_logs', desc: 'Nhật ký hoạt động' },

  // G3 — Sao lưu
  { file: '47_sao_luu_tech.png', role: 'tech', url: '/backups', desc: 'Sao lưu' },
];

// ============================================================
// ENGINE (không cần sửa trừ khi đổi cách chụp)
// ============================================================

const sleep = ms => new Promise(r => setTimeout(r, ms));

const browser = await puppeteer.launch({
  headless: true,
  args: ['--no-sandbox'],
  defaultViewport: { width: 1440, height: 3000, deviceScaleFactor: 2 },
});

// Cache context per role (tránh login lại)
const contexts = {};

async function getPage(roleKey) {
  if (contexts[roleKey]) return contexts[roleKey];

  const context = await browser.createBrowserContext();
  const page = await context.newPage();

  const role = ROLES[roleKey];
  await page.goto(`${BASE}/users/sign_in`, { waitUntil: 'networkidle0' });
  await page.waitForSelector('#user_username', { timeout: 10000 });
  await page.type('#user_username', role.username);
  await page.type('#user_password', PW);
  await page.click('[type="submit"]');
  await page.waitForNavigation({ waitUntil: 'networkidle0' }).catch(() => {});

  const url = page.url();
  if (url.includes('sign_in')) throw new Error(`Login FAILED: ${role.username}`);

  contexts[roleKey] = { context, page };
  return { context, page };
}

async function measureFitHeight(page) {
  return page.evaluate(() => {
    let max = 0;
    document.querySelectorAll('aside a, nav a, aside span, nav span, main *').forEach(el => {
      const r = el.getBoundingClientRect();
      if (r.height > 0 && r.height < 500 && r.bottom > max) max = r.bottom;
    });
    return Math.ceil(max) + 20;
  });
}

async function injectScrollbar(page) {
  await page.evaluate(() => {
    const s = document.createElement('style');
    s.textContent = `
      ::-webkit-scrollbar { -webkit-appearance: none; width: 12px; height: 12px; }
      ::-webkit-scrollbar-thumb { background: #999; border-radius: 6px; }
      ::-webkit-scrollbar-track { background: #eee; }
    `;
    document.head.appendChild(s);
  });
}

async function captureBilling(page, filepath) {
  // Bảng tính tiền: viewport cao để thấy hết dòng, rộng 1440 để scroll ngang tự nhiên
  await page.setViewport({ width: 1440, height: 3000, deviceScaleFactor: 2 });
  await sleep(500);
  await injectScrollbar(page);

  // Bỏ h-screen + overflow để đo đúng
  await page.evaluate(() => {
    document.body.style.height = 'auto';
    document.body.classList.remove('h-screen');
    const flex = document.querySelector('.flex.flex-1.overflow-hidden');
    if (flex) { flex.style.overflow = 'visible'; flex.classList.remove('overflow-hidden'); }
    const main = document.querySelector('main');
    if (main) { main.style.overflow = 'visible'; main.classList.remove('overflow-y-auto'); }
  });
  await sleep(300);

  const info = await page.evaluate(() => {
    const main = document.querySelector('main');
    const allChildren = main ? Array.from(main.querySelectorAll('*')) : [];
    let maxBottom = 0;
    allChildren.forEach(el => {
      const rect = el.getBoundingClientRect();
      if (rect.bottom > maxBottom) maxBottom = rect.bottom;
    });
    return { maxBottom: Math.ceil(maxBottom) };
  });

  await page.setViewport({ width: 1440, height: info.maxBottom + 20, deviceScaleFactor: 2 });
  await sleep(200);
  await page.screenshot({ path: filepath });
}

async function captureForcePasswordChange(filepath) {
  // Tạo tài khoản tạm, đăng nhập, chụp trang đổi mật khẩu lần đầu
  const { page: saPage } = await getPage('sa');
  await saPage.goto(`${BASE}/users`, { waitUntil: 'networkidle0' });

  // Tạo qua Rails runner (nhanh hơn UI)
  const { execSync } = await import('child_process');
  try {
    execSync(`docker compose -f compose.dev.yml exec -T app bin/rails runner "
      User.find_by(username: 'tmpScreenshot')&.destroy
      User.create!(username: 'tmpScreenshot', password: 'Abc@1234', password_confirmation: 'Abc@1234',
        display_name: 'Tài khoản tạm', role: :unit_admin, unit: Unit.first, force_password_change: true)
    "`, { stdio: 'pipe' });
  } catch { /* ignore */ }

  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  await page.goto(`${BASE}/users/sign_in`, { waitUntil: 'networkidle0' });
  await page.waitForSelector('#user_username', { timeout: 10000 });
  await page.type('#user_username', 'tmpScreenshot');
  await page.type('#user_password', PW);
  await page.click('[type="submit"]');
  await page.waitForNavigation({ waitUntil: 'networkidle0' }).catch(() => {});
  await sleep(500);

  // Đo + chụp (không có sidebar)
  const h = await page.evaluate(() => {
    let max = 0;
    document.querySelectorAll('body *').forEach(el => {
      const r = el.getBoundingClientRect();
      if (r.height > 0 && r.bottom > max) max = r.bottom;
    });
    return Math.ceil(max) + 20;
  });
  await page.setViewport({ width: 1440, height: h, deviceScaleFactor: 2 });
  await sleep(200);
  await page.screenshot({ path: filepath });
  await context.close();

  // Xóa tài khoản tạm
  try {
    execSync(`docker compose -f compose.dev.yml exec -T app bin/rails runner "User.find_by(username: 'tmpScreenshot')&.destroy"`, { stdio: 'pipe' });
  } catch { /* ignore */ }
}

// ============================================================
// CHẠY
// ============================================================

let count = 0;
let errors = [];

for (const entry of PAGES) {
  const filepath = path.join(OUTPUT, entry.file);

  try {
    // Trang đăng nhập (không cần login)
    if (entry.role === null) {
      const context = await browser.createBrowserContext();
      const page = await context.newPage();
      await page.goto(`${BASE}${entry.url}`, { waitUntil: 'networkidle0' });
      await sleep(500);
      const h = await page.evaluate(() => {
        let max = 0;
        document.querySelectorAll('body *').forEach(el => {
          const r = el.getBoundingClientRect();
          if (r.height > 0 && r.bottom > max) max = r.bottom;
        });
        return Math.ceil(max) + 20;
      });
      await page.setViewport({ width: 1440, height: h, deviceScaleFactor: 2 });
      await sleep(200);
      await page.screenshot({ path: filepath });
      await context.close();

    // Đổi mật khẩu lần đầu (flow đặc biệt)
    } else if (entry.role === 'force_pw') {
      await captureForcePasswordChange(filepath);

    // Bảng tính tiền (cần xử lý đặc biệt)
    } else if (entry.useBillingCapture) {
      // Billing cần context mới (vì sửa DOM)
      const context = await browser.createBrowserContext();
      const page = await context.newPage();
      const role = ROLES[entry.role];
      await page.goto(`${BASE}/users/sign_in`, { waitUntil: 'networkidle0' });
      await page.waitForSelector('#user_username', { timeout: 10000 });
      await page.type('#user_username', role.username);
      await page.type('#user_password', PW);
      await page.click('[type="submit"]');
      await page.waitForNavigation({ waitUntil: 'networkidle0' }).catch(() => {});
      await page.goto(`${BASE}${entry.url}`, { waitUntil: 'networkidle0' });
      await sleep(1500);
      await captureBilling(page, filepath);
      await context.close();

    // Trang thường
    } else {
      const { page } = await getPage(entry.role);

      // Viewport mặc định cao để đo
      const vp = entry.viewport || { width: 1440, height: 3000 };
      await page.setViewport({ ...vp, deviceScaleFactor: 2 });

      if (entry.url) {
        await page.goto(`${BASE}${entry.url}`, { waitUntil: 'networkidle0' });
        await sleep(800);
      }
      if (entry.pre) await entry.pre(page);

      await injectScrollbar(page);

      // Đo vừa khít
      const fitHeight = await measureFitHeight(page);
      const finalHeight = Math.max(fitHeight, vp.height === 3000 ? 0 : vp.height);
      await page.setViewport({ width: vp.width || 1440, height: finalHeight, deviceScaleFactor: 2 });
      await sleep(200);
      await page.screenshot({ path: filepath, fullPage: entry.viewport ? true : false });
    }

    count++;
    console.log(`  [${String(count).padStart(2, '0')}] ${entry.file} — ${entry.desc}`);

  } catch (err) {
    errors.push({ file: entry.file, error: err.message });
    console.error(`  ❌ ${entry.file} — ${err.message}`);
  }
}

// Cleanup
for (const { context } of Object.values(contexts)) {
  await context.close().catch(() => {});
}
await browser.close();

console.log(`\n${count}/${PAGES.length} ảnh chụp thành công.`);
if (errors.length) {
  console.log(`${errors.length} lỗi:`);
  errors.forEach(e => console.log(`  ${e.file}: ${e.error}`));
}
