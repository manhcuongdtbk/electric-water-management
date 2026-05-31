module SettingsAccessGuard
  extend ActiveSupport::Concern

  # Page-level guard cho các trang Thiết lập / Hệ thống.
  # Theo mapping sidebar trong V2_THIET_KE_HE_THONG.md:
  # - zones, pump_allocations: chỉ system_admin và đơn vị quản lý khu vực (zone manager)
  # - units, pricing, ranks: chỉ system_admin
  # - users: chỉ system_admin và technician (quản lý tài khoản)
  #
  # Redirect kèm cảnh báo (giống BusinessRoleRequired và rescue CanCan::AccessDenied):
  # chặn truy cập trực tiếp qua URL khi sidebar đã ẩn liên kết.

  private

  def require_system_admin!
    return if current_user&.system_admin?
    deny_settings_access
  end

  def require_system_admin_or_zone_manager!
    return if current_user&.system_admin? || current_zone_manager?
    deny_settings_access
  end

  def require_account_manager!
    return if current_user&.system_admin? || current_user&.technician?
    deny_settings_access
  end

  def deny_settings_access
    redirect_to root_path, alert: I18n.t("errors.access_denied")
  end
end
