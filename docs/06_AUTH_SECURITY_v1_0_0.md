# 06 — Xác thực, phân quyền và bảo mật

> **Phiên bản:** v1.0.0 — 01/05/2026
>
> **Đọc lần đầu?** Đọc 01_OVERVIEW trước để hiểu dự án là gì. Tra thuật ngữ tại 02_GLOSSARY.
>
> **Mục đích file này:** Tài liệu chi tiết xác thực, phân quyền, và bảo mật hệ thống.
>
> **Đối tượng đọc:** Developer cần hiểu security model, hoặc đội kỹ thuật cần audit bảo mật.
>
> **Schema User:** Xem 04_DATABASE_MODELS mục 2.2.
>
> **4 vai trò:** Xem 02_GLOSSARY mục 7.

---

## Mục lục

1. [Tổng quan kiến trúc bảo mật](#1-tổng-quan-kiến-trúc-bảo-mật)
2. [Devise — cấu hình xác thực](#2-devise--cấu-hình-xác-thực)
3. [CanCanCan — phân quyền chi tiết](#3-cancancan--phân-quyền-chi-tiết)
4. [Authorization patterns trong controllers](#4-authorization-patterns-trong-controllers)
5. [Security hardening — lịch sử PR](#5-security-hardening--lịch-sử-pr)
6. [Bảo mật mạng và hạ tầng](#6-bảo-mật-mạng-và-hạ-tầng)
7. [PaperTrail — audit trail](#7-papertrail--audit-trail)
8. [TODO — sai lệch giữa code và docs](#todo--sai-lệch-giữa-code-và-docs)

---

## 1. Tổng quan kiến trúc bảo mật

Hệ thống có 4 lớp bảo vệ, xếp theo chiều từ ngoài vào trong:

| Lớp | Cơ chế | Mục đích |
|---|---|---|
| Mạng / hạ tầng | Nginx + force_ssl + Rack::Attack + meta noindex | Chặn crawler, throttle login brute-force, ép HTTPS, bảo vệ bot probing |
| Xác thực (authentication) | Devise (`database_authenticatable`, `lockable`, `timeoutable`, `trackable`, `rememberable`, `validatable`) | Xác minh "user là ai" — email + bcrypt password, khóa sau 5 lần sai, timeout 2 giờ |
| Phân quyền (authorization) | CanCanCan `Ability` class | Trả lời "user này được làm gì" — 4 role với scope khác nhau |
| Audit | PaperTrail trên 13 model nghiệp vụ | Ghi lại "ai sửa gì, lúc nào, cũ→mới" để tra cứu sau sự cố |

Không có cơ chế MFA (multi-factor authentication) — phạm vi giai đoạn 1 không yêu cầu. Reset mật khẩu không qua email mà qua rake task `admin:reset_password` do admin_level1 hoặc tech chạy trên Mini PC production (xem `05_BUSINESS_LOGIC` mục 7.2).

---

## 2. Devise — cấu hình xác thực

File cấu hình: `config/initializers/devise.rb`. Khai báo modules trong: `app/models/user.rb` dòng 2–3.

### 2.1 Modules enabled

```ruby
# app/models/user.rb
devise :database_authenticatable, :rememberable, :validatable,
       :trackable, :lockable, :timeoutable
```

| Module | Mục đích | Config liên quan |
|---|---|---|
| `database_authenticatable` | Lưu password bcrypt vào DB, xác minh khi đăng nhập. | `config.stretches = 12` (cost factor bcrypt; test env = 1 cho nhanh). |
| `rememberable` | Cookie "Remember me" giữ session sau khi đóng trình duyệt. | `config.expire_all_remember_me_on_sign_out = true` — sign out invalidate tất cả remember token. Mặc định `remember_for = 2.weeks`. |
| `validatable` | Validate format email + độ dài password. | `config.password_length = 8..128`, `config.email_regexp = /\A[^@\s]+@[^@\s]+\z/`. |
| `trackable` | Ghi nhận `sign_in_count`, `current_sign_in_at`, `last_sign_in_at`, `current_sign_in_ip`, `last_sign_in_ip`. | Không cần config thêm. |
| `lockable` | Khóa tài khoản sau N lần nhập sai mật khẩu. F17. | `config.lock_strategy = :failed_attempts`, `config.unlock_strategy = :none`, `config.maximum_attempts = 5`, `config.last_attempt_warning = true`. Xem 2.3. |
| `timeoutable` | Tự đăng xuất sau X thời gian không hoạt động. | `config.timeout_in = 2.hours`. Xem 2.5. |

**Modules KHÔNG bật (cố ý):**

- `recoverable` — đã gỡ trong PR#34 (commit `c9e1831`). Lý do: phần mềm chạy nội bộ trên LAN/Mini PC, không có SMTP relay. Reset mật khẩu qua rake task `admin:reset_password`. Cột `reset_password_token` và `reset_password_sent_at` vẫn còn trong DB từ migration ban đầu, nhưng không có flow nào ghi/đọc.
- `registerable` — không cho user tự đăng ký. Tài khoản do tech (F15) tạo.
- `confirmable` — không cần email confirmation, đã có flow F18 force change password lần đầu.
- `omniauthable` — không cần SSO bên ngoài.

### 2.2 F16 — Đăng nhập

**Routes:** mount tại `config/routes.rb:2` (`devise_for :users`). Đường dẫn chuẩn của Devise:
- `GET /users/sign_in` — form đăng nhập
- `POST /users/sign_in` — submit
- `DELETE /users/sign_out` — đăng xuất (`config.sign_out_via = :delete`)

**Custom views Vietnamese (PR#34, commit `195c6db`):** Devise mặc định render bằng tiếng Anh. Project tạo views custom trong `app/views/devise/sessions/` để hiển thị tiếng Việt + Tailwind. Locale `config/locales/vi.yml` chứa các string Devise (errors, flash messages).

**Flow sau khi đăng nhập** (`app/controllers/application_controller.rb:36–48`):

```ruby
def after_sign_in_path_for(resource)
  post_sign_in_destination_for(resource)
end

def post_sign_in_destination_for(user)
  if user.force_password_change?
    edit_password_change_path        # F18 — bắt buộc đổi mật khẩu trước
  elsif user.tech?
    users_path                        # tech vào thẳng F15
  else
    stored_location_for(user) || root_path  # admin_level1/admin_unit/commander → dashboard
  end
end
```

`stored_location_for` của Devise: nếu user truy cập `/contact_points` khi chưa đăng nhập, Devise lưu URL gốc, sau khi đăng nhập sẽ redirect về đó.

### 2.3 F17 — Khóa tài khoản (Lockable)

**Cơ chế của Devise** (`config/initializers/devise.rb:198–201`):

- `lock_strategy = :failed_attempts` — đếm số lần nhập sai mật khẩu liên tiếp.
- `maximum_attempts = 5` — ngưỡng khóa.
- `unlock_strategy = :none` — không tự mở khóa qua thời gian hay token email. Phải tech mở khóa qua F15 hoặc rake task.
- `last_attempt_warning = true` — sau lần sai thứ 4, Devise hiển thị cảnh báo "lần thử cuối".

Khi đạt 5 lần sai:
1. Devise tự gọi `user.lock_access!` → set `locked_at = Time.current`.
2. Lần đăng nhập tiếp theo, Devise check `locked_at` → từ chối, hiển thị flash `Tài khoản đã bị khóa do nhập sai mật khẩu quá nhiều lần. Vui lòng liên hệ quản trị viên.` (`config/locales/vi.yml:93`).

**Manual lock/unlock qua F15** (`app/controllers/users_controller.rb:47–61`):

```ruby
def lock
  if @user == current_user
    redirect_to users_path, alert: t("flash.users.cannot_lock_self")
  elsif @user.last_active_admin_level1?
    redirect_to users_path, alert: t("flash.users.cannot_lock_last_admin")
  else
    @user.lock_access!(send_instructions: false)
    ...
end

def unlock
  @user.unlock_access!  # Devise: clear locked_at + failed_attempts
  ...
end
```

**Bảo vệ `admin_level1` cuối cùng — 3 lớp** (chi tiết tại 04_DATABASE_MODELS mục 2.2). Lý do nghiệp vụ: nếu khóa hết admin_level1 thì không còn ai mở khóa được, hệ thống bị deadlock. Ba cơ chế chồng nhau bịt mọi đường khóa:

| Cơ chế | Vị trí code | Block hành vi nào |
|---|---|---|
| Validation `prevent_locking_last_admin_level1` | `user.rb:20, 63–69` | Manual save (set `locked_at` qua `update`/`save`). Chạy trước commit DB. |
| Callback `before_destroy :prevent_destroying_last_admin_level1` | `user.rb:23, 71–76` | Xóa user qua `destroy`. `throw(:abort)` để rollback. |
| Override `lock_access!` ghi log warning | `user.rb:36–45` | Auto-lock do Devise gọi (5 lần sai). **Không chặn** — vì có thể là tấn công thật, chặn đồng nghĩa với hỗ trợ bypass lockable. Chỉ log `[SECURITY] Last active admin_level1 ... auto-locked ...` để tech/oncall thấy và chạy rake task `admin:reset_password` recover. |

**Tại sao không chặn auto-lock?** Nếu chặn, attacker có thể bombard sai mật khẩu rồi tài khoản admin_level1 vẫn unlocked → có thể tiếp tục thử. Devise vẫn auto-lock để chặn brute-force, ta dựa vào escape hatch (rake task chạy trên server) để recover.

`UsersController#lock` thì ngược lại: chặn mọi lần admin manual khóa admin_level1 cuối cùng — vì hành động này luôn là nhầm hoặc cố ý gây hại, không có lý do hợp lệ.

### 2.4 F18 — Bắt buộc đổi mật khẩu lần đầu

**Cột DB:** `users.force_password_change boolean default true not null` (xem 04_DATABASE_MODELS mục 2.2).

**Khi nào set `force_password_change = true`:**
- Migration default cho user mới.
- Khi tech tạo user qua F15 (cột default).
- Khi tech đổi mật khẩu cho user khác qua F15: `app/controllers/users_controller.rb:33–35`:
  ```ruby
  if @user != current_user && params.dig(:user, :password).present?
    @user.force_password_change = true
  end
  ```
  → Mật khẩu tạm do tech cấp, user phải tự đổi khi đăng nhập lại.

**Routes** (`config/routes.rb:9`): `resource :password_change, only: [:edit, :update]` → `GET /password_change/edit`, `PATCH /password_change`.

**Redirect ép buộc** (`app/controllers/application_controller.rb:7, 50–55`):

```ruby
before_action :check_force_password_change!

def check_force_password_change!
  return unless current_user&.force_password_change?
  return if controller_name == "password_changes"
  redirect_to edit_password_change_path, alert: t("flash.password_changes.required")
end
```

Mọi request từ user có `force_password_change = true` đều bị bounce về form đổi mật khẩu — trừ khi đang ở chính `PasswordChangesController` (tránh redirect loop).

**Flow đổi mật khẩu** (`app/controllers/password_changes_controller.rb:6–22`):

```ruby
def update
  @user = current_user
  attrs = password_change_params
  if @user.update(
    password: attrs[:password],
    password_confirmation: attrs[:password_confirmation],
    force_password_change: false
  )
    bypass_sign_in(@user)  # tránh logout sau khi rotate authenticatable_salt
    redirect_to root_path, notice: t("flash.password_changes.success")
  else
    render :edit, status: :unprocessable_entity
  end
end
```

`bypass_sign_in` (Devise helper) refresh session sau khi password đổi — không có nó, Devise tự đăng xuất user vì authenticatable_salt rotate.

### 2.5 Session timeout (Timeoutable)

**Config:** `config.timeout_in = 2.hours` (`config/initializers/devise.rb:194`). Lịch sử: PR#22 ban đầu set 30 phút, PR#27 (`d0fbcb5`) tăng lên 2 giờ vì khách quân đội cần thời gian dài hơn để xử lý số liệu.

**Cơ chế:** Devise lưu `last_request_at` trong session warden. Mỗi request, Devise check `Time.current - last_request_at > timeout_in` → force sign-out.

**Modal cảnh báo + extend session** (PR#28, commit `b720583`):

- Layout `app/views/layouts/application.html.erb:18–25` mount Stimulus controller `session-timeout` với `expires-at-value` = thời điểm session sẽ hết.
- Stimulus controller (file `app/javascript/controllers/session_timeout_controller.js`) hiển thị modal trước khi hết hạn 2 phút, có 2 nút: "Tiếp tục" (gọi `POST /sessions/extend`) và "Đăng xuất" (gọi `DELETE /users/sign_out`).
- Endpoint `SessionsController#extend_session` (`app/controllers/sessions_controller.rb:5–13`):
  ```ruby
  def extend_session
    unless user_signed_in?
      head :unauthorized; return
    end
    warden.session(:user)["last_request_at"] = Time.current.utc.to_i
    head :no_content
  end
  ```
  → Update `last_request_at` thủ công, không tải lại trang.
- Routes: `post "sessions/extend"` (`config/routes.rb:5`).

Helper `session_expires_at` ở ApplicationController dòng 27–34 đọc `last_request_at` để Stimulus controller biết khi nào hiển thị warning.

### 2.6 Password complexity

**Validation custom** (`app/models/user.rb:19, 56–61`):

```ruby
validate :password_complexity

def password_complexity
  return if password.blank?
  return if password.match?(/\A(?=.*[A-Za-z])(?=.*\d).+\z/)
  errors.add(:password, :complexity)
end
```

→ Nếu password được set, phải có **ít nhất 1 chữ cái VÀ 1 số**. Devise `validatable` thêm: 8..128 ký tự + format email.

`return if password.blank?` quan trọng: khi user update profile (đổi tên, không đổi password), `password` là `nil`, validation skip.

i18n key: `activerecord.errors.models.user.attributes.password.complexity` (file `vi.yml`) — message gì hiển thị cho user.

**Phương án rejected:** Không yêu cầu ký tự đặc biệt hoặc viết hoa — khách quân đội nhập trên màn hình chia sẻ, password phức tạp hơn dễ bị từ chối hoặc gây frustration. Quân đội thường dùng password đơn giản dễ nhớ — yêu cầu phải có cả chữ và số đã đủ block các password yếu thường gặp như "12345678" hoặc "password".

### 2.7 Remember me (Rememberable)

Cookie "Remember me" tự đăng nhập sau khi đóng browser, default `remember_for = 2.weeks`. Khách hiện chưa yêu cầu tùy chỉnh.

`config.expire_all_remember_me_on_sign_out = true` (`devise.rb:173`) — khi user sign out, mọi remember token bị invalidate. Bảo vệ trường hợp user đăng xuất từ máy A nhưng cookie ở máy B vẫn nhận diện.

DB column `remember_created_at` thêm trong migration `20260413162304` (xem 04_DATABASE_MODELS mục 5).

### 2.8 Trackable

Devise tự update các cột `sign_in_count`, `current_sign_in_at`, `last_sign_in_at`, `current_sign_in_ip`, `last_sign_in_ip` mỗi lần đăng nhập. Không cần config.

**Hệ quả:** Mỗi lần user đăng nhập, `users` row được UPDATE → PaperTrail ghi version. Đây là **noise** trong audit log F19 — xem mục TODO #1 cuối file.

### 2.9 Bảo vệ admin_level1 cuối cùng — chi tiết

**Helper:** `User#last_active_admin_level1?` (`user.rb:30–32`):

```ruby
def last_active_admin_level1?
  admin_level1? && User.where(role: :admin_level1).where(locked_at: nil)
                       .where.not(id: id).count == 0
end
```

→ true nếu user này là admin_level1 chưa bị khóa, và không còn admin_level1 nào khác active.

**Ba lớp dùng helper này:**

```ruby
# Layer 1 — model validation (chặn manual update locked_at)
validate :prevent_locking_last_admin_level1, if: :will_save_change_to_locked_at?

def prevent_locking_last_admin_level1
  return if locked_at_was.present?  # đã locked rồi, đây là unlock — bỏ qua
  return if locked_at.nil?           # đang unlock — bỏ qua
  return unless last_active_admin_level1?
  errors.add(:base, :last_admin_lock)
end

# Layer 2 — model callback (chặn destroy)
before_destroy :prevent_destroying_last_admin_level1

def prevent_destroying_last_admin_level1
  return unless last_active_admin_level1?
  errors.add(:base, :last_admin_destroy)
  throw(:abort)
end

# Layer 3 — controller guard (chặn UI lock button) — UsersController#lock
elsif @user.last_active_admin_level1?
  redirect_to users_path, alert: t("flash.users.cannot_lock_last_admin")
```

**Tại sao 3 lớp?**

- Validation chặn `update(locked_at: ...)` thường, nhưng Devise auto-lock dùng `save(validate: false)` để bypass validation. → Cần controller guard cho hành động manual; auto-lock phải qua override `lock_access!` (chỉ log, không chặn).
- Callback `before_destroy` chặn `destroy` ngay cả khi gọi từ console hoặc rake task.
- Controller guard cho thông báo UX rõ ràng — không phải lỗi validation generic.

**Escape hatch:** rake task `admin:reset_password[email]` (xem 05_BUSINESS_LOGIC mục 7.2). Tech chạy trên server (`docker compose exec web rails 'admin:reset_password[admin@example.com]'`) để mở khóa admin_level1 đã bị auto-lock + reset mật khẩu thành cấu hình mới + set `force_password_change = true` để admin tự đổi khi đăng nhập lại.

---

## 3. CanCanCan — phân quyền chi tiết

File: `app/models/ability.rb`. Toàn bộ phân quyền tập trung trong 1 class — không có policy file riêng.

### 3.1 Cấu trúc Ability

```ruby
class Ability
  include CanCan::Ability

  def initialize(user)
    return unless user
    case user.role.to_sym
    when :admin_level1 then admin_level1_abilities
    when :admin_unit   then admin_unit_abilities(user)
    when :commander    then commander_abilities(user)
    when :tech         then tech_abilities
    end
  end
  ...
end
```

**Quy ước quan trọng:** Tất cả conditions dùng **hash conditions** (`organization_id: org_id`), KHÔNG dùng block. Lý do: chỉ hash conditions mới hỗ trợ `accessible_by(current_ability)` để filter scope ở DB level. Nếu dùng block, CanCanCan phải load tất cả record rồi filter Ruby — chậm và không scale.

### 3.2 admin_level1 — Quản trị viên cấp 1 (Ban Doanh trại)

```ruby
def admin_level1_abilities
  can :manage, :all
  cannot :update_unit_config, UnitConfig
  cannot :manage, :backup
end
```

| Permission | Subject | Giải thích nghiệp vụ | F# |
|---|---|---|---|
| `can :manage, :all` | Tất cả model + symbol | Quyền tối cao toàn hệ thống. Xem được data tất cả 13 đơn vị. | F01–F21 |
| `cannot :update_unit_config, UnitConfig` | UnitConfig | Phần "tỷ lệ công cộng đơn vị" thuộc thẩm quyền admin_unit. admin_level1 vẫn cấu hình tỷ lệ tiết kiệm + công cộng Sư đoàn qua `:update`, nhưng không can thiệp tỷ lệ riêng từng đơn vị. | F04 |
| `cannot :manage, :backup` | Symbol `:backup` | Sao lưu/phục hồi là nghiệp vụ IT (`tech`), không phải nghiệp vụ điện. Phân tách trách nhiệm: admin_level1 quản lý số liệu, tech quản lý hạ tầng. | — |

**Ghi chú:** Vì `can :manage, :all`, admin_level1 **cũng** có quyền F15 (quản lý tài khoản) và F19 (audit log). Đây là side effect có chủ đích — admin_level1 là người dùng quyền lực nhất, có thể ghi đè tech khi cần. Tech vẫn là người vận hành chính của F15 và F19.

### 3.3 admin_unit — Quản trị viên đơn vị

```ruby
def admin_unit_abilities(user)
  org_id = user.organization_id

  can :manage, ContactPoint,       organization_id: org_id
  can :manage, Meter,              organization_id: org_id
  can :manage, Personnel,          contact_point: { organization_id: org_id }
  can :manage, MeterReading,       meter: { organization_id: org_id }
  can :read,        MonthlyCalculation, contact_point: { organization_id: org_id }
  can :recalculate, MonthlyCalculation, contact_point: { organization_id: org_id }

  can :read, UnitConfig, organization_id: org_id
  can :update_unit_config,        UnitConfig, organization_id: org_id
  can :update_electricity_supply, UnitConfig, organization_id: org_id

  can :read, MonthlyPeriod
  can :read, RankQuota
end
```

| Permission | Subject | Condition | Giải thích nghiệp vụ | F# |
|---|---|---|---|---|
| `can :manage` | `ContactPoint` | `organization_id: org_id` | CRUD đầu mối **trong đơn vị mình**. Không thấy đầu mối đơn vị khác. | F01 |
| `can :manage` | `Meter` | `organization_id: org_id` | CRUD công tơ trong đơn vị mình. Trùng cột `organization_id` (Meter denormalize từ ContactPoint). | F02 |
| `can :manage` | `Personnel` | `contact_point: { organization_id: org_id }` | Nhập quân số cho đầu mối thuộc đơn vị mình. Nested condition: Personnel → ContactPoint → org_id. | F03 |
| `can :manage` | `MeterReading` | `meter: { organization_id: org_id }` | Nhập chỉ số công tơ thuộc đơn vị mình. Nested: MeterReading → Meter → org_id. | F06 |
| `can :read` | `MonthlyCalculation` | `contact_point: { organization_id: org_id }` | Xem bảng 24 cột đơn vị mình. PR#61 (`b9717c5`) tách `:manage` thành `:read` + `:recalculate` — admin_unit không cần create/update/destroy MonthlyCalculation trực tiếp. | F11 |
| `can :recalculate` | `MonthlyCalculation` | (như trên) | Bấm nút "Tính lại" trên F11 để rerun engine. Permission tách riêng để có ngữ nghĩa rõ ràng (least-privilege). | F09 |
| `can :read` | `UnitConfig` | `organization_id: org_id` | Xem cấu hình tỷ lệ + Khác của đơn vị mình. | F04 |
| `can :update_unit_config` | `UnitConfig` | `organization_id: org_id` | Cấu hình `unit_public_rate` (tỷ lệ công cộng đơn vị). Permission **riêng** (không dùng `:update`) để tách thẩm quyền với admin_level1 (admin_level1 sửa `savings_rate` + `division_public_rate` qua `:update`). | F04 |
| `can :update_electricity_supply` | `UnitConfig` | `organization_id: org_id` | Nhập số điện lực hàng tháng (cột `electricity_supply_kw`). Permission riêng để tách rõ với cấu hình tỷ lệ. | F05 |
| `can :read` | `MonthlyPeriod` | (no condition) | Xem danh sách kỳ tính toán + đơn giá. **Không** sửa được — chỉ admin_level1 quản lý F20. | F20 (read) |
| `can :read` | `RankQuota` | (no condition) | Xem định mức 7 nhóm cấp bậc. **Không** sửa được — chỉ admin_level1 quản lý F21. | F21 (read) |

**Scope isolation:** Mọi rule có condition `organization_id` đều dùng hash → `accessible_by(current_ability)` ở controller filter ngay tại DB query. Admin_unit của Trung đoàn 101 query `ContactPoint.accessible_by(current_ability)` chỉ trả về đầu mối Trung đoàn 101.

### 3.4 commander — Chỉ huy đơn vị

```ruby
def commander_abilities(user)
  org_id = user.organization_id

  can :read, ContactPoint,       organization_id: org_id
  can :read, Meter,              organization_id: org_id
  can :read, Personnel,          contact_point: { organization_id: org_id }
  can :read, MeterReading,       meter: { organization_id: org_id }
  can :read, MonthlyCalculation, contact_point: { organization_id: org_id }
  can :read, UnitConfig,         organization_id: org_id

  can :read, MonthlyPeriod
  can :read, RankQuota
end
```

| Permission | Subject | Condition | Giải thích nghiệp vụ |
|---|---|---|---|
| `can :read` | tất cả model nghiệp vụ | `organization_id` của đơn vị mình | **Read-only** mọi data đơn vị mình. Không nhập, không sửa, không xóa. Vai trò là chỉ huy đơn vị kiểm tra số liệu do admin_unit nhập, không thao tác trực tiếp. |

Không có `:recalculate` trên MonthlyCalculation — commander không bấm được nút "Tính lại" trên F11.

Không có `:update_unit_config`, `:update_electricity_supply` — không nhập F04 và F05.

**F# tương ứng:** F11 (xem bảng), F12 (dashboard — qua DashboardController scope theo `current_user.organization`), F13 (history). Tất cả ở chế độ xem.

### 3.5 tech — Đội kỹ thuật

```ruby
def tech_abilities
  can :manage, User
  can :read, :audit_log
  can :manage, :backup
end
```

| Permission | Subject | Giải thích nghiệp vụ | F# |
|---|---|---|---|
| `can :manage, User` | User | CRUD tài khoản. Khóa/mở khóa thủ công. Reset mật khẩu (thực tế là set `force_password_change = true` + nhập mật khẩu tạm). | F15 |
| `can :read, :audit_log` | Symbol `:audit_log` | Xem nhật ký PaperTrail. Symbol vì :audit_log không phải model — controller `AuditLogsController` dùng `authorize! :read, :audit_log`. | F19 |
| `can :manage, :backup` | Symbol `:backup` | Tạo, restore, xóa file backup. Tech là người duy nhất (cùng admin_level1 bị explicit cannot — xem 3.2). | — |

**KHÔNG có:** `can :read, ContactPoint` / `Meter` / `Personnel` / `MonthlyCalculation` / `UnitConfig` / `MonthlyPeriod` / `RankQuota`. Tech tuyệt đối không thấy data nghiệp vụ — phân tách rõ trách nhiệm IT vs nghiệp vụ điện.

**Hệ quả UX:** Khi tech vô tình truy cập URL nghiệp vụ (ví dụ `/contact_points`), `CanCan::AccessDenied` raise. ApplicationController rescue silently bounce về `/users` thay vì hiển thị "Bạn không có quyền":

```ruby
# app/controllers/application_controller.rb:9–17
rescue_from CanCan::AccessDenied do |_exception|
  if current_user&.tech?
    redirect_to users_path
  else
    redirect_to root_path, alert: t("flash.access_denied")
  end
end
```

DashboardController và HistoryController có thêm guard explicit ở đầu action để bounce tech sớm hơn (ví dụ `app/controllers/dashboard_controller.rb:5`).

---

## 4. Authorization patterns trong controllers

### 4.1 `authorize!` inline

Pattern phổ biến nhất — gọi `authorize!` ở đầu action:

```ruby
# app/controllers/audit_logs_controller.rb:5
def index
  authorize! :read, :audit_log
  ...
end

# app/controllers/monthly_summaries_controller.rb:11
def show
  authorize! :read, MonthlyCalculation
  ...
end
```

CanCanCan check ability → nếu không pass, raise `CanCan::AccessDenied` → ApplicationController rescue bounce về root.

### 4.2 `before_action :authorize_xxx`

Pattern cho controller có nhiều action chung permission:

```ruby
# app/controllers/users_controller.rb:2, 65–67
before_action :authorize_user_management

def authorize_user_management
  authorize! :manage, User
end
```

```ruby
# app/controllers/backups_controller.rb:2, 32–34
before_action :authorize_backup

def authorize_backup
  authorize! :manage, :backup
end
```

### 4.3 `set_target_org` — 3 biến thể không thống nhất

Các controller "view by org" (admin_level1 chọn đơn vị, admin_unit/commander chỉ thấy đơn vị mình) có pattern `set_target_org`. Hiện tại có **3 biến thể khác nhau** giữa các controller — không thống nhất.

**Biến thể 1 — DashboardController** (`app/controllers/dashboard_controller.rb:36–44`):

```ruby
def set_target_org
  if current_user.admin_level1?
    @all_orgs = Organization.units.ordered
    @selected_org_id = params[:org_id].presence || "all"
    @target_org = (@selected_org_id != "all") ? @all_orgs.find_by(id: @selected_org_id) : nil
  else
    @target_org = current_user.organization
  end
end
```

→ Hỗ trợ giá trị đặc biệt `"all"` cho admin_level1 — xem aggregate toàn Sư đoàn. `@target_org = nil` khi `"all"`. `apply_org_scope` ở dòng 77–84 fallback sang query `Organization.where(parent_id: division.id).pluck(:id)` khi `@target_org.nil?`.

**Biến thể 2 — MonthlySummariesController, ElectricitySuppliesController, MeterReadingsController, PersonnelReviewsController** (4 controller dùng cùng pattern):

```ruby
# app/controllers/monthly_summaries_controller.rb:59–70 (giống các file kia)
def set_target_org
  if current_user.admin_level1?
    @all_orgs = Organization.units.ordered
    @target_org = if params[:org_id].present?
      @all_orgs.find_by(id: params[:org_id])
    else
      @all_orgs.first
    end
  else
    @target_org = current_user.organization
  end
end
```

→ KHÔNG có "all". Nếu admin_level1 không truyền `params[:org_id]`, default = `@all_orgs.first` (đơn vị đầu danh sách — thường là Sư đoàn bộ). Bảng 24 cột không thể "all" vì mỗi đơn vị tính riêng.

**Biến thể 3 — HistoryController** (`app/controllers/history_controller.rb:65–73`):

```ruby
def set_orgs_for_admin
  if current_user.admin_level1?
    @all_orgs = Organization.units.ordered
    @target_org = @all_orgs.find_by(id: params[:org_id]) || @all_orgs.first
    @selected_org_id = @target_org&.id
  else
    @target_org = current_user.organization
  end
end
```

→ Tương tự biến thể 2 nhưng viết gọn hơn (one-liner `find_by(id) || first`). Đặt biến `@selected_org_id` thêm.

**Tại sao chưa thống nhất:** Các controller này được thêm dần qua nhiều PR (M1–M4), khi đó solo developer ưu tiên ship feature thay vì refactor. Có thể consolidate vào một concern `OrgScope` trong M6 nếu thời gian cho phép. Xem TODO #2.

### 4.4 `accessible_by(current_ability)` + `find_by` — close enumeration side channel

**Pattern an toàn cho lookup theo ID** (PR#25 + PR#26):

```ruby
# app/controllers/contact_points_controller.rb:68–73
def set_contact_point
  @contact_point = ContactPoint
                     .accessible_by(current_ability)
                     .find_by(id: params[:id])
  raise CanCan::AccessDenied unless @contact_point
end
```

**Vì sao quan trọng:** Pattern naïve `ContactPoint.find(params[:id])` + `authorize!` có **lỗ hổng existence enumeration**:

| Trường hợp | Pattern naïve | Hệ quả |
|---|---|---|
| ID không tồn tại | `ActiveRecord::RecordNotFound` → 404 | Attacker biết "ID này chưa từng có" |
| ID tồn tại nhưng cross-org | `CanCan::AccessDenied` → 302 redirect | Attacker biết "ID này có nhưng tôi không truy cập được" |

→ Attacker phân biệt được hai response, brute-force ID để biết `ContactPoint` nào tồn tại, đo size đơn vị khác, trinh sát nội bộ.

**Pattern fix:** `accessible_by(current_ability)` filter ngay tại query — record cross-org bị loại khỏi result giống như record không tồn tại. Cả hai trường hợp đều `find_by` trả về `nil` → cùng raise `CanCan::AccessDenied` → cùng response (302 + flash). Attacker không phân biệt được.

**Áp dụng tại:**
- `ContactPointsController#set_contact_point` (PR#26, commit `175a046`)
- `MetersController#load_and_authorize_contact_point` (PR#25, parent lookup)
- `PersonnelController#load_and_authorize_contact_point` (PR#25, parent lookup)
- `MonthlyPeriodsController#edit/update/unlock` (commit `3711527`, follow-up sau PR#55)
- `RankQuotasController#set_rank_quota`

### 4.5 Nested resource authorization

**Vấn đề:** Routes nested kiểu `resources :contact_points do resources :meters end` → URL `/contact_points/:contact_point_id/meters/:id`. Authorize chỉ con (Meter) là không đủ — phải authorize cả parent (ContactPoint).

**Pattern fix** (`app/controllers/meters_controller.rb:54–60`):

```ruby
before_action :load_and_authorize_contact_point  # load parent + check access
before_action :set_meter, only: [:edit, :update, :destroy]  # load child

def load_and_authorize_contact_point
  @contact_point = ContactPoint
                     .accessible_by(current_ability)
                     .includes(:organization)
                     .find_by(id: params[:contact_point_id])
  raise CanCan::AccessDenied unless @contact_point
end

def set_meter
  @meter = @contact_point.meters.find(params[:id])
end
```

→ Lookup `@meter` đi qua `@contact_point.meters` (đã được scope) → không cần authorize lại cho mỗi action. Action vẫn gọi `authorize! :create, @meter` v.v. để check role-level permission.

**Tương tự:** `PersonnelController` (`controllers/personnel_controller.rb:69–75`) authorize parent ContactPoint trước.

### 4.6 `accessible_by` cho index pages

Pattern cho list view scope theo role:

```ruby
# app/controllers/contact_points_controller.rb:9
@q = ContactPoint.accessible_by(current_ability).ransack(params[:q])
@pagy, @contact_points = pagy(@q.result.ordered.includes(...), limit: 25)
```

→ Admin_level1 thấy tất cả; admin_unit/commander chỉ thấy đơn vị mình. Filter ở DB level (hash conditions trong Ability), không phải in-memory.

`ransack` (search/filter) chạy trên scope đã filter — search box không leak data cross-org.

---

## 5. Security hardening — lịch sử PR

Các PR security quan trọng theo thứ tự thời gian:

### PR#23 (commit `a3fadec`) — M3 CanCanCan refactor

**Vấn đề:** Trước M3 không có CanCanCan — phân quyền viết tay rải rác trong controllers (`if current_user.role == "admin_level1"`).

**Giải pháp:** Tạo `Ability` class tập trung. Refactor 9 controller dùng `authorize!`. Thêm shared example cho cross-org access spec.

**Bài học:** Phân quyền tập trung dễ audit hơn — đọc 1 file thay vì grep 9 controller. Hash conditions cho phép `accessible_by`, không cần load Ruby.

### PR#24 (commit `d9b9cb6`) — F06 data pollution bug fix

**Vấn đề:** Form F06 (nhập chỉ số công tơ) có 79 row (1 row/công tơ SDB). User để trống cả `reading_start` lẫn `reading_end` cho công tơ chưa nhập → controller vẫn `find_or_initialize_by` → tạo `MeterReading` với cả hai cột NULL → engine F09 đọc `consumption = NULL - NULL` ra 0 → bảng 24 cột báo cáo công tơ đó tiêu thụ 0 kW (sai).

**Giải pháp:**
- Controller: skip row nếu cả `reading_start_raw` lẫn `reading_end_raw` blank (`meter_readings_controller.rb:130`).
- Model: validate `reading_start` required khi `reading_end` present (và ngược lại).

**Bài học:** Form bulk update phải distinguish "user không nhập" vs "user nhập rỗng". Không nên dùng `find_or_initialize_by` blindly cho mọi key trong params.

Đây không phải authentication/authorization bug, nhưng là **data integrity** bug có hậu quả lan ra báo cáo — tính chất security-related (correctness của output ảnh hưởng đến quyết định nghiệp vụ).

### PR#25 (commit `6ae2903`) — Nested auth audit

**Vấn đề:** `MetersController` và `PersonnelController` (nested under `contact_points/:id`) chỉ authorize con (Meter, Personnel), không authorize parent. Attacker có thể truyền `contact_point_id` của đơn vị khác — nếu `Meter.find` và `authorize!` hoạt động, có lúc rò data.

**Giải pháp:** Thêm `before_action :load_and_authorize_contact_point` chạy TRƯỚC các before_action khác. Lookup parent qua `accessible_by(current_ability)`.

**Bài học:** Nested resources cần authorize cả parent VÀ child. Order before_action quan trọng — auth trước mọi DB lookup khác.

### PR#26 (commit `1e6e0b3`) — ContactPoints existence-enum fix

**Vấn đề:** `ContactPointsController#show/update/destroy` dùng `ContactPoint.find` → 404 cho ID không tồn tại, 302 cho ID cross-org. Phân biệt được = enumeration leak.

**Giải pháp:** Migrate sang `accessible_by(current_ability).find_by(id:)` → cả hai trường hợp cùng response. Pattern này lan ra MonthlyPeriods (PR#55 follow-up `3711527`), RankQuotas.

**Bài học:** Response code phải nhất quán cho "not exist" và "exist but not yours". Otherwise attacker enum.

### PR#27 + PR#28 (commits `d0fbcb5`, `468d710`, `b720583`, `df9ce52`, `1642ee8`) — Devise hardening

Group 5 commits:
- `d0fbcb5`: tăng `timeout_in` 30 phút → 2 giờ.
- `468d710`: enforce password complexity (8+ chars + 1 letter + 1 digit).
- `b720583`: session timeout warning modal + endpoint `/sessions/extend`.
- `df9ce52`: refactor cache `session_expires_at` ở layout.
- `1642ee8`: system spec sign-out button trong modal.

**Bài học:** Default Devise tốt nhưng cần điều chỉnh theo nghiệp vụ — quân đội không cần auto-lock 30 phút. Modal warning quan trọng cho UX khi timeout dài (user mất công nhập lại data dài).

### PR#33 (commit `bfb5f62`) — Last admin safeguard + idempotent seed

**Vấn đề:** Có thể khóa hoặc xóa admin_level1 cuối cùng → deadlock. Seed lần 2 không update password (find_or_create_by!).

**Giải pháp:** Ba lớp bảo vệ (xem 2.9). Seed dùng `find_or_initialize_by + save!`. Rake task `admin:reset_password` làm escape hatch.

**Bài học:** Multi-layer defense: validation, callback, controller guard, log warning. Mỗi layer chặn một entry point. Escape hatch (rake task chạy trên server) cho trường hợp tất cả layer fail.

### PR#30 (commit `cc2ec2e`) — Railway production + Rack::Attack

**Vấn đề:** Triển khai production cần force HTTPS, throttle login brute-force, chặn bot probing.

**Giải pháp:**
- `force_ssl + assume_ssl` ở `production.rb`.
- Security headers: X-Frame-Options, X-Content-Type-Options, Referrer-Policy.
- Rack::Attack: throttle login 5/phút/IP, throttle session extend 60/phút/IP, blocklist bot path.
- robots.txt `Disallow: /` + meta `noindex, nofollow`.

**Bài học:** Production cần lớp bảo vệ riêng ở cấp web server / middleware, không chỉ Rails. Rack::Attack chặn được nhiều attack mà Devise lockable không bắt (vì Lockable đếm theo user, attacker enumerate nhiều email).

### PR#34 (commit `c9e1831` + `195c6db`) — Custom Devise login + remove :recoverable

**Vấn đề:** Devise default views tiếng Anh; `:recoverable` cần SMTP nhưng dự án không có.

**Giải pháp:** Custom views Vietnamese trong `app/views/devise/sessions/`. Gỡ `:recoverable` khỏi User model. Recovery qua rake task `admin:reset_password`.

**Bài học:** Tránh enable Devise modules không có infrastructure backing. Gỡ rồi giữ DB column cũng OK (column unused, no harm).

### PR#61 (commit `b945660`) — Tech debt cleanup

**Vấn đề:** 3 issue tách rời:
1. Validation `greater_than_or_equal_to: 0` chặn `other_value` âm — sai nghiệp vụ (xác nhận v5.3.0 §11.2 cho phép âm).
2. admin_unit có `can :manage, MonthlyCalculation` quá rộng — chỉ cần đọc + recalculate.
3. Config `reset_password_within` dead sau khi gỡ `:recoverable` (PR#34).

**Giải pháp:**
1. Xóa validation, ImportFeb2026Service bỏ `validate: false` workaround.
2. Tách `:manage` thành `:read` + `:recalculate` (least-privilege).
3. Xóa config dead.

**Bài học:** Định kỳ audit Ability — quyền ban đầu thường rộng hơn cần thiết, refactor dần theo least-privilege. Dead config không hại nhưng gây nhầm lẫn đọc code.

---

## 6. Bảo mật mạng và hạ tầng

### 6.1 HTTPS

**Hiện tại:** Production trên Railway có HTTPS (`force_ssl = true` + `assume_ssl = true` ở `production.rb:29, 32`). Mini PC production (kế hoạch chuyển sang) sẽ dùng local certs do bên IT khách cung cấp — chi tiết xem `08_INFRASTRUCTURE` (khi có).

**Nginx production.conf** (`config/nginx/production.conf`) hiện chỉ listen port 80 — chưa có SSL block. Điều này là intent: Mini PC chạy sau HTTPS reverse proxy (Cloudflare hoặc nginx ngoài cùng do IT khách quản lý), Rails app chỉ nhận HTTP từ proxy. `assume_ssl = true` giúp Rails tin headers `X-Forwarded-Proto: https`.

### 6.2 Security headers

**Rails-level** (`config/environments/production.rb:72–76`):

```ruby
config.action_dispatch.default_headers.merge!(
  "X-Frame-Options"        => "SAMEORIGIN",
  "X-Content-Type-Options" => "nosniff",
  "Referrer-Policy"        => "strict-origin-when-cross-origin"
)
```

**Nginx-level** (`config/nginx/production.conf:15–17`):

```nginx
add_header X-Frame-Options SAMEORIGIN;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
```

| Header | Mục đích |
|---|---|
| `X-Frame-Options: SAMEORIGIN` | Chặn iframe từ origin khác → tránh clickjacking. |
| `X-Content-Type-Options: nosniff` | Browser không tự đoán content-type → tránh MIME confusion attack. |
| `Referrer-Policy: strict-origin-when-cross-origin` | Khi navigate ra origin khác, chỉ gửi domain (không full path) → tránh leak URL nội bộ. |
| `X-XSS-Protection: 1; mode=block` | Bật XSS filter của browser cũ (deprecated trong Chrome modern, nhưng vô hại). |

**Không có Content-Security-Policy (CSP)** explicit. Rails 8 default `csp_meta_tag` ở layout (`app/views/layouts/application.html.erb:10`) tạo nonce cho inline script nhưng không lock policy chặt. Nếu cần CSP strict, thêm vào `config/initializers/content_security_policy.rb` (chưa tồn tại).

### 6.3 Rack::Attack

File: `config/initializers/rack_attack.rb` (mount tại `config/application.rb:32` `config.middleware.use Rack::Attack`).

```ruby
class Rack::Attack
  throttle("logins/ip", limit: 5, period: 60.seconds) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  throttle("sessions_extend/ip", limit: 60, period: 60.seconds) do |req|
    req.ip if req.path == "/sessions/extend" && req.post?
  end

  blocklist("block_probing") do |req|
    [
      "/.env", "/wp-admin", "/wp-login.php", "/.git/config",
      "/admin.php", "/phpMyAdmin"
    ].any? { |path| req.path.start_with?(path) }
  end

  self.throttled_responder = ->(_request) {
    [ 429, { "Content-Type" => "text/plain" }, [ "Retry later.\n" ] ]
  }
end
```

| Rule | Tác dụng |
|---|---|
| `throttle logins/ip` | Tối đa 5 POST `/users/sign_in` mỗi phút mỗi IP. Vượt → 429. Phòng brute-force trước khi Devise Lockable đếm đến 5. |
| `throttle sessions_extend/ip` | Tối đa 60 POST `/sessions/extend` mỗi phút mỗi IP. Modal extend session bình thường gọi 1 lần/2 giờ — 60/phút là rộng rãi. |
| `blocklist block_probing` | Chặn 6 path bot probing (.env, wp-admin, ...). Log + return 403. Giảm noise log production. |

**Không có throttle cho path nghiệp vụ** (ví dụ `/contact_points`) — assume nội bộ LAN, traffic thấp. Production thực tế có 1 admin_level1 + ~15 admin_unit, không cần throttle business endpoint.

### 6.4 robots.txt + meta noindex

**`public/robots.txt`:**

```
User-agent: *
Disallow: /
```

**Layout meta tag** (`app/views/layouts/application.html.erb:8`):

```html
<meta name="robots" content="noindex, nofollow, noarchive, nosnippet">
```

→ Phần mềm nội bộ không cần index search engine. Hai lớp cùng chặn (robots.txt cho crawler tự giác, meta cho crawler ngoan cố tự crawl bỏ qua robots.txt).

### 6.5 Container — non-root user

`Dockerfile` line 65–67:

```dockerfile
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000
```

→ Container chạy với UID 1000 (không phải root). Nếu attacker exploit Rails process, không có quyền root để escalate trong container. Bind mount `db/backups/` cũng phải owner UID 1000 (xem 05_BUSINESS_LOGIC mục 5).

### 6.6 CSRF + cookie

**CSRF:** Rails default — `protect_from_forgery` enable, `csrf_meta_tags` ở layout. Devise không bypass CSRF. Mọi POST/PATCH/PUT/DELETE phải có authenticity token.

**Cookie:** `force_ssl = true` ở production tự động set `secure: true` cho cookie session → chỉ gửi qua HTTPS. Cookie session là Rails default (`ActionDispatch::Session::CookieStore`) — encrypted + signed bằng `secret_key_base`.

**`config.skip_session_storage = [:http_auth]`** (`devise.rb:100`) — auth qua HTTP Basic không lưu session, mỗi request phải auth lại. Không dùng trong UI bình thường.

---

## 7. PaperTrail — audit trail

### 7.1 Whodunnit wiring

`app/controllers/application_controller.rb:6, 23–25`:

```ruby
before_action :set_paper_trail_whodunnit

def user_for_paper_trail
  current_user&.id
end
```

`set_paper_trail_whodunnit` là helper Devise/PaperTrail integration: gọi `user_for_paper_trail` lấy giá trị → set `PaperTrail.request.whodunnit`. Mọi version tạo trong request đó có `whodunnit = current_user.id` (string của ID).

Khi không có user (không thể xảy ra trong app này vì `authenticate_user!` ép sign in), `whodunnit = nil`.

### 7.2 13 model tracked

Tất cả model nghiệp vụ + `User` đều có `has_paper_trail`:

| Model | Lý do tracking |
|---|---|
| `Organization` | Cấu trúc Sư đoàn ít đổi nhưng nếu rename hoặc reparent — quan trọng audit. |
| `User` | Tạo user mới, đổi role, đổi email, lock/unlock — phải có audit. |
| `ContactPoint` | F01 — admin_unit thêm/sửa đầu mối, audit để verify đúng đơn vị. |
| `Meter` | F02 — thêm/sửa công tơ, audit để xem ai đổi loại công tơ (`meter_type` → ảnh hưởng phân bổ tổn hao). |
| `MeterReading` | F06 — chỉ số công tơ, audit để xem ai sửa số đã nhập. |
| `Personnel` | F03 — quân số 7 nhóm, ảnh hưởng tiêu chuẩn. |
| `RankQuota` | F21 — định mức cấp bậc, audit khi có nghị định mới. |
| `MonthlyPeriod` | F20 — đơn giá thay đổi hàng tháng, audit để xem ai sửa giá. |
| `UnitConfig` | F04 + F05 — tỷ lệ công cộng, tiết kiệm, số điện lực. |
| `MonthlyCalculation` | Kết quả engine — audit để xem khi nào engine rerun, kết quả thay đổi gì. |
| `ContactPointOtherDeduction` | F04 cột "Khác" — admin_unit nhập, audit đặc biệt vì cho phép giá trị âm. |
| `PumpStation` | Trạm bơm thay đổi cấu hình. |
| `PumpStationAssignment` | Mapping trạm bơm ↔ đơn vị phục vụ. |

Các model **không tracked** (vì không nhập liệu trực tiếp): bảng PaperTrail `versions` chính nó.

### 7.3 F19 — Audit log UI

**Controller:** `AuditLogsController#index` (`app/controllers/audit_logs_controller.rb`).

**Authorization:** `authorize! :read, :audit_log` — admin_level1 (`can :manage, :all`) + tech (`can :read, :audit_log`) xem được. Admin_unit và commander **không** xem được (không có grant).

**Filter:**
- `params[:whodunnit]` — lọc theo user ID.
- `params[:item_type]` — lọc theo model (ví dụ "MonthlyPeriod", "UnitConfig").
- `params[:date_from]`, `params[:date_to]` — lọc theo khoảng thời gian (`created_at`).

**Hiển thị:**
- 25 row/page (`pagy`).
- Map `whodunnit` (string ID) → `User.full_name` qua `@users_map`.
- Filter dropdown: `@all_users` (tất cả user) + `@item_types` (distinct `item_type` từ DB).

**Không có:** chức năng revert (rollback đến version cũ). Audit log chỉ để xem, không hành động.

### 7.4 PaperTrail disabled trong ImportFeb2026Service

`app/services/import_feb_2026_service.rb:120`:

```ruby
PaperTrail.request(enabled: false) do
  ActiveRecord::Base.transaction do
    @period = upsert_monthly_period
    ...
  end
end
```

**Lý do** (comment dòng 116–119):

> PaperTrail versions are for tracking human edits in the UI. This service is an automated bulk loader — audit trail for it belongs to git / the Rake task invocation, not to a per-row DB log. Suppress version creation so re-running on identical data is truly a no-op.

→ Idempotent re-run không tạo noise. Nếu cần audit, xem git log của file source / log của rake task.

### 7.5 PaperTrail KHÔNG ignore Devise trackable columns

**Vấn đề tiềm ẩn:** Mỗi lần user đăng nhập, Devise Trackable update `sign_in_count`, `current_sign_in_at`, etc. → row `users` UPDATE → PaperTrail tạo version. Mỗi user đăng nhập 5 lần/ngày × 10 user = 50 version "noise" mỗi ngày trong audit log.

**Code hiện tại** (`app/models/user.rb:5`):

```ruby
has_paper_trail
```

→ Không có `:ignore` option. Trackable columns có trong version mỗi lần.

**Fix dự kiến:**

```ruby
has_paper_trail ignore: [
  :sign_in_count, :current_sign_in_at, :last_sign_in_at,
  :current_sign_in_ip, :last_sign_in_ip, :failed_attempts,
  :remember_created_at, :reset_password_token, :reset_password_sent_at
]
```

Xem TODO #1 cuối file.

---

## TODO — sai lệch giữa code và docs

### TODO #1 — PaperTrail trên User track noise từ Devise Trackable

**Vấn đề:** `has_paper_trail` trên `User` không ignore các cột Devise auto-update (Trackable + Lockable + Recoverable + Rememberable). Mỗi login tạo 1 version → audit log F19 đầy noise.

**Code thực tế** (`app/models/user.rb:5`): `has_paper_trail` không có option.

**Đề xuất:** thêm `ignore:` array với các cột auto-update. Cần kiểm tra UI F19 hiện tại có filter theo `event_type` hoặc skip Devise versions không (chưa kiểm tra trong scope file này).

**Trade-off:** mất khả năng track "user X login lúc nào" — nhưng thông tin này đã có ở chính cột `current_sign_in_at` của model User, không cần version.

### TODO #2 — `set_target_org` không thống nhất giữa 6 controller

**Vấn đề:** 3 biến thể của `set_target_org` (xem mục 4.3). Code lặp giữa MonthlySummaries, ElectricitySupplies, MeterReadings, PersonnelReviews. Dashboard và History có biến thể riêng.

**Đề xuất:** consolidate vào concern `OrgScope` trong `app/controllers/concerns/`. Concern expose `@target_org`, `@all_orgs`, optional `@selected_org_id`. Cho phép option `default: :first | :all` để khác biệt dashboard (`:all`) vs các controller khác (`:first`).

**Risk:** refactor hardcode pattern mà mỗi controller có twist nhỏ → có thể leak case edge. Test coverage hiện tại đủ tốt nhưng cần chạy lại full suite.

**Ưu tiên:** thấp — không phải bug, chỉ là tech debt. Có thể làm M6 nếu thời gian cho phép.

### TODO #3 — `accessible_by` chưa áp dụng cho `MonthlyCalculation` lookup

**Vấn đề:** `MonthlySummariesController#fetch_calculations` (dòng 91–97) dùng `MonthlyCalculation.by_organization(@target_org.id)` — KHÔNG đi qua `accessible_by`. Tin tưởng `set_target_org` đã filter đúng.

**Code:**
```ruby
def fetch_calculations
  MonthlyCalculation
    .by_organization(@target_org.id)
    .for_period(@period.id)
    ...
end
```

**Đánh giá:** Hiện tại an toàn vì `@target_org` được set trong `set_target_org`:
- admin_unit: `@target_org = current_user.organization` → chính đơn vị mình.
- admin_level1: `@target_org = @all_orgs.find_by(id: params[:org_id])` — `@all_orgs = Organization.units.ordered` (tức tất cả 13 đơn vị cấp 2). Admin_level1 có quyền tất cả → không leak.
- commander: tương tự admin_unit.

→ Không có lỗ hổng thực tế, nhưng pattern không nhất quán với phần còn lại của codebase. Nếu sau này thay đổi logic `set_target_org` (ví dụ thêm role mới), có thể leak.

**Đề xuất:** dùng `MonthlyCalculation.accessible_by(current_ability).by_organization(...)` — thêm 1 chain, defense in depth.

### TODO #4 — F-number trong commit message không thống nhất

**Vấn đề:** Một số commit cũ dùng F-number sai so với GLOSSARY v1.2.0:

- "feat: Enable Devise Timeoutable (F18) — auto-logout after 30 minutes (#22)" — F18 thực tế là **Force password change**, không phải session timeout. Session timeout không có F-number riêng (xem `02_GLOSSARY` mục 8.5 lưu ý).
- "feat: Add force password change flow (F16)" trong PR cũ — nhầm F16 (Login) với F18.
- "test(f18): add system spec for sign-out button in session timeout modal" — nhầm như trên.

**Tác động:** Không ảnh hưởng functionality, chỉ ảnh hưởng đọc git log. Khi tra cứu PR theo F-number có thể nhầm.

**Đề xuất:** khi viết tài liệu mới, dùng F-number theo `02_GLOSSARY v1.2.0`. Không cần sửa commit history (rebase rủi ro hơn lợi ích).

### TODO #5 — Devise `:recoverable` không bật nhưng cột DB còn

**Vấn đề:** PR#34 gỡ `:recoverable` khỏi Devise modules. Cột `reset_password_token` (unique index) và `reset_password_sent_at` còn trong bảng `users`. Comment ở `04_DATABASE_MODELS` mục 2.2 đã ghi nhận.

**Đề xuất:** giữ nguyên — không có hại. Migration drop column phải thận trọng (nếu rollback rõ ràng phức tạp). Nếu cần thuần khiết, có thể migration `remove_column` trong M6 sau khi nghiệm thu.

### TODO #6 — `audit_logs_controller` không filter theo organization

**Vấn đề:** Tech và admin_level1 cùng xem `AuditLogsController#index`. Tech thuộc Sư đoàn (parent), không có org-scope. Admin_level1 cũng manage all → cũng không scope.

**Hệ quả:** không có vấn đề thực tế (cả 2 role đều có quyền xem mọi đơn vị). Nhưng nếu sau này thêm role "admin_unit có thể xem audit log đơn vị mình", controller hiện tại không có scope mechanism.

**Đề xuất:** không cần làm cho M6 — phạm vi xác nhận không có yêu cầu này.

---

## Changelog

| Version | Ngày | Thay đổi |
|---|---|---|
| v1.0.0 | 01/05/2026 | Khởi tạo. Devise 6 modules, CanCanCan 4 role, 6 authorization patterns, 8 PR security history (#23–28, #30, #33, #34, #61), Rack::Attack + nginx + non-root container, PaperTrail 13 model + 6 TODO. |
