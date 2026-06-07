# Endpoint công khai để script deploy / bộ phận hỗ trợ xác minh bản đang chạy.
# Kế thừa ActionController::Base trực tiếp: không cần đăng nhập, không vướng
# before_action của ApplicationController (authenticate_user!, enforce_password_change...).
class VersionController < ActionController::Base
  def show
    render json: SystemInfo.to_h
  end
end
