module BusinessRoleRequired
  extend ActiveSupport::Concern

  # Mapping sidebar trong V2_THIET_KE_HE_THONG.md: tổng quan, bảng tính tiền,
  # tra cứu lịch sử, nhập liệu, cấu hình đơn vị chỉ dành cho 3 role nghiệp vụ.
  # Technician chỉ làm task hệ thống (users, audit_logs, backups).
  ALLOWED_ROLES = %w[system_admin unit_admin commander division_commander].freeze

  included do
    before_action :ensure_business_role
  end

  private

  def ensure_business_role
    return if current_user && ALLOWED_ROLES.include?(current_user.role.to_s)
    # Redirect kỹ thuật viên về trang mặc định của họ (tránh loop khi root_path = dashboard).
    redirect_to fallback_path_for_unauthorized_role,
                alert: I18n.t("errors.access_denied")
  end

  def fallback_path_for_unauthorized_role
    return new_user_session_path unless current_user
    case current_user.role.to_s
    when "technician" then users_path
    else new_user_session_path
    end
  end
end
